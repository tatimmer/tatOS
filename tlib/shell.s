;tatOS/tlib/shell.s

;this progam allows you to run other utilities that are part of tlib. 
;this is the top level routine in tatOS
;use scroll UP/DN then hit ENTER to run



;Shell Instruction String:
shellstr0:  
db 'March 2016',NL
db 'UP/DN to move selection bar & scroll the list',NL
db 'ENTER to execute the program',NL
db 'To shutdown push your power button',NL
db 'First init usb controller and flash',NL
db 'Use File Manager to set CurrentWorkingDirectory of tatOS formatted flash',0



;******************************************
;YOU MUST UPDATE THIS VALUE TO AGREE WITH 
;THE ARRAY OF POINTERS OR ELSE TATOS
;WILL TRIPLE FAULT ON BOOT
%define QTY_SHELL_LIST_CTRL_STRINGS 11
;******************************************

;array of pointers for List Control 
ShellStrings:
dd shell1,  shell2,  shell3,  shell4,  shell5,  
dd shell6,  shell7,  shell8,  shell9,  shell10, 
dd shell11, 

;Shell List Control Strings
;This is the full Shell functionality
shell1  db 'USB Central: init usb controller, flash drive, mouse',0
shell2  db 'File Manager',0
shell3  db 'TEDIT Text Editor',0
shell4  db 'XXD: Memory Hex Dump',0
shell5  db 'View Dump',0
shell6  db 'Calculator',0
shell7  db 'Palette Manager',0
shell8  db 'Date/Time',0
shell9  db 'Processor Info',0
shell10 db 'DD: Raw byte copy to Flash Drive',0
shell11 db 'Bitmap Viewer/Converter',0

;here we store in a table the addresses of all the functions 
;that can be called from the shell
;the order of these functions must match strings in the list above
ShellCallTable:
dd ShellUsbCentral
dd ShellFileManager
dd ShellTedit
dd ShellRunXXD              
dd ShellViewDump
dd ShellCalculator    
dd ShellPaletteMgr   
dd ShellDateTime    
dd ShellProcessorInfo      
dd ShellDD                
dd ShellBitmapViewer



;HERSHEYSTRUC  for "Welcome to tatOS"
tatOS_welcome:
dd 0              ;output device = screen
dd 100            ;XC start
dd 50             ;YC start
dd shellstr7      ;address of string
dd RED            ;color
dd HERSHEYGOTHIC  ;font
dd 0xffffffff     ;solid line 



;misc strings
shellstr1 db 'DateTime',0
shellstr2 db 'Save IMAGEBUFFER',0
shellstr3 db 'Windows 256 color Bitmap written to file <screenshbmp> in cwd',0
shellstr4 db 'screenshbmp',0  ;11 char filename with bmp extension 
shellstr5 db 'Save Image Buffer to Flash',0
shellstr6 db 'Enter BTS filename for screenshot',0
shellstr7 db 'Welcome to tatOS',0



;**********************************************************************



shell:


	call backbufclear


	;"Welcome to tatOS" string using Hershey Gothic
	mov edi,tatOS_welcome
	fld qword [two]     ;st0=2.0 scale factor
	call putshershey
	ffree st0           ;must free the scale factor


	;Instruction string
	STDCALL FONT01,0,100,shellstr0,0xefff,putsml

	;populate the list control buffer with strings
	mov ebx,0x2950000
	mov ecx,0

.populateListControlBuf:
	push dword [ShellStrings+ecx*4]
	push ebx
	call strcpy2

	add ebx,0x100
	add ecx,1
	cmp ecx,QTY_SHELL_LIST_CTRL_STRINGS
	jb .populateListControlBuf

	;setup the list control
	mov eax,QTY_SHELL_LIST_CTRL_STRINGS
	mov ebx,300   ;Ylocation top of list control
	call ListControlInit


.appmainloop:
	call ListControlPaint
	call swapbuf
	call getc

	;this shell does not respond to ESC
	;because you can never leave the shell
	;you can only invoke other functions
	;to shutdown the computer just power off
	;cmp al,ESCAPE
	;jz .done

	cmp al,ENTER
	jz .callFunction
	jmp .appmainloop

.callFunction:

	;get current selection from list control in ecx
	call ListControlGetSelection  

	call ListControlDestroy

	;execute the shell function
	call [ShellCallTable+ecx*4]


	;we never execute a ret instruction
	;always loop back to shell
	jmp shell





;*********************************************
;               SUBROUTINES
;**********************************************



ShellReturn:
	ret

ShellFileManager:
	mov ebx,1  ;full file manger capability
	call filemanager
	ret

ShellDD:
	call ddShell
	ret


ShellRunXXD:
	call xxdutil
	ret





ShellDateTime:

	mov ecx,30
	call alloc
	jz .done
	push esi  ;save for later free

	mov edi,esi
	call datetime

	STDCALL shellstr1,esi,putmessage
	call getc

	pop esi
	call free
.done:
	ret


ShellCalculator:
	call calculator
	ret


ShellPaletteMgr:
	call PaletteManager
	ret


ShellProcessorInfo:
	call cpuinfo
	ret


ShellTedit:
	;tedit is unique in that we dont use the normal call/ret
	;we just jump to/from it
	;the reason for this is to avoid messing up the kernel stack
	;from tedit we go to the user app using sysexit/sysenter
	;pressing F12 in tedit causes a jmp back to shell
	jmp tedit


ShellViewDump:
	call dumpview
	ret


ShellUsbCentral:
	call UsbCentral
	ret


ShellBitmapViewer:
	call BitmapViewer
	ret









