
;Project: TCAD
;txt40 Dec 28, 2015


;this file contains code and data for TCD_TEXT


;the text link stores unique properties as follows:

;offset size description
;80  qword x
;88  qword y
;96  qword text height scale factor
;104 dword x1 bounding box inflated & clipped screen coordinates
;108 dword y1 bounding box inflated & clipped screen coordinates
;112 dword x2 bounding box inflated & clipped screen coordinates
;116 dword y2 bounding box inflated & clipped screen coordinates
;120->220 reserved for the text string
;         max 100 bytes including 0 terminator
;         ascii characters
;         displayed using HERSHEYROMANSMALL font



;the text height is determined as follows:
;each HERSHEYROMANSMALL glyph is 9 pixels/units tall
;they go from y=-5 to y=4
;if we set the default dword [TextHeightScale] value to 0.100
;then on the screen the text height will measure in TCAD as
;0.100 times 9 = 0.9
;the zoom factor affects how the text appears on the screen
;but it does not affect how the text height is measured



;code labels in this file:

;txtcreate     (public)
;txtdelete
;txtmove
;txtcopy
;txtread       (public)
;txtwrite
;txtselect
;txtselectdrag
;txtpaint
;txtmirror
;txtscale
;txtdump

;txtmodify      (public)
;txtmodifyxy
;txtmodifystring






;txt.s to be placed in memory after io.s
;see main.s for complete TCAD memory map
org 0x2020000



;assign a unique number to this source file
;this prevents defining a duplicate public symbol 
;in more than one source file
;main.s = 00
;seg.s  = 01
;io.s   = 02
;txt.s  = 03
source 3



;*****************
;   EXTERN
;*****************

;symbols that are defined in main.s
extern GetMousePnt
extern CreateBLink
extern GetSelObj
extern UnselectAll
extern GetLayItems
extern LftMousProc
extern EntrKeyProc
extern FlipKeyProc
extern PassToPaint
extern headlink
extern float2int






;**********************
;   EQUates
;**********************

equ TCD_TEXT     4




;******************
;    DATA
;******************


;bytes


 
;dwords
object:
dd 0


;qwords
TextHeightScale:
dq .100


;arrays
MouseScreenXY:
db0 8



;strings
str1:
db 'txtcreate',0
str2:
db '[TextCreate] Enter text string max 80 chars',0
str3:
db 'txtcreate_11',0
str4:
db 'txtpaint',0
str5:
db 'txtselect',0




;for debugging where we are in the code sometimes
flag1:
db 'flag1',0
flag2:
db 'flag2',0
flag3:
db 'flag3',0
flag4:
db 'flag4',0









;********************************************
;txtcreate

;create a new link in the list for text

;user is prompted to:
;  * enter text string
;  * Lclick to place text

;text is drawn with HERSHEYROMANSMALL in the 
;current layer

;text height is set from a seperate menu pick

;input: none

;return:
;eax=dword [FeedbackMessageIndex]
;ebx=address of left mouse handler
;esi=address of newly created line segment
;*********************************************

public txtcreate

	push ebp
	mov ebp,esp

	dumpstr str1


	call CreateBLink
	;test return value, esi holds address of link


	;get the current layer
	mov ecx,0  ;dumy layer index
	call GetLayItems
	;this function returns:
	;eax=layer name
	; bl=visibility
	; cl=color
	;edx=linetype
	;edi=dword [currentlayer]
	;esi=preserved


	;initialize values for the line object
	mov dword [esi],TCD_TEXT
	mov [esi+4],edi        ;current layer index
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],0   ;qty points
	mov dword [esi+16],0   ;dat pointer
	mov dword [esi+20],txtpaint
	mov dword [esi+24],txtdelete
	mov dword [esi+28],txtcopy
	mov dword [esi+32],txtmove
	mov dword [esi+36],txtmirror
	mov dword [esi+40],txtmodify
	mov dword [esi+44],txtwrite
	mov dword [esi+48],txtread
	mov dword [esi+52],txtselect
	mov dword [esi+56],txtscale
	mov dword [esi+60],txtdump
	mov dword [esi+64],txtselectdrag
	mov dword [esi+68],objectstub



	;and zero out the x,y coordinates
	fldz
	fst  qword [esi+80]
	fstp qword [esi+88]


	;save the object link address for the other segmentcreate procs
	mov [object],esi


	;get text string from user
	;comprompt can only collect up to 80 chars
	;and we have reserved 100 bytes in the link
	mov eax,54
	mov ebx,str2       ;address prompt string
	lea ecx,[esi+120]  ;address destination buffer
	sysenter
	;jnz .error   ;user hit ESC


	;prompt user to make a mouse pick to place the text
	mov eax,89
	mov ebx,txtcreate_11

	pop ebp
	ret



txtcreate_11:

	;this is a left mouse handler
	;we got here after user made a mouse pick to locate the text

	dumpstr str3

	call GetMousePnt
	;returns st0=MOUSEX, st1=MOUSEY (or yellowbox)

	;get address of text object we are creating
	mov esi,[object]

	;save x,y mouse to the link
	fstp qword [esi+80]  ;save st0->x and pop the fpu so y=st0
	fstp qword [esi+88]  ;save st0->y and pop the fpu


	;get the current text height scale and 
	;store it in the link
	;the actual measured height in tcad = TextHeightScale*9
	fld qword [TextHeightScale]
	fstp qword [esi+96]


	;1 endpoint defined, text only has 1 point
	mov dword [esi+12],1

	;set feedback message and LeftMouse handler
	mov eax,0   ;feedback message
	mov ebx,0   ;left mouse handler

	;text will be drawn by txtpaint
	ret





;*****************************************************************
;txtpaint

;draw text using HERSHEYROMANSMALL

;input:
;     all this is pushed on the stack in main.s
;	push address zoom      [ebp+32]
;	push address xorg      [ebp+28]
;	push address yorg      [ebp+24]
;	push dword [mousex]    [ebp+20]
;	push dword [mousey]    [ebp+16]
;	push address MOUSEXF   [ebp+12]
;	push addresss MOUSEYF  [ebp+8]
;     esi=address of object to paint

;return:
;all object->paint routines  must return the following:
	;eax = dword flag to indicate if mouse is over/near this object
	;      0 mouse is not over/near this object
	;      1 mouse is over an object "point"
	;      2 mouse is "near" the object
	;ebx = X screen coordinates of YellowBox point
	;ecx = Y screen coordinates of YellowBox point
	;edx = address of YellowBox point (floating point coordinates)
;*****************************************************************

txtpaint:

	push ebp
	mov ebp,esp
	sub esp,8  ;local data
	;[ebp-4]   ;address of text object link address
	;[ebp-8]   ;object color

	mov [ebp-4],esi  ;save for later

	;dumpstr str4



	;have we made the mouse pick yet ?  
	;if not nothing to draw
	cmp dword [esi+12],1
	jnz .done
	

	;get the object layer color
	mov ecx,[esi+4]  ;layer index
	call GetLayItems
	;this function returns:
	;eax=layer name
	;ebx=visibility
	;ecx=color
	;edx=linetype
	;edi=dword [currentlayer]
	;esi=preserved
	mov [ebp-8],ecx  ;save the color




	;convert text floating point coordinates to screen coordinates
	lea esi,[esi+80]
	mov edi,MouseScreenXY
	call float2int   
	;x,y screen coordinates written to MouseScreenXY
	


	;load the text height scale factor into st0
	;and multiply it by the zoom factor
	mov esi,[ebp-4]     ;esi=address of object
	fld qword [esi+96]  ;st0=TextHeightScale factor
	mov eax,[ebp+32]    ;eax=address of zoom
	fld qword [eax]     ;st0=zoom, st1=TextHeightScale
	fmulp st1           ;st0=zoom * TextHeightScale


	;draw the text
	mov eax,48                ;putsHershey
	mov ebx,[MouseScreenXY]
	mov ecx,[MouseScreenXY+4]
	lea edx,[esi+120]         ;address of ascii string
	mov esi,[ebp-8]           ;color
	mov edi,2                 ;font=HERSHEYROMANSMALL
	sysenter

	ffree st0        ;free st0




.done:

	;the object->paint must return the following:
	;eax = dword flag to indicate if mouse is over/near this object
	;      0 mouse is not over/near this object
	;      1 mouse is over an object "point"
	;      2 mouse is "near" the object
	;ebx = X screen coordinates of YellowBox point
	;ecx = Y screen coordinates of YellowBox point
	;edx = address of YellowBox point (floating point coordinates)

	mov eax,0  ;mouse not near this object
	mov ebx,0
	mov ecx,0
	mov edx,0

	mov esp,ebp
	pop ebp
	retn 28







txtselect:
;esi = address of SEGMENT object to check
;push address of printf buffer [ebp+20]
;push address qword MOUSEYF    [ebp+16]
;push address qword MOUSEXF    [ebp+12]
;push address qword zoom       [ebp+8]

;return:
;eax = 1 have selection or 0 no selection

	dumpstr str5

	mov eax,0  ;no selection
	retn 16







txtdelete:
	ret
txtcopy:
	ret
txtmove:
	ret
txtmirror:
	ret
txtmodify:
	ret
txtwrite:
	ret
txtread:
	ret

txtscale:
	ret
txtdump:
	ret
txtselectdrag:
	ret



;a function that does nothing
objectstub:
	ret




           