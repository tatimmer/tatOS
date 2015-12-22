;tatOS/usb/comstat.s


;functions to access the usb command and status registers
;there are seperate functions for uhci and ehci 


;**********************************************
;uhci_command  
;dump the value of the command register
;a value of 0x81 is normal after controller reset

;input:none
;return
;zf set on success, clear on error

;local
comregstr1 db 'UHCI USBCMD command register',0
comregstr2 db 'Max Packet',0
comregstr3 db 'CF flag',0
comregstr4 db 'debug',0
comregstr5 db 'global resume',0
comregstr6 db 'global suspend',0
comregstr7 db 'global reset',0
comregstr8 db 'HC reset',0
comregstr9 db 'Run/Stop',0
;***********************************************

uhci_command:

	pushad

	mov dx,[UHCIBASEADD]
	in ax,dx
	and eax,0xffff
	STDCALL comregstr1,0,dumpeax

%if VERBOSEDUMP

	STDCALL comregstr2, 7,1,dumpbitfield  ;MaxPacket
	STDCALL comregstr3, 6,1,dumpbitfield  ;CF flag
	STDCALL comregstr4, 5,1,dumpbitfield  ;debug
	STDCALL comregstr5, 4,1,dumpbitfield  ;global resume
	STDCALL comregstr6, 3,1,dumpbitfield  ;global suspend
	STDCALL comregstr7, 2,1,dumpbitfield  ;global reset
	STDCALL comregstr8, 1,1,dumpbitfield  ;HC reset
	STDCALL comregstr9, 0,1,dumpbitfield  ;run/stop

%endif

.done:
	popad
	ret



;**********************************************
;ehci_command
;dump the value of the command register
;input:none
;return
;zf set on success, clear on error
;_ecomregstr1 db 'EHCI USBCMD command register',0
;***********************************************

;_ehci_command:

;	pushad

;	mov esi,[EHCIOPERBASE]  ;get start of operational registers
;	mov eax,[esi]     ;USBCMD is at opbar+0
;	STDCALL ecomregstr1,0,dumpeax

;.done:
;	popad
;	ret




;**********************************************
;uhci_status 
;dump the USBSTS status register
;this function may be called from the shell

;ax=00 is a normal condition
;ax=0x20 means controller is halted
;ax=0x10 means controller process error
;ax=8    means host system error

;input:none
;return:zf set on success, clear on error

uhcistatstr1 db 'UHCI USBSTS status register',0
uhcistatstr5 db 'Interrupt on Async Advance (0=default)',0
uhcistatstr6 db 'Host System Error',0
uhcistatstr9 db 'USB Error Interrupt',0
uhcistatstr10 db 'USB Interrupt',0
uhcistatstr11 db 'Process Error',0
uhcistatstr12 db 'Resume Detect',0
;*********************************************

uhci_status:

	mov dx,[UHCIBASEADD]
	add dx,0x02
	in ax,dx
	and eax,0xffff
	mov ebx,eax  ;copy
	STDCALL uhcistatstr1,0,dumpeax

	STDCALL uhcistatstr5,  5,1,dumpbitfield  ;halted
	STDCALL uhcistatstr11, 4,1,dumpbitfield  ;Process error
	STDCALL uhcistatstr6,  3,1,dumpbitfield  ;host system error
	STDCALL uhcistatstr12, 2,1,dumpbitfield  ;resume detect
	STDCALL uhcistatstr9,  1,1,dumpbitfield  ;Error Interrupt
	STDCALL uhcistatstr10, 0,1,dumpbitfield  ;Interrupt

	ret




;this is just a dummy stub routine
;uhci_status and ehci_status are pointers to functions called by initflash
;but ehci_status is actually never used
;its been replaced by show_ehci_status called from the shell
;eventually we will obsolete this alltogether
ehci_status:
	ret








