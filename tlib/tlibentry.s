;tatOS/tlib/tlibEntryProc.s


;tlibEntryProc
;ValidateUserAddress


;tlibEntryProc is the tatOS protected mode kernel entry procedure
;all apps that call kernel functions must enter the kernel here
;all arguments are passed to tlib functions in registers
;all functions in this file are accessible to apps via "sysenter"
;see tatOSinit.s which programs model specific registers MSR's 

;sysexit is also used to start a userland process
;see tedit where pressing F10 makes this happen
;the userland stack pointer is redefined to USERSTACKPTR 0x2400000
;the userland code execution begins at STARTOFEXE 0x2000010


;on kernel entry:
;*****************
;eax = dword integer ID of tlib function call
;ebx, ecx, edx, esi, edi, ebp  may be used to pass user args to kernel

;for reference only, the selectors are as follows on tlib entry:
;cs = ss = 0x10 kernel code selector
;ds = es = fs = gs  0x23 userland data selector


;on kernel exit:
;****************
;ecx = reserved for userland stack pointer
;edx = reserved for userland instruction pointer
;eax, ebx, esi, edi, ebp may be used for tlib function return values if any


;Warning!
;since ecx and edx are used for sysexit and eax is used for sysenter
;userland code that calls a tlib function 
;should preserve these registers with push/pop like this:
;  push eax
;  push ecx
;  push edx
;  invoke your tlib function which will modify eax,ecx,edx
;  pop edx
;  pop ecx
;  pop eax

;the userland stack pointer & return address are automatically saved in 
;the users memory just before the start of userland code 
;this is done with code inserted by ttasm when the sysenter function is assembled

;example of how a user app is to call a kernel function for "dumpstr":
	;mov eax,1                ;1=tlib function ID
	;mov ebx,AddressOfString  ;function argument
	;sysenter

;see ttasm which has sudo 'c' style short forms for the more commonly used 
;function calls:

;dumpstr AddressOfString    (note this trashes ebx)
;dumpebx ebx,AddressStringTag,RegSize
;fillrect x,y,w,h,color
;puts FONT02,x,y,string,color0xttbb
;putebx ebx,x,y,color,size
;putebxdec ebx,x,y,color,signed
;line SOLIDLINE,x1,y1,x2,y2,color
;polyline OpenClose,linetype,AddressPointsArray,QtyPoints,color
;swapbuf




;***********************************************************
;ValidateUserAddress
;check a userland address to make sure its within the users page
;dont let user pass a malicous pointer that will trick 
;kernel into over writting itself or copying parts of itself
;to userland 

;input:
;push userland address   [ebp+8]
;return:
;return:CF set on invalid address, CF is clear if valid

;since we have only 1 userland process at this time (Oct 2013)
;the address/ptr is valid if within 0x2000000->0x2400000
valstr1 db 'tlibentry:ValidateUserAddress:invalid address',0

%macro VALIDATE 1
	push %1
	call ValidateUserAddress
	jc near Exit
%endmacro

;***********************************************************

ValidateUserAddress:

	push ebp
	mov ebp,esp

	cmp dword [ebp+8],0x2000000
	jb .error
	cmp dword [ebp+8],0x2400000
	jb .success

.error:
	mov eax,[ebp+8]
	STDCALL valstr1,0,dumpeax
	stc  ;set cf
	jmp .done
.success:
	clc  ;clear cf
.done:
	pop ebp
	retn 4



;dumy proc for procedures removed from this table, entries may be used
_tlibentrystub:
	jmp near Exit


;**********************************************************************************
tlibEntryJumpTable:                                            ;tlib function ID
dd _backbufclear, _dumpstr, _swapbuf, _dumpreg, _exit2tedit    ;0,1,2,3,4
dd _getc, _fillrect, _putsml, _rand, _dumpebx                  ;5,6,7,8,9
dd _min, _cliprect, _checkc, _puts, _putebx                    ;10,11,12,13,14
dd _pow, _setpixel, _setpalette, _putpalette, _strcpy          ;15,16,17,18,19
dd _strcpy2, _ebxstr, _getbpsl, _swapuserbuf, _getflashinfo    ;20,21,22,23,24
dd _listctrladdstrings, _listctrlpaint, _tlibentrystub         ;25,26,27
dd _setyorient, _polyline, _line, _putc, _putst0               ;28,29,30,31,32
dd _getkeystate, _mmult44, _mmult41, _dumpst0, _sleep          ;33,34,35,36,37
dd _grid, _rectangle, _circle, _putscriptT, _subdivide         ;38,39,40,41,42
dd _putvectorq, _chamfer, _linepolar, _arc, _fillet            ;43,44,45,46,47
dd _putshershey, _rose, _putmarker, _swaprectprep, _swaprect   ;48,49,50,51,52
dd _putscroll, _comprompt, _ebx2dec, _str2eax, _printf         ;53,54,55,56,57
dd _clock, _polar2rect, _setdestvideobuf, _setdaccolor         ;58,59,60,61
dd _arrowpointer, _usbcheckmouse, _getmousexy, _puttransbits   ;62,63,64,65
dd _putmonobits, _putebxdec, _putbits, _putspause              ;66,67,68,69
dd _fatgetfilename, _fatwritefile, _fatreadfile, _filemanager  ;70,71,72,73
dd _splitstr, _xy2i, _choosecolor, _floodfill                  ;74,75,76,77
dd _copytoclipboard, _copyfromclipboard, _isdigit, _dumpmem    ;78,79,80,81
dd _timerinit, _timerstart, _timerstop, _checktimer            ;82,83,84,85
dd _ptinrect, _getmousebutton, _crosspointer, _tlibentrystub   ;86,87,88,89
dd _lineclip, _mirrorpoint, _getpixel, _str2st0                ;90,91,92,93
dd _getslope, _getlength, _intersection, _pointinrectfloat     ;94,95,96,97
dd _projectpointtoline, _rad2deg, _absval, _hline, _vline      ;98,99,100,101,102
dd _pickoption, _gets, _dropdowncreate, _dropdownpaint         ;103,104,105,106
dd _strchr, _rotateline, _getangleinc, _toggle, _offset        ;107,108,109,110,111
dd _gethubinfo, _hypot, _dumpFPUstatus, _dumpview              ;112,113,114,115
dd _dumpst09, _arccos, _strlenB, _st02str, _inflaterect        ;116,117,118,119,120
dd _dumpreset, _showpopup, _dumpstrquote, _linepdf             ;121,122,123,124

;dont forget to increment this tom when you add a function to this table !!!
%define MAXTLIBFUNCTIONID 124
;**********************************************************************************

tlibEntryProc:

	;we got here when user land code executed a sysenter instruction
	;interrupts are disabled by sysenter
	;at this point we have cs=ss=0x10 kernel code as set by sysenter
	;ds=es=fs=gs=0x23 userland data
	;these values for ds,es,fs,gs are set in tedit 
	;when you press F10 to run the app
	;in a flat binary environment its ok to execute kernel code with 
	;userland values for ds,es,fs,gs data
	;the CPL is determined by bits1:0 of cs & ss only
	;in 64bit these segment registers are I understand not used anyway
	;google for "Intel P6 vs P7 system call performance" 
	;from Linus Torvalds dated Tue Dec 24, 2002
	;for more discussion on use of userland data selectors in kernel code

		

	;interrupts are normally enabled just before sysexit
	;we need interrupts for getc and checkc
	sti  


	;check for eax value within range 
	;eax=ID of tlib function to call
	cmp eax,0
	jb near Exit
	cmp eax,MAXTLIBFUNCTIONID
	ja near Exit


	;jump to the required tlib function
	jmp [tlibEntryJumpTable + eax*4]



_backbufclear:  
	;eax=0
	call backbufclear
	jmp near Exit

_dumpstr: 
	;eax=1
	;ebx=address of string
	push ebx 
	call dumpstr
	jmp near Exit

_swapbuf:
	;eax=2
	call swapbuf
	jmp near Exit

_dumpreg:
	;mov eax,3   ;dumpreg
	call dumpreg
	jmp near Exit

_exit2tedit:
	;eax=4
	;all user apps must exit with "sysenter" which takes them here
	;user apps must not end with "ret" 
	mov ebx,0  ;reset video to BACKBUF for kernel
	call setdestvideobuf
	;in case the userland code created a list control
	call ListControlDestroy
	;redirect to tedit so user may continue to work on some cool asm code
	jmp tedit

_getc:
	;eax=5
	call getc
	jmp near Exit
	
_fillrect:
	;eax=6
	push ebx   ;x upper left
	push ecx   ;y
	push edx   ;width
	push esi   ;height
	push edi   ;color
	call fillrect
	jmp near Exit

_putsml:
	;eax=7
	VALIDATE esi
	push ebx   ;fontID
	push ecx   ;x
	push edx   ;y
	push esi   ;address of string
	push edi   ;color 0000ttbb
	call putsml
	jmp near Exit

_rand:
	;eax=8
	;ebx=0 to get random num or nonzero to provide a seed
	call rand  ;eax=random num
	jmp near Exit

_dumpebx:
	;eax=9
	;ebx=value to dump
	push ecx    ;address of string
	push edx    ;register size 0=dword, 1=word, 2=byte, 3=signed decimal
	call dumpebx
	jmp near Exit

_min:
	;eax=10
	;ebx=first num
	;ecx=2nd num
	call min   
	;ebx=min value
	jmp near Exit

_cliprect:
	;eax=11
	;ebx=x
	;ecx=y
	;edx=width
	;esi=height
	call cliprect  
	;return eax=Xclip, ebx=Yclip, esi=Wclip, edi=Hclip
	jmp near Exit

_checkc:
	;eax=12
	call checkc  ;al=ascii char, zf set if no keypress
	jmp near Exit

_puts:
	;eax=13
	push ebx   ;fontID
	push ecx   ;x
	push edx   ;y
	push esi   ;Address of String
	push edi   ;color 0000ttbb
	call puts
	jmp near Exit

_putebx:
	;eax=14
	;ebx=value to be displayed as hex
	push ecx  ;x
	push edx  ;y
	push esi  ;colors 0000ttbb
	push edi  ;size 0=ebx, 1=bx, 2=bl
	call putebx
	jmp near Exit

_pow:
	;eax=15
	;ebx=address of qword X
	;ecx=address of qword Y
	;edx=address of qword result
	push ebx
	push ecx
	push edx
	call pow
	jmp near Exit

_setpixel:
	;eax=16
	;ebx=X
	;ecx=Y
	;edx=color
	call setpixel
	jmp near Exit

_setpalette:
	;eax=17
	;ebx=palette argument, 0=std, 1=gray, N=custom
	;if ebx=N then edx=0000ttbb kernel text message color
	push ebx
	call setpalette
	jmp near Exit

_putpalette:
	;mov eax,18    ;putpalette
	call putpalette
	jmp near Exit

_strcpy:
	;mov eax,19    ;strcpy
	VALIDATE esi   ;address source str
	VALIDATE edi   ;adderss dest str
	call strcpy
	jmp near Exit

_strcpy2:
	;mov eax,20    ;strcpy2
	VALIDATE ebx   ;address source str
	VALIDATE ecx   ;address dest str
	push ebx
	push ecx
	call strcpy2
	jmp near Exit

_ebxstr:
	;mov eax,21   ;ebxstr
	;ebx = value to convert to hex
	VALIDATE ecx  ;address 0 term string tag
	VALIDATE edx  ;address dest buffer
	push ecx
	push edx
	call ebxstr
	jmp near Exit

_getbpsl:
	;mov eax,22
	call getbpsl  ;returns eax=BPSL
	jmp near Exit

_swapuserbuf:
	;mov eax,23
	;esi=address of private pixel buf
	VALIDATE esi
	call swapuserbuf
	jmp near Exit

_getflashinfo:
	;mov eax,24
	;edi=destination address to write to
	VALIDATE edi
	call getflashinfo
	jmp near Exit

_listctrladdstrings:
	;mov eax,25
	;mov ebx,AddressofArrayof0termStrings
	;mov ecx,QtyStrings
	;mov edx,YlocationListControl
	VALIDATE ebx
	call ListControlAddStrings
	jmp near Exit

_listctrlpaint:
	;mov eax,26
	call ListControlPaint
	jmp near Exit



	;this entry is available
	;mov eax,27

_setyorient:
	;mov eax,28
	;mov ebx,ValueOfYorient  (1=topdown, -1=bottomup)
	call setyorient
	jmp near Exit

_polyline:
	;mov eax,29
	push ebx  ;1=close 0=open
	push ecx  ;linetype
	push edx  ;AddressOfPointsArray
	push esi  ;QtyPoints
	push edi  ;color
	call polyline
	jmp near Exit

_line:
	;mov eax,30
	push ebx  ;linetype  (0xffffffff=solid)
	push ecx  ;x1
	push edx  ;y1
	push esi  ;x2
	push edi  ;y2
	push ebp  ;color
	call line
	jmp near Exit

_putc:
	;mov eax,31
	;mov ebx,fontID (1=FONT01 default, 2=FONT02)
	;mov ecx,AsciiChar2Display
	;mov edx,color 0000ttbb 
	;mov esi,xloc
	;mov edi,yloc
	call putc
	jmp near Exit

_putst0:
	;mov eax,32
	push ebx  ;fontID
	push ecx  ;Xloc
	push edx  ;Yloc
	push esi  ;color 0000ttbb
	push edi  ;NumberOfDecimalPlaces
	call putst0
	jmp near Exit

_getkeystate:
	;mov eax,33
	;ebx=keynum (CTRL=0, SHIFT=1, ALT=2, SPACE=3)
	call GetKeyState  ;returns eax = 1 if down else 0 if up
	jmp near Exit

_mmult44:
	;mov eax,34
	;mov esi=Address of matrix_A 
    ;mov edi=Address of matrix_B 
    ;mov ebx=Address of destination matrix_C
	call mmult44
	jmp near Exit

_mmult41:
	;mov eax,35
	;mov esi=Address of matrix_A 
    ;mov edi=Address of vector_B 
    ;mov ebx=Address of destination vector_C
	call mmult41
	jmp near Exit

_dumpst0:
	;mov eax,36
	VALIDATE ebx  ;address of string tag
	push ebx
	call dumpst0
	jmp near Exit

_sleep:
	;mov eax,37
	;ebx=amount to sleep in ms
	call sleep
	jmp near Exit

_grid:
	;mov eax,38
	push ebx  ;line spacing in x & y
	push ecx  ;color index (0-0xff) 
	call grid
	jmp near Exit

_rectangle:
	;mov eax,39
	push ebx    ;x
	push ecx    ;y
	push edx    ;width
	push esi    ;height
	push edi    ;color
	call rectangle
	jmp near Exit

_circle:
	;mov eax,40
	push ebx    ;1=filled, 0=unfilled
	push ecx    ;xcenter
	push edx    ;ycenter
	push esi    ;radius  
	push edi    ;color
	call circle
	jmp near Exit

_putscriptT:
	;mov eax,41
	push ebx  ;X
	push ecx  ;Y
	call putscriptT
	jmp near Exit

_subdivide:
	;mov eax,42
	VALIDATE ebx
	VALIDATE edx
	push ebx  ;Address of source array dword Points
	push ecx  ;qty points in source
	push edx  ;Address of destination array
	call subdivide
	jmp near Exit

_putvectorq:
	;mov eax,43
	push ebx  ;Address of qword vector
	push ecx  ;color
	call putvectorq
	jmp near Exit

_chamfer:
	;mov eax,44
	push ebx   ;Address of qword vector A
	push ecx   ;Address of qword vector B
	push edx   ;Address to store qword vector C
	push esi   ;Address of qword chamfer C size
	call chamfer
	jmp near Exit

_linepolar:
	;mov eax,45
	push ebx   ;linetype
	push ecx   ;xstart
	push edx   ;ystart
	push esi   ;radius
	push edi   ;angle,deg
	push ebp   ;color
	call linepolar
	jmp near Exit

_arc:
	;mov eax,46
	;ebp=address of ARC structure
	VALIDATE ebp
	call arc
	jmp near Exit

_fillet:
	;mov eax,47
	VALIDATE ebx
	VALIDATE ecx
	VALIDATE edx
	VALIDATE esi
	VALIDATE edi
	push ebx   ;Address of qword vector A
	push ecx   ;Address of qword vector B
	push edx   ;Address of qword arc radius
	push esi   ;Address of 20 byte results buffer1
	push edi   ;Address of 64 byte results buffer2
	call fillet
	jmp near Exit

_putshershey:
	;mov eax,48
	VALIDATE edi  ;edi=address of 28 byte HERSHEYSTRUC
	;st0 = qword scale factor
	call putshershey
	jmp near Exit

_rose:
	;mov eax,49
	;st0 = Kfactor
	;st1 = Amplitude
	;st2 = X center of rose
	;st3 = Y center of rose
	;edi = address of destination buffer 
	VALIDATE edi
	call rose
	jmp near Exit

_putmarker:
	;mov eax,50
	push ebx      ;marker style (1=square, 2=X, 3=cross)
	push ecx      ;color
	push edx      ;xlocation
	push esi      ;ylocation
	call putmarker
	jmp near Exit

_swaprectprep:
	;mov eax,51
	push ebx  ;xloc in LFB
	push ecx  ;yloc in LFB
	push edx  ;width
	push esi  ;height
	call swaprectprep
	jmp near Exit

_swaprect:
	;mov eax,52
	call swaprect
	jmp near Exit

_putscroll:
	;mov eax,53
	VALIDATE ebx
	push ebx  ;address of string
	call putscroll
	jmp near Exit

_comprompt:
	;mov eax,54
	VALIDATE ebx
	VALIDATE ecx
	push ebx  ;address of prompt string
	push ecx  ;address of destination buffer
	call comprompt
	jmp near Exit
	
_ebx2dec:
	;mov eax,55
	;ebx=value to be converted to string
	VALIDATE ecx
	push ecx   ;Address of dest buffer
	push edx   ;0=unsigned dword, 1=signed dword
	push esi   ;0=zero terminate, 1=dont zero terminate
	call ebx2dec
	jmp near Exit

_str2eax:
	;mov eax,56
	;esi=Address of string
	VALIDATE esi
	call str2eax
	jmp near Exit

_printf:
	;mov eax,57
	;ecx=qty of arguments 
	;ebx=address of arguments type array
	;esi=address of arguments list array
	;edi=address of destination buffer
	VALIDATE ebx
	VALIDATE esi
	VALIDATE edi
	call printf
	jmp near Exit

_clock:
	;mov eax,58
	call clock
	jmp near Exit

_polar2rect:
	;mov eax,59
	push ebx  ;radius,pixels
	push ecx  ;theta,degrees (0,1,2...359)
	call polar2rect
	jmp near Exit

_setdestvideobuf:
	;mov eax,60
	;ebx = address of private pixel buffer or 0 for BACKBUF
	;ecx = width of pixel buffer (bytesperscanline)
	cmp ebx,0
	jz .skipcheck
	VALIDATE ebx
.skipcheck:
	call setdestvideobuf
	jmp near Exit

_setdaccolor:
	;mov eax,61
	;dl=rr (red byte 0-0x3f)  
	;dh=gg (gre byte 0-0x3f) 
	;bl=bb (blu byte 0-0x3f)
	;cl=color index you want to change (0->0xff = background)
	call setdaccolor
	jmp near Exit

_arrowpointer:
	;mov eax,62
	call arrowpointer
	jmp near Exit

_usbcheckmouse:
	;mov eax,63
	call usbcheckmouse  ;al=mouse button or wheel
	jmp near Exit

_getmousexy:
	;mov eax,64
	call getmousexy  ;returns eax=mouseX, ebx=mouseY, esi=mouseDX, edi=mouseDY
	jmp near Exit

_puttransbits:
	;mov eax,65
	push ebx   ;x
	push ecx   ;y
	push edx   ;width
	push esi   ;height
	push edi   ;address of bits
	call puttransbits
	jmp near Exit

_putmonobits:
	;mov eax,66
	push ebx   ;x
	push ecx   ;y
	push edx   ;width
	push esi   ;height
	push edi   ;address of bits
	push ebp   ;color
	call putmonobits
	jmp near Exit

_putebxdec:
	;mov eax,67
	;ebx=value to be displayed as decimal
	push ecx    ;x
	push edx    ;y
	push esi    ;colors 0000ttbb
	push edi    ;0=unsigned dword, 1=signed dword       
	call putebxdec
	jmp near Exit

_putbits:
	;mov eax,68
	push ebx     ;xstart
	push ecx     ;ystart
	push edx     ;width
	push esi     ;height
	push edi     ;address of bits
	call putbits
	jmp near Exit

_putspause:
	;mov eax,69
	VALIDATE ebx
	push ebx    ;address of string
	call putspause
	jmp near Exit

_fatgetfilename:
	;mov eax,70
	VALIDATE ebx
	push ebx             ;address of 0 terminated prompt string
	call fatgetfilename  ;filename string is saved at COMPROMPTBUF
	jmp near Exit

_fatwritefile:
	;requires a pervious call to fatgetfilename
	;mov eax,71
	VALIDATE ebx
	push ebx   ;address of file data
	push ecx   ;filesize,bytes
	call fatwritefile  
	jmp near Exit

_fatreadfile:
	;mov eax,72
	VALIDATE ebx
	push ebx   ;destination memory address
	call fatreadfile
	jmp near Exit

_filemanager:
	;mov eax,73
	mov ebx,0   ;file chooser by default for user
	call filemanager
	jmp near Exit

_splitstr:
	;mov eax,74
	VALIDATE ebx
	VALIDATE esi
	push ebx    ;starting address of parent string
	push ecx    ;seperator byte (usually COMMA or PLUS)
	push edx    ;max qty substrings allowed
	push esi    ;address of memory block to hold array of substring addresses  
	call splitstr
	jmp near Exit

_xy2i:
	;mov eax,75
	push ebx  ;x
	push ecx  ;y
	push edx  ;bmwidth
	call xy2i ;eax=index
	jmp near Exit

_choosecolor:
	;mov eax,76
	call choosecolor  ;return color in eax
	jmp near Exit

_floodfill:
	;mov eax,77
	VALIDATE ebx
	push ebx     ;BitmapAddress
	push ecx     ;Xseed
	push edx     ;Yseed 
	push esi     ;bitmap width
	push edi     ;bitmap height
	push ebp     ;color to set
	call floodfill
	jmp near Exit

_copytoclipboard:
	;mov eax,78
	push ebx   ;starting address 
	push ecx   ;qty bytes
	call copytoclipboard
	jmp near Exit

_copyfromclipboard:
	;mov eax,79
	push ebx   ;starting address 
	call copyfromclipboard
	jmp near Exit

_isdigit:
	;mov eax,80
	;bl=ascii byte to examine
	call isdigitB
	jmp near Exit

_dumpmem:
	;mov eax,81
	push ebx    ;starting memory address
	push ecx    ;qty bytes
	call dumpmem
	jmp near Exit

_timerinit:
	;mov eax,82
	;ebx=time interval, milliseconds
	;ecx=name of user callback function
	call timerinit
	jmp near Exit

_timerstart:
	;mov eax,83
	call timerstart
	jmp near Exit

_timerstop:
	;mov eax,84
	call timerstop
	jmp near Exit

_checktimer:
	;mov eax,85
	call checktimer
	jmp near Exit

_ptinrect:
	;mov eax,86
	VALIDATE ebx
	push ebx  ;address of rect  x1,y1,x2,y2  16 bytes
	push ecx  ;dword Px
	push edx  ;dword Py
	call ptinrect
	jmp near Exit

_getmousebutton:
	;mov eax,87
	;ebx=0 for Lbut, 1 for Mbut, 2 for Rbut
	call getmousebutton  ;returns eax=1 for down, 0 for up, 0xff on error
	jmp near Exit

_crosspointer:
	;mov eax,88
	call crosspointer
	jmp near Exit


	;this entry is available
	;mov eax,89


_lineclip:
	;mov eax,90
	;esi=address of UNclipped line endpoints in memory
	;ebp=address of where this function writes CLipped endpoints to
	VALIDATE esi
	VALIDATE ebp
	call lineclip  ;return value in eax
	jmp near Exit

_mirrorpoint:
	;mov eax,91
	VALIDATE ebx
	VALIDATE ecx
	VALIDATE edx
	push ebx     ;address of mirror line L12 endpoints 32 bytes
	push ecx     ;address of point to be mirrored      16 bytes
	push edx     ;address of mirrored point storage    16 bytes
	call mirrorpoint
	jmp near Exit

_getpixel:
	;mov eax,92
	push ebx   ;x
	push ecx   ;y
	call getpixel
	jmp near Exit

_str2st0:
	;mov eax,93
	;ebx=address of string
	VALIDATE ebx
	call str2st0
	jmp near Exit

_getslope:
	;mov eax,94
	VALIDATE ebx
	push ebx       ;address of qword vector x1,y1,x2,y2  32 bytes
	call getslope  ;returns st0=dx, st1=dy
	jmp near Exit

_getlength:
	;mov eax,95
	;st0=dx, st1=dy
	call getlength
	jmp near Exit

_intersection:
	;mov eax,96
	VALIDATE ebx
	VALIDATE ecx
	VALIDATE edx
	push ebx     ;address of qword vector x1,y1,x2,y2 (32 bytes)
    push ecx     ;address of qword vector x3,y3,x4,y4 (32 bytes)
	push edx     ;address of destination point Px,Py  (16 bytes)
	call intersection
	jmp near Exit

_pointinrectfloat:
	;mov eax,97
	VALIDATE ebx
	VALIDATE ecx
	push ebx     ;address of qword x1,y1,x2,y2 rect corners (32 bytes)
	push ecx     ;address of qword point x,y (16 bytes)
	call pointinrectfloat
	jmp near Exit

_projectpointtoline:
	;mov eax,98
	VALIDATE ebx
	VALIDATE ecx
	push ebx                 ;address of Line12  (32 bytes)
	push ecx                 ;address of Line34  (32 bytes)
	call projectpointtoline  ;x4,y4 is written
	jmp near Exit
	
_rad2deg:
	;mov eax,99
	;st0=angle value in radians
	call rad2deg
	jmp near Exit

_absval:
	;mov eax,100
	;ebx=value to remove sign
	call absvalB  ;return value in eax
	jmp near Exit

_hline:
	;mov eax,101
	;ebx = xstart 
	;ecx = ystart 
	;edx = length,pixels 
	;esi = color index (0-255)
	call hline
	jmp near Exit

_vline:
	;mov eax,102
	;ebx = xstart 
	;ecx = ystart 
	;edx = length,pixels 
	;esi = color index (0-255)
	call vline
	jmp near Exit

_pickoption:
	;mov eax,103
	push ebx      ;address of Title string
	push ecx      ;address of Options string
	push edx      ;width of dialog box 
	push esi      ;height of dialog box
	call pickoption
	jmp near Exit

_gets:
	;mov eax,104
	;ebx = xstart 
	;esi = ystart 
	;ecx = maxnumchars (1-80)
	;edi = address of char buffer to store string (size=ecx+1)
	;edx = colors, (00ccbbtt) cc=caret, bb=background, tt=text
	mov eax,esi
	call gets
	jmp near Exit

_dropdowncreate:
	;mov eax,105
    ;ebx=address of DROPDOWNSTRUC
	VALIDATE ebx
	push ebx
	call dropdowncreate
	jmp near Exit

_dropdownpaint:
	;mov eax,106
    ;ebx=address of DROPDOWNSTRUC
	VALIDATE ebx
	push ebx
	call dropdownpaint
	jmp near Exit

_strchr:
	;mov eax,107
	;bl=byte to search for
	;edi=address of parent string
	VALIDATE edi
	call strchrB
	jmp near Exit

_rotateline:
	;mov eax,108
	VALIDATE ebx
	VALIDATE ecx
	VALIDATE edx
	VALIDATE esi
	push ebx   ;Address of line segment coordinates qword x1,y1,x2,y2 to rotate
	push ecx   ;Address of 32 bytes of memory to store rotated line endpoints
	push edx   ;Address of rotation angle,qword radians
	push esi   ;Address of center point coordinates qword xc,yc
	call rotateline
	jmp near Exit

_getangleinc:
	;mov eax,109
	VALIDATE ebx
	VALIDATE ecx
	push ebx     ;Address of qword vector A
	push ecx     ;Address of qword vector B 
	call getangleinc
	jmp near Exit

_toggle:
	;mov eax,110
	;ebx=address of dword in memory to toggle
	VALIDATE ebx
	call toggle
	jmp near Exit

_offset:
	;mov eax,111
	VALIDATE ebx
	VALIDATE ecx
	VALIDATE edx
	push ebx      ;address of qword vector x1,y1,x2,y2
	push ecx      ;address of 32bytes of memory to store new offset vector
	push edx      ;address of qword offset amount
	call offset
	jmp near Exit

_gethubinfo:
	;mov eax,112
	;edi=destination address to write to
	VALIDATE edi
	call gethubinfo
	jmp near Exit

_hypot:
	;mov eax,113
	VALIDATE ebx
	VALIDATE ecx
	VALIDATE edx
	push ebx     ;Address of length side A
	push ecx     ;Address of length side B  
	push edx     ;Address to store result Length of hypot
	push esi     ;Size of input/return values (0=dword, 1=qword)
	call hypot
	jmp near Exit

_dumpFPUstatus:
	;mov eax,114
	call dumpFPUstatus
	jmp near Exit

_dumpview:
	;mov eax,115
	call dumpview
	jmp near Exit

_dumpst09:
	;mov eax,116
	call dumpst09
	jmp near Exit

_arccos:
	;mov eax,117
	;st0=input value
	call arccos
	jmp near Exit

_strlenB:
	;mov eax,118
	VALIDATE ebx  ;ebx=address of 0 terminated string
	call strlenB
	jmp near Exit

_st02str:
	;mov eax,119
	VALIDATE ebx  ;ebx=address of 24 byte ascii dest buffer
	push ebx
	push ecx      ;ecx=num decimals
	call st02str
	jmp near Exit

_inflaterect:
	;mov eax,120
	;esi=address of x1,y1,x2,y2
	;edi=amount to inflate
	VALIDATE esi
	call inflaterect
	jmp near Exit

_dumpreset:
	;mov eax,121
	call dumpreset
	jmp near Exit

_showpopup:
	;mov eax,122
	VALIDATE esi   ;esi=address of DROPDOWNSTRUC
	call showpopup
	jmp near Exit

_dumpstrquote:
	;mov eax,123
	VALIDATE ebx  ;ebx=address of string
	push ebx
	call dumpstrquote
	jmp near Exit

_linepdf:
	;mov eax,124
	VALIDATE edi  
	push edi      ;destination pdf buffer
	push ebx      ;x1
	push ecx      ;y1
	push edx      ;x2
	push esi      ;y2
	call linepdf
	jmp near Exit





Exit:

	;retrieve userland ESP stack pointer
	mov ecx,[0x2000004]

	;retrieve userland EIP return address (1st byte after sysenter)
	mov edx,[0x2000000]  

	;(see ttasm SYSENTER where the code to save ESP & EIP is generated)

	;tedit also has similar code when pressing F10 to run userland code

	;NOTE: ecx and edx are not preserved !!!
	
	;return to the userland proc using ecx & edx & MSR's set in tatOSinit.s
	;processor will switch cs,ss 
	sysexit





