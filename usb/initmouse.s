;tatOS/usb/initmouse.s


;code to init a usb mouse 
; * uhci
; * ehci with root hub



usbmousestr1  db 'init usb mouse',0
usbmousestr2  db 'mouse-GetDeviceDescriptor',0
usbmousestr3a db 'mouse-GetConfigDescriptor 9 bytes',0
usbmousestr3b db 'mouse-GetConfigDescriptor full',0
usbmousestr4  db 'mouse-GetProtocol',0
usbmousestr5  db 'mouse-SetProtocol',0
usbmousestr6  db 'mouse-SetIdle',0
usbmousestr7  db 'mouse-SetAddress',0
usbmousestr8  db 'mouse-SetConfiguration',0
usbmousestr9  db 'mouse-usb transaction failure',0
usbmousestr10 db 'success init usb mouse',0
usbmousestr11 db '[initmouse] device is not a mouse, bInterfaceProtocol != 2',0



;************************************************************
;initmouse

;this code inits a low speed usb mouse 

;assumptions:
;   * a low speed device has been detected on the port
;   * the port is already reset
;the above functions are provided by initdevices.s

;note if bInterfaceProtocol != 02 then this function will bail

;input: none for uhci
;       eax=hub port number for ehci

;return: eax=0 success, device is a mouse, all transactions successful
;        eax=1 usb transaction error
;        eax=2 usb device is not a mouse
;************************************************************

initmouse:


%if USBCONTROLLERTYPE == 2  ;ehci w/root hub

	mov [mouse_hubportnum],eax  

	;write the port number of the mouse into MOUSE_CONTROL_QH 
	;all low speed devices need hub port number written into dword3 of control QH
	;eax=mouse_hubportnum from above
	mov ebx,[MOUSE_CONTROL_QH+8]  ;get dword3
	shl eax,23                    ;shift the mouse_portnum to bit23
	or ebx,eax                    ;and set the Port Number bits
	mov [MOUSE_CONTROL_QH+8],ebx  ;save dword3 endpoint capabilities

%endif


	STDCALL usbmousestr1,putscroll
	STDCALL usbmousestr1,dumpstr

	;get the mouse device descriptor
	STDCALL usbmousestr2,putscroll
	call MouseGetDeviceDescriptor  
	cmp eax,1  ;check for error
	jz near .errorTransaction


	;read just the configuration descriptor 
	;this gives us MOUSE_WTOTALLENGTH
	STDCALL usbmousestr3a,putscroll
	mov edx,9
	call MouseGetConfigDescriptor
	cmp eax,1  ;check for error
	jz near .errorTransaction


	;now we get the Config+Interface+HID+Endpoint Descriptors all in 1 shot
	STDCALL usbmousestr3b,putscroll
	movzx edx,word [MOUSE_WTOTALLENGTH]
	call MouseGetConfigDescriptor
	;return: eax=0 on success, 1 on transaction error
	;         bl=bInterfaceProtocol (should = 2 for mouse)

	cmp eax,1  ;check for error
	jz near .errorTransaction

	cmp bl,2   ;do we really have a mouse ?
	jnz near .notmouse



	;skip getting the mouse report descriptor, we dont use it anyway



	;get the mouse protocol
	STDCALL usbmousestr4,putscroll
	call MouseGetProtocol  ;return bl=0 for boot or 1 for report
	cmp eax,1  ;check for error
	jz near .errorTransaction


	;set report protocol if we are in boot protocol
	cmp bl,1  
	jz .HaveReportProtocolAlready
	STDCALL usbmousestr5,putscroll
	call MouseSetProtocol
.HaveReportProtocolAlready:


	;set mouse idle
	;this is important to control the responsiveness of the mouse for polling
	STDCALL usbmousestr6,putscroll
	call MouseSetIdle
	cmp eax,1  ;check for error
	jz near .errorTransaction


	;all usb transactions so far used ADDRESS0 default 'pipe'




%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

	STDCALL usbmousestr7,putscroll
	call MouseSetAddress

	STDCALL usbmousestr8,putscroll
	call MouseSetConfiguration

%endif



%if  USBCONTROLLERTYPE == 2  ;ehci with root hub

	;Mouse SetAddress
	STDCALL usbmousestr7,putscroll
	STDCALL devstr2,dumpstr   ;MOUSE

	mov eax,MOUSEADDRESS
	mov dword [qh_next_td_ptr], MOUSE_CONTROL_QH_NEXT_TD_PTR
	call SetAddress

	cmp eax,1  ;check for error
	jz near .errorTransaction

	;modify MOUSE_CONTROL_QH to include MOUSEADDRESS 
	mov eax,[MOUSE_CONTROL_QH+4]
	or eax,MOUSEADDRESS
	mov [MOUSE_CONTROL_QH+4],eax



	;Mouse SetConfiguration
	;control transfer still uses endpoint0
	STDCALL usbmousestr8,putscroll
	STDCALL devstr2,dumpstr   ;MOUSE

	movzx eax,byte [MOUSE_BCONFIGVALUE]
	mov dword [qh_next_td_ptr], MOUSE_CONTROL_QH_NEXT_TD_PTR
	call SetConfiguration

	cmp eax,1  ;check for error
	jz near .errorTransaction


	;modify MOUSE_INTERRUPT_QH to include MOUSEINENDPOINT & MOUSEADDRESS
	mov eax,MOUSE_INTERRUPT_QH
	mov ebx,MOUSEADDRESS
	movzx ecx, byte [MOUSEINENDPOINT] 
	call modify_ehci_qh

	;modify dword2 of MOUSE_INTERRUPT_QH to include MOUSE_WMAXPACKETSIZE
	mov eax,[MOUSE_INTERRUPT_QH+4]
	movzx ebx,word [MOUSE_WMAXPACKETSIZE]
	shl ebx,16   ;bits26:16 hold wMaxPacketSize
	or eax,ebx
	mov [MOUSE_INTERRUPT_QH+4],eax

	;modify dword3 of MOUSE_INTERRUPT_QH to include mouse_portnum
	mov eax,[MOUSE_INTERRUPT_QH+8]
	mov ebx,[mouse_hubportnum]
	shl ebx,23   ;bits29:23 hold port number of mouse
	or eax,ebx
	mov [MOUSE_INTERRUPT_QH+8],eax

%endif



	;ready to conduct usb mouse interrupt IN transactions
	;see /usb/mouseinterrupt.s



	;"zero" out our mousereportbuf to something which the mouse
	;can not possibly give as a valid report
	mov dword [MOUSE_REPORT_BUF],0x09090909
	jmp .success



.notmouse:
	STDCALL usbmousestr11,putscroll
	STDCALL usbmousestr11,dumpstr
	mov eax,2
	jmp .done
.errorTransaction:
	STDCALL usbmousestr9,putscroll
	STDCALL usbmousestr9,dumpstr
	STDCALL pressanykeytocontinue,putscroll
	mov eax,1
	jmp .done
.success:
	STDCALL usbmousestr10,putscroll
	mov eax,0
.done:
	ret



