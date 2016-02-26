;tatOS/usb/initflash.s



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

;if any transfer descriptor TD fails we bail 
;you can always go back and reinit controller and flash again

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

;this code will only handle one hi speed device plugged into a port per controller
;if there is more than 1 hi speed device plugged in there will be problems

;do not change the order of the function calls in initflash
;or insert new ones, without checking the data toggles. 




usbfdstr0  db 'init usb flash',0
usbfdstr1  db 'flash-GetDeviceDescriptor',0
usbfdstr2a db 'flash-GetConfigDescriptor 9 bytes',0
usbfdstr2b db 'flash-GetConfigDescriptor full',0
usbfdstr3a db 'flash-1st Endpoint wMaxPacketSize',0
usbfdstr3b db 'flash-2nd Endpoint wMaxPacketSize',0
usbfdstr4  db 'flash-SetAddress',0
usbfdstr5  db 'flash-SetConfiguration',0
usbfdstr6  db 'flash-Inquiry',0
usbfdstr7  db 'flash-TestUnitReady',0
usbfdstr8  db 'flash-RequestSense',0
usbfdstr9  db 'flash-ReadCapacity',0
usbfdstr10 db 'flash-Read10 3 blocks',0
usbfdstr11 db 'flash-Write10 3 blocks back',0
usbfdstr12 db 'flash-usb transaction failure',0
usbfdstr13 db 'flash-USB device is not 0x08 mass storage class',0
usbfdstr14 db 'flash-USB device subclass is not 0x06 for SCSI commands',0
usbfdstr15 db 'flash-USB device protocol is not 0x50 bulk-only transport',0
usbfdstr16 db 'flash-error bulk EPIN=0',0
usbfdstr17 db 'flash-error bulk EPOUT=0',0
usbfdstr18 db 'done init usb flash drive',0



;************************************************************
;initflash

;this code inits a hi speed usb flash drive (memory stick)

;assumptions:
;   * a hi speed device has been detected on the port
;   * the port is already reset
;the above functions are provided by initdevices.s

;input: none
;return: eax=0 success
;        eax=1 error
;************************************************************

initflash:

	STDCALL usbfdstr0,dumpstr
	STDCALL usbfdstr0,putscroll


	;refresh the Flash drive control/bulkout/bulkin QH queue heads
	;*************************************************************
	;in case there is a previous transaction error with the flash
	;you must refresh the queue heads QH because 
	;the usb controller writes values to them making them unuseable 
	;the idea here is to avoid having to always reset the usb controller
	;after a failed flash drive control or bulk transaction
	;but if you reset the usb controller
	;you have to reinit the mouse and any other
	;device plugged into your ports
	;I never got this concept working - for future

		
	;Device Descriptor
	;Some drivers request just 8 bytes then check bMaxPacketSize0=0x40 for endpoint 0
	;after getting the 18 bytes you might want to make sure that bNumConfigurations=1
	;sometimes this fails the first time
	STDCALL usbfdstr1,putscroll
	call FlashGetDeviceDescriptor
	cmp eax,1  ;check for error
	jz near .errorTransaction



	;so we do it again
	STDCALL usbfdstr1,putscroll
	call FlashGetDeviceDescriptor
	cmp eax,1  ;check for error
	jz near .errorTransaction



.getConfigDescriptor:
	;first we request the 9 byte Configuration Descriptor
	;this will give us the BNUMINTERFACES and WTOTALLENGTH
	STDCALL usbfdstr2a,putscroll
	mov edx,9
	call FlashGetConfigDescriptor
	cmp eax,1  ;check for error
	jz near .errorTransaction




	;make sure the device has only one interface
	;we dont know how to handle anything else
	;I have not yet come across a flash drive with more than 1 interface
	;a usb camera will have more than 1 interface
	;cmp byte [FLASH_BNUMINTERFACES],1
	;jz .getremainingdescriptors
	;jmp near .nextport  ;try another port
.getremainingdescriptors:


	;now we get the configuration, interface and
	;all endpoint descriptors all in one shot
	STDCALL usbfdstr2b,putscroll
	xor edx,edx
	mov dx,[FLASH_WTOTALLENGTH]
	call FlashGetConfigDescriptor
	cmp eax,1  ;check for error
	jz near .errorTransaction




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
	;control endpoint0 is 64 bytes and configured endpoints 
	;IN/OUT for bulk transport are 0x0200
	;we saved the first endpoint wMaxPacketSize at [0x5032+4]
	mov ax,[0x5032+4]
	and eax,0xffff
	STDCALL usbfdstr3a,0,dumpeax
	;we saved the 2nd endpoint wMaxPacketSize at [0x5039+4]
	mov ax,[0x5039+4]
	and eax,0xffff
	STDCALL usbfdstr3b,0,dumpeax

	


	STDCALL usbfdstr4,putscroll
	STDCALL devstr1,dumpstr  ;FLASH

	mov eax,FLASHDRIVEADDRESS
	mov dword [qh_next_td_ptr], FLASH_CONTROL_QH_NEXT_TD_PTR
	call SetAddress

	cmp eax,1  ;check for error
	jz near .errorTransaction


	
	;to this point all usb transactions used deviceaddress=0 and endpoint=0
	;now we must use devicesaddress=FLASHDRIVEADDRESS assigned in usb.s




%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)

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

%endif





	STDCALL usbfdstr5,putscroll
	STDCALL devstr1,dumpstr  ;FLASH

	mov ax,[FLASH_BCONFIGVALUE]
	mov dword [qh_next_td_ptr], FLASH_CONTROL_QH_NEXT_TD_PTR  ;ehci only
	call SetConfiguration

	cmp eax,1  ;check for error
	jz near .errorTransaction




	;***********************
	;    BULK Transfers
	;***********************

	;done with control transfers
	;now we start on the SCSI bulk transfers 
	;the order and redundancy is important
	;mostly I think to "warm" up the device and get it ready for read10/write10
	;all these SCSI commands are "bulk" commands along with read10/write10
	;they use the CBW command block wrapper and CSW command status wrapper
	;they must be sent to the BULKIN and BULKOUT endpoints 

	
%if USBCONTROLLERTYPE == 0  ;uhci
	;init toggles for bulk
	;the prepareTD functions will flip these toggles
	mov dword [bulktoggleout],0 
	mov dword [bulktogglein],0  
%endif


	STDCALL usbfdstr6,putscroll
	call Inquiry
	cmp eax,1  ;check for error
	jz near .errorTransaction



	;TestUnitReady will always fail the first time
	;looping 10x doesnt help
	;it just means you have to issue more bulk commands like RequestSense
	;until the flash is warmed up and ready to go
	STDCALL usbfdstr7,putscroll
	mov eax,0  ;status transport toggle for ehci
	call TestUnitReady
	;if eax=1, failure here will not hang the device
	;just keep going and do RequestSense



	;if this command fails the endpoint will halt, then dont try any more commands
	;just reset the usb controller and run initflash again and all will be well
	STDCALL usbfdstr8,putscroll
	call RequestSense
	cmp eax,1  ;check for error
	jz near .errorTransaction  



	STDCALL usbfdstr7,putscroll
	mov eax,1  ;status transport toggle for ehci
	call TestUnitReady
	cmp eax,1
	jz near .errorTransaction
	;I have never seen the flash not pass this one



	STDCALL usbfdstr9,putscroll
	call ReadCapacity
	cmp eax,1  ;check for error
	jz near .errorTransaction
	;If you get this far this command should never fail




%if (USBCONTROLLERTYPE == 1 || USBCONTROLLERTYPE == 2 || USBCONTROLLERTYPE == 3)
	;for ehci
	mov dword [bulktoggleout],1 ;previous ReadCapacity Command OUT used 0 so we use 1
	mov dword [bulktogglein],0  ;previous ReadCapacity Status IN used 1 so we use 0
%endif



	;Read10 test
	;we read 3 blocks near the end to warm up the flash
	STDCALL usbfdstr10,putscroll
	mov ebx,[flashdriveLBAmax]
	sub ebx,100
	mov ecx,3           ;qty blocks
	mov edi,CLIPBOARD   ;destination memory address
	call read10
	jz near .errorTransaction



	;Write10 test 
	;and we write back the same data
	STDCALL usbfdstr11,putscroll
	mov ebx,[flashdriveLBAmax]
	sub ebx,100        ;LBAstart = [flashdriveLBAmax] - 100 blocks
	mov ecx,3          ;qty blocks to write
	mov esi,CLIPBOARD  ;source address
	call write10
	jz near .errorTransaction





	;load the vbr, fat1, fat2, rootdir into memory
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
	;2do, this is not currently implemented, no way to execute this code
	;if bulkin or bulkout endpoints fails 
	;in one of the SCSI commands
	;we should jump here and call
	;mov ax,EndpointNumber 
	call ClearFeatureEndpointHalt
	;this will reset data toggles in the flash
	;and then fall thru and go back to resetport
.errorTransaction:
	mov eax,3
	STDCALL usbfdstr12,putscroll
	STDCALL pressanykeytocontinue,putscroll
	jmp .done
.not_mass_storage:
	STDCALL usbfdstr13,dumpstr 
	jmp .done
.not_SCSI:
	STDCALL usbfdstr14,dumpstr
	jmp .done
.not_bulk_only:
	STDCALL usbfdstr15,putscroll
	jmp .done
.epin_zero:
	STDCALL usbfdstr16,putscroll
	jmp .done
.epout_zero:
	STDCALL usbfdstr17,putscroll
	jmp .done
.done:
	STDCALL usbfdstr18,putscroll
	;initdevices will pause execution
	ret
	







