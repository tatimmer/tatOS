;tatOS/tlib/geometry.s


;intersection, ptinrect, pointinrectfloat, ptonline
;mirrorpoint, RotatePoint, projectpointtoline
;chamfer, fillet, grid, rose, rotateline, offset
;inflaterect



;***************************************************************
;intersection
;find the intersection of 2 line segments
;the algorithm comes from comp.graphics.algorithms.FAQ
;all calcs and inputs are qword double prec floating point

;input:
;push address of qword vector x1,y1,x2,y2  [ebp+16]
;push address of qword vector x3,y3,x4,y4  [ebp+12]
;push address of 16 bytes of memory to     [ebp+8]
;     store qword intersection point x5,y5

;return: x5,y5 is written
;eax=0 lines intersect
;eax=2 lines are parallel and do not cross

;the intersection point may be real or virtual
;code to report if the intersection is virtual is not done yet
;in the future we will report this as eax=1
;virtual intersection requires one or both lines be extended
;to reach the intersection point

;local
inter_denom:
dq 0.0
inter_r:
dq 0.0
inter_s:
dq 0.0
;*****************************************************************

intersection:

	push ebp
	mov ebp,esp
	push ebx
	push esi
	push edi

	mov esi,[ebp+16]
	;x1=[esi]
	;y1=[esi+8]
	;x2=[esi+16]
	;y2=[esi+24]

	mov edi,[ebp+12]
	;x3=[edi]
	;y3=[edi+8]
	;x4=[edi+16]
	;y4=[edi+24]

	;compute denominator
	fld  qword [esi+16]    ;st0=x4
	fsub qword [esi]       ;st0=x2-x1
	fld  qword [edi+24]    ;st0=y4, st1=x2-x1
	fsub qword [edi+8]     ;st0=y4-y3, st1=x2-x1
	fmulp st1              ;st0=(y4-y3)(x2-x1)
	fld  qword [esi+24]    ;st0=y2, st1=...
	fsub qword [esi+8]     ;st0=y2-y1, st1=...
	fld  qword [edi+16]    ;st0=x4, st1=y2-y1, st2=...
	fsub qword [edi]       ;st0=x4-x3, st1=y2-y1, st2=(y4-y3)(x2-x1)
	fmulp st1              ;st0=(x4-x3)(y2-y1), st1=(y4-y3)(x2-x1)
	fsubr st1              ;st0=(y4-y3)(x3-x1) - (x4-x3)(y2-y1)= denom, st1=...
	fst qword [inter_denom]  
	ffree st1              ;st0=denom

	;test for lines are parallel
	fldz              ;st0=0.0, st1=denom
	fcomip st1        ;cmp 0.0 with denom
	jz near .parallel ;lines are parallel, no intersection
	ffree st0         ;cleanup from fcomip
	


	;compute r
	fld  qword [esi+8] 
	fsub qword [edi+8]         ;st0=y1-y3
	fld  qword [edi+16]        ;st0=x4, st1=y1-y3
	fsub qword [edi]           ;st0=x4-x3, st1=y1-y3
	fmulp st1                  ;st0=(x4-x3)(y1-y3)
	fld  qword [esi]           ;st0=x1, st1=(x4-x3)(y1-y3)
	fsub qword [edi]           ;st0=x1-x3, st1=(x4-x3)(y1-y3)
	fld  qword [edi+24]        ;st0=y4, st1=x1-x3, st2=(x4-x3)(y1-y3)
	fsub qword [edi+8]         ;st0=y4-y3, st1=x1-x3, st2=...
	fmulp st1                  ;st0=(y4-y3)(x1-x3), st1=(x4-x3)(y1-y3)
	fsubr st1                  ;(x4-x3)(y1-y3) - (y4-y3)(x1-x3), st1=...
	fdiv qword [inter_denom]   ;st0=r, st1=...
	fstp qword [inter_r] 
	ffree st0



	;we only need to do these calcs
	;if we are interested in reporting a virtual intersection
	;compute s
	;fld  qword [esi+8] 
	;fsub qword [edi+8]         ;st0=y1-y3
	;fld  qword [esi+16] 
	;fsub qword [esi]           ;st0=x2-x1, st1=y1-y3
	;fmulp st1                  ;st0=(x2-x1)(y1-y3)
	;fld  qword [esi] 
	;fsub qword [edi]           ;st0=x1-x3, st1=(x2-x1)(y1-y3)
	;fld  qword [esi+24] 
	;fsub qword [esi+8]         ;st0=y2-y1, st1=x1-x3, st2=...
	;fmulp st1                  ;st0=(y2-y1)(x1-x3), st1=(x2-x1)(y1-y3)
	;fsubr st1                  ;(x2-x1)(y1-y3) - (y2-y1)(x1-x3), st1=...
	;fdiv qword [inter_denom]   ;st0=s, st1=...
	;fstp qword [inter_s] 
	;ffree st0
	

	;compute the point of intersection
	mov ebx,[ebp+8]
	;x5=[ebx]
	;y5=[ebx+8]
	fld  qword [esi+16] 
	fsub qword [esi]        ;st0=x2-x1
	fmul qword [inter_r]    ;st0=r(x2-x1)
	fadd qword [esi]        ;st0=x5= x1 + r(x2-x1)
	;call [DUMPST0] to see the value of x5
	fstp qword [ebx]        ;save x5
	fld  qword [esi+24] 
	fsub qword [esi+8]      ;st0=y2-y1
	fmul qword [inter_r]    ;st0=r(y2-y1)
	fadd qword [esi+8]      ;st0=y5= y1 + r(y2-y1)
	;call [DUMPST0] to see the value of y5
	fstp qword [ebx+8]      ;save y5


	;report a valid intersection
	;lines are not parallel
	;the intersection may be real or virtual
	mov eax,0   


	;determine if intersection is virtual
	;code not done yet
	;if (r<0.0 or r>1.0) or (s<0.0 or s>1.0) then we have virtual intersection

	jmp .done


.parallel:  ;no intersection
	ffree st0  ;cleanup from fcomip
	mov eax,2

.done:
	pop edi
	pop esi
	pop ebx
	pop ebp
	retn 12


   
;****************************************************
;ptinrect

;Dec 2015 reduced input args
;this function had 6 args pushed
;its an example where it would be really nice to 
;have 15 or so registers to play with

;determine if a point is inside a rectangle
;coordinates of rect or point may be negative 
;x2 must be greater than x1
;y2 must be greater than y1
;all x,y values are signed integers
;if pt is on rect border this is success

;if the rectangle endpoints degenerate to a 
;vertical or horizontal line and point P is 
;on the line this will also give success

;input:
;push address of rect  x1,y1,x2,y2 16 bytes  [ebp+16]
;push dword Px  [ebp+12]
;push dword Py  [ebp+8]

;return:
;sets   zf if point is IN rect
;clears zf if point is NOT in rect
;***************************************************

ptinrect:

	push ebp
	mov ebp,esp
	pushad

	mov esi,[ebp+16]
	;x1 = [esi]
	;y1 = [esi+4]
	;x2 = [esi+8]
	;y2 = [esi+12]


	mov ebx,[ebp+12]   ;ebx=Px
	mov ecx,[esi+8]    ;ecx=x2

	;test Px between x1 and x2
	cmp ebx,[esi]      ;Px-x1
	setge al
	cmp ecx,ebx        ;x2-Px
	setge dl
	cmp al,dl
	jnz .done


	mov ebx,[ebp+8]   ;ebx=Py
	mov ecx,[esi+12]  ;ecx=y2

	;test Py between y1 and y2
	cmp ebx,[esi+4]  ;Py-y1
	setge al      
	cmp ecx,ebx       ;y2-Py
	setg dl           ;Nov 2013 setg was setge, want y2 > Py not =
	                  ;this is for dropdownlist to prevent adjacent selections
	cmp al,dl         
	;if ZF is set we have ptinrect 

.done: 
	popad
	pop ebp
	retn 12
	


;******************************************************
;pointinrectfloat
;determine if a point P is inside a rectangle bounded 
;by points P1 and P2

;input: 
;push address of P1 and P2 qword floats           [ebp+12]
;     thats x1,y1,x2,y2  32 bytes
;push address of P, thats px,py  qwords 16 bytes  [ebp+8]

;return: 
;sets   ZF if point is IN rect
;clears ZF if point is NOT in rect
;*******************************************************

pointinrectfloat:

	push ebp
	mov ebp,esp

	push esi
	push edi

	mov esi,[ebp+12]
	;x1=[esi]
	;y1=[esi+8]
	;x2=[esi+16]
	;y2=[esi+24]

	mov edi,[ebp+8]
	;px=[edi]
	;py=[edi+8]


	;test X values
	;***************

	;special test for vertical lines
	fld qword  [esi]     ;st0=x1
	fsub qword [esi+16]  ;st0=x1-x2
	fabs                 ;st0=abs(x1-x2)
	fcomp qword [two]    ;cmp abs(x1-x2) with 2.0
	fstsw ax             ;copy status word to ax
	sahf                 ;store ah to flags
	jb .TestYvalues      ;abs(x1-x2) is less than  2.0


	;if we got here the line is not vertical

	fld qword [edi]
	fld qword [esi+16] 
	fld qword [esi]    ;st0=x1, st1=x2, st2=px

	fcomi st2          ;cmp x1 with px
	jc .x1LessThanPx
	jz .FailureFree    ;values are equal

	fxch st2           ;st0=px, st1=x2, st2=x1
	fcomi st1          ;cmp px with x2
	jnc .TestYvalues   ;x2<px<x1
	jmp .FailureFree   ;cant possible have ptinrect

.x1LessThanPx:
	fxch st2           ;st0=px, st1=x2, st2=x1
	fcomi st1          ;cmp px with x2
	jc .TestYvalues    ;x1<px<x2
	jmp .FailureFree   ;cant possibly have ptinrect
	

.TestYvalues:
;**************

	;if we got here we have px between x1 and x2
	;first clean up the fpuregs from x checks
	ffree st0
	ffree st1
	ffree st2

	;special test for horizontal lines 
	fld qword  [esi+8]   ;st0=y1
	fsub qword [esi+24]  ;st0=y1-y2
	fabs                 ;st0=abs(y1-y2)
	fcomp qword [two]    ;cmp abs(y1-y2) with 2.0
	fstsw ax             ;copy status word to ax
	sahf                 ;store ah to flags
	jb .SuccessHorizontalLine


	;if we got here its not a horizontal line

	fld qword [edi+8] 
	fld qword [esi+24] 
	fld qword [esi+8]  ;st0=y1, st1=y2, st2=py

	fcomi st2          ;cmp y1 with py
	jc .y1LessThanPy
	jz .FailureFree    ;values are equal

	fxch st2           ;st0=py, st1=y2, st2=y1
	fcomi st1          ;cmp py with y2
	jnc .Success       ;y2<py<y1
	jmp .FailureFree   ;cant possibly have ptinrect

.y1LessThanPy:
	fxch st2           ;st0=py, st1=y2, st2=y1
	fcomi st1          ;cmp py with y2
	jc .Success        ;y1<py<y2
	jmp .FailureFree   ;cant possible have ptinrect



.SuccessHorizontalLine:
	xor eax,eax  ;set ZF
	jmp .done
.Success:
	ffree st0
	ffree st1
	ffree st2
	xor eax,eax  ;set ZF
	jmp .done
.FailureFree:
	ffree st0
	ffree st1
	ffree st2
	or eax,eax   ;clear ZF
.done:
	pop edi
	pop esi
	pop ebp
	retn 8



;********************************************************************
;ptonline
;this routine uses a cross product 
;to test if a point in on a line or left or right of the line
;the line starts at P1 and ends at P2 (line L12)
;the line coordinates are stored in memory 
;as 4 consecutive dword ints: x1,y1,x2,y2
;the point coordinates (P3) are stored in memory
;as 2 consecutive dword ints: x3,y3
;the cross product test is: 
;(x2-x1)(y3-y1) - (y2-y1)(x3-x1)

;in this example P3 is right of the line so SF is set
;                  2
;                 *
;                *
;               *
;              *     3
;             *
;            *
;           1

;input
;push address of line L12   [ebp+12]
;push address of point P3   [ebp+8]

;return
;if P3 is on L12,       ZF is set           (eax = 0)
;if P3 is right of L12, SF is set           (eax < 0)
;if P3 is left of L12,  ZF and SF are clear (eax > 0)
;*********************************************************************

ptonline:

	push ebp
	mov ebp,esp
	pushad

	mov esi,[ebp+12]  ;get address of line
	;x1=[esi]
	;y1=[esi+4]
	;x2=[esi+8]
	;y2=[esi+12]
	mov edi,[ebp+8]   ;get address of point
	;x3=[edi]
	;y3=[edi+4]


	mov eax,[esi+12]  ;eax=y2
	mov ebx,[esi+4]   ;ebx=y1
	sub eax,ebx       ;eax=y2-y1
	mov ecx,[edi]     ;ecx=x3
	mov edx,[esi]     ;edx=x1
	sub ecx,edx       ;edx=x3-x1
	xor edx,edx
	imul ecx           ;eax=(y2-y1)(x3-x1)
	push eax

	mov eax,[esi+8]   ;eax=x2
	mov ebx,[esi]     ;ebx=x1
	sub eax,ebx       ;eax=x2-x1
	mov ecx,[edi+4]   ;ecx=y3
	mov edx,[esi+4]   ;edx=y1
	sub ecx,edx       ;ecx=y3-y1
	xor edx,edx
	imul ecx           ;eax = (x2-x1)(y3-y1)

	pop ebx
	sub eax,ebx       ;eax=(x2-x1)(y3-y1) - (y2-y1)(x3-x1)
	;we are not preserving eax so use ZF or SF as your return value

	popad
	pop ebp
	retn 8





;*************************************************************
;mirrorpoint
;determine the x,y coordinates of a mirored point 
;the mirror line is defined by points 12
;point P3 is any point not on line L12
;point P5 is on line L12 and 
;line L35 is perpendicular to line L12
;point P4 is the mirror image of point P3
;line L45 is also perpendicular to line L12
;line L45 is the same length as line L35

;input:
;push address of mirror line L12 endpoints     (4 qwords x1,y1,x2,y2)   [ebp+16]
;push address of point to be mirrored          (P3, 16 bytes)           [ebp+12]
;push address of mirrored point local storage  (P4, 16 bytes)           [ebp+8]

;return: P4 (x4,y4 is filled in)

;all calcs are done in floating point, each point is 16 bytes

;               1
;               *
;               *
;               *
;          4    5    3
;               *
;               *
;               *
;               2

;the mirror line can be any orientation, not just vertical

;locals
mir_Length dq 0.0
mir_DX     dq 0.0
mir_DY     dq 0.0
;****************************************************************

mirrorpoint:

	push ebp
	mov ebp,esp
	push eax
	push ebx
	push ecx

	mov eax,[ebp+16]  ;mirror line
	;x1=[eax]
	;y1=[eax+8]
	;x2=[eax+16]
	;y2=[eax+24]
	mov ebx,[ebp+12]  ;point to be mirrored
	;x3=[ebx]
	;y3=[ebx+8]
	mov ecx,[ebp+8]   ;the mirror point
	;x4=[ecx]
	;y4=[ecx+8]


	;first get length of mirror line

	push eax
	call getslope  ;st0=x2-x1, st1=y2-y1

	;save for later
	fst qword [mir_DX]        ;DX=x2-x1
	fxch st1         
	fst qword [mir_DY]        ;DY=y2-y1
	fxch st1

	call getlength           ;st0=L=length of mirror line 
	fstp qword [mir_Length]  ;save Length

	;now compute r=[(y1-y3)(y1-y2) - (x1-x3)(x2-x1)] / L^2
	fld  qword [eax] q      ;st0=x1
	fsub qword [ebx] q      ;st0=x1-x3
	fmul qword [mir_DX] q       ;st0=(x1-x3)(x2-x1)
	fld  qword [eax+8] q    ;st0=y1, st1=...
	fsub qword [eax+24] q   ;st0=y1-y2, st1=...
	fld  qword [eax+8] q    ;st0=y1, st1=y1-y2, st2=...
	fsub qword [ebx+8] q    ;st0=y1-y3, st1=y1-y2, st2=...
	fmulp st1         ;st0=(y1-y3)(y1-y2), st1=...
	fsub st1          ;st0=(y1-y3)(y1-y2) - (x1-x3)((x2-x1), st1=...
	ffree st1
	fdiv qword [mir_Length] q
	fdiv qword [mir_Length] q   ;st0=r

	;compute x5,y5 which is on the mirror line
	;it is the projected point of P3 onto the mirror line
	;x5=x1 + r(x2-x1), y5=y1 + r(y2-y1)
	fst st1                ;st0=r, st1=r
	fmul qword [mir_DX]    ;st0=r(x2-x1), st1=r
	fadd qword [eax]       ;st0=x5, st1=r
	fxch st1               ;st0=r, st1=x5
	fmul qword [mir_DY]    ;st0=r(y2-y1), st1=x5
	fadd qword [eax+8]     ;st0=y5, st1=x5

	
	;finally compute x4,y4 our mirror point
	;x4=2*x5 - x3
	;y4=2*y5 - y3
	fmul qword [two]      ;st0=2*y5, st1=x5
	fsub qword [ebx+8]    ;st0=y4
	fstp qword [ecx+8]    ;st0=x5
	fmul qword [two]      ;st0=2*x5
	fsub qword [ebx]      ;st0=x4
	fstp qword [ecx]      

	pop ecx
	pop ebx
	pop eax
	pop ebp
	retn 12




;*****************************************************************
;projectpointtoline
;L12 is any line
;P3 is any point not on L12 
;P4 is a point on L12 or the imaginary extension thereof
;L34 is perpendicular to L12

;input
;push Starting address of Line12  (4 qwords 32 bytes x1,y1,x2,y2) [ebp+12]
;push Starting address of Line34  (4 qwords 32 bytes x3,y3,x4,y4) [ebp+8]

;you should initialize x4 and y4 to zero

;return
;this function will write the value of x4,y4 to your memory block

;the calculation comes from the comp.graphics.algorithms FAQ

;this routine uses all fpu registers but returns them all free
pp2lstr1 db 'projectpointtoline',0
pp2lstr2 db 'projectpointtoline end',0
;*******************************************************************

projectpointtoline:

	push ebp
	mov ebp,esp
	push esi
	push edi

	;STDCALL pp2lstr1,dumpstr

	mov esi,[ebp+12]
	;x1=[esi]
	;y1=[esi+8]
	;x2=[esi+16]
	;y2=[esi+24]

	mov edi,[ebp+8]
	;x3=[edi]
	;y3=[edi+8]
	;x4=[edi+16]
	;y4=[edi+24]


	;test for horizontal line
	;if dy<.01 we call it "horizontal"
	;************************************
	fld  qword [esi+8]         ;st0=y1
	fsub qword [esi+24]        ;st0=y1-y2
	fabs                       ;st0=abs(dy) 
	fld  qword [pointzeroone]  ;st0=.01, st1=abs(dy)
	fcomip st1                 ;compare st0 with st1 & set flags
	jc .doneHorizontalLine

	;if we got here we have a horizontal line
	;x4=x3, y4=y1
	ffree st0
	fld  qword [edi]     ;load x3
	fstp qword [edi+16]  ;save x4=x3
	fld  qword [esi+8]   ;load y1
	fstp qword [edi+24]  ;save y4=y1
	jmp .done
.doneHorizontalLine:
	ffree st0





	;the line is not horizontal 
	;it is vertical or at some oblique angle
	;*********************************************

	;get length of L12
	push esi
	call getslope
	call getlength    ;st0=length of L12

	fmul st0          ;st0=L*L


	;compute r=[(y1-y3)(y1-y2) - (x1-x3)(x2-x1)] / (L*L)
	fld  qword [esi]     ;st0=x1, st1=L*L 
	fsub qword [edi]     ;st0=(x1-x3), st1=L*L
	fld  qword [esi+16]  ;st0=x2, st1=(x1-x3), st2=L*L
	fsub qword [esi]     ;st0=(x2-x1), st1=(x1-x3), st2=L*L
	fst  st3             ;st0=(x2-x1), st1=(x1-x3), st2=L*L, st3=(x2-x1)
	fmul st1
	 ;st0=(x2-x1)*(x1-x3), st1=(x1-x3), st2=L*L, st3=(x2-x1)

	fld qword [esi+8]  
	 ;st0=y1, st1=(x2-x1)*(x1-x3), st2=(x1-x3), st3=L*L, st4=(x2-x1)

	fsub qword [edi+8]  
	 ;st0=(y1-y3), st1=(x2-x1)*(x1-x3), st2=(x1-x3), st3=L*L, st4=(x2-x1)

	fld  qword [esi+8]  
	;st0=y1, st1=(y1-y3), st2=(x2-x1)*(x1-x3)
	;st3=(x1-x3), st4=L*L, st5=(x2-x1)

	fsub qword [esi+24]  
     ;st0=(y1-y2), st1=(y1-y3) st2=(x1-x3)(x2-x1)
     ;st3=(x1-x3), st4=L*L, st5=(x2-x1)

	fchs   ;change sign of st0
     ;st0=(y2-y1), st1=(y1-y3) st2=(x1-x3)(x2-x1)
     ;st3=(x1-x3), st4=L*L, st5=(x2-x1)

	fst st6 
     ;st0=(y2-y1), st1=(y1-y3) st2=(x1-x3)(x2-x1)
     ;st3=(x1-x3), st4=L*L, st5=(x2-x1), st6=(y2-y1)

	fchs  ;change it back

     ;st0=(y1-y2), st1=(y1-y3) st2=(x1-x3)(x2-x1)
     ;st3=(x1-x3), st4=L*L, st5=(x2-x1), st6=(y2-y1)

	fmul st1
     ;st0=(y1-y3)(y1-y2), st1=(y1-y3) st2=(x1-x3)(x2-x1)
     ;st3=(x1-x3), st4=L*L, st5=(x2-x1), st6=(y2-y1)



	fsub st2       
     ;st0=(y1-y3)(y1-y2)-(x1-x3)(x2-x1), st1=(y1-y3) st2=(x1-x3)(x2-x1)
     ;st3=(x1-x3), st4=L*L, st5=(x2-x1), st6=(y2-y1)

	fdiv st4
     ;st0=r, st1=(y1-y3) st2=(x1-x3)(x2-x1)
     ;st3=(x1-x3), st4=L*L, st5=(x2-x1), st6=(y2-y1)


	
	;at this point we need the values in st0, st5, st6
	;all other register values can be discarded

	ffree st1
	ffree st2
	ffree st3
	ffree st4


	;compute x4
	;**********

	fxch st5
	;st0=(x2-x1), st1=free, st2=free, st3=free, st4=free
	;st5=r, st6=(y2-y1)

	fmul st5
	;st0=r*(x2-x1), st1=free, st2=free, st3=free, st4=free
	;st5=r, st6=(y2-y1)

	fadd qword [esi] 
	;st0=x1+r*(x2-x1), st1=free, st2=free, st3=free, st4=free
	;st5=r, st6=(y2-y1)


	fstp qword [edi+16]   ;save x4
	;st0=free, st1=free, st2=free, st3=free, st4=r, st5=(y2-y1)



	;compute y4
	;***********

	fxch st5
	;st0=(y2-y1), st1=free, st2=free, st3=free, st4=r, st5=free

	fmul st4 
	;st0=r*(y2-y1), st1=free, st2=free, st3=free, st4=r, st5=(y2-y1)

	fadd qword [esi+8] 
	;st0=y1+r*(y2-y1), st1=free, st2=free, st3=free, st4=r, st5=(y2-y1)


	fstp qword [edi+24]   ;save y4
	;st0=free, st1=free, st2=free, st3=r, st4=(y2-y1)

	ffree st3
	ffree st4

.done:
	;STDCALL pp2lstr2,dumpstr

	pop edi
	pop esi
	pop ebp
	retn 8




;***********************************************
;chamfer
;given vectors A and B compute chamfer vector C
;does not draw the chamfer
;A and B must share a common start point 

;the angle between vectors A and B does not have
;to be 90deg, any acute angle will work.

;the chamfer may or may not intersect vectors A and B
;i.e. if the chamfer is large enough its endpoints will
;fall outside vectors A,B

;if chamfer vector C does intersect vectors A and B
;then the length of side A(x1,y1)->C(x1,y2)
;and  the length of side B(x1,y1)->C(x2,y2) are equal

;each qword vector is 32 bytes x1,y1,x2,y2

;the "size" of the chamfer is defined as the 
;distance from the intersection of vectors A,B
;to the point where the chamfer would intersect either
;vectors A or B. In other words the size of the chamfer
;is equal to the length of the leg of the chamfer triangle
;not the length of vector C. If vectors A,B intersect at
;90 degrees, then a std 45 deg chamfer is created.


;                  
;                * A(x2,y2)
;                *
;                *  
;          C   * *  A
;            *   * 
;          *     *
;    ************* A(x1,y1)=B(x1,y1)
; B(x2,y2)    B    

;input
;push Address of qword vector A        [ebp+20]
;push Address of qword vector B        [ebp+16]
;push Address to store qword vector C  [ebp+12]
;push Address of qword chamfer C size  [ebp+8]

;return:none
;***************************************************
 

chamfer:

	push ebp
	mov ebp,esp
	push esi
	push edi

	mov edi,[ebp+12]   ;edi=VectorC


	;compute Cx1 = Ax1 + (Ax2-Ax1) * size/LengthA;
	;*********************************************
	
	mov esi,[ebp+20]     ;esi=Vector A
	push esi
	call getslope        ;returns st0=dx, st1=dy
	call getlength       ;returns st0=LengthA

	mov esi,[ebp+8]      ;esi=chamf size
	fld qword [esi]
	;st0=size, st1=LengthA

	fdiv st1
	ffree st1
	;st0=size/LengthA

	;save a copy 
	fst st1
	;st0=st1=size/LengthA

	mov esi,[ebp+20]     ;esi=Vector A
	fld qword [esi+16]
	;st0=Ax2, st1=st2=size/LengthA

	fsub qword [esi]
	;st0=Ax2-Ax1, st1=st2=...

	fmulp st1
	;st0=(Ax2-Ax1)*size/LengthA  st1=size/LengthA
	
	fadd qword [esi]
	;st0=Cx1=Ax1+(Ax2-Ax1)*size/LengthA  st1=...

	;save Cx1
	fstp qword [edi]
	;st0=size/LengthA



	;Cy1 = Ay1 + (Ay2-Ay1) * size/LengthA
	;*************************************

	fld qword [esi+24]
	;st0=Ay2, st1=size/LengthA

	fsub qword [esi+8]
	;st0=Ay2-Ay1, st1=...

	fmulp st1
	;st0=(Ay2-Ay1)*size/LengthA
	
	fadd qword [esi+8]
	;st0=Ay1+(Ay2-Ay1)*size/LengthA = Cy1

	;save Cy1
	fstp qword [edi+8]



	;Cx2 = Bx1 + (Bx2-Bx1) * size/LengthB
	;***************************************

	mov esi,[ebp+16]     ;esi=Vector B
	push esi
	call getslope        ;returns st0=dx, st1=dy
	call getlength       ;returns st0=LengthB
	
	mov esi,[ebp+8]      ;esi=chamf size
	fld qword [esi]
	;st0=size, st1=LengthB

	fdiv st1
	ffree st1
	;st0=size/LengthB

	;save a copy 
	fst st1
	;st0=st1=size/LengthB

	mov esi,[ebp+16]     ;esi=Vector B
	fld qword [esi+16]
	;st0=Bx2, st1=st2=size/LengthB

	fsub qword [esi]
	;st0=Bx2-Bx1, st1=st2=...

	fmulp st1
	;st0=(Bx2-Bx1)*size/LengthB  st1=size/LengthB
	
	fadd qword [esi]
	;st0=Cx2=Bx1+(Bx2-Bx1)*size/LengthB  st1=...

	;save Cx2
	fstp qword [edi+16]
	;st0=size/LengthB



	;Cy2 = By1 + (By2-By1) * size/LengthB
	;*************************************

	fld qword [esi+24]
	;st0=By2, st1=size/LengthB

	fsub qword [esi+8]
	;st0=By2-By1, st1=...

	fmulp st1
	;st0=(By2-By1)*size/LengthB
	
	fadd qword [esi+8]
	;st0=By1+(By2-By1)*size/LengthB = Cy2

	;save Cy1
	fstp qword [edi+24]

	pop edi
	pop esi
	pop ebp
	retn 16






;*********************************************************
;fillet
;computes parameters necessary to draw an arc which is 
;tangent to two non-parallel (intersecting) vectors. 
;does not draw the arc. the center of the arc falls on a 
;line which bisects vectors A and B. Vectors A and B must 
;share a common start point. the order in which you push 
;vectors A,B is important. (A cross B) must be > 0
;the included angle between A and B need not be 90deg
;you must use YORIENT=-1 with this function otherwise
;getnormal returns a nonsense result.

;                      * Ax2,Ay2
;                      *
;                      *
;         center       *
;         of arc       4
;          [0]        **
;                    * * 
;                  *   *  A
;                *     * 
;              *       *
;           *          *
;        *             *
; ****5****************2  Ax1,Ay1
; Bx2,By2    B            Bx1,By1
;       
;
;input
;push Address of qword vector A          [ebp+24]
;push Address of qword vector B          [ebp+20]
;push Address of qword arc radius        [ebp+16]         
;push Address of 20 byte results buffer1 [ebp+12]
;push Address of 64 byte results buffer2 [ebp+8]

;return
;fills in results buffer1 and buffer2

;results buffer1 (20 bytes)
;****************************
;these are the first 5 values of the ARC structure (see arc.s)
;dword arc X0 center         
;dword arc Y0 center         
;dword arc radius            
;dword arc angle_start,deg   
;dword arc angle_end         

;results buffer2 (64 bytes)
;****************************
;these values are used to draw lines from the 
;arc center to its endpoints 
;qword arc center      x0   [buffer2 ]
;qword arc center      y0   [buffer2 + 8]
;qword arc start point x4   [buffer2 + 16]
;qword arc start point y4   [buffer2 + 24]
;qword arc center      x0   [buffer2 + 32]
;qword arc center      y0   [buffer2 + 40]
;qword arc end   point x5   [buffer2 + 48]
;qword arc end   point y5   [buffer2 + 56]

;locals
fillet_norm_buf           times 16 db 0
fillet_angle_start_vector times 32 db 0
fillet_angle_end_vector   times 32 db 0
fillet_L24   dq 0.0
fillet_LA    dq 0.0
fillet_LB    dq 0.0
;**********************************************************


fillet:

	push ebp
	mov ebp,esp
	push eax
	push ebx
	push ecx
	push edi

	mov eax,[ebp+24] ;eax=vector A
	mov ebx,[ebp+20] ;ebx=vector B
	mov ecx,[ebp+16] ;ecx=radius
	
	push eax
	push ebx
	call getangleinc
	;st0=angle
	fabs  ;absolute value


	;compute L20 from point 2 to center of arc
	;*********************************************
	;L20 = radius / sin(angle/2.0);
	fdiv qword [two]
	;st0=angle/2
	fsin
	;st0=sin(angle/2)
	fld qword [ecx]
	;st0=radius, st1=sin()
	fdivrp st1
	;st0=L20=radius/sin()
	


	;compute L24 from point 2 to where fillet touches A
	;L24 = sqrt(L20*L20 - radius*radius);
	;********************************************************
	fmul st0
	;st0=L20^2
	fld qword [ecx]
	;st0=radius, st1=...
	fmul st0
	;st0=radius^2, st1=L20^2
	fsubp st1
	;st0=L20^2-radius^2
	fsqrt
	;st0=L24
	fstp qword [fillet_L24]

	

	;x4 = Ax1 + (L24/LA)*(Ax2-Ax1)
	;******************************
	push eax
	call getslope  ;returns st0=dx, st1=dy
	call getlength ;returns st0=LA
	fstp qword [fillet_LA]
	fld qword [eax+16]
	;st0=Ax2
	fsub qword [eax]
	;st0=Ax2-Ax1
	fmul qword [fillet_L24]
	;st0=L24(Ax2-Ax1)
	fdiv qword [fillet_LA]
	;st0=(L24/LA)*(Ax2-Ax1)
	fadd qword [eax]
	;st0=x4=Ax1+(L24/LA)*(Ax2-Ax1), st1=LA, st2=L24
	fst qword [fillet_angle_end_vector+16]
	;set edi=results buffer2
	mov edi,[ebp+8]  
	fstp qword [edi+16]



	;y4 = Ay1 + (L24/LA)*(Ay2-Ay1)
	;*******************************
	fld qword [eax+24]
	;st0=Ay2
	fsub qword [eax+8]
	;st0=Ay2-Ay1
	fmul qword [fillet_L24]
	;st0=L24(Ay2-Ay1)
	fdiv qword [fillet_LA]
	;st0=(L24/LA)*(Ay2-Ay1)
	fadd qword [eax+8]
	;st0=y4=Ay1+(L24/LA)*(Ay2-Ay1), st1=LA, st2=L24
	fst qword [fillet_angle_end_vector+24]
	fstp qword [edi+24]



	;x5 = Bx1 + (L24/LB)*(Bx2-Bx1)
	;******************************
	push ebx
	call getslope   ;returns st0=dx, st1=dy
	call getlength  ;returns st0=LB  
	fstp qword [fillet_LB]
	fld qword [ebx+16]
	;st0=Bx2
	fsub qword [ebx]
	;st0=Bx2-Bx1
	fmul qword [fillet_L24]
	;st0=L24(Bx2-Bx1)
	fdiv qword [fillet_LB]
	;st0=(L24/LB)*(Bx2-Bx1)
	fadd qword [ebx]
	;st0=x4=Bx1+(L24/LB)*(Bx2-Bx1)
	fst qword [fillet_angle_start_vector+16]
	fstp qword [edi+48]



	;y5 = By1 + (L24/LB)*(By2-By1)
	;******************************
	fld qword [ebx+24]
	;st0=By2
	fsub qword [ebx+8]
	;st0=By2-By1
	fmul qword [fillet_L24]
	;st0=L24(By2-By1)
	fdiv qword [fillet_LB]
	;st0=(L24/LB)*(By2-By1)
	fadd qword [ebx+8]
	;st0=y4=By1+(L24/LB)*(By2-By1)
	fst qword [fillet_angle_start_vector+24]
	fstp qword [edi+56]




	;X0 = x4 + normx * radius
	;*************************
	push eax
	push fillet_norm_buf
	call getnormal
	fld qword [fillet_norm_buf]
	;st0=normx
	fmul qword [ecx]
	;st0=normx*radius
	fadd qword [fillet_angle_end_vector+16]
	;st0=x0=x4 + normx*radius
	fst qword [fillet_angle_start_vector]
	fst qword [fillet_angle_end_vector]
	;save x0 as qword to buffer2
	fst qword [edi]
	fst qword [edi+32]
	;save x0 as dword to buffer1 
	mov edi,[ebp+12]  
	fistp qword [edi]
	

	;Y0 = y4 + normy * radius
	;**************************
	fld qword [fillet_norm_buf+8]
	;st0=normy
	fmul qword [ecx]
	;st0=normy*radius
	fadd qword [fillet_angle_end_vector+24]
	;st0=y0=y4 + normy*radius
	fst qword [fillet_angle_start_vector+8]
	fst qword [fillet_angle_end_vector+8]
	;save y0 as qword to buffer2
	mov edi,[ebp+8]
	fst qword [edi+8]
	fst qword [edi+40]
	;save y0 as dword to buffer1
	mov edi,[ebp+12]  
	fistp qword [edi+4]


	;radius
	;*******
	fld qword [ecx]
	fistp dword [edi+8]



	;angle_start
	;*************
	push fillet_angle_start_vector
	call getslope   ;returns st0=dx, st1=dy
	fpatan          ;st0=angle
	call rad2deg
	fistp dword [edi+12]
	mov eax,[edi+12]
	call normalizedeg
	mov [edi+12],eax


	;angle_end
	;**********
	push fillet_angle_end_vector
	call getslope
	fpatan
	call rad2deg
	fistp dword [edi+16]
	mov eax,[edi+16]
	call normalizedeg
	mov [edi+16],eax

	
	pop edi
	pop ecx
	pop ebx
	pop eax
	pop ebp
	retn 20




;****************************************************
;RotatePoint
;determine the x,y coordinates of a point rotated
;about a local origin center of rotation

;all x,y coordinates and calcs are qword floats
;each point is stored in memory as (qword X, qword Y)
;each point takes up 16 bytes of memory
;the rotation angle is a qword float

;the x,y coordinates must be defined relative to
;the center of rotation

;the basic formulas:
;X=xcos-ysin
;Y=xsin+ycos

;input:
;push Address of point x,y                       [ebp+16]
;push Address of rotation angle,radians          [ebp+12]
;push Address to store rotated point coordinates [ebp+8]

;return:
;x,y is written to the memory address provided
;****************************************************

RotatePoint:

	push ebp
	mov ebp,esp
	pushad

	mov esi,[ebp+16]
	;x=[esi]
	;y=[esi+8]

	mov edi,[ebp+12]   ;esi=angle
	mov ebx,[ebp+8]    ;ebx=Xnew,Ynew

	;work on x
	fld qword [edi]    ;st0=angle...
	fsincos            ;st0=cos,  st1=sin
	fmul qword [esi]   ;st0=xcos, st1=sin
	fxch st1           ;st0=sin,  st1=xcos
	fmul qword [esi+8] ;st0=ysin, st1=xcos
	fsubp st1          ;st0=xcos-ysin
	fstp qword [ebx]   ;save Xnew

	;work on y
	fld qword [edi]    ;st0=angle...
	fsincos            ;st0=cos,  st1=sin
	fmul qword [esi+8] ;st0=ycos, st1=sin
	fxch st1           ;st0=sin,  st1=ycos
	fmul qword [esi]   ;st0=xsin, st1=ycos
	faddp st1          ;st0=xsin+ycos
	fstp qword [ebx+8] ;save Ynew
	
	popad
	pop ebp
	retn 12

 



;***************************************************
;grid
;draws a rectangular grid
;of vertical and horiz lines
;useful as a background for graphic layout

;input
;push line spacing in pixels  [ebp+12]
;push color index (0-0xff)    [ebp+8]
;return:none

;YORIENT=1 horizontal grid lines start from top
;YORIENT=-1 horizontal grid lines start from bottom
;****************************************************

grid:
	push ebp
	mov ebp,esp
	pushad

	mov esi,[ebp+8]  ;color
	
	;vertical lines 
	mov ebx,0         ;x
	mov ecx,0         ;y
	mov edx,599       ;length
.1:	call vline
	add ebx,[ebp+12]  ;inc x
	cmp ebx,799
	jb .1
	

	;horizontal lines
	mov ebx,0        ;x
	mov ecx,0        ;y
	mov edx,799      ;length
.2:	call hline
	add ecx,[ebp+12]
	cmp ecx,599
	jb .2
	

	;border
	STDCALL 0,0,799,599,[ebp+8],rectangle
	
	popad
	pop ebp
	retn 8




;****************************************************************
;rose
;this function generates 3000 points for the polar equation 
;Radius = Amplitude * Cos[Kfactor*theta]

;the Kfactor controls the shape of the rose
;some typical Kfactors to use are:
;k=1.0  circle
;k=2.0  4 pedal rose
;k=3.0  3 pedal rose
;k=4.0  8 pedal rose
;k=5.0  5 pedal rose
;k=6.0  12 pedal rose
;other Kfactors to try which generate the spirograph shapes are:
;1/7,  1/6, 1/5,  1/4,  2/7
;1/3,  2/5, 3/7,  1/2,  4/7, 3/5,  2/3, 5/7, 3/4, 4/5
;5/6,  6/7, 8/7,  7/6,  6/5, 5/4,  9/7, 4/3, 7/5
;10/7, 3/2, 11/7, 9/5,  5/3, 12/7, 7/4, 9/5, 11/6
;13/7, 7/4, 9/5,  11/6, 13/7

;if you every played with "spirograph" as a child these figures
;will look familiar.

;reference document from the web:
;"Rose Curve" http://xahlee.info/SpecialPlaneCurves_dir/Rose_dir/rose.html
;there is also a wikipedia article as of Sept 2013

;I include this function in tlib because I have a fondness for 
;mathmatical constructs and this function can generate so many
;interesting shapes. Also a useful fpu demo

;the cosine curve looks like the familiar "wave" with humps if
;you plot as x/y coordinates, but this functions first computes
;r/theta polar then converts to rectangular.
;also note that we dont plot from 0->360deg because this will not
;generate enough points for the more detailed shapes
;we keep going to generate 3000 points incrementing by 1 degree

;this function will generate 3000 x,y points for setpixel
;(each x value and each y value is a dword)
;reqd buffer size is 6000 dwords 
;the points are stored in the buffer as x0,y0, x1,y1, x2,y2, x3,y3....

;input
;st0 = Kfactor
;st1 = Amplitude
;st2 = X center of rose
;st3 = Y center of rose
;edi = Address of 20,000 byte buffer to store  dword x,y points

;return:
;the x,y dword points are written to the destination buffer

;local
rose_thetainc  dq 0.0174532
rose_theta     dq 0.0
rose_AngleStop dq 44.0
rose_Amplitude dq 0.0
rose_Kfactor   dq 0.0
rose_Xcenter   dq 0.0
rose_Ycenter   dq 0.0
rose_X         dd 0
rose_Y         dd 0
;*****************************************************************

rose:

	push ecx
	push edi

	;first save to local memory and free up the fpu registers
	fstp qword [rose_Kfactor]
	fstp qword [rose_Amplitude]
	fstp qword [rose_Xcenter]
	fstp qword [rose_Ycenter]


	;start out with theta=0
	fldz                    ;st0=theta=0
	fst  qword [rose_theta] ;zero out theta to begin with for consecutive invoke of exe
	mov ecx,0               ;array index

.1:
	;copy theta
	fst st1                      ;st0=st1=theta
	fmul qword [rose_Kfactor]    ;st0=3*theta, st1=theta
	fcos                         ;st0=cos(3*theta), st1=theta
	fmul qword [rose_Amplitude]  ;st0=radius=Amp*cos(3*theta), st1=theta

	;convert polar coordinates to cartesian for plotting
	fxch st1                   ;st0=theta, st1=radius
	fsincos                    ;st0=cos(theta), st1=sin(theta), st2=radius
	fmul st2                   ;st0=radius*cos, ...
	fadd qword [rose_Xcenter]  ;st0=Xcenter+radius*cos, ...

	;save X as dword int and store in DestBuf
	fistp dword [rose_X]       ;st0=sin(theta), st1=radius
	mov eax,[rose_X]
	mov [edi],eax              ;save x

	;save Y 
	fmulp st1                  ;st0=radius*sin
	fadd qword [rose_Ycenter]  ;st0=Ycenter+radius*sin
	fistp dword [rose_Y]
	mov eax,[rose_Y]
	mov [edi+4],eax            ;save y

	;increment theta
	fld qword  [rose_theta]      ;st0=theta
	fadd qword [rose_thetainc]   ;st0=theta+thetainc
	fst qword  [rose_theta]      ;save new theta

	;inc array index
	add ecx,1

	;inc destination address
	add edi,8
	
	;test for quit
	cmp ecx,3000
	jb .1


.done:
	pop edi
	pop ecx
	ret



 

;*******************************************************************
;rotateline
;determine the endpoints of a new line segment x3,y3,x4,y4
;that is rotated relative to an existing line segment x1,y1,x2,y2
;using center point xc,yc
;all coordinates & angles are qword dbl prec floating point
;the direction of rotation is counter clock wise with [YORIENT]=-1

;Rotate point, angle=t +ccw
;x,y are defined relative to the center of rotation
;x = xcost - ysint
;y = xsint + ycost

;input:
;push Address of line segment coordinates x1,y1,x2,y2      [ebp+20]
;push Address of 32 bytes of memory to store rotated line  [ebp+16]
;push Address of rotation angle,radians                    [ebp+12]
;push Address of center point coordinates xc,yc            [ebp+8]

;return:
;x3,y3,x4,y4 are written to [ebp+16]

;locals
rot_dx      dq 0.0
rot_dy      dq 0.0
rot_radius  dq 0.0
rot_angle   dq 0.0
rot_stor times 32 db 0

;**********************************************************************

rotateline:

	push ebp
	mov ebp,esp
	pushad


	;source line segment
	mov esi,[ebp+20]
	;x1=[esi]
	;y1=[esi+8]
	;x2=[esi+16]
	;y2=[esi+24]

	;rotated line segment
	mov edi,[ebp+16]
	;x3=[edi]
	;y3=[edi+8]
	;x4=[edi+16]
	;y4=[edi+24]

	;save local rot_angle,radians
	mov ebx,[ebp+12]
	fld  qword [ebx]
	fstp qword [rot_angle] 

	;center point
	mov ecx,[ebp+8]
	;xc=[ecx]
	;yc=[ecx+8]




	;point (x1,y1)->(x3,y3)
	;**********************

	fld  qword [ecx]              ;st0=xc
	fstp qword [rot_stor] 
	fld  qword [ecx+8]            ;st0=yc
	fstp qword [rot_stor+8] 
	fld  qword [esi]              ;st0=x1
	fstp qword [rot_stor+16] 
	fld  qword [esi+8]            ;st0=y1
	fstp qword [rot_stor+24] 

	push rot_stor
	call getslope             ;st0=dx, st1=dy
	call getlength            ;st0=radius from center to P1
	fst  qword [rot_radius]   ;st0=radius 

	;check for radius < 2 which is rotation about self
	fld qword [two]   ;st0=2.0, st1=radius
	fcomip st1        ;cmp 2.0 with radius 
	jc .1             ;st0=2.0
	ffree st0         ;cleanup fcomip

	
	;if we got here we have rotation about self
	;just save x1,y1 to x3,y3
	fld  qword [esi]    ;load x1
	fstp qword [edi]    ;save x3
	fld  qword [esi+8]  ;load y1
	fstp qword [edi+8]  ;save y3
	jmp .doPoint2



.1:
	ffree st0         ;cleanup fcomip
	;if we got here the point is not rotation about self
	;compute angle from center of rotation to P1
	push rot_stor
	call getslope           ;st0=dx, st1=dy
	fpatan                  ;st0=angle,radians
	fadd qword [rot_angle]  ;st0=atan(dy,dx)+rotangle=newangle

	;coordinates of child point relative to center of rotation
	fsincos                   ;st0=cos(newangle), st1=sin(newangle)
	fmul qword [rot_radius]   ;st0=radius*cos(newangle)=newdx, st1=...
	fadd qword [ecx]          ;st0=newdx+xc, st1=...
	fstp qword [edi]          ;save x3, st0=sin(newangle)
	fmul qword [rot_radius]   ;st0=radius*sin(newangle)=newdy
	fadd qword [ecx+8]        ;st0=newdy+yc
	fstp qword [edi+8]        ;save y3
 
	
	
.doPoint2:

	;point (x2,y2)->(x4,y4)
	;**********************

	fld  qword [esi+16]           ;st0=x2
	fstp qword [rot_stor+16] 
	fld  qword [esi+24]           ;st0=y2
	fstp qword [rot_stor+24] 

	push rot_stor
	call getslope          ;st0=dx, st1=dy
	call getlength         ;st0=radius from center to P2
	fst  qword [rot_radius]  ;save rotation radius

	;check for radius < 2 which is rotation about self
	fld qword [two]   ;st0=2.0, st1=radius
	fcomip st1        ;cmp 2.0 with radius
	jc .2             ;st0=2.0 
	ffree st0         ;cleanup fcomip

	;if we got here we have rotation about self
	;just save x2,y2 to x4,y4
	fld  qword [esi+16]   ;load x2
	fstp qword [edi+16]   ;save x4
	fld  qword [esi+24]   ;load y2
	fstp qword [edi+24]   ;save y4
	jmp .done


.2:
	ffree st0         ;cleanup fcomip
	;if we got here the point is not rotation about self
	;compute angle from center of rotation to P2
	push rot_stor
	call getslope      ;st0=dx, st1=dy
	fpatan             ;st0=angle,radians
	fadd qword [rot_angle]  ;st0=atan(dy,dx)+rotangle=newangle

	;coordinates of child point relative to center of rotation
	fsincos              ;st0=cos(newangle), st1=sin(newangle)
	fmul qword [rot_radius]   ;st0=radius*cos(newangle)=newdx, st1=...
	fadd qword [ecx]          ;st0=newdx+xc, st1=...
	fstp qword [edi+16]       ;save x4, st0=sin(newangle)
	fmul qword [rot_radius]   ;st0=radius*sin(newangle)=newdy
	fadd qword [ecx+8]        ;st0=newdy+yc
	fstp qword [edi+24]       ;save y4
 

.done:
	popad
	pop ebp
	retn 16




;*************************************************************
;offset
;create a new line segment x3,y3,x4,y4 
;that is parallel offset from an existing segment x1,y2,x2,y2
;endpoint coordinates and offset amount are qword dbl prec floating point

;input
;push address of qword vector x1,y1,x2,y2                     [ebp+16]
;push address of 32bytes of memory to store new offset vector [ebp+12]
;push address of qword offset amount                          [ebp+8]

;return:
;the new vector is written to memory supplied by the second push

;the offset is + or - as follows with default [YORIENT]=1 :
;horizontal lines (+) offset is down
;vertical lines   (+) offset is to the right
;diagonal lines   (+) offset is to right and up/dn 

;the offset is + or - as follows with [YORIENT]=-1 :
;horizontal lines (+) offset is up
;vertical lines   (+) offset is to the right
;diagonal lines   (+) offset is to right and up/dn 

;local
offset_DX dq 0.0
;**************************************************************

offset:

	push ebp
	mov ebp,esp
	push esi
	push edi
	push ebx


	;esi holds address of vector to be offset
	mov esi,[ebp+16]
	;x1=[esi]
	;y1=[esi+8]
	;x2=[esi+16]
	;y2=[esi+24]


	;esi holds address of new offset vector
	mov edi,[ebp+12]
	;x3=[edi]
	;y3=[edi+8]
	;x4=[edi+16]
	;y4=[edi+24]


	;ebx holds address of offset amount
	mov ebx,[ebp+8]


	;test for special case horizontal line to offset
	fld  qword [esi+24]
	fsub qword [esi+8]   ;st0=dy
	fabs                 ;st0=abs(dy)
	fld1                 ;st0=1.0, st1=abs(dy)
	fcomip st1           ;st0=abs(dy)
	jc .offsetGeneralLine

	;if we got here we have a horizontal line to offset
	ffree st0  ;cleanup from fcomip


	;define x3,y3,x4,y4 for new horizontal offset line
	fld  qword [esi]
	fstp qword [edi]    ;x3=x1
	fld  qword [ebx]
	fadd qword [esi+8] 
	fstp qword [edi+8]  ;y3=y1+offset
	fld  qword [esi+16]
	fstp qword [edi+16] ;x4=x2
	fld  qword [ebx]
	fadd qword [esi+24]
	fstp qword [edi+24] ;y4=y2+offset
	jmp .done
	;done with offset horizontal line

	

.offsetGeneralLine:
	;our line is not horizontal (general case)
	;first compute k=(x1-x2)/(y1-y2)
	ffree st0  ;cleanup from fcomip

	;compute k=(x1-x2)/(y1-y2)
	fld  qword [esi+8] 
	fsub qword [esi+24] 
	fld  qword [esi] 
	fsub qword [esi+16]   ;st0=x1-x2, st1=y1-y2
	fdiv st1              ;st0=k, st1=y1-y2
	fmul st0              ;st0=k^2, st1=y1-y2
	fld1                  ;st0=1.0, st1=k^2, st2=y1-y2
	fadd st1              ;st0=1+k^2, st1=k^2, st2=y1-y2
	fld qword [ebx]       ;st0=offset, st1=1+k^2, st2=k^2, st3=y1-y2
	fmul st0              ;st0=offset^2, st1=1+k^2, st2=k^2, st3=y1-y2
	fdiv st1              ;st0=offset^2/1+k^2, st1=1+k^2, st2=k^2, st3=y1-y2
	fsqrt        
	;st0=dx=sqrt(offset^2/(1+k^2)), st1=1+k^2, st2=k^2, st3=y1-y2
	fstp qword [offset_DX]  ;st0=1+k^2, st1=k^2, st2=y1-y2
	ffree st0
	ffree st1
	ffree st2
	fldz
	fld qword [ebx]  ;st0=offset, st1=0.0
	fcomip st1       ;cmp offset with 0.0
	jc .doNegativeOffset
	;offset>0.0
	ffree st0
	fld  qword [esi] 
	fadd qword [offset_DX] 
	fstp qword [edi]      ;save x3=x1+dx
	fld  qword [esi+16] 
	fadd qword [offset_DX] 
	fstp qword [edi+16]   ;save x4=x2+dx
	jmp .doY3Y4
.doNegativeOffset:
	;offset<0.0
	ffree st0
	fld  qword [esi] 
	fsub qword [offset_DX] 
	fstp qword [edi]       ;save x3=x1-dx
	fld  qword [esi+16] 
	fsub qword [offset_DX] 
	fstp qword [edi+16] q  ;save x4=x2-dx
.doY3Y4:
	fld  qword [esi+8] 
	fsub qword [esi+24]    ;st0=y1-y2
	fld  qword [esi+16] 
	fsub qword [esi]       ;st0=x2-x1, st1=y1-y2
	fld  qword [edi]       ;st0=x3, st1=x2-x1, st2=y1-y2
	fsub qword [esi]       ;st0=x3-x1, st1=x2-x1, st2=y1-y2
	fmul st1               ;st0=(x3-x1)(x2-x1)...
	fdiv st2               ;st0=(x3-x1)(x2-x1)/(y1-y2)...
	fadd qword [esi+8]     ;st0=y3=y1 + (x3-x1)(x2-x1)/(y1-y2)...
	fstp qword [edi+8]     ;save y3, st0=x2-x1, st1=y1-y2
	fld  qword [edi+16]    ;st0=x4, st1=x1-x1, st2=y1-y2
	fsub qword [esi+16]    ;st0=x4-x2, st1=x2-x1, st2=y1-y2
	fmul st1
	fdiv st2               ;st0=(x4-x2)(x2-x)/(y1-y2)...
	fadd qword [esi+24]    ;st0=y4=y2 + (x4-x2)(x2-x1)/(y1-y2)...
	fstp qword [edi+24]    ;save y4, st0=x2-x1, st=y1-y2
	ffree st0
	ffree st1

.done:
	pop ebx
	pop edi
	pop esi
	pop ebp
	retn 12



 
;***********************************************
;inflaterect
;increase the size of a rectangle

;if x1,y1 is not the upper left
;this function will make it so 
;x1,y1 will end up being upper left 
;x2,y2 will end up being lower right
;same as ptinrect
;all units are pixels

;input: 
;esi = starting address of x1,y1,x2,y2 
;      the 4 dwords must be consecutive in memory
;edi = amount to inflate 

;return: the original x1,y1,x2,y2 values
;        are overwritten with inflated values
;**********************************************

inflaterect:

	push ebp
	mov ebp,esp
	sub esp,16
	;[ebp-4]  ;x1 temporary
	;[ebp-8]  ;y1 temporary
	;[ebp-12] ;x2 temporary
	;[ebp-16] ;y2 temporary

	push eax
	push ebx
	

	;compare x2 and x1 
	mov eax,[esi+8]   ;eax=x2
	mov ebx,[esi+0]   ;ebx=x1
	cmp eax,ebx       ;x2-x1
	jge .1 

	;x2<x1
	mov [ebp-12],ebx  
	add [ebp-12],edi  ;x2=x1+inflate
	mov [ebp-4],eax   
	sub [ebp-4],edi   ;x1=x2-inflate
	jmp .2


.1: ;(x2>=x1)
	mov [ebp-12],eax   
	add [ebp-12],edi  ;x2=x2+inflate
	mov [ebp-4],ebx   
	sub [ebp-4],edi   ;x1=x1-inflate


.2:
	;done with x
	;now deal with Y

	;compare y2 and y1
	mov eax,[esi+12]  ;eax=y2
	mov ebx,[esi+4]   ;ebx=y1
	cmp eax,ebx       ;y2-y1
	jge .3 

	;y2<y1
	mov [ebp-16],ebx 
	add [ebp-16],edi  ;y2=y1+inflate
	mov [ebp-8],eax  
	sub [ebp-8],edi   ;y1=y2-inflate
	jmp .4


.3: ;(y2>=y1)
	mov [ebp-16],eax   
	add [ebp-16],edi  ;y2=y2+inflate
	mov [ebp-8],ebx   
	sub [ebp-8],edi   ;y1=y1-inflate


.4:
	;write return values back to user memory
	mov eax,[ebp-4]  ;x1 new
	mov [esi+0],eax  ;write it back

	mov eax,[ebp-8]  ;y1 new
	mov [esi+4],eax  ;write it back

	mov eax,[ebp-12] ;x2 new
	mov [esi+8],eax  ;write it back

	mov eax,[ebp-16] ;y2 new
	mov [esi+12],eax ;write it back
	
	pop ebx
	pop eax
	mov esp,ebp  ;deallocate locals
	pop ebp
	ret




