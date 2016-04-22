;tatOS/usb/inithub.s

;code to communicate with and configure the usb hub
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


;                                        ------> Keyboard
;  ************       **************   |     
;  *   ehci   * ----> *  ROOT HUB  * --------> Flash
;  ************       **************   |     
;                                        ------> Mouse


hubstr0  db 'INIT ROOT HUB',0
hubstr1  db 'hub-GetDeviceDescriptor',0
hubstr2  db 'hub-GetConfigDescriptor 9 bytes',0
hubstr3  db 'hub-GetConfigDescriptor full',0
hubstr4  db 'error hub bInterfaceClass is not HUB_CLASSCODE',0
hubstr5  db 'hub IN endpoint #',0
hubstr6  db 'hub-GetHubDescriptor',0
hubstr7  db 'hub-SetAddress',0
hubstr8  db 'inithub-failed usb transaction',0
hubstr9  db 'hub-SetConfiguration',0
hubstr10 db 'hub putting power to all ports',0
hubstr11 db 'success init usb root hub',0



inithub:

	;this function take no inputs and returns no values

	STDCALL hubstr0,dumpstr


	;now you might ask how do we know that we are communicating with the hub ?
	;well the root hub is the first device downstream from ehci
	;we may have multiple things plugged into the downstream ports of the hub
	;but these "things" are not "recognized" by ehci until we do a port reset
	;at the end of initehci with hub we did a port reset of the hub "upstream" port


	;hub Device Descriptor
	STDCALL hubstr1,putscroll  
	call HubGetDeviceDescriptor



	;hub Configuration Descriptor  9 bytes
	;first we request the 9 byte Configuration Descriptor
	;this will give us the BNUMINTERFACES and WTOTALLENGTH
	STDCALL hubstr2,putscroll  
	mov edx,9
	call hubGetConfigDescriptor
	cmp eax,1  ;check for error
	jz near .error  ;or tom reset upstream port


	;hub Configuration Descriptor  full
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
	STDCALL devstr4,dumpstr  ;HUB

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
	STDCALL devstr4,dumpstr  ;HUB
	
	mov ax,[HUB_BCONFIGVALUE]
	mov dword [qh_next_td_ptr], HUB_CONTROL_QH_NEXT_TD_PTR
	call SetConfiguration

	cmp eax,1  ;check for error
	jz near .error


	;at this point the hub is configured but the ports have NO power


	;get the HUB descriptor
	;this gives us the number of downstream ports on the device
	;my asus laptop reports 6 ports but there are only 3 external physical
	STDCALL hubstr6,putscroll
	call GetHubDescriptor


	;if you attempt HUbGetPortStatus at this point all you will get is 00 00 00 00
	

	;apply power to all ports 
	STDCALL hubstr10,putscroll
	movzx ecx,byte [HUB_BQTYDOWNSTREAMPORTS]
.1:
	mov eax,ecx  ;eax=hub port number
	call HubPortPower
	loop .1



	;done inithub
	;see initdevices with USBCONTROLLERTYPE == 2 for code continuation

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
	STDCALL hubstr11,putscroll
	mov eax,0
.done:
	ret



