;tatOS/tlib/tedit.s   
;rev Dec 2015


;this determines where the left margin starts if using line numbering
;TEDITSHOWLINENUMBERS is defined in tatOS.config
;with the left margin at 50 and each char of FONT01 occupying 10 pixels
;this takes away 5 chars in the line leaving you with 75 chars per line
;if a line has more than 75 chars text will wrap
%if TEDITSHOWLINENUMBERS    ;defined in tatOS.config
	%define TEDITLEFTMARGIN 50
%else
	%define TEDITLEFTMARGIN 0
%endif



;***********************************************************
;TEDIT

;this is the text editor for tatOS
;see /doc/tedit-help 

;tedit uses a double link list starting at 0x100000
;1meg is reserved allowing for 750,000 max chars per file

;CUT/COPY/PASTE is same as windows CTRL+X, CTRL+C, CTRL+V
;selection is made with SHIFT down and moving arrow keys
;Ctrl+y yanks/copies a single word at the caret to CLIPBOARD 

;scrolling is done with the arrow keys, PAGEUP, PAGEDN, HOME, END
;thru the manipulation of the "toplink"
;toplink is the address of the first char drawn at upper left

;Ctrl+f to enter a string to find/search 
;Ctrl+n to find the next instance
;Ctrl+8 jumps to the next instance of word at caret, then Ctrl+n

;Goto is handled with Ctrl+g to jump to a line number

;there are several options to delete characters:
;Delete 1 character at the caret
;Ctrl+Delete delete 1 word
;Alt+Delete  delete a large block of chars from starting charnum to caret
;Shift+Arrows then Delete the selection

;by default tedit file->open appends data to the existing link list at the caret
;unless you press F7 to clear first. 
;if your usb File->save fails you can reinit the controller and flash
;and return to your tedit memory block and repeat the save

;each tedit link is 12 bytes:
;  byte char     (this is the ascii keypress)
;  byte select   (1=selected, 0=not selected)
;  word unused   (added to keep dword alignment
;  dword prev    (address of prev char link)
;  dword next    (address of next char link)

;if ebp holds address of a link then:
; byte  [ebp]   = the ascii char
; byte  [ebp+1] = selected or not
; dword [ebp+4] = address of previous link
; dword [ebp+8] = address of next link

;messagepointer
;to display a 0 terminated string along the bottom of the screen
;do mov dword [messagepointer],AddressofMyString
;on the next paint cycle your message will show up
;***********************************************************


tedit:

	;the link list is initialized in tatOSinit.s 
	
	;reset default Yaxis orientation to topdown
	mov dword [YORIENT],1 

	;reset the default X,Y global offsets
	mov dword [XOFFSET],0
	mov dword [YOFFSET],0


	;queue up a usb keyboard request
	;this version of tedit uses the usb keyboard
	call usbkeyboardrequest


	call tedit_paint

	

;**************************************************************
;          APP_MAIN_LOOP
;**************************************************************


tedit_app_main_loop:



	call getc
	;returns ascii keydown in al



	cmp byte [CTRLKEYSTATE],1
	jnz .doneCTRLcheck

	cmp al,'f'
	jz near te_doFind
	cmp al,'n'
	jz near te_doNext
	cmp al,'g'
	jz near te_doGoto
	cmp al,'y'
	jz near te_doYankWord
	cmp al,'8'
	jz near te_doYankFindNext
	cmp al,F1
	jz near te_doRead10

	;some other Ctrl key combination we dont support
	jb near tedit_endkeypress

.doneCTRLcheck:



	;keys below TAB are excluded
	cmp al,TAB
	jb near tedit_endkeypress

	;keys from 0x20 -> 0x7f are included in link list
	cmp al,0x7f
	jbe near insertnewlink 

	;we have a keypress > 0x7f
	;deal with the nonprintables via our jumptable (0x80 & greater)
	xor edx,edx
	mov dl,al

	;convert nonprintable into jumptable index
	;0x80 comes from tatOS.inc where we arbitrarly assign
	;F1 key = 0x80, F2=0x81 ... and increment from there
	;so when you press F1 we subtract 0x80 to get 0 which is the
	;index of F1 in the jump table
	sub edx,0x80 

	;now jump to one of the cases listed below
	;each case label is listed in the jumptable
	;each block of code must end with "jmp near tedit_endkeypress"
	jmp near [teditjumptable + edx*4]




	;*****************
	;case: CUT
	;*****************
te_doCut:
	call Copy2Clip
	call DeleteSelections
	jmp near tedit_endkeypress


	;*****************
	;case: COPY
	;*****************
te_doCopy:
	call Copy2Clip
	call UnselectAll
	jmp near tedit_endkeypress


	;*****************
	;case: PASTE
	;*****************
te_doPaste:
	;insert clipboard at caret
	mov edi,0x1300004    ;edi=start of clipboard data
	mov ecx,[CLIPBOARD ]  ;ecx=qty bytes in clipboard

	;we limit the amount of pasteable bytes 
	;this was introduced because I was on occasion
	;crashing the system for some unknown reason
	;perhaps the value in ecx was negative ???
	cmp ecx,0
	seta dl
	cmp ecx,20000  ;littlebits PASTE needs more than 10,000 bytes
	setb dh
	add dl,dh
	cmp dl,2
	jz .continuePaste

	;error:we have less than 0 or more than 20,000 bytes to paste
	STDCALL te_str13,dumpstr
	jmp near tedit_endkeypress
	
.continuePaste:
	mov ebp,[caretlink]
	call PreviousLink
.pasteloop:
	mov al,[edi]
	call InsertNewLink
	inc edi
	loop .pasteloop
	;want caret to stay at beginning of paste group
	;where InsertNewLink would push it to the end
	mov [caretlink],ebp
	
.donepaste:
	jmp near tedit_endkeypress
	
	
	

	;*****************
	;case: LEFT arrow
	;*****************
te_doLeft:
	call CaretPreviousLink
	jmp near tedit_endkeypress
	


	;*****************
	;case: RIGHT arrow
	;*****************
te_doRight:
	cmp byte [SHIFTKEYSTATE],1
	jnz .noselect
	call SelectCaretLink
.noselect:
	call CaretNextLink
	jmp near tedit_endkeypress



	;***************
	;case: UParrow
	;****************
te_doUp:
	call CaretPreviousEOL
	call GetBOL
	cmp dword [carety],0
	jnz near tedit_endkeypress
	mov [toplink],ebp
	jmp near tedit_endkeypress


	
	;***************
	;case: DOWNarrow
	;****************
	;this routine does not properly scroll the text up
	;if the bottom line on the screen contains more than 80 char
te_doDown:
	cmp byte [SHIFTKEYSTATE],1
	jnz .noselect
	mov al,1
.noselect:
	mov ebp,[caretlink]
	cmp byte [ebp],NEWLINE
	jz .down1line
	;if we are in the middle of a line
	;we need to advance the caret by 2 NEWLINE chars
	call CaretNextEOL
.down1line:
	call CaretNextEOL
	jmp near tedit_endkeypress



	;****************************
	;case: PAGEUP
	;****************************
te_doPageUP:
	;we can only display 39 lines
	;we jump 1 less than that
	mov ecx,38 
.pageup:
	call CaretPreviousEOL
	loop .pageup
	mov [toplink],ebp
	jmp near tedit_endkeypress




	;****************************
	;case: PAGEDN
	;****************************

te_doPageDN:
	mov ecx,38
.1:
	call CaretNextEOL
	loop .1
	mov [toplink],ebp
	jmp near tedit_endkeypress



	;*****************************
	;case: ESCAPE 
	;*****************************

te_doEscape:
	call UnselectAll
	jmp near tedit_endkeypress
	
	


	;*********************************
	;case: HOME 
	;*********************************

te_doHome:
	cmp byte [CTRLKEYSTATE],1
	jnz .noctrlhome
	;Ctrl+HOME
	;beginning of link list
	mov dword [caretlinecount],0
	mov ebp,[headlink]
	mov [caretlink],ebp
	mov [toplink],ebp
	jz near tedit_endkeypress
.noctrlhome:
	
	;HOME (beginning of line)
	mov ebp,[caretlink]
	call GetBOL
	mov [caretlink],ebp
	jmp near tedit_endkeypress





	;**********************
	;case: END
	;**********************

te_doEnd:

	cmp byte [SHIFTKEYSTATE],1
	jnz .doneshiftend

	;Shift+END
	;select from caret to end of line
	mov al,1 ;select as we go
	call CaretNextEOL
	jz near tedit_endkeypress

.doneshiftend:


	cmp byte [CTRLKEYSTATE],1
	jnz .donectrlend

	;Ctrl+END
	;display the last page (39) lines of text in the file
	
	;first get metrics for numlines
	call ComputeMetrics  

	;if numlines in the file is < 39 were done
	cmp dword [numline],39
	jb .doneEnd

	;set caretlink == taillink and caretlinecount==numline
	;then backup 39 lines
	mov eax,[taillink]
	mov [caretlink],eax
	mov ebx,[numline]
	mov [caretlinecount],ebx

	cld
	mov ecx,39  ;ecx should be preserved by CaretPreviousLink
.backupCaret:
	call CaretPreviousEOL
	loop .backupCaret

	;go to beginning of next line and set toplink and caretlink
	call CaretNextLink
	mov [toplink],ebp

	jmp near tedit_endkeypress
.donectrlend:



	;just the END key has been pressed, mov to end of line
	mov al,0
	call CaretNextEOL

.doneEnd:
	jmp near tedit_endkeypress



	;******************
	;case: DELETE
	;******************

te_doDelete:


	;delete all selected links
	;****************************
	cmp dword [qtyselected],0
	jz .nodelsel
	call DeleteSelections
	jmp near tedit_endkeypress
	.nodelsel:


	;CTRL+Delete
	;delete from caret to next space (i.e. delete word)
	;****************************************************

	cmp byte [CTRLKEYSTATE],1
	jnz .nodeleteword
	mov ebp,[caretlink]
.delnextlink:
	call DeleteLink	
	call NextLink
	cmp ebp,[taillink]    ;test for taillink
	jz .donedeleteword
	;test for various end of word markers
	;we will say that any ascii char less than 48 
	;is a valid end-of-word marker
	cmp byte [ebp],48
	jae .delnextlink
.donedeleteword:
	jmp near tedit_endkeypress
.nodeleteword:



	;ALT+Delete
	;delete a large block of bytes bounded by starting bytenum and caret
	;user is prompted to enter starting bytenum (use F3 metrics)
	;**************************************************************

	cmp byte [ALTKEYSTATE],1
	jnz .endblockdelete

	;prompt user to enter starting bytenum 
	STDCALL te_str20,COMPROMPTBUF,comprompt

	;get the starting bytenum in eax 
	mov esi,COMPROMPTBUF
	call str2eax
	jnz near .endblockdelete
	mov ebx,eax       ;ebx=starting bytenum 

	;go thru the link list and find the address of starting bytenum
	mov ebp,[headlink]
	mov ecx,0
.nextlink: 
	mov ebp,[ebp+8]       ;ebp=next link
	inc ecx               ;increment qty bytes counted
	cmp ebx,ecx           ;check if weve counted to the starting bytenum
	jz .2                 ;done,ebp=address of starting bytenum
	cmp ebp,[caretlink]   ;check if weve counted to the caret link
	jz .endblockdelete    ;error,counted to caret link
	cmp ebp,0             ;check for tail link
	jnz .nextlink

	;if we got here there is a problem
	;we counted all the way to the end of the link list
	jmp .endblockdelete

.2: 
	;ebp=address of starting bytenum to delete
	mov edi,[caretlink]
	mov edi,[edi+4]  ;edi=link before caret, dont delete caret

.3:	;delete all links from ebp to caretlink
	call DeleteLink  ;ebp=link to delete
	mov ebp,[ebp+8]  ;get next link
	cmp ebp,edi      ;are we done ?
	jz .endblockdelete
	cmp ebp,0        ;test for end of list
	jnz .3
.endblockdelete:



	;delete a single char at caret 
	;*******************************
	mov ebp,[caretlink]
	call DeleteLink	
	jmp near tedit_endkeypress




	;**********************
	;case: ENTER
	;**********************
te_doEnter:
	mov al,NEWLINE
	call InsertNewLink
	inc dword [caretlinecount]
	cmp dword [carety],560
	jb near tedit_endkeypress
	call TopNextBOL
	jmp near tedit_endkeypress



	;******************
	;case: BACKSPACE
	;******************
te_doBkspace:
	;delete the previous link
	mov ebp,[caretlink]
	cmp ebp,[headlink]
	jz near tedit_endkeypress  
	mov ebp,[ebp+4]  ;prev link
	call DeleteLink	
	jmp near tedit_endkeypress



	;***********************
	;case: unsupported keys
	;***********************
te_doNot:
	jmp near tedit_endkeypress




	;***************************************
	;case: F1
	;F1=Read tatOS FAT16 file off Pen Drive
	;***************************************
	
te_doF1:

	;user to select a file to open
	mov ebx,0  ;list/display/select files only
	call filemanager
	jz .userHitEscape
	;otherwise the 11char filename string is at FILENAME


	;check that the file does not exceed 700,000 bytes ??
	;check that the file is a text file ??


	;save the filename for the benefit of metrics
	STDCALL FILENAME,currentfilename,strcpy2


	;allocate scratch memory for fatreadfile to copy file data to
	;we dont know how big the file is but we just allocate 1meg which is max
	mov ecx,0x100000
	call alloc  ;esi is pointer to scratch memory
	jz .allocfailed


	;load the FAT16 file
	push esi            ;dest memory address
	call fatreadfile    ;returns eax=filesize
	cmp eax,0           ;fatloadfile failed, filesize is 0
	jz .failed


	;if we dont blank the tedit link list
	;the new file will be inserted at the caret
	;this is useful for bringing in data from another file
	;if you dont like this just press F7 to clear beforehand

	;convert ascii array to tedit link list
	;esi = address of file bytes returned from alloc
	mov ecx,eax        ;filesize
	call TeditLinkListGen


.success:
	call free  ;esi = pointer to scratch memory
	jmp .done
.failed:
	mov dword [messagepointer],te_str6
	call free  ;esi = pointer to scratch memory
.allocfailed:
.userHitEscape:
.done:
	mov dword [caretlinecount],0
	jmp near tedit_endkeypress



	;***************************************
	;case: Ctrl+F1
	;F1=Read10 ascii bytes Pen Drive
	;***************************************
	
	;this is undocumented functionality
	;the user may load some ascii bytes off flash using read10
	;in case there was some previous error in the filesytem
	;the user is prompted to provide LBAstart & qtyblocks to read
	;to convert starting cluster number to LBAstart see fat16.s

te_doRead10:

	;prompt user to enter LBAstart & qtyblocks
	STDCALL te_str14,COMPROMPTBUF,comprompt


	;extract the address of csv's to teditbuf
	push COMPROMPTBUF  ;parent string
	push COMMA         ;seperator
	push 2             ;max qty substrings
	push teditbuf      ;storage for substring address
	call splitstr      ;returns eax=qty substrings

	cmp eax,2          ;must find 2 substrings
	jnz near .error

	;substr1 = LBAstart
	mov esi,COMPROMPTBUF
	call str2eax
	jnz near .error
	mov ebx,eax       ;ebx=LBAstart

	;substr2 = qtyblocks
	mov esi,[teditbuf]
	call str2eax     
	jnz near .error
	;eax=qty blocks


	;allocate scratch memory for fatreadfile to copy file data to
	;we dont know how big the file is but we just allocate 1meg which is max
	mov ecx,0x100000
	call alloc  ;esi is pointer to scratch memory
	jz near .error


	;ebx=LBAstart
	mov ecx,eax   ;qty blocks
	mov edi,esi   ;destination address
	call read10


	;convert ascii array to tedit link list
	;esi = address of file bytes returned from alloc
	shl ecx,9   ;qtybytes = qtyblocks * 512
	call TeditLinkListGen

	
.error:
	call free  ;esi is pointer to memory block allocated
	mov dword [caretlinecount],0
	jmp near tedit_endkeypress






	;**************************************
	;case: F2 
	;F2=Write tatOS FAT16 file to Pen Drive
	;**************************************
	
te_doF2:

	STDCALL te_str8,dumpstr

	;prompt user to enter 11 char filename and store at COMPROMPTBUF
	push te_str8
	call fatgetfilename
	jnz near .userHitEscape

	;save the filename for the benefit of metrics
	STDCALL COMPROMPTBUF,currentfilename,strcpy2

	;get number of bytes in link list dword [numbyte]
	call ComputeMetrics

	;alloc 1meg of scratch memory
	mov ecx,0x100000
	call alloc  ;esi=address of scratch memory
	jz .allocfailed


	;copy link list to scratch memory as ascii array
	mov ebp,[headlink]
	xor ecx,ecx           ;byte offset
.nextlink:
	mov al,[ebp]          ;get byte
	mov [esi+ecx],al      ;copy/transfer
	mov ebp,[ebp+8]       ;next link
	inc ecx               ;increment byte offset 
	cmp ebp,0             ;check for tail link
	jnz .nextlink

	;write the file to tatOS formatted flash drive
	push esi              ;address of file data
	push dword [numbyte]  ;filesize, bytes
	call fatwritefile

	cmp eax,0
	jz .successfulsave
	cmp eax,1
	jz .generalfailure
	cmp eax,2
	jz .filealreadyexists
	

.generalfailure:
	mov dword [messagepointer],te_str10
	call free  ;esi=address of scratch memory
	jmp .done
.filealreadyexists:
	mov dword [messagepointer],te_str11
	call free  ;esi=address of scratch memory
	jmp .done
.successfulsave:
	mov dword [messagepointer],te_str12
	call free  ;esi=address of scratch memory
.allocfailed:
.userHitEscape:
.done:
	jmp near tedit_endkeypress





	;*********************
	;case: F3 
	;show file metrics
	;*********************

te_doF3:

	;we build and display a formatted ascii string that looks like this:
	;"filename: caretbyte=123/456   line=012/345   ascii=20"
	;caretbyte = index of the caret from beginning of file / filesize
	;line = line number of the caret / total_qty_lines
	;ascii = ascii value of the caret byte

	call ComputeMetrics

	;get the ascii equivalent of the caret byte
	mov eax,[caretlink]
	movzx ebx,byte [eax]  ;get char
	mov [caretascii],ebx

	;build the printf string
	mov ecx,12           ;qty args
	mov ebx,te_metrics_argtype
	mov esi,te_metrics_arglist
	mov edi,feedbackbuf  ;dest buffer
	call printf

.done:
	mov dword [messagepointer],feedbackbuf
	jmp near tedit_endkeypress



	;*********************
	;case: F4 
	;invoke calculator
	;*********************


te_doF4:
	call calculator
	jmp near tedit_endkeypress



	;*******************************
	;case: Ctrl+f 
	;FIND
	;*******************************

	;first you press Ctrl+f to enter a search string
	;then press Ctrl+n repeatedly to scroll screen to next search string
	;if nothing found then screen will not scroll
	
te_doFind:

	;prompt user to enter search string
	STDCALL te_str4,COMPROMPTBUF,comprompt
	jmp near tedit_endkeypress



	;*******************************
	;case: Ctrl+n 
	;NEXT
	;*******************************

te_doNext:

	call FindNext
	jmp near tedit_endkeypress





	;*********************
	;case: Ctrl+g
	;GoTo Line#
	;*********************

te_doGoto:

	;prompt user to enter linenum
	STDCALL te_str15,COMPROMPTBUF,comprompt
	jnz near .done

	mov esi,COMPROMPTBUF
	call str2eax  
	;eax holds linenum
	jnz near .done

	;initialize	
	mov ebp,[headlink]  
	mov edx,0  ;edx=qty newline
	
.examine:
	mov bl,[ebp]  ;examine char

	cmp bl,NEWLINE
	jnz .not
	inc edx
	cmp edx,eax  ;are we there yet ?
	jb .not
	;found the line num
	mov [caretlink],ebp
	mov [toplink],ebp
	jmp .done
.not:
	
	cmp ebp,0
	jz .done

	mov ebp,[ebp+8]  ;next link
	jmp .examine

.done:
	call CaretNextLink
	jmp near tedit_endkeypress




	;*********************
	;case: F6
	;View the DUMP
	;*********************

te_doF6:
	call dumpview
	jmp near tedit_endkeypress




	;*********************
	;case: F7 
	;empty
	;*********************


te_doF7:
	jmp near tedit_endkeypress




	;*********************
	;case: F8 
	;clear the link list  
	;*********************

te_doF8:
	;this affectively erases the screen
	;do this before loading a new file to assemble
	call teditBlankList
	jmp near tedit_endkeypress




	;*********************
	;case: F9 
	;Assemble/Link
	;*********************

te_doF9:

	cmp byte [CTRLKEYSTATE],1
	jz .invoketlink 

	;first transfer the link list of assembler code
	;to 0x1990000 as an ascii array of bytes
	mov ebp,[headlink]
	xor ecx,ecx  ;qtybytes=0

.nextlink:
	mov al,[ebp]           ;get byte
	mov [0x1990000+ecx],al ;transfer
	mov ebp,[ebp+8]        ;next link
	inc ecx
	cmp ebp,0              ;tail ?
	jnz .nextlink
	
	mov byte [0x1990000+ecx],0 ;terminate

	;now call our assembler
	call ttasm 

	;return eax=address of string giving the 
	;results of the assembly
	mov dword [messagepointer],eax

	jmp near tedit_endkeypress


.invoketlink:

	;Ctrl+F9 = invoke tlink
	call tlink
	jz .1
	mov dword [messagepointer],te_str22
	jmp near tedit_endkeypress
.1: ;there are linker errors
	mov dword [messagepointer],te_str21
	jmp near tedit_endkeypress



	;*********************
	;case: F10
	;Make
	;*********************

te_doF10:
	;this allows you to enter file names interactively
	;and then run the make utility
	call make
	jmp near tedit_endkeypress




	;*********************
	;case: F11 
	;Execute/Run
	;*********************

te_doF11:

	;kernel startup code prior to calling sysexit to run the users app

	;check for a valid "start" value for startofexe
	;the first byte of executable code is defined by the symbol '..start'
	;a zero value is invalid, it must be between 0x2000010 and 0x23ff000
	mov esi,[0x2000008]
	push 0x2000010   ;min
	push 0x23ff000   ;max
	call checkrange
	jnz .error


	;init the mouse pointer to center of grid
	mov dword [MOUSEX],400
	mov dword [MOUSEY],300
	mov dword [mousey1],300


	;clear the dump of all the ttasm messages
	;let the app write to the dump its own messages
	;if you want to see the ttasm assembler messages
	;look at the dump before you "run"
	call dumpreset


	;queue up a usb mouse request just in case the app needs it
	call usbmouserequest


	;dump a message that we are about to do SYSEXIT
	STDCALL te_str9,dumpstr


	;set user data segment selectors
	;cs and ss are taken care of by sysexit (values in MSR's)
	mov ax,0x23
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax

	mov edx,[0x2000008]    ;start of user land code
	mov ecx,USERSTACKPTR   ;userland stack pointer
	sysexit

	;program execution continues at 0x1b:[0x2000008]
	;this is RPL=3 user land code
	;apps should not end with "ret" but with "exit"
	;apps may not call tlib functions directly
	;instead use sysenter, see tlibentry.s
	;interrupts are disabled 
	;now instructions in user code like cli will cause 
	;interrupt-13 General Protection Fault
	;because paging is enabled, apps may not read/write kernel code
	;see paging.s for what is kernel land and what is the user land

	;when the userland code is finished
	;the last instruction of userland as inserted by ttasm is "exit"
	;all userland apps must end with "exit"
	;"exit" is a sysenter instruction with eax=4 
	;this is tlibentry proc "_exit2tedit"
	;so we end up back at the start of tedit after user proc completes

.error:
	;silently exit, failed to start users exe
	jmp near tedit_endkeypress







	;*********************
	;case: F12 
	;quit tedit 
	;*********************


te_doF12:
	;note we do not use the normal call/ret between shell and tedit
	;from shell we jmp to tedit so we must jmp back to shell
	;this is to avoid messing up the kernel stack
	;since we use sysexit/sysenter between tedit and user app
	jmp shell




	;*********************
	;case: Ctrl+y
	;YANK Word
	;*********************

te_doYankWord:

	;copy a single word at caret to the teditbuf
	call YankWord

	;copy teditbuf to CLIPBOARD
	cld
	mov esi,teditbuf
	mov edi,CLIPBOARD
	mov ecx,[teditbuf]  ;first dword is strlen
	add ecx,4           ;accounts for first dword 
	rep movsb

	jmp near tedit_endkeypress



	;*********************
	;case: Ctrl+8
	;YANK-FIND-NEXT
	;*********************

	;this operation is similar to VIM
	;except in VIM we use Shift+* instead of Ctrl+8
	;yank a word at the caret
	;copy the word to the COMPROMPTBUF and 0 terminate
	;invoke FindNext to search for the word
	;user must continue with Ctrl+n after this

te_doYankFindNext:

	call YankWord

	;copy word to COMPROMPTBUF and 0 terminate
	mov ecx,[teditbuf]
	mov edx,ecx
	lea esi,[teditbuf+4] ;start of string
	cld
	mov edi,COMPROMPTBUF
	rep movsb

	;0 terminate
	mov byte [COMPROMPTBUF+edx],0

	call FindNext
	jmp near tedit_endkeypress




	;**********************************************
	;case: alloc & insert a single new ascii char
	;      al=ascii byte to insert
	;      unless CTRL is held down
	;**********************************************

insertnewlink:


	;al=ascii byte
	call InsertNewLink

	;scrollup if typing a char at lower left of screen
	cmp dword [carety],560
	jb tedit_endkeypress
	cmp dword [caretx],780
	jb tedit_endkeypress
	call TopNextBOL


tedit_endkeypress:
	call tedit_paint

	;provide alternate way to break out of tedit
	;this is for usb keyboard developement when we lock up the keyboards
	call usbcheckmouse
	cmp al,0
	jnz near shell

	jmp tedit_app_main_loop






;**********************************************************
;            PAINT ROUTINE
;**********************************************************

;there is room to display 39 lines of text on the screen
;the menu sits along the bottom just below the last line
;the caretlinecount is displayed right of the menu

tedit_paint:

	call backbufclear  


	
%if TEDITSHOWLINENUMBERS

	;count the number of lines to the toplink
	;this is for displaying line numbers in the left margin

	mov ebp,[headlink]  
	mov ecx,0               ;ecx=number of lines to toplink
.1:
	cmp ebp,[toplink]       ;test for toplink
	jz .donecount
	cmp ebp,0               ;test for end of link list 
	jz .donecount

	cmp byte [ebp],NEWLINE  ;test for newline
	jnz .notnl
	inc ecx                 ;increment newline count

.notnl:
	mov ebp,[ebp+8]         ;get address next link
	jmp .1

.donecount:
	;set the starting line number that will appear in the left margin
	;the very first line is 0 which is not displayed and the next line down is 1
	;this keeps the line numbering consistent with ComputeMetrics and GoTo Ctrl+g
	add ecx,1
	mov [linenumleftmargin],ecx
%endif




	;TOPLINK
	;the first char drawn at upper left
	;we use ebp to hold address of link being drawn
	mov ebp,[toplink]  



	;set initial x position of toplink char
	mov dword [xloc],TEDITLEFTMARGIN 

	;set initial y position of toplink char
	mov dword [yloc],0  ;top of screen




.topoflinkdrawloop:

	;this is the top of the loop 
	;for drawing each text char on the screen 


	;get x,y,and ascii char for putc
	mov esi,[xloc]  
	mov edi,[yloc]
	mov cl,[ebp]  

	;cl holds the ascii char 
	;so DONT USE ECX for anything in paint
	;unless you push/pop
	;also note that esi and edi are used below
	;to record the carety x,y location so these registers
	;must also be preserved



	;test for comment line
	cmp byte [ebp],';'
	jnz .notsemi
	mov dword [linecomment],1
.notsemi:



	;test for NEWLINE
	cmp cl,NEWLINE
	jnz .notnewline
	mov cl,SPACE   ;draw as space
	mov dword [haveNL],1
.notnewline:



	;test for TAB
	cmp cl,TAB
	jnz .nottab
	add dword [xloc],40 ;inc x by 4 spaces
	mov cl,SPACE   ;draw as space
.nottab:



	;test for caret 
	cmp ebp,[caretlink]
	jnz .notcaretlink 
	;set colors for caret
	mov dh,BLA ;text
	mov dl,RED ;back
	;save x,y location of caret
	mov [caretx],esi
	mov [carety],edi
	jmp .drawchar
.notcaretlink:


	;set colors for selected text
	cmp byte [ebp+1],1
	jnz .notselectedtext 
	mov dh,WHI ;text
	mov dl,BLA ;back
	jmp .drawchar
.notselectedtext:


	;set colors for comment line 
	cmp dword [linecomment],1
	jnz .notcomment
	mov dh,BLU  ;text
	mov dl,BKCOLOR  ;back
	jmp .drawchar
.notcomment:

	
.normalcolor:
	mov dh,BLA 
	mov dl,BKCOLOR


.drawchar:

	;set font
	mov ebx,FONT01

	;ebx=fontID, ecx=ascii char, edx=colors, esi=xloc, edi=yloc
	call putc



	;now we increment some things and prepare 
	;for the next link




.getnextlink:
	;get address of next link
	mov ebp, [ebp+8]   ;link=link->next 




	;NL
	;if we have a NEWLINE char
	;we must reset x,y 
	;and we must also display the line number in left margin if called for
	;and also increment this line number
	cmp dword [haveNL],1
	jnz .notnewline2

	mov dword [xloc],TEDITLEFTMARGIN
	add dword [yloc],15        ;y+=15
	mov dword [linecomment],0  ;clear for blue text
	mov dword [haveNL],0

%if TEDITSHOWLINENUMBERS
	;draw the line number in left margin
	;because we draw an entire line and then discover a NL char
	;the first line does not get a line number, but thats ok
	mov eax,[linenumleftmargin]
	push 0                    ;xloc
	push dword [yloc]         ;yloc
	push dword 0x11ff         ;colors
	push 0                    ;unsigned
	call puteaxdec
	;increment the line number to display
	add dword [linenumleftmargin],1
%endif

	jmp .checkyloc
.notnewline2:




	;increment x location of next char
	add dword [xloc],10      ;x+=10


	;test for char at right margin 
	cmp dword [xloc],790
	jbe .not2endofline
	mov dword [xloc],0
	add dword [yloc],15
.not2endofline:



	;we are done drawing when yloc>570 or we hit taillink
.checkyloc:
	cmp dword [yloc],570
	ja .savelastlink



	;check for end of link list (taillink)
	cmp ebp,0   
	jnz .topoflinkdrawloop 
	;go back and draw next char



.savelastlink:
	;we want to save the last link drawn
	;but we went past it already, so...
	mov ebp, [ebp+4]  ;backup 1 link  
	mov [lastlink],ebp




	;show the tedit menu bar at bottom
	STDCALL  FONT02,0,589,te_menu,0xeffe,puts


	;display the caret linecount
	;this is not accurate
	;with this style of editor we dont have an accurate count of lines
	;without starting from the beginning and count NL chars
	;as of Sept 2012 we are updating the caretlinecount for quite a few cases but
	;we still need to update caretlinecount for CUT/COPY/PASTE and GOTO
	;so until we fix all these we will not display
	;use metrics F3 to get your line count or use GOTO Ctrl+g


	
	;display a message along bottom of screen
	cmp dword [messagepointer],0
	jz .nomessage
	mov esi,[messagepointer]
	STDCALL 0,585,800,15,WHI,fillrect
	STDCALL  FONT01,0,585,esi,0xf3fe,puts
	mov dword [messagepointer],0
.nomessage:


		

.swapbuf:
	call swapbuf 
	ret  
	;endpaint





;*********************************************************
;          SUBROUTINES
;*********************************************************



;***********************************************************
;teditBlankList
;this function is called to zero out the tedit link list
;it is called in tatOS.init on startup or when you push F7
;***********************************************************

teditBlankList:

	STDCALL te_str19,dumpstr

	mov edx,TEDITMEMORYSTART

	;our link list will initially contain only a single SPACE link
	;this is so paint has something to (not) show
	;this space will remain with the file unless you delete it
	mov byte  [edx  ],SPACE 
	mov byte  [edx+1],0     ;unselected
	mov dword [edx+4],0     ;prev
	mov dword [edx+8],0     ;next
	mov dword [headlink], TEDITMEMORYSTART 
	mov dword [taillink], TEDITMEMORYSTART 
	mov dword [toplink],  TEDITMEMORYSTART 
	mov dword [caretlink],TEDITMEMORYSTART
	mov dword [newlink],  TEDITMEMORYSTART 
	mov dword [te_qtylinksalloc],1

	ret



;********************************************************
;TeditLinkListGen
;generate tedit link list
;this converts an array of ascii bytes in memory 
;to a tedit double link list

;input
;esi=StartAddress of ascii text in memory to display
;ecx=qty ascii bytes  (fat16filesize)

;note:
;The generated link list may be smaller than ecx 
;because we ignore all 0xd bytes and use only 0xa to mark
;the end of a line.
;********************************************************

TeditLinkListGen:
	pushad

	cld 

.buildlist:
	lodsb      ;al=[esi],esi++

	cmp al,0xd 
	jz .loop   ;ignore 0xd

	call InsertNewLink

.loop:
	loop .buildlist  ;dec ecx jnz
	
.done:
	mov eax,[headlink]
	mov [caretlink],eax
	mov [toplink],eax

	popad
	ret


;***********************************************
;ComputeMetrics:
;compute various link list measures
;input:none
;return: various globals are computed
;dword [numbyte]    = qty bytes in list
;dword [numline]    = qty NEWLINE chars in list
;dword [caretline]  = line where caret is found
;dword [caretbyte]  = byte offset from beginning to caret
;dword [caretascii] = ascii value of char at caret
;***********************************************

ComputeMetrics:

	STDCALL te_str16,dumpstr

	;count lines and chars 
	mov ebp,[headlink]  
	mov ecx,0 ;numline
	mov ebx,0 ;numbytes

.getmetrics:
	cmp ebp,0   
	jz .donecount

	;caretline & caretbyte
	cmp ebp,[caretlink]
	jnz .notcaret
	mov [caretline],ecx
	mov [caretbyte],ebx
	.notcaret:

	;newline
	cmp byte [ebp],NEWLINE
	jnz .notnl
	inc ecx
	.notnl:

	;all char
	inc ebx

	.nextlink:
	mov ebp,[ebp+8]
	jmp .getmetrics

	.donecount:
	mov [numbyte],ebx
	mov [numline],ecx
	call dumpreg
	ret



;input: none
;return: eax=qty char from caret to beginning of line
CountChar2BOL:
	mov ecx,80  ;max char we test for
	mov ebp,[caretlink]
.loop1:
	call PreviousLink  ;ebp=link->prev, al=prev char
	cmp ebp,[headlink]
	jz .done
	cmp al,NEWLINE
	jz .done
	dec ecx
	jnz .loop1
.done:
	mov eax,80
	sub eax,ecx
	ret




;*******************************************************
;FindNext
;brute force here
;start at caret
;find match for first char then continue
;input:0 terminated search string in COMPROMPTBUF
;*******************************************************

FindNext:


	;set ebp to first char after caret
	mov ebp,[caretlink]  ;our starting point
	mov ebp,[ebp+8]
	cmp ebp,0
	jz .doneNext
	
	mov eax,COMPROMPTBUF
	call strlen 
	mov [lenfindbuf],ecx

	;look for match of first char in findbuf
.findfirst:
	mov al,[COMPROMPTBUF+0]  ;1st char of findbuf 
.findfirstchar:
	cmp al,[ebp]        ;check for match       
	jz .check4remaining ;found match for 1st char of findbuf
	mov ebp,[ebp+8]     ;get next link
	cmp ebp,0           ;check for end of list
	jz .doneNext
	jmp .findfirstchar

	;look for match of remaining chars in findbuf 
	;any failure here sends us back to previous loop
.check4remaining:
	mov edx,1
	mov ecx,[lenfindbuf]
	dec ecx
.checkremaining:
	mov al,[COMPROMPTBUF+edx]    ;next char
	mov ebp,[ebp+8]      ;nextlink
	mov bl,[ebp]         ;char at nextlink
	cmp al,bl
	jnz .findfirst   ;any failure & we start over
	inc edx
	loop .checkremaining

.success:
	;set caret to findbuf first char match
	mov [caretlink],ebp  
	;set toplink to BOL
	call GetBOL
	mov [toplink],ebp

.doneNext:
	ret


;*****************************************************************
;YankWord
;copy a single word at the caret to teditbuf
;we dont use CLIPBOARD because user may have something in there
;that he wishes to paste elsewhere
;the term "yank" comes from VIM 
;where you can press yy to copy a single word 
;back up to start of word and copy to teditbuf til end of word
;in teditbuf the first dword is qty chars then comes the string
;string is not 0 terminated
;input:none
;return:none
;******************************************************************

YankWord:

	mov ebp,[caretlink]

	;if caret is over SPACE we quit
	cmp byte [ebp],SPACE
	jz .done

	;find the start of the word
	;we will only backup at most 25 chars
	;start of word is defined by SPACE or NEWLINE or [ or , or ; 
	cld
	mov ecx,25
.1:
	call PreviousLink  ;returns ebp=Previous Link
	cmp byte [ebp],SPACE
	jz .FoundStartOfWord
	cmp byte [ebp],NEWLINE
	jz .FoundStartOfWord
	cmp byte [ebp],'['
	jz .FoundStartOfWord
	cmp byte [ebp],','
	jz .FoundStartOfWord
	cmp byte [ebp],';'
	jz .FoundStartOfWord
	loop .1

.FoundStartOfWord:
	;move to next link which is start of word
	call NextLink

	;in the teditbuf the first dword is the qty of data bytes
	;the actual data starts at teditbuf+4
	;copy first char to teditbuf
	lea edi,[teditbuf+4] 
	mov al,[ebp]        ;get the char 
	stosb               ;save to teditbuf, [edi]=al, edi++
	mov ebx,1           ;keeps count of qty chars to clip

	;now copy to end of word but no more than 25 chars
	;end of word is defined by SPACE, NEWLINE, comma, colon, Rbrace
	mov ecx,25
.2:
	call NextLink
	mov al,[ebp]   ;put char in al
	cmp al,SPACE
	jz .WriteQtyChars2Clip
	cmp al,NEWLINE
	jz .WriteQtyChars2Clip
	cmp al,',' 
	jz .WriteQtyChars2Clip
	cmp al,':'
	jz .WriteQtyChars2Clip
	cmp al,']' 
	jz .WriteQtyChars2Clip
	stosb          ;save to clip
	inc ebx        ;inc qty chars written to clip
	loop .2

.WriteQtyChars2Clip:
	mov [teditbuf],ebx

.done:
	ret




;*************************************
;Copy2Clip
;copy all selected text to clipboard
;*************************************

Copy2Clip:
	pushad

	;preparations
	mov edi,CLIPBOARD     ;address of clipboard
	mov ecx,[qtyselected]
	jecxz .done2clip     ;nothing selected
	mov [edi],ecx        ;1st dword at clip is qtybytes
	add edi,4            ;edi points to start of clipboard data
	mov ebp,[headlink]   ;start at beginning of link list
	
.store2clip:
	cmp byte [ebp+1],1   ;check for selected
	jnz .not2clip        ;skip unselected links
	mov al,[ebp]         ;get the char
	mov [edi],al         ;copy to clip
	inc edi              ;increment clip address
.not2clip:
	mov ebp,[ebp+8]      ;next link
	cmp ebp,0            ;test for end of list
	jz .done2clip
	jmp .store2clip
	
.done2clip:
	popad
	ret
	


;*****************
;UnselectAll
;*****************

UnselectAll:
	mov ebp,[headlink]
	.clearnextlink:
	mov byte [ebp+1],0  ;unselect
	mov ebp,[ebp+8]     ;get next link
	cmp ebp,0           ;end of list
	jnz .clearnextlink
	mov dword [qtyselected],0
	ret



;*****************************
;InsertNewLink
;al=ascii byte
;to be inserted left of caret
;caretlink stays the same but
;appears to be moving right
;*****************************

InsertNewLink:
	pushad
	
	;allocate/define a newlink 
	;each link struct is 12 bytes
	add dword [newlink],12


	;we reserve 9meg for tedit
	;since each char struct takes 12 bytes
	;thats 750,000 char max
	inc dword [te_qtylinksalloc]
	cmp dword [te_qtylinksalloc],750000
	jb .plentyofmemory
	mov dword [messagepointer],te_str7
	jmp .endinsertnewlink  ;newlink not inserted
	.plentyofmemory:



	;put pointers to caret and new links in registers
	;links are always inserted left of the caret
	mov ebp, [caretlink]
	mov ebx, [newlink]


	;save char and show as unselected
	mov       [ebx+0],al  ;save char
	mov byte  [ebx+1],0   ;newlink->select=0


	;case 1: caretlink==headlink 
	;define new headlink/toplink and push caretlink over
	cmp ebp,[headlink]
	jnz .notheadlink
	mov dword [ebx+4],0   ;newlink->prev=0
	mov       [ebx+8],ebp ;newlink->next=caret
	mov       [ebp+4],ebx ;caretlink->prev=newlink
	mov    [headlink],ebx ;headlink=newlink
	mov     [toplink],ebx ;toplink=newlink
	jmp .endinsertnewlink
	.notheadlink:


	;case 2: all other cases caretlink != headlink
	mov eax,  [ebp+4]     ;eax=previous link
	mov       [eax+8],ebx ;prevlink->next=newlink
	mov dword [ebx+4],eax ;newlink->prev=prevlink
	mov       [ebx+8],ebp ;newlink->next=caretlink
	mov       [ebp+4],ebx ;caretlink->prev=newlink

	.endinsertnewlink:
	popad
	ret
	



;***************************************************************
;PreviousEOL:
;input: 
;ebp=address of some link
;return:
;on success eax=0 and ebp=address of the previous EOL link
;on failure eax=1 and ebp=address of headlink
;***************************************************************

PreviousEOL:
	cmp ebp,[headlink]  ;test for headlink
	jz .foundhead
	mov ebp,[ebp+4]     ;ebp=link->prev 
	cmp byte [ebp],NEWLINE
	jnz PreviousEOL

	mov eax,0    ;found previous EOL
	jmp .done
.foundhead:
	mov eax,1
.done:
	ret

	

;*************************************************
;PrevousLink
;input ebp=address of some link
;return: ebp=address of prev link
;prevents going beyond headlink
;*************************************************
PreviousLink:
	push eax
	mov eax,[ebp+4]       ;ebp=link->prev 
	cmp eax,0             ;check for head
	jz .done
	mov ebp,eax           ;assign prevlink to ebp
.done:
	pop eax
	ret


;************************************************
;CaretPreviousLink
;use this to move the caret closer to headlink
;protect from going past headlink
;modifies toplink as reqd to keep caret visible
;input:none 
;return: ebp=caretlink
;usage: left arrow, uparrow, pageup
;************************************************
CaretPreviousLink:
	mov ebp,[caretlink]
	mov ebx,ebp         ;save
	call PreviousLink   ;ebp=linkprev
	;check is previous link is toplink
	cmp ebx,[toplink]
	jnz .notoplinkadjust
	mov [toplink],ebp
.notoplinkadjust:
	mov [caretlink],ebp
	;if this link is NEWLINE, decrement the caret line count
	cmp byte [ebp],NEWLINE
	jnz .notnewline
	dec dword [caretlinecount]
.notnewline:
	ret
	

;no input and no return
;redefines [caretlink] to the previous NEWLINE
CaretPreviousEOL:
.1:
	call CaretPreviousLink
	cmp ebp,[headlink]   
	jz .done
	cmp byte [ebp],NEWLINE
	jnz .1
.done:
	ret




;**************************************
;NextEOL:
;takes as input the address of some link
;in ebp and finds the address of the next
;EOL marker after ebp 
;returns ebp = address of EOL marker
;al=1 to select as we go
;  =0 to not select
;**************************************
NextEOL:
	.forward:
	cmp ebp,[taillink]    ;test for taillink
	jz .done
	mov ebp,[ebp+8]       ;ebp=link->next 
	cmp byte [ebp],NEWLINE
	jnz .forward
	.done:
	ret



;*********************************************
;TopNextBOL
;this is scrollup
;we move toplink to next EOL marker
;then move one more byte putting toplink 
;at beginning of next line
;********************************************
TopNextBOL:
	push ebp
	mov ebp,[toplink]
	call NextEOL
	call NextLink
	mov [toplink],ebp
	pop ebp
	ret



;*************************************************
;NextLink
;input ebp=address of some link
;return: ebp=address of next link
;prevents going beyond taillink
;*************************************************
NextLink:
	push eax
	mov eax,[ebp+8]       ;ebp=link->next 
	cmp eax,0             ;check for tail
	jz .done
	mov ebp,eax           ;assign nextlink to ebp
.done:
	pop eax
	ret

;************************************************
;CaretNextLink
;use this to move the caret closer to taillink
;protect from going past taillink
;modifies toplink as reqd to keep caret visible
;input: none
;return: ebp=new caret and [caretlink] is redefined
;usage: right arrow, dnarrow, pagedn
;************************************************

;Dec 2010
;tom this routine needs to be modified to also call TopNextBOL
;if the caret is at the end of a line that is longer than 80char display
;or the user must learn to insert line breaks before end of screen
;otherwise pushing the DOWN arrow key when the carot is at the bottom of
;the screen with a line longer than 80 char may result in the carot being
;redefined but the toplink is not so the text is not scrolled up 
;status: problem unsolved

CaretNextLink:
	push ebx
	mov ebp,[caretlink]
	mov ebx,ebp         ;save oldcaret
	call NextLink       ;returns ebp=address of next link
	cmp ebx,[lastlink]
	jnz .notoplinkadjust
	call TopNextBOL     ;caret is at bottom of screen end of line so scroll up
.notoplinkadjust:
	;redefine the caret link
	mov [caretlink],ebp
	push ebp  ;preserve caret link
	;if the previous link is NEWLINE then increment the line count
	call PreviousLink
	cmp byte [ebp],NEWLINE
	jnz .PreviousIsNotNEWLINE
	inc dword [caretlinecount]
.PreviousIsNotNEWLINE:
	pop ebp  ;return address of caret link
	pop ebx
	ret
	

;********************************************
;CaretNextEOL
;move the caret to the next NEWLINE char
;input: al=1 to select and 0 to not select
;*******************************************
CaretNextEOL:
	mov ebp,[caretlink]
.1:
	;if the caret is at the taillink then quit
	cmp ebp,[taillink]  
	jz .done
	cmp al,1  ;do we select ?
	jnz .noselect
	call SelectCaretLink
.noselect:
	call CaretNextLink      ;returns ebp new caretlink
	cmp byte [ebp],NEWLINE  ;check for NEWLINE
	jnz .1                  ;loop until we find a NEWLINE byte
.done:
	ret


;*******************************************
;GetBOL
;input: ebp=address of any link
;return:ebp=address of first char in line
;*******************************************

GetBOL:
	call PreviousEOL
	cmp eax,1  ;we are at headlink
	jz .done
	call NextLink
.done:
	ret




;*************************
;SelectCaretLink
;no input and no return
;*************************

SelectCaretLink:
	mov ebp,[caretlink]
	mov byte [ebp+1],1       ;select
	inc dword [qtyselected]  ;increment qtyselected
	ret


;*****************************************
;DeleteSelections
;removes all selected links from the list
;*****************************************
DeleteSelections:
	pushad
	mov ebp,[headlink]  ;start at beginning
	
.deleteselections:
	cmp byte [ebp+1],1
	jnz .notselected
	call DeleteLink
.notselected:
	mov ebp,[ebp+8]  ;get next link
	cmp ebp,0        ;test for end of list
	jnz .deleteselections

	;set qtyselected to zero
	mov dword [qtyselected],0
	popad
	ret




;************************************
;DeleteLink
;removes a single link from the list
;ebp=address of link to remove
;called when delete key pressed
;also called by CUT
;************************************

DeleteLink:
	pushad

	mov eax,[ebp+4]  ;previous
	mov ebx,[ebp+8]  ;next
	
	;taillink may not be deleted
	cmp ebp,[taillink]
	jz near .enddelete
	
	;delete headlink
	cmp ebp,[headlink]
	jnz .noheadlink2del
	mov [caretlink],ebx
	mov [headlink],ebx
	mov [toplink],ebx
	jmp .fixlinkage
.noheadlink2del:

	;delete toplink
	cmp ebp,[toplink]
	jnz .notoplink2del
	mov [toplink],ebx 
	mov [caretlink],ebx
	jmp .fixlinkage
.notoplink2del:

	;the caretlink becomes the next link
	mov [caretlink],ebx
	
	;fix up the prev/next linkage
.fixlinkage:
	cmp eax,0        ;is there a prev link ?
	jz .noprevlink
	mov [eax+8],ebx  ;prev->next=next
.noprevlink:
	cmp ebx,0        ;is there a next link ?
	jz .nonextlink
	mov [ebx+4],eax  ;next->prev=previous
.nonextlink:

.enddelete:
	popad
	ret



;************************************************************
;               DATA
;************************************************************

align 4

;link pointers
headlink  dd 0 ;first link of list
taillink  dd 0 ;last link of list
toplink   dd 0 ;first char displayed at upper left
lastlink  dd 0 ;last char displayed lower right
caretlink dd 0 ;caret is shaded rect behind char
newlink   dd 0 

;dwords
xloc dd 0
yloc dd 0
caretx dd 0
carety dd 0
qtyselected dd 0  ;the current number of selected links
messagepointer dd 0
atolconversion dd 0
numline dd 0
numbyte dd 0
caretline dd 0
caretbyte dd 0
linecomment dd 0
haveNL dd 0
qtybytesgetsbuf dd 0
LBAstart dd 0
qtyblocks dd 0
qtybytes dd 0
numstartdel dd 0
numenddel dd 0
lenfindbuf dd 0
editdirectory dd 0
saveEXE dd 0
teditfilesize dd 0
caretlinecount dd 0
caretascii dd 0
te_qtylinksalloc dd 1
linenumleftmargin dd 0


;bytes
te_slash db '/'
te_colon db ':'

;strings
te_str1 db '   caretbyte=',0
te_str2 db '   line=',0
te_str3 db '   ascii=',0
te_str4 db 'Enter string to search (Ctrl+f = Next)',0
te_str5 db 'Open FAT16 file off PenDrive: Enter 11 char filename',0
te_str6 db 'File not found',0
te_str7 db 'tedit: out of memory, reached 750000 max char links',0
te_str8 db 'tedit: Save FAT16 file to Flash: Enter 11 char filename',0
te_str9 db '[tedit] leaving kernel, continue execution at 0x1b:[0x2000008] userland',0
te_str10 db 'File Save: Failed',0
te_str11 db 'File Save: Failed - File already exists',0
te_str12 db 'File Save: Success/Done',0
te_str13 db 'error PASTE outside the range 0->20,000 bytes',0
te_str14 db 'tedit Read10: Enter LBAstart, qtyblocks',0
te_str15 db 'GoTo: linenum',0
te_str16 db 'tedit:ComputeMetrics:ebx=numbyte,ecx=numline',0
te_str18 db 'filesize=',0
te_str19 db 'tedit: Blank List',0
te_str20 db 'tedit delete block of characters to caret: Enter starting character number',0
te_str21 db 'tlink:check dump for errors',0
te_str22 db 'tlink:success',0



;menu string that appears at bottom of tedit 
te_menu db 'tedit: F1=Open F2=Save F3=Metrics F4=calc F6=Dump F8=Clear F9=Asm F10=make F11=Run F12=quit',0




;jump table to handle non-printable keydowns
;see tatOS.inc where these are defined
;doNot is just a stub routine for tedit unsupported keys
;this table must mirror the non displayable keydowns listed in tatOS.inc
;in the same order starting with 0x80 for F1 key and continuing
teditjumptable:
dd te_doF1, te_doF2, te_doF3, te_doF4, te_doNot
dd te_doF6, te_doF7, te_doF8, te_doF9, te_doF10
dd te_doF11, te_doF12
dd te_doEscape, te_doNot, te_doNot, te_doNot
dd te_doNot, te_doNot,  te_doBkspace, te_doHome
dd te_doEnd, te_doUp, te_doDown, te_doLeft, te_doRight
dd te_doPageUP, te_doPageDN, te_doNot, te_doNot ;PAGEUP, PAGEDN, CENTER, INSERT
dd te_doDelete, te_doNot, te_doNot, te_doEnter  ;DELETE, PRNTSCR, SCRLOCK, ENTER
dd te_doCut, te_doCopy, te_doPaste
dd te_doNot, te_doNot, te_doNot                 ;GUI, MENU, BREAK



;These arrays are needed by printf
;to build a metrics string when F3 is pushed
te_metrics_argtype:
dd 3,1,3,2,1,2,3,2,1,2,3,2
	

te_metrics_arglist:
dd currentfilename, te_colon, te_str1, caretbyte, te_slash, numbyte, te_str2
dd caretline, te_slash, numline, te_str3, caretascii


;arrays
teditbuf times 100 db 0
feedbackbuf times 100 db 0
viewtxtbuf times 100 db 0
currentfilename times 12 db SPACE  ;11 char + 0term




