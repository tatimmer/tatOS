;tatOS/boot/ps2mouseinit.s


;Jan 2010
;this code is depreciated and listed here for reference only
;it is not assembled into tatOS by default
;the usb mouse is std



;Routines to initialize the ps/2 mouse 
;this code works for:
;  * ps/2 mouse with 2 buttons + wheel which sends a 4 byte 
;    packet and returns DeviceID=0x03
;    wheel can be rolled or pushed to act as 3rd button

;2 button no wheel mouse with 3 byte packet not supported
;also mice with usb connector on end and then 
;usb2ps2 connector may or may not work
;wait_write & wait_read are also used in mouse.s for the irq12 mouse driver



keymouse4 db 'ps2: sendsendack',0
keymouse5 db 'ps2: Initializing the ps/2 mouse',0
keymouse8 db 'ps2: wheel mouse ID != 0x03, failed to find 3 button mouse',0
keymouse9 db 'ps2: init ps/2 mouse error - is device connected ?',0
keymouse12 db 'ps2: aborting ps2 mouse init',0
keymouse14 db 'ps2: wheel mouse ID',0



;Dec 2009 note to self
;my daughters HP Pavillion laptop requires this 
;ps/2 mouse code to be executed
;otherwise the keyboard will not work
;why is that ???
	



	;start mouse init
	STDCALL keymouse5,[DUMPSTR]

	;enable the mouse port
	call wait_write
	call mouse_pause
	mov al,0xa8  
	out 0x64,al


	;code to initialize the Intellimouse
	;see Adam Chapweske "The PS/2 Mouse Interface"
	;this is by far the best reference I have found
	;ID 0x00 = 3 byte packet
	;ID 0x03 = 4 byte packet (Intellimouse)
	;ID 0x04 = 4 byte packet for 5 btn mouse + wheel
	;my irq12 driver in interrupts.s assumes 0x03


.mousereset:
	mov bl,0xff  
	call sendsendack

	;sendsendack timeout
	;if zf is not set at this point then we probably dont have a ps2 mouse
	;so abort the ps2 mouse init code
	jnz near .Ps2MouseFailed  

	and eax,0xff
	STDCALL keymouse13,0,[DUMPEAX]
	;should return al=fa

	
	call wait_read
	call mouse_pause
	in al,0x60
	and eax,0xff
	STDCALL keymouse13,0,[DUMPEAX]
	;should get al=aa 


	
	call wait_read
	call mouse_pause
	in al,0x60
	and eax,0xff
	STDCALL keymouse13,0,[DUMPEAX]
	;should get al=00  



	;Enter scrolling wheel mode
	mov bl,0xf3   ;set sample rate
	call sendsendack
	and eax,0xff
	STDCALL keymouse13,0,[DUMPEAX]

	;should get al=fa

	
	mov bl,0xc8
	call sendsendack
	
	mov bl,0xf3
	call sendsendack
	
	mov bl,0x64
	call sendsendack
	
	mov bl,0xf3
	call sendsendack
	
	mov bl,0x50
	call sendsendack
	

	;******************************************
	;check for mouse deviceID=0x03
	;this is a 3 button mouse w/wheel
	;*****************************************

	mov bl,0xf2   ;GetDeviceID
	call sendsendack
	call wait_read
	call mouse_pause

	mov ecx,1000
.checkID:	
	in al,0x60
	and eax,0xff
	STDCALL keymouse14,0,[DUMPEAX]
	;my daughters HP Pavillion laptop returns 
	;first a bunch of FA then a bunch of 00, why ? 
	cmp al,0x03   ;=intelliwheel mouse
	jz near .savemouseID
	loop .checkID

	;if we got here the mouseID is not 0x03
	STDCALL keymouse8,[DUMPSTR]
	;continue on without proper ps2 mouse init
	;perhaps you dont have a ps2 mouse plugged in
	jmp .Ps2MouseFailed


.savemouseID:
	mov [0x54c],al 



	;enable mouse interrupts
.1:	call wait_write
	call mouse_pause
	mov al,0x20  
	out 0x64,al  
	call wait_read
	call mouse_pause
	in al,0x60
	or al,2
	mov bl,al   ;save status
	call wait_write
	call mouse_pause
	mov al,0x60
	out 0x64,al
	call wait_write
	call mouse_pause
	mov al,bl
	out 0x60,al


	;set defaults
	mov bl,0xf6   
	call sendsendack
	
	;Mouse enable 
	;now the mouse will send data to the keyboard controller
	mov bl,0xf4   
	call sendsendack





	;***************************************************************
	;           END INIT PS2MOUSE
	;***************************************************************
	
.Ps2MouseFailed:






;************************************************************************
;sendsendack
;sends 0xd4 to 0x64 (status port) of the keyboard controller
;which means the next byte is for the mouse 
;then sends the next byte which is relayed to the mouse
;then reads 0x60 (data port) and checks for 0xfa acknowledgement
;input
;bl=command byte to send to the mouse
;return
;al holds the byte read from port60
;ZF is set on success, clear on error (maybe we dont have ps2 mouse ??)
;************************************************************************
sendsendack:
	mov ecx,10
.1:
	STDCALL keymouse4,[DUMPSTR]

	call wait_write
	mov al,0xd4  ;next byte written goes to mouse
	out 0x64,al
	
	call wait_write
	mov al,bl  
	out 0x60,al  ;send command to mouse
	
	call wait_read
	call mouse_pause
	in al,0x60   ;check port
	;mouse should acknowledge with 0xfa

	;i have found the mouse sometimes gives 0xfe "resend"
	;and your startup screen would hang black
	;hope the mouse gives us 0xfa soon
	cmp al,0xfa 
	jz .done   ;zf set on success
	loop .1
	
	;error-didnt get 0xfa after 10 tries
	;we get here if ps2 mouse is not connected
	STDCALL keymouse12,[DUMPSTR]
	or byte [0x54d],100b  ;this will clear zf

.done:
	ret




;*****************************************************
;mouse_pause
;menuet adds a pause at the end of 
;wait_read and it is definitely reqd
;if you check 0x64 and it says its ok
;you must still wait for the proper response
;read too quick and you may get 0xfe from the mouse
;in bochs this pausing takes a long time
;but on real hdwre it seems necessary
;and on PII its un-noticable
;*****************************************************
mouse_pause:
	push ecx
	;there is nothing magic about 0xa0000
	;its reqd for my Toshiba laptop P1
	;faster Pentiums can use a much smaller value
	mov ecx,0xa0000
.1: loop .1

	pop ecx
	ret


