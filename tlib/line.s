;tatOS/tlib/line.s

;various functions to draw lines
;hline, vline, line, polyline, linepolar





;****************************************************
;hline
;draws a solid horizontal line 1 pixel wide
;the line is drawn "right" from start
; +------->

;input:
;ebx = xstart 
;ecx = ystart 
;edx = length,pixels 
;esi = color index (0-255)

;return:none
;***************************************************

hline:

	pushad
	
	push ebx   ;x
	push ecx   ;y
	call getpixadd
	;returns edi=address of starting pixel

	cld          ;increment
	mov eax,esi  ;al=color
	mov ecx,edx  ;num bytes to set
	rep stosb    ;al->edi set entire row of pixels

	popad
	ret





;***************************************************
;vline
;draws a a solid vertical line 1 pixel wide
;from the start point to a more + Y value
;for normal drawing the line is draw "down" from start
;   +
;   |
;   |
;   V
;if YORIENT=-1 then the line is drawn up

;input:
;ebx = xstart 
;ecx = ystart 
;edx = length,pixels 
;esi = color index (0-255)
;***************************************************

vline:

	pushad

	push ebx   ;x
	push ecx   ;y
	call getpixadd ;returns edi=start of BACKBUF or private pixel array

	push edx             ;preserve because mul destroys edx
	mov eax,[videobufferwidth] 
	mul dword [YORIENT]  ;1 for topdown, -1 for bottomup
	mov ebp,eax          ;num bytes to jmp up/dn to next line
	pop ecx              ;length of line in ecx

	cld          ;increment
	mov eax,esi  ;color to al

.1:	mov [edi],al ;set pixel 
	add edi,ebp  ;jump down/up to next row 
	loop .1

	popad
	ret










;*********************************************************
;polyline
;input
;push 1=Close, 0=Open           [ebp+24]
;push linetype                  [ebp+20]
;push address of points array   [ebp+16]
;push qty points/vertices       [ebp+12]
;push color                     [ebp+8]

;a "point" or vertex consists of a dword X and dword Y coordinate
;each point takes up 2 dwords in memory

;the points or vertices are stored in memory as
;x1,y1,x2,y2,x3,y3...
;the line is drawn from 1->2->3...

;if you push 1=Close then a line is drawn from the last point
;to the first
polystr1 db 'polyline open-close',0
;*********************************************************

polyline:

	push ebp
	mov ebp,esp
	pushad

	mov eax,[ebp+24]
	STDCALL polystr1,0,dumpeax

	;the number of lines is 1 less than qty points
	;if we dont join the start and end points with a line
	mov ecx,[ebp+12]
	dec ecx

	mov edi,[ebp+16]  ;edi=address of points array
	mov ebx,edi       ;save for later

	;debug: draw a marker around the first endpoint
	;STDCALL 1,WHI,[edi],[edi+4],putmarker

	;debug: draw a marker around the 2nd endpoint
	;add edi,8
	;STDCALL 1,BLU,[edi],[edi+4],putmarker
	;sub edi,8

	;debug: draw a marker around the last endpoint
	;push edi
	;lea edi,[edi+ecx*8]
	;STDCALL 1,RED,[edi],[edi+4],putmarker
	;pop edi



.drawpoly:
	push dword [ebp+20] ;linetype
	push dword [edi]    ;x1
	push dword [edi+4]  ;y1
	push dword [edi+8]  ;x2
	push dword [edi+12] ;y2
	push dword [ebp+8]  ;color
	call line
	add edi,8
	loop .drawpoly



	;Draw a final line to close the loop
	cmp dword [ebp+24],0
	jz .doneClose
	sub edi,8
	push dword [ebp+20] ;linetype
	push dword [edi+8]  ;x1 of last point
	push dword [edi+12] ;y1
	push dword [ebx]    ;x2 of first point
	push dword [ebx+4]  ;y2
	push dword [ebp+8]  ;color
	call line
.doneClose:

.done:
	popad
	pop ebp
	retn 20




;****************************************************
;linepolar
;draws a straight line using polar coordinates

;input
;push linetype             [ebp+28]
;push xstart               [ebp+24]
;push ystart               [ebp+20]
;push radius,pixels        [ebp+16]
;push angle,deg            [ebp+12]
;push colorIndex (0-0xff)  [ebp+8]
;**************************************************

linepolar:

	push ebp
	mov ebp,esp

	STDCALL [ebp+16],[ebp+12],polar2rect
	add ebx,[ebp+24]
	add eax,[ebp+20]
	STDCALL [ebp+28],[ebp+24],[ebp+20],ebx,eax,[ebp+8],line

	pop ebp
	retn 24








;**************************************************
;line  
;draws a line 1 pixel wide
;the line may be solid or any bit pattern you choose
;ref: GraphicsGems, DigitalLine.c by Paul S. Heckbert
;this is bresenham's algorithm from 1965. 

;input (6 args)
;push linetype             [ebp+28]    (this is a new argument)
;push x1                   [ebp+24]    ;dword int
;push y1                   [ebp+20]
;push x2                   [ebp+16]
;push y2                   [ebp+12]
;push colorIndex (0-0xff)  [ebp+8]

;return:none

;the linetype is a dword representing a repeating bit pattern
;the pixel is set if bit31=1 else skipped if 0
;here are the std linetypes or you can make your own:

;for a solid line,  linetype = 0xffffffff
;.............................

;for a centerline,  linetype = 0xffffe1f0
;19set + 4not + 5set + 4not
;...................    .....    

;for a hiddenline,  linetype = 0xffc0ffc0
;10set + 6not + 10set + 6not
;..........      ..........      

;for a phantomline, linetype = 0xfff0f0f0
;12set + 4not + 4set + 4not + 4set + 4not
;............    ....    ....

;for a dotline,     linetype = 0xc2108420
;2set + 4not + (1set + 4not) ... + 1set + 5not
;..    .    .    .    .    .    .    .    .

;tatos.inc & ttasm have defines for these std line types:
;SOLIDLINE, CENTERLINE, HIDDENLINE, PHANTOMLINE, DOTLINE

;local variables
line_SY dd 0  ;sign of y, 1 or -1
line_SX dd 0
line_AY dd 0
line_AX dd 0
line_BufferWidth dd 0
linestr1 db 'line:x or y value out of range or zero length line',0
;*************************************************************

line:

	push ebp
	mov ebp,esp
	pushad


	;crash protection for drawing to 800x600 pixel screen
	;if x is outside the range 0-799 or y is outside the range 0-599
	;this code will continue to write to memory outside the video back buffer
	;and bring tatOS to its knees !!!!!!!!!!
	;also this code will have to be updated for private pixel buffers

	;make sure line length != 0
	mov eax,[ebp+24]  ;x1
	cmp eax,[ebp+16]  
	jnz .notzerolength
	mov ebx,[ebp+20]  ;y1
	cmp ebx,[ebp+12]
	jz near .error
.notzerolength:

	;make sure x1 is within range 0-799
	cmp dword [ebp+24],0
	setge bl
	cmp dword [ebp+24],799
	setle bh
	add bl,bh
	cmp bl,2
	jnz near .error

	;make sure x2 is within range 0-799
	cmp dword [ebp+16],0
	setge bl
	cmp dword [ebp+16],799
	setle bh
	add bl,bh
	cmp bl,2
	jnz near .error

	;make sure y1 is within range 0-599
	cmp dword [ebp+20],0
	setge bl
	cmp dword [ebp+20],599
	setle bh
	add bl,bh
	cmp bl,2
	jnz near .error

	;make sure y2 is within range 0-599
	cmp dword [ebp+12],0
	setge bl
	cmp dword [ebp+12],599
	setle bh
	add bl,bh
	cmp bl,2
	jnz near .error
	


	;now get on with the business of drawing a line

	;get address of starting pixel in edi
	push dword [ebp+24]  ;x1
	push dword [ebp+20]  ;y1
	call getpixadd ;returns edi=start of x1,y1 in BACKBUF or private pixel array


	;compute dx,SX,AX 
	mov eax,[ebp+16]  ;x2
	sub eax,[ebp+24]  ;dx=x2-x1
	push eax
	call sign
	mov [line_SX],eax ;sx=sign(dx)  1 or -1
	pop eax
	call absval   ;eax=|eax|
	mov [line_AX],eax

	
	;compute dy,SY,AY 
	mov eax,[ebp+12]  ;y2
	sub eax,[ebp+20]  ;dy=y2-y1
	push eax
	call sign
	mov [line_SY],eax ;sy=sign(dy)
	pop eax
	call absval    
	mov [line_AY],eax


	;compute (bytesperscanline * line_SY * YORIENT)
	mov eax,[videobufferwidth]
	mul dword [line_SY]  ;times 1 or -1
	mul dword [YORIENT]  ;times 1 or -1
	mov [line_BufferWidth],eax
	;now we have amount to inc pixel address to next or previous line
	


	;put color in dl
	mov edx,[ebp+8]

	;put linetype bit pattern in ebx
	mov ebx,[ebp+28]

	;are we moving mostly horiz or vert ? 
	mov ecx,[line_AX]
	cmp ecx,[line_AY]
	js .MostlyVertical


;**************************************
;mostly Horiz and a little Down or UP
;**************************************

.MostlyHorizontal:

	;initialize d error term and loop counter
	shl dword [line_AY],1  ;times 2
	mov esi,[line_AY]
	mov ecx,[line_AX]      ;qty pixels to set
	sub esi,ecx            ;d=AY-(AX>>1)
	shl dword [line_AX],1  ;times 2
	

.drawLineH:
	
	;mask off all but bit31
	test ebx,10000000000000000000000000000000b	
	jz .doneSetPixelH

	mov [edi],dl    ;set pixel
.doneSetPixelH:

	;rotate the linetype bitmap
	rol ebx,1

            
	;check cumulative error term "d"  
	cmp esi,0
	jl .adjustX  


	;adjustY occasionally
	add edi,[line_BufferWidth]   ;move 1 row up or down
	sub esi,[line_AX]  ;d-=AX
		
		
.adjustX: 
	;with every interation
	add edi,[line_SX]           ;move 1 pixel right or left
	add esi,[line_AY]  ;d+=AY 
	loop .drawLineH


	jmp .done






;**************************************
;mostly Vert and a little Right or Left
;**************************************

.MostlyVertical:

	;initialize d error term and loop counter
	shl dword [line_AX],1  ;times 2
	mov esi,[line_AX]
	mov ecx,[line_AY]      ;qty pixels to set
	sub esi,ecx            ;d=AX-(AY>>1)
	shl dword [line_AY],1  ;times 2
	

.drawLineV:

	;mask off all but bit31
	test ebx,10000000000000000000000000000000b	
	jz .doneSetPixelV

	mov [edi],dl    ;set pixel
.doneSetPixelV:

	;rotate the linetype bitmap
	rol ebx,1


            
	;check cumulative error term "d"  
	cmp esi,0
	jl .adjustY 


	;adjustX occasionally
	add edi,[line_SX]            ;move 1 row right or left
	sub esi,[line_AY]            ;d-=AY
		
		
.adjustY: 
	;with every interation
	add edi,[line_BufferWidth]   ;move 1 row up or down 
	add esi,[line_AX]            ;d+=AX 
	loop .drawLineV

	jmp  .done


.error:
	;this can flood your dump so use for debug only
	;STDCALL linestr1,dumpstr
.done:
	popad
	pop ebp	
	retn 24 ;cleanup 6 args
	




