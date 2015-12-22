;tatOS/tlib/tableext.s



;extern_table_clear
;extern_add_direntry
;extern_find_direntry
;extern_add_link
;extern_get_lastlink




;code to manage "extern" symbols with an extern symbol table

;extern symbols are symbols whos address is unknown at assembly time 
;because the address is known/defined in another source file using the "public" directive.  
;ttasm will assemble all extern symbols with a value of 00000000 
;and save to the extern symbol table link list the value of the 
;assembly point where the symbol value has to be patched. 
;the linker (tlink) will read the public symbol table and the extern symbol table 
;and patch all extern symbols in memory with the correct symbol value.

;the same extern symbol (11 byte ascii string) may be found in multiple source files
;each instance will be assigned the value of the matching "public" symbol

;extern symbols must all be declared at the top of the source file like this:
;extern apple
;extern orange
;extern pear

;The extern table and the public table must be properly cleared/erased at some point
;this is done with the ttasm directive "erasepe". You will typically invoke this directive 
;at the beginning of assembly of your projects first source file. Subsequent source 
;file assemblies will just keep appending to these tables.

;extern symbols are classified as either "data" or "procedure"

;ttasm supports a limited usage of extern data symbols 
;  * any instruction which uses the ProcessMemoryAndDisp and test4imm functions
;    this includes: mov, cmp, add, sub, or, neg, not, inc, dec and some fpu instructions
;  * mov dword imm->reg where imm is an extern symbol

;ttasm supports extern procedure symbols via the "call reldisp32" instruction only
;you can not do "call [extern]", this will generate an assembly error
;nor can you do "call reg" with an extern symbol in the reg

;to assemble a project using extern and public symbols, you must do the following in order:
;  * assemble the main source file which calls "erasepe"
;  * assemble the secondary sources files
;  * call tlink (Ctrl+F11)
;now run your project


;the extern symbol table is organized into two parts.

;Extern Table Directory
;*************************
;Part 1 is an array of 16 byte elements:

;    * 11 byte symbol, ascii string, (code or data label)
;    * byte not used set to 0                 (offset 11)
;    * dword address first/head link of list  (offset 12)


;Extern Table Link Lists
;****************************
;Part 2 is the memory block allocated for single link lists
;one single link list is generated for each extern symbol in the directory
;one link will be generated for each useage/instance of an extern symbol in the sourcefile

;each link consists of (2) dwords:
;   * dword1  _assypoint  (tlink must overwrite value at this address)
;   * dword2  address of next link (pointer to next link in list)
;     (the last link of the list will be assigned dword2=0)

;for the case of extern data, the value written to memory address dword1 by ttasm 
;is 00000000, tlink will overwrite the 00000000 with the address of the public data label

;for the case of an extern procedure, the value written to memory address dword1 by ttasm
;is equal to the _assypoint less 4 (see ttasm docall code generator), tlink will read this
;value then subtract it from the value of the public code label to arrive at reldisp32 
;which is then written back as the value at dword1




;Extern Table Layout
;*********************
;the extern symbol table starts at 0x127e000, 0x8000 bytes are reserved

;extern table directory:
;   * starting address           = 0x127e000
;   * amount of memory available = 0x2000
;   * max qty directory entries  = 0x200 = 512  (16 bytes each)

;extern table Links:
;   * starting address = 0x1280000
;   * ending address   = 0x1286000
;   * bytes per link   = 8
;   * max qty links    = 3000  



EXTERNTABLESTART            equ  0x127e000
EXTERNTABLELINKMEMORYSTART  equ  0x1280000
EXTERNTABLEMAXDIRENTRIES    equ  512
EXTERNTABLEMAXLINKADDRESS   equ  0x1286000
SIZEOFEXTERNDIRENTRY        equ  16

externTableQtyDirEntries    dd   0
externTableNextDirEntry     dd   0
externTableNextLinkAddress  dd   0  
externTableIsFull           dd   0


extstr0 db 'extern_add_direntry: need <erasepe> directive to init extern symbol table',0
extstr1 db 'extern_add_direntry: failed - extern symbol table directory is full',0
extstr2 db 'extern_add_link: failed - extern symbol table link list memory is full',0
extstr3 db 'extern_add_direntry: failed - extern symbol string length exceeds 11 bytes',0
extstr4 db 'extern_add_link: failed - error fetching address of last link of list',0
extstr5 db 'extern_add_link: directory entry for symbol already exists',0
extstr6 db 'extern_add_link: failed to find direntry',0
extstr7 db 'extern_add_link: value of address to patch',0
extstr8 db 'extern_add_link: address of first link',0
extstr9 db 'extern_add_link: adding first link of list',0
extstr10 db 'extern_add_link: appending link',0
extstr11 db 'extern_add_direntry',0
extstr12 db 'extern_add_direntry: add new symbol to directory', 0
extstr13 db 'extern_add_link',0





;********************************************
;extern_table_clear
;fill the extern symbol table with all zeros
;init the destination address and qty entries
;the "erasepe" directive will cause this
;function to be executed
;input:none
;return:none
;********************************************

extern_table_clear:

	cld
	mov al,0
	mov edi,EXTERNTABLESTART  ;starting address
	mov ecx,0x8000            ;qty bytes
	rep stosb

	mov dword [externTableQtyDirEntries],0
	mov dword [externTableNextDirEntry],EXTERNTABLESTART
	mov dword [externTableNextLinkAddress],EXTERNTABLELINKMEMORYSTART
	mov dword [externTableIsFull],0   ;1=full

	ret


;*********************************************************************
;extern_add_direntry
;add a directory entry to the extern table
;this function is invoked every time you declare an extern variable
;these declarations should all appear at the top of your source file

;input
;push address of 0 terminated ascii symbol/string max 11 bytes   [ebp+8]

;return:zf is set on error, clear on success
;*********************************************************************

extern_add_direntry:

	push ebp
	mov ebp,esp
	;create space on the stack to store the string length
	sub esp,4  ;[ebp-4]

	STDCALL extstr11,dumpstr
	mov eax,[ebp+8]
	STDCALL eax,dumpstrquote

	;check if the extern table was properly cleared
	;and externTableNextEntry is holding a proper value
	cmp dword [externTableNextDirEntry],EXTERNTABLESTART
	jb near .error0


	;check if the extern table directory is full
	;if so cant add any more
	cmp dword [externTableQtyDirEntries],EXTERNTABLEMAXDIRENTRIES
	jae near .error1

	
	;get/check the string length, is it less or equal to 11 bytes ?
	mov eax,[ebp+8] ;address of string
	call strlen      ;returns ecx=string length not counting 0 terminator
	cmp ecx,11       ;does the string length exceed 11 bytes ?
	ja near .error2

	;save the string length for later
	mov [ebp-4],ecx


	;check to see if this particular extern symbol is already in the table 
	push dword [ebp+8]
	call extern_find_direntry  ;returns edi=address of direntry
	cmp edi,0
	jnz .3  


.2:
	;if we got here extern_find_direntry returned a zero value
	;indicating the symbol is not in the extern table  
	;so we just add a new symbol to the directory

	STDCALL extstr12,dumpstr

	;copy the symbol to the extern directory
	mov esi,[ebp+8]  ;address of string
	mov edi,[externTableNextDirEntry]
	mov eax,edi  ;save
	call strcpy80


	;zero out byte at offset 11 not used
	mov byte [eax+11],0

	;write a value of 0 to the direntry offset 12 for the address of first link
	mov dword [eax+12],0


	;increment the qty direntries
	add dword [externTableQtyDirEntries],1

	;increment the address of the next available directory entry slot
	;each direntry occupies SIZEOFEXTERNDIRENTRY bytes
	add dword [externTableNextDirEntry],SIZEOFEXTERNDIRENTRY

	or eax,1  ;clear zf on success
	jmp .done


.3:
	;if we got here a directory entry already exists for this symbol
	;multiple source files may declare the same symbol
	;we just exit with dump message

	STDCALL extstr5,dumpstr
	or eax,1  ;clear zf on success
	jmp .done


.error0:
	STDCALL extstr0,dumpstr
	xor eax,eax  ;set ZF
	jmp .done
.error1:
	STDCALL extstr1,dumpstr
	xor eax,eax  ;set ZF
	jmp .done
.error2:
	STDCALL extstr3,dumpstr
	xor eax,eax  ;set ZF
	jmp .done
.done:
	mov esp,ebp  ;deallocate locals
	pop ebp
	retn 4



;***************************************************************
;extern_find_direntry
;loop thru the extern table directory until we find 
;a matching symbol/string
;input:
;push address of 0 terminated ascii symbol/string max 11 bytes   [ebp+8]
;return: edi=address of direntry
;        if edi=0 failed to find
;***************************************************************

extern_find_direntry:

	push ebp
	mov ebp,esp


	;check if the extern table directory is empty
	;if so we can skip looping thru the table
	cmp dword [externTableQtyDirEntries],0
	jz .2  


	;prefill temp buffer with all zero's
	;the pubext_tempbuf is defined in tablepub.s
	cld 
	mov al,0
	mov edi,pubext_tempbuf
	mov ecx,50
	rep stosb


	;copy the symbol to the pubext_tempbuf 
	mov esi,[ebp+8]  ;address of string
	mov edi,pubext_tempbuf
	call strcpy80


	mov edi,EXTERNTABLESTART
	mov ebx,[externTableQtyDirEntries]
.1: 
	;compare the 11 byte pubext_tempbuf string with an entry in the extern table directory
	push edi     ;must preserve
	mov ecx,11   ;the strings must be 11 bytes long
	mov esi,pubext_tempbuf
	;edi=starting address of an entry in the public symbol table
	rep cmpsb    ;returns zf set if equal else clear if not
	pop edi      ;restore, flags are not affected
	jz .success  ;the two strings are equal, found a matching directory entry symbol

	;inc to the next entry in the extern table directory
	add edi,SIZEOFEXTERNDIRENTRY  

	;decrement the qty entries that have been checked
	dec ebx
	jnz .1  ;end of ebx loop


.2:
	;if we got here we looped thru the entire extern table directory
	;and we did not find this extern symbol in the directory 
	;or the table is empty
	mov edi,0  ;did not find direntry
	jmp .done


.success:
	;returns edi=starting address of direntry
.done:
	pop ebp
	retn 4







;*************************************************************************
;extern_add_link
;add a link to an extern entries link list
;each instance/usage of an extern variable causes a link to be generated
;input:
;push address of 0 terminated ascii symbol/string max 11 bytes   [ebp+12]
;push address of _assypoint/location counter to patch            [ebp+8]
;return:zf is set on error, clear on success
;*************************************************************************

extern_add_link:

	push ebp
	mov ebp,esp
	pushad

	STDCALL extstr13,dumpstr

	;dump the address to patch
	mov eax,[ebp+8]
	STDCALL extstr7,0,dumpeax

	;check if the extern table link list memory is full
	cmp dword [externTableNextLinkAddress],EXTERNTABLEMAXLINKADDRESS
	jae near .error1

	;get address of direntry
	push dword [ebp+12]
	call extern_find_direntry  ;returns edi=address of direntry
	cmp edi,0
	jz near .error2                 ;failed to find symbol in the directory

	;eax= address of first link
	mov eax,[edi+12]
	STDCALL extstr8,0,dumpeax

	;if address of first link is 0 this is a special case
	;we add the new link and write the address to the direntry
	cmp eax,0
	jnz .1 


	;if we got here the headlink is not defined
	;so we are adding the first link to the list
	;edi=address of direntry
	;eax=address of first link is 0
	STDCALL extstr9,dumpstr

	;get the address of the next available link in the link list memory pool
	mov esi,[externTableNextLinkAddress]

	;write link address to the direntry
	mov [edi+12],esi

	;now assign values to the link
	jmp .2


.1:
	;if we got here the headlink is already defined
	;so we just append another link
	;edi=address of direntry
	;eax=address of first link 
	STDCALL extstr10,dumpstr

	;get address of last link of list
	;edi=address of direntry
	mov eax,[edi+12]    ;eax=address of 1st link
	call extern_get_lastlink  ;return value in eax
	cmp eax,0  ;was there an error in fetching the last link address ?
	jz near .error3 

	;write newlink address to previous link
	mov esi,[externTableNextLinkAddress]
	mov [eax+4],esi


.2:
	;esi=address of newlink

	;write to the new link:  _assypoint/LC address to patch
	mov ebx,[ebp+8]  ;ebx=_assypoint/LC
	mov [esi],ebx    ;assign to link the assypoint/LC

	;write to the new link: next link pointer
	;a value of 0 here indicates its the last link of the list
	mov dword [esi+4],0    ;assign next link pointer

	;increment the value of externTableNextLinkAddress by 8 bytes
	add dword [externTableNextLinkAddress],8

	or eax,1  ;clear zf on success
	jmp .done


.error1:
	STDCALL extstr2,dumpstr
	xor eax,eax  ;set ZF
	jmp .done
.error2:
	STDCALL extstr6,dumpstr
	xor eax,eax  ;set ZF
	jmp .done
.error3:
	STDCALL extstr4,dumpstr
	xor eax,eax  ;set ZF
	jmp .done
.done:
	popad
	pop ebp
	retn 8




;**************************************************************
;extern_get_lastlink
;walk a link list and get the address of the last link
;input:  eax=address first/head link of list
;return: eax=address of last link of list
;        if eax=0 we failed to find the last link within 3000
;**************************************************************

extern_get_lastlink:
	
	push ebx
	push ecx

	;just to make sure we limit the check to 3000 links 
	mov ecx,3000

.1:
	mov ebx,[eax+4]  ;ebx=address of next link

	sub ecx,1        ;decrement counter
	jz .error

	cmp ebx,0        ;if ebx=0 then eax=address of last link
	jz .done

	mov eax,ebx      ;eax=address of current link
	jmp .1

.error:
	mov eax,0
.done:
	pop ecx
	pop ebx
	ret


