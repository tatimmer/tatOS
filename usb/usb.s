;tatOS/usb/usb.s


;this file is included in tlib.s
;this file includes all the other /usb files

;code to control interaction between a USB mass storage device
;aka "flash drive" or "memory stick" or "pen drive"
;and also the low speed usb mouse
;using a UHCI or EHCI USB Controller

;this file contains the data structures
;and "includes" the supporting functions
;see also tlib/tatOS.inc for #defines

;initflash prepares a pen drive for read10/write10
;as of Aug 2009 it must be executed from the shell (f12)
;initmouse does similar work

;this code was specifically developed on
;Intel 82371 UHCI Universal host controller
;VID=0x8086  DID=0x7112
;and later modified for EHCI usage using a pci addon card by Manhattan
;this card contains a chip with (1) EHCI and (2) UHCI companion controllers 
;this usb 2.0 controller chip is made by VIA VT6212 and it has 4 ports
;VID=0x1106  DID=0x3104
;ehci with root hub is also supported. see tatOS.config

;the UHCI controller was typically found on computers
;circa Windows98 up to WindowsXP
;the UHCI controller supports (2) usb "Full" speed ports
;the ports can also operate on low speed for the usb mouse

;the EHCI controller is found on the newer desktop computers
;the OHCI USB controller is unsupported.
;the xHCI which is the newest usb 3.0 super-dooper-speed is unsupported


bits 32



;write10 uses this 
notready db 'Flash Drive Not Ready: Init the controller & drive (USB CENTRAL)',0



FUN       dd 0
BUSDEV    dd 0
BUSDEVFUN dd 0


;this string is used in putspause if a call to runTDchain has failed
usbrunerror db 'RUNTDCHAIN Failure-TD still active-reinit flash/controller',0



;storage for function pointers
;pointers are assigned in usbcentral
;depending on which controller is found, ehci or uhci
initcontroller dd 0
portreset      dd 0
portconnect    dd 0
portlowspeed   dd 0
portscan       dd 0
portread       dd 0
portdump       dd 0
command        dd 0
prepareTDchain dd 0
runTDchain     dd 0
TDstatus       dd 0
ControllerError dd 0

;during initflash this function pointer is initiated properly
;here we set a default value
;this should really be set at the end of boot2.s
usbcontrollerstatus dd ehci_status


;various globals used throughout the usb code
dCBWDataTransferLength dd 0
TDbytes                dd 0
TDmaxbytes             dd 0
haveNULLpacket         dd 0
chainbytecount         dd 0
LinkPointer            dd 0
BufferPointer          dd 0
flash_hubportnum       dd 0  ;saved in inithub.s
mouse_hubportnum       dd 0



;our UHCI usb frame list consits of 1024 pointers 
;the frame list starts at 0x1000000
%define FRAMELIST 0x1000000



portnumber   dd 0
eecp         dd 0  ;EHCI Extended Capabilities Pointer

;the results from ReadCapacity are saved here
;write10 checks if the LBAstart is valid within range
;these values are written to usb central at bottom
flashdriveLBAmax        dd 0
flashdriveBytesPerBlock dd 0
flashdriveCapacityBytes dd 0


;runTD may indicate the result of a usb transaction shows
;bit6 of a TD being set indicating an endpoint has halted
;this is a serious error and the endpoint will not transfer any more data
;our solution is to reinit the controller, reset the port and reinit the flash
;we check this value before resetting the port
ehciEndpointHasHalted dd 0

;boot2 sets to 0, initusbmass sets to 1 at end if successful
;read10 and write10 check for 1 before proceeding
%define FLASHDRIVEREADY 0x528


;usb mouse uses this memory for its TD for interrupt transactions
;all other control and bulk transaction TD's are written to 0xd60000
;we seperate to prevent interference
align 32
interruptTD times 100 db 0


;speed
%define FULLSPEED 0  ;actually this will work for hi speed also, see prepareTDchain
%define LOWSPEED  1


;packet identification
;we use the same values as for ehci
;the uhci_prepareTDchain will modify accordingly
%define PID_OUT   0   ;uhci=0xe1
%define PID_IN    1   ;uhci=0x69
%define PID_SETUP 2   ;uhci=0x2d
pid  dd 0
	


;global data toggles
;with ehci you could keep toggles in the QH but we cant with uhci
controltoggle  dd 0
bulktoggle     dd 0
bulktogglein   dd 0
bulktoggleout  dd 0
mousetogglein  dd 0
mousetoggleout dd 0


;endpoint numbers are read from endpoint descriptors and saved to global memory
endpoint0          dd 0
;all endpoint numbers are byte values 0->127
%define BULKINENDPOINT   0x532   ;usb flash drive IN  endpoint # 
%define BULKOUTENDPOINT  0x533   ;usb flash drive OUT endpoint # 
%define MOUSEINENDPOINT  0x534   ;usb mouse IN endpoint #
%define HUBINENDPOINT    0x535   ;usb hub   IN endpoint #



;queue heads reserved for uhci
;0x1005000 is for mouse interrupt xfers on uhci
;0x1005100 is for mouse control xfers on uhci and for flash control/bulk xfer on uhci

;important queue head addresses for usb transactions using ehci
%define HUB_CONTROL_QH                 0x1005300
%define HUB_CONTROL_QH_NEXT_TD_PTR     0x1005310
%define FLASH_CONTROL_QH               0x1005400
%define FLASH_CONTROL_QH_NEXT_TD_PTR   0x1005410
%define MOUSE_CONTROL_QH               0x1005500
%define MOUSE_CONTROL_QH_NEXT_TD_PTR   0x1005510
%define FLASH_BULKIN_QH                0x1005600
%define FLASH_BULKIN_QH_NEXT_TD_PTR    0x1005610
%define FLASH_BULKOUT_QH               0x1005700
%define FLASH_BULKOUT_QH_NEXT_TD_PTR   0x1005710
%define MOUSE_INTERRUPT_QH             0x1006000
%define MOUSE_INTERRUPT_QH_NEXT_TD_PTR 0x1006010

;storage for this ehci important qh address
;its used by SetAddress, SetConfig ...
;save your QH_NEXT_TD_PTR here before calling these functions
qh_next_td_ptr dd 0



;here we reserve a unique usb address for each device that tatOS supports
;addresses are 7 bits (0-127)
;address=0 is reserved for control transfers
%define ADDRESS0           0  ;unconfigured device
%define FLASHDRIVEADDRESS  2  ;usb flash drive
%define MOUSEADDRESS       3  ;usb mouse
%define HUBADDRESS         4  ;usb hub


;we build each transfer descriptor TD chain starting at 0xd60000
%define ADDRESS_FIRST_TD 0xd60000
;and they are spaced out as follows
%define UHCITDSPACING 32
%define EHCITDSPACING 64
;prepareTDchain and runTDchain use these values


;prepareTDchain fills this value in and runTDchain reads it
chainqtyTDs  dd 0

;we now support 2 differant types of ehci controllers:
;type=1 ehci with uhci companions  (VIA pci addon card)
;type=2 ehci with root hub  (my asus laptop)
ehciType dd 0


;defines for memory addresses where we store
;the fields of the USBMASS Configuration Descriptor
;and Interface Descriptor and Endpoint Descriptors
;for the usb flash drive:
%define FLASH_WTOTALLENGTH        0x5022
%define FLASH_BNUMINTERFACES      0x5024
%define FLASH_BCONFIGVALUE        0x5025
%define FLASH_BNUMENDPOINTS       0x502d
%define FLASH_BINTERFACECLASS     0x502e
%define FLASH_BINTERFACESUBCLASS  0x502f
%define FLASH_BINTERFACEPROTOCOL  0x5030

;for the low speed usb mouse we store the DeviceDescriptor starting
;at 0x5500 then the Config/Interface/HID and endpoint descriptors
;see /doc/memorymap
%define MOUSE_WTOTALLENGTH   0x5522  ;length of all Config/Interf/HID/Endpoint descriptors
%define MOUSE_BNUMINTERFACES 0x5524
%define MOUSE_BCONFIGVALUE   0x5525
%define MOUSE_WREPORTLENGTH  0x5539  ;length of Report Descriptor
%define MOUSE_WMAXPACKETSIZE 0x553f


;defines for memory addresses for the usb hub:
%define HUB_WTOTALLENGTH    0x6022  ;length of all Config/Interf/HID/Endpoint descriptors
%define HUB_BNUMINTERFACES  0x6024
%define HUB_BCONFIGVALUE    0x6025
%define HUB_BINTERFACECLASS 0x602e
%define HUB_BQTYDOWNSTREAMPORTS 0x6042



;the device will fill in the 0x53425355 signature
;and it will copy the CBWtag
;and it will give you status: pass/fail/phase error
align 0x1000
scsiCSW:
times 13 db 0

;the device should return this 
;as the signature and tag of the CSW
expectedCSW:
db 0x55,0x53,0x42,0x53,0xdd,0xcc,0xbb,0xaa,0,0,0,0,0



;USB-SCSI
%include "usb/initflash.s"
%include "usb/inithub.s"
%include "usb/initmouse.s"
%include "usb/devicedesc.s"
%include "usb/configdesc.s"
%include "usb/reportdesc.s"
%include "usb/protocol.s"
%include "usb/setidle.s"
%include "usb/mouseinterrupt.s"
%include "usb/setaddress.s"
%include "usb/setconfig.s"
%include "usb/readcapacity.s"
%include "usb/inquiry.s"
%include "usb/testunit.s"
%include "usb/requestsense.s"
%include "usb/read10.s"
%include "usb/write10.s"
%include "usb/clearep.s"

;UHCI/EHCI-hdwre
%include "usb/status.s"
%include "usb/port.s"
%include "usb/run.s"
%include "usb/checkcsw.s"
%include "usb/saveEP.s"
%include "usb/prepareTD-uhci.s"
%include "usb/prepareTD-ehci.s"
%include "usb/inituhci.s"
%include "usb/initehci.s"
%include "usb/showehcireg.s"
%include "usb/showuhcireg.s"
%include "usb/showehciroothubports.s"
%include "usb/usbcentral.s"
%include "usb/error.s"
%include "usb/baseaddress.s"
%include "usb/hubdesc.s"
%include "usb/hubport.s"
%include "usb/usbdump.s"
%include "usb/queuehead.s"
%include "usb/info.s"










