;tatOS/tlib/make.s

;a make utility for tatOS

;this version of make can handle 05 project files


;the make utility is for assembling a project consisting of multiple 
;source files. 

;This make utility performs the following actions:
;	1) allow the user to enter project filenames interactively
;      the files must all be located in the current working directory
;   2) execute "runmake" which does the following:
;  		* erase the public and extern symbol tables
;  		* load file1 & assemble, load file2 and assemble, ...
;  		* run tlink to bind all extern and public symbols in all files


;to enter filenames you press F1 or F2... then enter the filename
;then hit "enter" to close the edit control and update the filename in memory


;function keys assigned to each filename edit control
%define MAKEQTYFILENAMES 5
mkfil01 db 'F1',0
mkfil02 db 'F2',0
mkfil03 db 'F3',0
mkfil04 db 'F4',0
mkfil05 db 'F5',0


;storage for filenames 
;each filename may be max 11 chars in accordance with the tatOS fat16
;filesystem which conforms to dos 8.3 but merges them into 11 chars total
;file names are stored at 16 byte offsets in the "makefilename" buffer
;file01 = makefilename +  0
;file02 = makefilename + 16
;file03 = makefilename + 32
;and so forth...
makefilename times 100 db 0     ;100 bytes can store 6 file names




mkstr0 db 'runmake',0
mkstr1 db 'tatOS MAKE utility',0
mkstr6 db 'xxxxx',0
mkstr9 db 'F10 = run MAKE to build executable',0
mkstr10 db 'ESC = quit',0
mkstr11 db 'Enter asm code filenames:',0
mkstr12 db '[make] fatreadfile returns 0 file not found',0
mkstr13 db '[make] ttasm returns non-zero errorcode',0
mkstr14 db '[make] success',0
mkstr15 db '[make] tlink has errors',0
mkstr16 db '[make] fatreadfile failed to find file in cwd',0
mkstr17 db 'call ttasm',0
mkstr18 db 'call tlink',0
mkstr19 db '[make] erasing extern & public symbol tables',0
mkstr20 db '[make] fatreadfile failed, attempting to link',0



;storage for make filenames
;each filename is 11 char + 0 terminator
;filename_0  offset 0
;filename_1  offset 16
;filename_2  offset 32
;filename_3  offset 48
;      |      
;      |
;      V
;filename_n  offset n*16




;**************************************************
;make
;input: none
;return: none

;the user will interactively enter the name
;of up to X files in the current working directory
;that are to be assembled in sequence

;pressing F10 to runmake will cause the screen to scroll
;putscroll will display messages directly to the screen
;about the progress of each assembly and linking

;menu:
;F1 = enter name of file1
;F2 = enter name of file2
;F3 = enter name of file3
;F4 = enter name of file4
;      |
;      |
;      V
;Fn = enter name of filen

;F10 = run make
;**************************************************

make:

	;do not init the filenames to some dumy value
	;we want the users filename entries to be persistant
	;so next time user remakes the project he doesnt have
	;to re-enter all the filenames

.1: 
	;top of paint

	call backbufclear


	;display "tatOS make"
	push FONT01
	push 100    ;x
	push 100    ;y
	push mkstr1 ;address of string
	push 0xefff ;colors
	call puts


	;"Project filenames:"
	STDCALL FONT01,100,130,mkstr11,0xefff,puts


	;display the function key assignment along the left margin
	STDCALL FONT01,100,150,mkfil01,0xefff,puts  ;F1
	STDCALL FONT01,100,170,mkfil02,0xefff,puts  ;F2
	STDCALL FONT01,100,190,mkfil03,0xefff,puts  ;F3
	STDCALL FONT01,100,210,mkfil04,0xefff,puts  ;F4
	STDCALL FONT01,100,230,mkfil05,0xefff,puts  ;F5


	;display the filenames
	;the first time you run make
	;the filenames are all blank spaces
	mov eax,150 ;y
	mov ecx,MAKEQTYFILENAMES
	mov esi,makefilename
.2:
	push FONT01
	push 150  ;x
	push eax  ;y
	push esi  ;address of string
	push 0xefff  ;color
	call puts

	add eax,20  ;increment y
	add esi,16  ;increment to address of next filename string
	loop .2


	;draw some hlines under each makefilename
	;the origin of FONT01 is upper left and is 15 pixels hi
	;so we draw hline 15 pixels down
	mov ebx,150  ;x
	mov ecx,165  ;y
	mov edx,100  ;length
	mov esi,BLA  ;color
	call hline   ;file01

	mov ebx,150  ;x
	mov ecx,185  ;y
	mov edx,100  ;length
	mov esi,BLA  ;color
	call hline   ;file02

	mov ebx,150  ;x
	mov ecx,205  ;y
	mov edx,100  ;length
	mov esi,BLA  ;color
	call hline   ;file03

	mov ebx,150  ;x
	mov ecx,225  ;y
	mov edx,100  ;length
	mov esi,BLA  ;color
	call hline   ;file04

	mov ebx,150  ;x
	mov ecx,245  ;y
	mov edx,100  ;length
	mov esi,BLA  ;color
	call hline   ;file05






	;"F10 = run make"
	STDCALL FONT01,100,350,mkstr9,0xefff,puts

	;"ESC=quit"
	STDCALL FONT01,100,370,mkstr10,0xefff,puts


	call swapbuf  ;endpaint
	call getc  ;block waiting for keypress

	cmp al,ESCAPE
	jz near .done
	cmp al,F1
	jz near .doF1
	cmp al,F2
	jz near .doF2
	cmp al,F3
	jz near .doF3
	cmp al,F4
	jz near .doF4
	cmp al,F5
	jz near .doF5

	cmp al,F10
	jz near .runmake

	jmp .1


.doF1:
	;edit file01
	mov ebx,150    ;x
	mov eax,150    ;y
	mov ecx,11     ;maxnumchars
	mov edi,makefilename
	mov edx,0x00fbfdef ;colors
	call gets
	;the function exits on ESCAPE or ENTER
	;set   zf on success with ENTER key
	;clear zf on failure with ESCAPE key

	;need to message the filename string so it is exactly
	;11 chars long with appended spaces and 0 terminated
	mov eax,makefilename
	call fatprocessfilename
	jmp .1

.doF2:
	;edit file02
	mov ebx,150    ;x
	mov eax,170    ;y
	mov ecx,11     ;maxnumchars
	lea edi,[makefilename+16]
	mov edx,0x00fbfdef ;colors
	call gets

	lea eax,[makefilename+16]
	call fatprocessfilename
	jmp .1

.doF3:
	;edit file03
	mov ebx,150    ;x
	mov eax,190    ;y
	mov ecx,11     ;maxnumchars
	lea edi,[makefilename+32]
	mov edx,0x00fbfdef ;colors
	call gets

	lea eax,[makefilename+32]
	call fatprocessfilename
	jmp .1

.doF4:
	;edit file04
	mov ebx,150    ;x
	mov eax,210    ;y
	mov ecx,11     ;maxnumchars
	lea edi,[makefilename+48]
	mov edx,0x00fbfdef ;colors
	call gets

	lea eax,[makefilename+48]
	call fatprocessfilename
	jmp .1
	
.doF5:
	;edit file05
	mov ebx,150    ;x
	mov eax,230    ;y
	mov ecx,11     ;maxnumchars
	lea edi,[makefilename+64]
	mov edx,0x00fbfdef ;colors
	call gets

	lea eax,[makefilename+64]
	call fatprocessfilename
	jmp .1
	


.runmake:
	call runmake
	call getc  ;press any key to exit
	;fall thru
.done:
	ret





runmake:


	push ebp
	mov ebp,esp
	sub esp,8  ;space on stack for 2 locals
	;[ebp-4]   ;address of makefilename
	;[ebp-8]   ;makefile count

	STDCALL mkstr0,dumpstr

	push mkstr19
	call putscroll

	;erase the public symbol table
	call public_table_clear

	;erase the extern symbol table and links
	call extern_table_clear  

	;address of current makefilename being assembled
	mov dword [ebp-4],makefilename

	;init qty of file names to assemble/link
	mov dword [ebp-8],MAKEQTYFILENAMES


.1: ;top of loop


	;put the filename to the screen
	push dword [ebp-4]
	call putscroll

	;copy filename to FILENAME (fat.s buffer)
	push dword [ebp-4]
	push FILENAME
	call strcpy2


	;push destination memory address         [ebp+8]
	push 0x1990000   ;load file to this address for ttasm
	call fatreadfile
	;returns eax=filesize else 0 if file not found


	cmp eax,0
	jz near .2     ;file not found, so attempt to link the project 

	;0 terminate for the benefit of ttasm
	mov byte [0x1990000+eax],0

	;put a message to the screen that we are invoking ttasm
	push mkstr17
	call putscroll


	;invoke our assembler
	call ttasm
	;returns eax=address of string giving results of assemble
	;        ebx=dword [_errorcode]


	;display the ttasm results of the assembly string
	push eax
	call putscroll

	cmp ebx,0   ;check for non-zero ttasm errorcode
	jnz .error2


	;increment the address of makefilename
	add dword [ebp-4],16


	;decrement the file count
	sub dword [ebp-8],1
	jnz .1   

	jmp .3


	;*********************************

.2:
	;we got here after fatreadfile failed so 
	;we now attempt to link the project
	push mkstr20
	call putscroll

	;*********************************

.3:

	;invoke our linker to read the extern and public symbol tables
	;and patch addresses in the executable code
	push mkstr18
	call putscroll

	call tlink
	;return: ZF is set on error, clear on success
	jz .error3


	;if we got here all files assembled successfully and linked
	push mkstr14
	call putscroll

	jmp .done

.error1:
	push mkstr12
	call putscroll
	jmp .done
.error2:   ;ttasm assembly error-fatal
	push mkstr13
	call putscroll
	jmp .done
.error3:  ;tlink error
	push mkstr15
	call putscroll
	jmp .done
.error4:  ;fatreadfile failed 
	push mkstr16
	call putscroll
.done:
	mov esp,ebp  ;deallocate locals
	pop ebp
	ret


