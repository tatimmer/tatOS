;tatOS/tlib/dropdown.s
;rev Jan 2016

;dropdowncreate
;dropdownpaint
;showpopup


;this is a dropdown list box for tatOS
;contains a "title" string with multiple "option" strings below 

;the dropdown can be used to make a popup menu on right click or
;you can string multiple dropdowns across the top of the screen
;to make a main program menu

;the popup will not show up on the screen until user calls "showpopup"
;typically done in response to a Rclick then the title and option strings
;will be visible all at once. The menu title will be visible immediately 
;and the option strings will become visibile when the mouse is hovered 
;over the title.

;you must allocate in userland and fill in as stated below
;one DROPDOWNSTRUC for each instance of a drop down box
;[1] indicates you should initially set this value to 0
;and kernel will fill the proper value in for you later

;DROPDOWNSTRUC
;dword dropdown type 0=menu, 1=popup          [esi]
;dword ID of selected string return value [1] [esi+4]
;dword address of 0 terminated title string   [esi+8]
;dword xloc                                   [esi+12]
;dword yloc                                   [esi+16]
;dword width of dropdown                      [esi+20]
;dword full height of dropdown [1]            [esi+24]
;dword expose event            [1]            [esi+28]
;dword qty option strings                     [esi+32]
;dword address option string 0                [esi+36]
;dword address option string 1                [esi+40]
;dword address option string n                [esi+36+n*4]


;dropdown type  [esi]
;use 0 for a top level menu and 1 for a popup

;ID of selected string  [esi+4]
;in response to a mouse Lclick
;your app must read this value to determine which item was selected
;the ID of the selected option string is 0->(n-1)
;else -1=0xffffffff if no selection
;selecting the title string results in -1

;xloc yloc [esi+12], [esi+16]
;the x,y loc are the upper left corner of the title string
;for a menu across the top of your screen use yloc=0 and the appropriate xloc
;for a popup menu just use 0,0 for xloc, yloc as kernel will take care of this

;full height [esi+24]
;the height is computed by kernel and includes the title string plus all option strings

;expose event [esi+28]
;set to 0 initially, kernel will take care of this

;this control will over-ride users YORIENT value but then restore it on exit

;the title string and options strings must all be 0 terminated

;font02 is used
;each title & option string may be up to 12 characters
;the title string and each option string occupy 15 pixels hi
;the height of the dropdown is 15 times qty option strings + 
;another 15 for the title string

;your app must properly handle the following functions:
;dropdowncreate
;dropdownpaint

;for an example of how to use the dropdown see tatOS/apps/DROPDN




ddlstr1 db 'dropdowncreate',0
ddlstr2 db 'dropdownpaint',0
ddlstr3 db 'dropdown:full height of dropdown',0
ddlOptionStringY   dd 0

dropdownRect times 16 db 0


;**********************************************************
;dropdowncreate

;input: 
;push address of DROPDOWNSTRUC                [ebp+8]

;return:none
;**********************************************************

dropdowncreate:

	push ebp
	mov ebp,esp

	;STDCALL ddlstr1,dumpstr

	;esi=address of DROPDOWNSTRUC
	mov esi,[ebp+8]   

	;compute and save full exposed height of dropdown including the title string
	mov eax,[esi+32]  ;eax=qty option strings
	mov ebx,15        ;each string is 15 pixels hi
	mul ebx           ;eax=15*qtyoptionstrings
	add eax,15        ;add height of title string, eax=total height of dropdown
	mov [esi+24],eax  ;save height of dropdown
	;STDCALL ddlstr3,0,dumpeax

	;set ID of selected option string to -1 indicating no selection
	mov dword [esi+4],-1

	pop ebp
	retn 4







;****************************************************
;dropdownpaint
;see notes above

;input: push address of DROPDOWNSTRUC                [ebp+8]

;return:
;this function does not return a value
;but is will save dynamically as the mouse is hovering
;the integer ID of the option string under the mouse
;this ID is saved to dword [DROPDOWNSTRUC+4] 
;user apps should respond to usbcheckmouse al=1 for Lclick
;if the Lclick occurs outside the dropdown then
;the value of dword [DROPDOWNSTRUC+0] = -1 or 0xffffffff

;sample code for responding to the menu selection
;	mov eax,63  ;usbcheckmouse
;	sysenter
;	cmp al,1    ;Lclick
;	jz HandleLeftMouse
;HandleLeftMouse:
;   check for File menu selection
;	mov eax,[FileMenuStruc+4]  ;get ID of selected menu item
;	cmp eax,0xffffffff         ;check for no selection
;	jz .doneFileMenu
;	mov ebx,FileMenuProcTable[eax]  ;get proc address
;   jmp ebx  ;and jmp to that proc or call if you prefer
;.doneFileMenu:

;this procedure uses the value of "mousey1" which is 
;the y coordinate of the mouse with y=0 at the top
;of the screen and +y going down (see /usb/mouseinterrupt.s)

;****************************************************

dropdownpaint:

	push ebp
	mov ebp,esp

	;STDCALL ddlstr2,dumpstr

	;force the dropdown to be placed at the top of the screen
	;so it will properly "dropdown" making option strings visible
	push dword [YORIENT]  ;save calling programs Yorientation
	mov dword [YORIENT],1 ;set Yorientation to top down



	;in dropdownpaint we must preserve esi
	mov esi,[ebp+8]  ;esi=address of DROPDOWNSTRUC


	;is this a menu ?
	cmp dword [esi],0
	jz .drawtitle


	;if we got here we have a popup 
	;we only draw the popup if user sets expose=1 on Rclick
	cmp dword [esi+28],1
	jnz near .popupnoexpose


.drawtitle:

	;gray background rectangle for title
	push dword [esi+12]  ;x
	push dword [esi+16] ;y
	push dword [esi+20] ;w
	push 15             ;h
	push 0xe9           ;gray background
	call fillrect


	;title string
	push FONT02
	mov eax,[esi+12]  
	add eax,2
	push eax                    ;x+2
	mov eax,[esi+16] 
	;add eax,2               
	push eax                    ;y+2
	push dword [esi+8]          ;address of title string
	push 0xefff                 ;colors
	call puts


	;draw a thick line under the title string
	push esi                  ;perserve address of MOUSEOPTIONSTRUC
	mov ebx,[esi+12]           ;x
	mov ecx,[esi+16]
	add ecx,15                ;y
	mov edx,[esi+20]          ;width of dropdown
	mov esi,BLA               ;color
	call hline
	sub ecx,1
	call hline
	pop esi


	;if the mouse was previously over the title
	;then we have permission to draw all the option strings
	;but first we should test to see if the user moved the mouse
	;outside the dropdown
	cmp dword [esi+28],1     ;check for expose event
	jz .haveExposeEvent  ;we already have an expose even so no need to check again


	;test if the mouse is over the title 
	mov eax,[esi+12]               ;x1
	mov [dropdownRect],eax
	mov ebx,[esi+16]               ;y1
	mov [dropdownRect+4],ebx
	add eax,[esi+20]               ;eax=x2=x1+width
	mov [dropdownRect+8],eax       ;x2
	mov edx,ebx                    ;edx=y1
	add edx,15                     ;edx=y2=y1+15  (title is 15 pixels hi)
	mov [dropdownRect+12],edx      ;y2
	push dropdownRect              ;address x1,y1,x2,y2 rect
	push dword [MOUSEX]            ;Px
	push dword [mousey1]           ;Py
	call ptinrect                  ;zf set if ptinrect
	jnz near .mousenotovertitle 
	
	;if we got here the mouse is over the title for the first time
	;set expose event = 1
	mov dword [esi+28],1


.haveExposeEvent:

	;test if mouse is over the dropdown title + option strings 
	mov eax,[esi+12]         ;eax=x1
	mov [dropdownRect],eax
	mov ebx,[esi+16]         ;ebx=y1
	mov [dropdownRect+4],ebx 
	mov edx,eax              ;edx=x
	add edx,[esi+20]         ;x2=x1+width
	mov [dropdownRect+8],edx
	add ebx,[esi+24]         ;y2=y1+height
	mov [dropdownRect+12],ebx
	push dropdownRect
	push dword [MOUSEX]      ;Px
	push dword [mousey1]     ;Py
	call ptinrect            ;zf set if ptinrect
	jnz near .mousenotoverdropdown 
	

.displayOptionStrings:

	;prepare to display the option strings with the appropriate background color
	;if the mouse is over an option string the background is colored blue else gray
	;each string starts at (x,ddlOptionStringY)
	;we increment pomOptionStringY by 15 pixels with every string drawn
	mov ecx,0          ;ecx=qty option strings drawn, we count up
	lea ebx,[esi+36]   ;ebx=address in DROPDOWNSTRUC for 1st option string
	mov edi,[ebx]      ;edi=address of 1st option string
	mov eax,[esi+16]   ;eax=Yloc of title string
	add eax,15         ;15=height of title string
	mov dword [ddlOptionStringY],eax  ;yloc option string 2b drawn

	;init ID of selected option string to -1 indicating no selection yet
	;if user exposes the dropdown but clicks on the title this returns 0xffffffff
	mov dword [esi+4],-1


.ddDrawStringsLoop:

	;loop to draw all the option strings 
	;in this loop we must preserve ebx, ecx


	;draw gray background for option string [i]
	push dword [esi+12]              ;x
	push dword [ddlOptionStringY]   ;y
	push dword [esi+20]             ;width
	push 15                         ;height
	push 0xe9                       ;gray background
	call fillrect


	;test if mouse is over an option string rect
	push ebx                      ;preserve
	mov eax,[esi+12]              ;x1
	mov [dropdownRect],eax
	mov ebx,[ddlOptionStringY]    ;y1
	mov [dropdownRect+4],ebx
	add eax,[esi+20]              ;x2=x1+w
	mov [dropdownRect+8],eax
	add ebx,15                    ;y2=y1+h
	mov [dropdownRect+12],ebx  
	push dropdownRect
	push dword [MOUSEX]           ;Px
	push dword [mousey1]          ;Py
	call ptinrect                 ;ZF set if ptinrect
	pop ebx
	jnz .drawstringUnselected
	

	;draw selected drop down string with RED text
	push FONT02
	push dword [esi+12]              ;xloc
	push dword [ddlOptionStringY]   ;yloc
	push edi                        ;address of string
	push 0xf5ff                     ;red text
	call puts
	
	;save id of RED/selected option string
	;this will be a value of 0 for the 1st option string up to (n-1)
	;if user clicks on title string or outside dropdown, saved value is -1
	;user has not Lclicked this string
	;this just indicates mouse is over this string
	mov [esi+4],ecx


	;test is user is holding down the left mouse button 
	;if so we will roll up the dropdown and 
	;return the index of selected string in the first dword of DROPDOWNSTRUC
	cmp dword [LBUTTONDOWN],1
	jz .cancelExpose

	jmp .increment


.drawstringUnselected:

	;draw un-selected string with BLACK text
	;mouse is not over this string
	push FONT02
	push dword [esi+12]             ;xloc
	push dword [ddlOptionStringY]   ;yloc
	push edi                        ;address of string
	push 0xefff                     ;black text 
	call puts
	

.increment:
	add dword [ddlOptionStringY],15   ;inc yloc
	add ebx,4                      ;inc address in DROPDOWNSTRUC for next option string
	mov edi,[ebx]                     ;read address of next option string
	inc ecx                           ;inc qty strings drawn 
	cmp ecx,[esi+32]                  ;cmp ecx with qty option strings
	jb .ddDrawStringsLoop

	jmp .done



.popupnoexpose:
.mousenotovertitle:
.mousenotoverdropdown:
	;we set the index of selected string to -1 indicating no selection
	mov dword [esi+4],-1
	;fall thru

.cancelExpose:
	;we got here when user moved mouse outside the dropdown
	;or user did Lclick over an option string that was displayed red
	;these are the only 2 ways to "roll up" the dropdown
	mov dword [esi+28],0

.done:
	pop dword [YORIENT]  ;restore calling program YORIENT
	pop ebp
	retn 4
	;end dropdownpaint




;*********************************************
;showpopup
;causes a popup menu to be fully displayed
;call this function in response to a Rclick
;we actually position the popup to be
;offset 20,20 pixels from the mouse so the 
;mouse will be over the first option string
;input:esi=address of DROPDOWNSTRUC
;return:none
;*********************************************

showpopup:
	push eax
	push ebx
	mov dword [esi+28],1  ;set expose=yes
	mov eax,[MOUSEX]
	sub eax,20
	mov [esi+12],eax      ;xloc
	mov ebx,[mousey1]
	sub ebx,20
	mov [esi+16],ebx      ;yloc
	pop ebx
	pop eax
	ret




