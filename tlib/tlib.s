;tatOS/tlib/tlib.s
;June 2015


;tlib.s
;toms library
;NASM assembly language routines for tatOS

;this file includes all /tlib files and /usb files 

;functions which access video memory 
;are customized for 800x600x8bpp graphics mode
;and write to a back buffer for double buffering

;functions which draw text (putc,puts,getc,gets...)
;are customized for the font01.inc & font02.inc

;the default coordinate system for graphic functions is:
;the pixel 0,0 is the upper left corner of the screen
;the pixel 799,599 is the lower right corner of the screen
;this can be modified with YORIENT, XOFFSET, YOFFSET
;see /doc/memorymap


;Tom Timmermann
;tatOS
;see /doc/LICENSE
;******************************************************

%include "tatOS.config"
%include "tlib/tatOS.inc"

bits 32

;boot2 loads the entire library to 0x10000
org 0x10000



;note as of tatOS 2013 this indirect function call table is obsolete
;tatOS apps can not call tlib functions indirectly
;paging is now active and any attempt to call these functions indirectly
;will result in a paging violation
;only the kernel can call these functions indirectly

;here is our table of addresses of exported tlib functions
;allowing apps to make indirect calls to tlib functions
;for example to call the gets function:
;call [0x10004] 
;or within tlib: call gets ---- do not call [gets] :(
;or outside tlib: call [GETS]  
;where symbol GETS=0x10004 is hardcoded in ttasm.s
;if you dont want some function to be available to apps
;then dont put it in this list.
;as noted below you must also update the ttasm symbol table (ttasm.s)
;to associate the function entry point name using CAPITAL letters
;with the function address

;[1] denotes this function is used somewhere in /boot code

;*******************************************************
;  WARNING !!!    WARNING !!!    WARNING !!!
;DO NOT INSERT ANY CODE OR DATA BEFORE THIS POINT
;0x10000 must be the first address of this table
;Do not leave any holes in this table either
;because tatos.inc has defines for these symbols
;and ttasm has a hardcoded symbol table for these
;Do not insert function names into this table, only append
;each address must be 4 bytes greater than previous
;*******************************************************

;function/data   ;IndirectAddress (=4 bytes greater than previous)
dd getc          ;0x10000
dd gets          ;0x10004 
dd putc          ;0x10008
dd puts          ;0x1000c   [1]
dd absval        ;0x10010 
dd str2eax       ;0x10014
dd putbits       ;0x10018
dd putbits4      ;0x1001c 
dd puttransbits  ;0x10020 
dd mem2str       ;0x10024
dd fillrect      ;0x10028
dd backbufclear  ;0x1002c 
dd setpalette    ;0x10030
dd genstdpalette ;0x10034
dd rand          ;0x10038
dd putreg        ;0x1003c
dd min           ;0x10040
dd getbits       ;0x10044
dd setdaccolor   ;0x10048
dd strlen        ;0x1004c
dd puteaxdec     ;0x10050
dd puteax        ;0x10054   [1]
dd putmem        ;0x10058
dd datetime      ;0x1005c
dd sleep         ;0x10060
dd clock         ;0x10064
dd swapbuf       ;0x10068
dd hline         ;0x1006c
dd vline         ;0x10070
dd grid          ;0x10074
dd ptinrect      ;0x10078
dd putsn         ;0x1007c
dd toggle        ;0x10080
dd str2st0       ;0x10084
dd _tlibstub     ;0x10088
dd printf        ;0x1008c
dd read10        ;0x10090
dd checkc        ;0x10094
dd putBTSfile    ;0x10098
dd putsml        ;0x1009c
dd viewtxt       ;0x100a0
dd choosecolor   ;0x100a4
dd dumpbyte      ;0x100a8
dd st02str       ;0x100ac
dd dumpreset     ;0x100b0  [1]
dd _tlibstub        ;0x100b4
dd comprompt     ;0x100b8
dd write10       ;0x100bc
dd eax2hex       ;0x100c0   [1]
dd strcpy        ;0x100c4
dd eax2dec       ;0x100c8
dd memset        ;0x100cc
dd max           ;0x100d0
dd dumpreg       ;0x100d4
dd dumpstr       ;0x100d8
dd dumpview      ;0x100dc
dd dumpspace     ;0x100e0
dd isdigit       ;0x100e4
dd xxd           ;0x100e8
dd isascii       ;0x100ec
dd ishex         ;0x100f0
dd strncmp       ;0x100f4
dd cliprect      ;0x100f8
dd crosspointer  ;0x100fc
dd getpixel      ;0x10100
dd palette       ;0x10104
dd gengraypalette;0x10108
dd ttasm         ;0x1010c
dd hash          ;0x10110
dd strcat        ;0x10114
dd strncpy       ;0x10118
dd ishexstring   ;0x1011c
dd getline       ;0x10120
dd floor         ;0x10124
dd strchr        ;0x10128
dd skipspace     ;0x1012c
dd memsetd       ;0x10130
dd symadd        ;0x10134
dd symlookup     ;0x10138
dd symtableclear ;0x1013c
dd fillsincos    ;0x10140
dd dumpeax       ;0x10144   [1]
dd dumpnl        ;0x10148
dd getreginfo    ;0x1014c
dd reg2str       ;0x10150
dd getpixadd   ;0x10154
dd mmult44       ;0x10158  
dd xy2i          ;0x1015c
dd bytes2blocks  ;0x10160
dd _tlibstub     ;0x10164
dd convertbmp24grayBTS  ;0x10168
dd getrgb        ;0x1016c
dd backbufsave   ;0x10170
dd backbufrestore;0x10174
dd pickoption    ;0x10178
dd floodfill     ;0x1017c
dd checkrange    ;0x10180
dd dumpflags     ;0x10184
dd backbufscroll ;0x10188
dd putscroll     ;0x1018c
dd eax2bin       ;0x10190
dd shell         ;0x10194
dd _tlibstub     ;0x10198
dd putst0        ;0x1019c
dd polar2rect    ;0x101a0
dd roundmode     ;0x101a4
dd _tlibstub  ;0x101a8
dd checktimer    ;0x101ac
dd line          ;0x101b0
dd setpixel      ;0x101b4
dd circle        ;0x101b8
dd rectangle     ;0x101bc
dd flag2str      ;0x101c0
dd putflags      ;0x101c4
dd printscreen   ;0x101c8
dd dumpchar      ;0x101cc
dd pow           ;0x101d0
dd dumpst0       ;0x101d4
dd sign          ;0x101d8
dd symtableload  ;0x101dc
dd isbinstring   ;0x101e0
dd puteaxbin     ;0x101e4
dd arrowpointer  ;0x101e8
dd polyline      ;0x101ec
dd subdivide     ;0x101f0
dd tedit         ;0x101f4
dd hypot         ;0x101f8
dd arc           ;0x101fc
dd linepolar     ;0x10200
dd putmonobits   ;0x10204
dd dumpPoints    ;0x10208
dd crossproduct  ;0x1020c
dd dotproduct    ;0x10210
dd getlength     ;0x10214
dd getslope      ;0x10218
dd chamfer       ;0x1021c
dd putvectord    ;0x10220
dd putvectorq    ;0x10224
dd q2d           ;0x10228
dd fillet        ;0x1022c
dd getangleinc   ;0x10230
dd origin        ;0x10234
dd getnormal     ;0x10238
dd rad2deg       ;0x1023c
dd normalizedeg    ;0x10240
dd usbcheckmouse   ;0x10244
dd mmult41         ;0x10248  
dd usbmouserequest ;0x1024c
dd swaprect        ;0x10250
dd swaprectprep    ;0x10254
dd _tlibstub       ;0x10258
dd _tlibstub       ;0x1025c
dd pciReadDword    ;0x10260
dd pciWriteDword   ;0x10264
dd dumpBusDevFun   ;0x10268
dd squeeze         ;0x1026c
dd dumpFPUstatus   ;0x10270
dd putmessage      ;0x10274
dd dumpbitfield    ;0x10278   [1]
dd bcd2bin         ;0x1027c
dd strcpy2         ;0x10280
dd puteaxstr       ;0x10284  [1]
dd fatreadfile     ;0x10288
dd fatwritefile    ;0x1028c
dd fatgetfilename  ;0x10290
dd eaxstr          ;0x10294
dd putspause       ;0x10298
dd filemanager     ;0x1029c
dd ListControlInit         ;0x102a0
dd ListControlKeydown      ;0x102a4
dd ListControlPaint        ;0x102a8
dd ListControlGetSelection ;0x102ac
dd _tlibstub               ;0x102b0
dd putscriptT              ;0x102b4
dd alloc                   ;0x102b8
dd free                    ;0x102bc
dd dumpmem                 ;0x102c0
dd ptonline                ;0x102c4
dd bubblesort              ;0x102c8
dd putpalette              ;0x102cc
dd lineclip                ;0x102d0
dd putcHershey             ;0x102d4
dd putsHershey             ;0x102d8
dd teditBlankList          ;0x102dc
dd tatOSinit               ;0x102e0
dd _tlibstub         ;0x102e4
dd dumpstrn                ;0x102e8   [1]
dd _tlibstub         ;0x102ec
dd offset                  ;0x102f0
dd rotateline              ;0x102f4
dd intersection            ;0x102f8
dd popupmessage            ;0x102fc
dd dumpstack               ;0x10300
dd _tlibstub               ;0x10304
dd dumpst09                ;0x10308
dd _tlibstub               ;0x1030c
dd _tlibstub               ;0x10310
;tom we should get rid of most of these indirect function calls
;but some are still used in /boot
;becareful because just commenting out the last 30 or so entries
;prevented us from booting properly
;go thru every file in /boot and tatOSinit.s 
;for all the indirect function call usage




;all the tlib files are included here:

%include "tlib/tatOSinit.s"
%include "tlib/tlibentry.s"
%include "tlib/font01.inc"
%include "tlib/font02.inc"
%include "tlib/fontHershey.inc"
%include "tlib/put.s"
%include "tlib/putHershey.s"
%include "tlib/getc.s"
%include "tlib/gets.s"
%include "tlib/rectangle.s"
%include "tlib/video.s"
%include "tlib/palette.s"
%include "tlib/rand.s"
%include "tlib/datetime.s"
%include "tlib/time.s"
%include "tlib/line.s"
%include "tlib/dump.s"
%include "tlib/controls.s"
%include "tlib/string.s"
%include "tlib/memset.s"
%include "tlib/is.s"
%include "tlib/xxd.s"
%include "tlib/pointer.s"
%include "tlib/ttasm.s"
%include "tlib/tlink.s"
%include "tlib/tedit.s"
%include "tlib/tablesym.s"
%include "tlib/tablepub.s"
%include "tlib/tableext.s"
%include "tlib/getline.s"
%include "tlib/flood.s"
%include "tlib/bmp.s"
%include "tlib/shell.s"
%include "tlib/circle.s"
%include "tlib/roundmode.s"
%include "tlib/polar.s"
%include "tlib/subdivide.s"
%include "tlib/math.s"
%include "tlib/arc.s"
%include "tlib/origin.s"
%include "tlib/calc.s"
%include "tlib/pci.s"
%include "tlib/cpuid.s"
%include "tlib/fat16.s"
%include "tlib/dd.s"
%include "tlib/filemanager.s"
%include "tlib/list.s"
%include "tlib/bcd2bin.s"
%include "tlib/bits.s"
%include "tlib/alloc.s"
%include "tlib/sort.s"
%include "tlib/viewtxt.s"
%include "tlib/geometry.s"
%include "tlib/clipping.s"
%include "tlib/paging.s"
%include "tlib/clipboard.s"
%include "tlib/dropdown.s"




dd 0


;if you decide to remove something from the tlib call table
;replace it with this stub
_tlibstub:
	ret



;include all /usb code 
%include "usb/usb.s"




;we keep tract of how big the last ttasm executable is
;for the benefit of saving the executable to flash from the shell
sizeofexe dd 0


;in boot2.s on startup
;the std palette is copied to this array
;this array is used to set the DAC
;new palettes should be copied to this array first
;before setting the DAC
;getpixel uses this array
palette times 768 db 0



;floating point constants 
;**************************
pointzeroone       dq 0.01
one                dq 1.0    ;why do we need this tom ?  use fld1
two                dq 2.0
one_eighty_over_pi dq 57.29577951
deg2rad            dq 0.0174532      ;radian = degree * deg2rad
twopi              dq 6.283185308


;dword constants
;*************************
_x                 dd 0
_y                 dd 0
bmwidth            dd 0
bmheight           dd 0
filesize           dd 0
qtybits            dd 0
palettetype        dd 0



;this memory is used for the fsave/frstor commands
_fpustate:
times 120 db 0



;single precision floating point constants used by st02str 
;for display up to 10 decimal digits
;the idea is to take the float and multiply by power of ten
;then convert to bcd and display decimal in appropriate spot
PowerOfTen:
dd 1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0, 1000000.0, 
dd 10000000.0, 100000000.0, 1000000000.0, 10000000000.0


pressanykeytocontinue:
db 'Press any key to continue',0


;tlib is always growing
;SIZEOFTLIB is defined in tatOS.inc 
;because SIZEOFTLIB is also used in boot2.s for loading tatOS
;do not change the 512
;go to tatOS.inc and redefine SIZEOFTLIB to some bigger number of sectors
times 512*SIZEOFTLIB - ($-$$) db 0



