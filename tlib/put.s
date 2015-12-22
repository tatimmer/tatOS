;tatOS/tlib/put.s

;functions to display text on the screen:

;putc, puts, putsn, putsml, putscroll, putreg, 
;puteax, puteaxhex, puteaxdec, puteaxbin, puteaxstr   (kernel)
;putebx, putebxhex, putebxdec                         (user)
;putmem, putflags, putst0, putshang, putspause
;putmessage, popupmessage, putcHershey, putsHershey

;to build complex strings for display use printf see string.s

;some functions default to using FONT01
;others like puts let you choose


;locals
_putcbitmap times 120 db 0    ;storage for unpacked bitmap array
_eaxbuf     times 100 db 0
_ebxbuf     times 100 db 0
bitmapFontWidth       dd 0
bitmapFontHeight      dd 0
putsAdvanceX          dd 0
putsMaxChars          dd 0







;********************************************************************
;putc
;display a single bitmap character on 800x600 256 color display
;origin of the bitmap font char is upper left

;fontID
;at this time you have two choices for bitmap font to display
;1=font01, 2=font02
;tatos.inc has defines for FONT01 and FONT02
;each bitmap char in font01 is 8 pixels wide by 15 pixels hi
;each bitmap char in font02 is 8 pixels wide by 11 pixels hi

;if the ascii value is not in the range 0x20->0x7e
;we will display a box character
;ascii 0x7f is reserved in all tatOS bitmap fonts for box character

;input:
;ebx = fontID (1=FONT01 default, 2=FONT02)
;ecx = ascii char to display
;edx = color 0000ttbb  t=text, b=back
;esi = xloc,pixel 
;edi = yloc,pixel 

;return:none
;rev Aug 2013 new registers
;*******************************************************************

putc:

	pushad

	;clear all bits of ascii char except low byte
	and ecx,0xff 


	;test char for outside the ascii range 0x20-0x7e
	;display box char 0x7f for all nonprintable
	cmp ecx,0x20
	jb .showbox
	cmp ecx,0x7e
	ja .showbox
	jmp .loadFontParameters
.showbox:
	mov ecx,0x7f    ;box character



.loadFontParameters:

	cmp ebx,1
	jz .doFont01
	cmp ebx,2
	jz .doFont02
	
	;if we got here user has entered an invalid fontID
	;we will fall thru to font01 by default

.doFont01:
	lea ebp,[font01table + ecx*4 - 0x80]  
	mov dword [bitmapFontWidth],8
	mov dword [bitmapFontHeight],15
	jmp .loadaddress
.doFont02:
	lea ebp,[font02table + ecx*4 - 0x80]
	mov dword [bitmapFontWidth],8
	mov dword [bitmapFontHeight],11
.loadaddress:

	;done with ebx and ecx, eax is free

	push esi  ;save xloc for later
	push edi  ;save yloc for later

	mov ecx,[bitmapFontWidth]   ;pixels per row
	mov esi,[ebp]               ;get address of source bitmap, done with ebp 
	mov edi,_putcbitmap         ;edi now holds dest bitmap
	mov bl,[esi]                ;source bitmap first char
	mov bh,10000000b            ;init the row bitmask
	mov eax,[bitmapFontHeight]  ;row counter


	;set text and background color of _putcbitmap
	;we loop once for each bit in a row
	;each bit of the font01 or font02 char becomes a byte of _putcbitmap

.mainloop:
	test bl,bh          ;source bits are packed bitmapFontWidth per byte
	jz .2               ;zf is set for a 0 bit indicating background
	mov [edi],dh        ;set text color
	jmp .3
.2:	mov [edi],dl        ;set bk color
.3:	shr bh,1            ;adjust bitmask for next bit of source
	inc edi             ;next byte of dest
	loop .mainloop      ;decrements ecx til 0

	;setup for the next row of bits
	inc esi                     ;point to next byte of source bitmap
	mov bh,10000000b            ;re-init row bitmask
	mov ecx,[bitmapFontWidth]   ;restore loop counter
	mov bl,[esi]                ;get next byte of source bitmap 
	dec eax                     ;bitmapFontHeight rows per char bitmap
	jnz .mainloop


	;display the bitmap char
	;x and y are alread pushed
	push dword [bitmapFontWidth]  
	push dword [bitmapFontHeight]
	push _putcbitmap
	call puttransbits 

	popad
	ret







;*********************************************************************
;puts
;display a single line 0 terminated string of ascii bytes
;using font01 or font02
;strlen should not exceed 80 chars otherwise is will be truncated

;input
;push fontID (1=FONT01, 2=FONT02)        [ebp+24]
;push xloc                               [ebp+20]
;push yloc                               [ebp+16]
;push Address of 0 terminated string     [ebp+12]
;push color 0000ttbb  t=text, b=back     [ebp+8]

;return:none
;********************************************************************

puts:

	push ebp
	mov ebp,esp
	pushad

	
	cld  
	mov ebx,[ebp+24]  ;fontID
	mov esi,[ebp+20]  ;xloc
	mov edi,[ebp+16]  ;yloc
	mov eax,[ebp+12]  ;Address of string
	mov edx,[ebp+8]   ;color


	cmp ebx,1
	jz .doFont01
	cmp ebx,2
	jz .doFont02
	;fall thru to font01
.doFont01:
	mov dword [putsAdvanceX],10
	jmp .doneFontParameters
.doFont02:
	mov dword [putsAdvanceX],8
.doneFontParameters:


	;as a safety valve we will limit the num of chars drawn in case of missing 0 term
	;font01 will fit 80 chars across the screen
	;font02 will fit 100 chars across the screen
	mov dword [putsMaxChars],100
	
.topofloop:

	mov cl,[eax] ;fetch byte
	
	;test for 0 terminator
	cmp cl,0     
	jz .done   ;normal exit

	;display the char
	;ebx=FontID, ecx=ascii char, edx=color, esi=xloc, edi=yloc
	call putc

	;point to next char
	inc eax      

	;advance xloc += BitmapWidth + SpaceIfRequired
	add esi,[putsAdvanceX] 

	dec dword [putsMaxChars]
	jnz .topofloop

	;if we got here we failed to find 0 terminator within 81 bytes

.done:
	popad
	pop ebp
	retn 20



;****************************************************	
;putsml
;display multi-line 0 terminated ascii text 

;will wrap to next line if necessary
;will break lines at 0x0a (NL)
;will move over 30 pixels with tab 0x9
;does not scroll, see viewtxt for multiple pages
;words will be broken at end of line (no backup)

;with YORIENT=1 the x,y ref is upper left and
;the text extends to the right and down
;if YORIENT=-1 the x,y ref is lower left and
;the text extends to the right and up

;input
;push fontID (1=font01, 2=font02)  [ebp+24]
;push xloc,pixel                   [ebp+20]
;push yloc,pixel                   [ebp+16]
;push starting address of string   [ebp+12]
;push color 0000ttbb               [ebp+8]

;return 
;esi=address of next char to display
;if bottom of screen reached before 0 terminator

;example usage:
;str1:
;db 'Tom Timmermann',NL
;db '1812 Sherman Ave',NL
;db 'Hanover Germany',NL
;db '103569',0
;****************************************************	

putsml:

	push ebp
	mov ebp,esp
	push ecx  ;preserve
	
	xor ecx,ecx
	mov ebx,[ebp+24]  ;fontID
	mov esi,[ebp+20]  ;xloc
	mov edi,[ebp+16]  ;yloc
	mov eax,[ebp+12]  ;Address of string
	mov edx,[ebp+8]   ;color
	cld

	cmp ebx,1
	jz .dofont01
	cmp ebx,2
	jz .dofont02
	;defaults to font01		
.dofont01:
	mov dword [bitmapFontWidth],8
	mov dword [bitmapFontHeight],15
	mov dword [putsAdvanceX],10
	jmp .topofloop
.dofont02:
	mov dword [bitmapFontWidth],8
	mov dword [bitmapFontHeight],11
	mov dword [putsAdvanceX],8

	
.topofloop:
	
	;fetch ascii byte
	mov cl,[eax] 
	
	;check for 0 terminator
	cmp cl,0     
	je .done

	;check for newline
	cmp cl,NEWLINE
	jnz .doneNL
	mov esi,[ebp+20]             ;reset x
	add edi,[bitmapFontHeight]   ;y++
	jmp .incPointer
.doneNL:

	;check for tab
	cmp cl,9
	jnz .doneTAB
	add esi,[bitmapFontWidth]  ;move over 1 char
	add esi,[bitmapFontWidth]  ;move over 1 char
	add esi,[bitmapFontWidth]  ;move over 1 char
	add esi,[bitmapFontWidth]  ;move over 1 char
	inc eax   
	jmp .topofloop
.doneTAB:

	
	;display the char
	;ebx=fontID, ecx=ascii char, edx=color, esi=xloc, edi=yloc
	call putc

	;advance xloc += BitmapWidth + SpaceIfRequired
	add esi,[putsAdvanceX] 

	cmp esi,780    ;are we near the right border of the screen ?
	jb .linenotfilled
	mov esi,[ebp+20]            ;reset x
	add edi,[bitmapFontHeight]  ;y++
.linenotfilled:


.incPointer:
	inc eax      

	;check if yloc falls off bottom of screen
	;we will not use the very bottom line
	;apps may wish to put a prompt message at the bottom
	cmp edi,600
	jb .topofloop


.done:
	;return value: esi holds address of last char displayed
	mov esi,eax

	pop ecx ;restore
	pop ebp
	retn 20







;********************************************************
;putsn
;displays an ascii string that is not 0 terminated

;as of Aug 2013 only the filemanager uses this function

;input:
;push fontID (1=font01, 2=font02) [ebp+28]
;push xloc,pixel                  [ebp+24]
;push yloc,pixel                  [ebp+20]
;push starting address of string  [ebp+16]
;push qty bytes to display        [ebp+12]
;push color 0000ttbb              [ebp+8]

;return:none
;********************************************************

putsn:

	push ebp
	mov ebp,esp
	cld          ;inc

	;check for anything to display
	mov ecx,[ebp+12]  ;ecx=qty bytes = loop cntr
	cmp ecx,0
	jz .done

	mov eax,[ebp+16] ;eax=address of string
	mov esi,[ebp+24] ;esi=xloc
	mov edi,[ebp+20] ;edi=yloc
	mov ebx,[ebp+28] ;ebx=fontID
	mov edx,[ebp+8]  ;edx=color

.1:
	push ecx	         ;save for later 
	movzx ecx,byte [eax] ;fetch ascii byte

	;ebx=FontID, ecx=ascii char, edx=color, esi=xloc, edi=yloc
	call putc

	inc eax              ;get next ascii byte

    ;advance to location of next char bitmap
	;equal to width of bitmap + space inbetween
	add esi,8+2   

	;wrap text to next line if reqd
	cmp esi,790   ;check xloc
	jbe .2
	mov esi,0     ;reset xloc=0
	add edi,15    ;yloc+=15
.2:	
	pop ecx       ;loop cntr
	loop .1

.done:
	pop ebp
	retn 24 





	


;****************************************************
;putscroll
;scrolls the backbuffer down 15 pixels
;and displays a 1 line text message across the top
;and calls swapbuf to make it show up
;text is BLACK on BKCOLOR
;defaults to font01
;input
;push address of 0 terminated string to display
;return:none
;***************************************************

putscroll:

	push ebp
	mov ebp,esp
	pushad

	;scroll backbuffer down 15 pixels
	STDCALL 15,backbufscroll

	;erase the top 15 scanlines
	STDCALL 0,0,800,15,BKCOLOR,fillrect
	
	;display the 1 liner across top
	mov esi,[ebp+8]
	STDCALL FONT01,0,0,esi,0xefff,puts

	;make it show up
	call swapbuf

	popad
	pop ebp
	retn 4





;*****************************************************
;putreg
;display string generated by REG2STR
;this is the contents of 8 general purpose registers + eflags

;input
;push Xloc                              [ebp+16]
;push Yloc                              [ebp+12]
;push Color  0000ttbb  tt=text, bb=back [ebp+8]

;this function produces an ascii hex output like this:
;eax=xxxxxxxx ebx=xxxxxxxx ecx=xxxxxxxx edx=xxxxxxxx ebp=xxxxxxxx
;esp=xxxxxxxx esi=xxxxxxxx edi=xxxxxxxx eflag=xxxxxxxx
;*****************************************************
putreg:

	;get return address (EIP)
	pop dword [0x590] 
	push dword [0x590] 

	push ebp
	mov ebp,esp

	call getreginfo
	call reg2str  ;writes 0 terminated string to "reginfostring"
	STDCALL FONT01, [ebp+16], [ebp+12], reginfostring, [ebp+8], putsml

	pop ebp
	retn 12






;***************************************************
;puteax
;display contents of eax as ascii hex

;input
;push xloc,pixel           [ebp+20]
;push yloc,pixel           [ebp+16]
;push colors 0000ttbb      [ebp+12]
;     tt=text, bb=back
;push 0 to display eax     [ebp+8]
;     1 to display  ax
;     2 to display  al  
;************************************************

putebx:
putebxhex:
	mov eax,ebx
puteax:
puteaxhex:
	push ebp
	mov ebp,esp
	push edi
	push edx

	mov edi, _eaxbuf
	mov edx,[ebp+8]
	call eax2hex
	STDCALL FONT01, [ebp+20], [ebp+16], _eaxbuf, [ebp+12], puts 

	pop edx
	pop edi
	pop ebp
	retn 16
	




;****************************************************
;puteaxdec 
;display contents of eax as base 10 ascii 

;input
;push xloc,pixel           [ebp+20]
;push yloc,pixel           [ebp+16]
;push colors 0000ttbb      [ebp+12]
;push 0=unsigned dword     [ebp+8]
;     1=signed dword       
;****************************************************

putebxdec: 
	mov eax,ebx
puteaxdec: 

	push ebp
	mov ebp,esp
	pushad

	push _eaxbuf        ;address of dest buf
	push dword [ebp+8]  ;0=unsigned, 1=signed
	push 0              ;zero terminate
	call eax2dec

	STDCALL FONT01, [ebp+20], [ebp+16], _eaxbuf, [ebp+12], puts 
	
	popad
	pop ebp
	retn 16

	

;****************************************************
;puteaxbin
;display the contents of eax as binary 1's and 0's

;input
;push xloc,pixel           [ebp+16]
;push yloc,pixel           [ebp+12]
;push colors 0000ttbb      [ebp+8]
;     tt=text, bb=back
;****************************************************

puteaxbin:
	push ebp
	mov ebp,esp
	push edi
	
	mov edi,_eaxbuf
	call eax2bin
	STDCALL FONT01, [ebp+16], [ebp+12], _eaxbuf, [ebp+8], puts 
	
	pop edi
	pop ebp
	retn 12



;***************************************************
;puteaxstr
;displays the contents of eax as hex then a SPACE
;then adds a string tag. similar function is dumpeax
;"xxxxxxxx This is the contents of eax"
;input
;push xloc,pixel                         [ebp+20]
;push yloc,pixel                         [ebp+16]
;push colors 0000ttbb  tt=text, bb=back  [ebp+12]
;push address of 0 terminated string tag [ebp+8]
;return:none
;***************************************************

puteaxstr:
	push ebp
	mov ebp,esp
	pushad

	push dword [ebp+8]
	push _eaxbuf
	call eaxstr

	STDCALL FONT01, [ebp+20], [ebp+16], _eaxbuf, [ebp+12], puts 

	popad
	pop ebp
	retn 16




;***************************************
;putmem
;display bytes of memory 
;as a series of ascii hex bytes

;push X start                [ebp+24]
;push Y start                [ebp+20]
;push Colors 0000ttbb        [ebp+16]
;push starting address       [ebp+12]
;push qty bytes to display   [ebp+8]
;***************************************


putmem:
	push ebp
	mov ebp,esp
	
	STDCALL [ebp+12],CLIPBOARD,[ebp+8], mem2str
	STDCALL FONT01,[ebp+24],[ebp+20],CLIPBOARD,[ebp+16],putsml

	pop ebp
	retn 20




;*****************************************************
;putflags
;display string generated by "flag2str"
;supports CF,ZF,SF,DF,OF
;shows which flags are set
;e.g. "FLAGS CF ZF"
;see also DUMPFLAGS
;input
;push Xloc                              [ebp+16]
;push Yloc                              [ebp+12]
;push Color  0000ttbb  tt=text, bb=back [ebp+8]
;*****************************************************

putflags:
	push ebp
	mov ebp,esp
	
	call flag2str  
	STDCALL FONT01, [ebp+16], [ebp+12], flagstrbuf, [ebp+8], puts

	pop ebp
	retn 12



;***********************************************************
;putst0
;prints the floating point value of st0 (top of fpu stack)
;as a signed based 10 decimal 
;see notes with st02str for how this number is displayed
;
;input
;push fontID (1=FONT01, 2=FONT02)       [ebp+24]
;push Xloc                              [ebp+20]
;push Yloc                              [ebp+16]
;push color 0000ttbb tt=text, bb=back   [ebp+12]
;push NumberOfDecimalPlaces             [ebp+8]
;***********************************************************

putst0:
	push ebp
	mov ebp,esp

	STDCALL CLIPBOARD, [ebp+8], st02str
	STDCALL [ebp+24], [ebp+20], [ebp+16], CLIPBOARD, [ebp+12], puts

.done:
	pop ebp
	retn 24



;***********************************************************
;putshang
;print the contents of eax then print an error message 
;along the bottom of the screen then it will hang your computer
;its for fatal errors in init code and drivers
;use with Caution since it will most like corrupt your stack
;white text on red background
;input
;push address of string to display   [ebp+8]
;return
;hangs your computer
;local
puts_hang_str db 'FATAL ERROR-HANGING COMPUTER-CTRL+ALT+DEL to Continue',0
;***********************************************************

putshang:

	push ebp
	mov ebp,esp

	;we will display whatever was in eax for some hint to the error
	push eax

	;background for title 
	STDCALL 0,570,800,30,RED,fillrect

	;title string "Fatal Error"
	STDCALL FONT01, 0,570,puts_hang_str,0xfef5,puts

	;contents of eax
	pop eax
	STDCALL 0,585,0xfef5,0,puteax

	;string user wishes to display 
	STDCALL 100,585,[ebp+8],0xfef5,puts

	call swapbuf
	jmp $   ;hang

	pop ebp
	retn 4




;***********************************************************
;putspause
;puts up a message at the bottom of the screen to get user attention
;waits for user to press any key before continuing execution
;input
;push Address of Message string   [ebp+8]
;return:none
;local
puts_pause_str db 'Pausing Execution-Press any key to continue',0
;***********************************************************************

putspause:

	push ebp
	mov ebp,esp
	pushad

	;background 
	STDCALL 0,570,800,30,LBL,fillrect

	;title string 
	STDCALL FONT01,0,570,puts_pause_str,0xeff8,puts

	;the users message string
	STDCALL FONT01,0,585,[ebp+8],0xeff8,puts

	call swapbuf
	call getc    ;pause wait for user to press key

	popad
	pop ebp
	retn 4





;*******************************************************************
;putmessage
;this is a debug or progress function
;displays two ascii strings in a filled rectangle
;at the bottom of the screen. 
;"Title String"
;"Message String"
;this may be used for example in a long routine to show progress
;the title string is typically the function name 
;the message string shows progress within the function
;the rest of the screen is left untouched
;the message is persistant until another routine paints the area
;input
;push address of 0 terminated title string   [ebp+12]
;push address of 0 terminated message string [ebp+8]
;return:none
;********************************************************************

putmessage:

	push ebp
	mov ebp,esp

	;define where the portion of backbuf will be placed in LFB
	STDCALL 0,570,800,30,swaprectprep

	;background for title string
	STDCALL 0,0,800,15,BLA,fillrect

	;title string  (yellow text on black)
	STDCALL FONT01,0,0,[ebp+12],0xfdef,puts

	;background for message string
	STDCALL 0,15,800,15,YEL,fillrect

	;message string  (black text on yellow)
	STDCALL FONT01,0,15,[ebp+8],0xeffd,puts

	;make it show up
	call swaprect

	pop ebp
	retn 8






;**********************************************************
;popupmessage
;saves BACKBUF then displays a putmessage at bottom of screen 
;then pauses for a few seconds then restores the BACKBUF
;the popupmessage is two strings, the title is above the other
;input
;push address of 0 terminated title string   [ebp+12]
;push address of 0 terminated message string [ebp+8]
;return:none
;*********************************************************

popupmessage:

	push ebp
	mov ebp,esp
	pushad

	call backbufsave

	STDCALL [ebp+12],[ebp+8],putmessage

	;sleep so user can read the message
	mov ebx,3500  ;3.5 seconds
	call sleep

	;clear out the message and restore the screen as it was
	call backbufrestore
	call swapbuf

	popad
	pop ebp
	retn 8




 
;********************************************************************
;putcHershey
;a function to display a single hershey vector font character/glyph
;a Hershey glyph is an unfilled line drawing
;using a series of MoveTo and LineTo encoded as an ascii string
;each glyph may be scaled to suit
;see tlib/fontHershey.inc for the encoding of each glyph

;input
;push Hershey Font type                  [ebp+28]
;push X center of char                   [ebp+24]
;push Y center of char                   [ebp+20]
;push ascii char to display              [ebp+16]
;push color (byte from std palette)      [ebp+12]
;push scale factor factor                [ebp+8]

;return
;ecx=HersheyRightBound which is distance from center of glyph
;    to far right edge

;font type is a dword describing the font table
;0=HersheyRoman
;1=HersheyGothic

;the Hershey coordinates are both neg and pos about zero in x and y
;the glyph lines are drawn relative to center X,Y
;see notes in fontHershey.inc for the pixel size of these glyphs

;there is not a full compliment of ascii glyphs here
;HERSHEYROMAN is fairly complete but HERSHEYGOTHIC has only
;the upper and lower case alpha's
;again see fontHershey.inc

;the color is just a byte value from the std palette 0->0xfe

;the scale factor is an integer >= 1

;the Hershey ascii chars are converted to integer coordinates as follows:
;subtract the letter R (ascii decimal 82) from each char 
;e.g. O-R = 79-82 = -3 so O=-3 and O,M represents an x,y pair of -3,-5
;for more on this see fontHershey.inc

;the Hershey font data is encoded in ascii as follows:

;example for the letter H 
;H03:
;db 'MWOMOV RUMUV ROQUQ',0

;a tatOS Hershey string is 0 terminated
;other implementations may have a leading byte representing qty vertices
;each Hershey string must always be an even number of ascii chars
;the first two chars of every Hershey string (in this case MW) 
;represent the bounding box (xmin and xmax) of the char
;since the chars are a variable pitch font
;the next pair O,M represents a MoveTo
;the next pair O,V represents a LineTo
;any time you have a space followed by R this represents pen up
;the next pair after a pen up always represents a MoveTo
;the U,M represents a MoveTo
;the U,V represents a LineTo
;then we have a pen up followed by MoveTo O,Q and LineTo U,Q and done with H

;in a Hershey string the center of the next char is equal to the sum of
;the xmaxPrevious char + xminCurrent char

;you must use [YORIENT]=1 otherwise the characters will be displayed
;upside down  (Tom we need to fix this)



;locals
HERSHEYROMAN equ 0
HERSHEYGOTHIC equ 1

HersheyLeftBound: 
db 0
HersheyRightBound: 
db 0
HersheyX1:   
dd 0
HersheyY1:   
dd 0
HersheyScale:
dd 0
HersheyXC:
dd 0
HersheyYC:
dd 0
HersheyColor:
dd 0
;***********************************************************************

putcHershey:

	push ebp
	mov ebp,esp
	pushad


	;test for outside the ascii range 0x20-0x7e
	;display box char 0x7f for all nonprintable
	mov ecx,[ebp+16]
	and ecx,0xff   ;clear out the upper 3 bytes
	cmp ecx,0x20
	jb .showbox
	cmp ecx,0x7e
	ja .showbox
	jmp .loadaddress
.showbox:
	mov ecx,0x7f    ;we will display a box character


.loadaddress:

	;get the Hershey font type 
	mov esi,[ebp+28]

	cmp esi,HERSHEYROMAN
	jz .doRoman
	cmp esi,HERSHEYGOTHIC
	jz .doGothic
	jmp .done     ;error invalid font table specified

.doRoman:
	;get address of char from font lookup table
	lea esi,[HersheyRoman + ecx*4 - 0x80]
	jmp .SaveGlobals
.doGothic:
	lea esi,[HersheyGothic + ecx*4 - 0x80]


.SaveGlobals:
	mov esi,[esi]     ;read the glyph address in font table
	mov eax,[ebp+24]
	mov [HersheyXC],eax
	mov eax,[ebp+20]
	mov [HersheyYC],eax
	mov eax,[ebp+12]
	mov [HersheyColor],eax
	mov eax,[ebp+8]
	mov [HersheyScale],eax



	;now starting fetching bytes from the Hershey char string
	cld 

	;get and save the xmin/xmax boundry
	lodsb
	sub al,'R'
	mov [HersheyLeftBound],al
	lodsb
	sub al,'R'
	mov [HersheyRightBound],al

	xor eax,eax
	lodsb
	jmp .doMoveTo


.TopOfLoop:

	xor eax,eax
	lodsb         ;get next byte in Hershey string

	cmp al,0      ;tatOS Hershey string is 0 terminated
	jz .done
	cmp al,SPACE  ;check for penUP
	jz .doPenUp
	jmp .doLineTo

.doPenUp:
	lodsb         ;we must always have 'R' byte after SPACE
	xor eax,eax
	lodsb
	;then fall thru and do MoveTo

.doMoveTo:
	call HersheyMoveTo
	jmp .TopOfLoop

.doLineTo:
	call HersheyLineTo
	jmp .TopOfLoop


.done:
	popad
	pop ebp
	movzx ecx,byte [HersheyRightBound]  ;return 
	retn 24  ;cleanup 5 args




;******************************************************************
;HersheyMoveTo
;input
;al=Hershey char representing the X coordinate of MoveTo
;result
;HersheyX1 and HersheyY1 are saved
;******************************************************************

HersheyMoveTo:

	;process the MoveTo byte X
	sub eax,'R'
	;scale 
	mov ebx,[HersheyScale]
	imul ebx
	;add the absolute distance from screen origin to center of Xchar
	add eax,[HersheyXC]
	;save for LineTo
	mov [HersheyX1],eax

	;process the MoveTo byte Y
	xor eax,eax
	lodsb
	sub eax,'R'
	imul ebx
	add eax,[HersheyYC]
	mov [HersheyY1],eax
	
	ret





;******************************************************************
;HersheyLineTo
;input
;al=Hershey char representing the X coordinate of LineTo
;globals HersheyX1 and HersheyY1 must be contain valid values
;result
;a line is drawn from HersheyX1,HersheyY1 to LineToX,LineToY
;******************************************************************

HersheyLineTo:
	;stdcall str4,0,[DUMPEAX]

	push 0xffffffff  ;linetype
	push dword [HersheyX1]
	push dword [HersheyY1]
	
	;process the LineTo byte X
	sub eax,'R'
	mov ebx,[HersheyScale]
	imul ebx
	add eax,[HersheyXC]
	push eax
	mov [HersheyX1],eax


	;process the LineTo byte Y
	xor eax,eax
	lodsb
	sub eax,'R'
	imul ebx
	add eax,[HersheyYC]
	push eax
	mov [HersheyY1],eax

	push dword [HersheyColor]
	call line

	ret



;****************************************************
;GetHersheyLeftBound
;this function returns the left bound (xmin)
;of a particular Hershey glyph
;this is needed for determining xloc of the next
;char in a Hershey string
;input
;push Hershey Font type                  [ebp+12]
;push ascii char to display              [ebp+8]
;return
;ebx=HersheyLeftBound, on error ebx=0
;***************************************************

GetHersheyLeftBound:

	push ebp
	mov ebp,esp
	push ecx
	push esi
	;eax,ecx,edx,esi,ebp must be preserved for putsHershey


	;get ascii char in ecx
	;test for outside the ascii range 0x20-0x7e
	;display box char 0x7f for all nonprintable
	mov ecx,[ebp+8]
	and ecx,0xff   ;clear out the upper 3 bytes
	cmp ecx,0x20
	jb .showbox
	cmp ecx,0x7e
	ja .showbox
	jmp .loadaddress
.showbox:
	mov ecx,0x7f    ;we will display a box character


.loadaddress:
	;get the Hershey font type 
	mov esi,[ebp+12]

	cmp esi,HERSHEYROMAN
	jz .doRoman
	cmp esi,HERSHEYGOTHIC
	jz .doGothic
	jmp .error     ;invalid font table specified

.doRoman:
	;get address of char from font lookup table
	lea esi,[HersheyRoman + ecx*4 - 0x80]
	jmp .SaveGlobals
.doGothic:
	lea esi,[HersheyGothic + ecx*4 - 0x80]


.SaveGlobals:
	mov esi,[esi]     ;read the glyph address in font table

	;get HersheyLeftBound 
	mov bl,[esi]
	sub bl,'R'   
	;this is a negative value and we must sign extend the dword
	;to get the math to work out right for xloc of the next glyph
	or ebx,0xffffff00   ;ebx=return value HersheyLeftBound
	jmp .done

.error:
	xor ebx,ebx
.done:
	pop esi
	pop ecx
	pop ebp
	retn 8  ;cleanup 2 args





;*******************************************************
;putsHershey
;display a 0 terminated ascii string of Hershey chars
;input
;push X center of first char                   [ebp+28]
;push Y center of first char                   [ebp+24]
;push Address of 0 terminated ascii string     [ebp+20]
;push color (byte from std palette)            [ebp+16]
;push FontType 0=HERSHEYROMAN, 1=HERSHEYGOTHIC [ebp+12]
;push scale factor (integer >=1)               [ebp+8]

;the height of the glyphs depends on your scale factor
;also HERSHEYROMAN is smaller than HERSHEYGOTHIC for 
;the same scale factor.  see notes in fontHershey.inc
;********************************************************

putsHershey:

	push ebp
	mov ebp,esp
	pushad

	cld

	;store address of string
	mov esi,[ebp+20]

	;get the first char
	xor eax,eax
	lodsb           ;al=[esi], esi++

	;xloc
	mov edx,[ebp+28]
	

.DrawHersheyGlyph:

	push dword [ebp+12]   ;font type
	push edx              ;xloc
	push dword [ebp+24]   ;yloc
	push eax              ;ascii char
	push dword [ebp+16]   ;color
	push dword [ebp+8]    ;scale
	call putcHershey
	;returns ecx=HersheyRightBoundOld


	;get the next char in the string
	lodsb   ;al=[esi], esi++

	cmp al,0   ;check for 0 terminator
	jz Done

	;get the HersheyLeftBoundNew
	push dword [ebp+12]  ;font type
	push eax             ;ascii char
	call GetHersheyLeftBound 
	;returns ebx=left bound which is negative
	

	;increment xloc += (HersheyRightBoundOld + HersheyLeftBoundNew) * scale
	neg ebx          ;make HersheyLeftBound positive
	add ecx,ebx      ;add HersheyRightBound+HersheyLeftBound
	push eax
	push edx         ;preserve xloc because mul uses edx
	mov eax,[ebp+8]  ;scale factor
	mul ecx          ;eax=(HersheyRightBound+HersheyLeftBound)*scale
	pop edx
	add edx,eax      ;edx=xloc + (HersheyRightBound+HersheyLeftBound)*scale
	pop eax

	jmp .DrawHersheyGlyph

Done:
	popad
	pop ebp
	retn 24





