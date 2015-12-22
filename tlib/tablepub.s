;tatOS/tlib/tablepub.s



;public_table_clear
;public_table_add



;a Public Symbol Table for ttasm

;any symbol declared with the keyword "public" will be added to this table
;public symbols are used to resolve "extern" symbols by the linker

;public symbols are not declared at the top of the source file
;public symbols are defined at their known assembly point
;public symbols are normally a known data address or function entry point

;the Public symbol table is an array of 16 byte entries
;   * 11 byte ascii string, (code or data label), this is the "symbol"
;   * byte  sourcefile number
;   * dword known symbol value/address/_assypoint  (offset 12)

;the symbol is an ascii string of no more than 11 bytes, it may be less than 11 bytes
;but can be no more, the string should contain no leading dot and no trailing colon

;the sourcefile number is an assembler directive.  the sourcefile number is a unique 
;number from 0->0xff to identify the source being assembled.  this is needed to ensure 
;that multiple source files do not attempt to declare the same public symbol.
;a public symbol may only be declared once in only 1 source file of a multiple 
;source file project. the sourcefile number is used to resolve any attempts to redefine 
;a public symbol.
;     if the public symbol is already in the table and the sourcefilenum matches, 
;then the symbol value/address will be redefined (why would you want to do this ?)
;     if the public symbol is already in the table and the sourcefilenum does not match, 
;then ttasm will stop and emit an error message because another source file is attemping 
;to declare the same public symbol
;     if the symbol is not in the table, then it is just added to the table
;e.g. source 1
;e.g. source 2
;e.g. source 0xff

;the Public Symbol Table starts at address 0x127a000
;0x4000 bytes are allocated allowing for a max of 1024 entries in the table

;any messages to the dump in this code will not be visible in the dump because this
;code is executed by ttasm on pass=1 only (all symbols are added on the first pass)

;public symbols are not added to the ttasm symbol table



pubtableQtyEntries dd 0

;holds the address of the next available entry in the table
pubtableNextEntry dd 0

;this buffer is also shared with tableext.s
pubext_tempbuf times 50 db 0

PUBTABLESTART        equ 0x127a000
PUBTABLESIZE         equ 0x4000
PUBTABLEMAXENTRIES   equ 1024

pubstr0 db 'pubtableadd failed - need <erasepe> directive to init Public symbol table',0
pubstr1 db 'pubtableadd failed - Public symbol table is full',0
pubstr2 db 'pubtableadd failed - Public symbol string length exceeds 11 bytes',0
pubstr3 db 'pubtableadd failed - attempt to redefine Public symbol by another source file',0
pubstr4 db 'pubtableadd failed - sourcefile number is out of range 0->0xff',0
pubstr5 db 'pubtableadd - modifying value of existing symbol',0
pubstr6 db 'pubtableadd - adding new symbol to table',0
pubstr7 db 'public_table_add',0
pubstr8 db 'public_table_add: byte sourcefile number',0
pubstr9 db 'public_table_add: dword symbol value',0


;********************************************
;public_table_clear
;fill the public symbol table with all zeros
;init the destination address and qty entries
;the "erasepe" directive will cause this
;function to be executed
;input:none
;return:none
;********************************************

public_table_clear:

	cld
	mov al,0
	mov edi,PUBTABLESTART  ;starting address
	mov ecx,SYMTABLESIZE   ;qty bytes
	rep stosb

	mov dword [pubtableQtyEntries],0
	mov dword [pubtableNextEntry],PUBTABLESTART

	ret


;********************************************************
;public_table_add
;add a symbol to the public table
;input:
;push address of 0 terminated ascii string max 11 bytes [ebp+16]
;push the sourcefile number (0->0xff)                   [ebp+12]
;push dword symbol value (assypoint/location counter)   [ebp+8]
;return:zf is set on error, clear on success

;warning!
;you must call pubtableclear before calling this function
;otherwise the destination address and qtyentries
;are not properly initialized. (we have a check for this)
;********************************************************

public_table_add:

	push ebp
	mov ebp,esp
	;create space on the stack to store the string length
	sub esp,4  ;[ebp-4]

	STDCALL pubstr7,dumpstr

%if VERBOSEDUMP
	;these dumps will only be visible on the 1st pass of ttasm
	mov eax,[ebp+16]
	STDCALL eax,dumpstrquote
	mov eax,[ebp+12]
	STDCALL pubstr8,2,dumpeax
	mov eax,[ebp+8]
	STDCALL pubstr9,0,dumpeax
%endif


	;check if the public table was properly cleared
	;and pubtableNextEntry is holding a proper value
	cmp dword [pubtableNextEntry],PUBTABLESTART
	jb near .error0


	;check if the public symbol table is full
	;0x4000 bytes / 20 bytes per entry gives max 819 entries
	cmp dword [pubtableQtyEntries],PUBTABLEMAXENTRIES
	jae near .error1


	;get/check the string length, is it less or equal to 11 bytes ?
	mov eax,[ebp+16] ;address of string
	call strlen      ;returns ecx=string length not counting 0 terminator
	cmp ecx,11       ;does the string length exceed 11 bytes ?
	ja near .error2

	;save the string length for later
	mov [ebp-4],ecx


	;check for a valid sourcefile number in the range 0->0xff
	mov esi,[ebp+12]  ;sourcefile number
	push 0            ;min value
	push 0xff         ;max value
	call checkrange   ;zf is set on success if value is in the range
	jnz near .error4


	;prefill our temp buffer with all zero's
	cld 
	mov al,0
	mov edi,pubext_tempbuf
	mov ecx,50
	rep stosb

	;copy the 11 byte string to the pubext_tempbuf 
	mov ecx,[ebp-4]   ;strlen
	mov esi,[ebp+16]  ;address of string
	mov edi,pubext_tempbuf
	rep movsb
	;the value in ecx string length has been destroyed


	;check if the public symbol table is empty
	mov ebx,[pubtableQtyEntries]
	cmp ebx,0  ;are there any entries in the public symbol table ?
	jz .3      ;no then just add the symbol to the table


	;if we got here the public symbol table has 1 or more entries
	;loop thru the public symbol table
	;and check to see if this new symbol is already in the table
	;if it is then check also the sourcefilenum
	;we want a fast 11 byte comparison
	;ebx=loop counter

	mov edi,PUBTABLESTART

.1: 
	;compare the 11 byte pubext_tempbuf string with an entry in the public symbol table
	push edi    ;must preserve
	mov ecx,11  ;the strings are 11 bytes long
	mov esi,pubext_tempbuf
	;edi=starting address of an entry in the public symbol table
	rep cmpsb   ;returns zf set if equal else clear if not
	pop edi     ;restore, flags are not affected
	jz .2       ;the two strings are equal

	;inc to the next entry in the public symbol table
	add edi,16
	;decrement the qty entries that have been checked
	dec ebx
	jnz .1  ;end of ebx loop



	;if we got here we looped thru the entire public symbol table
	;and we did not find our symbol in the table 
	;so it is a new symbol to be added
	jmp .3
	

.2:
	;MODIFY EXISTING SYMBOL
	;if we got here the symbol is already in the table
	;check to see if it is the same source file or not
	;edi=starting address of entry in the public symbol table
	movzx ebx,byte [edi+11]  ;read the sourcefile number in the public table
	cmp ebx,[ebp+12]
	jnz near .error3         ;attempt to redefine symbol by another source file

	;if we got here the symbol is already in the table and the sourcefiles match
	;so the same source is being reassembed and we just want to set a new symbol
	;value/address

	;this dumpstr will not normally show up in the dump because 
	;public symbols are only added on pass=1 of ttasm and the dump messages
	;are only displayed on pass=2
	STDCALL pubstr5,dumpstr  
	
	;redefine the new symbol/address 
	mov eax,[ebp+8]   ;read from stack
	mov [edi+12],eax  ;write to public symbol table offset 12

	or eax,1  ;clear zf on success
	jmp .done


.3:
	;ADD A NEW SYMBOL 
	;copy the string into the public symbol table
	STDCALL pubstr6,dumpstr

	cld     
	mov ecx,[ebp-4]   ;strleng
	mov esi,[ebp+16]  ;address of string
	mov edi,[pubtableNextEntry]
	mov eax,edi  ;eax=starting address of new public symbol table entry - save a copy
	rep movsb

	;copy the byte sourcefilenum into the public symbol table
	mov ebx,[ebp+12]
	mov [eax+11],bl

	;copy the dword symbol value into the table
	mov ebx,[ebp+8]  ;symbol value
	mov [eax+12],ebx ;save symbol value 12 bytes after start of string

	;increment the qty entries
	add dword [pubtableQtyEntries],1

	;increment the address of the next available entry
	add dword [pubtableNextEntry],16   ;16 bytes past the start of the previous entry
	
	or eax,1  ;clear zf on success
	jmp .done

	
.error0:
	STDCALL pubstr0,dumpstr
	xor eax,eax  ;set ZF
	jmp .done
.error1:
	STDCALL pubstr1,dumpstr
	xor eax,eax  ;set ZF
	jmp .done
.error2:
	STDCALL pubstr2,dumpstr
	xor eax,eax  ;set ZF
	jmp .done
.error3:
	STDCALL pubstr3,dumpstr
	xor eax,eax  ;set ZF
	jmp .done
.error4:
	STDCALL pubstr4,dumpstr
	xor eax,eax  ;set ZF
.done:
	mov esp,ebp  ;deallocate locals
	pop ebp
	retn 12



