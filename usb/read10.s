;tatOS/usb/read10.s

;read10

;code to transfer blocks off the usb flash drive to memory
;before attempting this function or write10
;you have to go thru the entire init sequence in initflash.s successfully
;and before that you have to init the usb controller



align 0x10

;note the bmCBWFlags byte is important for some devices but not
;others. For example my SimpleTech Bonzai pen drive I can set
;bmCBWFlags=0 and it will still read but with my Toshiba
;I must set bmCBWFlags=0x80 otherwise it will except the CBW
;but NAK every data request. Learned this the hard way.

Read10Request:

;the Command Block Wrapper
;the dCBWDataTransferLength, LBA, and TransferLength
;get overwritten below
dd 0x43425355   ;dCBWSignature
dd 0xaabbccdd   ;dCBWTag  (just make it up)
dd 0            ;dCBWDataTransferLength (total bytes Data Transport=written below)
db 0x80         ;bmCBWFlags (TD direction 0x80=IN 00=OUT)
db 0            ;bCBWLun
db 10           ;bCBWCBLength,Read10 is a 10 byte CBWCB
;CBWCB  10 bytes  (see Working Draft SCSI Block Commands SBC-2)
db 0x28         ;operation code for scsi Read10 
db 0            ;RDPROTECT/DPO/FUA/FUA_NV
db 0            ;LBA to read (msb)   filled in below
db 0            ;LBA
db 0            ;LBA
db 0            ;LBA (lsb) 
db 0            ;groupnum ?
db 0            ;TransferLength MSB in blocks  filled in below
db 0            ;TransferLength LSB 
db 0            ;control
times 6 db 0    ;pad to give a 31 byte CBW


%if USBCONTROLLERTYPE == 0  ;uhci

Read10_structTD_command:
dd Read10Request    ;BufferPointer
dd 31               ;all scsi requests are 31 bytes 
dd FULLSPEED 
dd PID_OUT
dd bulktoggleout   ;Address of toggle
dd BULKOUTENDPOINT ;Address of endpoint
dd FLASHDRIVEADDRESS     ;device address on bus

Read10_structTD_data:
dd 0                ;BufferPointer-set by edi arg below-data is read to here
dd 0                ;dCBWDataTransferLength total qty bytes for transfer-set below
dd FULLSPEED  
dd PID_IN
dd bulktogglein
dd BULKINENDPOINT
dd FLASHDRIVEADDRESS    

%endif


readstr4 db 'Read10 total qty bytes to transfer',0
readstr8 db 'Read10: LBA start',0
readstr9 db 'Read10: qty blocks',0
readstr10 db 'Read10: memory address',0
readstr11 db 'Read10: Command Transport failed',0
readstr12 db 'Read10: Data Transport failed',0
readstr13 db 'Read10: Status Transport failed',0
readstr14 db 'Read10: CSW check failed',0


;*****************************************************************
;read10

;copy bytes from flash drive -> memory
;the scsi read10 command permits reading by blocks
;the assumption here is that block size = 512 bytes
;see the dump for the output of the ReadCapacity command

;input:
;ebx = lba of first block/sector to read  (0->LBAmax)
;ecx = qty blocks to read
;edi = destination memory address

;return: ZF is set on error, clear on success 
;*************************************************************

read10:

	pushad

	;dump the lbastart, qtyblocks, memory address
	call dumpnl
	mov eax,ebx
	STDCALL readstr8,0,dumpeax
	mov eax,ecx
	STDCALL readstr9,0,dumpeax
	mov eax,edi
	STDCALL readstr10,0,dumpeax


	;compute eax = dCBWDataTransferLength = total qty bytes to transfer
	mov edx,0
	mov eax,512  ;bytes per block
	mul ecx      ;ecx=qty blocks
	;eax = qtyblocks * 512 = dCBWDataTransferLength
	STDCALL readstr4,0,dumpeax
	mov [Read10Request+8],eax

%if USBCONTROLLERTYPE == 0  ;uhci
	mov [Read10_structTD_data+4],eax  ;total qty bytes to transfer
	mov [Read10_structTD_data],edi    ;buffer pointer
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	mov [chainbytecount],eax
	mov [BufferPointer],edi
%endif


	;copy the lba of the first block to the CBWCB
	;reverse the byte order because we need lsb last
	bswap ebx
	mov [Read10Request+17],ebx


	;copy the word qty blocks to read to the CBWCB
	mov [Read10Request+22],ch
	mov [Read10Request+23],cl



	;clear out the 13 byte scsiCSW
	mov ecx,13
	mov edi,scsiCSW
	mov al,0xff
	cld         
	rep stosb   


	
	STDCALL devstr1,dumpstr  ;FLASH


	;Command Transport
	;*********************
	STDCALL transtr16a,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push Read10_structTD_command
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .ReadErrorCommandTransport
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;copy request to data buffer 0xb70000
	;this request tells ehci what to do during data transport
	mov esi,Read10Request
	mov edi,0xb70000
	mov ecx,31
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,31 ;Request is 31 bytes long
	mov ebx,0  ;PID = OUT
	mov ecx,[bulktoggleout] 
	call generate_TD

	;flip the toggle
	mov ebx,bulktoggleout
	call toggle

	;attach TD to queue head and run
	mov eax,FLASH_BULKOUT_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .ReadErrorCommandTransport
%endif





	;Data Transport
	;*****************
	STDCALL transtr16b,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push Read10_structTD_data
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .ReadErrorDataTransport
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)

	;generate a chain of ehci TD's
	;global dwords [chainbytecount], [BufferPointer] are set above
	mov eax,[bulktogglein]
	mov [bulktoggle],eax
	mov dword [pid],PID_IN
	call ehci_prepare_TDchain

	;write address of first TD to our bulk queue head to init transaction
	mov eax,FLASH_BULKIN_QH_NEXT_TD_PTR
	call ehci_runTDchain
	jnz near .ReadErrorDataTransport

	;on success ebx=value of data toggle of last qTD in the chain after run
	;see notes at the end of run() why we are doing this
	mov [bulktogglein],ebx

	;to see what the ehci did to our TD's
	call dumpehciTDs  ;for debug
%endif



	;Status Transport
	;*****************
	STDCALL transtr16c,dumpstr

%if USBCONTROLLERTYPE == 0  ;uhci
	push SCSI_structTD_status
	call uhci_prepareTDchain
	call uhci_runTDchain
	jnz near .ReadErrorStatusTransport

	mov esi,scsiCSW
	call CheckCSWstatus  
	jnc .ReadErrorCSWcheck
%endif

%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;generate 1 usb Transfer Descriptor
	mov eax,13 ;qty bytes to receive, every CSW is 13 bytes
	mov ebx,1  ;PID IN
	mov ecx,[bulktogglein] 
	call generate_TD

	;flip the toggle
	mov ebx,bulktogglein
	call toggle

	;attach TD to queue head and run
	mov eax,FLASH_BULKIN_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .ReadErrorStatusTransport

	;dump the CSW and check last byte for pass/fail
	mov esi,0xb70000
	call CheckCSWstatus  
	jnc .ReadErrorCSWcheck
%endif


	
	
	;if we got here we have a successful read10
	jmp .success

.ReadErrorCommandTransport:
	STDCALL readstr11,putspause 
	xor eax,eax  ;set ZF on error
	jmp .done
.ReadErrorDataTransport:
	STDCALL readstr12,putspause 
	xor eax,eax  ;set ZF on error
	jmp .done
.ReadErrorStatusTransport:
	STDCALL readstr13,putspause 
	xor eax,eax  ;set ZF on error
	jmp .done
.ReadErrorCSWcheck:
	STDCALL readstr14,putspause 
	xor eax,eax  ;set ZF on error
	jmp .done
.success:
	or eax,1     ;clear ZF on success
.done:
	popad
	ret






