;tatOS/tlib/circle.s


;************************************************
;circle
;draws a bresenham circle 
;the border is drawn solid 1 pixel wide
;the center may be filled or unfilled
;computes x,y of border pixel in the 2nd Octant (theta=45->90)
;remainder of circle border is by mirror image

;input
;push 1=filled, 0=unfilled [ebp+24]  
;push xcenter              [ebp+20]
;push ycenter              [ebp+16]
;push radius               [ebp+12]
;push ColorIndex 0-0xff    [ebp+8]


;local variables
circle_xmax      dd 0
circle_dx        dd 0  ;x coordinate in 2nd Octant
circle_dy        dd 0
circle_d         dd 0
Octant1          dd 0  ;stores address of pixel on border for scanline filling
Octant2          dd 0
Octant3          dd 0
Octant4          dd 0
Octant5          dd 0
Octant6          dd 0
Octant7          dd 0
Octant8          dd 0
;************************************************

circle:

	push ebp
	mov ebp,esp
	pushad


	;get address of center of circle
	push dword [ebp+20]  ;x
	push dword [ebp+16]  ;y
	call getpixadd
	mov esi,edi    ;save


	;compute xmax=radius/sqrt(2)=radius*1000/1414 (integer)
	;this is qty pixels to move horizontal 
	;from theta=90 to theta=45
	mov ebx,[ebp+12]
	mov eax,1000
	mul ebx ;eax=radius*1000
	xor edx,edx
	mov ebx,1414
	div ebx  ;eax=radius*1000/1414
	mov dword [circle_xmax],eax  ;save



	;init dx
	mov dword [circle_dx],0

	;init dy to radius
	mov eax,[ebp+12]
	mov [circle_dy],eax

	;init the "d" error term to -radius
	neg eax
	mov [circle_d],eax

	;color in cl
	mov ecx,[ebp+8]


	
.topofCircleLoop:

	;compute error term d=2*dx-1
	mov eax,[circle_dx]
	shl eax,1  ;2*dx
	sub eax,1  ;2*dx-1
	add [circle_d],eax  ;d+=2*dx-1


	;check if error term is >=0
	cmp dword [circle_d],0
	jl .dontupdate
	;adjust dy if necessary (move closer to center of circle)
	dec dword [circle_dy]     ;y--
	mov eax,[circle_dy]
	shl eax,1  ;2*dy
	sub [circle_d],eax  ;d-=2*dy
.dontupdate:



	;precompute ebx=dx*[videobufferwidth] 
	;eax=width of pixel buffer
	mov eax,[videobufferwidth]
	mul dword [circle_dx]
	mov ebx,eax  

	;precompute eax=dy*[videobufferwidth] 
	mov eax,[videobufferwidth]
	mul dword [circle_dy]



	;set 8 pixels, one in each octant

	

	;[1] set pixel in 1st Octant, theta=0->45
	;edi-dx*[BPSL]+dy, (y,x)
	mov edi,esi 
	sub edi,ebx
	add edi,[circle_dy]
	mov [Octant1],edi  ;save for later circle fill
	mov byte [edi],cl

	;[2] set pixel in 2nd Octant, theta=45->90
	;edi-dy*[BPSL]+dx, (x,y)
	mov edi,esi 
	sub edi,eax
	add edi,[circle_dx]
	mov [Octant2],edi  
	mov byte [edi],cl
	
	;[3] set pixel in 3rd Octant, theta=90->135
	;edi-dy*[BPSL]-dx, (-x,y)
	mov edi,esi 
	sub edi,eax
	sub edi,[circle_dx]
	mov [Octant3],edi  
	mov byte [edi],cl

	;[4] set pixel in 4th Octant, theta=135->180
	;edi-dx*[BPSL]-dy, (-y,x)
	mov edi,esi 
	sub edi,ebx
	sub edi,[circle_dy]
	mov [Octant4],edi   
	mov byte [edi],cl

	;[5] set pixel in 5th Octant, theta=180->225
	;edi+dx*[BPSL]-dy, (-y,-x)
	mov edi,esi 
	add edi,ebx
	sub edi,[circle_dy]
	mov [Octant5],edi  
	mov byte [edi],cl

	;[6] set pixel in 6th Octant, theta=225->270
	;edi+dy*[BPSL]-dx, (-x,-y)
	mov edi,esi 
	add edi,eax
	sub edi,[circle_dx]
	mov [Octant6],edi  
	mov byte [edi],cl

	;[7] set pixel in 7th Octant, theta=270->325
	;edi+dy*[BPSL]+dx, (x,-y)
	mov edi,esi 
	add edi,eax
	add edi,[circle_dx]
	mov [Octant7],edi  
	mov byte [edi],cl

	;[8] set pixel in 8th Octant, theta=325->360
	;edi+dx*[BPSL]+dy, (y,-x)
	mov edi,esi 
	add edi,ebx
	add edi,[circle_dy]
	mov [Octant8],edi  
	mov byte [edi],cl




	;set pixels in scanlines to fill the circle
	cmp dword [ebp+24],0
	jz .DoneCircleFill
	cld        ;increment

	;Octant[3]->Octant[2]
	mov eax,[ebp+8]    ;color in al
	mov ecx,[Octant2]
	sub ecx,[Octant3]  ;ecx is number of pixels in scanline to set
	mov edi,[Octant3]  ;starting address
	rep stosb          ;al->edi, edi++,ecx--

	;Octant[4]->Octant[1]
	mov eax,[ebp+8]  
	mov ecx,[Octant1]
	sub ecx,[Octant4]  
	mov edi,[Octant4]  
	rep stosb          

	;Octant[5]->Octant[8]
	mov eax,[ebp+8]  
	mov ecx,[Octant8]
	sub ecx,[Octant5]  
	mov edi,[Octant5]  
	rep stosb          

	;Octant[6]->Octant[7]
	mov eax,[ebp+8]  
	mov ecx,[Octant7]
	sub ecx,[Octant6]  
	mov edi,[Octant6]  
	rep stosb          

	;must restore the color register for setting border pixels above
	mov ecx,[ebp+8]
.DoneCircleFill:

	
	

	;test 4 doneness
	mov eax,[circle_dx]
	cmp eax,[circle_xmax]
	jz .done
	inc dword [circle_dx]
	jmp .topofCircleLoop


.done:
	popad
	pop ebp
	retn 20




