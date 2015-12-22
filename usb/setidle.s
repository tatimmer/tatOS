;tatOS/usb/setidle.s


;code to issue the usb Set Idle Request
;for low speed usb mouse only via uhci or ehci with root hub

;this command limits the reporting frequency of the endpoint

;SetIdleDuration=00 
;you get one report per button down event and one for button up
;multiple reports are not given if you hold down a button for extended time
;for example right button down gives you: 
;	02 00 00 00   
;when you release the button you get:
;   00 00 00 00

;SetIdleDuration > 00 
;the mouse generates a stream of duplicate button down reports depending on
;the duration value and how long you hold down a button
;if you do not touch the mouse then a stream of 
;00 00 00 00 reports are given indicating no activity

;according to the usb-hid spec the recommended value for
;SetIdleDuration for the mouse is 00

;duration byte examples: (always multiply by 4)
;02 = 8 milliseconds reporting frequency
;0f = 60 milliseconds
;ff = 1020 milliseconds
;00 = indefinite

;I found the mouse to work perfectly fine on the older uhci controllers
;with a duration value of 00. 

;run /usb/mouseinterrupt.s usbShowMouseReport() with differant values of the set idle
;duration byte to see the behavior of the mouse


align 0x10

SetIdleRequest:
db 0x21    ;bmRequestType
db 0x0a    ;bRequest 0a=SET_IDLE
dw 0x0000  ;the hi byte is Duration, the low byte is Report ID
dw 0       ;wIndex=InterfaceNum
dw 0       ;wLength no bytes in data phase



;************************************************************************
;              LOW SPEED USB MOUSE
;************************************************************************


msistr1 db 'Mouse SetIdle COMMAND Transport',0
msistr2 db 'Mouse SetIdle STATUS  Transport',0
msistr3 db 'Set Idle Duration',0


%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

MouseSI_structTD_command:
dd SetIdleRequest      ;Bufferpointer
dd 8                   ;SetIdle Request struct is 8 bytes
dd LOWSPEED
dd PID_SETUP
dd controltoggle
dd endpoint0    
dd ADDRESS0            ;use the default 'pipe'  

;no data transport
	
MouseSI_structTD_status:
dd 0      ;null BufferPointer
dd 0      ;0 byte transfer
dd LOWSPEED
dd PID_IN              ;with no data phase we use PID_IN else PID_OUT
dd controltoggle
dd endpoint0   
dd ADDRESS0

%endif



;***************************************************************************
;MouseSetIdle
;input:none
;return: none
;*****************************************************************************

MouseSetIdle:

	;dump the set idle duration and reportID
	xor eax,eax
	mov ax,[SetIdleRequest+2]
	STDCALL msistr3,0,dumpeax


	;Command Transport
	;********************
	STDCALL msistr1,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],0
	push MouseSI_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;copy request to data buffer 0xb70000
	mov esi,SetIdleRequest
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



	;no data transport


	;Status Transport
	;*******************
	STDCALL msistr2,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseSI_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,1  ;PID_IN	
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





