;tatOS/tlib/arc.s

;************************************************************
;arc
;draws a circular arc

;input: 
;ebp=Address of 32 byte ARC structure

;return: none


;32 byte ARC structure (8 dwords)
;*******************************************
;dword Xcenter                    [ebp]
;dword Ycenter                    [ebp+4]
;dword radius,pixels              [ebp+8]
;dword angle_start,deg (0-359)    [ebp+12]
;dword angle_end  ,deg (0-359)    [ebp+16]
;dword angle_inc                  [ebp+20]
;dword color index     (0-0xff)   [ebp+24]
;dword linetype                   [ebp+28]

;all the inputs are unsigned dwords
;the arc is drawn by computing x,y points along the arc
;at equal intervals of angle_inc and connecting the points
;with straight line segments. 
;use angle_inc=5 deg for a smooth looking arc
;if you are doing fast scrolling use angle_inc=30

;warning! angle_end must be greater than angle_start
;and both must be in the range +0->+359. See function
;normalizedeg in polar.s

;if YORIENT=1 and angle_start=0 and angle_end=180
;this draws a smile (holds water)
;if YORIENT=-1 and angle_start=0 and angle_end=180
;this draws a hill or frown (doesnt hold water)
;*************************************************************

arc:
	pushad

	;get the radius
	mov ecx,[ebp+8]

	;set the starting angle
	mov edx,[ebp+12]

	;get x,y start of first line segment
	push ecx
	push edx
	call polar2rect
	;returns ebx=x, eax=y
	;we reserve esi and edi to store x,y for start point
	mov esi,ebx       ;esi=x_start
	mov edi,eax       ;edi=y_start
	add esi,[ebp]    ;+xc
	add edi,[ebp+4]  ;+yc

	;increment angle for end point of first segment
	add edx,[ebp+20]

.arc_drawing_loop:

	;get x,y for the segment end point
	push ecx
	push edx
	call polar2rect
	add ebx,[ebp]   ;+xc
	add eax,[ebp+4] ;+yc

	;draw the line segment
	push dword [ebp+28] ;linetype
	push dword esi      ;x1
	push dword edi      ;y1
	push ebx            ;x2
	push eax            ;y2
	push dword [ebp+24] ;color 
	call line

	;save the end point as the start point
	mov esi,ebx
	mov edi,eax

	;increment angle
	add edx,[ebp+20]

	;are we past angle end ?
	cmp edx,[ebp+16]
	jb .arc_drawing_loop


	;the last segment drawn is short
	push ecx
	mov edx,[ebp+16] ;ending angle
	push edx
	call polar2rect
	add ebx,[ebp]   ;+xc
	add eax,[ebp+4] ;+yc


	;draw the line segment
	push dword [ebp+28] ;linetype
	push dword esi
	push dword edi
	push ebx
	push eax
	push dword [ebp+24]
	call line

.done:
	popad
	ret 


