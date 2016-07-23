;tatOS/tlib/getline.s

;general revision 6/27/12
;you can now put asm comments on the same line as the code

;************************************************
;getline

;reads an ascii text file 
;lines are terminated by NEWLINE/NL/0xa
;the file must be terminated with 0
;this function is customized for the ttasm assembler 

;copies bytes to a seperate buffer and 0 terminates by the following rules:
;  * if NL terminator is found stop reading and exit 
;  * if : colon is read, stop saving bytes but read to end of line 
;    this would indicate a code label
;    colon not allowed within ascii string bounded by ''
;    SPACE not allowed on code label line 
;  * if ; semicolon is read stop saving bytes but read to end of line (comment)
;  * if 80 chars have been read and not 0 terminator, quit with error
;  * if leading SPACE or TAB, ignore

;input
;esi=address of ascii source
;edi=address of buffer to copy bytes to

;return
;esi is incremented to the last byte fetched
;eax=return code:
;	0=successful copy, found NEWLINE, 0 terminated
;   1=blank line found
;	2=error:parse error or buffer full and not 0 terminated
;   3=found 0 (eof)
;   5=code_label: (string ends with colon:)

;we no longer return 4 comment line, its folded in with blank line
;this function will now silently eat up comment lines by itself
;or comments after a line of asm code

;locals:
destbuffer      dd 0
ReadWithoutSave db 0
FoundCodeLabel  db 0
HaveStartChar   db 0
HaveString      db 0
HaveSpace       db 0
glstr1          db 'getline return value',0
;************************************************

getline:

	push ebx
	push ecx
	push edx
	push edi

	cld

	;save start address of dest buffer
	mov [destbuffer],edi

	;init
	mov byte [ReadWithoutSave],0
	mov byte [FoundCodeLabel],0
	mov byte [HaveStartChar],0
	mov byte [HaveString],0
	mov byte [HaveSpace],0

	;max 80 chars read
	mov ecx,80



.nextchar:  ;top of loop

	lodsb   ;al=[esi], esi++
	
	;for each byte read decrement our counter
	dec ecx
	;if we got here we fetched 80 char without finding some end of line marker
	js near .parserror

	;now examine the byte
	cmp al,EOF  
	jz near .doEOF
	cmp al,NEWLINE  
	jz near .doNEWLINE
	cmp byte [ReadWithoutSave],1
	jz near .nextchar
	cmp al,COLON       
	jz near .doColon
	cmp al,SEMICOLON
	jz near .doReadToEOL
	cmp al,SINGLEQUOTE
	jz near .doString
	cmp al,SPACE
	jz near .doSpace
	cmp al,TAB
	jz near .doTab
	
.savebyte:
	;if we got here we have a valid char to save
	stosb    ;[edi]=al, edi++

	;indicate the first valid char of asm code has been found
	mov byte [HaveStartChar],1

	jmp .nextchar
	;end of loop
	



.doString:
	mov byte [HaveString],1
	jmp .savebyte


.doTab:
.doSpace:
	mov byte [HaveSpace],1
	cmp byte [HaveStartChar],1
	jz .savebyte
	jmp .nextchar  ;this will eliminate leading space or tab
	

.doColon:
	;if we found a previous SPACE on a line with : this will be treated as error
	;this fixes an error like this jmp MyLabel: which will not assemble to jmp
	;another example that will not be allowed is this
	;db 'line: left click 1st point',0 
	cmp byte [HaveSpace],1
	jz .parserror
	;if we have a previous string marker 0x27 ' this is not a code label 
	cmp byte [HaveString],1
	jz .savebyte
	;otherwise we have a code label
	mov byte [FoundCodeLabel],1

.doReadToEOL:
	;parse the remainder of the source string without saving to dest buffer
	mov byte [ReadWithoutSave],1
	jmp .nextchar


.doNEWLINE:
	;check if this was a code label
	cmp byte [FoundCodeLabel],1
	jz .codelabel

	;check for a short line 
	;any line of less than 3 chars we will treat like a blank/comment line
	mov eax,edi
	sub eax,[destbuffer]
	sub eax,3
	js .blankline

	;this is an ordinary line of asm code with NL terminator
	jmp .success
	

.codelabel:
	mov eax,5
	jmp .done

.doEOF:
	mov eax,3         ;return found eof
	jmp .done

.parserror:
	mov eax,2         ;return error 
	jmp .done

.blankline:
	mov eax,1
	jmp .done

.success:
	mov eax,0         ;return success

.done:
	mov byte [edi],0          ;terminate dest string 
	;STDCALL glstr1,0,dumpeax  ;for debug only

	pop edi
	pop edx
	pop ecx
	pop ebx
	ret



