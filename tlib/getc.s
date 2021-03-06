;tatOS/tlib/getc.s

;functions to act on ps2 or usb keyboard presses

;getc, checkc, GetKeyState

;see tatOS.inc for some predefined key combinations
;for example:
;hold down Ctrl key then press 'x', returns al=0xa1=CUT
;hold down Ctrl key then press 'c', returns al=0xa2=COPY
;hold down Ctrl key then press 'v', returns al=0xa3=PASTE


;************************************************************************
;getc
;get a single keypress from 0x504 or 0x50b
;this function will poll/block until a key on a ps2 or usb keyboard is pressed

;this version also handles ListControlKeydown
;if a list control is being displayed by a kernel or user app
;the ascii keypress retrieved by getc will be passed on to
;ListControlKeydown for processing

;input:none
;return: al=ascii char returned

;   tatOS.inc has some defines like F1,F2,SPACE,TAP,NL,ESCAPE...
;   or 0x31 is for the number 1 ...and so forth

getcstr1 db '[getc] return value in al',0
;***********************************************************************

getc:
	xor eax,eax

	sti  ;need ps2 interrupt


	;if you have enabled the usb keyboard then we check byte [0x50b]
	;else for ps2 keyboard we check byte [0x504]
	cmp dword [have_usb_keyboard],1
	jz .dousb
	mov ebx,0x504   ;buffer for ps2 keyboard (irq1)
	jmp .getc_mainloop
.dousb:
	mov ebx,0x50b   ;buffer for usb keyboard 


	;loop until we read a non-zero value
	;all program execution is blocked until we get a non-zero value

.getc_mainloop:
	cmp byte [ebx],0
	je .getc_mainloop


	cli ;disable interrupt


	;return the ascii char in al
	mov al,[ebx]


	;reset for subsequent read operations
	mov byte [ebx],0


	;if you want to dump every keypress uncomment this line
	;STDCALL getcstr1,2,dumpeax


	;if we have a list control, it needs to handle the keypress also
	cmp dword [list_HaveList],1
	jnz .done
	call ListControlKeydown  ;al=ascii char
	
.done:
	ret




;***********************************************
;checkc
;same as above except does not block
;returns immediately if byte [0x504] or [0x50b] = 0

;input:none
;return: al=ascii char 
;zf is set   if the keyboard buffer is empty and al=0
;zf is clear if a key has been pressed and al=ascii char

checkcstr1 db 'checkc',0
checkcstr2 db 'checkc return value in eax',0
;***********************************************

checkc:

	;for debug
	;STDCALL checkcstr1,dumpstr

	xor eax,eax  ;al=0


	;if you have enabled the usb keyboard then we check byte [0x50b]
	;else for ps2 keyboard we check byte [0x504]
	cmp dword [have_usb_keyboard],1
	jz .dousb
	mov ebx,0x504   ;buffer for ps2 keyboard (irq1)
	jmp .check_keyboard_buffer
.dousb:
	mov ebx,0x50b   ;buffer for usb keyboard 


.check_keyboard_buffer:
	cmp byte [ebx],0
	jz .done  ;zf is set if keypress buffer empty

	;return the ascii char in al
	mov al,[ebx]

	;reset for subsequent read operations
	mov byte [ebx],0

.done:

	;for debug if you want to dump every checkc return value uncomment this line
	;STDCALL checkcstr2,2,dumpeax
	ret



;*******************************************************
;GetKeyState
;userland function to obtain the state of special keys
;on the ps2 or usb keyboard
;input:
;to obtain state of CTRL  key set ebx=0
;to obtain state of SHIFT key set ebx=1
;to obtain state of ALT   key set ebx=2
;to obtain state of SPACE key set ebx=3
;return:
;on success eax=1 if key is down else 0 if it is up
;on error eax=0xff
gks_str1 db 'getkeystate return value',0
;*******************************************************

GetKeyState:

	cmp ebx,0
	jz .doCTRL
	cmp ebx,1
	jz .doSHIFT
	cmp ebx,2
	jz .doALT
	cmp ebx,3
	jz .doSPACE
	jmp .error

.doCTRL:
	movzx eax,byte [CTRLKEYSTATE]
	jz .done
.doSHIFT:
	movzx eax,byte [SHIFTKEYSTATE]
	jz .done
.doALT:
	movzx eax,byte [ALTKEYSTATE]
	jz .done
.doSPACE:
	movzx eax,byte [SPACEKEYSTATE]
	jz .done
.error:
	mov eax,0xff
.done:
	;STDCALL gks_str1,0,dumpeax   for debug
	ret



