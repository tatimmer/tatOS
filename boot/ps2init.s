;tatOS/boot/ps2init.s


;Jan 2010 - removed ps2mouseinit
;Dec09-output messages to dump instead of screen

;Routines to initialize the ps/2 keyboard 
;this code works for:
;  * ps/2 keyboard with 104 keys and defaults to scan code set=1

;You must have a ps/2 keyboard connected before boot
;the ps/2 keyboard is enabled and the typematic rate is increased to max

;see doc/memorymap for storage of key parameters

;inport64 and check appropriate bits before inport60 or outport64
;thats what wait_read and wait_write are for
;8042 - motherboard controller chip - port64
;8048 - keyboard controller chip    - port60
;inport60 to get data/response



jmp near init_keyboard


keymouse2 db 'ps2: wait_write timeout error',0 
keymouse3 db 'ps2: wait_read timeout error',0 
keymouse6 db 'ps2: Enabling the ps/2 keyboard',0
keymouse7 db 'ps2: Set kb auto repeat rate',0
keymouse10 db 'ps2 key status',0
keymouse11 db 'ps2: key echo',0
keymouse13 db 'ps2: port60 read',0




;***************************************************************
;keyboardstatus
;print the contents of the status register
;the register is part of the 8042 controller on motherboard
;no input no return
;we read status register port 0x64
;b3=0 indicates last write to 0x60, 1=0x64 was last
;b4=keyboard is inhibited if data in output buffer

;if status=0x15 then output buf is full and keyboard wont work
;the controller puts data into the output buffer 
;you must read that data from 0x60 to clear bit0 

keystatstr0 db 'Output Buffer Full',0
keystatstr1 db 'Input  Buffer Full',0
keystatstr2 db 'System Flag',0
keystatstr3 db 'Last Port Write, 0=DataPort 60h, 1=CommandPort 64h',0
keystatstr4 db 'Output Buffer Inhibit, 0=Keyboard is Inhibited',0
keystatstr5 db 'Transmit TimeOut',0
keystatstr6 db 'Receive TimeOut',0 
keystatstr7 db 'Parity Error',0
keystatstr8 db 'Keyboard Status Register',0
;**************************************************************

keyboardstatus:

	in al,0x64
	and eax,0xff
	STDCALL keymouse10,0,[DUMPEAX]

%if VERBOSEDUMP

	STDCALL keystatstr8, [DUMPSTR]
	STDCALL keystatstr0, 0,1,[0x10278]  ;dumpbitfield 
	STDCALL keystatstr1, 1,1,[0x10278]  
	STDCALL keystatstr2, 2,1,[0x10278]  
	STDCALL keystatstr3, 3,1,[0x10278]  
	STDCALL keystatstr4, 4,1,[0x10278]  
	STDCALL keystatstr5, 5,1,[0x10278]  
	STDCALL keystatstr6, 6,1,[0x10278]  
	STDCALL keystatstr7, 7,1,[0x10278]  

%endif
	ret


;*****************************************************
;putalscroll
;display the contents of al to the screen and scroll 
;local
ps2buf times 10 db 0
;*****************************************************
putalscroll:
	mov edi,ps2buf
	mov edx,2     ;do al
	call [0x100c0]   ;eax2hex
	STDCALL ps2buf,0,[DUMPEAX]
	ret







;********************************************
;wait_write
;checks keyboard controller status register 0x64
;to see if INPUT buffer is empty
;this function also used by driver mouse.s
;input:none
;********************************************
wait_write:
	push ecx
	mov ecx,0xa0000
.1:
	in al,0x64          ;read status reg
	;bit1 of al is 0 if input buffer ready to receive
	test al,10b   
	jz .2               ;success
	dec ecx
	jnz .1

	;time out error
	STDCALL keymouse2,[DUMPSTR]

.2:
	pop ecx
	ret


;********************************************
;wait_read
;checks keyboard controller status register
;to see if OUTPUT buffer is full
;this function also used by driver mouse.s
;input:none
;********************************************
wait_read:
	push ecx
	mov ecx,0xa0000
.1:
	in al,0x64         ;read status reg
	;bit0 is 0 if output buffer not ready to be read
	test al,1  
	jnz .2             ;success
	dec ecx
	jnz .1
	
	;time out error
	STDCALL keymouse3,[DUMPSTR]

.2:
	pop ecx
	ret




init_keyboard:

	STDCALL keymouse6,[DUMPSTR]


	call keyboardstatus
	;I get status=0x15
	;the keyboard will not work at this point



	;8042 motherboard: enable keyboard
	call wait_write
	mov al,0xae   
	out 0x64,al
	call wait_read
	in al,0x60  
	and eax,0xff
	STDCALL keymouse13,0,[DUMPEAX]
	;I get al=0xfe resend



	call keyboardstatus
	;I get status=0x1c



	;8048 keyboard: clear output buffer/enable keyboard
	call wait_write
	mov al,0xf4   
	out 0x60,al
	call wait_read
	in al,0x60  
	and eax,0xff
	STDCALL keymouse13,0,[DUMPEAX]
	;I get al=0xfa



	call keyboardstatus
	;I get status=0x14



	;8048 keyboard: echo	
	STDCALL keymouse11,[DUMPSTR]
	call wait_write
	mov al,0xee   
	out 0x60,al
	call wait_read
	in al,0x60  
	and eax,0xff
	STDCALL keymouse13,0,[DUMPEAX]
	;I get al=0xee



	call keyboardstatus
	;I get status=0x14




	;8048 keyboard: delay/typematic rate	
	;so the keyboard responds faster
	;you could skip this code but then some keyboards
	;respond slowly when you want to scroll using up/dn arrow 
.setrate:
	STDCALL keymouse7,[DUMPSTR]
	call wait_write
	mov al,0xf3
	out 0x60,al
	call wait_read
	in al,0x60  
	and eax,0xff
	STDCALL keymouse13,0,[DUMPEAX]


	;0aabbbbb is the setting
	;the default setting is 00101011 giving 500/20.9
	;aa=500ms until it starts repeating
	;bbbbb=30 char/sec while repeating (this is max possible)
	call wait_write
	mov al,00100000b
	out 0x60,al
	call wait_read
	in al,0x60
	and eax,0xff
	STDCALL keymouse13,0,[DUMPEAX]

	cmp al,0xfe 
	jz .setrate



	call keyboardstatus
	;I get status=0x14



	;Jan 2010 I have removed the ps2mouseinit code
	;the usb mouse is now the std



.ps2done:

	;initialize our global mouse x,y position to lower right corner
	;the app is responsible for drawing the mouse cursor/pointer
	;see tlib/pointer.s
	mov [MOUSEX],dword 750
	mov [MOUSEY],dword 550



;for debug
;call [0x100dc]  ;dumpview	


