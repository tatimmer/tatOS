;tatOS/boot/picpitinit.s

;this file is included in boot2.s

;init the PIC and PIT



;**********************************
;        PIC
;programmable interrupt controller
;here we enable/disable 
;which hdwre interrupts we want
;also we remap the hdwre interrupts
;so they dont interfere
;which some software interrupts
;pic1=irq0-irq7, master, port 0x20
;pic2=irq8-irq15, slave, port 0xa0
;to idt 32-47
;**********************************
	
	jmp picstart

	
picpause:
	mov ecx,0xff
.1:
	loop .1
	ret


picstart:
	;ICW1 (initilization command word 1)
	mov al,0x11
	out 0x20,al  ;pic1
	call picpause
	out 0xa0,al  ;pic2
	call picpause
	
	;ICW2	
	mov al,0x20  ;0x20=32=starting hdwre interrupt for pic1
	out 0x21,al
	call picpause
	mov al,0x28  ;0x28=40=starting hdwre interrupt for pic2
	out 0xa1,al
	call picpause

	;ICW3
	mov al,4
	out 0x21,al
	call picpause
	mov al,2
	out 0xa1,al
	call picpause

	;ICW4
	mov al,1
	out 0x21,al
	call picpause
	out 0xa1,al
	call picpause


	;******************************
	;pic1
	;******************************

	;OCW1 (operation control word 1)
	;a bit of 0 means to enable
	;a bit of 1 means to disable/maskoff

	;irq0=bit0 = pit system timer 
	;irq1=bit1 = ps2 keyboard
	;irq2=bit2 = redirect to pic2
	;irq3=bit3 = serial port
	;irq4=bit4 = serial port
	;irq5=bit5 = sound card
	;irq6=bit6 = floppydisc controller
	;irq7=bit7 = parallel port
	
	;note: usb controller initialization needs the pit for sleep()

	;as of May 2016 we are only using the usb keyboard
	;still we need to enable ps2 keyboard (irq1)
	;because bios uses this to enable our usb keyboard on start up 
	;until we take control

	mov al,11111000b    ;enable pit, ps2 keyboard, pic2
	;mov al,11111010b   ;enable pit, pic2
	;mov al,11111100b   ;enable pit and ps2 keyboard
	;mov al,11111011b   ;enable pic2
	;mov al,11111101b   ;enable ps2 keyboard
	;mov al,11111111b   ;enable nothing 
	
	out 0x21,al
	call picpause


	;******************************
	;pic2
	;******************************

	;irq8 =bit0 = real time clock 
	;irq9 =bit1 = irq2 redirected 
	;irq10=bit2 = reserved
	;irq11=bit3 = usb controller 
	;irq12=bit4 = ps/2 mouse 
	;irq13=bit5 = math co-processor
	;irq14=bit6 = hard disc drive 
	;irq15=bit7 = reserved
	
	;mov al,0         ;enable everything
	mov al,11101111b ;enable ps2mouse
	;mov al,11100111b  ;enable usb + ps2mouse
	;mov al,11111111b ;enable nothing

	out 0xa1,al
	call picpause
	
	





;*****************************************************************
;Initialize the Programmable Interrupt Timer 
;set how many interrupts/sec we get from the PIT
;we use channel 0 here
;hits/second = 1193182 hz / divisor
;2^16=65536 is the max divisor you can use (bios uses this)
;using 65536 gives the lowest 18.2065 hits/second
;supposedly data bytes of 0 are same as 65536

;WARNING !!!!!
;/tlib/sleep uses the PITCOUNTER value 
;to pause procedural code execution
;our sleep function expects the PITCOUNTER 
;to increment once every millisecond (fast firing rate)
;if you reprogram the pit to change the firing rate
;then you will affect how long sleep is sleeping
;the usb controller & port reset are also dependent on sleep
;*****************************************************************

;square wave, lsb then msb, channel=0=irq0
mov al,110110b
out 0x43,al          ;command  


;slow firing rate
;*******************
;set the the slowest firing rate possible
;0=65536 divisor which gives 18 hits/seconds
;mov al,0            
;out 0x40,al          ;data: low byte hits/sec
;out 0x40,al          ;data: hi  byte hits/sec


;medium firing rate
;*********************
;1193182/11930 ~= 100 hits/second
;11930 = 0x2e90
;mov al,0x9a   ;low data byte
;out 0x40,al
;mov al,0x2e   ;hi data byte
;out 0x40,al


;fast firing rate
;******************
;1193182/1193 ~= 1000 hits/second
;1193 = 0x04a9	
mov al,0xa9   ;low data byte
out 0x40,al
mov al,0x04   ;hi data byte
out 0x40,al




;*****************************
;initialize some values
;*****************************

;interrupt bitmask 
mov dword [0x50c],0



