;tatOS/usb/setconfig.s


;SetConfiguration
;MouseSetConfiguration
;KeyboardSetConfiguration
;GetConfiguration



setconfigstr3 db 'device configuration value',0
getconfigstr4 db 'Get Configuration: configuration value received',0
configstor dd 0


align 0x10

SetConfigurationRequest:
db 0       ;bmRequestType
db 9       ;bRequest=SET_CONFIGURATION
dw 1       ;wValue=set to BCONFIGURATIONVALUE from ConfigDescriptor
dw 0       ;wIndex
dw 0       ;wLength=bytes data returned


;*********************************************************************
;        SET CONFIGURATION
;*********************************************************************

%if USBCONTROLLERTYPE == 0  ;uhci

FlashSC_structTD_command:
dd SetConfigurationRequest  ;BufferPointer
dd 8                        ;SetConfig Request struct is 8 bytes long
dd FULLSPEED
dd PID_SETUP
dd controltoggle            ;toggle address
dd endpoint0
dd FLASHDRIVEADDRESS        ;we now must use device address

;no data transport
	
FlashSC_structTD_status:
dd 0                        ;null BufferPointer
dd 0                        ;qty bytes transferred
dd FULLSPEED
dd PID_IN
dd controltoggle
dd endpoint0
dd FLASHDRIVEADDRESS

%endif


;***************************************************************************
;SetConfiguration
;code to issue the usb SetConfiguration request
;hi speed flash drive or hub using ehci
;low speed usb mouse using ehci with root hub
;The DeviceDescriptor gives us bNumConfigurations
;The ConfigDescriptor gives us bConfigurationValue

;input: al=bConfigurationValue
;       global dword [qh_next_td_ptr] holds address of 
;       ehci QH_NEXT_TD_PTR to attach to for ehci_run  

;return: success eax=0, error eax=1
;***************************************************************************

SetConfiguration:

	;set the wValue field of the SetConfigurationRequest
	;this must be the bConfigurationValue gotten from the Config Descriptor
	;generally this value is == 01 since most flash drives or hubs only have 1 config
	STDCALL setconfigstr3,1,dumpeax
	mov [SetConfigurationRequest+2],ax
	

	;Command Transport
	;******************
	STDCALL transtr7a,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	mov dword [controltoggle],0
	push FlashSC_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;copy request to data buffer 0xb70000
	mov esi,SetConfigurationRequest
	mov edi,0xb70000
	mov ecx,8  
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,[qh_next_td_ptr]
	call ehci_run
	jnz near .error
%endif


	;no Data Transport

	
	;Status Transport
	;*******************
	STDCALL transtr7c,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	mov dword [controltoggle],1
	push FlashSC_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,1  ;PID = IN	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,[qh_next_td_ptr]
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





;*******************************
;   MOUSE SET CONFIGURATION
;*******************************

MouseSC_structTD_command:
dd SetConfigurationRequest  ;BufferPointer
dd 8                        ;SetConfig Request struct is 8 bytes long
dd LOWSPEED
dd PID_SETUP
dd controltoggle            ;toggle address
dd endpoint0
dd MOUSEADDRESS             ;we now must use device address


;no data transport

	
MouseSC_structTD_status:
dd 0                        ;null BufferPointer
dd 0                        ;qty bytes transferred
dd LOWSPEED
dd PID_IN
dd controltoggle
dd endpoint0
dd MOUSEADDRESS

;***************************************************************************
;MouseSetConfiguration
;for uhci ony
;no input and no return
;***************************************************************************

MouseSetConfiguration:

	STDCALL devstr2,dumpstr  ;MOUSE

	;set the wValue field of the SetConfigurationRequest
	;this must be the bConfigurationValue gotten from Config Descriptor
	mov al,[MOUSE_BCONFIGVALUE]
	mov [SetConfigurationRequest+2],al
	

	;Command Transport
	;******************
	STDCALL transtr7a,dumpstr

	mov dword [controltoggle],0
	push MouseSC_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain


	;no Data Transport

	
	;Status Transport
	;*******************
	STDCALL transtr7c,dumpstr

	mov dword [controltoggle],1
	push MouseSC_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain

	ret






;*******************************
;   KEYBOARD SET CONFIGURATION
;*******************************

KeyboardSC_structTD_command:
dd SetConfigurationRequest  ;BufferPointer
dd 8                        ;SetConfig Request struct is 8 bytes long
dd LOWSPEED
dd PID_SETUP
dd controltoggle            ;toggle address
dd endpoint0
dd KEYBOARDADDRESS          ;we now must use device address

;no data transport
	
KeyboardSC_structTD_status:
dd 0                        ;null BufferPointer
dd 0                        ;qty bytes transferred
dd LOWSPEED
dd PID_IN
dd controltoggle
dd endpoint0
dd KEYBOARDADDRESS


;***************************************************************************
;KeyboardSetConfiguration
;for uhci ony
;no input and no return
;***************************************************************************

KeyboardSetConfiguration:

	STDCALL devstr3,dumpstr    ;KEYBOARD


	;set the wValue field of the SetConfigurationRequest
	;this must be the bConfigurationValue gotten from Config Descriptor
	mov al,[KEYBOARD_BCONFIGVALUE]
	mov [SetConfigurationRequest+2],al
	

	;Command Transport
	;******************
	STDCALL transtr7a,dumpstr

	mov dword [controltoggle],0
	push KeyboardSC_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain


	;no Data Transport

	
	;Status Transport
	;*******************
	STDCALL transtr7c,dumpstr

	mov dword [controltoggle],1
	push KeyboardSC_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain


	ret




;*********************************************************************
;        GET CONFIGURATION
;*********************************************************************

GetConfigurationRequest:
db 80h     ;bmRequestType
db 8       ;bRequest=GET_CONFIGURATION
dw 0       ;wValue=0
dw 0       ;wIndex
dw 1       ;wLength=bytes data returned

;***************************************************************************
;GetConfiguration
;for flash drive or hub on ehci only
;input: none
;       global dword [qh_next_td_ptr] holds address of 
;       ehci QH_NEXT_TD_PTR to attach to for ehci_run  
;return: success eax=0, error eax=1, ebx=configuration value
;***************************************************************************

GetConfiguration:


	;Command Transport
	;******************
	STDCALL transtr8a,dumpstr

	;copy request to data buffer 0xb70000
	mov esi,GetConfigurationRequest
	mov edi,0xb70000
	mov ecx,8  
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,[qh_next_td_ptr]
	call ehci_run
	jnz near .error



	;Data Transport
	;*****************
	STDCALL transtr8b,dumpstr

	;generate 1 usb Transfer Descriptor
	mov eax,1   ;qty bytes to transfer
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,[qh_next_td_ptr]
	call ehci_run
	jnz near .error

	;copy the configuration value received 
	xor eax,eax
	mov al,[0xb70000]
	mov [configstor],eax
	STDCALL getconfigstr4,0,dumpeax



	
	;Status Transport
	;*******************
	STDCALL transtr8c,dumpstr
	
	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,0  ;PID_OUT	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,[qh_next_td_ptr]
	call ehci_run
	jnz near .error



.success:
	mov eax,0
	mov ebx,[configstor]
	jmp .done
.error:
	mov eax,1
	mov ebx,0
.done:
	ret





