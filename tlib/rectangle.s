;tatOS/tlib/rectangle.s


;rectangle
;fillrect

;****************************************************************
;rectangle
;draws an unfilled rectangular box 1 pixel wide

;if YORIENT=1 then x,y is the upper left corner of the rect
;the rect is drawn to the right and down

;if YORIENT=-1 then x,y is the lower left corner of the rect
;the rect is drawn to the right and up

;input
;push x        [ebp+24]
;push y        [ebp+20]
;push width    [ebp+16]
;push height   [ebp+12]
;push color    [ebp+8]
;****************************************************************

rectangle:

	push ebp
	mov ebp,esp
	pushad

	;crash protection, width & height must not be neg or 0
	cmp dword [ebp+16],0
	jle .done
	cmp dword [ebp+12],0
	jle .done

	;top 
	mov ebx,[ebp+24] ;x
	mov ecx,[ebp+20] ;y
	mov edx,[ebp+16] ;length
	mov esi,[ebp+8]  ;color
	call hline

	;bottom 
	mov ebx,[ebp+24] ;x
	mov ecx,[ebp+20] 
	add ecx,[ebp+12] ;y
	mov edx,[ebp+16] ;length
	mov esi,[ebp+8]  ;color
	call hline

	;left side
	mov ebx,[ebp+24] ;x
	mov ecx,[ebp+20] ;y
	mov edx,[ebp+12] ;length
	mov esi,[ebp+8]  ;color
	call vline

	;right side
	mov ebx,[ebp+24] 
	add ebx,[ebp+16] ;x
	mov ecx,[ebp+20] ;y
	mov edx,[ebp+12] ;length
	mov esi,[ebp+8]  ;color
	call vline

.done:
	popad
	pop ebp
	retn 20
	



;***********************************
;fillrect
;draws a filled box
;input
;push x upper left     [ebp+24]
;push y                [ebp+20]
;push width            [ebp+16]
;push height           [ebp+12]
;push color            [ebp+8]
;STDCALL x,y,w,y,RED,fillrect
;**********************************

fillrect:

	push ebp
	mov ebp,esp
	pushad

	push dword [ebp+24]
	push dword [ebp+20]
	call getpixadd
	;edi=address of pixel at upper left corner

	mov edx,[BPSL] ;bytesperscanline
	sub edx,[ebp+16]  
	;edx now holds qty bytes to advance video buffer to next row

	mov eax,[ebp+8]  ;color to al
	mov ebx,[ebp+16] ;width
	mov ecx,ebx      ;needed by stosb
	mov esi,[ebp+12] ;height
	cld              ;inc

.setpixels:	
	rep stosb   ;al->edi ecx times (set entire row of pixels)
	dec esi     ;one less row
	jz .done
	add edi,edx ;increment video buffer to next row
	mov ecx,ebx ;rep destroys ecx so restore for next row
	jmp .setpixels

.done:	
	popad
	pop ebp
	retn 20




