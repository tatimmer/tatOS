;tatOS/tlib/tatOS.init

;we jump from boot2.s to this file
;here we put various initiation code that is executed
;only once when tatOS boots up.
;at the end we jmp to the shell which is our top level tatOS app
;all code here is bits32 protected mode
;here you may start to draw to the screen as noted below where some key
;globals are initialized


tatOSinit:


	STDCALL initstr3,dumpstr


	;program the MSR model specific registers for sysenter/sysexit
	;******************************************************************

	;MSR 0x174 Kernel Code Selector CS
	mov ecx,0x174          ;MSR_SYSENTER_CS 
	rdmsr                  ;read msr to edx:eax
	mov ax,0x08            ;kernel code CS
	wrmsr                  ;write edx:eax to msr

	;MSR 0x175 Kernel target ESP 
	mov ecx,0x175          ;MSR_SYSENTER_ESP 
	rdmsr                  ;read msr to edx:eax
	mov eax,0x88888        ;kernel stack ESP
	wrmsr                  ;write edx:eax to msr
	
	;MSR 0x176 Kernel target EIP 
	mov ecx,0x176          ;MSR_SYSENTER_EIP 
	rdmsr                  ;read msr to edx:eax
	mov eax,tlibEntryProc  ;tlib entry procedure see tlibentry.s
	wrmsr                  ;write edx:eax to msr
	;note interrupts will be disabled after entering
	;tlibEntryProc so you must do sti to enable them
	
	


	;setup and init paging
	;this must be done in protected mode
	cli
	call BuildPageDirectory   ;see tlib/paging.s
	mov eax,cr4  ;read cr4
	;first set the PSE bit4 of cr4 to enable 4mb pages
	or eax,10000b
	;and make sure the PAE physical address extension is disabled (bit5=0)
	and eax,0xffffffdf
	mov cr4,eax  ;write cr4
	;cr3 holds the address of our page directory entries
	mov ebx,0x8000
	mov cr3,ebx
	;now enable paging
	mov eax,cr0  ;read cr0
	or eax,0x80000000 ;set bit31 of cr0 to enable paging
	mov cr0,eax  ;write cr0
	sti




	;compute sizeof video LFB and BACKBUF 
	;this number is used by swapbuffer and clearsc
	;to blit the entire contents of video memory
	xor edx,edx
	mov eax,[BPSL] ;bytesperscanline
	mov ebx,600
	mul ebx
	;edx:eax = BPSL*600
	shr eax,2  ;eax/4
	mov [BPSL4],eax  ;save for rep movsd version of swapbuf
	shr eax,4  ;eax/16
	mov [BPSL64],eax ;save for mmx register version of swapbuf 


	;dump the address of linear frame buffer LFB and bitsperscanline BPSL
	mov eax,[LFB]  ;LFB is saved in boot2.s
	STDCALL initstr1,0,dumpeax
	mov eax,[BPSL]
	STDCALL initstr2,0,dumpeax



	;generate the std and gray palettes
	call genstdpalette   
	call gengraypalette 


	;load the stdpalette
	push 0  
	call setpalette 


	;set default Yaxis orientation to topdown
	mov dword [YORIENT],1 

	;set the default X,Y global offsets
	mov dword [XOFFSET],0
	mov dword [YOFFSET],0

	;tell tlib graphic functions to draw to BACKBUF by default
	;after this point you may draw to the screen
	mov ebx,0
	call setdestvideobuf






	;init the fpu
	;we assume the existance of an fpu
	;it would be best to check cpuid
	STDCALL initstr8,putscroll
	mov eax,cr0 
	and eax,0xfffffffb   ;clear bit2 EM Emulation
	or eax,10b           ;set   bit1 MP Monitor Coprocessor
	or eax,100000b       ;set   bit5 NE Numberic Error 
	mov cr0,eax
	finit



	;build 2 lookup tables 
	;see tatOS/tlib/polar.s 
	STDCALL initstr9,putscroll
	call fillsincos


	;use [PITCOUNTER] to initialize [RANDSEED]
	mov eax,[PITCOUNTER]
	mov [RANDSEED],eax

	;checktime user callback function set to 0 here, user must give us a valid address 
	mov dword [TIMERCALLBACK],0

	;initialize 0x1300000 which holds qty bytes in the clipboard
	mov dword [0x1300000],0



	;keyboard.s will set this value to 1 on CTRL+ALT+DEL
	;apps with a loop should check for 1
	;and exit gracefully
	mov dword [0x518],0



	;set FLASHDRIVEREADY to 0 not ready
	mov dword [0x528],0



	;init some globals to keep tract of button down status
	mov dword [LBUTTONDOWN],0
	mov dword [RBUTTONDOWN],0
	mov dword [MBUTTONDOWN],0



	;init usb controllers (now moved to usb central and you must do manually)


	;disable the boot processor local apic
	mov ecx,0x1b
	rdmsr  ;read value of model specific register 0x1b, return in edx:eax
	;now clear bit 11 of eax to disable the local apic
	and eax,0xfffff7ff
	wrmsr   ;now write it back



	;set the name of the CurrentWorking Directory to "root       " see fat16.s
	STDCALL initstr11,NAMEOFCWD,strcpy2


	;init and blank the tedit link list see tedit.s
	call teditBlankList


	;init the MAT memory allocation table see alloc.s
	cld
	mov edi,STARTOFMAT
	mov ecx,2550
	mov al,0
	rep stosb


	;init the address of "..start" to a known invalid value 
	;see ttasm ..START where this value is written on successful assemble
	;and tedit F10 where this value is checked before executing users app
	mov dword [0x2000008],0



	;tom do not write a 0 to the dump here
	;that will terminate the dump and prevent any additional strings
	;from being displayed


	;jump to start of shell
	STDCALL initstr5,putscroll
	jmp near shell




;************
;  DATA
;************

initstr1 db 'address of linear frame buffer LFB',0
initstr2 db 'bytes per scan line BPSL',0
initstr3 db 'tatOS init',0
initstr5 db 'Jump to start of SHELL',0
initstr8 db '3:Setting up FPU',0
initstr9 db '4:Filling sin/cos lookup tables',0
initstr11 db 'root       ',0  ;11 bytes + terminator




