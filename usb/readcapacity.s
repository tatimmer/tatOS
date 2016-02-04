;tatOS/usb/readcapacity.s

;ReadCapacity for usb flash drive

;returns 8 bytes of data to 0x5100 like this:
;00 07 b7 ff 00 00 02 00
;first 4 bytes are LBAmax
;next 4 bytes are bytes per block
;need to use bswap 
;the LBAmax is 0007b7ff=505,855  (lba 0->505,855 accessible)
;the bytes per block is 0200=512 bytes
;the total capacity is (505,855+1) * 512  or about 250 Meg

;my Toshiba 2GB pen drive returns data like this:
;00 3c 87 ff 00 00 02 00
;(0x003c87ff)(0x0200) = 2,031,091,200 bytes
;max LBA that can be addressed is 0x003c87ff=3,966,975



;Command Block Wrapper for SCSI ReadCapacity10 (31 bytes)
ReadCapacityRequest:
dd 0x43425355   ;dCBWSignature
dd 0xaabbccdd   ;dCBWTag  (just make it up)
dd 8            ;dCBWDataTransferLength (during tdData)
db 0x80         ;bmCBWFlags (tdData direction 0x80=IN 00=OUT)
db 0            ;bCBWLun
db 10           ;bCBWCBLength, ReadCapacity10 is a 10 byte command
;CBWCB (16 bytes) see the SCSI ReadCapacity(10) Command
db 0x25         ;SCSI operation code for ReadCapacity10
db 0            ;SCSI reserved
dd 0            ;SCSI Logical Block Address
dw 0            ;SCSI Reserved
db 0            ;SCSI Reserved
db 0            ;SCSI Control
times 6 db 0    ;USBmass CBWCB must be 16 bytes long


%if USBCONTROLLERTYPE == 0  ;uhci

FlashRC_structTD_command:
dd ReadCapacityRequest  ;BufferPointer
dd 31                   ;all scsi requests are 31 bytes
dd FULLSPEED 
dd PID_OUT
dd bulktoggleout  
dd BULKOUTENDPOINT
dd FLASHDRIVEADDRESS  

FlashRC_structTD_data:
dd 0x5100 ;BufferPointer-data is written here
dd 8      ;total amount of inquiry data to receive 
dd FULLSPEED  
dd PID_IN
dd bulktogglein
dd BULKINENDPOINT
dd FLASHDRIVEADDRESS

%endif


;uses same SCSI_structTD_status as inquiry for status transport


rcstr1 db '********** Flash ReadCapacity  COMMAND transport **********',0
rcstr2 db '********** Flash ReadCapacity  DATA    transport **********',0
rcstr3 db '********** Flash ReadCapacity  STATUS  transport **********',0
rcstr4 db 'flash drive LBAmax',0
rcstr5 db 'bytes per block',0
rcstr6 db 'flash drive capacity, bytes',0


ReadCapacity:


	;Command Transport
	;********************
	STDCALL rcstr1,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push FlashRC_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;copy request to data buffer 0xb70000
	mov esi,ReadCapacityRequest
	mov edi,0xb70000
	mov ecx,31  
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,31 ;all scsi requests are 31 bytes long
	mov ebx,0  ;PID = OUT	
	mov ecx,0  ;data toggle  (previous TestUnit Command was 1 so we use 0)
	call generate_TD

	;attach TD to the proper queue head and run
	;endpoint and address are in the QH
	mov eax,FLASH_BULKOUT_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error
%endif



	;Data Transport
	;*****************
	STDCALL rcstr2,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push FlashRC_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .error
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;generate 1 usb Transfer Descriptor
	mov eax,8   ;qty bytes to receive
	mov ebx,1   ;PID = IN	
	mov ecx,0   ;data toggle (previous TestUnit Status IN was 1 so we use 0)
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_BULKIN_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;copy the bytes received to 0x5100 for permanent storage
	mov esi,0xb70000
	mov edi,0x5100
	mov ecx,8
	call strncpy
%endif


	STDCALL 0x5100,8,dumpmem  ;dump the capacity bytes

	;dump the LBAmax
	;[1] denotes value written to screen in usbcentral at bottom
	mov eax,[0x5100]
	bswap eax
	;save for later checks for write10
	mov [flashdriveLBAmax],eax  ;[1] 
	mov ebx,eax
	STDCALL rcstr4,0,dumpeax

	;dump the bytes per block
	mov eax,[0x5104]
	bswap eax
	mov [flashdriveBytesPerBlock],eax   ;[1]
	STDCALL rcstr5,0,dumpeax

	;compute & dump the flash drive capacity in bytes
	add ebx,1  ;total qty logical blocks = LBAmax + 1
	mul ebx    ;edx:eax=eax*ebx
	mov [flashdriveCapacityBytes],eax   ;[1]
	STDCALL rcstr6,0,dumpeax



	;Status Transport
	;*******************
	STDCALL rcstr3,dumpstr

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
	mov ecx,1  ;data toggle  (ReadCapacity Data IN is 0 so we use 1)
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



	
	


