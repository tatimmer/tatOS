;tatOS/usb/usbcentral.s

;rev: Dec 29, 2015

;a utility executed from the shell

; * init ehci only with no usb 1.0 support
; * init ehci with uhci companion controllers
; * init ehci with root hub
; * init usb flash drive
; * show controller registers and bitfields
; * init usb mouse
; * show mouse report
; * format usb flash drive

;Feb 2015
;This code is now usb controller hardware dependent
;there are 3 differant hdwre approaches to using the usb flash drive and mouse
;1) Via pci addon card with EHCI and UHCI companion controllers
;2) old computer Intel UHCI with only 2 ports on the machine
;3) new laptop Acer with EHCI and root hub
;you must set USBCONTROLLERTYPE in tatOS.config and reassemble


usbcen_menu:
db 'USB CENTRAL',NL
db '***********',NL
db NL

;conditional assembly will present to the user only 1 of 4 options for controlling
;the flash drive and mouse, the USBCONTROLLERTYPE is set in tatOS.config

%if USBCONTROLLERTYPE == 0
db 'USBCONTROLLERTYPE == 0',NL
db 'UHCI primary: INTEL 8086 did=7112 bus:dev:fun 00:07:02',NL
db NL
db 'F1=init UHCI',NL
db 'F9=Show UHCI Primary Controller Registers',NL
%endif

%if USBCONTROLLERTYPE == 1
db 'USBCONTROLLERTYPE == 1',NL
db 'EHCI with UHCI companion controllers: VIA pci card vid=1106',NL
db 'ehci    bus:dev:fun 00:10:02',NL
db 'uhci #1 bus:dev:fun 00:10:00',NL
db 'uhci #2 bus:dev:fun 00:10:01',NL
db NL
db 'F1=init EHCI & UHCI companions',NL
db 'F8=Show EHCI Controller Registers',NL
db 'F10=Show UHCI Companion Controller #1 Registers',NL
db 'F11=Show UHCI Companion Controller #2 Registers',NL
%endif

%if USBCONTROLLERTYPE == 2
db 'USBCONTROLLERTYPE == 2',NL
db 'EHCI with root hub: INTEL 8086 bus:dev:fun 00:1d:00',NL
db NL
db 'F1=init EHCI & root hub',NL
db 'F4=hub downstream port status wPortStatus',NL
db 'F8=Show EHCI Controller Registers',NL
%endif

%if USBCONTROLLERTYPE == 3
db 'USBCONTROLLERTYPE == 3',NL
db 'EHCI only no usb 1.0 support',NL
db NL
db 'F1=init EHCI only',NL
db 'F8=Show EHCI Controller Registers',NL
%endif

db 'F2      = init usb devices: flash, keyboard, mouse',NL
db 'F6      = Format Flash Drive with tatOS FAT16 no partition',NL
db 'F7      = Show usb mouse report',NL
db 'Ctrl+F7 = Show usb keyboard report',NL
db 'F12     = Scan PCI bus for all usb controllers',NL
db 'ESC     = quit',NL
db 0




usbcen1 db 'UHCI Primary USB controller pci config address',0
usbcen2 db 'EHCI USB controller pci config address',0
usbcen3 db 'UHCI Companion #1 USB controller pci config address',0
usbcen4 db 'UHCI Companion #2 USB controller pci config address',0
usbcen5 db 'initting UHCI companion #1',0
usbcen6 db 'initting UHCI companion #2',0
usbcen7 db 'Flash drive LBAmax',0
usbcen8 db 'Flash drive max cluster',0
usbcen9 db 'Flash drive bytes per block',0
usbcen10 db 'Flash drive capacity, bytes',0


LEFTMARGIN equ 50




UsbCentral:

	;begin paint
	call backbufclear 

	;display our menu
	STDCALL FONT01,LEFTMARGIN,50,usbcen_menu,0xefff,putsml

	;display some flash drive parameters like 
	;LBAmax, max cluster, bytesperblock, capacity
	STDCALL FONT01,LEFTMARGIN,400,usbcen7,0xefff,puts
	mov eax,[flashdriveLBAmax]  ;scsi ReadCapacity gives us this value
	push eax
	STDCALL 350,400,0xf0ff,0,puteaxdec

	;max cluster
	pop eax
	shr eax,6  ;tatOS cluster = LBA/64
	STDCALL 350,420,0xf0ff,0,puteaxdec
	STDCALL FONT01,LEFTMARGIN,420,usbcen8,0xefff,puts

	;bytes per block
	STDCALL FONT01,LEFTMARGIN,440,usbcen9,0xefff,puts
	mov eax,[flashdriveBytesPerBlock]
	STDCALL 350,440,0xf0ff,0,puteaxdec

	;capacity, bytes
	STDCALL FONT01,LEFTMARGIN,460,usbcen10,0xefff,puts
	mov eax,[flashdriveCapacityBytes]
	STDCALL 350,460,0xf0ff,0,puteaxdec



	

	call swapbuf  
	;end paint



	call getc

	cmp al,ESCAPE
	jz near .quit
	cmp al,F1
	jz near .F1
	cmp al,F2
	jz near .F2
	cmp al,F4
	jz near .F4
	cmp al,F6
	jz near .F6
	cmp al,F7
	jz near .F7
	cmp al,F8
	jz near .F8
	cmp al,F9
	jz near .F9
	cmp al,F10
	jz near .F10
	cmp al,F11
	jz near .F11
	cmp al,F12
	jz near .F12

	;handle all other keystrokes
	jmp UsbCentral



.F1:  ;init usb controller

	%if USBCONTROLLERTYPE == 0   ;uhci only
	mov bl,UHCI_BUS
	mov cl,UHCI_DEV
	mov dl,UHCI_FUN
	call build_pci_config_address  ;return value in eax
	mov [UHCIBUSDEVFUN],eax        ;save for later
	call initUHCI
	STDCALL pressanykeytocontinue,putscroll  
	call getc
	%endif

	%if USBCONTROLLERTYPE == 1 
	call init_EHCI_with_companion
	%endif

	%if USBCONTROLLERTYPE == 2 
	call init_EHCI_with_roothub
	%endif

	%if USBCONTROLLERTYPE == 3  
	call init_EHCI_only
	%endif


	jmp UsbCentral





.F2:  ;init flash drive, keyboard & mouse
	call initdevices
	jmp UsbCentral



.F4:
	;call a function to build strings for list box
	call showehciroothubports
	jmp UsbCentral



.F6:  ;format flash drive
	call fatformatdrive
	jmp UsbCentral

.F7:
	cmp byte [CTRLKEYSTATE],1
	jz .showkeyboardreport
	call usbShowMouseReport
	jmp UsbCentral
.showkeyboardreport:
	call usbShowKeyboardReport
	jmp UsbCentral


.F8:
	call show_ehci_reg
	jmp UsbCentral

.F9:
	mov eax,[UHCIBUSDEVFUN]
	call show_uhci_reg
	jmp UsbCentral

.F10:
	mov eax,[UHCIBUSDEVFUNCOM1]
	call show_uhci_reg
	jmp UsbCentral

.F11:
	mov eax,[UHCIBUSDEVFUNCOM2]
	call show_uhci_reg
	jmp UsbCentral

.F12:
	call pci_detect_usb_controllers
	call dumpview
	jmp UsbCentral

.quit:
	ret








