;tatOS/usb/initkeyboard.s


;code to init a usb keyboard
; * uhci
; * ehci with root hub

;the usb keyboard and usb mouse are both low speed devices and they both
;respond to the same code, this code was originally developed for the usb mouse
;so there are many references to "mouse" that are equally applicable to keyboard.
;the only differance is the buffer pointers, device address and endpoint #

;for keyboard, bInterfaceProtocol = 1
;for mouse     bInterfaceProtocol = 2

;my acer acer laptop has ehci with integrated root hub (i.e. rate matching hub)
;the hub TT transaction translator takes care of the conversion of 
;low speed mouse packets into something the hi speed ehci can understand
;this hub must be initted with usb commands, see inithub.s

;the uhci code works on old computers with only 2 ports controlled by uhci
;or it works on a VIA pci addon card with ehci and uhci companion controllers

;you must set the appropriate value for USBCONTROLLERTYPE 
;in tatOS.config and re-assemble for your usb hardware



usbkbstr1  db 'init usb keyboard',0
usbkbstr2  db 'keyboard-GetDeviceDescriptor',0
usbkbstr3a db 'keyboard-GetConfigDescriptor 9 bytes',0
usbkbstr3b db 'keyboard-GetConfigDescriptor full',0
usbkbstr4  db 'keyboard-GetProtocol',0
usbkbstr5  db 'keyboard-SetProtocol',0
usbkbstr6  db 'keyboard-SetIdle',0
usbkbstr7  db 'keyboard-SetAddress',0
usbkbstr8  db 'keyboard-SetConfiguration',0
usbkbstr9  db 'keyboard-usb transaction failure',0
usbkbstr10 db 'success init usb keyboard',0
usbkbstr11 db '[initkeyboard] device is not a keyboard, bInterfaceProtocol != 1',0
usbkbstr12 db 'done initkeyboard, setting byte 0x50b to 0',0






;************************************************************
;initkeyboard

;this code inits a low speed usb keyboard 

;assumptions:
;   * a low speed device has been detected on the port
;   * the port is already reset
;the above functions are provided by initdevices.s

;note if bInterfaceProtocol != 01 then this function will bail

;input: none for uhci
;       eax=hub port number for ehci

;return: eax=0 success, device is a keyboard, all transactions successful
;        eax=1 usb transaction error
;        eax=2 usb device is not a keyboard
;************************************************************

initkeyboard:

	mov dword [have_usb_keyboard],0  ;not ready


%if USBCONTROLLERTYPE == 2  ;ehci w/root hub

	mov [keyboard_hubportnum],eax

	;write the hub port number of the keyboard into KEYBOARD_CONTROL_QH 
	;all low speed devices need hub port number written into dword3 of control QH
	;eax=keyboard_hubportnum from above
	mov ebx,[KEYBOARD_CONTROL_QH+8]  ;get dword3
	shl eax,23                       ;shift the keyboard_portnum to bit23
	or ebx,eax                       ;and set the Port Number bits
	mov [KEYBOARD_CONTROL_QH+8],ebx  ;save dword3 endpoint capabilities

%endif



	STDCALL usbkbstr1,putscroll
	STDCALL usbkbstr1,dumpstr


	;get the keyboard device descriptor
	STDCALL usbkbstr2,putscroll
	call KeyboardGetDeviceDescriptor  
	cmp eax,1  ;check for error
	jz near .errorTransaction


	;read just the configuration descriptor to get KEYBOARD_WTOTALLENGTH
	STDCALL usbkbstr3a,putscroll
	mov edx,9
	call KeyboardGetConfigDescriptor
	cmp eax,1  ;check for error
	jz near .errorTransaction


	;now we get the Config+Interface+HID+Endpoint Descriptors all in 1 shot
	STDCALL usbkbstr3b,putscroll
	movzx edx,word [KEYBOARD_WTOTALLENGTH]
	call KeyboardGetConfigDescriptor
	;return: eax=0 on success, 1 on transaction error
	;         bl=bInterfaceProtocol (should = 1 for keyboard)

	cmp eax,1  ;check for error
	jz near .errorTransaction

	cmp bl,1   ;do we really have a keyboard ?
	jnz near .notkeyboard




	;skip getting the keyboard report descriptor, we dont use it anyway


	;get the keyboard protocol
	STDCALL usbkbstr4,putscroll
	call KeyboardGetProtocol  ;return bl=0 for boot or 1 for report
	cmp eax,1  ;check for error
	jz near .errorTransaction


	;set report protocol if we are in boot protocol
	cmp bl,1  
	jz .KeyboardHaveReportProtocolAlready
	STDCALL usbkbstr5,putscroll
	call KeyboardSetProtocol
.KeyboardHaveReportProtocolAlready:


	;SetIdle
	STDCALL usbkbstr6,putscroll
	call KeyboardSetIdle
	cmp eax,1  ;check for error
	jz near .errorTransaction



%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	;all usb transactions so far used ADDRESS0 default 'pipe'
	;now we use KEYBOARDADDRESS

	STDCALL usbkbstr7,putscroll
	call KeyboardSetAddress

	STDCALL usbkbstr8,putscroll
	call KeyboardSetConfiguration

%endif


%if  USBCONTROLLERTYPE == 2  ;ehci with root hub

	;SetAddress
	STDCALL usbkbstr7,putscroll
	STDCALL devstr3,dumpstr  ;KEYBOARD

	mov eax,KEYBOARDADDRESS
	mov dword [qh_next_td_ptr], KEYBOARD_CONTROL_QH_NEXT_TD_PTR
	call SetAddress

	cmp eax,1  ;check for error
	jz near .errorTransaction

	;modify KEYBOARD_CONTROL_QH to include KEYBOARDADDRESS 
	mov eax,[KEYBOARD_CONTROL_QH+4]
	or eax,KEYBOARDADDRESS
	mov [KEYBOARD_CONTROL_QH+4],eax


	;Keyboard SetConfiguration
	;control transfer still uses endpoint0
	STDCALL usbkbstr8,putscroll
	STDCALL devstr3,dumpstr  ;KEYBOARD

	movzx eax,byte [KEYBOARD_BCONFIGVALUE]
	mov dword [qh_next_td_ptr], KEYBOARD_CONTROL_QH_NEXT_TD_PTR
	call SetConfiguration

	cmp eax,1  ;check for error
	jz near .errorTransaction

	;modify KEYBOARD_INTERRUPT_QH to include KEYBOARDINENDPOINT & KEYBOARDADDRESS
	mov eax,KEYBOARD_INTERRUPT_QH
	mov ebx,KEYBOARDADDRESS
	movzx ecx, byte [KEYBOARDINENDPOINT] 
	call modify_ehci_qh

	;modify dword2 of KEYBOARD_INTERRUPT_QH to include KEYBOARD_WMAXPACKETSIZE
	mov eax,[KEYBOARD_INTERRUPT_QH+4]
	movzx ebx,word [KEYBOARD_WMAXPACKETSIZE]
	shl ebx,16   ;bits26:16 hold wMaxPacketSize
	or eax,ebx
	mov [KEYBOARD_INTERRUPT_QH+4],eax

	;modify dword3 of KEYBOARD_INTERRUPT_QH to include keyboard_hubportnum
	mov eax,[KEYBOARD_INTERRUPT_QH+8]
	mov ebx,[keyboard_hubportnum]
	shl ebx,23   ;bits29:23 hold port number of keyboard
	or eax,ebx
	mov [KEYBOARD_INTERRUPT_QH+8],eax

%endif



	;ready to conduct usb keyboard interrupt IN transactions
	;see /usb/keyboardinterrupt.s

	mov eax,0  ;success


	;"zero" out our keyboard report buf to something 
	;which the keyboard can not possibly give as a valid report
	mov dword [KEYBOARD_REPORT_BUF],0x09090909
	jmp .success



.notkeyboard:
	STDCALL usbkbstr11,putscroll
	STDCALL usbkbstr11,dumpstr
	mov dword [have_usb_keyboard],0  ;not ready
	mov eax,2
	jmp .done

.errorTransaction:
	STDCALL usbkbstr9,putscroll
	STDCALL pressanykeytocontinue,putscroll
	mov dword [have_usb_keyboard],0  ;not ready
	mov eax,1
	jmp .done

.success:
	STDCALL usbkbstr10,putscroll

	;set usb keyboard to 1= ready
	mov dword [have_usb_keyboard],1

%if USBCONTROLLERTYPE == 2
	;generate the static keyboard interrupt TD, see prepareTD-ehci.s
	;these 13 dwords are copied over and over and over again by usbkeyboardrequest
	;every time you press a key
	call ehci_generate_keyboard_TD
%endif

	;queue up our first usb keyboard request, see interkeybd.s
	call usbkeyboardrequest

	mov eax,0

.done:

;tom this code is in conflict with a line above
;tom this too failed to pervent the initdevices code from executing multiple times
;mov dword [KEYBOARD_REPORT_BUF],0

	;zero out the usb keyboard ascii keypress buffer
	mov byte [0x50b],0
	STDCALL usbkbstr12,dumpstr
	ret



