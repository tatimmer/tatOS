;tatOS/usb/showehciroothubports.s


;code to build list control strings to show the bitfields of the
;downstream ports of a root hub on my asus laptop
;we examine dword [HUB_QTYDOWNSTREAMPORTS] saved from the config descriptor

;you must first init the ehci and root hub before executing this function
;strings are written to LISTCTRLBUF and spaced 0x100 bytes apart

;note the bits 9,10 for detecting the speed of the device is only relavant
;if there is in fact a device attached see bit0


hpstr0 db 'EHCI ROOT HUB DOWNSTREAM PORT STATUS wPortStatus',0
hpstra db '********** port number for wPortStatus **********',0
hpstr1 db 'current connect status 1=device present on port',0
hpstr2 db 'port enabled/disabled  1=enabled',0
hpstr3 db 'suspend 1=suspended or resuming',0
hpstr4 db 'overcurrent 1=overcurrent condition exists',0
hpstr5 db 'reset 1=reset signalling asserted',0
hpstr6 db 'port power 1=not powered OFF state',0
hpstr7 db 'low speed device attached 0=full or hi speed 1=low speed',0
hpstr8 db 'hi speed device attached 0=full speed 1= hi speed',0
hpstr9 db 'building list control strings',0




showehciroothubports:


	;we are going to clear the screen and show the program title immediately
	;because it takes more than 1 second to build and display the list
	;control strings, and we want the user to feel like something is happening
	call backbufclear

	;show the program title
	STDCALL FONT01,0,20,hpstr0,0xefff,puts

	;message to tell user we are building list control strings
	;this string will get overwritten by the list control
	STDCALL FONT01,0,100,hpstr9,0xefff,puts

	;make it show up
	call swapbuf



	;now prepare to build list control strings

	;edx holds address in memory to store list control string
	;all addresses are spaced out 0x100
	;ecx must be preserved
	mov edx,LISTCTRLBUF

	;loop number
	;ecx= portnum (1,2,3, up to byte [HUB_BQTYDOWNSTREAMPORTS])
	;ecx must be preserved in this loop
	mov ecx,1

	;copy title string
	push hpstr0
	push edx     
	call strcpy2
	add edx,0x100 ;string spacing in list control buffer




.1: ;top of loop
    ;9 strings are generated for each hub port
	;this loop actually takes more than 1 second to execute

	;get status of port 
	mov eax,ecx            ;eax=portnum 1,2,3... 
	call HubGetPortStatus  ;ebx = dword [hubportstatus] 
	

	;display a string to identify the port number
	push hpstra
	mov eax,ecx  ;eax=port number
	push edx     ;destination memory address to write string
	call eaxstr
	add edx,0x100

	;Current Connect Status
	mov eax,ebx
	and eax,1
	STDCALL hpstr1,edx,eaxstr
	add edx,0x100

	;Port Enabled/Disabled
	mov eax,[hubportstatus]
	shr eax,1
	and eax,1
	STDCALL hpstr2,edx,eaxstr
	add edx,0x100

	;suspend
	mov eax,[hubportstatus]
	shr eax,2
	and eax,1
	STDCALL hpstr3,edx,eaxstr
	add edx,0x100

	;over-current
	mov eax,[hubportstatus]
	shr eax,3
	and eax,1
	STDCALL hpstr4,edx,eaxstr
	add edx,0x100

	;reset
	mov eax,[hubportstatus]
	shr eax,4
	and eax,1
	STDCALL hpstr5,edx,eaxstr
	add edx,0x100

	;port power
	mov eax,[hubportstatus]
	shr eax,8
	and eax,1
	STDCALL hpstr6,edx,eaxstr
	add edx,0x100

	;low speed device
	mov eax,[hubportstatus]
	shr eax,9
	and eax,1
	STDCALL hpstr7,edx,eaxstr
	add edx,0x100

	;hi speed device
	mov eax,[hubportstatus]
	shr eax,10
	and eax,1
	STDCALL hpstr8,edx,eaxstr
	add edx,0x100


	;go back and build strings for the next port
	add ecx,1
	cmp cl,[HUB_BQTYDOWNSTREAMPORTS]
	jbe .1



	;now setup the list control
	;the qty of strings generated was [HUB_QTYDOWNSTREAMPORTS]*9 + 1
	xor edx,edx
	mov eax,9
	movzx ebx,byte[HUB_BQTYDOWNSTREAMPORTS]
	mul ebx     ;result is in edx:eax
	add eax,1   ;eax=qty strings
	mov ebx,100 ;Ylocation of top of listcontrol
	call ListControlInit



.appmainloop:

	call ListControlPaint

	STDCALL FONT01,0,20,hpstr0,0xefff,puts

	call swapbuf
	call getc  ;ListControlKeydown is called within getc

	cmp al,ESCAPE  ;to quit
	jnz .appmainloop

	ret






