;tatOS/usb/configdesc.s


;FlashGetConfigDescriptor
;MouseGetConfigDescriptor
;hubGetConfigDescriptor


;code to issue the usb Configuration Descriptor Request



ConfigDescriptorRequest:
db 0x80    ;bmRequestType
db 6       ;bRequest=06=GET_DESCRIPTOR
dw 0x0200  ;wValue=02=CONFIGURATION and 00=index
dw 0       ;wIndex
dw 9       ;wLength=bytes data to be returned,9 or WTOTALLENGTH


;*****************************************************************
;      FLASH DRIVE Config/Interface/Endpoint Descriptor
;*****************************************************************

%if USBCONTROLLERTYPE == 0  ;uhci

FlashCD_structTD_command:
dd ConfigDescriptorRequest  ;BufferPointer
dd 8              ;ConfigDescriptorRequest structure is 8 bytes 
dd FULLSPEED
dd PID_SETUP
dd controltoggle 
dd endpoint0  
dd ADDRESS0   

FlashCD_structTD_data:
dd 0x5020 ;BufferPointer-data is written to
dd 0      ;qtybytes2get is passed as arg to function
dd FULLSPEED 
dd PID_IN
dd controltoggle
dd endpoint0
dd ADDRESS0
	
FlashCD_structTD_status:
dd 0        ;null BufferPointer
dd 0        ;0 byte transfer
dd FULLSPEED 
dd PID_OUT
dd controltoggle
dd endpoint0
dd ADDRESS0

%endif



;results from my blue pen drive

;9 byte config descriptor (02):
;09 02 27 00 01 01 00 80 fa 

;09=bLength=length of descriptor
;02=bDescriptor type = CONFIGURATION descriptor
;2700=wTotalLength=total length of all config/interface/endpoint descriptors
;01=bNumInterfaces
;01=bConfigurationValue
;00=iConfiguration=index of string descriptor
;80=bmAttributes
;fa=bMaxPower

;note wTotalLength should be 0x27 or 39 bytes for most/all flash drives
;that gives us 9 + 9 + 3*7 for config + interface + 3 endpoint descriptors
;tatOS will not save to global memory any more than this
;if a hi speed device is detected with wTotalLength > 0x27, then only the 
;first 0x27 bytes will be saved and a warning is printed to the screen
;odds are if wTotalLength is > 0x27, your device is not a flash


;9 byte interface descriptor (04):
;the 6th byte of this descriptor tells you its a flash drive 08=MASS STORAGE class
;see below the 6th byte of the mouse interface desc is 03=HID class
;09 04 00 00 03 08 06 50 00 

;09=bLength
;04=bDescriptor type = INTERFACE descriptor
;00=bInterfaceNumber
;00=bAlternateSetting
;03=bNumEndpoints
;08=bInterfaceClass=MASS STORAGE class
;06=bInterfaceSubclass=SCSI
;50=bInterfaceProtocol=BULK-ONLY-TRANSPORT
;00=iInterface,index to string descriptor describing this interface


;We have (3) 7 byte endpoint descriptors (05):
;the endpoint descriptor changes depending on which controller is used

;for UHCI:
;07 05 81 02 40 00 00   (81 IN endpoint 0x40 wMaxPacket)
;07 05 02 02 40 00 00   (02 OUT endpoint 0x40 wMaxPacket)
;07 05 83 03 02 00 01

;for EHCI
;07 05 81 02 00 02 00   (0x0200 wMaxPacket)
;07 05 02 02 00 02 00
;07 05 83 03 02 00 01

;07=bLength=length of descriptor
;05=bDescriptorType=ENDPOINT descriptor
;83=bEndpointAddress, 8=IN endpoint and 3=address
;03=bmAttributes, 02=bulkendpoint and 03=?
;0200=wMaxPacketSize=512 bytes
;01=bInterval,does not apply to bulk endpoints

	
configstr1 db '********** Flash ConfigDescriptor COMMAND Transport **********',0
configstr2 db '********** Flash ConfigDescriptor DATA    Transport **********',0
configstr3 db '********** Flash ConfigDescriptor STATUS  Transport **********',0
configstr4 db 'Config Descriptor wTotalLength',0
configstr5 db 'bNumInterfaces',0
configstr6 db 'bConfigurationValue',0
configstr7 db 'bNumEndpoints',0
configstr8 db 'bInterfaceClass',0
configstr9 db 'bInterfaceSubClass',0
configstr10 db 'bInterfaceProtocol',0
configstr11 db 'Warning: wTotalLength exceeds 0x27, saving only 0x27 bytes',0


qtyconfigdata dd 0




;**********************************************************
;FlashGetConfigDescriptor
;run this 2 times
;the first time request 9 bytes of data
;this is the Configuration Descriptor
;we store this starting at 0x5020
;then examine the wTotalLength field offset 2
;this field gives the total qty bytes which includes the 
;config + all interface + all endpoint descriptors
;then run GetConfigDescriptor again 
;requesting wTotalLength bytes in the tdData packet

;input:
;edx = qty bytes for device to return in tdData packet
;    = 9 or WTOTALLENGTH

;return: eax=0 on success, 1 on error
;this function for ehci only !
;***********************************************************

FlashGetConfigDescriptor:


	;qty bytes device should return 
	mov [qtyconfigdata],edx 
	mov [ConfigDescriptorRequest+6],dx



	;Command Transport
	;*********************
	STDCALL configstr1,dumpstr
	
%if USBCONTROLLERTYPE == 0 ;uhci
	mov [FlashCD_structTD_data+4],edx
	mov dword [controltoggle],0
	push FlashCD_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2) ;ehci
	;copy request to data buffer 0xb70000
	mov esi,ConfigDescriptorRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Config Descritor Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif




	;Data Transport
	;*******************
	STDCALL configstr2,dumpstr

%if USBCONTROLLERTYPE == 0 ;uhci
	mov dword [controltoggle],1
	push FlashCD_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2) ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,[qtyconfigdata]  ;qty bytes to transfer
	mov ebx,1                ;PID = IN	
	mov ecx,1                ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the Config Descriptor bytes received to 0x5020 for permanent storage
	mov ecx,[qtyconfigdata]
	cmp ecx,0x27
	jbe .docopy
	STDCALL configstr11,dumpstr
	mov ecx,0x27  ;prevent copying more than 0x27 of wTotalLength
.docopy:
	mov esi,0xb70000
	mov edi,0x5020
	call strncpy
%endif



	;dump the entire descriptor bytes
	STDCALL 0x5020,[qtyconfigdata],dumpmem  ;to see all the config data


	;skip dump with comment until we get the full config/inter/ep descriptor
	cmp dword [qtyconfigdata],9
	jz near .1

	mov ax,[FLASH_WTOTALLENGTH]
	STDCALL configstr4,1,dumpeax 

	;flash drives have only 1 interface
	;if you detect a hi speed device like webcam it will have 2 interfaces
	;could put a check/warning here
	mov al,[FLASH_BNUMINTERFACES]
	STDCALL configstr5,2,dumpeax

	mov al,[FLASH_BCONFIGVALUE]
	STDCALL configstr6,2,dumpeax

	;flash drives only have 2 endpoints: IN/OUT
	mov al,[FLASH_BNUMENDPOINTS]
	STDCALL configstr7,2,dumpeax

	mov al,[FLASH_BINTERFACECLASS]
	STDCALL configstr8,2,dumpeax

	mov al,[FLASH_BINTERFACESUBCLASS]
	STDCALL configstr9,2,dumpeax

	mov al,[FLASH_BINTERFACEPROTOCOL]
	STDCALL configstr10,2,dumpeax

.1:



	;Status Transport
	;*****************
	STDCALL configstr3,dumpstr

%if USBCONTROLLERTYPE == 0 ;uhci
	mov dword [controltoggle],1
	push FlashCD_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2) ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,0  ;PID_OUT	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif



.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret




;*****************************************************************
;      MOUSE Config/Interface/Endpoint Descriptor
;*****************************************************************

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

MouseCD_structTD_command:
dd ConfigDescriptorRequest  ;BufferPointer
dd 8                        ;ConfigDescriptorRequest structure is 8 bytes 
dd LOWSPEED
dd PID_SETUP
dd controltoggle
dd endpoint0
dd ADDRESS0

MouseCD_structTD_data:
dd 0x5520 ;BufferPointer-data is written to
dd 0      ;qtybytes2get is passed as arg to function
dd LOWSPEED
dd PID_IN
dd controltoggle
dd endpoint0
dd ADDRESS0

MouseCD_structTD_status:
dd 0        ;null BufferPointer
dd 0        ;0 byte transfer
dd LOWSPEED
dd PID_OUT
dd controltoggle
dd endpoint0
dd ADDRESS0

%endif


;we store the mouse config descriptor starting at 0x5520
;Manhattan usb mouse device returns 34 bytes of data in 5 packets:
;9 byte config descriptor (02):
;09 02 22 00 01 01 00 a0 31 
;(wTotalLength=22, bNumInterfaces=01, bConfigurationValue=01)

;we store the mouse interface descriptor starting at 0x5529
;9 byte interface descriptor (04):
;09 04 00 00 01 03 01 02 00 
;(bInteraceNumber=00,bNumEndpoints=01, class=03 HID,subclass=01 boot,protocol=02 mouse)
;subclass=01 is boot interface, we issue Set_Protocol(Boot Interface)
;this standardizes the report given by the mouse

;we store the mouse HID descriptor starting at 0x5532
;9 byte HID descriptor (21):
;09 21 10 01 00 01 22 57 00 
;blength=09=size of descriptor in bytes
;bDescriptorType=0x21=HID descriptor
;bcdHID=0x101=HID class spec release number
;bCountryCode=00=Hardware Target country
;bNumDescriptors=01=number of HID class descriptors to follow
;bDescriptorType=22=report descriptor type
;wItemLength=0x0057=total length of report descriptor

;we store the mouse endpoint descriptor starting at 0x553b
;7 byte HID endpoint descriptor (05):
;07 05 81 03 06 00 0a
;(81=IN endpoint #1, 03=attributes interrupt, 06=wMaxPacketSize, 0a=polling interval)
;the wMaxPacketSize tells us the mouse gives a 6 byte report if SetProtocol=report


;Logitech Mouse Config Descriptor
;09 02 22 00 01 01 00 a0 31 
;Logitech Mouse Interface Descriptor
;09 04 00 00 01 03 01 02 00 
;Logitech Mouse HID Descriptor
;09 21 10 01 00 01 22 34 00 
;Logitech Mouse Endpoint Descriptor
;07 05 81 03 04 00 0a   (wMaxPacketSize=04)

	
mconfigstr1 db 'Mouse ConfigDescriptor COMMAND Transport',0
mconfigstr2 db 'Mouse ConfigDescriptor DATA    Transport',0
mconfigstr3 db 'Mouse ConfigDescriptor STATUS  Transport',0
mconfigstr4 db 'Mouse Interface Subclass (0x01=boot)',0
mconfigstr5 db 'MOUSINENDPOINT',0
mconfigstr6 db 'Mouse endpoint wMaxPacketSize',0
mconfigstr7 db 'Mouse bNumInterfaces',0
mconfigstr8 db 'Mouse bConfigValue',0


;**********************************************************
;MouseGetConfigDescriptor
;first time we ask for the 9 bytes Config Descriptor
;this gets us the WTOTALLENGTH value at offset 2
;then we call again asking for WTOTALLENGTH bytes
;which includes the Config, Interface, HID and Endpoint
;descriptors for the device

;input:
;edx = qty bytes for device to return in tdData packet
;    = 9 or MOUSE_WTOTALLENGTH

;return: eax=0 on success, 1 on error
;***********************************************************


MouseGetConfigDescriptor:

	;qty bytes device should return 
	mov [qtyconfigdata],edx 
	mov [ConfigDescriptorRequest+6],dx



	;Command Transport
	;*********************
	STDCALL mconfigstr1,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov [MouseCD_structTD_data+4],edx  ;write qty bytes requested into this struc
	mov dword [controltoggle],0
	push MouseCD_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if USBCONTROLLERTYPE == 2   ;ehci
	;copy request to data buffer 0xb70000
	mov esi,ConfigDescriptorRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Config Descritor Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,MOUSE_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif



	;Data Transport
	;*******************
	STDCALL mconfigstr2,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseCD_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if USBCONTROLLERTYPE == 2   ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,[qtyconfigdata]  ;qty bytes to transfer
	mov ebx,1                ;PID = IN	
	mov ecx,1                ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,MOUSE_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the Config Descriptor bytes received to 0x5520 for permanent storage
	mov ecx,[qtyconfigdata]
	cmp ecx,0x27
	jbe .docopy
	STDCALL configstr11,dumpstr
	mov ecx,0x27  ;prevent copying more than 0x27 of wTotalLength
.docopy:
	mov esi,0xb70000
	mov edi,0x5520
	call strncpy
%endif



	;dump the entire descriptor as hex
	STDCALL 0x5520,[qtyconfigdata],dumpmem  

	;skip dump details until we get the full config/inter/ep descriptor
	cmp dword [qtyconfigdata],9
	jz near .1

	;dump descriptor wTotalLength
	mov ax,[MOUSE_WTOTALLENGTH]
	STDCALL configstr4,1,dumpeax ;dump the WTOTALLENGTH

	;dump bConfigValue
	mov al,[MOUSE_BCONFIGVALUE]
	STDCALL mconfigstr8,2,dumpeax

	;dump bNumInterfaces
	mov al,[MOUSE_BNUMINTERFACES]
	STDCALL mconfigstr7,2,dumpeax

	;dump Interface Subclass  01=boot
	mov al,[0x552f]
	STDCALL mconfigstr4,2,dumpeax

	;dump endpoint wMaxPacketSize
	mov ax,[MOUSE_WMAXPACKETSIZE]  
	STDCALL mconfigstr6,1,dumpeax

	;save the address of the mouse endpoint
	;its the 3rd byte of the endpoint descriptor
	;and it better be an IN endpoint 0x8?
	movzx eax,byte [0x553d]   ;eax=0x81 typically
	and eax,0xf               ;eax=1 
	mov [MOUSEINENDPOINT],al  ;save mouse in endpoint num
	STDCALL mconfigstr5,0,dumpeax

.1:


	;Status Transport
	;*****************
	STDCALL mconfigstr3,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseCD_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if USBCONTROLLERTYPE == 2   ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,0  ;PID_OUT	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,MOUSE_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif



.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret







;*****************************************************************
;      HUB Config/Interface/Endpoint Descriptor
;*****************************************************************


;this code is written for the ehci with root hub only


;results for intel ehci with root HUB VID=8086h, DID=1e2dh
;************************************************************
;after requesting the 9 byte config descriptor we get the following:
;09 02 19 00 01 01 00 e0 00 

;09=bLength=length of descriptor
;02=bDescriptor type = CONFIGURATION descriptor
;0019=wTotalLength=total length of all config/interface/endpoint descriptors
;01=bNumInterfaces
;01=bConfigurationValue
;00=iConfiguration=index of string descriptor
;e0=bmAttributes
;00=bMaxPower

;after requesting HUB_WTOTALLENGTH we get the following:
;09 02 19 00 01 01 00 e0 00   ;config descriptor
;09 04 00 00 01 09 00 00 00   ;interface descriptor
;07 05 81 03 01 00 0c         ;endpoint descriptor

;09 04 00 00 01 09 00 00 00   ;interface descriptor
;09=bLength
;04=bDescriptor type = INTERFACE descriptor
;00=bInterfaceNumber
;00=bAlternateSetting
;01=bNumEndpoints
;09=bInterfaceClass=HUB_CLASSCODE
;00=bInterfaceSubclass (nothing for hubs)
;00=bInterfaceProtocol (nothing for hubs)
;00=iInterface,index to string descriptor describing this interface

;07 05 81 03 01 00 0c         ;endpoint descriptor
;07=bLength=length of descriptor
;05=bDescriptorType=ENDPOINT descriptor
;81=bEndpointAddress, 8=IN endpoint and 1=address
;03=bmAttributes, 03=transfer type interrupt
;0100=wMaxPacketSize=256 bytes
;0c=bInterval,not sure what to do with this one

;the hub has 2 endpoints, endpoint 0 and the "status change" endpoint
;the host system receives port and hub status change notifications 
;thru the status change endpoint. See section 11.12.1 of usb 2.0 spec
;hub descriptors and hub/port status and control are available
;thru the default "control pipe" (endpoint 0)
;currently tatOS does not have any support for the status change endpoint


hubconfigstr1 db '********** hub Config Descriptor COMMAND Transport **********',0
hubconfigstr2 db '********** hub Config Descriptor DATA    Transport **********',0
hubconfigstr3 db '********** hub Config Descriptor STATUS  Transport **********',0
hubconfigstr4 db 'hub Config Descriptor wTotalLength',0
hubconfigstr5 db 'hub bConfigurationValue for SetConfiguration',0
hubconfigstr6 db 'hub bNumInterfaces',0

hubqtyconfigdata dd 0
hub_wtotallength dd 0




;**********************************************************
;hubGetConfigDescriptor
;run this 2 times
;the first time request 9 bytes of data
;this is the Configuration Descriptor
;we store this starting at 0x6020
;then examine the wTotalLength field offset 2
;this field gives the total qty bytes which includes the 
;config + all interface + all endpoint descriptors
;then run GetConfigDescriptor again 
;requesting wTotalLength bytes in the tdData packet

;input:
;edx = qty bytes for device to return in tdData packet
;    = 9 or WTOTALLENGTH

;return: eax=0 on success, 1 on error
;***********************************************************

hubGetConfigDescriptor:

	;qty bytes device should return 
	mov [qtyconfigdata],edx 
	mov [ConfigDescriptorRequest+6],dx



	;Command Transport
	;*********************
	STDCALL hubconfigstr1,dumpstr

	;copy request to data buffer 0xb70000
	mov esi,ConfigDescriptorRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Config Descriptor Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error



	;Data Transport
	;*******************
	STDCALL hubconfigstr2,dumpstr

	;generate 1 usb Transfer Descriptor
	mov eax,[qtyconfigdata]  ;qty bytes to transfer
	mov ebx,1                ;PID = IN	
	mov ecx,1                ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the Config Descriptor bytes received to 0x6020 for permanent storage
	mov esi,0xb70000
	mov edi,0x6020
	mov ecx,[qtyconfigdata]
	call strncpy



	;lets dump some important stuff
	STDCALL 0x6020,[qtyconfigdata],dumpmem  ;to see all the config data

	mov ax,[HUB_WTOTALLENGTH]
	STDCALL hubconfigstr4,1,dumpeax 
	mov al,[HUB_BCONFIGVALUE]
	STDCALL hubconfigstr5,2,dumpeax
	mov al,[HUB_BNUMINTERFACES]
	STDCALL hubconfigstr6,2,dumpeax



	;Status Transport
	;*****************
	STDCALL hubconfigstr3,dumpstr

	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,0  ;PID_OUT	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error




.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret





