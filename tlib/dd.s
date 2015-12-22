;tatOS/tlib/dd.s

;raw byte copy from memory to flash drive
;similar to "dd" on linux
;July 2012 moved copy from flash to memory to XXD
;this is a dangerous function now that we have FAT16 
;I would not use this at all 


tatOSddstr1: 
db 'DD',NL
db 'raw byte copy to your Flash Drive',NL
db 'Warning ! This function does not respect your file system',NL
db 'It will copy bytes to your flash drive wherever you want',NL
db 'Including overwrite of your VBR, FAT and root directory',NL
db 'DD requires an absolute memory address, LBAstart and qtybytes/blocks',NL
db 'F1=Copy data from memory to Flash drive',NL
db 'ESC=quit',0
 
tatOSddstr3 db 'Load blocks off PenDrive to STARTOFEXE=0x2000000: LBAstart,qtyblocks',0
tatOSddstr4 db 'Copy Binary Data to PenDrive: Address,QtyBytes,LBAstart',0
tatOSddstr6  db 'LBAstart',0
tatOSddstr7  db 'qty blocks',0

_ddstor times 20 db 0


ddShell:

	;clear screen
	call backbufclear

	;title message and instructions
	STDCALL FONT01,75,100,tatOSddstr1,0xefff,putsml

	call swapbuf

	;wait for the user to press a function key 
	call getc

	cmp al,F1
	jz .doF1
	
	;any other keypress causes quit
	jmp .done

.doF1:
	call ddMemory2Flash
.done:
	ret






ddMemory2Flash:

	;prompt user to enter Address,QtyBytes,LBAstart
	STDCALL tatOSddstr4,COMPROMPTBUF,comprompt
	jnz .done

	;extract the address of csv's to global memory
	push COMPROMPTBUF  ;parent string
	push COMMA         ;seperator
	push 3             ;max qty substrings
	push _ddstor       ;storage for substring address
	call splitstr      ;returns eax=qty substrings

	cmp eax,3          ;must find 3 substrings
	jnz near .error


	;substr1 = Address
	mov esi,COMPROMPTBUF
	call str2eax
	jnz .done
	mov esi,eax  ;esi=address

	;substr2 = qtyblocks
	mov esi,[_ddstor]
	call str2eax     ;eax=qtybytes user entered
	jnz .done
	call bytes2blocks
	mov ecx,eax      ;ecx=qtyblocks

	;substr3 = LBAstart
	mov esi,[_ddstor+4]
	call str2eax   
	jnz .done

	;copy to pen drive
	;esi=memory address
	mov ebx,eax  ;LBAstart
	;ecx=qtyblocks
	call write10
	;sets ZF on error, no check here

.error:
.done:
	ret


