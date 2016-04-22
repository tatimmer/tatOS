;tatOS/usb/prepareTD.s



;uhci_prepareTDchain
;uhci_prepareInterruptTD
;uhci_generate_keyboard_TD



;functions to prepare usb transfer descriptor TD chains for UHCI
;a TD is a data structure that is read by the usb controller
;the TD instructs the controller how to transfer data between controller & device




;***********************************************************************************
;uhci_prepareTDchain
;function to build a single TD transfer descriptor or chain of TD's
;for UHCI Usb Controller
;for control or bulk transactions
;for interrupt transactions see prepareInterruptTD below
;the TD's are written to memory starting at 0xd60000
;use runTDchain to execute

;uhci uses a 32 byte TD for 32bit operation

;structureTD (28 bytes)
;dword Address of BufferPointer to send/receive data
;dword (n) Total qty bytes to send (OUT) or receive (IN) in the chain
;dword Speed: 
;      0 = FlashDrive operating at full or hi speed 
;      1 = Mouse operating at low speed 
;dword PID Packet ID: use PID_SETUP or PID_IN or PID_OUT 
;dword Address of Data Toggle (bulktogglein, bulktoggleout, controltoggle)             
;dword Address of Endpoint  (endpoint0, BULKEPIN, BULKEPOUT, MOUSEPIN )
;dword Constant unique device address (ADDRESS0, BULKADDRESS, MOUSEADDRESS)             


;input
;push Address of structureTD    [ebp+8]   

;return:none

;note for a control xfer you must set your data toggle before calling 
;this function, for bulk transfers this is not necessary
;***************************************************************************


uhci_prepareTDchain:

	push ebp
	mov ebp,esp
	pushad


	;init chainqtyTDs-this is needed by runTDchain
	mov dword [chainqtyTDs],0
	mov dword [haveNULLpacket],0  


	;init edi to address where first TD will be written
	mov edi,0xd60000


	;init LinkPointer to next TD which is alway 32 bytes greater than edi
	mov [LinkPointer],edi
	add dword [LinkPointer],UHCITDSPACING


	;esi holds address of structureTD
	mov esi,[ebp+8]


	;get the initial value of the buffer pointer
	mov eax,[esi]
	mov [BufferPointer],eax


	;get qty bytes for xfer
	mov eax,[esi+4] 
	mov [chainbytecount],eax



	;set TDmaxbytes
	;for control endpoint, bMaxPacketSize0 is at (DeviceDescriptor+7)
	;only 08h, 10h, 20h, 40h are valid
	;for all other endpoints wMaxPacketSize is at (EndpointDescriptor+4)
	;the usb mouse can only handle 8 byte packets on uhci or ehci
	;the usb flash drive can handle 40h byte packets on uhci and 200h on ehci
	mov dword [TDmaxbytes],8    ;set default for low speed mouse
	cmp dword [esi+8],1         ;test for low speed device
	jz .havelowspeed
	mov dword [TDmaxbytes],64   ;full speed flash drive
.havelowspeed:



	;set TDbytes if NULL packet 
	cmp eax,0
	jnz .nonullpacket
	;uhci uses n-1 qty bytes and NULL packet is 0x7ff (wierd)
	mov dword [TDbytes],0x800  ;0x7ff+1
	mov dword [haveNULLpacket],1
	jmp .FirstDword
.nonullpacket:





	;********* start of loop **************************************

	;the loop must deal with 3 sizes of TD's:
	;	NULL TD's  (TDbytes = 0x800)       i.e. 0 byte packet status stage
	;	short TD's (TDbytes < TDmaxbytes)  last packet
	;	full TD's  (TDbytes = TDmaxbytes)  most TD's
	

.buildTDchain:	

	;set TDbytes for this TD to either short or full packet
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

	;1st dword of TD (LinkPointer)
	;******************************
	;for both uhci and ehci the 1st dword is a pointer to the next TD
	;ehci calls this Next qTD Pointer
	;each TD holds address of next TD else 1 if terminate
	;we terminate if chainbytecount <= TDmaxbytes or on NULL packet
	cmp dword [haveNULLpacket],1
	jz .terminateLinkPointer
	mov eax,[TDmaxbytes]
	cmp [chainbytecount],eax
	jbe .terminateLinkPointer
	;TD will point to the next TD
	mov eax,[LinkPointer]
	or eax,100b            ;depth first TD (for uhci only)
	mov [edi],eax          ;write TD 1st dword
	jmp .SecondDword
.terminateLinkPointer:
	;TD will not point to another TD
	mov dword [edi],1





	;2nd dword of TD
	;****************
.SecondDword:
	;for uhci this dword is control/status
	;unlimited retries, speed, no Isochronous, no Interrupt On Complete, active
	;the actual length bits[10:0] n-1 is written by uhci at completion
	mov ebx,[esi+8]  ;0=full speed, 1=low speed
	shl ebx,26     
	mov eax,1        ;1=active
	shl eax,23      
	or eax,ebx
	mov [edi+4],eax





	;3rd dword of td  (USB PacketHeader)
	;**********************************

	;for both uhci and ehci the 3rd dword of TD contains the interesting usb stuff
	;unfortunately the bit fields are all differant

	;bit[31:21] Max Length
	;number of data bytes "allowed" for the transfer.
	;some devices allow you to set this to TDmaxbytes for each packet even the last
	;other devices will stall if you dont set this to the proper number for short packet
	;Ah the joys of hdwre programming.
	mov eax,[TDbytes]  ;n
	dec eax            ;n-1
	shl eax,21
	
	;bit[19] data toggle  (1,0,1,0...)
	;see Toggle.info for details
	mov ebx,[esi+16] ;get address of toggle        
	mov ecx,[ebx]    ;get value of toggle
	shl ecx,19
	or eax,ecx
	;toggle our global
	not dword [ebx]   ;flip all the bits
	and dword [ebx],1 ;mask off bit0
	
	;bit[18:15] endpoint 
	;must read device endpoint descriptor to get this one
	mov ebx,[esi+20]  ;get address of endpoint
	mov ecx,[ebx]     ;get value of endpoint
	shl ecx,15
	or eax,ecx
	
	;bit[14:8] device address on the usb bus
	;0 for control else 2 or 3
	mov ebx,[esi+24]
	shl ebx,8
	or eax,ebx
	
	;bit[7:0] PID Packet ID: IN=0x69, OUT=0xe1, SETUP=0x2d
	;our PID_IN, PID_OUT, PID_SETUP are defined to use the ehci values
	;so we translate them here into a uhci value
	mov ecx,[esi+12]  
	cmp ecx,PID_OUT
	jz .pidout
	cmp ecx,PID_IN
	jz .pidin
.pidsetup:
	mov al,0x2d
	jmp .writeDword3
.pidin:
	mov al,0x69
	jmp .writeDword3
.pidout:
	mov al,0xe1


.writeDword3:
	;finally write the 3rd dword of TD
	mov [edi+8],eax





	;4th dword of TD  (BufferPointer)
	;************************************
	;this is the address to send/receive data 
	;this could be the request/command/CBW
	;or this is where the device data is returned
	;or this could be the data we are sending to the device
	;or this could be 0 in status transport or the CSW
	;for ehci this pointer must be page aligned
	;because bits[11:0] are reserved for the Current Offset into the page

	mov ebx,[BufferPointer]
	mov [edi+12], ebx


	;the uhci has 4 more dwords making up the TD but they are not used
	mov dword [edi+16],0
	mov dword [edi+20],0
	mov dword [edi+24],0
	mov dword [edi+28],0





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

	;increment BufferPointer
	add [BufferPointer],eax   ;BufferPointer += TDbytes

	;increment where the next TD will be written
	add edi,UHCITDSPACING

	;increment LinkPointer
	add dword [LinkPointer],UHCITDSPACING

	;decrement chainbytecount
	sub dword [chainbytecount],eax   ;chainbytecount -= TDbytes
	;sets ZF if chainbytecount goes to zero
	jnz .buildTDchain           
	;*************end of loop ******************


.done:
	popad
	pop ebp
	retn 4








;***********************************************************************************
;uhci_prepareInterruptTD
;this function is a stripped down and hard coded version of uhci_prepareTDchain
;for low speed usb mouse interrupt IN transactions only
;which needs a single 32 byte TD
;the TD is written to "interruptTD" defined in uhci.s
;we keep this TD seperate so mouse and flash drive transactions
;can be conducted at the same time
;input:none
;return:none
;***************************************************************************


uhci_prepareInterruptTD:

	pushad

	;init edi to address where TD will be written
	mov edi,interruptTD


	;1st dword of TD (LinkPointer)
	;******************************
	mov dword [edi],1  ;terminate, no more TD's



	;2nd dword of TD (Control/Status)
	;***********************************
	mov dword [edi+4],0x4800000  ;low speed, active



	;3rd dword of td  (USB PacketHeader)
	;**********************************

	;bit[31:21] MaxLen
	;we ask for 8 bytes, the mouse report may only be 4 or 5 bytes
	mov eax,7    ;n-1
	shl eax,21
	
	;data toggle  (1,0,1,0...)
	;see Toggle.info for details
	mov ecx,[mousetogglein]    ;get value of toggle
	shl ecx,19
	or eax,ecx
	;now toggle the global variable
	not dword [mousetogglein]   ;flip all the bits
	and dword [mousetogglein],1 ;mask off bit0
	
	;endpoint 
	;must read device endpoint descriptor to get this one
	mov ecx,[MOUSEINENDPOINT]  
	shl ecx,15
	or eax,ecx
	
	;device address on the usb bus
	;0 for control else 2 or 3
	mov ebx,MOUSEADDRESS
	shl ebx,8
	or eax,ebx
	
	;PID: IN=0x69, OUT=0xe1, SETUP=0x2d for low speed uhci
	mov al,0x69  ;interrupt-IN

	;finally write the 3rd dword of TD
	mov [edi+8],eax
	



	;4th dword of TD  (BufferPointer)
	;************************************
	;mouse report 
	;Logitech or Microsoft: bb dx dy dz
	;Manhattan: 01 bb dx dy dz
	mov dword [edi+12], mousereportbuf


.done:
	popad
	ret 






;***********************************************************************************
;uhci_generate_keyboard_TD

;this function builds a single 32 byte TD for usb keyboard interrupt transactions
;using uhci, the TD is written to 0x1003300

;input:none
;return:none
;***************************************************************************

uhci_generate_keyboard_TD:

	pushad

	;init edi to address where TD will be written
	mov edi,0x1003300


	;1st dword of TD (LinkPointer)
	;******************************
	mov dword [edi],1  ;terminate, no more TD's



	;2nd dword of TD (Control/Status)
	;***********************************
	;bit28:27 = error detection = 00 no error limit
	;bit26    = low speed device
	;bit23    = active
	mov dword [edi+4],0x4800000    ;no error limit, low speed, active



	;3rd dword of td  (USB PacketHeader)
	;**********************************

	;bit[31:21] MaxLen
	;we ask for 8 bytes, the keyboard gives an 8 byte report
	mov eax,7    ;n-1
	shl eax,21
	
	;data toggle  (1,0,1,0...)
	;see Toggle.info for details
	mov ecx,[keyboardtogglein]    ;get value of toggle
	shl ecx,19
	or eax,ecx
	;now toggle the global variable
	not dword [keyboardtogglein]   ;flip all the bits
	and dword [keyboardtogglein],1 ;mask off bit0
	
	;endpoint 
	;must read device endpoint descriptor to get this one
	mov ecx,[KEYBOARDINENDPOINT]  
	shl ecx,15
	or eax,ecx
	
	;device address on the usb bus
	;0 for control else 2 or 3
	mov ebx,KEYBOARDADDRESS
	shl ebx,8
	or eax,ebx
	
	;PID: IN=0x69, OUT=0xe1, SETUP=0x2d for low speed uhci
	mov al,0x69  ;interrupt-IN

	;finally write the 3rd dword of TD
	mov [edi+8],eax
	



	;4th dword of TD  (BufferPointer)
	;************************************
	mov dword [edi+12], KEYBOARD_REPORT_BUF


.done:
	popad
	ret 




