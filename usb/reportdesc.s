;tatOS/usb/reportdesc.s


;code to issue the usb Report Descriptor Request
;for low speed usb mouse only via uhci or ehci w/root hub


align 0x10

ReportDescriptorRequest:
db 0x81    ;bmRequestType, HID Class Descriptor
db 6       ;bRequest=06=GET_DESCRIPTOR
dw 0x2200  ;wValue=22 for Report Descriptor and 00 for index
dw 0       ;wIndex=InterfaceNum
dw 0       ;wLength=bytes data=MOUSEWREPORTLENGTH from HID descriptor



;************************************************************************
;              LOW SPEED USB MOUSE
;************************************************************************


mrdstr1 db 'Mouse ReportDescriptor COMMAND Transport',0
mrdstr2 db 'Mouse ReportDescriptor DATA    Transport',0
mrdstr3 db 'Mouse ReportDescriptor STATUS  Transport',0
mrdstr4 db 'Mouse Length of Report Descriptor',0


%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

MouseRD_structTD_command:
dd ReportDescriptorRequest  ;Bufferpointer
dd 8                        ;ReportDescriptorRequest structure is 8 bytes
dd LOWSPEED
dd PID_SETUP
dd controltoggle  ;Address of toggle
dd endpoint0      ;Address of endpoint
dd ADDRESS0       ;device address

MouseRD_structTD_data:
dd 0x5600   ;BufferPointer 
dd 0        ;set to MOUSEREPORTLENGTH below
dd LOWSPEED
dd PID_IN
dd controltoggle  ;Address of toggle
dd endpoint0      ;Address of endpoint
dd ADDRESS0       ;device address

MouseRD_structTD_status:
dd 0      ;null BufferPointer
dd 0      ;0 byte transfer
dd LOWSPEED
dd PID_OUT
dd controltoggle  ;Address of toggle
dd endpoint0      ;Address of endpoint
dd ADDRESS0       ;device address

%endif



;Manhattan mouse returns 0x57 bytes of report data
;05 01 09 02 a1 01 85 01 09 01 a1 00 05 09 19 01 29 03 15 00 25 01 95 03 75 01
;81 02 95 01 75 05 81 03 05 01 09 30 09 31 09 38 15 81 25 7f 75 08 95 03 81 06
;05 0c 0a 38 02 95 01 81 06 c0 c0 06 f3 f1 0a f3 f1 a1 01 85 02 09 00 95 01 75
;08 15 00 26 ff 00 81 02 c0

;see the usb hid spec for how to decipher this mess
;see also the USB "HID Usage Tables" ver 1.11
;tatOS has no code parser for this-instead see /uhci/mousereport.s where we 
;have the ShowMouseReport function which gets the bytes from the mouse and 
;dumps to screen so you can see live what the mouse is doing

;line1 09 10 usage pointer
;line1 05 09 usage page buttons
;line1 09 01 29 03 there are 3 buttons
;line1 15 00 25 01 each button represented by 1 bit
;line2 09 30 09 31 09 38 Usage (x) Usage (y) Usage (wheel)
;line2 15 81 25 7f Logical min (-127) Logical max (127)
;line2 75 08 95 03 Report size (8) Report Count (3) 3@ 8bits each for x,y



	
;***************************************************************************
;MouseGetReportDescriptor
;input:none
;return: eax=0 on success, 1 on error
;*****************************************************************************


MouseGetReportDescriptor:

	movzx eax,word [MOUSE_WREPORTLENGTH]
	mov [ReportDescriptorRequest+6],ax
	mov edx,eax  ;save for later


	;Command Transport
	;********************
	STDCALL mrdstr1,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov [MouseRD_structTD_data+4],eax
	mov dword [controltoggle],0
	push MouseRD_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif


%if USBCONTROLLERTYPE == 2  ;ehci
	;copy request to data buffer 0xb70000
	mov esi,ReportDescriptorRequest
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
	STDCALL mrdstr2,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseRD_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if USBCONTROLLERTYPE == 2  ;ehci
	;generate 1 usb Transfer Descriptor
	movzx eax,word [MOUSE_WREPORTLENGTH]  ;qty bytes to transfer
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,MOUSE_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the Descriptor bytes received for permanent storage
	mov esi,0xb70000
	mov edi,0x5600
	movzx ecx,word [MOUSE_WREPORTLENGTH] 
	call strncpy
%endif


	;dump the report descriptor
	mov eax,edx
	and eax,0xffff
	STDCALL mrdstr4,0,dumpeax
	STDCALL 0x5600,eax,dumpmem 



	;Status Transport
	;*******************
	STDCALL mrdstr3,dumpstr

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov dword [controltoggle],1
	push MouseRD_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if USBCONTROLLERTYPE == 2  ;ehci
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






