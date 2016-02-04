;tatOS/usb/requestsense.s

;SCSI RequestSense command for usb flash drive 

;use this immediately after a failed bulk transfer
;to get some status 
;returns 18 bytes in data transport
;this command has some magical affects
;for example on my Toshiba pen drive
;the TestUnitReady always failed the status transport first time
;so if I try to issue TestUnitReady a second time I get a stall
;but issuing RequestSense after the first TestUnitReady "frees"
;up the device then a second call to TestUnitReady passes

;the Data Transport section of this command seems to take the longest to process
;of any usb request and this command will often fail the first time
;then I reinit the controller and go thru initflash again and it will pass

;the bytes returned during DATA transport look something like this if there is a problem:
;70 00 06 00 00 00 00 0a 00 00 00 00 28 00 00 00 00 00
;and if no problem:
;70 00 00 00 00 00 00 0a 00 00 00 00 00 00 00 00 00 00

;70= response code
;06= "unit attention" sense key per table 107 of spc-2
;0a= 10 more bytes of sense data
;28= additional sense code per table 108 of spc-2
;    28 stands for "not ready to ready change,medium may have changed"




;Command Block Wrapper for SCSI RequestSense (31 bytes)
RequestSenseRequest:
dd 0x43425355   ;dCBWSignature
dd 0xaabbccdd   ;dCBWTag  (just make it up)
dd 18           ;dCBWDataTransferLength (during data transport)
db 0x80         ;bmCBWFlags (TD direction 0x80=IN 00=OUT)
db 0            ;bCBWLun
db 6            ;bCBWCBLength, ReadCapacity10 is a 10 byte command TOM WHAT DOES THIS MEAN ?
;CBWCB
db 0x03         ;operation code for RequestSense
db 0            
dd 0            
db 0            
dw 18             
db 0            
times 6 db 0



%if USBCONTROLLERTYPE == 0  ;uhci

FlashRS_structTD_command:
dd RequestSenseRequest  ;BufferPointer
dd 31                   ;all scsi structures are 31 bytes
dd FULLSPEED 
dd PID_OUT
dd bulktoggleout        ;Address of toggle
dd BULKOUTENDPOINT      ;Address of endpoint
dd FLASHDRIVEADDRESS    ;device address on bus

FlashRS_structTD_data:
dd 0x5400 ;BufferPointer-data is written here
dd 18     ;total amount of sense data to receive 
dd FULLSPEED  
dd PID_IN
dd bulktogglein
dd BULKINENDPOINT
dd FLASHDRIVEADDRESS

%endif


;uses same SCSI_structTD5_status as inquiry for status transport

rsstr1 db '********** Flash RequestSense  COMMAND transport **********',0
rsstr2 db '********** Flash RequestSense  DATA    transport **********',0
rsstr3 db '********** Flash RequestSense  STATUS  transport **********',0



RequestSense:


	;Command Transport
	;********************
	STDCALL rsstr1,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push FlashRS_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;copy request to data buffer 0xb70000
	mov esi,RequestSenseRequest
	mov edi,0xb70000
	mov ecx,31  
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,31 ;all scsi requests are 31 bytes long
	mov ebx,0  ;PID = OUT	(SETUP was for control xfer only)
	mov ecx,0  ;data toggle (TestUnit Command OUT was 1 so we use 0)
	call generate_TD

	;attach TD to the proper queue head and run
	;endpoint and address are in the QH
	mov eax,FLASH_BULKOUT_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif



	;Data Transport
	;*****************
	STDCALL rsstr2,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push FlashRS_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;generate 1 usb Transfer Descriptor
	mov eax,18  ;qty bytes to receive
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle (TestUnit Status IN was 0 so we use 1)
	call generate_TD

	;attach TD to queue head and run
	;this is the difficult one
	;ehci_run may loop anywhere from 5-10 times 
	;waiting for the device to respond with data
	;or it may time out and the flash will never give us the data 
	;if this request passes, everything else should be a breeze
	mov eax,FLASH_BULKIN_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the bytes received to 0x5400 for permanent storage
	mov esi,0xb70000
	mov edi,0x5400
	mov ecx,18
	call strncpy
%endif


	STDCALL 0x5400,18,dumpmem  ;dump the sense bytes


	;Status Transport
	;*******************
	STDCALL rsstr3,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push SCSI_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;generate 1 usb Transfer Descriptor
	mov eax,13 ;qty bytes to receive
	mov ebx,1  ;PID IN
	mov ecx,0  ;data toggle (RequestSense Data IN is 1 so we use 0)
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_BULKIN_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif


	STDCALL 0xb70000,13,dumpmem  ;dump the Command Status Wrapper returned

	mov esi,0xb70000
	call CheckCSWstatus  ;test the last byte of CSW for pass/fail


.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret




	



