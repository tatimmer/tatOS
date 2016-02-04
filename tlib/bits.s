;tatOS/tlib/bits.s

;putbits, putbits4, puttransbits, putmonobits, putBTSfile, 
;putscriptT, BitmapViewer, printscreen, putmarker


;routines to display "BITS" files, arrays of bits, and small bitmaps
;to display text see put.s

;when we talk about the "bits" we usually mean 
;an array of byte values representing an index into the std palette
;the array of bits is arranged top down left to right like video memory
;each byte is actually 6 bits of color information for each pixel
;because the DAC only accepts 6 bits
;in our stdpalette 0xff is reserved for the background color

;a "BTS" file in tatOS as of Jan 2011 can be stored on your FAT16 formatted 
;flash drive with whatever extension you want but I use .BTS
;the program "littlebits" will save a BTS file
;the function convertbmp256bits will convert a Windows 256 color bitmap to a BTS file
;BTS1 means version 1, future versions will be BTS2, BTS3 ...

;***********************************************
;    BTS Version 01
;***********************************************
;the format of the BTS1 file is as follows:

;3bytes: ascii 'BTS' = 0x42,0x54,0x53
;byte:   version number (currently use 01)
;dword:  bitmap width in pixels
;dword:  bitmap height in pixels
;dword:  palette type: 
;        0=use tatOS std palette  (file contains no palette colors)
;        1=use tatOS graypalette  (file contains no palette colors)
;        2=custom palette is included in this file
;        if palette type = 2 then follows the 256 color palette 
;        which takes up 768 bytes total (each rgb triple is 3 bytes times 256)
;then follows the array of bits top down left to right

;so the BTS filesize = 16 + palette + bits 
;the palette (if included) is always 768 bytes
;the bits array is always size = bmwidth*bmheight 
;since 256 color is 1 byte/pixel





;***************************************************
;putbits
;display a rectangular grid of pixels
;may be any width or height
;starting pixel is upper left corner of the bitmap
;bits array is 2d top down left to right
;each 'bit' is a byte value index into the DAC (0-255)

;input:
;push xstart           [ebp+24]
;push ystart           [ebp+20]
;push width            [ebp+16]
;push height           [ebp+12]
;push address of bits  [ebp+8]
;***************************************************

putbits:

	push ebp
	mov ebp,esp
	pushad
	
	;compute address of first pixel
	push dword [ebp+24] ;x
	push dword [ebp+20] ;y
	call getpixadd   ;returns edi=address of first pixel in backbuf

	mov edx,[BPSL]      ;bytesperscanline
	sub edx,[ebp+16]  
	;edx hold qty bytes from end of one row to start of next row

	cld                 ;increment
	mov ecx,[ebp+16]    ;width
	mov eax,[ebp+12]    ;height
	mov esi,[ebp+8]     ;address of bits
	mov ebx,ecx         ;save a copy of width

	;set pixels 1 row at a time
.1:	rep movsb           ;esi->edi, esi++, edi++  set entire row of pixels
	dec eax             ;one less row
	je .2
	add edi,edx         ;inc video buffer to next row
	mov ecx,ebx         ;rep destroys ecx so restore for next row
	jmp .1

.2:	popad
	pop ebp
	retn 20





;***************************************************
; getbits
; copy a rectangular pattern of bits from video memory
; for restoring background after drawing operations
; this is the same code as putbits
; with esi/edi reversed
; ebx = xstart - upper left col, pixel
; eax = ystart - upper left row, pixel
; ecx = width,pixels 
; ebp = height,pixels
; edi = address to store bitmap bits
;***************************************************

getbits:
	pushad
	
	push edi
	push ebx  ;x
	push eax  ;y
	call getpixadd
	mov esi,edi    ;esi holds address in video buffer of 1st pix
	pop edi

	mov edx,[BPSL] ;bytesperscanline
	sub edx,ecx  
	;edx hold qty bytes to advance video buffer to next row

	cld         ;increment
	mov ebx,ecx ;save a copy of width

	;get pixels 1 at a time
.1:	rep movsb    ;esi->edi set entire row of pixels
	dec ebp      ;one less row
	je .2
	add esi,edx  ;increment video buffer to next row
	mov ecx,ebx  ;rep destroys ecx so restore for next row
	jmp .1

.2:	popad
	ret




;***********************************
;putbits4
;same as putbits except
;bitmap width must be a multiple of 4 
;put a 256 color top down bitmap to the screen
;for 800x600x8bpp graphics display
;each bit is an index into the 
;DAC 256 color palette
;the first bit is upper left corner
;the last bit is lower right corner
;the bits are arranged left to right
;top to bottom, just like the video memory
;input:
;ebx = xstart - upper left col, pixel
;eax = ystart - upper left row, pixel
;ecx = width,pixels (must be multiple of 4)
;ebp = height,pixels
;esi = address of bitmap bits
;***********************************

putbits4:
	pushad

	;compute address of first pixel
	push ebx  ;x
	push eax  ;y
	call getpixadd

	mov edx,[BPSL] ;bytesperscanline
	sub edx,ecx  
	;edx hold qty bytes to advance video buffer to next row

	cld         ;increment
	shr ecx,2   ;width/4
	mov ebx,ecx ;save width

	;set pixels 4 at a time
.1:	rep movsd   ;esi->edi set entire row of pixels
	dec ebp     ;one less row
	je .2
	add edi,edx ;increment video buffer to next row
	mov ecx,ebx ;rep destroys ecx so restore for next row
	jmp .1

.2:
	popad
	ret






;***************************************************
;puttransbits
;display a transparent rectangular grid of pixels
;the bitmap may have any number of colors but
;the background bits 0xff are ignored
;may be any width or height
;starting pixel is upper left
;each pixel value is an index into the DAC (0-255)

;this is a fundamental function for tatOS because
;puts is dependent on putc and
;putc is dependent of puttransbits
;so be careful if you modify this function 

;input:
;push xstart - upper left col, pixel   [ebp+24]
;push ystart - upper left row, pixel   [ebp+20]
;push width,pixels                     [ebp+16]
;push height,pixels                    [ebp+12]
;push address of bitmap bits           [ebp+8]

;return:none
;***************************************************

puttransbits:

	push ebp
	mov ebp,esp
	pushad

	push dword [ebp+24]
	push dword [ebp+20]
	call getpixadd   ;returns edi=address of first pixel in backbuf

	mov edx,[BPSL] ;bytesperscanline
	sub edx,[ebp+16]  
	;edx hold qty bytes from end of one row to start of next row

	cld               ;increment
	mov ecx,[ebp+16]  ;width
	mov eax,[ebp+12]  ;height
	mov esi,[ebp+8]   ;address of bits
	mov ebx,ecx       ;save a copy of width


.1:	cmp byte [esi],0xff  ;test for background pixel in source
	jz .2        ;skip background pixel
	movsb        ;set pixel esi->edi and increment addresses
	jmp .3
.2: inc esi
	inc edi
.3	loop .1      ;dec ecx and jmp if not 0

	dec eax      ;one less row
	je .4
	add edi,edx  ;increment video buffer to next row
	mov ecx,ebx  ;loop destroys ecx so restore for next row
	jmp .1

.4:	
	popad
	pop ebp
	retn 20




;***************************************************
;putmonobits
;display a monochrome rectangular grid of pixels
;the bitmap has only 2 colors
;	0->0xfe = set all bits in this range to COLOR
;	0xff    = background color bits are ignored

;input
;push xstart                         [ebp+28]
;push ystart                         [ebp+24]
;push width                          [ebp+20]
;push height                         [ebp+16]
;push Address of bitmap bits         [ebp+12]
;push COLOR (0->0xfe)                [ebp+8]

;return: none
;***************************************************

putmonobits:

	push ebp
	mov ebp,esp
	pushad
	
	push dword [ebp+28]
	push dword [ebp+24]
	call getpixadd   ;edi=dest address of 1st pixel
	mov esi,[ebp+12] ;esi=source

	mov edx,[BPSL]   ;bytesperscanline
	sub edx,[ebp+20] ;BPSL-width  
	;edx hold qty bytes to advance video buffer to next row

	cld              ;inc
	mov ebx,[ebp+8]  ;color in bl
	mov ecx,[ebp+20] ;ecx=width

.setrowpixels:
	lodsb        ;get pixel color [esi]->al, esi++
	cmp al,0xff  ;test 4 background pixel
	jz .skipthispixel
	mov al,bl    ;save pixel color to al
	stosb        ;al->[edi], edi++
	jmp .doloop
.skipthispixel:
	inc edi
.doloop:
	loop .setrowpixels

	;for next row
	dec dword [ebp+16]   ;one less row
	jz .done
	add edi,edx      ;increment video buffer to next row
	mov ecx,[ebp+20] ;restore loop count 
	jmp .setrowpixels

.done:
	popad
	pop ebp
	retn 24





;*********************************************************************
;putBTSfile
;display a BTS version 1 file with std, gray or custom palette
;note this function assumes the stdpalette is active
;but it will call setpalette if a gray or custom palette is required
;see definition of a BTS file above

;input
;push Memory Address where file is located  [ebp+16]
;push Xloc                                  [ebp+12]
;push Yloc                                  [ebp+8] 
;return
;eax=0 on success, eax=1 on error reading file header

;locals:
bitsfiletag db 'BITS'
putbitsfilestr2 db 'This is not a BTS1 file',0
bitsStart dd 0
;********************************************************************

putBTSfile:

	push ebp
	mov ebp,esp
	
	;first check that we are dealing with a 'BTS' version 1 file
	mov edi,[ebp+16]
	cmp byte [edi],'B'
	jnz .error
	cmp byte [edi+1],'T'
	jnz .error
	cmp byte [edi+2],'S'
	jnz .error
	cmp byte [edi+3],0x01  ;version
	jnz .error


	;load the palette if gray or custom and set esi=address of bits
	cmp dword [edi+12],0  ;std palette
	jnz .donestd
	lea esi,[edi+16]      ;set starting address of bits array
	jmp .putbits
.donestd:
	cmp dword [edi+12],1  ;gray palette
	jnz .donegray
	STDCALL 1,setpalette
	lea esi,[edi+16]      
	jmp .putbits
.donegray:
	cmp dword [edi+12],2  ;custom palette
	jnz .donecustom
	lea eax,[edi+16]
	STDCALL eax,setpalette
	lea esi,[edi+784]      
.donecustom:


.putbits:

	push dword [ebp+12]  ;x
	push dword [ebp+8]   ;y
	push dword [edi+4]   ;width
	push dword [edi+8]   ;height
	push esi             ;address of bits array
	call putbits

	mov eax,0   ;success
	jmp .done

.error:
	STDCALL putbitsfilestr2,dumpstr
	mov eax,1   

.done:
	pop ebp
	retn 12





;*********************************************************************
;putscriptT
;display my script T bitmap
;this is a 20x20 array of bits assembled into tatOS
;its the letter 'T' in the handwritting style of my Grandmother/Oma
;bits are 0xf0 (blue) and everything else BKCOLOR 0xff
;input:
;push Xloc upper left corner [ebp+12]
;push Yloc upper left corner [ebp+8]
;return:none
scriptT:
incbin "tlib/scriptT.bits"
;*********************************************************************

putscriptT:

	push ebp
	mov ebp,esp

	push dword [ebp+12] ;xstart
	push dword [ebp+8]  ;ystart
	push 20             ;width
	push 20             ;height
	push scriptT        ;address of bits
	call puttransbits

	pop ebp
	retn 8



;*****************************************************************
;BitmapViewer
;a program to view a tatOS BTS bitmap file 
;or to convert to other bitmap formats
;this is an interactive program with menu called from the shell

;note after displaying a bitmap or bts file to get back to this 
;program menu you have to press the "menu" key on your keyboard

;input:none
;return:none
;*****************************************************************

ViewBitsMenu:
db 'Bitmap Viewer and  Converter',NL
db '*****************************',NL
db 'to return to this menu after displaying a bitmap or bts press the "menu" key',NL
db NL
db 'F1=Display unformatted bits array using std palette, user gives width,height',NL
db 'F2=Display a BTS file',NL
db 'F3=Convert a Windows 8 bit 256 color bmp to BTS',NL
db 'F4=Convert a Windows 24 bit DIB to grayscale BTS',NL
db 'F5=Convert BTS to Windows 8 bit 256 color bmp',NL
db 'F6=Display BMP file info',NL
db 'F7=Save IMAGEBUFFER to flash as BTS file (following PrntScrn)',NL
db 0



bitstr1 db 'Enter width,height of bits array',0
bitstr2 db 'putBTSfile',0
bitstr3 db 'this is not a BTS',0
bitstr4 db 'BitmapViewer',0
bitstr5 db 'Enter name of BTS file',0
bitstr6 db 'Save IMAGEBUFFER to flash',0
bitstr7 db 'operation completed',0
bitstr8 db 'Enter name of bmp file',0
bitstr9 db 'BitmapViewer: press MENU key for help',0
bitstr10 db 'alloc failed',0

BitsViewerMemory  dd 0
BitsCustomPalette dd 0
BitsPaintOption   dd 99
_bitstor times 20 dd 0


BitmapViewer:

	STDCALL bitstr4,dumpstr

	;allocate some memory to be used by this program
	mov ecx,600000
	call alloc  ;returns esi=address of memory block
	jz near .allocfailed
	mov [BitsViewerMemory],esi

	jmp .paint

.keyboard:

	;reset the stdpalette
	STDCALL 0,setpalette  


	call getc ;pause waiting for user input, returns char in al

	cmp al,ESCAPE  ;program exit
	jz near .done
	cmp al,MENU
	jz near .doMenu
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
	cmp al,F6
	jz near .doF6
	cmp al,F7
	jz near .doF7


	;handle all other keystrokes
	jmp .paint



.doMenu:
	mov dword [BitsPaintOption],0
	jmp near .paint
	

.doF1: ;Display an unformatted bits array

	;user to select a file to open
	mov ebx,0     ;list/display/select files only
	call filemanager
	jz .keyboard   ;user hit esc
	;otherwise the 11char filename string is at FILENAME (0x198fb00)

	;load the bitsfile from flash to memory
	push dword IMAGEBUFFER
	call fatreadfile
	;return eax=filesize
	cmp eax,0
	jz .keyboard  ;error

	;get user to enter width and height of bits
	STDCALL bitstr1,COMPROMPTBUF,comprompt
	jnz .keyboard   ;user hit esc

	;split the string and convert the bmwidth, bmheight
	push COMPROMPTBUF ;parent string
	push COMMA        ;seperator
	push 2            ;max qty substrings
	push _bitstor     ;storage for substring address
	call splitstr

	;there must be 2 substrings or else we bail
	cmp eax,2  
	jnz near .doneF1

	;convert bmwidth
	mov esi,COMPROMPTBUF
	call str2eax
	jnz .keyboard
	mov [bmwidth],eax

	;convert bmheight
	mov esi,[_bitstor]
	call str2eax
	jnz .keyboard
	mov [bmheight],eax

.doneF1:
	mov dword [BitsPaintOption],1
	jmp .paint




.doF2: ;display a BTS file

	;user to select a file to open
	mov ebx,0     ;list/display/select files only
	call filemanager
	jz .keyboard   ;user hit esc
	;otherwise the 11char filename string is at FILENAME (0x198fb00)

	;load the BTS from flash to memory
	push dword IMAGEBUFFER
	call fatreadfile
	;return eax=filesize
	cmp eax,0
	jz .keyboard  ;error

	mov dword [BitsPaintOption],2
	jmp .paint


	

.doF3:  ;convert a Windows 256 color bitmap to BTS with std palette

	;user to select a file
	mov ebx,0     ;list/display/select files only
	call filemanager
	jz .keyboard   ;user hit esc
	;otherwise the 11char filename string is at FILENAME (0x198fb00)

	;load the file to ViewerMemory
	push dword [BitsViewerMemory]
	call fatreadfile
	;return eax=filesize
	cmp eax,0
	jz .keyboard  ;error

	;convert the 256 color bitmap to a BTS file at IMAGEBUFFER
	mov edi,[BitsViewerMemory]
	call convertbmp256BTS
	cmp ecx,0   ;ecx=filesize else 0 on error
	jz .keyboard   

	;prompt user for filename to save and store at COMPROMPTBUF
	STDCALL bitstr5,fatgetfilename
	jnz .keyboard

	;save the file
	STDCALL IMAGEBUFFER,ecx,fatwritefile
	;returns eax=0 on success else nonzero on erro

	mov dword [BitsPaintOption],0
	jmp .paint  ;just to refresh the screen




.doF4:  ;convert a Windows 24bit DIB to grayscale BTS

	;user to select a file
	mov ebx,0     ;list/display/select files only
	call filemanager
	jz .keyboard   ;user hit esc
	;otherwise the 11char filename string is at FILENAME (0x198fb00)

	;load the Windows DIB bitmap from flash to memory
	push dword [BitsViewerMemory]
	call fatreadfile
	;return eax=filesize
	cmp eax,0
	jz .keyboard  ;error

	;convert the bitmap to grayscale bits at IMAGEBUFFER
	mov edi,[BitsViewerMemory]
	call convertbmp24grayBTS  ;returns ecx=filesize else 0

	;prompt user for filename to save and store at COMPROMPTBUF
	STDCALL bitstr5,fatgetfilename
	jnz .keyboard

	;save the file
	STDCALL IMAGEBUFFER,ecx,fatwritefile
	;returns eax=0 on success else nonzero on erro

	mov dword [BitsPaintOption],0
	jmp .paint  ;just to refresh the screen




.doF5:  ;convert BTS to Windows 8 bit bmp

	;user to select a file
	mov ebx,0     ;list/display/select files only
	call filemanager
	jz .keyboard   ;user hit esc
	;otherwise the 11char filename string is at FILENAME (0x198fb00)

	;load the BTS from flash to memory
	push dword [BitsViewerMemory]
	call fatreadfile
	;return eax=filesize
	cmp eax,0
	jz .keyboard  ;error

	;convert the BTS to bmp
	mov edi,[BitsViewerMemory]
	call convertBTSbmp  ;returns ecx=filesize else 0

	;prompt user for filename to save and store at COMPROMPTBUF
	STDCALL bitstr8,fatgetfilename
	jnz .keyboard

	;save the file
	STDCALL IMAGEBUFFER,ecx,fatwritefile
	;returns eax=0 on success else nonzero on erro

	mov dword [BitsPaintOption],0
	jmp .paint  ;just to refresh the screen



.doF6:  ;Display bmp file info like bmwidth, bmheight, numcolors ...

	;user to select a file
	mov ebx,0     ;list/display/select files only
	call filemanager
	jz .keyboard   ;user hit esc
	;otherwise the 11char filename string is at FILENAME (0x198fb00)

	;load the Windows DIB bitmap from flash to memory
	push dword IMAGEBUFFER
	call fatreadfile
	;return eax=filesize
	cmp eax,0
	jz .keyboard  ;error

	mov dword [BitsPaintOption],3
	jmp near .paint




.doF7: ;save IMAGEBUFFER to flash as BTS file

	;pushing the PrintScreen button writes a BTS file to the IMAGEBUFFER
	;here we save to flash

	;prompt user for filename to save and store at COMPROMPTBUF
	STDCALL shellstr6,fatgetfilename
	jnz .keyboard  ;user hit ESC

	;save the file
	STDCALL IMAGEBUFFER,480016,fatwritefile
	;returns eax=0 on success else nonzero on erro

	STDCALL bitstr6,bitstr7,popupmessage
	jmp .keyboard





.paint: ;our paint routine for BitmapViewer

	call backbufclear

	
	;Option 0
	;show the menu
	STDCALL FONT01,10,0,ViewBitsMenu,0xefff,putsml


	;Option 1
	;display unformatted bits array previously loaded to IMAGEBUFFER
	cmp dword [BitsPaintOption],1
	jnz .doneOption1
	xor edx,edx
	mov ecx,2
	mov eax,800
	sub eax,[bmwidth]
	div ecx
	push eax               ;x=(800-width)/2 centers on screen
	mov eax,600
	sub eax,[bmheight]
	div ecx
	push eax               ;y=(600-height)/2 centers on screen
	push dword [bmwidth]   ;width of xbits
	push dword [bmheight]  ;height of xbits
	push IMAGEBUFFER       ;address of bits
	call putbits
.doneOption1:

	
	;Option 2
	;display BTS file previously loaded to IMAGEBUFFER
	cmp dword [BitsPaintOption],2
	jnz .doneOption2
	STDCALL IMAGEBUFFER,0,0,putBTSfile  ;sets palette if gray or custom
.doneOption2:


	;Option 3
	;display BMP file info
	cmp dword [BitsPaintOption],3
	jnz .doneOption3
	call ShowBMPinfo	
.doneOption3:


	call swapbuf
	jmp .keyboard




.done:
	;free the memory we allocated at the start of this program
	mov esi,[BitsViewerMemory]
	call free
	jmp .quit
.allocfailed:
	STDCALL bitstr10,dumpstr
.quit:
	ret




;***********************************************************
;printscreen
;this function creates a BTS file 800x600 of the entire screen
;the file data is written to IMAGEBUFFER
;called from keyboard.s when PrtScrn button is pressed
;input:none
;return:none
prntscrstr1 db 'printscreen',0
prntscrstr3 db 'BTS bitmap file written to IMAGEBUFFER',0
;**********************************************************

printscreen:

	STDCALL prntscrstr1,dumpstr

	;start writting our BTS file
	mov byte [IMAGEBUFFER],'B'
	mov byte [IMAGEBUFFER+1],'T'
	mov byte [IMAGEBUFFER+2],'S'

	;file version number
	mov byte [IMAGEBUFFER+3],1

	;bitmap width
	mov dword [IMAGEBUFFER+4],800 

	;bitmap height
	mov dword [IMAGEBUFFER+8],600

	;palette type 
	mov eax,[setpalettetype]  ;value saved in setpalette()
	mov dword [IMAGEBUFFER+12],eax 

	;now the bits, top down left to right
	;each bit is an index into the colortable
	mov esi,[LFB]            ;start of linear frame buffer
	lea edi,[IMAGEBUFFER+16]
	mov ecx,480000
	cld
	rep movsb


	STDCALL prntscrstr1,prntscrstr3,popupmessage

.done:
	ret





;*****************************************************
;putmarker
;display a small bitmap marker at a point
;sets pixels directly to BACKBUF
;each marker fits in a 5x5 bitmap
;x,y is the center of the bitmap

;input
;push marker style   [ebp+20]
;push color          [ebp+16]
;push x              [ebp+12]
;push y              [ebp+8]
;return:sets bits in BACKBUF at location

;marker styles are as follows:
;1=square, 2=X, 3=cross
;****************************************************

putmarker:

	push ebp
	mov ebp,esp
	pushad

	push dword [ebp+12]
	push dword [ebp+8]
	call getpixadd    ;returns address in edi

	mov ebx,[ebp+16]  ;color in ebx

	mov eax,[ebp+20]  
	cmp eax,1
	jz near .dosquare
	cmp eax,2
	jz near .doX
	cmp eax,3
	jz near .docross
	jmp near .done

.dosquare:
	;row y-2
	sub edi,[BPSL]
	sub edi,[BPSL]
	mov [edi-2],bl   ;tom you could set dword instead of 4 bytes to speed up
	mov [edi-1],bl 
	mov [edi],  bl
	mov [edi+1],bl 
	mov [edi+2],bl 
	;row y-1
	add edi,[BPSL]
	mov [edi-2],bl 
	mov [edi+2],bl 
	;row y
	add edi,[BPSL]
	mov [edi-2],bl 
	mov [edi+2],bl 
	;row y+1
	add edi,[BPSL]
	mov [edi-2],bl 
	mov [edi+2],bl 
	;row y+2
	add edi,[BPSL]
	mov [edi-2],bl 
	mov [edi-1],bl 
	mov [edi],  bl
	mov [edi+1],bl 
	mov [edi+2],bl 
	jmp near .done
.docross:
	;row y-2
	sub edi,[BPSL]
	sub edi,[BPSL]
	mov [edi],bl 
	;row y-1
	add edi,[BPSL]
	mov [edi],bl 
	;row y
	add edi,[BPSL]
	mov [edi-2],bl 
	mov [edi-1],bl 
	mov [edi],  bl
	mov [edi+1],bl 
	mov [edi+2],bl 
	;row y+1
	add edi,[BPSL]
	mov [edi],bl 
	;row y+2
	add edi,[BPSL]
	mov [edi],bl 
	jmp near .done

.doX:
	;row y-2
	sub edi,[BPSL]
	sub edi,[BPSL]
	mov [edi-2],bl 
	mov [edi+2],bl 
	;row y-1
	add edi,[BPSL]
	mov [edi-1],bl 
	mov [edi+1],bl 
	;row y
	add edi,[BPSL]
	mov [edi],bl 
	;row y+1
	add edi,[BPSL]
	mov [edi-1],bl 
	mov [edi+1],bl 
	;row y+2
	add edi,[BPSL]
	mov [edi-2],bl 
	mov [edi+2],bl 

.done:
	popad
	pop ebp
	retn 16



