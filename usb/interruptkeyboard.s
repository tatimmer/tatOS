;tatOS/usb/interruptkeyboard.s


;usbkeyboardrequest
;usbgetc
;getKeyboardReportBuf
;usbShowKeyboardReport


;code to conduct usb interrupt transactions for the usb keyboard

;a usb interrupt requires polling
;you queue up a request (prepare interruptTD) and wait for a key to be pressed
;then you check the memory block (keyboard report) for a change and if so
;decode the report, translate it to an ascii char and queue up a new request
;this is not at all like a ps2 keyboard hardware interrupt



ukbstr1:
db 'USB Show Keyboard Report',NL 
db 'Press 1 or more keys simultaneously, observe the report',NL
db 'To exit, press ESCAPE',0

ukbstr2 db 'usbgetc',0



;*********************************************************
;usbkeyboardrequest

;prepares a keyboard interrupt TD and attach to QH 
;to get the keyboard going

;input:none
;return:none
;*********************************************************

usbkeyboardrequest:

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

	;zero out the first 4 bytes of the keyboard report buffer
	;to something the keyboard can not possibly give
	mov dword [KEYBOARD_REPORT_BUF],0x09090909

	;build a new TD
	call uhci_prepareInterruptTD_keyboard   ;registers are preserved

	;attach TD to second dword of queue head 
	;nothing happens til you press a key
	;then the TD is retired and must queue up another
	mov dword [KEYBOARD_UHCI_INTERRUPT_QH+4],KEYBOARD_INTERRUPT_TD  

%endif

%if USBCONTROLLERTYPE == 2  ;ehci 

	;ehci keyboard report buffer for interrupt transfer is 0x1009000 page aligned
	;write to the report a value the keyboard can not possible give
	;we use this to check for keyboard activity
	mov dword [0x1009000],0x09090909

	;keyboard interruptTD is written to 0x1003300, registers are preserved
	call generate_keyboard_TD  

	;attach TD to 5th dword of KEYBOARD_INTERRUPT_QH to begin transaction
	mov dword [KEYBOARD_INTERRUPT_QH_NEXT_TD_PTR], 0x1003300

%endif



	ret





;***************************************************************************
;usbShowKeyboardReport

;this routine will display the 8 byte usb keyboard report

;before you run this program you must init the controller and keyboard
;this function is called from usbcentral

;the keyboard report is an 8 byte sequence: [aa bb cc dd ee ff gg hh]
;when you press a single key a-z or 1-3 or F1-F12
;then a byte value is returned in the cc byte

;when you press LCTRL, LALT or LSHIFT a value is returned in the aa byte

;with all keys up the report is 00 00 00 00 00 00 00 00

;for more details on what the usb keyboard report is for various
;key combinations, see tatOS/doc/usbkeybd

;input:none
;return: none
;*********************************************************************

usbShowKeyboardReport:

	call usbkeyboardrequest

	;we want the keyboard report to be persistant
	;so we do not clear the backbuffer on every paint cycle
	;only once at the start
	call backbufclear

	;program messages
	STDCALL FONT01,100,50,ukbstr1,0xefff,putsml 


.1: ;top of paint loop


	;test if user wants to quit, we read the keyboard report cc byte directly
	;tom need to wait on this until we get all the bugs out of usb keyboard driver
	;right now we are loosing the keyboard after initting flash on the other port :(
	;cmp byte [KEYBOARD_REPORT_BUF+2],0x29  ;ESCAPE=0x29
	;jz near .done



	;use the PS2 keyboard to test if user wants to quit
	;must have a sleep here
	;otherwise we never get any response from checkc
	;the ps2 keyboard controller is slow 
	mov ebx,5
	call sleep
	call checkc  ;zf is set if no key pressed
	jz .2
	cmp al,ESCAPE
	jz near .done




.2:

	;box around the keyboard report
	STDCALL 92,195,250,30,BLA,rectangle



%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

	;test for activity 
	cmp dword [KEYBOARD_REPORT_BUF],0x09090909
	jz .3  
	;if you comment out this check
	;all you see is 09090909 all the time
	;when you press a key the 09090909 flickers but you cant see
	;how the report has changed.

	;display the 8 bytes of the keyboard report buf
	;if the keyboard initiated properly
	;you should see 00 00 00 00 00 00 00 00 with all keys up
	STDCALL 100,200,0xfeef,KEYBOARD_REPORT_BUF,8,putmem

%endif

%if USBCONTROLLERTYPE == 2  ;ehci 

	;test for keyboard activity 
	cmp dword [0x1009000],0x09090909
	jz .3  ;no keyboard activity so check for keypress

	;display the raw bytes of the keyboard report buffer
	STDCALL 100,200,0xfeef,0x1009000,8,putmem

%endif




	;queue up a new request
	call usbkeyboardrequest

.3:
	call swapbuf  ;endpaint
	jmp .1        ;bottom of loop


.done:


	;queue up a new request
	;this function also "zero's" out the keyboard buffer
	call usbkeyboardrequest   ;registers are preserved

	ret






;****************************************************************************
;usbgetc

;this is a user apps main function to read the usb keyboard report
;and return an ascii character, it is designed to be used in an appmainloop

;this is a non-blocking function 
;the function will return immediately after checking the usb KEYBOARD_REPORT_BUF

;the Gear Head usb keyboard returns an 8 byte report [aa bb cc dd ee ff gg hh]
;if you only press 1 key then the result is in the cc byte
;see doc/usbkeybd for details

;the tatOS usb keyboard driver does not support all key press combinations
;only the most commonly used single and double key presses
;the only triple key press supported is LCTRL+LALT+DEL which kicks you
;back to the shell

;the usb keyboard report is written to 0x1009000=KEYBOARD_REPORT_BUF

;note currently there is no repeat, holding down a single key for a prolonged 
;period of time does not generate additional reports


;input:none
;return:
;      al=ascii char (translated from the 'cc' byte of the usb keyboard report)
;      al=0 no keyboard activity since last report

;      ebx=state of the LCTRL,LALT,LSHIFT keys
;      ebx=0 if none of these keys are down
;      ebx=1 if LCTRL  is down
;      ebx=2 if LALT   is down
;      ebx=3 if LSHIFT is down

;*****************************************************************************

usbgetc:

	;STDCALL ukbstr2,dumpstr

	;note the user app must have sufficient amount of 
	;processor activity before calling usbgetc
	;otherwise we must insert a call to "sleep" for at least 5ms
	;to prevent the usb keyboard from becoming unresponsive 
	;not quite sure why


	mov eax,0
	mov ebx,0


	;get the keyboard report
	mov esi,[KEYBOARD_REPORT_BUF]
	
	
	;test for activity 
	cmp esi,0x09090909  ;indicates no activity since last queue up
	jz near .done       ;no need to queueUP, the interrupt TD is still good


	;if we got here we have activity
	;translate the keyboard report into an ascii char



	;check for CTRL+ALT+DEL   (3 key combination)
	;*********************************************
	;this will take you back to the shell
	cmp dword [KEYBOARD_REPORT_BUF],0x004c0005
	jnz .doneCTRLALTDEL

	;restore topdown orientation of y axis
	mov dword [YORIENT],1

	;restore XOFFSET and YOFFSET
	mov dword [XOFFSET],0
	mov dword [YOFFSET],0

	;restore the stdpallete 
	push 0
	call setpalette

	;kernel data selectors are kept since we are jumping to the shell

	jmp near shell  ;start of the tatOS shell 
.doneCTRLALTDEL:



	;check for CUT = LCTRL + x  (2 key combination)
	;************************************************
	cmp dword [KEYBOARD_REPORT_BUF],0x001b0001
	jnz .doneCUT 
	mov eax,CUT
	mov ebx,1
	jmp .done
.doneCUT:


	;check for COPY = LCTRL + c   (2 key combination)
	;***************************************************
	cmp dword [KEYBOARD_REPORT_BUF],0x00060001
	jnz .doneCOPY
	mov eax,COPY
	mov ebx,1
	jmp .done
.doneCOPY:


	;check for PASTE = LCTRL + v  (2 key combination)
	;****************************************************
	cmp dword [KEYBOARD_REPORT_BUF],0x00190001
	jnz .donePASTE
	mov eax,PASTE
	mov ebx,1
	jmp .done
.donePASTE:


	;check for LCTRL down
	cmp byte [KEYBOARD_REPORT_BUF],1
	jnz .doneLCTRL
	mov ebx,1
	jmp .checkCC 
.doneLCTRL:


	;check for LALT down
	cmp byte [KEYBOARD_REPORT_BUF],4
	jnz .doneLALT
	mov ebx,2
	jmp .checkCC 
.doneLALT:


	;check for LSHIFT down
	cmp byte [KEYBOARD_REPORT_BUF],2
	jnz .doneLSHIFT
	mov ebx,3
	jmp .checkCC 
.doneLSHIFT:

		

.checkCC:

	;check for a cc byte down, a-z, 0-9, function keys etc...
	;*********************************************************
	movzx ecx, byte [KEYBOARD_REPORT_BUF+2]
	cmp ecx,0
	jz .doneCC
	;translate the cc byte to ascii
	movzx eax, byte [Translate_CC_byte_2ascii + ecx]
.doneCC:



.queueUP:
	;queue up a new usb keyboard request
	push eax
	push ebx
	call usbkeyboardrequest
	pop ebx
	pop eax

.done:
	;return values in eax,ebx  
	ret


	


;the following table is applicable to this Gear Head keyboard
;when you only press a singe key and get a cc byte
;see also tatOS.inc which defines these non-displayable keys

Translate_CC_byte_2ascii:        
;  ascii                          ;keyboard report cc byte in hex
;****************************************************************
db 0,0,0,0,                       ;0,1,2,3  all none
db 'abcde'                        ;4,5,6,7,8
db 'fghij'                        ;9,a,b,c,d
db 'klmno'                        ;e,f,10,11,12
db 'pqrst'                        ;13,14,15,16,17
db 'uvwxy'                        ;18,19,1a,1b,1c
db 'z1234'                        ;1d,1e,1f,20,21
db '56789'                        ;22,23,24,25,26
db '0',ENTER,ESCAPE,BKSPACE,TAB   ;27,28,29,2a,2b
db SPACE,'-=[]'                   ;2c,2d,2e,2f,30
db '\',0,';',39,'`'               ;31,32=none,33,34=squote,35=btick
db 44,'./',0                      ;36=comma,37=period,38=fslash,39=none
db F1,F2,F3,F4,F5                 ;3a,3b,3c,3d,3e
db F6,F7,F8,F9,F10                ;3f,40,41,42,43
db F11,F12,PRNTSCR,SCRLOCK,BREAK  ;44,45,46,47,48   
db INSERT,HOME,PAGEUP,DELETE      ;49,4a,4b,4c
db END,PAGEDN,RIGHT,LEFT          ;4d,4e,4f,50
db DOWN,UP,NUMLOCK                ;51,52,53



