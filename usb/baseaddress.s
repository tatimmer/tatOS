;tatOS/usb/baseaddress.s


;***************************************************************
;uhcibaseaddress

;PCI Config: USBBA usb i/o space base address (byte offset 0x20)
;the USBBA is a dword at Address Offset 20-23h
;then we extract from this the UHCIBASEADD
;this is the important one needed for usb transactions

;on my CBS homebuilt USBBA=0x7121
;the UHCIBASEADD is then 0x7120  (USBBA with bit0 cleared)
;on my Via pci addon card with ehci and (2) uhci companions
;the UHCIBASEADD of the companions is 0xef20, 0xef40

;input:
;eax=bus:dev:fun number of UHCI usb controller
;return:
;the usb controller base address is saved to global [UHCIBASEADD]

ubastr1 db 'uhcibaseaddress: UHCIBASEADD',0
;***************************************************************

uhcibaseaddress:
	pushad

	;eax=bus:dev:fun number of usb controller 
	mov ebx,0x20  ;20=address offset for USBBA
	call pciReadDword
	mov [0x52c],eax  ;save USBBA

	;save the "Index Register Base Address" for usb transactions
	;this is bits15-5 of USBBA with bit0 cleared
	;I guess the bios sets this value but we could change it
	and eax,0xfffffffe
	mov [UHCIBASEADD],ax
	STDCALL ubastr1,1,dumpeax

	popad
	ret



