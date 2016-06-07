;Project: TCAD
;aro05  June 07, 2016


;this file contains code and data for TCD_ARROW

;the arrow consists of a "shaft" segment defined by 2 mouse clicks
;the arrow head consists of 2 segments of length "size" 
;attached to the shaft start point and aligned to the shaft

;the arrow head will not show up on the screen until after the 
;2nd mouse click to define the shaft endpoint

;the arrow paint routine does not use line clipping
;so if any part of the aro falls off the screen the tlib line()
;will not draw it

;P1 & P2 arrow head endpoints are computed by ComputeArrowHeadEndPoints 
;this must be done every time you create or modify an arrow

;the screen coordinates are saved with every paint cycle
;and used by aroselectdrag and aro2pdf

;FileOpenTCD in io.s must be updated to read a new object




;the 256 byte text link stores object properties as follows:

;offset-size-description
;80   qword  x1 start
;88   qword  y1 start
;96   qword  x2 end
;104  qword  y2 end
;112  qword  arrow head "size" 
;120  qword  arrow head P1x
;128  qword  arrow head P1y
;136  qword  arrow head P2x
;144  qword  arrow head P2y
;152  dword  x1  screen coordinate
;156  dword  y1  screen coordinate
;160  dword  x2  screen coordinate
;164  dword  y2  screen coordinate
;168  dword  P1x screen coordinate
;172  dword  P1y screen coordinate
;176  dword  P2x screen coordinate
;180  dword  P1y screen coordinate


;note:
;the object "paint"  routine must retn 28 
;the object "select" routine must retn 16





;          P1
;          *
;         *
;        *
;       *
;      *
;     *                 Arrow
;    start***************************************end
;     *
;      *
;       *
;        *
;         *
;          *
;           P2




;P1x = size * cos (leaderangle + angleA)
;P1y = size * sin (leaderangle + angleA)
;P2x = size * cos (leaderangle - angleA)
;P2y = size * sin (leaderangle - angleA)

;size = distance from Start->P1 or P2
;angleA = angle of arrow head segment relative to the shaft segment
;leaderangle = absolute angle of the shaft segment

;cos(A+B) = cosAcosB - sinAsinB
;sin(A+B) = sinAcosB + cosAsinB








;code labels in this file:

;arocreate     (public)
;arodelete
;aromove
;arocopy
;aroread       (public)
;arowrite
;aroselect
;aroselectdrag
;aropaint
;aromirror
;aroscale
;arodump
;aro2pdf

;aromodify      (public)
;aromodifyx1y1
;aromodifyx2y2
;aromodifylayer
;aromodifysize

;ComputeArrowHeadEndPoints




;aro.s to be placed in memory after txt.s
;see main.s for complete TCAD memory map
org 0x2030000



;assign a unique number to this source file
;this prevents defining a duplicate public symbol 
;in more than one source file
;main.s = 00
;seg.s  = 01
;io.s   = 02
;txt.s  = 03
;aro.s  = 04
source 4



;*****************
;   EXTERN
;*****************

;symbols that are defined in main.s
extern GetMousePnt
extern CreateBLink
extern GetSelObj
extern Get1SelObj
extern UnselectAll
extern GetLayItems
extern LftMousProc
extern EntrKeyProc
extern FlipKeyProc
extern PassToPaint
extern headlink
extern float2int
extern OrthoMode



;symbols defined in io.s
extern PDFpencolor






;**********************
;   EQUates
;**********************

equ TCD_ARROW          6
equ HERSHEYROMANSMALL  2





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
UnclippedEndpoints:
db0 16
storeD:
dd 0




;qwords
;**********
zero:
dq 0.0

;this sets the default size/length of arrow head at startup
qArrowHeadSize:
dq 1.0

qOrthoPoint:
db0 16

;aropaint uses this value to determine if you want a horiz or vert 
;this is the amount of mouse movement in qword floating point
;the templine will snap to horiz or vert if mouse movement is
;within this band
Oblique_Band:
dq 0.3

;contants used to compute location of points determining arrow head
;k1=cos(angleA)
;k2=sin(angleA)
k1:
dq .984
k2:
dq .174

leader_dx:
dq 0.0
leader_dy:
dq 0.0
leader_length:
dq 0.0

arohead_dx:
dq 0.0
arohead_dy:
dq 0.0





;arrays
;*********
MouseScreenXY:
db0 8

compromptbuf:
db0 100

UnitVector_X:
dq 0.0, 0.0, 1.0, 0.0

aroselbuf:
db0 32



AroModifyProcTable:
dd aromodifyx1y1, aromodifyx2y2, aromodifylayer, aromodifysize


;a point is 16 bytes local storage for x,y qwords
Point1:
db0 16
Point2:
db0 16




;strings
;**********
str1:
db 'arocreate',0
str2:
db 'arocreate_11',0
str3:
db 'arocreate_22',0
str4:
db 'aro leader angle= ',0
str5:
db 'horiz templine',0
str6:
db 'vert templine',0
str7:
db 'oblique templine',0
str8:
db 'dumping qword x1,y1,x2,y2   ',0
str9:
db 'aroselectdrag',0
str10:
db 'aromodifyx1y1',0
str11:
db 'aromodifyx2y2',0
str12:
db 'aroselect',0
str13:
db '[aromodifysiz] Enter new arrow head size as qword (default=1.0)',0
str14:
db 'aromove',0
str15:
db 'arocopy',0
str16:
db 'aromirror',0
str17:
db 'aroscale',0
str18:
db 'aro2pdf',0
str19:
db 'P1x screen coordinate',0
str20:
db 'P1y screen coordinate',0
str21:
db 'P2x screen coordinate',0
str22:
db 'P2y screen coordinate',0






;for debugging where we are in the code sometimes
flag1:
db 'flag1',0
flag2:
db 'flag2',0
flag3:
db 'flag3',0
flag4:
db 'flag4',0






;**********************************
;TCD_ARROW  Selection Properties
;***********************************

;this data is needed by a call to printf 
;to display object properties when you select this object
;this string is displayed at top of the screen:

;aro: x1=xxx y1=xxx x2=xxx y2=xxx size= lay=xxx

equ AROPRINTFQTYARGS 13

arostr0:
db 'aro',0x3a,0
arostr1:
db '  x1=',0
arostr2:
db '  y1=',0
arostr3:
db '  x2=',0
arostr4:
db '  y2=',0
arostr5:
db '  size=',0
arostr6:
db '  lay=',0

aroargtype:  ;2=dword, 3=0term string, 4=qword float
dd 3,3,4,3,4,3,4,3,4,3,4,3,2

aroarglist:
dd arostr0
dd arostr1,sel_X1
dd arostr2,sel_Y1
dd arostr3,sel_X2
dd arostr4,sel_Y2
dd arostr5,sel_Size
dd arostr6,sel_Layer
















;******************
;    PROCEDURES
;******************



;********************************************
;arocreate

;create a new arrow  by mouse picking
;user is prompted to make 2 Lclicks
;the arrow head is attached to the start point
;the arrow gets assigned the current layer

;the object endpoints are set to all 0.0
;you must assign proper values to offset 80,88,96,104
;default proc addresses are assigned for paint etc...
;set new [CurrentObjectLink]
;set new [LeftMouseHandler]
;set new [FeedbackMessageIndex]

;input:
;push dword [currentlayer]   [ebp+8]

;return:
;eax=dword [FeedbackMessageIndex]
;ebx=address of left mouse handler
;esi=address of newly created TCD_ARROW
;*********************************************

public arocreate

	push ebp
	mov ebp,esp

	dumpstr str1  ;arocreate


	call CreateBLink
	;test return value, esi holds address of link


	;initialize values for the object
	mov dword [esi],TCD_ARROW
	mov eax,[ebp+8]        ;read current layer index
	mov [esi+4],eax        ;layer index
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],0   ;qty points defined so far
	mov dword [esi+16],0   ;dat pointer
	mov dword [esi+20],aropaint
	mov dword [esi+24],arodelete
	mov dword [esi+28],arocopy
	mov dword [esi+32],aromove
	mov dword [esi+36],aromirror
	mov dword [esi+40],aromodify
	mov dword [esi+44],arowrite
	mov dword [esi+48],aroread
	mov dword [esi+52],aroselect
	mov dword [esi+56],aroscale
	mov dword [esi+60],arodump
	mov dword [esi+64],aroselectdrag
	mov dword [esi+68],aro2pdf

	;zero out 
	fldz
	fst  qword [esi+80]  ;x1
	fst  qword [esi+88]  ;y1
	fst  qword [esi+96]  ;x2
	fst  qword [esi+104] ;y2

	;assign default arrow head size
	fld  qword [qArrowHeadSize]
	fstp qword [esi+112]



	;save the object link address for the other create procs
	mov [object],esi


	;set feedback message and LeftMouse handler
	mov eax,91             ;feedback message (prompt for arrow start pt)
	mov ebx, arocreate_11  ;left mouse handler

	pop ebp
	retn 4




arocreate_11:

	;we got here after user made a Lclick to define 
	;the start point of the arrow object

	dumpstr str2

	call GetMousePnt
	;returns st0=MOUSEX, st1=MOUSEY (or yellowbox)

	;get address of object we are creating
	mov esi,[object]

	;save x1,y1 to the link
	fstp qword [esi+80]  ;save st0->x and pop the fpu so y1=st0
	fstp qword [esi+88]  ;save st0->y  and pop the fpu

	;1 endpoint defined so far
	mov dword [esi+12],1

	;set feedback message and LeftMouse handler
	mov eax,92           ;feedback message (prompt for arrow end pt)
	mov ebx,arocreate_22 ;left mouse handler

	ret




arocreate_22:

	;we got here after user made a Lclick to define 
	;the endpoint of the arrow object

	dumpstr str3


	;get address of object we are creating
	mov esi,[object]


	;base x2,y2 on the qOrthoPoint 
	;qOrthoPoint is saved during the last TCD_ARROW paint cycle
	;while drawing a temp object
	;it may be qOrthoPoint-Horizontal
	;or qOrthoPoint-Vertical
	;or qOrthoPoint-Oblique
	fld  qword [qOrthoPoint]
	fstp qword [esi+96]   ;x2
	fld  qword [qOrthoPoint+8]
	fstp qword [esi+104]  ;y2




	;compute P1 and P2 to define the arrow head segments
	;esi=address of TCD_ARROW
	call ComputeArrowHeadEndPoints



.done:

	;2 endpoints defined - done
	mov dword [esi+12],2  ;qty points

	;for debug: esi address of new object
	;call arodump

	;return new left mouse handler
	mov eax,0   ;default feedback message
	mov ebx,0   ;default left mouse handler

	ret







;**************************************************************
;aropaint

;this is the paint & hit testing proc for TCD_ARROW

;this code is based on TCD_SEGMENT
;a temp arrow is drawn after the 1st mouse click 
;there is no line clipping 

;this routine must properly handle the painting
;during all phases of object creation:
;	* before any points are defined [1]
;	* after 1 point is defined      [2]
;	* after both points are defined [3]

;[1] qty points = 0, the new link is created
;the endpoints are not yet defined
;so we dont paint anything

;[2] qty points = 1 the user has defined the first endpoint P1
;we draw a temp line from P1 to the mouse x,y

;[3] qty points = 2 both endpoints P1 and P2 are defined
;draw the object using its assigned layer properties


;input: 
;esi=address of TCD_ARROW object in link list to draw
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

aropaint:

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



	;edi holds address of buffer to store unclipped endpoints
	;this buffer is used to draw a templine 
	;and the unclipped object after all points are defined
	mov edi,UnclippedEndpoints



	;note esi and edi must be preserved
	;throughout this function across all tlib calls
	;esi=address of TCD_ARROW
	;edi=address of UnclippedEndpoints
	


	;eax=object qty points defined (so far)
	mov eax,[esi+12]

	;test for both endpoints undefined
	cmp eax,0
	jz .bothEndpointsUndefined

	;test for both endpoints defined
	cmp eax,2
	jz .bothEndpointsDefined



	;Templine
	;if we got here, we have only 1 endpoint defined (P1)
	;draw a temp line from P1 to the mouse
	;**********************************************************


	;OrthoMode = "on"  draw horizontal or vertical temp line
	;OrthoMode = "off"  draw Oblique temp line
	;Ortho can be toggled on/off from the main menu
	cmp dword [OrthoMode],0
	jz .notOrtho




	;Templine-Horizontal
	;x2=MOUSEX, y2=y1
	;***********************


	;test if the user wants a horizontal line
	;if (MOUSEY-Y1) < Oblique_Band
	;we will force a horizontal line
	;autocadd calls this "ortho"
	mov eax,[ebp+8]           ;address MOUSEYF
	fld  qword [eax]          ;st0=MOUSEYF
	fsub qword [esi+88]       ;st0=MOUSEYF-y1
	fabs                      ;st0=abs(MOUSEYF-y1)
	fld qword [Oblique_Band]  ;st0=OB, st1=abs(MOUSEYF-y1)
	fcomi st1
	jc .tryVertTempLine       ;st0<st1
	;fall thru
	

	ffree st0
	ffree st1

	;we have a horizontal templine
	;dumpstr str5  ;horiz templine


	;save MOUSEXF to the object link offset 96 as x2
	mov eax,[ebp+12]    ;address MOUSEXF
	fld  qword [eax]
	fstp qword [esi+96] ;save x2


	;save y1 to the object link offset 104 as y2
	fld  qword [esi+88]  ;load y1
	fstp qword [esi+104] ;save y2
	

	;save qOrthoPoint
	;qOrthoPoint is used by arocreate_22 to define x2,y2
	mov eax,[ebp+12]              ;eax=address MOUSEXF
	fld  qword [eax]              ;st0=MOUSEXF
	fstp qword [qOrthoPoint]      ;x2
	fld  qword [esi+88]           ;y1
	fstp qword [qOrthoPoint+8]    ;y2=y1 horizontal


	jmp .bothEndpointsDefined

.notHorizontal:
	




.tryVertTempLine:

	ffree st0
	ffree st1


	;Templine-Vertical
	;x2=x1, y2=MOUSEY
	;***********************

	;test if the user wants a vertical line
	;if (MOUSEX-X1) < Oblique_Band
	;we will force a vertical line
	mov eax,[ebp+12]          ;address MOUSEXF
	fld  qword [eax]          ;st0=MOUSEXF
	fsub qword [esi+80]       ;st0=MOUSEXF-x1
	fabs                      ;st0=abs(MOUSEXF-x1)
	fld qword [Oblique_Band]  ;st0=OB, st1=abs(MOUSEXF-x1)
	fcomi st1
	jc .doOblTempLine         ;st0<st1
	;fall thru

	
	ffree st0
	ffree st1


	;we have a vertical templine
	;dumpstr str6      ;vert templine


	;save x1 to the object link offset 96 as x2
	fld  qword [esi+80]
	fstp qword [esi+96]


	;save MOUSEYF to the object link offset 104 as y2
	mov eax,[ebp+8]      ;address MOUSEYF
	fld  qword [eax]     ;load y1
	fstp qword [esi+104] ;save y2



	;save qOrthoPoint
	;qOrthoPoint is used by arocreate_22 to define x2,y2
	fld  qword [esi+80]           ;x2=x1
	fstp qword [qOrthoPoint]
	mov eax,[ebp+8]               ;eax=address MOUSEYF
	fld  qword [eax]              ;y1=MOUSEYF
	fstp qword [qOrthoPoint+8]

	jmp .bothEndpointsDefined

.notVertical:
.notOrtho:





.doOblTempLine:


	ffree st0
	ffree st1


	;Oblique templine
	;x2=MOUSEX, y2=MOUSEY
	;*********************

	;dumpstr str7       ;oblique templine

	;save x2
	mov eax,[ebp+12]          ;address MOUSEXF
	fld  qword [eax]          ;st0=x2
	fst qword [esi+96]        ;save x2 to object link
	fstp qword [qOrthoPoint]  ;save x2 to qOrthoPoint

	;save y2
	mov eax,[ebp+8]            ;address MOUSEYF
	fld  qword [eax]           ;st0=y1
	fst  qword [esi+104]       ;save y2 to object link
	fstp qword [qOrthoPoint+8] ;save x2 to qOrthoPoint

	;fall thru





.bothEndpointsDefined:


	;if we got here the start & end points are defined
	;the endpoint may be "temp"
	;now we prepare to draw


	;convert the floating point line object endpoints
	;to UNclipped screen/pixel coordinates


	;convert x1,y1 qword float to dword int
	mov esi,[ebp-12]               ;esi=address of TCD_ARROW
	add esi,80                     ;esi=address of x1 float
	mov edi,UnclippedEndpoints     ;address to store x1,y1 int
	call float2int

	;convert x2,y2 qword float to dword int
	mov esi,[ebp-12]               ;esi=address of TCD_ARROW
	add esi,96                     ;esi=address of x2 float
	lea edi,[UnclippedEndpoints+8] ;address to store x2,y2 int
	call float2int




	;restore esi=address of TCD_ARROW
	mov esi,[ebp-12]



	;save the UnclippedEndpoints to the object link as screen
	;coordinates for the benefit of aroselectdrag & aro2pdf
	mov eax,[UnclippedEndpoints]
	mov [esi+152],eax               ;x1 screen
	mov eax,[UnclippedEndpoints+4]
	mov [esi+156],eax               ;y1 screen
	mov eax,[UnclippedEndpoints+8]
	mov [esi+160],eax               ;x2 screen
	mov eax,[UnclippedEndpoints+12]
	mov [esi+164],eax               ;y2 screen
	




	;if we got here
	;object is partial or totally exposed on the screen
	;if the object was previously off screen we will 
	;change the selected state from 
	;2=offscreen to "0=unselected
	;so that it may now be drawn and selected
	cmp dword [esi+8],2
	jnz .getLinetype


	mov dword [esi+8],0  ;mark unselected


.getLinetype:

	;get the object linetype from the link
	mov ebx,[ebp-8]      

	;is the object selected ?
	cmp dword [esi+8],1  
	jnz .paintTheObject

	;over-ride the linetype with "selected" type
	mov ebx, 0xc2108420  




.paintTheObject:

	;if we got here all of TCD_ARROW is visible
	;use the assigned layer properties
	;if selected we use special dashed line type
	;uses clipped screen coordinates
	;if part of the object falls off screen 
	;tlib line() will exit
	;and not draw the line (trivial reject)



	;draw the shaft
	push esi             ;preserve
	push edi             ;preserve
	push ebp             ;preserve
	mov eax,30           ;draw line function
	;ebx=linetype
	mov ecx,[UnclippedEndpoints]      ;x1
	mov edx,[UnclippedEndpoints+4]    ;y1  
	mov esi,[UnclippedEndpoints+8]    ;x2
	mov edi,[UnclippedEndpoints+12]   ;y2
	mov ebp,[ebp-4]      ;color
	sysenter
	pop ebp              ;restore
	pop edi              ;restore
	pop esi              ;restore






	;the aro head is only drawn after the 2nd mouse click
	mov eax,[esi+12]  ;eax=qty points defined

	cmp eax,2
	jnz .doneAroHead


	;convert P1x,P1y qword float to dword int screen coordinates
	;P1 andd P2 screen coordinates are also needed for aro2pdf
	mov esi,[ebp-12]               ;esi=address TCD_ARROW
	add esi,120                    ;esi=address TCD_ARROW+120
	mov edi,esi
	add edi,48                     ;edi=address TCD_ARROW+168
	call float2int


	;draw line from start->P1
	push ebp             ;preserve
	mov eax,30           ;draw line function
	mov esi,[ebp-12]     ;esi=address TCD_ARROW
	;ebx=linetype
	mov ecx,[UnclippedEndpoints]      ;x1
	mov edx,[UnclippedEndpoints+4]    ;y1  
	mov edi,[esi+172]                 ;P1y  
	mov esi,[esi+168]                 ;P1x  (note trashes esi)
	mov ebp,[ebp-4]                   ;color
	sysenter
	pop ebp                           ;restore

	

	;convert P2x,P2y qword float to dword int screen coordinates
	mov esi,[ebp-12]               ;esi=address TCD_ARROW
	add esi,136                    ;esi=address TCD_ARROW+136
	mov edi,esi
	add edi,40                     ;edi=address TCD_ARROW+176
	call float2int


	;draw line from start->P2
	push ebp             ;preserve
	mov eax,30           ;draw line function
	mov esi,[ebp-12]     ;esi=address TCD_ARROW
	;ebx=linetype
	mov ecx,[UnclippedEndpoints]      ;x1
	mov edx,[UnclippedEndpoints+4]    ;y1  
	mov edi,[esi+180]                 ;P2y
	mov esi,[esi+176]                 ;P2x  (note trashes esi)
	mov ebp,[ebp-4]                   ;color
	sysenter
	pop ebp                           ;restore


.doneAroHead:




	;*******************************************
	;Yellow Box Testing    (Mouse Hover)
	;*******************************************

	;we are not going to do any yellow box hit testing
	;the endpoints of this object are not selectable




	;need to preserve UnclippedEndpoints
	;for the next paint cycle
	;since its used for ortho testing
	jmp .done





.bothEndpointsUndefined:
	;just zero out the UnclippedEndpoints buffer
	mov esi,UnclippedEndpoints
	mov dword [esi],0 
	mov dword [esi+4],0 
	mov dword [esi+8],0 
	mov dword [esi+12],0 
	jmp .doneNoReturn

.doneNEAR:
	jmp .doneNoReturn

.notNEAR:
.doneNoReturn:

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

	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,0

	mov esp,ebp       ;deallocate local variables
	pop ebp
	retn 28           ;cleanup 7 args on stack













;********************************************************
;aroselect

;this is the object selection proc for TCD_ARROW

;this function is based on "segmentselect"
;this function is our line "hit test" function
;this function is called from IdleLeftMouseHandler

;first we test if mouse is within the 
;bounding box  defined by  endpoints

;then we test if the perpendicular from the mouse
;to the arrow shaft is a "short" distance, if so we mark the
;arrow as "selected" and let aropaint draw it accordingly

;finally we build a complex string using printf
;that will display the TCD_ARROW object properties

;all object->select procs are passed the following args
;all object->select procs must clean up 16 bytes off the stack

;input:
;esi = address of TCD_ARROW object to check
;push address of printf buffer [ebp+20]
;push address qword MOUSEYF    [ebp+16]
;push address qword MOUSEXF    [ebp+12]
;push address qword zoom       [ebp+8]

;return:
;eax = 1 have selection or 0 no selection

sel_X1:
dq 0.0
sel_Y1:
dq 0.0
sel_X2:
dq 0.0
sel_Y2:
dq 0.0
sel_DX:
dq 0.0
sel_DY:
dq 0.0
sel_Length:
dq 0.0
sel_Angle:
dq 0.0
sel_Layer:
dd 0
sel_Size:
dq 0.0

;*********************************************************

aroselect:

	push ebp
	mov ebp,esp
	sub esp,4  ;stack locals
	;[ebp-4]    ;saved address of object link

	dumpstr str12   ;aroselect

	;save address of object for later
	mov [ebp-4],esi 



	;get mouse xy in screen coordinates
	mov eax,64 ;getmousexy
	sysenter
	;returns eax=mousex, ebx=mousey, esi,edi also



	;test if mouse is within the bounding box of the arrow shaft
	mov eax,97        ;pointinrectfloat
	mov esi,[ebp-4]   ;esi=address of TCD_ARROW
	lea ebx,[esi+80]  ;ebx=address of x1,y1,x2,y2 rect corners
	mov ecx,[ebp+12]  ;ecx=address of MOUSEXF,MOUSEYF
	sysenter          ;sets ZF if point is IN rect
	jnz .nopick       ;mouse is not within bounding box

	


	;fill the first 16 bytes of aroselbuf with MOUSEXF,MOUSEYF
	;to prepare for "projectpointtoline"
	;aroselbuf is a 32 byte buffer
	mov eax,[ebp+12]  ;eax=address MOUSEXF
	fld  qword [eax]
	fstp qword [aroselbuf]
	mov eax,[ebp+16]  ;eax=address MOUSEYF
	fld  qword [eax]
	fstp qword [aroselbuf+8]



	;project Mouse point onto the arrow shaft
	;the first 16 bytes of aroselbuf is MOUSEXF,MOUSEYF
	;this function will fill in the last 16 bytes of segselbuf
	;with the projected point coordinates
	mov eax,98          ;tlib function projectpointtoline
	mov esi,[ebp-4]     ;address of object
	lea ebx,[esi+80]    ;ebx=address of our line segment
	mov ecx,aroselbuf
	sysenter




	;get length of segment defined by mouse x,y -> projected point
	;in floating obj coordinates
	mov eax,94        ;getslope
	mov ebx,aroselbuf 
	sysenter          ;st0=dx, st1=dy
	mov eax,95        ;getlength
	sysenter          ;st0=length



	;scale by zoom & convert to pixel screen coordinates
	mov eax,[ebp+8]        ;eax=address of zoom
	fmul  qword [eax]      ;zoom 
	fistp dword [storeD]   ;length of line in pixels


	;the line length from Mouse->Projected point should be 
	;5 pixels or less in length for selection
	cmp dword [storeD], 5 
	ja .nopick   ;mouse is more than 5 pixels away



	;if we got here mouse is "on" the arrow shaft
	;we have a selection


	;now toggle the object selection state to 1,0,1,0...
	;this allows repeated left mouse clicks to change
	;the linetype from normal->selected->normal...
	mov esi,[ebp-4]  ;esi=address of TCD_ARROW
	mov eax,[esi+8]  ;eax=object selection state 1=yes, 0=not
	not eax          ;flip all bits
	and eax,1        ;mask off all but bit0
	mov [esi+8],eax  ;save selection state back to object link




	;fill in values to be used by printf to display object properties
	;this is displayed as a feedback message
	;when you Lclick on a segment
	fld  qword [esi+80] 
	fstp qword [sel_X1]
	fld  qword [esi+88] 
	fstp qword [sel_Y1]
	fld  qword [esi+96] 
	fstp qword [sel_X2]
	fld  qword [esi+104] 
	fstp qword [sel_Y2]
	fld  qword [esi+112]
	fstp qword [sel_Size]
	mov eax,[esi+4]
	mov [sel_Layer],eax
	


	;call printf to build the object properties string
	;the string is stored in a 100 byte buffer in the main module
	mov eax,57         ;printf
	mov ebx,aroargtype
	mov ecx,AROPRINTFQTYARGS
	mov esi,aroarglist
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
	retn 16










;*********************************************
;aroselectdrag

;this procedure is called from main.s
;when a user makes a drag box

;we use the screen coordinates of the aro shaft
;if both points are inside the drag box
;then we mark the object as selected

;note the drag box upper left should be picked first
;then the lower right
;so that x2>x1 and y2>y1 in screen coordinates

;input:
;esi=address of TCD_ARROW object
;edi=address of dragbox screen coordinates x1,y1,x2,y2 16 bytes

;return:none
;**********************************************

aroselectdrag:

	dumpstr str9


	;is x1,y1 inside bounding box ?
	;********************************
	mov eax,86          ;tlib ptinrect
	mov ebx,edi         ;address of dragbox coordinates
	mov ecx,[esi+152]   ;object x1 screen coordinate
	mov edx,[esi+156]   ;object y1 screen coordinate
	sysenter
	jnz .outsideBox


	;is  x2,y2 inside bounding box ?
	;*******************************
	mov eax,86          ;tlib ptinrect
	mov ebx,edi         ;address of dragbox coordinates
	mov ecx,[esi+160]   ;object x2 screen coordinate
	mov edx,[esi+164]   ;object y2 screen coordinate
	sysenter
	jnz .outsideBox


	;if we got here both endpoints are inside the dragbox

	;mark the object as selected
	mov dword [esi+8],1
	jmp .done

.outsideBox:
.done:
	ret









;***********************************************************
;aromodfify

;this procedure is called from main.s after the user selects
;an TCD_ARROW object then Rclicks to invoke the aro popup
;then Lclicks within that popup
;The AroModifyProcTable defined above gives a list of 
;aro modify functions that can be executed from this popup

;input:
;eax = index into AroModifyProcTable  (see main.s HandleLeftMouse)
;esi = dword [headlink]
;esi = dword [currentlayer]

;return: all aro modify procs should return:
;        eax = feedback message index
;        ebx = Left Mouse handler
;************************************************************

public aromodify

	;cant dumpstr here tom, it would trash eax

	;we got here after user picked a menu item
	;from the Aro Modify Popup menu

	;eax = index into AroModifyProcTable
	;esi = dword [headlink] 
	;edi = dword [currentlayer]

	mov ebx,AroModifyProcTable[eax]
	call ebx

	;return values for all aro  modify procs:
	;eax = feedback message index
	;ebx = Left Mouse handler
	ret





aromodifyx1y1:

	dumpstr str10

	;save address of selected object
	mov eax,TCD_ARROW
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	cmp eax,0
	jz .done

	mov dword [object],ebx ;save address of object

	;prompt user to pick new location for arrow x1y1
	mov eax,93   ;feedback message index
	
	;and set new left mouse handler
	mov ebx,aromodifyx1y1_11

.done:
	ret



aromodifyx1y1_11:

	;this is a left mouse handler
	;we got here after user picked new location for text

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save new x1y1
	mov esi,[object]
	fstp qword [esi+80]
	fstp qword [esi+88]


	;recalculate the arrow head endpoints
	call ComputeArrowHeadEndPoints


	mov eax,0  ;feedback message index
	mov ebx,0  ;left mouse handler

	ret





aromodifyx2y2:

	dumpstr str11

	;save address of selected object
	mov eax,TCD_ARROW
	call GetSelObj
	;returns:
	;eax=qty selected objects else 0 if none selected
	;ebx=address of 1st selected object
	;ecx=address of 2nd selected object

	cmp eax,0
	jz .done

	mov dword [object],ebx ;save address of object

	;prompt user to pick new location for arrow x1y1
	mov eax,94   ;feedback message index
	
	;and set new left mouse handler
	mov ebx,aromodifyx2y2_11

.done:
	ret



aromodifyx2y2_11:

	;this is a left mouse handler
	;we got here after user picked new location for text

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save new x2y2
	mov esi,[object]
	fstp qword [esi+96]
	fstp qword [esi+104]


	;recalculate the arrow head endpoints
	call ComputeArrowHeadEndPoints


	mov eax,0  ;feedback message index
	mov ebx,0  ;left mouse handler

	ret






;***********************************************
;aromodifylayer

;modifys the object layer to the current layer

;input: Rclick for popup and select "layer"
;return
;***********************************************

aromodifylayer:


	;get address of selected object
	mov eax,TCD_ARROW
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





;***************************************************
;aromodifysize

;change the size of the arrow head
;the default size is 1.0
;input:user is prompted to enter new size as qword
;return:none
;****************************************************

aromodifysize:

	;tom the right mouse handler invoked this function and knows
	;the address of selected object so why dont we just pass it
	;to left mouse handler and then to this function ?
	call Get1SelObj
	;returns 
	;ecx=qty selected objects 
	;eax=type of last selected object 
	;esi=address of last selected object


	;prompt user to enter value (default=1.0)
	mov eax,54            ;comprompt
	mov ebx,str13         ;prompt string
	mov ecx,compromptbuf  ;destination buffer
	sysenter

	mov eax,93            ;str2st0
	mov ebx,compromptbuf
	sysenter              ;st0=new arrow head size

	;save new global arrow head size for future arrow objects
	fst qword [qArrowHeadSize]

	;modify size of selected object arrow head size
	fstp qword [esi+112]

	;and must recalculate P1 and P2 endpoints of arrowhead
	call ComputeArrowHeadEndPoints


.done:
	mov eax,0
	mov ebx,0
	ret






;****************************************************
;aromove

;all we do is redefine object coordinates by 
;DeltaX and DeltaY

;this function is called by "MoveObjects" in main.s

;input: 
;eai=address of object to move 
;push address of qword DeltaX      [ebp+12]
;push address of qword DeltaY      [ebp+8]

;return:none
;****************************************************

aromove:

	push ebp
	mov ebp,esp

	dumpstr str14

	;esi is address of selected object to move

	mov eax,[ebp+12]  ;eax=address of qword DeltaX
	mov ebx,[ebp+8]   ;ebx=address of qword DeltaY

	;start X  
	fld  qword [esi+80]
	fadd qword [eax]   ;x+=DeltaX
	fstp qword [esi+80] 

	;start Y  
	fld  qword [esi+88] 
	fadd qword [ebx]   ;y+=DeltaY
	fstp qword [esi+88]

	;end X
	fld  qword [esi+96]
	fadd qword [eax]   ;x+=DeltaX
	fstp qword [esi+96]

	;end Y
	fld  qword [esi+104]
	fadd qword [ebx]   ;y+=DeltaY
	fstp qword [esi+104]  


	;compute P1 and P2 to define the arrow head segments
	;esi=address of TCD_ARROW
	call ComputeArrowHeadEndPoints

	pop ebp
	retn 8  ;cleanup 2 args








;***************************************************
;arocopy

;function to create a child TCD_ARROW object
;that is offset from the parent object

;X = X + [DeltaX]
;Y = Y + [DeltaY]

;this function is usually called by "CopyObjects" in main.s

;input: 
;esi=address of object to copy
;push address of qword DeltaX      [ebp+12]
;push address of qword DeltaY      [ebp+8]

;return:
;esi=address of new TCD_ARROW object
;****************************************************


arocopy:

	push ebp
	mov ebp,esp
	sub esp,4   ;space on stack for 1 local variable

	mov [ebp-4],esi  ;save address of parent object to copy

	dumpstr str15


	call CreateBLink
	;test return value, esi holds address of link


	;initialize values for the new object
	mov dword [esi],TCD_ARROW
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],2   ;qty points
	mov dword [esi+16],0   ;dat pointer

	mov dword [esi+20],aropaint
	mov dword [esi+24],arodelete
	mov dword [esi+28],arocopy
	mov dword [esi+32],aromove
	mov dword [esi+36],aromirror
	mov dword [esi+40],aromodify
	mov dword [esi+44],arowrite
	mov dword [esi+48],aroread
	mov dword [esi+52],aroselect
	mov dword [esi+56],aroscale
	mov dword [esi+60],arodump
	mov dword [esi+64],aroselectdrag
	mov dword [esi+68],aro2pdf


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


	;copy the end point x,y  offset 96,104
	fld  qword [eax+96]  ;get x
	mov ebx,[ebp+12]     ;get address of DeltaX
	fadd qword [ebx]     ;add DeltaX
	fstp qword [esi+96]  ;save x
	fld  qword [eax+104] ;get y
	mov ebx,[ebp+8]      ;get address of DeltaY
	fadd qword [ebx]     ;add DeltaY
	fstp qword [esi+104] ;save y


	;copy the arrow head size
	fld  qword [eax+112]
	fstp qword [esi+112]


	;compute P1 and P2 to define the arrow head segments
	;esi=address of TCD_ARROW
	call ComputeArrowHeadEndPoints  ;must preserve esi

	
	mov esp,ebp  ;deallocate locals
	pop ebp

	;returns esi=address of new object
	;this is used by aromirror
	retn 8       ;cleanup 2 args








;********************************************************
;aromirror

;creates a child TCD_ARROW that is mirrored about a TCD_SEGMENT

;the mirror line endpoints are qwords x1,y1,x2,y2 (32 bytes)
;they are provided by "MirrorObjects" in main.s

;input:
;esi= address of parent TCD_ARROW to mirror 
;push address of TCD_SEGMENT mirror line endpoints  [ebp+8]

;return:none
;********************************************************

aromirror:

	push ebp
	mov ebp,esp
	push esi

	dumpstr str15

	;edi=address of parent segment to mirror
	mov edi,esi


	;first make a copy of the parent segment with DeltaX=DeltaY=0.0
	;esi=address parent segment
	push zero     ;DeltaX=0.0
	push zero     ;DetlaY=0.0
	call arocopy
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


	;now save mirrored points back to the child link
	fld  qword [Point1]   ;x1
	fstp qword [esi+80] 
	fld  qword [Point1+8] ;y1
	fstp qword [esi+88] 
	fld  qword [Point2]   ;x2
	fstp qword [esi+96] 
	fld  qword [Point2+8] ;y2
	fstp qword [esi+104]


	;compute P1 and P2 to define the arrow head segments
	;esi=address of TCD_ARROW
	call ComputeArrowHeadEndPoints  ;must preserve esi


	;return esi=address of object that was mirrored
	pop esi
	pop ebp
	retn 4









;**********************************************
;aroscale

;scales a TCD_ARROW object larger or smaller
;XC,YC is the reference point for scaling

;note the arrow head size is also scaled and so 
;all future arrow objects will have this new size

;this function is called by ScaleObjects in main.s

;input:
;esi=address of object to scale (must be preserved)
;push address of qword XC          [ebp+16]
;push address of qword YC          [ebp+12]
;push address of qword ScaleFactor [ebp+8]

;return:none
;**********************************************

aroscale:

	push ebp
	mov ebp,esp

	dumpstr str17

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



	;scale the arrow head size
	fld qword [esi+112]  ;load OldSize
	fmul qword [ecx]     ;st0=OldSize * ScaleFactor = NewSize
	fstp qword [esi+112] ;save NewSize


	;compute P1 and P2 to define the arrow head segments
	;esi=address of TCD_ARROW
	call ComputeArrowHeadEndPoints  ;must preserve esi


	;must return esi=address of object scaled
	pop ebp
	retn 12










;********************************************************
;arowrite  qtybytes=80

;this procedure is called when writting a TCD_ARROW to tcd file

;the total qty bytes written must be an even multiple of 16
;pad with zeros if necessary. this is so each object in the 
;file starts on a 16 byte boundry and so is easy to read
;with xxd

;input:
;edi= destination memory address
;esi= address of TCD_ARROW object in link list

;return:
;eax=qty bytes written
;*********************************************************

arowrite:

	push esi  ;must preserve


	;dword object type   offset 0
	mov [edi], dword TCD_ARROW
	add edi,4  ;inc the destination address


	;an 8 byte ascii string representing the name of the object
	;ascii bytes 'ARROW   ' 
	mov byte [edi],0x41     ;A
	mov byte [edi+1],0x52   ;R
	mov byte [edi+2],0x52   ;R
	mov byte [edi+3],0x4f   ;O
	mov byte [edi+4],0x57   ;W
	mov byte [edi+5],0x20   ;
	mov byte [edi+6],0x20   ;
	mov byte [edi+7],0x20   ;
	add edi,8
	

	;dword layer  offset 12
	mov eax,[esi+4]  ;get the layer
	mov [edi], eax
	add edi,4

	;dword qty points offset 16
	mov [edi], dword 2
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

	;qword "size"  offset 64
	fld qword [esi+112]
	fstp qword [edi]
	add edi,8


	;write 8 padding bytes
	mov dword [edi],0
	add edi,4
	mov dword [edi],0
	add edi,4


	;return eax=qty bytes written
	mov eax,80

	pop esi  ;must restore
	;and edi is incremented by qty of bytes written 

	ret












;*************************************************************
;aroread 

;this procedure is called when reading a tcd file
;with object type == TCD_ARROW

;input:
;esi= address of object data to read in tcd file
;     see arowrite for format of this data

;return: 
;esi is incremented to start of next object

;make sure all the reads here match the writes in the 
;object write proc
;**************************************************************

public aroread

	pushad

	;at this point esi does not point to the start of the tcd file
	;esi should point to the start of a new TCD_ARROW object data
	;in the tcd file
	;when we are done esi should be set to point to the start of the
	;next object in the tcd file

	push esi  ;preserve starting address of TCD_ARROW data in tcd file


	call CreateBLink
	;returns esi=address of object link 

	mov edi,esi
	pop esi
	
	;so in this procedure:
	;esi=address to read TCD_ARROW object data in tcd file
	;edi=address to write TCD_ARROW object data to link list


	;make sure we have the correct version ?? (later)


	;object type
	;FileOpenTCD already read the first byte to make sure
	;it was a TCD_ARROW
	mov eax,[esi]          ;eax should = TCD_ARROW
	mov [edi],eax          ;write object type to link


	;layer
	mov eax,[esi+12]        ;read layer
	mov [edi+4],eax         ;write layer to link


	;object visibility state
	;this info is not stored in the tcd file
	;so we just set to 0 unselected
	mov dword [edi+8],0  


	;qty points 
	;may want to check the value should = 2
	mov eax,[esi+16]   
	mov [edi+12],eax


	;dat pointer 
	mov dword [edi+16],0  


	;various procedure names
	mov dword [edi+20],aropaint
	mov dword [edi+24],arodelete
	mov dword [edi+28],arocopy
	mov dword [edi+32],aromove
	mov dword [edi+36],aromirror
	mov dword [edi+40],aromodify
	mov dword [edi+44],arowrite
	mov dword [edi+48],aroread
	mov dword [edi+52],aroselect
	mov dword [edi+56],aroscale
	mov dword [edi+60],arodump
	mov dword [edi+64],aroselectdrag
	mov dword [edi+68],aro2pdf

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

	;size of arrow head
	fld  qword [esi+64]
	fstp qword [edi+112]



	mov esi,edi   ;esi=address of TCD_ARROW in link list
	call ComputeArrowHeadEndPoints




	;debug: esi=address of link, lets see what weve got
	;call DumpLink


	popad

	;at the start of this proc
	;esi pointed to the start of the object data
	;there are 80 bytes of object data 
	;so now esi must point to the start of the next objects data
	;FileOpenTCD requires this
	add esi,80

	ret











;***************************************************************
;aro2pdf

;this is an object->writepdf procedure for TCD_ARROW
;writes the object to a pdf graphic stream

;this function is called by FileSavePDF in io.s


;this function will write the following pdf commands:

;x y m  
;this is a MoveTo command

;x y l
;this is a LineTo command

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


aro2pdf:

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


	dumpstr str18



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

	mov esi,[ebp-8]     ;esi=address of object

	;tlib function linepdf will generate 3 pdf strings
	;x1 y1 m
	;x2 y2 l
	;S

	;arrow shaft
	mov ebx,[esi+152]   ;x1 unclipped screen coordinate
	mov ecx,[esi+156]   ;y1 ditto
	mov edx,[esi+160]   ;x2 ditto
	mov esi,[esi+164]   ;y2 ditto  (note esi is trashed)
	;edi=destination pdf buffer
	mov eax,124         ;linepdf
	sysenter


	;arrow head start->P1
	mov esi,[ebp-8]     ;esi=address of object
	mov ebx,[esi+152]   ;x1 screen coordinate
	mov ecx,[esi+156]   ;y1  ditto
	mov edx,[esi+168]   ;P1x ditto
	mov esi,[esi+172]   ;P1y ditto  (note trashes esi)
	;edi=destination pdf buffer
	mov eax,124         ;linepdf
	sysenter


	;arrow head start->P2
	mov esi,[ebp-8]     ;esi=address of object
	mov ebx,[esi+152]   ;x1 screen coordinate
	mov ecx,[esi+156]   ;y1  ditto
	mov edx,[esi+176]   ;P2x ditto
	mov esi,[esi+180]   ;P2y ditto  (note trashes esi)
	;edi=destination pdf buffer
	mov eax,124         ;linepdf
	sysenter

	

	;done writting PDF graphic stream commands 
	;for one TCD_ARROW


.done:

	;must return address of object in esi
	mov esi,[ebp-8]

	;edi holds address of end of graphic stream

	mov esp,ebp  ;deallocate locals
	pop ebp
	ret








;************************************************
;arodump
;dump the various fields of a TCD_ARROW link

;input:  esi=address of link
;return: esi=address of link

;locals
DLstr0:
db 0xa
db 'TCD_ARROW',0
DLstra:
db 'address of object object/link',0
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
db 'qArrowHeadSize=',0
;************************************************

arodump:

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


	;qArrowHeadSize
	fld qword [esi+112]  
	mov eax,36           ;dumpst0
	mov ebx,DLstr15e
	sysenter
	ffree st0



	;dump P1x,P1y,P2x,P2y screen coordinates as 3=signed decimal

	mov ebx,[esi+168] ;P1x
	dumpebx ebx,str19,3

	mov ebx,[esi+172] ;P1y
	dumpebx ebx,str20,3

	mov ebx,[esi+176] ;P2x
	dumpebx ebx,str21,3

	mov ebx,[esi+180] ;P2y
	dumpebx ebx,str22,3

	;must return esi=address of object in link list
	ret





;********************************************
;dumpoints
;dump the object endpoints (qword) x1,y1,x2,y2
;input:esi=address of object
;return:none

pts01:
db 'address of TCD_SEGMENT',0
pts02:
db 'x1 = ',0
pts03:
db 'y1 = ',0
pts04:
db 'x2 = ',0
pts05:
db 'y2 = ',0
;*********************************************

dumpoints:

	;dump the object address
	mov eax,9     ;dumpebx
	mov ebx,esi   ;address of object
	mov ecx,pts01 ;string tag
	mov edx,0     ;dword reg
	sysenter

	;dump x1
	fld qword [esi+80]
	mov eax,36  ;dumpst0
	mov ebx,pts02
	sysenter
	ffree st0

	;dump y1
	fld qword [esi+88]
	mov eax,36  ;dumpst0
	mov ebx,pts03
	sysenter
	ffree st0

	;dump x2
	fld qword [esi+96]
	mov eax,36  ;dumpst0
	mov ebx,pts04
	sysenter
	ffree st0

	;dump y2
	fld qword [esi+104]
	mov eax,36  ;dumpst0
	mov ebx,pts05
	sysenter
	ffree st0

	ret




arodelete:
	;some objects may have pointers to allocated memory
	;that must be freed
	;TCD_ARROW does not use this function
	ret






;********************************************************
;ComputeArrowHeadEndPoints

;this function computes the arrow head endpoints 
;P1x,P1y and P2x,P2y.  
;These are saved to the link offset 120-144
;it is used in arocreate and modify procs
;any time the aro shaft endpoints are changed

;input:  esi=address of TCD_ARROW object
;return: none
;***********************************************************

ComputeArrowHeadEndPoints:

	;compute P1 and P2 to define the arrow head segments

	;compute P1x

	;leader dx & dy 
	mov eax,94        ;getslope
	lea ebx,[esi+80]  ;ebx=starting address of x1,y1,x2,y2
	sysenter          ;returns st0=dx, st1=dy
	fst qword [leader_dx]
	fxch st1
	fst qword [leader_dy]
	fxch st1

	;length of leader
	mov eax,95
	sysenter     ;returns st0=length
	fstp qword [leader_length]

	;compute termB
	fld qword [leader_dy]
	fmul qword [k2]
	fdiv qword [leader_length]  ;st0=termB

	;compute termA 
	fld qword [leader_dx]
	fmul qword [k1]
	fdiv qword [leader_length]  ;st0=termA, st1=termB

	;compute arrow head dx
	fsub qword st1     ;st0=termA-termB
	lea eax,[esi+112]  ;eax=address of arrow head size
	fmul qword [eax]   ;st0=size[termA-termB]
	fstp qword [arohead_dx]
	ffree st0

	;save P1x
	fld qword [esi+80]      ;x1
	fadd qword [arohead_dx]
	fstp qword [esi+120]    ;save P1x to offset 120 in the link



	;compute P1y

	;compute termB
	fld qword [leader_dx]
	fmul qword [k2]
	fdiv qword [leader_length]  ;st0=termB

	;compute termA 
	fld qword [leader_dy]
	fmul qword [k1]
	fdiv qword [leader_length]  ;st0=termA, st1=termB

	;compute arrow head dy
	fadd qword st1     ;st0=termA+termB
	lea eax,[esi+112]  ;eax=address of arrow head size
	fmul qword [eax]   ;st0=size[termA+termB]
	fstp qword [arohead_dy]
	ffree st0

	;save P1y
	fld qword [esi+88]      ;y1
	fadd qword [arohead_dy]
	fstp qword [esi+128]    ;save P1y to offset 128 in the link

	

	;compute P2x

	;compute termB
	fld qword [leader_dy]
	fmul qword [k2]
	fdiv qword [leader_length]  ;st0=termB

	;compute termA 
	fld qword [leader_dx]
	fmul qword [k1]
	fdiv qword [leader_length]  ;st0=termA, st1=termB

	;compute arrow head dx
	;this is not the same as for P1x
	fadd qword st1     ;st0=termA+termB
	lea eax,[esi+112]  ;eax=address of arrow head size
	fmul qword [eax]   ;st0=size[termA+termB]
	fstp qword [arohead_dx]
	ffree st0

	;save P2x
	fld qword [esi+80]      ;x1
	fadd qword [arohead_dx]
	fstp qword [esi+136]    ;save P2x to offset 136 in the link




	;compute P2y

	;compute termB
	fld qword [leader_dx]
	fmul qword [k2]
	fdiv qword [leader_length]  ;st0=termB

	;compute termA 
	fld qword [leader_dy]
	fmul qword [k1]
	fdiv qword [leader_length]  ;st0=termA, st1=termB

	;compute arrow head dy
	fsub qword st1     ;st0=termA-termB
	lea eax,[esi+112]  ;eax=address of arrow head size
	fmul qword [eax]   ;st0=size[termA-termB]
	fstp qword [arohead_dy]
	ffree st0

	;save P2y
	fld qword [esi+88]      ;y1
	fadd qword [arohead_dy]
	fstp qword [esi+144]    ;save P2y to offset 144 in the link

	ret  ;esi=address of TCD_ARROW












;**************** THE END ***********************************


;mov eax,9    ;dumpebx
;mov ebx,edi  ;value to dump
;mov ecx,txtdebug1
;mov edx,0    ;0=reg32
;sysenter


;mov eax,36  ;dumpst0
;mov ebx,AddressStringTag or 0
;sysenter

;remember that dumpreg trashes eax





                     