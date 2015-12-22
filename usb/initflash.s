;tatOS/usb/initflash.s
;May 2015



;initflash


;code to prepare a usb flash drive for read/write
;get the flash drive usb descriptors
;do SetAddress, SetConfiguration etc...

;suitable for use with:
;0) usb 1.0: the old uhci with only 2 usb root ports on back of my desktop
;1) usb 2.0: ehci having uhci companion controllers (Via pci addon card)
;2) usb 2.0: ehci with root hub  (my Acer laptop running windows 7)

;see tatOS.config which requires you to set the USBCONTROLLERTYPE
;and then reassemble

;prior to calling this function the ehci usb controller must be setup
;including populating the ehci async list

;if any transfer descriptor TD fails we jump back to reset the port and try again
;usually there is success the first time thru but sometimes we have to reset the port
;a second time. If a flash drive endpoint halts, then you must reinit the usb controller
;and try init flash again. It usually always passes the 2nd time.

;we store the various usbmass descriptors
;(device,condiguration,interface,endpoint)
;starting at 0x5000
;see /doc/memorymap for details

;GetMaxLun
;we dont support this command
;we assume the device (pendrive) does not support multiple luns
;the usbmass spec states a device that does not 
;support multiple luns may stall this command
;all our SCSI CBW use bCBWLUN=0

;Bulk Only Mass Storage Reset is also unsupported
;I experimented with this a couple years ago and it didnt have the desired affect
;if you have a failed read10/write10 just reinit the controller and flash

;the ehci driver now uses all 5 page pointers for maximum data transfer rates
;and this has also increased reliability greatly. 

;this code will only handle one hi speed device plugged into a port
;if there is more than 1 hi speed device plugged in there will be problems


mpdstr0 db 'initflash with  ehci & uhci companions',0
mpdstr1 db 'pausing 5 seconds',0
mpdstr2 db 'initflash with uhci',0
mpdstr8 db 'Decrementing port number',0
mpdstr10 db 'Check for device connect',0
mpdstr11 db 'Check for low speed device',0
mpdstr13 db 'Port Reset',0
mpdstr29 db 'initflash usb transaction failure',0
mpdstr26 db 'Low Speed device attached',0
mpdstr28 db 'endpoint has halted - initflash failed - reinit ehci and flash',0
mpdstr25 db 'No device attached to port',0
mpdstr27 db 'Fatal-All ports have been checked',0

fdstr0 db 'initflash common code',0
fdstr1 db 'USB device is not 0x08 mass storage class',0
fdstr2 db 'USB device subclass is not 0x06 for SCSI commands',0
fdstr3 db 'USB device protocol is not 0x50 bulk-only transport',0
fdstr4 db 'initflash: error EPin=0',0
fdstr5 db 'initflash: error EPout=0',0
fdstr6 db 'USB device has more than 1 interface',0
fdstr7 db 'Endpoint wMaxPacketSize',0
fdstr8 db 'Get Device Descriptor',0
fdstr9 db 'Get Configuration/Interface/Endpoint Descriptors',0
fdstr10 db 'Set Address',0
fdstr11 db 'Set Configuration',0
fdstr12 db 'Inquiry',0
fdstr13 db 'TestUnitReady',0
fdstr14 db 'RequestSense',0
fdstr15 db 'ReadCapacity',0
fdstr16 db 'Read10 3 blocks',0
fdstr17 db 'Write10 3 blocks back',0
fdstr18 db 'Invalid root hub port num for flash',0

hbstr1 db 'initflash with ehci and integrated root hub',0




initflash:

	;before resetting the port we make sure this value is 0
	;if a usb transaction fails resulting in an endpoint halting
	;this value will be set to 1 which indicates the ehci controller
	;must be reinit before doing port reset
	mov dword [ehciEndpointHasHalted],0


;****************************************************
;      ehci w/ integrated root hub
;****************************************************


%if USBCONTROLLERTYPE == 2  ;ehci with root hub

;code to init a hi speed flash drive plugged into the port of ehci with root hub
;also reset the port
;you must first init ehci and init the root hub before calling this function

	STDCALL hbstr1,putscroll
	STDCALL hbstr1,dumpstr
	
.resetport:

	STDCALL mpdstr13,putscroll  

	;first make sure inithub found a valid port number for the flash
	cmp dword [flash_hubportnum],0xff
	jz near .invalidFlashPortNum

	;in inithub we reset all the ports and found which 
	;port the flash drive and mouse were plugged into
	;but it wont hurt to do it again
	;if for some reason this fails, I suggest to reassemble tatOS
	;and copy the image file to your boot flash again
	mov eax,[flash_hubportnum]
	call HubPortReset
	cmp eax,1  ;check for error
	jz near .failure



%endif  ;end of ehci with root hub  *********************************





;****************************************************
;      ehci w/ uhci companion controllers
;****************************************************

%if USBCONTROLLERTYPE == 1  ;ehci with uhci companions

	;here we do not know whats plugged into what
	;so we have to loop 
	;checking ports 3,2,1,0 for a connected device
	;if so is it lo or hi speed ?
	;if its hi speed then reset the port

	STDCALL mpdstr0,putscroll

	
	;pause for 5 seconds
	;if you try to init the flash too quickly immediately after bootup
	;this sequence will fail. But just waiting a bit seems to help
	STDCALL mpdstr1,putscroll
	mov ebx,5000 ;5 seconds
	call sleep

	
	;init loop with portnum=4
	;for ehci with uhci companions we check ports 3,2,1,0
	mov dword [portnumber],4         


.NextPort:

	STDCALL mpdstr8,putscroll
	dec dword [portnumber]     ;decrement portnumber
	jns .PortConnect           ;when portnumber goes (-) were done
	STDCALL mpdstr27,putscroll ;fatal
	jmp .done


.PortConnect:
	; check for device connected
	STDCALL mpdstr10,putscroll
	mov eax,[portnumber]
	call ehci_portconnect   ;CF is set on device connect
	jc .donePortConnect
	STDCALL mpdstr25,putscroll  ;nothing attached
	jmp .NextPort
.donePortConnect:


	;check for low speed device
	STDCALL mpdstr11,putscroll
	mov eax,[portnumber]
	call ehci_portlowspeed     ;ZF is set on low speed device attached
	jnz .donePortLowSpeed
	STDCALL mpdstr26,putscroll  ;low speed device like mouse is attached
	jmp .NextPort
.donePortLowSpeed:


.resetport:

	;first check if the endpoint has halted
	;this happens sometimes with Request Sense
	;just go thru the ehci controller init sequence a 2nd time
	;and then go thru initflash a second time and all will be well
	cmp dword [ehciEndpointHasHalted],0
	jz .doportreset
	STDCALL mpdstr28,putscroll
	jmp .done


.doportreset:
	;reset the port and start usb transactions
	;we still dont know if we have a flash drive connected
	;or some other hi speed device
	STDCALL mpdstr13,putscroll  
	mov eax,[portnumber]
	call ehci_portreset

%endif  ;ehci w/ uhci compannions  ***************************************
	


%if USBCONTROLLERTYPE == 0  ;uhci
	
	;the code here is same as USBCONTROLLERTYPE == 1
	;except for function calls for uhci 

	STDCALL mpdstr2,putscroll
	STDCALL mpdstr2,dumpstr

	STDCALL mpdstr1,putscroll
	mov ebx,5000 ;5 seconds
	call sleep

	mov dword [portnumber],2  ;only 2 ports for uhci: 0,1

.NextPort:
	STDCALL mpdstr8,putscroll
	dec dword [portnumber]   ;decrement portnumber
	jns .PortConnect         ;when portnumber goes (-) were done
	STDCALL mpdstr27,putscroll ;fatal
	jmp .done


.PortConnect:
	STDCALL mpdstr10,putscroll
	mov eax,[portnumber]
	call uhci_portconnect   ;CF is set on device connect
	jc .donePortConnect
	STDCALL mpdstr25,putscroll  ;nothing attached
	jmp .NextPort
.donePortConnect:


	;check for low speed device
	STDCALL mpdstr11,putscroll
	mov eax,[portnumber]
	call uhci_portlowspeed     ;ZF is set on low speed device attached
	jnz .donePortLowSpeed
	STDCALL mpdstr26,putscroll  ;low speed device like mouse is attached
	jmp .NextPort
.donePortLowSpeed:


	;reset the port
	;ehci has dword [ehciEndpointHasHalted] but not uhci
	STDCALL mpdstr13,putscroll  
	mov eax,[portnumber]
	call uhci_portreset

%endif







	;prior to this the port must be detected 
	;where the hi speed flash drive is plugged in
	;and the port must be reset


	STDCALL fdstr0,dumpstr
	STDCALL fdstr0,putscroll


	;refresh the Flash drive control/bulkout/bulkin QH queue heads
	;*************************************************************
	;in case there is a previous transaction error with the flash
	;you must refresh the QH because the ehci writes values to them
	;making them unuseable 
	;the idea here is to avoid having to always call initehci 
	;after every failed transaction since initehci generates the QH's
	;but this also means you have to reinit the mouse and any other
	;device plugged into your ehci ports
	;but having duplicate code here and also in inehci 
	;also poses a code maintenance problem
	;so as of April 2015 we are back to having to reinit the ehci if you
	;suffer a failed flash transaction
	

	


	;do not change the order of these function calls or insert new ones
	;without checking the data toggles. all data toggles are set manually here


		
	;Device Descriptor
	;Some drivers request just 8 bytes then check bMaxPacketSize0=0x40 for endpoint 0
	;after getting the 18 bytes you might want to make sure that bNumConfigurations=1
	;sometimes this fails the first time
	STDCALL fdstr8,putscroll
	call FlashGetDeviceDescriptor
	cmp eax,1  ;check for error
	jz near .failure



	;so we do it again
	call FlashGetDeviceDescriptor
	cmp eax,1  ;check for error
	jz near .failure



.getConfigDescriptor:
	;first we request the 9 byte Configuration Descriptor
	;this will give us the BNUMINTERFACES and WTOTALLENGTH
	mov edx,9
	call FlashGetConfigDescriptor
	cmp eax,1  ;check for error
	jz near .failure




	;make sure the device has only one interface
	;we dont know how to handle anything else
	;I have not yet come across a flash drive with more than 1 interface
	;a usb camera will have more than 1 interface
	;cmp byte [FLASH_BNUMINTERFACES],1
	;jz .getremainingdescriptors
	;STDCALL fdstr6,putscroll
	;jmp near .nextport  ;try another port
.getremainingdescriptors:


	;now we get the configuration, interface and
	;all endpoint descriptors all in one shot
	STDCALL fdstr9,putscroll
	xor edx,edx
	mov dx,[FLASH_WTOTALLENGTH]
	call FlashGetConfigDescriptor
	cmp eax,1  ;check for error
	jz near .failure




	;make sure usb device is mass storage class
	;08 = mass storage
	;03 = HID (protocol: 1=keyboard, 2=mouse)
	;09 = hub
	cmp byte [FLASH_BINTERFACECLASS],0x08
	jnz near .not_mass_storage



.checkSCSI:
	;make sure device responds to SCSI commands
	;06 = SCSI
	;04 = UFI
	cmp byte [FLASH_BINTERFACESUBCLASS],0x06
	jnz near .not_SCSI 



.checkProtocol:
	;make sure device is "bulk only transport"
	;50 = bulk only transport
	;00 = CBI
	;62 = USB-IF
	cmp byte [FLASH_BINTERFACEPROTOCOL],0x50
	jnz near .not_bulk_only 


	

.getEndpointNums:
	;the first endpoint descriptor starts at 0x5032
	;the bEndpointAddress field is at 0x5034
	mov al, [0x5034]
	call SaveEPnum

	;the second endpoint descriptor starts at 0x5039
	;the bEndpointAddress field is at 0x503b
	mov al, [0x503b]
	call SaveEPnum


	;make sure EPin is not 0 which is default pipe for control xfers
	cmp byte [BULKINENDPOINT],0
	jz near .epin_zero

	;make sure EPout is not 0 which is default pipe for control xfers
	cmp byte [BULKOUTENDPOINT],0
	jz near .epout_zero

	;note: on some flash drives EPin=EPout, this is valid



	;dump the wMaxPacketSize for each endpoint
	;control endpoint0 is 64 bytes and configured endpoints IN/OUT are 0x0200
	;we saved the first endpoint wMaxPacketSize at [0x5032+4]
	mov ax,[0x5032+4]
	and eax,0xffff
	STDCALL fdstr7,0,dumpeax
	;we saved the 2nd endpoint wMaxPacketSize at [0x5039+4]
	mov ax,[0x5039+4]
	and eax,0xffff
	STDCALL fdstr7,0,dumpeax

	


	STDCALL fdstr10,putscroll
	mov eax,FLASHDRIVEADDRESS
	mov dword [qh_next_td_ptr], FLASH_CONTROL_QH_NEXT_TD_PTR
	call SetAddress
	cmp eax,1  ;check for error
	jz near .failure


	
	;to this point all usb transactions used deviceaddress=0 and endpoint=0
	;now we must use devicesaddress=FLASHDRIVEADDRESS assigned in usb.s


	;for EHCI only, has no affect for UHCI primary
	;Modify QH(1) for control transfers with assigned FLASHDRIVEADDRESS
	;SetConfiguration uses the CONTROLQUEUEHEAD but needs FLASHDRIVEADDRESS

	;also modify QH(2) and QH(3) for bulk transfer which need BULKEPIN and BULKEPOUT
	;the ehci controller puts these in the QH
	

	;modify our control QH to include the address
	mov eax,FLASH_CONTROL_QH
	mov ecx,0  ;still use endpoint 0
	mov ebx,FLASHDRIVEADDRESS
	call modify_ehci_qh

	;modify flash bulk_out QH to add the endpoint # and address
	mov eax,FLASH_BULKOUT_QH
	movzx ecx, byte [BULKOUTENDPOINT] 
	mov ebx,FLASHDRIVEADDRESS
	call modify_ehci_qh

	;modify flash bulk_in QH to add the endpoint # and address
	mov eax,FLASH_BULKIN_QH
	movzx ecx, byte [BULKINENDPOINT] 
	mov ebx,FLASHDRIVEADDRESS
	call modify_ehci_qh





	STDCALL fdstr11,putscroll
	mov ax,[FLASH_BCONFIGVALUE]
	mov dword [qh_next_td_ptr], FLASH_CONTROL_QH_NEXT_TD_PTR  ;ehci only
	call SetConfiguration
	cmp eax,1  ;check for error
	jz near .failure




	;done with control transfers
	;now we start on the SCSI bulk transfers 
	;the redundancy is important
	;mostly I think to "warm" up the device and get it ready for read10/write10
	;all these SCSI commands are "bulk" commands along with read10/write10
	;they use the CBW command block wrapper and CSW command status wrapper
	;they must be sent to the BULKIN and BULKOUT endpoints 

	;notes about data TOGGLE
	;as of March 2015 I am using data toggles from the qTD for all SCSI bulk commands
	;that means I have to keep track of the toggles myself in code
	;this is supposed to make my life easier for recovering from failed transactions (I hope)
	;the rule is to start with BULKIN toggle =0 and BULKOUT toggle =0 then flip them
	;after every use
	;because I am setting toggles manually, you must execute these bulk commands
	;in the order shown here, do not reorder these function calls or insert new ones
	;otherwise the value of the toggles will be messed up


	STDCALL fdstr12,putscroll
	call Inquiry
	cmp eax,1  ;check for error
	jz near .failure


	;TestUnitReady will always fail the first time
	;looping 10x doesnt help
	;it just means you have to issue more bulk commands like RequestSense
	;until the flash is warmed up and ready to go
	STDCALL fdstr13,putscroll
	mov eax,0  ;status transport toggle
	call TestUnitReady
	;failure here will not hang the device
	;just keep going and try some more commands until TestUnitReady passes
	;do not resetport here, it totally messes up the controller


	;if this command fails the endpoint will halt, then dont try any more commands
	;just reset ehci and run initflash again and all will be well
	STDCALL fdstr14,putscroll
	call RequestSense
	cmp eax,1  ;check for error
	jz near .failure  
	;do not jmp to reset port, it will not work, GetDeviceDescriptor will fail
	;must instead reinit ehci
	;on my old blue flash drive this always fails the first time
	;and always passes the 2nd time after doing initehci again
	;perhaps we should implement "Bulk Only Mass Storage Reset"  ???
	;or try clearing the endpoint




	STDCALL fdstr13,putscroll
	mov eax,1  ;status transport toggle
	call TestUnitReady


	STDCALL fdstr15,putscroll
	call ReadCapacity
	cmp eax,1  ;check for error
	jz near .failure
	;If you get this far this command should never fail




	;init our data toggle values
	;up to this point we had control transfers and bulk transfers
	;which used data toggles which I set manually
	;you can not eliminate any of the above function calls or change their order
	;without messing up the data toggles
	;from here on we will not set the toggles manually
	;read10 and write10 will instead get their toggles from variables
	;dword [bulktogglein] and dword [bulktoggleout]
	;our QH in initehci.s is setup to get toggles from the qTD
	;every time we use these variables, must call toggle() from math.s to flip
	;the toggle value must be 0,1,0,1,0,1 ...
	mov dword [bulktoggleout],1 ;previous ReadCapacity Command OUT used 0 so we use 1
	mov dword [bulktogglein],0  ;previous ReadCapacity Status IN used 1 so we use 0






	;Read10 test
	;we read 3 blocks near the end to warm up the flash
	STDCALL fdstr16,putscroll
	mov ebx,[flashdriveLBAmax]
	sub ebx,100
	mov ecx,3           ;qty blocks
	mov edi,CLIPBOARD   ;destination memory address
	call read10
	jz near .failure



	;Write10 test 
	;and we write back the same data
	STDCALL fdstr17,putscroll
	mov ebx,[flashdriveLBAmax]
	sub ebx,100        ;LBAstart = [flashdriveLBAmax] - 100 blocks
	mov ecx,3          ;qty blocks to write
	mov esi,CLIPBOARD  ;source address
	call write10
	jz near .failure





	;load the vbr, fat1, fat2, rootdir into memory
	;all tatOS file operations that modify the fat or root dir
	;are done in memory only
	;to write all changes to the flash is done manually from the filemanager
	;before you unplug and shutdown
	call fatloadvbrfatrootdir	


	;set the CWD as "root"
	call fatsetCWDasRoot


	;save a backup copy of VBR+FAT1+FAT2+ROOTDIR
	;in case this portion of the flash drive becomes corrupted later on
	;the user may reinit the flash and restore this from usb central
	;we assume the flash drive is tatOS fat16 formatted
	mov esi,0x1900000
	mov edi,0x1200000  ;destination memory address
	mov ecx,0x40e00
	call memcpy



	mov eax,0  ;success
	jmp .done


.clearEndpoint:
	;2do, this is not currently implemented, not way to execute this code
	;if bulkin or bulkout endpoints fails 
	;in one of the SCSI commands
	;we should jump here and call
	;mov ax,EndpointNumber 
	call ClearFeatureEndpointHalt
	;this will reset data toggles in the flash
	;and then fall thru and go back to resetport

.failure:
	mov eax,3
	STDCALL mpdstr29,putscroll
	jmp .done
.invalidFlashPortNum:
	STDCALL fdstr18,putscroll
	jmp .done
.not_mass_storage:
	STDCALL fdstr1,dumpstr 
	jmp .done
.not_SCSI:
	STDCALL fdstr2,dumpstr
	jmp .done
.not_bulk_only:
	STDCALL fdstr3,putscroll
	jmp .done
.epin_zero:
	STDCALL fdstr4,putscroll
	jmp .done
.epout_zero:
	STDCALL fdstr5,putscroll
	jmp .done
.done:
	;so user can see the init sequence messages
	STDCALL pressanykeytocontinue,putscroll 
	call getc
	ret
	







