;tatOS/tlib/pci.s

;rev Feb 1, 2015

;PCI = Peripheral Component Interface
;code to read/write a few pci configuration space registers
;in order to identify usb controllers on the pci bus
;each device plugged into the pci bus gets assigned a BUS:DEV:FUN number
;and is allocated 256 bytes of memory used to control the device

;a pci configuration address is 32 bits:
;bit31    = enable
;bit30-24 = reserved
;bit23-16 = bus       (8 bits allow max 255 but I have read there can be only 8 busses ?))
;bit15-11 = device    (5 bits max 31 )
;bit10-8  = function  (3 bits max 7  )
;bit 7-2  = register
;bit1-0   = 00

;pci header types:
;The old PCI cards have 256 bytes of configuration space
;PCI Express has 4096 bytes
;00=Standard PCI Header
;01=PCI-to-PCI Bridge Header
;02=CardBus Bridge Header
;0x80=????
;0x81

;The type 00 and 01 PCI header start like this:
;31        24|23          16|15                  8|7             0| <- bit
;DeviceID.................. | VendorID............................|   00  <-register/offset
;Status.................... | Command.............................|   04
;ClassCode.. | SubClass.... | ProgrammingInterface|RevisionID.....|   08
;Bist....... | HeaderType.. | LatencyTimer....... |CacheLineSize..|   0c
;BaseAddress0  (BAR0) ............................................|   10 
;BaseAddress1  (BAR1) ............................................|   14

;after this the headers diverge containing differant information
;to detect the usb controllers we need to examine the register offset 08
;ClassCode            = 0c for all Seriel Bus Controllers
;SubClass             = 03 for all USB controllers
;ProgrammingInterface = 00h UHCI controller
;                     = 01h OHCI controller (unsupported by tatos)
;                     = 02h EHCI controller 
;                     = 30h xHCI controller (unsupported by tatos)



;*************************************************************
;pci_detect_usb_controllers
;detect all usb controllers on the pci bus
;instead of using the bios on boot 
;to detect usb controllers
;we now have the ability to scan the pci bus on our own
;this function is executed from pmode in usb central
;you should run this function the first time you boot a new computer
;it will give you the bus:dev:fun of all usb controllers
;then hard code the desired usb controller bus:dev:fun 
;in tatosconfig
;this function was developed to deal with the modern computers
;that may have more than 1 ehci controller
;input:none
;return:writes bus:dev:fun of usb controllers to the screen
bus db 0
dev db 0
fun db 0
pci_deviceID dw 0
pci_vendorID dw 0
pci_configaddress dd 0
pci_str1 db 'pci DeviceID',0
pci_str2 db 'pci VendorID',0
pci_str3 db 'pci HeaderType',0
pci_str4 db 'Class-Subclass-ProgrammingInterface-RevID',0  
pci_str5 db 'Dumping USB Controllers found on PCI bus',0
pci_str7 db 'found UHCI usb controller',0
pci_str8 db 'found OHCI usb controller',0
pci_str9 db 'found EHCI usb controller',0
pci_str10 db 'found xHCI usb controller',0
pci_str11 db 'found unknown usb controller',0
pci_str12 db 'done scan pci bus',0
;**************************************************************

pci_detect_usb_controllers:

	;initialize the bus:dev:fun
	mov byte [bus],0    ;0->7
	mov byte [dev],0    ;0->31
	mov byte [fun],0    ;0->7

	STDCALL pci_str5,dumpstr

.1:

	;form a 32 bit pci config address into eax
	mov bl,[bus]
	mov cl,[dev]
	mov dl,[fun]
	call build_pci_config_address

	;save for later
	mov [pci_configaddress],eax

	

	;read PCI config space register/offset=00 and check the vendorID
	;eax=pci_configaddress
	mov ebx,0
	call pciReadDword  ;return in eax, 0xffffffff if invalid device
	cmp ax,0xffff
	jz near .doneDevice


	;save the DeviceID and VendorID for later
	mov [pci_vendorID],ax
	shr eax,16
	mov [pci_deviceID],ax


	;ok we have a valid device on the pci bus


	;then read register/offset=08 and check the Class/SubClass/ProgInt for usb
	mov eax,[pci_configaddress]
	mov ebx,8  ;register/offset for ClassSubClass/ProgInt
	call pciReadDword  ;return in eax


	;test for USB controller 
	mov ebx,eax
	mov ecx,eax
	shr ecx,8       ;cl gives us 00=uhci, 01=ohci, 02=ehci, 30=xhci
	;need to preserve cl for later
	shr ebx,16
	cmp bx,0x0c03   ;0c=seriel controller, 03=usb
	jnz near .notUSB


	;if we got here we have found a usb controller on the pci bus


	;dump the 0c03xx usb controller Class-SubClass...pci identification
	STDCALL pci_str4,0,dumpeax

	;dump the bus:dev:fun
	mov eax,[pci_configaddress]
	call dumpBusDevFun

	;dump the pci DeviceID
	mov ax,[pci_deviceID]
	STDCALL pci_str1,1,dumpeax

	;dump the pci VendorID
	mov ax,[pci_vendorID]
	STDCALL pci_str2,1,dumpeax

	;read & dump the pci Header type
	mov eax,[pci_configaddress]
	mov ebx,0x0c  
	call pciReadDword  ;return in eax
	shr eax,16  ;bump off the LatencyTimer & CacheLineSize
	and eax,0xff
	STDCALL pci_str3,2,dumpeax
	;ecx is still preserved



	;dump a message telling if its ehci, uhci, ohci, xhci
	cmp cl,0x00
	jnz .2
	STDCALL pci_str7,dumpstr    ;UHCI
	jmp .doneDevice
.2: cmp cl,0x10
	jnz .3
	STDCALL pci_str8,dumpstr    ;OHCI
	jmp .doneDevice
.3: cmp cl,0x20
	jnz .4
	STDCALL pci_str9,dumpstr    ;EHCI
	jmp .doneDevice
.4: cmp cl,0x30
	jnz .5
	STDCALL pci_str10,dumpstr   ;xHCI
	jmp .doneDevice
.5:	STDCALL pci_str11,dumpstr   ;unknown usb


.doneDevice:
.notUSB:


	;increment the fun
	add byte [fun],1  ;inc fun
	cmp byte [fun],7
	jbe .1

	;increment the dev 
	mov byte [fun],0  ;reset fun
	add byte [dev],1  ;inc dev
	cmp byte [dev],31
	jbe .1

	;increment the bus
	mov byte [fun],0  ;reset fun
	mov byte [dev],0  ;reset dev
	add byte [bus],1  ;inc bus
	cmp byte [bus],7  ;attempting a value here of 255 causes computer freeze
	jbe .1
	

	STDCALL pci_str12,dumpstr

	;this code will not detect the xHCI controller
	;on my asus laptop, it will detect the EHCI controllers
	;on the same device, not sure why not

	ret







;**************************************************************
;pciReadDword
;uses port I/O to read from pci configuration space
;input
;eax = pci_config_address with register=00
;ebx = offset/register 
;      you should only use ebx values on dword boundries
;      i.e. ebx=00,04,08,0c,10,14,18,1c,20,24,28,2c... (all hex)
;      this ensures bit0 and bit1 of the pci config space address are 00
;return
;eax=dword read from port
;**************************************************************

pciReadDword:
	push edx

	or eax,ebx
	mov dx,0xcf8  
	out dx,eax    ;send to command port 
	mov dx,0xcfc  
	in  eax,dx    ;read dword from data port 

	pop edx
	ret



;******************************************
;pciWriteDword
;input
;eax and ebx same as above
;ecx=dword value to be written
;******************************************

pciWriteDword:
	push edx
	push eax

	or eax,ebx
	mov dx,0xcf8  
	out dx,eax    ;send to command port 
	mov dx,0xcfc  
	mov eax,ecx
	out dx,eax    ;write dword to data port 

	pop eax
	pop edx
	ret



;******************************************************************
;BusDevFunString
;small routine to split apart the pic_config_address
;and display the bus:dev:fun as a string like this:
;"00:07:02 PCI BUS:DEV:FUN"

;input:
;eax = pci_config_address with register=00
;edi = destination address for string

;return:none

;examples of bus:dev:fun     bus:dev:fun
;Intel onboard UHCI          00:07:02
;Via VT6212 EHCI addon card  00:0d:02
;Emachines w/nVidia EHCI     00:0b:01
;Intel EHCI on HP Pavillion  00:1a:07
;Intel UHCI on HP Pavillion  00:1a:00

busdevfun db ' BUS:DEV:FUN',0
;*****************************************************************

BusDevFunString:

	mov ebx,eax  ;save
	mov edx,2    ;convert al to hex

	;get BUS
	shr eax,16
	and eax,0xff
	call eax2hex  ;edi points to 0 terminator

	mov byte [edi],':'
	inc edi

	;get DEV
	mov eax,ebx
	shr eax,11
	and eax,11111b
	call eax2hex  

	mov byte [edi],':'
	inc edi

	;get FUN
	mov eax,ebx
	shr eax,8
	and eax,111b
	call eax2hex  


	;now add the busdevfun string tag
	mov esi,busdevfun
	mov ecx,12
	cld     
	rep movsb

	mov byte [edi],0  ;terminator

	ret


;******************************************************************
;dumpBusDevFun
;small routine to split apart the pic_config_address
;and write the bus:dev:fun individually to the dump
;we store UHCI at 0x560 and EHCI at 0x568

;input:
;eax = pci_config_address with register=00

;return:none
pcistr1 db 'pci BUS',0
pcistr2 db 'pci DEVICE',0
pcistr3 db 'pci FUNCTION',0
;*****************************************************************

dumpBusDevFun:

	push eax
	mov ebx,eax  ;save

	;dump the bus:dev:fun individually
	shr eax,16
	and eax,0xff
	STDCALL pcistr1,2,dumpeax  ;bus
	mov eax,ebx
	shr eax,11
	and eax,11111b
	STDCALL pcistr2,2,dumpeax  ;dev
	mov eax,ebx
	shr eax,8
	and eax,111b
	STDCALL pcistr3,2,dumpeax  ;fun

	pop eax
	ret



;********************************************
;build_pci_config_address
;build a 32 bit pci config address into eax
;input:
;bl=BUS 
;cl=DEV 
;dl=FUN 
;return:
;eax=pci_config_address
;*******************************************

build_pci_config_address:

	xor eax,eax

	;bus
	and ebx,0xff
	shl ebx,16
	or eax,ebx ;set bus bits

	;dev
	and ecx,0xff
	shl ecx,11
	or eax,ecx ;set dev bits

	;fun
	and edx,0xff
	shl edx,8
	or eax,edx ;set fun bits

	;you must set the enable bit in order to retrieve any pci config data
	or eax,0x80000000

	;eax=pci_config_address with the enable bit set
	ret

