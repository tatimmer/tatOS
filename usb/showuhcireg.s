;tatOS/usb/showuhcireg.s


;**********************************************************************
;show_uhci_reg
;code to display the register values and bitfields of the UHCI
;this code is based on show_ehci_reg
;input:eax = BUS:DEV:FUN pci config address of UHCI controller
;            this may be a UHCI primary controller or a companion controller
;            in tatos the permissable values for eax are:
;            [UHCIBUSDEVFUN],[UHCIBUSDEVFUNCOM1],[UHCIBUSDEVFUNCOM2]
;return:none
;**********************************************************************

;Program Title
uhcireg db 'USB UHCI Controller PCI & I/O Space Registers',0


;STATUS-COMMAND
ustatcom1 db 'PCI: STATUS-COMMAND',0
ustatcom2 db 'Bus Master enable',0
ustatcom3 db 'I/O Space enable',0

;CLASSC-SUBCLA-PROGINT-REVID
uclass1 db 'PCI: ClassCode, SubClass, ProgrammingInterface, RevisionID',0

;BIST-HEADER-LATENCY-CACHE
uheader db 'PCI: BIST, PCIHeaderType,(00=common), LatencyTimer, CacheLineSize',0

;USBBASE
uubase1 db 'PCI: USBBASE - EHCI Base Address',0
uubase2 db 'Base Address Type (0=32bit, 2=64bit)',0

;USBCMD-Command Register
ucmd1 db 'USBCMD - COMMAND REGISTER',0
ucmd2 db '    max packet size (1=64, 0=32)',0
ucmd3 db '    run/stop',0

;USBSTS-Status Register
usts1 db 'USBSTS - STATUS REGISTER',0
usts2 db '    Halted (set=1 by controller after it has stopped)',0
usts3 db '    Host Controller Process Error',0
usts4 db '    Host System Error',0
usts5 db '    USB Error Interrupt (1=transaction error)',0
usts6 db '    USB Interrupt (1=TD complete if IOC bit set)',0

;USBINTR - Interrupt Enable
uinten db 'USBINTR- INTERRUPT ENABLE',0

;PORTSC-Port Status & Control
uport1 db 'PORTSC(n) - PORT STATUS & CONTROL',0
uport2 db '    low speed device attached',0
uport3 db '    port enabled',0
uport4 db '    port connected',0



;define start of strings in list control buffer
;each string starts 0x100 after previous
UBSDVFNLIST equ 0x2950000
UDEVENLIST  equ UBSDVFNLIST+0x100
USTCOMLIST  equ UDEVENLIST+0x200
UCLASSLIST  equ USTCOMLIST+0x300
UHEADRLIST  equ UCLASSLIST+0x100
UUBASELIST  equ UHEADRLIST+0x100
UCMDLIST    equ UUBASELIST+0x100
USTATUSLIST equ UCMDLIST+0x300
UINTENLIST  equ USTATUSLIST+0x600
UPORTLIST   equ UINTENLIST+0x100

TOTALQTYUHCILISTSTRINGS equ 27

;local variable storage for the uhci bus:dev:fun value
uhcibusdevfun dd 0
;******************************************************************

show_uhci_reg:

	;first save the uhci bus:dev:fun to our local storage
	mov [uhcibusdevfun],eax


	;display the BUS:DEV:FUN number of the uhci controller
	;eax=[uhcibusdevfun]
	mov edi,UBSDVFNLIST     ;dest address of string
	call BusDevFunString



	;********************************************
	;DEVICEID-VENDORID
	;********************************************
	mov eax,[uhcibusdevfun]
	mov ebx,0  ;PCIconfig + 0 = DEVICEID
	call pciReadDword
	STDCALL devid1,UDEVENLIST,eaxstr
	and eax,0xffff  ;mask off devid

	;vendor name string
	cmp ax,0x8086
	jnz .trynVidia
	STDCALL devid2a,UDEVENLIST+0x100,eaxstr
	jmp .doneVID
.trynVidia:
	cmp ax,0x10de
	jnz .tryViaTech
	STDCALL devid2b,UDEVENLIST+0x100,eaxstr
	jmp .doneVID
.tryViaTech:
	cmp ax,0x1106
	jnz .unknownVID
	STDCALL devid2c,UDEVENLIST+0x100,eaxstr
	jmp .doneVID
.unknownVID:
	STDCALL devid2d,UDEVENLIST+0x100,eaxstr
.doneVID:



	;********************************************
	;STATUS-COMMAND
	;********************************************
	mov eax,[uhcibusdevfun]
	mov ebx,4  ;PCIconfig + 4 = STATUS
	call pciReadDword
	mov ebx,eax   ;copy
	STDCALL ustatcom1,USTCOMLIST,eaxstr

	;bus master enable 
	mov eax,ebx
	shr eax,2
	and eax,1
	STDCALL ustatcom2,USTCOMLIST+0x100,eaxstr

	;i/o space enable
	mov eax,ebx
	and eax,1
	STDCALL ustatcom3,USTCOMLIST+0x200,eaxstr



	;********************************************
	;CLASSC-SUBCLA-PROGINT-REVID
	;********************************************
	mov eax,[uhcibusdevfun]
	mov ebx,8  ;PCIconfig + 8 = CLASSC  
	call pciReadDword
	STDCALL class1,UCLASSLIST,eaxstr



	;********************************************
	;BIST-HEADER-LATENCY-CACHE
	;********************************************
	mov eax,[uhcibusdevfun]
	mov ebx,0x0c  ;PCIconfig + 0ch 
	call pciReadDword
	STDCALL header,UHEADRLIST,eaxstr



	;********************************************
	;USBBASE - UHCI Base Address
	;********************************************
	mov eax,[uhcibusdevfun]
	mov ebx,0x20  ;PCIconfig + 0x20 = USBBA 
	call pciReadDword
	and eax,0xfffffffe     ;mask off bits 4:0
	mov [UHCIBASEADD],eax  ;save
	STDCALL ubase1,UUBASELIST,eaxstr



	;done with PCI
	;now we deal with the Host Controller port I/O Space Registers



	;***************************
	;USBCMD - Command Register	
	;***************************
	mov dx,[UHCIBASEADD]
	in ax,dx   ;read in USBCMD
	and eax,0xffff  
	mov ebx,eax    ;copy
	STDCALL ucmd1,UCMDLIST,eaxstr

	;max packet MAXP
	mov eax,ebx
	shr eax,7
	and eax,1
	STDCALL ucmd2,UCMDLIST+0x100,eaxstr

	;Run/Stop
	mov eax,ebx
	and eax,1
	STDCALL ucmd3,UCMDLIST+0x200,eaxstr




	;***************************
	;USBSTS - Status Register	
	;***************************
	mov dx,[UHCIBASEADD]
	add dx,2
	in ax,dx  ;read in USBSTS
	and eax,0xffff  
	mov ebx,eax    ;copy
	STDCALL usts1,USTATUSLIST,eaxstr

	;halted
	mov eax,ebx
	shr eax,5
	and eax,1
	STDCALL usts2,USTATUSLIST+0x100,eaxstr

	;Host controller process error
	mov eax,ebx
	shr eax,4
	and eax,1
	STDCALL usts3,USTATUSLIST+0x200,eaxstr

	;Host System Error
	mov eax,ebx
	shr eax,3
	and eax,1
	STDCALL usts4,USTATUSLIST+0x300,eaxstr

	;USB Error Interrupt 
	mov eax,ebx
	shr eax,1
	and eax,1
	STDCALL usts5,USTATUSLIST+0x400,eaxstr

	;USB Interrupt 
	mov eax,ebx
	and eax,1
	STDCALL usts6,USTATUSLIST+0x500,eaxstr





	;****************************************
	;USBINTR - Interrupt Enable Register	
	;****************************************
	mov dx,[UHCIBASEADD]
	add dx,4
	in ax,dx  ;read in USBINTR
	and eax,0xffff  
	STDCALL uinten,UINTENLIST,eaxstr



	;********************************
	;PORTSC - Port Status & Control
	;********************************
	;1st port
	mov dx,[UHCIBASEADD]
	add dx,10h  ;first port
	in ax,dx    ;read in PORTSC(0)
	and eax,0xffff  
	mov ebx,eax ;copy
	STDCALL uport1,UPORTLIST,eaxstr

	;port(0) low speed device
	mov eax,ebx
	shr eax,8
	and eax,1
	STDCALL uport2,UPORTLIST+0x100,eaxstr

	;port(0) enabled
	mov eax,ebx
	shr eax,2
	and eax,1
	STDCALL uport3,UPORTLIST+0x200,eaxstr

	;port(0) connected
	mov eax,ebx
	and eax,1
	STDCALL uport4,UPORTLIST+0x300,eaxstr



	;2nd port
	mov dx,[UHCIBASEADD]
	add dx,12h  ;first port
	in ax,dx    ;read in PORTSC(1)
	and eax,0xffff  
	mov ebx,eax ;copy
	STDCALL uport1,UPORTLIST+0x400,eaxstr

	;port(1) low speed device
	mov eax,ebx
	shr eax,8
	and eax,1
	STDCALL uport2,UPORTLIST+0x500,eaxstr

	;port(1) enabled
	mov eax,ebx
	shr eax,2
	and eax,1
	STDCALL uport3,UPORTLIST+0x600,eaxstr

	;port(1) connected
	mov eax,ebx
	and eax,1
	STDCALL uport4,UPORTLIST+0x700,eaxstr


	


	;now setup the list control
	mov eax,TOTALQTYUHCILISTSTRINGS 
	mov ebx,100 ;Ylocation of listcontrol
	call ListControlInit

.appmainloop:
	call backbufclear
	call ListControlPaint

	;program title
	STDCALL FONT01,0,20,uhcireg,0xefff,puts

	call swapbuf
	call getc

	cmp al,ESCAPE  ;to quit
	jnz .appmainloop

	ret





