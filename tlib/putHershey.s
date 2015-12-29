;tatOS/tlib/putHershey.s

;functions to display a Hershey scaleable font  on the screen
;see fontHershey.inc for details on what a Hershey font is for tatOS

;putcHershey
;putsHershey
;GetHersheyLeftBound
;HersheyMoveTo
;HersheyLineTo



;data
HersheyLeftBound: 
db 0
HersheyRightBound: 
db 0
HersheyX1:   
dd 0
HersheyY1:   
dd 0
HersheyX2:
dd 0
HersheyY2:
dd 0
HersheyScale:
dd 0
HersheyXC:
dd 0
HersheyYC:
dd 0
HersheyColor:
dd 0
HersheyCharLessR:
dd 0
HersheyRightPlusLeftBound:
dd 0
HersheyRightPlusLeftBoundScaled:
dd 0


 
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
;push dword 0 not used                   [ebp+8]
;st0 = qword scale factor

;return
;ecx=HersheyRightBound which is distance from center of glyph
;    to far right edge

;font type is a dword describing the font table
;0=HERSHEYROMANLARGE  (font03)
;1=HERSHEYGOTHIC      (font04)
;2=HERSHEYROMANSMALL  (font05)

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

;this function takes that value of YORIENT into consideration and so will
;draw the glyph upright regardless of its value

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

	cmp esi,HERSHEYROMANLARGE
	jz .doRomanLarge
	cmp esi,HERSHEYROMANSMALL
	jz .doRomanSmall
	cmp esi,HERSHEYGOTHIC
	jz .doGothic

	jmp .done     ;error invalid font table specified

	;set esi to hold address of a Hershey char
.doRomanLarge:
	;get address of char from font lookup table
	lea esi,[HersheyRoman03 + ecx*4 - 0x80]
	jmp .SaveGlobals
.doRomanSmall:
	;get address of char from font lookup table
	lea esi,[HersheyRoman05 + ecx*4 - 0x80]
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
;this function is privately called by putcHershey
;input:
;  al  = ascii value of Hershey char representing the X coordinate MoveTo
;  esi = address of Hershey char
;  st0 = scale factor
;  dword [HersheyXC], [HersheyYC]
;result:
;  HersheyX1 and HersheyY1 are saved
;******************************************************************

HersheyMoveTo:

	;process the MoveTo byte X
	sub eax,'R'

	;and save it to memory
	mov dword [HersheyCharLessR],eax

	;and load it into the fpu
	fild dword [HersheyCharLessR]   ;st0=MoveTo_X, st1=scale

	;and scale it
	fmul st1                        ;st0=MoveTo_X * scale, st1=scale

	;add the absolute distance from screen origin to center of Xchar
	fiadd dword [HersheyXC]        ;st0=(MoveTo_X * scale) + HersheyXC, st1=scale

	;and save for LineTo
	fistp dword [HersheyX1]        ;st0=scale


	;process the MoveTo_Y same as MoveTo_X  (no comments here)
	xor eax,eax                    ;eax=0
	lodsb
	sub eax,'R'
	mul dword [YORIENT]            ;1 for topdown, -1 for bottomup
	mov dword [HersheyCharLessR],eax
	fild dword [HersheyCharLessR]  
	fmul st1   
	fiadd dword [HersheyYC]  
	fistp dword [HersheyY1]        ;st0=scale

	;returns:
	;HersheyX1, HersheyY1  are the x1,y1 coordinates of a line
	;st0=scale factor still
	ret





;******************************************************************
;HersheyLineTo
;this function is privately called by putcHershey
;input:
;   al = Hershey char representing the X coordinate of LineTo
;  esi = address of Hershey char
;  st0 = scale factor
;  dword [HersheyXC], [HersheyYC], [HersheyX1], [HersheyY1] 
;result:
;a line is drawn from HersheyX1,HersheyY1 to LineToX,LineToY
;******************************************************************

HersheyLineTo:

	;stdcall str4,0,[DUMPEAX]

	push 0xffffffff          ;linetype
	push dword [HersheyX1]   ;x1  from MoveTo
	push dword [HersheyY1]   ;y1  from MoveTo
	
	;process the LineTo_X byte
	;see HersheyMoveTo for comments about what we are doing here using the fpu
	sub eax,'R'
	mov dword [HersheyCharLessR],eax
	fild dword [HersheyCharLessR]  
	fmul st1   
	fiadd dword [HersheyXC]  
	fistp dword [HersheyX2]        ;st0=scale
	push dword [HersheyX2]         ;x2

	
	;process the LineTo_Y byte
	xor eax,eax
	lodsb
	sub eax,'R'
	mul dword [YORIENT]  ;1 for topdown, -1 for bottomup
	mov dword [HersheyCharLessR],eax
	fild dword [HersheyCharLessR]  
	fmul st1   
	fiadd dword [HersheyYC]  
	fistp dword [HersheyY2]        ;st0=scale
	push dword [HersheyY2]         ;y2

	push dword [HersheyColor]
	call line  ;requires linetype,x1,y1,x2,y2,color pushed on stack

	;assign x2 to x1 and y2 to y1 for the next LineTo
	mov eax,[HersheyX2]
	mov [HersheyX1],eax
	mov ebx,[HersheyY2]
	mov [HersheyY1],ebx


	;st0=scale factor still
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
	;eax,ecx,edx,esi,ebp must be preserved for puts Hershey call


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

	cmp esi,HERSHEYROMANLARGE
	jz .doRomanLarge
	cmp esi,HERSHEYROMANSMALL
	jz .doRomanSmall
	cmp esi,HERSHEYGOTHIC
	jz .doGothic

	jmp .error     ;invalid font table specified

.doRomanLarge:
	;get address of char from font lookup table
	lea esi,[HersheyRoman03 + ecx*4 - 0x80]
	jmp .SaveGlobals
.doRomanSmall:
	;get address of char from font lookup table
	lea esi,[HersheyRoman05 + ecx*4 - 0x80]
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
;push X center of first char                      [ebp+28]
;push Y center of first char                      [ebp+24]
;push dword Address of 0 terminated ascii string  [ebp+20]
;push dword color (0-0xff from std palette)       [ebp+16]
;push dword FontType                              [ebp+12]
;push dword 0 (not used)                          [ebp+8]
;st0 = qword scale factor

;NOTE!
;calling function must free st0 when done !!!

;the FontType may be:
;0=HERSHEYROMANLARGE  (font03)
;1=HERSHEYGOTHIC      (font04)
;2=HERSHEYROMANSMALL  (font05)

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
	push dword [ebp+8]    ;0 not used
	;st0=scale factor put in st0 by calling procedure
	call putcHershey
	;returns ecx=HersheyRightBoundOld


	;get the next char in the string
	lodsb   ;al=[esi], esi++

	cmp al,0   ;check for 0 terminator
	jz .done

	;get the HersheyLeftBoundNew
	push dword [ebp+12]  ;font type
	push eax             ;ascii char
	call GetHersheyLeftBound 
	;returns ebx=left bound which is negative
	

	;increment xloc += (HersheyRightBoundOld + HersheyLeftBoundNew) * scale
	neg ebx          ;make HersheyLeftBound positive
	add ecx,ebx      ;ecx = HersheyRightBound + HersheyLeftBound
	mov dword [HersheyRightPlusLeftBound],ecx

	;and load it into the fpu
	fild dword [HersheyRightPlusLeftBound]   ;st0=L+Rbound, st1=scale

	;and scale it
	fmul st1                        ;st0=L+Rbound * scale, st1=scale
	
	;and save it as integer
	fistp dword [HersheyRightPlusLeftBoundScaled]

	;edx = xloc + (HersheyRightBound+HersheyLeftBound)*scale
	add edx,[HersheyRightPlusLeftBoundScaled]
	
	jmp .DrawHersheyGlyph

.done:
	popad
	pop ebp
	retn 24





