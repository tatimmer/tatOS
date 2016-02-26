;tatOS/usb/showehcireg.s



;*******************************************************************
;show_ehci_reg
;code to display the register values and bitfields of the ehci
;pci registers and well as capability and operational registers
;all register values and bitfields are written as text strings
;directly to List Control Buffer starting at 0x2950000. 
;This routine is called from USB CENTRAL
;not every register and bitfield is shown here
;I tried for whats most important in tatOS
;view this output before and after ehci controller init
;and also before and after flash drive init

;input:none
;return:none

;Program Title
ehcireg db 'USB EHCI Controller PCI/Capability/Operational Registers',0



;DEVICEID-VENDORID
devid1 db 'PCI: DeviceID-VendorID',0
devid2a db 'Vendor=Intel (0x8086)',0
devid2b db 'Vendor=nVidia (0x10de)',0
devid2c db 'Vendor=Via Technologies (0x1106)',0
devid2d db 'Vendor=unknown',0

;STATUS-COMMAND
statcom1 db 'PCI: STATUS-COMMAND',0
statcom2 db 'Bus Master enable (1=yes)',0
statcom3 db 'Memory Space enable (1=yes)',0

;CLASSC-SUBCLA-PROGINT-REVID
class1 db 'PCI: ClassCode, SubClass, ProgrammingInterface, RevisionID',0

;BIST-HEADER-LATENCY-CACHE
header db 'PCI: BIST, PCIHeaderType,(00=common), LatencyTimer, CacheLineSize',0

;USBBASE
ubase1 db 'PCI: USBBASE/USBBA - USB Controller Base Address',0
ubase2 db 'Base Address Type (0=32bit, 2=64bit)',0

;SUBSYSTEM 
subsys db 'PCI: SubsystemID-SubsystemVendorID',0

;USBLEGSUP
legsup1 db 'PCI: USBLEGSUP - Legacy Support Extended Capability',0
legsup2 db 'HC OS Owned Semaphore (1=OS wants ehci)',0
legsup3 db 'HC Bios Owned Semaphore (0=default, 1=bios owns ehci)',0
legsup4 db 'Next EHCI Extended Capability Pointer',0
legsup5 db 'Capability ID (1=Legacy Support reg at eecp+4)',0

;USBLEGCTLSTS
legctl db 'PCI: USBLEGCTLSTS - Legacy Support (System Management Event Interrupts)',0

;CAPLENGTH
capl db 'CAPLENGTH Capability Registers Length (offset to OperReg)',0

;HCSPARAMS-Structural Parameters
sprm1 db 'HCSPARAMS - HOST CONTROLLER STRUCTURAL PARAMETERS',0
sprm2 db '    Debug port number',0
sprm3 db '    N_CC Number of Companion Controllers',0
sprm4 db '    N_PCC Number of Ports per Companion Controller',0
sprm5 db '    Port Routing Rules',0
sprm6 db '    PPC Port Power Control (1=ports have power switch)',0
sprm7 db '    N_PORTS Number of Ports (0=undefined)',0

;HCCPARAMS-Capability Parameters
parm1 db 'HCCPARAMS - HOST CONTROLLER CAPABILITY PARAMETERS',0
parm2 db '    EECP Extended Capability Pointer (0x68 typ)',0
parm3 db '    Asynchronous Schedule Park Capability',0
parm4 db '    Programmable Frame List Flag',0
parm5 db '    64 bit addressing (1=64, 0=32)',0

;USBCMD-Command Register
cmd1 db 'USBCMD - COMMAND REGISTER',0
cmd2 db  '    Interrupt Threshold Control (max rate for interrupts)',0
cmd3 db  '    Asynchronous Schedule Park Mode Enable (1=enable)',0
cmd4 db  '    Asynchronous Schedule Park Mode Count',0
cmd5 db  '    Light Host Controller Reset',0
cmd6 db  '    Interrupt on Async Advance Doorbell',0
cmd7 db  '    Async Schedule Enable',0
cmd8 db  '    Periodic Schedule Enable',0
cmd9 db  '    Frame List Size (00=1024)',0
cmd10 db '    Host Controller Reset HCRESET',0
cmd11 db '    Run/Stop (1=run)',0

;USBSTS-Status Register
sts1 db 'USBSTS - STATUS REGISTER',0
sts2 db  '    Asynchronous Schedule Status (0=disabled)',0
sts3 db  '    Periodic Schedule Status (0=disabled)',0
sts4 db  '    Reclamation (0=default, empty asynchronous schedule)',0
sts5 db  '    Halted (set=1 by controller after it has stopped)',0
sts6 db  '    Interrupt on Async Advance (0=default)',0
sts7 db  '    Host System Error (1=serious error)',0
sts8 db  '    Frame List Rollover (1=rollover)',0
sts9 db  '    Port Change Detect (1=change)',0
sts10 db '    USB Error Interrupt (1=transaction error)',0
sts11 db '    USB Interrupt (1=TD complete if IOC bit set)',0

;USBINTR - Interrupt Enable
inten db 'USBINTR - INTERRUPT ENABLE REGISTER',0

;CONFIGFLAG
conff db 'CONFIGFLAG - CONFIG FLAG (1=ports route to ehci)',0

;PORTSC-Port Status & Control
port1 db  'PORTSC(n) - PORT STATUS & CONTROL',0
port2 db  '    Port Owner (1=companion controller,0=ehci)',0
port3 db  '    Port Power (1=host controller has port power switches)',0
port4a db '    Line Status:Not low speed device, perform EHCI reset',0
port4b db '    Line Status:Low speed device, release ownership of port',0
port5 db  '    Port Reset (1=in reset)',0
port6 db  '    Port Suspend (1=in suspend)',0
port7 db  '    Port Enable (1=enable)',0
port8 db  '    Port Connect Status (1=device present)',0



;define start of strings in list control buffer
;each string starts 0x100 after previous
BSDVFNLIST equ 0x2950000
DEVENLIST  equ BSDVFNLIST+0x100
STCOMLIST  equ DEVENLIST+0x200
CLASSLIST  equ STCOMLIST+0x300
HEADRLIST  equ CLASSLIST+0x100
UBASELIST  equ HEADRLIST+0x100
SUBLIST    equ UBASELIST+0x200
CAPLLIST   equ SUBLIST+0x100
SPRMLIST   equ CAPLLIST+0x100
PARMLIST   equ SPRMLIST+0x700
LEGLIST    equ PARMLIST+0x500
CMDLIST    equ LEGLIST+0x600
STATUSLIST equ CMDLIST+0xb00
INTENLIST  equ STATUSLIST+0xb00
CONFFLIST  equ INTENLIST+0x100
PORTLIST   equ CONFFLIST+0x100

TOTALQTYEHCILISTSTRINGS equ 86
;******************************************************************

show_ehci_reg:


	;the USB 2.0 spec says that in PCI configuration space
	;a number of registers are "implementation as needed..."
	;this includes 00-08h, 0c-0fh, 14-5fh, 64-ffh
	;so you see if this code doesnt work maybe you need to find your
	;specific controller data sheet and set some of these pci confi registers




	;display the BUS:DEV:FUN number of the ehci controller
	mov eax,[EHCIBUSDEVFUN]
	mov edi,BSDVFNLIST
	call BusDevFunString



	;********************************************
	;DEVICEID-VENDORID
	;********************************************
	mov eax,[EHCIBUSDEVFUN]
	mov ebx,0  ;PCIconfig + 0 = DEVICEID
	call pciReadDword
	STDCALL devid1,DEVENLIST,eaxstr
	and eax,0xffff  ;mask off devid

	;vendor name string
	cmp ax,0x8086
	jnz .trynVidia
	STDCALL devid2a,DEVENLIST+0x100,eaxstr
	jmp .doneVID
.trynVidia:
	cmp ax,0x10de
	jnz .tryViaTech
	STDCALL devid2b,DEVENLIST+0x100,eaxstr
	jmp .doneVID
.tryViaTech:
	cmp ax,0x1106
	jnz .unknownVID
	STDCALL devid2c,DEVENLIST+0x100,eaxstr
	jmp .doneVID
.unknownVID:
	STDCALL devid2d,DEVENLIST+0x100,eaxstr
.doneVID:



	;********************************************
	;STATUS-COMMAND
	;********************************************
	mov eax,[EHCIBUSDEVFUN]
	mov ebx,4  ;PCIconfig + 4 = STATUS
	call pciReadDword
	mov ebx,eax   ;copy
	STDCALL statcom1,STCOMLIST,eaxstr

	;bus master enable (Via and hopefully others)
	mov eax,ebx
	shr eax,2
	and eax,1
	STDCALL statcom2,STCOMLIST+0x100,eaxstr

	;memory space enable
	mov eax,ebx
	shr eax,1
	and eax,1
	STDCALL statcom3,STCOMLIST+0x200,eaxstr



	;********************************************
	;CLASSC-SUBCLA-PROGINT-REVID
	;********************************************
	mov eax,[EHCIBUSDEVFUN]
	mov ebx,8  ;PCIconfig + 8 = CLASSC  
	call pciReadDword
	STDCALL class1,CLASSLIST,eaxstr



	;********************************************
	;BIST-HEADER-LATENCY-CACHE
	;********************************************
	mov eax,[EHCIBUSDEVFUN]
	mov ebx,0x0c  ;PCIconfig + 0ch 
	call pciReadDword
	STDCALL header,HEADRLIST,eaxstr



	;********************************************
	;USBBASE - EHCI Base Address
	;********************************************
	mov eax,[EHCIBUSDEVFUN]
	mov ebx,0x10  ;PCIconfig + 0x10 = USBBASE 
	call pciReadDword
	mov ebx,eax   ;copy
	;mask off the address "type"
	and eax,0xffffff00
	mov [EHCIUSBBASE],eax  
	STDCALL ubase1,UBASELIST,eaxstr

	;address type
	mov eax,ebx
	shr eax,1
	and eax,11b
	STDCALL ubase2,UBASELIST+0x100,eaxstr



	;********************************************
	;SUBSYSTEM
	;********************************************
	mov eax,[EHCIBUSDEVFUN] ;get the pci_config_address of ehci
	mov ebx,0x2c            ;PCIconfig + 0x2c = SUBSYTEM
	call pciReadDword       ;eax=dword from port
	STDCALL subsys,SUBLIST,eaxstr



	;********************************************
	;CAPLENGTH - Capability Registers Length	
	;********************************************
	mov esi,[EHCIUSBBASE]  ;get start of capa reg
	xor eax,eax
	mov al,[esi]    ;CapabilityBase + 0 = CAPLENGTH 
	STDCALL capl,CAPLLIST,eaxstr



	;********************************************
	;HCSPARAMS - Structural Parameters Register	
	;********************************************
	mov esi,[EHCIUSBBASE]  ;get start of capa reg
	mov eax,[esi+4]  ;CapabilityBase + 4 = HCSPARAMS 
	mov ebx,eax      ;copy

	;HCSPARAMS register value
	STDCALL sprm1,SPRMLIST,eaxstr

	;Debug port number
	mov eax,ebx
	shr eax,20
	and eax,1111b
	STDCALL sprm2,SPRMLIST+0x100,eaxstr

	;N_CC Number of Companion Controllers
	mov eax,ebx
	shr eax,12
	and eax,1111b
	STDCALL sprm3,SPRMLIST+0x200,eaxstr

	;N_PCC Number of Ports per Companion Controller
	mov eax,ebx
	shr eax,8
	and eax,1111b
	STDCALL sprm4,SPRMLIST+0x300,eaxstr

	;Port Routing Rules
	mov eax,ebx
	shr eax,7
	and eax,1
	STDCALL sprm5,SPRMLIST+0x400,eaxstr

	;PPC Port Power Control
	mov eax,ebx
	shr eax,4
	and eax,1
	STDCALL sprm6,SPRMLIST+0x500,eaxstr

	;N_PORTS Number of Ports (0=undefined)
	mov eax,ebx
	and eax,0xf
	STDCALL sprm7,SPRMLIST+0x600,eaxstr



	;********************************************
	;HCCPARAMS - Capability Parameters Register	
	;********************************************
	mov esi,[EHCIUSBBASE]  ;get start of capa reg
	mov eax,[esi+8]  ;CapabilityBase + 8 = HCCPARAMS 
	mov ebx,eax      ;copy

	;HCCPARAMS register value
	STDCALL parm1,PARMLIST,eaxstr

	;EECP Extended Capability Pointer
	mov eax,ebx
	shr eax,8
	and eax,0xff
	mov [eecp],eax  ;save eecp
	STDCALL parm2,PARMLIST+0x100,eaxstr

	;Asynchronous Schedule Park Capability
	mov eax,ebx
	shr eax,2
	and eax,1
	STDCALL parm3,PARMLIST+0x200,eaxstr

	;Programmable Frame List Flag
	mov eax,ebx
	shr eax,1
	and eax,1
	STDCALL parm4,PARMLIST+0x300,eaxstr

	;64 bit addressing (1=64, 0=32)
	mov eax,ebx
	and eax,1
	STDCALL parm5,PARMLIST+0x400,eaxstr




	;************************************************
	;USBLEGSUP - Legacy Support Extended Capability
	;************************************************
	;we move this down here because it depends on eecp
	mov eax,[EHCIBUSDEVFUN] ;get the pci_config_address of ehci
	mov ebx,[eecp]          ;PCIconfig + eecp = USBLEGCTLSTS
	call pciReadDword       ;eax=dword from port
	mov ebx,eax             ;copy
	STDCALL legsup1,LEGLIST,eaxstr

	;HC OS Owned Semaphore
	mov eax,ebx
	shr eax,24
	and eax,1
	STDCALL legsup2,LEGLIST+0x100,eaxstr

	;HC BIOS Owned Semaphore
	mov eax,ebx
	shr eax,16
	and eax,1
	STDCALL legsup3,LEGLIST+0x200,eaxstr

	;Next EHCI Extended Capability Pointer
	mov eax,ebx
	shr eax,8
	and eax,0xff
	STDCALL legsup4,LEGLIST+0x300,eaxstr

	;Capability ID
	mov eax,ebx
	and eax,0xff
	STDCALL legsup5,LEGLIST+0x400,eaxstr



	;************************************************
	;USBLEGCTLSTS - (System Management Interrupts)
	;************************************************
	;we move this down here because it depends on eecp
	mov eax,[EHCIBUSDEVFUN] ;get the pci_config_address of ehci
	mov ebx,[eecp]       
	add ebx,4              ;PCIconfig + eecp + 4 = USBLEGCTLSTS
	call pciReadDword      ;eax=dword from port
	STDCALL legctl,LEGLIST+0x500,eaxstr






	;***************************
	;USBCMD - Command Register	
	;***************************
	mov esi,[EHCIOPERBASE]  ;get start of oper reg
	mov eax,[esi+0]  ;OperationalBase + 0 = USBCMD 
	mov ebx,eax      ;copy

	;USBCMD register value
	STDCALL cmd1,CMDLIST,eaxstr

	;Interrupt Threshold Control 
	;max rate at which controller may issue interrupts
	;01h=1 micro-frame
	;40h=64 micro-frames
	mov eax,ebx
	shr eax,16
	and eax,0xf
	STDCALL cmd2,CMDLIST+0x100,eaxstr

	;Asynchronous Schedule Park Mode Enable
	mov eax,ebx
	shr eax,11
	and eax,1
	STDCALL cmd3,CMDLIST+0x200,eaxstr

	;Asynchronous Schedule Park Mode Count
	mov eax,ebx
	shr eax,8
	and eax,11b
	STDCALL cmd4,CMDLIST+0x300,eaxstr

	;Light Host Controller Reset
	mov eax,ebx
	shr eax,7
	and eax,1
	STDCALL cmd5,CMDLIST+0x400,eaxstr

	;Interrupt on Async Advance Doorbell
	mov eax,ebx
	shr eax,6
	and eax,1
	STDCALL cmd6,CMDLIST+0x500,eaxstr

	;Async Schedule Enable
	mov eax,ebx
	shr eax,5
	and eax,1
	STDCALL cmd7,CMDLIST+0x600,eaxstr

	;Periodic Schedule Enable
	mov eax,ebx
	shr eax,4
	and eax,1
	STDCALL cmd8,CMDLIST+0x700,eaxstr

	;Frame List Size
	mov eax,ebx
	shr eax,2
	and eax,11b
	STDCALL cmd9,CMDLIST+0x800,eaxstr

	;Host Controller Reset HCRESET
	mov eax,ebx
	shr eax,1
	and eax,1
	STDCALL cmd10,CMDLIST+0x900,eaxstr

	;Run/Stop
	mov eax,ebx
	and eax,1
	STDCALL cmd11,CMDLIST+0xa00,eaxstr




	;***************************
	;USBSTS - Status Register	
	;***************************
	mov esi,[EHCIOPERBASE]  ;get start of oper reg
	mov eax,[esi+4]  ;OperationalBase + 4 = USBSTS
	mov ebx,eax      ;copy

	;USBSTS register value
	STDCALL sts1,STATUSLIST,eaxstr

	;now we display the bitfields of USBSTS with explanation

	;Asynchronous Schedule Status
	shr eax,15
	and eax,1
	STDCALL sts2,STATUSLIST+0x100,eaxstr

	;Periodic Schedule Status
	mov eax,ebx
	shr eax,14
	and eax,1
	STDCALL sts3,STATUSLIST+0x200,eaxstr

	;Reclamation
	mov eax,ebx
	shr eax,13
	and eax,1
	STDCALL sts4,STATUSLIST+0x300,eaxstr

	;HCHalted
	mov eax,ebx
	shr eax,12
	and eax,1
	STDCALL sts5,STATUSLIST+0x400,eaxstr

	;bits 11:6 are reserved

	;Interrupt on Async Advance
	mov eax,ebx
	shr eax,5
	and eax,1
	STDCALL sts6,STATUSLIST+0x500,eaxstr

	;Host System Error
	mov eax,ebx
	shr eax,4
	and eax,1
	STDCALL sts7,STATUSLIST+0x600,eaxstr

	;Frame List Rollover
	mov eax,ebx
	shr eax,3
	and eax,1
	STDCALL sts8,STATUSLIST+0x700,eaxstr

	;Port Change Detect
	mov eax,ebx
	shr eax,2
	and eax,1
	STDCALL sts9,STATUSLIST+0x800,eaxstr

	;USB Error Interrupt ISBERRINT
	;this bit is set if a TD has failed, often happens during initflash
	mov eax,ebx
	shr eax,1
	and eax,1
	STDCALL sts10,STATUSLIST+0x900,eaxstr

	;USB Interrupt USBNIT
	mov eax,ebx
	and eax,1
	STDCALL sts11,STATUSLIST+0xa00,eaxstr

	;end USBSTS




	;****************************************
	;USBINTR - Interrupt Enable Register	
	;****************************************
	mov esi,[EHCIOPERBASE]  ;get start of oper reg
	mov eax,[esi+8]  ;OperationalBase + 8 = USBINTR 
	STDCALL inten,INTENLIST,eaxstr



	;****************************************
	;CONFIGFLAG - Configure Flag Register	
	;****************************************
	mov esi,[EHCIOPERBASE]     ;get start of oper reg
	mov eax,[esi+0x40]  ;OperationalBase+0x40 = CONFIGFLAG 
	STDCALL conff,CONFFLIST,eaxstr




	;********************************
	;PORTSC - Port Status & Control
	;********************************
	;we dump PORTSC for 4 ports only 
	mov edx,PORTLIST  ;edx=dest address of list control buffer string
	mov esi,[EHCIOPERBASE]
	mov ebx,[esi+44h]  ;OperationalBase + 0x44 = PORTSC(0)
	call ShowPORTSC
	mov ebx,[esi+48h]  ;OperationalBase + 0x48 = PORTSC(1)
	call ShowPORTSC
	mov ebx,[esi+4ch]  ;OperationalBase + 0x4c = PORTSC(2)
	call ShowPORTSC
	mov ebx,[esi+50h]  ;OperationalBase + 0x50 = PORTSC(3)
	call ShowPORTSC




	;now setup the list control
	mov eax,TOTALQTYEHCILISTSTRINGS 
	mov ebx,100 ;Ylocation of listcontrol
	call ListControlInit

.appmainloop:
	call backbufclear
	call ListControlPaint

	;program title
	STDCALL FONT01,0,20,ehcireg,0xefff,puts

	call swapbuf
	call getc

	cmp al,ESCAPE  ;to quit
	jnz .appmainloop

	ret





;*****************************************************
;ShowPORTSC
;input
;ebx=port address = ehci OperationalBase + 44h/48h/4ch/50h
;return
;writes portsc strings to list control buffer
;edx must be preserved as it holds the dest address
;for the list control buffer string
;*****************************************************

ShowPORTSC:


	;PORTSC register value
	mov eax,ebx
	STDCALL port1,edx,eaxstr
	add edx,0x100

	;now the bitfields

	;port owner
	mov eax,ebx
	shr eax,13
	and eax,1
	STDCALL port2,edx,eaxstr
	add edx,0x100

	;port power
	mov eax,ebx
	shr eax,12
	and eax,1
	STDCALL port3,edx,eaxstr
	add edx,0x100

	;line status
	mov eax,ebx
	shr eax,10
	and eax,11b
	cmp eax,1  
	jz .lowspeed
	STDCALL port4a,edx,eaxstr
	jmp .doneLineStatus
.lowspeed:
	STDCALL port4b,edx,eaxstr
.doneLineStatus:
	add edx,0x100

	;Port Reset
	mov eax,ebx
	shr eax,8
	and eax,1
	STDCALL port5,edx,eaxstr
	add edx,0x100

	;Port Suspend
	mov eax,ebx
	shr eax,7
	and eax,1
	STDCALL port6,edx,eaxstr
	add edx,0x100

	;Port Enable
	mov eax,ebx
	shr eax,2
	and eax,1
	STDCALL port7,edx,eaxstr
	add edx,0x100

	;Connect Status
	mov eax,ebx
	and eax,1
	STDCALL port8,edx,eaxstr
	add edx,0x100

	ret




