;tatOS/usb/run.s

;June 2013

;ehci_run
;ehci_runTDchain
;uhci_runTDchain


;March 2015
;added a check for ehci PING, every time I see bit0 set this indicates PING but this is
;an internal thing between ehci and the flash drive, no need for software intervention
;every time I see bit0 set I always see bit7 clear indicating TD is retired no other
;error bits are set so in summary when al=0 thats good and when al=1 thats ok too !


runstr3 db 'ehci time out error: exceeded time allotted to complete transaction',0
runstr5 db 'USB runTD Halted/Stalled bit (endpoint has halted)',0
runstr6 db 'USB runTD Data Buffer Error',0
runstr7 db 'USB runTD Babble Detected',0
runstr8 db 'USB runTD Transaction Error',0
runstr9  db 'UHCI NAK',0
runstr10 db 'UHCI CRC',0
runstr11 db 'UHCI bitstuff',0
runstr12 db 'TD status 2nd dword',0
runstr14 db 'ehci run: polling status of Last qTD dword3 packet header ',0
runstr15 db 'PING',0





;**********************************************************************
;ehci_runTDchain
;allow the EHCI controller to parse our TD's in memory
;assumes a chain of TD's has already been built by ehci_prepareTDchain

;input:eax=address of QH Next qTD Pointer to attach to 
;      see initehci.s for address of available queue heads to use
;      for example 0x1005410 is FLASH_BULKIN_QH_NEXT_TD_PTR
	
;return: ZF is set on success, clear on error
;        on success ebx=value of data toggle of last qTD

;required before executing this function:
; * global dword [chainqtyTDs] must hold a proper value before
; * Proper Transfer Descriptor(s) TD's must be written to ADDRESS_FIRST_TD = 0xd60000

ehci_QH_next_TD_address dd 0
;***********************************************************************

ehci_run:
ehci_runTDchain:

	;registers must be preserved
	;failure to do so will result in bad things
	push eax
	push ecx
	push edx
	push esi
	push edi
	push ebp

	;save for later
	mov [ehci_QH_next_TD_address],eax  

	;to begin transaction for ehci: 
	;write the address of our first TD to the 5th dword of our queue head
	;the ehci is already running and checking each queue head in the circular link list
	;the ehci usb 2.0 spec calls this 5th dword the "Next qTD Pointer"
	mov dword [eax],ADDRESS_FIRST_TD

	;now that the TD string is attached to the appropriate QH
	;the usb controller can do its thing

	;get esi=address of last TD in chain
	;this code modified from uhci_runTDchain to work with 64bit addressing
	mov eax,[chainqtyTDs] ;value saved by prepareTDchain
	dec eax
	mov ebx,EHCITDSPACING
	xor edx,edx
	mul ebx              ;eax=(chainqtyTDs-1)*EHCITDSPACING
	add eax,ADDRESS_FIRST_TD
	mov esi,eax

	;set poll counter - waiting for the controller to do its thing 
	mov ecx,50  ;50*100ms per = 5000ms = 5 seconds


.topofloop:

	;poll the Status dword of the last TD in the chain  (control/status)
	;we ignore the previous TD's, if this one doesnt pass the previous wont
	;2do: check every TD

	;ehci status is the lo byte of the 3rd dword of TD (packet header)
	;ehci will write back to this byte setting bits for success or failure
	mov eax,[esi+8]

	;for debug dump the entire packet header
	;the first dump is what the tatOS code generated
	;on successful transaction the last dump shows how ehci modified your qTD
	;it shows how the ehci flips the dt data toggle bit
	;for most usb transactions it only takes 2 loops to complete 
	;the first time you will see the low byte = 0x80 indicating TD still "active"
	;the next loop the low byte will on success = 00 for "retired" no errors
	;on RequestSense Data transport I see this value dumped 9 times before the 
	;command completes and the data is transported
	STDCALL runstr14,0,dumpeax  

	;if al=0 the TD is not active and there are no errors
	;bits 6,5,4,3 are error bits that may be set by the controller
	;a serious error will set 1 or more bits and may de-active the TD
	;and stop/halt the controller
	;so just because the active bit is clear doesnt mean a successful transaction
	;bit2=missed microframe, bit1=splittransaction, bit0=ping
	;I dont know what to do about these 3 bits so for now just ignore

	cmp al,0   ;TD is retired successfully, TD is no longer active
	jz near .success 
	cmp al,1   ;PING, nothing to worry about, bit7 is always clear
	jz .ping
	bt eax,6  ;bit6=1 serious error,halted,babble,stall,errorcnt=0
	jc .halted
	bt eax,5  ;bit5=1 data buffer error
	jc .databuffer
	bt eax,4  ;bit4=1 babble
	jc .babble
	bt eax,3  ;bit3=1 transaction error
	jc .transaction

	;if we got here the TD is still active and no errors

.decrement:
	mov ebx,100
	call sleep ;for 1/10 sec

	dec ecx
	jnz .topofloop

	;if we got here we ran out of time
	;most likely a data toggle problem
	STDCALL runstr3,dumpstr
	jmp .dumpOverlay



.ping:
	;if EPS=hi speed like flash & PID=OUT 
	STDCALL runstr15,dumpstr
	jmp .success
.halted:
	;a serious error, endpoint has halted
	;reinit controller & flash
	mov dword [ehciEndpointHasHalted],1
	STDCALL runstr5,dumpstr
	STDCALL runstr5,putscroll  
	jmp .dumpOverlay
.databuffer:
	STDCALL runstr6,dumpstr
	jmp .dumpOverlay
.babble:
	STDCALL runstr7,dumpstr
	jmp .dumpOverlay
.transaction:
	;sometimes RequestSense will fail with this error
	;just reint ehci and flash again and all will be well
	;there must be a more elegant way to recover
	;perhaps "Bulk Only Mass Storage Reset" ? 
	STDCALL runstr8,dumpstr
	jmp .dumpOverlay

.dumpOverlay:
	;to aid in debugging whats going on
	;dump the Overlay Area in the Queue Head
	;these fields hold the value of the last TD processed
	mov esi,[ehci_QH_next_TD_address] ;esi=address of "Next qTD Pointer"
	sub esi,16  ;to get to start of QH
	call dumpQH

	;dump the transfer descriptor 8 dwords 
	;so we can see how the controller modified them
	;call dumpehciTDs

	or eax,1   ;error
	jmp .done

.success:

	;Data Toggle management
	;Read10 Data transport always uses dword [bulktogglein]
	;prepareTD_ehci.s  prepares each qTD in the chain to have 
	;the same data toggle value either set or clear
	;after the transaction the controller will modify the qTD to decrement the qty
	;of bytes transferred and clear the active bits or set error bits
	;but each qTD in the chain will maintain the same toggle bit except the last qTD
	;the last qTD may have its toggle bit flipped or it may keep the same toggle bit
	;I havent quite figured out the exact behavior of the ehci yet
	;there must be something in the standard about this
	;so in order to avoid a transaction error with Read10 Status transport
	;since Read10 status transport also uses bulktogglein and it must use the same
	;toggle value as the last qTD of read10 data transport
	;so we will just copy the state of the toggle bit as the controller left it
	;and use this for Read10 Status transport

	mov ebx,eax         ;eax=dword3 packet header from last qTD
	and ebx,0x80000000  ;mask off all except bit31 toggle bit
	shr ebx,31          ;return ebx=value of data toggle of last qTD set or clear by ehci

	xor eax,eax  ;set zf on success

.done:

	pop ebp
	pop edi
	pop esi
	pop edx
	pop ecx
	pop eax

	ret











;****************************************************
;uhci_runTDchain
;allow the UHCI controller to parse our TD's in memory
;input:TD chain built by uhci_prepareTDchain
;return: ZF is set on success, clear on error
;***************************************************

uhci_runTDchain:

	;registers must be preverved
	;failure to do so will result in bad things
	pushad

	;to begin transaction for uhci attach td to 2nd dword of queue head
	mov dword [0x1005100+4],ADDRESS_FIRST_TD


	;now that the TD is attached to the QH
	;the usb controller can do its thing
	

	;get esi=address of last TD in chain
	mov esi,[chainqtyTDs] ;value saved by prepareTDchain
	dec esi
	shl esi,5  ;esi*32
	add esi,ADDRESS_FIRST_TD

	;set poll counter - waiting for the controller to do its thing 
	mov ecx,20  ;20*100ms per = 2000ms = 2 seconds


.topofloop:

	;get the Status dword of the last TD in the chain  (control/status)
	;we ignore the previous TD's, if this one doesnt pass the previous wont
	;all we do is test if the controller set the stall bit or if TD is still active


	;uhci status is 2nd dword of td
	mov eax,[esi+4]

	;for debug if you want to see the TD status
	;STDCALL runstr12,0,dumpeax


	test eax,10000000000000000000000b ;bit22 set if stall
	jz .1  ;no stall
	jmp .decrement
.1:	test eax,100000000000000000000000b ;bit23 set if active
	jz .success  ;no active



.decrement:
	mov ebx,100
	call sleep ;for 1/10 sec
	dec ecx
	jnz .topofloop


.error:
	or eax,1   ;clear zf on error
	jmp .done
.success:
	xor eax,eax  ;set zf on success
.done:
	popad
	ret


