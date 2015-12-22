;tatOS/tlib/dropdown.s


;dropdowncreate
;dropdownpaint


;this is a dropdown list box for tatOS
;contains a "title" string with multiple "option" strings below 
;initially the option strings are not visible
;when the mouse is hovered over the title string the option strings will appear 

;multiple dropdowns can be used to make a top level menu

;you must allocate in userland and fill in as stated below
;one DROPDOWNSTRUC for each instance of a drop down box
;[1] indicates you should initially set this value to 0
;and kernel will fill the proper value in for you later

;DROPDOWNSTRUC
;dword ID of selected string   [1]            [esi]
;dword address of 0 terminated title string   [esi+4] 
;dword xloc                                   [esi+8]
;dword yloc                    [1]            [esi+12]
;dword width of dialog                        [esi+16]         
;dword full height of dialog   [1]            [esi+20]       
;dword expose event            [1]            [esi+24]            
;dword qty option strings                     [esi+28]
;dword address option string 0                [esi+32]
;dword address option string 1                [esi+36]
;dword address option string n                [esi+32+n*4]


;the ID of the selected option string is 0->(n-1)  else -1=0xffffffff no selection
;selecting the title string results in -1

;the x,y loc are the upper left corner of the title string
;the height is computed by kernel and includes the title string plus all option strings

;this control expects [YORIENT]=1

;the title string and options strings must all be 0 terminated

;the mouse must hover over the title string to generate an expose event
;that permits all option strings to be drawn
;moving the mouse outside the fully exposed region of the dialog
;cancels the expose and causes only the title string to be displayed 

;as the mouse hovers over an option string the text changes color
;and the ID of the "selected" option string is saved dynamically to [DROPDOWNSTRUC+0]
;if there is a Lclick over one of the option strings
;the user app should respond in its LeftButtonProc checking the value of [DROPDOWNSTRUC+0]

;font02 is used
;each title & option string may be up to 12 characters
;the title string and each option string occupy 15 pixels hi
;the height of the dialog is 15 times qty option strings + 
;another 15 for the title string

;your app must properly handle the following functions:
;dropdowncreate
;dropdownpaint

;for an example of how to use the dropdown for a top level menu
;see tatOS/apps/DROPDOWN


ddlstr1 db 'dropdowncreate',0
ddlstr2 db 'dropdownpaint',0
ddlstr3 db 'dropdown:full height of dialog',0
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

	;check for valid userland address here tom

	;esi=address of DROPDOWNSTRUC
	mov esi,[ebp+8]   

	;compute and save full exposed height of dialog including the title string
	mov eax,[esi+28]  ;eax=qty option strings
	mov ebx,15        ;each string is 15 pixels hi
	mul ebx           ;eax=15*qtyoptionstrings
	add eax,15        ;add height of title string, eax=total height of dropdown
	mov [esi+20],eax  ;save height of dropdown
	;STDCALL ddlstr3,0,dumpeax

	;set ID of selected option string to -1 indicating no selection
	mov dword [esi],-1

	;set Ylocation of dropdown to 0
	;for now all drop downs will be placed at the top of the screen
	;future versions may better handle YORIENT and allow for placement
	;anywhere on the screen as well as dropping "up"
	mov dword [esi+12],0

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
;this ID is saved to dword [DROPDOWNSTRUC+0] 
;user apps should respond to usbcheckmouse 
;al=1 (Lclick) 
;if the Lclick occurs outside the dropdown then
;the value of dword [DROPDOWNSTRUC+0] = -1 or 0xffffffff

;sample code for responding to the menu selection
;	mov eax,63  ;usbcheckmouse
;	sysenter
;	cmp al,1    ;Lclick
;	jz HandleLeftMouse
;HandleLeftMouse:
;   check for File menu selection
;	mov eax,[FileMenuStruc]  ;get ID of selected menu item
;	cmp eax,-1               ;-1 means no selection
;	jz .doneFileMenu
;	mov ebx,FileMenuProcTable[eax]  ;get proc address
;   jmp ebx  ;and jmp to that proc or call if you prefer
;.doneFileMenu:

;this procedure uses the value of "mousey1" which is 
;the y coordinate of the mouse with y=0 at the top
;of the screen and +y going down

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


	;gray background rectangle for title
	push dword [esi+8]  ;x
	push dword [esi+12]  ;y
	push dword [esi+16] ;w
	push 15             ;h
	push 0xe9           ;gray background
	call fillrect


	;title string
	push FONT02
	mov eax,[esi+8]  
	add eax,2
	push eax                    ;x+2
	mov eax,[esi+12] 
	;add eax,2               
	push eax                    ;y+2
	push dword [esi+4]          ;address of title string
	push 0xefff                 ;colors
	call puts


	;draw a thick line under the title string
	push esi                  ;perserve address of MOUSEOPTIONSTRUC
	mov ebx,[esi+8]           ;x
	mov ecx,[esi+12]
	add ecx,15                ;y
	mov edx,[esi+16]          ;width of dialog
	mov esi,BLA               ;color
	call hline
	sub ecx,1
	call hline
	pop esi


	;if the mouse was previously over the title
	;then we have permission to draw all the option strings
	;but first we should test to see if the user moved the mouse
	;outside the dialog
	cmp dword [esi+24],1     ;check for expose event
	jz .haveExposeEvent  ;we already have an expose even so no need to check again


	;if we got here the mouse has not been over the title
	;test if the mouse is somewhere over the title 
	;if so then we set Expose=1 
	mov eax,[esi+8]                ;x1
	mov [dropdownRect],eax
	mov ebx,[esi+12]               ;y1
	mov [dropdownRect+4],ebx
	add eax,[esi+16]               ;eax=x2=x1+width
	mov [dropdownRect+8],eax       ;x2
	mov edx,ebx                    ;edx=y1
	add edx,15                     ;edx=y2=y1+15  (title is 15 pixels hi)
	mov [dropdownRect+12],edx      ;y2
	push dropdownRect              ;address x1,y1,x2,y2 rect
	push dword [MOUSEX]            ;Px
	push dword [mousey1]           ;Py
	call ptinrect                  ;zf set if ptinrect
	jnz near .showDropdownNotVisible 
	
	;if we got here the mouse is over the title for the first time
	;set expose event = 1
	mov dword [esi+24],1


.haveExposeEvent:

	;if the mouse is somewhere over the dialog title + option strings 
	;in its drop down state and Expose==1 then we show the dropdown 
	;else we do not
	mov eax,[esi+8]          ;eax=x1
	mov [dropdownRect],eax
	mov ebx,[esi+12]         ;ebx=y1
	mov [dropdownRect+4],ebx 
	mov edx,eax              ;edx=x
	add edx,[esi+16]         ;x2=x1+width
	mov [dropdownRect+8],edx
	add ebx,[esi+20]         ;y2=y1+height
	mov [dropdownRect+12],ebx
	push dropdownRect
	push dword [MOUSEX]      ;Px
	push dword [mousey1]     ;Py
	call ptinrect            ;zf set if ptinrect
	jnz near .showDropdownNotVisible 
	

.displayOptionStrings:

	;prepare to display the option strings with the appropriate background color
	;if the mouse is over an option string the background is colored blue else gray
	;each string starts at (x,ddlOptionStringY)
	;we increment pomOptionStringY by 15 pixels with every string drawn
	mov ecx,0          ;ecx=qty option strings drawn, we count up
	lea ebx,[esi+32]   ;ebx=address in DROPDOWNSTRUC for 1st option string
	mov edi,[ebx]      ;edi=address of 1st option string
	mov eax,[esi+12]   ;eax=Yloc of title string
	add eax,15         ;15=height of title string
	mov dword [ddlOptionStringY],eax  ;yloc option string 2b drawn

	;init ID of selected option string to -1 indicating no selection yet
	;if user exposes the dropdown but clicks on the title this returns 0xffffffff
	mov dword [esi],-1


.ddDrawStringsLoop:

	;loop to draw all the option strings 
	;in this loop we must preserve ebx, ecx


	;draw gray background for option string [i]
	push dword [esi+8]              ;x
	push dword [ddlOptionStringY]   ;y
	push dword [esi+16]             ;width
	push 15                         ;height
	push 0xe9                       ;gray background
	call fillrect


	;test if mouse is over an option string rect
	push ebx                      ;preserve
	mov eax,[esi+8]               ;x1
	mov [dropdownRect],eax
	mov ebx,[ddlOptionStringY]    ;y1
	mov [dropdownRect+4],ebx
	add eax,[esi+16]              ;x2=x1+w
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
	push dword [esi+8]              ;xloc
	push dword [ddlOptionStringY]   ;yloc
	push edi                        ;address of string
	push 0xf5ff                     ;red text
	call puts
	
	;save id of RED option string
	;this will be a value of 0 for the 1st option string up to (n-1)
	;if user clicks on title string or outside dialog, saved value is -1
	;user has not Lclicked this string
	;this just indicates mouse is over this string
	mov [esi],ecx


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
	push dword [esi+8]              ;xloc
	push dword [ddlOptionStringY]   ;yloc
	push edi                        ;address of string
	push 0xefff                     ;black text 
	call puts
	

.increment:
	add dword [ddlOptionStringY],15   ;inc yloc
	add ebx,4                         ;inc address in DROPDOWNSTRUC for next option string
	mov edi,[ebx]                     ;read address of next option string
	inc ecx                           ;inc qty strings drawn 
	cmp ecx,[esi+28]                  ;cmp ecx with qty option strings
	jb .ddDrawStringsLoop

	jmp .done



.showDropdownNotVisible:
	;we set the index of selected string to -1 indicating no selection
	mov dword [esi],-1

.cancelExpose:
	;we got here when user moved mouse outside the dialog
	;or user did Lclick over an option string that was displayed red
	;these are the only 2 ways to "roll up" the dropdown
	mov dword [esi+24],0

.done:
	pop dword [YORIENT]  ;restore calling program YORIENT
	pop ebp
	retn 4
	;end dropdownpaint




