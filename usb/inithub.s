;tatOS/usb/inithub.s

;code to communicate and configure the usb hub
;hubs can be internal "root" hubs or external devices
;these typically have 1 upstream port and multiple down stream ports
;the downstream ports allow you to plug in multiple usb devices

;this code was specifically developed on my asus laptop
;which has 2 ehci usb controllers each with a "root" hub
;VID=0x8086, DID=0x1e2d and 0x1e26
;in order to reset a downstream port of a hub
;you must first configure the device which means collecting and examining
;the various descriptors, then issue SetAddress and SetConfiguration for the hub
;then you can apply power to the ports and reset the ports 
;using hub class commands (not ehci register memory maps)



hubstr0 db 'INIT ROOT HUB',0
hubstr1 db 'hub get Device descriptor',0
hubstr2 db 'hub get Configuration descriptor',0
hubstr3 db 'hub get Config/Interface/Endpoint descriptors',0
hubstr4 db 'error hub bInterfaceClass is not HUB_CLASSCODE',0
hubstr5 db 'hub IN endpoint #',0
hubstr6 db 'hub get Hub descriptor',0
hubstr7 db 'hub Set Address',0
hubstr8 db 'hub failed usb control transfer during init',0
hubstr9 db 'hub Set Configuration',0
hubstr10 db 'hub getting status of all ports, save flash & mouse port#',0
hubstr11 db 'hub putting power to all ports',0
hubstr12 db 'hub resetting all ports',0
hubstr13 db 'flash hub portnum',0
hubstr14 db 'mouse hub portnum',0
hubstr15 db 'failed to find valid portnum for flash',0
hubstr16 db 'failed to find valid portnum for mouse',0



inithub:

	STDCALL hubstr0,dumpstr


	;now you might ask how do we know that we are communicating with the hub ?
	;well the root hub is the first device downstream from ehci
	;we may have multiple things plugged into the downstream ports of the hub
	;but these "things" are not "recognized" by ehci until we do a port reset
	;at the end of initehci with hub we did a port reset of the hub "upstream" port



	;Device Descriptor
	STDCALL hubstr1,putscroll  
	call HubGetDeviceDescriptor




	;Configuration Descriptor
	;first we request the 9 byte Configuration Descriptor
	;this will give us the BNUMINTERFACES and WTOTALLENGTH
	STDCALL hubstr2,putscroll  
	mov edx,9
	call hubGetConfigDescriptor
	cmp eax,1  ;check for error
	jz near .error  ;or tom reset upstream port


	;now we get the configuration, interface and
	;endpoint descriptors all in one shot
	;the value of HUB_WTOTALLENGTH was determined
	;after we received the 9 byte hub config descriptor
	STDCALL hubstr3,putscroll
	xor edx,edx
	;note if you request the wrong number of bytes here
	;your machine will triple fault :)
	mov dx,[HUB_WTOTALLENGTH]
	call hubGetConfigDescriptor
	cmp eax,1  ;check for error
	jz near .error  ;or tom reset upstream port



	;make sure bInterfaceClass is HUB_CLASSCODE
	cmp byte [HUB_BINTERFACECLASS],0x09
	jnz near .error1


	;the first endpoint descriptor starts at 0x6032
	;the bEndpointAddress=0x81 (for asus laptop) field is at 0x6034
	;the 8 indicates IN endpoint, the 1 is the endpoint address
	xor eax,eax
	mov al,[0x6034]
	and al,1                   ;mask off the 8
	mov [HUBINENDPOINT],al     ;save the endpoint address to HUBEPIN (defined in usb.s)
	STDCALL hubstr5,2,dumpeax  ;dump the endpoint #
	;we need HUBEPIN after the hub is configured


	;assign a unique address to the hub	
	;HUBADDRESS is defined in usb.s
	STDCALL hubstr7,putscroll
	mov eax,HUBADDRESS
	mov dword [qh_next_td_ptr], HUB_CONTROL_QH_NEXT_TD_PTR
	call SetAddress
	cmp eax,1  ;check for error
	jz near .error  ;or tom reset upstream port


	
	;modify QH to include hub address 
	;this code similar to initflash.s
	mov eax,HUB_CONTROL_QH
	mov ecx,0  ;still use endpoint 0
	mov ebx,HUBADDRESS
	call modify_ehci_qh



	;set hub configuration
	STDCALL hubstr9,putscroll
	mov ax,[HUB_BCONFIGVALUE]
	mov dword [qh_next_td_ptr], HUB_CONTROL_QH_NEXT_TD_PTR
	call SetConfiguration
	cmp eax,1  ;check for error
	jz near .error


	;at this point the hub is configured but the ports have NO power



	;get the hub descriptor
	;this gives us the number of downstream ports on the device
	;my asus laptop reports 6 ports but there are only 3 external physical
	STDCALL hubstr6,putscroll
	call GetHubDescriptor


	;if you attempt HUbGetPortStatus at this point all you will get is 00 00 00 00
	

	;apply power to ports 
	STDCALL hubstr11,putscroll
	movzx ecx,byte [HUB_BQTYDOWNSTREAMPORTS]
.1:
	mov eax,ecx
	call HubPortPower
	loop .1



	;reset all the ports 
	STDCALL hubstr12,putscroll
	movzx ecx,byte [HUB_BQTYDOWNSTREAMPORTS]
.2:
	mov eax,ecx
	call HubPortReset
	loop .2


	
	;dump the status of each hub port
	;you can get this information by pressing ALT+F4 from usbcentral
	;also save port number of flash drive and mouse
	;at this point we can determine which port the flash and mouse are plugged into
	;wPortStatus = 0x0503 =  flash
	;device present, port enabled, port has power, hi speed device attached (flash)
	;wPortStatus = 0x0303 =  mouse
	;device present, port enabled, port has power, low speed device attached (mouse)
	;wPortStatus = 0x100  nothing connected

	STDCALL hubstr10,putscroll
	mov dword [mouse_hubportnum],0xff  ;init to something invalid
	mov dword [flash_hubportnum],0xff

	movzx ecx,byte [HUB_BQTYDOWNSTREAMPORTS]
.3:
	mov eax,ecx  ;ecx=port number
	call HubGetPortStatus  ;returns ebx=wPortChangewPortStatus

	cmp ebx,0x110503
	jz .foundflash
	cmp ebx,0x110303
	jz .foundmouse
	jmp .loop

.foundflash:
	mov [flash_hubportnum],ecx  ;save flash port number
	jmp .loop 
.foundmouse:
	mov [mouse_hubportnum],ecx  ;save mouse port number
.loop:
	loop .3


	;dump the flash and mouse port numbers we found
	;we need these portnums for port reset
	;and the mouse control QH has the portnum written into it
	mov eax,[flash_hubportnum]
	STDCALL hubstr13,0,dumpeax

	cmp eax,0xff
	jnz .doneflashwarning
	;warn user that we failed to find a valid hubportnum for flash
	;sometimes just rebooting will solve the problem
	STDCALL hubstr15,putscroll
.doneflashwarning:

	;mouse hub port num
	mov eax,[mouse_hubportnum]
	STDCALL hubstr14,0,dumpeax

	cmp eax,0xff
	jnz .donemousewarning
	STDCALL hubstr16,putscroll
.donemousewarning:



	;write the port number of the mouse into MOUSE_CONTROL_QH (see initehci.s)
	;this must go in bits29:23 of dword3 endpoint capabilities
	;eax=mouse_hubportnum from above
	mov ebx,[MOUSE_CONTROL_QH+8]  ;get dword3
	shl eax,23                    ;shift the mouse portnum into position
	or ebx,eax                    ;set the Port Number bits
	mov [MOUSE_CONTROL_QH+8],ebx  ;save dword3 endpoint capabilities




	;just trying out this function never used before
	;to make sure we have indeed set the configuration properly
	;mov dword [qh_next_td_ptr], HUB_CONTROL_QH_NEXT_TD_PTR
	;call GetConfiguration



	jmp .success

.error:
	STDCALL hubstr8,putscroll
	mov eax,1
	jmp .done
.error1:
	STDCALL hubstr4,putscroll
	mov eax,1
	jmp .done
.success:
	mov eax,0
.done:
	ret



