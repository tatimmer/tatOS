;tatOS/usb/inquiry.s

;SCSI inquiry command for usb flash drive 

;returns 36 bytes of info to 0x5200
;there is an ascii vendor string that on my pen drive by SimpleTech
;says "Simple Flash Disk 2.00"
;my Toshiba flash drive says "TOSHIBA TransMemory     PMAP"

;this is a "bulk" transfer
;all the SCSI commands are bulk transfers 
;because they use the CBW command block wrapper and the CSW command status wrapper
;note also these commands must be sent to the BULKIN or BULKOUT endpoints of the flash
;not endpoint0 because the device has already been assigned an address (SetAddress)
;and has been configured (SetConfiguration)



;Command Block Wrapper for SCSI Inquiry (31 bytes)
InquiryRequest:
dd 0x43425355   ;dCBWSignature
dd 0xaabbccdd   ;dCBWTag (device will copy this into CSW)
dd 0x24         ;dCBWDataTransferLength (for tdData)
db 0x80         ;bmCBWFlags 0x80=Device2Host, 00=Host2Device
db 0            ;bCBWLun
db 6            ;bCBWCBLength (of CBWCB)
;CBWCB (16 bytes) see SCSI Inquiry Command
db 0x12         ;SCSI operation code
db 0            ;SCSI reserved
db 0            ;SCSI page or operation code
db 0            ;SCSI reserved
db 0x24         ;SCSI allocation length
db 0            ;SCSI control 
times 10 db 0   ;USBmass CBWCB must be 16 bytes long 
dd 0
dd 0
dd 0

	

%if USBCONTROLLERTYPE == 0  ;uhci

FlashINQ_structTD_command:
dd InquiryRequest  ;BufferPointer
dd 31              ;InquiryRequest structure is 31 bytes
dd FULLSPEED 
dd PID_OUT
dd bulktoggleout      ;Address of toggle
dd BULKOUTENDPOINT    ;Address of endpoint
dd FLASHDRIVEADDRESS  ;device address on bus

FlashINQ_structTD_data:
dd 0x5200 ;BufferPointer-data is written here
dd 36     ;total amount of inquiry data to receive 
dd FULLSPEED  
dd PID_IN
dd bulktogglein
dd BULKINENDPOINT
dd FLASHDRIVEADDRESS

%endif



;this structure is used for all scsi status transports
SCSI_structTD_status: 
dd scsiCSW       ;BufferPointer
dd 13            ;all scsi should return 13 byte transfer
dd FULLSPEED 
dd PID_IN
dd bulktogglein
dd BULKINENDPOINT
dd FLASHDRIVEADDRESS



;my simpletech flash drive returns the following ascii string:
;00 80 02 1f 00 00 00 53 69 6d 70 6c 65 20 20 46 6c 61 73 68 20 44 69 73 6b 20 32 2e 30
;                     S  i  m  p  l  e        F  l  a  s  h     D  i  s  k
;20 20 32 2e 30 30
;      2  .  0  0


;a successful scsi status will return the CSW as follows:
;55 53 42 53 dd cc bb aa 00 00 00 00 00
;55 53 42 53 is the dCSWSignature
;dd cc bb aa is my arbitrary dCSWTag I put in every CBW
;the last byte is the status code 00=pass, 01=fail, 02=phase error



fistr1 db '********** Flash Inquiry  COMMAND transport **********',0
fistr2 db '********** Flash Inquiry  DATA    transport **********',0
fistr3 db '********** Flash Inquiry  STATUS  transport **********',0


Inquiry:


	;Command Transport
	;********************
	STDCALL fistr1,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push FlashINQ_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2)  ;ehci
	;copy request to data buffer 0xb70000
	mov esi,InquiryRequest
	mov edi,0xb70000
	mov ecx,31  
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,31 ;all scsi requests are 31 bytes long
	mov ebx,0  ;PID = OUT	
	mov ecx,0  ;data toggle, QH uses this toggle
	call generate_TD

	;attach TD to the proper queue head and run
	;endpoint and address are in the QH
	mov eax,FLASH_BULKOUT_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif


	
	;Data Transport
	;*****************
	STDCALL fistr2,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push FlashINQ_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2)  ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,36  ;qty bytes to receive
	mov ebx,1   ;PID = IN	
	mov ecx,0   ;data toggle, QH uses this toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_BULKIN_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the bytes received to 0x5200 for permanent storage
	mov esi,0xb70000
	mov edi,0x5200
	mov ecx,36
	call strncpy
%endif


	STDCALL 0x5200,36,dumpmem  ;dump the inquiry bytes

	;a portion of the returned data can be displayed as ASCII
	mov byte [0x5200+36],0  ;0 terminate offset 36
	STDCALL 0x5208,dumpstrquote






	;Status Transport
	;*******************
	STDCALL fistr3,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push SCSI_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2)  ;ehci
	;generate 1 usb Transfer Descriptor
	mov eax,13 ;qty bytes to receive
	mov ebx,1  ;PID IN
	mov ecx,1  ;data toggle
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










