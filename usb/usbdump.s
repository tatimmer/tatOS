;tatOS/usb/usbdump.s


;functions to write to the dump various interesting usb stuff


;dumpehciTDs
;dumpQH




;*********************************************************
;dumpehciTDs
;this function dumps a chain of ehci transfer descriptors
;each ehci TD is 8 dwords in memory plus 4 more dwords for 64 bit addressing
;TD's are spaced out every 64 bytes
;use this function after a usb transaction
;to see how the ehci controller has modified your TDs
;see /usb/prepareTD-ehci.s for more details

;input: none (all TD's are written to fixed memory 0xd60000)
;       global dword [chainqtyTDs]
;return:none

ehciTDstr0 db 'dumping ehci chain of qTD after run',0
ehciTDstr1 db 'after run: dword1 next qTD pointer',0
ehciTDstr2 db 'after run: dword2 alternate next qTD pointer',0
ehciTDstr3 db 'after run: dword3 packet header',0
ehciTDstr4 db 'after run: dword4 buffer pointer page0',0
ehciTDstr5 db 'after run: dword5 buffer pointer page1',0
ehciTDstr6 db 'after run: dword6 buffer pointer page2',0
ehciTDstr7 db 'after run: dword7 buffer pointer page3',0
ehciTDstr8 db 'after run: dword8 buffer pointer page4',0
;*********************************************************

dumpehciTDs:

	STDCALL ehciTDstr0,dumpstr
	
	mov ebx,0xd60000  ;load starting address of ehci TD's in memory

	;[chainqtyTDs] is a global set by prepareTD_ehci.s
	;ecx is our loop counter
	mov ecx,[chainqtyTDs]

.1:
	;dword 1  Next qTD Pointer
;	mov eax,[ebx]
;	STDCALL ehciTDstr1,0,dumpeax

	;dword 2  Alternate Next qTD Pointer
;	mov eax,[ebx+4]
;	STDCALL ehciTDstr2,0,dumpeax

	;dword 3  USB Packet Header
	mov eax,[ebx+8]
	STDCALL ehciTDstr3,0,dumpeax

	;dword 4  Buffer Pointer page 0
;	mov eax,[ebx+12]
;	STDCALL ehciTDstr4,0,dumpeax

	;dword 5  Buffer Pointer page 1
;	mov eax,[ebx+16]
;	STDCALL ehciTDstr5,0,dumpeax

	;dword 6  Buffer Pointer page 2
;	mov eax,[ebx+20]
;	STDCALL ehciTDstr6,0,dumpeax

	;dword 7  Buffer Pointer page 3
;	mov eax,[ebx+24]
;	STDCALL ehciTDstr7,0,dumpeax

	;dword 8  Buffer Pointer page 4
;	mov eax,[ebx+28]
;	STDCALL ehciTDstr8,0,dumpeax

	add ebx,64  ;get address of start of next TD
	dec ecx     ;dec qty of TD's dumped
	jnz .1

	ret



;************************************************
;dumpQH
;dump a queue head
;each QH is 12 dwords
;the overlay area starts after the first 3 dwords 
;the ehci may overwrite/modify portions of the overlay
;input:esi=address of QH
;      valid addresses are:
;      FLASH_CONTROL_QH
;      FLASH_BULKIN_QH
;      FLASH_BULKOUT_QH
;      HUB_CONTROL_QH
;return:none

qhstr1 db 'dumping ehci queue head QH',0
qhstr2 db 'QH horizontal link pointer',0
qhstr3 db 'QH endpoint characteristics',0
qhstr4 db 'QH endpoint capabilities',0
qhstr5 db 'QH current qTD pointer',0
qhstr6 db 'QH next qTD pointer',0
qhstr7 db 'QH alternate next qTD pointer',0
qhstr8 db 'QH packet header',0
qhstr9 db 'QH buffer pointer page0',0
qhstr10 db 'QH buffer pointer page1',0
qhstr11 db 'QH buffer pointer page2',0
qhstr12 db 'QH buffer pointer page3',0
qhstr13 db 'QH buffer pointer page4',0

;**********************************************

dumpQH:

	STDCALL qhstr1,dumpstr

	;QH horizontal link pointer
	mov eax,[esi]
	STDCALL qhstr2,0,dumpeax	

	;QH endpoint characteristics
	mov eax,[esi+4]
	STDCALL qhstr3,0,dumpeax	

	;QH endpoint capabilities
	mov eax,[esi+8]
	STDCALL qhstr4,0,dumpeax	


	;now starts the QH "Transfer Overlay" area
	;these dwords represent a transaction working space for ehci


	;QH Current qTD pointer
	mov eax,[esi+12]
	STDCALL qhstr5,0,dumpeax	

	;QH next qTD Pointer
	mov eax,[esi+16]  
	STDCALL qhstr6,0,dumpeax

	;QH alternate next qTD pointer
	mov eax,[esi+20]  
	STDCALL qhstr7,0,dumpeax

	;QH packet header	
	mov eax,[esi+24] 
	STDCALL qhstr8,0,dumpeax

	;QH buffer pointer page 0, dword8
	mov eax,[esi+28]  
	STDCALL qhstr9,0,dumpeax

	;QH buffer pointer page 1, dword9
	mov eax,[esi+32]  
	STDCALL qhstr10,0,dumpeax

	;QH buffer pointer page 2, dword10
	mov eax,[esi+36]  
	STDCALL qhstr11,0,dumpeax

	;QH buffer pointer page 3, dword11
	mov eax,[esi+40]  
	STDCALL qhstr12,0,dumpeax

	;QH buffer pointer page 4, dword12
	mov eax,[esi+44]  
	STDCALL qhstr13,0,dumpeax

	ret



