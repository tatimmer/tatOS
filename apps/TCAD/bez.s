;Project: TCAD
;bez105  July 23, 2016

 
;this file contains code and data for TCD_BEZIER

;this object is a cubic bezier curve
;it is drawn using the tatOS/tlib/bezier function with 20 segments
;the object is defined by 4 points: 2 endpoints and 2 control points

;to create a new bezier you make 4 mouse clicks:
;Startpoint->Controlpoint1->Controlpoint2->Endpoint
;the bezier will not show up on the screen 
;until after the end point is defined

;the bezier paint routine does not use line clipping
;so if any part of the object falls off the screen the tlib line()
;will not draw it

;screen coordinates are computed & saved with every paint cycle
;they are used to draw the object, and used by bezselectdrag and bez2pdf


;slide mode allows the user to dynamically relocate an end point
;or control point. dword offset 180 takes on the value of 0xffffffff
;for no slide else the value of 0,1,2,3 where 0 indicates the start
;point is in slide mode and 3 indicates the end point is in slide mode
;and 1,2 are for the control points. User invokes slide mode by 
;selecting a bezier then Rclick popup menu.
;Exit slide mode with an Lclick to define the point location.

;markers are little square boxes to indicate the location of 
;endpoints and control points. the starting point x1y1 has a double box. 
;markers can be shown or hidden by selecting the object then 
;Rclick popup menu.




;the 256 object link stores unique properties as follows:

;offset-size-description
;80   qword  x1 start point
;88   qword  y1 start point
;96   qword  x2 control point 1
;104  qword  y2 control point 1
;112  qword  x3 control point 2
;120  qword  y3 control point 2
;128  qword  x4 end point
;136  qword  y4 end point
;144  dword  x1 screen coordinate
;148  dword  y1 screen coordinate
;152  dword  x2 screen coordinate
;156  dword  y2 screen coordinate
;160  dword  x3 screen coordinate
;164  dword  y3 screen coordinate
;168  dword  x4 screen coordinate
;172  dword  y4 screen coordinate
;176  dword  show/hide point markers
;180  dword  slide mode




;code labels in this file:

;bezcreate     (public)
;bezdelete
;bezmove
;bezcopy
;bezread       (public)
;bezwrite
;bezselect
;bezselectdrag
;bezpaint
;bezmirror
;bezscale
;bezdump
;bez2pdf

;bezmodify      (public)
;bezmodifyx1y1
;bezmodifyx2y2
;bezmodifyx3y3
;bezmodifyx4y4
;bezmodifylayer
;bezmodifymarkers






;bez.s to be placed in memory after aro.s
;see main.s for complete TCAD memory map
org 0x2040000




;assign a unique number to this source file
;main.s = 00
;seg.s  = 01
;io.s   = 02
;txt.s  = 03
;aro.s  = 04
;bez.s  = 05
source 5





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

equ TCD_BEZIER 7





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
zero:
dq 0.0


;if the mouse is within 5 pixels of an object endpoint
;we pass the address of this endpoint back to paint in main.s
;and a yellow box is drawn and we call this the "YellowBoxPoint"
YellowBoxPoint:
db0 16


;arrays
;*********
compromptbuf:
db0 100

Point1:
db0 16
Point2:
db0 16
Point3:
db0 16
Point4:
db0 16


;we have 6 modify procs for TCD_BEZIER
;the popup for this is defined in main.s
;popup is invoked on Rclick after selecting a TCD_BEZIER
BezModifyProcTable:
dd bezmodifyx1y1, bezmodifyx2y2, bezmodifyx3y3, bezmodifyx4y4
dd bezmodifylayer, bezmodifymarkers




;*******************************
;TCD_BEZIER Selection Properties
;*******************************

;this data is needed by a call to printf in bezselect
;to display object properties when you select a bezier
;this string is displayed at top of the screen:

;aro: x1=xxx y1=xxx x2=xxx y2=xxx x3=xxx y3=xxx x4=xxx y4=xxx lay=xxx

;number must match argtype and arglist = 1+9+9
equ BEZPRINTFQTYARGS 19

bezstr0:
db 'bez',0x3a,0

bezstr1:
db '  x1=',0
bezstr2:
db '  y1=',0
bezstr3:
db '  x2=',0
bezstr4:
db '  y2=',0
bezstr5:
db '  x3=',0
bezstr6:
db '  y3=',0
bezstr7:
db '  x4=',0
bezstr8:
db '  y4=',0
bezstr9:
db '  lay=',0

bez_x1:
dq 0.0
bez_y1:
dq 0.0
bez_x2:
dq 0.0
bez_y2:
dq 0.0
bez_x3:
dq 0.0
bez_y3:
dq 0.0
bez_x4:
dq 0.0
bez_y4:
dq 0.0
bez_layer:
dd 0

bezargtype:  ;2=dword, 3=0term ascii string, 4=qword float
dd 3,3,4,3,4,3,4,3,4,3,4,3,4,3,4,3,4,3,2

bezarglist:
dd bezstr0
dd bezstr1, bez_x1
dd bezstr2, bez_y1
dd bezstr3, bez_x2
dd bezstr4, bez_y2
dd bezstr5, bez_x3
dd bezstr6, bez_y3
dd bezstr7, bez_x4
dd bezstr8, bez_y4
dd bezstr9, bez_layer





;strings
;**********
str1:
db 'bezcreate',0
str3a:
db 'bezcreate_11',0
str3b:
db 'bezcreate_22',0
str3c:
db 'bezcreate_33',0
str3d:
db 'bezcreate_44',0
str4:
db 'bezpaint',0
str5:
db 'bezselect',0
str6:
db '[bezselect] no selection',0
str8:
db 'bezselectdrag',0
str9:
db '[bezselectdrag] have selection',0
str10:
db '[bezselectdrag] no selection',0
str14:
db 'bezmodify',0
str16:
db 'bezcopy',0
str17:
db 'bezread',0
str18:
db 'bezwrite',0
str19:
db 'bez2pdf',0
str20:
db 'bezmodifyx1y1',0
str21:
db 'bezmodifyx2y2',0
str22:
db 'bezmodifyx3y3',0
str23:
db 'bezmodifyx4y4',0
str24:
db 'bezcopy',0
str25:
db 'bezmove',0
str26:
db 'bezmirror',0
str27:
db 'bezscale',0
str28:
db 'bez2pdf',0



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
;bezcreate

;create a new link in the list for TCD_BEZIER

;user must make 4 Lclicks to define the object
;Startpoint->Controlpoint1->Controlpoint2->Endpoint
;the bezier will not show up on the screen 
;until after the end point is defined

;input: push dword [currentlayer]     [ebp+8]

;return:
;eax=dword [FeedbackMessageIndex]
;ebx=address of left mouse handler
;esi=address of newly created line segment
;*********************************************

public bezcreate

	push ebp
	mov ebp,esp

	dumpstr str1


	push 256
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
	mov dword [esi],TCD_BEZIER
	mov [esi+4],edi        ;current layer index
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],0   ;qty points
	mov dword [esi+16],0   ;dat pointer
	mov dword [esi+20],bezpaint
	mov dword [esi+24],bezdelete
	mov dword [esi+28],bezcopy
	mov dword [esi+32],bezmove
	mov dword [esi+36],bezmirror
	mov dword [esi+40],bezmodify
	mov dword [esi+44],bezwrite
	mov dword [esi+48],bezread
	mov dword [esi+52],bezselect
	mov dword [esi+56],bezscale
	mov dword [esi+60],bezdump
	mov dword [esi+64],bezselectdrag
	mov dword [esi+68],bez2pdf


	;and zero out the x,y floating point coordinates
	fldz
	fst qword [esi+80]   ;x1
	fst qword [esi+88]   ;y1
	fst qword [esi+96]   ;x2
	fst qword [esi+104]  ;y2
	fst qword [esi+112]  ;x3
	fst qword [esi+120]  ;y3
	fst qword [esi+128]  ;x4
	fstp qword [esi+136]  ;y4

	mov dword [esi+176],0           ;hide markers
	mov dword [esi+180],0xffffffff  ;disable slide mode



	;save the object link address for the other segmentcreate procs
	mov [object],esi


	;prompt user to make a mouse pick to define x1,y1
	mov eax,95
	mov ebx,bezcreate_11

	pop ebp
	retn 4



bezcreate_11:

	;this is a left mouse handler
	;we got here after user made a Lclick to define 
	;the x1,y1 of the bezier

	dumpstr str3a

	call GetMousePnt
	;returns st0=MOUSEX, st1=MOUSEY (or yellowbox)

	;get address of object we are creating
	mov esi,[object]

	;save x1,y1 mouse to the link
	fstp qword [esi+80]  ;save st0->x and pop the fpu so y=st0
	fstp qword [esi+88]  ;save st0->y and pop the fpu


	mov dword [esi+12],1   ;qty endpoints defined


	;set feedback message and LeftMouse handler
	mov eax,96   ;feedback message
	mov ebx,bezcreate_22   ;left mouse handler

	ret



bezcreate_22:

	;this is a left mouse handler
	;we got here after user made a Lclick to define 
	;the x2,y2 of the bezier

	dumpstr str3b

	call GetMousePnt
	;returns st0=MOUSEX, st1=MOUSEY (or yellowbox)

	;get address of object we are creating
	mov esi,[object]

	;save x2,y2 mouse to the link
	fstp qword [esi+96]   ;save st0->x and pop the fpu so y=st0
	fstp qword [esi+104]  ;save st0->y and pop the fpu


	mov dword [esi+12],2   ;qty endpoints defined


	;set feedback message and LeftMouse handler
	mov eax,97   ;feedback message
	mov ebx,bezcreate_33   ;left mouse handler

	ret



bezcreate_33:

	;this is a left mouse handler
	;we got here after user made a Lclick to define 
	;the x3,y3 of the bezier

	dumpstr str3c

	call GetMousePnt
	;returns st0=MOUSEX, st1=MOUSEY (or yellowbox)

	;get address of object we are creating
	mov esi,[object]

	;save x3,y3 mouse to the link
	fstp qword [esi+112]   ;save st0->x and pop the fpu so y=st0
	fstp qword [esi+120]  ;save st0->y and pop the fpu


	mov dword [esi+12],3   ;qty endpoints defined


	;set feedback message and LeftMouse handler
	mov eax,98   ;feedback message
	mov ebx,bezcreate_44   ;left mouse handler

	ret



bezcreate_44:

	;this is a left mouse handler
	;we got here after user made a Lclick to define 
	;the x4,y4 of the bezier

	dumpstr str3d

	call GetMousePnt
	;returns st0=MOUSEX, st1=MOUSEY (or yellowbox)

	;get address of object we are creating
	mov esi,[object]

	;save x4,y4 mouse to the link
	fstp qword [esi+128]   ;save st0->x and pop the fpu so y=st0
	fstp qword [esi+136]  ;save st0->y and pop the fpu


	mov dword [esi+12],4   ;qty endpoints defined


	;set feedback message and LeftMouse handler
	mov eax,0   ;feedback message
	mov ebx,0   ;left mouse handler

	;done creating bezier
	ret










;**************************************************************
;bezpaint

;this is the paint & hit testing proc for TCD_BEZIER

;the bezier is drawn after all 4 points (2 endpts 2 ctrlpts)
;are defined.  

;there is no line clipping, its drawn using the tatOS/tlib/bezier 
;function with 20 line segments

;this routine must properly handle the painting
;during all phases of object creation:
;	* before any points are defined
;	* after all 4 points are defined

;if mouse is close to either endpoint this function will return a
;yellow box point for attachment of other objects, the control points
;are not returned as yellow box

;user may Rclick to invoke the bezier popup and show/hide the 
;endpt and ctrlpt markers

;this object does not respond to "ortho", if user wants endpoint to
;fall on a vertical or horizontal line, user must draw such a line
;in advance for attachment of bezier endpoints



;input: 
;esi=address of TCD_BEZIER object in link list to draw
;push address of qword zoom           [ebp+32]
;push address of qword xorg           [ebp+28]
;push address of qword yorg           [ebp+24]
;push dword [mousex] screen coord     [ebp+20]
;push dword [mousey] screen coord     [ebp+16]
;push address of qword MOUSEXF        [ebp+12]
;push address of qword MOUSEYF        [ebp+8]

;return:
;eax=0 mouse is not over an endpoint or near this object
;eax=1 mouse is over this object start/end point
;eax=2 mouse is "near" the object somewhere between the endpoints
;ebx = X screen coordinates of YellowBoxPoint
;ecx = Y screen coordinates of YellowBoxPoint
;edx = address of YellowBoxPoint float coordinates for GetMousePoint

;***************************************************************

bezpaint:

	push ebp
	mov ebp,esp
	sub esp,12  ;make space on stack for local variables
	;[ebp-4]  color
	;[ebp-8]  linetype (may be over ridden if selected)
	;[ebp-12] address of object in link list


	;save the object address for later since esi is often trashed
	mov [ebp-12],esi




	;retrieve the object linetype & color from the layer index
	mov ecx,[esi+4]   ;ecx= layer index
	call GetLayItems
	;this function returns:
	;eax=layer name
	; bl=visibility
	; cl=color
	;edx=linetype
	;edi=dword [currentlayer]
	;esi=preserved
	mov [ebp-4],ecx    ;save  color for later
	mov [ebp-8],edx    ;save  linetype for later




	;through out this routine ebp must be preserved
	;we use this register to access input data on the stack



	;note esi and edi must be preserved
	;throughout this function across all tlib calls
	;esi=address of TCD_BEZIER


	;eax=object qty points defined (so far)
	mov eax,[esi+12]



	cmp eax,1  ;x1,y1 defined
	jz .1pts
	cmp eax,2  ;x1,y1 x2,y2 defined
	jz .2pts
	cmp eax,3  ;x1,y1 x2,y2 x3,y3 defined
	jz .3pts
	cmp eax,4  ;x1,y1 x2,y2 x3,y3 x4,y4 defined
	jz .4pts

	jmp .EndpointsUndefined




	;allow point markers to be displayed as the user
	;makes Lclicks to define the start point and control points

.3pts:

	;convert x3,y3 qword float to dword int
	mov esi,[ebp-12]      ;esi=address of TCD_BEZIER
	lea edi,[esi+160]     ;address to store x3,y3 int
	lea esi,[esi+112]     ;esi=address of x3 float
	call float2int

	;display marker at x3,y3
	mov esi,[ebp-12]  ;esi=address of TCD_BEZIER
	mov eax,50        ;tatOS/tlib/putmarker
	mov ebx,1         ;style=square
	mov ecx,[ebp-4]   ;color
	mov edx,[esi+160] ;x3
	mov esi,[esi+164] ;y3
	sysenter

	;fall thru

.2pts:

	;convert x2,y2 qword float to dword int
	mov esi,[ebp-12]      ;esi=address of TCD_BEZIER
	lea edi,[esi+152]     ;address to store x2,y2 int
	lea esi,[esi+96]      ;esi=address of x2 float
	call float2int

	;display marker at x2,y2
	mov esi,[ebp-12]  ;esi=address of TCD_BEZIER
	mov eax,50        ;tatOS/tlib/putmarker
	mov ebx,1         ;style=square
	mov ecx,[ebp-4]   ;color
	mov edx,[esi+152] ;x2
	mov esi,[esi+156] ;y2
	sysenter

	;fall thru

.1pts:

	;convert x1,y1 qword float to dword int
	mov esi,[ebp-12]      ;esi=address of TCD_BEZIER
	lea edi,[esi+144]     ;address to store x1,y1 int
	lea esi,[esi+80]      ;esi=address of x1 float
	call float2int

	;display point marker at x1,y1
	mov esi,[ebp-12]  ;esi=address of TCD_BEZIER
	mov eax,50        ;tatOS/tlib/putmarker
	mov ebx,4         ;style=dblsqr
	mov ecx,[ebp-4]   ;color
	mov edx,[esi+144] ;x1
	mov esi,[esi+148] ;y1
	sysenter

	jmp .YellowBoxTesting




.4pts:

	;if we got here all 4 bezier pts are defined

	;now we prepare to draw


	;convert the floating point line object endpoints
	;to UNclipped screen/pixel coordinates
	;the screen coordinates are used by bezselectdrag and bez2pdf


	;convert x1,y1 qword float to dword int
	mov esi,[ebp-12]      ;esi=address of TCD_BEZIER
	lea edi,[esi+144]     ;address to store x1,y1 int
	lea esi,[esi+80]      ;esi=address of x1 float
	call float2int

	;convert x2,y2 qword float to dword int
	mov esi,[ebp-12]      ;esi=address of TCD_BEZIER
	lea edi,[esi+152]     ;address to store x2,y2 int
	lea esi,[esi+96]      ;esi=address of x2 float
	call float2int

	;convert x3,y3 qword float to dword int
	mov esi,[ebp-12]      ;esi=address of TCD_BEZIER
	lea edi,[esi+160]     ;address to store x3,y3 int
	lea esi,[esi+112]     ;esi=address of x3 float
	call float2int

	;convert x4,y4 qword float to dword int
	mov esi,[ebp-12]      ;esi=address of TCD_BEZIER
	lea edi,[esi+168]     ;address to store x4,y4 int
	lea esi,[esi+128]     ;esi=address of x4 float
	call float2int







	;check if user wants any of the point markers are to be displayed
	mov esi,[ebp-12]  ;esi=address of TCD_BEZIER
	cmp dword [esi+176],1
	jnz .doneMarker

	;check for slide mode
	;this mode redefines x,y to be at the mouse
	cmp dword [esi+180],0xffffffff
	jz .doneslide

	;we are in slide mode
	cmp dword [esi+180],0
	jz .slide0
	cmp dword [esi+180],1
	jz .slide1
	cmp dword [esi+180],2
	jz .slide2
	cmp dword [esi+180],3
	jz .slide3
	jmp .doneslide

.slide0:
	;define x1y1 for slide mode
	mov eax,[ebp+20]  ;mousex screen
	mov [esi+144],eax ;x1
	mov eax,[ebp+16]  ;mousey screen
	mov [esi+148],eax ;y1
	jz .doneslide
.slide1:
	;define x2y2 for slide mode
	mov eax,[ebp+20]  ;mousex screen
	mov [esi+152],eax ;x2
	mov eax,[ebp+16]  ;mousey screen
	mov [esi+156],eax ;y2
	jz .doneslide
.slide2:
	;define x3y3 for slide mode
	mov eax,[ebp+20]  ;mousex screen
	mov [esi+160],eax ;x3
	mov eax,[ebp+16]  ;mousey screen
	mov [esi+164],eax ;y3
	jz .doneslide
.slide3:
	;define x4y4 for slide mode
	mov eax,[ebp+20]  ;mousex screen
	mov [esi+168],eax ;x4
	mov eax,[ebp+16]  ;mousey screen
	mov [esi+172],eax ;y4
.doneslide:



	;display markers
	;user may show/hide these markers from the Rclick/popup

	;display marker at x1,y1
	;this is the start point, it gets the dblsqr marker #4
	mov esi,[ebp-12]  ;esi=address of TCD_BEZIER
	mov eax,50        ;tatOS/tlib/putmarker
	mov ebx,4         ;style=dblsqr
	mov ecx,[ebp-4]   ;color
	mov edx,[esi+144] ;x1
	mov esi,[esi+148] ;y1
	sysenter

	;display marker at x2,y2
	;the control points and endpoint get a single square marker #1
	mov esi,[ebp-12]  ;esi=address of TCD_BEZIER
	mov eax,50        ;tatOS/tlib/putmarker
	mov ebx,1         ;style=square
	mov ecx,[ebp-4]   ;color
	mov edx,[esi+152] ;x2
	mov esi,[esi+156] ;y2
	sysenter

	;display marker at x3,y3
	mov esi,[ebp-12]  ;esi=address of TCD_BEZIER
	mov eax,50        ;tatOS/tlib/putmarker
	mov ebx,1         ;style=square
	mov ecx,[ebp-4]   ;color
	mov edx,[esi+160] ;x3
	mov esi,[esi+164] ;y3
	sysenter

	;display marker at x4,y4
	mov esi,[ebp-12]  ;esi=address of TCD_BEZIER
	mov eax,50        ;tatOS/tlib/putmarker
	mov ebx,1         ;style=square
	mov ecx,[ebp-4]   ;color
	mov edx,[esi+168] ;x4
	mov esi,[esi+172] ;y4
	sysenter

.doneMarker:





	;restore esi=address of TCD_BEZIER
	mov esi,[ebp-12]


	;if we got here
	;object is partial or totally exposed on the screen
	;if the object was previously off screen we will 
	;change the selected state from 
	;2=offscreen to "0=unselected
	;so that it may now be drawn and selected
	cmp dword [esi+8],2
	jnz .setlinetype

	mov dword [esi+8],0  ;mark unselected

.setlinetype:

	;get the object linetype from the link
	mov ebx,[ebp-8]      

	;is the object selected ?
	cmp dword [esi+8],1  
	jnz .drawbezier

	;over-ride the linetype with "selected" type
	mov ebx, 0xc2108420  


.drawbezier:


	;use the assigned layer properties
	;if selected we use special dashed line type
	;uses screen coordinates
	;since bezier is made up of 20 lines
	;any lines off screen will not be drawn


	;draw the bezier
	mov esi,[ebp-12]     ;esi=address of TCD_BEZIER
	push esi             ;preserve
	push edi             ;preserve
	push ebp             ;preserve
	mov eax,125          ;tatOS/tlib/bezier function
	;ebx=linetype
	lea ecx,[esi+144]    ;address of x1,y1->x4,y4 screen coordinates
	mov edx,[ebp-4]      ;color
	sysenter
	pop ebp              ;restore
	pop edi              ;restore
	pop esi              ;restore









.YellowBoxTesting:

	;*******************************************
	;Yellow Box Testing    (Mouse Hover)
	;*******************************************

	;we test here for mouse hover:
	; * mouse close to START point
	; * mouse close to END   point


	;the yellow box marker is drawn in main.s  paint routine
	;segment->paint returns values in eax,ebx,ecx,edx for this


	;we can first test if mouse is within the convex hull of bezier
	;(later)



	mov esi,[ebp-12]  ;esi=address of TCD_BEZIER


	;if we are in slide mode then no Yellow Box testing
	cmp dword [esi+180],0xffffffff
	jnz .slidemode




	;START test
	;test for mouse close to END point x1,y1
	;we return the x,y screen coordinates as "Yellow Box Point"
	;**********************************************************

	;is mousex within 10 pixels of x1 ?
	mov ebx,[ebp+20]        ;mousex
	sub ebx,[esi+144]       ;x1 screen coordinate
	mov eax,100             ;tlib function absval(b)
	sysenter                ;returns eax=|ebx|
	cmp eax,10              ;mouse must be within this many pixels
	ja .doneSTART           ;mouse is not close enough


	;is mousey within 10 pixels of y1 ?
	mov ebx,[ebp+16]        ;mousey
	sub ebx,[esi+148]       ;y1 screen coordinate
	mov eax,100             ;tlib function absval(b)
	sysenter                ;returns eax=|ebx|
	cmp eax,10
	ja .doneSTART           ;mouse is not close enough


	;return values
	;the yellow box will be drawn in main.s paint routine
	mov eax,1          ;mouse is over P1 point
	mov ebx,[esi+144]  ;X screen coordinates of YellowBoxPoint
	mov ecx,[esi+148]  ;Y screen coordinates of YellowBoxPoint
	lea edx,[esi+80]   ;address of YellowBoxPoint float
	jmp .done

.doneSTART:






	;END test
	;test for mouse close to END point x4,y4
	;*****************************************

	;is mousex within 10 pixels of x2 ?
	mov eax,100       ;tlib function absval(b)
	mov ebx,[ebp+20]  ;mousex
	sub ebx,[esi+168] ;x4 screen coordinate
	sysenter
	cmp eax,10
	ja .doneEND


	;is mousey within 10 pixels of y2 ?
	mov eax,100       ;absval(b)
	mov ebx,[ebp+16]  ;mousey
	sub ebx,[esi+172] ;y4 screen coordinate
	sysenter
	cmp eax,10
	ja .doneEND


	;return values
	;the yellow box will be drawn in main.s paint routine
	mov eax,1          ;mouse is over P4 point
	mov ebx,[esi+168]  ;X screen coordinates of YellowBoxPoint
	mov ecx,[esi+172]  ;Y screen coordinates of YellowBoxPoint
	lea edx,[esi+128]  ;address of YellowBoxPoint float
	jmp .done


.doneEND:
	;fall thru



.slidemode:
.EndpointsUndefined:

	;if we got here the mouse is not near x1,y1 or x4,y4
	;so we do not return a YellowBox point
	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,0
	jmp .done

.done:
	;the object->paint must return the following:
	;eax = dword flag to indicate if mouse is over/near this object
	;      0 mouse is not over/near this object
	;      1 mouse is over an object "point"
	;      2 mouse is "near" the object
	;ebx = X screen coordinates of YellowBox point or 0
	;ecx = Y screen coordinates of YellowBox point or 0
	;edx = address of YellowBox point (floating point coordinates)or 0
	;      this value is used by GetMousePnt

	mov esp,ebp       ;deallocate local variables
	pop ebp
	retn 28           ;cleanup 7 args on stack










;*********************************************
;bezselectdrag

;this procedure is called from main.s
;when a user makes a drag box

;we use the screen coordinates of the bezier endpoints
;if both endpoints are inside the drag box
;then we mark the object as selected

;note the drag box upper left should be picked first
;then the lower right
;so that x2>x1 and y2>y1 in screen coordinates

;input:
;esi=address of TCD_BEZIER object
;edi=address of dragbox screen coordinates x1,y1,x2,y2 16 bytes

;return:none
;**********************************************

bezselectdrag:


	;is x1,y1 inside bounding box ?
	;********************************
	mov eax,86          ;tlib ptinrect
	mov ebx,edi         ;address of dragbox coordinates
	mov ecx,[esi+144]   ;object x1 screen coordinate
	mov edx,[esi+148]   ;object y1 screen coordinate
	sysenter
	jnz .outsideBox


	;is  x4,y4 inside bounding box ?
	;*******************************
	mov eax,86          ;tlib ptinrect
	mov ebx,edi         ;address of dragbox coordinates
	mov ecx,[esi+168]   ;object x4 screen coordinate
	mov edx,[esi+172]   ;object y4 screen coordinate
	sysenter
	jnz .outsideBox


	;if we got here both endpoints are inside the dragbox

	;mark the object as selected
	mov dword [esi+8],1
	jmp .done

.outsideBox:
.done:
	ret






;********************************************************
;bezselect

;this is the object selection proc for TCD_BEZIER

;this function is based on aroselect
;this function is our object "hit test" function
;this function is called from IdleLeftMouseHandler

;we test if mouse is within the bezier polygon
;defined by the endpoints and control points (ptinpoly)
;if the control points are above and below the invisible line
;defined by the endpoints, this is problematic because the
;polygon crosses over itself. In this case 
;you must pick directly on the bezier for this to work, 
;if the control points are on the same side then you can pick 
;anywhere inside the polygon.
;obviously this is not the most accurate, a better method 
;would be to expose the 20 segments making up the bezier and
;do hit testing on each one. Thats too much work. We are
;taking a simplified approach here and see if it works
;adequately down the road.

;finally we build a complex string using printf
;that will display the TCD_BEZIER object properties

;all object->select procs are passed the following args
;all object->select procs must clean up 16 bytes off the stack

;the dword HitTest is 0=skip hit testing or 1=do hit testing
;when user hits RIGHT or LEFT arrow we skip hit testing and
;just mark the object as selected and build the object properties
;string.


;input:
;esi = address of TCD_BEZIER object to check
;push dword HitTest            [ebp+24]
;push address of printf buffer [ebp+20]
;push address qword MOUSEYF    [ebp+16]
;push address qword MOUSEXF    [ebp+12]
;push address qword zoom       [ebp+8]

;return:
;eax = 1 have selection or 0 no selection
;*********************************************************

bezselect:

	push ebp
	mov ebp,esp
	sub esp,4   ;stack locals
	;[ebp-4]    ;saved address of object link

	dumpstr str5 ;bezselect

	;save address of object for later
	mov [ebp-4],esi 


	cmp dword [ebp+24],0
	jz .skipHitTest


	;test if mouse is within the polygon defined by 
	;bezier endpoints and control points
	mov eax,126       ;tatOS/tlib/ptinpoly
	mov ecx,4         ;qtypoints
	mov esi,[ebp-4]   ;esi=address of TCD_BEZIER
	mov edi,[ebp+12]  ;edi=address of MOUSEXF,MOUSEYF
	lea esi,[esi+80]  ;esi=address of polygon points
	sysenter          
	cmp eax,1
	jnz .nopick
	


.skipHitTest:

	;selected
	;if we got here the object is "selected"
	;now toggle the object selection state to 1,0,1,0...
	;this allows repeated left mouse clicks to change
	;the linetype from normal->selected->normal...
	mov esi,[ebp-4]  ;esi=address of object
	mov eax,[esi+8]  ;eax=object selection state 1=yes, 0=not
	not eax          ;flip all bits
	and eax,1        ;mask off all but bit0
	mov [esi+8],eax  ;save selection state back to object link




	;fill in values to be used by printf to display object properties
	;this is displayed as a feedback message
	;when you Lclick on a segment
	fld  qword [esi+80] 
	fstp qword [bez_x1]
	fld  qword [esi+88] 
	fstp qword [bez_y1]
	fld  qword [esi+96] 
	fstp qword [bez_x2]
	fld  qword [esi+104] 
	fstp qword [bez_y2]
	fld  qword [esi+112]
	fstp qword [bez_x3]
	fld  qword [esi+120]
	fstp qword [bez_y3]
	fld  qword [esi+128]
	fstp qword [bez_x4]
	fld  qword [esi+136] 
	fstp qword [bez_y4]
	mov eax,[esi+4] ;get the layer
	mov [bez_layer],eax
	


	;call printf to build the object properties string
	;the string is stored in a 100 byte buffer in the main module
	mov eax,57         ;printf
	mov ebx,bezargtype
	mov ecx,BEZPRINTFQTYARGS
	mov esi,bezarglist
	mov edi,[ebp+20]   ;address printf buffer
	sysenter



	;we have a mouse pick on a line segment
	mov eax,1  ;selection = YES
	jmp .done


.nopick:
	mov eax,0   ;selection = NO

.done:
	mov esp,ebp  ;deallocate locals
	pop ebp
	retn 20













;************************************************
;bezdump
;dump the various fields of a TCD_BEZIER link

;input:  esi=address of link
;return: esi=address of link

;locals
DLstr0:
db 0xa
db 'TCD_BEZIER',0
DLstra:
db 'address of object link',0
DLstr1:
db 'object type',0
DLstr2:
db 'layer index',0
DLstr3:
db 'visibility state',0
DLstr4:
db 'qty points',0
DLstr5:
db 'dat pointer',0

DLstr13:
db 'previous link',0
DLstr14:
db 'next link',0

DLstr15a:
db 'x1=',0
DLstr15b:
db 'y1=',0
DLstr15c:
db 'x2=',0
DLstr15d:
db 'y2=',0
DLstr15e:
db 'x3=',0
DLstr15f:
db 'y3=',0
DLstr15g:
db 'x4=',0
DLstr15h:
db 'y4=',0

DLstr16a:
db 'x1 screen coordinate',0
DLstr16b:
db 'y1 screen coordinate',0
DLstr16c:
db 'x2 screen coordinate',0
DLstr16d:
db 'y2 screen coordinate',0
DLstr16e:
db 'x3 screen coordinate',0
DLstr16f:
db 'y3 screen coordinate',0
DLstr16g:
db 'x4 screen coordinate',0
DLstr16h:
db 'y4 screen coordinate',0
DLstr17:
db 'show/hide markers',0
DLstr18:
db 'slide mode',0

;************************************************

bezdump:

	dumpstr DLstr0

	mov ebx,[esi]   ;obj type
	dumpebx ebx,DLstr1,0

	mov ebx,esi     ;address of object/link
	dumpebx ebx,DLstra,0

	mov ebx,[esi+4] ;layer index
	dumpebx ebx,DLstr2,0

	mov ebx,[esi+8] ;selected state
	dumpebx ebx,DLstr3,0

	mov ebx,[esi+12] ;qty points defined so far
	dumpebx ebx,DLstr4,0

	mov ebx,[esi+16] ;dat pointer
	dumpebx ebx,DLstr5,0


	;we skip  proc addresses - not very interesting


	mov ebx,[esi+72] ;previous link
	dumpebx ebx,DLstr13,0

	mov ebx,[esi+76] ;next link
	dumpebx ebx,DLstr14,0



	;X1
	fld qword [esi+80]  ;x1
	mov eax,36          ;dumpst0
	mov ebx,DLstr15a
	sysenter
	ffree st0

	;Y1
	fld qword [esi+88]  ;y1
	mov eax,36          ;dumpst0
	mov ebx,DLstr15b
	sysenter
	ffree st0

	;X2
	fld qword [esi+96]  ;x2
	mov eax,36          ;dumpst0
	mov ebx,DLstr15c
	sysenter
	ffree st0

	;Y2
	fld qword [esi+104]  ;y2
	mov eax,36           ;dumpst0
	mov ebx,DLstr15d
	sysenter
	ffree st0

	;X3
	fld qword [esi+112]  ;x3
	mov eax,36           ;dumpst0
	mov ebx,DLstr15e
	sysenter
	ffree st0

	;Y3
	fld qword [esi+120]  ;y3
	mov eax,36           ;dumpst0
	mov ebx,DLstr15f
	sysenter
	ffree st0

	;X4
	fld qword [esi+128]  ;x4
	mov eax,36           ;dumpst0
	mov ebx,DLstr15g
	sysenter
	ffree st0

	;Y4
	fld qword [esi+136]  ;y4
	mov eax,36           ;dumpst0
	mov ebx,DLstr15h
	sysenter
	ffree st0




	;dump x1,y1->x4,y4  screen coordinates as 3=signed decimal
	mov ebx,[esi+144] ;x1
	dumpebx ebx,DLstr16a,3

	mov ebx,[esi+148] ;y1
	dumpebx ebx,DLstr16b,3

	mov ebx,[esi+152] ;x2
	dumpebx ebx,DLstr16c,3

	mov ebx,[esi+156] ;y2
	dumpebx ebx,DLstr16d,3

	mov ebx,[esi+160] ;x3
	dumpebx ebx,DLstr16e,3

	mov ebx,[esi+164] ;y3
	dumpebx ebx,DLstr16f,3

	mov ebx,[esi+168] ;x4
	dumpebx ebx,DLstr16g,3

	mov ebx,[esi+172] ;y4
	dumpebx ebx,DLstr16h,3


	;show/hide markers
	mov ebx,[esi+176]
	dumpebx ebx,DLstr17,3

	;slide mode
	mov ebx,[esi+180]
	dumpebx ebx,DLstr18,3

	
	;must return esi=address of object in link list
	ret






;***********************************************************
;bezmodify

;this procedure is called from main.s after the user selects
;an TCD_BEZIER object then Rclicks to invoke a popup
;then Lclicks within that popup
;The BezModifyProcTable defined above gives a list of 
;modify functions that can be executed from this popup

;input:
;eax = index into BezModifyProcTable  (see main.s HandleLeftMouse)
;esi = dword [headlink]
;esi = dword [currentlayer]

;return: all modify procs should return:
;        eax = feedback message index
;        ebx = Left Mouse handler
;************************************************************

public bezmodify

	;cant dumpstr here tom, it would trash eax

	;we got here after user picked a menu item
	;from the Bez Modify Popup menu

	;eax = index into BezModifyProcTable
	;esi = dword [headlink] 
	;edi = dword [currentlayer]

	mov ebx,BezModifyProcTable[eax]
	call ebx

	;return values for all  modify procs:
	;eax = feedback message index
	;ebx = Left Mouse handler
	ret




;move x1y1 in slide mode
bezmodifyx1y1:

	dumpstr str20

	;save address of selected object
	mov eax,TCD_BEZIER
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	cmp eax,0
	jz .done

	mov dword [object],ebx ;save address of object

	;show markers (if not)
	mov dword [ebx+176],1

	;put x1,y1 in slide mode
	mov dword [ebx+180],0


	;prompt user to pick new location for arrow x1y1
	mov eax,95   ;feedback message index
	
	;and set new left mouse handler
	mov ebx,bezmodifyx1y1_11

.done:
	ret



bezmodifyx1y1_11:

	;this is a left mouse handler
	;we got here after user picked new location for bezier x1y1

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF


	;save new x1y1
	mov esi,[object]  ;esi=address of TCD_BEZIER
	fstp qword [esi+80]
	fstp qword [esi+88]


	;disable slide mode
	mov dword [esi+180],0xffffffff

	mov eax,0  ;feedback message index
	mov ebx,0  ;left mouse handler

	ret






bezmodifyx2y2:

	dumpstr str21

	;save address of selected object
	mov eax,TCD_BEZIER
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	cmp eax,0
	jz .done

	mov dword [object],ebx ;save address of object

	;show markers (if not)
	mov dword [ebx+176],1

	;put x2,y2 in slide mode
	mov dword [ebx+180],1


	;prompt user to pick new location for arrow x1y1
	mov eax,96   ;feedback message index
	
	;and set new left mouse handler
	mov ebx,bezmodifyx2y2_11

.done:
	ret



bezmodifyx2y2_11:

	;this is a left mouse handler
	;we got here after user picked new location for bezier x2y2

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save new x2y2
	mov esi,[object]
	fstp qword [esi+96]
	fstp qword [esi+104]

	;disable slide mode
	mov dword [esi+180],0xffffffff

	mov eax,0  ;feedback message index
	mov ebx,0  ;left mouse handler
	ret





bezmodifyx3y3:

	dumpstr str22

	;save address of selected object
	mov eax,TCD_BEZIER
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	cmp eax,0
	jz .done

	mov dword [object],ebx ;save address of object

	;show markers (if not)
	mov dword [ebx+176],1

	;put x3,y3 in slide mode
	mov dword [ebx+180],2


	;prompt user to pick new location for arrow x1y1
	mov eax,97   ;feedback message index
	
	;and set new left mouse handler
	mov ebx,bezmodifyx3y3_11

.done:
	ret



bezmodifyx3y3_11:

	;this is a left mouse handler
	;we got here after user picked new location for bezier x3y3

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save new x3y3
	mov esi,[object]
	fstp qword [esi+112]
	fstp qword [esi+120]

	;disable slide mode
	mov dword [esi+180],0xffffffff

	mov eax,0  ;feedback message index
	mov ebx,0  ;left mouse handler
	ret




bezmodifyx4y4:

	dumpstr str23

	;save address of selected object
	mov eax,TCD_BEZIER
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	cmp eax,0
	jz .done

	mov dword [object],ebx ;save address of object

	;show markers (if not)
	mov dword [ebx+176],1


	;put x4,y4 in slide mode
	mov dword [ebx+180],3


	;prompt user to pick new location for arrow x1y1
	mov eax,98   ;feedback message index
	
	;and set new left mouse handler
	mov ebx,bezmodifyx4y4_11

.done:
	ret



bezmodifyx4y4_11:

	;this is a left mouse handler
	;we got here after user picked new location for bezier x4y4

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save new x4y4
	mov esi,[object]
	fstp qword [esi+128]
	fstp qword [esi+136]

	;disable slide mode
	mov dword [esi+180],0xffffffff

	mov eax,0  ;feedback message index
	mov ebx,0  ;left mouse handler
	ret






bezmodifylayer:

	;assign current layer to the selected object
	;this is a popup menu proc
	

	;get address of selected object
	mov eax,TCD_BEZIER
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	;do we have only 1 object selected ?
	cmp eax,1
	jnz .done

	
	;save address of selected object
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


	pop esi              ;esi=address of selected object
	mov [esi+4],edi      ;assign current layer to object link


.done:
	mov eax,0
	mov ebx,0
	ret






bezmodifymarkers:

	;show/hide the point markers of the selected object
	;this is a popup menu proc

	;save address of selected object
	mov eax,TCD_BEZIER
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	cmp eax,0
	jz .done


	;toggle the show/hide marker
	mov eax,[ebx+176]
	not eax
	and eax,1
	mov [ebx+176],eax ;save it
	
.done:
	mov eax,0
	mov ebx,0
	ret






;***************************************************
;bezcopy

;function to create a child TCD_BEZIER object
;that is offset from the parent object

;X = X + [DeltaX]
;Y = Y + [DeltaY]

;this function is usually called by "CopyObjects" in main.s

;input: 
;esi=address of object to copy
;push address of qword DeltaX      [ebp+12]
;push address of qword DeltaY      [ebp+8]

;return:
;esi=address of new TCD_BEZIER object
;****************************************************


bezcopy:

	push ebp
	mov ebp,esp
	sub esp,4   ;space on stack for 1 local variable

	mov [ebp-4],esi  ;save address of parent object to copy

	dumpstr str24


	push 256   ;request a 256 byte link
	call CreateBLink
	;test return value, esi holds address of link


	;initialize values for the new object
	mov dword [esi],TCD_BEZIER
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],4   ;qty points
	mov dword [esi+16],0   ;dat pointer

	mov dword [esi+20],bezpaint
	mov dword [esi+24],bezdelete
	mov dword [esi+28],bezcopy
	mov dword [esi+32],bezmove
	mov dword [esi+36],bezmirror
	mov dword [esi+40],bezmodify
	mov dword [esi+44],bezwrite
	mov dword [esi+48],bezread
	mov dword [esi+52],bezselect
	mov dword [esi+56],bezscale
	mov dword [esi+60],bezdump
	mov dword [esi+64],bezselectdrag
	mov dword [esi+68],bez2pdf


	mov eax,[ebp-4]  
	;eax=address of child
	;esi=address of parent


	;copy the layer index offset 4
	mov ebx,[eax+4]  ;retrieve the layer
	mov [esi+4],ebx  ;and copy into new object


	;copy the start point x,y offset 80,88
	fld  qword [eax+80] ;get x
	mov ebx,[ebp+12]    ;get address of DeltaX
	fadd qword [ebx]    ;add DeltaX
	fstp qword [esi+80] ;save x
	fld  qword [eax+88] ;get y
	mov ebx,[ebp+8]     ;get address of DeltaY
	fadd qword [ebx]    ;add DeltaY
	fstp qword [esi+88] ;save y


	;copy the 1st control point x,y  offset 96,104
	fld  qword [eax+96]  ;get x
	mov ebx,[ebp+12]     ;get address of DeltaX
	fadd qword [ebx]     ;add DeltaX
	fstp qword [esi+96]  ;save x
	fld  qword [eax+104] ;get y
	mov ebx,[ebp+8]      ;get address of DeltaY
	fadd qword [ebx]     ;add DeltaY
	fstp qword [esi+104] ;save y


	;copy the 2nd control point x,y  offset 112,120
	fld  qword [eax+112] ;get x
	mov ebx,[ebp+12]     ;get address of DeltaX
	fadd qword [ebx]     ;add DeltaX
	fstp qword [esi+112] ;save x
	fld  qword [eax+120] ;get y
	mov ebx,[ebp+8]      ;get address of DeltaY
	fadd qword [ebx]     ;add DeltaY
	fstp qword [esi+120] ;save y


	;copy the end point x,y  offset 128,136
	fld  qword [eax+128] ;get x
	mov ebx,[ebp+12]     ;get address of DeltaX
	fadd qword [ebx]     ;add DeltaX
	fstp qword [esi+128] ;save x
	fld  qword [eax+136] ;get y
	mov ebx,[ebp+8]      ;get address of DeltaY
	fadd qword [ebx]     ;add DeltaY
	fstp qword [esi+136] ;save y


	;init  show/hide point markers
	mov dword [esi+176],0

	;init slide mode 
	mov dword [esi+180],0xffffffff

	
	mov esp,ebp  ;deallocate locals
	pop ebp

	;returns esi=address of new object
	;this is used by aromirror
	retn 8       ;cleanup 2 args







;****************************************************
;bezmove

;all we do is redefine object coordinates by 
;DeltaX and DeltaY

;this function is called by "MoveObjects" in main.s

;input: 
;eai=address of object to move 
;push address of qword DeltaX      [ebp+12]
;push address of qword DeltaY      [ebp+8]

;return:none
;****************************************************

bezmove:

	push ebp
	mov ebp,esp

	dumpstr str25

	;esi is address of selected object to move

	mov eax,[ebp+12]  ;eax=address of qword DeltaX
	mov ebx,[ebp+8]   ;ebx=address of qword DeltaY

	;x1
	fld  qword [esi+80]
	fadd qword [eax]   ;x+=DeltaX
	fstp qword [esi+80] 

	;y1
	fld  qword [esi+88] 
	fadd qword [ebx]   ;y+=DeltaY
	fstp qword [esi+88]

	;x2
	fld  qword [esi+96]
	fadd qword [eax]   ;x+=DeltaX
	fstp qword [esi+96]

	;y2
	fld  qword [esi+104]
	fadd qword [ebx]   ;y+=DeltaY
	fstp qword [esi+104]  

	;x3
	fld  qword [esi+112]
	fadd qword [eax]   ;x+=DeltaX
	fstp qword [esi+112]

	;y3
	fld  qword [esi+120]
	fadd qword [ebx]   ;y+=DeltaY
	fstp qword [esi+120]

	;x4
	fld  qword [esi+128]
	fadd qword [eax]   ;x+=DeltaX
	fstp qword [esi+128]

	;y4
	fld  qword [esi+136]
	fadd qword [ebx]   ;y+=DeltaY
	fstp qword [esi+136]


	pop ebp
	retn 8  ;cleanup 2 args






;********************************************************
;bezmirror

;creates a child TCD_BEZIER that is mirrored about a TCD_SEGMENT

;the mirror line endpoints are qwords x1,y1,x2,y2 (32 bytes)
;they are provided by "MirrorObjects" in main.s

;input:
;esi= address of parent TCD_BEZIER to mirror 
;push address of TCD_SEGMENT mirror line endpoints  [ebp+8]

;return:none
;********************************************************

bezmirror:

	push ebp
	mov ebp,esp
	push esi

	dumpstr str26

	;edi=address of parent segment to mirror
	mov edi,esi


	;first make a copy of the parent with DeltaX=DeltaY=0.0
	;esi=address parent
	push zero     ;DeltaX=0.0
	push zero     ;DetlaY=0.0
	call bezcopy
	;returns esi=address of new child segment

	
	;mirror point x1,y1 
	mov eax,91         ;91=tlib function "mirrorpoint"
	mov ebx,[ebp+8]    ;address mirror line
	lea ecx,[esi+80]   ;address point to be mirrored
	mov edx,Point1     ;address mirrored point local storage
	sysenter


	;mirror point x2,y2
	mov eax,91       ;mirrorpoint
	mov ebx,[ebp+8]  ;address mirror line
	lea ecx,[esi+96] ;address point to be mirrored
	mov edx,Point2   ;address mirrored point local storage
	sysenter


	;mirror point x3,y3
	mov eax,91        ;mirrorpoint
	mov ebx,[ebp+8]   ;address mirror line
	lea ecx,[esi+112] ;address point to be mirrored
	mov edx,Point3    ;address mirrored point local storage
	sysenter


	;mirror point x4,y4
	mov eax,91        ;mirrorpoint
	mov ebx,[ebp+8]   ;address mirror line
	lea ecx,[esi+128] ;address point to be mirrored
	mov edx,Point4    ;address mirrored point local storage
	sysenter


	;now save mirrored points back to the child link
	fld  qword [Point1]   ;x1
	fstp qword [esi+80] 
	fld  qword [Point1+8] ;y1
	fstp qword [esi+88] 
	fld  qword [Point2]   ;x2
	fstp qword [esi+96] 
	fld  qword [Point2+8] ;y2
	fstp qword [esi+104]
	fld  qword [Point3]   ;x3
	fstp qword [esi+112] 
	fld  qword [Point3+8] ;y3
	fstp qword [esi+120]
	fld  qword [Point4]   ;x4
	fstp qword [esi+128] 
	fld  qword [Point4+8] ;y4
	fstp qword [esi+136]



	;return esi=address of object that was mirrored
	pop esi
	pop ebp
	retn 4







;**********************************************
;bezscale

;scales a TCD_BEZIER object larger or smaller
;XC,YC is the reference point for scaling

;this function is called by ScaleObjects in main.s

;input:
;esi=address of object to scale (must be preserved)
;push address of qword XC          [ebp+16]
;push address of qword YC          [ebp+12]
;push address of qword ScaleFactor [ebp+8]

;return:none
;**********************************************

bezscale:

	push ebp
	mov ebp,esp

	dumpstr str27

	;preserve eax,ebx,ecx
	mov eax,[ebp+16]  ;eax=address of XC
	mov ebx,[ebp+12]  ;ebx=address of YC
	mov ecx,[ebp+8]   ;ecx=address of ScaleFactor

	;the general formula for scaling an endpoint coordinate is:
	;x(i) = [x(i)-x(ref)]*ScaleFactor + x(ref)
	;here XC and YC are the reference point picked by the user

	;scale x1
	fld  qword [esi+80]   ;x1
	fst st1               ;st0=st1=x1
	fsub qword [eax]      ;x1-xc
	fmul qword [ecx]      ;(x1-xc)*ScaleFactor
	fadd qword [eax]      ;(x1-xc)*ScaleFactor + xc
	fstp qword [esi+80]   ;store it
	ffree st0

	;scale y1
	fld  qword [esi+88] 
	fst st1               ;st0=st1=y1
	fsub qword [ebx]      ;y1-yc
	fmul qword [ecx]      ;(y1-yc)*ScaleFactor
	fadd qword [ebx]      ;(y1-yc)*ScaleFactor + yc
	fstp qword [esi+88] 
	ffree st0

	;scale x2
	fld  qword [esi+96] 
	fst st1                ;st0=st1=x2
	fsub qword [eax]
	fmul qword [ecx]
	fadd qword [eax]
	fstp qword [esi+96] 
	ffree st0

	;scale y2
	fld  qword [esi+104] 
	fst st1                ;st0=st1=y2
	fsub qword [ebx]
	fmul qword [ecx]
	fadd qword [ebx]
	fstp qword [esi+104] 
	ffree st0


	;scale x3
	fld  qword [esi+112] 
	fst st1               
	fsub qword [eax]
	fmul qword [ecx]
	fadd qword [eax]
	fstp qword [esi+112] 
	ffree st0

	;scale y3
	fld  qword [esi+120] 
	fst st1                
	fsub qword [ebx]
	fmul qword [ecx]
	fadd qword [ebx]
	fstp qword [esi+120] 
	ffree st0

	;scale x4
	fld  qword [esi+128] 
	fst st1               
	fsub qword [eax]
	fmul qword [ecx]
	fadd qword [eax]
	fstp qword [esi+128] 
	ffree st0

	;scale y4
	fld  qword [esi+136]
	fst st1                
	fsub qword [ebx]
	fmul qword [ecx]
	fadd qword [ebx]
	fstp qword [esi+136]
	ffree st0


	;must return esi=address of object scaled
	pop ebp
	retn 12






;********************************************************
;bezwrite  qtybytes=96

;this procedure is called when writting a TCD_BEZIER to tcd file

;the total qty bytes written must be an even multiple of 16
;pad with zeros if necessary. this is so each object in the 
;file starts on a 16 byte boundry and so is easy to read
;with xxd

;input:
;edi= destination memory address
;esi= address of TCD_BEZIER object in link list

;return:
;eax=qty bytes written
;*********************************************************

bezwrite:

	push esi  ;must preserve


	;dword object type   offset 0
	mov [edi], dword TCD_BEZIER
	add edi,4  ;inc the destination address


	;an 8 byte ascii string representing the name of the object
	;ascii bytes 'BEZIER  '    offset 4
	mov byte [edi],0x42     ;B
	mov byte [edi+1],0x45   ;E
	mov byte [edi+2],0x5a   ;Z
	mov byte [edi+3],0x49   ;I
	mov byte [edi+4],0x45   ;E
	mov byte [edi+5],0x52   ;R
	mov byte [edi+6],0x20   ;
	mov byte [edi+7],0x20   ;
	add edi,8
	

	;dword layer  offset 12
	mov eax,[esi+4]  ;get the layer
	mov [edi], eax
	add edi,4

	;dword qty points offset 16
	mov [edi], dword 4
	add edi,4

	;pad 12 bytes so x1 starts on a 16 byte boundry
	cld
	mov al,0
	mov ecx,12
	repstosb  ;increments edi


	;qword x1  offset 32
	fld qword [esi+80]  ;get x1
	fstp qword [edi]    ;write it and pop to cleanup fpu
	add edi,8

	;qword y1  offset 40
	fld qword [esi+88]
	fstp qword [edi]
	add edi,8

	;qword x2  offset 48
	fld qword [esi+96]
	fstp qword [edi]
	add edi,8

	;qword y2  offset 56
	fld qword [esi+104]
	fstp qword [edi]
	add edi,8

	;qword x3  offset 64
	fld qword [esi+112]
	fstp qword [edi]
	add edi,8

	;qword y3  offset 72
	fld qword [esi+120]
	fstp qword [edi]
	add edi,8

	;qword x4  offset 80
	fld qword [esi+128]
	fstp qword [edi]
	add edi,8

	;qword y4  offset 88
	fld qword [esi+136]
	fstp qword [edi]
	add edi,8

	;offset 96 start of next object
	;no padding zeros reqd


	;return eax=qty bytes written
	mov eax,96

	pop esi  ;must restore
	;and edi is incremented by qty of bytes written 

	ret






;*************************************************************
;bezread 

;this procedure is called when reading a tcd file
;with object type == TCD_BEZIER

;FileOpenTCD in io.s must be updated to read any new TCD object

;input:
;esi= address of object data to read in tcd file
;     see "bezwrite" for format of this data

;return: 
;esi is incremented to start of next object

;make sure all the reads here match the writes in the 
;object write proc
;**************************************************************

public bezread

	pushad

	;at this point esi does not point to the start of the tcd file
	;esi should point to the start of a new TCD_BEZIER object data
	;in the tcd file
	;when we are done esi should be set to point to the start of the
	;next object in the tcd file

	push esi  ;preserve starting address of TCD_BEZIER data in tcd file


	push 256  ;link size
	call CreateBLink
	;returns esi=address of object link 

	mov edi,esi
	pop esi
	
	;so in this procedure:
	;esi=address to read TCD_BEZIER object data in tcd file
	;edi=address to write TCD_BEZIER object data to link list


	;make sure we have the correct version ?? (later)


	;object type
	;FileOpenTCD already read the first byte to make sure
	;it was a TCD_BEZIER
	mov eax,[esi]          ;eax should = TCD_BEZIER
	mov [edi],eax          ;write object type to link


	;layer
	mov eax,[esi+12]        ;read layer
	mov [edi+4],eax         ;write layer to link


	;object visibility state
	;this info is not stored in the tcd file
	;so we just set to 0 unselected
	mov dword [edi+8],0  


	;qty points 
	;may want to check the value should = 4
	mov eax,[esi+16]   
	mov [edi+12],eax


	;dat pointer 
	mov dword [edi+16],0  


	;various procedure names
	mov dword [edi+20],bezpaint
	mov dword [edi+24],bezdelete
	mov dword [edi+28],bezcopy
	mov dword [edi+32],bezmove
	mov dword [edi+36],bezmirror
	mov dword [edi+40],bezmodify
	mov dword [edi+44],bezwrite
	mov dword [edi+48],bezread
	mov dword [edi+52],bezselect
	mov dword [edi+56],bezscale
	mov dword [edi+60],bezdump
	mov dword [edi+64],bezselectdrag
	mov dword [edi+68],bez2pdf

	;x1
	fld  qword [esi+32]
	fstp qword [edi+80]

	;y1
	fld  qword [esi+40]
	fstp qword [edi+88]

	;x2
	fld  qword [esi+48]
	fstp qword [edi+96]
	
	;y2
	fld  qword [esi+56]
	fstp qword [edi+104]

	;x3
	fld  qword [esi+64]
	fstp qword [edi+112]
	
	;y3
	fld  qword [esi+72]
	fstp qword [edi+120]

	;x4
	fld  qword [esi+80]
	fstp qword [edi+128]
	
	;y4
	fld  qword [esi+88]
	fstp qword [edi+136]


	mov dword [edi+176],0           ;hide markers
	mov dword [edi+180],0xffffffff  ;disable slide mode


	;debug: esi=address of link, lets see what weve got
	;call DumpLink


	popad

	;at the start of this proc
	;esi pointed to the start of the object data
	;there are 96 bytes of object data
	;so now esi must point to the start of the next objects data
	;FileOpenTCD requires this
	add esi,96

	ret








;***************************************************************
;bez2pdf

;this is an object->writepdf procedure for TCD_BEZIER
;writes the object to a pdf graphic stream

;this function is called by FileSavePDF in io.s


;this function will write the following pdf commands:

;x y m  
;this is a MoveTo command

;x2 y2 x3 y3 x4 y4 c
;this is a Bezier CurveTo command

;r g b RG
;this declares DeviceRGB color space with pen color r g b

;S
;this is the stroke operator (draw the line)


;all x,y coordinates are the unclipped screen coordinates (pixels)
;you should zoom/pan your objects to fit the screen 
;before exporting to pdf


;many commercial applications will write the graphic stream
;using  zlib compression, pdf calls this "FlateDecode". 
;TCAD does not support this (yet)
;instead we just use ascii text which pdf also supports


;input: edi = destination address of pdf graphic stream buffer
;       esi = address of segment object in link list

;return:
;       edi is incremented to the end of the pdf graphic stream
;       esi = address of segment object in link list
;***************************************************************


bez2pdf:

	push ebp
	mov ebp,esp
	sub esp,8  ;local variables
	;[ebp-4]    address of pdf graphic stream
	;[ebp-8]    address of segment object in link list


	;edi holds destination address for PDF graphic stream
	;throughout this proc edi must be preserved and incremented
	;with every byte written to the graphic stream buffer

	mov [ebp-4],edi  ;save destination stream address
	mov [ebp-8],esi  ;save address of object for later


	dumpstr str28



	;set DeviceRGB space and pen color
	;looks like this: "r g b RG"
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

	mov esi,[ebp-8]    ;esi=address of object
	mov eax,127        ;tlib/bez2pdf
	mov ebx,edi        ;address dest pdf buffer
	lea ecx,[esi+144]  ;address of x1y1x2y2x3y3x4y4
	sysenter


	;done writting PDF graphic stream commands 
	;for one TCD_BEZIER


.done:

	;must return address of object in esi
	mov esi,[ebp-8]

	;edi holds address of end of graphic stream

	mov esp,ebp  ;deallocate locals
	pop ebp
	ret












objectstub:
	;a function that does nothing
	ret
bezdelete:
;	some objects may have pointers to allocated memory 
;	that must be freed
	ret





;**************** THE END ***********************************


;mov eax,9    ;dumpebx
;mov ebx,edi  ;value to dump
;mov ecx,txtdebug1
;mov edx,0    ;0=reg32
;sysenter



;bezdump:
;	ret
;bezselect:
;	retn 20
;bezselectdrag:
;	ret
;bezpaint:
;	mov eax,0  ;mouse not near this object
;	mov ebx,0
;	mov ecx,0
;	mov edx,0
;	retn 28
;public bezmodify
;	ret
;bezcopy:
;	retn 8
;bezmove:
;	retn 8
;bezmirror:
;	retn 4
;bezscale:
;	retn 12
;bezwrite:
;	ret
;public bezread
;	ret
;bez2pdf:
;	ret
;bezdelete:
;	some objects may have pointers to allocated memory 
;	that must be freed
;	ret
;objectstub:
;	a function that does nothing
;	ret




                                      