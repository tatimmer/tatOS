;tatOS/usb/initehci.s


;init_EHCI_base
;init_EHCI_with_companion
;init_EHCI_with_roothub



;code to setup the ehci usb controller for flash drive transactions under tatos

;the ehci is a high speed usb controller for flash drive
;but it can not handle the low speed mouse directly
;the hardware vendors handle the low speed mouse two ways:
;  1) ehci + companion controllers (usually uhci)
;  2) ehci + root hub
;the companion controllers or the root hub will service the low speed mouse


;we note here a few differances between EHCI and UHCI
;UHCI has a single frame list for all transaction types 
;EHCI has two differant lists:
;	* asynchronous circular link list for control/bulk transactions
;	* frame list for interrupt transactions
;Queue Heads
;	* UHCI are a simple pair of dwords 
;	* EHCI are a 68 byte structure
;	* EHCI queue heads contain device/endpoint specific data
;Transfer descriptors for both uhci and ehci are 32 bytes 
;but the bitfields are organized differantly
;ehci is memory mapped, uhci uses port i/o 

;Purpose:
;functions to init the usb EHCI controller
;Get the base address needed for usb transactions. 
;Also resets the usb controller and sets up the frame list and 
;queue heads for usbmass/bulk and usbmouse/interrupt transactions

;Problems:
;if you have problems with this code try the following:
;* disconnect all attached usb devices especially low speed (mouse)
;* after bootup remove the boot flash drive before ehci controller init
;* use usb ports on the back of your desktop not the front
;  ports on the front are connected to the controller thru a "hub" which is unsupported
;* some ports may be hardwired to ohci controllers which are unsupported so try others
;* consult your datasheet, some devices have specific pci config registers
;* use hardware that provides datasheets like Intel,AMD,Via, not nVidia

;the bus:dev:fun pci config address (dword) of the usb controllers is stored at:
;0x5d8, UHCI companion #1  (UHCIBUSDEVFUNCOM1)
;0x5dc, UHCI companion #2  (UHCIBUSDEVFUNCOM2)
;EHCIBUSDEVFUN, EHCI controller
;UHCIBUSDEVFUN, UHCI primary controller



;*******************************
;          DATA
;*******************************
usbinitstr0 db 'EHCI USB Controller Init',0
usbinitstr1 db 'EHCI Buss Master Enable',0
usbinitstr2 db 'EHCI CTRLDSSEGMENT Setting hi 32bits of 64 bit address to 0',0
usbinitstr5 db 'EHCI Saving USBBASE MemoryBaseAddress',0
usbinitstr7 db 'EHCI Capabilities Registers Length',0
usbinitstr13 db 'EHCI Legacy Extended Capability (bios-os control)',0
usbinitstr15 db 'EHCI HCCPARAMS Capability Parameters',0
usbinitstr24 db 'EHCI CONFIGFLAG 1=all ports route to ehci',0 
usbinitstr28 db 'EHCI Looping for controller reset',0
usbinitstr29 db 'EHCI Controller reset complete',0
usbinitstr31 db 'EHCI Testing for companion controllers',0
usbinitstr32 db 'EHCI Setting up Asynchronous list',0
usbinitstr33 db 'EHCI Setting up Periodic List',0
usbinitstr34 db 'EHCI Halting Controller',0
usbinitstr35 db 'EHCI Disable Interrupts',0
usbinitstr36 db 'EHCI Enable the Asynchronous & Periodic List',0
usbinitstr37 db 'EHCI Start Controller',0
usbinitstr40 db 'EHCI Done Controller Init',0
usbinitstr41 db 'testing port0 for low speed device',0
usbinitstr42 db 'testing port1 for low speed device',0
usbinitstr43 db 'testing port2 for low speed device',0
usbinitstr44 db 'testing port3 for low speed device',0
usbinitstr45 db 'releasing ownership of ehci port to companion controller',0
usbinitstr46 db 'no low speed device found-no release port ownership-no init uhci',0
usbinitstr47 db 'init ehci with root hub',0
usbinitstr48 db 'resetting upstream port of ehci with root hub',0

usbcompstr1 db 'bus:dev:fun of UHCI Companion is invalid pci device',0
usbcompstr2 db 'found valid bus:dev:fun for UHCI companion',0
usbcompstr3 db 'found valid UHCI companion',0
usbcompstr4 db 'failed to find valid UHCI companion',0




;**************************************************************
;init_EHCI_base
;this is base code to 
;prepare the ehci controller for usb transactions
;this code should work for both
;ehci+companion controllers and 
;ehci+root hub
;input: 
;the pci config address [EHCIBUSDEVFUN] must already be stored
;return:none
;**************************************************************


init_EHCI_base:


	STDCALL usbinitstr0,putscroll 


	;PCI Config: Command Register - Buss Master Enable
	;set bus master enable and memory space enable
	;this comes from the Via ehci controller datasheet
	;bit[2]=bus master enable/disable
	;bit[1]=memory space enable/disable
	;bit[0]=i/0 space enable/disable
	;I cant guarrantee this will work for all other brands
	;it seems to work ok on intel
	STDCALL usbinitstr1,putscroll  
	mov eax,[EHCIBUSDEVFUN]  
	mov ebx,4  ;register/offset 
	call pciReadDword

	;set bus master enable and memory space enable bits
	or eax,110b  

	;write new value to the pci Config Command Register
	mov ecx,eax
	mov eax,[EHCIBUSDEVFUN]  
	mov ebx,4  ;register/offset 
	call pciWriteDword

	;if you do not set the memory space enable bit
	;then any attempt to read the Capability registers below will result in ffffffff



	

	;PCI Config: Memory Base Address (USBBASE) 
	STDCALL usbinitstr5,putscroll  
	mov eax,[EHCIBUSDEVFUN]
	mov ebx,0x10  ;10=address offset for MemoryBaseAddress
	call pciReadDword

	;base address is bits 31:8
	;mask off bits 2:1 which indicate the address "type"
	and eax,0xffffff00

	;save the USBBASE of EHCI
	;this is also the start of the ehci capability registers
	;the capability registers include: CAPLENGTH, HCIVERSION, HCSPARAMS
	mov [EHCIUSBBASE],eax  

	;Via VT6212 returns 0xf4008000 (this is page aligned)
	;the bios should give us a huge virtual memory address
	;thats outside the range of real memory




	;EHCI Capability Registers
	;***************************
	;00 = capabilities register length
	;04-07 = structural parameters
	;08-0b = capability parameters

	;CAPLENGTH - Capabilities Registers Length (offset 00)
	STDCALL usbinitstr7,putscroll  
	mov esi,[EHCIUSBBASE]
	mov al,[esi+0]
	and eax,0xff

	;compute and save the start of the operational registers
	;the operational registers begin after the capability registers
	;operational registers are read/write dword access only
	;the operational registers are: USBCMD, USBSTS, USBINTR, FRINDEX,
	;CTRLSSEGMENT, PERIODICLISTBASE, ASYNCLISTADDR, CONFIGFLAG, PORTSC
	add esi,eax
	mov [EHCIOPERBASE],esi




	;HCCPARAMS- Get the Capability Parameters (offset 08)
	;bit1 is the Programmable Frame List Flag
	;if bit1=0 then the periodic list is fixed at 1024 elements
	;our Acer laptop gives a value of 0
	;the Via pci addon card gives a value of 1
	;tatOS will support a frame list of 1024 elements for the periodic list
	STDCALL usbinitstr15,putscroll  
	mov esi,[EHCIUSBBASE]
	mov eax,[esi+8]

	;save EECP Extended Capabilities Pointer
	;this is needed to access USBLEGSUP & USBLEGCTLSTS registers in pci config space
	mov ebx,eax
	shr ebx,8
	and ebx,0xff
	mov [eecp],ebx ;save eecp
	



	;now that we have eecp we can take ownership of ehci from the bios
	;PCI Config: USBLEGSUP Legacy Support EHCI Extended Capability Register
	;this tells if bios or os gets control of ehci
	;bit24 must be set and bit16 must be clear for os to have control
	;*******************************************************************
	;2do: tom bits 15:8 are offset to next pointer so more work to do
	;also if bios has already yielded, do not automatically set this
	;*******************************************************************
	STDCALL usbinitstr13,putscroll  
	mov eax,[EHCIBUSDEVFUN] 
	mov ebx,[eecp]  ;register offset in pci config space   
	call pciReadDword

	;see if bios owns the ehci
	bt eax,16  ;if bit16 is set then bios owns ehci 
	jnc .doneUSBLEGSUP

	;set bit24 to tell bios that the OS wants control of ehci
	or eax,0x1000000

	;write is back
	mov ecx,eax
	mov eax,[EHCIBUSDEVFUN] 
	mov ebx,[eecp]  ;register/offset 
	call pciWriteDword

	;pause 
	mov ebx,50
	call sleep
.doneUSBLEGSUP:





	;PCI Config: USBLEGCTLSTS Legacy Support Control/Status Register
	;this register controls all the SMI's (System Management Interrupts)
	;linux reportedly forces control of ehci from the bios and disables
	;all SMI's. Most of the bits of this register are read only or shadow
	;bits of USBSTS. 
	;mov eax,[EHCIBUSDEVFUN]
	;mov ebx,[eecp] 
	;add ebx,4
	;mov ecx,0
	;call pciWriteDword

	



	
	;EHCI Operational Registers
	;***************************
	;we saved the start of oper regs at EHCIOPERBASE
	;00 = USBCMD  command 
	;04 = USBSTS  status
	;08 = USBINTR interrupt enable
	;0c = USB2 frame index
	;10 = 4gb segment selector
	;14 = frame list base address
	;18 = next asynchronous list address
	;1c-3f reserved
	;40 = configure flag register
	;44 = PORTSC(0) status/control
	;48 = PORTSC(1) status/control
	;4c = PORTSC(2) status/control
	;50 = PORTSC(3) status/control
	


	;stop ehci
	;dont try to reset or change register values of a running controller
	;I have found some controllers are running at this point and some are not
	STDCALL usbinitstr34,putscroll  
	mov esi,[EHCIOPERBASE]
	mov eax,[esi+0]
	and eax,0xfffffffe ;clear bit0
	mov [esi+0],eax    ;write it back
	;make sure ehci is HCHalted (bit is bit12 of USBSTS)
	mov esi,[EHCIOPERBASE]    
.stillrunning:
	mov eax,[esi+4]    ;read USBSTS
	bt eax,12
	jnc .stillrunning



	;Interrupt Threshold
	;program how often the ehci can issue interrupts
	;tatOS does not actually use the interrupt at all so why bother ?
	



	;reset EHCI 
	;the reset bit is set to zero by the controller when reset is complete
	;the controller must be halted (HCHalted bit of USBSTS = 1)before resetting
	;the reset causes port ownership to revert to companion controllers
	STDCALL usbinitstr28,putscroll  
	mov esi,[EHCIOPERBASE]
	mov eax,[esi+0]   ;read current value
	or eax,10b        ;HCRESET
	mov [esi+0],eax   ;write it back

.EHCI_in_reset:
	;loop until reset bit is set to zero by the controller
	mov eax,[esi+0]   ;read current value
	bt eax,1
	jc .EHCI_in_reset

	STDCALL usbinitstr29,putscroll  





	;USBINTR-Usb Interrupt Enable Register
	mov esi,[EHCIOPERBASE]
	mov dword [esi+08h],0  ;disable all interrupts
	STDCALL usbinitstr35,putscroll  


	
	;CTRLDSSEGMENT
	;Control Data Structure Segment Register (64 addressing)
	;if bit0 of HCCPARAMS=0 then 32bit addressing is default and this write will fail
	;otherwise controllers likes Intels ICHn which uses 64 bit addressing
	;use the value of this register as the hi 32bits of a 64bit address
	STDCALL usbinitstr2,putscroll  
	mov esi,[EHCIOPERBASE]
	mov dword [esi+10h],0






	;PERIODIC Frame List 
	;*********************
	;setup the periodic frame list
	;generate one QH to conduct mouse interrupt tranfers using this frame list

	;Smask = 01
	;a non-zero Smask value is required for interrupt transfers
	;Smask=01 means 00000001b or the mouse interrupt occurs at the 
	;beginning of the frame (each frame is divided into 8 pieces) 
	;each of the 8 bits in Smask represents 1/8th or a microframe of time
	;and completion of the interrupt wont cross a frame boundary with a value of 1 
	;see section 4.12.2 and figure 4-17 of USB 2.0 spec
	;this also means you dont have to deal with FSTN's (Frame Span Traversal Node)

	;Cmask = 0x1c
	;page 94 of the usb 2.0 spec suggests this value for case=1 of fig 4-17
	;dont know any more, it works
	;frankly I think the ehci authors should have hid Smask & Cmask all in the hardware
	;uhci was alot easier to deal with
	;the so called "universal" series bus could hide more functionality in the hdwre
	;and be a little less universal 

	;we use a frame list of 1024 pointers 
	;if you write a valid QH address to the first entry in the list 
	;and mark all the others as invalid 01 
	;then the mouse response is very slow 
	;you get a response about once every second 

	;generate one QH for mouse interrupt xfers at 0x1006000
	;this QH will include the PortNumber & HubAddress where the mouse is plugged in
	;the Next qTD pointer must be marked terminate for now 
	;so the ehci does not execute any usb transaction when we enable ehci 

	STDCALL usbinitstr33,putscroll  

	;QH 1st dword-Horiz Link Pointer
	mov dword [0x1006000],1    ;QH horiz link ptr is invalid

	;QH 2nd dword-Endpoint Characteristics
	;bit31:28  NAK reload counter (we seem to like the value 5 here)
	;bit27     Control Endpoint Flag (set to 0 if not control endpoint)
	;bit26:16  MaxPacketLength  (set to MOUSE_WMAXPACKETSIZE in initmouse) 
	;bit15     Head of Reclaim list  (use 0 for periodic)
	;bit14     Data Toggle (1=initial data toggle comes from incoming TD)
	;bit13:12  endpoint speed (1=lo speed  endpoint)
	;bit11:8   endpoint number (set to MOUSEINENDPOINT in initmouse)
	;bit7      inactive on next transaction (init to 0)
	;bit6:0    Device Address (hardcode to MOUSEADDRESS=3 see usb.s)
	mov dword [0x1006004],0x50005003  
	;mov dword [0x1006004],0x50065103 ;hard code maxpacket=06, endpointnum=1, mouseaddress=3

	;QH 3rd dword - Endpoint Capabilities
	;bits31:30 hi bandwidth Pipe Multiplier (we use 1.0, Linux #define QH_MULT 0xc0000000)
	;bits29:23 port number where mouse is plugged in (set to mouse_hubportnum in initmouse)
	;bits22:16 HUBADDRESS is hard coded here as 4 see usb.s
	;bits15:8  Split Transaction Mask  Cmask (see notes above, we use 0x1c)
	;bits7:0   Interrupt Schedule Mask Smask (see notes above, we use 0x01)
;	mov dword [0x1006008],0x40041c01    ;MULT=1
	mov dword [0x1006008],0xc0041c01    ;MULT=3
	
	;QH overlay 4th, 5th, 6th, 7th, 8th, 9th, 10th, 11th, 12th dwords
	;the ehci overwrites this area but you must init Next qTD to 1 or a valid pointer
	mov dword [0x100600c],0  ;4th dword Current qTD Pointer 
	mov dword [0x1006010],1  ;5th dword Next qTD Pointer    (1=terminate)
	mov dword [0x1006014],0  
	mov dword [0x1006018],0
	mov dword [0x100601c],0
	mov dword [0x1006020],0
	mov dword [0x1006024],0
	mov dword [0x1006028],0
	mov dword [0x100602c],0

	;dwords 13-17 of QH
	;if your controller uses 64bit addressing like the Intel ICHn
	;then you need to specify the upper 32bits here
	mov dword [0x1006030],0  ;Extended Buffer Pointer Page 0
	mov dword [0x1006034],0
	mov dword [0x1006038],0
	mov dword [0x100603c],0
	mov dword [0x1006040],0  ;Extended Buffer Pointer Page 4



	;generate a Periodic frame list of 1024 QH addresses 
	;this periodic list setup is similar to what we did for uhci
	;every address in this list is 0x1006002 our mouse interrupt QH
	;this gives us maximum response time for the mouse
	;tatOS does not support usb sound so we dont need the periodic list for anything else
	;we reserve 0x1000 bytes starting at 0x1002000 for this periodic list
	;you can also mark every item in this list as 01 for invalid
	;you can mark every item in the list as 01 except the first item
	;and this gives you a mouse response time of ~1second
	;or you can mark every 8th item in the list with the mouse QH to speed this up
	;but we just take over the entire list for the mouse to make it fast
	cld
	mov ecx,1024       ;qty dwords written
	mov eax,0x1006002  ;write our QH address into the frame list, 2=QH typ 
	mov edi,0x1002000  ;starting address of periodic frame list
	rep stosd


	;write to PERIODICLISTBASE the starting address of our frame list
	;so ehci knows where this list is in memory
	mov esi,[EHCIOPERBASE]
	mov dword [esi+0x14],0x1002000  ;0x1002000 is start of our periodic frame list


	;to enable the periodic list see line ~750 below







	;ASYNCLISTADDR asynchronous list
	;***********************************
	;set up our asynchronous list of queue heads for flash drive 
	;the asynchronous list is a circular link list of queue heads (QH) 
	;for control and bulk xfers
	;you need one QH for each endpoint
	;the asynchronous list plays 2nd fiddle to the periodic list
	;the reason for having seperate QH's for hub and flash control xfer
	;is because after SetAddress, the device address needs to be stored in the QH

	;note the more queue heads added into the list
	;the more problems there will be with timing of the initflash sequence
	;the VIA vt6212 pci addon card ehci does not like more than 3 QH's in the list

	;the recommended way in the ehci spec is to keep the list small
	;and add or remove QH's from the list as needed
	;I am trying to avoid the complexity of this

	;this list has 5 Qh's now
	;QH1 = hub control xfer
	;QH2 = Flash control xfer
	;QH3 = Mouse control xfer
	;QH4 = Flash bulk IN
	;QH5 = Flash bulk OUT


	;note there are %defines in usb.s for these QH addresses
	;so dont just go and reorder things willy nilly tom !
;%define HUB_CONTROL_QH               0x1005300
;%define FLASH_CONTROL_QH             0x1005400
;%define MOUSE_CONTROL_QH             0x1005500
;%define FLASH_BULKIN_QH              0x1005600
;%define FLASH_BULKOUT_QH             0x1005700



	STDCALL usbinitstr32,putscroll  

	;write address of QH(1) to ASYNCLISTADDR
	mov esi,[EHCIOPERBASE]
	mov dword [esi+18h],0x1005300





	;QH(1)  hub control transfers  HUB_CONTROL_QH = 0x1005300
	;**************************************************************

	;QH 1st dword-Horiz Link Pointer
	mov dword [0x1005300],0x1005402  ;points to 0x1005400, QH, valid pointer

	;QH 2nd dword-Endpoint Characteristics
	;bit31:28  NAK reload counter (0xf gives us the max qty of retries on nak)
	;bit27     Control Endpoint Flag (set to 0 for hi speed device)
	;bit26:16  MaxPacketLength  (0x40 for flash drive control transfer)
	;bit15     Head of Reclaim list  (1=this QH is head of list)
	;bit14     Data Toggle (1=initial data toggle comes from incoming TD)
	;bit13:12  endpoint speed (2=hi speed  endpoint)
	;bit11:8   endpoint number (0 for ctrl xfer)
	;bit7      inactive on next transaction (set for periodic schedule only)
	;bit6:0    Device Address (0 for ctrl xfer before SetAddress)
	mov dword [0x1005304],0x5040e000 

	;QH 3rd dword - Endpoint Capabilities
	;bit31:30  Hi Bandwidth Pipe Multiplier Mult (1 transaction per microframe)
	;bits29:23 PortNum (low speed device id on usb hub, use 0 for flash )
	;bits22:16 HubAddr (usb hub address if low speed device attached, use 0 for flash)
	;bits15:8  C-Mask (low speed device split transaction periodic list, use 0 for flash)
	;bits0:7   S-Mask (use 0 for asynchronous list)
	mov dword [0x1005308],0x40000000
	
	;QH overlay 4th, 5th, 6th, 7th, 8th, 9th, 10th, 11th, 12th dwords
	;the ehci overwrites this area but you must init Next qTD to 1 or a valid pointer
	mov dword [0x100530c],0  ;4th dword Current qTD Pointer 
	mov dword [0x1005310],1  ;5th dword Next qTD Pointer    (1=terminate)
	mov dword [0x1005314],0  
	mov dword [0x1005318],0
	mov dword [0x100531c],0
	mov dword [0x1005320],0
	mov dword [0x1005324],0
	mov dword [0x1005328],0
	mov dword [0x100532c],0

	;dwords 13-17 of QH
	;if your controller uses 64bit addressing like the Intel ICHn
	;then you need to specify the upper 32bits here
	mov dword [0x1005330],0  ;Extended Buffer Pointer Page 0
	mov dword [0x1005334],0
	mov dword [0x1005338],0
	mov dword [0x100533c],0
	mov dword [0x1005340],0  ;Extended Buffer Pointer Page 4



	;QH(2)  Flash control transfers  FLASH_CONTROL_QH = 0x1005400
	;**************************************************************

	;tom note this code is also repeated in part in initflashehci_common.s
	;so if you make changes here you must also make changes their !!!

	;QH 1st dword-Horiz Link Pointer
	mov dword [0x1005400],0x1005502  ;points to 0x1005500, QH, valid pointer

	;QH 2nd dword-Endpoint Characteristics
	;bit31:28  NAK reload counter (0xf gives us the max qty of retries on nak)
	;bit27     Control Endpoint Flag (set to 0 for hi speed device)
	;bit26:16  MaxPacketLength  (0x40 for flash drive control transfer)
	;bit15     Head of Reclaim list  (1=this QH is head of list)
	;bit14     Data Toggle (1=initial data toggle comes from incoming TD)
	;bit13:12  endpoint speed (2=hi speed  endpoint)
	;bit11:8   endpoint number (0 for ctrl xfer)
	;bit7      inactive on next transaction (set for periodic schedule only)
	;bit6:0    Device Address (0 for ctrl xfer before SetAddress)
	mov dword [0x1005404],0x50406000   ;same as QH1 but not head-of-list

	;QH 3rd dword - Endpoint Capabilities
	;bit31:30  Hi Bandwidth Pipe Multiplier Mult (1 transaction per microframe)
	;bits29:23 PortNum (low speed device id on usb hub, use 0 for flash )
	;bits22:16 HubAddr (usb hub address if low speed device attached, use 0 for flash)
	;bits15:8  C-Mask (low speed device split transaction periodic list, use 0 for flash)
	;bits0:7   S-Mask (use 0 for asynchronous list)
	mov dword [0x1005408],0x40000000
	
	;QH overlay 4th, 5th, 6th, 7th, 8th, 9th, 10th, 11th, 12th dwords
	;the ehci overwrites this area but you must init Next qTD to 1 or a valid pointer
	mov dword [0x100540c],0  ;4th dword Current qTD Pointer 
	mov dword [0x1005410],1  ;5th dword Next qTD Pointer    (1=terminate)
	mov dword [0x1005414],0  
	mov dword [0x1005418],0
	mov dword [0x100541c],0
	mov dword [0x1005420],0
	mov dword [0x1005424],0
	mov dword [0x1005428],0
	mov dword [0x100542c],0

	;dwords 13-17 of QH
	;if your controller uses 64bit addressing like the Intel ICHn
	;then you need to specify the upper 32bits here
	mov dword [0x1005430],0  ;Extended Buffer Pointer Page 0
	mov dword [0x1005434],0
	mov dword [0x1005438],0
	mov dword [0x100543c],0
	mov dword [0x1005440],0  ;Extended Buffer Pointer Page 4





	;QH(3)  Mouse control transfers MOUSE_CONTROL_QH = 0x1005500
	;********************************************************************
	;QH 1st dword-Horiz Link Pointer
	mov dword [0x1005500],0x1005602  ;points to 0x1005500, QH, valid pointer

	;QH 2nd dword-Endpoint Characteristics
	;bit31:28  NAK reload counter (0xf gives us the max qty of retries on nak)
	;bit27     Control Endpoint Flag (set to 1 for lo speed device control xfer)
	;bit26:16  MaxPacketLength  (0x08 for mouse control transfer, note 0x40 is wrong!)
	;bit15     Head of Reclaim list  (0=this QH is not head of list)
	;bit14     Data Toggle (1=initial data toggle comes from incoming qTD)
	;bit13:12  endpoint speed EPS (1=lo speed  endpoint)
	;bit11:8   endpoint number (0 for ctrl xfer)
	;bit7      inactive on next transaction (set for periodic schedule only)
	;bit6:0    Device Address (0 for ctrl xfer before SetAddress)
	mov dword [0x1005504],0x58085000   

	;QH 3rd dword - Endpoint Capabilities
	;bit31:30  Hi Bandwidth Pipe Multiplier Mult (1 transaction per microframe)
	;bits29:23 PortNum (inithub.s writes value here)
	;bits22:16 HubAddr (our HUBADDRESS=4)
	;bits15:8  C-Mask (used for mouse interrupt in periodic list)
	;bits0:7   S-Mask (used for mouse interrupt in periodic list)
	mov dword [0x1005508],0x40040000
	
	;QH overlay 4th, 5th, 6th, 7th, 8th, 9th, 10th, 11th, 12th dwords
	;the ehci overwrites this area but you must init Next qTD to 1 or a valid pointer
	mov dword [0x100550c],0  ;4th dword Current qTD Pointer 
	mov dword [0x1005510],1  ;5th dword Next qTD Pointer    (1=terminate)
	mov dword [0x1005514],0  
	mov dword [0x1005518],0
	mov dword [0x100551c],0
	mov dword [0x1005520],0
	mov dword [0x1005524],0
	mov dword [0x1005528],0
	mov dword [0x100552c],0

	;dwords 13-17 of QH
	;if your controller uses 64bit addressing like the Intel ICHn
	;then you need to specify the upper 32bits here
	mov dword [0x1005530],0  ;Extended Buffer Pointer Page 0
	mov dword [0x1005534],0
	mov dword [0x1005538],0
	mov dword [0x100553c],0
	mov dword [0x1005540],0  ;Extended Buffer Pointer Page 4





	;QH(4)  Flash bulk IN/read transfers FLASH_BULKIN_QH = 0x1005600
	;*****************************************************************

	;QH 1st dword-Horiz Link Pointer
	mov dword [0x1005600],0x1005702  ;points to 0x1005500, QH, valid pointer

	;QH 2nd dword-Endpoint Characteristics
	;bit31:28  NAK reload counter (0xf gives us the max qty of retries on nak)
	;bit27     Control Endpoint Flag (set to 0 for hi speed device)
	;bit26:16  MaxPacketLength  (0x200 for flash drive bulk transfer)
	;bit15     Head of Reclaim list  (0=not head of list)
	;bit14     Data Toggle (1=dt from qTD)
	;bit13:12  endpoint speed (2=hi speed  endpoint)
	;bit11:8   endpoint number (initflash writes BULKEPIN to this QH after SetAddress)
	;bit7      inactive on next transaction (set for periodic schedule only)
	;bit6:0    Device Address (initflash writes BULKADDRESS to this QH after SetAddress)
	mov dword [0x1005604],0x52006000  


	;QH 3rd dword - Endpoint Capabilities
	;see QH(1) above for explanation of what 0x40000000 means
	mov dword [0x1005608],0x40000000
	
	;QH overlay 4th, 5th, 6th, 7th, 8th, 9th, 10th, 11th, 12th dwords
	;the ehci overwrites this area but you must init Next qTD to 1 or a valid pointer
	mov dword [0x100560c],0  ;4th dword Current qTD Pointer 
	mov dword [0x1005610],1  ;5th dword Next qTD Pointer    (1=terminate)
	mov dword [0x1005614],0  
	mov dword [0x1005618],0
	mov dword [0x100561c],0
	mov dword [0x1005620],0
	mov dword [0x1005624],0
	mov dword [0x1005628],0
	mov dword [0x100562c],0

	;dwords 13-17 of QH
	;if your controller uses 64bit addressing like the Intel ICHn
	;then you need to specify the upper 32bits here
	mov dword [0x1005630],0  ;Extended Buffer Pointer Page 0
	mov dword [0x1005634],0
	mov dword [0x1005638],0
	mov dword [0x100563c],0
	mov dword [0x1005640],0  ;Extended Buffer Pointer Page 4




	;QH(4)  Flash bulk OUT/write transfers FLASH_BULKOUT_QH = 0x1005700
	;********************************************************************

	;QH 1st dword-Horiz Link Pointer
	mov dword [0x1005700],0x1005302  ;points back to start of circular list

	;QH 2nd dword-Endpoint Characteristics
	mov dword [0x1005704],0x52006000  ;0x200 max packet, dt from qTD, not head-of-list

	;QH 3rd dword - Endpoint Capabilities
	mov dword [0x1005708],0x40000000
	
	;QH overlay 4th, 5th, 6th, 7th, 8th, 9th, 10th, 11th, 12th dwords
	;the ehci overwrites this area but you must init Next qTD to 1 or a valid pointer
	mov dword [0x100570c],0  ;4th dword Current qTD Pointer 
	mov dword [0x1005710],1  ;5th dword Next qTD Pointer    (1=terminate)
	mov dword [0x1005714],0  
	mov dword [0x1005718],0
	mov dword [0x100571c],0
	mov dword [0x1005720],0
	mov dword [0x1005724],0
	mov dword [0x1005728],0
	mov dword [0x100572c],0

	;dwords 13-17 of QH
	;if your controller uses 64bit addressing like the Intel ICHn
	;then you need to specify the upper 32bits here
	mov dword [0x1005730],0  ;Extended Buffer Pointer Page 0
	mov dword [0x1005734],0
	mov dword [0x1005738],0
	mov dword [0x100573c],0
	mov dword [0x1005740],0  ;Extended Buffer Pointer Page 4



	;note: QH 0x1006000 is reserved for the periodic list
	;see /doc/memorymap and above periodic list initialization







	;CONFIGFLAG
	;00=port routing to classic controller
	;01=port routing to EHCI controller
	;note on disconnect all ports revert to ehci
	STDCALL usbinitstr24,putscroll  
	mov esi,[EHCIOPERBASE]
	mov eax,[esi+40h]
	or eax,1          ;set bit0, all ports belong to EHCI
	mov [esi+40h],eax

	mov ebx,250
	call sleep





	;enable the async list & the periodic list
	STDCALL usbinitstr36,putscroll  
	mov esi,[EHCIOPERBASE]
	mov eax,[esi+0]   ;read USBCMD which is offset 0
	or eax,10000b     ;set bit4 to enable periodic list for mouse interrupt xfer
	or eax,100000b    ;set bit5 to enable async list for bulk/control xfer
	;bits3:2 set the Frame list size to 1024, 512, or 256
	;the Acer laptop does not support a programmable list (HCCPARAMS bit1=0)
	;so tatOS will by default just use a 1024 list
	mov [esi+0],eax   ;write it back



	;start the controller
	STDCALL usbinitstr37,putscroll  
	mov esi,[EHCIOPERBASE]
	mov eax,[esi+0]
	or eax,1       ;set bit0 to start
	mov [esi+0],eax

	mov ebx,500
	call sleep


	;at this point Via USBCMD reports 0x80021 = run, async enable
	;end of setting up the EHCI controller

	ret




	


;*********************************************************************
;init_EHCI_with_companion
;init the EHCI 
;release port ownership of low speed device to companion controller
;init both UHCI companion controllers
;input: none
;return:none
;**********************************************************************

init_EHCI_with_companion:


	;form a pci_config_address for EHCI using the 
	;bus:dev:fun values pre-assembled into tatOS from tatOS.config
	mov bl,EHCI_WITH_COMPANION_BUS
	mov cl,EHCI_WITH_COMPANION_DEV
	mov dl,EHCI_WITH_COMPANION_FUN
	call build_pci_config_address  ;return value in eax
	mov [EHCIBUSDEVFUN],eax

	call init_EHCI_base


	;test for low speed mouse on port 0
	STDCALL usbinitstr41,putscroll
	mov eax,0
	call ehci_portlowspeed  
	;zf is set if low speed mouse attached to this port
	jz near .releaseOwnership

	;test for low speed mouse on port 1
	STDCALL usbinitstr42,putscroll
	mov eax,1
	call ehci_portlowspeed  
	;zf is set if low speed mouse attached to this port
	jz near .releaseOwnership

	;test for low speed mouse on port 2
	STDCALL usbinitstr43,putscroll
	mov eax,2
	call ehci_portlowspeed  
	;zf is set if low speed mouse attached to this port
	jz near .releaseOwnership

	;test for low speed mouse on port 3
	STDCALL usbinitstr44,putscroll
	mov eax,3
	call ehci_portlowspeed  
	;zf is set if low speed mouse attached to this port
	jz .releaseOwnership

	;if we got here we failed to find any low speed device on any ehci port
	;will not release port ownership to UHCI
	;will not even init the UHCI controllers
	STDCALL usbinitstr46,putscroll  
	jmp .done


.releaseOwnership:
	;Release ownership of port to companion controller
	;found low speed device attached
	;eax=port number
	STDCALL usbinitstr45,putscroll
	mov esi,[EHCIOPERBASE]  ;get start of ehci operational regs
	mov edi,[esi+44h+eax*4] ;read PORTSC=1 (ports are 44h, 48h, 4ch, 50h)
	or edi,10000000000000b  ;set bit13 port owner = companion controller
	mov [esi+44h+eax*4],edi ;write it back

.doneReleaseOwnership:



	;init UHCI companion controllers
	;we dont know which companion controls the mouse port
	;so we just init both companion controllers

	;init UHCI companion 1
	;run pci bus scan and manually edit tatOS.config
	;to store the BUS/DEV/FUN constants for the companion controllers
	mov bl,EHCI_COMPANION_UHCI_BUS_1
	mov cl,EHCI_COMPANION_UHCI_DEV_1
	mov dl,EHCI_COMPANION_UHCI_FUN_1
	call build_pci_config_address  ;return value in eax
	mov [UHCIBUSDEVFUNCOM1],eax
	STDCALL usbcen5,putscroll
	;eax=pci_config_address
	call initUHCI

	;init UHCI companion 2
	mov bl,EHCI_COMPANION_UHCI_BUS_2
	mov cl,EHCI_COMPANION_UHCI_DEV_2
	mov dl,EHCI_COMPANION_UHCI_FUN_2
	call build_pci_config_address  ;return value in eax
	mov [UHCIBUSDEVFUNCOM2],eax
	STDCALL usbcen6,putscroll
	;eax=pci_config_address
	call initUHCI


.done:
	STDCALL usbinitstr40,putscroll  
	STDCALL pressanykeytocontinue,putscroll  
	call getc
	ret




;******************************************************
;init_EHCI_with_roothub
;this is the ehci controller found on my asus laptop
;intel DID=1e2dh & 1e26h
;it has two ehci controllers, each with a "root hub"
;each controller has 1 upstream port and
;may have up to 8 down stream ports although
;my laptop has only a total of 3 usb ports
;input:none
;return:
;*****************************************************

init_EHCI_with_roothub:

	STDCALL usbinitstr47,putscroll 

	;tatOS.config must contain these defines EHCI_WITH...
	mov bl,EHCI_WITH_ROOTHUB_BUS
	mov cl,EHCI_WITH_ROOTHUB_DEV
	mov dl,EHCI_WITH_ROOTHUB_FUN
	call build_pci_config_address  ;return value in eax
	mov [EHCIBUSDEVFUN],eax

	call init_EHCI_base


	;reset the (internal) upstream port of ehci with root hub
	;we are not resetting the down stream ports (where devices connect)
	;usb hub class commands must be used to reset down stream ports
	STDCALL usbinitstr48,putscroll  
	mov eax,0  ;port=0, port 1 is a debug port, port 2 is a redirect port ??
	call ehci_portreset



	;now we need usb hub class commands to configure the hub
	;and get status of the downstream ports

	call inithub


	


.done:
	STDCALL usbinitstr40,putscroll  
	STDCALL pressanykeytocontinue,putscroll  
	call getc
	ret





