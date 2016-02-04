;tatOS/tlib/math.s

;Sept 2015

;putvectord, putvectorq, q2d, dotproduct, crossproduct
;getlength, getslope, getangleinc, getnormal
;mmult44, mmult41, sign, hypot, pow, absval
;floor, toggle, min, max, checkrange, arccos
;bytes2blocks


;see also polar.s and geometry.s


;most math/trig functions operate on double precision floating point
;values referred to as "qword". Each qword is 8 bytes.
;Single precision dword floats are not supported by tatOS.

;Many functions return a value in st0. 
;The calling function is responsible to clean this up via ffree or a fpu pop.

;The array x1,y1,x2,y2 describes the starting and ending
;points of a line segment (vector) as double precision floating point 

;A "qword" vector is an array of 4 qword floats taking 32 bytes: x1,y1,x2,y2
;A "dword" vector is an array of 4 dword ints   taking 16 bytes

;any function which takes a vector as an argument must specify: 
;	dword (indicating signed 4 byte integer) 
;				or 
;	qword (indicating double precision 8 byte floating point)

;if esi points to the start of a dword vector:
;x1=[esi], y1=[esi+4], x2=[esi+8], y2=[esi+12]

;if esi points to the start of a qword vector:
;x1=[esi], y1=[esi+8], x2=[esi+16], y2=[esi+24]


;a few comments about notation
;********************************
;I use differant notation depending on the weather

;early functions used this style of notation
;notation if we have 2 vectors A and B:
;Ax1, Ay1 is the starting point of vector A
;Ax2, Ay2 is the ending   point of vector A
;Bx1, By1 is the starting point of vector B
;Bx2, By2 is the ending   point of vector B
;LA is the length of vector A
;LB is the length of vector B

;later functions use this style of notation:
;for endpoints I use P3 which is defined by x3,y3
;for lines I use L12 which is defined by x1,y1,x2,y2







;*************************************************
;putvectord
;display a dword vector as a solid line segment

;input
;push address of dword vector  [ebp+12]
;push color                    [ebp+8]

;return: none
;***********************************************

putvectord:

	push ebp
	mov ebp,esp
	push esi

	mov esi,[ebp+12]
	push dword SOLIDLINE
	push dword [esi]    ;x1
	push dword [esi+4]  ;y1
	push dword [esi+8]  ;x2
	push dword [esi+12] ;y2
	mov esi,[ebp+8]
	push esi            ;color
	call line

	pop esi
	pop ebp
	retn 8





;****************************************************
;putvectorq
;display a qword vector x1,y1,x2,y2
;all coordinates are dbl prec floats
;solid line only

;input
;push Address of qword vector  [ebp+12]
;push color                    [ebp+8]

;return:none

;local
putvectorq_buf times 32 db 0
;****************************************************

putvectorq:
	push ebp
	mov ebp,esp
	push esi
	push edi
	push ecx

	mov esi,[ebp+12]
	mov edi,putvectorq_buf
	mov ecx,4

	;convert 4 qwords to dwords
.convert:
	fld   qword [esi]
	fistp dword [edi]
	add esi,8
	add edi,4
	dec ecx
	jnz .convert

	;draw the line
	mov esi,putvectorq_buf
	push dword SOLIDLINE
	push dword [esi]    ;x1
	push dword [esi+4]  ;y1
	push dword [esi+8]  ;x2
	push dword [esi+12] ;y2
	mov esi,[ebp+8]
	push esi            ;color
	call line

	pop ecx
	pop edi
	pop esi
	pop ebp
	retn 8
	



;*******************************************************
;q2d
;convert a qword double precision 8 byte 
;floating point value to dword 4 byte value

;input
;edi=Address to store dword int result 
;st0=qword float        

;return:none, st0 is popped

;does an assembly programmer really need this function ?
;******************************************************

q2d:
	fistp dword [edi]
	ret 





;*********************************************
;dotproduct
;compute the dot (scaler) product of 2 vectors
;A dot B = ABcos(theta) = ax*bx + ay*by

;the two vectors must share a common start point

;input
;push Address of qword vector A     [ebp+12]
;push Address of qword vector B     [ebp+8]

;return
;st0=magnitude of dot product
;********************************************

dotproduct:

	push ebp
	mov ebp,esp
	push esi
	push edi

	mov esi,[ebp+12]  ;vector A
	mov edi,[ebp+8]   ;vector B

	;get ax
	fld qword [esi+16] 
	;st0=x2
	fsub qword [esi]   
	;st0=x2-x1=ax

	;get bx
	fld qword [edi+16]
	fsub qword [edi]
	;st0=bx, st1=ax

	fmulp st1 
	;st0=ax*bx


	;get ay
	fld qword [esi+24]
	fsub qword [esi+8]
	;st0=ay, st1=ax*bx

	;get by
	fld qword [edi+24]
	fsub qword [edi+8]
	;st0=y2-y1=by, st1=ay, st2=ax*bx
	
	fmulp st1
	;st0=ay*by, st2=ax*bx

	faddp st1
	;st0=ax*bx + ay*by

	pop edi
	pop esi
	pop ebp
	retn 8






;***************************************************
;crossproduct
;determine the cross (vector) product of 2 vectors
;A cross B = A*B*sin(theta) * N = ax*by - ay*bx
;N = normal unit vector
;use right hand rule to determine direction of N

;input
;push Address of qword vector A     [ebp+12]
;push Address of qword vector B     [ebp+8]

;return
;st0=magnitude of cross product

;the sign of the cross product indicates the 
;direction of the resulting normal unit vector as follows:
;    (+) out of page
;    (-) into page


;             2
;             * 
;             *  A
;             * 
;        B    *
;     2*******1
;            *
;           *
;          *  +N
;         *
       
;  as shown, A cross B is > 0   (N out of page)
;  as shown, B cross A is <  0  (N into page)
;  A cross B == 0 if the two vectors are parallel
;  use right hand rule (ccw)

;geometric significance: 
;the magnitude of the cross product is equal
;to the area of a parallelagram with sides A & B
;**************************************************

crossproduct:

	push ebp
	mov ebp,esp
	push esi
	push edi

	mov esi,[ebp+12]  ;vector A
	mov edi,[ebp+8]   ;vector B

	;get ax
	fld qword [esi+16] 
	;st0=x2
	fsub qword [esi]   
	;st0=x2-x1=ax

	;get by
	fld qword [edi+24]
	;st0=y2, st1=ax
	fsub qword [edi+8]
	;st0=y2-y1=by, st1=ax
	
	fmulp st1 
	;st0=ax*by


	;get ay
	fld qword [esi+24]
	fsub qword [esi+8]
	;st0=ay, st1=ax*by

	;get bx
	fld qword [edi+16]
	fsub qword [edi]
	;st0=bx, st1=ay, st2=ax*by

	fmulp st1
	;st0=ay*bx, st2=ax*by

	fsubp st1
	;st0=ax*by - ay*bx
	
	pop edi
	pop esi
	pop ebp
	retn 8



;**************************************************
;getslope
;returns dx,dy of a qword vector

;input
;push address of qword vector x1,y1,x2,y2  [ebp+8]

;return
;st0=qword dx=x2-x1
;st1=qword dy=y2-y1
;user is responsible to cleanup st0,st1

;note to compute the angle in radians you can
;immediately do fpatan after this function.
;st0 = angle,radians = atan2(dy/dx) 
;st1 is freed by fpatan

;you can also get the length of the vector by
;immediately following with a call to getlength
gs_str1 db 'getslope: dy,dx',0
;**************************************************

getslope:

	push ebp
	mov ebp,esp
	push esi

	;STDCALL gs_str1,dumpstr

	mov esi,[ebp+8]

	;work on dy
	fld qword [esi+24]  ;st0=y2
	fld qword [esi+8]  	;st0=y1, st1=y2
	fsubp st1 	        ;st0=dy

	;work on dx
	fld qword [esi+16]
	fld qword [esi]
	fsubp st1          ;st0=dx, st1=dy
	
	pop esi
	pop ebp
	retn 4




;**************************************************
;getlength
;compute the Length of a qword vector
;Length=sqrt(dx^2 + dy^2)

;input: st0=dx, st1=dy   (use getslope)

;return: st0=qword Length 
;user is responsible to cleanup st0
;**************************************************

getlength:

	fmul st0   ;st0=dx^2, st1=dy
	fxch st1   ;st0=dy, st1=dx^2
	fmul st0   ;st0=dy^2, st1=dx^2
	faddp st1  ;st0=dy^2 + dx^2
	fsqrt      ;st0=Length=sqrt(dx^2 + dy^2)

	ret





;**************************************************
;getangleinc
;computes the included angle between 2 vectors

;             B            
;            *
;           * included 
;          *  angle
;         *      
;        *      
;       * * * * * * * * A

;the vectors must share a common start point
;this version used the dot product method


;input
;push Address of qword vector A     [ebp+12]
;push Address of qword vector B     [ebp+8]

;return
;st0=angle,radians

;locals
gia_str1 db 'getangleinc',0
gia_str2 db 'leaving getangleinc',0
;************************************************

getangleinc:

	STDCALL gia_str1,dumpstr	

	push ebp
	mov ebp,esp
	push esi
	push edi

	;compute the dot product
	mov esi,[ebp+12]  ;address vectorA
	mov edi,[ebp+8]   ;address vectorB
	push esi
	push edi
	call dotproduct
	;returns result in st0

	;compute length of vectorA = LA
	push esi
	call getslope
	;st0=dx, st1=dy, st2=dotproduct
	call getlength
	;st0=LA, st1=dotproduct

	;compute length of vectorB = LB
	push edi
	call getslope
	;st0=dx, st1=dy, st2=dotproduct
	call getlength
	;st0=LB, st1=LA, st2=dotproduct

	;compute (dotproduct)/LA/LB
	fxch st2
	;st0=dotproduct, st1=LA, st2=LB
	fdiv st1
	;st0=dotproduct/LA, st1=LA, st2=LB
	fdiv st2
	;st0=dotproduct/LA/LB, st1=LA, st2=LB
	ffree st1
	ffree st2

	;compute the arccos = included angle
	call arccos
	;st0=arccos(dotproduct/LA/LB) = angle in radians return value
	call dumpst09

	pop edi
	pop esi
	pop ebp
	;returns included angle in st0
	retn 8



;*********************************************************
;getnormal
;returns the x,y coordinates of the tip of a vector 
;with unit length, tail at 0,0 and direction which is 
;perpendicular to a given vector A.
;standing at Ax1 looking at Ax2, the normal vector points 
;off to the left

;input
;push Address of qword vector A         [ebp+12]
;push Address of 16 byte results buffer [ebp+8]

;return
;the following is written to the results buffer:
;qword Nx2, tip of normal vector
;qword Ny2, tip of normal vector
;*********************************************************

getnormal:

	push ebp
	mov ebp,esp
	push esi
	push edi

	mov esi,[ebp+12]
	mov edi,[ebp+8]

	push esi
	call getslope
	call getlength
	;st0=Length


	;work on normal tip X
	;*********************
	fld qword [esi+24]
	;st0=Ay2  st1=Length

	fsub qword [esi+8]
	;st0=Ay2-Ay1  st1=Length

	fdiv st1
	;st0=(Ay2-Ay1)/Length, st1=Length

	fchs
	;st0=-(Ay2-Ay1)/Length, st1=Length


	;save normal x2
	fstp qword [edi]
	;st0=Length


	;work on normal tip Y
	;*********************
	fld qword [esi+16]
	;st0=Ax2  st1=Length

	fsub qword [esi]
	;st0=Ax2-Ax1  st1=Length

	fdiv st1
	;st0=(Ax2-Ax1)/Length, st1=Length

	;save normal y2
	fstp qword [edi+8]

	ffree st0

	pop edi
	pop esi
	pop ebp
	retn 8
	
 


;******************************************************
;mmult44
;matrix multiply
;multiply a 4x4 matrix by another 4x4 matrix
;a |4x4| times |4x4| yields another |4x4|
;16 qwords are written to matrix_C

;C = A*B 
;C(i,j) = Summation(k=0->3) A(i,k) * B(k,j)
;the first row=0 and first col=0

;input
;esi=Address of matrix_A 
;edi=Address of matrix_B 
;ebx=Address of destination matrix_C
;return: 16 qwords are written to matrix_C

;a 4x4 matrix must be stored in memory as follows:
;matrix_A:
;dq A00,A01,A02,A03
;dq A10,A11,A12,A13
;dq A20,A21,A22,A23
;dq A30,A31,A32,A33

;to access any element in the 4x4 array  = [matrix_A + offset]
;where offset = 8*(row*4 + column)
;both row and col are 0,1,2,3

;this function is used to combine translations and rotation 
;matrices into 1 transformation matrix

;example
;|0 -1  7  6 |   |-2  2  5 -2 |   |20 32 42  9|
;|3  2  3  2 | * | 6 -2  0  4 | = |16 12 33  7|
;|3  4 -1  4 |   | 2  0  6  1 |   |24 18  9 13|
;|6  1  6  3 |   | 2  5  0  1 |   |12 25 66  1|
;note all matrix elements must be double precision floats

;local:
matrix_C dd 0
;******************************************************

mmult44:

	mov [matrix_C],ebx   ;save for later
	mov eax,0             ;i=0->numrow_A=4
.3:
	mov ebx,0             ;j=0->numcol_B=4
.2:
	mov edx,0             ;k=0->numcol_A or numrow_B=4
	fldz                  ;st0=0
.1:
	;load A(i,k) 
	lea ecx,[eax*4+edx]     ;ecx=i*4 + k
	lea ecx,[esi+ecx*8]     ;ecx=ArrayA + 8*(i*4 + k)
	fld qword [ecx]         ;st0=A(i,k), st1=0 or PreviousSum

	;load B(k,j) 
	lea ecx,[edx*4+ebx]     ;ecx=k*4 + j
	lea ecx,[edi+ecx*8]     ;ecx=ArrayB + 8*(k*4 + j)
	fld qword [ecx]         ;st0=B(k,j), st1=A(i,k), st2=Previous-st0
	
	fmulp st1               ;st0=A(i,k)*B(k,j), st1=Previous-st0
	faddp st1               ;st0=A(i,k)*B(k,j) + Previous-st0

	inc edx                 ;k++
	cmp edx,4
	jb .1                   ;end inner loop on k

	;save C(i,j)
	lea ecx,[eax*4+ebx]     ;ecx=i*4+j
	shl ecx,3               ;ecx=8*(i*4+j)
	add ecx,[matrix_C]      ;ecx=matrix_C + 8*(i*4+j)
	fstp qword [ecx]        ;save C(i,j) and pop off st0

	inc ebx
	cmp ebx,4
	jb .2                   ;end middle loop on j

	inc eax
	cmp eax,4
	jb .3                   ;end outer loop on i

	ret




;*********************************************************
;mmult41
;matrix multiply
;multiply a 4x4 matrix by a 4x1 column vector
;a |4x4| times |4x1| yields |4x1|
;4 qwords are written to vector_C

;input
;esi=Address of matrix_A (must be 4 rows x 4 columns)
;edi=Address of vector_B (must be 4 rows x 1 column)
;ebx=Address of destination vector_C
;return: 4 qwords are written to vector_C

;this function is used to apply the transformatinon
;matrix to every vertex of your 3d model

;C(i) = Summation(j=0->3) A(i,j) * B(j)

;example:
;|1  2  3  4 |   |1|   |30 |
;|5  6  7  8 | * |2| = |70 |
;|9  10 11 12|   |3|   |110|
;|13 14 15 16|   |4|   |150|
;note all matrix elements must be double precision floats
;**********************************************************

mmult41:
	pushad

	mov eax,0             ;i=0->3
.2:
	mov edx,0             ;j=0->3
	fldz                  ;st0=0
.1:
	;load A(i,j) 
	lea ecx,[eax*4+edx]     ;ecx=i*4 + j
	lea ecx,[esi+ecx*8]     ;ecx=ArrayA + 8*(i*4 + j)
	fld qword [ecx]         ;st0=A(i,j), st1=0 or PreviousSum

	;load B(j) 
	lea ecx,[edi+edx*8]     ;ecx=vectorB + 8*(j)
	fld qword [ecx]         ;st0=B(j), st1=A(i,j), st2=PreviousSum
	
	fmulp st1               ;st0=A(i,j)*B(j), st1=PreviousSum
	faddp st1               ;st0=A(i,j)*B(j) + PreviousSum

	inc edx                 ;j++
	cmp edx,4
	jb .1                   ;end inner loop on j

	;save C(i)
	lea ecx,[ebx+eax*8]     ;ecx=vectorC + 8*(i)
	fstp qword [ecx]        ;save C(i) and pop off st0

	inc eax
	cmp eax,4
	jb .2                   ;end outer loop on i
	
	popad
	ret



;**************************************
;sign
;compute the sign of the number
;input:
;eax=signed dword to be checked
;return:
;eax = 1 if value is 0 or positive
;eax =-1 if value is negative
;*************************************

sign:
	push ebx
	xor ebx,ebx
	;sar is one of those instructions I rarely use but should get used to
	;its a shift right and fill the vacated bits with copies of bit31
	;so it operates on signed numbers
	;so here for example:
	;if eax>0 then bit31=0 and sar eax,31 leaves eax=0
	;if eax<0 then bit31=1 and sar eax,31 leaves eax=0xffffffff
	;             eax>0       eax<0
	sar eax,31   ;eax=0       eax=0xffffffff=-1
	;technically we could stop here and say if eax>=0 then we return eax=0
	;and if eax<0 then we return eax=-1 
	;the remaining code is just required to return eax=1 if eax was + or 0
	setz bl      ;ebx=1       ebx=0
	add eax,ebx  ;eax=1       eax=0xffffffff=-1
	pop ebx
	ret





;********************************************************
;hypot
;computes the length of hypotenuse of a right triangle
;this version can work with int dword or dblprec qword

;                      *
;                    * *
;               L  *   *
;                *     * B
;              *       *
;            * * * * * *
;                 A

;input
;push Address of length side A    [ebp+20]
;push Address of length side B    [ebp+16]
;push Address to store result L   [ebp+12]
;push Size of Values              [ebp+8]
;     0=input as dword int and return as same
;     1=input as qword dbl and return as same
;********************************************************

hypot:

	push ebp
	mov ebp,esp
	push eax
	push ebx

	;get addresses of input data
	mov eax,[ebp+20]
	mov ebx,[ebp+16]
	
	cmp dword [ebp+8],1
	jz .InputAsDbl

.InputAsInt:
	fild  dword [eax]
	fimul dword [eax]
	fild  dword [ebx]
	fimul dword [ebx]
	faddp st1
	fsqrt
	mov eax,[ebp+12]
	fistp dword [eax]
	jmp .done

.InputAsDbl:
	fld  qword [eax]
	fmul qword [eax]
	fld  qword [ebx]
	fmul qword [ebx]
	faddp st1
	fsqrt
	mov eax,[ebp+12]
	fstp qword [eax]

.done:
	pop ebx
	pop eax
	pop ebp
	retn 16






;***********************************************************
;pow
;X raise to the power Y (X^^Y)

;input
;push Address of qword X (must be > 0.000)         [ebp+16]
;push Address of qword Y                           [ebp+12]
;push Address where qword result is to be written  [ebp+8]

;"The log of a number is the power or exponent
;to which the base must be raised in order to produce
;the number".

;this function can be used to compute antilog  (10^^y)
;if N=3    then antilog(N) = 1000      (x=10, y=3)
;if N=-3.4 then anitlog(N) = .0003981  (x=10, y=-3.4)

;how does this code word ?
;1) compute yln(x) =whole.fraction
;2) split into whole and fractional parts
;3) compute 2^^whole and 2^^fraction
;4) multiply together to get result

;x^^y = 2^^[yln(x)]

;local variables
pow_controlword dw 0
pow_oldcontrolword dw 0
;*****************************************************

pow:
	push ebp
	mov ebp,esp
	push eax
	fsave [_fpustate] 
	
	;comments are based on x=10 and y=3 so we compute 10^^3 = 1000.00

	mov eax,[ebp+12]
	fld qword [eax]  
	;st0=Y

	mov eax,[ebp+16]
	fld qword [eax]  
	;st0=X, st1=Y

	fyl2x   
	;st0=yln(x)=3*3.322 = 9.966  


	;set rounding mode to truncate
	fstcw word [pow_controlword]
	;save for later restoration
	mov ax,[pow_controlword]
	mov [pow_oldcontrolword],ax
	;set bits 10,11 for truncate to 0
	or word [pow_controlword],0xc00
	fldcw word [pow_controlword]
	

	fld st0
	;st0=st1=9.966

	frndint    ;round st0 
	;st0=9.000, st1=9.966


	fsub st1,st0
	;st0=9.000, st1=0.966

	fxch st0,st1

	f2xm1      ;2^^x - 1, st0 must be 0->1.000
	;st0=0.953, st1=9.000


	fld1
	;st0=1.000, st1=0.953, st2=9.000

	faddp st1    ;add 1 to st1 then pop
	;st0=1.953, st1=9.000	


	fscale       ;round st1 toward 0 then st0=st0*2^^st1
	;st0=1000.00, st1=9.000


	;the final answer X^^Y is in st0
	mov eax,[ebp+8]

	;save final answer to users memory
	fst qword [eax]


	;restore rounding mode
	fldcw word [pow_oldcontrolword]	


	frstor [_fpustate] 
	pop eax
	pop ebp
	retn 12




;******************************************
;absval
;absolute value
;this comes from John Eckerdal, assy gems
;tat modified for 32bit 
;input:eax
;return:eax=|eax|
;******************************************

absvalB:    ;for userland 
	mov eax,ebx
absval:

	push edx
	mov edx,eax

	;sar will fill edx with the top bit of edx
	;if eax>0 then edx=0 
	;if eax<0 then edx=-1 (0xffffffff)
	sar edx,31

	;this xor will return a positive result in eax
	;if edx=0  then eax=eax
	;if edx=-1 then eax=|eax|-1
	xor eax,edx
	
	;if edx=0 then eax=eax
	;if edx=-1 then eax=(|eax|-1) - (-1) 
	sub eax,edx

	pop edx
	ret



;****************************************
;floor
;returns a value in eax 
;which is less than (or = to) the original value in ebx 
;and is a multiple of the value in ecx

;input
;ebx=original value
;ecx=divisor (2,4,10,whatever)

;result
;return value in eax (may be same as orignal)

;example:
;find a multiple of 10 value less than 252
;ebx=252, ecx=10, returns eax=0xfa=250

;example:
;if ebx=252 and ecx=3 then returns eax=252

;example
;if ebx=252 and ecx=7 then returns eax=245
;******************************************

floor:
	xor edx,edx
	mov eax,ebx
	div ecx      ;edx:eax/ecx, quotient in eax
	mul ecx      ;edx:eax = eax*ebx
	ret





;***************************************
;toggle
;flip all the bits then mask off so
;the value varies from 0,1,0,1,0,1...
;for dword only
;input
;ebx=address of value in memory to toggle
;***************************************

toggle:
	not dword [ebx]
	and dword [ebx],1
	ret




;*********************************************
;min
;determine the minimum of 2 unsigned values
;code from Agner Fog Pentium Optimization Manual

;input
;ebx=first num
;ecx=second num

;return 
;ebx=min value
;*********************************************

min: 
	push edx
	sub ecx,ebx   ;c=c-b
	              ;if cf=1        if cf=0
	sbb edx,edx   ;d=0xffffffff   d=0     (edx=edx-edx-CF)
	and edx,ecx   ;d=c-b          d=0
	add ebx,edx   ;b=b+(c-b)=c    b=b+0=b
	pop edx
	ret



;*************************************************
;max
;determine maximum value of 2 numbers
;based on "max.asm" by Paul Carter
;demonstrates how to avoid conditional branches

;input
;eax=first value
;ebx=second value

;return
;ecx=max value
;************************************************

max:
	push edx
	xor edx,edx
	cmp ebx,eax
	setg dl
	neg edx
	mov ecx,edx
	and ecx,ebx
	not edx
	and edx,eax
	or ecx,edx
	pop edx
	ret
	



;*******************************************
;checkrange
;test if signed value is within range

;input
;esi=signed value to be checked
;push min value  [ebp+12]
;push max value  [ebp+8]

;return
;ZF is set on success (value is within range)
;(value >= minrange) && (value <= maxrange)

;if you dont care about the result 
;but want to clamp eax so it is >0
;but less than mask use: and eax,mask
crstr1 db 'checkrange: value is out-of-range',0
;************************************************

checkrange:

	push ebp
	mov ebp,esp
	push ebx

	cmp esi,[ebp+12]
	setge bl
	cmp esi,[ebp+8]
	setle bh
	add bl,bh
	cmp bl,2
	jz .done 	;zf is set if within range
	mov eax,esi
	STDCALL crstr1,0,dumpeax   ;dump error message

.done:
	pop ebx
	pop ebp
	ret 8
	



;*******************************************************************
;arccos
;compute the inverse cosine

;the x86 fpu does not have arccos function so we have to conjure 
;something up, could also use power series approximation

;input:  st0 = any value 'a' between -1.0->1.0 
;return: st0 = arccos(a), the angle is in radians

;if the value passed to this function was outside the range
;-1.0->1.0 then we exit and st0 is unchanged

;if the value passed to this function is < 0.0
;then we add pi to the result

;if the value passed to this function is exactly 0.0
;we return pi/2  (avoid division by 0)

;the value 'a' represents on a right triangle the ratio of the 
;length of the side adjacent over the length of the hypotanuse

;the algorithm used here was obtained from the web
;  arccos(a) = arctan [ sqrt(1 - a*a) / a ]

;warning: this function will be slow because of fdiv and fsqrt
;so avoid using this in time sensitive code

ac_str1 db '[arccos] error input outside the range -1.0->1.0',0
ac_str2 db '[arccos] comparison was indeterminate',0
;*******************************************************************

arccos:

	;reserve ebx to indicate if input value is < 0
	;if so we add pi to the result so we return a (+) angle
	mov ebx,0

	;st0=a the value user passed to this function

	;test for outside the range -1.0->1.0
	fst st1                   ;st0=a, st1=a
	fabs                      ;st0=abs(a), st1=a
	fld1                      ;st0=1.0, st1=abs(a), st2=a
	fcompp                    ;perform [1.0-abs(a)] and set fpu flags
	fstsw ax                  ;store fpu status word in ax
	sahf                      ;store ah to EFLAGS
	jpe near .error           ;comparison was indeterminate (invalid value in st0)
	ja .pos1 
	jb .neg1                
	jz .zero1

.zero1:
.pos1:
	;test for a=0.0 which would give a divide by  0 error 
	                          ;st0=a
	ftst                      ;perform (st0-0) and set fpu flags 
	fstsw ax                  ;store fpu status word in ax
	sahf                      ;store ah to EFLAGS
	jpe near .error           ;comparison was indeterminate (invalid value in st0)
	ja .pos2                 
	jb .neg2
	jz .zero2               

.zero2:
	;the value passed to this function = 0.0 so we return pi/2
	fldpi                     ;st0=pi, st1=a 
	fdiv qword [two]          ;st0=pi/2, st1=a
	ffree st1                 
	jmp .done                 ;return st0=pi/2


	;ok so we have a value that is between -1.0- and 1.0 and is not 0.0
.neg2:
	mov ebx,1  ;at the end add pi to the value
.pos2:
	fst st1    ;st0=a, st1=a
	fmul st1   ;st0=a*a, st1=a
	fld1       ;st0=1.0, st1=a*a, st2=a
	fsub st1   ;st0=1-a*a, st1=a*a, st2=a
	fsqrt      ;st0=sqrt(1-a*a), st1=a*a, st2=a
	fdiv st2   ;st0=sqrt()/a, st1=a*a, st2=a
	fld1       ;st0=1, st1=sqrt()/a, st2=a*a, st3=a
	fpatan     ;st0=arccos(a), st1=a*a, st2=a

	;do we add pi to the result ?
	cmp ebx,0
	jz .3

	;add pi to the result since the input was (-)
	fldpi     ;st0=pi, st1=arccos(a), st2=a*a, st3=a
	faddp st1 ;st0=arccos(a)+pi, st2=a*a, st3=a

.3:
	ffree st1
	ffree st2
	jmp .done


.neg1:
	STDCALL ac_str1,dumpstr
	jmp .done
.error:
	STDCALL ac_str2,dumpstr
	jmp .done
.done:
	;returns a value in st0
	ret


;***************************************************
;bytes2blocks
;determine qty of blocks needed to store
;"files" on our pen drive

;input
;eax=qty bytes
;return
;eax=qty blocks

;if qty bytes is an even multiple of 512
;then the return value will be exactly
;1 block more than necessary
;this is not a problem since we only use the
;qtyblock value to read off the pen drive
;text files are 0 terminated so we know where they end
;and executable code has its own ret statements
;and the exact size of binary data like bits files
;is known externally
;*****************************************************

bytes2blocks:

	;divide by 512 bytes/block
	shr eax,9
	inc eax
	ret





