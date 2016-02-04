;tatOS/tlib/string.s


;various functions to deal with ascii strings
;generally we deal with 0 terminated strings like c
;but some functions like strncpy need the string size in advance

;strcpy, strcpy2, strncpy, strcpy80
;strncmp, strcat, strlen (kernel), strlenB (user), strchr 
;skipspace, str2eax, st02str, str2st0
;eax2hex, eax2dec, eax2bin, eaxstr     (kernel only)
;ebx2hex, ebx2dec, ebx2bin, ebxstr     (user apps)
;reg2str, getreginfo, printf
;splitstr, squeeze
;flag2str, mem2str
;StripTrailingSpace


;***************************************************************************
;strcpy
;copy bytes from source to dest 

;input
;esi=address of 0 terminated source string
;edi=address of destination memory

;no return value
;esi holds address of first char after src  string end
;edi holds address of first char after dest string end

;WARNING
;this function does not preserve ESI or EDI
;it intentionally returns with ESI and EDI incremented
;holding the address of the first char after the 0 terminator
;this is needed for building complex strings 
;this function should not be used in a loop
;or else if you need to preserve, do your own push/pop !!!

;note also this function is slow because it first calls string length
;if you know the length of the string its faster to use strncpy

;also note the 0 terminator is NOT copied

strcpystr1 db 'strcpy:Warning-strlen > 300 bytes, clamping ecx=300',0
;************************************************************************

strcpy:
	push eax
	push ecx

	;first get len of source
	mov eax,esi
	call strlen  ;ret in ecx

	;for safe string handling
	;we assume a string longer than 300 bytes is unterminated
	;and strlen would then return a huge number
	;and we would have possible buffer overflows
	cmp ecx,300
	jb .docopy
	STDCALL strcpystr1,dumpstr
	mov ecx,300    ;clamp strlen at 300 bytes

.docopy:
	cld        ;increment
	rep movsb  ;byte [esi]->[edi], esi++, edi++
	;note esi and edi are both incremented, not preserved

	pop ecx
	pop eax
	ret



;***************************************************************************
;strcpy80
;copy a 0 terminated string of no more than 80 char from source to dest 
;if the string is longer than 80 char then it is truncated 
;a 0 terminator is always written

;input
;esi=address of 0 terminated source string
;edi=address of destination memory

;return:none 
;************************************************************************

strcpy80:

	push eax
	push ecx
	push esi
	push edi

	cld
	mov ecx,79
.1:
	lodsb         ;al=[esi], esi++
	cmp al,0
	jz .terminate ;quit if we find 0 before 80 char
	stosb         ;[edi]=al, edi++
	loop .1

.terminate:
	mov al,0  ;in case we copied 79 char and didnt find 0
	stosb

	pop edi
	pop esi
	pop ecx
	pop eax
	ret





;******************************************************
;strcpy2
;this version uses the stack for args
;and preserves esi,edi
;it also copies the 0 terminator
;this function is designed to be used in a loop
;input
;push address of source 0 terminated string  [ebp+12]
;push address of destination memory          [ebp+8]
;return:none
;*******************************************************

strcpy2:

	push ebp
	mov ebp,esp

	push esi
	push edi

	mov esi,[ebp+12]
	mov edi,[ebp+8]
	call strcpy
	mov byte [edi],0   ;0 terminator

	pop edi
	pop esi
	pop ebp
	retn 8



;*****************************************************
;strcpyquote
;same as strcpy2 except bounds the string with quotes
;*****************************************************

strcpyquote:
	push ebp
	mov ebp,esp
	push esi
	push edi

	;starting quote
	mov edi,[ebp+8]
	mov al,'"'
	stosb

	;copy the string
	mov esi,[ebp+12]
	call strcpy

	;back up so edi holds address of 0 terminator
	dec edi

	;overwrite 0 terminator with ending quote
	mov al,'"'
	stosb

	;now add new 0 terminator
	mov al,'"'
	stosb
	
	pop edi
	pop esi
	pop ebp
	retn 8




;***********************************************
;strncpy
;copy a string of known length from esi to edi

;input
;esi=address of source bytes to copy
;edi=address of destination memory
;ecx=qty bytes to copy from source string

;WARNING: esi/edi/ecx are not preserved
;does an asm programmer really need this function ?
;***********************************************

memcpy:
strncpy:

	cld     
	rep movsb

	ret



;**************************************
;strncmp
;compare 2 strings for equality

;input
;esi=address of str1
;edi=address of str2
;ecx=qty bytes to compare

;output
;zf is set on success and ecx=0
;zf is clear on error and ecx is nonzero
;**************************************

strncmp:

	push esi
	push edi

	cld   ;inc
	repe cmpsb  ;compare string byte while equal
	;if strings are same zf is set
	
	pop edi
	pop esi
	ret
	



;********************************************
;strcat
;str2 is copied after str1 and 0 terminated

;input
;edi=0 terminated parent string (str1)
;    max length of str1=80 char
;esi=0 terminated child string (str2) 
;ecx=length of str2

;result
;edi=address of combined 0 terminated string 
;*******************************************

strcat:

	push eax
	push ecx  ;save for later

	;find end of destination string
	mov ecx,80  ;max length of str1
	cld
	mov al,0
	repne scasb  
	dec edi   ;goes 1 too far

	;now cat
	pop ecx  ;len of str2
	rep movsb

	mov byte [edi],0  ;terminate
	pop eax
	ret





;********************************************************
;strlen/strlenB

;input:
;eax=address of 0 terminated string

;returns:
;kernel ecx=length of string (not counting terminator)
;user   eax=length of string (not counting terminator)

;author: Paul Hsieh
;source: John Eckerdahl Assy Gems
;the loop has been unrolled 4 times for speed
;note Pauls use of the U/V pipes
;********************************************************

strlenB:  ;userland ebx=address of 0 terminated string
	mov eax,ebx

strlen:   ;kernel

	push ebx
	
	lea ecx,[eax-1]
l1: inc ecx
	test ecx,3
	jz l2
	cmp byte [ecx],0
	jne l1
	jmp l6
l2: mov ebx,[ecx]       ; U
	add ecx,4           ; V
	test bl,bl          ; U
	jz l5               ; V
	test bh,bh          ; U
	jz l4               ; V
    test ebx,0ff0000h   ; U
	jz l3               ; V
    test ebx,0ff000000h ; U
	jnz l2              ; V +1brt
	inc ecx
l3: inc ecx
l4: inc ecx
l5: sub ecx,4
l6: sub ecx,eax         ;ecx=strlen return value for kernel

	;copy strlen to eax for userland strlenB return value
	mov eax,ecx
	pop ebx
	ret



;*******************************************************************************
;strchr
;find the first instance of byte in al 
;within a 0 or NL terminate string

;input
;edi=address of string
;al=byte to search for

;output
;success: zf is clear and edi points to byte 
;failure: zf is set   and edi holds address of 0 or NL found
;ecx=index in string of last byte checked

;note: 
;1) edi & ecx & eax are not preserved
;2) this function will stop searching and exit on error if it finds 0 or NEWLINE
;   so do not use this function to search for 0 or NL, use repne scasb instead
strchrstr1 db 'strchr:failed',0
strchrstr2 db 'strchr:IndexOfByteFound',0
;*******************************************************************************

strchrB:          ;userland may call this 
	mov eax,ebx   ;pass byte to search for in bl
strchr:

	xor ecx,ecx
.1:
	cmp [edi],al
	jz .success
	cmp byte [edi],0
	jz .failed  
	cmp byte [edi],NL
	jz .failed  
	inc edi
	inc ecx
	jmp .1

.success:
	mov eax,ecx
	STDCALL strchrstr2,0,dumpeax  
	or eax,1     ;ZF clear
	jmp .done
.failed:
	;STDCALL strchrstr1,dumpstr  for debug
	xor eax,eax  ;ZF set
.done:
	ret



;*******************************************************
;skipspace
;used to parse an ascii string containing spaces
;stops at first non-SPACE

;input
;esi=address of string 

;return
;esi points to first non-SPACE

;Caution: no limit on how many bytes to check !!
;footnote: I tried a version with repe scasb 
;but had troubles 
;********************************************************

skipspace:
	cmp byte [esi],SPACE
	jnz .done
	inc esi
	jmp skipspace

.done:
	ret

	





;******************************************************
;eax2hex
;convert the contents of al/ax/eax
;into a series of ascii HEX bytes base 16
;and write to destination string 

;input
;edi = address of destination buffer
;edx = 0 to convert eax  
;      1 to convert  ax 
;      2 to convert  al 
;
;return 
;string is 0 terminated and edi points to the 0

;the memory pointed to by edi must be large enough
;9 bytes required for eax 
;5 bytes required for ax
;3 bytes required for al
;******************************************************

ebx2hex:
	mov eax,ebx
eax2hex:

	push eax
	push ecx
	push ebp

	mov ecx,8  ;to display the entire eax we need 8 nibbles

	cmp edx,0
	jz .2
	cmp edx,2
	jz .1
	
    ;to display ax
	rol eax,16 ;mov ax up to hi 16 bits of eax
	mov ecx,4  ;display 4 nibbles
	jmp .2
	
	
    ;to display al
.1:	rol eax,24 ;mov al up to hi 8 bits of eax
	mov ecx,2  ;display 2 nibble
 

	;get the first nibble ready
.2:	rol eax,4   ;move hi nibble to al
	mov ebp,eax ;save a copy 
	and eax,0xf ;mask off all but al



.3: ;loop ecx times

	;this is the code that 
	;converts the nibble to ascii hex
	;see John Eckerdahls website
	cmp al,10
	sbb al,69h
	das  ;al contains the ascii char
	
	;write the char to string
	mov [edi],al

	;increment some things
	inc edi
	rol ebp,4
	mov eax,ebp
	and eax,0xf  
	loop .3

	;0 terminate
	mov byte [edi],0

	pop ebp
	pop ecx
	pop eax
	ret
	


;****************************************************
;eax2dec
;convert the contents of eax
;into a series of ascii DECIMAL base 10 bytes
;and write to destination string 

;input
;push Address of dest buffer                   [ebp+16] 
;push 0=unsigned dword, 1=signed dword         [ebp+12]
;push 0=zero terminate, 1=dont zero terminate  [ebp+8]

;return
;edi holds address of last char written

;local variable
haveneg dd 0
_eax10buf times 15 db 0
;****************************************************

ebx2dec:    ;userland
	mov eax,ebx
eax2dec:    ;kernel

	push ebp
	mov ebp,esp

	;init this variable to assume we dont have a neg number
	mov dword [haveneg],0


	push esi
	push edx
	push ecx
	push ebx
	push eax

	;zero out the local buffer
	mov edi,_eax10buf
	mov ecx,15
	push eax
	mov al,0
	cld
	rep stosb 
	pop eax                     ;our value to convert

	;do we have unsigned ?
	cmp dword [ebp+12],0
	jz .doneneg
	;we have a signed dword
	cmp eax,0    ;test dword for < 0
	jge .doneneg
	;make it pos and later insert (-) sign into string
	neg eax   
	mov dword [haveneg],1
.doneneg:

	
	mov ebx,10                  ;our base (denominator)
	;0xffffffff requires 10 ascii decimal characters
	mov ecx,10                  ;loop count
	
.divloop:
	;our value in eax is repeatedly divided by 10
	xor edx,edx  ;zero out
	div ebx      ;eax/ebx, quotient in eax, remainder in edx
	add edx,0x30 ;convert to ascii
	;dl contains the ascii char

	;store and increment from right to left starting at end of buffer
	mov [_eax10buf+ecx-1],dl   ;store in buf from right to left
	cmp eax,0                  ;were done if quotient is 0
	loopnz .divloop            ;dec ecx, jmp if ecx not 0 and zf not set
	;ecx=10-qtybytes in base10 string


	;insert neg sign if appropriate
	mov edi,[ebp+16]
	cmp dword [haveneg],1
	jnz .notneg
	mov al,'-'
	stosb	
.notneg:

	;now copy from _eax10buf to dest buffer left justified
	mov edx,10
	sub edx,ecx
	xchg edx,ecx
	;ecx=qty bytes and edx=10-qtybytes
	lea esi,[_eax10buf+edx]
	rep movsb


	;0 terminate
	cmp dword [ebp+8],1
	jz .dontzeroterminate
	mov byte [edi],0
.dontzeroterminate:

	pop eax
	pop ebx
	pop ecx
	pop edx
	pop esi
	pop ebp
	retn 12

	






;************************************************
;eax2bin
;convert eax to 32bit binary 0 terminated string
;input
;edi=address of dest 33 byte buffer 
;return
;string is 0 terminated and edi points to the 0
;leading zeros are ignored
;***********************************************

ebx2bin:
	mov eax,ebx
eax2bin:
	push ecx
	push edx

	;store index of first set bit in ecx moving bit32->bit0
	;(skip leading 0 bits) bsr=bit scan reverse
	;if eax=0 then ZF is set and ecx is undefined
	bsr ecx,eax
	jz .eaxiszero

.mainloop:
	bt eax,ecx         ;set/clear cf
	setc dl            ;put bit in dl
	add dl,0x30        ;convert 2 ascii
	mov byte [edi],dl  ;write 2 dest buffer
	inc edi
	dec ecx
	jns .mainloop
	jmp .terminate

.eaxiszero:
	mov byte [edi],0x30 
	inc edi

.terminate:
	mov byte [edi],0  ;terminator
	pop edx
	pop ecx
	ret
		


;****************************************************
;eaxstr
;this function generates an ascii string like this:
;"xxxxxxxx This is a string tag",0
;xxxxxxxx is value of eax in hex
;then follows a space then a string tag 
;which describes the value of eax
;the entire string is 0 terminated
;a similar function that writes to the dump is dumpeax

;input
;push Address of 0 terminated string tag    [ebp+12]
;push Address of dest buffer                [ebp+8] 
;return:none
;****************************************************

ebxstr:
	mov eax,ebx
eaxstr:
	push ebp
	mov ebp,esp
	pushad

	mov edi,[ebp+8]
	mov edx,0   ;convert eax
	call eax2hex
	;edi points to 0 terminator

	mov byte [edi],SPACE
	add edi,1

	;copy string tag
	mov esi,[ebp+12]
	;edi is set above
	call strcpy

	;0 terminator
	mov byte [edi],0

	popad
	pop ebp
	retn 8






;*********************************************************
;str2eax
;convert numerical string to dword in eax
;the string may be hex, dec or bin 
;hex has '0x' prefix
;bin has 'b' suffix
;all strings must be 0 terminated
;first we check for hex or bin
;if neither we assume dec and convert

;input:
;esi = address of 0 terminated string

;return:
;eax=dword value
;jz  to indicate successful conversion
;jnz to indicate error invalid char found in string

;local variable
_haveneg dd 0
_str2eax1 db 'str2eax:ParentString:',0
;*********************************************************


str2eax: 
	push ebx
	push ecx
	push edx
	push esi
	push edi
	push ebp

	;for debug
	;STDCALL _str2eax1,esi,dumpstrstr

	mov dword [_haveneg],0
	
	
	;do we have a hex string ?
	call ishexstring  ;esi=address of string
	jnz .trybinstring
	mov edi,16   ;hex multiplier
	add esi,2    ;inc pointer to str past 0x
	jmp .1


.trybinstring:
	call isbinstring  ;esi=address of string
	jnz .dodecstring
	mov edi,2         ;bin multiplier
	mov byte [ecx],0  ;overwrite 'b' with 0 terminator
	jmp .1
	

.dodecstring:
	;if not hex or bin we assume dec by default
	;this will return a garbage result
	;if there are invalid chars
	;conversion to decimal is multiply by 1,10,100,1000...
	mov edi,10   ;decimal multiplier
	;check for negative decimal
	cmp byte [esi],'-'
	jnz .1
	;increment past -
	inc esi
	mov dword [_haveneg],1

.1:
	;address of last char of string
	mov eax,esi          ;eax=start of string
	call strlen          ;ecx=strlen
	lea esi,[esi+ecx-1]  ;esi=address of last char of string

	xor ebx,ebx  ;ebx holds our cumulative total
	xor edx,edx  ;zero out upper bits for mul
	mov ebp,1    ;holds the cumulative multiplier
	std          ;want lodsb to decrement (move left)

.2:	
	xor eax,eax  ;lodsb does not zero out first
	lodsb        ;al=[esi], esi--

	;check for decimal 0-9
	call isdigit
	jnz .notdecimal  
	sub al,0x30      ;convert ascii dec to num
	jmp .3
	.notdecimal:

	;check for hex a-f
	call ishex
	jnz .nothex
	sub al,0x57 ;convert ascii hex to num
	jmp .3
	.nothex:

	;neither decimal nor hex, invalid digit
	add eax,1  ;clear zf to indicate failure
	jmp .done

.3:	
	mul ebp      ;eax * power of 10 or 16
	add ebx,eax  ;ebx stores the result
	
	;increase multiplier by 2 or 10 or 16
	mov eax,ebp
	mul edi      ;eax *=2 or *=10 or eax *=16
	mov ebp,eax  
	loop .2      ;bottom of loop


	;if (-) dec then make it so
	cmp dword [_haveneg],1
	jnz .4
	neg ebx


	;save our cumulative total for return
.4:	mov eax,ebx
	xor ebx,ebx   ;set zf to indicate success

.done:
	cld
	pop ebp
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	ret






;*****************************************************
;st02str        Aug 2012
;function converts the fpu value in st0
;to a 0 terminated ascii string signed decimal
;example: -123.456 or 789.5

;input 
;push address of 24 byte ascii dest buffer   [ebp+12]
;push number of decimal places (< 10)        [ebp+8] 

;return:none
;edi points to 0 terminator
;st0 is preserved

;if you have done some bad fpu programming
;then you may get a result like this:  +???<0000000.000000
;any attempt to display the contents of st0 after it is freed will result in this

;the string is 24 bytes long max but usually shorter
;if you have not changed the rounding mode then the numdecimals
;are rounded up so 123.456 is displayed as 123.5 
;if you ask for more decimals than the number has then zeros
;are appended so 123.456 with 6 decimals is displayed as 123.456000
;no zeros are written between the sign byte and the first non zero byte

;excellent help on fpu programming is "Simply FPU" by 
;Raymond Filiatreault

;local variable
bcdpacked    times 10 db 0x30
bcdunpacked  times 20 db 0x30
leadingzero      db 0
st02strstr1 db 'st02str conversion error',0
;*****************************************************

st02str:

	push ebp
	mov ebp,esp
	push eax
	push ecx
	push esi


	;check that qty decimals < whats in our PowerOfTen table
	cmp dword [ebp+8],10
	ja near .error 



	;load scale factor
	;to display 3 decimals we mul x 1000
	;to display 4 decimals we mul * 10000  etc
	mov eax,[ebp+8]
	fld dword [PowerOfTen + eax*4]
	;st0=scale factor 1,10,100..., st1=ourfloat


	;apply scale factor
	fmul st1   ;st0=ourfloat*scalefactor  st1=ourfloat


	;save st0 as 10 byte reversed order packed bcd
	;fbstp rounds to integer then converts to packed bcd
	;so if we take a number like -65536.12 after multiply by 1000 
	;and call fbstp we get: 
	;bcd = 0x12, 0x36, 0x55, 0x06, 00, 00, 00, 00, 00, 0x80
	;then after doing inplace reverse of the byte order we get:
	;bcd = 0x80, 00, 00, 00, 00, 00, 0x06, 0x55, 0x36, 0x12
	;the 0x8 holds the sign bit79 indicating a negative number else 0 
	;is a positive number
	fbstp [bcdpacked]  ;st0=ourfloat  (st0 is preserved)


	;inplace reverse the byte order of the 10 packed bcd
	mov ecx,5
	mov esi,bcdpacked 
	lea edi,[bcdpacked+9]
.reversebcd:
	mov al, [esi]
	xchg al,[edi]
	xchg al,[esi]
	inc esi
	dec edi
	loop .reversebcd



	;convert to unpacked bcd
	cld
	mov esi,bcdpacked
	mov edi,bcdunpacked
	mov ecx,10
.unpack:
	lodsb
	ror eax,4
	and al,0xf  ;mask off
	stosb       ;save left nibble
	rol eax,4
	and al,0xf
	stosb       ;save right nibble
	loop .unpack




	;prepare for unpacked bcd->ascii conversion 
	mov edi,[ebp+12]
	mov esi,bcdunpacked



	;write the sign byte
	;if its + we wont print anything
	lodsb
	cmp al,0
	jz .donesign
	;we have a negative number
	mov al,'-'
	stosb
.donesign:



	;convert the remaining 19 unpacked bcd bytes to ascii
	;ignore leading zeros
	;insert decimal point in proper position
	;******************************************************
	
	mov byte [leadingzero],0
	mov ecx,19
	mov edx,[ebp+8] 
	add edx,1        ;marker for when to insert decimal

.convert2ascii:
	lodsb
	cmp al,0
	jnz .NotZero
	;we have a 0 byte, is it a leading 0 ?
	cmp byte [leadingzero],0
	jz .checkfordecimalpoint   ;skip leading zero's
.NotZero:
	mov byte [leadingzero],1   ;now inserts zeros
	add al,0x30                ;convert to ascii
	stosb                      ;and save the byte
.checkfordecimalpoint:
	cmp ecx,edx
	jnz .nextchar
	;insert decimal point
	mov byte [leadingzero],1   ;now inserts zeros
	mov al,'.'
	stosb
.nextchar:
	loop .convert2ascii


	;0 terminator
	mov byte [edi],0   ;0 terminator
	jmp .done

.error:
	STDCALL st02strstr1,dumpstr
.done:
	pop esi
	pop ecx
	pop eax
	pop ebp
	retn 8





;*********************************************************************
;str2st0
;convert a 0 terminated ascii string to a floating point value in st0
;string must be a base 10 numerical value 
;string should contain a decimal point but can handle without

;input:
;ebx=address of string (must be < 50 bytes long)

;return:
;qword double precision floating point value written to st0
;the calling program is responsible for ffree-ing st0

;this code is based on DQ in ttasm
exponent     dd 0
significant  dd 0
HaveNegative dd 0

st0str0 db 'str2st0',0
st0str1 db 'str2st0:exponent',0
st0str2 db 'str2st0:significant',0
st0str3 db 'str2st0:error hit byte 50',0
;*********************************************************************

str2st0:

	pushad

	STDCALL st0str0,dumpstr

	;request 100 bytes for some scratch space
	mov ecx,100
	call alloc
	mov ebp,esi
	;ebp holds address of memory block allocated


	;do we have a negative number
	mov dword [HaveNegative],0  ;init to 0
	cmp byte [ebx],'-'
	jnz .donenegative
	mov dword [HaveNegative],1
	inc ebx  ;ebx now points to first char after -
.donenegative:

	;copy the dq string to ebp without the decimal
	;count numdecimals
	mov esi,ebx
	cld
	xor edx,edx
	xor ebx,ebx
	mov ecx,50
	mov edi,ebp

.getbyte:
	lodsb       ;[esi]->al, esi++
	cmp al,'.'
	jnz .notDot
	mov ebx,1
	jmp .getbyte
.notDot:
	stosb          ;al->[edi], edi++
	add edx,ebx    ;edx holds numdecimals
	dec ecx
	jz near .HitByte50 ;reached byte 50 b4 0 terminator
	cmp al,0           ;check for 0 terminator
	jnz .getbyte


	;process the exponent 
	cmp edx,0  ;string does not contain a decimal point
	jz .skipdec
	dec edx  ;num decimals
.skipdec:
	neg edx
	mov [exponent],edx
	mov eax,edx
	;STDCALL st0str1,0,dumpeax


	;convert the significant string to eax
	mov esi,ebp
	call str2eax
	;save the significant
	mov [significant],eax
	;STDCALL st0str2,0,dumpeax


	;load the exponent into the fpu
	;for the following comments we will use the 
	;floating point number 5.678
	;significant=5678
	;exponent=-3
	fild dword [exponent]    ;st0=-3

	;load the log base 2 of 10
	fldl2t               
	;st0=3.322, st1=-3

	fmulp st1
	;st0=-9.966

	;copy st0
	fld st0
	;st0=st1=-9.966

	;change the rounding mode of the fpu to truncate
	fstcw word [oldCW]  ;store control word
	mov ax,[oldCW]
	or ax,0xc00
	mov [newCW],ax
	fldcw word [newCW]  ;load new control word

	;round st0 to int
	;without changing the rounding mode to truncate
	;we would instead get st0=-10.000 which is wrong
	frndint
	;st0=-9.000, st1=-9.966

	fsub st1,st0
	;st0=-9.000, st1=-0.966

	fxch
	;sto=-0.966, st1=-9.000

	f2xm1
	;st0=(2^^-0.966 - 1)=-0.488, st1=-9.000

	fld1
	;st0=1.000, st1=-0.488, st2=-9.000

	faddp st1
	;st0=0.512, st2=-9.000

	fscale
	;st0=0.512 * 2^^-9.000, st1=-9.000

	fild dword [significant]
	;st0=5678, st1=0.001, st2=-9.000

	fmul st1
	;st0=5.678, st1=0.001, st2=-9.000



	;set the sign
	cmp dword [HaveNegative],1
	jnz .doneChangeSign
	fchs
.doneChangeSign:

	;st0 holds our return value


	;change the rounding mode back to nearest
	fldcw word [oldCW]

	;free the fpu registers we left full except for our return value in st0
	ffree st1
	ffree st2

	jmp .done

.HitByte50:
	STDCALL st0str3,dumpstr
.done:
	mov esi,ebp
	call free
	popad
	ret












;*********************************************************************
;reg2str
;generates an ascii text string of the contents of
;all 8 generate purpose 32bit registers plus EIP and eflags
;this routine takes the dword values stored in memory by getreginfo 
;and builds a 0 terminated  ascii string displaying 
;the value of the 8 general pupose registers + eflags 
;+ 4 dwords on the stack 

;input:none
;return:none

;the ascii hex output looks like this:
;eax=xxxxxxxx ebx=xxxxxxxx ecx=xxxxxxxx edx=xxxxxxxx  ebp=xxxxxxxx 
;esp=xxxxxxxx esi=xxxxxxxx edi=xxxxxxxx eflag=xxxxxxxx 

;the string is 0 terminated and written to "reginfostring" 

;this is a 2 step process
;[1] In some local function call getreginfo to store the current value of the registers 
;[2] call reg2str to build the ascii reginfo string

;for an example of how to use these functions
;see "stackreg" in stack.s
;see also "dumpreg" below

;nowhere do we get the value of eip
;eip is hard to get and with the pentiums prefetching and 
;u/v pipes it seems hard to know exactly what the pentiums doing
;but anyway to know the value of eip I suggest doing
;"pop eax  then push eax" as the first lines of a function proc
;since the ret value is always on top the stack

;the reginfo string is written here
reginfostring times 124 db 0

;Local Data
_editg db 'edi=',0
_esitg db 'esi=',0
_ebptg db 'ebp=',0
_esptg db 'esp=',0
_ebxtg db 'ebx=',0
_edxtg db 'edx=',0
_ecxtg db 'ecx=',0
_eaxtg db 'eax=',0
_eflagtg db 'eflag=',0


RegTagTable:
dd _eaxtg, _ebxtg, _ecxtg, _edxtg, _ebptg
dd _esptg, _esitg, _editg, _eflagtg
;*****************************************************************

reg2str:
	pushad

	mov ecx,0  
	mov edi,reginfostring

.1:
	;copy register tag "eax=...ebx=..."
	mov esi, [RegTagTable + ecx*4]
	call strcpy  ;edi points to end 

	;get register value
	mov eax,[0x570+ecx*4]
	mov edx,0 ;convert eax
	call eax2hex

	;put a space
	mov byte [edi],SPACE
	inc edi

	;insert NL breaks
	cmp ecx,4
	jz .insertnewline
	cmp ecx,8
	jz .insertnewline
	jmp .increment

.insertnewline:
	mov byte [edi],NL
	inc edi

.increment:
	inc ecx
	cmp ecx,9  ;qty items in RegTagTable
	jb .1


	;0 terminate
	mov byte [edi],0

	popad
	ret




getreginfo:
	
	push eax

	;8 general purpose 32bit registers
	mov [0x570],eax
	mov [0x574],ebx
	mov [0x578],ecx
	mov [0x57c],edx
	mov [0x580],ebp
	mov [0x584],esp
	mov [0x588],esi
	mov [0x58c],edi


	;get eflags
	pushfd
	pop dword [0x590]


	;get values off the stack
	mov eax,[esp]
	mov [0x5a0],eax
	mov eax,[esp+4]
	mov [0x5a4],eax
	mov eax,[esp+8]
	mov [0x5a8],eax
	mov eax,[esp+12]
	mov [0x5ac],eax


	pop eax
	ret
	
	



;***********************************************************
;printf
;This function builds complex ascii strings by combining
;the strcpy, eax2dec and st02str functions into one
;the function can handle a variable number of arguments
;the string is not displayed, use puts to display

;input:
;ecx=qty of arguments 
;ebx=address of arguments type array
;esi=address of arguments list array
;edi=address of destination buffer

;return:
;ZF is set on error and clear on success
;the 0 terminated string is written to the destination buffer

;valid argument types:
;type 1=address of dword containing a byte in bits7:0 to be displayed as ascii
;type 2=address of dword to be displayed as ascii decimal unsigned
;type 3=address of 0 terminated ascii string
;type 4=address of qword floating point value to be displayed as ascii with 3 decimals

;Example String: 
;"The value in ebx is 234 and the value in ecx is 12",0

;string1 db 'The value in ebx is ',0
;number1 dd 234  (may be computed on the fly then saved here)
;string2 db ' and the value in ecx is ',0
;number2 dd 12

;the argtype and arglist are both arrays of dwords
;argtype dd 3,2,3,2
;each element of the arglist is a memory address for a string or dword or qword float ...
;arglist dd string1,number1,string2,number2

;mov ecx,4
;mov ebx,artype
;mov esi,arglist
;mov edi,AddressDestinationBuffer
;call printf

pfstr1 db 'printf:invalid argument type',0

_printfBuffer times 30 db 0
;******************************************************************************

printf:

	;get arg type
	mov eax,[ebx]

	cmp eax,1
	jz .doAsciiByte
	cmp eax,2
	jz .doDwordInt
	cmp eax,3
	jz .doString
	cmp eax,4
	jz .doFloat
	jmp .error  ;bail


.doAsciiByte:
	mov edx,[esi]   ;get the address of the dword
	mov eax,[edx]   ;get the dword
	mov [edi],al    ;copy the ascii byte
	inc edi
	jmp .nextarg


.doDwordInt:
	mov edx,[esi]   ;get the address of the dword
	mov eax,[edx]   ;get the dword
	push edi
	push 0          ;unsigned dword
	push 0          ;0 terminate
	call eax2dec
	jmp .nextarg


.doString:
	push esi        ;preserve
	mov esi,[esi]   ;get the string address
	call strcpy
	pop esi
	jmp .nextarg


.doFloat:
	mov edx,[esi]   ;get the address of the qword
	fld qword [edx] ;load qword in st0
	push edi
	push 3          ;num decimals
	call st02str
	ffree st0



.nextarg:
	add ebx,4  ;advance argtype array
	add esi,4  ;advance arglist array
	dec ecx
	jnz printf


.success:
	mov byte [edi],0   ;0 terminate the dest string
	or eax,1           ;clear ZF on success
	jmp .done
.error:
	STDCALL pfstr1,dumpstr
	xor eax,eax  ;set ZF on error
.done:
	ret




;**************************************************************************
;squeeze
;remove all SPACE bytes from an ascii string
;input
;esi=address of 0 terminated string
;return
;the compressed string is written to the same address and 0 terminated
;*************************************************************************

squeeze:
	;esi holds address of the byte being examined
	;edi holds address of where the byte should be written
	;esi will advance thru spaces to the next non space byte while edi stays behind

	pushad
	mov edi,esi

.1:
	mov al,[esi]  ;get byte

	cmp al,SPACE
	jz .haveSpace
	cmp al,0
	jz .haveTerminator

	;if we got here we have a char that is not a space and not 0

	;check for edi=esi=nonspace
	cmp edi,esi
	jz .advanceboth

	;edi!=esi so save byte
	mov [edi],al
	jmp .advanceboth

.haveSpace:
	inc esi  ;advance esi leaving edi in the dust
	jmp .1

.advanceboth:
	inc esi
	inc edi
	jmp .1

.haveTerminator:
	mov byte[edi],0
	popad
	ret


;*********************************************************
;StripTrailingSpace
;remove all SPACE bytes from the end of an ascii string
;this function finds the 0 terminator, backs up
;to the first non-SPACE then inserts a new 0
;terminator 1 byte after this
;function assumes string is less than 100 bytes long
;input:
;edi=address of 0 terminated string
;return:none
;********************************************************

StripTrailingSpace:

	pushad

	cmp byte [edi],NL
	jz .done
	cmp byte [edi],0
	jz .done

	;find the 0 terminator end of string, max 100 bytes in string
	mov al,0
	mov ecx,100
	cld
	repne scasb
	;edi goes 1 byte past 0

	dec edi  ;edi is at 0 terminator

	cmp byte [edi-1],SPACE
	jnz .done

	;backup to the first non SPACE
.backup:
	dec edi
	cmp byte [edi],SPACE
	jz .backup

	;insert new 0 terminator
	inc edi
	mov byte [edi],0

.done:
	popad
	ret









;****************************************************************
;flag2str
;builds a 0 terminated string
;showing which of the Eflags are set
;e.g. "FLAGS CF ZF DF"
;the string is written to "flagstrbuf"
;see putflags or dumpflags 
;input:none

;the following flags are supported and will be displayed if set
;CF=carry flag set bit0
;ZF=zero flag set bit6
;SF=sign flag set bit7
;DF=direction flag set bit10
;OF=overflow flag set bit11

flagstrbuf times 30 db 0
;****************************************************************

_Flags db 'FLAGS '
_CFset db 'CF '
_ZFset db 'ZF '
_SFset db 'SF '
_DFset db 'DF '
_OFset db 'OF '


flag2str:

	;preserve
	pushfd  
	pushad
	
	;put eflags into eax
	pushfd
	pop eax


	;tag "FLAGS"
	mov edi,flagstrbuf
	mov esi,_Flags
	mov ecx,6  
	call strncpy

	;carry flag
	bt eax,0
	jnc .carrynotset
	mov esi,_CFset
	mov ecx,3  
	call strncpy
.carrynotset:

	;zero flag
	bt eax,6
	jnc .zeronotset
	mov esi,_ZFset
	mov ecx,3  
	call strncpy
.zeronotset:

	;sign flag
	bt eax,7
	jnc .signnotset
	mov esi,_SFset
	mov ecx,3  
	call strncpy
.signnotset:

	;direction flag
	bt eax,10
	jnc .dirnotset
	mov esi,_DFset
	mov ecx,3  
	call strncpy
.dirnotset:

	;overflow flag
	bt eax,11
	jnc .overnotset
	mov esi,_OFset
	mov ecx,3  
	call strncpy
.overnotset:


.terminate:
	;0 terminate
	mov byte [edi],0

	popad
	popfd

	ret





;*************************************************************
;splitstr
;split a parent string consisting of substrings seperated by 
;some ascii byte like comma or plus

;the parent string is "squeezed" to remove all spaces
;all instances of the seperator byte in the parent string
;are overwritten with 0

;this function writes to destination memory an array of
;dword substring addresses, the addresses are stored one after
;the other with no space or seperating bytes between

;input:
;push dword starting address of parent string              [ebp+20]
;push dword seperator byte (usually COMMA or PLUS)         [ebp+16]
;push dword max qty substrings allowed                     [ebp+12]
;push dword address of destination memory block            [ebp+8]
;     large enough to hold address of each substring
;     one dword per substring is needed

;returns:
;eax=0 error
;eax=1 parent string only
;eax=n found n substrings 

;this function deals with a string of ascii characters
;consisting of substrings seperated by commas , or plus + sign
;e.g. 1,2,3,4,5,6 
;e.g. apple+0x4567
;e.g. Tom,Karin,Nathaniel,Emily

;in this example the 1st substring is "Tom" and its address is still "ParentString"
;the 2nd substring is "Karin" and its address is stored at     [Dest]
;the 3rd substring is "Nathaniel" and its address is stored at [Dest+4]
;the 4th substring is "Emily" and its address is stored at     [Dest+8]

;e.g. 'Main+ebx+1234',0  is the parent string and PLUS is the seperator byte
;this string will be split by splitstr as follows:
;     'Main',0,'ebx',0,'1234',0
;and the address of 'e' and the address of '1' will be stored
;in the destination substring memory block

;all spaces, leading, trailing and inbetween are removed
;parent string may not be longer than 100 characters

;note: only 1 seperator byte can be used multiple times in the parent string,
;typically COMMA or PLUS but not both

;the memory block which stores the starting address of each substring
;does not store the starting address of the parent string
;the first address stored is the first substring found after the first 0 terminator

;local
_splitstr1 db 'splitstr:parent string:',0
_splitstr2 db 'splitstr:qty substrings',0
_splitstr3 db 'splitstr:too many substrings',0
_splitstr4 db 'splitstr:no seperator byte',0
_splitstr5 db 'splitstr:lodsb returns',0
_splitstr6 db 'splitstr debug qty seperator bytes found',0
;********************************************************


splitstr:

	push ebp
	mov ebp,esp
	push ebx
	push ecx
	push esi
	push edi

	;remove all spaces
	mov esi,[ebp+20]
	call squeeze

	;dump the squeezed parent string
	STDCALL _splitstr1,[ebp+20],dumpstrstr
	

	;check for at least 1 seperator byte in the parent string
	;if no byte is found we exit 
	mov edi,[ebp+20]  ;parent string
	mov eax,[ebp+16]  ;seperator
	call strchr
	jz near .parentstringonly


	cld
	xor eax,eax
	mov ebx,0         ;qty seperator bytes found
	mov ecx,100       ;we will search at most 100 bytes of parent string
	mov esi,[ebp+20]  ;parent string
	mov edi,[ebp+8]   ;memory block to store substring addresses

.1:

	lodsb   ;al=[esi], esi++

	;debug only
	;STDCALL _splitstr5,2,dumpeax

	;check for end of parent string
	cmp al,0
	jz .endParentString

	;check for seperator byte
	cmp eax,[ebp+16]
	jnz .notseperator

	;overwrite seperator byte with 0
	mov byte [esi-1],0

	;save starting address of first byte after 0 terminator 
	;this marks the start of a substring
	mov [edi+ebx*4],esi

	;inc qty seperator bytes found
	inc ebx


	;check to make sure we dont save too many substrings
	cmp ebx,[ebp+12]
	jae .error

.notseperator:
	loop .1

	;if we got here we failed to find a 0 byte within 100 chars


.error:
	;if we got here we are in trouble-too many substrings
	STDCALL _splitstr3,dumpstr
	mov eax,0
	jmp .done
	
.parentstringonly:
	STDCALL _splitstr4,dumpstr
	;no seperator byte was found
	;we have only the 0 terminated parent string
	mov eax,1
	jmp .done

.endParentString:
	inc ebx       ;QtySubstrings = QtySeperatorsBytes + 1
	mov eax,ebx   ;return qty substr in eax
	STDCALL _splitstr2,0,dumpeax

.done:
	pop edi
	pop esi
	pop ecx
	pop ebx
	pop ebp
	retn 16




;*************************************************************
;mem2str
;convert bytes in memory to 0 terminated ascii string
;this function generates 3 ascii bytes for each memory byte
;input
;push address of source memory to convert     [ebp+16]
;push address of destination ascii string     [ebp+12]
;push qty bytes to convert                    [ebp+8]
;*************************************************************

mem2str:

	push ebp
	mov ebp,esp
	pushad

	mov esi,[ebp+16]
	mov edi,[ebp+12]
	mov ecx,[ebp+8]
	cld


.1:	
	lodsb         ;[esi]->al, esi++

	;hi nibble
	ror eax,4
	and al,0xf
	cmp al,10     ;conversion to ascii
	sbb al,69h
	das           ;al contains the ascii char
	stosb         ;al->[edi], edi++ 	

	;low nibble
	rol eax,4
	and al,0xf
	cmp al,10
	sbb al,69h
	das           ;al contains the ascii char
	stosb         ;al->[edi], edi++ 	
	
	;seperator
	mov al,SPACE
	stosb

	loop .1


	;0 terminator
	mov al,0
	stosb

	popad
	pop ebp
	retn 12



