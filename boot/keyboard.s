;tatOS/boot/keyboard.s

;this file is included in boot2.s

;rev: June 2012 

;this is irq1
;this code converts ps/2 keyboard scancodes to ascii bytes
;and stores the byte in the keyboard buffer at memory address 0x504

;KEYBOARD
;developed on the US IBM "Windows" 104 key board
;with standard 61 keypad covering A-Z, 0-9, enter, shift, ctrl...
;"Windows" and "menu" keys either side of spacebar
;12 function keys across the top plus prntscrn, scrllck,pause
;17 numeric keypad to the far right
;4 arrow keys group
;ins/del/home/end/Pgup/Pgdn group
;ps/2 round 6 pin connector on end of chord

;SCANCODE SET = 1 (XT)
;on boot, keymouseinit.s checks the scan code num
;the scancode set num must be 0x41 which is set=1
;sets 2 and 3 are not supported by this driver

;some examples of set 1

;         keydown     keyup  
;escape   01          81           
;1        02          82
;2        03          83
;3        04          84
;a        1e          9e
;b        30          b0
;c        2e          ae
;home     e0 47       eo c7 
;up       e0 48       e0 c8 
;Larrow   e0 4b       e0 cb
;DNarrow  e0 50       e0 d0
;Delete   e0 53       e0 d3
;LALT     0x38        0xb8

;note for keydown bit7 is clear and for keyup bit7 is set

;NUMLOCK
;unsupported for now
;some keys are numlock sensitive:
;insert,delete,home,end,pageup,pagedn and 4 arrow keys
;you get an "e0 2a" prefix and "e0 aa" suffix if numlock is on
;specific examples with numlock on:
;home:  e0 2a e0 47 (down) e0 c7 e0 aa (up)
;end :  e0 2a e0 4f (down) e0 cf e0 aa (up)
;left:  e0 2a e0 4b (down) e0 cb e0 aa (up)
;right: e0 2a e0 4d (down) e0 cd e0 aa (up)
;note: numeric keypad does not respond to numlock

;the Ctrl, Shift and Alt keys have their own
;memory address and we set 1=down and 0=up for these
;Ctrl  = 0x506
;Shift = 0x507
;Alt   = 0x508

;KEYUP
;except for Ctrl, Shift and Alt
;we ignore all keyups and exit the driver

;UNSUPPORTED KEYS
;pause, LGUI, RGUI, NUMLOCK
;if you press these keys nothing happens

;MENU
;when you press the "menu" key which is just left of R-Ctrl
;the value 0xa5 defined as MENU in tatos.inc is put in the keyboard buffer 
;this key is also referred to as the APPS key
;after a call to getc, apps may check for the MENU keypress and draw a menu
;see bits.s for an example

;PRINTSCREEN
;this will write a tatOS BTS file of the entire screen to the IMAGEBUFFER

;CTRL+ALT+DEL
;this will kick you back to start of SHELL 

;local
keyboard_irq_color dd 0

;***********************************************************************


irq1:  

	cli	
	pushad
	push ds
	push es
	push fs
	push gs

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax


	;read the port
	in al,0x60          ;read byte at port
	mov [_scancode],al  ;save the scancode 

	

	;for debug
	;call [DUMPBYTE]
	;and if you are really desperate to see if you are getting keyboard irq's
	;this will put a colored rect on the screen for every keydown and keyup
	;STDCALL 0,0,50,50,[keyboard_irq_color],[0x10028]  ;fillrect
	;add dword [keyboard_irq_color],1   ;change color so keyup is differant from keydown
	;call [0x10068]  ;swapbuf




	;Pause key unsupported
	;ignore the 4 bytes after E1
	cmp byte [_haveE1],1
	jnz .notE1
	dec byte [_E1count]
	jnz near .keydone
	mov byte [_haveE1],0
	jnz near .keydone
.notE1:


	;Pause key unsupported
	;you will get 6 total interrupts with this keydown
	;Pause key = E1 1d 45 e1 9d c5
	cmp al,0xe1
	jnz .noPause
	mov byte [_haveE1],1
	mov byte [_E1count],4 ;ignore the next 4 interrupts
	jmp near .keydone
	.noPause:




	;E0
	cmp al,0xe0
	jnz .notE0 
	mov byte [_haveE0],1
	jz near .keydone
.notE0:



	;2A
	;e0 2a is a numlock prefix
	;but 2a is also Lshift down
	cmp al,0x2a
	jnz .not2a
	cmp byte [_haveE0],1
	jz near .clearE0
	mov byte [SHIFTKEYSTATE],1
	jmp near .keydone
.clearE0:
	mov byte [_haveE0],0
	jmp near .keydone
	.not2a:
	



	;AA
	;e0 aa is a numlock suffix
	;aa without e0 is Lshift up
	cmp al,0xaa
	jnz .notaa
	cmp byte [_haveE0],1
	jz near .clearE0again
	mov byte [SHIFTKEYSTATE],0
	jmp near .keydone
.clearE0again:
	mov byte [_haveE0],0
	jmp near .keydone
	.notaa:



	;test for LGUI down and disable
	cmp al,0x5b
	jnz .notLGUIdn
	jmp near .keydone
.notLGUIdn:


	;test for LGUI up and disable
	cmp al,0xdb
	jnz .notLGUIup
	jmp near .keydone
.notLGUIup:


	;test for RGUI down and disable
	cmp al,0x5c
	jnz .notRGUIdn
	jmp near .keydone
.notRGUIdn:


	;test for RGUI up and disable
	cmp al,0xdc
	jnz .notRGUIup
	jmp near .keydone
.notRGUIup:



	
	




	;************************
	;CUT/COPY/PASTE
	;************************


	;someday if we get enough of these special ctrl keys
	;we should implement a CTRL lookup table 
	;just like the shifts


	;CUT (Ctrl+X)
	cmp al,0x2d 
	jnz .notcut
	cmp byte [CTRLKEYSTATE],1
	jnz .notcut
	mov bl,CUT  ;return CUT
	jmp near .save_keypress
.notcut:



	;COPY (Ctrl+C)
	cmp al,0x2e 
	jnz .notcopy
	cmp byte [CTRLKEYSTATE],1
	jnz .notcopy
	mov bl,COPY  ;return COPY
	jmp near .save_keypress
.notcopy:



	;PASTE (Ctrl+V)
	cmp al,0x2f 
	jnz .notpaste
	cmp byte [CTRLKEYSTATE],1
	jnz .notpaste
	mov bl,PASTE  ;return PASTE
	jmp near .save_keypress
.notpaste:




	;*******************************
	;CTRL/ALT/SHIFT
	;we test for down and up
	;and set a 1/0 global value 
	;lookup tables not used
	;********************************

	;ALT down
	cmp al,0x38 
	jnz .not38
	mov byte [ALTKEYSTATE],1
	.not38:

	;ALT up
	cmp al,0xb8
	jnz .notb8
	mov byte [ALTKEYSTATE],0
	.notb8:

	;CTRL down
	cmp al,0x1d
	jnz .not1d
	mov byte [CTRLKEYSTATE],1
	.not1d:

	;CTRL up
	cmp al,0x9d
	jnz .not9d
	mov byte [CTRLKEYSTATE],0
	.not9d:

	;LSHIFT down  
	;LSHIFT up
	;see above under 2a and aa
	
	;RSHIFT down
	cmp al,0x36
	jnz .not36
	mov byte [SHIFTKEYSTATE],1
	.not36:

	;RSHIFT up
	cmp al,0xb6
	jnz .notb6
	mov byte [SHIFTKEYSTATE],0
	.notb6:

	;SPACE bar down
	cmp al,0x39
	jnz .not39
	mov byte [SPACEKEYSTATE],1
	.not39:

	;SPACE bar up
	cmp al,0xb9
	jnz .notb9
	mov byte [SPACEKEYSTATE],0
	.notb9:



	

	;*****************
	;test for keyup
	;*****************

	;the low 6 bits of the scan code do not change
	;for any particular key from keyup to keydown
	;only bit7 changes
	;bit7 is 1 on keyup, 0 on keydown
	mov al,[_scancode]
	test al,10000000b
	jz .convert2ascii
	
	
	;keyup
	;ignore all keyups for now
	;getc will continue to loop
	;because all it sees is 0 at 0x504
	
	;clear E0 key (like "e0 9c" for numeric enter keyup)
	mov byte [_haveE0],0

	jmp near .keydone
	


.convert2ascii:


	;***************************
	;convert scancode to ascii 
	;***************************
	xor eax,eax

	;our lookup tables are just sequential 
	;collections of the scancodes 
	;so we can use the scancode as an index 
	;into the lookup table
	mov al,[_scancode]
	

	;E0 Table 
	cmp byte [_haveE0],1
	jnz .notE0Table
	mov ebx,[E0Table + eax - 0x1c] 
	mov byte [_haveE0],0
	jmp .save_keypress
	.notE0Table:


	;Shift Table
	cmp byte [SHIFTKEYSTATE], 1
	jnz .notShiftTable
	mov ebx,[ShiftTable + eax] 
	jmp .save_keypress
	.notShiftTable:

		
	;Standard Table
	mov ebx,[StandardTable + eax] 
	jmp .save_keypress
	


.save_keypress:

	;here we save the ascii keypress
	;apps like getc will set this byte to 0
	;then poll for a change by this driver
	mov [0x504],bl



	;this is the normal end of our isr
	;the code after this point is used to perform 
	;special functions independent of the current process
	



	;************************
	; 	PRINTSCREEN
	;************************
	
	;write a tatOS BTS file 800x600 of the current screen to IMAGEBUFFER
	;you can save this image to flash from the BitmapViewer
	cmp bl,PRNTSCR
	jnz .notprintscreen
	call [PRINTSCREEN]
	;this will kill the app because we saved a byte
	;to 0x504 above and a call to GETC in the app
	;will then fall thru.
.notprintscreen:



	;************************
	; 	CTRL+ALT+DEL
	;************************

	;this is manual process control :)
	;immediate redirection of instruction pointer
	;jmp back to start of Tedit.s 
	;use this after a processor trap/abort/exception
	;or if stuck in infinite loop

	cmp bl, DELETE ;must hold down CTRL+ALT before DEL is pressed
	jnz .noctrlaltdel

	mov al,[CTRLKEYSTATE]
	add al,[ALTKEYSTATE]
	cmp al,2
	jnz .noctrlaltdel


	STDCALL _ctrlaltdel,[DUMPSTR]

	;no keypress available to GETC
	mov byte [0x504],0   

	;restore topdown orientation of y axis
	mov dword [YORIENT],1

	;restore XOFFSET and YOFFSET
	mov dword [XOFFSET],0
	mov dword [YOFFSET],0

	;restore the stdpallete 
	push 0
	call [SETPALETTE]


	;iret would take 12 bytes off stack in 32bit mode
	pop eax  ;return address
	pop eax  ;code segment
	pop eax  ;EFLAGS


	;kernel data selectors are kept since we are jumping to the shell

	;end of interrupt signal
	mov al,0x20
	out 0x20,al  
	popad
	sti         

	jmp near [SHELL]  ;start of the tatos shell 
.noctrlaltdel:





.keydone:
	;end of interrupt signal
	mov al,0x20
	out 0x20,al  

	;restore interrupted routine data selectors
	pop gs
	pop fs
	pop es
	pop ds
	popad
	sti  
	iret  
	;iret pops eip,cs,eflags
	;if return is to another privaledge level
	;iret also pops esp & ss




_err1 db 'return address for keyboard isr',0
_returnaddress dd 0
_scancode  db 0   
_haveE1 db 0
_haveE0 db 0
_E1count db 0
_ctrlaltdel db 'Ctrl+Alt+Delete',0




;the values in CAPS are defined in tatos.inc


;scancode set=1  
;our keymap to convert scancode to lower/upper case ascii
;the table is built in sequential order by scancode
;ESC is scancode=1, 1 is scancode=2, 2 is scancode=3...
;some scancodes are intercepted before table lookup
;0 bytes are just placeholders



StandardTable:
db 0                                  ;scancode 0
db ESCAPE, '1234567890-=', BKSPACE    ;scancode 1-0xe
db TAB, 'qwertyuiop[]', ENTER, CTRL   ;scancode 0xf-0x1d
db 'asdfghjkl;', "'", '`'             ;scancode 0x1e-0x29
db SHIFT, '\', 'zxcvbnm,./', SHIFT    ;scancode 0x2a-0x36
db '*', ALT, ' ', CAPSLOCK            ;scancode 0x37-0x3a
db F1, F2, F3, F4, F5, F6, F7, F8, F9 ;scancode 0x3b-0x43
db F10, NUMLOCK, SCRLOCK              ;scancode 0x44-0x46
db '789-456+1230.'                    ;scancode 0x47-0x53
db 0,0,0, F11, F12                    ;scancode 0x54-0x58



ShiftTable:
db 0 
db ESCAPE, '!@#$%^&*()_+', BKSPACE 
db TAB, 'QWERTYUIOP{}', ENTER, CTRL
db 'ASDFGHJKL:"~'  
db SHIFT, '|', 'ZXCVBNM<>?', SHIFT
db '*', ALT, ' ', CAPSLOCK 
db F1, F2, F3, F4, F5, F6, F7, F8, F9 
db F10, NUMLOCK, SCRLOCK
db '789-456+1230.'
db 0,0,0,F11, F12



E0Table:
db ENTER, CTRL,                  ;scancode 0x1c-0x1d
db 0,0,0,0,0,0,0,0,0,0           ;scancode 0x1e-0x27
db 0,0,0,0,0,0,0,0,0,0           ;scancode 0x28-0x31
db 0,0,0,                        ;scancode 0x32-0x34
db '/', 0, PRNTSCR, ALT          ;scancode 0x35-0x38
db 0,0,0,0,0,0,0,0,0,0           ;scancode 0x39-0x42
db 0,0,0,0                       ;scancode 0x43-0x46
db HOME, UP, PAGEUP, 0, LEFT     ;scancode 0x47-0x4b
db 0,RIGHT, 0, END               ;scancode 0x4c-0x4f
db DOWN, PAGEDN, INSERT, DELETE  ;scancode 0x50-0x53
db 0,0,0,0,0,0,0                 ;scancode 0x54-0x5a
db GUI, GUI, MENU                ;scancode 0x5b-0x5d 




	;NUMLOCK light
	;the numlock light seems to be on by default at startup
	;so we just toggle it here hopefully turning it off
	;cmp al,0x45
	;jnz .notnumlock
	
	;tell keyboard next byte is for lights
	;call wait_write
	;mov al,0xed
	;out 0x60,al
	;call wait_read
	;in al,0x60  ;read the fa
	
	;flip the numlock bit
	;xor byte [keyboardlights],010b

	;write it back
	;call wait_write
	;mov al,[keyboardlights]
	;out 0x60,al
	;call wait_read
	;in al,0x60  ;read the fa
	;.notnumlock




