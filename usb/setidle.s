;tatOS/usb/setidle.s


;MouseSetIdle
;KeyboardSetIdle



;code to issue the usb Set Idle Request
;for low speed usb mouse & keyboard only via uhci or ehci with root hub

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
;02 duration * 4 = 8 milliseconds reporting frequency
;07 duration * 4 = 28 ms
;0f duration * 4 = 60 ms
;4b duration * 4 = 300 ms
;7d duration * 4 = 500 ms
;ff duration * 4 = 1020 ms
;00 duration * 4 = indefinite

;I found the mouse to work perfectly fine on the older uhci controllers
;with a duration value of 00. 


;run /usb/mouseinterrupt.s usbShowMouseReport() with differant values of the set idle
;duration byte to see the behavior of the mouse


msistr3 db 'Set Idle Duration',0



;**************************
;    MOUSE SET IDLE 
;*************************

align 0x10

SetIdleRequest:
db 0x21    ;bmRequestType
db 0x0a    ;bRequest 0a=SET_IDLE
dw 0x0000  ;bDuration-bReportID
dw 0       ;wIndex=InterfaceNum
dw 0       ;wLength no bytes in data phase


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



;****************************
;MouseSetIdle
;no inputs and no returns
;****************************

MouseSetIdle:

	STDCALL devstr2,dumpstr    ;MOUSE


	;dump the set idle duration and reportID
	xor eax,eax
	mov ax,[SetIdleRequest+2]
	STDCALL msistr3,0,dumpeax


	;Command Transport
	;********************
	STDCALL transtr6a,dumpstr

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
	STDCALL transtr6c,dumpstr

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




;**************************
;KEYBOARD SET IDLE 
;no inputs and no returns
;*************************

align 0x10

KeyboardSetIdleRequest:
db 0x21    ;bmRequestType
db 0x0a    ;bRequest 0a=SET_IDLE
dw 0x4b00  ;bDuration-bReportID
dw 0       ;wIndex=InterfaceNum
dw 0       ;wLength no bytes in data phase

;dw 0xff00  ;bDuration-bReportID: 1020ms duration
;dw 0x7d00  ;bDuration-bReportID: 500ms duration
;dw 0x4b00  ;bDuration-bReportID: 300ms duration
;dw 0x0700  ;bDuration-bReportID:  28ms duration
;dw 0       ;bDuration-bReportID:  00ms duration 

;the bDuration value can control a number of things such as how fast the keyboard
;repeats when you hold down a key, or how it responds to multiple simultaneous 
;key presses, it you set the value to something less than the PIT timer polling rate
;you will get duplicate key presses.


%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

KeyboardSI_structTD_command:
dd KeyboardSetIdleRequest      ;Bufferpointer
dd 8                           ;SetIdle Request struct is 8 bytes
dd LOWSPEED
dd PID_SETUP
dd controltoggle
dd endpoint0    
dd ADDRESS0       

;no data transport
;use same status as mouse

%endif


KeyboardSetIdle:

	STDCALL devstr3,dumpstr    ;KEYBOARD


	;dump the set idle duration and reportID
	xor eax,eax
	mov ax,[KeyboardSetIdleRequest+2]
	STDCALL msistr3,0,dumpeax


	;Command Transport
	;********************
	STDCALL transtr6a,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],0
	push KeyboardSI_structTD_command
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
	mov eax,KEYBOARD_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif



	;no data transport


	;Status Transport
	;*******************
	STDCALL transtr6c,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseSI_structTD_status   ;keyboard & mouse use same
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






