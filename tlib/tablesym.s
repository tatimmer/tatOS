;tatOS/tlib/tablesym.s
;rev June 2013

;this is the ttasm symbol table
;functions developed for ttasm to store and retrieve hashed strings 
;and their value using a symbol table
;these are local/global symbols within 1 source file

;hash
;TableIndex
;symadd
;symlookup
;symtableclear
;symtableload



;note:
;this code builds a hash table that does not employ chaining
;we have no way to avoid collisions except to carefully choose your strings !!!
;the current hash algorithm is quite good so dont worry about getting too many clashes
;if ttasm stops with an error message like "symbol already in table..." 
;just change the spelling of your symbol slightly


;SYMBOL TABLE
;the symbol table starts at 0x1a90000 
;the sizeof the symbol table is currently 2meg
;each entry in the table entry consists of (2) dwords:
;the first dword is the data class or type of data
;the 2nd dword is the symbol value
;so there are 8 bytes per symbol entry

;note we do not store the actual string
;Hashing converts the string to a 32 bit dword number
;then Table Index clips the dword to a memory offset
;that fits within the size of the symbol table 

;ttasm stores the strings along with their respective address 
;to a special "String Table" which gets dumped at the end of every asm

;note if you add new data classes you must edit some functions like test4imm

;Data Class:
;      * dword, data class or type of data 
;       ttasm uses the following for data class:
;      	0=symbol not found in table  
;		1=register name eax,ebx,ecx... (general purpose reg 8/16/32bit)
;		2=register indirect [eax], [ebx]... (32bit reg only)
;       3=defined constant (color, address, codelabel, ...)
;		4=      stack reference [ebp+4], [ebp+8]...
;       5=ttasm function entry points
;       6=      [esi+disp8] memory reference
;       7=size qualifier byte,word,dword,qword
;       8=fpu register st0,st1,st2...
;       9=extern symbol

;Symbol Value:
;      * dword, symbol value
;		 this is typically the address of a code label or function entry point
;        for reserved symbols like register names the symbol value is a unique 
;        number to identify the register



%define SYMTABLESTART    0x1a90000  
%define SYMTABLESIZE     0x200000
%define SYMTABLEEND      SYMTABLESTART+SYMTABLESIZE



;***********************************************
;hash
;convert a 0 terminated ascii string to a number

;input
;esi=address of 0 terminated string to hash

;return
;ebx=hash value of string

;***********************************************

hash:
	push eax
	push esi
	push ecx
	push edx
	push ebp
	
	cld
	xor eax,eax
	xor ebx,ebx  ;our dword hash value will be stored here
	
.nextchar:
	lodsb  ;al=[esi],esi++
	
	cmp al,0
	jz .done


;this is the "djb2" hash function
;source: www.cse.yorku.ca/~oz/hash.html
;this algorithm is not so good
;	shl ebx,5
;	add ebx,ebx
;	add ebx,eax  ;hash*33 + c



;this is the "sdbm" hash algorithm
;while (c = *str++)
;hash=c + (hash<<6) + (hash<<16) - hash
;this is much better 
	mov ecx,ebx
	shl ecx,6
	mov edx,ebx
	shl edx,16

	mov ebp,eax
	add ebp,ecx
	add ebp,edx
	sub ebp,ebx
	mov ebx,ebp
	
	jmp .nextchar
		
.done:
	mov eax,ebx   ;ebx=returned hash value
	pop ebp
	pop edx
	pop ecx
	pop esi
	pop eax
	ret



;this is the Java hash function:
;summation [ Ci * 37^i ]  for (i=0->n-1)
;n=num chars in string
;Ci = the ith character (ascii I persume)




;***********************************************************
;TableIndex
;converts ascii string to symbol table index

;input
;esi=address of 0 terminated string

;return
;ebx=index value from 0 -> max qty symbol entries

tblindxstr2 db 'TableIndex: hash value',0
tblindxstr3 db 'TableIndex: array index',0
;**********************************************************

TableIndex:

	push eax
	push edx

	;removed a dumpstrquote which is redundant because
	;ttasm functions which call this function will do their own dumping of strings
	
	;esi=address of string 
	call hash
	;ebx=dword hash value
	;esi is preserved

	;for debug
	;mov eax,ebx
	;STDCALL tblindxstr2,0,dumpeax

	;now reduce this value to a table index/memory offset 
	;at 1 meg allowable and each entry needs 8 bytes so
	;0x100000/8 = 131072 max qty entries in symtable 
	;we need to divide by a number less than or equal to 131072

	;dividing by 131072 actually works pretty good until you find out that
	;the immediate value "220" and the register string "st0" 
	;both hash to the same index

	;some advocate dividing by a prime number but 
	;131071 results in clashes while loading the ttasm symbol table
	;107101 results in clashes while loading the ttasm symbol table
	;103007 results in clashes while loading the ttasm symbol table

	;Jan 2013 I expanded the symbol table from 1->2meg and
	;at 2meg allowable, 0x200000/8 = 262,144 max qty entries in symtable
	;dividing by prime number 190,027 which is < 262,144 is good for now

	xor edx,edx
	mov eax,ebx
	mov ebx,190027 ;divide by this number
	div ebx        ;edx:eax/ebx
	;edx=remainder after division, this is our offset
	mov ebx,edx    ;return value in ebx

	;for debug
	;mov eax,ebx    
	;STDCALL tblindxstr3,0,dumpeax

	pop edx
	pop eax
	;esi is perserved
	ret
	



;*************************************************************************
;symadd
;hashes an ascii string to a number less than max qty symbol entries
;checks to make sure the location in memory is available  
;writes symbol value

;input
;esi=address of 0 terminated string
;eax=symbol value (i.e. _assypoint/LC, or some dword representation of the string)
;edx=data class (see above discussion for predefined integer values)

;see the end of ttasm for examples of how a symbol table is setup

;return
;eax=0 for success
;   =1 error symbol already used
;ebx=table index

symadd1 db 'symadd:value',0
symadd2 db 'symadd:class',0
;************************************************************************

symadd:

	push esi
	push edi


%if VERBOSEDUMP
	;this generates a lot of dump messages
	;you see all the symbols added when ttasm first starts up
	STDCALL symadd1,0,dumpeax  ;dump value
	push eax
	mov eax,edx
	STDCALL symadd2,0,dumpeax  ;dump class
	pop eax
%endif


	call TableIndex  
	;ebx=index

	;edi=start memory address for symbol entry
	lea edi, [SYMTABLESTART+ebx*8]


	;check to make sure the entry is empty/unused 
	cmp dword [edi],0
	jz .notused
	mov eax,1  ;error symbol used
	jmp .done
.notused:
	
	;write the data class
	mov [edi],edx

	;write the symbol value
	mov [edi+4],eax

	mov eax,0  ;return success

.done:
	pop edi
	pop esi
	ret



;********************************************
;symlookup

;input
;esi=address of 0 terminated string

;return
;eax=data class 
;ebx=symbol value

;if eax=0 then the symbol 
;is NOT in the table
symlookstr1 db 'symlookup:class',0
symlookstr2 db 'symlookup:value',0
;******************************************

symlookup:

	push edi

	;esi=address of string
	call TableIndex  ;ebx=index
	;esi is perserved
	
	lea edi, [SYMTABLESTART+ebx*8]

	;get the data class
	mov eax,[edi]

	;get the symbol value
	add edi,4
	mov ebx,[edi]

	;dump the data class and symbol value
	;ttasm does a lot of symlookup so this generates alot of dump strings
%if VERBOSEDUMP
	STDCALL symlookstr1,0,dumpeax
	push eax
	mov eax,ebx
	STDCALL symlookstr2,0,dumpeax
	pop eax
%endif

	pop edi
	ret



;**************************************************
;symtableclearall
;clears all local/global symbols in the table
;no input and no return
;**************************************************

symtableclear:

	cld
	mov al,0
	mov edi,SYMTABLESTART  ;starting address
	mov ecx,SYMTABLESIZE   ;zero out 2 meg
	rep stosb

	ret




;**********************************************
;symtableload
;this is the top level routine used by apps
;to load a symbol table on startup
;this function is also used to load the
;ttasm symbol table

;input
;push Starting Address of Symbols        [ebp+12]
;push Address of 7 byte 'THE-END' string [ebp+8]

;return
;sets ZF on error during the load

;the symbols must be organized as follows.
;each entry consists of a 0 terminated string
;followed by 2 dwords
;the symbol is a unique dword associated with 
;the string, it is typically a function entry point
;the ClassCode is a unique dword that may be used
;to further classify the symbols
;repeat the 2 lines for as many symbols as reqd

;db 'mystring',0
;dd Symbol,ClassCode

;the last entry in the symbol table 
;must be this special 0 terminated 7 byte ascii string 
;to mark the end of the symbol table:
;db 'THE-END'
;*********************************************

symtableload:

	push ebp
	mov ebp,esp

	;removed symtableclear
	;ttasm now uses symtableload, symtableclear and symtableclearall seperately
	;since the user may have public symbols that he does not want erased

	;starting address of symbols to add
	mov esi,[ebp+12]

	xor eax,eax

.loadnextsymbol:

	;get length of string to add to table in ecx
	mov eax,esi
	call strlen 
	;ecx=length

	;eax=address of symbol value	
	lea eax,[esi+ecx+1] ;1=0 terminator

	;edx=address of data class
	lea edx,[eax+4]

	;eax=symbol value
	mov eax,[eax]

	;edx=data class
	mov edx,[edx]

	;add the symbol
	call symadd
	;eax=0 for success, ebx=table index


	;check return value of symadd to make sure no clashes
	cmp eax,1
	jz .done


	;increment esi to next symbol string
	lea esi,[esi+ecx+9]  ;9= two dwords + 0 terminator


	;look for special 7 byte 'THE-END' string 
	;to stop entering strings in our symbol table
	mov edi,[ebp+8]
	mov ecx,7
	call strncmp
	jnz .loadnextsymbol


	;clear ZF to indicate success
	or eax,1

.done:
	pop ebp
	retn 8




