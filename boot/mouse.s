;tatOS/boot/mouse.s

;this file is depreciated in favor of the usb mouse driver

;Oct 2009
;in the process of creating a usb mouse driver
;and trying to use shared code with the ps2 & usb mouse 
;Ive come up with the following scheme
;both drivers will write the 4 mouse bytes starting at 0x550
;representing the mouse response (button,dX,dY,dZ)
;thats all the drivers will do

;this is the irq12 ps2 mouse driver
;this file is included in boot2.s
;this code may/maynot work for a mouse with a usb mouse
;and a usb2ps2 adapter, I have had mixed success.
;I suggest you buy a pure ps/2 mouse (6pin round connector)

;this isr is based on the fact that the bytes come 
;from the mouse 1 per interrupt 
;you may see some code elsewhere (on the net) 
;that attempts to read all 4 bytes
;from the keyboard controller on 1 interrupt
;this actually works on some hdwre 
;and it unfortunately works on Bochs
;but on other hdwre it will not work (mouse bounces around)
;the driver from Sanik (osdev) 
;and a doc from cas.mcmaster.ca/~se3f03
;suggests you read 1 byte per interrupt
;local
_mousepacketID db 0  ;0,1,2,3 = 4 byte packet
;***********************************************************


irq12:

	cli  ;disable hdwre interrupts (can still get exception)
	pushad
	

	;read mouse packet byte
	;one byte per interrupt
	call wait_read
	in al,0x60


	;store first byte of packet
	;bit0=left button
	;bit1=right button
	;bit2=middle button
	;bit3=always set
	;bit4=X sign
	;bit5=Y sign
	;bit6=X overflow
	;bit7=Y overflow
	cmp byte [_mousepacketID],0
	jnz .1
	inc byte [_mousepacketID]
	mov [0x550],al
	jmp .eoi

.1:
	;store second byte of packet (delta X)
	cmp byte [_mousepacketID],1
	jnz .2
	inc byte [_mousepacketID]
	mov [0x551],al
	jmp .eoi

.2:
	;store third byte of packet  (delta Y)
	cmp byte [_mousepacketID],2
	jnz .3
	inc byte [_mousepacketID]
	mov [0x552],al
	jmp .eoi

.3:
	;store fourth byte of packet  (delta Z)
	mov byte [_mousepacketID],0
	mov [0x553],al



.eoi:

	;eoi-end of interrupt signal for pic2
	mov al,0x20
	out 0xa0,al  ;eoi for pic2
	out 0x20,al  ;eoi for pic1


	popad
	sti  ;enable interrupts
	iret





