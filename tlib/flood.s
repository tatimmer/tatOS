;tatOS/tlib/flood.s

;*********************************************************
;floodfill
;fill a randomly shaped area of pixels
;with one color

;input
;push starting address of bitmap  [ebp+28]
;push Xseed                       [ebp+24]
;push Yseed                       [ebp+20]
;push bitmap width                [ebp+16]
;push bitmap height               [ebp+12]
;push color to set                [ebp+8]

;this function uses the kernel stack
;we start with a "seed" value, any pixel in the middle to fill
;we save the color of the "seed" value
;and push its x,y coordinates on the stack
;then we enter the loop
;in the loop we pop off an x,y coordinate
;we color this pixel with the seed value color
;next wet examine the 4 neighboring pixels top,bot,left,right
;we push them on the stack if their color matches the seed 
;continue at top of loop

;beware of stack corruption
;everything you put on the stack must be taken off

;beware of stack overflow
;available stack space as of Nov 2008
;= esp - (startofApplication + sizeofApplication)
;= 0x88888-(0x1a000+25600)= 0x68400 = 427k bytes
;each pixel requires 8 bytes so 53k pixels are allowed
;so we could fill a region of about 200x250 pixels max
;since push something on the stack decrements esp 
;closer to our code, we will just limit esp to 0x33333 
;to protect our code 

;locals
floodstacksize     dd 0
floodseedcolor     db 0
floodAddressBitmap dd 0
;*******************************************************

floodfill:
	push ebp
	mov ebp,esp

	;save for later
	mov eax,[ebp+28]
	mov [floodAddressBitmap],eax


	;push our seed on the stack
	;push X
	push dword [ebp+24]
	;push Y
	push dword [ebp+20]
	;inc floodstacksize
	inc dword [floodstacksize] 
	

	;save seed color
	mov ebx,[ebp+24]
	mov eax,[ebp+20]
	call getpixelcolor
	mov [floodseedcolor],dl


floodmainloop:

	;this is our exit point
	;when there is no more data to pop off stack
	;we quit  
	cmp dword [floodstacksize],0
	jz near .done


	;ebx and eax must be preserved thru this main loop !!


	;pop Y
	pop eax
	;pop X
	pop ebx
	;dec qty pixels on stack
	dec dword [floodstacksize] 


	;color this pixel same as our seed
	call setpixelcolor

	
	;examine pixel above
	;*********************
	;Y-1
	dec eax
	call floodprocesspixel
	;reset Y 
	inc eax
	
	
	;examine pixel below
	;*********************
	;Y+1
	inc eax
	call floodprocesspixel
	;reset Y 
	dec eax
	

	;examine pixel Left
	;*********************
	;X-1
	dec ebx
	call floodprocesspixel
	;reset X 
	inc ebx
	

	;examine pixel Right
	;********************
	;X+1
	inc ebx
	call floodprocesspixel
	;reset X 
	dec ebx
	

	jmp floodmainloop
	;go back top top and continue


.done:
	pop ebp
	ret 24
	



;**************************************
;getpixelcolor
;input
;ebx=X
;eax=Y
;returns 
;color of pixel in dl
;*************************************

getpixelcolor:
	push eax
	push ebx
	
	mov ecx,[ebp+16]

	push ebx  ;x
	push eax  ;y
	push ecx  ;bmwidth
	call xy2i ;eax=pixel index

	mov esi,[floodAddressBitmap]
	mov dl,[eax+esi]
	;return pixel color in dl

	pop ebx
	pop eax
	ret


;***************************
;setpixelcolor
;sets pixel to our flood color
;input
;ebx=X
;eax=Y
;no return
;**************************

setpixelcolor:
	push eax
	push ebx
	
	mov ecx,[ebp+16]

	push ebx  ;x
	push eax  ;y
	push ecx  ;bmwidth
	call xy2i ;eax=pixel index

	mov edx,[ebp+8]  ;get color

	mov esi,[floodAddressBitmap]
	mov [eax+esi],dl  ;set color

	pop ebx
	pop eax
	ret



;**********************************
;floodprocesspixel
;input
;ebx=x
;eax=y

;return:none

;if pixel x,y is out of range 
;or if pixel is not seed color 
;or if stack if full 
;then this routine does nothing
;else it pushes x,y on stack
;and increments count
;**********************************

floodprocesspixel:

	;make sure X value is within range
	mov esi,ebx
	push 0
	push dword [ebp+16]
	call checkrange
	jnz .done

	;make sure Y value is within range
	mov esi,eax
	push 0
	push dword [ebp+12]
	call checkrange
	jnz .done

	;get pixel color and check if its seed color
	call getpixelcolor
	cmp dl,[floodseedcolor]
	jnz .done
	
	;put on stack if we have available size
	cmp esp,0x33333
	jb .done
	
	;now before we push x,y on the stack
	;we must retrieve our return address
	;and then put it on the stack after x,y
	pop edx

	;push X,Y on stack 
	push ebx
	push eax
	;inc floodstacksize
	inc dword [floodstacksize] 

	;now put return address on stack
	push edx

.done:
	ret


