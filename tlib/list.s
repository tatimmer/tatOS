;tatOS/tlib/list.s

;Functions to provide elementory list control functionality
;The list control will display (15) 0 terminated strings and scroll the list

;kernel code must properly handle the following functions:
;	* ListControlInit
;   * ListControlPaint
;   * ListControlGetSelection
;   * ListControlDestroy

;userland apps must properly handle the following functions:
;   * ListControlAddStrings
;   * ListControlPaint

;this function is called by the shell to save a text dump of the cwd files
;   * ListControlSaveToFile


;ListControlKeydown is now incorporated into getc so you do not have to call
;this function in a kernel or user app.
;this version uses the UP/DN arrow keys to manipulate the list
;the DN arrow moves the selection bar to the bottom of the list at which point
;the list is scrolled up. The reverse happens when with UP arrow.
;also the Ylocation of top of the list box may be set as a variable
;The END key puts the last string of the list at the top
;The HOME key puts the first string of the list at the top

;for painting purposes the List Control occupies a fixed rectangle on your
;screen that starts at List_Ytop which you set and then extends down 240 pixels

;ListControl Buffer
;The List Control Buffer starts at 0x2950000  (LISTCTRLBUF)
;kernel may write strings directly to this buffer
;user code must use ListControlAddStrings
;each string is spaced 0x100 bytes apart
;each string must be no more than 80 char long
;so it fits on 1 line across the screen
;otherwise the string will be truncated
;The starting address of each string corresponds to:
;0x2950000 + n*0x100  
;were n=0,1,2,3,4... string index
;the buffer will hold a max of 500 strings

;list_IndexFirstString holds the index of the string drawn at the top of the
;list control, The arrow keys will inc/dec this value if the list is longer than
;15 strings. filemanager sets this to 0 when listing contents of a new subdirectory

;for examples of how to use the ListControl in the kernel see:
; filemanager, shell, cpuid
;for a userland example see FlashInfo


;list control globals
list_YLoc_SelectionBar   dd 0  ;Ylocation of gray selection bar
list_QtyStrings          dd 0
list_IndexFirstString    dd 0  ;index of string displayed at top of list control
list_IndexSelectedString dd 0
list_Ytop                dd 0  ;Ylocation of top of the list control 
list_Ybottom             dd 0  
list_YLastString         dd 0
list_HaveList            dd 0


list_str1 db 'ListControlKeydown',0


;delta Y between strings, font01 is 15 pixels hi
;do not change this value because there are some shr/shl below by 2^4=16
LISTSPACING equ 16     

;**********************************************************************
;ListControlInit
;call this before displaying the list control for the first time
;kernel code calls this function first
;userland code gets here indirectly via ListControlAddStrings
;input
;eax=qty items in list
;ebx=Ylocation of top of list control
;*********************************************************************

ListControlInit:

	mov dword [list_HaveList],1
	mov [list_QtyStrings],eax
	mov [list_Ytop],ebx
	mov [list_YLoc_SelectionBar], ebx
	add ebx,240  ;15 strings * 16 pixels hi per string
	mov [list_Ybottom],ebx
	sub ebx,LISTSPACING 
	mov [list_YLastString],ebx

	mov dword [list_IndexSelectedString],0
	mov dword [list_IndexFirstString],0
	ret


;********************************************************************
;ListControlDestroy
;indicated that the list control is no longer needed
;all we do is set a global variable to 0
;this is needed by getc which now incorporated ListControlKeydown
;to indicate the the ListControlKeydown code may be skipped
;userland apps will execute this code in tlibentry automatically on exit
;kernel code must call this function just before ret
;input:none
;return:none
;********************************************************************

ListControlDestroy:
	mov dword [list_HaveList],0
	ret



;*********************************************************************
;ListControlGetSelection
;returns the zero based index of the currently selected list string
;input:none
;return:
;ecx=index of selected item
;esi=starting address of selected string in list control buffer
;*********************************************************************

ListControlGetSelection:

	;this value is updated after each paint cycle
	mov ecx,[list_IndexSelectedString]

	;now return the starting address of the selected string in ebx.
	mov esi,0x2950000
	xor edx,edx
	mov eax,0x100
	mul ecx     ;eax=ecx*0x100
	add esi,eax

	ret





;*********************************************************************
;ListControlKeydown
;controls list scrolling and movement of the selection bar
;you must call getc prior to this function then mov bl,al

;this function is now incorporated into getc
;do not call this function directly in your app

;input:al=ascii keypress 
;      UP or DOWN scrolls the list
;      "u" or "d" or "CTRL+UP" or "CTRL+DOWN" moves the selection bar
;return:none
;*********************************************************************

ListControlKeydown:

	push eax
	push ebx
	push edx


	;for debug
	;STDCALL list_str1,dumpstr


	cmp dword [list_QtyStrings],0
	jz near .done


	;this list control only responds to UP/DN arrow keys
	cmp al,UP
	jz .doUParrow
	cmp al,DOWN
	jz .doDOWNarrow
	cmp al,HOME
	jz near .doHOME
	cmp al,END
	jz near .doEND
	jmp .done



.doUParrow:

	;check is selection bar is already at the top
	mov eax,[list_Ytop]
	cmp dword [list_YLoc_SelectionBar],eax
	jz .ScrollListDOWN

	;move the selection bar up 
	mov eax,LISTSPACING
	sub dword [list_YLoc_SelectionBar],eax
	jmp near .done


.ScrollListDOWN:

	;the selection bar is at the top so we scroll list down
	cmp dword [list_IndexFirstString],0 ;prevent scrolling list down past 0
	jz near .done
	dec dword [list_IndexFirstString]
	jmp .done




.doDOWNarrow:

	;check if selection bar is already at the bottom of list control
	mov eax,[list_YLastString]
	cmp dword [list_YLoc_SelectionBar],eax
	jz .ScrollListUP

	;the selection bar is not at the bottom of the list control
	;for a list shorter than 15 strings
	;prevent the selection bar from being moved to whitespace below the list
	mov eax,[list_QtyStrings]
	sub eax,[list_IndexFirstString]
	dec eax
	shl eax,4  ;eax*16
	add eax,[list_Ytop]  ;eax=Yloc in pixels of the last item down to be selected
	cmp eax,[list_YLoc_SelectionBar]
	jz .done
	;move the selection bar down
	mov eax,LISTSPACING
	add dword [list_YLoc_SelectionBar],eax
	jmp .done

.ScrollListUP:

	;the list is scrolled up only if the last item of the list
	;is currently below the visible border of the list control
	mov eax,[list_QtyStrings]
	sub eax,[list_IndexFirstString]
	sub eax,1
	shl eax,4    ;eax*16
	add eax,[list_Ytop]
	;now eax holds the Ypixel location of the last list string
	cmp eax,[list_YLastString]
	jbe .done  ;dont scroll 

	;the selection bar is at the bottom so we scroll list up
	inc dword [list_IndexFirstString]
	mov eax,[list_QtyStrings]
	jmp .done


.doEND:
	;we set the last string at the top of the list control
	;and the selection bar also at the top
	mov eax,[list_QtyStrings]
	dec eax
	mov [list_IndexFirstString],eax
	mov eax,[list_Ytop]
	mov [list_YLoc_SelectionBar],eax
	jmp .done


.doHOME:
	mov dword [list_IndexFirstString],0
	mov eax,[list_Ytop]
	mov [list_YLoc_SelectionBar],eax


.done:
	pop edx
	pop ebx
	pop eax
	ret



;********************************************************************
;ListControlPaint
;draw the list control
;the list control is of fixed size and location
;List Control defaults:
;each string is spaced 16 pixels vertically
;max qty strings that can be displayed = 15
;15 strings * 16 pixel spacing = 240 pixel tall List Control
;Ylocation of the last displayable string is (list_Ytop+240 - 16)
;you should leave at least 30 pixels below the list control for putmessage
;input:none
;return:none
;*******************************************************************

ListControlPaint:

	;draw list control background 
	push 0                 ;Xstart
	push dword [list_Ytop] ;Ystart
	push 800               ;width
	push 240               ;height
	push WHI               ;background color
	call fillrect


	;check if we have anything to draw
	cmp dword [list_QtyStrings],0
	jz near .done


	;init Yloc for first string
	mov ebx,[list_Ytop]


	;compute memory address of first string to be displayed
	mov eax,[list_IndexFirstString]   ;get index of first displayed string n=0,1,2,3
	mov edx,eax       ;edx used in drawing loop 
	shl eax,8         ;times 0x100
	add eax,0x2950000 ;eax=0x2950000 * eax*0x100

	

	;draw the selection bar as a gray rect 
	STDCALL 0,[list_YLoc_SelectionBar],800,LISTSPACING,LGR,fillrect




	;in this loop:
	;eax = address of string drawn
	;ebx = Y pixel location of string being drawn
	;edx = index of string drawn


.DrawListLoop:

	;draw the string
	STDCALL FONT01,0,ebx,eax,0xefff,puts

	;increment to address of next string to be displayed
	add eax,0x100

	;increment Yloc of string to be drawn
	add ebx,LISTSPACING

	;increment index of next string to be displayed
	inc edx

	;there are 2 ways to exit this loop

	;exit if we are at bottom of list drawable area
	cmp ebx,[list_Ybottom]
	jae .ComputeSelectedString

	;exit if we have drawn the last string before the bottom of the list control rect
	cmp edx,[list_QtyStrings] 
	jb .DrawListLoop
	;end of list drawing loop


.ComputeSelectedString:
	;compute the index of the selected list control string
	;list_IndexSelectedString = list_IndexFirstString + 
	;                           (list_YLoc_SelectionBar-list_Ytop)/LISTSPACING
	mov eax,[list_YLoc_SelectionBar]
	sub eax,[list_Ytop]
	shr eax,4   ;eax/16
	add eax,[list_IndexFirstString]
	mov [list_IndexSelectedString],eax  
	;return value from ListControlGetSelection

.done:
	ret




;*****************************************************
;ListControlSaveToFile
;saves the list items to file on your flash drive
;the 0 terminator of each string is replaced with NL 0xa
;written for FileManager to save a file listing
;input:none
;return:none
ListControlFileNamePrompt db 'Enter filename to save list control items',0
list_buffer dd 0
liststr01 db 'ListControlSaveToFile:',0
liststr02 db 'qty strings in list',0
;*****************************************************

ListControlSaveToFile:

	STDCALL liststr01,dumpstr
	mov eax,[list_QtyStrings]
	STDCALL liststr02,0,dumpeax


	;prompt user to enter filename and store at COMPROMTBUF
	push ListControlFileNamePrompt
	call fatgetfilename  
	jnz .done


	;compute the size of a buffer to hold all the strings
	xor edx,edx
	mov eax,[list_QtyStrings]
	mov ebx,80
	mul ebx  ;eax=qty bytes total all strings

	;alloc a text buffer, 80bytes per string
	mov ecx,eax
	call alloc  ;returns esi=address of buffer
	jz .done
	mov [list_buffer],esi


	;prepare for the string copy operation
	mov ecx,[list_QtyStrings]
	mov edi,[list_buffer]
	mov esi,0x2950000  ;start of list control strings

.listFillBuffer:

	;copy strings to our buffer and change 0 terminator to NL
	push esi  ;save for later increment by 0x100
	call strcpy   

	;overwrite 0 terminator with NL
	mov byte [edi],NL
	inc edi  ;so the next list item doesnt overwrite or NL

	;get start of next list control string
	pop esi
	add esi,0x100

	loop .listFillBuffer

	;note the  newly created file is not included in this list
	;because the file is written below, dah !


	;now write the file
	push dword [list_buffer]
	;compute filesize
	sub edi,[list_buffer]
	push edi
	call fatwritefile ;returns eax=0 on success, nonzero on error


	;free the buffer
	mov esi,[list_buffer]
	call free

.done:
	ret



;**********************************************************
;ListControlAddStrings
;this function is meant for userland only
;kernel may write strings to the list control buffer directly

;copies an array of strings to the list control buffer
;each string must be 0 terminated and no more than 80 char
;strings in excess of 80 char will be truncated with 0 terminator

;since this function may be called by userland
;we test each address before doing strcpy
;if an invalid address is found we set
;list control qty strings = 0 and the list control is painted
;plain white (empty)

;input:ebx=address of array of 0 terminated strings
;      ecx=qty strings 
;      edx=Ylocation of list control
;return:none
;**********************************************************

ListControlAddStrings:

	;save for now and maybe modify later
	mov [list_QtyStrings],ecx
	mov [list_Ytop],edx


	;zero out the list control buffer
	mov edi,0x2950000
	mov ecx,0x50000
	mov al,0
	call memset


	;init destination address
	mov edi,0x2950000


	;set loop counter
	mov ecx,[list_QtyStrings]

.1: 
	;in this loop ebx, ecx, edi must be preserved

	;get next source string address
	mov esi,[ebx]

	;check if this is a valid ptr, if not we bail
	push esi
	call ValidateUserAddress
	jc .error

	;copy the string to list control buffer, at most 80 char & 0 term
	call strcpy80

	;inc dest address
	add edi,0x100

	;inc source address
	add ebx,4

	loop .1

	jmp .done


.error:
	;if user passes us an invalid string address
	;the list control will be empty
	mov dword [list_QtyStrings],0
.done:
	mov eax,[list_QtyStrings]
	mov ebx,[list_Ytop]
	call ListControlInit
	ret


