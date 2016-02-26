;tatOS/tlib/filemanager.s
;rev May 2015


;filemanager
;fmDeleteFile
;fmRenameFile
;fmCutFile
;fmCopyFile
;fmPasteFile
;fmSaveFileListing
;fmCreateMSDOSDirEntry
;fmSaveExe
;fmLoadExe
;fmGetSelectedFilename
;fmDeleteSub
;fmSetCWDasSub
;fmSetCWDasRoot
;fmMakeSubDir


;provides basic functions to operate on a FAT16 formatted flash drive
;provides an interactive user interface for the functions found in fat16.s

;the NAMEOFCWD is set to root on startup in boot2.s
;this filemanager can also act as a ChooseFile Dialog 

;to move a file use CUT (Ctrl+x) then navigate to root or a subdir and PASTE (Ctrl+v)
;to copy a file use COPY (Ctrl+c) then navigate to root or a subdir and PASTE (Ctrl+v)


FMmenu: 
db 'tatOS USB Flash Drive FAT16 File Manager',NL
db '*****************************************',NL
db 'UP/DN arrow to select',NL
db 'CUT/COPY/PASTE to move or copy a file',NL
db NL
db 'F1     = List VBR Volume Boot Record Info',NL
db 'r      = Set CWD as ROOT',NL
db 'ENT    = Set CWD as SUBDIR',NL
db 'F3     = Create SUBDIR',NL
db 'F7     = Rename File',NL
db 'F8     = Rename File as MSDOS',NL
db 'DEL    = Delete File',NL
;db 'F9     = Save code at STARTOFEXE to flash as flat binary exe',NL
;db 'F8  = Load Executable off flash & run (disabled)',NL
db 'F10    = Save directory listing to flash',NL
db 'ESC    = Exit',0
 

FMstr1  db 'filemanager',0
FMstr3  db 'fmCutFile',0
FMstr4  db 'Rename Directory Entry: Enter new 11 char file/dir name',0
FMstr5  db 'fmCopyFile',0
FMstr6  db 'fmPasteFile',0
FMstr7  db 'Make Subdirectory in Root: Enter 11 char directory name',0
FMstr8  db 'error: not an archive file',0
FMstr9  db 'CurrentWorkingDirectory =',0
FMstr10 db 'fmPasteFile: fatwritefile failed',0
FMstr12 db 'Filename......Filesize...LastModified...Attributes.....StartCluster',0
FMstr13 db 'filemanager exit: selected filename:',0
FMstr14 db 'Delete DirEntry: there is NO undo - do you wish to proceed? (ENTER/ESC)',0
FMstr15 db 'Copy File failed',0
FMstr16 db 'Copy File: Enter unique name of file copy',0
FMstr17 db 'DeleteSub: Sorry no code for this yet',0
FMstr18 db 'fmPasteFile: fatFindAvailableDirEntry failed',0


;0=FileChooser, 1=FileManager
FMcapability dd 0  

;some storage for a new filename
DOSfilename times 20 dd 0

yorient_stor dd 0

;for file copy
TempMemoryBlock     dd 0
SizeTempMemoryBlock dd 0
dCutCopy            dd 0




;**************************************************************************
;filemanager
;displays a list control filled with the files of the current working directory
;Y=285 is the top of the filemanager 
;initially the CWD=root
;user may select a SUBDIR and hit enter to display contents of SUBDIR

;input:
;	ebx=0 run filemanager to list and select files only (File Chooser)
;       this hides&disables the filemanger menu
;       sets ZF on return if user hits ESC to quit out of the function
;   ebx=1 run filemanger with full file/subdir modification capabilities

;return: 
;   File chooser: on ENTER, ZF is set if user hits escape and decides 
;                 not to select/open a file else ZF is clear and the 
;                 11 char filename of the currently selected directory entry
;                 is copied to FILENAME/0x198fb00 and 0 terminated 
;   File manger:  ZF is set on ESCAPE key press 
;**************************************************************************

filemanager:

	pushad

	STDCALL FMstr1,dumpstr

	;save calling programs YORIENTation
	mov eax,[YORIENT]
	mov [yorient_stor],eax
	;and set YORIENTation to top down
	mov dword [YORIENT],1 


	;this variable is used for CUT/COPY/PASTE
	mov dword [dCutCopy],0

	;[FMcapability]=0  File chooser (disable menus)
	;[FMcapability]=1  File manager
	mov [FMcapability],ebx


	;as of April 2015
	;there are only 2 places to load the VBR, fats and rootdir 
	;1=end of initflash
	;2=after fatformatflash


	;fill the list control buffer with DIRENTRY strings 
	;this function will generate strings by searching
	;either the root dir entries or the sub dir entries
	;depending on the value of dword [CurrentWorkingDirectory]
	call fatGenerateDEStrings
	;returns ecx=qty directory entry strings

	mov eax,ecx  ;qty strings
	mov ebx,300  ;Ylocation top of list control
	call ListControlInit

	jmp .paint


.getkeypress:

	;block for keypress
	call getc  ;returns ascii keypress in al

	cmp al,ESCAPE  
	jz near .quit

	cmp al,ENTER
	jz near .doEnter


	;*****************************************************************
	;FileChooser can not use these function keys
	cmp dword [FMcapability],0
	jz near .paint  

	cmp al,DELETE
	jz near .doDelete
	cmp al,CUT
	jz near .doCut
	cmp al,COPY
	jz near .doCopy
	cmp al,PASTE
	jz near .doPaste
	cmp al,'r'
	jz near .doR
	cmp al,F1
	jz near .doF1
	;cmp al,F2
	;jz near .doF2
	cmp al,F3
	jz near .doF3
	;cmp al,F4
	;jz near .doF4
	;cmp al,F5
	;jz near .doF5
	;cmp al,F6
	;jz near .doF6
	cmp al,F7
	jz near .doF7
	cmp al,F8
	jz near .doF8
	cmp al,F9
	jz near .doF9
	cmp al,F10
	jz near .doF10
	
	
	;we have to let other keypresses fall thru like UP/DN
	;for the benefit of ListControlPaint
	jmp .paint

.doF1:
	call fatreadVBR
	jmp .paint
.doR:
	call fmSetCWDasRoot
	jmp .paint
.doF3:
	call fmMakeSubDir
	jmp .paint
.doF7:
	call fmRenameFile
	jmp .paint
.doF8:
	call fmCreateMSDOSDirEntry
	jmp .paint
.doF9:
	call fmSaveExe
	jmp .paint
.doF10:
	call fmSaveFileListing
	jmp .paint
.doF11:
	jmp .paint
.doDelete:
	call fmDeleteFile
	jmp .paint
.doEnter:
	cmp dword [FMcapability],0
	jz near .FileChooserNormalExit
	call fmSetCWDasSub  ;File manager change CWD on enter
	jmp .paint
.doCut:
	call fmCutFile
	jmp .paint
.doCopy:
	call fmCopyFile
	jmp .paint
.doPaste:
	call fmPasteFile
	jmp .paint


	;************************************************************


.paint:

	cmp dword [FMcapability],0
	jz .dontshowmenu
	;clear the screen
	call backbufclear  
	;title & instructions
	STDCALL FONT01,0,10,FMmenu,0xefff,putsml  
.dontshowmenu:

	
	;describe the various fields of the directory listing
	STDCALL 0,285,800,15,BLA,fillrect
	STDCALL FONT01,0,285,FMstr12,0xfeef,puts  ;"Filename....Filesize...."


	;display the CWD DIRENTRY strings starting at Y=300
	;from Y=300 to Y=540
	call ListControlPaint  


	;tag "CurrentWorkingDirectory ="
	;white text on black appears along the bottom of file listing
	STDCALL 0,540,800,15,BLA,fillrect
	STDCALL FONT01,0,540,FMstr9,0xfeef,puts

	;the name of the CWD is appended to the "CurrentWorkingDirectory =" string
	push FONT01
	push 260       ;x
	push 540       ;y
	push NAMEOFCWD ;address
	push 11        ;11 bytes
	push 0xfaff    ;color
	call putsn



	call swapbuf   ;endpaint
	jmp .getkeypress



.FileChooserNormalExit:
	call fmGetSelectedFilename
	STDCALL FMstr13,dumpstr
	STDCALL FILENAME,dumpstrquote
	or eax,1     ;clear ZF for successful exit 
	jmp .done
.quit:
	;free memory that was allocated by fmCopyFile but possibly not used	
	cmp dword [TempMemoryBlock],0
	jz .setzf
	mov esi,[TempMemoryBlock]
	call free
	mov dword [TempMemoryBlock],0
.setzf:
	xor eax,eax  ;set ZF for FileChooser quit or File manger quit
.done:
	;restore calling programs YORIENTation
	mov eax,[yorient_stor]
	mov [YORIENT],eax
	call ListControlDestroy
	popad
	ret








	;*************************************
	;     SUBROUTINES
	;*************************************







fmMakeSubDir:
	STDCALL FMstr7,fatgetfilename
	jnz .userHitESC
	push dword COMPROMPTBUF
	call fatmakeSubDir
	call fatGenerateDEStrings
.userHitESC:
	ret


fmSetCWDasRoot:
	call fatsetCWDasRoot
	call fatGenerateDEStrings
	ret


fmSetCWDasSub:
	mov dword [CurrentWorkingDirectory],1
	;the user must first select a subdir from the list control
	call fmGetSelectedFilename
	;Load new sub directory entries 
	push FILENAME
	call fatloadSubDirEntries
	jz .invalid  ;bad subdir name entered
	call fatGenerateDEStrings
	;when the list control is painted
	;we want the first string index=0 to appear at the top
	mov dword [list_IndexFirstString], 0
.invalid:
	ret




fmDeleteSub:
	;we dont have any code for this yet
	;would have to first delete all files within the sub
	STDCALL FMstr17,putspause
	ret



;you can rename a file or directory with this code
fmRenameFile:

	call fmGetSelectedFilename

	;prompt user to enter new filename
	push FMstr4
	call fatgetfilename
	jnz .done

	push FILENAME
	push COMPROMPTBUF
	call fatrenamefile

	call fatGenerateDEStrings
.done:
	ret



fmDeleteFile:
	call fmGetSelectedFilename

	mov eax,FILENAME
	call fatdeletefile

	call fatGenerateDEStrings
.done:
	ret





;**********************************************************************
;fmCutFile
;prepare to move a file
;copy the currently selected direntry to a buffer
;then mark the file as deleted
;move file = cut file + paste file
;do not try to copy a subdir
;input:none
;return:none
;**********************************************************************

fmCutFile:

	STDCALL FMstr3,dumpstr

	mov dword [dCutCopy], 1  ;1=cut

	call fmGetSelectedFilename  ;copies filename string to FILENAME

	push FILENAME
	call fatfindfile  
	;returns esi=address of DIRENTRY 
	;fills in direntry.filename, direntry.filesize, direntry.attributes
	;if eax=0 this function fails, but I dont see this can happen
	;unless fmGetSelectedFilename returns a bad FILENAME

	;make sure we have an archive file
	cmp dword [direntry.attributes],0x20  ;0x20=archive file
	jnz .error  ;can not cut a subdir

	;save the 32byte direntry structure
	;esi=address of DIRENTRY 
	mov edi,old_direntry
	mov ecx,32
	cld
	call strncpy

	;mark the direntry as deleted
	mov eax,FILENAME
	call fatdeletefile

	call fatGenerateDEStrings

	;now user must navigate to root or another subdir
	;and use PasteFile 
	jmp .done

.error:
	STDCALL FMstr8,dumpstr
.done:
	ret



;********************************************************
;fmCopyFile
;prepare to copy a file to the CWD
;alloc temp memory and load the file
;save pointer to temp memory as global for fmPasteFile
;file data is also copied
;*********************************************************

fmCopyFile:

	STDCALL FMstr5,dumpstr

	mov dword [dCutCopy], 2  ;2=copy

	;get name of currently selected file
	;the 0 terminated filename is stored at FILENAME
	call fmGetSelectedFilename

	;call fatfindfile to get the file size
	;and to make sure the user has selected an archive file not subdir
	push FILENAME
	call fatfindfile
	cmp eax,0   ;check for subdir
	jz .error
	;if we got here eax=filesize 
	mov [SizeTempMemoryBlock],eax


	;if for some reason the user previously invoked fmCopyFile
	;but did not go thru with the Paste, then we must first clear this memory
	cmp dword [TempMemoryBlock],0
	jz .doalloc
	mov esi, [TempMemoryBlock]
	call free
	mov dword [TempMemoryBlock],0


.doalloc:

	;alloc temp memory to load the file to
	mov ecx,eax  ;ecx=qty bytes to alloc
	call alloc
	jz .error
	;esi=address of allocated memory block
	mov [TempMemoryBlock],esi  ;save for free

	;load the file off flash to our temp memory
	push esi ;destination memory address
	call fatreadfile
	cmp eax,0
	jz .free_error  ;file not found, why not ?


	;now user must navigate to root or another subdir and PASTE



.error:
	STDCALL FMstr15,dumpstr
	jmp .done

.free_error:
	STDCALL FMstr15,dumpstr
	mov esi, [TempMemoryBlock]
	call free
	mov dword [TempMemoryBlock],0
	jmp .done

.done:
	call fatGenerateDEStrings
	ret






;***********************************************************
;fmPasteFile
;if previous call was to fmCutFile 
;this function will write the old direntry to the CWD 
;if previous call was to fmCopyFile 
;this function will prompt user for a unique filename
;and write a file that was previously loaded by fmCopyFile
;do not try to paste a subdir 0x10
;************************************************************

fmPasteFile:

	STDCALL FMstr6,dumpstr

	cmp dword [dCutCopy], 1  
	jz near .handleCut
	cmp dword [dCutCopy], 2
	jz near .handleCopy
	;if we got here user did not do CUT or COPY previously but just hit PASTE
	jmp .done 


.handleCut:   ;Move File = cut + paste

	;find a place for our FATDIRENTRY struct in CWD
	call fatFindAvailableDirEntry
	;edi=address of available 32byte dir entry
	cmp edi,0
	jz near .error

	;copy the  32byte DIRENTRY structure 
	;saved during fmCutFile
	mov esi,old_direntry  
	;edi is set by fatFindAvailableDirEntry 
	mov ecx,32
	cld
	rep movsb
	jmp .writeSubDir



.handleCopy:  ;Copy File = copy + paste

	;fmCopyFile used alloc to load file data to temp memory
	;so dont forget to free this memory

	;prompt user to enter the unique filename of the copy 
	;the file copy direntry will appear in the CWD
	;the 11 char filename is stored at COMPROMPTBUF
	;and used by fatwritefile
	push FMstr16
	call fatgetfilename
	jnz .free_success  ;user hit ESC so decided not to continue with the copy

	;fatwritefile to CWD
	push dword [TempMemoryBlock]
	push dword [SizeTempMemoryBlock]
	call fatwritefile
	cmp eax,0 ;check if fatwritefile failed 
	jnz .free_success


.free_error:
	STDCALL FMstr10,dumpstr
	;fall thru

.free_success:
	mov esi, [TempMemoryBlock]
	call free
	mov dword [TempMemoryBlock],0
	;fall thru

.writeSubDir:
	;finally if we are in a subdir
	;we must write to flash the subdir entries
	cmp dword [CurrentWorkingDirectory],ROOTDIRECTORY
	jz .saveroot
	cmp dword [CurrentWorkingDirectory],SUBDIRECTORY
	jz .savesub
	jmp .error

.saveroot:
	call fatsaveroot  ;zf set on error
	jz .error
	jmp .done
.savesub:
	call fatsavesub  ;zf set on error
	jnz .done

.error:
	STDCALL FMstr18,dumpstr
.done:
	mov dword [dCutCopy], 0  ;0=neither cut or copy
	call fatGenerateDEStrings
	ret





;*******************************************************************************
;fmGetSelectedFilename
;copy the 11 byte filename from the list control that is currently selected 
;to memory address "FILENAME" and 0 terminate
;the user must first use the up/dn arrow keys to select a file name
;*******************************************************************************

fmGetSelectedFilename:

	call ListControlGetSelection
	;returns esi=address of selected directory entry
	;the filename is the first 11 bytes

	;copy the 11 byte filename to FILENAME and 0 terminate
	mov edi,FILENAME
	mov ecx,11     
	call strncpy
	mov byte [FILENAME+11],0  ;0 terminate

	ret



;***********************************************************
;fmSaveExe
;save a tatos executable to your flash drive
;the flat binary code must have previously been assembled 
;by ttasm to STARTOFEXE

;we write a 20 byte exe file header then the code follows
;the format of the tatos.exe version=1, 20 byte executable header:
;ascii characters 'TATOSEXE' (8 bytes)
;next comes the header version number = 1 (dword)
;next comes the memory address of STARTOFEXE (dword)
;next comes the qty bytes of the flat binary code header not included (dword) 
;next comes the flat binary code

;input:none
;return:none
startofexe  dd 0
exestr1 db 'SaveExe:',0
exestr2 db 'Enter executable filename (11 char)',0
tatosexetag db 'TATOSEXE'
;***********************************************************

fmSaveExe:

	STDCALL exestr1,dumpstr

	;prompt user to enter 11 char filename and store at COMPROMPTBUF
	push exestr2
	call fatgetfilename
	jnz near .userhitESC

	;alloc some memory to create the exe
	mov ecx,[sizeofexe]
	add ecx,20
	call alloc  ;returns esi address of memory
	jz .done
	mov [startofexe],esi

	;the first 8 bytes are 'TATOSEXE'
	cld
	mov esi,tatosexetag
	mov edi,[startofexe]
	mov ecx,8
	rep movsb

	;the next dword is the header version
	mov edi,[startofexe]
	lea eax,[edi+8]
	mov dword [eax],1

	;the next dword is the STARTOFEXE address
	;all tatos executables are assembled as flat binary to STARTOFEXE
	lea eax,[edi+12]
	mov dword [eax],STARTOFEXE

	;the next dword is the filesize
	lea eax,[edi+16]
	mov ebx,[sizeofexe]
	mov [eax],ebx

	;now we copy the code
	mov esi,STARTOFEXE
	lea edi,[edi+20]
	mov ecx,[sizeofexe]
	rep movsb


	;now save exe to flash
	push dword [startofexe]   ;start of code
	mov ecx,[sizeofexe]
	add ecx,20
	push ecx                  ;total qty bytes for exe file
	call fatwritefile         ;returns eax=0 on success, nonzero=failure

	call fatGenerateDEStrings

	mov esi,[startofexe]
	call free

.done:
.userhitESC:
	ret


;*************************************************************
;fmLoadExe
;load and execute a tatos executable version=1
;input: first select the executable you want to run
;return:none
LandEstr0 db 'fmLoadExe',0
LandEstr1 db 'Failed to find TATOSEXE',0
LandEstr2 db 'Failed to find exe version=1',0
LandEstr3 db 'failed to get exe file size',0
exebuffer dd 0
;*************************************************************

fmLoadExe:   ;this function is not up to date and should not be used Nov 2013

	STDCALL LandEstr0,dumpstr

	call fmGetSelectedFilename

	;get the filesize
	push FILENAME      ;address of 11char filename 0 terminated
	call fatfindfile
	cmp eax,0           ;returns eax=filesize
	jnz .allocatememory
	STDCALL LandEstr3,putspause
	jmp .failed


.allocatememory:
	mov ecx,eax
	call alloc
	jz near .failed
	mov [exebuffer],esi


	;load the file 

;tom the arguments to this function are wrong
;also this function needs a previous call to filemanager to fill in FILENAME
;need to check this code - later

;	push FILENAME      ;address of 11char filename 0 terminated  THIS IS WRONG !!!!
	push dword [exebuffer]
	call fatreadfile    ;returns eax=filesize
	cmp eax,0           ;fatloadfile failed
	jz .done


	;check if this is a valid 'TATOSEXE'
	mov esi,tatosexetag
	mov edi,[exebuffer]
	mov ecx,8
	call strncmp
	jz .checkversion
	;failed to find 'TATOSEXE'
	STDCALL LandEstr1,putspause
	jmp .done


.checkversion:
	;check the header version number=1
	mov ebx,[exebuffer]
	cmp dword [ebx+8],1
	jz .copycode
	;failed to find version=1
	STDCALL LandEstr2,putspause
	jmp .done


.copycode:
	;copy the flat binary code to STARTOFEXE
	cld
	lea esi,[ebx+20]
	mov edi,STARTOFEXE
	mov ecx,[ebx+16]
	rep movsb


	;run the executable
	call STARTOFEXE

	;reset default Yaxis orientation to topdown
	mov dword [YORIENT],1 

	;reset the default X,Y global offsets
	mov dword [XOFFSET],0
	mov dword [YOFFSET],0

.done:
	mov esi,[exebuffer]
	call free
.failed:
	ret




;*******************************************************************************
;fmCreateMSDOSDirEntry
;convert direntry name to MSDOS
;a valid MSDOS direntry name uses the following characters:
;A-Z, 0-9, !#$%^&()-@`{}~
;spaces are tricky so will be eliminated
;this routine converts according to the following rules:
;1) a-z are converted to upper case A-Z
;2) 0-9 and A-Z are left as is
;3) all other chars are replaced by the dash ----
;Windows will not allow you to access any files or directorys 
;on a tatOS formatted flash unless the filename follows the MSDOS rules.
;This is because tatOS does not use LFN but uses 8.3 only
;********************************************************************************

fmCreateMSDOSDirEntry:

	call fmGetSelectedFilename

	;copy filename
	push FILENAME
	push DOSfilename
	call strcpy2

	xor ecx,ecx  ;loop counter and array index
.convertchar:

	;get the next char
	mov bl,[DOSfilename+ecx]

	;[1] test for upper case A-Z
	mov al,bl
	call isupper
	cmp al,1
	jz .donechar  ;skip over upper case ascii

	;[2] test for digits 0-9
	mov al,bl
	call isdigit
	jz .donechar ;skip over digits 

	;[3] test for lower case a-z
	mov al,bl
	call islower
	cmp al,1     
	jnz .doneLowerCase
	;convert a-z to A-Z
	sub byte [DOSfilename+ecx],32  
	jmp .donechar
.doneLowerCase:

	;[4] if we got here its not a-z or A-Z or 0-9 so we change to dash -
	mov byte [DOSfilename+ecx],'-'

.donechar:
	inc ecx
	cmp ecx,11
	jnz .convertchar

	;rename the direntry
	push FILENAME      ;existing filename
	push DOSfilename    ;new filename
	call fatrenamefile

	call fatGenerateDEStrings
.done:
	ret




;this function prompts the user for a filename
;then saves all the DIRENTRY strings which are currently
;in the list controller buffer, to your flash drive
fmSaveFileListing:
	call ListControlSaveToFile
	call fatGenerateDEStrings
	ret


