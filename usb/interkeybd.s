;tatOS/usb/interkeybd.s


;usbkeyboardrequest
;set_usb_keyboard_polling_frequency
;getKeyboardReportBuf
;usbShowKeyboardReport
;usbkeyboardinterrupt
;ProcessUsbKeyboardReport


;code to conduct usb interrupt transactions for the usb keyboard

;a usb interrupt requires polling
;you queue up a request (prepare interruptTD) and wait for a key to be pressed
;then you check the TD status for a change 
;and if so decode the report, translate it to an ascii char and queue up a new request
;this is not at all like a ps2 keyboard hardware interrupt

;see /boot/irq0.s PIT timer, we are now using this to continually pound 
;the usb keyboard with requests at a regular rate



ukbstr1:
db 'USB Show Keyboard Report',NL 
db 'Press 1 or more keys simultaneously, observe the report',NL
db 'To exit, press Ctrl+Esc',0


ukbstr2  db 'testing for key held down',0
ukbstr3  db 'noCCbyte',0
ukbstr4  db 'queueUP',0
ukbstr5  db 'no_interruptTD_change',0
ukbstr6  db '******* cc byte *******',0
ukbstr7  db 'keyUP',0
ukbstr8  db 'have dd byte',0
ukbstr9  db 'ProcessUsbKeyboardReport',0
ukbstr10 db 'convert cc byte to ascii',0
ukbstr11 db 'cc byte not same as previous',0
ukbstr12 db 'previous report was keyUP',0
ukbstr13 db 'testing 00 00 00 00 keyup',0
ukbstr14 db 'checking usb keyboard counter',0
ukbstr15 db 'testing for keyboard interruptTD changes',0
ukbstr16 db 'uhci TD control/status',0
ukbstr17 db 'NAK',0
ukbstr18 db 'cc byte is same as previous',0
ukbstr19 db 'return 0',0
ukbstr20 db 'return previous cc byte',0
ukbstr21 db 'have_keyup',0
ukbstr22 db 'TwoDownReleasedOne',0
ukbstr23 db 'testing dd byte',0
ukbstr24 db '[usbkeyboardinterrupt] value of byte [0x50b]',0
ukbstr25 db 'TimeOut error',0
ukbstr26 db 'previous report was cc and dd down',0
ukbstr27 db 'save cc bytes as previous',0
ukbstr28 db 'dword [have_cc_and_dd]',0


cc_byte_previous     db 0
cc_ascii_previous    db 0
have_keyup           dd 0
usbkeyboardcounter   dd 0
have_cc_and_dd       dd 0



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
	call uhci_generate_keyboard_TD   ;registers are preserved

	;attach TD to QH to begin transaction
	mov dword [KEYBOARD_UHCI_INTERRUPT_QH+4],KEYBOARD_INTERRUPT_TD  

%endif

%if USBCONTROLLERTYPE == 2  ;ehci 

	;ehci keyboard report buffer for interrupt transfer is 0x1009000 page aligned
	;write to the report a value the keyboard can not possible give
	;we use this to check for keyboard activity
	mov dword [KEYBOARD_REPORT_BUF],0x09090909

	;copy the static keyboard interruptTD to 0x1003300 for interrupt transfer
	;the data toggle is now maintained by the QH
	;see prepareTD-ehci.s
	cld
	mov ecx,13
	mov esi,ehci_keyboard_interrupt_TD
	mov edi,0x1003300
	rep movsd

	;attach TD to 5th dword of KEYBOARD_INTERRUPT_QH to begin transaction
	mov dword [KEYBOARD_INTERRUPT_QH_NEXT_TD_PTR], KEYBOARD_INTERRUPT_TD

%endif



	ret




;**************************************************************
;set_usb_keyboard_polling_frequency
;the usb keyboard interrupt routine is called by the PIT
;at regular intervals, here we set the interval.
;input:none
;return:none
;*************************************************************

set_usb_keyboard_polling_frequency:

	;for uhci or ehci
	;I used to have seperate values for each, but no need
	mov dword [USBKEYBDPOLLFREQ],20

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

	call backbufclear

	;program messages
	STDCALL FONT01,100,50,ukbstr1,0xefff,putsml 

	;box around the keyboard report
	STDCALL 92,195,250,30,BLA,rectangle

	;modify the usb keyboard polling frequency for this procedure only
	mov dword [USBKEYBDPOLLFREQ],100


.1: ;top of paint loop

	;need to call this otherwise report is frozen
	mov ebx,1
	call sleep

	call checkc  

	;the user must press CTRL+ESC to quit
	;this allows you to see what is the report for the ESCAPE key
	cmp al,ESCAPE
	jnz .2
	cmp byte [CTRLKEYSTATE],1
	jz near .done


.2:
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

.3:
	call swapbuf  ;endpaint
	jmp .1        ;bottom of loop


.done:

	;reset the usb keyboard polling frequency for normal typing
	call set_usb_keyboard_polling_frequency

	ret






;****************************************************************************
;usbkeyboardinterrupt

;this function is called by the PIT (irq0) at routine intervals

;it checks the usb interruptTD for a change 
;if there is a change it does the following:
;   * convert usb keyboard report to ascii and store value at byte [0x50b] 
;   * queue up a new request

;if there is no change it stores 0 at byte [0x50b]

;this procedure does the same work that /boot/keyboard.s does for the ps2

;the Gear Head usb keyboard returns an 8 byte report [aa bb cc dd ee ff gg hh]
;if you only press 1 key then the result is in the cc byte
;see doc/usbkeybd for details

;the tatOS usb keyboard driver does not support all key press combinations
;only the most commonly used single and double key presses
;the only triple key press supported is LCTRL+LALT+DEL which kicks you
;back to the shell

;handy addresses to examine whats going on
;0x1003300  keyboard interruptTD for uhci
;0x1005200  keyboard interruptQH for uhci
;0x1009000  KEYBOARD_REPORT_BUF

;all the dumpstr and dumpeax calls are for debug only

;with uhci, holding down a key for a prolonged period does not generate 
;additional non-zero return values, the repeat key function only works with ehci

;input:none
;return:
;      saves ascii char to byte [0x50b] else 0
;      saves bytes [CTRLKEYSTATE], [ALTKEYSTATE], [SHIFTKEYSTATE] 

;*****************************************************************************

;April 2016
;spent alot of time on this code lately
;this version is based on version 46
;introduced new variable dword have_cc_and_dd

;*****************************************************************************


usbkeyboardinterrupt:

	;this value gets set to 1 in initkeyboard.s
	cmp dword [have_usb_keyboard],0
	jz near .nokeyboard


	;call dumpnl
	

	;test for keyboard interrupt TD changes 
	;look at the dword of the interrupt TD which holds the active bits
	;the usb controller will modify this after a keypress or timeout error
	;it is a mistake to just look at the keyboard report 
	;because sometimes the report does not change 
	;but the TD packet header does change due to a timeout error 

%if USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1


	;the 2nd dword of uhci TD contains the active bits

	;dump the TD dword
	;mov eax,[0x1003304]  
	;STDCALL 0,0,dumpeax  
	;call dumpnl

	;dump the first 4 bytes of the report
	;push KEYBOARD_REPORT_BUF
	;push 4  ;qty bytes
	;call dumpmem

	;put the TD 2nd dword into eax
	mov eax,[0x1003304]  

	;test TD bit19 for NAK, the uhci does this alot
	bt eax,19
	jc near .NAK

	;test TD bit18 for Time Out Error, the uhci also does this alot
	bt eax,18
	jc near .TimeOut

	;did the controller read/modify our TD ? 
	cmp eax,0x4800000  ;see prepareTD_uhci.s, uhci_generate_keyboard_TD
	jz near .no_interruptTD_change 

%endif

%if USBCONTROLLERTYPE == 2  ;ehci w/root hub

	;the 3rd dword of ehci TD contains the active bits
	mov eax,[0x1003308]  

	;and compare it to how we created it 
	cmp eax,[ehci_keyboard_interrupt_TD+8] 

	jz near .no_interruptTD_change 
	;no need to queueUP, the interrupt TD is still good
	;if user holds down a key for a prolonged period of time
	;the code will jump directly to .no_interruptTD_change

%endif

	
	;if we got here we have a change in the interruptTD 
	;this could be due to a keypress or release or timeout error
	;translate the keyboard report into an ascii char


	;dump the cc byte
	;mov al,[KEYBOARD_REPORT_BUF+2]
	;STDCALL ukbstr6,2,dumpeax  ;*** cc byte ***



	;test for all keys up report 00 00 00 00
	;we just look at the first 4 bytes of the report
	;if they are all zeros then all keys are up
	;STDCALL ukbstr13,dumpstr  ;testing for 00 00 00 00 keyup
	cmp dword [KEYBOARD_REPORT_BUF],0
	jnz .donekeyup
	;STDCALL ukbstr7,dumpstr   ;keyUP
	mov byte [CTRLKEYSTATE],0
	mov byte [ALTKEYSTATE],0
	mov byte [SHIFTKEYSTATE],0
	mov byte [0x50b],0
	mov dword [have_keyup],1
	mov byte [cc_byte_previous],0
	mov dword [have_cc_and_dd],0
	jmp .queueUP ;you must queueUP another request after getting this report 
.donekeyup:



	;there is another keyup case to consider
	;where you hold down two keys but release one

	


	
	;test for a dd byte 
	;user is holding down 2 keys at once
	cmp byte [KEYBOARD_REPORT_BUF+3],0
	jz .doneDD
	;STDCALL ukbstr8,dumpstr  ;have dd byte  

	;save the dd byte as previous
	mov al, [KEYBOARD_REPORT_BUF+3]
	mov [cc_byte_previous],al

	;overwrite cc byte with dd
	mov byte [KEYBOARD_REPORT_BUF+2],al

	;zero out the dd byte
	mov byte [KEYBOARD_REPORT_BUF+3],0

	mov dword [have_cc_and_dd],1

	call ProcessUsbKeyboardReport  ;returns 0 or 1
	cmp eax,0
	jz near .noCCbyte
	jmp near .queueUP
.doneDD:
	




	;was the previous report keyup ?
	;it is possible to get a series of reports something like this:
	;00 00 18 00 00 00 00 00
	;09 09 09 09 
	;09 09 09 09 
	;09 09 09 09 
	;00 00 18 00 00 00 00 00
	;here it looks like the user pressed the 'u' key twice 
	;with 3 cycles of no activity in between 
	;but there is no keyup
	;in fact the second 00 00 18 is not a keydown but a duplicate report 
	;do to polling speeds and keypress timing 
	cmp dword [have_keyup],1
	jnz .donePreviousKeyup
	;STDCALL ukbstr12,dumpstr  ;previous report was keyUP

	;save the cc byte as previous
	mov al, [KEYBOARD_REPORT_BUF+2]
	mov [cc_byte_previous],al
	mov dword [have_cc_and_dd],0

	call ProcessUsbKeyboardReport  ;returns 0 or 1
	cmp eax,0
	jz .noCCbyte
	jmp .queueUP
.donePreviousKeyup:






	;if we got here the previous report was not keyup
	;is the cc byte same as previous ?
	mov al,[KEYBOARD_REPORT_BUF+2]  ;al=cc byte current
	cmp al,[cc_byte_previous]
	jz .doneCCsameAsPrevious
	;STDCALL ukbstr11,dumpstr  ;cc byte not same as previous

	;if previous report was cc and dd held down we ignore cc 
	;user released one of two keys
	cmp dword [have_cc_and_dd],0
	jz .donetwokeys
	;STDCALL ukbstr26,dumpstr  ;prev report was cc and dd down 
	mov dword [have_cc_and_dd],0
	jmp near .noCCbyte
.donetwokeys:

	;STDCALL ukbstr27,dumpstr  ;save cc byte as previous
	mov al, [KEYBOARD_REPORT_BUF+2]
	mov [cc_byte_previous],al

	call ProcessUsbKeyboardReport  ;returns 0 or 1
	cmp eax,0
	jz .noCCbyte
	jmp .queueUP
.doneCCsameAsPrevious:



	;cc byte is same as previous, not a new keypress
	;ignore this cc byte and return 0
	;with uhci we get here alot
	;STDCALL ukbstr18,dumpstr  ;cc byte same as previous
	jmp .noCCbyte





.noCCbyte:
	;return nothing
	;STDCALL ukbstr3,dumpstr  ;noCCbyte
	mov byte [0x50b],0
	mov byte [cc_ascii_previous],0
	;fall thru to queueUP

.queueUP:
	;STDCALL ukbstr4,dumpstr  ;queueUP
	mov dword [usbkeyboardcounter],0
	;queue up a new usb keyboard request
	call usbkeyboardrequest
	jmp .done

.NAK:
	;STDCALL ukbstr17,dumpstr  ;uhci NAK
	;the uhci does this alot
	;the interruptTD 2nd dowrd = 0x48807ff (no bytes transferred, not ready)
	jmp .done

.TimeOut:
	;STDCALL ukbstr25,dumpstr  ;uhci TimeOut
	;the Via pci card with ehci + uhci companions does this alot
	;the interruptTD 2nd dword = 0x48407ff
	;do not queueUP here, no need, it will cause missed keystrokes
	jmp .done


.no_interruptTD_change:
	;we jump here most of the time with ehci & root hub
	;there has been no change in the keyboard interrupt TD packet header
	;usually the keyboard report will be 09090909

	;STDCALL ukbstr5,dumpstr  ;no_interrupt_TD_change

	;mov eax,[have_keyup]
	;STDCALL ukbstr21,0,dumpeax  ;value of have_keyup

	;is a key being held down?
	cmp dword [have_keyup],1
	jz .returnZero

	;inc only if key held down
	add dword [usbkeyboardcounter],1  

	;checking usb keyboard counter
	;STDCALL ukbstr14,dumpstr ;checking usb keyboard counter 
	;user must hold key down for 30 counts before we initiate the repeat key
	cmp dword [usbkeyboardcounter],30
	jb .returnZero

	.returnpreviousCC:
	   ;return previous cc value
       ;STDCALL ukbstr20,dumpstr ;return previous cc byte
	   mov al,[cc_ascii_previous]
	   mov [0x50b],al
	   jmp .done

   .returnZero:
       ;STDCALL ukbstr19,dumpstr ;return 0
	   mov byte [0x50b],0
	   ;fall thru
.done:

	;mov eax,[have_keyup]
	;STDCALL ukbstr21,0,dumpeax  ;value of have_keyup
	;mov al,[0x50b]
	;STDCALL ukbstr24,2,dumpeax  ;value of byte 0x50b
	;mov eax,[have_cc_and_dd]
	;STDCALL ukbstr28,0,dumpeax  ;value of have_cc_and_dd
	;fall thru

.nokeyboard:
	ret





	

;******************************************************
;ProcessUsbKeyboardReport

;convert the keyboard report buffer to ascii
;if we got here we have an aa byte or a new cc byte
;or a new dd byte that we converted to a cc byte

;input:none
;return:eax=0 do not queue UP a new interrupt request
;       eax=1 queue UP a new request
;*****************************************************

ProcessUsbKeyboardReport:

	;STDCALL ukbstr9,dumpstr  


	;check for CTRL+ALT+DEL   (3 key combination)
	;*********************************************
	;this will take you back to the shell
	cmp dword [KEYBOARD_REPORT_BUF],0x004c0005
	jnz .doneCTRLALTDEL

	mov dword [have_keyup],0

	;restore topdown orientation of y axis
	mov dword [YORIENT],1

	;restore XOFFSET and YOFFSET
	mov dword [XOFFSET],0
	mov dword [YOFFSET],0

	;restore the stdpallete 
	push 0
	call setpalette

	mov byte [0x50b],0
	call usbkeyboardrequest


	;this code same as irq1 for ps2 keyboard
	;since this function is called by irq0 we must deal with end-of-interrupt
	pop eax  ;return address
	pop eax  ;code segment
	pop eax  ;EFLAGS
	;kernel data selectors are kept since we are jumping to the shell
	mov al,0x20
	out 0x20,al
	popad
	sti

	jmp near shell  ;start of the tatOS shell 
.doneCTRLALTDEL:



	;check for CUT = LCTRL + x  (2 key combination)
	;************************************************
	cmp dword [KEYBOARD_REPORT_BUF],0x001b0001
	jnz .doneCUT 
	mov byte [0x50b],CUT
	mov dword [have_keyup],0
	jmp .queueUP
.doneCUT:


	;check for COPY = LCTRL + c   (2 key combination)
	;***************************************************
	cmp dword [KEYBOARD_REPORT_BUF],0x00060001
	jnz .doneCOPY
	mov byte [0x50b],COPY
	mov dword [have_keyup],0
	jmp .queueUP
.doneCOPY:


	;check for PASTE = LCTRL + v  (2 key combination)
	;****************************************************
	cmp dword [KEYBOARD_REPORT_BUF],0x00190001
	jnz .donePASTE
	mov byte [0x50b],PASTE
	mov dword [have_keyup],0
	jmp .queueUP
.donePASTE:


	;check for LCTRL down
	cmp byte [KEYBOARD_REPORT_BUF],1
	jnz .doneLCTRL
	mov byte [CTRLKEYSTATE],1
	mov dword [have_keyup],0
	jmp .checkCC 
.doneLCTRL:


	;check for RCTRL down
	cmp byte [KEYBOARD_REPORT_BUF],0x10
	jnz .doneRCTRL
	mov byte [CTRLKEYSTATE],1
	mov dword [have_keyup],0
	jmp .checkCC 
.doneRCTRL:


	;check for LALT down
	cmp byte [KEYBOARD_REPORT_BUF],4
	jnz .doneLALT
	mov byte [ALTKEYSTATE],1
	mov dword [have_keyup],0
	jmp .checkCC 
.doneLALT:


	;do we ever need RALT ?


	;check for LSHIFT down
	;translate cc byte to UPPER case ascii
	cmp byte [KEYBOARD_REPORT_BUF],2
	jnz .doneLSHIFT
	mov byte [SHIFTKEYSTATE],1
	mov dword [have_keyup],0
	mov al,[KEYBOARD_REPORT_BUF+2]                    ;al=cc byte
	;mov [cc_byte_previous],al                         ;save cc byte as previous
	movzx ecx, al                                     ;put cc byte into ecx
	movzx eax, byte [UpperCase_CC_byte_2ascii + ecx]  ;translate to UpperCase ascii
	mov [0x50b],al                                    ;ascii char saved
	mov [cc_ascii_previous],al
	jmp .queueUP 
.doneLSHIFT:


	;check for RSHIFT down
	;translate cc byte to UPPER case ascii
	cmp byte [KEYBOARD_REPORT_BUF],0x20
	jnz .doneRSHIFT
	mov byte [SHIFTKEYSTATE],1
	mov dword [have_keyup],0
	mov al,[KEYBOARD_REPORT_BUF+2]                    ;al=cc byte
	;mov [cc_byte_previous],al                         ;save cc byte as previous
	movzx ecx, al                                     ;put cc byte into ecx
	movzx eax, byte [UpperCase_CC_byte_2ascii + ecx]  ;translate to UpperCase ascii
	mov [0x50b],al                                    ;ascii char saved
	mov [cc_ascii_previous],al
	jmp .queueUP 
.doneRSHIFT:




.checkCC:

	;translate cc byte to LOWER case ascii
	;**************************************
	;STDCALL ukbstr10,dumpstr  ;convert cc byte to ascii

	;get the cc byte
	mov al,[KEYBOARD_REPORT_BUF+2]   ;al=cc byte
	;mov [cc_byte_previous],al        ;save cc byte as previous
	movzx ecx, al                    ;put cc byte into ecx

	;is there a non zero cc byte ?
	cmp ecx,0
	jz .noCCbyte
	
	;we have a normal keypress cc byte
	mov dword [have_keyup],0
	movzx eax, byte [LowerCase_CC_byte_2ascii + ecx]  ;translate to LowerCase
	mov [0x50b],al                                    ;ascii char saved
	mov [cc_ascii_previous],al
	jmp .queueUP


.noCCbyte:
	mov eax,0
	jmp .done
.queueUP:
	mov eax,1
.done:
	ret







;the following table is applicable to this Gear Head keyboard
;when you only press a singe key and get a cc byte
;see also tatOS.inc which defines these non-displayable keys

LowerCase_CC_byte_2ascii:        
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



UpperCase_CC_byte_2ascii:        
;  ascii                          ;keyboard report cc byte in hex
;****************************************************************
db 0,0,0,0,                       ;0,1,2,3  all none
db 'ABCDE'                        ;4,5,6,7,8
db 'FGHIJ'                        ;9,a,b,c,d
db 'KLMNO'                        ;e,f,10,11,12
db 'PQRST'                        ;13,14,15,16,17
db 'UVWXY'                        ;18,19,1a,1b,1c
db 'Z!@#$'                        ;1d,1e,1f,20,21
db '%^&*('                        ;22,23,24,25,26
db ')',ENTER,ESCAPE,BKSPACE,TAB   ;27,28,29,2a,2b
db SPACE,'_+{}'                   ;2c,2d,2e,2f,30
db '|',0,':',34,'~'               ;31,32=none,33=colon,34=dquote,35=tilde
db '<>?',0                        ;36=larrow,37=rarrow,38=quest,39=none
db F1,F2,F3,F4,F5                 ;3a,3b,3c,3d,3e
db F6,F7,F8,F9,F10                ;3f,40,41,42,43
db F11,F12,PRNTSCR,SCRLOCK,BREAK  ;44,45,46,47,48   
db INSERT,HOME,PAGEUP,DELETE      ;49,4a,4b,4c
db END,PAGEDN,RIGHT,LEFT          ;4d,4e,4f,50
db DOWN,UP,NUMLOCK                ;51,52,53



