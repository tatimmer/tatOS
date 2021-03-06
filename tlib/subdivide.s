;tatOS/tlib/subdivide.s

;************************************************************
;subdivide
;generate a new array of points from a given array of points
;by subdividing the original array into smaller and smaller
;line segments. This is a polyline smoothing/corner clipping
;operation. Also may be thought of as a spline generator.
;We iterate 3 times using the fpu to produce a smooth curve. 

;note this function does not draw to the screen
;the polyline function may be used to display these points
;as a series of line segments

;a "point" consists of a dword X and dword Y coordinate
;each point takes up 2 dwords or 8 bytes in memory

;the final number of points generated by this function is (8N-14) points 
;N is the original number of points
;this function requires you to allocate 200,000 bytes for the destination points

;we loop 3x each time the number of points increases by 2 less 
;than twice the original number of points
;start with N qtypoints
;after 1st pass we have 2N-2 qtypoints
;after 2nd pass we have 4N-6 qtypoints
;after 3rd pass we have 8N-14 qtypoints

;input
;push Address of source array dword Points       [ebp+16]
;push N qty points in source                     [ebp+12]
;push Address of 200,000 byte Destination array  [ebp+8]

;return:none

;locals
sub_qtyptsLess2 dd 0
sub_loopcount   dd 0
sub_num25  dq 0.25
sub_num75  dq 0.75
sub_xa     dq 0.0
sub_ya     dq 0.0
sub_xb     dq 0.0
sub_yb     dq 0.0
;our memory buffers, each are ptrs to 100,000 bytes 
subuf1 dd 0
subuf2 dd 0
substr1 db 'subdivide',0
substr2 db 'subdivide:Destination',0
;**************************************************************

subdivide:

	push ebp
	mov ebp,esp

	STDCALL substr1,dumpstr

	;get userland pointer to destination memory
	mov edi,[ebp+8]

	;set esi=Address of destination array
	mov esi,edi


	;save our sub-buffer addresses
	;we read and write to these alternately
	mov [subuf1],esi
	add esi,100000
	mov [subuf2],esi


	;read in the dword points and convert to qword float
	mov ecx,[ebp+12] ;qty points
	shl ecx,1        ;qty dwords
	mov esi,[ebp+16] ;source 
	mov edi,[subuf1] ;destination
.readAndConvert:
	fild dword [esi]
	fstp qword [edi]
	add esi,4
	add edi,8
	loop .readAndConvert


	cld
	mov dword [sub_loopcount],0

.OuterLoop:

	;set up esi and edi and qtyptsLess2 for loop stop
	cmp dword [sub_loopcount],0
	jz .FirstPass
	cmp dword [sub_loopcount],1
	jz .SecondPass
	cmp dword [sub_loopcount],2
	jz .ThirdPass
	jmp .ConvertFloatToInt


.FirstPass:
	mov esi,[subuf1]  ;read from
	mov edi,[subuf2]  ;write to
	mov eax,[ebp+12]
	sub eax,2         ;N-2
	mov [sub_qtyptsLess2],eax   ;in src array to loop on
	xor ecx,ecx
	jmp .InnerLoop

.SecondPass:
	mov esi,[subuf2]  ;read from
	mov edi,[subuf1]  ;write to
	mov eax,[ebp+12]
	shl eax,1         ;2N
	sub eax,4         ;2N-4
	mov [sub_qtyptsLess2],eax 
	xor ecx,ecx
	jmp .InnerLoop

.ThirdPass:
	mov esi,[subuf1]
	mov edi,[subuf2]
	mov eax,[ebp+12]
	shl eax,2   ;4N
	sub eax,8   ;4N-8
	mov [sub_qtyptsLess2],eax 
	xor ecx,ecx



.InnerLoop:

	;x1,y1,x2,y2 are the start and endpoints of 
	;the current segment being considered
	;xa,ya,xb,yb are new points on the current segment
	;point a is 25% from point 1 
	;point b is 25% from point 2



	;compute xa = x1 + 0.25(x2-x1)
	;*******************************

	fld qword [esi]
	fld qword [esi+16]
	;st0=x2, st1=x1


	fsub st1
	;st0=x2-x1, st1=x1

	fst st2
	;st0=x2-x1, st1=x1, st2=x2-x1

	fld qword [sub_num25]
	fmulp st1
	;st0=0.25(x2-x1) ...

	fadd st1
	;st0=x1+0.25(x2-x1) ...

	fstp qword [sub_xa]
	fxch st1
	;st0=x2-x1, st1=x1



	;compute xb = x1 + 0.75(x2-x1)
	;*******************************

	fld qword [sub_num75]
	fmulp st1
	;st0=0.75(x2-x1), st1=x1
	
	fadd st1
	;st0=x1+0.75(x2-x1)

	fstp qword [sub_xb]
	ffree st0



	;compute ya = y1 + 0.25(y2-y1)
	;same code as for xa except for the fld offset
	;*******************************

	fld qword [esi+8]
	fld qword [esi+24]
	;sto=y2, st1=y1
	fsub st1
	fst st2
	fld qword [sub_num25]
	fmulp st1
	fadd st1
	fstp qword [sub_ya]
	fxch st1


	;compute yb = y1 + 0.75(y2-y1)
	;*******************************

	fld qword [sub_num75]
	fmulp st1
	fadd st1
	fstp qword [sub_yb]
	ffree st0



	;test for startline or endline
	cmp ecx,0 
	jz near .doStartLine
	cmp ecx,[sub_qtyptsLess2]
	jz near .doEndLine



	;compute points for intermediate line
	fld  qword [sub_xa]
	fstp qword [edi]
	fld  qword [sub_ya]
	fstp qword [edi+8]
	fld  qword [sub_xb]
	fstp qword [edi+16]
	fld  qword [sub_yb]
	fstp qword [edi+24]

	add esi,16  ;inc by 1 FloatingPoint or 16 bytes
	add edi,32  ;inc by 2 FloatingPoints or 32 bytes
	inc ecx
	jmp .InnerLoop
	
	
.doStartLine:
	fld  qword [esi]   ;x1
	fstp qword [edi]
	fld  qword [esi+8] ;y1
	fstp qword [edi+8]
	fld  qword [sub_xb]
	fstp qword [edi+16]
	fld  qword [sub_yb]
	fstp qword [edi+24]

	add esi,16
	add edi,32
	inc ecx
	jmp .InnerLoop


.doEndLine:
	fld  qword [sub_xa]
	fstp qword [edi]
	fld  qword [sub_ya]
	fstp qword [edi+8]
	fld  qword [esi+16]  ;x2
	fstp qword [edi+16]  
	fld  qword [esi+24]  ;y2
	fstp qword [edi+24]


	inc dword [sub_loopcount]
	jmp .OuterLoop
	


.ConvertFloatToInt:

	;for the benefit of polyline we read in each qword float
	;and write back as dword int	
	mov esi,[subuf2]  ;read from
	mov edi,[subuf1]  ;write to
	mov ecx,[ebp+12]
	shl ecx,3         ;8N
	sub ecx,14        ;8N-14 final qty floating points
	shl ecx,1         ;2*(8N-14) final qty x,y coordinates

.Convert:
	fld   qword [esi]   ;load the qword float
	fistp dword [edi]   ;save as dword int 
	add esi,8   ;inc by qword or 8 bytes
	add edi,4   ;inc by dword or 4 bytes
	loop .Convert
	

.done:
	pop ebp
	retn 12 


