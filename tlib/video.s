;tatOS/tlib/video.s

;various functions to deal with video buffers

;swapbuf, swaprect, swaprectprep, getvideosize
;backbufclear, backbufscroll, backbufsave, backbufrestore, 
;getbpsl, swapuserbuf, setyorient
;getpixadd, setpixel, xy2i, setdestvideobuf


;tatOS uses a double buffer scheme
;most tlib graphic functions are designed to set pixels
;in the backbuffer and then you use swapbuf to copy pixels
;from the backbuffer to the linear frame buffer

;use backbufclear to fill the back buffer with ff bytes
;this wipes everything out giving you a fresh slate
;for each paint cycle

;but say you want to draw over the top of something
;use backbufsave to save a copy of the backbuffer
;then use backbufrestore at the start of your paint cycle

;dont forget a call to getc if appropriate, which suspends execution of 
;your program so you can see whats on the screen



;*******************************************************
;swapbuf
;this function is called at the end of a paint cycle
;to copy the entire back buffer to the entire 
;linear frame buffer

;NOTE this function does not preserve any registers !!!!!

;input:none

;you can draw to the screen from any subroutine
;by just calling puts or whatever and then call swapbuf
;********************************************************


swapbuf:
	cld
	mov esi, BACKBUF   ;backbuffer
	mov edi, [LFB]     ;linear frame buffer
	mov ecx, [BPSL4]   ;=BPSL*600/4
	rep movsd
	ret






;*******************************************************************
;swaprect
;this routine is for apps that dont want to draw over
;the entire LFB but just want a small "window"
;this routine copies only a rectangular portion of the backbuffer
;of width,height starting at 0,0 to the LFB starting at x,y
;the width must be a multiple of 4 for dword copy
;again all units are pixels
;you MUST call swaprectprep() in your app_init
;to initialize global variables used by this routine
;input:none
;*******************************************************************

swaprect:

	pushad
	cld
	mov esi,BACKBUF          ;backbuffer start at 0,0

	;these globals are computed by swaprectprep in your app_init
	mov edi,[LFBSTART]
	mov ebx,[WINDOWHEIGHT]     ;ebx=height=num rows to copy
	mov ecx,[WINDOWIDTH]       ;dwords per scanline
	mov edx,[WINDOWROWADVANCE] ;BPSL-width

.setpixels:	
	rep movsd   ;esi->edi ecx times (set entire row of pixels)
	dec ebx     ;one less row
	jz .done
	add edi,edx           ;inc LFB to next row
	add esi,edx           ;inc BACKBUF to next row
	mov ecx,[WINDOWIDTH]  ;rep destroys ecx so restore for next row
	jmp .setpixels

.done:
	popad
	ret 



;************************************************************
;swaprectprep
;call this function during your app init
;it inits global variables used by swaprect
;this is done to save swaprect some time
;input:
;push xloc in LFB      [ebp+20]
;push yloc in LFB      [ebp+16]
;push width            [ebp+12]
;push height           [ebp+8]
;*******************************************************

swaprectprep:

	push ebp
	mov ebp,esp
	pushad

	;compute destination address in LFB
	;code comes from getpixadd except destination is LFB
	;note XOFFSET,YOFFSET and YORIENT do not work here
	;so +Y is down same as vga default
	mov edx,[BPSL]         ;bytesperscanline
	mov edi,[LFB]          ;start of LFB
	mov eax,[ebp+16]       ;y
	mul edx                ;eax = y*bpsl
	add edi,eax            ;edi = LFB + y*bpsl 
	add edi,[ebp+20]       ;edi = LBF + y*bpsl + x
	mov [LFBSTART],edi


	;compute the number of dwords per scanline in the little "window"
	mov ecx,[ebp+12]
	shr ecx,2   ;/4
	mov [WINDOWIDTH],ecx


	;compute number of dwords to advance esi and edi to next row
	mov edx,[BPSL]    ;bytesperscanline
	sub edx,[ebp+12]  ;BPSL-width
	;edx now holds qty bytes to advance video buffer to next row
	;because rep movsd leaves edi/esi at the end of the row
	mov [WINDOWROWADVANCE],edx


	;height of window
	mov eax,[ebp+8]
	mov [WINDOWHEIGHT],eax


	popad
	pop ebp
	retn 16





;********************************************************
;alternate swapbuf
;this code performed no better 
;than rep movsd above
;in a simple test of pressing and holding a keydown
;and timing character/second
;the keyboard typematic rate was the important setting
;and either swapbuf perfomed equally well
;so I am opting for shorter swapbuf for now
;but keeping this for someday
;if you have PIII or greater investigate the 
;128bit xmm register mov instructions
;or the movsq instruction
;*******************************************************

;swapbuf:
	;pushad
		
	;set up for moving 64 bytes at a time
	;mov esi, BACKBUF   ;backbuffer
	;mov edi, [LFB]     ;linear frame buffer
	;mov ecx, [BPSL64]  ;sizeof video buffer/64
	
;.moveit:
	;grab 64 bytes using MMX registers
	;movq mm0, [esi]
	;movq mm1, [esi+8]
	;movq mm2, [esi+16]
	;movq mm3, [esi+24]
	;movq mm4, [esi+32]
	;movq mm5, [esi+40]
	;movq mm6, [esi+48]
	;movq mm7, [esi+56]

	;copy to LFB
	;movq [edi], mm0
	;movq [edi+8], mm1
	;movq [edi+16], mm2
	;movq [edi+24], mm3
	;movq [edi+32], mm4
	;movq [edi+40], mm5
	;movq [edi+48], mm6
	;movq [edi+56], mm7

	;add esi,64
	;add edi,64
	;loop .moveit


	;popad
	;ret


;************************************************
;getvideosize
;computes size of video buffer in bytes
;and stores for quick fetch by clearsc
;and swapbuf functions
;on many computers the size is 800*600
;but on others each scanline has padding bytes
;so the actual size of the buffer is larger
;input:none
;return:saves value at 0x530
;************************************************

getvideosize:
	xor edx,edx
	mov eax, [BPSL] ;bytesperscanline
	mov ebx,600
	mul ebx     
	;note to self TOM 0x530 is defined as UHCIBASEADD
	;so this save here doesnt make much sense.
	;this function getvideosize doesnt have any current usage in tlib
	;that I can see, may treat as depreciated.
	mov [0x530],eax   
	ret





;*****************************************
;backbufsave
;we save a copy of the BACKBUF to 0x1c90000
;this is for apps that want to draw 
;to a portion of the screen
;and want to preserve whats underneath
;call this before your paint loop
;this is the same code as swapbuf
;except for the destination
;input:none
;return:none
;*****************************************

backbufsave:
	pushad
	cld
	mov esi, BACKBUF   
	mov edi, 0x1c90000 
	mov ecx, [BPSL4]   
	;ecx=BPSL*600/4
	rep movsd
	popad
	ret



;******************************************
;backbufrestore
;use this at start of paint cycle
;instead of backbufclear
;if wanting to perserve whats underneath
;this is the same code as backbufsave
;with source and dest reversed
;input:none
;return:none
;******************************************
backbufrestore:
	pushad
	cld
	mov edi, BACKBUF   
	mov esi, 0x1c90000 
	mov ecx, [BPSL4]   
	;ecx=BPSL*600/4
	rep movsd
	popad
	ret



;**********************************************
;backbufclear
;fill the entire back buffer with ff bytes
;ff is reserved in the 256 color palette 
;for our background
;no input and no return
;controls like list or edit box should not call this
;only user app of kernel utils
;**********************************************
backbufclear:
	cld
	mov eax,0xffffffff
	mov edi, BACKBUF  
	;ecx=BPSL*600/4
	mov ecx, [BPSL4]   
	rep stosd
	ret



;*****************************************************
;backbufscroll
;scrolls the backbuffer down

;input
;push "N" qty scanlines to scroll down   [ebp+8]

;this function works only with the backbuffer
;it moves an upper block of the backbuffer
;down to the bottom of the backbuffer
;to prevent overwritting itself
;we copy bits from the end 
;working back toward the beginning

;usage
;startup code that repeatedly displays a 1 line
;text message along the top of the screen
;set N=15 for use with PUTS and our bitmap font
;*****************************************************


backbufscroll:

	push ebp
	mov ebp,esp

	;get address of end of Nth from the bottom scanline
	mov eax,599
	sub eax,[ebp+8]
	push 0   ;x
	push eax ;y
	call getpixadd
	;edi=beginning of scanline
	add edi,[BPSL]
	;edi=end of scanline
	mov esi,edi


	;get address of end of last scanline
	push 0   ;x
	push 599 ;y
	call getpixadd
	add edi,[BPSL]


	;total qty bits to copy
	mov eax,[BPSL]
	mov ebx,600
	sub ebx,[ebp+8]
	mul ebx
	mov ecx,eax


	;set direction flag so we start at end
	;and work towards beginning
	;this way we dont overwrite ourself
	std
	rep movsb
	
	
.done:
	cld ;reset
	pop ebp
	ret 4




;********************************************************************
;getbpsl
;returns the bytes per scanline returned by the bios
;this is for apps that want to draw to a private pixel buffer
;the size of the private pixel buffer in pixels must be = [BPSL]*600
;because tatOS uses the bios to set the video mode to 800x600
;most video adapters will set [BPSL]=800 
;but on some there are invisible padding bytes at the end of each row
;so [BPSL] will be > 800 
;input:none
;return: eax=bytes per scan line BPSL
;********************************************************************

getbpsl:
	mov eax,[BPSL]
	ret


;*******************************************************
;swapuserbuf
;this function copies a userland private pixel buffer
;to the LFB linear frame buffer.
;its for direct draw apps 
;the size of this pixel buffer must be [BPSL]*600
;userland apps will find space for this buffer
;directly after the user exe in the same page
;NOTE this function does not preserve any registers !!!!!
;I suggest the address of this buffer be page aligned
;see apps/fire.s for an example of how to use this function

;input:esi=address of private pixel buffer
;return:none
;********************************************************


swapuserbuf:
	cld
	;esi=address of private pixel buffer 
	mov edi, [LFB]     ;linear frame buffer
	mov ecx, [BPSL4]   ;=BPSL*600/4
	rep movsd
	ret



;*****************************************************************
;setyorient
;the global dword [YORIENT] determines topdown or bottomup drawing
;if YORIENT=1 then Y=0 is at top of screen and +Y goes down 
;this is default for vga
;if YORIENT=-1 then Y=0 is at bottom of screen and +y goes up
;input: ebx=1 or -1
;return:none
;*****************************************************************

setyorient:

	cmp ebx,1
	jz .settopdown
	cmp ebx,-1
	jz .setbottomup
	jmp .done  ;invalid value in ebx

.settopdown:
	mov dword [YORIENT],1
	jmp .done
.setbottomup:
	mov dword [YORIENT],-1
.done:
	ret




;********************************************************************************
;getpixadd
;get pixel address
;computes address of any pixel at x,y (col,row)
;in the video back buffer BACKBUF or any private pixel buffer
;for BACKBUF we are dealing with 800x600 screen only
;if BPSL=800 then the address can vary from 0-479999 (if not padding bytes)
;by default the vga linear frame buffer:
;x goes from 0-799 right
;y goes from 0-599 down
;the upper left corner is 0,0
;the lower righ corner is 799,599 
;this is our YORIENT=1
;the address of the pixel at the lower right of screen is
;as follows assuming bpsl=800:  599*800 + 799 = 479999
;note some video adapters require padding bytes at the end
;of each scanline so BPSL > 800.

;if using a special video buffer then a previous call
;to setdestvideobuf() is reqd

;we also introduce YORIENT=-1
;here the bottom scanline is y=0 and +y increases going up
;the lower left corner is 0,0
;the upper right corner is 799,599 
;this is the default for engineering graphs

;input:
;push x (column)   [ebp+12]
;push y (row)      [ebp+8]

;returns:
;edi=address of pixel in either BACKBUF or private pixel buffer
;********************************************************************************

getpixadd:

	push ebp
	mov ebp,esp

	push eax
	push ebx
	push edx


	;global X/Y offsets for BACKBUF
	mov ebx,[ebp+12]  ;ebx=x
	mov eax,[ebp+8]   ;eax=y
	add ebx,[XOFFSET]
	add eax,[YOFFSET]


	;the default vga Yaxis orientation is YORIENT=1 
	;y=0 at top scanline and +y pointing down
	;if YORIENT=-1 then
	;y=0 at bottom scanline with +y pointing up
	cmp dword [YORIENT],1
	jz .topdown
	;for bottom up
	sub eax,599
	neg eax
.topdown:
	

	;get address of dest video buffer and buffer width
	;dest video may be BACKBUF or some special buffer
	mov edx,[videobufferwidth] 
	mov edi,[videobufferstart]


	;compute pixel address
	mul edx                  ;eax = y*width
	add edi,ebx              ;edi=StartingAddress + x 
	add edi,eax              ;edi=StartingAddress + x + y*width

	pop edx
	pop ebx
	pop eax
	pop ebp
	retn 8





;***********************************************
;setpixel
;set a pixel in the BACKBUF to a certain color
;input:
;ebx=x
;ecx=y
;edx=color index into current DAC palette
;    value from 0-0xff
;return:none
;**********************************************

setpixel:

	push edi

	push ebx  ;x
	push ecx  ;y
	call getpixadd
	;edi=address of pixel to set in backbuffer
	
	;set pixel
	mov byte [edi], dl

	;you must call [SWAPBUF] in your paint routine
	;to get anything to show up on the screen

	pop edi
	ret





;******************************************
;xy2i
;convert xy bitmap pixel coordinates
;to array index. The index is the offset
;from the start of the bitmap
;the column and row numbers start with 0
;i.e. the first column and first row are 0

;input
;push x or column   [ebp+16]
;push y or row      [ebp+12]
;push bitmap width  [ebp+8]

;return
;eax=array index or offset 

;the formula is:
;index = (y*bmwidth) + x or (row*bmwidth) + col
;then PixelAddress = StartingAddressOfArrayOfBits + index
xy2i_str db 'xy2i return value',0
;************************************************************

xy2i:
	
	push ebp
	mov ebp,esp
	push edx

	mov eax,[ebp+12]  ;y
	mul dword [ebp+8] ;eax=y*bmwidth
	add eax,[ebp+16]  ;eax=y*bmwidth + x

	;STDCALL xy2i_str,0,dumpeax   for debug

	pop edx
	pop ebp
	retn 12



;********************************************************
;setdestvideobuf
;by default all tatOS tlib graphic functions set pixels
;in the BACKBUF and then we use swapbuf() to make them show up

;with this function the user may specify a differant buffer
;to set pixels and then use swapuserbuf() to make them show up

;the values you pass to this function are stored in globals
;and used by getpixadd. getpixadd is used by all tlib drawing
;functions to determine the starting address of a pixel

;input
;ebx = Starting Address of pixel buffer
;ecx = Width of pixel buffer (bytesperscanline)
;return:none

;if ebx=0 then pixels will be set in the BACKBUF and the
;bytesperscanline will be set to the value the bios gave
;on startup which is [BPSL]

;this function is called in tatOSinit and also in tlibentry
;to set default dest video buffer to BACKBUF

;local
videobufferstart  dd 0
videobufferwidth  dd 0
;********************************************************

setdestvideobuf:

	cmp ebx,0
	jz .setdefaultvideo

	;save values for a special video buffer
	mov [videobufferstart],ebx
	mov [videobufferwidth],ecx
	jmp .done

.setdefaultvideo:
	mov dword [videobufferstart],BACKBUF
	mov eax,[BPSL]
	mov [videobufferwidth],eax

.done:
	ret



