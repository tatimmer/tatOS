;tatOS/usb/testunit.s


;SCSI TestUnitReady command for usb flash drive 

;on my pen drive the CSW status is usually 01 fail
;but if I run the transaction a 2nd time it passes
;I found a couple other pen drives need RequestSense called
;after TestUnitReady fails so we now automatically do
;TestUnitReady->RequestSense->TestUnitReady->RequestSense


TestUnitReadyRequest:
dd 0x43425355   ;dCBWSignature
dd 0xaabbccdd   ;dCBWTag
dd 0            ;dCBWDataTransferLength
db 0            ;bmCBWFlags 0x80=Device2Host, 00=Host2Device
db 0            ;bCBWLun
db 6            ;bCBWCBLength 
;CBWCB refer to spc2r20.pdf from t10
db 0            ;operation code for TEST UNIT READY
db 0            ;reserved
db 0            ;reserved
db 0            ;reserved
db 0            ;reserved
db 0            ;control ?? whats this
times 10 db 0   ;pad out 



%if USBCONTROLLERTYPE == 0  ;uhci

FlashTUR_structTD_command:
dd TestUnitReadyRequest ;BufferPointer
dd 31                   ;all scsi structures are 31 bytes
dd FULLSPEED 
dd PID_OUT
dd bulktoggleout        ;Address of toggle
dd BULKOUTENDPOINT      ;Address of endpoint
dd FLASHDRIVEADDRESS    ;device address on bus

%endif




;*****************************************************************
;TestUnitReady
;input:eax=value of data toggle for STATUS transport (0 or 1) for ehci
;return: success eax=0, error eax=1
status_toggle dd 0
;*****************************************************************

TestUnitReady:

	;save for later
	mov dword [status_toggle],eax


	STDCALL devstr1,dumpstr  ;FLASH


	;Command Transport
	;********************
	STDCALL transtr10a,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push FlashTUR_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;copy request to data buffer 0xb70000
	mov esi,TestUnitReadyRequest
	mov edi,0xb70000
	mov ecx,31  
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,31 ;all scsi requests are 31 bytes long
	mov ebx,0  ;PID = OUT	(SETUP was for control xfer only)
	mov ecx,1  ;data toggle (Inquiry/ReadCapacity Command OUT was 0 so we use 1)
	call generate_TD

	;attach TD to the proper queue head and run
	;endpoint and address are in the QH
	mov eax,FLASH_BULKOUT_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif




	;Data Transport
	;*****************
	;there is no data transport



	;Status Transport
	;*******************
	STDCALL transtr10c,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push SCSI_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error

	mov esi,scsiCSW
	call CheckCSWstatus  
	jnc .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;generate 1 usb Transfer Descriptor
	mov eax,13 ;qty bytes to receive
	mov ebx,1  ;PID IN
	mov ecx,[status_toggle] 
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_BULKIN_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	mov esi,0xb70000
	call CheckCSWstatus  
	jnc .error
%endif


.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret





