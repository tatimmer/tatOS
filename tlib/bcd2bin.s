;tatOS/tlib/bcd2bin.s

;convert a bcd byte to binary

;bcd is used in date.s
;the bios returns the month/day/year in bcd
;this routine originally written to convert mon/day/year bytes to binary bytes
;for usage in fat.s

;to convert a bcd to binary:
;the 0xf is just to mask off and isolate the nibble
;each nibble is multiplied by 0,10,100,1000 ...
;then just add them all up
;(LoNibble & 0xf) + (NextNibble>>4 & 0xf)*10 + (NextNibble>>8 & 0xf)*100 ...

;since bcd values can only be 0,1,2...8,9
;the largest bcd byte is 0x99 which can be converted to binary 0x63


;****************************************
;bcd2bin
;convert a bcd byte to binary byte
;input: al=bcd value to convert
;return al=binary equivalent
;****************************************

bcd2bin:
	push ebx
	push ecx

	mov bl,al  ;copy
	mov cl,al  ;copy again 
	and cl,0xf ;save the low nibble

	;work with the hi nibble
	shr bl,4   ;shift hi nibble to low position
	and bl,0xf ;mask off all but the nibble
	mov al,10
	mul bl     ;ax=10*hinibble

	add ax,cx    ;ax=10*hinibble + lonibble
	and eax,0xff ;mask off all but al

	pop ecx
	pop ebx
	ret


