;tatOS/tlib/gets.s


;***********************************************************
;gets
;single line edit control

;input:
;ebx = xstart 
;eax = ystart 
;ecx = maxnumchars (1-80)
;edi = address of char buffer to store string (size=ecx+1)
;edx = colors, (00ccbbtt) cc=caret, bb=background, tt=text

;return:
;the function exits on ESCAPE or ENTER
;set   zf on success with ENTER key
;clear zf on failure with ESCAPE key

;this is a single line edit control
;it is drawn at xstart,ystart and is ecx*10 pixels wide
;it allows you to modify an array of ascii chars with the keyboard
;this function uses the 8x15 bitmap font01 
;each char takes up 10 pixels wide and 15 high
;the edit box must fit all on 1 line: i.e. (ebx + ecx*10) < 800
;the calling program must alloc space for a buffer
;that is (ecx+1) chars long, 1 is for the 0 terminator
;and pass the address of the buffer in edi

;if the first char of the buffer pointed to by edi is not 0
;then gets.s will initially display the string
;the remainder of the buffer will be filled with SPACE initially
;each DELETE or BKSPACE appends a SPACE
;apon ENTER a 0 will be placed after the first
;NON-SPACE char

;this version of gets uses the tlib double buffer
;it will only paint within its own rectangle 
;what ever else is on the screen will not be affected
;it checks for keypresses using getc

;this code does not use a gap buffer
;we just split the array at the cursor and slide everything down

;WARNING!
;max sure the buffer pointed to by edi is plenty big
;it is a common problem the dreaded "buffer overflow"
;where you overwrite the buffer and in the process
;wipe out some code. this can be a nasty problem in a 
;flat binary environment where code and data are mixed.
;usually what happens is the code works correctly only the
;first time then after that you get interrupt invalid opcode.

;colors:     caret color   background color   text color
;0x00fbffef  light red     transparent        black 
;0x00fbfeef  light red     white              black 
;0x00fbfdef  light red     yellow             black (same as comprompt)

;locals
_startaddress dd 0  ;starting address of string buffer
_endaddress dd 0    ;startaddress+maxnumchars-1 
_caretaddress dd 0  ;address of byte at caret
_xstart dd 0
_ystart dd 0
_width dd 0
_maxnumchars dd 0
_colortext db 0
_colorback db 0
_colorcaret db 0

;***********************************************************

gets:

	push ebx
	push ecx
	push edx
	push esi
	push edi
	push ebp

	;init local variables
	mov [_xstart],ebx
	mov [_ystart],eax
	mov [_maxnumchars],ecx
	mov [_startaddress],edi
	mov [_caretaddress],edi
	mov [_colortext],dl
	mov [_colorback],dh
	shr edx,16
	mov byte [_colorcaret],dl


	;width of edit line = ecx*10
	lea eax,[ecx*8 + ecx]
	add eax,ecx
	mov [_width],eax


	;end address 
	mov edx,[_startaddress]
	add edx,[_maxnumchars]
	dec edx
	mov [_endaddress],edx


	;append spaces to string buffer 
	mov eax,edi
	call strlen
	;returns len of string in ecx
	mov edx,[_maxnumchars]
	sub edx,ecx
	xchg edx,ecx
	;ecx=qty spaces to append
	mov edi,[_endaddress]
	sub edi,ecx
	inc edi
	;edi holds address of 0 terminator
	mov al,SPACE
	cld
	rep stosb
	



.gets_mainloop:


	;GETS PAINT
	;*************

	mov ebx,[_xstart]
	mov eax,[_ystart]
	mov ecx,[_width]
	movzx edx,byte [_colorback] 

	;draw a background rectangle
	STDCALL ebx,eax,ecx,15,edx,fillrect


	;prepare
	mov eax,[_startaddress]
	mov ebx,FONT01
	mov ecx,[_maxnumchars] 
	mov dh,[_colortext] 
	mov esi,[_xstart]
	mov edi,[_ystart]

.drawcharloop:

	;if this is caret set special bk color
	mov ebp,[_caretaddress]
	cmp eax,ebp
	jnz .notcaret
	mov dl,[_colorcaret]
	jmp .drawchar
.notcaret:

	;set std bk color of normal text
	mov dl,[_colorback]

	.drawchar:
	push ecx  ;save loop counter
	mov cl,[eax]
	;ebx=font, ecx=ascii char, edx=color, esi=xloc, edi=yloc
	call putc
	pop ecx

	;increment things
	add esi,10  ;inc x
	inc eax     ;address of next byte
	loop .drawcharloop
	

.swapbuf:
	call swapbuf
	;end paint




	;keypress
	;**********

	;block waiting for keypress
	;al contains ascii keypress
	;so dont use eax for anything else !!!
	call getc
	

	cmp al,ESCAPE
	jz .doEscape
	cmp al,ENTER
	jz .doEnter
	cmp al,HOME
	jz .doHome
	cmp al,END
	jz .doEnd
	cmp al,DELETE
	jz .doDelete
	cmp al,BKSPACE
	jz .doBackspace
	cmp al,LEFT
	jz near .doLeftArrow
	cmp al,RIGHT
	jz near .doRightArrow



	;filter out keys below ascii 0x20
	cmp al,0x20
	jb near .gets_mainloop


	;filter out above 0x80
	cmp al,0x80
	jae near .gets_mainloop



	;if we got here we have a valid keypress to save and 
	;display in the gets edit control
	jmp .InsertNewChar



.doEscape:
	mov ebx,[_endaddress]
	inc ebx
	mov byte [ebx],0  ;terminate
	add eax,1         ;clear zf on failure
	jmp near .done  

.doEnter:
	call zeroterminate	
	xor eax,eax  ;set zf
	jmp near .done  

.doHome:
	mov edx,[_startaddress]
	mov [_caretaddress],edx
	jmp near .gets_mainloop

.doEnd:
	mov ebx,[_endaddress]
	mov [_caretaddress],ebx
	jmp near .gets_mainloop
	
.doDelete:
	call getsdelete
	jmp near .gets_mainloop

.doBackspace:
	call getsbackspace
	jmp near .gets_mainloop

.doLeftArrow:
	;no affect if carrot is at 1st char
	mov edx,[_caretaddress]
	sub edx,[_startaddress]
	jz near .gets_mainloop
	dec dword [_caretaddress]
	jmp near .gets_mainloop

.doRightArrow:
	;are we at end of string ?
	mov edx,[_endaddress]
	sub edx,[_caretaddress]
	jz near .gets_mainloop
	inc dword [_caretaddress]
	jmp near .gets_mainloop




	
	;******************
	;insert new char
	;******************

.InsertNewChar:

	;qty bytes to move right
	mov ecx,[_endaddress]
	sub ecx,[_caretaddress]
	jnz .havebytes2slide
	;caret is at end of edit control
	mov edi,[_caretaddress]
	mov [edi],al
	jmp near .gets_mainloop
.havebytes2slide:
	

	;slide right all bytes from caret on down
	;start at end and work toward caret
	;this will always bump off the last char
	std          ;decrement
	mov edi,[_endaddress] ;dest
	mov esi,edi
	dec esi      ;source
	rep movsb    ;slide 


	;insert al at caret
	mov edi,[_caretaddress]
	mov [edi],al

	
	;increment 
	inc dword [_caretaddress]

	jmp near .gets_mainloop



.done:
	pop ebp
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	ret




;**************************
; subroutines for gets
;**************************



zeroterminate:
	;this code cut from comprompt.s
	;now start at the end and find the first non SPACE
	;and 0 terminate
	;for the benefit of getsubstr 
	;which requires a SPACE after every substring
	;we terminate this parent string with a SPACE,0
	mov edi,[_endaddress]
	mov ecx,[_maxnumchars]
	mov al,SPACE
	std   ;dec
	repe scasb  
	;repeat while SPACE dec edi
	inc edi
	inc edi
	mov byte [edi],0  
	cld    
	ret


	


getsdelete:

	;qty bytes right of caret to move left
	mov ecx,[_endaddress]
	sub ecx,[_caretaddress]
	cmp ecx,0
	jz .lastspace  ;deletelastchar

	;we must slide left all bytes right of the caret 	
	cld
	mov edi,[_caretaddress] ;caret is dest
	mov esi,edi
	inc esi       ;byte right of caret is source
	rep movsb     ;slide 

	;the last char gets a space
	.lastspace:
	mov edx,[_endaddress]
	mov byte [edx],SPACE

	ret



getsbackspace:

	;same as delete except 
	;the char b4 the carrot is removed
		
	;no affect if carrot is at 1st char
	mov edx,[_caretaddress]
	sub edx,[_startaddress]
	jz .done
		
	;qty bytes to move left
	mov edx,[_caretaddress]
	sub edx,[_startaddress]
	mov ecx,[_maxnumchars]
	sub ecx,edx

	;we must slide left all bytes starting at the caret 	
	cld
	mov esi,[_caretaddress] 
	mov edi,esi
	dec edi
	rep movsb       ;slide 

	;redefine caret
	dec dword [_caretaddress]
	
	;the last char gets a space
	mov edx,[_endaddress]
	mov byte [edx],SPACE

.done:
	ret



