
;Project: TCAD
;txt14  Feb 04, 2016


;this file contains code and data for TCD_TEXT


;the 256 byte text link stores unique properties as follows:

;offset-size-description
;80   qword  x center of first glyph of string (floating point value)
;88   qword  y center of first glyph of string (floating point value)
;96   qword  TextHeightScale factor
;104  dword  x1 bounding box screen coordinates
;108  dword  y1 bounding box screen coordinates
;112  dword  x2 bounding box screen coordinates
;116  dword  y2 bounding box screen coordinates

;120->200    ascii text string
;            max 80 bytes including 0 terminator
;            displayed using HERSHEYROMANSMALL font

;starting offset 208 we include the 28 byte HERSHEYSTRUC
;for painting a hershey font string
;see tlib/putHershey.s for details

;208  dword  output device type: 0=graphics monitor, else
;     dword  address of pdf buffer
;212  dword  XC center of first glyph of string  (screen coordinate)
;216  dword  YC center of all glyphs of string   (screen coordinate)
;220  dword  address of ascii string 0 terminated
;224  dword  color
;228  dword  font type (2=HERSHEYROMANSMALL)
;232  dword  linetype





;TextHeightScale factor
;************************
;text height is not input directly, but you enter a scale factor
;the text height is determined as follows:
;each HERSHEYROMANSMALL glyph is 9 pixels/units tall
;they go from y=-5 to y=4 in the glyph coordinate system
;which is centered in the middle of the glyph
;if you set the Text Height Scale factor to 0.100
;then on the screen the text height will measure in TCAD as
;0.100 times 9 = 0.9
;i.e. Text height float = 9 x TextHeightScale, float
;the text height on the screen in pixels is =
;                         9 x zoom x TextHeightScale, pixels
;the zoom factor affects how the text appears on the screen
;but it does not affect how the text height is measured
;a scale factor of .01->.33 gives the following text heights:
;text height   .1   .25   .5    .75   1.0   1.5   2.0  3.0
;scale factor  .011 .028  .056  .083  .11   .167  .22  .33


;the text is not clipped to the screen. Instead we take advantage of 
;the fact that the hershey glyph is made up of multiple small 
;line segemnts and the tlib line() function employs trivial 
;reject if an endpoint falls off the screen then that segment 
;is just not drawn



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
;txt2pdf

;txtmodify      (public)
;txtmodifyxy
;txtmodifyheight
;txtmodifystring
;txtmodifylayer






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

;symbols defined in io.s
extern PDFpencolor






;**********************
;   EQUates
;**********************

equ TCD_TEXT 4
equ HERSHEYROMANSMALL 2




;******************
;    DATA
;******************


 
;dwords
;********
object:
dd 0
temp:
dd 0
pdfcurrentlayer:
dd 0


;qwords
;**********
TextHeightScale:
dq .05
ZoomTimesTextHeightScale:
dq 0.0
four:
dq 4.0
five:
dq 5.0
zero:
dq 0.0


;arrays
;*********
MouseScreenXY:
db0 8

compromptbuf:
db0 100

Point1:
db0 16

TextModifyProcTable:
dd txtmodifyxy, txtmodifyheight, txtmodifystring, txtmodifylayer





;Text Properties
;************************
;this data is needed by a call to printf in txtselect
;to display text properties when you select some text
;this string is displayed at top of the screen:
;x=xxx y=xxx height=xxx lay=xxx

equ TXTPROPQTYARGS 8

txtstr1:
db 'x=',0
txtstr2:
db '  y=',0
txtstr3:
db '  height=',0
txtstr4:
db '  lay=',0

txt_x:
dq 0.0
txt_y:
dq 0.0
txt_height:
dq 0.0
txt_layer:
dd 0

txtargtype:  ;2=dword, 3=0term ascii string, 4=qword float
dd 3,4,3,4,3,4,3,2

txtarglist:
dd txtstr1, txt_x, txtstr2, txt_y
dd txtstr3, txt_height, txtstr4, txt_layer





;strings
;**********
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
str6:
db '[txtselect] no selection',0
str7:
db 'Enter TextHeightScale factor as float (default=.05)',0
str8:
db 'txtselectdrag',0
str9:
db '[txtselectdrag] have selection',0
str10:
db '[txtselectdrag] no selection',0
str11:
db 'txtmodifyxy',0
str12:
db 'txtmodifyheight',0
str13:
db 'txtmodifystring',0
str14:
db 'txtmodify',0
str15:
db '[txtmodifystring] Enter text string max 80 chars',0
str16:
db 'txtcopy',0
str17:
db 'txtread',0
str18:
db 'txtwrite',0
str19:
db 'txt2pdf',0
str20:
db '[txt2pdf] start address pdf graphic stream',0
str21:
db '[txt2pdf] end address pdf graphic stream',0
str22:
db '[txt2pdf] edi starting',0
str23:
db '[txt2pdf] edi ending',0




;for debugging where we are in the code sometimes
flag1:
db 'flag1',0
flag2:
db 'flag2',0
flag3:
db 'flag3',0
flag4:
db 'flag4',0





;******************
;    PROCEDURES
;******************





;********************************************
;txtcreate

;create a new link in the list for text

;user is prompted to:
;  * enter text string
;  * Lclick to place text

;text is drawn with HERSHEYROMANSMALL in the 
;current layer

;text height is set from a seperate menu pick

;input: push dword [currentlayer]     [ebp+8]

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
	mov ecx,[ebp+8]  ;current layer
	call GetLayItems
	;this function returns:
	;eax=layer name
	; bl=visibility
	; cl=color
	;edx=linetype
	;edi=dword [currentlayer]
	;esi=preserved


	;initialize values for the object
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
	mov dword [esi+68],txt2pdf

	;init values for the HERSHEYSTRUC 
	mov dword [esi+208],0           ;output type=graphics monitor
	lea eax,[esi+120]               ;eax=address of string
	mov dword [esi+220],eax         ;address of string
	mov dword [esi+224],ecx         ;color
	mov dword [esi+228],HERSHEYROMANSMALL  ;font type
	

	;and zero out the x,y floating point coordinates
	fldz
	fst  qword [esi+80]
	fstp qword [esi+88]


	;save the object link address for the other segmentcreate procs
	mov [object],esi


	;get text string from user
	;comprompt can only collect up to 80 chars
	;and we have reserved 80 bytes in the link
	mov eax,54         ;comprompt
	mov ebx,str2       ;address prompt string
	lea ecx,[esi+120]  ;address destination buffer
	sysenter
	;jnz .error   ;user hit ESC


	;prompt user to make a mouse pick to place the text
	mov eax,89
	mov ebx,txtcreate_11

	pop ebp
	retn 4



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
;     esi=address of text object to paint

;return:
;all object->paint routines must return the following:
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

	mov [ebp-4],esi  ;save address of link for later

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
	lea edi,[esi+212]
	lea esi,[esi+80]   ;esi is corrupted
	call float2int   
	;x,y screen coordinates written to offset 212,216 in
	;the text object link

	

	;compute st0 = (zoom * TextHeightScale factor)
	mov esi,[ebp-4]     ;restore esi=address of object
	fld qword [esi+96]  ;st0=TextHeightScale factor
	mov eax,[ebp+32]    ;eax=address of zoom
	fld qword [eax]     ;st0=zoom, st1=TextHeightScale
	fmulp st1           ;st0=zoom * TextHeightScale
	fst qword [ZoomTimesTextHeightScale]  ;save for later



	;determine the linetype to use for this paint cycle.
	;linetype must be written back to the link for putshershey

	;assign solid linetype
	mov dword [esi+232],0xffffffff

	;is the object selected ?
	cmp dword [esi+8],1  
	jnz .drawtxt

	;over-ride the linetype with dotline type for selected
	mov dword [esi+232],0xc2108420



.drawtxt:

	;draw the text
	;st0=zoom * TextHeightScale
	mov eax,48         ;putshershey
	lea edi,[esi+208]  ;address of HERSHEYSTRUC
	sysenter
	ffree st0          ;free scale factor
	;returns eax=xloc of last glyph drawn





	;save coordinates of bounding box for txtselect
	;at offsets 104, 108, 112, 116 in the link
	;these are pixel coordinates

	;save xmin and xmax (they are already known)
	mov esi,[ebp-4]         ;esi=address of object
	mov [esi+112],eax       ;xmax
	mov eax,[esi+212]
	mov [esi+104],eax       ;xmin

	;ytop = [YC] + [5 * zoom * TextHeightScale]
	fld  qword [five] 
	fmul qword [ZoomTimesTextHeightScale]
	fiadd dword [esi+216]  ; YC
	fistp dword [esi+108]  ;save ytop to link
	
	;ybot = [YC] - [4 * zoom * TextHeightScale]
	fld  qword [four]
	fmul qword [ZoomTimesTextHeightScale]
	fchs
	fiadd dword [esi+216]  ;YC
	fistp dword [esi+116]  ;save ybot to link




	;if you want to see the bounding box around txt
	;then comment out this jmp
	jmp .done


	;for debug draw the bounding box around the text

	;left border
	push ebp
	mov eax,[ebp-4]           ;address of text link
	mov ebx,0xffffffff        ;linetype
	mov ecx,[eax+104]         ;x1
	mov edx,[eax+108]         ;y1
	mov esi,[eax+104]         ;x2
	mov edi,[eax+116]         ;y2
	mov ebp,RED               ;color
	mov eax,30                ;line
	sysenter
	pop ebp

	;across the top
	push ebp
	mov eax,[ebp-4]           ;address of text link
	mov ebx,0xffffffff        ;linetype
	mov ecx,[eax+104]         ;x1
	mov edx,[eax+108]         ;y1
	mov esi,[eax+112]         ;x2
	mov edi,[eax+108]         ;y2
	mov ebp,YEL               ;color
	mov eax,30                ;line
	sysenter
	pop ebp

	;right border
	push ebp
	mov eax,[ebp-4]           ;address of text link
	mov ebx,0xffffffff        ;linetype
	mov ecx,[eax+112]         ;x1
	mov edx,[eax+108]         ;y1
	mov esi,[eax+112]         ;x2
	mov edi,[eax+116]         ;y2
	mov ebp,GRE               ;color
	mov eax,30                ;line
	sysenter
	pop ebp

	;across the bottom
	push ebp
	mov eax,[ebp-4]           ;address of text link
	mov ebx,0xffffffff        ;linetype
	mov ecx,[eax+104]         ;x1
	mov edx,[eax+116]         ;y1
	mov esi,[eax+112]         ;x2
	mov edi,[eax+116]         ;y2
	mov ebp,BLU               ;color
	mov eax,30                ;line
	sysenter
	pop ebp


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





;****************************************************
;txtselect

;select text via a Lclick inside the bounding box 

;the bounding box does not completely surround the text
;you can comment out a jmp statement in txtpaint
;to see what the bounding box looks like

;there can be problems if you have 2 text strings
;where bounding box of string1 is inside the bounding
;box of string2.  then must select by dragbox

;input:
;esi = address of SEGMENT object to check
;push address of printf buffer [ebp+20]
;push address qword MOUSEYF    [ebp+16]
;push address qword MOUSEXF    [ebp+12]
;push address qword zoom       [ebp+8]

;return:
;eax = 1 have selection or 0 no selection
;*****************************************************

txtselect:

	push ebp
	mov ebp,esp
	sub esp,4   ;stack locals
	;[ebp-4]    ;saved address of object link

	dumpstr str5

	;save address of SEGMENT object for later
	mov [ebp-4],esi 


	;get mouse xy in screen coordinates
	mov eax,64 ;getmousexy
	sysenter
	;returns eax=mousex, ebx=mousey, esi,edi also



	;test if mouse is within the bounding box of the line segment
	;the order of register assignment is so as not to trash 
	;eax,ebx mouse coordinates
	mov ecx,eax        ;mousex
	mov edx,ebx        ;mousey
	mov esi,[ebp-4]    ;address object link
	lea ebx,[esi+104]  ;address x1,y1,x2,y2 inflated clipped bounding box
	mov eax,86         ;tlib function ptinrect
	sysenter
	jnz .nopick        ;mouse is not within bounding box

	
	

	;now toggle the line selection state to 1,0,1,0...
	;this allows repeated left mouse clicks to change
	;the linetype from normal->selected->normal...
	mov esi,[ebp-4]
	mov eax,[esi+8]
	not eax          ;flip all bits
	and eax,1        ;mask off all but bit0
	mov [esi+8],eax  ;save selection state




	;now use printf to build a string
	;to display TEXT PROPERTIES
	;this is displayed as a feedback message
	;when you Lclick on text
	fld  qword [esi+80] ;x
	fstp qword [txt_x]
	fld  qword [esi+88] ;y
	fstp qword [txt_y]
	fld  qword [esi+96]  ;TextHeightScale
	fstp qword [txt_height]
	mov eax,[esi+4]      ;layer
	mov [txt_layer],eax
	

	;call printf to build the text properties string
	;the string looks like this:
	;x=xxx y=xxx height=xxx lay=xxx
	;the string is stored in an 80 byte buffer in main.s
	mov eax,57         ;printf
	mov ebx,txtargtype
	mov ecx,TXTPROPQTYARGS
	mov esi,txtarglist
	mov edi,[ebp+20]   ;address printf buffer
	sysenter


	;we have a mouse pick inside the text bounding box
	mov eax,1  ;selection = YES
	jmp .done


.nopick:
	dumpstr str6
	mov eax,0   ;selection = NO

.done:
	mov esp,ebp  ;deallocate locals
	pop ebp
	retn 16






;*********************************************
;txtselectdrag

;this procedure is called from main.s
;when a user makes a drag box

;we use x1,y1,x2,y2 of the text bounding box
;if both points are inside the drag box
;then we mark the text as selected

;note the drag box upper left should be picked first
;then the lower right
;so that x2>x1 and y2>y1 in screen coordinates

;input:
;esi=address of text object in link list
;edi=address of dragbox x1,y1,x2,y2 16 bytes

;return:none
;**********************************************

txtselectdrag:

	dumpstr str8


	;is x1,y1 inside bounding box ?
	;********************************
	mov eax,86          ;tlib ptinrect
	mov ebx,edi         ;address of dragbox coordinates
	mov ecx,[esi+104]   ;object x1 screen coordinate
	mov edx,[esi+108]   ;object y1 screen coordinate
	sysenter
	jnz .outsideBox


	;is  x2,y2 inside bounding box ?
	;*******************************
	mov eax,86          ;tlib ptinrect
	mov ebx,edi         ;address of dragbox coordinates
	mov ecx,[esi+112]   ;object x2 screen coordinate
	mov edx,[esi+116]   ;object y2 screen coordinate
	sysenter
	jnz .outsideBox


	;if we got here both endpoints are inside the dragbox

	dumpstr str9

	;mark the object as selected
	mov dword [esi+8],1
	jmp .done

.outsideBox:
	dumpstr str10
.done:
	ret





;***********************************************************
;txtmodfify
;Text Modify

;input:
;eax = index into TextModifyProcTable
;esi = dword [headlink]
;esi = dword [currentlayer]

;return: all text modify procs should return:
;        eax = feedback message index
;        ebx = Left Mouse handler
;************************************************************

public txtmodify

	;cant dumpstr here tom, it would trash eax

	;we got here after user picked a menu item
	;from the Text Modify Popup menu

	;eax = index into SegmentModifyProcTable
	;esi = dword [headlink] 
	;edi = dword [currentlayer]

	mov ebx,TextModifyProcTable[eax]
	call ebx

	;return values for all text modify procs:
	;eax = feedback message index
	;ebx = Left Mouse handler
	ret



txtmodifyxy:

	dumpstr str11

	;save address of selected object
	mov eax,TCD_TEXT
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	cmp eax,0
	jz .done

	mov dword [object],ebx ;save address of object

	;prompt user to pick new location for text
	mov eax,90   ;feedback message index
	
	;and set new left mouse handler
	mov ebx,txtmodifyxy_11

.done:
	ret



txtmodifyxy_11:

	;this is a left mouse handler
	;we got here after user picked new location for text

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save reference point
	mov esi,[object]
	fstp qword [esi+80]
	fstp qword [esi+88]

	mov eax,0  ;feedback message index
	mov ebx,0  ;left mouse handler

	ret



;******************************************************
;txtmodifyheight

;this procedure works similar to layer modify
;you should first set a new text height from
;the main menu then invoke this function with Rclick

;input:none
;return:none
;******************************************************

txtmodifyheight:

	dumpstr str12

	;save address of selected object
	mov eax,TCD_TEXT
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	cmp eax,0
	jz .done


	;save the current TextHeightScale factor 
	;to offset 96 in the link
	fld qword [TextHeightScale]
	fstp qword [ebx+96]  ;ebx=address of link

.done:
	mov eax,0  ;feedback message index
	mov ebx,0  ;left mouse handler
	ret






txtmodifystring:

	;throw up a gets edit box so user can modify the string

	dumpstr str13


	;get address of selected object
	mov eax,TCD_TEXT
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	cmp eax,0
	jz .done


	mov [object],ebx  ;save for later


	;compute x,y in screen coordinates for gets edit control
	lea esi,[ebx+80]
	mov edi,MouseScreenXY
	call float2int   
	;x,y screen coordinates written to MouseScreenXY
	


	;throw up an gets edit control overtop the string to edit
	;start edit control at x=10 so its not drawn off screen
	;we allow max 75 chars (link buffer is 80 chars include 0 term)
	;we store string in a temp buffer
	mov eax,104                ;gets
	mov ebx,10                 ;x
	mov esi,[MouseScreenXY+4]  ;y 
	mov ecx,75                 ;max num chars
	mov edi,compromptbuf       ;address of buffer to store string
	mov edx,0xfbfeef           ;colors ccbbtt
	sysenter

	;in case user changed mind and doesnt want to save
	jnz .done                  ;user hit ESC


	;copy string to the object link at offset 120
	mov eax,20    ;strcpy2 also copies 0 term
	mov ebx,compromptbuf
	mov ecx,[object]
	add ecx,120   ;offset 120 in link
	sysenter
	

.done:
	mov eax,0  ;feedback message index
	mov ebx,0  ;left mouse handler
	ret



;**************************************
;txtmodifylayer

;modifys the text object layer and color

;input: Rclick for popup and select "layer"
;return
;***************************************

txtmodifylayer:


	;get address of selected object
	mov eax,TCD_TEXT
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	;do we have only 1 text object selected ?
	cmp eax,1
	jnz .done

	
	;save address of selected text object
	push ebx


	;get the current layer
	mov ecx,0  ;dumy
	call GetLayItems
	;this function returns:
	;eax=layer name
	; bl=visibility
	; cl=color
	;edx=linetype
	;edi=dword [currentlayer]   this is what we want
	;esi=preserved


	;now get the current layer color
	mov ecx,edi  ;edi=current layer
	call GetLayItems
	

	pop esi              ;esi=address of selected text object
	mov [esi+4],edi      ;change layer number
	mov [esi+224],ecx    ;change color

.done:
	mov eax,0
	mov ebx,0
	ret









txtdelete:
	;some objects may have pointers to allocated memory
	;that must be freed
	;TCD_TEXT does not use this function
	ret




;***************************************************
;txtcopy

;function to create a child text string
;that is offset from the parent string

;X = X + [DeltaX]
;Y = Y + [DeltaY]

;this function is called by "CopyObjects" in main.s

;input: 
;esi=address of object to copy
;push address of qword DeltaX      [ebp+12]
;push address of qword DeltaY      [ebp+8]

;return:
;esi=address of new TCD_TEXT object
;****************************************************


txtcopy:

	push ebp
	mov ebp,esp
	sub esp,4   ;space on stack for 1 local variable

	mov [ebp-4],esi  ;save address of object to copy

	dumpstr str16


	call CreateBLink
	;test return value, esi holds address of link


	;initialize values for the object
	mov dword [esi],TCD_TEXT
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],1   ;qty points
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
	mov dword [esi+68],txt2pdf

	;copy the layer index offset 4
	mov eax,[ebp-4]  ;eax=address of object to copy
	mov ebx,[eax+4]  ;retrieve the layer
	mov [esi+4],ebx  ;and copy into new object

	;copy the x,y location offset 80,88
	fld  qword [eax+80] ;get x
	mov ebx,[ebp+12]    ;get address of DeltaX
	fadd qword [ebx]    ;add DeltaX
	fstp qword [esi+80] ;save x
	fld  qword [eax+88] ;get y
	mov ebx,[ebp+8]     ;get address of DeltaY
	fadd qword [ebx]    ;add DeltaY
	fstp qword [esi+88] ;save y

	;copy the qword TextHeightScale factor offset 96
	fld  qword [eax+96] ;get TextHeightScale
	fstp qword [esi+96] ;save it

	;copy the string offset 120
	lea ebx,[eax+120]  ;ebx=address source string
	lea ecx,[esi+120]  ;ecx=address dest string
	mov eax,20         ;strcpy2 also copies 0 term
	sysenter
	
	mov esp,ebp  ;deallocate locals
	pop ebp
	;returns esi=address of new text object
	retn 8       ;cleanup 2 args






;****************************************************
;txtmove

;see notes for txtcopy
;all we do is redefine object coordinates by 
;DeltaX and DeltaY

;this function is called by "MoveObjects" in main.s

;input: 
;eai=address of object to move 
;push address of qword DeltaX      [ebp+12]
;push address of qword DeltaY      [ebp+8]

;return:none
;****************************************************

txtmove:

	push ebp
	mov ebp,esp

	;dumpstr

	;esi is address of selected object to move

	mov eax,[ebp+12]  ;eax=address of qword DeltaX
	mov ebx,[ebp+8]   ;ebx=address of qword DeltaY

	;x=x+[DeltaX]
	fld  qword [esi+80]
	fadd qword [eax] 
	fstp qword [esi+80] 

	;y=y+[DeltaY]
	fld  qword [esi+88] 
	fadd qword [ebx]
	fstp qword [esi+88] 

	pop ebp
	retn 8  ;cleanup 2 args






;********************************************************
;txtmirror

;creates a child object whos x,y location is mirrored about
;a line segment

;the text string is drawn upright and the glyphs appear
;in the same order so the only thing that is really 
;mirrored is the starting location

;the mirror segment points are qwords x1,y1,x2,y2 (32 bytes)

;input:
;esi= address of parent text object to mirror
;push address of mirror segment points   [ebp+8]

;return:none
;********************************************************

txtmirror:

	push ebp
	mov ebp,esp
	push esi

	;dumpstr

	;edi=address of parent segment to mirror
	mov edi,esi


	;first make a copy of the parent with DeltaX=DeltaY=0.0
	;esi=address parent
	push zero     ;DeltaX=0.0
	push zero     ;DetlaY=0.0
	call txtcopy
	;returns esi=address of new child object

	
	;mirror point x,y
	mov eax,91         ;91=tlib function "mirrorpoint"
	mov ebx,[ebp+8]    ;address mirror line
	lea ecx,[esi+80]   ;address point to be mirrored
	mov edx,Point1     ;address mirrored point local storage
	sysenter


	;now save mirrored points back to new link
	fld  qword [Point1]   ;x
	fstp qword [esi+80] 
	fld  qword [Point1+8] ;y
	fstp qword [esi+88] 


	;return esi=address of object that was mirrored
	pop esi
	pop ebp
	retn 4






;**********************************************
;txtscale

;xc,yc is the reference point for scaling

;we scale the text location x,y and also 
;scale the text height as well

;input:
;esi=address of object to scale (must be preserved)
;push address of qword XC          [ebp+16]
;push address of qword YC          [ebp+12]
;push address of qword ScaleFactor [ebp+8]

;return:none
;**********************************************

txtscale:

	push ebp
	mov ebp,esp

	;preserve eax,ebx,ecx
	mov eax,[ebp+16]  ;eax=address of XC
	mov ebx,[ebp+12]  ;ebx=address of YC
	mov ecx,[ebp+8]   ;ecx=address of ScaleFactor

	;the general formula for scaling an endpoint coordinate is:
	;x(i) = [x(i)-xc]*ScaleFactor + xc

	;scale x
	fld  qword [esi+80]   ;x1
	fst st1               ;st0=st1=x1
	fsub qword [eax]      ;x1-xc
	fmul qword [ecx]      ;(x1-xc)*ScaleFactor
	fadd qword [eax]      ;(x1-xc)*ScaleFactor + xc
	fstp qword [esi+80]   ;store it
	ffree st0

	;scale y
	fld  qword [esi+88] 
	fst st1               ;st0=st1=y1
	fsub qword [ebx]      ;y1-yc
	fmul qword [ecx]      ;(y1-yc)*ScaleFactor
	fadd qword [ebx]      ;(y1-yc)*ScaleFactor + yc
	fstp qword [esi+88] 
	ffree st0

	;scale the TextHeightScale factor
	fld  qword [esi+96]    ;st0=TextHeightScale factor
	fmul qword [ecx]       ;st0=TextHeightScale * ScaleFactor
	fstp qword [esi+96]


	;must return esi=address of object scaled
	pop ebp
	retn 12








;********************************************************
;txtwrite  version=01  qtybytes=160

;this procedure is called when writting a tcd file
;the total qty bytes written must be an even multiple of 16
;pad with zeros if necessary. this is so each object in the 
;file starts on a 16 byte boundry and so is easy to read
;with xxd

;input:
;edi= destination memory address where tcd file is built
;esi= address of text object link

;return:
;eax=qty bytes written
;esi= address of text object link (same as input)
;*********************************************************

txtwrite:

	push ebp
	mov ebp,esp
	sub esp,4

	mov [ebp-4],esi  ;save copy of object address

	dumpstr str18    ;txtwrite


	;dword object type   (tcd offset 0)
	mov [edi], dword TCD_TEXT
	add edi,4  ;inc the destination address


	;an 8 byte ascii string representing the name of the object
	;ascii bytes 'TEXT    ' 
	mov byte [edi],  0x54   ;T
	mov byte [edi+1],0x45   ;E
	mov byte [edi+2],0x58   ;X
	mov byte [edi+3],0x54   ;T
	mov byte [edi+4],0x20   ;
	mov byte [edi+5],0x20   ;
	mov byte [edi+6],0x20   ;
	mov byte [edi+7],0x20   ;
	add edi,8
	

	;dword layer  (tcd offset 12)
	mov eax,[esi+4]  ;get the layer
	mov [edi], eax
	add edi,4

	;dword qty points (tcd offset 16)
	mov dword [edi], 1
	add edi,4


	;qword x  (tcd offset 20)
	fld qword [esi+80]  ;get x
	fstp qword [edi]    ;write it and pop to cleanup fpu
	add edi,8

	;qword y  (tcd offset 28)
	fld qword [esi+88]
	fstp qword [edi]
	add edi,8

	;qword TextHeightScale (tcd offset 36)
	fld qword [esi+96]
	fstp qword [edi]
	add edi,8


	;get length of string
	mov eax,118        ;strlenB
	lea ebx,[esi+120]  ;address of string
	sysenter
	;returns eax=length of string


	;dword length of the string (tcd offset 44)
	mov [edi],eax
	add edi,4
	push eax  ;save strlen for later


	;write the string  (tcd offset 48)
	;the string can be up to 80 bytes long
	;note the 0 terminator is not included
	lea esi,[esi+120]
	;edi is already set
	mov ecx,eax   ;strlen
	repmovsb      ;byte [esi]->[edi], esi++, edi++
	;edi destination pointer has been incremented by repmovsb


	;determine qty padding spaces
	;the string may be 80 bytes
	;qty spaces to write = 80-strlen
	pop ebx      ;retrieve strlen
	mov ecx,80
	sub ecx,ebx  ;ecx=qty padding spaces
	jz .1        ;skip padding bytes if string is already 80 chars


	;write the padding bytes
	mov al,1     ;write number 1 byte
	;edi and ecx is set
	repstosb     ;al->[edi], edi++
	;edi destination pointer has been incremented by repstosb




.1:
	;now write the HERSHEYSTRUC
	mov esi,[ebp-4]  ;address of object

	;dword output device type 
	;tcd offset 128
	;TCD_TEXT link offset 208
	mov eax,[esi+208]
	mov [edi],eax
	add edi,4

	;dword XC 
	;tcd offset 132
	;TCD_TEXT link offset 212
	mov eax,[esi+212]
	mov [edi],eax
	add edi,4

	;dword YC
	;tcd offset 136
	;TCD_TEXT link offset 216
	mov eax,[esi+216]
	mov [edi],eax
	add edi,4

	;dword address of string
	;tcd offset 140
	;TCD_TEXT link offset 220
	mov eax,[esi+220]
	mov [edi],eax
	add edi,4

	;dword color
	;tcd offset 144
	;TCD_TEXT link offset 224
	mov eax,[esi+224]
	mov [edi],eax
	add edi,4
	
	;dword font type
	;tcd offset 148
	;TCD_TEXT link offset 228
	mov eax,[esi+228]
	mov [edi],eax
	add edi,4

	;dword linetype
	;tcd offset 152
	;TCD_TEXT link offset 232
	mov eax,[esi+232]
	mov [edi],eax
	add edi,4


	;write a 0 to set edi at 160  (tcd offset 156)
	mov dword [edi],0
	add edi,4


	
	mov eax,160      ;return qty bytes written
	mov esi,[ebp-4]  ;return address of object
	;and edi is incremented by qty bytes written


	mov esp,ebp  ;deallocate locals
	pop ebp
	ret






;*************************************************************
;txtread  version=01

;this procedure is called when reading a tcd file
;with object type == TCD_TEXT

;input:
;esi=address of text object data to read in tcd file

;return: 
;esi=incremented to start of next object

;make sure all the reads here match the writes in txtwrite

;implementation of a new object->read function 
;requires that you edit io.s 
;to make this function available (extern !)
;**************************************************************

public txtread

	push ebp
	mov ebp,esp
	sub esp,8
	;[ebp-4]  save esi
	;[ebp-8]  save edi

	pushad

	;at this point esi does not point to the start of the tcd file
	;esi should point to the start of a new TCD_TEXT object data
	;in the tcd file
	;when we are done esi should be set to point to the start of the
	;next object in the tcd file

	dumpstr str17  ;txtread


	;save start of TCD_TEXT object in tcd file
	mov [ebp-4],esi   ;read from


	;create a new blank link
	call CreateBLink
	;returns esi=address of object link


	 ;edi=new blank link
	mov edi,esi 


	;save address of link
	mov [ebp-8],edi  ;write to



	;make sure we have the correct version ?? (later)


	;so in this procedure:
	;esi=address to read  TCD_TEXT object data in tcd file
	;edi=address to write TCD_TEXT object data to link list




	;object type
	;FileOpenTCD already read the first byte to make sure
	;it was a TCD_TEXT
	mov esi,[ebp-4]        ;esi=address of TCD_TEXT object in tcd file
	mov eax,[esi]          ;eax should = TCD_TEXT = 4
	mov [edi],eax          ;write object type to link


	;layer
	mov eax,[esi+12]        ;read layer
	mov [edi+4],eax         ;write layer to link


	;object visibility state
	;this info is not stored in the tcd file
	;so we just set to 0 unselected
	mov dword [edi+8],0  


	;qty points 
	;may want to check the value should = 1
	mov eax,[esi+16]   
	mov [edi+12],eax


	;dat pointer 
	mov dword [edi+16],0  ;just write it


	;various procedure names
	mov dword [edi+20],txtpaint
	mov dword [edi+24],txtdelete
	mov dword [edi+28],txtcopy
	mov dword [edi+32],txtmove
	mov dword [edi+36],txtmirror
	mov dword [edi+40],txtmodify
	mov dword [edi+44],txtwrite
	mov dword [edi+48],txtread
	mov dword [edi+52],txtselect
	mov dword [edi+56],txtscale
	mov dword [edi+60],txtdump
	mov dword [edi+64],txtselectdrag
	mov dword [edi+68],txt2pdf

	;x
	fld  qword [esi+20]
	fstp qword [edi+80]

	;y
	fld  qword [esi+28]
	fstp qword [edi+88]

	;TextHeightScale factor
	fld  qword [esi+36]
	fstp qword [edi+96]
	

	;read the strlen ( offset 44 in the tcd file)
	;the strlen is not stored in the link
	mov ecx,[esi+44]




	;copy the string from offset 48 in the file 
	;to offset 120 in the link

	cld
	;ecx strlen is set above
	add esi,48         ;esi points to start of string in tcd file
	add edi,120        ;edi points to start of string in link
	repmovsb           ;byte [esi]->[edi], esi++, edi++
	;edi is incremented by the amount of string length


	;and 0 terminate
	mov byte [edi],0





	;now read the HERSHEYSTRUC
	mov esi,[ebp-4]
	mov edi,[ebp-8]

	
	;dword output device type  
	;tcd offset 128
	;TCD_TEXT link offset 208
	mov eax,[esi+128]
	mov [edi+208],eax


	;dword XC  
	;tcd offset 132
	;TCD_TEXT link offset 212
	mov eax,[esi+132]
	mov [edi+212],eax


	;dword YC  
	;tcd offset 136
	;TCD_TEXT link offset 216
	mov eax,[esi+136]
	mov [edi+216],eax


	;dword address of string  
	;tcd offset 140
	;TCD_TEXT link offset 220
	mov eax,[esi+140]
	mov [edi+220],eax


	;dword color  
	;tcd offset 144
	;TCD_TEXT link offset 224
	mov eax,[esi+144]
	mov [edi+224],eax


	;dword font type  
	;tcd offset 148
	;TCD_TEXT link offset 228
	mov eax,[esi+148]
	mov [edi+228],eax


	;dword linetype  
	;tcd offset 152
	;TCD_TEXT link offset 232
	mov eax,[esi+152]
	mov [edi+232],eax




.done:
	popad  ;this restores the original esi
	;esi holds address of start of next object in tcd file

	;esi must point to start of next object in tcd file
	;our text object takes up 160 bytes in the tcd file
	add esi,160

	mov esp,ebp  ;deallocate locals
	pop ebp
	ret








;a function that does nothing
objectstub:
	ret






;************************************************
;txtdump
;dump the various fields of a text object link

;note the addresses of the various procedures are not dumped
;because they are not very interesting

;input: esi=address of link
;return: none

;locals



txstr0:
db 0xa
db 'TCD_TEXT',0
txtstra:
db 'address of txt object/link',0
txstr1:
db 'object type',0
txstr2:
db 'layer index',0
txstr3:
db 'visibility state',0
txstr4:
db 'qty points',0

txstr13:
db 'previous link',0
txstr14:
db 'next link',0

txtstr15a:
db 'x=',0
txtstr15b:
db 'y=',0
txtstr15c:
db 'TextHeightScalefactor=',0

txstr18a:
db 'x1 bounding box screen coord',0
txstr18b:
db 'y1 bounding box screen coord',0
txstr18c:
db 'x2 bounding box screen coord',0
txstr18d:
db 'y2 bounding box screen coord',0

txtstr19a:
db 'output type',0
txtstr19b:
db 'XC screen coordinate',0
txtstr19c:
db 'YC screen coordinate',0
txtstr19d:
db 'address of string',0
txtstr19e:
db 'color',0
txtstr19f:
db 'font type',0
txtstr19g:
db 'linetype',0

;************************************************

txtdump:

	dumpstr txstr0

	mov ebx,esi
	dumpebx ebx,txtstra,0  ;address of txt object/link

	mov ebx,[esi]   ;obj type
	dumpebx ebx,txstr1,0

	mov ebx,[esi+4] ;layer index
	dumpebx ebx,txstr2,0

	mov ebx,[esi+8] ;selected state
	dumpebx ebx,txstr3,0

	mov ebx,[esi+12] ;qty points defined so far
	dumpebx ebx,txstr4,0



	;these proc addresses are not very interesting
	;and so are omitted from the dump for now


	mov ebx,[esi+72] ;previous link
	dumpebx ebx,txstr13,0

	mov ebx,[esi+76] ;next link
	dumpebx ebx,txstr14,0




	;X
	fld qword [esi+80]  ;x
	mov eax,36          ;dumpst0
	mov ebx,txtstr15a   ;x=
	sysenter
	ffree st0


	;Y
	fld qword [esi+88]  ;y
	mov eax,36          ;dumpst0
	mov ebx,txtstr15b   ;y=
	sysenter
	ffree st0


	;TextHeightScale
	fld qword [esi+96]
	mov eax,36          ;dumpst0
	mov ebx,txtstr15c   ;TextHeightScale
	sysenter
	ffree st0



	;bounding box x1,y1,x2,y2 in decimal screen coordinates
	mov ebx,[esi+104]
	dumpebx ebx,txstr18a,3 

	mov ebx,[esi+108]
	dumpebx ebx,txstr18b,3

	mov ebx,[esi+112]
	dumpebx ebx,txstr18c,3

	mov ebx,[esi+116]
	dumpebx ebx,txstr18d,3


	;dump the string as quoted
	mov eax,123        ;dumpstrquote
	lea ebx,[esi+120]  ;ebx=address of string
	sysenter


	;now the 28 byte HERSHEYSTRUC
	mov ebx,[esi+208]     ;output type
	dumpebx ebx,txtstr19a,0

	mov ebx,[esi+212]     ;XC screen coordinate
	dumpebx ebx,txtstr19b,0

	mov ebx,[esi+216]     ;YC screen coordinate
	dumpebx ebx,txtstr19c,0

	mov ebx,[esi+220]     ;address of string
	dumpebx ebx,txtstr19d,0

	mov ebx,[esi+224]     ;color
	dumpebx ebx,txtstr19e,0

	mov ebx,[esi+228]     ;font type
	dumpebx ebx,txtstr19f,0

	mov ebx,[esi+232]     ;linetype
	dumpebx ebx,txtstr19g,0

	ret






;**************************************************
;SetTxtHight
;Set Text Height

;this function is invoked from the Misc menu
;allows the user to input a value for the
;TextHeightScale factor

;input:none
;return: global qword [TextHeightScale] is stored

;**************************************************

public SetTxtHight

	pushad

	;prompt user to enter value
	mov eax,54            ;comprompt
	mov ebx,str7          ;prompt string
	mov ecx,compromptbuf  ;destination buffer
	sysenter

	mov eax,93            ;str2st0
	mov ebx,compromptbuf
	sysenter              ;st0=TextHeightScale

	fstp qword [TextHeightScale]

	;should clamp this scale value to the range .01-1.0
	;as stated above a value of .1 gives a text height of .9

	;so everytime you create text
	;you will get this size by default 
	;unless you change it first

	popad
	ret






;***************************************************************
;txt2pdf

;this is an object->writepdf procedure for TCD_TEXT
;writes a TCD_TEXT object to a pdf graphic stream

;input: edi = destination address of pdf graphic stream buffer
;       esi = address of segment object in link list

;return:
;       edi is incremented to the end of the pdf graphic stream
;       esi = address of segment object in link list
;***************************************************************

txt2pdf:

	push ebp
	mov ebp,esp
	sub esp,8  ;local variables
	;[ebp-4]    address of pdf graphic stream
	;[ebp-8]    address of object in link list


	;edi holds destination address for PDF graphic stream
	;throughout this proc edi must be preserved and incremented
	;with every byte written to the graphic stream buffer

	mov [ebp-4],edi  ;save destination address of pdf graphic stream
	mov [ebp-8],esi  ;save address of object for later



	dumpstr str19


	;dump the starting value of edi
	mov eax,9    ;dumpebx
	mov ebx,edi
	mov ecx,str22
	mov edx,0  ;0=reg32
	sysenter



	;set DeviceRGB space and pen color
	;looks like this: "r g b RG"
	;this code same as segmentpdf
	;************************************************

	
	mov ebx,[esi+4]
	;ebx=object layer index
	;the layer index must be from 0->9
	;since TCAD currently only supports 10 layers


	;is the new layer same as previous ?
	cmp ebx,[pdfcurrentlayer]
	jz .2  ;skip RG since we have the same layer

	;save new pdf layer
	mov [pdfcurrentlayer],ebx

	;compute address of RG string to write to pdf
	;mov esi,PDFpencolor[ecx]  this code wont work
	;PDFpencolor is an extern variable in io.s
	;cant use ttasm array syntax on an extern variable
	;so we do it the long way
	;PDFpencolor is an array of pencolor strings
	;there are 10 addresses in the table, 1 for each of the
	;10 basic tatOS palette colors and 1 for each layer in TCAD
	mov ecx,PDFpencolor
	mov eax,4
	xor edx,edx
	mul ebx       ;eax=4 * LayerIndex
	add ecx,eax   ;esi=PDFpencolor + 4*LayerIndex


	;now read the address from the PDFpencolor lookup table
	;this is the starting address of a string like 'r g b RG'
	;see io.s
	mov esi,[ecx]


	;write 'r g b RG',0xa  string
	mov eax,19       ;strcpy
	mov edi,[ebp-4]  ;dest pdf graphic stream
	sysenter
	;edi is incremented

	;done writting new pen color to pdf graphic stream

.2:


	;this was computed on the last paint cycle
	fld qword [ZoomTimesTextHeightScale] 


	;call putshershey to "draw" the text string to pdf buffer
	mov esi,[ebp-8]    ;esi=address of object
	mov [esi+208],edi  ;set output device = address of pdf buffer
	lea edi,[esi+208]  ;address of HERSHEYSTRUC
	mov eax,48         ;putshershey
	sysenter
	ffree st0          ;free ZoomTimesTextHeightScale 


	;this function overwrites the 1st dword of the HERSHEYSTRUC
	;with a new address for the next byte to be written to the
	;pdf graphic stream


	;return esi = address of object
	mov esi,[ebp-8]


	;return edi=address of next byte to be written to pdf graphic stream
	;the HersheyLineTo function will provide us this
	;lea eax,[esi+208] ;eax=address of output device
	;mov edi,[eax]
	mov edi,[esi+208]


	;dump the final value of edi
	mov eax,9    ;dumpebx
	mov ebx,edi
	mov ecx,str23
	mov edx,0  ;0=reg32
	sysenter
	;esi & edi should be preserved



	;reset text output device to graphics monitor in HERSHEYSTRUC
	mov dword [esi+208],0   ;set output device = graphics monitor


	;return values in esi and edi

	mov esp,ebp  ;deallocate locals
	pop ebp
	ret



;**************** THE END ***********************************


;mov eax,9    ;dumpebx
;mov ebx,edi  ;value to dump
;mov ecx,txtdebug1
;mov edx,0    ;0=reg32
;sysenter



 