;tatOS/tlib/palette.s

;various routines dealing with the palette and colors:

;setpalette, genstdpalette, gengraypalette, setdaccolor, choosecolor
;getpixel, getrgb, putpalette, PaletteManager, SetReservedColors



;**************************************
; program the DAC
; this is where we load a palette
; DAC color values are 6 bit 
; see Michael Abrash for more info on this
; here the palette is an arry of bytes 
; of RGB triples (rrggbbrrggbb...)
; each byte ranges from 0-63 (0x3f=111111)
; the total byte count must be a multiple of 3 (rgb)
; in boot2 we generate the std and gray palettes
; then we load the std pal to DAC
; we use the array PALETTE defined in tlib.s
; to store whats in the DAC
;**************************************




;******************************************
;tatOS reserved palette colors  Sept 2012
;******************************************
;color index 239-255
;the stdpalette and graypalette are generated with these colors at the end
;the very last entry of every palette is reserved for the background color
;all values are scaled for 6 bit 0-63 max (RGB * 63 / 255 = DAC)
;a quick alternative to converting the 8bit to 6bit scaling
;is to just shift the 8bit value right by 2 bits
;see tatos.inc where these colors are %defined
;if you reorder these colors, do the same in tatos.inc and ttasm.s
;some examples:
;63DAC=255RGB
;42DAC=170RGB
;0x3f=63, 0x2a=42, 0x30=48, 0x15=21

vga16:
;  r,g,b
db 0,0,0    ;239 0xef BLACK
db 0,0,42   ;240 0xf0 BLUE   ;63 is too bright for tedit comment text
db 0,48,0   ;241 0xf1 GREEN  ;63 is too bright
db 0,42,42  ;242 0xf2 CYAN
db 42,0,42  ;243 0xf3 MAGENTA  (purple)
db 42,21,0  ;244 0xf4 BROWN
db 48,0,0   ;245 0xf5 RED    ;63 is too bright for tedit carot
db 42,42,42 ;246 0xf6 LTGRAY
db 21,21,21 ;247 0xf7 DKGRAY
db 21,21,63 ;248 0xf8 LTBLUE
db 21,63,21 ;249 0xf9 LTGREEN
db 21,63,63 ;250 0xfa LTCYAN
db 63,21,21 ;251 0xfb LTRED
db 63,21,63 ;252 0xfc LTMAGENTA
db 63,63,21 ;253 0xfd YELLOW
db 63,63,63 ;254 0xfe WHITE
;255 0xff is reserved for the background color



;these are supposedly the Windows basic 16 colors
;scaled for 0-3f, here for reference only
;I prefer the darker cyan over teal
;and my preferred blue is darker as well
;and I have a brown which doesnt appear here at all
Windows16:
db 00,00,00 ;black
db 31,00,00 ;maroon
db 00,31,00 ;green
db 31,31,00 ;olive
db 00,00,31 ;navy
db 31,00,31 ;purple
db 00,31,31 ;teal
db 47,47,47 ;silver
db 31,31,31 ;gray
db 63,00,00 ;red
db 00,63,00 ;lime
db 63,63,00 ;yellow
db 00,00,63 ;blue
db 63,00,63 ;fuchsia
db 00,63,63 ;aqua
db 63,63,63 ;white



;**************************************************
;setpalette
;load the DAC with a palette

;input:
;push 0 = use stdpalette             [ebp+8]
;     1 = use grayscale palette
;     N = custom palette, N is the dword address
;         of an array of 768 bytes representing
;         your custom palette

;if you push N=custom palette then you must also 
;provide ebx=0000ttbb color of text to be used
;for kernel isr routines that use puts
;tt=index of dark color or black
;bb=index of lite color or white

;note also a properly behaved app should restore
;the standard palette before exiting
;otherwise tatOS may be unuseable

;return:none 

;this function just copies either
;local array _stdpalette or _graypalette 
;or your N custom palette array
;to global array [PALETTE]
;max qtybytes is 256colors*3=768bytes
;A well behaved app should at the end restore
;the stdpalette
;note:the last 17 entries of any palette are
;reserved colors

setpalstr1 db 'setpalette argument',0
setpalettetype dd 0
;**************************************************

setpalette:

	push ebp
	mov ebp,esp
	pushad

	mov eax,[ebp+8]
	STDCALL setpalstr1,0,dumpeax

	;save the palette type for tlib functions wanting to know 
	;what the current palette is
	mov eax,[ebp+8]
	mov [setpalettetype],eax

	cmp eax,0
	jz .copystdpal
	cmp eax,1
	jz .copygraypal
	jmp .copycustompal
	

.copystdpal:
	mov esi,_stdpalette
	mov edi,palette
	mov ecx,768
	call strncpy  

	;and set the kernel text color for isr messages using puts
	mov dword [KERNELTXTCOLOR],0xeffe   ;black on white

	jmp .loadDAC


.copygraypal:
	mov esi,_graypalette
	mov edi,palette
	mov ecx,768
	call strncpy  

	;and set the kernel text color for isr messages using puts
	mov dword [KERNELTXTCOLOR],0xeffe   ;black on white

	jmp .loadDAC


.copycustompal:

	;Aug 2012
	;I used to include a call to SetReservedColors here
	;to give the custom palette the reserved colors
	;but this breaks code like Plasma which requires a full 256 color custom palette
	;so if you want a custom palette you must add the reserved colors yourself
	;and the user must call SetKernelTextColors to define dark on lite text colors
	;for use by the isr puts messages

	;copy the custom palette to "palette"
	mov esi,[ebp+8]
	mov edi,palette
	mov ecx,768
	call strncpy  

	;save kernel text color
	mov [KERNELTXTCOLOR],edx
	


.loadDAC:  
	;loop 768 times to set 256*3 rgb values to DAC
	;load the DAC with "PALETTE" 
	mov al,0      ;starting index=0
	mov dx,0x3c8  ;control
	out dx,al
	mov dx,0x3c9  ;data

	mov esi,palette
	mov ecx,768  ;256 reg + 256 green + 256 blu = 768
.1:
	mov al,[esi] 
	out dx,al 
	inc esi
	loop .1

.done:
	popad
	pop ebp
	ret 4







;********************************************
; stdpalette
; this is our standard palette of 256 colors
; the first 216 colors are generated from
; a 6x6x6 array where each is 6bit max
; the next 22 colors are shades of gray
; the next entry is unused
; the next 16 colors are the vga16 colors
; the last entry 0xff is reserved for
; the background color
; the program bm8gen uses the same palette
;********************************************

;256 entries * 3 bytes per = 768

_stdpalette times 768 db 0
_r db 0
_g db 0
_b db 0



;********************************
;genstdpalette
;fill the _stdpalette array entries
;6x6x6=216 colors
;change red fastest
;takes no args and returns no value
;********************************

genstdpalette:

	mov eax,0 
	mov ebx,0  ;DAC color value
	mov edx,0  ;DAC color value
	mov ecx,0

.1: 
	mov [_stdpalette + ecx    ], al  ;r
	mov [_stdpalette + ecx + 1], bl  ;g
	mov [_stdpalette + ecx + 2], dl  ;b

	;inner loop
	add ecx,3
	add al,12
	inc byte [_r]
	cmp byte [_r],6
	jb .1

	;middle loop
	mov byte [_r],0
	mov al,0
	add bl,12
	inc byte [_g]
	cmp byte [_g],6
	jb .1

	;outer loop
	mov byte [_r],0
	mov al,0
	mov byte [_g],0
	mov bl,0
	add dl,12
	inc byte [_b]
	cmp byte [_b],6
	jb .1


	;now append 22 shades of gray
	;starting with black (0,0,0) index=216  GRAY1
	;ending with white (63,63,63) index=237  GRAY22
	;GRAY1 thru GRAY22 are defined in tatos.inc
	mov bl,0  ;DAC color value
.2:
	mov [_stdpalette + ecx], bl
	mov [_stdpalette + ecx + 1], bl
	mov [_stdpalette + ecx + 2], bl

	add ecx,3
	add bl,3
	cmp bl,64
	jb .2


	;skip a color (ends up being black in the DAC)
	;unused entry 238
	add ecx,3


	;now append the reserved colors
	mov edi,_stdpalette
	call SetReservedColors

	ret







;***********************************************
;graypalette
;generate a uniform  gray scale palette 
;since DAC values are 6 bit (0x3f or 63 max)
;we only have 64 shades of gray at our disposable
;after the 64 shades, we set the next 176 entries
;to white (basically unused)
;and then append the vga16 basic colors

;this palette can be used to display 
;a windows 24bit color image just by 
;the following formula:
;index into gray palette = [(r+g+b)/3] * 64 / 256
;were r,g,b goes from 0-256
;***********************************************
_graypalette times 768 db 0

gengraypalette:

	;the first 64*3 entires are the shades of gray
	;starting at 0=black to 64=white
	mov ebx,0  ;DAC color value
	mov edi,_graypalette
.1:
	mov [edi],ebx  ;r
	inc edi
	mov [edi],ebx  ;g
	inc edi
	mov [edi],ebx  ;b
	inc edi

	inc ebx
	cmp ebx,64
	jb .1


	;the next 176*3 entries are all white (3f,3f,3f)
	mov ecx,175	
.2:
	mov byte [edi],0x3f
	inc edi
	mov byte [edi],0x3f
	inc edi
	mov byte [edi],0x3f
	inc edi
	
	dec ecx
	jnz .2


	;now append the reserved colors
	mov edi,_graypalette
	call SetReservedColors

	ret




;***************************************************************
;SetReservedColors
;function overwrites the last 17 entires of a palette
;with the vga16 reserved colors plus our std background color
;input:
;edi=address of palette
;return:none
;***************************************************************

SetReservedColors:

	;we starting writting to the palette at offset 716
	;717=768-17*3
	add edi,717 

	mov eax,0
.1:
	mov bl,[vga16+eax] 
	mov [edi],bl 
	inc edi
	inc eax
	cmp eax,48
	jb .1


	;the last entry 0xff is reserved for the bkcolor
	;if you prefer a CYAN background 
;	mov byte [edi], 0
;	inc edi
;	mov byte [edi], 42
;	inc edi
;	mov byte [edi], 42

	;if you prefer a TAN background 
	mov byte [edi], 0x38
	inc edi
	mov byte [edi], 0x34
	inc edi
	mov byte [edi], 0x27

	ret






;**************************************************
;setdaccolor
;this changes any one of the 256 colors
;in the DAC, each byte may range from 0-63 (0x3f)

;input:
;dl=rr (red byte 0-0x3f)
;dh=gg (gre byte 0-0x3f)
;bl=bb (blu byte 0-0x3f)
;cl=color index you want to change (0-0xff)
;    0xff will change the background color

;return:none

;local
_colorindex db 0
;**************************************************

setdaccolor:

	pushad

	;save for later
	mov [_colorindex],cl
	mov [_r],dl
	mov [_g],dh
	mov [_b],bl

	mov dx,0x3c8  ;control
	mov al,[_colorindex]
	out dx,al     
	;tell DAC which color to change, cl=color index
	
	;now write the r g b data bytes
	mov dx,0x3c9  ;data
	mov al,[_r] 
	out dx,al 
	mov al,[_g] 
	out dx,al 
	mov al,[_b] 
	out dx,al 


	;update the color in the PALETTE 
	;for the benefit of getpixel
	mov edx,palette ;edx=address of current palette array
	xor ecx,ecx
	mov cl,[_colorindex]
	add edx,ecx
	add edx,ecx
	add edx,ecx  ;edx=PALETTE+index*3
	mov al,[_r]
	mov [edx],al
	mov al,[_g]
	mov [edx+1],al
	mov al,[_b]
	mov [edx+2],al

	popad
	ret

	


;***********************************************************
;getpixel
;get r,g,b colors at x,y location

;input:
;push  xloc   [ebp+12]
;push  yloc   [ebp+8]

;return: eax=0xblgrrdci where bl=blue, gr=green, rd=red, ci=color index

;this function reads the LFB then goes to the current PALETTE array
;PALETTE is a color array of 768 bytes defined in tlib.s
;it does not actually read any DAC ports
;you would typically input ebx=[MOUSEX], eax=[MOUSEY]
;note also you must call this function in your paint routine
;before drawing the mouse cursor
;**********************************************************

getpixel:

	push ebp
	mov ebp,esp

	push edi
	push edx

	;ebx=x, eax=y, returns address of pixel in edi
	push dword [ebp+12]  ;x
	push dword [ebp+8]   ;y
	call getpixadd
	
	;get color index  (0-255)
	xor ecx,ecx
	mov cl,[edi]

	;ecx=color index
	call getrgb
	;dl=red
	;dh=green
	;bl=blue

	;for the benefit of tlib protected mode interface
	;which can not return any values in ecx or edx
	;we pack everything into eax
	;low byte=color index
	;bits8:15=red
	;bits16:23=green
	;bits24:31=blue
	mov eax,ecx
	and edx,0xffff  
	shl edx,8
	or eax,edx
	and ebx,0xff
	shl ebx,24
	or eax,ebx

	pop edx
	pop edi
	pop ebp
	retn 8




;***********************************************
;getrgb
;gets the rrggbb color components
;of any one of the 256 currently loaded colors

;input
;ecx=color index 0-0xff

;return
;dl=red
;dh=green
;bl=blue

;note these are 6bit scaled for the DAC 0-0x3f
;***********************************************

getrgb:

	push eax

	;get red
	mov eax,palette ;address of currently loaded DAC palette
	add eax,ecx
	add eax,ecx
	add eax,ecx  ;edx=PALETTE+index*3
	mov dl,[eax] ;al=r

	;get green
	mov dh,[eax+1]

	;get blue
	mov bl,[eax+2]

	pop eax
	ret



 



;***************************************************************
;putpalette
;draws the 256 colors of the current palette
;as a grid of 16x16 squares
;square at upper left is ColorIndex=0
;square at lower right is ColorIndex=0xff
;each square is 20x20 pixels
;so the entire grid takes up 320x320 pixels
;the grid starts at X=200, Y=100
;input:none
;return:none
;to make it show up call swapbuf
palLabel db '0123456789abcdef',0
putpalstr1 db 'putpalette',0
;***************************************************************

putpalette:

	;STDCALL putpalstr1,dumpstr

	;initialize for multiple execution
	mov ebx,200 ;x upper left corner of grid
	mov eax,100 ;y 
	mov ecx,20  ;w each color square is 20x20
	mov esi,20  ;h
	mov dl,0   ;color index


	;paint the grid of color squares
.paintrow:
	;draw 1 rect
	STDCALL ebx,eax,ecx,esi,edx,fillrect

	;inc x and color
	add ebx,20
	inc dl   
	cmp ebx,520
	jb .paintrow

	;inc for next row
	mov ebx,200
	add eax,20 
	cmp eax,420
	jb .paintrow


	;display a horizontal white rect behind the column labels
	STDCALL 180,80,340,20,WHI,fillrect


	;display the column labels across the top
	mov ebx,FONT01
	mov esi,205    ;xstart
	mov edi,85     ;y
	mov edx,0xeffe ;color
	mov ecx,0      ;num col start also serves as array index
.paintColumnLabel:
	push ecx
	mov cl,[palLabel+ecx]  ;get char to display
	call putc
	pop ecx
	add ecx,1    ;inc num col
	add esi,20   ;inc x
	cmp ecx,16   ;max 16 columns
	jb .paintColumnLabel


	;display a vertical white rect behind the row labels
	STDCALL 180,80,20,340,WHI,fillrect


	;display the row labels vertical down left of the grid
	mov esi,190  ;x
	mov edi,105  ;ystart
	mov edx,0xeffe
	mov ecx,0
.paintRowLabel:
	push ecx
	mov cl,[palLabel+ecx]
	call putc
	pop ecx
	add ecx,1
	add edi,20  ;inc y
	cmp ecx,16
	jb .paintRowLabel

	ret





;****************************************************************************
;PaletteManager    9/7/2012
;allows you to switch between std and gray palettes from shell
;also permits changing the background color from the palette
;or use r,g,b + CTRL keys to set a custom background color
;shows the color components on the fly
;input:none
;return:none
;****************************************************************************

palmgrMenu:
db 'Palette Manager',NL
db 'F1=Set Standard Palette',NL
db 'F2=Set Gray Palette',NL
db 'F3=Set Background Color from palette',NL
db 'To set custom background color use r,g,b & CTRL keys',0

palred db 0
palgreen db 0
palblue db 0

palmgrstr1 db 'SetBackgroundColor: Enter color value as 0xRC (R=row, C=column)',0
palmgrstr2 db 'red',0
palmgrstr3 db 'green',0
palmgrstr4 db 'blue',0

palmgrstr5 db 'decrementing green',0


PaletteManager:


	;we will show live the color components of the backgroundcolor
	mov ecx,0xff
	call getrgb
	mov [palred],  dl
	mov [palgreen],dh
	mov [palblue], bl

	call backbufclear  
	call putpalette

	;to ensure the text is visible regardless of background color
	STDCALL 0,450,800,150,WHI,fillrect

	;menu string
	STDCALL FONT01,0,450,palmgrMenu,0xefff,putsml

	;display the r,g,b color values 
	movzx eax,byte [palred]
	STDCALL 400,450,0xefff,palmgrstr2,puteaxstr
	movzx eax,byte [palgreen]
	STDCALL 400,470,0xefff,palmgrstr3,puteaxstr
	movzx eax,byte [palblue]
	STDCALL 400,490,0xefff,palmgrstr4,puteaxstr


	call swapbuf  ;end paint

	call getc

	cmp al,ESCAPE
	jz near .done
	cmp al,F1
	jz .setStdPalette
	cmp al,F2
	jz .setGrayPalette
	cmp al,F3
	jz .setBKcolor
	;cmp al,F4
	;jz near .getRGB
	cmp al,0x72   ;r key
	jz near .dored
	cmp al,0x67   ;g key
	jz near .dogreen
	cmp al,0x62   ;b key
	jz near .doblue

	;all other keypresses
	jmp PaletteManager


.setStdPalette:
	push dword 0
	call setpalette
	jmp PaletteManager

.setGrayPalette:
	push dword 1
	call setpalette
	jmp PaletteManager

.setBKcolor:
	call SetBackgroundColor
	jmp PaletteManager


.dored:
	mov al,[palred]
	cmp byte [CTRLKEYSTATE],1 
	jz .decred
	;increment
	inc al
	cmp al,0x3f
	jbe .setred
	mov al,0x3f  ;clamp
	jmp .setred
.decred:
	dec al
	jns .setred
	mov al,0
.setred:
	mov [palred],al
	call SetCustBkCol
	jmp PaletteManager


.dogreen:
	mov al,[palgreen]
	cmp byte [CTRLKEYSTATE],1 
	jz .decgreen
	;increment
	inc al
	cmp al,0x3f
	jbe .setgreen
	mov al,0x3f  ;clamp
	jmp .setgreen
.decgreen:
                     STDCALL palmgrstr5,dumpstr
	dec al
	jns .setgreen
	mov al,0
.setgreen:
	mov [palgreen],al
	call SetCustBkCol
	jmp PaletteManager


.doblue:
	mov al,[palblue]
	cmp byte [CTRLKEYSTATE],1 
	jz .decblu
	;increment
	inc al
	cmp al,0x3f
	jbe .setblu
	mov al,0x3f  ;clamp
	jmp .setblu
.decblu:
	dec al
	jns .setblu
	mov al,0
.setblu:
	mov [palblue],al
	call SetCustBkCol
	jmp PaletteManager


.done:
	ret
	;end PaletteManager main




;this routine sets a custom background color based on the users
;pressing the r,g,b or CTRL keys
SetCustBkCol:
	mov dl,[palred]
	mov dh,[palgreen]
	mov bl,[palblue]
	mov cl,0xff
	call setdaccolor
	ret

 

;this routine sets the background color based on an existing entry in the palette
SetBackgroundColor:

	;prompt user to enter color as 0xRC  (row/column)
	STDCALL palmgrstr1,COMPROMPTBUF,comprompt
	jnz .done

	;convert user string to value in eax
	mov esi,COMPROMPTBUF
	call str2eax
	jnz .done
	mov ecx,eax

	;convert the color index in ecx to rrggbb
	call getrgb
	;dl=rr, dh=gg, bl=bb

	;set the new background color
	mov ecx,BKCOLOR
	call setdaccolor

.done:
	ret




;*****************************************************************************
;choosecolor
;displays the 16x16 grid = 256 colors of the current palette
;if usb mouse is available user may Lclick on a color
;else if user will press any key
;user is prompted to enter 0xRC color value
;this function is for user apps to select a color

;input:none
;return:eax=color index (0-0xff) else eax=-1 on error

;local
choosestr0 db 'choosecolor',0
choosestr1 db 'Choose Color-Lclick or press any key for manual entry',0
choosestr2 db 'Enter color index as 0xRC (R=row, C=column, 0xff=background)',0
choosestr3 db 'Choose color return value',0
choosestr4 db 'choosecolor: HandleLeftClick',0
cc_col dd 0
;****************************************************************************

choosecolor:

	STDCALL choosestr0,dumpstr

.1:
	call backbufclear

	;title/instruction string for choose color
	STDCALL FONT01,200,50,choosestr1,0xefff,puts

	;display the 16x16 color palette
	call putpalette

	call arrowpointer
	call swapbuf

	call checkc
	jnz .HandleKeyboard 

	call usbcheckmouse
	cmp al,1  
	jz .HandleLeftClick

	jmp .1 



.HandleLeftClick:

	STDCALL choosestr4,dumpstr  ;for debug only

	;here the use may Lclick on a color square to select
	;convert mouseX position to row/col of palette grid
	mov eax,[MOUSEX]
	sub eax,200     ;grid starts at x=200
	js .failure     ;mouse is left of grid
	cmp eax,320     ;grid is 320 pixels wide
	jae .failure    ;mouse is right of grid
	mov ebx,20      ;each square is 20 pixels wide
	xor edx,edx
	div ebx         ;eax=col number
	mov [cc_col],eax

	;convert mouseY position
	mov eax,[MOUSEY]
	sub eax,100     ;grid starts at y=100
	js .failure     ;mouse is above grid
	cmp eax,320     ;grid is 320 pixels hi
	jae .failure    ;mouse is below grid
	mov ebx,20      ;each square is 20 pixels wide
	xor edx,edx
	div ebx         ;eax=row number

	;compute array offset
	push dword [cc_col]
	push eax  ;row
	push 16   ;bmwidth
	call xy2i ;eax=array offset 0->255 color selection
	jmp .done


.HandleKeyboard:

	;prompt user to enter color as 0xRC  (row/column)
	STDCALL choosestr2,COMPROMPTBUF,comprompt
	jnz .failure

	;convert user string into color value in al
	mov esi,COMPROMPTBUF
	call str2eax   ;color return value is in eax
	jnz .failure
	or ebx,1       ;zf is clear
	jmp .done

.failure:
	mov eax,-1 
.done:
	STDCALL choosestr3,0,dumpeax
	ret












