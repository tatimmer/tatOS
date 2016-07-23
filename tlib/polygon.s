;tatOS/tlib/polygon.s

;functions to deal with polygons


;*******************************************************
;ptinpoly

;determine if a point is inside a polygon

;the polygon points array must be ordered, either cw or ccw
;as you walk around the polygon

;the polygon is assumed "closed" and the end point is the 
;the same as the start point (dont repeat the end point)
;i.e. a rectangle needs 4 points, a triangle needs 3 points ...

;x0,y0,x1,y1,x2,y2...xn,yn each x,y value is qword float
;we use the nomenclature xp(i),yp(i) for this array of points
;this function uses dbl precision floating point values
;each x,y point of the polygon and point to check is 8+8=16 bytes

;i,j are indexes into the fpu array
;i starts at 0 and goes 0,1,2,3...
;j starts at npol-1 and then is always 1 less than y
;so if the number of polygon points is 5 then
;j goes 4,0,1,2,3 while i goes 0,1,2,3,4

;the algo here comes from the comp.graphic.algorithms.faq
;based on the method of Franklin

;input:
;ecx=qty of points
;esi=address of polygon points array
;edi=address of x,y point to check

;return:
;eax=1 if point is inside polygon else 0 if not
;****************************************************

ptinpoly:

	push ebp
	mov ebp,esp
	sub esp,16  ;local variables
	;[ebp-4]    ;qty polygon points (qtypts)
	;[ebp-8]    ;storage for result of fpu comparison1
	;[ebp-12]   ;storage for result of fpu comparison2
	;[ebp-16]   ;storage for return value "c" that will be 1 or 0



	;save qty polygon points to local
	mov dword [ebp-4],ecx


	;init the return value "c"
	;this value will toggle from 0,1,0,1,0...
	;we toggle this depending on the calcs below
	;when done looping, the final value is the return value
	mov dword [ebp-16],0


	;in this loop i and j refer to a point index
	;if i=0 then x0,y0
	;if i=1 then x1,y1
	;and so on



	;init j
	mov edx,ecx  ;edx=qtypts
	sub edx,1    ;j=qtypts-1


	;init i
	mov ecx,0


	;load y into the fpu
	fld qword [edi+8]  ;st0=y


	;load x into the fpu
	fld qword [edi]    ;st0=x, st1=y





.1:  


	;top of loop

	;must preserve the following registers
	;ecx=i
	;edx=j
	;esi=address of points array


	;load yp(i) into fpu
	mov eax,ecx ;eax=i
	shl eax,4   ;i*16
	add eax,8   ;i*16 + 8
	mov ebx,esi 
	add ebx,eax ;ebx=address of yp(i)
	fld qword [ebx]  ;st0=yp(i), st1=x, st2=y


	;load xp(i) into fpu
	mov eax,ecx ;eax=i
	shl eax,4   ;i*16
	mov ebx,esi 
	add ebx,eax ;ebx=address of xp(i)
	fld qword [ebx]  ;st0=xp(i), st1=yp(i), st2=x, st3=y


	;load yp(j) into fpu
	mov eax,edx ;eax=j
	shl eax,4   ;j*16
	add eax,8   ;j*16 + 8
	mov ebx,esi 
	add ebx,eax ;ebx=address of yp(j)
	fld qword [ebx]  
	;st0=yp(j), st1=xp(i), st2=yp(i), st3=x, st4=y



	;load xp(j) into fpu
	mov eax,edx ;eax=j
	shl eax,4   ;j*16
	mov ebx,esi 
	add ebx,eax ;ebx=address of xp(j)
	fld qword [ebx]
	;st0=xp(j), st1=yp(j), st2=xp(i), st3=yp(i), st4=x, st5=y




	fxch st3  ;swap st0 and st3
	;st0=yp(i), st1=yp(j), st2=xp(i), st3=xp(j), st4=x, st5=y




	;compare [yp(i) > y] = "A"
	fcomi st5
	jnc .2

	;yp(i) is less than or equal to y
	mov dword [ebp-8],0
	jmp .3

.2:  
	;yp(i) is greater than y
	mov dword [ebp-8],1



.3:
	fxch st1  ;swap st0 and st1
	;st0=yp(j), st1=yp(i), st2=xp(i), st3=xp(j), st4=x, st5=y



	;compare [yp(j) > y] = "B"
	fcomi st5
	jnc .4

	;yp(j) is less than or equal to y
	mov dword [ebp-12],0
	jmp .5

.4:  ;yp(j) is greater than y
	mov dword [ebp-12],1


.5:
	;compare A and B for inequalty
	mov eax,[ebp-8]
	cmp eax,[ebp-12]
	jnz .6

	;if we got here, A and B are equal so we are done with this i,j
	;free st0,st1,st2,st3 for the next loop
	ffreep st0
	ffreep st0
	ffreep st0
	ffreep st0
	;st0=x, st1=y

	jmp .9


	


.6:  

	;A and B are NOT equal
	;so we must continue on with a big calculation
	;we must compare x with the following term:

	;[xp(j)-xp(i)][y-yp(i)]
	;***********************  +  xp(i)
	;      yp(j)-yp(i)

	;if x is less than the above term then we toggle the return value
	
	;st0=yp(j), st1=yp(i), st2=xp(i), st3=xp(j), st4=x, st5=y

	fsub st1  
	;st0=yp(j)-yp(i), st1=yp(i), st2=xp(i), st3=xp(j), st4=x, st5=y

	fld st5
	;st0=y, st1=yp(j)-yp(i), st2=yp(i), st3=xp(i), st4=xp(j),
	;st5=x, st6=y

	fsub st2
	;st0=y-yp(i), st1=yp(j)-yp(i), st2=yp(i), st3=xp(i), st4=xp(j),
	;st5=x, st6=y

	fxch st4
	;st0=xp(j), st1=yp(j)-yp(i), st2=yp(i), st3=xp(i),
	;st4=y-yp(i), st5=x, st6=y

	fsub st3
	;st0=xp(j)-xp(i), st1=yp(j)-yp(i), st2=yp(i), st3=xp(i),
	;st4=y-yp(i), st5=x, st6=y

	fmul st4
	;st0=[xp(j)-xp(i)]*[y-yp(i)]
	;st1=yp(j)-yp(i), st2=yp(i), st3=xp(i), st4=y-yp(i), st5=x, st6=y

	fdiv st1
	;st0=[xp(j)-xp(i)]*[y-yp(i)] / [yp(j)-yp(i)]
	;st1=yp(j)-yp(i), st2=yp(i), st3=xp(i), st4=y-yp(i), st5=x, st6=y

	fadd st3
	;st0=[[xp(j)-xp(i)]*[y-yp(i)] / [yp(j)-yp(i)]] + xp(i)
	;st1=yp(j)-yp(i), st2=yp(i), st3=xp(i), st4=y-yp(i), st5=x, st6=y




	;compare [st0 > x]
	fcomi st5
	jnc .7

	;st0 is less than or equal to x
	;we do not toggle "c" return value
	jmp .8

.7:  
	;st0 is greater than x
	;we must toggle "c" return value
	mov eax,[ebp-16]
	not eax            ;flip all the bits
	and eax,1          ;mask off all bits to 0 except bit0
	mov [ebp-16],eax   ;save it


.8:
	;free st0,st1,st2,st3,st4 after dealing with Big Calc
	ffreep st0
	ffreep st0
	ffreep st0
	ffreep st0
	ffreep st0
	;st0=x, st1=y




.9: 
	;increment some things for the next loop

	add ecx,1  ;i++

	;does i=qtypts ?
	cmp ecx,[ebp-4]
	jz .done  ;this is our normal exit

	;inc j
	cmp ecx,1   ;does i=1 ?
	jz .10
	add edx,1   ;j++
	jmp .1      ;top of loop

.10:
	mov edx,0   ;j=0
	jmp .1      ;top of loop
	;end of loop




.done:

	;free x,y from the fpu
	ffree st0
	ffree st1

	;put return value "c" in eax
	mov eax,[ebp-16]

	mov esp,ebp  ;deallocate locals
	pop ebp
	ret

         

  
