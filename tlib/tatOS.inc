;tatOS/tlib/tatos.inc

;some defines and macros for tatOS

;WARNING !
;dont forget to update ttasm if you make changes in this file
;ttasm has some hard coded memory addresses too


;TIMES error
;***************
;here is where you increase the size of tatOS
;if you assembled tatOS and get a TIMES error (-) you must increase this value
;SIZEOFTLIB is used at the end of tlib.s
;to set the qty blocks of assembled code
;SIZEOFTLIB is also used in boot2.s for loading tatOS
%define SIZEOFTLIB 290


;my SimpleTech flash drive has a listed capacity of 250meg
;250,000,000/512 =488,281 blocks
LBAMAX equ 488000




;some names for memory addresses 
;see doc/memorymap 
;********************************
%define LFB               0x500    ;linear frame buffer
%define ASCIIKEYDN        0x504
%define CTRLKEYSTATE      0x506    ;byte
%define SHIFTKEYSTATE     0x507    ;byte
%define ALTKEYSTATE       0x508    ;byte
%define SPACEKEYSTATE     0x50a    ;byte
%define RANDSEED          0x514
%define PITCOUNTER        0x51c
%define UHCIBASEADD       0x530
%define BPSL              0x538    ;bytesperscanline
%define BPSL64            0x53c    ;BPSL*600/64
%define BPSL4             0x540    ;BPSL*600/4
%define PRIVATEPIXELBUF   0x544    ;1=yes, 0=no use BACKBUF
%define USBERROR          0x548    ;read10 error codes
%define MOUSEX            0x554
%define MOUSEY            0x558
%define MOUSE_DX          0x5e4
%define MOUSE_DY          0x5e8
%define LBUTTONDOWN       0x5ec
%define MBUTTONDOWN       0x5f0
%define RBUTTONDOWN       0x5f4
%define UHCIBUSDEVFUN     0x560
%define EHCIBUSDEVFUN     0x568
%define YORIENT           0x56c
%define TIMERSTART        0x594
%define TIMERELAPSED      0x598
%define TIMERCALLBACK     0x59c
%define XOFFSET           0x5b4
%define YOFFSET           0x5b8
%define KERNELTXTCOLOR    0x5bc
%define LFBSTART          0x5c0
%define WINDOWIDTH        0x5c4
%define WINDOWHEIGHT      0x5c8
%define WINDOWROWADVANCE  0x5cc
%define EHCIUSBBASE       0x5d0
%define EHCIOPERBASE      0x5d4
%define UHCIBUSDEVFUNCOM1 0x5d8  ;uhci companion controller #1
%define UHCIBUSDEVFUNCOM2 0x5dc  ;uhci companion controller #2



;std line types 
%define SOLIDLINE   0xffffffff
%define CENTERLINE  0xffffe1f0
%define HIDDENLINE  0xffc0ffc0
%define PHANTOMLINE 0xfff0f0f0
%define DOTLINE     0xc2108420


;see polar.s
%define SINTABLE  0xf000
%define COSTABLE  0xf600


;some important memory addresses
%define TEDITMEMORYSTART 0x100000   ;tedit double link list  memory
%define USBDATASTORAGE   0xb70000
%define BACKBUF          0x1100000  ;graphic functions draw here
%define CLIPBOARD        0x1300000  ;The Clipboard starts here
%define FILENAME         0x198fb00  ;filemanager saves 0 terminated filename string here
%define NAMEOFCWD        0x198fe00  ;holds ascii string name of CurrentWorkingDirectory
%define COMPROMPTBUF     0x198ff00  ;Comprompt Buffer
%define STARTOFEXE       0x2000010  ;start of executable code
%define USERSTACKPTR     0x2400000  ;user land stack pointer
%define LISTCTRLBUF      0x2950000  ;list control buffer
%define IMAGEBUFFER      0x2ba0000  ;image buffer for paint
%define STARTOFDUMP      0x2ca0000  ;start of the DUMP


;indirect function address table for tlib functions in /boot
%define PUTS           0x1000c
%define SETPALETTE     0x10030
%define GENSTDPALETTE  0x10034
%define PUTEAX         0x10054
%define SWAPBUF        0x10068
%define DUMPRESET      0x100b0
%define DUMPSTR        0x100d8
%define GENGRAYPAL     0x10108
%define FILLSINCOS     0x10140
%define DUMPEAX        0x10144
%define GETREGINFO     0x1014c
%define PUTSCROLL      0x1018c
%define SHELL          0x10194
%define PRINTSCREEN    0x101c8
%define TEDITBLANKLIST 0x102dc
%define TATOSINIT      0x102e0
%define PUTEAXSTR      0x10284



;the vga16 colors 
;see palette.s for rgb values of these colors
;these colors are the same for the std or gray palette
;tom how come we dont have and ORA orange color here ?????
%define BLA   239  ;ef  black
%define BLU   240  ;f0  blue
%define GRE   241  ;f1  green
%define CYA   242  ;f2  cyan
%define MAG   243  ;f3  magenta
%define BRN   244  ;f4  brown
%define RED   245  ;f5  red
%define LGR   246  ;f6  light gray
%define GRA   247  ;f7  dark gray
%define LBL   248  ;f8  light blue
%define LGN   249  ;f9  light green
%define LCY   250  ;fa  light cyan
%define LRE   251  ;fb  light red
%define LMA   252  ;fc  light magenta
%define YEL   253  ;fd  yellow
%define WHI   254  ;fe  white
%define BKCOLOR   0xff 



;shades of gray in the stdpalette
;going from dark to light
%define GRAY1  216   ;r=g=b=0  black
%define GRAY2  217   ;r=g=b=3
%define GRAY3  218   ;6
%define GRAY4  219   ;9
%define GRAY5  220   ;12
%define GRAY6  221   ;15
%define GRAY7  222   ;18
%define GRAY8  223   ;21
%define GRAY9  224   ;24
%define GRAY10 225   ;27
%define GRAY11 226   ;30
%define GRAY12 227   ;33
%define GRAY13 228   ;36
%define GRAY14 229   ;39
%define GRAY15 230   ;42
%define GRAY16 231   ;45
%define GRAY17 232   ;48
%define GRAY18 233   ;51
%define GRAY19 234   ;54
%define GRAY20 235   ;57
%define GRAY21 236   ;60
%define GRAY22 237   ;63 white




;defines for fonts
%define FONT01 1
%define FONT02 2
%define HERSHEYROMANLARGE 0
%define HERSHEYGOTHIC     1
%define HERSHEYROMANSMALL 2


;*******************************************************
;non-displayable KEYDOWNS and ascii chars
;in addition to the usual ascii codes
;our keyboard driver keyboard.s will return
;the following values in 0x504 for examination by getc
;********************************************************

%define EOF         0x0
%define TAB         0x9
%define NEWLINE     0xa
%define NL          0xa
%define SPACE       0x20  ;' '
%define SPACEBAR    0x20  
%define PLUS        0x2b
%define COMMA       0x2c
%define COLON       0x3a
%define SEMICOLON   0x3b
%define SINGLEQUOTE 0x27 ;'

;most printable ascii ends with 0x7f
;these non-printables are numbered sequentially
;here we have deviated from ascii
;do not change these numbers because
;tedit has a jumptable which 
;depends on these numbered sequentially as shown
%define F1       0x80
%define F2       0x81
%define F3       0x82
%define F4       0x83
%define F5       0x84
%define F6       0x85
%define F7       0x86
%define F8       0x87
%define F9       0x88
%define F10      0x89
%define F11      0x8a
%define F12      0x8b
%define ESCAPE   0x8c
%define SHIFT    0x8d
%define CAPSLOCK 0x8e
%define CTRL     0x8f
%define ALT      0x90
%define NUMLOCK  0x91
%define BKSPACE  0x92
%define HOME     0x93
%define END      0x94
%define UP       0x95  ;up arrow
%define DOWN     0x96  ;dn arrow
%define LEFT     0x97
%define RIGHT    0x98
%define PAGEUP   0x99
%define PAGEDN   0x9a
%define CENTER   0x9b
%define INSERT   0x9c
%define DELETE   0x9d
%define PRNTSCR  0x9e
%define SCRLOCK  0x9f
%define ENTER    0xa0
%define CUT      0xa1   ;Ctrl+x
%define COPY     0xa2   ;Ctrl+c
%define PASTE    0xa3   ;Ctrl+v
%define GUI      0xa4
%define MENU     0xa5





;******************************************************
;STDCALL
;this nasm macro provides kernel code with a short
;hand way to call other kernel functions which
;take args on the stack
;e.g. STDCALL 1,2,3,4,myproc
;is the same as:
;push dword 1
;push dword 2
;push dword 3
;push dword 4
;call myproc
;args are pushed on the stack left->right
;the last arg is the address of function entry
;and the function is responsible to cleanup the stack
;*****************************************************

%macro STDCALL 2-10
	%rep %0-1
	push dword %1
	%rotate 1
	%endrep
	call %1
%endmacro


