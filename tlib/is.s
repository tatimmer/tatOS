;tatOS/tlib/is.s

;various functions used in string parsing

;isdigit, isascii, ishex, ishexstring, 
;isbinarystring, isupper, islower, isalpha


;****************************************************
;isdigit
;check if value is a valid decimal digit
;within the range 0x30-0x39  (0-9)
;April 2009 added check for negative sign -
;because decimal values may be -
;note al must contain an ascii character not a number

;input
;al=ascii byte to check

;return
;zf is set on success if byte is in range ascii 0-9
;or if we have - sign 
;zf is clear on failure
;*****************************************************

isdigitB:     ;for userland
	mov eax,ebx
isdigit:
	push ebx
	push ecx
	
	cmp al,0x2d   ;check for -
	;zf will be set if we found -
	jz .done 
	cmp al,0x30   ;check for ascii 0
	setl bl    
	cmp al,0x39   ;check for ascii 9
	setg cl

	add bl,cl
	;bl will be nonzero and zf clear if out of range
	;bl will be zero    and zf set if within the range 0-9
	
.done:
	pop ecx
	pop ebx
	ret









;****************************************************
;isascii
;check if byte value is in range 0x20-0x7e
;this is the range of our font01 
;printable ascii bitmaps

;input
;al=byte to check

;return
;zf is set on success, clear on failure

;*****************************************************

isascii:
	push ebx
	push ecx
	
	cmp al,0x20
	setl bl    ;set bl=1 if condition is true
	cmp al,0x7e
	setg cl
	add bl,cl ;zf=1 if (bl and cl)=0 else zf=0

	pop ecx
	pop ebx
	ret



;****************************************************
;ishex
;check a single ascii byte
;if value is a valid hex digit
;within the range lower case a-f
;which corresponds to ascii 0x61-0x66
;upper case A-F is unsupported

;input
;al=byte to check

;return
;zf is set on success, clear on failure

;*****************************************************

ishex:
	push ebx
	push ecx
	
	cmp al,0x61
	setl bl    ;set bl=1 if condition is true
	cmp al,0x66
	setg cl
	add bl,cl ;zf=1 if (bl and cl)=0 else zf=0
	
	pop ecx
	pop ebx
	ret




;*********************************************
;ishexstring
;for tatos a valid hex string consists of
;'0x' prefix followed by numbers 0-9 or 
;the letters a-f 
;the string is 0 terminated
;e.g. '0x1234a8',0
;upper case is unsupported 
;h suffix is unsupported
;this function only checks for the '0x' prefix

;input
;esi=address of hex string constant

;return
;zf is set on success, clear on failure
;*********************************************

ishexstring:
	push ecx
	push edx

	cmp byte [esi],'0'
	setnz cl
	cmp byte [esi+1],'x'
	setnz dl
	add cl,dl

	pop edx
	pop ecx
	ret
	

	
;*********************************************
;isbinarystring
;for tatos a binary string consists of 
;a series of 1's or 0's followed by 'b'
;the string is 0 terminated
;e.g. '110111001b',0
;this function only checks for the 'b' suffix

;input
;esi=address of bin string constant

;return
;zf is set on success, clear on failure
;ecx holds address of 'b' char
;*********************************************

isbinstring:
	push eax

	;get string length
	mov eax,esi
	call strlen

	;check for 'b' at end
	lea ecx,[esi+ecx-1]
	cmp byte [ecx],'b'

	pop eax
	ret





;******************************************************************
;untested version of isdigit by bitshifter needs to be verified
;input: eax=value
;return:eax=0 if false else 1 if true
;******************************************************************
isdigit2:
	sub eax,'0'
	sub eax,10
	sbb eax,eax
	neg eax
	ret


;******************************************************************
;isupper 
;original code by bitshifter is modified to use al register
;input:al=ascii char value
;return:al=0 if false else 1 if true
;******************************************************************
isupper:
	sub al,'A'
	sub al,26
	sbb al,al
	neg al
	ret

;******************************************************************
;islower
;tests for lower case characters in the range a-z
;original code by bitshifter is modified to use al register
;input:al=ascii char value
;return:al=0 if false else 1 if true
;******************************************************************
islower:
	sub al,'a'
	sub al,26
	sbb al,al
	neg al
	ret

;******************************************************************
;untested isalpha by bitshifter
;input:eax=value
;return:eax=0 if false else 1 if true
;abused:edx
;******************************************************************
isalpha:
	mov edx,eax
	sub eax,'a'
	sub eax,26
	sbb eax,eax
	sub edx,'A'
	sub edx,26
	sbb edx,edx
	or eax,edx
	neg eax
	ret



