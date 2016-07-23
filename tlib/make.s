;tatOS/tlib/make.s

;a make utility for tatOS


;makeDialog
;EditMakeFileName
;LoadMakefile
;make



;the make utility is for assembling a project consisting of multiple 
;source files. 

;we currently support up to 12 project files (MAKEMAXQTYFILES)
;if the makefile contains more than this, the makeDialog will truncate the list
;and display an error message.

;This make utility performs the following actions:
;	* user should open a makefile, this will set dword [qtyMakefiles]
;      and populate the makeDialog accordingly
;	* allow the user to edit project filenames interactively
;      the files must all be located in the current working directory
;   * execute "make" which does the following:
;  		* erase the public and extern symbol tables
;  		* load file1 & assemble, load file2 and assemble, ...
;  		* run tlink to bind all extern and public symbols in all files

;to edit filenames you press F1 or F2... then enter the filename
;then hit "enter" to close the edit control and update the filename in memory


;the actual number of files to be assembled 
;is determined after you open a makefile
;the number is between 2->MAKEMAXQTYFILES
;this value is set to 0 in tatOSinit.s on boot
qtyMakefiles dd 0

;function keys assigned to each filename edit control
%define MAKEMAXQTYFILES 12
%define YLOCATIONFIRSTFILENAME 250

;menu strings
mkfil01 db 'F1',0
mkfil02 db 'F2',0
mkfil03 db 'F3',0
mkfil04 db 'F4',0
mkfil05 db 'F5',0
mkfil06 db 'F6',0
mkfil07 db 'F7',0
mkfil08 db 'F8',0
mkfil09 db 'F9',0
mkfil10 db 'F10',0
mkfil11 db 'F11',0
mkfil12 db 'F12',0

FunctionKeyStringTable:
dd mkfil01, mkfil02, mkfil03, mkfil04, mkfil05, mkfil06
dd mkfil07, mkfil08, mkfil09, mkfil10, mkfil11, mkfil12




;storage for filenames 
;each filename may be max 11 chars in accordance with the tatOS fat16
;filesystem which conforms to dos 8.3 but merges them into 11 chars total
;file names are stored at 16 byte offsets in the "makefilebuf" buffer
;each filename is mess-aged to 11 char + 0 terminator
;file01 = makefilebuf +  0
;file02 = makefilebuf + 16
;file03 = makefilebuf + 32
;and so forth...

%define SIZEOFMAKEFILEBUF 400
%define SIZEOFMAKEFILEBUFLESS16 400-16
makefilebuf times SIZEOFMAKEFILEBUF db 0     

;used by getline
makelinebuf times 100 db 0

makeTooManyFiles dd 0


mkstr0 db 'make',0
mkstr1 db 'tatOS MAKE utility',0
mkstr8  db 'l = Load a makefile',0
mkstr9  db 'm = run MAKE to build executable',0
mkstr10 db 'ESC = quit',0
mkstr11 db 'Load a makefile, edit names as reqd',0
mkstr12 db '[make] fatreadfile returns 0 file not found',0
mkstr13 db '[make] ttasm returns non-zero errorcode',0
mkstr14 db '[make] success',0
mkstr15 db '[make] tlink has errors',0
mkstr16 db '[make] fatreadfile failed to find file in cwd',0
mkstr17 db 'call ttasm',0
mkstr18 db 'call tlink',0
mkstr19 db '[make] erasing extern & public symbol tables',0
mkstr20 db '[make] fatreadfile failed, attempting to link',0
mkstr21 db 'LoadMakefile',0
mkstr22 db '[LoadMakefile] getline return value',0
mkstr23 db '[LoadMakefile] getline returns error',0
mkstr24 db 'qtyMakefiles',0
mkstr25 db '[LoadMakefile] error file not found',0
mkstr26 db '[LoadMakefile] alloc failed',0
mkstr27 db '[LoadMakefile] getline error',0
mkstr28 db '[LoadMakefile] address of source for getline',0
mkstr29 db 'error-makefile exceeds MAKEMAXQTYFILES - truncating',0








;**************************************************
;makeDialog

;input: none
;return: none

;[F9]the user should first load a makefile from flash
;then the user may interactively edit any filename
;typically the last filename is the one that changes
;since it is the one currently being developed

;[F10]make will cause the screen to scroll
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

makeDialog:

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


	;"Enter asm code filenames:"
	STDCALL FONT01,100,130,mkstr11,0xefff,puts

	;"Load Makefile"
	STDCALL FONT01,100,150,mkstr8,0xefff,puts

	;"run make to build executable"
	STDCALL FONT01,100,170,mkstr9,0xefff,puts

	;"ESC = quit"
	STDCALL FONT01,100,190,mkstr10,0xefff,puts

	;display the qty Makefiles
	;this value is set by loading a makefile manually off flash
	mov eax,[qtyMakefiles]
	STDCALL 100,210,0xefff,mkstr24,puteaxstr

	;the file names are displayed on screen starting at YLOCATIONFIRSTFILENAME


	;if user has not loaded a makefile yet we skip this drawing code
	cmp dword [qtyMakefiles],0
	jz near .5


	;if the makefile contains more than MAKEMAXQTYFILES, we truncate
	cmp dword [qtyMakefiles],MAKEMAXQTYFILES
	jbe .15
	mov dword [qtyMakefiles],MAKEMAXQTYFILES  ;truncate
	STDCALL FONT01,20,20,mkstr29,0xf5ff,puts  ;error message



.15:

	;display the F1,F2,F3... function key assignment along the left margin
	;user will press a function key to edit/enter a filename
	mov ecx,0
	mov ebx,YLOCATIONFIRSTFILENAME
.2:
	push FONT01
	push 100  ;x
	push ebx  ;y
	push dword [FunctionKeyStringTable + ecx*4]  ;address of string to display
	push 0xefff  ;color
	call puts
	add ebx,20   ;y+=20
	inc ecx
	cmp ecx,[qtyMakefiles]  ;project may have fewer files dword [qtyMakefiles]
	jb .2




	;draw some hlines under each make filename
	mov eax,[qtyMakefiles]
	lea ecx,[YLOCATIONFIRSTFILENAME+15]
.3:
	mov ebx,150  ;x
	mov edx,100  ;length
	mov esi,BLA  ;color
	call hline   ;file01
	add ecx,20   ;y+=20
	dec eax
	jnz .3




	;display the filenames
	mov eax,YLOCATIONFIRSTFILENAME
	mov ecx,[qtyMakefiles]
	mov esi,makefilebuf
.4:
	push FONT01
	push 150  ;x
	push eax  ;y
	push esi  ;address of string
	push 0xefff  ;color
	call puts
	add eax,20  ;y+=20
	add esi,16  ;increment to address of next filename string
	loop .4


	
.5:
	call swapbuf  ;endpaint
	call getc     ;block waiting for keypress in al

	cmp al,ESCAPE ;quit
	jz near .done

	cmp al,0x6c   ;'l'
	jz near .LoadMakefile

	cmp al,0x6d   ;'m'
	jz near .make


	;allow user to edit a makefile name
	;if we got here the user most likely entered F1->Fn to edit a file name
	;check that the getc return value is between 0 and dword [qtyMakefiles]
	xor ecx,ecx
	mov cl,al
	sub ecx,0x80   ;F1=0x80
	js .1          ;SF is set, subtraction is (-), user pressed a key with value <0x80 
	cmp ecx,[qtyMakefiles]
	jge .1

	;ecx=0,1,2,3... file name index
	call EditMakeFileName
	jmp near .1  ;top of loop


.LoadMakefile:
	call LoadMakefile
	jmp near .1  ;top of loop

.make:
	call make
	call getc  ;so user can see the ttasm/tlink messages scrolled
	jmp near .1  ;top of loop

.done:
	;have to press ESC to get here
	ret





;****************************************************
;EditMakeFileName

;a proc to allow user to edit 
;the name of a file in the make list

;input: ecx=0,1,2,3,4...n  FileNameIndex
;return:none

MakeTwenty dd 20
;****************************************************

EditMakeFileName:

	push ebp
	mov ebp,esp
	sub esp,8         ;create space on stack for 2 dwords
	mov [ebp-4],ecx   ;save n=FileNameIndex


	;compute 16*n and save
	mov eax,2
	shl eax,3        ;eax=16
	xor edx,edx
	mul ecx          ;eax=16*n
	mov [ebp-8],eax  ;save 16n for later


	;address of make filename storage
	lea edi,[makefilebuf+eax]


	;y=YLOCATIONFIRSTFILENAME + 20*n
	mov eax,ecx             
	xor edx,edx
	mul dword [MakeTwenty]           ;eax=20*n
	add eax,YLOCATIONFIRSTFILENAME   ;y=eax=YLOCATIONFIRSTFILENAME + 20*n 


	;call it
	mov ebx,150        ;x
	mov ecx,11         ;maxnumchars
	mov edx,0x00fbfdef ;colors
	call gets
	jnz .done  ;user hit ESC


	;need to mess-age what the user entered
	;filename string must be exactly 11 chars long with appended spaces and 0 terminated
	mov eax,makefilebuf
	add eax,[ebp-8]  ;eax=makefilebuf+16*n
	call fatprocessfilename

.done:
	mov esp,ebp  ;deallocate locals
	pop ebp
	ret





;********************************************
;make

;read filenames, load files, assemble & link
;feedback messages are scrolled on screen

;input:global "makefilebuf" holds filenames
;      global dword qtyMakefiles must be set 
;      by loading a makefile off flash first
;return:none
;*******************************************

make:

	push ebp
	mov ebp,esp
	sub esp,8  ;space on stack for 2 locals
	;[ebp-4]   ;address of makefilebuf
	;[ebp-8]   ;makefile count

	STDCALL mkstr0,dumpstr

	push mkstr19
	call putscroll

	;erase the public symbol table
	call public_table_clear

	;erase the extern symbol table and links
	call extern_table_clear  

	;address of current makefilename being assembled
	mov dword [ebp-4],makefilebuf

	;init qty of file names to assemble/link
	mov eax,[qtyMakefiles]
	mov dword [ebp-8],eax


.1: ;top of loop


	;put the filename to the screen
	push dword [ebp-4]
	call putscroll

	;copy filename to FILENAME (fat.s buffer)
	push dword [ebp-4]
	push FILENAME
	call strcpy2


	;load file off flash to memory
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


	;increment the address of makefilebuf
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




;****************************************************
;LoadMakefile

;allows the user to open a makefile
;the contents of this file is a formatted listing
;of project files. This saves on typing file names
;into the make dialog box.

;input: the filechooser dialog is displayed
;       user must select a makefile
;return:file names are populated into the make dialog

;the format of the makefile is as follows:
;one or more asm comment lines which begin with a semi colon in the first byte
;then follow the file name strings, one file name string per line
;***************************************************

LoadMakefile:

	push ebp
	mov ebp,esp
	sub esp,4  ;allocate locals on the stack

	STDCALL mkstr21,dumpstr

	mov dword [makeTooManyFiles],0

	;load file chooser dialog, let user pick a makefile
	mov ebx,0
	call filemanager
	jz near .done  ;user hit ESC

	;11 char 0 terminated filename is stored at address FILENAME


	;allocate memory to store the file
	mov ecx,0x10000  ;65,000 bytes should be plenty
	call alloc
	jz near .allocfailed
	;esi=memory address allocated
	mov [ebp-4],esi  ;save for later



	;load the file
	push esi
	call fatreadfile
	;returns eax=filesize else 0 if not found
	;esi is preserved
	cmp eax,0
	jz near .notfound



	;terminate the file with 0 for the benefit of getline
	;esi=address start of memory block
	lea edi,[esi+eax]  ;edi=address end of memory block
	mov byte [edi],0


	;zero out the qtyMakefiles
	mov dword [qtyMakefiles],0


	;start of loop to read the make file
	;edx must be preserved in this loop
	;we inc edx by 16 bytes for every filename read
	xor edx,edx

.1:

	;dump the address of getline source for debug
	mov eax,esi
	STDCALL mkstr28,0,dumpeax
	
	;read comment lines and return first filename
	;esi=address of source 
	;esi is incremented by getline and this must be preserved
	;for the next getline read
	mov edi,makelinebuf  ;line buffer storage
	call getline      
	;esi is incremented
	;eax return code

	;dump the getline return value
	STDCALL mkstr22,0,dumpeax

	cmp eax,0  ;successful copy
	jz .2
	cmp eax,1  ;blank line
	jz near .1
	cmp eax,2  ;error
	jz near .getlineerror
	cmp eax,3  ;eof/normal exit/found 0 terminator
	jz near .done
	cmp eax,5  ;code label
	jz near .getlineerror
	jmp near .getlineerror ;justincase



.2: ;successful line has been read

	;dump the line read for debug
	STDCALL makelinebuf,dumpstrquote


	;need to mess-age what the user entered
	;filename string must be exactly 11 chars long with appended spaces and 0 terminated
	mov eax,makelinebuf  
	call fatprocessfilename


	;copy filename string to makefilebuf
	push makelinebuf             ;source
	lea edi,[makefilebuf + edx]  ;dest
	push edi
	call strcpy2



	;inc the qty of makefiles
	add dword [qtyMakefiles],1


	;check to be sure we have not exceeded allowable number of  project files
	cmp dword [qtyMakefiles],MAKEMAXQTYFILES
	jbe .3
	;error - too many files in makefile
	mov dword [makeTooManyFiles],1
	jz .done


.3:
	;inc to start of next file name in "makefilebuf" buffer
	add edx,16  

	;check to make sure we still have room in the buffer for more filenames
	cmp edx,SIZEOFMAKEFILEBUFLESS16
	jb .1     ;get the next line



.getlineerror:
	STDCALL mkstr27,dumpstr
	jmp .done
.allocfailed:
	STDCALL mkstr26,dumpstr
	jmp .done
.notfound:
	STDCALL mkstr25,dumpstr
	jmp .done
.done:
	mov esi,[ebp-4]
	call free
	;do not put a call to dumpmem in here, it will mess up the alloc ptrs (not sure why)
	mov esp,ebp  ;deallocate locals
	pop ebp
	ret






