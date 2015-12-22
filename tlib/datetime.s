;tatOS/tlib/datetime.s

;****************************************************************
;datetime
;generates an ascii string of the current date and time
;relies on bios int 1a,4 for date on startup
;gets values from RealTimeClock CMOS RAM Bank 0 for time
;assumes values returned by RTC are BCD

;input
;edi=address of destination buffer

;returns 
;ascii string "mm/dd/yy hh:mm"

;assumes conversion from BCD to ascii is reqd for the time
;buffer must be at least 15 bytes long 
;string will be 0 terminated

;to write a byte do "out 0x70,Addr" then "out 0x71,byte"
;to read  a byte do "out 0x70,Addr" then "in  al,0x71"

;to convert a bcd to binary:
;(LoNibble & 0xf) + (NextNibble>>4 & 0xf)*10 + (NextNibble>>8 & 0xf)*100 ...
;***************************************************************

datetime:
	push eax
	push ebx
	push edx


	;month in BCD
	;April will be al=0x04
	mov al,[0x510] 
	mov edx,2
	call eax2hex

	mov byte [edi],'/'
	inc edi

	;day in BCD
	;the 11th day of the month will be al=0x11
	mov al,[0x511] 
	mov edx,2
	call eax2hex

	mov byte [edi],'/'
	inc edi
	
	;year in BCD
	;for a year like 2010, al=0x10
	;so the entire string will be "04/11/10"
	mov al,[0x512] 
	mov edx,2
	call eax2hex

	mov byte [edi],SPACE
	inc edi
	


	;TIME

.1:	mov al,0xa    ;RTC register A
	out 0x70,al
	in al,0x71
	test al,0x80 ;is update in progress
	jne .1


	;register B
	mov al,0xb
	out 0x70,al
	in al,0x71


	;bit1
	;bit=1,zf=0 = 24 hour mode
	;bit=0,zf=1 = 12 hour mode
	;test al,00000010b
	

	;bit2
	;if bit2=0,zf=1 we have BCD endcoding
	;if bit2=1,zf=0 we have binary
	;test al,00000100b
	;for now we just assume BCD


	;hours, Address=04
	mov al,0x04
	out 0x70,al
	in al,0x71
	
	movzx ebx,al
	shr ebx,4
	add ebx,0x30
	mov [edi],bl
	inc edi

	movzx ebx,al
	and ebx,0xf
	add ebx,0x30
	mov [edi],bl
	inc edi

	mov byte [edi],':'
	inc edi


	
	;minutes, Address=02
	mov al,0x02
	out 0x70,al
	in al,0x71

	movzx ebx,al
	shr ebx,4
	add ebx,0x30
	mov [edi],bl
	inc edi

	movzx ebx,al
	and ebx,0xf
	add ebx,0x30
	mov [edi],bl
	inc edi

	;0 terminate
	mov byte [edi],0

	;seconds are at Address=00 (not supported)

	pop edx
	pop ebx
	pop eax
	ret


