;tatOS/tlib/clipping.s


;lineclip, cliprect



;*******************************************************************
;lineclip
;this is Liang-Barsky Line Clipping
;uses floating point parametric equations
;any attempt to draw lines off screen will result in a Bresenham crash
;this function computes the x,y coordinates of any line that crosses 
;the left/top/right/bottom border of a 800x600 pixel screen

;input: 
;esi=starting address of UNclipped line endpoints in memory
;    stored consecutively as x1,y1,x2,y2 (16 bytes reqd)
;    x1=[esi], y1=[esi+4], x2=[esi+8], y2=[esi+12]
;    these are dword pixel coordinates
;ebp=starting address of where this function writes CLipped endpoints to
;    these are stored consecutively as x1,y1,x2,y2 (16 bytes reqd)
;    x1=[ebp+0], y1=[ebp+4], x2=[ebp+8], y2=[ebp+12]

;return: 
;success: eax=0 and clipped endpoints are written to ebp, line may be drawn
;failure: eax returns a non zero value, this line should not be drawn
;         eax=1 general clipping error
;         eax=2 zero length line  
;         eax=3 trivial reject, both endpoints not visible


;note this function does not preserve any registers

;locals
clipStartVisible:
dd 0
clipEndVisible:
dd 0
P1_clip_saved:
dd 0
clipScreenHeight:
dq 600.0
clipScreenWidth:
dq 800.0
;*********************************************************************

lineclip:



	;init
	mov dword [clipStartVisible],1 
	mov dword [clipEndVisible],1  
	mov dword [P1_clip_saved],0 



	;test for zero length line which will crash breshenham
	mov eax,[esi+8]  
	sub eax,[esi]   
	cmp eax,0       ;dx=0 ?
	jnz .doneZeroLengthLine
	mov eax,[esi+12]
	sub eax,[esi+4] 
	cmp eax,0       ;dy=0 ?
	jz near .ClipZeroLengthLine
.doneZeroLengthLine:




	;if we got here the line is not zero length


	;Visibility Test for P1
	;is x1 visible (within range 0-799)
	cmp dword [esi],0     ;x1>0 ?   
	setge bl
	cmp dword [esi],799   ;x1<799 ?
	setle bh
	add bl,bh
	cmp bl,2
	jnz .P1NotVisible
	;is y1 visible (within range 0-599)
	cmp dword [esi+4],0 
	setge bl
	cmp dword [esi+4],599 
	setle bh
	add bl,bh
	cmp bl,2
	jz .P1Visible
.P1NotVisible:
	mov dword [clipStartVisible],0 
	jmp .DoneP1visibility
.P1Visible:
	mov dword [clipStartVisible],1 
.DoneP1visibility:




	;Visibility Test for P2
	cmp dword [esi+8],0 
	setge bl
	cmp dword [esi+8],799 
	setle bh
	add bl,bh
	cmp bl,2
	jnz .P2NotVisible
	;is y2 visible
	cmp dword [esi+12],0 
	setge bl
	cmp dword [esi+12],599 
	setle bh
	add bl,bh
	cmp bl,2
	jz .P2Visible
.P2NotVisible:
	mov dword [clipEndVisible],0  
	jmp .DoneP2visibility
.P2Visible:
	mov dword [clipEndVisible],1  
.DoneP2visibility:



	;now if both start and end are visible 
	;there is no need for clipping

	mov eax,[clipStartVisible]
	add eax,[clipEndVisible]
	cmp eax,2  ;a value of 2 indicates both visible
	jnz .TestForTrivialReject

	;Trivial Accept
	;both start and end are visible
	;so skip our line clipping routine and draw the line
	mov eax,[esi]
	mov [ebp+0],eax
	mov eax,[esi+4]
	mov [ebp+4],eax
	mov eax,[esi+8]
	mov [ebp+8],eax
	mov eax,[esi+12]
	mov [ebp+12],eax
	jmp .ClipSuccess




.TestForTrivialReject:
	;there are 4 cases where both endpoints are not visible
	;and a line can not be drawn
	;if y1 and y2 are both > 599 or both less than 0
	;if x1 and x2 are both > 799 or both less than 0

	cmp dword [esi+4],599 
	setg bl
	cmp dword [esi+12],599 
	setg bh
	add bl,bh
	cmp bl,2
	jz near .ClipTrivialReject

	cmp dword [esi+4],0 
	setl bl
	cmp dword [esi+12],0 
	setl bh
	add bl,bh
	cmp bl,2
	jz near .ClipTrivialReject

	cmp dword [esi],799 
	setg bl
	cmp dword [esi+8],799 
	setg bh
	add bl,bh
	cmp bl,2
	jz near .ClipTrivialReject

	cmp dword [esi],0 
	setl bl
	cmp dword [esi+8],0 
	setl bh
	add bl,bh
	cmp bl,2
	jz near .ClipTrivialReject






.PrepareForClipping:

	;load dy,y1,dx,x1 into the fpureg
	fild dword [esi]
	fild dword [esi+8]   ;st0=x2, st1=x1
	fsub st1             ;st0=dx, st1=x1
	fild dword [esi+4]   ;st0=y1, st1=dx, st2=x1
	fild dword [esi+12]  ;st0=y2, st1=y1, st2=dx, st3=x1
	fsub st1             ;st0=dy, st1=y1, st2=dx, st3=x1



	;****************************************
	;check for intersection with LEFT edge
	;****************************************


	;compute t0
	fld1
	fsub st4  ;st0=1-x1
	fdiv st3  ;st0=t0=(1-x1)/dx st1=dy, st2=y1, st3=dx, st4=x1


	;t0 must be between 0.0 and 1.0 to intersect the left edge
	fldz
	fcomip st1 ;(0.0-t0)
	jnc near .NoLeftIntersect_t0
	fld1
	fcomip st1  ;(1.0-t0)
	jc near .NoLeftIntersect_t0


	;compute y=y1+dy*t0
	fld st1     ;st0=dy, st1=t0, st2=dy, st3=y1, st4=dx, st5=x1
	fmul st1    ;st0=dy*t0
	fadd st3    ;st0=y=y1+dy*t0, st1=t0, st2=dy, st3=y1, st4=dx, st5=x1


	;y must be within 0.0 and ScreenHeight to intersect the left edge
	fldz
	fcomip st1  ;(0.0-y)
	jnc near .NoLeftIntersect_y
	fld qword [clipScreenHeight]
	fcomip st1  ;(600-y)
	jc near .NoLeftIntersect_y


	;compute x=x1+dx*t0
	fld st1    ;st0=t0, st1=y, st2=t0, st3=dy, st4=y1, st5=dx, st6=x1
	fmul st5   ;st0=dx*t0
	fadd st6   ;st0=x=x1+dx*t0, st1=y, st2=t0, st3=dy, st4=y1, st5=dx, st6=x1


	;fpu regs are full


	;jump to code depending on the visibility of P1 or P2
	mov eax,[clipStartVisible]
	mov ebx,[clipEndVisible]
	shl ebx,1
	or eax,ebx
	;eax=0 if both not visible
	;eax=1 if StartVisible
	;eax=2 if EndVisible
	;eax=3 if both visible but this was taken care of above
	cmp eax,0
	jz .LeftBothNotVisible
	cmp eax,1
	jz .LeftStartVisible
	cmp eax,2
	jz .LeftEndVisible

	jmp .ClipError   ;we shouldnt get here



.LeftStartVisible:
	fist dword [ebp+8]
	fxch st1   ;st0=y, st1=x
	fist dword [ebp+12]
	fxch st6   ;st0=x1, ...
	fist dword [ebp+0]
	fxch st4   ;st0=y1, ...
	fist dword [ebp+4]
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	jmp .ClipSuccess


.LeftEndVisible:
	fist dword [ebp+0]
	fxch st1   ;st0=y, st1=x, ...
	fist dword [ebp+4]
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	;save the unclipped endpoint as clip because its visible
	fild dword [esi+8]  
	fistp dword [ebp+8]
	fild dword [esi+12]
	fistp dword [ebp+12]
	jmp .ClipSuccess


.LeftBothNotVisible:
	fist dword [ebp+0]
	fxch st1
	fist dword [ebp+4]
	mov dword [P1_clip_saved],1 
	;clean up some fpu regs
	ffreep st0   ;free x
	ffreep st0   ;free y
	ffreep st0   ;free t0
	;st0=dy, st1=y1, st2=dx, st3=x1
	jmp .TopEdge


.NoLeftIntersect_y:
	ffreep st0   ;free y
.NoLeftIntersect_t0:
	ffreep st0   ;free t0









	;****************************************
	;check for intersection with TOP edge
	;****************************************

.TopEdge:


	;at this point we expect fpureg to contain: st0=dy, st1=y1, st2=dx, st3=x1

	;compute t0
	fld qword [clipScreenHeight]  ;st0=600.0, st1=dy, st2=y1, st3=dx, st4=x1
	fsub qword [one]	
	fsub st2
	fdiv st1            ;st0=t0=(600-1.0-y1)/dy st1=dy, st2=y1, st3=dx, st4=x1

	;compare t0 with 0 and 1
	fldz
	fcomip st1 ;compare 0.0 with t0
	jnc near .FreeTop_t0
	fld1
	fcomip st1  ;compare 1.0 with t0
	jc near .FreeTop_t0

	;compute x=x1+dx*t0
	fld st0    ;st0=t0, st1=t0, st2=dy, st3=y1, st4=dx, st5=x1
	fmul st4   ;st0=dx*t0
	fadd st5   ;st0=x=x1+dx*t0, st1=t0, st2=dy, st3=y1, st4=dx, st5=x1

	;compare x with 0 and ScreenWidth
	fldz
	fcomip st1  ;compare x with 0
	jnc near .FreeTop_x
	fld qword [clipScreenWidth]
	fcomip st1  ;compare x with 600
	jc near .FreeTop_x

	;compute y=y1+dy*t0
	fld st1     ;st0=t0, st1=x, st2=t0, st3=dy, st4=y1, st5=dx, st6=x1
	fmul st3    ;st0=dy*t0
	fadd st4    ;st0=y=y1+dy*t0, st1=x, st2=t0, st3=dy, st4=y1, st5=dx, st6=x1



	;jump to code depending on the visibility of P1 or P2
	mov eax,[clipStartVisible]
	mov ebx,[clipEndVisible]
	shl ebx,1
	or eax,ebx
	cmp eax,0
	jz .TopBothNotVisible
	cmp eax,1
	jz .TopStartVisible
	cmp eax,2
	jz .TopEndVisible

	jmp .ClipError   ;we shouldnt get here




.TopStartVisible:
	fist dword [ebp+12]
	fxch st1   ;st0=x, st1=y, ...
	fist dword [ebp+8]
	fxch st6   ;st0=x1, ...
	fist dword [ebp+0]
	fxch st4   ;st0=y1, ...
	fist dword [ebp+4]
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	jmp .ClipSuccess


.TopEndVisible:
	fist dword [ebp+4]
	fxch st1   ;st0=x, st1=y, ...
	fist dword [ebp+0]
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	fild dword [esi+8]
	fistp dword [ebp+8]
	fild dword [esi+12]
	fistp dword [ebp+12]
	jmp .ClipSuccess



.TopBothNotVisible:
	;have we already saved the P1 clipped endpoint ?
	cmp dword [P1_clip_saved],0 
	jz near .TopSaveToP1
	;top save to P2 because P1 is already saved
	fist dword [ebp+12]
	fxch st1
	fist dword [ebp+8]
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	jmp .ClipSuccess
.TopSaveToP1:
	fist dword [ebp+4]
	fxch st1
	fist dword [ebp+0]
	mov dword [P1_clip_saved],1 
	;clean up some fpu regs
	ffreep st0   
	ffreep st0   
	ffreep st0   
	;st0=dy, st1=y1, st2=dx, st3=x1
	jmp .RightEdge


.FreeTop_x:
	ffreep st0   ;free x
.FreeTop_t0:
	ffreep st0   ;free t0






	;****************************************
	;check for intersection with RIGHT edge
	;****************************************

.RightEdge:


	;at this point we expect fpureg to contain: st0=dy, st1=y1, st2=dx, st3=x1

	;compute t0
	fld qword [clipScreenWidth]   ;st0=800.0, st1=dy, st2=y1, st3=dx, st4=x1
	fsub qword [one]	
	fsub st4
	fdiv st3            ;st0=t0=(800-1.0-x1)/dx st1=dy, st2=y1, st3=dx, st4=x1

	;compare t0 with 0 and 1
	fldz
	fcomip st1     ;compare 0.0 with t0
	jnc near .FreeRight_t0
	fld1
	fcomip st1     ;compare 1.0 with t0
	jc near .FreeRight_t0

	;compute y=y1+dy*t0
	fld st0    ;st0=t0, st1=t0, st2=dy, st3=y1, st4=dx, st5=x1
	fmul st2   ;st0=dy*t0
	fadd st3   ;st0=y=y1+dy*t0, st1=t0, st2=dy, st3=y1, st4=dx, st5=x1

	;compare y with 0 and ScreenHeight
	fldz
	fcomip st1  ;compare y with 0
	jnc near .FreeRight_y
	fld qword [clipScreenHeight]
	fcomip st1  ;compare y with 800
	jc near .FreeRight_y

	;compute x=x1+dx*t0
	fld st1     ;st0=t0, st1=y, st2=t0, st3=dy, st4=y1, st5=dx, st6=x1
	fmul st5    ;st0=dx*t0
	fadd st6    ;st0=x=x1+dx*t0, st1=y, st2=t0, st3=dy, st4=y1, st5=dx, st6=x1




	;jump to code depending on the visibility of P1 or P2
	mov eax,[clipStartVisible]
	mov ebx,[clipEndVisible]
	shl ebx,1
	or eax,ebx
	cmp eax,0
	jz .RightBothNotVisible
	cmp eax,1
	jz .RightStartVisible
	cmp eax,2
	jz .RightEndVisible

	jmp .ClipError   ;we shouldnt get here



.RightStartVisible:
	fist dword [ebp+8]
	fxch st1   ;st0=y, st1=x, ...
	fist dword [ebp+12]
	fxch st6   ;st0=x1, ...
	fist dword [ebp+0]
	fxch st4   ;st0=y1, ...
	fist dword [ebp+4]
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	jmp .ClipSuccess


.RightEndVisible:
	fist dword [ebp+0]
	fxch st1   ;st0=y, st1=x, ...
	fist dword [ebp+4]
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	fild dword [esi+8]
	fistp dword [ebp+8]
	fild dword [esi+12]
	fistp dword [ebp+12]
	jmp .ClipSuccess


.RightBothNotVisible:
	cmp dword [P1_clip_saved],0 
	jz near .RightSaveToP1
	;save to P2 because P1 is already saved
	fist dword [ebp+8]
	fxch st1
	fist dword [ebp+12]
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	jmp .ClipSuccess
.RightSaveToP1:
	fist dword [ebp+0]
	fxch st1
	fist dword [ebp+4]
	mov dword [P1_clip_saved],1 
	;clean up some fpu regs
	ffreep st0   
	ffreep st0   
	ffreep st0   
	;st0=dy, st1=y1, st2=dx, st3=x1
	jmp .BottomEdge


.FreeRight_y:
	ffreep st0   ;free y
.FreeRight_t0:
	ffreep st0   ;free t0



	;****************************************
	;check for intersection with BOTTOM edge
	;****************************************

.BottomEdge:


	;at this point we expect fpureg to contain: 
	;st0=dy, st1=y1, st2=dx, st3=x1

	;compute t0
	fld qword [one]     ;st0=1.0, st1=dy, st2=y1, st3=dx, st4=x1
	fsub st2
	fdiv st1      ;st0=t0=(1.0-y1)/dy st1=dy, st2=y1, st3=dx, st4=x1

	;compare t0 with 0 and 1
	fldz
	fcomip st1         ;compare 0.0 with t0
	jnc near .FreeBottom_t0  
	;if we havent satisfied endpoint visibility by now we never will
	fld1
	fcomip st1         ;compare 1.0 with t0
	jc near .FreeBottom_t0

	;compute x=x1+dx*t0
	fld st0    ;st0=t0, st1=t0, st2=dy, st3=y1, st4=dx, st5=x1
	fmul st4   ;st0=dx*t0
	fadd st5   ;st0=x=x1+dx*t0, st1=t0, st2=dy, st3=y1, st4=dx, st5=x1

	;compare x with 0 and ScreenWidth
	fldz
	fcomip st1         ;compare x with 0
	jnc near .FreeBottom_x
	fld qword [clipScreenWidth]
	fcomip st1         ;compare x with 800
	jc near .FreeBottom_x

	;compute y=y1+dy*t0
	fld st1     ;st0=t0, st1=x, st2=t0, st3=dy, st4=y1, st5=dx, st6=x1
	fmul st3    ;st0=dy*t0
	fadd st4    ;st0=y=y1+dy*t0, st1=x, st2=t0, st3=dy, st4=y1, st5=dx, st6=x1




	;jump to code depending on the visibility of P1 or P2
	mov eax,[clipStartVisible]
	mov ebx,[clipEndVisible]
	shl ebx,1
	or eax,ebx
	cmp eax,0
	jz .BottomBothNotVisible
	cmp eax,1
	jz .BottomStartVisible
	cmp eax,2
	jz .BottomEndVisible

	jmp .ClipError   ;we shouldnt get here




.BottomStartVisible:
	fist dword [ebp+12]
	fxch st1   ;st0=x, st1=y, ...
	fist dword [ebp+8]
	fxch st6   ;st0=x1, ...
	fist dword [ebp+0]
	fxch st4   ;st0=y1, ...
	fist dword [ebp+4]
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	jmp .ClipSuccess



.BottomEndVisible:
	fist dword [ebp+4]
	fxch st1   ;st0=x, st1=y, ...
	fist dword [ebp+0]
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	fild dword [esi+8]
	fistp dword [ebp+8]
	fild dword [esi+12]
	fistp dword [ebp+12]
	jmp .ClipSuccess



.BottomBothNotVisible:
	;if we got here we must have already saved P1_clip
	;so now we save P2_clip
	;this happens if the line crosses the bottom edge
	;and one other edge and both endpoints are not visible
	fist dword [ebp+12]
	fxch st1
	fist dword [ebp+8]
.FreeBottom_x:
.FreeBottom_t0:
	ffree st0
	ffree st1
	ffree st2
	ffree st3
	ffree st4
	ffree st5
	ffree st6
	ffree st7
	jmp .ClipSuccess
	;done bottom edge



.ClipTrivialReject:
	mov eax,3
	jmp .ClipDone

.ClipZeroLengthLine:
	mov eax,2
	jmp .ClipDone

.ClipError:
	mov eax,1
	jmp .ClipDone

.ClipSuccess:
	mov eax,0

.ClipDone:
	ret



 


 

;************************************
;cliprect
;modify the x,y,w,h of a rectangle
;to prevent falling off the screen
;and writting to non-video memory
;input
;ebx=x, ecx=y, edx=width, esi=height
;return
;eax=Xclipped, ebx=Yclipped, esi=WIDTHclipped, edi=HEIGHTclipped

;locals
_xclip dd 0
_yclip dd 0
_wclip dd 0
_hclip dd 0
;************************************

cliprect:

	push ecx
	
	;check x with 790
	mov ecx,790   ;xmax
	call min      ;return value in ebx
	mov [_xclip],ebx

	;check y with 590
	pop ecx
	mov ebx,590  ;ymax
	call min
	mov [_yclip],ebx

	;check w 
	mov ebx,795
	sub ebx,[_xclip]  ;wmax=795-xclip
	mov ecx,edx
	call min
	mov dword [_wclip],ebx
	
	;check h
	mov ebx,595
	sub ebx,[_yclip]  ;hmax=595-yclip
	mov ecx,esi
	call min
	mov dword [_hclip],ebx

	mov eax,[_xclip]
	mov ebx,[_yclip]
	mov esi,[_wclip]
	mov edi,[_hclip]

	ret
	
