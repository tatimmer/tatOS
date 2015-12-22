;tatOS/usb/initmouse.s


;code to init a usb mouse 
; * uhci
; * ehci with root hub

;my acer acer laptop has ehci with root hub
;the hub TT transaction translator takes care of the conversion of 
;low speed mouse packets into something the hi speed ehci can understand

;the uhci code works on old computers with only 2 ports controlled by uhci
;or it works on a VIA pci addon card with ehci and uhci companion controllers


usbmousestr1 db 'initusbmouse with uhci primary controller',0
usbmousestr2 db 'initusbmouse with ehci & root hub',0
usbmousestr3 db 'mouse Get Protocol',0
usbmousestr4 db 'invalid hub port num for mouse',0
usbmousestr5 db 'hub port reset failed',0
usbmousestr6 db 'mouse Report Descriptor',0
usbmousestr7 db 'mouse Set Protocol',0
usbmousestr8 db 'mouse Set Idle',0
usbmousestr9 db 'Could not find low speed device/mouse on ehci port',0
usbmousestr9a db 'Could not find low speed device/mouse on primary UCHI port',0
usbmousestr10 db 'initusbmouse with ehci & uhci companion controllers',0
usbmousestr11 db 'initmouse common code',0
usbmousestr13 db 'Resetting 1st uhci companion controller',0
usbmousestr14 db 'Resetting 2nd uhci companion controller',0
usbmousestr15 db 'Failed to find mouse on any uhci companion controller port',0
usbmousestr17 db 'uhci port dump',0
usbmousestr18 db 'uhci port scan',0
usbmousestr19 db 'uhci port reset',0
usbmousestr23 db 'resetting UHCI port of low speed mouse',0
usbmousestr24 db 'checking port0 of uhci companion 1',0
usbmousestr25 db 'checking port1 of uhci companion 1',0
usbmousestr26 db 'checking port0 of uhci companion 2',0
usbmousestr27 db 'checking port1 of uhci companion 2',0
usbmousestr29 db 'mouse Get Device Descriptor',0
usbmousestr30 db 'mouse Get Configuration/Interface/Endpoint Descriptors',0
usbmousestr31 db 'mouse Set Address',0
usbmousestr32 db 'mouse Set Configuration',0
usbmousestr33 db 'initmouse done',0


;init mouse takes no inputs and returns no values
;set appropriate value for USBCONTROLLERTYPE in tatOS.config and re-assemble

usbinitmouse:


%if  USBCONTROLLERTYPE == 0  ;uhci primary

	STDCALL usbmousestr1,putscroll
	STDCALL usbmousestr1,dumpstr

	STDCALL usbmousestr17,putscroll
	call uhci_portdump

	STDCALL usbmousestr18,putscroll
	call uhci_portscan
	mov eax,esi  ;esi=portnum of mouse else 0xffffffff

	cmp eax,0xffffffff
	jnz .resetport  
	STDCALL usbmousestr9a,putscroll  ;failed
	jmp near .error

.resetport:
	;reset the port that the mouse is connected to 
	STDCALL usbmousestr23,putscroll
	;eax=port number 0,1
	call uhci_portreset

%endif


;***********************************************************

%if  USBCONTROLLERTYPE == 1  ;ehci with uhci companion controllers

	;note the port ownership is already released 
	;to the UHCI companion controller during initehci

	STDCALL usbmousestr10,putscroll
	STDCALL usbmousestr10,dumpstr

	;need to find which port the low speed mouse is plugged into

	;first check both ports of UHCIBUSDEVFUNCOM1

	mov eax,[UHCIBUSDEVFUNCOM1]
	call uhcibaseaddress
	;[UHCIBASEADD] is set for uhci companion controller #1

	STDCALL usbmousestr24,putscroll
	STDCALL usbmousestr24,dumpstr
	mov eax,0      ;check port 0
	mov [portnumber],eax
	call uhci_portlowspeed
	jz near .resetport ;zf is set if low speed device is attached

	STDCALL usbmousestr25,putscroll
	STDCALL usbmousestr25,dumpstr
	mov eax,1      ;check port 1
	mov [portnumber],eax
	call uhci_portlowspeed
	jz near .resetport

	;then check both ports of UHCIBUSDEVFUNCOM2

	mov eax,[UHCIBUSDEVFUNCOM2]
	call uhcibaseaddress
	;[UHCIBASEADD] is set for uhci companion controller #2

	STDCALL usbmousestr26,putscroll
	STDCALL usbmousestr26,dumpstr
	mov eax,0      ;check port 0
	mov [portnumber],eax
	call uhci_portlowspeed
	jz .resetport ;zf is set if low speed device is attached

	STDCALL usbmousestr27,putscroll
	STDCALL usbmousestr27,dumpstr
	mov eax,1      ;check port 1
	mov [portnumber],eax
	call uhci_portlowspeed
	jz .resetport

	;if we got here we failed to find the mouse
	;on any port of either the 1st or 2nd uhci companion
	jmp near .uhci_no_mouse


.resetport:

	;if we got here we found a port of a uhci companion with a 
	;low speed device attached which we assume is the mouse
	;now reset the port
	STDCALL usbmousestr19,putscroll
	STDCALL usbmousestr19,dumpstr
	;eax=port number 0,1
	mov eax,[portnumber]
	call uhci_portreset

%endif

;***********************************************************
	
%if  USBCONTROLLERTYPE == 2  ;ehci with root hub


	STDCALL usbmousestr2,dumpstr
	STDCALL usbmousestr2,putscroll

	
.resetport:

	;first make sure inithub found a valid port number for the flash
	cmp dword [mouse_hubportnum],0xff
	jz near .invalidMousePortNum
	
	;we already did reset the port at the end of inithub.s
	;but it wont hurt to do it again
	;we already collected mouse_hubportnum at the end of inithub.s
	mov eax,[mouse_hubportnum]
	call HubPortReset
	cmp eax,1
	jz near .hubportresetfailed

%endif


;***********************************************************


	;I rarely have a problem with this code
	;the mouse seems to be more easy to init than some flash drives


	STDCALL usbmousestr11,putscroll  ;start of common code for initmouse

	;get the mouse descriptors, SetAddress, SetConfiguratio, SetIdle ...
	;each one of these functions also includes conditional assembly
	;for USBCONTROLLERTYPE


	;get the mouse device descriptor
	STDCALL usbmousestr29,putscroll
	call MouseGetDeviceDescriptor  
	cmp eax,1  ;check for error
	jz .resetport


	;read just the configuration descriptor to get MOUSEWTOTALLENGTH
	STDCALL usbmousestr30,putscroll
	mov edx,9
	call MouseGetConfigDescriptor
	cmp eax,1  ;check for error
	jz .resetport


	;now we get the Config+Interface+HID+Endpoint Descriptors all in 1 shot
	STDCALL usbmousestr30,putscroll
	movzx edx,word [MOUSE_WTOTALLENGTH]
	call MouseGetConfigDescriptor
	cmp eax,1  ;check for error
	jz .resetport


	;get the mouse report even though we dont use it
	STDCALL usbmousestr6,putscroll
	call MouseGetReportDescriptor
	cmp eax,1  ;check for error
	jz .resetport


	;get the mouse protocol
	STDCALL usbmousestr3,putscroll
	call MouseGetProtocol  ;return bl=0 for boot or 1 for report
	cmp eax,1  ;check for error
	jz .resetport


	;set report protocol if we are in boot protocol
	cmp bl,1  
	jz .HaveReportProtocolAlready
	STDCALL usbmousestr7,putscroll
	call MouseSetProtocol
.HaveReportProtocolAlready:


	STDCALL usbmousestr8,putscroll
	call MouseSetIdle
	cmp eax,1  ;check for error
	jz near .resetport


	;all usb transactions so far used ADDRESS0 default 'pipe'




%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

	STDCALL usbmousestr31,putscroll
	call MouseSetAddress

	STDCALL usbmousestr32,putscroll
	call MouseSetConfiguration

%endif


%if  USBCONTROLLERTYPE == 2  ;ehci with root hub


	STDCALL usbmousestr31,putscroll
	mov eax,MOUSEADDRESS
	mov dword [qh_next_td_ptr], MOUSE_CONTROL_QH_NEXT_TD_PTR
	call SetAddress
	cmp eax,1  ;check for error
	jz near .resetport


	;modify MOUSE_CONTROL_QH to include MOUSEADDRESS 
	mov eax,[MOUSE_CONTROL_QH+4]
	or eax,MOUSEADDRESS
	mov [MOUSE_CONTROL_QH+4],eax


	;Mouse SetConfiguration
	;control transfer still uses endpoint0
	STDCALL usbmousestr32,putscroll
	movzx eax,byte [MOUSE_BCONFIGVALUE]
	mov dword [qh_next_td_ptr], MOUSE_CONTROL_QH_NEXT_TD_PTR
	call SetConfiguration
	cmp eax,1  ;check for error
	jz near .resetport


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
	;the ehci mouse report buffer is 0x1004000
	mov dword [0x1004000],0x09090909
	jmp .done


.uhci_no_mouse:
	STDCALL usbmousestr15,putscroll
	STDCALL usbmousestr15,dumpstr
	jmp .done
.invalidMousePortNum:
	STDCALL usbmousestr4,putscroll
	STDCALL usbmousestr4,dumpstr
	jmp .done
.hubportresetfailed:
	STDCALL usbmousestr5,putscroll
	STDCALL usbmousestr5,dumpstr
	;fall thru
.done:
	STDCALL pressanykeytocontinue,putscroll
	call getc
	ret

