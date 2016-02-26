;tatOS/usb/setaddress.s



;SetAddress
;MouseSetAddress
;KeyboardSetAddress


;code to issue the usb Set Address Request







align 0x10

SetAddressRequest:  ;8 bytes like all control requests
db 0                ;bmRequestType
db 5                ;bRequest
dw 0                ;wValue=The unique USB DEVICE ADDRESS (see below)
dw 0                ;wIndex
dw 0                ;wLength=bytes data returned


%if USBCONTROLLERTYPE == 0  ;uhci

FlashSA_structTD_command:
dd SetAddressRequest  ;BufferPointer
dd 8                  ;SetAddressRequest struct is 8 bytes
dd FULLSPEED
dd PID_SETUP
dd controltoggle   
dd endpoint0          
dd ADDRESS0           ;use address=0 to issue command
	
FlashSA_structTD_status:
dd 0                ;null BufferPointer
dd 0                ;no data xfer
dd 0           
dd PID_IN
dd controltoggle
dd endpoint0
dd ADDRESS0    

%endif



;***********************************************************
;SetAddress

;set unique address for usb device
;every usb device must have a unique address (0-127) 
;this code for flash on uhci or ehci
;for  hub, keyboard, mouse on ehci

;input: eax=usb device address (see our defines in usb.s)
;       global dword [qh_next_td_ptr] holds address of 
;       ehci QH_NEXT_TD_PTR to attach to for ehci_run  

;return: success eax=0, error eax=1
;***********************************************************

SetAddress:


	;write device address into the request
	mov word [SetAddressRequest+2],ax 


	;Command Transport
	;********************
	STDCALL transtr3a,dumpstr 

%if USBCONTROLLERTYPE == 0  ;uhci
	mov dword [controltoggle],0
	push FlashSA_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;copy request to data buffer 0xb70000
	mov esi,SetAddressRequest
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



	;Data Transport
	;****************
	;there is no data transport for this command
	


	;Status Transport
	;******************
	STDCALL transtr3c,dumpstr 

%if USBCONTROLLERTYPE == 0  ;uhci
	mov dword [controltoggle],1
	push FlashSA_structTD_status
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



;****************************
;   MOUSE SET ADDRESS
;****************************

MouseSA_structTD_command:
dd SetAddressRequest  ;BufferPointer
dd 8                  ;SetAddress request structure is 8 bytes
dd LOWSPEED
dd PID_SETUP
dd controltoggle   
dd endpoint0          
dd ADDRESS0           ;use address=0 to issue command

	
MouseSA_structTD_status:
dd 0                ;null BufferPointer
dd 0                ;no data xfer
dd LOWSPEED
dd PID_IN
dd controltoggle   
dd endpoint0          
dd ADDRESS0           ;use address=0 to issue command

;***********************************************************
;MouseSetAddress
;set unique address for usb device
;for mouse plugged into root port of uhci
;input:none
;***********************************************************

MouseSetAddress:

	;set the device address to our structTD_command
	mov word [SetAddressRequest+2],MOUSEADDRESS


	STDCALL devstr2,dumpstr  ;"MOUSE"


	;Command Transport
	;********************
	STDCALL transtr3a,dumpstr 
	mov dword [controltoggle],0
	push MouseSA_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain


	;Data Transport
	;****************
	;there is no data transport for this command
	

	;Status Transport
	;******************
	STDCALL transtr3c,dumpstr 
	mov dword [controltoggle],1
	push MouseSA_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain


	ret





;********************************
;     KEYBOARD SET ADDRESS 
;********************************

;same inputs and return value as for mouse
;this code for uhci only
;just a differant device address 

KeyboardSetAddress:

	;set the device address to our structTD_command
	mov word [SetAddressRequest+2],KEYBOARDADDRESS


	STDCALL devstr3,dumpstr    ;KEYBOARD


	;Command Transport
	;********************
	STDCALL transtr3a,dumpstr 
	mov dword [controltoggle],0
	push MouseSA_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain


	;there is no data transport for this command
	

	;Status Transport
	;******************
	STDCALL transtr3c,dumpstr 
	mov dword [controltoggle],1
	push MouseSA_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain

	ret





