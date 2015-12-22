;tatOS/tlib/pointer.s

;routines to draw a software mouse pointer/cursor
;apps are responsible for drawing the pointer
;at the end of their paint routine
;call crosspointer or arrowpointer
;dont forget to call swapbuf to make it show up
;all these pointer routines use MOUSEX,MOUSEY 
;which is maintained by tatOS/usb/mouseinterrupt.s for the usb mouse


;*******************************************
;crosspointer
;draw the mouse pointer/cursor 
;its a simple cross 16x16 pixels
;color RED so its visible on either a 
;WHI or BLA or CYA background
;the point MOUSEX,MOUSEY
;is at the intersection

;input:none
;return:none
;********************************************

crosspointer:

	push dword [MOUSEX]
	push dword [MOUSEY]
	call getpixadd
	push edi     ;save

	;horizontal line
	sub edi,8    ;backup 8 pixels in the row
	mov al,RED   ;color
	mov ecx,16   ;set 16 pixels
	cld          ;inc
	rep stosb    ;al->edi

	;vertical line
	mov ebp,[BPSL] ;ebp=qty bytes to advance to next row
	mov ebx,ebp
	shl ebx,3      ;ebx = qty bytes to advance 8 rows
	pop edi      
	sub edi,ebx    ;edi=address at top of vert line
	mov ecx,16     ;qty vert pixels to set
	mov al,RED  
	cld            ;inc
.Vline3:
	mov [edi],al  
	add edi,ebp
	loop .Vline3

	ret



;**********************************************
;arrowpointer
;this is your standard arrow pointer
;black border, white interior
;width=12, height=21
;the hot spot is the very first byte
;input: none
;**********************************************

arrowpointer:

	push dword [MOUSEX]  ;xstart
	push dword [MOUSEY]  ;ystart
	push 12              ;width
	push 21              ;height
	push _arrowpointerbits
	call puttransbits
	ret




_arrowpointerbits:
db 239,255,255,255,255,255,255,255,255,255,255,255
db 239,239,255,255,255,255,255,255,255,255,255,255
db 239,254,239,255,255,255,255,255,255,255,255,255
db 239,254,254,239,255,255,255,255,255,255,255,255
db 239,254,254,254,239,255,255,255,255,255,255,255
db 239,254,254,254,254,239,255,255,255,255,255,255
db 239,254,254,254,254,254,239,255,255,255,255,255
db 239,254,254,254,254,254,254,239,255,255,255,255
db 239,254,254,254,254,254,254,254,239,255,255,255
db 239,254,254,254,254,254,254,254,254,239,255,255
db 239,254,254,254,254,254,254,254,254,254,239,255
db 239,254,254,254,254,254,254,239,239,239,239,239
db 239,254,254,254,239,254,254,239,255,255,255,255
db 239,254,254,239,239,254,254,239,255,255,255,255
db 239,254,239,255,255,239,254,254,239,255,255,255
db 239,239,255,255,255,239,254,254,239,255,255,255
db 239,255,255,255,255,255,239,254,254,239,255,255
db 255,255,255,255,255,255,239,254,254,239,255,255
db 255,255,255,255,255,255,255,239,254,254,239,255
db 255,255,255,255,255,255,255,239,254,254,239,255
db 255,255,255,255,255,255,255,255,239,239,255,255
 



