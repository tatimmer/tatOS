;tatOS/usb/devicedesc.s


;FlashGetDeviceDescriptor
;MouseGetDeviceDescriptor
;KeyboardGetDeviceDescriptor
;HubGetDeviceDescriptor


;code to issue the usb Device Descriptor Request


align 10

;this request block can be used for all devices
DeviceDescriptorRequest:
db 0x80    ;bmRequestType
db 6       ;bRequest=06=GET_DESCRIPTOR
dw 0x0100  ;wValue=01 for DEVICE and 00 for index
dw 0       ;wIndex
dw 18      ;wLength=bytes data returned in data phase (8 or 18)


ddstr5 db 'Device Descriptor Data Transport failed to return 12 01',0
ddstr6 db 'VID VendorID',0
ddstr7 db 'PID ProductID',0
ddstr8 db 'bMaxPacket endpoint0',0









;************************************************************************
;              USB FLASH DRIVE
;************************************************************************


%if USBCONTROLLERTYPE == 0  ;uhci

FlashDD_structTD_command:
dd DeviceDescriptorRequest  ;BufferPointer
dd 8              ;DeviceDescriptorRequest structure is 8 bytes
dd FULLSPEED     
dd PID_SETUP
dd controltoggle  ;Address of toggle
dd endpoint0      ;Address of endpoint
dd ADDRESS0       ;device address

FlashDD_structTD_data:
dd 0x5000 ;BufferPointer-data is written to for usbmass
dd 18     ;we should get 18 bytes from the flash drive
dd FULLSPEED  
dd PID_IN
dd controltoggle
dd endpoint0  
dd ADDRESS0
	
FlashDD_structTD_status: 
dd 0      ;null BufferPointer
dd 0      ;0 byte transfer
dd FULLSPEED 
dd PID_OUT
dd controltoggle
dd endpoint0 
dd ADDRESS0

qtydevicedata dd 0

%endif




;blue pen drive returns:
;12 01 00 02 00 00 00 40 a0 0e 68 21 00 02 01 02 03 01

;12=bLength=size of descriptor in bytes
;01=bDescriptorType=DEVICE descriptor
;0002=bcdUSB=usb spec release num
;00=bDeviceClass  (see interface descriptor)
;00=bDeviceSubClass
;00=bDeviceProtocol
;40=bMaxPacketSize0=max packet size for endpoint 0
;a00e=idVendor
;6821=idProduct
;0002=bcdDevice
;01=iManufacturer=index of string descriptor describing the mfg
;02=iProduct=index of string descriptor describing the product
;03=iSerielNumber=index of string descriptor describing the seriel num
;01=bNumConfigurations=number of possible configurations



;********************************************************
;FlashGetDeviceDescriptor
;returns 18 bytes of pen drive data 
;see table 4.1 Universal Serial Bus Mass Storage Class
;Bulk-Only Transport  Rev 1.0 Sept 31, 1999
;for a detailed description of what the 18 bytes of
;data is. It is common to request just 8 bytes then do it again
;requesting 18 bytes.

;input:none
;return: eax=0 on success, 1 on error
;this function for ehci only !
;********************************************************

FlashGetDeviceDescriptor:

	STDCALL devstr1,dumpstr


	;Command Transport
	;********************
	STDCALL transtr1a,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	mov dword [controltoggle],0
	push FlashDD_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)

	;copy request to data buffer 0xb70000
	mov esi,DeviceDescriptorRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Device Descriptor Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif



	;Data Transport
	;*****************
	STDCALL transtr1b,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	mov dword [controltoggle],1
	push FlashDD_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif



%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)

	;generate 1 usb Transfer Descriptor
	mov eax,18  ;qty bytes to transfer
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the Device Descriptor bytes received to 0x5000 for permanent storage
	mov esi,0xb70000
	mov edi,0x5000
	mov ecx,18
	call strncpy
%endif



.dumpDescriptorBytes:
	STDCALL 0x5000,18,dumpmem  

	;dump bMaxPacketEndpoint0
	mov eax,[0x5000+7]
	and eax,0xff
	STDCALL ddstr8,0,dumpeax  

	;dump the VID Vendor ID  (we keep track of these in /doc/hardware)
	xor eax,eax
	mov ax,[0x5000+8]
	STDCALL ddstr6,0,dumpeax

	;dump the PID Product ID
	xor eax,eax
	mov ax,[0x5000+10]
	STDCALL ddstr7,0,dumpeax

	;check the first 2 bytes of the device descriptor
	;should be "12 01" - bail if not because the device is not responding
	cmp word [0x5000],0x0112
	jz .validDDreceived
	STDCALL ddstr5,putshang
.validDDreceived:



	;Status Transport
	;*******************
	STDCALL transtr1c,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	mov dword [controltoggle],1
	push FlashDD_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif



%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)

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







;************************************************************************
;              LOW SPEED USB MOUSE 
;************************************************************************

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

MouseDD_structTD_command:
dd DeviceDescriptorRequest  ;Bufferpointer
dd 8                        ;Device Descriptor Request structure is 8 bytes
dd LOWSPEED  
dd PID_SETUP
dd controltoggle  ;Address of toggle
dd endpoint0      ;Address of endpoint
dd ADDRESS0       ;device address

MouseDD_structTD_data:
dd 0x5500   ;BufferPointer 
dd 18       ;we should get 18 bytes from the mouse
dd LOWSPEED
dd PID_IN
dd controltoggle  ;Address of toggle
dd endpoint0      ;Address of endpoint
dd ADDRESS0       ;device address

MouseDD_structTD_status:
dd 0      ;null BufferPointer
dd 0      ;0 byte transfer
dd LOWSPEED
dd PID_OUT
dd controltoggle  ;Address of toggle
dd endpoint0      ;Address of endpoint
dd ADDRESS0       ;device address

%endif


;Logitech mouse 18 byte Device Descriptor (01):
;12 01 00 02 00 00 00 08 6d 04 0e c0 10 11 01 02 00 01
;(bMaxPacketSize0=08)

;Manhattan mouse 18 bytes Device Descriptor (01):
;12 01 00 02 00 00 00 08 cf 1b 07 00 10 00 00 02 00 01
	

;***************************************************************************
;MouseGetDeviceDescriptor
;this code is for a low speed mouse 
;that can only transmit at most 8 bytes per packet. 
;The 18 bytes are stored starting at 0x5500
;we use conditional assembly so this code can be used for:
;1) old 2-port uhci (vintage Windows 98 computers)
;2) VIA pci card with ehci and uhci companion controllers
;3) my newer ACER laptop with ehci and integrated root hub
;the value of USBCONTROLLERTYPE is set in tatOS.config

;input:none
;return: none
;*****************************************************************************

MouseGetDeviceDescriptor:

	STDCALL devstr2,dumpstr  ;MOUSE

	;Command Transport
	;********************
	STDCALL transtr1a,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],0
	push MouseDD_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if USBCONTROLLERTYPE == 2   ;ehci
	;copy request to data buffer 0xb70000
	mov esi,DeviceDescriptorRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Device Descriptor Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,MOUSE_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif



	;Data Transport
	;*****************
	STDCALL transtr1b,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseDD_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if USBCONTROLLERTYPE == 2   ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,18  ;qty bytes to transfer
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,MOUSE_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the Device Descriptor bytes received to 0x5500 for permanent storage
	mov esi,0xb70000
	mov edi,0x5500
	mov ecx,18
	call strncpy
%endif


	STDCALL 0x5500,18,dumpmem  ;to see the device descriptor



	;Status Transport
	;*******************
	STDCALL transtr1c,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseDD_structTD_status
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





;************************************************************************
;              LOW SPEED USB KEYBOARD 
;************************************************************************

;the usb keyboard is a low speed usb device like the mouse
;and it responds to the same code
;all we do here is copy the mouse code and use differant buffer pointers
;and endpoint/address values

;Gear Head usb keyboard device descriptor
;12 01 10 01 00 00 00 08 4f 1c 02 00 10 01 01 02 00 01


KeyboardDD_structTD_data:
dd 0x6500         ;BufferPointer 
dd 18             ;we should get 18 bytes from the mouse
dd LOWSPEED
dd PID_IN
dd controltoggle  ;Address of toggle
dd endpoint0      ;Address of endpoint
dd ADDRESS0       ;device address




KeyboardGetDeviceDescriptor:


	STDCALL devstr3,dumpstr    ;KEYBOARD


	;Command Transport
	;********************
	STDCALL transtr1a,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],0
	push MouseDD_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if USBCONTROLLERTYPE == 2   ;ehci
	;copy request to data buffer 0xb70000
	mov esi,DeviceDescriptorRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Device Descriptor Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,KEYBOARD_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif



	;Data Transport
	;*****************
	STDCALL transtr1b,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push KeyboardDD_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if USBCONTROLLERTYPE == 2   ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,18  ;qty bytes to transfer
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,KEYBOARD_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the Device Descriptor bytes received to 0x5500 for permanent storage
	mov esi,0xb70000
	mov edi,0x6500
	mov ecx,18
	call strncpy
%endif


	STDCALL 0x6500,18,dumpmem  ;to see the device descriptor



	;Status Transport
	;*******************
	STDCALL transtr1c,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseDD_structTD_status
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
	mov eax,KEYBOARD_CONTROL_QH_NEXT_TD_PTR
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






;********************
;        USB HUB
;********************

;this code was developed on my Acer laptop with ehci having "root" hub
;intel 7 Series /C216 Chipset Platform Controller Hub
;intel ehci with root hub VID=8086h, DID=1e2dh

;The 18 byte device descriptor we get is:
;12 01 00 02 09 00 01 40 87 80 24 00 00 00 00 00 00 01

;12=bLength=size of descriptor in bytes
;01=bDescriptorType=DEVICE descriptor
;0002=bcdUSB=usb spec release num
;09=bDeviceClass = HUB_CLASSCODE 
;00=bDeviceSubClass
;01=bDeviceProtocol  (0=low speed, 1=hi speed single TT, 2=hi speed multiple TT's)
;40=bMaxPacketSize0=max packet size for endpoint 0
;8087=idVendor
;0024=idProduct
;0000=bcdDevice
;00=iManufacturer=index of string descriptor describing the mfg
;00=iProduct=index of string descriptor describing the product
;00=iSerielNumber=index of string descriptor describing the seriel num
;01=bNumConfigurations=number of possible configurations



;************************************************************
;HubGetDeviceDescriptor
;control transfer code for the usb hub
;for use with ehci controller having root hub only
;input:none
;return:none
;************************************************************

HubGetDeviceDescriptor:

 
	STDCALL devstr4,dumpstr


	;Command Transport
	;********************
	STDCALL transtr1a,dumpstr

	;copy request to data buffer 0xb70000
	mov esi,DeviceDescriptorRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Device Descriptor Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error



	;Data Transport
	;*****************
	STDCALL transtr1b,dumpstr

	;zero out some memory where our descriptor will be written to
	;something is writting to memory in this area (maybe bios ?)
	mov edi,0x6000
	mov ecx,48
	mov al,0
	call memset

	;generate 1 usb Transfer Descriptor
	mov eax,18  ;qty bytes to transfer
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the Device Descriptor bytes received to 0x6000 for permanent storage
	mov esi,0xb70000
	mov edi,0x6000
	mov ecx,18
	call strncpy



	;dump the hub device descriptor
	STDCALL 0x6000,18,dumpmem  



	;Status Transport
	;*******************
	STDCALL transtr1c,dumpstr

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


