;tatOS/usb/initdevices.s

;code to reset ports and init usb devices plugged into ports
;the usb controller must first go thru its init sequence
;this function calls initmouse, initkeyboard and initflash
;we support only these devices and only 1 of each

;with uhci we only support two ports 0,1
;with ehci we support four ports 0,1,2,3



port0str db 'PORT0',0
port1str db 'PORT1',0
port2str db 'PORT2',0
port3str db 'PORT3',0
port4str db 'PORT_INVAL',0
port_num_dump:
dd port0str, port1str, port2str, port3str, port4str

portnumHIspeed         dd 0
which_low_speed_device dd 0


usbdevstr0  db '[initdevices]',0
usbdevstr1  db 'usb transaction failure',0
usbdevstr2  db 'usb hub port reset failed',0
usbdevstr3  db 'end init usb devices',0
usbdevstr4  db 'exceeded max port #',0
usbdevstr5  db 'nothing connected',0
usbdevstr6  db 'low speed device connected',0
usbdevstr7  db 'hi  speed device connected',0
usbdevstr8a db 'reset low speed port',0
usbdevstr8b db 'reset hi  speed port',0
usbdevstr9  db 'determining low speed device type',0
usbdevstr10 db 'error detecting low speed device type',0
usbdevstr11 db 'uhci primary',0
usbdevstr12 db 'ehci w/uhci companions',0
usbdevstr13 db 'confirm uhci companion port connect',0
usbdevstr14 db 'error uhci companion port no device connected',0
usbdevstr15 db 'confirm uhci companion port low speed',0
usbdevstr16 db 'error uhci companion port is not low speed',0
usbdevstr18 db 'uhci companion 1 port0',0
usbdevstr19 db 'uhci companion 1 port1',0
usbdevstr20 db 'uhci companion 2 port0',0
usbdevstr21 db 'uhci companion 2 port1',0
usbdevstr22 db 'ehci w/root hub',0
usbdevstr23 db 'root hub wPortStatus return value is invalid',0
usbdevstr24 db 'mouse-GetConfigDescriptor 18 bytes',0
usbdevstr26 db 'low speed device is not a keyboard',0
usbdevstr27 db 'low speed device is not a mouse',0
usbdevstr28 db 'reset port',0
usbdevstr29 db 'invalid flash portnum',0
usbdevstr30 db 'was flash plugged in during low speed device init ?',0



;************************************************
;initdevices

;the usb controllers must have gone thru their init sequence first
;before executing this function

;also you must run this function first to init the low speed devices
;because the portnumber of the hi speed flash drive is found and saved
;then you may init the flash
;the reason we do it this way is because the ehci root hub port must be reset
;before the device speed can be detected
;and this reset will kill any connected low speed device that was previously init

;input: eax=0 init low speed devices
;       eax=1 init hi speed flash drive
;return:none
;***********************************************



initdevices:


	STDCALL usbdevstr0,putscroll


	;if user wants to initflash we jump directly to it
	;portnumber of flash was found while scanning all ports to low speed devices
	cmp eax,1
	jz near .initflash


	;continue on to scan all ports, init low speed devices
	;and save the port number of hi speed devices


	;init port number of flash to some invalid value
	mov dword [portnumHIspeed],0xff


	;0=initmouse, 1=initkeyboard
	mov dword [which_low_speed_device],0  


	;start with PORT#=-1
	mov eax,-1
	mov [portnumber],eax


.incport:

	;increment the port number
	;for uhci we support downstream ports 0,1
	;for ehci w/ companions downstream ports 0,1,2,3
	;for ehci w/ root hub downstream port numbers are 1,2,3,4
	add dword [portnumber],1


	;show the port number: PORT0/PORT1/PORT2/PORT3
	mov eax,[portnumber]
	mov esi,[port_num_dump + eax*4]
	STDCALL esi,putscroll


	;just pause the scrolling strings so user can see the port# 
	mov ebx,3000  ;ms
	call sleep


;***********************************************************
%if  USBCONTROLLERTYPE == 0  ;uhci primary

	STDCALL usbdevstr11,putscroll

	;have we exceeded the max port number ?
	;uhci supports two ports: 0,1
	cmp dword [portnumber],1
	ja near .exceededMaxPortNum
	;this is the normal way to break out of initdevices


	;check the port for something connected
	mov eax,[portnumber]
	call uhci_portconnect
	jc .1    ;have device connect
	STDCALL usbdevstr5,putscroll  
	jmp .incport

.1:
	;check the port for low speed device connect
	mov eax,[portnumber]
	call uhci_portlowspeed
	;zf is set if low speed device attached
	jz .2


	;if we got here the connected device is hi speed
	;save the portnumber of hi speed device and continue with next port
	STDCALL usbdevstr7,putscroll  
	mov eax,[portnumber]
	mov dword [portnumHIspeed],eax
	jmp .incport


.2: 
	;if we got here the connected device is low speed
	STDCALL usbdevstr6,putscroll  
	;continue


.resetport:

	;reset the port
	;once you reset a port you must go thru the complete device init sequence
	STDCALL usbdevstr8a,putscroll
	mov eax,[portnumber]
	call uhci_portreset

%endif
;***********************************************************

;***********************************************************
%if  USBCONTROLLERTYPE == 1  ;ehci with uhci companion controllers

	STDCALL usbdevstr12,putscroll

	;have we exceeded the max portnumber ?
	;our ehci supports four ports: 0,1,2,3
	cmp dword [portnumber],3
	ja near .exceededMaxPortNum
	;this is the normal way to break out of initdevices


	;check the port for something connected
	mov eax,[portnumber]
	call ehci_portconnect
	jc .1    ;have device connect
	STDCALL usbdevstr5,putscroll  
	jmp .incport
.1:


	;check the ehci port for low speed device connect
	mov eax,[portnumber]
	call ehci_portlowspeed
	;zf is set if low speed device attached
	jz .2


	;if we got here the connected device is hi speed
	;save the portnumber of hi speed device and continue with next port
	STDCALL usbdevstr7,putscroll  
	mov eax,[portnumber]
	mov dword [portnumHIspeed],eax
	jmp .incport



.2: 
	;LOW speed device connect
	;************************
	;if we got here the connected device is low speed
	STDCALL usbdevstr6,putscroll  
	;continue

	;release ownership of port to uhci
	mov eax,[portnumber]
	call ehci_release_ownership

	;reset the low speed port
	;we make the following assumptions:
	;ehci port #0 = uhci #1 port0
	;ehci port #1 = uhci #1 port1
	;ehci port #2 = uhci #2 port0
	;ehci port #3 = uhci #2 port1

.resetport:

	cmp dword [portnumber],0
	jz near .uhci1port0
	cmp dword [portnumber],1
	jz near .uhci1port1
	cmp dword [portnumber],2
	jz near .uhci2port0
	cmp dword [portnumber],3
	jz near .uhci2port1
	jmp near .errorCompanionPort 


.uhci1port0:

	STDCALL usbdevstr18,putscroll

	;set UHCIBASEADD for uhci #1
	mov eax,[UHCIBUSDEVFUNCOM1]
	call uhcibaseaddress  

	;confirm uhci device connect
	STDCALL usbdevstr13,putscroll
	mov eax,0  ;port0
	call uhci_portconnect
	jc .3    ;have device connect
	STDCALL usbdevstr14,putscroll 
	jmp near .errorCompanionPort
.3:

	;check for uhci low speed
	STDCALL usbdevstr15,putscroll
	mov eax,0  ;port0
	call uhci_portlowspeed
	jz .4
	STDCALL usbdevstr16,putscroll
	jmp near .errorCompanionPort
.4:

	;reset low speed port
	STDCALL usbdevstr8a,putscroll
	mov eax,0  ;port0
	call uhci_portreset

	jmp .ehci1done



.uhci1port1:

	STDCALL usbdevstr19,putscroll

	;set UHCIBASEADD for uhci #1
	mov eax,[UHCIBUSDEVFUNCOM1]
	call uhcibaseaddress  

	;confirm uhci device connect
	STDCALL usbdevstr13,putscroll
	mov eax,1  ;port1
	call uhci_portconnect
	jc .5    ;have device connect
	STDCALL usbdevstr14,putscroll 
	jmp near .errorCompanionPort
.5:

	;check for uhci low speed
	STDCALL usbdevstr15,putscroll
	mov eax,1   ;port1
	call uhci_portlowspeed
	jz .6
	STDCALL usbdevstr16,putscroll
	jmp near .errorCompanionPort
.6:

	;reset low speed port
	STDCALL usbdevstr8a,putscroll
	mov eax,1  ;port1
	call uhci_portreset

	jmp .ehci1done



.uhci2port0:

	STDCALL usbdevstr20,putscroll

	;set UHCIBASEADD for uhci #2
	mov eax,[UHCIBUSDEVFUNCOM2]
	call uhcibaseaddress  

	;confirm uhci device connect
	STDCALL usbdevstr13,putscroll
	mov eax,0  ;port0
	call uhci_portconnect
	jc .7    ;have device connect
	STDCALL usbdevstr14,putscroll 
	jmp near .errorCompanionPort
.7:

	;check for uhci low speed
	STDCALL usbdevstr15,putscroll
	mov eax,0  ;port0
	call uhci_portlowspeed
	jz .8
	STDCALL usbdevstr16,putscroll
	jmp near .errorCompanionPort
.8:

	;reset low speed port
	STDCALL usbdevstr8a,putscroll
	mov eax,0  ;port0
	call uhci_portreset

	jmp .ehci1done



.uhci2port1:

	STDCALL usbdevstr21,putscroll

	;set UHCIBASEADD for uhci #2
	mov eax,[UHCIBUSDEVFUNCOM2]
	call uhcibaseaddress  

	;confirm uhci device connect
	STDCALL usbdevstr13,putscroll
	mov eax,1  ;port1
	call uhci_portconnect
	jc .9    ;have device connect
	STDCALL usbdevstr14,putscroll 
	jmp near .errorCompanionPort
.9:

	;check for uhci low speed
	STDCALL usbdevstr15,putscroll
	mov eax,1   ;port1
	call uhci_portlowspeed
	jz .10
	STDCALL usbdevstr16,putscroll
	jmp near .errorCompanionPort
.10:

	;reset low speed port
	STDCALL usbdevstr8a,putscroll
	mov eax,1  ;port1
	call uhci_portreset

	;fall thru


.ehci1done:

%endif
;***********************************************************

;***********************************************************
%if  USBCONTROLLERTYPE == 2  ;ehci with root hub

	STDCALL usbdevstr22,putscroll

	;have we exceeded the max portnumber ?
	;root hub downstream ports are 1,2,3,4 
	;so we have to accomodate this by adding +1 to [portnumber]
	cmp dword [portnumber],3
	ja near .exceededMaxPortNum
	;this is the normal way to break out of initdevices


.resetport:

	;reset the hub downstream port
	STDCALL usbdevstr28,putscroll
	mov eax,[portnumber]
	add eax,1  ;because hub port starts with 1
	call HubPortReset
	cmp eax,1
	jz near .errorTransaction


	;get Hub Port Status wPortStatus
	;0x503=device present, port enabled, port has power, hi speed device attached
	;0x303=device present, port enabled, port has power, low speed device attached
	;0x100=nothing connected
	mov eax,[portnumber]
	add eax,1  ;because hub port starts with 1
	call HubGetPortStatus  
	;returns ebx=wPortChangewPortStatus, eax=0 on success, 1=transaction error

	cmp eax,1
	jz near .errorTransaction
	cmp ebx,0x100  
	jz near .nothingconnected
	cmp ebx,0x110503
	jz .foundHIspeed
	cmp ebx,0x110303
	jz .foundLOspeed
	;if we got here we have some unknown hub status
	jmp near .errorHubPortStatus


.nothingconnected:
	STDCALL usbdevstr5,putscroll  
	jmp near .incport


.foundHIspeed:
	;if we got here the connected device is hi speed
	;save the portnumber of hi speed device and continue with next port
	STDCALL usbdevstr7,putscroll  
	mov eax,[portnumber]
	mov dword [portnumHIspeed],eax
	jmp .incport


.foundLOspeed:
	;if we got here the connected device is low speed
	STDCALL usbdevstr6,putscroll  
	;continue


.ehci2done:
	
%endif
;***********************************************************

;***********************************************************
%if  USBCONTROLLERTYPE == 3  ;ehci only
	;I put this code label in here to keep nasm quiet
	;in truth you can not run a mouse on ehci only 
	;ehci does not support low speed usb 1.0 devices like the mouse
	;but this file needs a .resetport code label for every USBCONTROLLERTYPE
	.resetport:
%endif
;***********************************************************



	;at this point the dword [portnumber] is known and the port is reset
	;uhci & ehci w/companions = dword [portnumber]
	;ehci w/root hub          = dword [portnumber]+1
	;if its a hi speed device we saved portnumHIspeed and continued to next port


	;LOW SPEED device detection code
	;if we got here we have a low speed device
	;dont know if its keyboard or mouse
	STDCALL usbdevstr9,putscroll

	;in theory we could have an infinite loop here
	;initmouse    bInterfaceProtocol could respond "not mouse"    so we try keyboard
	;initkeyboard bInterfaceProtocol could respond "not keyboard" so we try mouse
	;I think the likely hood of this occuring is very small
	;remember we only support 1 keyboard and 1 mouse
	cmp dword [which_low_speed_device],0  
	jz .initmouse
	cmp dword [which_low_speed_device],1  
	jz .initkeyboard

	jmp near .errorLowSpeed




.initmouse:

%if USBCONTROLLERTYPE == 2  ;ehci w/root hub
	mov eax,[portnumber]
	add eax,1  ;because hub port starts with 1
%endif

	call initmouse
	;return: eax=0 success, device is a mouse, all transactions successful
	;        eax=1 usb transaction error
	;        eax=2 usb device is not a mouse

	cmp eax,0
	jz near .mousesuccess
	cmp eax,1
	jz near .errorTransaction
	cmp eax,2
	jz .notmouse

.mousesuccess:
	mov dword [which_low_speed_device],1  ;1=try initkeyboard
	jmp near .incport

.notmouse:
	;if we got here the low speed device was not a mouse
	;so we go back, reset the port and try the keyboard
	STDCALL usbdevstr27,putscroll
	mov dword [which_low_speed_device],1  ;1=try initkeyboard
	jmp .resetport





.initkeyboard:

%if USBCONTROLLERTYPE == 2  ;ehci w/root hub
	mov eax,[portnumber]
	add eax,1  ;because hub port starts with 1
%endif

	call initkeyboard
	;return: eax=0 success, device is a keyboard, all transactions successful
	;        eax=1 usb transaction error
	;        eax=2 usb device is not a keyboard
	
	cmp eax,0
	jz .keyboardsuccess
	cmp eax,1
	jz near .errorTransaction
	cmp eax,2
	jz .notkeyboard

.keyboardsuccess:
	mov dword [which_low_speed_device],0  ;0=try initmouse
	jmp near .incport

.notkeyboard:
	;the low speed device was not a keyboard
	;so we go back, reset the port and try the mouse
	STDCALL usbdevstr26,putscroll
	mov dword [which_low_speed_device],0  ;0=try initmouse
	jmp .resetport





.initflash:

	;the port number of the flash was determined during the 
	;scan/init of low speed devices
	STDCALL usbdevstr8b,putscroll  ;reset hi speed port

	;do we have a valid portnum ? (did user forget to plug in flash ?)
	cmp dword [portnumHIspeed],0xff
	jz near .errorFlashPortNum


%if  USBCONTROLLERTYPE == 0  ;uhci primary
	mov eax,[portnumHIspeed]
	call uhci_portreset  ;eax=portnum
%endif

%if  USBCONTROLLERTYPE == 1  ;ehci with uhci companion controllers
	mov eax,[portnumHIspeed]
	call ehci_portreset  ;eax=portnum
%endif

%if  USBCONTROLLERTYPE == 2  ;ehci with root hub
	;if you pull out your tatOS boot flash and plug in your tatOS FAT formated flash
	;the hub port loses power so...
	mov eax,[portnumHIspeed]
	add eax,1  ;because hub port starts with 1
	call HubPortPower
	
	mov eax,[portnumHIspeed]
	add eax,1  ;because hub port starts with 1
	call HubPortReset  

	cmp eax,1
	jz near .errorTransaction
%endif


	call initflash
	jmp near .done




.errorFlashPortNum:
	STDCALL usbdevstr29,putscroll
	STDCALL usbdevstr30,putscroll
	mov eax,1
	jmp .done
.errorHubPortStatus:
	STDCALL usbdevstr23,putscroll
	STDCALL usbdevstr23,dumpstr
	mov eax,1
	jmp .done
.errorCompanionPort:
	STDCALL usbdevstr2,putscroll
	STDCALL usbdevstr2,dumpstr
	mov eax,1
	jmp .done
.errorLowSpeed:
	STDCALL usbdevstr10,putscroll
	STDCALL usbdevstr10,dumpstr
	mov eax,1
	jmp .done
.exceededMaxPortNum:
	;this is the normal exit, may not be error
	STDCALL usbdevstr4,putscroll
	STDCALL usbdevstr4,dumpstr
	mov eax,1
	jmp .done
.errorTransaction:
	STDCALL usbdevstr1,putscroll
	STDCALL usbdevstr1,dumpstr
	mov eax,1
	STDCALL pressanykeytocontinue,putscroll
	jmp .done
.hubportresetfailed:
	STDCALL usbdevstr2,putscroll
	STDCALL usbdevstr2,dumpstr
	mov eax,1
	;fall thru
.done:
	push eax
	STDCALL usbdevstr3,putscroll
	STDCALL pressanykeytocontinue,putscroll
	call getc
	pop eax
	ret

