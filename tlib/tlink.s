;tatOS/tlib/tlink.s

;a linker for tatOS

;tlink is used for projects with multiple source files. 
;tlink will read the extern table  and search for a matching symbol in the 
;public table. It will then patch (write to memory) every instance of the 
;extern symbol with the matching memory address from the public table. 

;tlink assumes that all source code has already been assembled by ttasm 
;into memory ready to go except for patching all the extern symbol addresses 
;which were assembled with a value of 00000000.

;both the extern & public tables are built by ttasm and added to with the 
;assembly of each source file. see tlib/tableext.s and tablepub.s  

;tlink works in concert with "make", see tlib/make.s 





tlnkstr0 db 'tlink',0
tlnkstr1 db 'tlink:extern table is empty, nothing for tlink to do',0
tlnkstr2 db 'tlink:failed to find matching symbol in public table',0
tlnkstr3 db 'tlink:get extern symbol',0
tlnkstr4 db 'tlink:found matching public symbol',0
tlnkstr5 db 'tlink:done patching all links of 1 extern symbol',0
tlnkstr6 db 'tlink:exit success',0
tlnkstr7 db 'tlink:public symbol value (destination)',0
tlnkstr8 db 'tlink:extern link address',0
tlnkstr9 db 'tlink:extern link value (source)',0
tlnkstr10 db 'tlink:reldisp32 (value of patch)',0
tlinkstr11 db 'tlink:extern symbol has headlink=0, no usage of symbol',0




;**************************************************************
;tlink
;input: code must be assembled into memory by ttasm
;       public and extern symbol tables are built by ttasm
;return: ZF is set on error, clear on success
;**************************************************************

tlink:

	call dumpnl
	call dumpnl
	STDCALL tlnkstr0,dumpstr

	push ebp
	mov ebp,esp
	sub esp,8   
	;local/stack variables:
	;[ebp-4] address of extern symbol direntry being processed
	;[ebp-8] qty extern symbols processed


	;are there any entries in the extern table ?
	;if not then there is nothing for tlink to do
	cmp dword [externTableQtyDirEntries],0
	jz near .error1


	mov eax,[externTableQtyDirEntries]
	mov [ebp-8],eax
	;eax=qty extern table direntries processed
	;we will decrement this value with each entry processed


	;clear out the temp buffer 
	cld 
	mov al,0
	mov edi,pubext_tempbuf
	mov ecx,50
	rep stosb


	;copy extern symbol from extern directory to temp buffer
	cld     
	mov esi,EXTERNTABLESTART
	mov [ebp-4],esi  ;save for later
.1:
	STDCALL tlnkstr3,dumpstr
	mov edi,pubext_tempbuf
	mov ecx,11  ;each ascii string/symbol is 11 bytes
	rep movsb

	;dump the extern symbol
	STDCALL pubext_tempbuf,11,dumpstrn


	;prepare to read the public table
	mov edi,PUBTABLESTART
	mov ebx,[pubtableQtyEntries]
.2: 
	;compare the 11 byte pubext_tempbuf string with an entry in the public table 
	push edi     ;must preserve
	mov ecx,11   ;the strings must be 11 bytes long
	mov esi,pubext_tempbuf
	;edi=starting address of an entry in the public symbol table
	rep cmpsb    ;returns zf set if equal else clear if not
	pop edi      ;restore, flags are not affected
	jz .3        ;the two strings are equal, found a matching directory entry symbol

	;inc to the next entry in the public table directory
	add edi,16  ;each entry in the public table is 16 bytes  

	;decrement the qty entries that have been checked
	dec ebx
	jnz .2  ;end of ebx loop

	;if we got here we did not find a matching symbol in the public directory
	jmp .error2


.3: 
	;if we got here we found a matching public symbol
	;edi=address of public symbol direntry
	STDCALL tlnkstr4,dumpstr

	;dump the 11 byte public symbol/string
	;STDCALL edi,11,dumpstrn

	;esi = public symbol patching _assypoint/LC address
	;this is the destination or target address of an external function
	mov esi,[edi+12]  
	mov eax,esi
	STDCALL tlnkstr7,0,dumpeax  ;tlink: public symbol value (destination)

	;now travel the extern symbol link list and patch every instance/link

	;get address of first/head link of this extern list
	mov eax,[ebp-4]  ;eax=address of extern direntry
	mov ebx,[eax+12] ;ebx=extern symbol address of head link

	;if the address of the head link is 0 that means we have a extern symbol
	;but no usage/instance so we just skip this one
	cmp ebx,0
	jnz .4
	STDCALL tlinkstr11,dumpstr
	jmp .donePatch


.4:
	;ebx=address of a particular link of an extern link list
	mov ecx,[ebx]    ;ecx=extern symbol _assypoint/LC to patch
	mov edx,[ebx+4]  ;edx=extern symbol address of next link in the list

	;dump the address of the extern link 
	mov eax,ecx
	STDCALL tlnkstr8,0,dumpeax  ;tlink:extern link address

	;dump the value of the extern link
	;this is what ttasm has written to memory that needs patching
	;for a public call reldisp32 the value written here is (sourceaddress-4)
	;for a public data the value written here is just 00000000
	mov edi,[ecx]  ;edi=address written to memory by ttasm that needs patching (source)
	mov eax,edi
	STDCALL tlnkstr9,0,dumpeax  ;tlink:extern link value (source)

	;patch
	;all patching addresses are written as relative disp32 for the benefit of call
	push esi       ;must preserve the destination for the next link
	sub esi,edi    ;esi=(destination - source)
	;for external data, source=0 so this subtraction has no affect
	;for external function call, (dest-source) = reldisp32 for the call instruction
	mov [ecx],esi  ;write the patch
	mov eax,esi
	STDCALL tlnkstr10,0,dumpeax 
	pop esi        ;restore the destination address

	;do we have another extern link ?
	cmp edx,0
	jz .donePatch

	;if we got here we still have more links to patch for this extern symbol
	mov ebx,edx  ;assign new link address
	jmp .4


.donePatch:
	;if we got here we are done patching all the links of 1 extern symbol link list
	;now we increment to the next extern symbol direntry 
	STDCALL tlnkstr5,dumpstr

	;decrement the qty of extern symbol direntries processed
	sub dword [ebp-8],1

	;normal exit from tlink
	cmp dword [ebp-8],0
	jz .success      ;we are done processing all the extern symbols

	;we are not done, more extern symbols to process
	add dword [ebp-4],16    ;esi=address of next extern symbol direntry
	mov esi,[ebp-4]
	jmp .1


.success:
	STDCALL tlnkstr6,dumpstr
	or eax,1  ;clear zf 
	jmp .done
.error1:
	STDCALL tlnkstr1,dumpstr
	xor eax,eax  ;zf set on error
	jmp .done
.error2:
	STDCALL tlnkstr2,dumpstr
	xor eax,eax  ;zf set on error
	jmp .done
.done:
	mov esp,ebp  ;deallocate locals
	pop ebp
	ret




