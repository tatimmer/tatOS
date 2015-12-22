;tatOS/usb/setconfig.s


;SetConfiguration
;MouseSetConfiguration
;GetConfiguration



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



setconfigstr1 db '********** SetConfiguration COMMAND transport **********',0
setconfigstr2 db '********** SetConfiguration STATUS  transport **********',0 
setconfigstr3 db 'SetConfiguration: configuration value used',0



;***************************************************************************
;SetConfiguration
;code to issue the usb SetConfiguration request
;hi speed flash drive or hub using ehci
;low speed usb mouse using uhci or ehci with root hub
;for flash drive or hub on ehci
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
	STDCALL setconfigstr1,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	mov dword [controltoggle],0
	push FlashSC_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2)  ;ehci
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
	STDCALL setconfigstr2,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	mov dword [controltoggle],1
	push FlashSC_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2)  ;ehci
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





;*********************************************************************
;      LOW SPEED MOUSE 
;*********************************************************************

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



msetconfigstr1 db 'Mouse SetConfiguration COMMAND transport',0
msetconfigstr2 db 'Mouse SetConfiguration STATUS  transport',0 

;***************************************************************************
;MouseSetConfiguration
;input:none
;***************************************************************************

MouseSetConfiguration:


	;set the wValue field of the SetConfigurationRequest
	;this must be the bConfigurationValue gotten from Config Descriptor
	mov al,[MOUSE_BCONFIGVALUE]
	mov [SetConfigurationRequest+2],al
	

	;Command Transport
	;******************
	STDCALL msetconfigstr1,dumpstr
	mov dword [controltoggle],0
	push MouseSC_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain


	;no Data Transport

	
	;Status Transport
	;*******************
	STDCALL msetconfigstr2,dumpstr
	mov dword [controltoggle],1
	push MouseSC_structTD_status
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


getconfigstr1 db '********** GetConfiguration COMMAND transport **********',0
getconfigstr2 db '********** GetConfiguration DATA    transport **********',0
getconfigstr3 db '********** GetConfiguration STATUS  transport **********',0 
getconfigstr4 db 'Get Configuration: configuration value received',0

configstor dd 0

;***************************************************************************
;GetConfiguration
;for flash drive or hub on ehci
;input: none
;       global dword [qh_next_td_ptr] holds address of 
;       ehci QH_NEXT_TD_PTR to attach to for ehci_run  
;return: success eax=0, error eax=1, ebx=configuration value
;***************************************************************************

GetConfiguration:


	;Command Transport
	;******************
	STDCALL getconfigstr1,dumpstr

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
	STDCALL getconfigstr2,dumpstr

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
	STDCALL getconfigstr3,dumpstr
	
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





