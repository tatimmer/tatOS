;tatOS/usb/write10.s


;write10

;code to copy an array of bytes from memory to your flash drive



Write10Request:
;the Command Block Wrapper  31 bytes
;the byte order of the dCBWDataTransferLength is LSB FIRST
db 0x55,0x53,0x42,0x43, 0xdd,0xcc,0xbb,0xaa, 0,2,0,0, 0,0,10
;the CBWCB which is the scsi command block
;here the byte order for the Logical Block Address
;and the Transfer Length is LSB LAST !!!
;here we write to lba=3 which is the 4th block
db 0x2a,0, 0,0,0,3, 0, 0,1, 0,0,0,0,0,0,0


%if USBCONTROLLERTYPE = 0  ;uhci

Write10_structTD_command:
dd Write10Request  ;BufferPointer
dd 31              ;all scsi requests are 31 bytes 
dd FULLSPEED 
dd PID_OUT
dd bulktoggleout   ;Address of toggle
dd BULKOUTENDPOINT ;Address of endpoint
dd FLASHDRIVEADDRESS     ;device address on bus

Write10_structTD_data:
dd 0                ;BufferPointer-set by edi arg below-data is read to here
dd 0                ;dCBWDataTransferLength total qty bytes for transfer-set below
dd FULLSPEED  
dd PID_OUT
dd bulktoggleout
dd BULKOUTENDPOINT
dd FLASHDRIVEADDRESS    

%endif



wrtstr4 db 'Write10: total qty bytes to transfer',0
wrtstr5 db 'Write10: invalid LBAstart out of range',0
wrtstr6 db 'Write10: flash drive not ready',0
wrtstr8 db 'Write10: LBA start',0
wrtstr9 db 'Write10: qty blocks',0
wrtstr10 db 'Write10: memory address',0
wrtstr11 db 'Write10: Command Transport failed',0
wrtstr12 db 'Write10: Data Transport failed',0
wrtstr13 db 'Write10: Status Transport failed',0
wrtstr14 db 'Write10: CSW check failed',0


;*********************************************************************
;write10 

;copy bytes from memory -> flash drive

;input:
;ebx = destination LBAstart on pendrive
;ecx = qty blocks to write  
;esi = source address of memory 

;return: ZF is set on error, clear on success 

sourceAddress dd 0
;********************************************************************

write10:

	pushad


	;dump the lbastart, qtyblocks, memory address
	mov eax,ebx
	STDCALL wrtstr8,0,dumpeax
	mov eax,ecx
	STDCALL wrtstr9,0,dumpeax
	mov eax,esi
	STDCALL wrtstr10,0,dumpeax


	mov [sourceAddress],esi  ;save for later


	;check for valid LBAstart within range of flash drive
	cmp ebx,[flashdriveLBAmax]
	jae near .InvalidLBA 


	;compute eax = dCBWDataTransferLength = total qty bytes to transfer
	mov edx,0
	mov eax,512  ;bytes per block
	mul ecx      ;ecx=qty blocks
	;eax = qtyblocks * 512 = dCBWDataTransferLength
	STDCALL wrtstr4,0,dumpeax
	mov [dCBWDataTransferLength],eax
	mov [Write10Request+8],eax

%if USBCONTROLLERTYPE = 0  ;uhci
	mov [Write10_structTD_data+4],eax ;qty bytes to transfer
	mov [Write10_structTD_data],esi   ;buffer pointer
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	mov [chainbytecount],eax
	mov [BufferPointer],esi
%endif


	;copy the lba of the first block to the CBWCB
	;reverse the byte order because we need lsb last
	bswap ebx
	mov [Write10Request+17],ebx


	;copy the word qty blocks to the CBWCB
	mov [Write10Request+22],ch
	mov [Write10Request+23],cl



	STDCALL devstr1,dumpstr  ;FLASH



	;Command Transport
	;*********************
	STDCALL transtr17a,dumpstr

%if USBCONTROLLERTYPE = 0  ;uhci
	push Write10_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .WriteErrorCommandTransport
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;copy request to data buffer 0xb70000
	mov esi,Write10Request
	mov edi,0xb70000
	mov ecx,31
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,31 ;Request is 31 bytes long
	mov ebx,0  ;PID = OUT
	mov ecx,[bulktoggleout] 
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_BULKOUT_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .WriteErrorCommandTransport

	;save the toggle value ehci left us
	mov [bulktoggleout],ebx
%endif




	;Data Transport
	;*****************
	STDCALL transtr17b,dumpstr

%if USBCONTROLLERTYPE = 0  ;uhci
	push Write10_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .WriteErrorDataTransport
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;copy the source bytes to our usb data buffer at 0xb70000
	mov esi,[sourceAddress]
	mov edi,0xb70000
	mov ecx,[dCBWDataTransferLength]
	call strncpy

	;generate a chain of ehci TD's
	;global dwords [chainbytecount], [BufferPointer] are set above
	mov eax,[bulktoggleout]
	mov [bulktoggle],eax
	mov dword [pid],PID_OUT
	call ehci_prepare_TDchain

	;write address of first TD to our bulk queue head to init transaction
	mov eax,FLASH_BULKOUT_QH_NEXT_TD_PTR
	call ehci_runTDchain
	jnz near .WriteErrorDataTransport

	;on success ebx=value of data toggle of last qTD in the chain after run
	;see notes at the end of run() why we are doing this
	mov [bulktoggleout],ebx

	;to see what the ehci did to our TD's
	call dumpehciTDs  ;for debug
%endif



	;Status Transport
	;*****************
	STDCALL transtr17c,dumpstr

%if USBCONTROLLERTYPE = 0  ;uhci
	push SCSI_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .WriteErrorStatusTransport 

	mov esi,scsiCSW
	call CheckCSWstatus  ;test the last byte of CSW for pass/fail
	jnc .WriteErrorCSWcheck
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;generate 1 usb Transfer Descriptor
	mov eax,13 ;qty bytes to receive, every CSW is 13 bytes
	mov ebx,1  ;PID IN
	mov ecx,[bulktogglein] 
	call generate_TD

	mov ebx,bulktogglein
	call toggle

	;attach TD to queue head and run
	mov eax,FLASH_BULKIN_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .WriteErrorStatusTransport 

	;dump the CSW and check last byte for pass/fail
	mov esi,0xb70000
	call CheckCSWstatus  ;test the last byte of CSW for pass/fail
	jnc .WriteErrorCSWcheck
%endif


	

	;if we got here we have a successful write10
	jmp .success

.WriteErrorCommandTransport:
	;because a failure of write10 is serious
	;we warn the user and exit
	;a failure here could possibly write bad data to random parts of your Flash 
	STDCALL wrtstr11,putspause 
	xor eax,eax  ;set ZF on error
	jmp .done
.WriteErrorDataTransport:
	STDCALL wrtstr12,putspause 
	xor eax,eax  ;set ZF on error
	jmp .done
.WriteErrorStatusTransport:
	STDCALL wrtstr13,putspause 
	xor eax,eax  ;set ZF on error
	jmp .done
.WriteErrorCSWcheck:
	STDCALL wrtstr14,putspause 
	xor eax,eax  ;set ZF on error
	jmp .done
.flashNotReady:
	STDCALL wrtstr6,notready,popupmessage
	xor eax,eax  ;set ZF on error
	jmp .done
.InvalidLBA:
	STDCALL wrtstr5,dumpstr
	xor eax,eax  ;set ZF on error
	jmp .done
.success:
	or eax,1     ;clear ZF on success
.done:
	popad
	ret




