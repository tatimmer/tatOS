;tatOS/usb/usbcentral.s


;a utility executed from the shell to init the usb controller and connected devices

;conditional assembly will present to the user only 1 option for controlling
;the flash drive, keyboard and mouse 
;you must set an appropriate value for USBCONTROLLERTYPE in tatOS.config
;and reassemble for your hardware


usbcen_menu:
db 'USB CENTRAL',NL
db '***********',NL
db NL

%if USBCONTROLLERTYPE == 0
db 'USBCONTROLLERTYPE == 0',NL
db 'UHCI primary: INTEL 8086 did=7112 bus:dev:fun 00:07:02',NL
db NL
db 'F9      = show UHCI primary controller registers',NL
%endif

%if USBCONTROLLERTYPE == 1
db 'USBCONTROLLERTYPE == 1',NL
db 'EHCI with UHCI companion controllers: VIA pci card vid=1106',NL
db 'ehci    bus:dev:fun 00:10:02',NL
db 'uhci #1 bus:dev:fun 00:10:00',NL
db 'uhci #2 bus:dev:fun 00:10:01',NL
db NL
db 'F8      = show EHCI controller registers',NL
db 'F10     = show UHCI companion controller #1 registers',NL
db 'F11     = show UHCI companion controller #2 registers',NL
%endif

%if USBCONTROLLERTYPE == 2
db 'USBCONTROLLERTYPE == 2',NL
db 'EHCI with root hub: INTEL 8086 bus:dev:fun 00:1a/1d:00',NL
db NL
db 'F4      = hub downstream port status wPortStatus',NL
db 'F8      = show EHCI controller registers',NL
%endif

%if USBCONTROLLERTYPE == 3
db 'USBCONTROLLERTYPE == 3',NL
db 'EHCI only no usb 1.0 support',NL
db NL
db 'F8      = show EHCI controller registers',NL
%endif

db NL
db 'F1      = init usb controller & low speed devices',NL
db 'F2      = init flash drive',NL
db 'F6      = format flash drive with tatOS FAT16 no partition',NL
db 'F7      = show usb mouse report',NL
db 'Ctrl+F7 = show usb keyboard report',NL
db 'F12     = scan pci bus to get usb controllers bus:dev:fun',NL
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
usbcen11 db '[usbcentral] calling initdevices:low speed',0
usbcen12 db '[usbcentral] calling initdevices:hi  speed',0


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



.F1:  ;init usb controller & low speed devices

%if USBCONTROLLERTYPE == 0   ;uhci only
	mov bl,UHCI_BUS
	mov cl,UHCI_DEV
	mov dl,UHCI_FUN
	call build_pci_config_address  ;return value in eax
	mov [UHCIBUSDEVFUN],eax        ;save for later
	call initUHCI
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

	;the Lenovo does not have a ps2 port so we only have the usb keyboard
	;when it boots up the usb keyboard is controlled by bios
	;once we init the ehci the usb keyboard is dead so we must
	;immediately detect the keyboard and init it otherwise we have no control

	STDCALL usbcen11,putscroll
	mov eax,0  ;low speed devices
	call initdevices
	jmp UsbCentral



.F2:
	STDCALL usbcen12,putscroll
	mov eax,1  ;hi speed flash drive
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








