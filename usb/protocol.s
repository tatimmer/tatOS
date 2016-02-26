;tatOS/usb/protocol.s



;MouseGetProtocol
;MouseSetProtocol
;KeyboardGetProtocol  
;KeyboardSetProtocol 

;for the low speed mouse using uhci or ehci w/root hub
;we want the mouse to use "report" protocol not "boot" protocol

;these commands still use address=0 and endpoint=0 (unconfigured device)
;the keyboard code is copied from the mouse code except buffer pointer is changed


mgpstr4 db 'Mouse Get Protocol returns 0=BOOT',0
mgpstr5 db 'Mouse Get Protocol returns 1=REPORT',0
mgpstr6 db 'Mouse Get Protocol returns unknown value',0
mgpstr7 db 'Mouse Protocol value',0

kgpstr4 db 'Keyboard Get Protocol returns 0=BOOT',0
kgpstr5 db 'Keyboard Get Protocol returns 1=REPORT',0
kgpstr6 db 'Keyboard Get Protocol returns unknown value',0
kgpstr7 db 'Keyboard Protocol value',0

;here we store the protocol values returned in data transport
bMouseProtocol db 0  
bKeyboardProtocol db 0


;**************************************
;    MOUSE GET PROTOCOL
;**************************************


align 0x10

GetProtocolRequest:
db 0xa1       ;bmRequestType
db 0x03       ;bRequest 0b=GET_PROTOCOL
dw 0          ;wValue
dw 0          ;wIndex=InterfaceNum (we assume 0)
dw 1          ;wLength  we will get 1 byte of data (0=Boot Protocol, 1=Report Protocol)



%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

MouseGP_structTD_command:
dd GetProtocolRequest   ;Bufferpointer
dd 8                    ;GetProtocolRequest struct is 8 bytes
dd LOWSPEED
dd PID_SETUP
dd controltoggle
dd endpoint0    
dd ADDRESS0             ;use the default 'pipe' 

MouseGP_structTD_data:
dd bMouseProtocol       ;BufferPointer 
dd 1                    ;we should get 1 byte from the mouse
dd LOWSPEED
dd PID_IN
dd controltoggle       ;Address of toggle
dd endpoint0           ;Address of endpoint
dd ADDRESS0            ;device address

MouseGP_structTD_status:
dd 0                  ;null BufferPointer
dd 0                  ;0 byte transfer
dd LOWSPEED
dd PID_OUT            ;with data phase we use PID_OUT
dd controltoggle
dd endpoint0   
dd ADDRESS0

%endif

;***************************************************************************
;MouseGetProtocol
;input:none
;return: bl=protocol value, 0=boot, 1=report
;*****************************************************************************

MouseGetProtocol:

	STDCALL devstr2,dumpstr   ;MOUSE


	;init to some crazy value
	;a successful usb transaction should return 0 or 1
	mov byte [bMouseProtocol],0xff


	;Command Transport
	;********************
	STDCALL transtr4a,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],0
	push MouseGP_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;copy request to data buffer 0xb70000
	mov esi,GetProtocolRequest
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
	STDCALL transtr4b,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseGP_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,1   ;qty bytes to transfer
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,MOUSE_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;save the Mouse Protocol value given
	movzx eax,byte [0xb70000]
	mov [bMouseProtocol],al
	STDCALL mgpstr7,0,dumpeax
%endif




	;dump to screen a protocol value message
	cmp byte [bMouseProtocol],0
	jz .boot
	cmp byte [bMouseProtocol],1
	jz .report

	;if we got here we have some unknown mouse protocol value
	STDCALL mgpstr6,putscroll
	jmp .status
.boot:
	STDCALL mgpstr4,putscroll
	jmp .status
.report:
	STDCALL mgpstr5,putscroll




.status:
	;Status Transport
	;*******************
	STDCALL transtr4c,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseGP_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,0  ;PID_OUT	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,MOUSE_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz .error
%endif


	mov bl, byte [bMouseProtocol]  ;return value

.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret







;**************************************
;    KEYBOARD GET PROTOCOL
;**************************************

KeyboardGP_structTD_data:
dd bKeyboardProtocol   ;BufferPointer 
dd 1                   ;we should get 1 byte from the mouse
dd LOWSPEED
dd PID_IN
dd controltoggle       ;Address of toggle
dd endpoint0           ;Address of endpoint
dd ADDRESS0            ;device address


;the inputs and return values for this function are same as for the mouse

KeyboardGetProtocol:

	STDCALL devstr3,dumpstr    ;KEYBOARD

	;init to some crazy value
	;a successful usb transaction should return 0 or 1
	mov byte [bKeyboardProtocol],0xff



	;Command Transport
	;********************
	STDCALL transtr4a,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],0
	push MouseGP_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;copy request to data buffer 0xb70000
	mov esi,GetProtocolRequest
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
	STDCALL transtr4b,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push KeyboardGP_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,1   ;qty bytes to transfer
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,KEYBOARD_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;save the Mouse Protocol value given
	movzx eax,byte [0xb70000]
	mov [bMouseProtocol],al
	STDCALL mgpstr7,0,dumpeax
%endif




	;dump to screen a protocol value message
	cmp byte [bKeyboardProtocol],0
	jz .boot
	cmp byte [bKeyboardProtocol],1
	jz .report

	;if we got here we have some unknown mouse protocol value
	STDCALL kgpstr6,putscroll
	jmp .status
.boot:
	STDCALL kgpstr4,putscroll
	jmp .status
.report:
	STDCALL kgpstr5,putscroll




.status:
	;Status Transport
	;*******************
	STDCALL transtr4c,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseGP_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,0  ;PID_OUT	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,KEYBOARD_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz .error
%endif


	mov bl, byte [bKeyboardProtocol]  ;return value

.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret








;***********************************
;     MOUSE SET PROTOCOL
;***********************************

;code to issue the usb Set Protocol Request

;see /usb/mouseinterrupt.s which shows the bytes given by the mouse
;the type of protocol controls how many bytes and what their meaning is
;during interruptIN transactions

%define BOOTPROTOCOL 0
%define REPORTPROTOCOL 1

align 0x10

SetProtocolRequest:
db 0x21            ;bmRequestType
db 0x0b            ;bRequest 0b=SET_PROTOCOL
dw REPORTPROTOCOL  ;wValue boot protocol or report protocol 
dw 0               ;wIndex=InterfaceNum
dw 0               ;wLength  no bytes in data phase


;my Manhattan mouse on boot protocol does not give any wheel movement
;therefore I suggest sticking with the report protocol
;the downside of report protocol is that the byte order/content are not standardized
;for example my Manhattan mouse gives a leading 01 byte as the first byte of the report
;whats the point of this 01 byte ?  I dont know
;Microsoft and Logitech mice do not give a leading 01 byte to the report
;see the mouse report in usbcentral


%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

MouseSP_structTD_command:
dd SetProtocolRequest   ;Bufferpointer
dd 8                    ;SetProtocol Request struct is 8 bytes
dd LOWSPEED
dd PID_SETUP
dd controltoggle
dd endpoint0    
dd ADDRESS0             ;use the default 'pipe'

;no data transport
	
MouseSP_structTD_status:
dd 0      ;null BufferPointer
dd 0      ;0 byte transfer
dd LOWSPEED
dd PID_IN              ;with no data phase we use PID_IN else PID_OUT
dd controltoggle
dd endpoint0   
dd ADDRESS0

%endif


;***************************************************************************
;MouseSetProtocol
;input:none
;return: none
;*****************************************************************************

MouseSetProtocol:

	STDCALL devstr2,dumpstr   ;MOUSE


	;Command Transport
	;********************
	STDCALL transtr5a,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],0
	push MouseSP_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;copy request to data buffer 0xb70000
	mov esi,SetProtocolRequest
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
	STDCALL transtr5c,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseSP_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,0  ;PID_OUT	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,MOUSE_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz .error
%endif


.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret



;**************************************
;KEYBOARD SET PROTOCOL
;input:none
;return: none
;**************************************

KeyboardSetProtocol:


	STDCALL devstr3,dumpstr    ;KEYBOARD


	;Command Transport
	;********************
	STDCALL transtr5a,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],0
	push MouseSP_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;copy request to data buffer 0xb70000
	mov esi,SetProtocolRequest
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
	STDCALL transtr5c,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseSP_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,0  ;PID_OUT	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,KEYBOARD_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz .error
%endif



.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret


