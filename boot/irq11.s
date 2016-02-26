;tatOS/boot/irq11.s


;this is the irq11 interrupt handler
;this file is included in boot2.s

;Feb 2016
;I decided to dabble into getting interrupts working for uhci keyboard interrupt
;tranfers but after a few failed attemps Im going to set this aside for now

irq11str1 db 'this is irq11',0

irq11:  

	cli
	pushad
	push ds
	push es
	push fs
	push gs

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax


	STDCALL irq11str1,[DUMPSTR]


	
	;EndOfInterrupt:any pic2 interrupt must also acknowledge pic1
	mov al,0x20
	out 0x20,al  ;eoi for pic1
	out 0xa0,al  ;eoi for pic2

	pop gs
	pop fs
	pop es
	pop ds
	popad
	sti
	iret



