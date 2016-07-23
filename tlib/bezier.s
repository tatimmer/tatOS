;tatOS/tlib/bezier.s


;bezier
;bez2pdf


;code to draw a bezier curve with line segments of evenly spaced 't'
;its fast but less accurate than setting every pixel along the curve
;no allowance to adjust 't' spacing in areas of hi gradient


;Acoef = (1-t)^3
;Bcoef = 3t(1-t)^2
;Ccoef = 3t^2(1-t)
;Dcoef = t^3
;for t=0->1.0 in steps of .1 

;to draw a cubic bezier with 20 line segments we need to precompute these coeffecients
;at 21 points.
;the first segment is drawn from t=0 to t=.05
;the next segment is drawn from t=.05 to t=.10  and so forth
;note how A and D are related 
;D is the reverse order of A and C is the reverse order of B

bez_Acoef:
;t=  0      .05     .1      .15     .2      .25     .3      .35     .4      .45     .5     
dq 1.0,    0.8574, 0.729,  0.6141, 0.512,  0.4219, 0.343,  0.2746, 0.216,  0.1664, 0.125, 
;t= .55     .6      .65     .7      .75     .8      .85     .9      .95    1.0
dq 0.0911, 0.064,  0.0429, 0.027,  0.0156, 0.008,  0.0034, 0.001,  0.0001, 0.0

bez_Bcoef:
dq 0.0,    0.1354, 0.243,  0.3251, 0.384,  0.4219, 0.441,  0.4436, 0.432,  0.4084, 0.375, 
dq 0.3341, 0.288,  0.2389, 0.189,  0.1406, 0.096,  0.0574, 0.027,  0.0071, 0.0

bez_Ccoef:
dq 0.0,    0.0071, 0.027,  0.0574, 0.096,  0.1406, 0.189,  0.2389, 0.288,  0.3341, 0.375, 
dq 0.4084, 0.432,  0.4436, 0.441,  0.4219, 0.384,  0.3251, 0.243,  0.1354, 0.0

bez_Dcoef:
dq 0.0,    0.0001, 0.001,  0.0034, 0.008,  0.0156, 0.027,  0.0429, 0.064,  0.0911, 0.125
dq 0.1664, 0.216,  0.2746, 0.343,  0.4219, 0.512,  0.6141, 0.729,  0.8574, 1.0

bez_startX dd 0
bez_startY dd 0
bez_endX   dd 0
bez_endY   dd 0

%define QTYBEZIERSEGMENTS 20


;x(t) = Acoef*x1 + Bcoef*x2 + Ccoef*x3 + Dcoef*x4
;y(t) = Acoef*y1 + Bcoef*y2 + Ccoef*y3 + Dcoef*y4

;where:
;x1,y1 are the start point
;x2,y2 is the 1st control point
;x3,y3 is the 2nd control point
;x4,y4 is the end point



;**************************************************
;bezier

;draws a cubic bezier curve with line segments

;all the x,y coordinates must be input as 
;dword screen coordinates
;x1,y1 and x4,y4 are the end points
;x2,y2 and x3,y3 are the control points

;input: 
;push linetype                 [ebp+16]  see line.s 
;push Address of points array  [ebp+12]  x1,y1,x2,y2,x3,y3,x4,y4 all dwords 32 bytes
;push colorIndex (0-0xff)      [ebp+8]   see palette.s

;return:
;**************************************************

bezier:

	push ebp
	mov ebp,esp


	;we use esi to access the x,y point coordinates
	;esi must be preserved
	mov esi,[ebp+12]
	;esi    x1
	;esi+4  y1
	;esi+8  x2
	;esi+12 y2
	;esi+16 x3
	;esi+20 y3
	;esi+24 x4
	;esi+28 y4


		
	;we know x,y at t=0 for the first segment, the user gave us this
	mov eax,[esi]         ;x
	mov [bez_startX],eax
	mov ebx,[esi+4]       ;y
	mov [bez_startY],ebx

	

	;init our loop counter
	mov ecx,1   ;corresponds to t=0.1


	;now loop to compute x,y from t=.05 thru t=1.0

.1:

	;load coeffecients to compute the end point of the current segment to be drawn
	fld qword [bez_Acoef + 8*ecx]    ;st0=Acoef
	fld qword [bez_Bcoef + 8*ecx]    ;st0=Bcoef, st1=Acoef
	fld qword [bez_Ccoef + 8*ecx]    ;st0=Ccoef, st1=Bcoef, st2=Acoef
	fld qword [bez_Dcoef + 8*ecx]    ;st0=Dcoef, st1=Ccoef, st2=Bcoef, st3=Acoef
	;compute x end
	fild dword [esi]                 ;st0=x1, st1=D, st2=C, st3=B, st4=A
	fmul st4                         ;st0=A*x1, st1=D, st2=C, st3=B, st4=A
	fild dword [esi+8]               ;st0=x2, st1=A*x1, st2=D, st3=C, st4=B, st5=A
	fmul st4                         ;st0=B*x2, st1=A*x1, st2=D, st3=C, st4=B, st5=A
	faddp st1                        ;st0=A*x1+B*x2, st1=D, st2=C, st3=B, st4=A
	fild dword [esi+16]              ;st0=x3, st1=A*x1+B*x2, st2=D, st3=C, st4=B, st5=A
	fmul st3                         ;st0=C*x3, st1=..., st2=D, st3=C, st4=B, st5=A
	faddp st1                        ;st0=A*x1+B*x2+C*x3, st1=D, st2=C, st3=B, st4=A
	fild dword [esi+24]              ;st0=x4, st1=..., st2=D, st3=C, st4=B, st5=A
	fmul st2                         ;st0=D*x4, st1=..., st2=D, st3=C, st4=B, st5=A
	faddp st1                        ;st0=A*x1+B*x2+C*x3+D*x4, st1=D, st2=C, st3=B, st4=A
	fistp dword [bez_endX]           ;save x @ t=1, st0=D, st1=C, st2=B, st3=A
	;compute y end
	fild dword [esi+4]               ;st0=y1, st1=D, st2=C, st3=B, st4=A
	fmul st4                         ;st0=A*y1, st1=D, st2=C, st3=B, st4=A
	fild dword [esi+12]              ;st0=y2, st1=A*y1, st2=D, st3=C, st4=B, st5=A
	fmul st4                         ;st0=B*y2, st1=A*y1, st2=D, st3=C, st4=B, st5=A
	faddp st1                        ;st0=A*y1+B*y2, st1=D, st2=C, st4=B, st5=A
	fild dword [esi+20]              ;st0=y3, st1=A*y1+B*y2, st2=D, st3=C, st4=B, st5=A
	fmul st3                         ;st0=C*y3, st1=..., st2=D, st3=C, st4=B, st5=A
	faddp st1                        ;st0=A*y1+B*y2+C*y3, st1=D, st2=C, st4=B, st5=A
	fild dword [esi+28]              ;st0=y4, st1=..., st2=D, st3=C, st4=B, st5=A
	fmul st2                         ;st0=D*y4, st1=..., st2=D, st3=C, st4=B, st5=A
	faddp st1                        ;st0=A*y1+B*y2+C*y3+D*y4, st1=D, st2=C, st4=B, st5=A
	fistp dword [bez_endY]           ;save y @ t=1, st0=D, st1=C, st2=B, st3=A
	;draw the line 
	push dword [ebp+16]     ;linetype
	push dword [bez_startX] ;x1
	push dword [bez_startY] ;y1
	push dword [bez_endX]   ;x2
	push dword [bez_endY]   ;y2
	push dword [ebp+8]      ;color 
	call line
	;free the fpu
	ffree st0
	ffree st1
	ffree st2
	ffree st3


	;copy the ending x,y to the start
	mov eax,[bez_endX]
	mov [bez_startX],eax
	mov ebx,[bez_endY]
	mov [bez_startY],ebx


	;inc loop counter
	add ecx,1

	cmp ecx,QTYBEZIERSEGMENTS
	jbe .1
	
.done:
	pop ebp
	retn 12








;***************************************************************
;bez2pdf

;this function will write 3 ascii strings
;which define a cubic bezier curve in a pdf file:

;x1 y1 m  
;x2 y2 x3 y3 x4 y4 c
;S

;m = MoveTo operator
;c = CurveTo operator
;S = stroke operator

;all x,y coordinates are dword unclipped screen coordinates 
;x1y1 is the start point
;x2y2 and x3y3 are the control points
;x4y4 is the end point

;input: push dword destination buffer to write pdf strings [ebp+12]
;       push dword address of x1,y1,x2,y2,x3,y3,x4,y4      [ebp+8]

;return:
;       3 ascii strings are written to the destination buffer
;       edi = holds address of end of buffer for subsequent writes
;***************************************************************

bez2pdf:

	push ebp
	mov ebp,esp

	mov edi,[ebp+12]  ;address of pdf buffer
	mov esi,[ebp+8]   ;address of bezier points	


	;x1 y1 m
	;*********

	;write x1
	mov eax,[esi]  ;x1
	push edi       ;dest buffer
	push 0         ;unsigned
	push 0         ;0 terminate
	call eax2dec

	;edi is incremented to address of 0 terminator which gets 
	;overwritten by the next space

	;write a space
	mov byte [edi],0x20
	inc edi


	;write y1
	mov eax,[esi+4]  ;y1
	push edi         ;dest buffer
	push 0           ;unsigned
	push 0           ;0 terminate
	call eax2dec

	;write a space
	mov byte [edi],0x20
	inc edi

	;write the 'm'
	mov byte [edi],'m'
	inc edi

	;write end of line
	mov byte [edi],0xa
	inc edi
	



	;x2 y2 x3 y3 x4 y4 c
	;*********************

	;write x2
	mov eax,[esi+8]  ;x2
	push edi         ;dest buffer
	push 0           ;unsigned
	push 0           ;0 terminate
	call eax2dec

	;write a space
	mov byte [edi],0x20
	inc edi

	;write y2
	mov eax,[esi+12] ;y2
	push edi         ;dest buffer
	push 0           ;unsigned
	push 0           ;0 terminate
	call eax2dec

	;write a space
	mov byte [edi],0x20
	inc edi

	;write x3
	mov eax,[esi+16] ;x3
	push edi         ;dest buffer
	push 0           ;unsigned
	push 0           ;0 terminate
	call eax2dec

	;write a space
	mov byte [edi],0x20
	inc edi

	;write y3
	mov eax,[esi+20] ;y3
	push edi         ;dest buffer
	push 0           ;unsigned
	push 0           ;0 terminate
	call eax2dec

	;write a space
	mov byte [edi],0x20
	inc edi

	;write x4
	mov eax,[esi+24] ;x4
	push edi         ;dest buffer
	push 0           ;unsigned
	push 0           ;0 terminate
	call eax2dec

	;write a space
	mov byte [edi],0x20
	inc edi

	;write y4
	mov eax,[esi+28] ;y4
	push edi         ;dest buffer
	push 0           ;unsigned
	push 0           ;0 terminate
	call eax2dec

	;write a space
	mov byte [edi],0x20
	inc edi

	;write the 'c'
	mov byte [edi],'c'
	inc edi

	;write end of line
	mov byte [edi],0xa
	inc edi

	;write the "Stroke" operator upper case S to make it show up
	mov byte [edi],'S'
	inc edi

	;write end of line
	mov byte [edi],0xa
	inc edi

	
.done:

	mov eax,edi   ;return address of next byte to be written to pdf graphic stream
	pop ebp
	retn 8









