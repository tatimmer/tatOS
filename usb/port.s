;tatOS/usb/port.s


;various routines to deal with the usb "ports"

;uhci_portreset
;ehci_portreset
;uhci_portconnect
;ehci_portconnect
;ehci_portlowspeed
;uhci_portlowspeed
;ehci_portread
;uhci_portread	
;uhci_portdump 
;ehci_portdump
;uhci_portscan 
;ehci_portscan
;ehci_release_ownership


;a "port" is where you plug your device (mouse,flash drive) into
;there is some confusion about port numbering depending on what docs you read
;some say port num starts with 0 and others start with 1
;the EHCI docs for example use port nums starting with 1
;tatOS uses port numbers starting with 0

;so UHCI has 2 ports 0,1

;EHCI generally has 4 or more "root" ports starting with 0,1,2,3...

;if you have EHCI with integrated root hub (i.e. rate matching hub)
;then the commands in this file to reset a port only work on the "upstream" port
;The upstream port is the invisible port between ehci and hub
;The downstream hub ports are the 4 ports you plug your devices into
;these downstream ports do not respond to commands in this file
;you must you usb hub class commands to reset these downstream ports
;see hubport.s
;these downstream hub ports are numbered starting with 1,2,3,4


;run this after resetting the controller
;also if your communication with the device gets screwed up 
;the only solution I found is to do this:
;	*resetport
;   *run SetAddress
;	*if SetAddress fails then resetport again
;now SetAddress should pass and you can SetConfig and use the device. 

;note this code is for ports that are directly controlled by ehci or uhci registers
;this code is not for "hub" ports (see hubport.s)


portstr2 db 'Device NOT connected on port',0
portstr3 db 'PORTSC(n) Device connected on requested port',0
portstr4 db 'PORTSC(n) status/control',0
portstr5 db 'port owner, 0=ehci, 1=CompanionController',0
portstr6 db 'port power',0
portstr7 db 'line status, (for ehci: 1=LO speed release ownership)',0
portstr8 db 'reset',0
portstr9 db 'suspend',0
portstr10 db 'enabled',0
portstr11 db 'connect status',0
portstr12 db 'Low speed device attached',0
portstr13 db 'connect status change',0
portstr14 db 'enable/disable change',0
portstr15 db 'over current',0



;************************************************************************
;uhci_portreset 
;reset a UHCI port
;input :eax=port number 0,1
;return:none
uportstr1 db 'uhci_portreset: port number',0
;Apr 2015 added a little more time for sleeps
;***********************************************************************

uhci_portreset:

	push eax  ;save portnum for later
	STDCALL uportstr1,0,dumpeax

	;get the port i/o address into dx
	mov dx,[UHCIBASEADD]
	add dx,0x10
	shl ax,1  ;+0 or +2 gives us 0x10 or 0x12
	add dx,ax

	;first reset PORT
	mov ax,0x200  ;bit9 is reset
	out dx,ax     

	;pause while the reset signal is active
	mov ebx,200
	call sleep

	;write all zeros to the register
	mov ax,0
	out dx,ax     

	;pause again
	mov ebx,100
	call sleep
	
	;enable PORT
	mov ax,1110b  ;enablechange + enable + connectchange
	out dx,ax    

	;pause 1 more time
	mov ebx,200
	call sleep

	;dump PORTSC
	pop eax
	call uhci_portread


	ret





;********************************************************************
;ehci_portreset
;reset an EHCI port
;input :eax=port number 0,1,2,3...
;return:none

;the ehci ports are at OpBase + 44h, 48h, 4ch, 50h
;the ehci controller must be running (HCHalted bit = 0 of USBSTS)
;before resetting a port

;I recommend reading the Intel EHCI Programmers Reference Manual
;it documents the various ports states for various device speeds
;a few simple rules:

;  * you must not perform ehci reset on a low speed device
;    usb 1.1 devices do not operate at the signal rates of usb 2.0
;  * the port must be disabled first, dont reset an enabled port
;  * reset signal must be active for at least 50ms (see usb 2.0 spec)
;  * wait at least 10ms after reset before issuing first usb transaction
;  * if port is enabled and connected then we have hi speed
;  * if port is not enabled and connected then we have full speed


eportstr1 db 'Resetting EHCI Port',0
eportstr2 db 'Port reset failed',0
eportstr3 db 'Port is already enabled',0
;********************************************************************

ehci_portreset:

	STDCALL eportstr1,0,dumpeax


	;tom before resetting the port
	;check to be sure the ehci controller is still running
	;it may have stopped due to a transaction TD error
	;so first initehci and then reset the port



	mov ecx,eax              ;save ecx=portnum
	mov esi,[EHCIOPERBASE]   ;get start of ehci operational regs
	mov eax,[esi+44h+ecx*4]  ;get PORTSC(ecx)


	or eax,0x100             ;set bit8 for port reset
	and eax,0xfffffffb       ;clear bit2 port enable/disable
	mov [esi+44h+ecx*4],eax  ;begin
	push eax


	;pause while the reset signal is active
	;I guess we need at least 50ms
	mov ebx,200
	call sleep

	;clear bit8 to stop the reset signaling
	pop eax
	and eax,0xfffffeff  ;clear bit8
	mov [esi+44h+ecx*4],eax




	;some echi take a long time to complete reset
	;"when software writes a 0 to this bit there may be a delay
	;before the bit status changes to a zero.The bit status will not 
	;read as a 0 until after the reset has completed."

	;we will wait 100ms and check at most 10x for reset to complete
	mov edx,10

.portResetCheck:

	;see if bit8 really is 0 
	mov eax,[esi+44h+ecx*4]  ;get PORTSC(ecx)
	test eax,100000000b
	jz .portResetComplete

	mov ebx,100
	call sleep

	dec edx
	jnz .portResetCheck

	;if we got here we looped 10x
	;and the reset bit8 never went to 0, why not ??
	STDCALL eportstr2,putshang

.portResetComplete:


	;pause 1 more time
	mov ebx,100
	call sleep



	;dump PORTSC
	mov eax,ecx
	call ehci_portread


	;before reset: 
	;PORTSC=0x1803 connect, no enable 
	;PORTSC=0x1403 lowspeeddevice, connect, noenable

	;this is what you want after reset:
	;PORTSC=0x1005 connect, enabled, HC has port power switch

	;this is not good:
	;PORTSC=0x1001 connect, notenabled, HC has port power switch
	;PORTSC=0x1000 noconnect, notenabled, HC has port power switch

	ret









;**************************************************
;uhci_portconnect and ehci_portconnect
;checks if a device is connected to a port
;input
;eax=port number starting with 0 (0,1,2,3...)
;return
;CF is set if some device is connected to the port
;**************************************************

uhci_portconnect:
	pushad

	mov dx,[UHCIBASEADD]
	add dx,0x10  ;offset for port0, 0x12 is offset for port1
	shl ax,1     ;ax=0 or 2
	add dx,ax    ;dx=0x10 for port 0 or 0x12 for port 1
	in ax,dx     ;read the port
	;ax contains PORTSC 

	bt ax,0      ;sets CF if bit0 is set if device is present 

	popad
	ret



ehci_portconnect:
	pushad

	mov ecx,eax
	mov esi,[EHCIOPERBASE]    ;get start of ehci operational regs
	mov eax,[esi+44h+ecx*4]
	;eax contains PORTSC

	bt ax,0   ;sets CF if bit0 is set if device is present 

	popad
	ret





;*****************************************************************
;uhci_portlowspeed and ehci_portlowspeed

;tests if a low speed device is connected to the port
;there is no quick easy way to know if a mouse of flash drive
;is connected to a port except to read the 6th byte of the
;interface descriptor. But we can use this function to
;see if a low speed device is connected to the port 

;input
;eax=port number 0,1 for uhci, 0,1,2,3 for ehci
;return
;ZF is set if a low speed device is attached 
;**************************************************************

uhci_portlowspeed:

	pushad

	mov dx,[UHCIBASEADD]

	add dx,0x10  ;offset for port0, 0x12 is offset for port1
	shl ax,1     ;ax=0 or 2
	add dx,ax    ;dx=0x10 for port 0 or 0x12 for port 1

	;read the port
	in ax,dx    
	;ax contains PORTSC 

	;Apr 2015
	;dont just check bit8 for low speed, also check bit0 for connect !
	;it is possible to have bit8 set but not bit0
	;if bit8 is set we have a low speed device
	;if bit0 is set we have a device connected
	;so if ax=0x101 we have a low speed device connected

	and eax,0x101  ;mask off all but bit8 and bit0
	cmp eax,0x101  ;if true we have low speed device connected and zf is set

	popad
	ret


ehci_portlowspeed:
	pushad

	mov ecx,eax
	mov esi,[EHCIOPERBASE]    ;get start of ehci operational regs
	mov eax,[esi+44h+ecx*4]
	;eax contains PORTSC
	shr eax,10
	and eax,11b
	cmp eax,1  ;eax=1 if low speed device attached

	popad
	ret






;***************************************************
;uhci_portread and ehci_portread
;read the PORTSC status and control register
;for uhci:
;0x95=full speed device attached, port enabled
;0x1a5=low speed device attached, port enabled

;input:
;eax=port number 0,1,2,3... 
;return:none
;***************************************************

uhci_portread:	
	pushad

	mov dx,[UHCIBASEADD]
	add dx,0x10  ;offset for port0, 0x12 is offset for port1
	shl ax,1     ;+0 or +2 gives us 0x10 or 0x12
	add dx,ax
	in ax,dx     ;read portsc
	and eax,0xffff
	mov ebx,eax  ;copy
	STDCALL portstr4,0,dumpeax

%if VERBOSEDUMP

	;STDCALL portstr9, 12,1,dumpbitfield  ;suspend
	;STDCALL portstr15,10,1,dumpbitfield  ;overcurrent
	STDCALL portstr8,  9,1,dumpbitfield  ;reset
	STDCALL portstr12, 8,1,dumpbitfield  ;low speed device 
	;STDCALL portstr7,  4,3,dumpbitfield  ;line status
	;STDCALL portstr14, 3,1,dumpbitfield  ;port enable/disable change
	STDCALL portstr10, 2,1,dumpbitfield  ;port enable
	;STDCALL portstr13, 1,1,dumpbitfield  ;connect status change
	STDCALL portstr11, 0,1,dumpbitfield  ;connect status

%endif

	popad
	ret






ehci_portread:
	pushad

	mov ecx,eax
	mov esi,[EHCIOPERBASE]    ;get start of ehci operational regs
	mov eax,[esi+44h+ecx*4]
	mov ebx,eax        ;copy
	STDCALL portstr4,0,dumpeax

%if VERBOSEDUMP

	STDCALL portstr5, 13,1,dumpbitfield  ;port owner 1=companion, 0=ehci
	STDCALL portstr6, 12,1,dumpbitfield  ;port power
	STDCALL portstr7, 10,3,dumpbitfield  ;line status
	STDCALL portstr8,  8,1,dumpbitfield  ;reset
	STDCALL portstr9,  7,1,dumpbitfield  ;suspend
	STDCALL portstr10, 2,1,dumpbitfield  ;port enable
	STDCALL portstr11, 0,1,dumpbitfield  ;current connection status

%endif

	popad
	ret




;**************************************
;uhci_portdump, ehci_portdump
;dump PORTSC 
;2 ports for uhci and 4 ports for ehci
;**************************************

uhci_portdump:
	mov eax,0
.dumpPORTSC:
	call uhci_portread
	inc eax
	cmp eax,1  ;max port num
	jbe .dumpPORTSC
	ret


ehci_portdump:
	mov eax,0
.dumpPORTSC:
	call ehci_portread
	inc eax
	cmp eax,3
	jbe .dumpPORTSC
	ret




;*************************************************************
;uhci_portscan, ehci_portscan
;scan all available ports checking for device connections
;input:none
;return:
;esi=port number of connected low speed device
;edi=port number of connected full/hi speed device
;esi and/or edi = 0xffffffff if nothing found

;tatos assumes that any port with a low speed
;device attached is the mouse.
;tatos assumes that any port with a device attached
;that is not low speed is the flash.

;note if you have 2 or more devices of the same speed attached
;this routine will return the highest portnum 
;it is best for tatOS to have only 1 mouse and 1 flash drive
;connected
;if for example you boot a computer with a external floppy drive
;with usb attach, just disconnect this device after bootup
;so tatOS doesnt get confused that its a mouse or flash


;the only sure way to know what device is attached is to 
;read the interface descriptor
portscanstr1 db 'UHCI port scan',0
portscanstr2 db 'EHCI port scan',0
portscanstr3 db 'portnum of low speed device',0
portscanstr4 db 'portnum of full speed device',0
;************************************************************

uhci_portscan:

	STDCALL portscanstr1,dumpstr

	;init esi and edi to indicate nothing found
	mov esi,0xffffffff
	mov edi,0xffffffff

	;in this loop eax is the port number being checked
	mov eax,0        

.checkforconnect:
	call uhci_portconnect
	jnc .trynextport
	;CF is set if any device is connected to port

	call uhci_portlowspeed
	jz .foundlowspeed

	;if we got here we have a full speed device attached
	mov edi,eax
	jmp .trynextport

.foundlowspeed:
	mov esi,eax

.trynextport:
	;increment port num and try again
	inc eax

	;for uhci we check 2 ports: 0,1
	cmp eax,1
	jbe .checkforconnect

	;dump what we found
	mov eax,esi
	STDCALL portscanstr3,0,dumpeax
	mov eax,edi
	STDCALL portscanstr4,0,dumpeax

	ret




ehci_portscan:

	STDCALL portscanstr2,dumpstr

	;init esi and edi to indicate nothing found
	mov esi,0xffffffff
	mov edi,0xffffffff

	;in this loop eax is the port number being checked
	mov eax,0        

.checkforconnect:
	call ehci_portconnect
	jnc .trynextport
	;CF is set if any device is connected to port

	call ehci_portlowspeed
	jz .foundlowspeed

	;if we got here we have a full speed device attached
	mov edi,eax
	jmp .trynextport

.foundlowspeed:
	mov esi,eax

.trynextport:
	;increment port num and try again
	inc eax

	;for ehci we check 4 ports: 0,1,2,3 
	cmp eax,3
	jbe .checkforconnect

	;dump what we found
	mov eax,esi
	STDCALL portscanstr3,0,dumpeax
	mov eax,edi
	STDCALL portscanstr4,0,dumpeax

	ret




;******************************************************************
;ehci_release_ownership

;this function sets bit13 of PORTSC to indicate the port
;belongs (is controlled) by uhci (companion controller)
;because the device is low speed

;input: eax=port number (0,1,2,3)
;return:none
;******************************************************************

ehci_release_ownership:

	STDCALL usbinitstr45,putscroll

	mov esi,[EHCIOPERBASE]  ;get start of ehci operational regs

	mov edi,[esi+44h+eax*4] ;read PORTSC=1 (ports are 44h, 48h, 4ch, 50h)
	or edi,10000000000000b  ;set bit13 port owner = companion controller
	mov [esi+44h+eax*4],edi ;write it back

	ret




