;tatOS/usb/prepareTD-ehci.s
;rev March 2015


;ehci_prepare_TDchain
;generate_TD
;generate_mouse_TD



;functions to create a single qTD transfer descriptor (max 0x5000 bytes transferred)
;or a chain/single link list of qTDs (for > 0x5000 bytes)
;for EHCI data transfers

;to start a usb transaction, the address of the first qTD is written into the QH
;see run.s
;a circular link list of QH queue heads is created in initehci.s

;there is a new function in the dump called "dumpehciTDs" which you can call
;after any usb transfer to see what the ehci has done with your TD packet header

TDstr1 db 'prepareTD: dword1 next qTD pointer',0
TDstr2 db 'prepareTD: dword2 alternate next qTD pointer',0
TDstr3 db 'prepareTD: dword3 packet header',0
TDstr4 db 'prepareTD: dword4 buffer pointer page 0',0
TDstr5 db 'prepareTD: dword5 buffer pointer page 1',0
TDstr6 db 'prepareTD: dword6 buffer pointer page 2',0
TDstr7 db 'prepareTD: dword7 buffer pointer page 3',0
TDstr8 db 'prepareTD: dword8 buffer pointer page 4',0
TDstr9 db 'ehci_prepareTDchain: qty TDs generated',0
TDstr10 db 'ehci_prepareTDchain',0







;******************************************************************
;ehci_prepare_TDchain
;build of chain (single link list) of ehci qTD's in memory 
;for conducting usb bulk data transactions read10/write10

;we space out ehci TD's every 64 bytes in memory

;input
;global dword [BufferPointer]   
;global dword [chainbytecount]  
;global dword [bulktoggle]  holds value of dword [bulktogglein] or [bulktoggleout] 
;global dword [pid]         holds value PID_IN or PID_OUT

;note for a chain of TD's, the BufferPointer must be page aligned
;*******************************************************************

ehci_prepare_TDchain:

	pushad

	STDCALL TDstr10,dumpstr


	;init chainqtyTDs-this is needed by runTDchain
	mov dword [chainqtyTDs],0
	mov dword [haveNULLpacket],0  


	;init edi to address where first TD will be written
	mov edi,0xd60000


	;init LinkPointer to next TD 
	mov [LinkPointer],edi
	add dword [LinkPointer],EHCITDSPACING


	;get qty bytes for xfer into eax
	mov eax,[chainbytecount] 



	;Transaction speed control
	;set TDmaxbytes which directly affects "Total Bytes to Transfer" per TD
	;the ehci controller can transfer multiple packets per time frame
	;0x5000 is the max qty bytes a single ehci page pointer can access
	;we started this driver with a transfer of only 512 bytes per TD
	;then got bold and upped it to 0x1000 bytes per TD with a significant increase in speed
	;now we make use of all 5 page page pointers to maximize the byte xfer rate 
	;0x5000 is (40) 512 byte packets per TD
	mov dword [TDmaxbytes],0x5000  



	;set TDbytes if NULL packet 
	cmp eax,0
	jnz .nonullpacket
	;ehci uses n qty bytes like it should
	mov dword [TDbytes],0      ;n 
	mov dword [haveNULLpacket],1
	jmp .FirstDword
.nonullpacket:




	;********* start of loop **************************************

	;the loop must deal with 3 sizes of TD's:
	;	NULL TD's  (TDbytes = 0x800)       i.e. 0 byte packet status stage
	;	short TD's (TDbytes < TDmaxbytes)  last packet
	;	full TD's  (TDbytes = TDmaxbytes)  most TD's
	

.buildTDchain:	

	;set TDbytes to 0x5000 for most full TD's
	;the ehci controller will generate 40 packets of 512 bytes each to
	;transfer this much data in one TD
	;set TDbytes will usually be less than 0x5000 for the last short TD
	mov eax,[TDmaxbytes]
	mov ebx,[chainbytecount]
	cmp ebx,eax
	jb .setshortpacket
	;set full packet
	mov [TDbytes],eax   ;TDbytes=TDmaxbytes
	jmp .donesetTDbytes
.setshortpacket:
	mov [TDbytes],ebx   ;TDbytes=chainbytecount
.donesetTDbytes:

	

	;in this loop:
	;eax=holds one of the dwords of the TD we are building
	;edi=destination address where TD is written
	;esi= address of structureTD


.FirstDword:

	;1st dword of TD (Next qTD Pointer)
	;************************************
	;for both uhci and ehci the 1st dword is a pointer to the next TD
	;each TD holds address of next TD else 1 if terminate
	;we terminate if chainbytecount <= TDmaxbytes or on NULL packet
	cmp dword [haveNULLpacket],1
	jz .terminateLinkPointer
	mov eax,[TDmaxbytes]
	cmp [chainbytecount],eax
	jbe .terminateLinkPointer
	;TD will point to the next TD
	mov eax,[LinkPointer]
	mov [edi],eax          ;write TD 1st dword
	jmp .SecondDword
.terminateLinkPointer:
	;TD will not point to another TD
	mov dword [edi],1





	;2nd dword of TD (Alternate Next qTD Pointer)
	;**********************************************
.SecondDword:
	;this is used by the controller on short packet
	;for now we just set to 1=terminate and see what happens ???
	mov dword [edi+4],1





	;3rd dword of td  (USB Packet Header)
	;**********************************

	;for both uhci and ehci the 3rd dword of TD contains the interesting usb stuff

	;bit[31] data toggle  (1,0,1,0...)
	mov eax,[bulktoggle]    ;get value of data toggle
	shl eax,31              ;shift toggle to bit31
	;all qTD's in this chain will use the same toggle
	;controller will retire the last qTD and flip the toggle so we must also



	;bit[30:16]  Total Bytes to Transfer
	mov ebx,[TDbytes]  ;n
	shl ebx,16
	or eax,ebx

	;bit[15] Interrupt on Complete    is left at zero

	;bit[14:12] Current Page (C_Page)  is left at 0
	;index into buffer pointer list, valid values are 0-4
	;we only use BufferPointerPage0 so C_Page must always be 0
	;see discussion about Buffer Pointer below


	;bit[11:10] Error Counter CERR
	;clear bits 10,11 to allow unlimited retry
	;in the past we only allowed 3 tries 
	;but I think this was the cause of write10 errors
	and eax,0xfffff3ff


	;bit[9:8] PID code
	;read10  uses 1=IN  for data transport
	;write10 uses 0=OUT for data transport
	mov ebx,[pid] ;ebx=PID_IN or PID_OUT
	shl ebx,8
	or eax,ebx


	;bit[7:0] Status
	;bit fields as follows
	;7=active, 6=halted, 5=DataBufferError, 4=Babble, 3=TransactError, 
	;2=MissedMicro, 1=SplitTransState, 0=PingState
	;split transactions are for low speed devices plugged into hubs
	;set bit7 = active, the controller clears this on success
	or eax,0x80


	;finally write the 3rd dword of TD
	mov [edi+8],eax

	;note with ehci the Endpoint and Address are in the queue head






	;4th dword of TD  (BufferPointer's )
	;****************************************
	;this is the address to send/receive data 
	;this could be the request/command/CBW
	;or this is where the device data is returned
	;or this could be the data we are sending to the device
	;or this could be 0 in status transport or the CSW

	;we use all 5 BufferPointerPages here 
	;I suggest for ehci with a chain of TD's
	;that the initial value of BufferPointerPage0 should be page aligned 
	;otherwise you will get bad results
	;thereafter add 0x5000 for full TD bulk transfers 
	;to the BufferPointer for each successive TD

	;bits[11:0] are reserved for all pointers and must be set to 0 by software
	;for page 0 these bits will be modified by the controller
	;to indicate the "offset into the current page as selected by C_Page"

	mov ebx,[BufferPointer]
	mov [edi+12],ebx ;Buffer Pointer Page 0, 4th dword
	add ebx,0x1000
	mov [edi+16],ebx ;Buffer Pointer Page 1, 5th dword
	add ebx,0x1000       
	mov [edi+20],ebx ;Buffer Pointer Page 2, 6th dword
	add ebx,0x1000
	mov [edi+24],ebx ;Buffer Pointer Page 3, 7th dword
	add ebx,0x1000
	mov [edi+28],ebx ;Buffer Pointer Page 4, 8th dword


	;and if your controller uses 64bit addressing
	;the upper 32bits of each page is specified here
	mov dword [edi+32],0   ;Extended Buffer Pointer Page 0, 9th dword
	mov dword [edi+36],0
	mov dword [edi+40],0
	mov dword [edi+44],0
	mov dword [edi+48],0   ;Extended Buffer Pointer Page 4, 13th dword


	;for debug we dump the first 8 dwords of the TD
	;this is what the TD's look like before the controller reads them
	;dont forget the controller will modify the packet header 3rd dword
;	mov eax,[edi]
;	STDCALL TDstr1,0,dumpeax  ;Next qTD Pointer
;	mov eax,[edi+4]
;	STDCALL TDstr2,0,dumpeax  ;Alternate Next qTD Pointer
	mov eax,[edi+8]
	STDCALL TDstr3,0,dumpeax  ;USB Packet Header
;	mov eax,[edi+12]
;	STDCALL TDstr4,0,dumpeax  ;buffer pointer page 0
;	mov eax,[edi+16]
;	STDCALL TDstr5,0,dumpeax  ;buffer pointer page 1
;	mov eax,[edi+20]
;	STDCALL TDstr6,0,dumpeax  ;buffer pointer page 2
;	mov eax,[edi+24]
;	STDCALL TDstr7,0,dumpeax  ;buffer pointer page 3
;	mov eax,[edi+28]
;	STDCALL TDstr8,0,dumpeax  ;buffer pointer page 4


	;******done building a single TD, now prepare loop for next time around *******




	inc dword [chainqtyTDs] ;needed for runTDchain

	;preserve eax til end of loop
	mov eax,[TDbytes]   

	;quit if NULL packet
	cmp dword [haveNULLpacket],1
	jz .done

	;quit if short packet
	cmp eax,[TDmaxbytes]
	jb .done

	;if we got here we just processed a full packet

	;increment BufferPointer (Memory Address)
	add [BufferPointer],eax   ;BufferPointer += TDbytes



	;increment where the next TD will be written
	add edi,EHCITDSPACING

	;increment LinkPointer
	add dword [LinkPointer],EHCITDSPACING

	;decrement chainbytecount
	sub dword [chainbytecount],eax   ;chainbytecount -= TDbytes
	;sets ZF if chainbytecount goes to zero
	jnz .buildTDchain           
	;*************end of loop ******************


.done:
	mov eax,[chainqtyTDs]
	STDCALL TDstr9,0,dumpeax

	popad
	ret 







;******************************************************
;generate_TD
;generate a single qTD Transfer Descriptor
;this is for ehci control transfers only (< 0x40 bytes)
;and the small bulk transfers (< 5*0x1000 bytes) 
;like ReadCapacity, Inquiry, RequestSense etc...
;the TD is (8) dwords written to 0xd60000=ADDRESS_FIRST_TD
;the data exchange buffer (between ehci & usb device) is 0xb70000 

;input:
;eax=qty bytes to transfer
;ebx=PID Packet Identifier code 0=OUT, 1=IN, 2=SETUP
;ecx=data toggle 0 or 1
;return:none
;*****************************************************

generate_TD:

	mov dword [0xd60000],1     ;write the Next qTD Pointer

	mov dword [0xd60000+4],1   ;write the Alternate Next qTD Pointer

	;generate the packet header in eax
	;bit15 IOC interrupt on complete is 0
	;bit14:12 C_Page is 0
	;bit11:10 CERR is 0 for unlimited retries
	shl eax,16            ;total bytes to transfer starts bit16
	shl ecx,31            ;data toggle is bit31
	or eax,ecx            ;set data toggle bit in packet header
	shl ebx,8             ;PID code starts bit8
	or eax,ebx            ;set bits for PID code in packet header
	or eax,0x80           ;set bit7 to indicate status="active" 
	mov [0xd60000+8],eax  ;write the packet header

	mov dword [0xd60000+12],0xb70000 ;write the buffer pointer page 0
	mov dword [0xd60000+16],0xb71000 ;buffer pointer page 1
	mov dword [0xd60000+20],0xb72000 ;buffer pointer page 2
	mov dword [0xd60000+24],0xb73000 ;buffer pointer page 3
	mov dword [0xd60000+28],0xb74000 ;buffer pointer page 4

	;and if your controller uses 64bit addressing
	;the upper 32bits of each page is specified here
	mov dword [0xd60000+32],0   ;Extended Buffer Pointer Page 0, 9th dword
	mov dword [0xd60000+36],0
	mov dword [0xd60000+40],0
	mov dword [0xd60000+44],0
	mov dword [0xd60000+48],0   ;Extended Buffer Pointer Page 4, 13th dword


	;we generated a single TD 
	mov dword [chainqtyTDs],1
	
	ret







;*******************************************************************
;generate_mouse_TD
;this TD is for mouse interrupt transfers with the perodic list
;using ehci and a root hub
;the TD is written starting at 0x1003500
;input:none
;return:none
;********************************************************************

generate_mouse_TD:

	;registers (in particular eax) must be preserved for usbmouserequest
	pushad

	mov dword [0x1003500],1     ;write the Next qTD Pointer

	mov dword [0x1003504],1     ;write the Alternate Next qTD Pointer

	;generate the packet header in eax
	;we start with eax=0x0180
	;this means bits7=active, bit8=PID "in", IOC=0, C_Page=0, C_ERR=0
	mov eax,0x0180
	mov ebx,[mousetogglein]               ;get value of toggle
	shl ebx,31                            ;bit31 is toggle
	or eax,ebx                            ;set toggle bit
	movzx ebx,word [MOUSE_WMAXPACKETSIZE] ;total bytes to transfer
	shl ebx,16                            ;bit16 is total bytes to transfer
	or eax,ebx                            ;add total bytes to transfer
	mov [0x1003508],eax                   ;write the packet header
	;now flip the toggle for the next TD
	not dword [mousetogglein]
	and dword [mousetogglein],1

	;0x1004000 is where the mouse report is written to 
	mov dword [0x100350c], 0x1004000      ;write the buffer pointer page 0
	mov dword [0x1003510],0               ;buffer pointer page 1
	mov dword [0x1003514],0               ;buffer pointer page 2
	mov dword [0x1003518],0               ;buffer pointer page 3
	mov dword [0x100351c],0               ;buffer pointer page 4

	;and if your controller uses 64bit addressing
	;the upper 32bits of each page is specified here
	mov dword [0x1003520],0   ;Extended Buffer Pointer Page 0, 9th dword
	mov dword [0x1003524],0
	mov dword [0x1003528],0
	mov dword [0x100352c],0
	mov dword [0x1003530],0   ;Extended Buffer Pointer Page 4, 13th dword

	popad
	
	ret






