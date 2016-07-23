;tatOS/tlib/dump.s

;rev: Feb 01, 2016  dumpst0

;various functions to write ascii bytes to a special block of memory
;we call the "dump". Useful for debugging

;dumpbyte, dumpspace, dumpnl, dumpreset, dumpview, dumpstr, dumpstrn
;dumpstrnol, dumpchar, dumpst0, dumpst09, dumpeax (kernel), dumpebx (user), 
;dumpstack, dumpreg, dumpflags, dumpPoints, dumpmem, dumpbitfield, 
;dumpheader, dumpcsv, dumpstrquote, dumpFPUstatus, 
;dumpstrstr, dumpeaxstrn



;our "dump" is a block of memory starting at STARTOFDUMP
;2meg is currently reserved
;all routines append ascii bytes to the dump
;this code was originally added to examine keypress scancodes
;it is also useful for debugging just about anything
;where you cant just printout stuff to the screen immediately
;ttasm uses this code extensively for providing feedback

;make sure if you add a new dump function that you 
;properly check the value of the _dumptr and exit
;all good practice to prevent buffer overflow of the dump

;WARNING !!!!
;Arguments:
;unlike most tlib functions which use registers to pass args
;we do not use registers but we use the stack
;we use the PASCAL (simto Microsoft _stdcall) calling convention 
;all args are "push"ed on the stack and
;the subroutine is responsible for cleanup of the stack args
;this is done using "retn 4" for 1 arg or "retn 8" for 2 args...
;see Paul Carter "PC Assembly Language" for more info on this
;also beware: DO NOT write to EBP in your subroutine

;if 1 arg to function:
;esp=ebp->   saved ebp
;ebp+4--->   return address
;ebp+8--->   arg 1
;ret 4

;if 2 args to function:
;esp=ebp->   saved ebp
;ebp+4--->   return address
;ebp+8--->   arg 2
;ebp+12-->   arg 1
;ret 8

;if 3 args to function:
;esp=ebp->   saved ebp
;ebp+4--->   return address
;ebp+8--->   arg 3
;ebp+12-->   arg 2
;ebp+16-->   arg 1
;ret 12

;example usage for 1 arg:
;	push AddressOfString
;	call [DUMPSTR]
;or using the tatos STDCALL macro:
;STDCALL AddressofString,[DUMPSTR]


;_dumpptr holds the address of where the next byte will be written
;all routines that use the dump should first check this value
;do not exceed MAXDUMPADDRESS   
_dumptr dd STARTOFDUMP

%define MAXDUMPADDRESS STARTOFDUMP+0x200000 




;**********************************************
;dumpbyte
;input: push dword value to be copied to dump
;       only low 8 bits of dword are used
;**********************************************
dumpbyte:
	push ebp
	mov ebp,esp
	pushad

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done

	mov ebx,[_dumptr]

	;our data resides on the stack at ebp+8
	mov ecx,[ebp+8]  
	mov [ebx],cl

	;must manually update _dumptr
	inc dword [_dumptr]
	
.done:
	popad
	pop ebp
	retn 4   ;clean up 1 arg


;no input and no cleanup
dumpspace:
	push SPACE
	call dumpbyte
	ret
	
;no input and no cleanup
dumpnl:
	push NEWLINE
	call dumpbyte
	ret


;**********************************************
;dumpreset
;no input and no cleanup
;zero out 2meg starting at STARTOFDUMP
;use this to zero out the dump
;as strings are appended to the dump
;this ensures a 0 terminator to the file
;be careful using this because it wipes out all 
;previous messages which may be useful
;**********************************************

dumpreset:

	pushad
	
	mov edi,STARTOFDUMP
	mov dword [_dumptr],edi

	;zero out the memory pointed to by edi
	mov ecx,0x200000 ;qty bytes
	mov al,0         ;set to 0
	cld              ;increment
	rep stosb        ;al->edi do ecx times

	popad
	ret





;*****************************************
;dumpview
;invoke viewtxt.s to display dump contents
;use if dump contains ascii bytes
;input:none
;return:none

;note viewtxt uses black text
;the 0xff background color in the dac palette
;must be a light color or else the
;text wont show
;*****************************************

dumpview:

	;no need to 0 terminate
	;because dumpreset zeros all the memory
	;now invoke viewtxt to show the dump

	mov esi,STARTOFDUMP 
	call viewtxt
	ret
	



;***************************************************
;dumpstr
;copies a 0 terminated ascii string to the dump
;will stop after 300 bytes for protection
;the 0 terminator is overwritten with NEWLINE 
;input: 
;push address of 0 terminated ascii source string
;***************************************************

dumpstr:

	push ebp
	mov ebp,esp
	pushad
	pushfd              ;for the benefit of dumpflags


	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done

	mov esi,[ebp+8]     ;Address of string to display
	mov edi,[_dumptr]   ;destination
	cld
	xor ecx,ecx

.fetchbyte:

	;quit when we find 0 terminator
	cmp byte [esi],0
	jz .newline

	movsb                ;copy the byte
	inc dword [_dumptr]  ;inc dump ptr
	inc ecx              ;inc qty bytes copied

	;or quit after 300 bytes
	;this is protection for strings lacking the 0
	cmp ecx,300
	jb .fetchbyte

.newline:
	call dumpnl

.done:
	popfd
	popad
	pop ebp
	retn 4   ;clean up 1 arg
	

;***************************************************
;dumpstrn
;dump an ascii string that is not zero terminated
;input:
;push address of ascii source string   [ebp+12]
;push qty bytes in string              [ebp+8]

;caution! 
;since the dump is 0 terminated
;we will examine every byte and if the ascii string
;contains a 0 we will stop writting to the dump
;and the string will be truncated.
;**************************************************

dumpstrn:

	push ebp
	mov ebp,esp
	pushad

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done

	cld
	mov esi,[ebp+12]  ;Address of string to display
	mov edi,[_dumptr]
	mov ecx,[ebp+8]   ;qty bytes

.1:
	lodsb            ;al=[esi], esi++  read the byte
	cmp al,0         ;check for 0 which would terminate the dump
	jz .2
	stosb            ;[edi],al, edi++  write to the dump
	dec ecx
	jnz .1

.2: ;finish up:redefine dumptr and add a NL to the dump
	;edi points to the end of the dest string
	mov [_dumptr],edi
	call dumpnl

.done:
	popad
	pop ebp
	retn 8   
	



;*********************************************************
;dumpstrnol
;dump-string-no-line
;same as above but does not add newline
;permits building more complicated strings on the same line
;typically you would make multiple calls to this function
;then end with a call to dumpnl
;input: ;push address of 0 terminated ascii source string
;*********************************************************
dumpstrnol:
	push ebp
	mov ebp,esp
	pushad

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done

	mov esi,[ebp+8]  ;Address of string to display
	mov edi,[_dumptr]
	call strcpy
	mov [_dumptr],edi
	
.done:
	popad
	pop ebp
	retn 4   ;clean up 1 arg
	


;**************************************************
;dumpchar
;displays the contents of al as ascii hex
;followed by a space
;input: none
;written to view the output of functions that
;compute values from 0-0xff
;**************************************************
dumpchar:
	pushad

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done

	call dumpnl

	mov edi,[_dumptr]
	mov edx,2 ;convert al
	call eax2hex
	mov [_dumptr],edi

	call dumpnl

.done:
	popad
	ret



;*******************************************************************************
;dumpst0
;dump the contents of the fpu st0 register with a string tag preceeding

;this works opposite of dumpeax, first string tag appears then value in st0
;"my string tag "1.234
;"Length of Apple = "3.456

;the value in st0 defaults to 3 decimal places

;input:
;push address of string tag, if address=0 then skip string  [ebp+8]
;return:none

;kernel functions may use this string tag 
_st0tag db 'ST0=',0
;******************************************************************************

dumpst0:

	push ebp
	mov ebp,esp
	pushad

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done


	;check for a value string tag address
	cmp dword [ebp+8],0
	jz .1


	;string tag
	push dword [ebp+8]
	call dumpstrnol

	;there are no spaces inserted after the string tag
	;user may append spaces to his string to create space if desired
	
.1:
	;value in st0
	push dword [_dumptr] ;destination
	push 3               ;numdecimals fixed at 3
	call st02str
	mov [_dumptr],edi

	;overwrite 0 terminator with 0xa newline
	call dumpnl
	
.done:
	popad
	pop ebp
	retn 4






;*******************************************************************************
;dumpst09
;dump the contents of the fpu st0 register to 9 decimal places
;same as above only more precision
;this will produce a 0 terminated floating point string up to 27 bytes long
;e.g. 123.123456789, see st02str for details
;defaults to 9 decimal places
;input:none
;return:none
;local variable
;******************************************************************************

dumpst09:
	pushad

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done

	push _st0tag
	call dumpstrnol      ;"ST0="
	
	push dword [_dumptr] ;destination
	push 9               ;numdecimals
	call st02str
	mov [_dumptr],edi

	;overwrite 0 terminator with 0xa newline
	call dumpnl
	
.done:
	popad
	ret








;****************************************************************
;dumpeax

;displays contents of al/ax/eax as ascii hex 
;or as signed decimal
;then display a SPACE then display an ascii string
;example:  "ff123456 This is the value of apple"

;input: 
;push address of string tag, if address=0 then skip string
;push register size 0=dword, 1=word, 2=byte, 3=signed decimal

;return: none
;****************************************************************

dumpebx:
	mov eax,ebx
dumpeax:

	push ebp
	mov ebp,esp
	pushad

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done

	;edi holds address of destination buffer
	mov edi,[_dumptr]

	;decimal conversion
	cmp dword [ebp+8],3
	jnz .donedecimal
	push dword [_dumptr]
	push 1    ;signed
	push 0    ;zero term
	call eax2dec
	jmp .dospace
.donedecimal:

	;hex conversion 
	mov edx,[ebp+8] ;convert al/ax/eax
	call eax2hex

.dospace:
	mov [_dumptr],edi
	call dumpspace

	;do string comment
	cmp dword [ebp+12],0
	jz .skipstring
	push dword [ebp+12]
	call dumpstr  ;function also puts NL
.skipstring:

.done:
	popad
	pop ebp
	retn 8   ;clean up 2 arg




;****************************************************************
;dumpeaxstrn
;similar to dumpeax except the tag string is not 0 terminated
;and the numerical value is dword hex only
;input: 
;push dword address of string tag    [ebp+12]
;push dword string length            [ebp+8]
;return: none
;****************************************************************

dumpeaxstrn:

	push ebp
	mov ebp,esp
	pushad

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done

	;edi holds address of destination buffer
	mov edi,[_dumptr]

	;hex conversion 
	;edi=address of dest buffer
	mov edx,0   ;dword hex numerical value
	call eax2hex

	;add a space
	mov [_dumptr],edi
	call dumpspace

	;add the strn comment
	push dword [ebp+12]  ;address of string
	push dword [ebp+8]   ;strlen
	call dumpstrn     

.done:
	popad
	pop ebp
	retn 8   ;clean up 2 arg





;**************************************************
;dumpstack
;dump a dword on the stack as hex 
;this is a stripped down version of dumpeax
;input: 
;push address of 0 terminated string  [ebp+12]
;push dword value to dump             [ebp+8]        
;return: both values are poped off the stack
;**************************************************

dumpstack:

	push ebp
	mov ebp,esp
	pushad

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done

	;hex conversion 
	mov eax,[ebp+8]    ;our dword to dump
	mov edi,[_dumptr]  ;destination buffer
	mov edx,0          ;convert eax
	call eax2hex

.dospace:
	mov [_dumptr],edi
	call dumpspace

	;dump the string tag
	cmp dword [ebp+12],0
	jz .skipstring
	push dword [ebp+12]
	call dumpstr  ;function also puts NL
.skipstring:

.done:
	popad
	pop ebp
	retn 8   ;clean up 2 arg






;*****************************************************
;dumpreg
;dumps a string showing the contents of the 
;8 general purpose reg + eflags 
;input:none 
;return:none

;this function produces an ascii hex output like this:
;eax=xxxxxxxx ebx=xxxxxxxx ecx=xxxxxxxx edx=xxxxxxxx ebp=xxxxxxxx
;esp=xxxxxxxx esi=xxxxxxxx edi=xxxxxxxx eflag=xxxxxxxx
;*****************************************************
dumpreg:

	;get EIP
	pop dword [0x590] 
	push dword [0x590] 

	call getreginfo
	call reg2str    ;writes string to "reginfostring"

	push reginfostring
	call dumpstr

	ret



;****************************************************************
;dumpflags
;appends to the dump the string generated by "flag2str"
;if the bit of eflags is set it will be displayed
;see flag2str for a list of the supported flags
;e.g. "FLAGS CF ZF DF"
;see also putflags
;input:none
;return:none
;****************************************************************


dumpflags:
	call flag2str  
	push flagstrbuf
	call dumpstr
	ret




;***********************************************
;dumpPoints
;display an array of dword Points to the dump
;a Point is 2 dwords x,y
;the Points are displayed as decimal
;the output looks like this:
;X     Y
;100   300
;250   466

;input
;push address of Points array   [ebp+12]
;push qty Points                [ebp+8]

;local variable
dumpPointsHeader db 'X      Y',0
dumpspaces       db '    ',0
pointbuf  dd 0
;**********************************************

dumpPoints:
	push ebp
	mov ebp,esp


	;allocate some scratch memory for generating the point as string
	mov ecx,100
	call alloc
	jz .done
	mov [pointbuf],esi

	;header
	push dumpPointsHeader
	call dumpstr
	
	;setup for loop
	mov esi,[ebp+12]
	mov ecx,[ebp+8]


.dumpPointsLoop:
	;x
	lodsd      
	STDCALL [pointbuf],0,0,eax2dec
	STDCALL [pointbuf],dumpstrnol
	
	;spaces
	STDCALL dumpspaces,dumpstrnol
	
	;y
	lodsd 
	STDCALL [pointbuf],0,0,eax2dec
	STDCALL [pointbuf],dumpstrnol

	call dumpnl
	loop .dumpPointsLoop


	;free the memory
	mov esi,[pointbuf]
	call free

.done:
	pop ebp
	retn 8



;***********************************************
;dumpmem
;dumps memory as a series of ascii hex bytes
;each byte is seperated by space
;3 ascii bytes are generated for each memory byte
;input:
;   push starting memory address   [ebp+12]
;   push qty bytes to convert      [ebp+8]
;return:none
dumpmemstr1 db 'dumpmem',0
;**********************************************

dumpmem:

	push ebp
	mov ebp,esp
	pushad

	STDCALL dumpmemstr1,dumpstr

	;alloc some memory for this
	;Aug 2011 this is our first function in all of tatOS to use alloc
	mov ecx,[ebp+8]
	call alloc  ;returns esi
	jz .failed 

	STDCALL [ebp+12],esi,[ebp+8], mem2str

	;mem2str generates 3 ascii bytes for each memory byte
	mov eax,[ebp+8]
	mov ecx,3
	mul ecx
	STDCALL esi,eax,dumpstrn

	;esi is memory address
	call free 

.failed:
	popad
	pop ebp
	retn 8





;***********************************************************************************
;dumpbitfield
;display 1 or more consecutive bits in eax
;the AND mask = 1 to display 1 bit, 
;= 11b to display 2 bits, = 111b to display 3 bits...

;example to display bits 28:26 of eax
;stdcall stringtag,26,111b,dumpbitfield

;input:
;push Address of 0 terminated string tag     [ebp+16]
;push qty bits to shift right                [ebp+12]
;push "AND" mask                             [ebp+8]
;*******************************************************


dumpbitfield:

	push ebp
	mov ebp,esp
	push eax
	push ecx

	mov ecx,[ebp+12]
	shr eax,cl   
	and eax,[ebp+8]
	STDCALL [ebp+16],0,dumpeax

	pop ecx
	pop eax
	pop ebp
	retn 12


;*******************************************************
;dumpheader
;dumps a row of asterisk then a string then
;another row of asterisk
;input:
;push Address of string   [ebp+8]

dumpasterisk:
db '****************************************************',0
;******************************************************

dumpheader:
	push ebp
	mov ebp,esp
	STDCALL dumpasterisk,dumpstr
	push dword [ebp+8]
	call dumpstr  
	STDCALL dumpasterisk,dumpstr
	pop ebp
	retn 4



;*********************************************************
;dumpcsv
;dump value in eax then dump a comma 
;you are responsible for calling dumpnl at some point
;input:
;push 0 = decimal csv              [ebp+8]
;     1 = dword eax hex csv
;     2 = word   ax hex csv
;     3 = byte   al hex csv
;return:none
;********************************************************

dumpcsv:
	push ebp
	mov ebp,esp

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja near .done

	cmp dword [ebp+8],1
	jz .hexdword
	cmp dword [ebp+8],2
	jz .hexword
	cmp dword [ebp+8],3
	jz .hexbyte

.decimal:
	push dword [_dumptr]
	push 0    ;unsigned
	push 0    ;zero term
	call eax2dec
	jmp .comma

.hexbyte:
	mov edi,[_dumptr]
	mov edx,2
	call eax2hex
	jmp .comma

.hexword:
	mov edi,[_dumptr]
	mov edx,1
	call eax2hex
	jmp .comma

.hexdword:
	mov edi,[_dumptr]
	mov edx,0
	call eax2hex
	jmp .comma


.comma:
	;insert a trailing comma
	mov byte [edi],0x2c
	add edi,1
	mov [_dumptr],edi

.done:
	pop ebp
	retn 4




;*****************************************************************
;dumpstrquote
;dumps a string bounded by quotes
;this is to help identify strings with leading
;or trailing spaces, or all spaces
;a NEWLINE byte is pushed after the string
;input: push address of 0 terminated ascii source string [ebp+8]
;return:none
;*****************************************************************

dumpstrquote:

	push ebp
	mov ebp,esp
	pushad

	;check that we do not put too much into the dump
	cmp dword [_dumptr],MAXDUMPADDRESS
	ja .done

	;dump a leading "
	push dword '"'
	call dumpbyte

	;dump the string
	push dword [ebp+8]
	call dumpstr

	;move the _dumptr back 1 byte
	dec dword [_dumptr]

	;dump a trailing "
	push dword '"'
	call dumpbyte

	call dumpnl

.done:
	popad
	pop ebp
	retn 4   ;clean up 1 arg
	


;*************************************************************
;dumpFPUstatus

;dump a string describing the contents of FPU register st0
;based on the fpu status word
;prior to calling this function you should load something
;into the "top" fpu register

;also dumps the fpu control word and strings describing the 
;current precision and rounding mode

;input:none
;return:none

;the bits of the fpu status word are as follows:
;0=invalid operation
;1=denormalized
;2=zero divide
;3=overflow (too big)
;4=underflow (too small)
;5=precision lost
;6=stack fault
;7=interrupt request
;8=C0
;9=C1
;10=C2
;11-13=top register
;14=C3
;15=busy

;the combination of C0, C2 and C3 give us the following:

;                 C3   C2   C0
;                 ZF   PF   CF
;unsupported      0    0    0
;NAN              0    0    1
;normal finite    0    1    0
;infinity         0    1    1
;zero             1    0    0
;empty            1    0    1
;denormal         1    1    0

;bits 0:6 are persistant and can only be reset with
;finit or fclex

;the code idea here comes from "Simply FPU" by Raymond Filiatreault

;for notes about the fpu control word see below

;ffree causes the register to be "empty"

fpusta1 db 'fpustat:zero',0
fpusta2 db 'fpustat:empty',0
fpusta3 db 'fpustat:denormal',0
fpusta4 db 'fpustat:normal finite',0
fpusta5 db 'fpustat:infinity',0
fpusta6 db 'fpustat:NAN not a number',0
fpusta7 db 'fpustat:unsupported',0
fpusta8 db 'fpuCW:control word',0
fpusta9 db 'fpuCW:precision, 0=24bit, 1=reserved, 2=53bit, 3=64bit',0
fpusta10 db 'fpuCW:roundingmode, 0=nearest, 1=down, 2=up, 3=truncate',0
controlword dd 0
;******************************************************

dumpFPUstatus:

	pushad
	fxam      ;set fpu flags C3,C2,C0
	fstsw  ax ;store floating point status word
	fwait
	sahf      ;store ah to EFLAGS: C3->ZF, C2->PF, C0->CF
	jz .ZeroOrEmptyOrDenormal
	jp .NormalOrInfinity
	jc .NotANumber

	;if we got here then ZF=PF=CF=0 this is unsupported
	STDCALL fpusta7,dumpstr
	jmp .doCW


.ZeroOrEmptyOrDenormal:  ;(ZF=1)
	jc .empty
	jp .denormal

	;if we got here, the value in st0 is "zero" (ZF=1, PF=0, CF=0)
	STDCALL fpusta1,dumpstr
	jmp .doCW

.empty:  ;(ZF=1, CF=1)
	STDCALL fpusta2,dumpstr
	jmp .doCW

.denormal:  ;(ZF=1, PF=1, CF=0)
	STDCALL fpusta3,dumpstr
	jmp .doCW

.NormalOrInfinity:  ;(ZF=0, PF=1)
	jc .Infinity

	;if we got here st0 is normal finite  (ZF=0, PF=1, CF=0)
	STDCALL fpusta4,dumpstr
	jmp .doCW

.Infinity:   ;(ZF=0, PF=1, CF=1)
	STDCALL fpusta5,dumpstr
	jmp .doCW

.NotANumber: ;(ZF=0, PF=0, CF=1)
	STDCALL fpusta6,dumpstr
	jmp .doCW

.doCW:

	;fpu Control Word
	;*********************
	;here we dump the fpu control word
	;bits 8,9 control the precision, we want 11b extended precision
	;bits 10,11 control the rounding mode
	fstcw word [controlword]

	;dump the entire fpu control word
	movzx eax, word [controlword]
	STDCALL fpusta8,0,dumpeax

	;dump the precision (bits9:8)
	movzx eax, word [controlword]
	shr eax,8
	and eax,3
	STDCALL fpusta9,0,dumpeax

	;dump the rounding mode (bits11:10)
	movzx eax, word [controlword]
	shr eax,10
	and eax,3
	STDCALL fpusta10,0,dumpeax

.done:
	popad
	ret






;*****************************************************************
;dumpstrstr
;dumps 2 strings in succession on one line
;the first string is typically a tag to describe the 2nd string
;input:
;push address of str1 [ebp+12]
;push address of str2 [ebp+8]
;return:none

;e.g. string#1 "string#2"
;******************************************************************

dumpstrstr:

	push ebp
	mov ebp,esp
	push esi

	mov esi,[ebp+12]
	push esi
	call dumpstr

	;we want to overwrite NL so both strings are on 1 line
	dec dword [_dumptr]

	mov esi,[ebp+8]
	push esi
	call dumpstrquote

.done:
	pop esi
	pop ebp
	retn 8



