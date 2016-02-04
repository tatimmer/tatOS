;tatOS/tlib/ttasm.s      

;rev Jan 2016


;ttasm is Tom Timmermann's Assembler
;a 2-pass assembler to generate executable code
;for the tatOS operating system
;32bit x86 Intel/AMD processors
;(64bit processors running in 32bit mode)

;input
;expects an array of 0 terminated ascii bytes representing the
;assembler source code starting at address 0x1990000

;return
; 1) executable code directly written directly to "org" (Assemble & Go)
; 2) verbose text output written to the "dump", see tlib/dump.s
;    all messages to the dump are erased after the first pass unless you 
;    elect VERBOSEDUMP from tatOS.config
; 3) eax=address of string describing results of the assemble
;    ebx=dword [_errorcode]  (0 if successful assemble)


;see /doc/ttasm-help for more info
;see also tlink.s which works in concert with ttasm



;supporting functions in ttasm:
;WRITEEXEBYTE
;WRITEEXEWORD
;WRITEEXEDWORD
;PROCESSWBITOPCODE
;PROCESSMODREGRMBYTE
;PROCESSMEMORYANDDISP
;PROCESSIMMEDIATEDATA
;PROCESSCODELABEL
;GETOPSTR
;GETOPERATION
;postprocess
;TEST4ARRAY
;TEST4REG
;TEST4FPUREG
;TEST4MEM
;TEST4IMM
;TEST4NUM
;check4destreg32
;PROCESSLOCALSTRING
;PROCESSSYSENTERCSV
;SYMBOL_TABLE
;ERRORCODE
;POSTPROCESS
;DATA
;SAVEGLOBALSYM
;PUBLIC
;EXTERN
;SOURCEfilenum




ttasm:

	;now that ttasm is called within a "make" loop
	;we need to preserve some registers
	;ttasm returns values in eax & ebx
	push ecx
	push edx
	push esi
	push edi
	push ebp

	call dumpreset
	mov dword [_onpass2],0    ;0=first pass, 1=2nd pass
	mov dword [_errorcode],0
	mov dword [_haveExit],0
	mov dword [_haveorg],0
	mov dword [_havestart],0
	mov dword [_exeAddressStart],0
	mov dword [_sourcefilenum],0


	;zero out the exe header except for address of ..start
	;we will not zero out 0x2000008 so the user may assemble the "main" source
	;only once then work on and assemble secondary source files and immediate
	;run the code without having to go back and reassemble main
	mov dword [0x2000000],0
	mov dword [0x2000004],0
	;mov dword [0x2000008],0  holds the starting address of executable code
	mov dword [0x200000c],0



	;zero out the ttasm string table
	;all code labels and their addresses are saved to this table
	;the table is dumped after every assembly
	cld
	mov al,0
	mov ecx,0x20000
	mov edi,0x29a0000
	rep stosb

	;init the string table pointer
	mov [_stringtblptr],dword 0x29a0000



	;erase the ttasm symbol table 
	call symtableclear


	;Load the ttasm assembler symbols before the 1st pass
	;these are all the symbols assembled into ttasm
	;included assembly directives, special constants and 
	;all the assembly code strings like cmp,mov,add,sub ... that ttasm understands
	;the symbol table is a shared resource
	;the user code labels and ttasms symbols both reside in this symbol table

	push ttasmSymbols
	push LastSymTableEntry
	call symtableload     
	jnz .doneLoadingSymbols
	mov dword [_errorcode],ERRORSYMTABLE
	jmp near .ttasm_end	
.doneLoadingSymbols:


	;1st pass header for the dump
	STDCALL str80,dumpstr   ;********************************
	STDCALL str21a,dumpstr  ;******** TTASM 1st PASS  *******
	STDCALL str80,dumpstr   ;********************************







	;********************************
	;READ ASM SOURCE BY LINE
	;********************************



	;prepare to parse asm source
	;we jump back here _onpass2

.StartSecondPass:

	cld
	mov dword [_asmsrcindex],0x1990000  ;starting address of source
	mov dword [_linecount],0 
	mov dword [_assypoint],STARTOFEXE   ;redefined by org


.parseline:

	;_linebufindex keeps tract of where we are parsing in the line
	mov dword [_linebufindex],0


	;zero out the 100 byte linebuffer
	cld
	mov eax,0
	mov ecx,25
	mov edi,_linebuf
	rep stosd


	;set _wbit for this line of asm code to some invalid value
	;later is should be set by getopstr or some other function to 0,1,2,3
	mov dword [_wbit],0xff


	;test4imm sets this value to 1 for extern variables
	;every instruction that references an extern variable must test this value
	;and add an entry to the extern symbol table
	mov dword [_havextern],0


	;copy a line of _asmsrc to _linebuf
	mov esi, [_asmsrcindex]
	mov edi,_linebuf
	call getline
	;esi is incremented to the last byte fetched
	;eax=return code:
	;0=successful copy, found NEWLINE, 0 terminated
	;1=blank line found
	;2=error:parse error or buffer full and not 0 terminated
	;3=found 0 (eof)
	;5=code_label: (ends with :)



	mov edi,_linebuf
	call StripTrailingSpace


	inc dword [_linecount]


	;save where we are in the source
	mov dword [_asmsrcindex],esi 


	;from here we check the getline() return value in eax



	;****************************
	;5=code label  (i.e. apple:)
	;****************************

	cmp eax,5  
	jnz near .notlabel

	push _linebuf
	call ProcessCodeLabel

	jmp .parseline

.notlabel:





	;****************
	;4=comment line
	;****************

	;June 2012 getline will now silently eat up comment lines by itself
	;or comments after a line of asm code so we probably never get here

	cmp eax,4  
	jz .parseline




	;*********************
	;3=end of ascii file
	;*********************

	cmp eax,3  
	jnz .eofnotfound
	mov eax,0

	;this is our normal exit on pass 2
	cmp dword [_onpass2],1
	jz near .ttasm_end
	
	
%if VERBOSEDUMP == 0
	;erase ttasm dump messages after pass=1 
	;because large asm files will overflow the dump if dumping messages on both passes
	;this makes messages in tablesym, tablepub, tableext unavailable
	call dumpreset
%endif


	;2nd pass header for the dump
	call dumpnl
	call dumpnl
	STDCALL str80,dumpstr   ;********************************
	STDCALL str21b,dumpstr  ;******** TTASM 2ND PASS  *******
	STDCALL str80,dumpstr   ;********************************

	mov dword [_onpass2],1  ;mark that we are doing the 2nd pass
	jmp .StartSecondPass

.eofnotfound:


	;************************************************
	;2=parse error or buffer full not 0 terminated
	;************************************************

	cmp eax,2  
	jnz .linebufnotfull
	mov dword [_errorcode],ERRORPARSE 
	jmp .ttasm_end
.linebufnotfull:


	;***************
	;1=blank line
	;***************

	cmp eax,1  
	jz .parseline
	



	;******************************
	;0=getline returns success
	;******************************

	;leave 3 blank lines after end of previous asm code dump
	call dumpnl
	call dumpnl
	call dumpnl

	;dump the line of asm code as ascii string that we are processing
	STDCALL _linebuf,dumpstr


	;dump the linecount
	mov eax,[_linecount]
	STDCALL str5,3,dumpeax  ;3=dump as decimal base 10


	;dump the _assypoint or location counter LC
	;this is the address in memory where the exe code bytes are written to
	;the main source file should have all asm code written to 'org STARTOFEXE'
	mov eax,[_assypoint]
	STDCALL str42,0,dumpeax  ;0=dump as hex 





	;*******************************************************
	;Get Instruction String
	;collect the first "word" from getline
	;this could be an assy instruction like mov,cmp,and,or,xor...
	;or an assembly directive like org,start,equ,align,global...
	;******************************************************

	;now read linebuf looking for the first word
	;this would be all ascii bytes from the beginning of the line
	;until we hit SPACE
	;this first word must be hashed into ttasms symbol table
	xor ecx,ecx
	mov esi,_linebuf
.readinstr:
	lodsb                 ;al=[esi],esi++
	cmp al,SPACE          ;space seperated values !
	jz .doneinstr
	cmp al,0
	jz .doneinstr
	mov [_instruc+ecx],al  ;save byte
	inc ecx
	jmp .readinstr
.doneinstr:

	;0 terminate the instruction string
	mov byte [_instruc+ecx],0
	inc ecx  ;ecx=strlen of instruction string


	;save where we are in the linebuf
	;_linebufindex points to the first char after the instruction
	mov [_linebufindex],esi





	;**********************
	;SYMBOL TABLE LOOKUP
	;**********************
		

	;see if the instruction string is in the symtable
	;this function will also display the string using quotes
	mov esi,_instruc
	call symlookup   ;eax=data class, ebx=symbol value/function entry  


	;check return
	cmp eax,0  ;0=failed:not in table
	jnz .intable
	;dump the string which symlookup failed
	push esi
	call dumpstrquote
	;and set an errorcode
	mov dword [_errorcode],ERRORSYMNOTINTBL
	jmp .ttasm_end	
	.intable:


	;call a custom function to deal with the instruction
	;this function will intern call other functions
	;until the entire asm source line is processed
	;this better be a call to a tlib subroutine
	;like dojmpd, domov, docmp ...
	call ebx


	;make sure we have no errors before continuing
	cmp dword [_errorcode],0
	jz .parseline

	;if we got here there are errors, just postprocess
	jmp .done



.ttasm_end:


.done:
	call postprocess

	pop ebp
	pop edi
	pop esi
	pop edx
	pop ecx

	;ttasm return values 
	mov eax,_ttasmreturnstring  ;address of string giving results of assemble
	mov ebx,[_errorcode]

	ret




;***************END OF TTASM*************************************



;these WriteExe... routines had checks to make sure
;we did not exceed 1meg code size but checks are removed
;because now we allow 10meg for all exe and resources
;will we ever generate an exe that big ???


;****************************************
;WRITEEXEBYTE
;input: al=exe byte written 
;****************************************

WriteExeByte:
	push edi
	mov edi,[_assypoint]
	mov [edi],al           ;write byte of executable code
	inc dword [_assypoint] ;inc our assembly point
	STDCALL 0,2,dumpeax
	pop edi
	ret


;****************************************
;WRITEEXEWORD
;input: ax=exe word written 
;****************************************

WriteExeWord:
	push edi
	mov edi,[_assypoint]
	mov [edi],ax              ;write word of executable code
	add dword [_assypoint],2  ;inc our assembly point
	STDCALL 0,2,dumpeax
	shr ax,8 ;ah->al
	STDCALL 0,2,dumpeax
	pop edi
	ret


;************************
;WRITEEXEDWORD
;input: eax=dword written 
;************************
WriteExeDword:
	push edi
	mov edi,[_assypoint]
	mov [edi],eax             ;write dword of executable code
	add dword [_assypoint],4  ;inc our assembly point / location counter (LC)
	STDCALL 0,2,dumpeax       ;write lo byte
	ror eax,8
	STDCALL 0,2,dumpeax
	ror eax,8
	STDCALL 0,2,dumpeax
	ror eax,8
	STDCALL 0,2,dumpeax
	pop edi
	ret







;*************************
;          MOV
;*************************
MovOperation:
dd movarray2reg, movmem2reg,  movreg2reg 
dd movimm2reg,   movreg2mem,  movimm2mem  
dd movreg2array, movimm2array


;If the operands are memory or register
;you must call functions in the following order
; *ProcessWbitOperand
; *ProcessModRegRmByte
; *ProcessMemoryAndDisp

;if the source operand is immediate data then
; *ProcessWbitOperand
; *ProcessModRegRmByte
; *ProcessMemoryAndDisp
; *ProcessImmediateData



domov:
	STDCALL str1,dumpstr
	call getoperation
	;eax=function table index
	cmp dword [_errorcode],0
	jnz .done
	call [MovOperation + eax*4]
.done:
	ret



;mov register,[memory]
;1000 101w modregrm
movmem2reg:

	STDCALL str10,dumpstr

	mov al,0x8a
	call ProcessWbitOpcode

	mov ebx,[_destvalu]      ;regnum
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	ret


;mov [memory],register
;1000 100w modregrm
movreg2mem:

	STDCALL str9,dumpstr

	mov al,0x88
	call ProcessWbitOpcode

	mov ebx,[_sourcevalu] ;regnum
	call ProcessModRegRmByte

	mov ebx,[_destclass]  ;mem class
	mov eax,[_destvalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	ret



;mov [memory],imm 
movimm2mem:

	STDCALL str29,dumpstr

	mov al,0xc6
	call ProcessWbitOpcode
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,0  
	call ProcessModRegRmByte

	mov ebx,[_destclass]  ;mem class
	mov eax,[_destvalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	mov eax,[_sourcevalu]
	call ProcessImmediateData

.done:
	ret




;ttasm: mov edx,apple[reg]
;nasm:  mov edx,[apple+reg*4]
;mov dword array element to 32bit reg
;reg = any 32bit register as index to array except ebp and esp
movarray2reg:

	STDCALL str101,dumpstr
	
	;opcode
	mov al,0x8b
	call WriteExeByte
	
	;modregr/m 
	;mod=00
	;reg=regnum
	;r/m=100 for SIB byte follows
	mov ebx,[_destvalu]  
	shl ebx,3
	mov eax,4
	or eax,ebx
	call WriteExeByte

	;SIB byte = 0x85 + 8*indexregnum  (disp32 follows with no base)
	mov eax,[_sourceclass] ;indexregnum
	shl eax,3
	add eax,0x85
	call WriteExeByte

	;array address
	mov eax,[_sourcevalu]
	call WriteExeDword

	ret


	
;ttasm: mov apple[reg],edx
;nasm:  mov [apple+reg*4],edx
;mov 32bit reg to dword array element
;reg = any 32bit register as index to array except ebp and esp
movreg2array:

	STDCALL str100,dumpstr

	;opcode
	mov al,0x89
	call WriteExeByte

	;modregr/m
	mov ebx,[_sourcevalu]  
	shl ebx,3
	mov eax,4
	or eax,ebx
	call WriteExeByte

	;SIB byte = 0x85 + 8*indexregnum  (disp32 follows with no base)
	mov eax,[_destclass] ;indexregnum
	shl eax,3
	add eax,0x85
	call WriteExeByte

	;array address
	mov eax,[_destvalu]
	call WriteExeDword

	ret




movimm2reg:

	STDCALL str7,dumpstr

	cmp dword [_wbit],0  ;byte register
	jz .1
	cmp dword [_wbit],1  ;dword register
	jz .3
	cmp dword [_wbit],2  ;word register
	jz .2

	;if we got here we have an invalid _wbit
	jmp .error


.1:
	;BYTE reg
	;write 1101wreg for byte register [_wbit]=1
	mov al,0xb0        ;1101w000 with w=0
	or al,[_destvalu]  ;regnum = _destvalue
	call WriteExeByte
	jmp .4

.2:
	;WORD reg
	;write 1101wreg for word [_wbit]=2 
	;need 66h prefix to indicate word register when processor in 32bit mode
	mov al,0x66  
	call WriteExeByte
	mov al,0xb8        ;1101w000 with w=1
	or al,[_destvalu]  ;regnum = _destvalue
	call WriteExeByte
	jmp .4

.3:
	;DWORD reg
	;write 1101wreg for dword [_wbit]=1
	mov al,0xb8        ;same byte as word reg
	or al,[_destvalu]  ;regnum = _destvalue
	call WriteExeByte
	;fall thru


.4:
	;save the assy point for extern_add_link
	;in case the immediate value is extern and needs to be patched by tlink
	mov eax,[_assypoint] 
	mov [_extern_address],eax  

	;write the immediate data
	mov eax,[_sourcevalu] 
	call ProcessImmediateData


	;if the imm data is an extern symbol...

	;add a link for every instance/usage of an extern symbol 
	;test4imm determines if we have an extern symbol
	;test4imm also saves the extern symbol to _externbuffer
	;we only add extern symbols to extern symbol table on pass 1
	cmp dword [_onpass2],1  ;are we on pass=2 ?
	jz .done  
	cmp dword [_havextern],1
	jnz .done

	call dumpnl
	STDCALL str290,dumpstr
	push dword _externbuffer
	push dword [_extern_address] 
	call extern_add_link
	jz .error1
	jmp .done

.error1:
	mov dword [_errorcode],ERROREXTRNLINKADD 
	jmp .done
.error:
	mov dword [_errorcode],ERRORWBIT
.done:
	ret








;mov ebx,ecx
;mov bx,cx
;mov bl,cl
movreg2reg:

	STDCALL str8,dumpstr

	cmp dword [_wbit],2
	jnz .noprefix
	mov al,0x66
	call WriteExeByte
	mov dword [_wbit],1
.noprefix:

	mov al,0x88
	or eax,[_wbit]
	call WriteExeByte
	mov al,0xc0
	or eax,[_destvalu]    ;des reg
	mov ebx,[_sourcevalu] ;src reg
	shl ebx,3
	or eax,ebx
	call WriteExeByte

	ret



;ttasm: mov apple[reg],0x1234  
;nasm:  mov dword [apple+reg*4],0x1234
;we support dword immediate only
;reg = any 32bit register as index to array except ebp and esp
movimm2array:

	STDCALL str111,dumpstr

	;opcode
	mov al,0xc7
	call WriteExeByte

	;mod=00
	;reg=00
	;r/m=100=SIB byte follows
	mov al,4
	call WriteExeByte

	;SIB byte = 0x85 + 8*indexregnum  (disp32 follows with no base)
	mov eax,[_destclass] ;indexregnum
	shl eax,3
	add eax,0x85
	call WriteExeByte

	;memory address
	mov eax,[_destvalu]
	call WriteExeDword

	;immediate 
	mov eax,[_sourcevalu]
	call WriteExeDword

	ret



;*************************
;          MOVZX
;*************************

;we support:
;mov reg32, byte [mem]  0f b6 modregr/m disp32
;mov reg32, word [mem]  0f b7 modregr/m disp32
;modregr/m = 00reg101 where reg=destination register

domovzx:

	STDCALL str73,dumpstr

	STDCALL _deststr,getopstr
	jc near .done 

	;is destination reg32 ?
	mov esi,_deststr
	call test4reg      ;ebx=regnum  ecx=wbit
	jnz .errordest
	cmp ecx,1
	jnz .errordest

	mov [_destvalu],ebx  ;save dest regnum
	;we dont save _wbit here because
	;_wbit will be determined by the source
	
	;getopstr will process the byte/word source qualifier
	;and save global [_wbit] for us
	;0=byte, 2=word, 
	STDCALL _sourcestr,getopstr
	jc near .done 

	;is source mem8 or mem16 ?
	mov esi,_sourcestr
	call test4mem
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is in register _rm & ebx=disp8 or disp32 (we dont support this)
	jnz .errorsrc
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	;write byte1
	mov al,0x0f
	call WriteExeByte

	;write byte2
	cmp dword [_wbit],2
	jz .WordExtend
	;we default to byte extend
	mov al,0xb6
	call WriteExeByte
	jmp .donebyte2
.WordExtend:
	mov al,0xb7
	call WriteExeByte
.donebyte2:

	;write byte3 is 00reg101 where reg=dest reg
	mov al,5
	mov edx,[_destvalu]
	shl edx,3
	or eax,edx
	call WriteExeByte

	;write dword memory address
	mov eax,ebx  ;ebx should hold our memory address from test4mem
	call WriteExeDword
	jmp .done


.errordest:
	mov dword [_errorcode],ERRORINVALDEST
	jmp .done
.errorsrc:
	mov dword [_errorcode],ERRORINVALSOURCE
.done:
	ret




;*************************
;          CALL
;*************************

;we support 3 "in same segment" calls:
;[1] call register........ Fetch address from register
;[2] call [Address]....... absolute indirect (fetch address from memory)
;[3] call Address......... dword relative displacement 
	
docall:

	STDCALL str2,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .error 


	;call reg32
	;******************
	STDCALL str74,dumpstr

	mov esi,_sourcestr
	call test4reg      
	;ebx=regnum  ecx=wbit
	jnz .donecallreg

	cmp ecx,1   ;must be 32bit reg
	jnz near .error3

	mov al,0xff
	call WriteExeByte
	mov al,0xd0
	or eax,ebx   ;ebx=regnum
	call WriteExeByte
	jmp .done
.donecallreg:



	;call [Memory] absolute indirect
	;**********************************
	STDCALL str65,dumpstr

	;this call was used in the early days of tatOS 
	;for the user to call tlib functions indirectly thru the tlib.s call table. 
	;now with the protected mode interface, user may no longer call 
	;tlib functions indirectly. user would have to make his own call table in 
	;user space to use this function

	mov esi,_sourcestr
	call test4mem
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is in register _rm & ebx=disp8 or disp32
	jnz .donecallmem
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx


	;call [extern] is not allowed
	cmp dword [_havextern],1  ;test4imm will set this flag
	jz near .error2
	
	mov al,0xff
	call WriteExeByte

	mov ebx,010b    ;reg is hardcode for this instruction 
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	jmp .done
.donecallmem:



	;call reldisp32
	;****************************
	STDCALL str64,dumpstr

	mov esi,_sourcestr
	call test4imm     ;ebx=imm value code label
	jnz .doneimm

	;are we calling a procedure defined in another file ?
	cmp dword [_havextern],1  ;test4imm will set this flag
	jz .1


	;call reldisp32: local function in the same file
	;*************************************************

	mov al,0xe8
	call WriteExeByte

	;dword relative displacement (same code as jmpd)
	;the -4 is required because the reldisp32 is from the end of this instruction
	sub ebx,[_assypoint]  ;ebx=(targetimm - _assypoint)  it may be + or -
	sub ebx,4             ;ebx=reldisp32 = (targetimm - _assypoint - 4) 
	mov eax,ebx
	call WriteExeDword
	jmp .done

.1:

	;call reldisp32:  public function (in another file)
	;***************************************************
	;here we will not write reldisp32 because we dont know what it is
	;only the linker knows "destination"
	;reldisp32 = (destination - _assypoint + 4)
	STDCALL str286,dumpstr

	mov al,0xe8
	call WriteExeByte
	mov eax,[_assypoint] 
	mov [_extern_address],eax  ;save for extern_add_link
	add eax,4                  ;(_assypoint+4)
	call WriteExeDword

	call dumpnl

	;we only add to the extern table on pass=1 
	cmp dword [_onpass2],1  ;are we on pass=2 ?
	jz .done                 

	;add link to extern symbol table
	push dword _externbuffer
	push dword  [_extern_address]
	call extern_add_link
	jz .error1
	jmp .done



.doneimm:
	;if we got here we ran out of call options so error
.error:
	mov dword [_errorcode],ERRORINVALSOURCE 
	jmp .done
.error1:
	mov dword [_errorcode],ERROREXTRNLINKADD 
	jmp .done
.error2:
	;attempt to call an extern symbol indirectly is not allowed
	mov dword [_errorcode],ERRORINVALCALL 
	jmp .done
.error3:
	;invalid register size, must be 32bit
	mov dword [_errorcode],ERRORINVALREGSIZE 
.done:
	ret







;*************************
;          PUSH
;*************************

;we support: 
;push reg
;push immed dword
;push [memory] (dword address only)
;push [reg32], push [ebp+disp8], push [esi+disp8]  dword only


dopush:
	STDCALL str93,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;push register
	;****************************
	mov esi,_sourcestr
	call test4reg      
	;ebx=regnum  ecx=wbit
	jnz .not32bitreg
	mov al,0x50
	or eax,ebx
	call WriteExeByte
	jmp .done
.not32bitreg:



	;push dword [memory] 
	;********************************
	mov esi,_sourcestr
	call test4mem  ;ecx=memory class, ebx=disp or address
	jnz .notmem
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	;it is not necessary to type push dword [memory]
	;you can just write push [memory]
	mov dword [_wbit],1  ;we force dword push only	

	mov al,0xff
	call ProcessWbitOpcode
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,110b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	jmp .done
.notmem:
	


	;push immediate  dword only
	;*************************
	mov esi,_sourcestr
	call test4imm
	;ebx=imm valu
	jnz .notimmed
	mov al,0x68
	call WriteExeByte
	mov eax,ebx
	call WriteExeDword
	jmp .done
.notimmed:


	;if we got here we are in trouble
	mov dword [_errorcode],3

.done:
	ret
	






;*************************
;          PUSHFD
;*************************
;push dword eflags

dopushfd:
	STDCALL str227,dumpstr
	mov al,0x9c
	call WriteExeByte
	ret


;*************************
;          POPFD
;*************************
;pop dword eflags

dopopfd:
	STDCALL str265,dumpstr
	mov al,0x9d
	call WriteExeByte
	ret





	
;*************************
;          POP
;*************************

dopop:
	STDCALL str94,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	;pop reg
	;************
	mov esi,_sourcestr
	call test4reg  ;ebx=regnum  ecx=wbit
	jnz .donepopreg
	mov al,0x58  ;this is alternate encoding 1 byte instruction
	or eax,ebx
	call WriteExeByte
	jmp .done
.donepopreg:


	;pop [Memory]  (dword is implied)
	;*********************************
	mov esi,_sourcestr
	call test4mem 
	;ecx=1 memory is immed or defined const, ebx=address
	;ecx=2 memory in reg _rm and ebx=disp8 or disp32
	jnz .error
	mov [_sourcevalu],ebx
	mov [_sourceclass],ecx

	mov al,0x8f
	call WriteExeByte

	mov ebx,0 ;reg is hardcode for this instruction 
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done
		
.error:
	mov dword [_errorcode],3
.done:
	ret
	




	
;*************************
;          PUSHAD
;*************************

;push all 32bit regs

dopushad:
	STDCALL str95,dumpstr
	mov al,0x60
	call WriteExeByte
	ret


	
;*************************
;          POPAD
;*************************

;pop all 32bit regs

dopopad:
	STDCALL str96,dumpstr
	mov al,0x61
	call WriteExeByte
	ret



;*************************
;          RET/RETN
;*************************

;ret
doret:
	STDCALL str3,dumpstr
	mov al,0xc3
	call WriteExeByte
	ret

;ret 16bitdisp
doretn:
	STDCALL str114,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	mov esi,_sourcestr
	call test4imm
	;ebx=immed value
	jnz .srcnotimmed
	mov al,0xc2
	call WriteExeByte
	mov eax,ebx
	call WriteExeWord
	jmp .done
.srcnotimmed:

	;parse error
	mov dword [_errorcode],7

.done:
	ret


;*************************
;          NOP
;*************************

donop:
	STDCALL str46,dumpstr
	mov al,0x90
	call WriteExeByte
	ret

;*************************
;          CDQ
;*************************

;replicate top bit of eax into edx
;use prior to imul and idiv
docdq:
	STDCALL str97,dumpstr
	mov al,0x99
	call WriteExeByte
	ret


;*************************
;          CLI/STI
;*************************

;clear/set interrupt flag IF
;this is bit9 of EFLAGS
;this will disable/enable the maskable interrupts
;I love these 1 byte instructions :)

docli:
	STDCALL str78,dumpstr
	mov al,0xfa
	call WriteExeByte
	ret

dosti:
	STDCALL str79,dumpstr
	mov al,0xfb
	call WriteExeByte
	ret



;*************************
;          STC/CLC
;*************************

;set/clear the carry flag

dostc:
	STDCALL str112,dumpstr
	mov al,0xf9
	call WriteExeByte
	ret

doclc:
	STDCALL str113,dumpstr
	mov al,0xf8
	call WriteExeByte
	ret


;*************************
;          STD/CLD
;*************************

;set/clear the direction flag

dostd:
	STDCALL str128,dumpstr
	mov al,0xfd
	call WriteExeByte
	ret

docld:
	STDCALL str129,dumpstr
	mov al,0xfc
	call WriteExeByte
	ret



;**************************************
;     STOSB/STOSW/STOSD/LODSB/LODSD
;**************************************

dostosb:
	STDCALL str105,dumpstr
	mov al,0xaa
	call WriteExeByte
	ret

dostosw:
	STDCALL str137,dumpstr
	mov al,0x66
	call WriteExeByte
	mov al,0xab
	call WriteExeByte
	ret

dostosd:
	STDCALL str106,dumpstr
	mov al,0xab
	call WriteExeByte
	ret

dolodsb:
	STDCALL str138,dumpstr
	mov al,0xac
	call WriteExeByte
	ret

dolodsd:
	STDCALL str186,dumpstr
	mov al,0xad
	call WriteExeByte
	ret




;****************************************
;   REPMOVSB/REPMOVSD/REPSTOSB/REPSTOSD
;****************************************

;repmovsb or repmovsd is the proper syntax
;rep movsb is not supported
;rep movsd is not supported
;ecx is the repeat count
;if you only want 1 byte set ecx=1
;repmovsb is used to copy a string from esi->edi
;dont forget cld if you want esi++ and edi++

dorepmovsb:
	STDCALL str134,dumpstr
	mov al,0xf3   ;rep
	call WriteExeByte
	mov al,0xa4
	call WriteExeByte
	ret

dorepmovsd:
	STDCALL str135,dumpstr
	mov al,0xf3   ;rep
	call WriteExeByte
	mov al,0xa5
	call WriteExeByte
	ret

dorepstosb:
	STDCALL str140,dumpstr
	mov al,0xf3   ;rep
	call WriteExeByte
	mov al,0xaa
	call WriteExeByte
	ret

dorepstosd:
	STDCALL str266,dumpstr
	mov al,0xf3   ;rep
	call WriteExeByte
	mov al,0xab
	call WriteExeByte
	ret







;*************************
;          CMP
;*************************

;if a register is involved its the dest op
;if an imm is involved its the source op 

CmpOperation:
dd cmparray2reg, cmpmem2reg,  cmpreg2reg 
dd cmpimm2reg,   cmpreg2mem,  cmpimm2mem  
dd cmpreg2array, cmpimm2array



docmp:
	STDCALL str6,dumpstr
	call getoperation
	;eax=function table index
	cmp dword [_errorcode],0
	jnz .done
	call [CmpOperation + eax*4]
.done:
	ret




;cmp register,[memory]
cmpmem2reg:

	STDCALL str121,dumpstr

	mov al,0x3a
	call ProcessWbitOpcode

	mov ebx,[_destvalu]  ;regnum
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	ret


;cmp [memory],register
cmpreg2mem:

	STDCALL str43,dumpstr

	mov al,0x38
	call ProcessWbitOpcode

	mov ebx,[_sourcevalu]  ;regnum
	call ProcessModRegRmByte

	mov ebx,[_destclass]  ;mem class
	mov eax,[_destvalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	ret



;cmp [memory],imm 
;note we do not support the sign extend bit, s=0
cmpimm2mem:

	STDCALL str213,dumpstr

	mov al,0x80
	call ProcessWbitOpcode

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,111b 
	call ProcessModRegRmByte

	mov ebx,[_destclass]  ;mem class
	mov eax,[_destvalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	mov eax,[_sourcevalu]
	call ProcessImmediateData
.done:
	ret









;cmp ebx,12
cmpimm2reg:
	STDCALL str44,dumpstr

	;32bit reg
	cmp dword [_wbit],1
	jnz .not32bit
	mov al,0x81
	call WriteExeByte
	mov al,0xf8
	or eax,[_destvalu]
	call WriteExeByte
	mov eax,[_sourcevalu]
	call WriteExeDword
	jmp .done
.not32bit:

	;16bit reg
	cmp dword [_wbit],2
	jnz .not16bit
	mov al,0x66
	call WriteExeByte
	mov al,0x81
	call WriteExeByte
	mov al,0xf8
	or eax,[_destvalu]
	call WriteExeByte
	mov eax,[_sourcevalu]
	call WriteExeWord
	jmp .done
.not16bit:

	;8bit reg
	mov al,0x80
	call WriteExeByte
	mov al,0xf8
	or eax,[_destvalu]
	call WriteExeByte
	mov eax,[_sourcevalu]
	call WriteExeByte

.done:
	ret



;cmp Myarray[reg],0x1234
;array is dword and so is immed
;reg is any 32bit register as index to array except esp and ebp
cmpimm2array:
	STDCALL str132,dumpstr

	mov al,0x81
	call WriteExeByte
	mov al,0x3c
	call WriteExeByte

	;SIB byte = 0x85 + 8*indexregnum  (disp32 follows with no base)
	mov eax,[_destclass] ;indexregnum
	shl eax,3
	add eax,0x85
	call WriteExeByte

	mov eax,[_destvalu]  ;array name
	call WriteExeDword
	mov eax,[_sourcevalu] ;memAddress
	call WriteExeDword  

	ret
	



;cmp reg2,reg1
;0011100w 11reg1reg2
cmpreg2reg: 
	STDCALL str173,dumpstr

	mov eax,0x38
	or eax,[_wbit]
	call WriteExeByte
	mov eax,0xc0
	mov ebx,[_sourcevalu]
	shl ebx,3
	or eax,ebx
	or eax,[_destvalu]
	call WriteExeByte
	
	ret




;ttasm: cmp ebx,Apple[reg]
;nasm:  cmp ebx,[apple+reg*4]
;00111011 00reg100 8d disp32
;reg=any 32bit register as index except esp and ebp
cmparray2reg:
	STDCALL str174,dumpstr

	mov al,0x3b
	call WriteExeByte
	mov eax,4
	mov ebx,[_destvalu]  ;regnum
	shl ebx,3
	or eax,ebx
	call WriteExeByte

	;SIB byte = 0x85 + 8*indexregnum  (disp32 follows with no base)
	mov eax,[_sourceclass] ;indexregnum
	shl eax,3
	add eax,0x85
	call WriteExeByte

	mov eax,[_sourcevalu] ;memory address
	call WriteExeDword

	ret



;unsupported cmp operations
cmpreg2array:
	mov dword [_errorcode],6
	ret





;*************************
;          JMP
;*************************

;this is nasms jmp near
;source may be dword immediate displacement or 32bit reg
;the displacement is relative to the first byte of the next instruction

dojmp:
	STDCALL str16,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	;try jmp with code label in reg
	mov esi,_sourcestr
	call test4reg    ;ebx=regnum
	jz .jmpToReg

	;try jmp with imm code label
	mov esi,_sourcestr
	call ProcessLocalString ;returns esi=global or global.local
	call test4imm    ;ebx=imm value code label
	jz .jmpToImm           

	;error, perhaps missing code label
	mov dword [_errorcode],ERRORSYMTABLE
	jmp .done


.jmpToImm:
	mov al,0xe9    ;jmp dword displacement
	call WriteExeByte
	
	;dword relative displacement 
	;the -4 is required because the reldisp32 is from the end of this instruction
	sub ebx,[_assypoint]  ;ebx=(targetimm - _assypoint) 
	sub ebx,4             ;jmp disp starts at the next instr
	mov eax,ebx
	call WriteExeDword
	jmp .done


.jmpToReg:
	mov al,0xff
	call WriteExeByte
	mov al,0xe0
	add al,bl   ;regnum
	call WriteExeByte

.done:
	ret


	
;*************************
;          JMPS
;*************************

;this is nasms jmp short
;jmps relative byte displacement
;jmps is a 2 byte instruction
;0xeb byte_displacement
;displacement range is -128 to +127 bytes
;the displacement is relative to the 
;first byte of the next instruction

dojmps:
	STDCALL str48,dumpstr

	;on pass 1 write garbage values
	cmp dword [_onpass2],0
	jz .writecode

	STDCALL _sourcestr,getopstr
	jc near .done 

	;label is resolved on pass 2
	mov esi,_sourcestr
	call ProcessLocalString ;returns esi=global or global.local
	call test4imm            ;ebx=imm value code label
	jz .checkdisp            ;error not imm


	;parse error, perhaps  missing label
	mov dword [_errorcode],7
	jmp .done


.checkdisp:
	;byte displacement
	sub ebx,[_assypoint]  ;ebx=code label value
	sub ebx,1             ;jmp disp starts after the byte

	STDCALL str49,dumpstr
	call dumpreg

	;are we within range of short jump ? 
	cmp ebx,127
	setl cl
	cmp ebx,-128
	setg dl
	add cl,dl
	cmp cl,2
	jz .writecode

	;we are in trouble, displacement is too great for byte
	mov dword [_errorcode],5
	jmp .done

.writecode:
	mov al,0xeb  
	call WriteExeByte
	mov eax,ebx
	call WriteExeByte

.done:
	ret



;******************************************
;     JZ,JNZ,JS,JNS,JA,JC,JB,JNC,JAE,JBE 
;     JL,JG,JLE,JGE,JE,JNE  (signed)
;******************************************

;conditional jumps
;0f xx disp32
;where xx=byte describing the type of jump (is stored temp in ebp)
;the displacement is relative to the first byte of the "next" instruction


dojc:
dojb:
	STDCALL str54,dumpstr
	mov ebp,0x82
	jmp jcc_continue

dojnc:
dojae:
	STDCALL str55,dumpstr
	mov ebp,0x83
	jmp jcc_continue

dojz:  
doje:
	STDCALL str51,dumpstr
	mov ebp,0x84
	jmp jcc_continue
	
dojnz:  
dojne:
	STDCALL str52,dumpstr
	mov ebp,0x85
	jmp jcc_continue

dojbe:
	STDCALL str56,dumpstr
	mov ebp,0x86
	jmp jcc_continue

doja:
	STDCALL str53,dumpstr
	mov ebp,0x87
	jmp jcc_continue

dojs:
	STDCALL str59,dumpstr
	mov ebp,0x88
	jmp jcc_continue

dojns:
	STDCALL str60,dumpstr
	mov ebp,0x89
	jmp jcc_continue

dojl:
	STDCALL str206,dumpstr
	mov ebp,0x8c
	jmp jcc_continue

dojge:
	STDCALL str208,dumpstr
	mov ebp,0x8d
	jmp jcc_continue

dojle:
	STDCALL str207,dumpstr
	mov ebp,0x8e
	jmp jcc_continue

dojg:
	STDCALL str103,dumpstr
	mov ebp,0x8f
	jmp jcc_continue



jcc_continue:

	STDCALL _sourcestr,getopstr
	jc near .done 

	;label is resolved on pass 2
	mov esi,_sourcestr
	call ProcessLocalString ;returns esi=global or global.local
	call test4imm            ;ebx=imm value code label
	jz .writecode           

	;parse error, perhaps  missing label
	mov dword [_errorcode],7
	jmp .done


.writecode:
	mov al,0xf
	call WriteExeByte
	mov eax,ebp              ;get our byte from dojb, dojnz...
	call WriteExeByte        ;write al
	
	;dword displacement
	sub ebx,[_assypoint]  ;ebx=code label value
	sub ebx,4             ;jmp disp starts at the next instr
	mov eax,ebx
	call WriteExeDword

.done:
	ret





;*************************
;         SETCC
;*************************

;we only allow 8bit reg as operand

;seta bl
doseta:
	STDCALL str122,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 
	mov esi,_sourcestr
	call test4reg      
	;ebx=regnum
	jz .writecode
	;invalid source operand
	mov dword [_errorcode],3
	jmp .done
.writecode:
	mov al,0x0f
	call WriteExeByte
	mov al,0x97
	call WriteExeByte
	mov al,0xc0
	or eax,ebx
	call WriteExeByte
.done:
	ret


;setb bl
dosetb:
	STDCALL str123,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 
	mov esi,_sourcestr
	call test4reg      
	;ebx=regnum
	jz .writecode
	;invalid source operand
	mov dword [_errorcode],3
	jmp .done
.writecode:
	mov al,0x0f
	call WriteExeByte
	mov al,0x92
	call WriteExeByte
	mov al,0xc0
	or eax,ebx
	call WriteExeByte
.done:
	ret


dosetge:
	STDCALL str203,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 
	mov esi,_sourcestr
	call test4reg      
	;ebx=regnum
	jz .writecode
	;invalid source operand
	mov dword [_errorcode],3
	jmp .done
.writecode:
	mov al,0x0f
	call WriteExeByte
	mov al,0x9d
	call WriteExeByte
	mov al,0xc0
	or eax,ebx
	call WriteExeByte
.done:
	ret


dosetg:
	STDCALL str210,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 
	mov esi,_sourcestr
	call test4reg ;ebx=regnum
	jz .writecode
	;invalid source operand
	mov dword [_errorcode],3
	jmp .done
.writecode:
	mov al,0x0f
	call WriteExeByte
	mov al,0x9f
	call WriteExeByte
	mov al,0xc0
	or eax,ebx
	call WriteExeByte
.done:
	ret




dosetle:
	STDCALL str204,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 
	mov esi,_sourcestr
	call test4reg      
	;ebx=regnum
	jz .writecode
	;invalid source operand
	mov dword [_errorcode],3
	jmp .done
.writecode:
	mov al,0x0f
	call WriteExeByte
	mov al,0x9e
	call WriteExeByte
	mov al,0xc0
	or eax,ebx
	call WriteExeByte
.done:
	ret


dosetl:
	STDCALL str211,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 
	mov esi,_sourcestr
	call test4reg ;ebx=regnum
	jz .writecode
	;invalid source operand
	mov dword [_errorcode],3
	jmp .done
.writecode:
	mov al,0x0f
	call WriteExeByte
	mov al,0x9c
	call WriteExeByte
	mov al,0xc0
	or eax,ebx
	call WriteExeByte
.done:
	ret



;*************************
;          LOOP
;*************************

;the displacement is 8bits
;relative to the end of the instruction
;e2 disp8
;apple:
;inc edx     ;0x42
;loop apple  ;0xe2 0xfd
;here disp8 is -3
doloop:
	STDCALL str104,dumpstr

	;on pass1 we just write garbage code
	;because test4imm returns 0 on pass1
	cmp dword [_onpass2],0
	jz .writecode

	STDCALL _sourcestr,getopstr
	jc near .done 

	;label is resolved on pass 2
	mov esi,_sourcestr
	call ProcessLocalString ;returns esi=global or global.local
	call test4imm            
	jnz .error
	;ebx=imm value code label

	;byte displacement
	sub ebx,[_assypoint]  ;ebx=code label value
	sub ebx,2             

	mov eax,ebx
	STDCALL str49,2,dumpeax

	;are we within range of short jump ? 
	cmp ebx,127
	setl cl
	cmp ebx,-128
	setg dl
	add cl,dl
	cmp cl,2
	jz .writecode

	;we are in trouble, displacement is too great for byte
	mov dword [_errorcode],5
	jmp .done

.writecode:
	mov al,0xe2  
	call WriteExeByte
	mov eax,ebx
	call WriteExeByte
	jmp .done

.error:
	mov dword [_errorcode],7
.done:
	ret




;**************************
;           LEA 
;**************************

;load effective address
;lea ebx,[esi+0x1234] or lea edx,[apple+0x1234]
;lea does address calculations
;lea does NOT read memory
;so for example if you put an address on the stack 
;this will not work: "lea eax,[ebp+8]"
;you must first move the address from stack into a register then use lea
;on that register

dolea:

	STDCALL str224,dumpstr

	STDCALL _deststr,getopstr
	jc near .done 

	;the dest must be reg32
	mov esi,_deststr
	call test4reg    ;ebx=regnum, ecx=Wbit
	jnz .errorDest
	cmp ecx,1        ;wbit must be 1 for reg32 dest
	jnz .unsupported
	mov [_reg],ebx   ;save for later

	STDCALL _sourcestr,getopstr
	jc near .done 

	;the source must be in the form [reg32+disp32]
	mov esi,_sourcestr
	call test4mem   ;returns _mod, _rm, ebx=disp32
	jnz .errorSource

	;this first byte of lea is always 0x8d
	mov al,0x8d
	call WriteExeByte

	push ebx   ;save disp32 for later
	mov ebx,[_reg]
	call ProcessModRegRmByte

	;write disp32
	pop eax   ;recall disp32
	call WriteExeDword

	jmp .done


.errorSource:
	mov dword [_errorcode],ERRORINVALSOURCE 
	jmp .done
.errorDest:
	mov dword [_errorcode],ERRORINVALDEST 
	jmp .done
.unsupported:
	mov dword [_errorcode],ERRORUNSUPPORTED 
.done:
	ret



;note to self Jan 03, 2016 erasepe has been removed
;since this function is now performed by make

;*******************************
;          SOURCEfilenum
;*******************************

;source xx
;assy directive to define a unique number representing the current source file 
;being assembled.  valid numbers range from 0->0xff
;the source # is used by ttasm in the public symbol table
;see tablepub.s for more details
;the default source # is 0
;each user source that is assembled into 1 project should be assigned a unique
;source number
;e.g.  source 2

dosourcefilenum:

	STDCALL str279,dumpstr

	STDCALL _sourcestr,getopstr
	jc .done 

	mov esi,_sourcestr
	call str2eax

	;assign a new source #
	mov [_sourcefilenum],eax

	;dump the new source #
	STDCALL str280,0,dumpeax

.done:
	ret



;*************************
;          EXTERN
;*************************

;add an entry to the "extern" symbol table directory 
;an extern symbol is one whos value in unknown at assembly time
;because it is defined in another file/module 
;all references to an extern symbol are assembled with a value of 00000000
;later tlink will patch all extern symbol addresses
;using the corresponding value from the public symbol table
;example:  extern orange

doextern:

	STDCALL str281,dumpstr

	;read the 11 byte ascii string/symbol into a 50 byte buffer named _sourcestr
	STDCALL _sourcestr,getopstr
	jc near .error1


	;we must only do this on the 1st pass 
	cmp dword [_onpass2],1  ;are we on pass=2 ?
	jz .skip                ;yes then we are done


	;add an entry to the extern symbol table directory
	STDCALL str284a,dumpstr
	push _sourcestr
	call extern_add_direntry
	jz .error2


	;add symbol to ttasm symbol table with special class code = 9
	STDCALL str284b,dumpstr
	mov esi,_sourcestr
	mov eax,0   ;symbol value (unknown at this time)
	mov edx,9   ;class=9 extern
	call symadd
	cmp eax,1
	jz .error3


	;there is no reason to add an "extern" symbol to the ttasm string table
	;this string table is for global symbols within the file and public symbols

	;and save global symbol for building global.local symbols
	;esi=address of global string
	call saveglobalsym
	jmp .done

.error3:
	mov dword [_errorcode],ERRORSYMADD 
	jmp .done
.error2:
	mov dword [_errorcode],ERROREXTERNDIRADD 
	jmp .done
.error1:
	mov dword [_errorcode],ERRORGETOPSTR
	jmp .done
.skip:
	STDCALL str282,dumpstr  ;skipping pass=2
.done:
	ret







;*************************
;          PUBLIC
;*************************

;this is a ttasm directive to add a symbol to the public symbol table
;a public symbol ascii string must be no more than 11 chars 
;there should be no leading dot and no trailing colon
;the address of all public symbols must be known at assembly time
;the public symbol table is used by tlink to resolve extern symbols
;with public symbols you must also issue a "sourcefile" directive
;see tablepub.s for details
;example: public apple

dopublic:

	STDCALL str273,dumpstr

	;read the symbol string into a 50 byte buffer named _sourcestr
	STDCALL _sourcestr,getopstr
	jc near .error1


	;we must only do public_table_add on the 1st pass 
	cmp dword [_onpass2],1  ;are we on pass=2 ?
	jz .1                   ;yes then we are done

	;add symbol to the public symbol table
	push _sourcestr
	push dword [_sourcefilenum]
	push dword [_assypoint]
	call public_table_add
	jz .error2

.1:
	;the public symbol is treated same as a local code lable
	;must be added to ttasm symbol table on pass=1 and retrieved on pass=2
	;this is because the label may be used locally as well as in another file
	;this function has its own test for pass=1 or pass=2
	push _sourcestr
	call ProcessCodeLabel
	jmp .done


.error2:
	mov dword [_errorcode],ERRORPUBSYMADD 
	jmp .done
.error1:
	mov dword [_errorcode],ERRORGETOPSTR
.done:
	ret





;*************************
;          ORG
;*************************

;e.g. org 0x02100000
;this is a ttasm directive 
;here you can re-define the _assypoint  (i.e. location counter LC)
;when you have multiple source files consisting of primary & secondary files
;you will want each secondary source file to have its own initial org
;the primary source file for all tatOS apps uses "STARTOFEXE" as the initial _assypoint
;secondary files may be assembled in memory somewhere after STARTOFEXE in the users page
;you are required to keep tract of where in memory your userland code is
;and the size of each assembled source file so as not to over write your self


doorg:

	STDCALL str268,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .error1 

	;test for multiple calls to org on the first pass
	;if we are on the first pass and have already done org thats an error
	;org must only be called once on each pass, 
	;normally before any symbols are processed or code is generated 
	cmp dword [_onpass2],1
	jz .doneorgtest   
	cmp dword [_haveorg],1
	jz .haveOrgAlready
.doneorgtest:


	;test for STARTOFEXE or some other userland address
	mov esi,_sourcestr
	call test4imm   ;returns ebx=immediate value
	jnz .errorSrc

	mov eax,ebx     ;eax=new org address

	;test for valid address within the users page 0x02000000->0x02400000
	push eax
	call ValidateUserAddress
	jc .errorAddress

	;ok we have a valid user address so redefine the _assypoint
	mov [_assypoint],eax

	;and save this address for sizeofexe calc in postprocess
	mov [_exeAddressStart],eax

	;and set a flag to indicate org has been defined
	mov dword [_haveorg],1

	;dump the new _assypoint, eax=[_assypoint]
	STDCALL str269,0,dumpeax

	jmp .done

.error1:
	mov dword [_errorcode],ERRORGETOPSTR
	jmp .done
.errorSrc:
	mov dword [_errorcode],ERRORINVALSOURCE 
	jmp .done
.errorAddress:
	mov dword [_errorcode],ERRORUSERADDRESS 
	jmp .done
.haveOrgAlready:
	mov dword [_errorcode],ERRORMULTIORG 
.done:
	ret



;*************************
;          ..START
;*************************

;   ..start
;a special symbol to define the address of start of executable code
;we write this address to the exe header at 0x2000008
;it must be an address between 0x2000010 and 0x23ff000
;note it must be in lower case and not followed by a colon
;the old way to start each exe with a 'jmp' statement is obsolete
;in a project with multiple asm sources, only 1 start should be defined

dostart:

	STDCALL str274,dumpstr

	mov eax,[_assypoint]

	;check that value of _assypoint is not less than 0x2000010 
	;since 0x2000000->0x2000009 are reserved for the header 
	;and bytes after the header are typically 
	;reserved for the users global data
	;if user has no global data than start=0x2000010 is acceptable
	cmp eax,0x2000010
	jl .done

	;check that the value of _assypoint is less than 0x23ff000
	;since the users stack starts at 0x2400000 and 0x23ff000 is 0x1000 bytes less
	;that gives the user 0x1000 bytes for stack space
	cmp eax,0x23ff000
	jae .done

	;write the value of _assypoint to 0x2000008
	;see tedit.s  press F10 where sysexit uses this value to run the users code
	mov [0x2000008],eax

	;flag to indicate that we have a start value
	mov dword [_havestart],1
	jmp .done

.error1:
	mov dword [_errorcode],ERRORUSERADDRESS 
.done:
	ret




;*************************
;          EQU
;*************************

;with equate you can define your own symbols
;syntax is a little differant from nasm
;example #1, APPLE is added to symbol table with the value 0x1234
;equ APPLE,0x1234
;example #2, PEAR is added to symbol table with the value (apple+0x40)
;equ PEAR,apple+0x40    (no spaces allowed)
;the second example is useful for defining the address of an element within an array
;you can only equate dword integer values not floating point constants
equstr1 db 'equ:ProcessSingleString',0
equstr2 db 'equ:ProcessDualString',0
equstr3 db 'equ:AddSymbolToTable',0

doequ:

	STDCALL str125,dumpstr
	STDCALL _deststr,getopstr
	jc near .error3 
	STDCALL _sourcestr,getopstr
	jc near .error3 


	;split the source string if it contains PLUS
	push _sourcestr  ;parent string
	push PLUS        ;seperator
	push 2           ;max qty substrings
	push _stor       ;storage for substring address
	call splitstr

	cmp eax,0
	jz near .error
	cmp eax,1  ;parent string only 
	jz near .SingleString
	cmp eax,2  ;two substrings seperated by PLUS
	jz near .DualString
	jmp near .error


.DualString:

	STDCALL equstr2,dumpstr
	
	;"apple" must be in the symbol table already
	;this function will also display the string using quotes
	mov esi,_sourcestr
	call symlookup
	;returns ebx=value of symbol "apple"

	cmp eax,0
	jz .error2  ;symbol not in table

	;now retrieve and convert to value in eax the 2nd substring 
	mov esi,[_stor]
	call str2eax

	;now add the address of "apple" plus the immediate value together
	add eax,ebx

	jmp .addToTable



.SingleString:

	STDCALL equstr1,dumpstr

	;convert imm string to eax
	mov esi,_sourcestr
	call str2eax


.addToTable:

	;dump the symbol value
	STDCALL equstr3,0,dumpeax

	;add symbol to the ttasm symbol table
	mov esi,_deststr
	mov edx,3   ;class=3 defined constant
	;esi=string, eax=value, edx=class
	call symadd
	;eax=0 for success, ebx=table index


	;symadd will fail on pass2
	;because the symbol is already in the table on pass1 
	;so we will only check for symadd return value on pass1
	;it could fail on pass1 if some previous symbol hashed to the same value

	cmp dword [_onpass2],1
	jz .done

	;check return value on pass1
	cmp eax,0  ;was symbol added successfully ?
	jz .done   ;yes
	jmp .error4 ;no



.error4:
	mov dword [_errorcode],ERRORSYMADD
	jmp .done
.error3:
	mov dword [_errorcode],ERRORGETOPSTR
	jmp .done
.error2:
	mov dword [_errorcode],ERRORSYMNOTINTBL 
	jmp .done
.error:
	mov dword [_errorcode],ERRORSYMTABLE 
	jmp .done
.done:
	ret




;*************************
;          INCBIN
;*************************

;this is same as nasm, borrowed from the old Amiga assembler
;we call fatreadfile and load off flash drive to memory
;syntax: incbin myfilename2
;note the filename is exactly 11 char not bounded by quotes
;the filename must have 11 char's no spaces
;the idea here is to tack on small bitmaps or data 
;to the end of your executable
;incbins should be located at the very end of your assembler source file
;and be preceeded by a symbol name which is dword aligned 
;e.g.
;align 32
;file01:
;incbin myfile01bts
incbinerror dd 0
incbinheapaddress dd 0  
incbinheapsize dd 0

doincbin:

	STDCALL str182,dumpstr

	STDCALL _sourcestr,getopstr
	jc near .done 

	mov dword [incbinerror],0 ;clear the incbinerror

	cmp dword [_onpass2],1
	jz .dopass2


	;*********1st Pass**********************


	;all we want is the filesize to properly increment the _assypoint
	;because in ttasm all symbols must be defined in the 1st pass
	push _sourcestr
	call fatfindfile ;eax=filesize on return or 0 on error
	cmp eax,0
	jnz .foundfile
	STDCALL str183,putspause
	mov dword [incbinerror],1
	jmp .failed
.foundfile:


	;advance the assy point by filesize
	add dword [_assypoint],eax

	;save the incbinheapsize for alloc
	mov [incbinheapsize],eax

	jmp .done



	;*********2nd Pass**********************
.dopass2:

	;see if we had an error finding the file on the 1st pass
	cmp dword [incbinerror],1
	jz .done


	;alloc some memory for loading the file on pass2
	mov esi,[incbinheapsize]
	call alloc  ;returns heap address in esi
	jnz .allocSuccess 
	mov dword [incbinerror],1
	jmp .failed
.allocSuccess:
	mov [incbinheapaddress],esi



	;copy the filename to FILENAME
	;its best if this is exactly 11 bytes long 0 terminated, no check here
	mov esi,_sourcestr
	mov edi,FILENAME
	call strcpy


	;load the file 
	;the reason we dont load directly to [_assypoint]
	;is because the data transfer can be messed up 
	;if your data crosses a page boundry memory address
	push dword [incbinheapaddress]
	call fatreadfile

	;check eax for filesize or 0 if error
	cmp eax,0
	jz .freeIncBinHeap ;failed to load

	;move the data to _assypoint, eax=filesize
	cld
	mov esi,[incbinheapaddress]
	mov edi,[_assypoint]
	mov ecx,eax
	rep movsb

	;increment _assypoint by filesize
	add dword [_assypoint],eax

.freeIncBinHeap:
	mov esi,[incbinheapaddress]
	call free

.failed:
.done:
	ret



;*************************
;          DB0
;*************************

;this is similar to nasms "times 100 db 0"
;we only support injecting 0 bytes into the exe
;like this:  "db0 100"
;in a flat binary environment 
;where code and data is mixed 
;this is useful for creating space 
;in your executable for data arrays
;if you need 100 dwords use "db0 400"

dodb0:
	STDCALL str81,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	mov esi,_sourcestr
	call str2eax

	;check for inject no bytes which doesnt make sense
	cmp eax,0
	jnz .injectzerobytes

	mov dword [_errorcode],7  ;parse error

.injectzerobytes:
	mov ecx,eax  ;qty to loop
	mov al,0
.again:
	call WriteExeByte
	loop .again

.done:
	ret



;*************************
;          DB
;*************************

;insert bytes directly into the exe
;you have two choices:
;(1) ascii bytes bounded by single quote 
;(2) decimal or hex csv bytes
;use 0xa csv byte for NEWLINE marker
;a quoted string may not follow csv bytes only preceed
;examples:
;db 'Hellow World',0
;db 23,45,0xf

dodb:

	STDCALL str17,dumpstr

	cld
	mov esi,[_linebufindex]
	call skipspace

	;check for single quote
	cmp byte [esi],0x27
	jnz .dbcsv

	;increment past the single quote
	inc esi

	;**************************************
	;ascii bytes bounded by single quotes
	;**************************************

.dbquoteLoop:	

	lodsb  ;al->[esi],esi++

	;look for ending quote
	cmp al,0x27  
	jz .prepareforcsv

	;if we find 0 terminator before end-quote thats parse error
	cmp al,0
	jz .error
	
	call WriteExeByte
	jmp .dbquoteLoop
	

.prepareforcsv:
	call dumpnl

	;skip spaces
	call skipspace

	;check for 0 terminator
	lodsb
	cmp al,0
	jz .done
	

	;***************************************
	;comma seperated bytes, hex or decimal
	;***************************************

.dbcsv:

	push esi         ;parent string
	push COMMA       ;seperator
	push 20          ;max qty substrings
	push _stor       ;storage for substring addresses
	call splitstr    ;return qty substrings in eax

	cmp eax,0
	jz .error

	;save qty substrings found
	mov [_qtystrings],eax
	
	;substring array index
	xor ecx,ecx

.processDBloop:

	;esi=address of db substring
	call test4imm ;ebx=imm valu
	jnz .error

	mov eax,ebx
	call WriteExeByte	

	call dumpnl

	;set esi to address of next substring
	mov esi,[_stor+ecx*4]
	inc ecx
	cmp ecx,[_qtystrings]
	jb .processDBloop

	jmp .done

.error:
	mov dword [_errorcode],ERRORPARSE
.done:
	ret 




;*************************
;          DW
;*************************
;we support comma seperated hex or decimal+- immediate values

dodw:

	STDCALL str57,dumpstr

	mov esi,[_linebufindex]  ;parent string

	push esi         ;parent string
	push COMMA       ;seperator
	push 20          ;max qty substrings
	push _stor       ;storage for substring addresses
	call splitstr    ;return qty substrings in eax

	cmp eax,0
	jz .error

	;save qty substrings found
	mov [_qtystrings],eax
	
	;substring array index
	xor ecx,ecx

.processDWloop:

	;esi=address of dw substring
	call test4imm ;ebx=imm valu
	jnz .error

	mov eax,ebx
	call WriteExeWord	

	call dumpnl

	;set esi to address of next substring
	mov esi,[_stor+ecx*4]
	inc ecx
	cmp ecx,[_qtystrings]
	jb .processDWloop

	jmp .done
	
.error:
	mov dword [_errorcode],ERRORPARSE
.done:
	ret 





;*************************
;          DD
;*************************

;we support comma seperated hex or decimal immediate values
;or code labels for building a jmp/call table

dodd:

	STDCALL str58,dumpstr

	mov esi,[_linebufindex]  ;parent string

	push esi         ;parent string
	push COMMA       ;seperator
	push 20          ;max qty substrings
	push _stor       ;storage for substring addresses
	call splitstr    ;return qty substrings in eax

	cmp eax,0
	jz .error

	;save qty substrings found
	mov [_qtystrings],eax
	
	;substring array index
	xor ecx,ecx

.processDDloop:

	;esi=address of dd substring
	call test4imm ;ebx=imm valu
	jnz .error

	mov eax,ebx
	call WriteExeDword	

	call dumpnl

	;set esi to address of next substring
	mov esi,[_stor+ecx*4]
	inc ecx
	cmp ecx,[_qtystrings]
	jb .processDDloop

	jmp .done

.error:
	mov dword [_errorcode],ERRORPARSE
.done:
	ret 








;************************
;         DQ  
;************************

;for inserting a single qword into your executable
;or multiple comma seperated dq's
;qword double precision floating point is assembled as 8 bytes 
;it must be a base 10 decimal
;it must have a decimal point
;it may have a negative sign prefix -
;scientific notation is not supported (dont use E or 10^exp)
;hex is not supported
;for more info see the IEEE fpu standard
;see also "Simply FPU" on the web
;examples:
;dq 123.456   is assembled as 76 be 9f 1a 2f dd 5e 40
;dq -.00035   is assembled as c7 ba b8 8d 06 f0 36 3f
;dq 5.678     is assembled as 83 c0 ca a1 45 b6 16 40
;dq 30000000. is assembled as 00 00 00 00 38 9c 7c 41

;note as of Aug 2012 the parser still does not like putting
;comments after the float or even spaces so make sure NL 
;immediately follows your float

;Sept 2015
;there is an error in this code:
;dq 57.29577951 is 180/pi
;ttasm: de 5c b2 e0 34 b1 2c 40    which is completely wrong, invalid floating point number
;nasm:  72 23 3d 1a dc a5 4c 40    which is correct
;if we just drop one digit then dq 57.2957795 is assembled as:
;ttasm:  e2 a9 47 1a dc a5 4c 40   close enough
;nasm:   e3 a9 47 1a dc a5 4c 40   correct
;need to further examine this problem
;for now perhaps limit to 6 digits max after the decimal to be safe 
;until we figure this out


dodq:

	STDCALL str136,dumpstr

	mov esi,[_linebufindex]  ;parent string

	push esi         ;parent string
	push COMMA       ;seperator
	push 20          ;max qty substrings
	push _stor       ;storage for substring addresses
	call splitstr    ;return qty substrings in eax

	cmp eax,0
	jz near .error

	;save total qty strings
	mov [_qtystrings],eax

	;save global string index
	mov dword [_dqIndex],0

.nextdqLoop:

	;esi=address of substring
	mov edi,_buf
	xor ebx,ebx
	xor edx,edx
	mov ecx,50   ;max qty char in string
	cld

	;copy the dq string to _buf without the decimal
	;count numdecimals
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
	jz near .error ;reached byte 50 b4 0 terminator
	cmp al,0       ;check for 0 terminator
	jnz .getbyte


	;whats numdecimals ?
	cmp edx,0
	jz near .error   ;didnt find decimal point
	dec edx
	neg edx
	;save the exponent
	mov [_exp],edx


	;convert the significant string to eax
	mov esi,_buf
	call str2eax
	;save the significant
	mov [_sig],eax


	;load the exponent into the fpu
	;for the following comments we will use the 
	;floating point number 5.678
	;sig=5678
	;exp=-3
	fild dword [_exp]    ;st0=-3

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

	fild dword [_sig]
	;st0=5678, st1=0.001, st2=-9.000

	fmul st1
	;st0=5.678, st1=0.001, st2=-9.000


	;finally save the qword to local memory
	fst qword [_dqbuf]


	;change the rounding mode back to nearest
	fldcw word [oldCW]


	;now write our qword to the executable and to the DUMP
	mov edi,[_assypoint]

	;copy the 8 bytes to executable
	mov esi,_dqbuf
	mov ecx,8
	call strncpy

	
	;increment our assembly point by 8 bytes
	add dword [_assypoint],8


	;display our 8 bytes to the DUMP
	STDCALL _dqbuf,CLIPBOARD,8,mem2str
	STDCALL CLIPBOARD,dumpstr

	;free the fpu registers we left full
	;if we dont free up these registers, the dq routine
	;produces incorrect results on the 2nd pass
	ffree st0
	ffree st1
	ffree st2

	;set esi to address of next substring
	mov ecx,[_dqIndex]
	mov esi,[_stor+ecx*4]
	inc ecx
	mov [_dqIndex],ecx
	cmp ecx,[_qtystrings]
	jb .nextdqLoop

	jmp .done

.error:
	mov dword [_errorcode],ERRORPARSE
.done:
	ret



;*************************
;          IMUL
;*************************

;Signed multiply
;we support only single operand 32bitreg * EAX
;e.g.  imul ebx  (=eax*ebx)
;result is stored in edx:eax
doimul:
	STDCALL str107,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	;is the operand 32bit reg ?
	mov esi,_sourcestr
	call test4reg      
	;ebx=regnum
	jz .writecode

	;invalid source operand
	mov dword [_errorcode],3
	jmp .done
	
.writecode:
	mov al,0xf7
	call WriteExeByte
	mov eax,0xe8
	or eax,ebx
	call WriteExeByte

.done:
	ret


;*************************
;          IDIV
;*************************

;Signed divide
;we support only single operand 32bitreg * EAX
;e.g.  idiv ebx  (=edx:eax/ebx)
;quotient is stored in eax, remainder in edx
doidiv:
	STDCALL str127,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	;is the operand 32bit reg ?
	mov esi,_sourcestr
	call test4reg      
	;ebx=regnum
	jz .writecode

	;invalid source operand
	mov dword [_errorcode],3
	jmp .done
	
.writecode:
	mov al,0xf7
	call WriteExeByte
	mov eax,0xf8
	or eax,ebx
	call WriteExeByte

.done:
	ret





;*************************
;          MUL
;*************************

;UNsigned multiply
;we support 2 forms:
; eax * reg32
; eax * dword [memory]
;result is stored in edx:eax

domul:
	STDCALL str116,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	;is the operand reg32 ?
	;**************************
	mov esi,_sourcestr
	call test4reg   ;ebx=regnum
	jnz .doneReg

	mov al,0xf7
	call WriteExeByte
	mov eax,0xe0
	or eax,ebx
	call WriteExeByte
	jmp .done
.doneReg:


	;is the source a memory reference ?
	;***********************************
	mov esi,_sourcestr
	call test4mem
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is in register _rm & ebx=disp8 or disp32
	jnz .doneMem
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx
	
	mov al,0xf7
	call WriteExeByte

	mov ebx,100b    ;reg is hardcoded for this instruction 
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done
.doneMem:
	

.error1:
	mov dword [_errorcode],ERRORINVALSOURCE
.done:
	ret





;*************************
;          DIV
;*************************

;div is edx:eax/operand
;operand may be dword mem or 32bit reg
;byte or word division is currently not supported
;e.g. div ebx          ;edx:eax/ebx
;e.g. div [0x1234]     ;edx:eax/(dword at 0x1234)
;size qualifier b/w/d is currently unsupported

dodiv:
	STDCALL str33,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;div register 
	;********************
	mov esi,_sourcestr
	call test4reg    ;ebx=reg num
	jnz .donereg
	STDCALL str34,dumpstr
	mov al,0xf7
	call WriteExeByte
	mov al,0xf0
	or eax,ebx
	call WriteExeByte
	jmp .done
.donereg:


	;div [memory]  (dword only)
	;****************************
	mov esi,_sourcestr
	call test4mem
	;ecx=1 memory is immed or defined const, ebx=address
	;ecx=2 memory address in reg and ebx=disp8 or disp32
	jnz .donemem
	mov [_sourcevalu],ebx
	mov [_sourceclass],ecx

	STDCALL str35,dumpstr

	mov al,0xf7
	call WriteExeByte

	mov ebx,110b    ;reg is hardcode for this instruction 
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done
.donemem:
	

	;if we got here we are in trouble
	mov dword [_errorcode],2

.done:
	ret





;*************************
;          ADD 
;*************************

AddOperation:
dd addarray2reg, addmem2reg,  addreg2reg 
dd addimm2reg,   addreg2mem,  addimm2mem 
dd addreg2array, addimm2array 




doadd:
	STDCALL str36,dumpstr
	call getoperation
	cmp dword [_errorcode],0
	jnz .done
	call [AddOperation + eax*4]
.done:
	ret




;add register,[memory]
addmem2reg:

	STDCALL str110,dumpstr

	mov al,2
	call ProcessWbitOpcode

	mov ebx,[_destvalu]  ;regnum
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	ret


;add [memory],register
addreg2mem:

	STDCALL str166,dumpstr

	mov al,0
	call ProcessWbitOpcode

	mov ebx,[_sourcevalu] ;regnum
	call ProcessModRegRmByte

	mov ebx,[_destclass]  ;mem class
	mov eax,[_destvalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	ret



;add [memory],imm 
addimm2mem:

	STDCALL str38,dumpstr

	mov al,0x80
	call ProcessWbitOpcode
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,0  
	call ProcessModRegRmByte

	mov ebx,[_destclass]  ;mem class
	mov eax,[_destvalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	mov eax,[_sourcevalu]
	call ProcessImmediateData

.done:
	ret






addimm2reg:
	STDCALL str37,dumpstr

	cmp dword [_wbit],0
	jz .add_byte
	cmp dword [_wbit],2
	jz .add_word
	cmp dword [_wbit],1
	jz .add_dword


.add_byte:
	mov al,0x80
	call WriteExeByte
	mov al,0xc0
	or eax,[_destvalu]  ;regnum
	call WriteExeByte
	mov eax,[_sourcevalu] ;immed
	call WriteExeByte
	jmp .done

.add_word:
	mov al,0x66
	call WriteExeByte
	mov al,0x81
	call WriteExeByte
	mov al,0xc0
	or eax,[_destvalu]  ;regnum
	call WriteExeByte
	mov eax,[_sourcevalu] ;immed
	call WriteExeWord
	jmp .done

.add_dword:
	mov al,0x81
	call WriteExeByte
	mov al,0xc0
	or eax,[_destvalu]     ;reg num
	call WriteExeByte
	mov eax,[_sourcevalu]  ;imm
	call WriteExeDword

.done:
	ret



addreg2reg: 
	STDCALL str91,dumpstr
	
	cmp dword [_wbit],2
	jnz .notword
	mov al,0x66
	call WriteExeByte
	mov dword [_wbit],1
.notword:
	mov eax,[_wbit]
	call WriteExeByte
	mov al,0xc0
	or eax,[_destvalu]
	mov ebx,[_sourcevalu]
	shl ebx,3
	or eax,ebx
	call WriteExeByte

	ret





;ttasm: add ebx,myarray[reg]
;nasm:  add ebx,[myarray+reg*4]
;reg=any 32bit reg as index except esp and ebp
;we support only 32bit reg
;03 1c 8d 34 12 00 00  (e.g. ecx=index reg, myarray=0x1234)
addarray2reg:
	STDCALL str109,dumpstr
	
	;opcode
	mov al,3
	call WriteExeByte

	;mod=00 
	;reg=usual 0,1,2...
	;r/m=100 to indicate SIB byte follows
	mov eax,4
	mov ebx,[_destvalu]
	shl ebx,3
	or eax,ebx
	call WriteExeByte


	;SIB byte = 0x85 + 8*indexregnum  (disp32 follows with no base)
	mov eax,[_sourceclass] ;indexregnum
	shl eax,3
	add eax,0x85
	call WriteExeByte


	;memory address
	mov eax,[_sourcevalu]
	call WriteExeDword
	ret



;ttasm: add array[reg],eax 
;nasm:  add [array+reg*4],eax
;reg is any 32bit reg as index except esp and ebp
addreg2array:
	STDCALL str133,dumpstr
	mov eax,1
	call WriteExeByte
	mov eax,4
	mov ebx,[_sourcevalu] ;reg
	shl ebx,3
	or eax,ebx
	call WriteExeByte    ;modregrm

	;SIB byte = 0x85 + 8*indexregnum  (disp32 follows with no base)
	mov eax,[_destclass] ;indexregnum
	shl eax,3
	add eax,0x85
	call WriteExeByte

	mov eax,[_destvalu]  ;array address
	call WriteExeDword
	ret



;unsupported add operations
addimm2array:
	mov dword [_errorcode],6
	ret







;*************************
;          SUB
;*************************


SubOperation:
dd subarrayFromreg,  submemFromreg,  subregFromreg 
dd subimmFromreg,    subregFrommem,  subimmFrommem 
dd subregFromarray,  subimmFromarray



dosub:
	STDCALL str61,dumpstr
	call getoperation
	cmp dword [_errorcode],0
	jnz .done
	call [SubOperation + eax*4]
.done:
	ret



;sub register,[memory]
submemFromreg:

	STDCALL str139,dumpstr

	mov al,0x2a
	call ProcessWbitOpcode

	mov ebx,[_destvalu]      ;regnum
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	ret


;sub [memory],register
subregFrommem:

	STDCALL str167,dumpstr

	mov al,0x28
	call ProcessWbitOpcode

	mov ebx,[_sourcevalu] ;regnum
	call ProcessModRegRmByte

	mov ebx,[_destclass]  ;mem class
	mov eax,[_destvalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	ret


;sub [memory],imm 
subimmFrommem:

	STDCALL str168,dumpstr

	mov al,0x80
	call ProcessWbitOpcode
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,101b  
	call ProcessModRegRmByte

	mov ebx,[_destclass]  ;mem class
	mov eax,[_destvalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	mov eax,[_sourcevalu]
	call ProcessImmediateData

.done:
	ret








;sub eax,15
subimmFromreg:
	STDCALL str90,dumpstr

	cmp dword [_wbit],0
	jz .byte
	cmp dword [_wbit],1
	jz .dword
	cmp dword [_wbit],2
	jz .word

.byte:
	mov al,0x80
	call WriteExeByte
	mov al,0xe8
	or eax,[_destvalu]
	call WriteExeByte
	mov eax,[_sourcevalu]
	call WriteExeByte
	jmp .done
	
.word:
	mov al,0x66
	call WriteExeByte
	mov al,0x81
	call WriteExeByte
	mov al,0xe8
	or eax,[_destvalu]
	call WriteExeByte
	mov eax,[_sourcevalu]
	call WriteExeWord
	jmp .done

.dword:
	mov al,0x81
	call WriteExeByte
	mov al,0xe8
	or eax,[_destvalu]
	call WriteExeByte
	mov eax,[_sourcevalu]
	call WriteExeDword
	
.done:
	ret




;subtract 32bitreg src from 32bitreg dest
;sub edx,ecx  edx=dest, ecx=src
subregFromreg: 
	STDCALL str108,dumpstr

	call check4destreg32
	jnz .done

	mov al,0x29
	call WriteExeByte
	mov eax,0xc0
	or eax,[_destvalu]
	mov ebx,[_sourcevalu]
	shl ebx,3
	or eax,ebx
	call WriteExeByte

.done:
	ret



;sub dword imm from array
;ttasm: sub myarray[reg],5 d          
;nasm:  sub dword [myarray+reg*4],5 
subimmFromarray:
	mov al,0x81
	call WriteExeByte
	mov al,0x2c
	call WriteExeByte

	;SIB byte = 0x85 + 8*indexregnum  (disp32 follows with no base)
	mov eax,[_destclass] ;indexregnum
	shl eax,3
	add eax,0x85
	call WriteExeByte

	;array address
	mov eax,[_destvalu]
	call WriteExeDword

	;source immediate
	mov eax,[_sourcevalu]
	call WriteExeDword

	ret

	


;unsupported sub operations, tbd
subregFromarray:
subarrayFromreg:
	mov dword [_errorcode],6
	ret


;*************************
;		   ALIGN
;*************************

;insert nops to align data (or code)
;e.g. align 8
	
doalign:
	STDCALL str178,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	mov esi,_sourcestr
	call test4imm     ;ebx=imm value
	jnz .error
	mov eax,[_assypoint]

	xor ecx,ecx
	mov esi,eax
	mov edi,ebx
	neg ebx      
	and eax,ebx  
	sub eax,esi
	setnz cl
	neg ecx
	and edi,ecx
	add eax,edi
	;eax=qty nops to insert
	STDCALL str179,0,dumpeax
	mov ecx,eax
	cmp ecx,0  ;nothing to insert
	jz .done
.align:
	call donop
	call dumpnl
	loop .align

	jmp .done
.error:
	mov dword [_errorcode],7
.done:
	ret


;*************************
;          AND
;*************************

;we only support dest=reg and source=immediate

doand:
	STDCALL str82,dumpstr
	STDCALL _deststr,getopstr
	jc near .done 

	mov esi,_deststr
	call test4reg      ;ebx=regnum  ecx=wbit
	jz near .savedest

	mov dword [_errorcode],2  ;invalid dest
	jmp .done

.savedest:
	mov [_destvalu],ebx
	mov [_wbit],ecx
	
	STDCALL _sourcestr,getopstr
	jc near .done 

	;is source immed ?
	mov esi,_sourcestr
	call test4imm
	jnz .sourcenotimmed
	mov dword [_sourcetype],5   ;source type
	mov [_sourcevalu],ebx       ;immed value
	jmp .writecode
.sourcenotimmed:

	mov dword [_errorcode],3  ;invalid source
	jmp .done


.writecode:

	cmp dword [_wbit],0
	jz .andbyte
	cmp dword [_wbit],1
	jz .anddword
	cmp dword [_wbit],2
	jz .andword


.andbyte:
	mov al,0x80
	call WriteExeByte
	mov al,0xe0
	or eax,[_destvalu]  ;regnum
	call WriteExeByte
	mov al,[_sourcevalu] ;immed
	call WriteExeByte
	jmp .done

.andword:
	mov al,0x66
	call WriteExeByte
	mov al,0x81
	call WriteExeByte
	mov al,0xe0
	or eax,[_destvalu]
	call WriteExeByte
	mov eax,[_sourcevalu]
	call WriteExeWord
	jmp .done
	
.anddword:
	mov al,0x81
	call WriteExeByte
	mov al,0xe0
	or eax,[_destvalu]
	call WriteExeByte
	mov eax,[_sourcevalu]
	call WriteExeDword
	
.done:
	ret








;*************************
;          OR
;*************************

OrOperation:
dd orarray2reg, ormem2reg,  orreg2reg 
dd orimm2reg,   orreg2mem,  orimm2mem 
dd orreg2array, orimm2array



door:
	STDCALL str83,dumpstr
	call getoperation
	cmp dword [_errorcode],0
	jnz .done
	call [OrOperation + eax*4]
.done:
	ret




;or register,[memory]
ormem2reg:

	STDCALL str221,dumpstr

	mov al,0x0a
	call ProcessWbitOpcode

	mov ebx,[_destvalu]      ;regnum
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	ret


;or [memory],register
orreg2mem:

	STDCALL str222,dumpstr

	mov al,0x08
	call ProcessWbitOpcode

	mov ebx,[_sourcevalu] ;regnum
	call ProcessModRegRmByte

	mov ebx,[_destclass]  ;mem class
	mov eax,[_destvalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	ret



;or [memory],imm 
orimm2mem:

	STDCALL str141,dumpstr

	mov al,0x80
	call ProcessWbitOpcode
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,1  
	call ProcessModRegRmByte

	mov ebx,[_destclass]  ;mem class
	mov eax,[_destvalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	mov eax,[_sourcevalu]
	call ProcessImmediateData

.done:
	ret







;or ebx,1
orimm2reg:
	STDCALL str141,dumpstr
	mov al,0x81
	call WriteExeByte
	mov al,0xc8
	or eax,[_destvalu]  ;regnum
	call WriteExeByte
	mov eax,[_sourcevalu]  ;immed
	call WriteExeDword
	ret


;or ebx,ecx
orreg2reg:
	STDCALL str209,dumpstr
	mov al,0x09
	call WriteExeByte
	mov eax,0xc0
	or eax,[_destvalu]     ;reg1
	mov ebx,[_sourcevalu]  ;reg2
	shl ebx,3
	or eax,ebx
	call WriteExeByte
	ret



;unsupported operations
orarray2reg:
orreg2array:
orimm2array:
	mov dword [_errorcode],6
	ret





;*************************
;          XOR
;*************************

XorOperation:
dd xorarray2reg, xormem2reg,  xorreg2reg 
dd xorimm2reg,   xorreg2mem,  xorimm2mem 
dd xorreg2array, xorimm2array


doxor:
	STDCALL str130,dumpstr
	call getoperation
	cmp dword [_errorcode],0
	jnz .done
	call [XorOperation + eax*4]
.done:
	ret


xorreg2reg:

	;we only support xor reg1,reg1
	;this is for zeroing out the register
	mov eax,[_sourcevalu]
	cmp eax,[_destvalu]
	jnz .error

	mov al,0x30
	or eax,[_wbit]
	call WriteExeByte
	mov al,0xc0
	mov ebx,[_destvalu]
	shl ebx,3
	or eax,ebx
	or eax,[_sourcevalu]
	call WriteExeByte
	jmp .done

.error:
	mov dword [_errorcode],2
.done:
	ret


;unsupported operations
xorarray2reg:
xorreg2array:
xorreg2mem:
xormem2reg:
xorimm2array:
xorimm2reg:
xorimm2mem:
	mov dword [_errorcode],6
	ret




;*************************
;          NEG
;*************************
;this is twos compliment: invert all bits and add 1

doneg:
	STDCALL str180,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;neg register
	;*************
	mov esi,_sourcestr
	call test4reg   ;ebx=regnum  ecx=wbit
	jnz .notreg
	cmp ecx,2       ;16bit reg unsupported
	jz near .error
	mov al,0xf6
	or eax,ecx 
	call WriteExeByte
	mov al,0xd8
	or eax,ebx
	call WriteExeByte
	jmp near .done
.notreg:


	;neg [memory] 
	;*********************
	mov esi,_sourcestr
	call test4mem  ;ecx=memory class, ebx=disp or address
	jnz .error
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	mov al,0xf6
	call ProcessWbitOpcode
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,011b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	jmp .done


.error:
	mov dword [_errorcode],3  ;invalid source
.done:
	ret






;*************************
;          NOT
;*************************

;NOT register or NOT memory with b/w/d qualifier
;this is ones compliment: invert all bits

donot:
	STDCALL str117,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;not register
	;*********************
	mov esi,_sourcestr
	call test4reg      
	;ebx=regnum  ecx=[_wbit]
	jnz .doneNotReg

	STDCALL str118,dumpstr

	mov dword [_wbit],ecx
	mov al,0xf6
	call ProcessWbitOpcode

	;modregr/m byte
	mov eax,0xd0
	or eax,ebx   ;regnum
	call WriteExeByte

	jmp .done
.doneNotReg:




	;not [memory] 
	;****************************
	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const, ebx=address
	;ecx=2 memory address in reg _rm and ebx=disp8 or disp32
	jnz .donemem
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	mov al,0xf6
	call ProcessWbitOpcode
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,010b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	jmp .done
.donemem:


.error:
	mov dword [_errorcode],3  ;invalid source
.done:
	ret




;*************************
;          INC
;*************************

doinc:	
	STDCALL str39,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;inc register
	;*******************
	;we use here the std 2 byte encoding
	mov esi,_sourcestr
	call test4reg
	jnz .donereg
	;ebx=regnum, ecx=[_wbit]

	mov dword [_wbit],ecx
	mov al,0xfe
	call ProcessWbitOpcode

	mov eax,0xc0  ;inc
	or eax,ebx   ;regnum
	call WriteExeByte
	jmp .done
.donereg:


	;inc [memory] 
	;*****************************
	mov esi,_sourcestr
	call test4mem
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .notmem
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	STDCALL str40,dumpstr
	
	mov al,0xfe
	call ProcessWbitOpcode

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,0  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done
.notmem:  
	

.error:
	mov dword [_errorcode],ERRORINVALSOURCE 
.done:
	ret
	




;*************************
;          DEC
;*************************

dodec:

	STDCALL str62,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;dec register
	;*******************
	;we use here the std 2 byte encoding
	;there is a shorter 1 byte version
	mov esi,_sourcestr
	call test4reg  ;ebx=regnum, ecx=_wbit
	jnz .donereg

	mov dword [_wbit],ecx
	mov al,0xfe
	call ProcessWbitOpcode

	mov eax,0xc8  
	or eax,ebx   ;regnum
	call WriteExeByte
	jmp .done
.donereg:


	;dec [memory] 
	;*****************************
	mov esi,_sourcestr
	call test4mem
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .notmem
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	STDCALL str63,dumpstr
	
	mov al,0xfe
	call ProcessWbitOpcode

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,001b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done
.notmem:  
	

.error:
	mov dword [_errorcode],ERRORINVALSOURCE 
.done:
	ret
	








;*************************
;          SHL
;*************************

;shl reg32,imm8
;shl reg32,cl
doshl:

	STDCALL str87,dumpstr
	call getoperation
	
	;the destination must be reg32
	cmp dword [_desttype],3  ;reg 
	jnz .errordest

	;test for source imm8
	cmp dword [_sourcetype],6 
	jz .1

	;test for source reg
	cmp dword [_sourcetype],5
	jz .2

	;if we got here we have an incorrect source
	jmp .errorsrc

.1:
	;shl reg32,imm8
	mov al,0xc0
	or eax,[_wbit]
	call WriteExeByte
	mov al,0xe0
	or eax,[_destvalu]  ;regnum
	call WriteExeByte
	mov al,[_sourcevalu] ;numplaces to shift
	call WriteExeByte
	jmp .done

	
.2:
	;shl reg32,cl
	;dest must be reg32, source must be cl  no exceptions !!
	;test for _sourcevalu = 1  which is the cl register
	cmp dword [_sourcevalu],1  
	jnz .errorsrc

	mov al,0xd3  ;this is (d2 || wbit), and dest must be reg32
	call WriteExeByte
	mov al,0xe0
	or eax,[_destvalu]  ;reg32
	call WriteExeByte
	jmp .done

.errordest:
	mov dword [_errorcode],ERRORINVALDEST
	jmp .done
.errorsrc:
	mov dword [_errorcode],ERRORINVALSOURCE
.done:
	ret



;*************************
;          SHR
;*************************

doshr:
	STDCALL str88,dumpstr
		call getoperation
	
	;we only support dest=reg and src=imm
	cmp dword [_desttype],DESTREG  ;reg 
	jnz .errordest
	cmp dword [_sourcetype],SOURCEIMM  ;imm 
	jnz .errorsrc

	mov al,0xc0
	or eax,[_wbit]
	call WriteExeByte
	mov al,0xe8
	or eax,[_destvalu]  ;regnum
	call WriteExeByte
	mov al,[_sourcevalu] ;numplaces to shift
	call WriteExeByte
	jmp .done

.errordest:
	mov dword [_errorcode],2
	jmp .done
.errorsrc:
	mov dword [_errorcode],3
.done:
	ret




;*************************
;          SAR
;*************************

;signed right shift
;note sar != shr

dosar:
	STDCALL str181,dumpstr
	call getoperation
	
	;we only support dest=reg and src=imm
	cmp dword [_desttype],DESTREG 
	jnz .errordest
	cmp dword [_sourcetype],SOURCEIMM
	jnz .errorsrc

	mov al,0xc0
	or eax,[_wbit]
	call WriteExeByte
	mov al,0xf8
	or eax,[_destvalu]  ;regnum
	call WriteExeByte
	mov al,[_sourcevalu] ;numplaces to shift
	call WriteExeByte
	jmp .done

.errordest:
	mov dword [_errorcode],2
	jmp .done
.errorsrc:
	mov dword [_errorcode],3
.done:
	ret



;*************************
;          BSWAP
;*************************

;32bit reg only
;0xaabbccdd becomes 0xddccbbaa
dobswap:
	STDCALL str176,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	mov esi,_sourcestr
	call test4reg    ;ebx=regnum 
	jnz .done

	mov al,0x0f
	call WriteExeByte
	mov al,0xc8
	or eax,ebx
	call WriteExeByte

.done:
	ret




;*************************
;          XCHG
;*************************

;we support only exchange between 32bit registers
doxchg:
	STDCALL str102,dumpstr
	STDCALL _deststr,getopstr
	jc near .done 

	;is dest reg ?
	mov esi,_deststr
	call test4reg      
	;ebx=regnum  ecx=wbit
	jnz .destnotreg
	mov [_destvalu],ebx
	jmp .getsourcereg
.destnotreg:

	mov dword [_errorcode],2 
	jmp .done


.getsourcereg:
	STDCALL _sourcestr,getopstr
	jc near .done 

	;is source reg ?
	mov esi,_sourcestr
	call test4reg      
	;ebx=regnum  ecx=wbit
	jnz .sourcenotreg
	mov [_sourcevalu],ebx
	jmp .writecode
.sourcenotreg:

	mov dword [_errorcode],3 
	jmp .done

.writecode:
	mov al,0x87
	call WriteExeByte
	mov eax,0xc0
	mov ebx,[_destvalu]
	shl ebx,3
	or eax,ebx
	or eax,[_sourcevalu]
	call WriteExeByte

.done:
	ret




;*************************
;          FST
;*************************

;fst copy st0 to fpureg or qword [memory]
;do not use this to copy another fpu reg into st0

dofst:
	STDCALL str158,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fst fpureg
	;********************
	mov esi,_sourcestr
	call test4fpureg  ;ebx=fpureg   
	jnz .notfpureg

	mov al,0xdd
	call WriteExeByte
	
	mov al,0xd0   
	or eax,ebx
	call WriteExeByte

	jmp .done
.notfpureg:



	;fst qword [memory] 
	;****************************
	mov esi,_sourcestr
	call test4mem  ;ecx=memory class, ebx=disp or address
	jnz .error
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	cmp dword [_wbit],3  ;qword only
	jnz .error2

	mov al,0xdd
	call WriteExeByte
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,010b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	jmp .done


.error:
	mov dword [_errorcode],ERRORINVALSOURCE
	jmp .done
.error2:
	mov dword [_errorcode],ERRORBWDQUAL
.done:
	ret





;*************************
;          FSTP
;*************************

;same as fst but pop

dofstp:
	STDCALL str170,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fstp fpureg
	;********************
	mov esi,_sourcestr
	call test4fpureg  ;ebx=fpuregnum 
	jnz .notfpureg

	mov al,0xdd
	call WriteExeByte

	mov al,0xd8   
	or eax,ebx
	call WriteExeByte

	jmp .done
.notfpureg:


	;fstp qword [memory] 
	;****************************
	mov esi,_sourcestr
	call test4mem  ;ecx=memory class, ebx=disp or address
	jnz .error
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	cmp dword [_wbit],3  ;qword only
	jnz .error2

	mov al,0xdd
	call WriteExeByte
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,011b 
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	jmp .done


.error:
	mov dword [_errorcode],ERRORINVALSOURCE
	jmp .done
.error2:
	mov dword [_errorcode],ERRORBWDQUAL
.done:
	ret






;*************************
;          FIST
;*************************

;convert st0 to int and store as dword 
;e.g. fist dword [memory], fist dword apple[reg32]
;16 & 64 bit writes are unsupported

dofist:
	STDCALL str148,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fist dword [memory] 
	;**************************
	mov esi,_sourcestr
	call test4mem  ;ecx=memory class, ebx=disp or address
	jnz .error
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	cmp dword [_wbit],1  ;save to dword only
	jnz .error2
	
	mov al,0xdb
	call WriteExeByte
	
	mov ebx,010b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	jmp .done

.error:
	mov dword [_errorcode],ERRORINVALSOURCE
	jmp .done
.error2:
	mov dword [_errorcode],ERRORBWDQUAL
.done:
	ret




;*************************
;          FISTP
;*************************

;same as FIST except pop fpu stack afterwards

dofistp:
	STDCALL str149,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fistp Myarray[reg32]   (nasm: fistp dword [Myarray+reg32*4]
	;***********************************************************

	mov esi,_sourcestr
	call test4array
	;returns ebx=memory address, ecx=regnumber
	jnz .sourcenotarray

	mov al,0xdb
	call WriteExeByte

	;modregr/m: mod=00, reg=011 hardcoded for fistp, r/m=100 SIB byte to follow
	mov al,0x1c
	call WriteExeByte

	;SIB byte = 0x85 + 8*indexregnum  (disp32 follows with no base)
	mov eax,ecx ;indexregnum
	shl eax,3
	add eax,0x85
	call WriteExeByte

	;memory address
	mov eax,ebx    
	call WriteExeDword
	jmp .done
.sourcenotarray:




	;fistp dword [memory] 
	;**************************
	mov esi,_sourcestr
	call test4mem  ;ecx=memory class, ebx=disp or address
	jnz .error1
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	cmp dword [_wbit],1  ;save to dword only
	jnz .error2
	
	mov al,0xdb
	call WriteExeByte
	
	mov ebx,011b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	jmp .done

.error1:
	mov dword [_errorcode],ERRORINVALSOURCE
	jmp .done
.error2:
	mov dword [_errorcode],ERRORBWDQUAL
.done:
	ret









;*************************
;          FILD
;*************************

;load dword integer to top of fpu stack (st0)
;fild [memory] d

dofild:
	STDCALL str142,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fild dword [memory] 
	;*****************
	mov esi,_sourcestr
	call test4mem  ;ecx=memory class, ebx=disp or address
	jnz .error1
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	cmp dword [_wbit],1
	jnz .error2
	
	mov al,0xdb
	call WriteExeByte
	
	mov ebx,0  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	jmp .done


.error1:
	mov dword [_errorcode],ERRORINVALDEST
.error2:
	mov dword [_errorcode],ERRORBWDQUAL
.done:
	ret






;*************************
;          FLD
;*************************

;load qword double precision to top of fpu stack (st0)
;fld qword [memory] 
;fld fpureg
;this rotates the barrel so st7 becomes st0 then loads
;if st7 is not empty/ffree then a stack fault occurs
;e.g. fld st3 causes the same value to be found in st0 and st4

dofld:

	STDCALL str143,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fld fpureg 
	;************
	mov esi,_sourcestr
	call test4fpureg   ;returns ebx=fpuregnum 
	jnz .notfpureg
	mov al,0xd9
	call WriteExeByte
	mov al,0xc0
	or eax,ebx
	call WriteExeByte
	jmp .done
.notfpureg:


	;fld qword [memory] 
	;*****************
	mov esi,_sourcestr
	call test4mem  ;ecx=memory class, ebx=disp or address
	jnz .error1
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	cmp dword [_wbit],3  ;qword only
	jnz .error2
	
	mov al,0xdd
	call WriteExeByte
	
	mov ebx,0  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	
	jmp .done


.error1:
	mov dword [_errorcode],ERRORINVALDEST
	jmp .done
.error2:
	mov dword [_errorcode],ERRORBWDQUAL
.done:
	ret









;*************************
;   FLD1, FLDZ, FLDPI
;*************************

;load floating point constants

;load 1.000 to st0
dofld1:
	STDCALL str144,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xe8
	call WriteExeByte
	ret

;load 0.000 to st0
dofldz:
	STDCALL str145,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xee
	call WriteExeByte
	ret

;load PI to st0
dofldpi:
	STDCALL str146,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xeb
	call WriteExeByte
	ret







;*************************
;          FIADD
;*************************

;fiadd dword [memory] 
;st0 = st0 + DwordInt [memory]

dofiadd:

	STDCALL str160,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .error1
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	cmp dword [_wbit],1  ;dword only
	jnz .error2

	mov al,0xda
	call WriteExeByte

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,0  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done

.error1:
	mov dword [_errorcode],ERRORINVALSOURCE
	jmp .done
.error2:
	mov dword [_errorcode],ERRORBWDQUAL
.done:
	ret







;*************************
;          FISUB
;*************************

;fisub dword [memory] 
;st0=st0-[dword memory]

dofisub:

	STDCALL str161,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .error
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	mov al,0xda
	call WriteExeByte

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,100b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done

.error:
	mov dword [_errorcode],3
.done:
	ret




;*************************
;          FISUBR
;*************************

;fisubr dword [memory] 
;st0=[dword memory]-st0

dofisubr:
	STDCALL str162,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .error
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	mov al,0xda
	call WriteExeByte

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,101b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done

.error:
	mov dword [_errorcode],3
.done:
	ret










;*************************
;          FIMUL
;*************************

;multiply st0 by dword integer in memory
;fimul dword [memory] 
;st0=st0*[memory]

dofimul:
	STDCALL str163,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .error1
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	cmp dword [_wbit],1  ;dword only
	jnz .error2

	mov al,0xda
	call WriteExeByte

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,001b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done

.error1:
	mov dword [_errorcode],3
.error2:
	mov dword [_errorcode],ERRORBWDQUAL
.done:
	ret








;*************************
;          FIDIV
;*************************

;fidiv dword [memory] 
;st0 = st0 / [memory]

dofidiv:
	STDCALL str164,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .error
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	mov al,0xda
	call WriteExeByte

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,110b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done

.error:
	mov dword [_errorcode],3
.done:
	ret




;*************************
;          FIDIVR
;*************************

;fidivr dword [memory] 
;st0 = [memory] / st0

dofidivr:
	STDCALL str165,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .error
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	mov al,0xda
	call WriteExeByte

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,111b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done

.error:
	mov dword [_errorcode],3
.done:
	ret










;*************************
;          FADD
;*************************

;st0=st0+sti, fadd sti
;st0=st0+qword [memory], fadd qword [memory] 
;FADD can not be used to add fpu registers to memory

dofadd:
	STDCALL str159,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	;fadd sti  (st0=st0+sti)
	;************************
	mov esi,_sourcestr
	call test4fpureg    ;ebx=fpuregnum 
	jnz .notreg
	mov al,0xd8
	call WriteExeByte
	mov al,0xc0
	or eax,ebx
	call WriteExeByte
	jmp .done
.notreg:


	;fadd qword [memory]    (st0=st0+[memory])
	;******************************************
	mov esi,_sourcestr
	call test4mem   
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .error
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	mov al,0xdc
	call WriteExeByte

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,0  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done

.error:
	mov dword [_errorcode],3
.done:
	ret








;*************************
;          FSUB
;*************************

;1) st0=st0-sti,    e.g. fsub st1 
;2) st0=st0-[qword] e.g. fsub [apple] q
;the qword is a double precision floating point number stored in memory

dofsub:
	STDCALL str172,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fsub  sti  (st0=st0-sti)
	;***************************
	mov esi,_sourcestr
	call test4fpureg  ;ebx=fpuregnum 
	jnz .notreg

	mov al,0xd8
	call WriteExeByte

	mov eax,0xe0  
	or eax,ebx
	call WriteExeByte

	jmp .done
.notreg:


	;fsub  qword [memory]   (st0=st0-[memory])
	;**************************************
	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .notmem
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	mov al,0xdc
	call WriteExeByte

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,100b 
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	jmp .done
.notmem:


.error:
	mov dword [_errorcode],ERRORINVALSOURCE
.done:
	ret






;*************************
;          FSUBR
;*************************

;1) st0=sti-st0,    e.g. fsubr st1 
;2) st0=[apple]-st0 e.g. fsubr [apple] q
;the qword is a double precision floating point number stored in memory

dofsubr:
	STDCALL str171,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fsubr sti  (st0=sti-st0)
	;***************************
	mov esi,_sourcestr
	call test4fpureg  ;ebx=fpuregnum 
	jnz .notreg

	mov al,0xd8
	call WriteExeByte

	mov eax,0xe8  
	or eax,ebx
	call WriteExeByte

	jmp .done
.notreg:


	;fsubr qword [memory]   (st0=[memory]-st0)
	;**************************************
	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .notmem
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	mov al,0xdc
	call WriteExeByte

	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,101b 
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	jmp .done
.notmem:


.error:
	mov dword [_errorcode],3
.done:
	ret








;*************************
;          FMUL
;*************************

;st0=st0*sti       fmul sti
;st0=st0*[qword]   fmul [apple] q
;result always ends in st0 and other fpu regs unchanged
;to square the value in st0 use "fmul st0"

dofmul:
	STDCALL str153,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	;fmul sti
	;st0=st0*sti
	;*****************
	mov esi,_sourcestr
	call test4fpureg  ;ebx=fpuregnum 
	jnz .notreg
	mov al,0xd8
	call WriteExeByte
	mov al,0xc8
	or eax,ebx
	call WriteExeByte
	jmp .done
.notreg:


	;fmul qword [memory] 
	;multiply st0 by qword in memory and store in st0
	;*********************
.tryqword:
	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .error
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	mov al,0xdc
	call WriteExeByte
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,1  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done

.error:
	mov dword [_errorcode],3
.done:
	ret




;*************************
;          FMULP
;*************************

;multiply st0*st(i) and store in st(i) then pop fpu reg
;single operand must be a fpu reg not st0
;for result to end in st0 must use "fmulp st1"
;e.g. fmulp st2
dofmulp:
	STDCALL str147,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fmul sti
	;sti=st0*sti
	;**************
	mov esi,_sourcestr
	call test4fpureg   ;ebx=fpuregnum 
	jnz .done

	mov al,0xde
	call WriteExeByte
	mov al,0xc8
	or eax,ebx
	call WriteExeByte

.done:
	ret




;*************************
;          FDIV
;*************************

;st0=st0/sti       fdiv sti
;st0=st0/[qword]   fdiv [apple] q
;result always ends in st0 and other fpu regs unchanged
;fdiv st0 results in st0=1.000

dofdiv:
	STDCALL str155,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fdiv sti   (st0=st0/sti)
	;**************************
	mov esi,_sourcestr
	call test4fpureg   ;ebx=fpuregnum 
	jnz .notreg
	mov al,0xd8
	call WriteExeByte
	mov al,0xf0
	or eax,ebx
	call WriteExeByte
	jmp .done
.notreg:



	;fdiv qword [memory]   (st0=st0/[memory])
	;**************************************
	mov esi,_sourcestr
	call test4mem  
	;ecx=1 memory is immed or defined const & ebx=address
	;ecx=2 memory is address in reg _rm and ebx=disp8 or disp32
	jnz .notmem
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	cmp dword [_wbit],3  ;qword only
	jnz .error2 

	mov al,0xdc
	call WriteExeByte
	
	;no register involved, the 3 reg bits are hardcoded here
	mov ebx,110b  
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp
	jmp .done
.notmem:


.error:
	mov dword [_errorcode],ERRORINVALSOURCE
	jmp .done
.error2:
	mov dword [_errorcode],ERRORBWDQUAL
.done:
	ret






;*************************
;          FDIVR
;*************************

;reciprocal of fdiv
;st0=sti/st0
dofdivr:
	STDCALL str156,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 


	;fdiv sti   (st0=sti/st0)
	;**************************
	mov esi,_sourcestr
	call test4fpureg   ;ebx=fpuregnum 
	jnz .done

	mov al,0xd8
	call WriteExeByte
	mov al,0xf8
	or eax,ebx
	call WriteExeByte

.done:
	ret



;*************************
;          FDIVP
;*************************

;sti=sti/st0 then pop fpu
dofdivp:
	STDCALL str157,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	;fdiv sti
	;sti=sti/st0
	;*******************
	mov esi,_sourcestr
	call test4fpureg   ;ebx=fpuregnum 
	jnz .done

	mov al,0xde
	call WriteExeByte
	mov al,0xf8
	or eax,ebx
	call WriteExeByte

.done:
	ret




;*************************
;          FSIN
;*************************

;computes sin of st0 in radians
;and stores in st0
dofsin:
	STDCALL str150,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xfe
	call WriteExeByte
	ret


;*************************
;          FCOS
;*************************

;computes cos of st0 in radians
;and stores in st0
dofcos:
	STDCALL str169,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xff
	call WriteExeByte
	ret


;*************************
;          FSINCOS
;*************************

;computes sin(st0) and cos(st0) in radians
;results in st0=cos and st1=sin

dofsincos:

	STDCALL str177,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xfb
	call WriteExeByte
	ret





;*************************
;          FPATAN
;*************************

;computes arc tangent of (st1/st0)
;put dy=st1, dx=st0
;result is angle in radians in st1 then
;pops fpu reg so result is in st0

dofpatan:

	STDCALL str223,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xf3
	call WriteExeByte
	ret




;*************************
;          FSQRT
;*************************

;computes st0=sqrt(st0) 
;no args reqd

dofsqrt:

	STDCALL str119,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xfa
	call WriteExeByte
	ret




;*************************
;          FABS
;*************************

;st0=|st0| 
;no args and no other fpu reg allowed

dofabs:

	STDCALL str212,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xe1
	call WriteExeByte
	ret





;*************************
;          FCHS
;*************************

;change sign of st0 (negate)
;no args and no other fpu reg allowed

dofchs:

	STDCALL str187,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xe0
	call WriteExeByte
	ret


	
;*************************
;          FXCH
;*************************

;exchange st0 with another fpureg
;we dont support FXCH alone which swaps st0 and st1
;you have to type "fxch st1" to swap st0 and st1

dofxch:

	STDCALL str151,dumpstr
	STDCALL _sourcestr,getopstr
	jc near .done 

	;fxch sti
	;st0=sti, sti=st0
	;**********************
	mov esi,_sourcestr
	call test4fpureg   ;ebx=fpuregnum 
	jnz .error

	mov al,0xd9
	call WriteExeByte
	mov al,0xc8
	or eax,ebx
	call WriteExeByte
	jmp .done

.error:
	mov dword [_errorcode],7  ;missing op string
.done:
	ret



	
;*************************
;          FRNDINT
;*************************

;round st0 to integer according to current rounding mode
dofrndint:
	STDCALL str175,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xfc
	call WriteExeByte
	ret




	
;*************************
;      FFREE/FFREEP
;*************************

;free fpu reg
;e.g. ffree st1
;you may not fld/fild if all the fpu regs are full
;so pop/free the unused
;according to Simply FPU:
;"Although any of the 8 data registers can be tagged as free with this instruction, 
;the only one which can be of any immediate value is the ST(7) register 
;when all registers are in use and another value must be loaded to the FPU. 
;If the data in that ST(7) is still valuable, other instructions should be used 
;to save it before emptying that register."

doffree:

	STDCALL str154,dumpstr
	STDCALL _sourcestr,getopstr
	jc .error 

	;ffree sti
	;***************
	mov esi,_sourcestr
	call test4fpureg   ;ebx=fpuregnum 
	jnz .error

	mov al,0xdd
	call WriteExeByte
	mov al,0xc0
	or eax,ebx
	call WriteExeByte

	jmp .done

.error:
	mov dword [_errorcode],ERRORPARSE
.done:
	ret


;free fpureg then pop 
doffreep:

	STDCALL str195,dumpstr
	STDCALL _sourcestr,getopstr
	jc .error 

	;ffreep sti
	;***************
	mov esi,_sourcestr
	call test4fpureg   ;ebx=fpuregnum 
	jnz .error

	mov al,0xdf
	call WriteExeByte
	mov al,0xc0
	or eax,ebx
	call WriteExeByte

	jmp .done

.error:
	mov dword [_errorcode],ERRORPARSE
.done:
	ret



;*************************
;    FINCSTP/FDECSTP
;*************************

;inc/dec the fpu stack pointer

dofpuinc:
	STDCALL str214,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xf7
	call WriteExeByte
	ret

dofpudec:
	STDCALL str215,dumpstr
	mov al,0xd9
	call WriteExeByte
	mov al,0xf6
	call WriteExeByte
	ret


;*************************
;          FCLEX
;*************************

;clear any floating point exceptions 
;bits0:6 of the FPU status word are persistant
;until you call this

dofclex:
	STDCALL str188,dumpstr
	mov al,0x9b
	call WriteExeByte
	mov al,0xdb
	call WriteExeByte
	mov al,0xe2
	call WriteExeByte
	ret



;*************************
;          FCOMI/FCOMIP
;*************************

;compare st0 with another fpu reg and set CPU flags directly
;assuming we are comparing st0 and st1:
;if st0 > sti then CF is not set
;if st0 < sti then CF is set
;if st0 == sti then ZF is set
;fcomip pops fpu afterwards

dofcomi:   

	STDCALL str196,dumpstr
	STDCALL _sourcestr,getopstr
	jc .error 

	;fcomi sti
	;****************
	mov esi,_sourcestr
	call test4fpureg  ;ebx=fpuregnum 
	jnz .error

	mov al,0xdb
	call WriteExeByte
	mov al,0xf0 
	or al,bl
	call WriteExeByte
	jmp .done

.error:
	mov dword [_errorcode],7
.done:
	ret


dofcomip:

	STDCALL str205,dumpstr
	STDCALL _sourcestr,getopstr
	jc .done 

	;fcomip sti
	;***********
	mov esi,_sourcestr
	call test4fpureg  ;ebx=fpuregnum 
	jnz .done

	mov al,0xdf
	call WriteExeByte
	mov al,0xf0
	or al,bl
	call WriteExeByte

.done:
	ret





;****************************************************************
;                  TLIB function calls 
;****************************************************************

;stdcall has been removed from ttasm August 2013
;user code can no longer call tlib functions directly
;we now have a protected mode interface
;and we pass args to the kernel thru registers using sysenter
;see tatOS/tlibentry.s for the kernel functions userland may call
;below we have some sudo "c" style function call syntax 
;for kernel functions that have several arguments


;*************************
;          PUTMARKER
;*************************

;putmarker MarkerStyle,color,xloc,yloc
;equivalent code:
;mov eax,50
;mov ebx,MarkerStyle
;mov ecx,color
;mov edx,xloc
;mov esi,yloc
;sysenter

doputmarker:
	STDCALL str261,dumpstr
	mov eax,50
	call ProcessSysEnterCsv
	ret



;*************************
;          PUTST0
;*************************

;putst0 fontID,xloc,yloc,color,NumDecPlaces
;equivalent code:
;mov eax,32
;mov ebx,fontID
;mov ecx,xloc
;mov edx,yloc
;mov esi,color  0000ttbb
;mov edi,NumDecimalPlaces
;sysenter

doputst0:
	STDCALL str257,dumpstr
	mov eax,32
	call ProcessSysEnterCsv
	ret



;*************************
;          PUTC
;*************************

;putc fontID,AsciiChar,color,xloc,yloc 
;equivalent code:
;mov eax,31
;mov ebx,fontID
;mov ecx,AsciiChar
;mov edx,color
;mov esi,xloc
;mov edi,yloc
;sysenter

doputc:
	STDCALL str256,dumpstr
	mov eax,31
	call ProcessSysEnterCsv
	ret


;*************************
;          POLYLINE
;*************************

;polyline OpenClose,linetype,AddressPointsArray,QtyPoints,color
;equivalent code:
;mov eax,29
;mov ebx,1=close 0=open
;mov ecx,linetype
;mov edx,AddressPointsArray
;mov esi,QtyPoints
;mov edi,color
;sysenter

dopolyline:
	STDCALL str254,dumpstr
	mov eax,29
	call ProcessSysEnterCsv
	ret


;*************************
;          LINE
;*************************

;line linetype,x1,y1,x2,y2,color
;equivalent code:
;mov eax,30
;mov ebx,linetype
;mov ecx,x1
;mov edx,y1
;mov esi,x2
;mov edi,y2
;mov ebp,color
;sysenter

doline:
	STDCALL str255,dumpstr
	mov eax,30
	call ProcessSysEnterCsv
	ret



;*************************
;          EBXSTR
;*************************

;ebxstr Value2Convert,StringTag,DestBuffer
;equivalent code:
;mov eax,21
;mov ebx,Value2Convert
;mov ecx,AddressStringTag
;mov edx,AddressDestBuffer
;sysenter


doebxstr:
	STDCALL str253,dumpstr
	mov eax,21
	call ProcessSysEnterCsv
	ret


;*************************
;          STRCPY2
;*************************

;strcpy2 Src,Dest
;equivalent code:
;mov eax,20
;mov ebx,AddressSrc
;mov ecx,AddressDes
;sysenter

dostrcpy2:
	STDCALL str252,dumpstr
	mov eax,20
	call ProcessSysEnterCsv
	ret


;*************************
;          SETPIXEL
;*************************

;setpixel X,Y,color
;equivalent code:
;mov eax,16
;mov ebx,X
;mov ecx,Y
;mov edx,color
;sysenter

dosetpixel:
	STDCALL str239,dumpstr
	mov eax,16
	call ProcessSysEnterCsv
	ret


;*************************
;          POW
;*************************

;pow addressX,addressY,addressResult
;equivalent code:
;mov eax,15
;mov ebx,addressX
;mov ecx,addressY
;mov edx,addressResult
;sysenter

dopow:
	STDCALL str238,dumpstr
	mov eax,15
	call ProcessSysEnterCsv
	ret




;*************************
;          BACKBUFCLEAR
;*************************

;backbufclear
;equivalent code:
;mov eax,0
;sysenter

dobackbufclear:
	STDCALL str240,dumpstr
	mov al,0xb8         ;mov eax
	call WriteExeByte
	mov eax,0           ;dword 2
	call WriteExeDword
	call dosysenter
	ret



;*************************
;          SWAPBUF
;*************************

;swapbuf
;equivalent code:
;mov eax,2
;sysenter

doswapbuf:
	STDCALL str228,dumpstr
	mov al,0xb8         ;mov eax
	call WriteExeByte
	mov eax,2           ;dword 2
	call WriteExeDword
	call dosysenter
	ret


;*************************
;          EXIT 
;*************************

;call exit at the end of your app to return to tedit
;if you do "ret" instead of exit your app will segfault

;exit 
;equivalent code:
;mov eax,4
;sysenter

doexit:
	STDCALL str229,dumpstr
	mov al,0xb8         ;mov eax
	call WriteExeByte
	mov eax,4           ;dword 4
	call WriteExeDword
	call dumpnl
	call dosysenter
	;if you forget to code an exit, we will warn you !!!
	;if you do mov eax,4 ; sysenter you will not get a warning :(
	mov dword [_haveExit],1
	ret

;*************************
;          GETC
;*************************

;getc
;equivalent code:
;mov eax,5
;sysenter

dogetc:
	STDCALL str230,dumpstr
	mov al,0xb8         ;mov eax
	call WriteExeByte
	mov eax,5           ;dword 5
	call WriteExeDword
	call dosysenter
	ret


;*************************
;          CHECKC
;*************************

;checkc
;equivalent code:
;mov eax,12
;sysenter

docheckc:
	STDCALL str232,dumpstr
	mov al,0xb8         ;mov eax
	call WriteExeByte
	mov eax,12           ;dword 
	call WriteExeDword
	call dosysenter
	ret


;*************************
;          RAND
;*************************

;rand Seed
;equivalent code:
;mov eax,8
;mov ebx,Seed
;sysenter
;use Seed=0 to return a random number
;use a nonzero Seed to assign a new Seed

dorand:
	STDCALL str231,dumpstr
	mov eax,8
	call ProcessSysEnterCsv
	ret


;*************************
;          CIRCLE
;*************************

;circle Filled,Xcenter,Ycenter,radius,color
;equivalent code:
;mov eax,40
;mov ebx,Filled
;mov ecx,Xcenter
;mov edx,Ycenter
;mov esi,radius
;mov edi,color
;sysenter

docircle:
	STDCALL str259,dumpstr
	mov eax,40
	call ProcessSysEnterCsv
	ret




;*************************
;          RECTANGLE
;*************************

;rectangle x,y,w,h,color
;equivalent code:
;mov eax,39
;mov ebx,x
;mov ecx,y
;mov edx,w
;mov esi,h
;mov edi,color
;sysenter

dorectangle:
	STDCALL str258,dumpstr
	mov eax,39
	call ProcessSysEnterCsv
	ret




;*************************
;          FILLRECT
;*************************

;fillrect x,y,w,h,color
;equivalent code:
;mov eax,6
;mov ebx,x
;mov ecx,y
;mov edx,w
;mov esi,h
;mov edi,color
;sysenter

dofillrect:
	STDCALL str233,dumpstr
	mov eax,6
	call ProcessSysEnterCsv
	ret



;*************************
;          CLIPRECT
;*************************

;cliprect x,y,w,h
;equivalent code:
;mov eax,11
;mov ebx,x
;mov ecx,y
;mov edx,w
;mov esi,h
;sysenter

docliprect:
	STDCALL str236,dumpstr
	mov eax,11
	call ProcessSysEnterCsv
	ret



;*************************
;          PUTS
;*************************

;puts fontID,x,y,String,color
;equivalent code:
;mov eax,13
;mov ebx,fontID
;mov ecx,x
;mov edx,y
;mov esi,String
;mov edi,color 0000ttbb
;sysenter

doputs:
	STDCALL str237,dumpstr
	mov eax,13
	call ProcessSysEnterCsv
	ret


;*************************
;          PUTSHERSHEY
;*************************

;putshershey Xcenter,Ycenter,String,color,FontType,ScaleFactor
;equivalent code:
;mov eax,48
;mov ebx,X center of first char
;mov ecx,Y center of first char
;mov edx,Address of 0 terminated ascii string
;mov esi,color
;mov edi,FontType 0=HERSHEYROMAN, 1=HERSHEYGOTHIC
;mov ebp,scale factor (integer >=1)
;sysenter

doputshershey:
	STDCALL str260,dumpstr
	mov eax,48
	call ProcessSysEnterCsv
	ret





;*************************
;          PUTSML
;*************************

;putsml fontID,x,y,String,color
;equivalent code:
;mov eax,7
;mov ebx,fontID
;mov ecx,x
;mov edx,y
;mov esi,String
;mov edi,color 0000ttbb
;sysenter

doputsml:
	STDCALL str235,dumpstr
	mov eax,7
	call ProcessSysEnterCsv
	ret


;*************************
;          PUTEBX
;*************************

;putebx ebx,x,y,colors,RegisterSize
;equivalent code:
;mov eax,14
;mov ebx,value to be displayed as hex 
;mov ecx,x
;mov edx,y
;mov esi,colors 0000ttbb
;mov edi,size 0=ebx 1=bx 2=bl
;sysenter

doputebx:
	STDCALL str241,dumpstr
	mov eax,14
	call ProcessSysEnterCsv
	ret


;*************************
;          PUTEBXDEC
;*************************

;putebxdec ebx,x,y,colors,SignedOrUnsigned
;equivalent code:
;mov eax,67
;mov ebx,value to be displayed as decimal 
;mov ecx,x
;mov edx,y
;mov esi,colors 0000ttbb
;mov edi 0=unsigned dword, 1=signed dword       
;sysenter

doputebxdec:
	STDCALL str264,dumpstr
	mov eax,67
	call ProcessSysEnterCsv
	ret



;*************************
;          PUTTRANSBITS
;*************************

;puttransbits x,y,width,height,AddressOfBits
;equivalent code:
;mov eax,65
;mov ebx,x
;mov ecx,y
;mov edx,width
;mov esi,height
;mov edi,AddressOfBits
;sysenter

doputtransbits:
	STDCALL str263,dumpstr
	mov eax,65
	call ProcessSysEnterCsv
	ret




;*************************
;          DUMPSTR
;*************************

;dumpstr StringAddress
;equivalent code:
;mov eax,1
;mov ebx,StringAddress
;sysenter

dodumpstr:
	STDCALL str242,dumpstr
	mov eax,1
	call ProcessSysEnterCsv
	ret



;*************************
;          DUMPEBX
;*************************

;dumpebx ebx,AddressStringTag
;equivalent code:
;mov eax,9
;mov ebx,ValueToDump
;mov ecx,AddressStringTag
;sysenter

dodumpebx:
	STDCALL str243,dumpstr
	mov eax,9
	call ProcessSysEnterCsv
	ret



;*************************
;          DUMPREG
;*************************

;dumpreg
;equivalent code:
;mov eax,3
;sysenter

dodumpreg:
	STDCALL str291,dumpstr
	mov al,0xb8         ;mov eax
	call WriteExeByte
	mov eax,3           ;dword 3
	call WriteExeDword
	call dosysenter
	ret







;*************************
;          SETYORIENT
;*************************

;setyorient YorientValue 
;equivalent code:
;mov eax,28
;mov ebx,YorientValue  (1 or -1)
;sysenter

dosetyorient:
	STDCALL str262,dumpstr
	mov eax,28
	call ProcessSysEnterCsv
	ret





;*************************
;          SYSENTER
;*************************

;this is your main function to call kernel code
;all tlib functions are accessible to user apps via sysenter
;see tlibEntryProc.s for more information
;this is actually a combo instruction
;we encode 3 instructions here:
;[1] save userland EIP return address to 0x2000000
;[2] save userland ESP stack pointer  to 0x2000004
;[3] sysenter

dosysenter:

	STDCALL str226,dumpstr

	;save userland ESP stack pointer
	;mov [0x2000004],esp  89 25 04 00 00 02
	mov al,0x89
	call WriteExeByte
	mov al,0x25
	call WriteExeByte
	mov eax,0x2000004
	call WriteExeDword

	;save userland EIP return address
	;mov dword [0x2000000],[_assypoint+6]  c7 05 00 00 00 02 UserLandAddress
	;[0x2000000] is the global address to save userland EIP return address
	;[_assypoint+6] is the user land address where the kernel returns to 
	;after sysexit
	;we want to jump back into user land code immediately after sysenter
	;the reason for all this is as the Intel manual states for sysenter: 
	;"the processor does not save a return EIP..."
	mov al,0xc7
	call WriteExeByte
	mov al,0x05
	call WriteExeByte
	mov eax,0x2000000    
	call WriteExeDword
	mov eax,[_assypoint]  
	;this +6 value is important tom
	;if you get this wrong the computer will triple fault
	add eax,6    ;eax=address of userland code after sysenter
	call WriteExeDword

	;sysenter
	mov al,0x0f
	call WriteExeByte
	mov al,0x34
	call WriteExeByte

	ret	




;***************************************************************
;       END OF TTASM CODE GENERATOR
;       supporting functions are below
;***************************************************************








;********************************************************************
;PROCESSWBITOPCODE

;this function is used with operations that require memory access

;this function writes an 0x66 prefix to exe
;for pmode WORD memory access if required

;it also 'or's the _wbit with the wbit opcode
;and writes the wbit opcode byte to exe 

;note none of the fpu instructions use the wbit

;this function requires global [_wbit] be known  

;input
;al=opcode byte 
;global dword [_wbit] is set to 0,1 or 2
;   the opcode byte passed to this function should have bit0 set to 0
;   the wbit opcode is typically the first byte of an instruction
;   not counting any prefix bytes
;   some instructions do not use a wbit
;   so dont use this function on those instructions
;return:none
;********************************************************************

ProcessWbitOpcode:

%if VERBOSEDUMP
	STDCALL str71,dumpstr
%endif

	pushad

	cmp dword [_wbit],0
	jz .doByte
	cmp dword [_wbit],1
	jz .doDword
	cmp dword [_wbit],2
	jz .doWord

	;if we got here we have invalid _wbit  
	mov dword [_errorcode],ERRORWBIT
	jmp .done


.doWord:
 	;intel wbit for word access in pmode is 1
	mov ebx,1  

	;word access requires 0x66 prefix in pmode
	STDCALL str216,dumpstr
	push eax ;preserve value passed to function
	mov al,0x66
	call WriteExeByte
	pop eax
	jmp .writeWbitOpcode

.doByte:
	;intel wbit for byte access in pmode is 0
	mov ebx,0
	jmp .writeWbitOpcode

.doDword:
	;intel wbit for dword access in pmode is 1	
	mov ebx,1

.writeWbitOpcode:
	;OpcodeByte | wbit
	or eax,ebx
	call WriteExeByte

.done:
	popad
	ret





;*********************************************************************
;PROCESSMODREGRMBYTE

;this function builds and writes the modregr/m byte to exe
;this function requires a previous call to test4mem

;input
;global dword [_mod] is defined by a call to test4mem
;global dword [_rm ] is defined by a call to test4mem
;ebx=reg value (bits5:3 of modregr/m)
;    reg is usually _sourcevalu or _destvalue from test4reg
;    if a register is involved then reg num is one of the following:
;    0=eax, 1=ecx, 2=edx, 3=ebx, 4=esp, 5=ebp, 6=esi, 7=edi
;    if the source operand is immediate data these 3 bits are hardcoded
;    to a unique instruction dependent value
;    see the intel/amd manuals 
;return: none
;*********************************************************************

ProcessModRegRmByte:

%if VERBOSEDUMP
	;will messup the display of exe bytes
	call dumpnl
	STDCALL str19,dumpstr
%endif

	pushad

	;form the modregr/m byte
	mov eax,[_mod]
	shl eax,6
	shl ebx,3  ;reg
	or eax,ebx
	or eax,[_rm]   ; _rm is a reg32 involved in memory addressing
	call WriteExeByte

	popad

	ret






;*******************************************************************
;PROCESSMEMORYANDDISP

;this is a dual purpose function to handle the writting of 
;a memory address or displacement to the exe

;for direct memory access like [x01234] or [GETC]
;write the dword imediate memory address to exe 

;for indirect memory access like [reg32+disp8] or [reg32+disp32]
;write either nothing or disp8 or disp32 to exe depending on the value of _mod 

;this function is usually called after
;prefix, opcode and SIB bytes are processed

;this function requires a previous call to test4mem

;input:
;ebx=memory class 
;    1=memory is immediate value or defined constant
;    2=memory is indirect in a register
;eax=displacment or memory address
;return:none
;*******************************************************************

ProcessMemoryAndDisp:

%if VERBOSEDUMP
	;this dumpstr will messup the display of the exe bytes
	call dumpnl
	STDCALL str20,dumpstr
%endif


	;add a link for every instance/usage of an extern symbol
	;test4imm determines if we have an extern symbol
	cmp dword [_onpass2],1  ;are we on pass=2 ?
	jz .1  
	cmp dword [_havextern],1
	jnz .1

	call dumpnl
	STDCALL str285,dumpstr
	push dword _externbuffer
	push dword [_assypoint] 
	call extern_add_link
	jz .error


.1:
	cmp ebx,1
	jz .doImmediateMemory
	cmp ebx,2
	jz .doIndirectMemory

	;display error message and stop ttasm 
	mov dword [_errorcode],ERROROUTOFRANGE  ;value out of range

.doImmediateMemory:
	call WriteExeDword
	jmp .done

.doIndirectMemory:
	;here we write the disp8 or disp32 depending on mod
	cmp dword [_mod],0
	jz .done  ;no displacement value with mod=0
	cmp dword [_mod],1
	jz .doDisp8
	cmp dword [_mod],2
	jz .doDisp32

.doDisp8:
	;tom I dont think this will ever get executed
	;because test4mem only supports mod=0 (no disp) and mod=2 (disp32) as of Oct 2015
	;disp8 is unsupported
	call WriteExeByte
	jmp .done

.doDisp32:
	call WriteExeDword
	jmp .done

.error:
	mov dword [_errorcode],ERROREXTRNLINKADD 
.done:
	ret





;*******************************************************
;PROCESSIMMEDIATEDATA

;writes a byte, word or dword of imm data to exe
;depending on _wbit
;checks to make sure the size of the immed data
;does not exceed the value of _wbit

;this function is usually called last after
;prefix, opcode, SIB and Memory/Disp bytes are processed

;input: eax=immediate data
;       global dword [_wbit]
;return:none
;*******************************************************

ProcessImmediateData:

	;this dumpstr will messup the display of the exe bytes, use only for error checks
	;STDCALL str22,dumpstr

	cmp dword [_wbit],0  ;byte   (same as intel)
	jz .doByte
	cmp dword [_wbit],1  ;dword  (same as intel)
	jz .doDword
	cmp dword [_wbit],2  ;word   (we made this up)
	jz .doWord
	jmp .error


.doByte:
	cmp eax,0xff
	ja .error
	call WriteExeByte
	jmp .done

.doWord:
	cmp eax,0xffff
	ja .error
	call WriteExeWord
	jmp .done

.doDword:

	;we used to have a call to extern_add_link in here
	;if [_havextern] we set to 1
	;but this is a problem for code like:
	;e.g. mov dword [PassToPaint],segmentcreateMI_11
	;where symbol PassToPaint is extern but segmentcreateMI_11 is local
	;because _havextern can not tell if the source or dest is extern
	;so for now immediate extern symbols are unsupported

	;finally write the dword immediate to exe
	call WriteExeDword
	jmp .done

.error:
	;display error message and stop ttasm 
	mov dword [_errorcode],ERRORWBIT  ;missing or invalid wbit

.done:
	ret






;************************************************************************
;PROCESSCODELABEL

;a code label is any ascii string followed by colon :
;or it is a "public" string
;the code label must be on a line all by itself
;the address/_assypoint of all code labels is known at assembly time
;code labels are hashed and added to ttasms symbol table on pass=1
;see tablesym.s
;this code does hash/add symbol on pass=1 and just retrieves on pass=2 

;input: push address of 0 terminated ascii string code label  [ebp+8]
;       note the : is not in the string nor is the word public
;return: sets dword [_errorcode] 
;************************************************************************

ProcessCodeLabel:

	push ebp
	mov ebp,esp

	cmp dword [_onpass2],1    ;are we on pass=2 ?
	jz near .pass2  


	;pass=1  hash and add label
	;****************************

	call dumpnl
	call dumpnl
	STDCALL str283a,dumpstr

	mov esi,[ebp+8]  ;esi=address of ascii string code label
	call ProcessLocalString
	;return value esi is either global or global.local string
	jnz .1

	;esi=address of global string
	call saveglobalsym

.1:

	;dump the symbol/string and symbol value
	;we now do this on pass2 only otherwise fills up the dump with too many strings
	;STDCALL str72,dumpstr
	;STDCALL esi,dumpstr
	;mov eax,[_assypoint]
	;STDCALL str92,0,dumpeax

	;add code label to symtable on pass1
	;esi=address of 0 terminated string
	mov eax,[_assypoint]  ;symbol value=address
	mov edx,3             ;data class
	call symadd           ;eax=0 success, ebx=table index

	;check return value of symadd to make sure no clashes
	cmp eax,0
	jnz .error1

	;if we got here we added a new hashed symbol to ttasms symtab on pass=1
	;since the hash table does not save the human readable ascii string
	;we will save the ascii string along with memory address to the 
	;ttasm string table and dump this string table at the end of every assembly

	;esi=address of string
	;global dword [_assypoint] is the symbol address
	call StringTableAdd

	jmp .done





.pass2:

	;pass=2 retrieve symbol from table
	;**********************************

	call dumpnl
	call dumpnl
	STDCALL str283b,dumpstr

	mov esi,[ebp+8]  ;esi=address of ascii string code label
	call ProcessLocalString
	;return value esi is either global or global.local string
	jnz .2

	;esi=address of global string
	call saveglobalsym

.2:

	;dump the symbol/code label/string
	STDCALL esi,dumpstrquote 

	;input = esi string to lookup
	call symlookup   ;eax=data class, ebx=symbol value 

	;dump the symbol value
	push eax
	mov eax,ebx
	STDCALL str86,0,dumpeax   
	pop eax

	;check return
	cmp eax,0  ;0=failed:not in table
	jz .error2

	;why did we do this tom ???
	;mov eax,ebx   ;symbol value in ebx
	jmp .done



.error1:
	mov dword [_errorcode],ERRORSYMADD   ;symadd failed
	jmp .done
.error2:
	mov dword [_errorcode],ERRORSYMTABLE
.done:
	pop ebp
	retn 4











;***************************************************
;GETOPSTR
;continue reading linebuffer 
;after the instruction string 
;read till SPACE or comma or 0 terminator  
;these ascii chars are collected to a seperate buffer
;they represent the source or destination operand
;the string is 0 terminated

;this function will also identify a size qualifier string
;e.g. 'byte', 'word', 'dword', 'qword'
;the qualifier must preceede the memory reference.
;e.g. dword [memory]
;if a size qualifier is read this fuction will set the 
;[_wbit] value and continue reading to store
;the memory reference

;input
;push address of buffer to store op string  [ebp+8]
;	  (_sourcestr or _deststr)

;return 
;success: CF is clear and op string is stored at given address
;         if a size qualifier is found, [_wbit] is set
;failure: CF is set, [_errorcode] will contain nonzero value 

;sample usage:
;stdcall _sourcestr,getopstr
;jc .error

HaveSizeQualifier dd 0
;**************************************************

getopstr:

	push ebp
	mov ebp,esp
	pushad

	mov dword [HaveSizeQualifier],0

.doagain:


	mov esi,[_linebufindex]
	call skipspace

	mov edi,[ebp+8]
	mov ecx,50  ;we read at most 50 char
	cld


.getopchar:

	lodsb ;al->[esi], esi++
	
	;terminate on comma
	cmp al, ','
	jz .terminate
	
	;terminate on SPACE
	cmp al,SPACE
	jz .terminate

	;terminate on 0
	cmp al,0
	jz .terminate
	
	;store 
	stosb   ;al->[edi], edi++

	dec ecx
	jnz .getopchar


	;if we got here we are in trouble
	jmp .error


.terminate:
	mov al,0
	stosb

	;redefine _linebufindex to be where we ended
	mov [_linebufindex],esi     


	;dump the string we collected
	STDCALL str4,[ebp+8],dumpstrstr


	;done saving the op string and 0 terminating


	;we dont want to lookup a size qualifier twice
	cmp dword [HaveSizeQualifier],1
	jz .success


	;*****************************************
	;test for byte,word,dword,qword qualifier
	;which must preceede a [memory] reference
	;e.g. dword [memory]
	;*****************************************

	STDCALL str225a,dumpstr

	;input = esi string to lookup
	mov esi,[ebp+8]
	call symlookup   ;eax=data class, ebx=symbol value 

	;the byte,word,dword,qword size qualifiers
	;are data class=7 in our symbol table

	cmp eax,7   
	jnz .success ;not a size qualifier

	;we have a byte,word,dword,qword size qualifier
	;the value in ebx is the same as our _wbit
	;0=byte, 1=dword, 2=word, 3=qword
	mov dword [_wbit],ebx
	
	;dump the size qualifier
	mov eax,ebx
	STDCALL str225b,0,dumpeax

	;now go back and read the rest of the operand string
	mov dword [HaveSizeQualifier],1
	jmp .doagain


.success:
	clc
	jmp .done
.error:
	mov dword [_errorcode],ERRORPARSE
	stc
.done:
	popad
	pop ebp
	retn 4












;*****************************************************
;GETOPERATION
;this function identifies the source and destination
;and returns a unique number describing the combination
;the return value is used as an index into a call table
;this function is only suitable when you have both
;a source and destination operand seperated by commas
;usage: mov, add, sub ...
;do not use for single operand functions like inc/dec...

;input
;none, reads _linebuf directly

;return
;eax=a number from 0-7 describing the source and destination
;    use number as index into a call table of function addresses
;    your call table should provide 8 addresses
;    see mov Operation for example


;src/dest type ID
;**************************
;_sourcetype    _desttype

;imm  =6        reg  =3
;reg  =5        mem  =1 
;mem  =4        array=-1  (0xffffffff)
;array=3                                 
        

;see test4mem for valid memory references that ttasm can decode (limited)
;see test4imm for valid immediate or defined constants that ttasm can decode 



;permissable operations:
;*************************
;src->dest

;array->reg = 3-3  =   0 <--return value=eax
;mem->reg   = 4-3  =   1  
;reg->reg   = 5-3  =   2
;imm->reg   = 6-3  =   3
;reg->mem   = 5-1  =   4
;imm->mem   = 6-1  =   5
;reg->array = 5--1 =   6 
;imm->array = 6--1 =   7


;it also fills in the following values: 
;_wbit
;_desttype
;_destvalue
;_destclass
;_sourcetype
;_sourcevalue
;_sourceclass

;the _wbit is set based on the size of the register involved
;not based on [memory]
;register can be source or dest
;if 8bit register then wbit=0
;if 32bit register then wbit=1
;for 16bit register which requires of prefix byte in pmode we temporarily
;set wbit=2 then later write the prefix byte and change wbit=1

;*****************************************************

getoperation:


	;zero _deststr and _sourcestr
	;this helps to identify syntax errors on reads in the next line
	mov byte [_deststr],0
	mov byte [_sourcestr],0


	;**************
	; DESTINATION
	;**************

	STDCALL str190,dumpstr
	
	STDCALL _deststr,getopstr
	jc near .done 


	;is dest reg ?
	mov esi,_deststr
	call test4reg
	jnz .destnotreg
	mov dword [_desttype], DESTREG  ;dest type 
	mov [_destvalu] ,ebx            ;reg number
	mov [_wbit],ecx                 ;0=8bit, 1=32bit, 2=16bit
	jmp .getsource
.destnotreg:



	;is dest array ?
	mov esi,_deststr
	call test4array
	jnz .destnotarray
	mov dword [_desttype], DESTARR 
	mov [_destvalu] ,ebx        ;array name address 
	mov [_destclass],ecx        ;register number 0-7 as index to array
	jmp .getsource
.destnotarray:



	;is dest mem ?
	mov esi,_deststr
	call test4mem
	;this function fills in global dwords [_mod] and [_rm] 
	;these are used to form the modregr/m byte
	;we can do this because mem can not be both a source and dest operand
	;ebx will be disp8 or disp32 or address as appropriate
	jnz .destnotmem
	mov dword [_desttype], DESTMEM   
	mov [_destvalu] ,ebx             ;memory address or disp8 or disp32
	mov dword [_destclass],ecx       ;memory class
	jmp .getsource
.destnotmem:



	;if we got here dest is not reg or array or mem
	;dest can not be imm
	;so we have invalid dest operand
	mov dword [_errorcode],ERRORINVALDEST
	jmp .done





	;**********
	; SOURCE
	;**********

.getsource:

	STDCALL str189,dumpstr


	STDCALL _sourcestr,getopstr
	jc near .done 


	;is source reg ?
	mov esi,_sourcestr
	call test4reg
	jnz .sourcenotreg
	mov dword [_sourcetype], SOURCEREG  ;source type 
	mov [_sourcevalu],ebx               ;reg number
	mov [_wbit],ecx
	jmp .computeoperation
.sourcenotreg:



	;is source array ?
	mov esi,_sourcestr
	call test4array
	jnz .sourcenotarray
	mov dword [_sourcetype], SOURCEARR
	mov [_sourcevalu] ,ebx       ;array name address 
	mov [_sourceclass],ecx       ;register number 0-7 as index to array
	jmp .computeoperation
.sourcenotarray:




	;is source mem ?
	mov esi,_sourcestr
	call test4mem
	jnz .sourcenotmem
	mov dword [_sourcetype], SOURCEMEM  
	mov [_sourcevalu] ,ebx              ;memory address or disp8 or disp32
	mov dword [_sourceclass],ecx        ;memory class
	jmp .computeoperation
.sourcenotmem:




	;is source immed ?
	mov esi,_sourcestr
	call test4imm
	jnz .sourcenotimmed
	mov dword [_sourcetype],SOURCEIMM   ;source type
	mov [_sourcevalu],ebx               ;immed value
	jmp .computeoperation
.sourcenotimmed:



	;we have invalid source operand
	mov dword [_errorcode],ERRORINVALSOURCE
	jmp .done


.computeoperation:

	;determine which mov operation we should call
	mov eax,[_sourcetype]   ;6,5,4,3 
	mov ebx,[_desttype]     ;3,1,-1
	sub eax,ebx
	
	;return value in eax is the operation index
	STDCALL str99,0,dumpeax  ;"getoperation index returned"


	;check to make sure index is within range 0->7 
	cmp eax,0
	setae bl
	cmp eax,7
	setbe cl
	add bl,cl
	cmp bl,2
	jz .done

	;this will stop ttasm
	mov dword [_errorcode],ERROROPERINDEX  ;value is out of range

.done:
	ret







;********************************************
;POSTPROCESS
;postprocess
; * dump warning messages about org, ..start, exit
; * prepare a string describing the result of the assemble
; * dump sizeof/start/end of executable code
; * dump the string table

;input:none
;return: "_ttasmreturnstring" string is written
;********************************************

postprocess:

	;3 blank lines after last line of asm code
	call dumpnl
	call dumpnl
	call dumpnl


	STDCALL str80,dumpstr   ;**********************************************
	STDCALL str32,dumpstr   ;ttasm post process:


	;check for one org directive, every asm file must have this
	cmp dword [_haveorg],1  
	jz .doneOrgCheck
	mov dword [_errorcode],ERRORNOORG  ;set error flag
.doneOrgCheck:


	;check for start directive and issue a warning if missing
	;secondary source files do not require start
	cmp dword [_havestart],1
	jz .doneStartCheck
	call dumpnl
	STDCALL str275,dumpstr    ;dump warning message
.doneStartCheck:


	;check for exit directive and issue a warning if missing
	;secondary source files do not require exit 
	cmp dword [_haveExit],1
	jz .doneExitCheck
	STDCALL str276,dumpstr   ;dump warning message
.doneExitCheck:



	;dump success/error message
	mov eax,[_errorcode]
	push dword [_errorstring+eax*4]
	call dumpstr
	
	STDCALL str80,dumpstr   ;**********************************************
	call dumpnl


	;prepare a string that will be passed to tedit
	;and displayed at the bottom of the tedit screen
	;this string will display the results of the assemble
	;*****************************************************

	;fill the ttasmreturnstring buffer with all spaces
	mov edi,_ttasmreturnstring
	mov ecx,100
	mov al,SPACE
	call memset 
	

	;linenum
	mov edi,_ttasmreturnstring
	mov esi,str5
	call strcpy  
	mov eax,[_linecount] 
	dec eax    
	STDCALL edi,0,0,eax2dec


	;error string
	mov byte [edi],SPACE  ;overwrite 0 terminator
	add edi,2             ;create some space
	mov eax,[_errorcode]
	mov esi, [_errorstring+eax*4]
	call strcpy
	
	
	;terminate 
	mov byte [edi],0 


	;determine qtyexebytes = final[_assypoint] - [_exeAddressStart]
	mov eax,[_assypoint]
	sub eax,[_exeAddressStart]  ;_exeAddressStart is set by a call to 'org'
	mov ecx,eax  ;save

	;save size of executable for benefit of shell which can save exe to flash
	;note this is the size of the current file being assembled
	;not applicable to multiple source files
	mov [sizeofexe],eax


	;dump size of executable
	;note if there was an asm error this value is not correct
	mov eax,[sizeofexe]
	STDCALL str270,0,dumpeax

	;dump address start of executable
	mov eax,[_exeAddressStart]
	STDCALL str271,0,dumpeax

	;dump address end of executable
	;eax=[_exeAddressStart] still
	add eax,[sizeofexe]
	STDCALL str272,0,dumpeax



	;dump the ttasm string table
	;******************************
	;the format of the ttasm string table is described above in the notes
	;we output like this:
	;"0x20000010 apple"   
	;first comes the code label address then the code label

	call dumpnl
	STDCALL str11,dumpstr  ;"ttasm string table:"

	mov esi,0x29a0000  ;start of string table

.1:
	;in this loop esi must be preserved

	;get symbol value in eax
	mov eax,[esi] 
	add esi,4    ;inc past end of

	cmp eax,0    ;quit when we read a 0 symbol value
	jz .done

	;get string length 
	movzx ecx,byte [esi]  ;get byte strlen
	add esi,1             ;inc past end of byte strlen to start of string

	;now dump the string
	push esi  ;starting address of string not 0 terminated
	push ecx  ;strlen
	call dumpeaxstrn

	add esi,ecx   ;inc past end of string to next symbol
	jmp .1


.done:
	STDCALL str289,dumpstr   ;************ END TTASM **********************
	ret








;************************************************************
;TEST4REG
;routine tests if operand string is a general purpose register
;these are the 8/16/32 bit registers

;input
;esi=address of operand string 

;return
;on success ZF is set 
;ebx=number from 0-7 representing the register 
;    see SYMBOL TABLE notes above
;ecx =_wbit= 0 for 8bit, 1 for 32bit, 2 for 16bit
;
;on error ZF is clear (reg not found)
;***********************************************************

test4reg:

	push esi

	STDCALL str25,esi,dumpstrstr

	;esi=address of string
	;this function will also display the string using quotes
	call symlookup   ;eax=data class, ebx=symbol value 

	;check return for reg data class
	cmp eax,1  ;1=reg
	jz .havereg
	or ebx,1    ;clear zf to indicate not reg
	jmp .done
.havereg:


	;decode the reg 
	;symlookup should return eax=1 for reg and 
	;ebx=0xbbaa were aa=reg num and bb=Wbit

	;Wbit  operand size
	mov ecx,ebx
	shr ecx,8   ;ecx=Wbit

	;which reg
	and ebx,0xff  ;mask off reg
	
.success:

	;register number
	mov eax,ebx
	STDCALL str191,0,dumpeax  

	;we can not set the global wbit here
	;because test4mem function calls test4reg
	;in order to identify a 32 bit reg within brackets [reg32]
	;which is a memory reference
	;and memory reference does not determine wbit, only register size does
	;i.e. in mov al,[edx] the wbit is determined by al not edx
	;so we return wbit in ecx
	;and its up to the calling function to decide
	;wether to save this to global _wbit or not
	mov eax,ecx
	STDCALL str192,0,dumpeax  

	xor eax,eax  ;set zf to indicate success

.done:
	pop esi
	ret





;************************************************************
;TEST4FPUREG
;routine tests if operand string is an fpu register
;these are 64 bit registers st0,st1,st2...st6

;input
;esi=address of operand string 

;return
;on success ZF is set 
;ebx=number from 0-7 representing the fpureg number
;    see symtable.s notes
;
;on error ZF is clear (not fpu reg)
;***********************************************************

test4fpureg:

	push esi

	STDCALL str23,esi,dumpstrstr

	;esi=address of string
	;this function will also display the string using quotes
	call symlookup   ;eax=data class, ebx=symbol value 

	;check return for reg data class
	cmp eax,8  ;8=fpureg
	jz .havefpureg
	or ebx,1    ;clear zf to indicate not fpureg
	jmp .done
.havefpureg:


	;dump the fpureg number
	mov eax,ebx
	STDCALL str278,0,dumpeax  

	xor eax,eax  ;set zf to indicate success

.done:
	pop esi
	ret






;***********************************************************
;TEST4ARRAY    

;input
;esi=address of operand string 

;output
;zf is set if string is array else clear if it is not
;ebx=address of array name from symbol table
;ecx=register number 0-7

;array
;this is a special syntax for ttasm
;and applies only to arrays of dwords
;example:
;myarray[reg]
;where reg = eax,ebx,ecx,edx,esi,edi  (ebp and esp not allowed)
;myarray[ebx] is equivalent to [myarray+ebx*4] in nasm
;there should be no spaces within the letters
;byte and word access is unsupported, only dword memory access

;this is the only instruction that supports the SIB byte 

;TIP: if your assemble fails, trying moving the array declaration
;to the beginning before the code  (i.e. jmp over data to code)

;locals
arrayAddressStart dd 0
arrayAddressBrace dd 0
;*************************************************************

test4array:

	push esi

	STDCALL str98,esi,dumpstrstr

	;save for later
	mov [arrayAddressStart],esi


	;make sure first byte of string is not '['
	cmp byte [esi],'['
	jz .failure
	

	;find address of [ in string
	mov edi,esi
	mov al,'['
	call strchr
	;returns zf clear on success, ecx=index of byte, edi=address of byte
	jz .failure


	;save for later
	mov [arrayAddressBrace],edi


	;now use test4mem to determine the index register used
	mov esi,edi
	call test4mem
	jnz .failure
	;ecx=1 memory is immediate or defined const & ebx=address
	;ecx=2 memory address in register _rm & ebx=disp8 or disp32
	;we expect ecx=2 class 2 register indirect
	cmp ecx,2  
	jnz .badmemoryclass


	;overwrite the [ with 0 so esi points to 0 terminated array name only 
	mov eax,[arrayAddressBrace]
	mov byte [eax],0


	;now we check our symbol table for the array name
	;esi=address of array name 
	;this function will also display the string using quotes
	mov esi,[arrayAddressStart]
	call symlookup   ;eax=data class, ebx=symbol value 


	;test for something found in table
	cmp eax,0
	jnz .success
	

.badmemoryclass:
	STDCALL str185,dumpstr  ;dont have class 2 reg indirect
.failure:
	or eax,1  ;clear zf
	jmp .done
.success:
	STDCALL esi,dumpstr
	mov eax,ebx
	STDCALL str76,0,dumpeax
	mov ecx,[_rm]  ;regnum
	xor eax,eax    ;set zf
.done:
	pop esi
	ret







;************************************************************
;TEST4MEM

;decode a bracketed [] string that is a memory reference
;save globals [_mod] and [_rm]  
;return the displacement or memory address as reqd

;mod=0 for [reg32], 1 for [reg32+disp8], 2 for [reg32+disp32]
;r/m numbers same as reg but r/m is memory address in register

;SIB bytes are not yet supported so you can not do [reg32 + reg32] 
;nor can you scale any register by 2 or 4  (see test4array)

;this function can not determine the _wbit value
;destination register size or the bwd qualifier determines wbit

;note: the byte,word,dword,qword size qualifier is processed by getopstr

;This function can decode only (3) types of memory reference strings:

;[1] address is dword immediate value or defined constant or code label in symbol table
;allowable [0x12345678], [GETC], [apple+0x40]
;mod=0, r/m=5, dword address follows the modregr/m byte

;[2] address in reg32: 
;allowable: [eax], [ecx], [edx], [ebx], [esi], [edi]
;mod=0 and r/m=0,1,2,3,6,7 respectively
;note [ebp] not allowed, use [ebp+0]

;[3] address in reg32 plus disp32 or stack reference with minus disp32: 
;allowable: [eax+disp32], [ecx+disp32], [edx+disp32], [ebx+disp32], 
;           [ebp+disp32], [esi+disp32], [edi+disp32]
;           any [reg-disp32] is also supported
;mod=2 and r/m=0,1,2,3,5,6,7 respectively


;note [reg32+disp8] is now ignored/unsupported, all displacements are disp32


;input
;esi=address of operand string 

;return
;zf is set if value is mem else clear if it is not
;dword [_mod] and dword [_rm] global values are saved
;these values are used to form the modregr/m byte for memory addressing
;ecx=memory class and ebx=memory address or displacement as follows:
;if ecx=1 memory is immediate value or defined constant and ebx=address
;if ecx=2 memory address is in register _rm and ebx=disp8 or disp32 
;other values of ecx are undefined

;locals:
;[ebp-4]  for [reg-disp32]=1 and for [reg+disp32]=0

;***********************************************************

test4mem:

	push ebp
	mov ebp,esp
	sub esp,4   ;[ebp-4] save local variable on the stack

	push esi
	push edi

	STDCALL str26,esi,dumpstrstr


	;check for the [ and ] braces
	;*******************************

	;check for left brace [
	mov al,[esi]
	cmp al, '['
	jnz near .failure   ;not memory

	;want esi to point to first char after [
	inc esi

	;find end of string - ]
	mov edi,esi
	mov al,']'
	call strchr
	jnz .terminate

	;if we got here we are in trouble-syntax error
	mov dword [_errorcode],ERRORPARSE
	jmp .failure

.terminate:

	mov byte [edi],0  ;overwrite ] with 0



	;first look for a minus "-" seperator byte of a dual string
	;*********************************************************

	STDCALL str197a,dumpstr

	push esi         ;parent string
	push 45          ;seperator byte 45 = (-)
	push 2           ;max qty substrings
	push _stormem    ;storage for substring addresses
	call splitstr    ;return qty substrings in eax

	cmp eax,0        ;error in trying to split the string
	jz near .error
	cmp eax,1        ;parent string does not contain (-) seperator byte
	jz near .tryPlusSeperator
	cmp eax,2        ;found 2 substrings seperated by (-)
	jz .DualStringNegative
	jmp near .failure


.tryPlusSeperator:

	;now look for a plus "+" seperator byte of a dual string
	;*********************************************************
	STDCALL str197b,dumpstr

	push esi         ;parent string
	push PLUS        ;seperator byte = (+)
	push 2           ;max qty substrings
	push _stormem    ;storage for substring addresses
	call splitstr    ;return qty substrings in eax

	cmp eax,0
	jz near .error
	cmp eax,1  ;string does not contain (+)
	jz near .SingleString
	cmp eax,2  ;two strings seperated by (+)
	jz .DualStringPositive
	jmp near .failure


.DualStringNegative:
	;if we got here we have a dual string with minus seperator byte
	mov dword [ebp-4],1   ;[reg32-disp32]
	jmp .DualString

.DualStringPositive:
	;if we got here we have a dual string with plus seperator byte
	mov dword [ebp-4],0   ;[reg32+disp32]

.DualString:

	;save address of the first substring
	mov [_dualstr1],esi  

	;save address of the 2nd substring 
	mov eax,[_stormem]
	mov [_dualstr2],eax  


	;test for [reg32+disp32]  or  [reg32-disp32]
	;**************************************************

	STDCALL str197c,dumpstr

	;the first string must be reg32
	;esi=address of first substring
	mov esi,[_dualstr1]
	call test4reg         ;ebx=regnum
	jnz .doneRegPlusDisp
	mov dword [_rm],ebx   ;regnum


	;the second string must be an immed value
	;for now we treat as disp32
	mov esi,[_dualstr2]
	call test4imm           ;ebx=imm value
	jnz .doneRegPlusDisp    ;string is not reg32+disp
	cmp dword [ebp-4],1     ;is the imm value negative as in [reg-disp32] ?
	jnz .notnegative
	neg ebx                 ;ebx= -disp32 for [reg-disp32]
.notnegative:

	;tom whats this instruction doing ???
	;mov edx,ebx             ;ebx=disp32


	;April 28, 2013
	;the way this assembler is written, test4imm may return 0 (disp8)
	;on the first pass with a forward reference 
	;but on the 2nd pass it could turn out to be a defined disp32 
	;and this will mess up the assembly points of code labels
	;since all assy points are set on the first pass
	;so we will for now hardcode all displacements as reg + disp32 

	mov dword [_mod],2   ;[reg32+disp32] or [reg32-disp32]
	;ebx=disp32
	mov ecx,2            ;memory class, address in reg
	jmp near .success

.doneRegPlusDisp:


	;a dual string may also be (DefinedConstant + ImmediateValue)

	;test for [apple+0x40]
	;***********************

	STDCALL str197d,dumpstr

	;this case is really the same as a single string immediate or defined constant
	;just have to add the two together
	;note the defined constant must come first and the immediate value last

	;first string
	mov esi,[_dualstr1]
	call test4imm   ;ebx=imm value
	jnz near .failure
	mov edx,ebx
	
	;second string
	mov esi,[_dualstr2]
	call test4imm   ;ebx=imm value
	jnz near .failure

	;now add the address of "apple" plus the immediate value together
	add ebx,edx

	mov dword [_mod],0
	mov dword [_rm],5

	;ebx = address	
	mov ecx,1  ;memory class, address is immediate or defined const
	jmp near .success
	;done dual string




.SingleString:

	STDCALL str198,dumpstr

	;we have a single string to examine at esi
	;valid single string examples:
	;allowable [0x12345678], [GETC]
	;allowable: [eax], [ecx], [edx], [ebx], [esi], [edi]



	;test for [reg32]
	;*****************
	STDCALL str248,dumpstr

	;esi=address of string
	call test4reg
	jnz .donetest4regSingle
	mov dword [_mod],0
	mov dword [_rm],ebx  ;regnum

	;note [ebp] is illegal since r/m=5 is reserved to indicate
	;memory address is displacement only
	;you must use [ebp+0]
	cmp ebx,5
	jz near .error

	mov ebx,0  ;there is no displacement
	mov ecx,2  ;memory class, address in reg
	jmp near .success
.donetest4regSingle:



	;test for [0x1888888] or [10125] 
	;*******************************
	STDCALL str249,dumpstr

	;esi=address of string
	call test4num  ;returns eax=numerical value
	jnz .donenumber
	mov dword [_mod],0
	mov dword [_rm],5
	mov ebx,eax  ;address
	mov ecx,1    ;memory class, address is immediate or defined const
	jmp near .success
.donenumber:


	;test for [apple] or [GETC]
	;***************************
	STDCALL str250,dumpstr

	;esi=address of string
	call test4imm   ;ebx=imm value
	jnz .failure
	mov dword [_mod],0
	mov dword [_rm],5
	;ebx=imm value
	mov ecx,1    ;memory class, address is immediate or defined const
	jmp near .success
	

	;end of evaluating single string memory reference
	



.failure:
	STDCALL str251a,dumpstr
	or eax,1  ;clear zf
	jmp .done

.error:
	mov dword [_errorcode],ERRORPARSE 
	or eax,1  ;clear zf
	jmp .done

.errorQualifier:
	mov dword [_errorcode],ERRORBWDQUAL 
	or eax,1  ;clear zf
	jmp .done

.success:
	STDCALL str251b,dumpstr

	mov eax,[_mod]
	STDCALL str218,0,dumpeax

	mov eax,[_rm]
	STDCALL str219,0,dumpeax

	mov eax,ebx   ;ebx=memory address or disp8 or disp32
	STDCALL str220,0,dumpeax

	mov eax,ecx   ;ecx=memory class
	STDCALL str217,0,dumpeax

	xor eax,eax  ;set zf

	;this function returns values in ZF, _mod, _rm, _ecx, ebx

.done:
	pop edi
	pop esi
	mov esp,ebp  ;deallocate locals
	pop ebp
	ret




;************************************************************
;TEST4IMM
;routine tests if operand string is 
;[1] decimal or hex string constant like 0x1234 or 123
;[2] a defined constant like "LFB" or "BACKBUF" or code label like "apple" 
;    whose numerical equivalent is stored in the symbol table 

;be careful with this function
;on pass1 it may assume you are feeding it an undefined constant
;and it will set ZF and return success
;see "getoperation" which tests the source op in the following order:
;reg, array, mem, imm  

;this function will also identify an extern symbol
;it will set global dword [_havextern] to 1
;and save the extern symbol to the _externbuffer
;for functions who will process the rest of the line of code

;input
;esi=address of operand string 

;return
;zero flag is set if value is immed else clear if it is not
;ebx=immediate value 
;***********************************************************

test4imm:

	push eax
	;ebx=return value
	push ecx
	push edx
	push esi
	push edi


	STDCALL str24,esi,dumpstrstr

	;[1] test for number like 0x1234 or 12345 
	call test4num
	jnz .trydefinedconstant
	mov ebx,eax
	jmp .success


.trydefinedconstant:

	;[2] Defined Constant or Code Label
	;only class=3 or 5 values will pass here, all others fail
	
	;if the code label is a forward reference that hasnt been added to symtable yet
	;and we are on pass1 we will just assign a symbol value of 00 
	;and quietly exit without error

	;esi=address of 0 terminated string to lookup
	call symlookup   
	;al=data class, ebx=symbol value 
	;esi is preserved

	;class=0 not in symbol table
	;class=1 register not imm
	;class=2 reg indirect not imm
	;class=3 string representing a defined constant imm value
	;class=4 stack reg not imm
	;class=5 ttasm function entry point
	;class=6 memory reference
	;class=7 byte,word,dword,qword size qualifier
	;class=8 fpu reg
	;class=9 extern symbol

	cmp al,0
	jz near .checkPass
	cmp al,1
	jz near .failure
	cmp al,2
	jz near .failure
	cmp al,3
	jz near .success
	cmp al,4
	jz near .failure
	cmp al,5
	jz near .success
	cmp al,6
	jz near .failure
	cmp al,7
	jz near .failure
	cmp al,8
	jz near .failure
	cmp al,9
	jz near .haveExtern

.checkPass:
	;we got here because the defined constant is not in the symtable yet
	;it could be a forward reference code label
	;so check which pass we are on
	cmp dword [_onpass2],0
	jz .quietFailurePassOne

	;if we got here we are on pass=2
	;the symbol is still not in the table so we exit failure
	;fall thru failure

.failure:
	mov ebx,0
	STDCALL str75d,dumpstr
	or edx,1        ;clear zf on failure
	jmp .done

.haveExtern:
	STDCALL str75cc,dumpstr

	;zero out the global buffer to store the extern symbol 
	cld 
	mov al,0
	mov edi,_externbuffer
	mov ecx,12
	rep stosb

	;copy the extern symbol to the buffer
	;docall & ProcessMemoryAndDisplacement will use this 
	;to add a link to the extern table
	;esi=address of extern symbol
	mov edi,_externbuffer
	call strcpy80

	mov dword [_havextern],1
	;ebx = save symbol value
	mov eax,ebx
	STDCALL str75c,0,dumpeax
	xor edx,edx    ;set zf on success
	jmp .done

.quietFailurePassOne:
	mov ebx,0      ;assign pass=1 temporary immediate value of 00
	STDCALL str75b,dumpstr
	xor edx,edx    ;set zf on success
	jmp .done

.success:
	;ebx=symbol value
	mov eax,ebx
	STDCALL str75a,0,dumpeax
	xor edx,edx    ;set zf on success
.done:
	pop edi
	pop esi
	pop edx
	pop ecx
	;ebx=return value
	pop eax
	ret





;************************************************
;TEST4NUM
;function will test if an ascii string
;represents a hex or decimal number
;e.g. "12345" or "0x1234"
;defined constants like SWAPBUF will fail 

;input
;esi=address of string

;output
;jz is set if string represents a number
;eax=numerical value
;************************************************

test4num:

	push esi

	STDCALL str69,esi,dumpstrstr
	
	;test the first digit to indicate immed value
	mov al,[esi]
	call isdigit
	jnz .notanumber

	;convert immed value
	;this function works for decimal or hex
	mov esi,esi
	call str2eax  ;zf is set on success, eax=numerical value
	jmp .done

.notanumber:
	STDCALL str193,dumpstr  ;"not a number"
.done:
	pop esi
	ret






;*************************************
;check4destreg32
;function checks for 32bit dest reg
;success: ZF is set
;error: ZF is clear
;************************************
check4destreg32:

	cmp dword [_wbit],1
	jz .done

	;not 32bit reg
	mov dword [_errorcode],6
	or eax,1  ;clear ZF
	ret

.done:
	xor eax,eax  ;set ZF
	ret
	

;*****************************************************************
;PROCESSLOCALSTRING
;this function checks for a local symbol
;which is any 0 terminated string preceeded by dot
;if esi points to a global symbol this function exits
;if esi points to a local symbol 
;which is a 0 terminated string preceeded by dot
;it then builds a more complex string
;consisting of [global].[local] string 
;this function is used in ttasm to add local
;symbols to the symtable and to look them up

;example of what this function does:
;Apple:   is the previous global string
;.done:   is a local string preceeded by dot
;Apple.done is what gets added to the symbol table

;the global string must be zero terminated and 
;stored in the _globalsym buffer

;input: 
;esi=address of 0 terminated local string

;return
;if string passed to this function is global then esi is unchanged & ZF is set
;if string passed to this function is local then 
;esi = address of [global].[local] string 0 terminated and ZF is clear

PLSstr1 db 'ProcessLocalString',0
;****************************************************************

ProcessLocalString:

	push eax
	push edi

	;test for local symbol
	cmp byte [esi],'.'
	jnz .notlocal


	;dump message that we are processing a local symbol
	STDCALL PLSstr1,dumpstr


	;copy _globalsym to _buf
	push esi
	mov esi,_globalsym
	mov edi,_buf
	call strcpy
	mov byte [edi],0  ;0 terminate

	;get length of local symbol
	pop esi
	mov eax,esi
	call strlen  ;ecx=length

	;catenate local symbol to global
	;esi=address of local symbol
	;ecx=length of local symbol
	mov edi,_buf
	call strcat

	mov esi,_buf  ;return value
	or eax,1      ;clear ZF
	jmp .done


.notlocal:
	xor eax,eax  ;set ZF
.done:
	pop edi
	pop eax
	ret



;******************************************************************
;SAVEGLOBALSYM
;saves a code label string to the _globalsym buffer
;a global string is one not preceeded with dot
;this function is usually preceeded by a call to ProcessLocalString
;input: esi=address of source global string
;return: esi is preserved
;******************************************************************

saveglobalsym:

	push esi  	;esi=source global string

	STDCALL str202,dumpstr

	mov edi,_globalsym
	call strcpy
	mov byte [edi],0  ;0 terminate

	pop esi

	ret




;****************************************************************************
;PROCESSSYSENTERCSV

;This function is used by many of the tlib functions 
;to allow the user to code sudo 'c' style function calls

;this function splits a string of comma seperated values
;each arg of the csv may be reg32 or dword [memory] or imm32
;then we write mov instructions

;the first arg in the csv gets written to ebx as "mov ebx,arg1"
;the 2nd   arg in the csv gets written to ecx as "mov ecx,arg2"
;the 3rd   arg in the csv gets written to edx as "mov edx,arg3"
;and so forth

;registers are written to in the following order: ebx,ecx,edx,esi,edi,ebp
;so the csv may only have up to 6 args

;here is an example of a fillrect syscall:
;fillrect 100,120,300,400,RED
;is equivalent to
;mov eax,6  because fillrect uses tlibFunctionID=6 see tlibentry.s
;mov ebx,100
;mov ecx,120
;mov edx,300
;mov esi,400
;mov edi,RED
;sysenter

;input: eax=dword tlibFunctionID (see tlibentry.s)
;return:none

;caution:
;if you pass register values as args, be careful
;the first arg gets written to ebx, the 2nd arg to ecx and so forth

;you may not use eax as an arg, its reserved for tlibFunctionID

;dont do something like this: fillrect ecx,ebx,esi,edi,[color]
;because this gets assmbled as:
;mov eax,6
;mov ebx,ecx ;failure over write of input arg
;mov ecx,ebx ;failure copy 
;mov edx,esi ;ok
;mov esi,edi ;ok
;mov edi,[color]
;sysenter

;for function args that are calculated and stored in registers
;you may be better off just using the proper registers according to tlibentry
;and just using sysenter outright

reg32Destination:
dd 3,1,2,6,7,5  ;ebx,ecx,edx,esi,edi,ebp
;****************************************************************************

ProcessSysEnterCsv:

	STDCALL str234,dumpstr

	;mov eax,imm32 where imm32=tlibFunctionID
	STDCALL str234a,dumpstr
	push eax
	mov al,0xb8
	call WriteExeByte
	pop eax
	call WriteExeDword

	call dumpnl


	mov esi,[_linebufindex]

	push esi         ;parent string
	push COMMA       ;seperator
	push 10           ;max qty substrings
	push _stor       ;storage for substring address
	call splitstr

	cmp eax,0
	jz near .error

	mov [_qtyargs],eax
	xor ebp,ebp   ;loop counter/array index

.mainloop:  

	;in this loop esi = ptr to string being processed
	;ebp = loop counter and array index
	;these must be preserved


	;dump the string to be processed
	STDCALL str234b,esi,dumpstrstr


	;mov reg32Dest,reg32Src
	;***********************
	;esi=string
	call test4reg 
	jnz .notreg
	;ebx=reg32Src  ecx=wbit
	cmp ecx,1   ;test 4 32bit reg
	jnz near .error

	STDCALL str245,dumpstr
	mov al,0x89
	call WriteExeByte

	mov eax,[reg32Destination+ebp*4] 
	STDCALL str18,0,dumpeax  ;dump regnum
	or al,0xc0
	shl ebx,3  ;ebx=source register
	or eax,ebx
	call WriteExeByte

	jmp near .nextarg
.notreg:



	;mov reg32, dword [Memory]
	;**************************
	;esi=string
	call test4mem
	;ecx=1 memory is immediate & ebx=address
	;ecx=2 memory address in register _rm & ebx=disp8 or disp32
	jnz .notmemory
	mov [_sourceclass],ecx
	mov [_sourcevalu],ebx

	STDCALL str246,dumpstr

	mov eax,[reg32Destination+ebp*4] 
	STDCALL str18,0,dumpeax  ;dump regnum
	push eax

	mov al,0x8b  ;we only support dword memory write here
	call WriteExeByte
	
	pop ebx
	call ProcessModRegRmByte

	mov ebx,[_sourceclass]  ;mem class
	mov eax,[_sourcevalu]   ;mem address or disp8 or disp32
	call ProcessMemoryAndDisp

	jmp .nextarg
.notmemory:


	;mov reg32, dword immediate
	;****************************
	;esi=string
	call test4imm   ;ebx=imm value
	jnz .notimmed

	STDCALL str247,dumpstr
	mov eax,[reg32Destination+ebp*4] 
	STDCALL str18,0,dumpeax  ;dump regnum
	or eax,0xb8  ;1011wreg
	call WriteExeByte

	;write DWORD immed 
	mov eax,ebx
	call WriteExeDword  
	
	jmp .nextarg
.notimmed:

	;if we got here we are in trouble
	mov dword [_errorcode],ERRORINVALSOURCE
	jmp .done


.nextarg:
	call dumpnl

	;get address of next substring 
	mov esi,[_stor+ebp*4]
	inc ebp  ;loop counter
	cmp ebp,[_qtyargs]
	jb .mainloop


	;done with main loop 


	;lastly we do sysenter
	call dosysenter
	jmp .done


.error:
	mov dword [_errorcode],ERRORPARSE
.done:
	ret



;***************************************************
;StringTableAdd:
;add a string to the string table
;the string table is just a way to store the human readable
;strings that represent code labels 
;along with their respective addresses
;because the ttasm symtable hashes these strings but does not
;save the string anywhere
;this function gets the symbol address from global dword [_assypoint]

;input:
;esi=address of string
;return:none  (what about when the string table is filled tom ?)
;****************************************************

StringTableAdd:

	push esi

	;each entry in the string table consists of:
	;dword symbol address
	;byte  string length
	;then follows the ascii string

	;add dword symbol address to string table
	mov eax,[_assypoint]         ;get current assy point or symbol value
	mov ebx,[_stringtblptr]      ;get address of string table ptr
	mov [ebx],eax                ;write sym address to string table
	add dword [_stringtblptr],4  ;inc _stringtblptr by 4 bytes

	;get the string length
	mov eax,esi
	call strlen  ;returns numbytes in ecx

	;add byte string length to string table
	mov ebx,[_stringtblptr]     
	mov [ebx],cl                  ;write strlen to string table 
	add dword [_stringtblptr],1   ;inc by 1 byte

	;add the string to string table
	;esi=address of string
	;ecx=strlen
	mov edi,[_stringtblptr]
	add [_stringtblptr],ecx  ;inc by ecx bytes
	call strncpy             ;ecx is preserved

	pop esi
	ret






;**************************************************************
;                EQU_WORD_DWORD_ARRAY
;**************************************************************

;equates determined by getoperation
SOURCEIMM equ 6
SOURCEREG equ 5
SOURCEMEM equ 4
SOURCEARR equ 3
DESTREG   equ 3
DESTMEM   equ 1
DESTARR   equ -1




;words
oldCW dw 0
newCW dw 0


;dwords
_errorcode    dd 0
_sourcetype   dd 0
_sourcevalu   dd 0
_sourceclass  dd 0
_desttype     dd 0
_destvalu     dd 0
_destclass    dd 0
_asmsrcindex  dd 0
_assypoint    dd 0  
_linebufindex dd 0
_linecount    dd 0
_haveEOL      dd 0
_havecomma    dd 0
_have66prefix dd 0
_onpass2      dd 0   ;holds the value of 0 for first pass and 1 for 2nd pass
_havedec      dd 0
_dataclass    dd 0
_symbolvalue  dd 0
_shrbyte      dd 0
_qtyargs      dd 0
_qtystrings   dd 0
_sig          dd 0
_exp          dd 0
_reg          dd 0
_dqIndex      dd 0
_qtycsv       dd 0
_wbit         dd 0     ;0=8bit, 1=32bit, 2=16bit
_rm           dd 0     ;this is bits3:0 of modregr/m
_mod          dd 0     ;this is bits7:8 of modregr/m
_disp32       dd 0
_dualstr1     dd 0
_dualstr2     dd 0
_stringtblptr dd 0
_haveorg      dd 0    ;keeps track or number of calls to 'org'
_havestart    dd 0
_haveExit     dd 0
_exeAddressStart dd 0
_sourcefilenum   dd 0
_havextern       dd 0
_extern_address  dd 0






;arrays/buffers
_linebuf    times 100 db 0
_instruc    times 50  db 0
_deststr    times 50  db 0
_sourcestr  times 50  db 0
_buf        times 100 db 0
_dqbuf      times 8   db 0
_globalsym  times 100 db 0
_stor       times 100 db 0
_stormem    times 20  db 0  ;for test4mem only !!!
_externbuffer times 12 db 0 ;stores the 11 byte extern symbol
_ttasmreturnstring times 100 db 0



;********************
;    ERRORCODE
;********************

;the dword _errorcode can be set by many routines
;before parsing a new line if _errorcode is nonzero ttasm will quit
;the _errorcode usage is not very consistant and needs to be cleaned up

ERRORSYMTABLE     equ 1
ERRORINVALDEST    equ 2
ERRORINVALSOURCE  equ 3
ERRORBWDQUAL      equ 4
ERROROUTOFRANGE   equ 5
ERRORUNSUPPORTED  equ 6
ERRORPARSE        equ 7
ERRORSYMNOTINTBL  equ 8
ERRORNOORG        equ 9
ERRORMULTIORG     equ 10
ERRORUSERADDRESS  equ 11
ERRORGETOPSTR     equ 12
ERRORSYMADD       equ 13
ERRORWBIT         equ 14
ERRORPUBSYMADD    equ 15
ERROREXTERNDIRADD equ 16
ERROREXTRNLINKADD equ 17
ERROROPERINDEX    equ 18
ERRORINVALCALL    equ 19
ERRORINVALREGSIZE equ 20

;error strings dumped to the stack on exit
_errorstring:
dd err0,  err1,  err2,  err3, err4, 
dd err5,  err6,  err7,  err8, err9
dd err10, err11, err12, err13, err14
dd err15, err16, err17, err18, err19
dd err20

err0:
db '0=successful assemble',0
err1:
db '1=symbol table failure (failed to find or already in table)',0
err2:
db '2=invalid/undefined destination operand',0
err3:
db '3=invalid/undefined source operand',0
err4:
db '4=missing or invalid memory size qualifier',0
err5:
db '5=value is out of range',0
err6:
db '6=unsupported size, type, wbit or operation',0
err7:
db '7=parse error, undefined symbol',0
err8:
db '8=error symbol not in table',0
err9:
db '9=error no org defined',0
err10:
db '10=error found multiple calls to org',0
err11:
db '11=error invalid userland address',0
err12:
db '12=error getopstr failed',0
err13:
db '13=symadd failed, (symbol clash)',0
err14:
db '14=invalid wbit, missing or invalid byte/word/dword size qualifier',0
err15:
db '15=failed to add public symbol to table',0
err16:
db '16=failed to add directory entry to extern symbol table',0
err17:
db '17=failed to add link to extern symbol table',0
err18:
db '18=getoperation index is out of range 0-7',0
err19:
db '19=call [indirect] of extern symbol is not allowed',0 
err20:
db '20=invalid register size',0

;if you add more error strings also update 
;the _errorstring table above



;******************
;  STRINGS
;******************

;strings copied to the "dump" to show what ttasm is doing

str1 db 'doing mov',0
str2 db 'doing call',0
str3 db 'doing ret',0
str4 db 'getopstr:',0
str5 db 'linenum ',0
str6 db 'doing cmp',0
str7 db 'mov imm->reg',0
str8 db 'mov reg->reg',0
str9 db 'mov reg->mem',0
str10 db 'mov mem->reg',0
str11 db 'ttasm string table:',0
str16 db 'doing jmpd',0
str17 db 'doing db',0
str18 db 'ProcessSysEnterCsv:regnum',0
str19 db 'ProcessModRegRmByte',0
str20 db 'ProcessMemoryAndDisp',0 
str21a db '************************* TTASM 1st PASS **************************',0
str21b db '************************* TTASM 2ND PASS **************************',0
str22 db 'ProcessImmData',0
str23 db 'test4fpureg',0
str24 db 'test4imm:',0
str25 db 'test4reg:',0
str26 db 'test4mem:',0
str29 db 'mov imm->mem',0
str31 db 'eax=qtyexe blocks, ebx=qtypad bytes, ecx=qtyexe bytes',0
str32 db 'ttasm post process:',0
str33 db 'doing div',0
str34 db 'div/reg',0
str35 db 'div/mem',0
str36 db 'doing add',0
str37 db 'add imm to reg',0
str38 db 'add imm to mem',0
str39 db 'doing inc',0
str40 db 'inc mem',0
str41 db 'inc reg',0
str42 db 'Assypoint',0
str43 db 'cmp mem with reg',0
str44 db 'cmp reg with imm',0
str46 db 'doing nop',0
str48 db 'doing jmps',0
str49 db 'displacement qty bytes for jmp/jmps/loop',0
str51 db 'doing jz/je',0
str52 db 'doing jnz/jne',0
str53 db 'doing ja',0
str54 db 'doing jb',0
str55 db 'doing jae/jnc',0
str56 db 'doing jbe',0
str57 db 'doing dw',0
str58 db 'doing dd',0
str59 db 'doing js',0
str60 db 'doing jns',0
str61 db 'doing sub',0
str62 db 'doing dec',0
str63 db 'dec mem',0
str64 db 'call reldisp32',0
str65 db 'call [memory] indirect (i.e. tlib function)',0
str66 db 'public symbols are processed on the 1st pass only',0
str69 db 'test4num:',0
str70 db 'test4imm: pass2 try defined constant sym lookup',0 
str71 db 'ProcessWbitOpcode',0 
str72 db 'adding symbol to table',0 
str73 db 'doing movzx',0
str74 db 'call register',0
str75a db 'test4imm: immediate value',0
str75b db 'test4imm: pass=1 assign temp immed value of 0',0
str75c db 'test4imm: immediate value',0
str75cc db 'test4imm: found extern symbol',0
str75d db 'test4imm: failure',0
str76 db 'memory address returned',0
str77 db 'ebx=regnum ecx=Wbit',0
str78 db 'doing cli',0
str79 db 'doing sti',0
str80 db '*******************************************************************',0
str81 db 'doing db0',0
str82 db 'doing and',0
str83 db 'doing or',0
str86 db 'ProcessCodeLabel: value of symbol from table on pass=2',0
str87 db 'doing shl',0
str88 db 'doing shr',0
str89 db 'doing getoperation',0
str90 db 'sub imm from reg',0
str91 db 'add reg->reg',0
str92 db 'symadd code label',0 
str93 db 'doing push',0
str94 db 'doing pop',0
str95 db 'doing pushad',0
str96 db 'doing popad',0
str97 db 'doing cdq',0
str98 db 'test4array:',0
str99 db 'getoperation: operation index returned',0
str100 db 'mov reg->array',0
str101 db 'mov array->reg',0
str102 db 'doing xchg',0
str103 db 'doing jg',0
str104 db 'doing loop',0
str105 db 'doing stosb',0
str106 db 'doing stosd',0
str107 db 'doing imul',0
str108 db 'sub reg from reg',0
str109 db 'add array to reg',0
str110 db 'add mem to reg32',0
str111 db 'mov imm->array',0
str112 db 'doing stc',0
str113 db 'doing clc',0
str114 db 'doing retn',0
str115 db 'stack reference ebp+disp8',0
str116 db 'doing mul',0
str117 db 'doing not',0
str118 db 'not register',0
str119 db 'doing fsqrt',0
str121 db 'cmp mem with reg',0
str122 db 'doing seta',0
str123 db 'doing setb',0
str124 db 'add stackref to reg',0
str125 db 'doing equate',0
str127 db 'doing idiv',0
str128 db 'doing std',0
str129 db 'doing cld',0
str130 db 'doing xor',0
str131 db 'doing stdcall',0
str132 db 'cmp array with immed',0
str133 db 'add reg->array',0
str134 db 'doing repmovsb',0
str135 db 'doing repmovsd',0
str136 db 'doing dq',0
str137 db 'doing stosw',0
str138 db 'doing lodsb',0
str139 db 'sub mem from reg32',0
str140 db 'doing repstosb',0
str141 db 'or immed with reg',0
str142 db 'doing fild Dword integer',0
str143 db 'doing fld Qword dbl precision',0
str144 db 'doing fld_1',0
str145 db 'doing fld_Z',0
str146 db 'doing fld_PI',0
str147 db 'doing fmulp sti=st0*sti then pop',0
str148 db 'doing fist store st0 as integer',0
str149 db 'doing fistp store st0 as integer & pop',0
str150 db 'doing fsin',0
str151 db 'doing fxch',0
str152 db 'reg number returned',0
str153 db 'doing fmul',0
str154 db 'doing ffree',0
str155 db 'doing fdiv',0
str156 db 'doing fdivr',0
str157 db 'doing fdivp',0
str158 db 'doing fst',0
str159 db 'doing fadd',0
str160 db 'doing fiadd',0
str161 db 'doing fisub',0
str162 db 'doing fisubr',0
str163 db 'doing fimul',0
str164 db 'doing fidiv',0
str165 db 'doing fidivr',0
str166 db 'add reg to mem',0
str167 db 'sub reg from mem',0
str168 db 'sub immed from mem',0
str169 db 'doing fcos',0
str170 db 'doing fstp',0
str171 db 'doing fsub',0
str172 db 'doing fsubr',0
str173 db 'cmp reg with reg',0
str174 db 'cmp reg with array',0
str175 db 'doing frndint',0
str176 db 'doing bswap',0
str177 db 'doing fsincos',0
str178 db 'doing align',0
str179 db 'qty nops to insert',0
str180 db 'doing neg',0
str181 db 'doing sar',0
str182 db 'doing incbin',0
str183 db 'ttasm-incbin:fatfindfile failed',0
str184 db 'esi+disp8',0
str185 db 'test4array: test4mem fails to return class 2 reg indirect',0
str186 db 'doing lodsd',0
str187 db 'doing fchs',0
str188 db 'doing fclex',0
str189 db 'getoperation: source',0
str190 db 'getoperation: destination',0
str191 db 'test4reg success:regnum',0
str192 db 'wbit, 0=8bit, 1=32bit, 2=16bit',0
str193 db 'test4num:not a number',0
str194 db 'doing memory address addition',0
str195 db 'doing ffreep',0
str196 db 'doing fcomi',0
str197a db 'test4mem: test for dual string with - seperator byte',0
str197b db 'test4mem: test for dual string with + seperator byte',0
str197c db 'test4mem: test for reg + or - disp32',0
str197d db 'test4mem: test for CodeLabel + disp32',0
str198 db 'test4mem: process single string',0
str199 db 'check for class=5 tlib function call',0
str200 db 'check for class=3 code label',0
str201 db 'setting pass=1 symbol value=0',0
str202 db 'saveglobalsym',0 
str203 db 'doing setge',0
str204 db 'doing setle',0
str205 db 'doing fcomip',0
str206 db 'doing jl',0
str207 db 'doing jle',0
str208 db 'doing jge',0
str209 db 'or reg->reg',0
str210 db 'doing setg',0
str211 db 'doing setl',0
str212 db 'doing fabs',0 
str213 db 'cmp imm with mem',0
str214 db 'increment fpu stack pointer',0
str215 db 'decrement fpu stack pointer',0
str216 db 'writting 0x66 prefix',0
str217 db 'memory class',0
str218 db 'mod',0
str219 db 'r/m',0
str220 db 'memory address or disp32',0
str221 db 'or mem with reg',0
str222 db 'or reg with mem',0
str223 db 'doing fpatan',0
str224 db 'doing lea',0
str225a db 'getopstr: test for size qualifier',0
str225b db 'size qualifier',0
str226 db 'doing sysenter',0
str227 db 'doing pushfd',0
str228 db 'doing swapbuf',0
str229 db 'doing exit',0
str230 db 'doing getc',0
str231 db 'doing rand',0
str232 db 'doing checkc',0
str233 db 'doing fillrect',0
str234 db 'doing ProcessSysEnter csv',0
str234a db 'writting code for mov eax,tlibFunctionID',0
str234b db 'ProcessSysEnterCsv:',0
str235 db 'doing putsml',0
str236 db 'doing cliprect',0
str237 db 'doing puts',0
str238 db 'doing pow',0
str239 db 'doing setpixel',0
str240 db 'doing backbufclear',0
str241 db 'doing putebx',0
str242 db 'doing dumpstr',0
str243 db 'doing dumpebx',0
str244 db 'doing setpalette',0
str245 db 'ProcessSysEnterCsv: doing mov reg,reg',0
str246 db 'ProcessSysEnterCsv: doing mov reg,[mem]',0
str247 db 'ProcessSysEnterCsv: doing mov reg,imm',0
str248 db 'test4mem: test for reg32',0
str249 db 'test4mem: test for number ',0
str250 db 'test4mem: test for immediate (defined constant or code label)',0
str251a db 'test4mem: failed',0
str251b db 'test4mem: mod, r/m, MemoryAddress, DataClass:',0
str252 db 'doing strcpy2',0
str253 db 'doing ebxstr',0
str254 db 'doing polyline',0
str255 db 'doing line',0
str256 db 'doing putc',0
str257 db 'doing putst0',0
str258 db 'doing rectangle',0
str259 db 'doing circle',0
str260 db 'doing putshershey',0
str261 db 'doing putmarker',0
str262 db 'doing setyorient',0
str263 db 'doing puttransbits',0
str264 db 'doing putebxdec',0
str265 db 'doing popfd',0
str266 db 'doing repstosd',0
str268 db 'doing org',0
str269 db 'new _assypoint',0
str270 db 'size of executable, bytes',0
str271 db 'address start executable',0
str272 db 'address end   executable',0
str273 db 'doing public',0
str274 db 'doing start',0
str275 db 'Warning: ..start directive is missing',0
str276 db 'Warning: exit directive is missing',0
str277 db 'erasing public & extern symbol tables',0
str278 db 'test4fpureg success:regnum',0
str279 db 'doing source #',0
str280 db 'new source #',0
str281 db 'doing extern',0
str282 db 'skipping code on 2nd pass',0
str283a db 'ProcessCodeLabel: adding code label on pass=1',0
str283b db 'ProcessCodeLabel: retrieving code label on pass=2',0
str284a db 'extern: adding extern table direntry',0
str284b db 'extern: adding symbol to ttasm symbol table value=0 class=9',0
str285 db 'ProcessMemoryAndDisp: usage of extern symbol, adding link',0
str286 db 'call reldisp32 extern symbol',0
str287 db 'mov imm->reg: usage of extern symbol, adding link',0
str288 db 'skipping erasepe on pass=2',0
str289 db '************************* END TTASM ****************************',0
str290 db '[ttasm] calling extern_add_link',0
str291 db 'doing dumpreg',0








;***************
;SYMBOL_TABLE
;***************

;these are the reserved symbols
;we hardcode into ttasm the addresses of 
;various tlib functions and defined symbols
;these are hashed and loaded when ttasm starts up

;the symbol table may contain:
; *register names  eax,ebx...         class=1
; *memory indirect [eax],[ebx]...     class=2
; *tlib defines                       class=3
; *stack reference [ebp+4],[ebp+8]... class=4
; *tlib code labels                   class=5
; *local code labels                  class=5

;each entry consists of a 0 terminated string on the first line
;then on the next line is a dword symbol value followed by
;a comma followed by a dword symbol class
;see symtable.s for more info

;symtable.s builds a hash table that does not employ chaining


ttasmSymbols:

;add to ttasm symbol table defines for Colors  (class=3)
db 'BLA',0    ;string = color name
dd 239,3      ;symbol value = color, class 3 = defined constant
db 'BLU',0 
dd 240,3
db 'GRE',0
dd 241,3 
db 'CYA',0
dd 242,3  
db 'MAG',0
dd 243,3  
db 'BRN',0
dd 244,3  
db 'RED',0
dd 245,3  
db 'LGR',0
dd 246,3  
db 'GRA',0
dd 247,3  
db 'LBL',0
dd 248,3  
db 'LGN',0
dd 249,3  
db 'LCY',0
dd 250,3  
db 'LRE',0
dd 251,3  
db 'LMA',0
dd 252,3  
db 'YEL',0
dd 253,3  
db 'WHI',0
dd 254,3  
db 'BKCOLOR',0
dd 0xff,3


;add to ttasm symbol table defines for misc special constants, class=3
db 'SOLIDLINE',0
dd 0xffffffff,3
db 'CENTERLINE',0
dd 0xffffe1f0,3
db 'HIDDENLINE',0
dd 0xffc0ffc0,3
db 'PHANTOMLINE',0
dd 0xfff0f0f0,3
db 'DOTLINE',0
dd 0xc2108420,3
db 'FONT01',0
dd 1,3
db 'FONT02',0
dd 2,3
db 'STARTOFEXE',0
dd 0x02000010,3







;add to ttasm's symbol table defines for key presses
;most printable ascii ends with 0x7f
;the non-printables are numbered sequentially
;here we have deviated from ascii
;do not change these numbers because
;tedit has a jumptable which 
;depends on these numbered sequentially as shown
db 'NEWLINE',0
dd 0xa,3
db 'NL',0
dd 0xa,3
db 'SPACE',0
dd 0x20,3
db 'PLUS',0
dd 0x2b,3
db 'COMMA',0
dd 0x2c,3
db 'F1',0
dd 0x80,3
db 'F2',0
dd 0x81,3
db 'F3',0
dd 0x82,3
db 'F4',0
dd 0x83,3
db 'F5',0
dd 0x84,3
db 'F6',0
dd 0x85,3
db 'F7',0
dd 0x86,3
db 'F8',0
dd 0x87,3
db 'F9',0
dd 0x88,3
db 'F10',0
dd 0x89,3
db 'F11',0
dd 0x8a,3
db 'F12',0
dd 0x8b,3
db 'ESCAPE',0
dd 0x8c,3
db 'SHIFT',0    
dd 0x8d,3
db 'CAPSLK',0
dd 0x8e,3
db 'CTRL',0     
dd 0x8f,3
db 'ALT',0
dd 0x90,3
db 'NUMLK',0
dd 0x91,3
db 'BKSPACE',0
dd 0x92,3
db 'HOME',0
dd 0x93,3
db 'END',0
dd 0x94,3
db 'UP',0
dd 0x95,3
db 'DOWN',0
dd 0x96,3
db 'LEFT',0
dd 0x97,3
db 'RIGHT',0
dd 0x98,3
db 'PAGEUP',0
dd 0x99,3
db 'PAGEDN',0
dd 0x9a,3
db 'CENTR',0
dd 0x9b,3
db 'INSERT',0
dd 0x9c,3
db 'DELETE',0
dd 0x9d,3
db 'PRNTSCR',0
dd 0x9e,3
db 'SCRLOCK',0
dd 0x9f,3
db 'ENTER',0
dd 0xa0,3
db 'CUT',0
dd 0xa1,3  
db 'COPY',0
dd 0xa2,3
db 'PASTE',0
dd 0xa3,3 
db 'GUI',0 
dd 0xa4,3
db 'MENU',0
dd 0xa5,3


;all indirect calls to tlib functions have been removed from ttasm
;user land code may not call tlib functions directly or indirectly
;instead must use sysenter as part of protected mode interface
;see tlibentry.s


;add to ttasm's symbol table defines for ttasm assembly language instructions  (class=5)
db 'mov',0   ;zero terminated string
dd domov,5   ;address entrypoint in ttasm ,data class
db 'movzx',0
dd domovzx,5
db 'cmp',0
dd docmp,5
db 'call',0
dd docall,5
db 'ret',0
dd doret,5
db 'retn',0
dd doretn,5
db 'jmp',0
dd dojmp,5
db 'jmps',0
dd dojmps,5
db 'db0',0
dd dodb0,5
db 'db',0
dd dodb,5
db 'dw',0
dd dodw,5
db 'dd',0
dd dodd,5
db 'dq',0
dd dodq,5
db 'add',0
dd doadd,5
db 'sub',0
dd dosub,5
db 'mul',0
dd domul,5
db 'div',0
dd dodiv,5
db 'imul',0
dd doimul,5
db 'idiv',0
dd doidiv,5
db 'inc',0
dd doinc,5
db 'dec',0
dd dodec,5
db 'nop',0
dd donop,5
db 'jae',0
dd dojae,5
db 'jbe',0
dd dojbe,5
db 'ja',0
dd doja,5
db 'jb',0
dd dojb,5
db 'jz',0
dd dojz,5
db 'jnz',0
dd dojnz,5
db 'je',0
dd doje,5
db 'jne',0
dd dojne,5
db 'js',0
dd dojs,5
db 'jns',0
dd dojns,5
db 'jl',0
dd dojl,5
db 'jg',0
dd dojg,5
db 'jle',0
dd dojle,5
db 'jge',0
dd dojge,5
db 'cli',0
dd docli,5
db 'sti',0
dd dosti,5
db 'and',0
dd doand,5
db 'or',0
dd door,5
db 'xor',0
dd doxor,5
db 'shl',0
dd doshl,5
db 'shr',0
dd doshr,5
db 'sar',0
dd dosar,5
db 'bswap',0
dd dobswap,5
db 'pop',0
dd dopop,5
db 'push',0
dd dopush,5
db 'pushad',0
dd dopushad,5
db 'pushfd',0
dd dopushfd,5
db 'popfd',0
dd dopopfd,5
db 'popad',0
dd dopopad,5
db 'cdq',0
dd docdq,5
db 'xchg',0
dd doxchg,5
db 'loop',0
dd doloop,5
db 'stosb',0
dd dostosb,5
db 'stosw',0
dd dostosw,5
db 'stosd',0
dd dostosd,5
db 'lodsb',0
dd dolodsb,5
db 'lodsd',0
dd dolodsd,5
db 'stc',0
dd dostc,5
db 'clc',0
dd doclc,5
db 'std',0
dd dostd,5
db 'cld',0
dd docld,5
db 'jc',0
dd dojc,5
db 'jnc',0
dd dojnc,5
db 'neg',0
dd doneg,5
db 'not',0
dd donot,5
db 'seta',0
dd doseta,5
db 'setb',0
dd dosetb,5
db 'setge',0
dd dosetge,5
db 'setg',0
dd dosetg,5
db 'setle',0
dd dosetle,5
db 'setl',0
dd dosetl,5
db 'repmovsb',0
dd dorepmovsb,5
db 'repmovsd',0
dd dorepmovsd,5
db 'repstosb',0
dd dorepstosb,5
db 'repstosd',0
dd dorepstosd,5
db 'lea',0
dd dolea,5



;add to ttasms symbol table directives that control the assembler output
db 'align',0
dd doalign,5
db 'incbin',0
dd doincbin,5
db 'equ',0
dd doequ,5
db 'org',0
dd doorg,5
db 'public',0
dd dopublic,5
db '..start',0   ;note you must preceed the word start with dot dot
dd dostart,5
db 'sysenter',0
dd dosysenter,5
db 'source',0
dd dosourcefilenum,5
db 'extern',0
dd doextern,5


;add to ttasms symbol table the floating point instructions
db 'fimul',0
dd dofimul,5
db 'fiadd',0
dd dofiadd,5
db 'fisub',0
dd dofisub,5
db 'fisubr',0
dd dofisubr,5
db 'fidiv',0
dd dofidiv,5
db 'fidivr',0
dd dofidivr,5
db 'fild',0
dd dofild,5
db 'fld',0
dd dofld,5
db 'fld1',0
dd dofld1,5
db 'fldpi',0
dd dofldpi,5
db 'fldz',0
dd dofldz,5
db 'fmulp',0
dd dofmulp,5
db 'fmul',0
dd dofmul,5
db 'fdiv',0
dd dofdiv,5
db 'fdivp',0
dd dofdivp,5
db 'fdivr',0
dd dofdivr,5
db 'fist',0
dd dofist,5
db 'fistp',0
dd dofistp,5
db 'fsin',0
dd dofsin,5
db 'fcos',0
dd dofcos,5
db 'fsincos',0
dd dofsincos,5
db 'fpatan',0
dd dofpatan,5
db 'fsqrt',0
dd dofsqrt,5
db 'fxch',0
dd dofxch,5
db 'fchs',0
dd dofchs,5
db 'fabs',0
dd dofabs,5
db 'ffree',0
dd doffree,5
db 'ffreep',0
dd doffreep,5
db 'fst',0
dd dofst,5
db 'fstp',0
dd dofstp,5
db 'fadd',0
dd dofadd,5
db 'fsub',0
dd dofsub,5
db 'fsubr',0
dd dofsubr,5
db 'frndint',0
dd dofrndint,5
db 'fclex',0
dd dofclex,5
db 'fcomi',0
dd dofcomi,5
db 'fcomip',0
dd dofcomip,5
db 'fincstp',0
dd dofpuinc,5
db 'fdecstp',0
dd dofpudec,5


;add to ttasm symbol table defines for tlib function calls for protected mode interface
db 'backbufclear',0
dd dobackbufclear,5
db 'putebx',0
dd doputebx,5
db 'putebxdec',0
dd doputebxdec,5
db 'setpixel',0
dd dosetpixel,5
db 'pow',0
dd dopow,5
db 'swapbuf',0
dd doswapbuf,5
db 'getc',0
dd dogetc,5
db 'rand',0
dd dorand,5
db 'exit',0
dd doexit,5
db 'checkc',0
dd docheckc,5
db 'fillrect',0
dd dofillrect,5
db 'rectangle',0
dd dorectangle,5
db 'circle',0
dd docircle,5
db 'putsml',0
dd doputsml,5
db 'cliprect',0
dd docliprect,5
db 'puts',0
dd doputs,5
db 'putshershey',0
dd doputshershey,5
db 'dumpstr',0
dd dodumpstr,5
db 'dumpebx',0
dd dodumpebx,5
db 'dumpreg',0
dd dodumpreg,5
db 'strcpy2',0
dd dostrcpy2,5
db 'ebxstr',0
dd doebxstr,5
db 'polyline',0
dd dopolyline,5
db 'line',0
dd doline,5
db 'putc',0
dd doputc,5
db 'putst0',0
dd doputst0,5
db 'putmarker',0
dd doputmarker,5
db 'setyorient',0
dd dosetyorient,5
db 'puttransbits',0
dd doputtransbits,5





;add to ttasm symbol table defines for register identification  (class=1)
;associate a reg or [reg] string with numerical values
;we pack the reg id and Wbit into 1 dword
;0x0000bbaa 
;aa=register identification number
;    see Table B-3 of Intel Instructions
;    0=al or eax
;    1=cl or ecx
;    2=dl or edx
;    3=bl or ebx
;    4=ah or esp
;    5=ch or ebp
;    6=dh or esi
;    7=bh or edi
;bb=oper size Wbit =  0=8bit, 1=32bit, 2=16bit
;note we use Wbit=2 to distinguish 16bit writes, this is not intel
;we will change Wbit to 1 and use the 66h prefix for write


;Defines for 32bit registers
db 'eax',0
dd 0x0100,1  ;symbol value=regID&Wbit, class 1=register 
db 'ecx',0
dd 0x0101,1
db 'edx',0
dd 0x0102,1
db 'ebx',0
dd 0x0103,1
db 'esp',0
dd 0x0104,1
db 'ebp',0
dd 0x0105,1
db 'esi',0
dd 0x0106,1
db 'edi',0
dd 0x0107,1

;16bit registers
db 'ax',0
dd 0x0200,1
db 'cx',0
dd 0x0201,1
db 'dx',0
dd 0x0202,1
db 'bx',0
dd 0x0203,1
db 'sp',0
dd 0x0204,1
db 'bp',0
dd 0x0205,1
db 'si',0
dd 0x0206,1
db 'di',0
dd 0x0207,1

;8bit registers
db 'al',0
dd 0x0000,1
db 'cl',0
dd 0x0001,1
db 'dl',0
dd 0x0002,1
db 'bl',0
dd 0x0003,1
db 'ah',0
dd 0x0004,1
db 'ch',0
dd 0x0005,1
db 'dh',0
dd 0x0006,1
db 'bh',0
dd 0x0007,1

;fpu registers
db 'st0',0
dd 0,8    ;symbol value=fpuregnum, class=8 for register
db 'st1',0
dd 1,8 
db 'st2',0
dd 2,8 
db 'st3',0
dd 3,8 
db 'st4',0
dd 4,8 
db 'st5',0
dd 5,8
db 'st6',0
dd 6,8

;add to ttasm symbol table size qualifiers
;byte,word,dword,qword symbols are used by getopstr
db 'byte',0
dd 0,7      ;symbol value=0, class=7
db 'word',0
dd 2,7
db 'dword',0
dd 1,7
db 'qword',0
dd 3,7




;this must be the last string of the ttasm symbols
;our code at the beginning of ttasm
;looks for this string then stops loading the symbol table
;of all known/reserved symbols
LastSymTableEntry:
db 'THE-END',0

;********************************************************************************






