;tatOS/boot/irq0.s


;PIT: Programmable Interrupt Timer
;referred to as the 8253 controller 
;or system timer

;this is the interrupt service routine for the pit
;this code gets called about 1000 times per second

;see picpitinit.s which initializes the pit
;and sets the firing rate

usb_keyboard_counter dd 0



irq0:  

	cli	  ;disable interrupts
	pushad 

	;I tried some code in here to push ds,es,fs,gs
	;then assign 0x10 kernel data selector values
	;then just after end of interrupt we pop ds,es,fs,gs
	;but doing this is not reqd
	;see discussion in tlibentry.s

	;count up to 0xffffffff then 
	;roll over to 0 and continue
	;this global is used by all functions in /tlib/time.s
	add dword [PITCOUNTER],1



	;usb keyboard
	;***************
	;call the usb keyboard interrupt procedure at regular intervals
	;if not done at regular intervals the transfer descriptor will suffer 
	;a time out error and the keyboard will become unusable

	mov eax,[usb_keyboard_counter]
	add eax,1

	;the usb keyboard polling frequency is set in tatOSinit
	;and modified by /usb/interkeybd.s
	;a value of 30  is good for general typing
	;a value of 100 is good for showing the keyboard report
	cmp eax,[USBKEYBDPOLLFREQ]
	ja  .1  

	;counter is <= USBKEYBDPOLLFREQ
	mov [usb_keyboard_counter],eax
	jmp .done

.1: ;counter is > USBKEYBDPOLLFREQ
	mov dword [usb_keyboard_counter],0

	;call usbkeyboardinterrupt() which is defined in /usb/interkeybd.s  
	;we are using the /tlib/tlib.s indirect call table
	call [0x10088]  


.done:
	;end of interrupt
	mov al,0x20 
	out 0x20,al  
	popad	 
	sti  ;enable interrupts
	iret  



