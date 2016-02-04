
;Project: TCAD
;seg02 Feb 02, 2016


;this file contains code and data for TCD_SEGMENT
;a segment is just a line of finite length
;having a start x1,y1 and endpoint x2,y2


;the segment link stores unique properties as follows:

;offset size description
;80  qword x1
;88  qword y1 
;96  qword x2
;104 qword y2
;112 qword xmid
;120 qword ymid
;128 qword xnear
;136 qword ynear
;144 dword x1 bounding box inflated & clipped screen coordinates
;148 dword y1      ditto
;152 dword x2      ditto
;156 dword y2      ditto
;160 dword x1 clipped screen coordinates for painting & export to pdf
;164 dword y1      ditto
;168 dword x2      ditto
;172 dword y2      ditto


;the Draw menu gives a variety of options for drawing lines:
;line-mm
;line-kk
;line-mk
;line-mi
;line-mpd2
;line-ipd2


;'m' stands for a mouse pick
;this is end/mid/near/scratch pick
;you can always select the endpoints or midpoint of an existing
;segment or select "near" any where along the line or just make
;a scratch pick out in space.

;'k' stands for a keyboard entry
;here you will enter x,y from the keyboard
;if defining the first endpoint you enter x1,y1 absolute
;if defining the 2nd endpoint you may enter dx+dy or length<angle
;or you may enter x2,y2 absolute

;'i' stands for intersection
;here you will select two line segments to define the intersection point

;'pd2' stands for perpendicular-to
;here you will select an existing line segment that your new line
;segment is to be perpendicular to

;the segment midpoint now resides in the object link
;new objects can be attached to a segment midpoint 
;the yellow box will show up at the midpoint


;offset 144-156
;here we store the coordinates of a bounding box around the segment
;which are used for yellow box mouse hit testing

;offset 160-172
;here we store the actual screen coordinates used to draw the segment
;these are also used for pdf output



;Left Mouse Handler
;every function that is a left mouse handler must return:
;eax=feedback message index or 0 for default
;ebx=address of left mouse handler or 0 for default

;Post Paint Handler
;this function gets executed once after PAINT
;to make this happen you must assign a valid proc address to 
;public dword [PassToPaint] and you must also 
;set eax = feedback message index
;and ebx = 0  for default left mouse handler

;Enter Key Handler
;every function that is an ENTER key handler must return:
;eax=feedback message index or 0 for default

;EnterKey, FlipKey, LeftMouse and PostPaint handlers may be defined
;by writting a valid proc address to the following:
;    dword [EntrKeyProc]
;    dword [FlipKeyProc]
;    dword [LftMousProc]
;    dword [PassToPaint]


;see main.s for all the predefined feedback messages

;if you make changes to this file you must always
;go back and reassemble main.s and tlink before running the program

;if you create a new link or modify an existing link, you must call
;SaveMidPoint since this will compute and write back to the link
;xmid,ymid.  Failure to do so will result in midpoints falling off
;into space




;code labels in this file:

;segcreate     (public)
;segcreatek    (public)
;segcreatemk   (public)
;segcreateMI   (public)
;segcreMPD2    (public)
;segcreIPD2    (public)
;segmentdelete
;segmentmove
;segmentcopy
;segmentread    (public)
;segmentwrite
;segmentselect
;segmentselectdrag
;segmentpaint
;segmentmirror
;segmentscale
;segmentdump
;segmentpdf

;segmodify      (public)
;SegmentModifyX1Y1
;SegmentModifyX2Y2
;SegmentModifyEndpoint
;SegmentModifyParallel
;SegmentModifyPerpendicular
;SegmentModifyEqual
;SegmentModifyAngle
;SegmentModifyLength
;SegmentModifyHorizontal
;SegmentModifyVertical
;SegmentModifyOrtho
;SegmentModifyLayer

;OffsetSegK           (public)
;OffsetSegM           (public)
;RotateSegK           (public)
;RotateSegM           (public)
;ExtndTrmSeg          (public)
;CornerSeg            (public)
;ChamferSeg           (public)
;GetNearPnt           (public)
;SetChamSize          (public)
;RedefineSegmentEndpoint
;GetKeyboardPoint
;SEGMENTPOLAR2CARTESIAN
;WHICHSEGMENTENDPOINT
;SaveMidPoint




;this file to be placed in memory after main.s
org 0x2008000



;assign a unique number to this source file
;this prevents defining a duplicate public symbol 
;in more than one source file
source 1



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


equ TCD_SEGMENT  0




;******************
;    local DATA
;******************


;bytes
;********
str01:
db 'segment mirror',0
str02:
db 'segment copy',0


;dwords
;********
object:
dd 0
Segment1:
dd 0
Segment2:
dd 0
Segment3:
dd 0
Segment1Endpoints:
dd 0
Segment2Endpoints:
dd 0
Pivot:
dd 0
HaveLeftMousePick:
dd 0
Layer:
dd 0
Xmid:
dd 0
Ymid:
dd 0
Xnear:
dd 0
Ynear:
dd 0
OrthoMode:
dd 1      ;at startup Ortho mode is "on"
zoom_pixel:
dd 0
pdfcurrentlayer:
dd 0





;qwords
;********
offset:
dq 0.0
X1:
dq 0.0
Y1:
dq 0.0
X2:
dq 0.0
Y2:
dq 0.0
tempX1:
dq 10.0
tempY1:
dq 10.0
tempX2:
dq 50.0
tempY2:
dq 30.0
XC:
dq 0.0
YC:
dq 0.0
DX:
dq 0.0
DY:
dq 0.0
Angle:
dq 0.0
Angle_ref:
dq 0.0
Length:
dq 0.0
Length1:
dq 0.0
Length2:
dq 0.0
Length3:
dq 0.0
Length4:
dq 0.0
point1X:
dq 0.0
point1Y:
dq 0.0
point2X:
dq 0.0
point2Y:
dq 0.0
Line34:
dq 0.0,0.0,0.0,0.0
storeD:   ;global used in segmentselect
dq 0.0
L1i:
dq 0.0
L1m:
dq 0.0
zero:
dq 0.0
Two:
dq 2.0
oneovertwo:
dq 0.5
deg90:
dq 1.570796327
deg2rad:
dq .0174532




;arrays
;*********

centerpoint:
db0 16

;a number of functions need the address of a "point"
;a point is 16 bytes local storage for x,y qwords
Point1:
db0 16

Point2:
db0 16

pIntersect:
db0 16

buffer:
db0 100

compromptbuf:
db0 100

UnclippedEndpoints:
db0 16



;x1,y1,x2,y2 for ptinrect testing
InflatedBoundingBox:
db0 16


;if the mouse is within 5 pixels of a segment endpoint
;a yellow box is drawn and we call this the "YellowBoxPoint"
YellowBoxPoint:
db0 16

;used for segmentselect only for mouse hit testing
segselbuf:
db0 32

;used for storage of bounding rectangle qwords x1,y1,x2,y2
boundrect:
db0 32

;storage of floating point coordinates x1,y1,x2,y2
vector1:
db0 32
vector2:
db0 32
vector3:
db0 32

;vector5,vector6 are reserved for segment paint ONLY !
vector5:
db0 32
vector6:
db0 32



;strings
;*********

str1:
db 'segmentselect',0
str1a:
db '[segmentselect] no selection',0
str2:
db 'segmentmodify',0
str4:
db 'OrthoMode',0
str5:
db 'Corner',0
str6:
db 'Corner_11',0
str7:
db 'Corner_22',0
str7a:
db '[Corner_22] seg1 - mouse is inside box P1 x Pintersect',0
str7b:
db '[Corner_22] seg1 - mouse is inside box P2 x Pintersect',0
str7c:
db '[Corner_22] seg2 - mouse is inside box P1 x Pintersect',0
str7d:
db '[Corner_22] seg2 - mouse is inside box P2 x Pintersect',0
str8:
db 'error no intersection lines are parallel',0
str9:
db '[GetNearPnt] return value',0


str10:
db 'GetNearPnt',0
str11:
db '<GetKeyboardPoint> Enter x,y  or length<angle or  dx+dy',0
str12:
db 'SegmentModifyEqual',0
str13:
db 'SegmentModifyEqual_11',0
str14:
db 'SegmentModifyEqual_22',0
str14a:
db 'SegmentModifyEqual_33',0
str15:
db '[GetKeyboardPoint] return value in eax',0
str16:
db 'GetKeyboardPoint',0
str17:
db '[Line-kk] Enter starting point as x,y absolute',0
str18:
db '[Line-kk] Enter ending point as length<angle or dx+dy or x,y',0
str19:
db '[GetKeyboardPoint] return value in eax',0


str20:
db 'ChamferSegments',0
str21:
db 'ChamferSegments_11',0
str22:
db 'ChamferSegments_22',0
str23:
db 'segmentcreatekeyboard',0
str24:
db 'segment move',0
str25:
db 'segmentcreatemk',0
str26:
db 'segmentcreatemk_11',0
str27:
db '[Line-mk] Enter segment endpoint as x,y or dx+dy or length<angle',0
str28:
db 'RotateSegmentsM',0
str29:
db 'RotateSegmentsM_11',0

str30:
db 'RotateSegmentsM_22',0
str31:
db 'RotateSegmentsM_33',0
str32a:
db 'RotateSegmentsM_44',0
str32b:
db 'RotateSegmentsM_55 flip key handler',0
str33:
db 'SegmentModifyParallel',0
str34:
db 'SegmentModifyParallel_11',0
str35:
db 'SegmentModifyParallel_22',0
str36:
db 'SegmentModifyParallel_33',0
str37:
db 'SegmentModifyParallel_44',0
str38:
db '[segmentpaint] lineclip failure line not drawn',0
str39:
db '[WhichSegmentEndpoint] return value',0

str40:
db '[Rotate] Enter Rotate Angle,deg,as float',0
str41:
db 'SegmentModifyPerpendicular',0
str42:
db 'SegmentModifyPerpendicular_11',0
str43:
db 'SegmentModifyPerpendicular_22',0
str44:
db 'SegmentModifyPerpendicular_33',0
str45:
db 'SegmentModifyPerpendicular_44',0
str46:
db 'segmentcreateim',0
str47:
db 'segmentcreateim_11',0
str48:
db 'segmentcreateim_22',0
str49:
db 'segmentcreateim_33',0

str50:
db 'SegmentModifyLength',0
str51:
db 'SegmentModifyLength_11',0
str52:
db 'SegmentModifyLength_22',0
str53:
db 'proc exit - insufficient selections',0
str55:
db 'no selection',0
str56:
db 'OffsetSegmentKeyboard',0
str57:
db 'OffsetSegmentKeyboard_11',0
str58:
db '[OffsetKeyboard] Enter amount to offset as float, f=flip',0
str59:
db 'OffsetSegmentMouse',0

str60:
db 'OffsetSegmentMouse_11',0
str61:
db 'OffsetSegmentMouse_22',0
str62:
db 'SegmentModifyAngle',0
str63:
db 'SegmentModifyAngle_11',0
str64:
db 'SegmentModifyAngle_22',0
str65:
db '[Modify] Enter new X1,Y1 as float',0
str66:
db '[Modify] Enter new X2,Y2 as float',0
str67:
db 'segmentcreatempd2',0
str68:
db 'segmentcreatempd2_11',0
str69:
db 'segmentcreatempd2_22',0

str70:
db 'segcreateMI',0
str71:
db 'segmentcreatemi_11',0
str72:
db 'segmentcreatemi_22',0
str73:
db 'segmentcreatemi_33',0
str74:
db 'segmentcreateipd2',0
str75:
db 'segmentcreateipd2_11',0
str76:
db 'segmentcreateipd2_22',0
str77:
db 'segmentcreateipd2_33',0
str78:
db '[segmentpaint] segment is off screen (select state=2)',0
str79:
db '[segmentpaint] visibility state was (2) setting to (0) unselected',0


str90:
db 'SegModHoriz',0
str91:
db 'SegModHoriz_11',0
str92:
db 'SegModHoriz_22',0
str93:
db '[Corner] error mouse pick at intersection',0
str95:
db '[ModifyLength] Enter new segment length as float',0
str96:
db 'SegModVertical',0
str97:
db 'SegModVertical_11',0
str98:
db 'SegModVertical_22',0


str100:
db 'mousex',0
str101:
db 'mousey',0
str102:
db '[Angle] Enter angle between segments in degrees',0
str104:
db 'segmentcreate',0
str104a:
db 'segmentcreate_11',0
str104b:
db 'segmentcreate_22',0
str105:
db 'segment endpaint',0
str106:
db 'segmentselectdrag',0
str107:
db '[segmentselectdrag] both pts inside dragbox (select=1)',0
str108:
db '[segmentselectdrag] one or both endpoints outside dragbox',0


str110:
db 'Trim',0
str111:
db 'Trim_11',0
str112:
db 'Trim_22',0
str114:
db 'segment modify endpoint',0
str117:
db 'SegmentPolar2Cartesian',0
str118:
db '[SegP2C]address of segment',0
str119:
db '[SegP2C]which endpoint',0


str120:
db '[SegP2C]qword length',0
str121:
db '[SegP2C]qword angle',0
str122:
db '[SegmentPolar2Cartesian] Invalid endpoint ID',0
str123:
db '[segmentpaint] zoom',0
str124:
db '[segmentpaint] xorg',0
str125:
db '[segmentpaint] yorg',0
str126:
db '[Chamfer] Enter size of chamfer as qword float',0
str128:
db 'segmentpdf',0
str129:
db '[segmentpdf] writting RG new pen',0


str130:
db '[segmentpdf] address of PDFpencolor string',0





flag1:
db 'flag1',0
flag2:
db 'flag2',0
flag3:
db 'flag3',0
flag4:
db 'flag4',0
flag5:
db 'flag5',0
flag6:
db 'flag6',0
flag7:
db 'flag7',0
flag8:
db 'flag8',0
flag9:
db 'flag9',0
flag10:
db 'flag10',0






;************************
;Segment Properties
;************************

;this data is needed by a call to printf in segment select
;to display segment properties when you select a line 
;this string is displayed at top of the screen:
;x1=xxx y1=xxx x2=xxx y2=xxx dx=xxx dy=xxx len=xxx ang=xxx lay=xxx

equ QTYARGSEGPROP 18

segstr1:
db 'x1=',0
segstr2:
db '  y1=',0
segstr3:
db '  x2=',0
segstr4:
db '  y2=',0
segstr5:
db '  dx=',0
segstr6:
db '  dy=',0
segstr7:
db '  len=',0
segstr8:
db '  ang=',0
segstr9:
db '  lay=',0

segargtype:  ;2=dword, 3=0term string, 4=qword float
dd 3,4,3,4,3,4,3,4,3,4,3,4,3,4,3,4,3,2
segarglist:
dd segstr1,sel_X1,segstr2,sel_Y1,segstr3,sel_X2,segstr4,sel_Y2
dd segstr5,sel_DX,segstr6,sel_DY,segstr7,sel_Length,segstr8,sel_Angle
dd segstr9,sel_Layer



;SegmentModifyProcTable
;***********************
;This is a call table of addresses for functions to modify segments
;the order of procs in this table must match the strings
;in the segment modify dropdown menu, see main.s

SegmentModifyProcTable:
dd SegmentModifyX1Y1,          SegmentModifyX2Y2
dd SegmentModifyEndpoint,      SegmentModifyParallel
dd SegmentModifyPerpendicular, SegmentModifyTangent   
dd SegmentModifyEqual,         SegmentModifyAngle
dd SegmentModifyLength,        SegmentModifyHorizontal
dd SegmentModifyVertical,      SegmentModifyOrtho
dd SegmentModifyLayer










;*******************
;    PROCEDURES
;*******************



segmentdelete:
	;some objects may have pointers to allocated memory
	;that must be freed
	;TCD_SEGMENT does not use this function
	ret





;**********************************************
;segmentscale
;XC,YC is the reference point for scaling
;input:
;esi=address of object to scale (must be preserved)
;push address of qword XC          [ebp+16]
;push address of qword YC          [ebp+12]
;push address of qword ScaleFactor [ebp+8]
;return:none
;**********************************************

segmentscale:

	push ebp
	mov ebp,esp

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

	;must return esi=address of object scaled
	pop ebp
	retn 12




;********************************************************
;segmentmirror
;creates a child segment that is mirrored about
;another line segment
;the mirror line points are qwords x1,y1,x2,y2 (32 bytes)
;input:
;esi= address of parent segment to mirror 
;push address of mirror segment points   [ebp+8]
;return:none
;********************************************************

segmentmirror:

	push ebp
	mov ebp,esp
	push esi

	dumpstr str01

	;edi=address of parent segment to mirror
	mov edi,esi

	;first make a copy of the parent segment with DeltaX=DeltaY=0.0
	;esi=address parent segment
	push zero     ;DeltaX=0.0
	push zero     ;DetlaY=0.0
	call segmentcopy  
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
	lea ecx,[esi+96] ;address point 2b mirrored
	mov edx,Point2   ;address mirrored point local storage
	sysenter


	;now save mirrored points back to new link
	fld  qword [Point1]   ;x1
	fstp qword [esi+80] 
	fld  qword [Point1+8] ;y1
	fstp qword [esi+88] 
	fld  qword [Point2]   ;x2
	fstp qword [esi+96] 
	fld  qword [Point2+8] ;y2
	fstp qword [esi+104] 

	;return esi=address of object that was mirrored
	pop esi
	pop ebp
	retn 4





;***********************************************************
;segmodfify
;Segment Modify
;input:
;eax = index into SegmentModifyProcTable
;esi = dword [headlink]
;esi = dword [currentlayer]
;return:none
;************************************************************

public segmodify

	;we got here after user picked an item
	;from the Segment Modify Popup menu

	;cant dumpstr here tom, it would trash eax

	;eax = index into SegmentModifyProcTable
	;esi = dword [headlink] 
	;edi = dword [currentlayer]

	mov ebx,SegmentModifyProcTable[eax]
	call ebx

	;return values: 
	;eax = feedback message index
	;ebx = Left Mouse handler
	ret



;********************************************************
;SegmentModifyX1Y1
;allow the user to redefine P1 starting point of segment
;input: prompts user for new x1,y1 value via keyboard
;return: eax=dword [FeedbackMessageIndex]
;*********************************************************

SegmentModifyX1Y1:

	;prompt user to select segment to modify
;	mov eax,65 ;feedback message index
;	mov ebx,0  ;idle left mouse handler
;	mov dword [PassToPaint],SegmentModifyX1Y1_11
;	ret

;	as of Jan 2016 the user must now preselect the segment
;	then Rclick to invoke the segment modify popup


SegmentModifyX1Y1_11:

	;redefine Segment P1 via keyboard

	;this is a post paint handler
	;we got here after user selected a segment to modify

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .done

	;save address of selected segment
	mov [object],ebx

	;prompt user to enter new value for X1,Y1
	mov eax,54            ;comprompt
	mov ebx,str65         ;prompt string
	mov ecx,compromptbuf  ;destination buffer
	sysenter

	mov eax,74            ;splitstr
	mov ebx,compromptbuf  ;parent string
	mov ecx,44            ;comma seperated
	mov edx,2             ;max qty substrings
	mov esi,buffer        ;storage for substring addresses
	sysenter

	;make sure we have 2 substrings
	cmp eax,2
	jnz .done

	;convert first value to st0 and save as X1
	mov eax,93       ;str2st0
	mov ebx,compromptbuf
	sysenter
	mov esi,[object]

	fstp qword [esi+80]    ;save new X1

	;convert next substring to st0 and save as Y1
	mov eax,93             ;str2st0
	mov ebx,[buffer]       ;substring address
	sysenter
	mov esi,[object]

	fstp qword [esi+88]    ;save new Y1


.done:
	mov eax,0  ;default feedback message
	mov ebx,0  ;default left mouse handler
	call UnselectAll
	ret






SegmentModifyX2Y2:

	;prompt user to select segment to modify
;	mov eax,66 ;feedback message index
;	mov ebx,0  ;idle left mouse handler
;	mov dword [PassToPaint],SegmentModifyX2Y2_11
;	ret

;	as of Jan 2016 the user must now preselect the segment
;	then Rclick to invoke the segment modify popup


SegmentModifyX2Y2_11:

	;redefine Segment P2 via keyboard

	;this is a post paint handler
	;we got here after user selected a segment to modify

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .done

	mov [object],ebx  ;save selected segment

	;prompt user to enter new value for x2
	mov eax,54            ;comprompt
	mov ebx,str66         ;prompt string
	mov ecx,compromptbuf  ;dest buffer
	sysenter

	mov eax,74            ;splitstr
	mov ebx,compromptbuf  ;parent string
	mov ecx,44            ;comma seperated
	mov edx,2             ;max qty substrings
	mov esi,buffer        ;storage for substring addresses
	sysenter


	;make sure we have 2 substrings
	cmp eax,2
	jnz .done

	;convert value to st0 and save as X2
	mov eax,93       ;str2st0
	mov ebx,compromptbuf
	sysenter
	mov esi,[object]

	fstp qword [esi+96]    ;save new X2

	;convert value to st0 and save as Y2
	mov eax,93       ;str2st0
	mov ebx,[buffer]
	sysenter
	mov esi,[object]

	fstp qword [esi+104]    ;save new Y2

.done:
	mov eax,0  ;default feedback message
	mov ebx,0  ;default left mouse handler
	call UnselectAll
	ret







;********************************************************
;SegmentModifyParallel
;rotate a segment parallel to an invisible line defined 
;by 2 endpoints

;user is asked to:
;* select a segment to rotate
;* select a pivot point on the segment to rotate
;* select 2 reference endpoints

;  these endpoints define the "reference" line
;  the rotated line will be parallel to this line
;  these ref endpoints may be on differant segments


;if the final position of the segment is 180 deg from desired
;press the 'f' key to flip the segment

;input:none
;return: 
;eax=dword [FeedbackMessageIndex]
;ebx=address of LeftMouseHandler
;********************************************************

SegmentModifyParallel:

;	dumpstr str33
	;prompt user to select segment to modify
;	mov eax,68 ;feedback message index
;	mov ebx,0  ;idle left mouse handler
;	mov dword [PassToPaint],SegmentModifyParallel_11
;	ret

;	as of Jan 2016 the user must preselect the segement
;	to modify then Rclick to invoke the segment modify popup



SegmentModifyParallel_11:

	dumpstr str34

	;this is a post paint handler
	;we got here after user selected a segment to modify

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .done


	;save the segment to rotate link address as Segment1
	mov esi,ebx
	mov [Segment1],esi

	
	;save the endpoints of segment to rotate as vector1
	fld  qword [esi+80] 
	fstp qword [vector1] 
	fld  qword [esi+88] 
	fstp qword [vector1+8] 
	fld  qword [esi+96] 
	fstp qword [vector1+16] 
	fld  qword [esi+104] 
	fstp qword [vector1+24] 
	

	;prompt user to select pivot point
	mov eax,37  ;feedback message index to select pivot
	mov ebx,SegmentModifyParallel_22  ;left mouse handler

.done:
	ret



SegmentModifyParallel_22:

	dumpstr str35

	;this is a left mouse handler
	;we got here after user selected a pivot point

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF


	;save coordinates of pivot point
	fstp qword [centerpoint]
	fstp qword [centerpoint+8]


	;left mouse handlers must return eax,ebx
	mov eax,31   ;feedback message index to select ref P1
	mov ebx,SegmentModifyParallel_33  ;left mouse handler

.done:
	ret




SegmentModifyParallel_33:

	dumpstr str36

	;this is a left mouse handler
	;we got here after user selected ref P1

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF


	fstp qword [vector2]    ;ref x1
	fstp qword [vector2+8]  ;ref y1

	;left mouse handlers must return eax,ebx
	mov eax,36   ;feedback message index to select ref P2
	mov ebx,SegmentModifyParallel_44  ;left mouse handler

	ret




SegmentModifyParallel_44:

	dumpstr str37

	;this is a left mouse handler
	;we got here after user selected ref P2

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF


	fstp qword [vector2+16]   ;ref x2
	fstp qword [vector2+24]   ;ref y2


	;compute reference angle
	mov eax,94          ;getslope
	mov ebx,vector2
	sysenter            ;st0=dx, st1=dy
	fpatan              ;st0=angle,radians
	fstp qword [Angle]  ;save ref Angle


	;esi holds address of segment to rotate
	mov esi,[Segment1] 


	;compute length of segment to rotate and save
	mov eax,94          ;getslope
	mov ebx,vector1
	sysenter            ;st0=dx, st1=dy
	mov eax,95          ;getlength
	sysenter            ;st0=length of segment to rotate
	fstp qword [Length]


	;are we modifying P1 or P2 of segment to rotate ?
	mov esi,[Segment1]  ;segment to modify
	mov ebx,centerpoint ;pivot
	call WhichSegmentEndpoint  ;return eax=1,2 or failure=0


	mov [Pivot],eax   ;save for flip
	mov esi,[Segment1]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian


.done:

	;left mouse handlers must return eax,ebx
	mov eax,0   ;feedback message index
	mov ebx,0   ;default left mouse handler
	mov dword [FlipKeyProc],SegmentModifyParallel_55
	call UnselectAll

	ret



SegmentModifyParallel_55:

	;this is a flip key handler
	;we got here if user pressed the "f" key to flip the object 180 deg

	;add 180 to the angle
	fldpi
	fadd qword [Angle]
	fstp qword [Angle]
	
	mov eax,[Pivot]
	mov esi,[Segment1]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian

	ret






;**********************************************************
;SegmentModifyPerpendicular

; * select line to rotate
; * pick the pivot point of line to rotate
; * pick 2 endpoints defining a reference line

;the code for this is taken from SegmentModifyParallel
;all we do is add 90 degrees to the reference angle
;**********************************************************

SegmentModifyPerpendicular:

;	dumpstr str41

	;prompt user to select segment to modify
;	mov eax,69 ;feedback message index
;	mov ebx,0  ;idle left mouse handler
;	mov dword [PassToPaint],SegmentModifyPerpendicular_11
;	ret

;	as of Jan 2016 the user must preselect the segment to 
;	modify then Rclick to invoke the segment modify popup




SegmentModifyPerpendicular_11:

	;this is a post paint handler
	;we got here after user picked segment to modify

	dumpstr str42

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .done

	;save the segment to rotate link address as Segment1
	mov esi,ebx
	mov [Segment1],esi

	;save the endpoints of segment to rotate as vector1
	fld  qword [esi+80] 
	fstp qword [vector1] 
	fld  qword [esi+88] 
	fstp qword [vector1+8] 
	fld  qword [esi+96] 
	fstp qword [vector1+16] 
	fld  qword [esi+104] 
	fstp qword [vector1+24] 
	

	;prompt user to select a pivot point on selected segment
	mov eax,40  ;feedback message index

	;set left mouse handler for endpoint selection
	mov ebx,SegmentModifyPerpendicular_22

.done:
	ret



SegmentModifyPerpendicular_22:

	;this is a left mouse handler
	;we got here after user selected a pivot point

	dumpstr str43

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save coordinates of pivot point
	fstp qword [XC]
	fstp qword [YC]

	mov eax,38  ;feedback message, prompt user to pick EP1
	mov ebx,SegmentModifyPerpendicular_33  ;left mouse handler

	ret



SegmentModifyPerpendicular_33:

	;this is a left mouse handler
	;we got here after user selected ref endpoint #1

	dumpstr str44

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save coordinates of reference endpoint #1
	fstp qword [vector2]    ;x1
	fstp qword [vector2+8]  ;y1


	;prompt user to select ref endpoint #2
	mov eax,39  ;feedback message index
	mov ebx,SegmentModifyPerpendicular_44  ;left mouse handler

	ret



SegmentModifyPerpendicular_44:

	;this is a left mouse handler
	;we got here after user selected ref endpoint #2

	dumpstr str45

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF


	;save coordinates of reference endpoint #2
	fstp qword [vector2+16]  ;x2
	fstp qword [vector2+24]  ;y2


	;now do the calculations

	;compute reference angle
	mov eax,94          ;getslope
	mov ebx,vector2
	sysenter            ;st0=dx, st1=dy
	fpatan              ;st0=angle,radians
	;add 90 degrees to the reference angle for perpendicular
	fadd qword [deg90]
	fstp qword [Angle]  ;save ref Angle
	

	;esi holds address of segment to rotate
	mov esi,[Segment1] 


	;compute length of segment to rotate and save
	mov eax,94          ;getslope
	mov ebx,vector1
	sysenter            ;st0=dx, st1=dy
	mov eax,95          ;getlength
	sysenter            ;st0=length of segment to rotate
	fstp qword [Length]


	;are we modifying P1 or P2 of segment to rotate ?
	mov esi,[Segment1]  ;segment to modify
	mov ebx,XC          ;pivot
	call WhichSegmentEndpoint  ;return eax=1,2 or failure=0


	mov [Pivot],eax   ;save for flip
	mov esi,[Segment1]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian


.done:
	;reset handlers and feedback message to defaults
	mov eax,0   ;feedback message index
	mov ebx,0   ;default left mouse handler
	mov dword [FlipKeyProc],SegmentModifyPerpendicular_55
	call UnselectAll

	ret



SegmentModifyPerpendicular_55:

	;we got here if user pressed the "f" key to flip the object 180 deg

	;add 180 to the angle
	fldpi
	fadd qword [Angle]
	fstp qword [Angle]
	
	mov eax,[Pivot]
	mov esi,[Segment1]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian

	ret






SegmentModifyTangent:

	;future version of tcad will implement circle
	;return feedback message index

	mov eax,41  ;function not available
	ret




;***************************************************
;SegmentModifyEqual
;make a segment the same length as another segment
;user is prompted to:
;* pick a segment to modify (segment #1)
;* pick a fixed endpoint on segment #1
;* pick a reference segment for length (segment #2)
;segment #1 length will be made equal to segment #2
;the reference endpoint on segment #1 will not move
;****************************************************


SegmentModifyEqual:

;	dumpstr str12

	;prompt user to select segment to modify
;	mov eax,75 ;feedback message index
;	mov ebx,0  ;idle left mouse handler
;	mov dword [PassToPaint],SegmentModifyEqual_11
;	ret

;	as of Jan 2016 the user must preselect the segment
;	to modify and Rclick to invoke segment modify popup



SegmentModifyEqual_11:

	;this is a post paint handler
	;we got here after user selected segment to modify

	dumpstr str13

	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,0
	jz .done

	;save the segment to modify
	mov [Segment1],ebx

	;prompt user to pick reference endpoint on segment #1
	mov eax,42

	;and set left mouse handler for endpoint selection
	mov ebx,SegmentModifyEqual_22

.done:
	ret




SegmentModifyEqual_22:

	;this is a Left Mouse Handler
	;we got here after user picked reference endpoint on Segment #1

	dumpstr str14

	;call GetMousePoint
	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save coordinates of reference endpoint
	;this point will not move when we redefine length
	fstp qword [XC]
	fstp qword [YC]

	;prompt user to pick reference segment #2 which gives us length
	mov eax,43  ;feedback message index
	mov ebx,0   ;default left mouse handler
	mov dword [PassToPaint],SegmentModifyEqual_33
	call UnselectAll

	ret



SegmentModifyEqual_33:

	;this is a post paint handler
	;we got here after user selected segment #2
	;we redefine the length of seg1 to match seg2

	dumpstr str14a

	;get address of selected segment in link list
	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,0
	jz .done  ;failed to find a selected segment


	;get address of ref segment endpoints
	add ebx,80


	;get length of reference segment
	mov eax,94           ;getslope
	;ebx=address of endpoints
	sysenter             ;st0=dx, st1=dy
	mov eax,95           ;getlength
	sysenter             ;st0=length
	fstp qword [Length]  ;save for later


	;save endpoints of segment to modify as vector1
	mov esi,[Segment1]

	;get address of segment to modify endpoints
	lea ebx,[esi+80]


	;get angle of segment to modify
	mov eax,94          ;getslope
	;ebx=address of endpoints
	sysenter            ;st0=dx, st1=dy
	fpatan              ;st0=angle,radians
	fstp qword [Angle]


	;are we modifying P1 or P2 of segment to modify equal length ?
	mov esi,[Segment1]  ;segment to modify
	mov ebx,XC          ;pivot
	call WhichSegmentEndpoint  
	;returns eax=1,2 or failure=0


	;eax=FixedEndpoint is set by WhichSegmentEndpoint
	mov esi,[Segment1]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian


.done:
	mov eax,0  ;default feedback message
	mov ebx,0  ;default left mouse handler
	mov dword [EntrKeyProc],0
	call UnselectAll
	ret

	






;****************************************************
;SegmentModifyAngle
;this allows you to set the angle of a segment
;relative to another segment
;the two segments must share a common point
;we use the intersection of the two segments as the pivot
;user is prompted to pick segment1 to move/modify
;then pick segment2 as reference segment 
;then enter the angle in degrees
;+ is ccw, - is cw
;this differs from the "rotate" function
;which moves one or more segments by some angle amount
;*****************************************************


SegmentModifyAngle:

;	dumpstr str62

	;prompt user to select segment to modify
;	mov eax,76 ;feedback message index
;	mov ebx,0  ;idle left mouse handler
;	mov dword [PassToPaint],SegmentModifyAngle_11
;	ret

;	as of Jan 2016 user must preselect segment to modify
;	then Rclick to invoke segment modify popup



SegmentModifyAngle_11:

	;this is a post paint handler
	;we got here after user selected segment to modify

	dumpstr str63

	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,0
	jz .done

	mov dword [Segment1],ebx  ;save selected segment

	;prompt user to pick reference segment2
	mov eax,49   ;feedback message index
	mov ebx,0    ;default left mouse handler
	mov dword [PassToPaint],SegmentModifyAngle_22
	call UnselectAll

.done:
	ret



SegmentModifyAngle_22:

	dumpstr str64

	;this is a post paint handler
	;we got here after user selected the reference segment2

	;get address of selected segment in link list
	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,0
	jz .done  ;failed to find a selected segment

	;save address of selected reference segment for later
	mov dword [Segment2],ebx

	;prompt user for angle,degrees
	;this should be entered as + for ccw rot and - for cw
	mov eax,54           ;comprompt
	mov ebx,str102       ;prompt string
	mov ecx,compromptbuf ;dest buffer
	sysenter
	jnz .done

	mov eax,93            ;str2st0
	mov ebx,compromptbuf
	sysenter              ;st0=angle
	fmul qword [deg2rad]  ;st0=angle,rad
	fstp qword [Angle]


	;get address of [Segment1] endpoints
	mov ebx,[Segment1]
	add ebx,80
	mov [Segment1Endpoints],ebx

	
	;get address of [Segment2] endpoints
	mov ecx,[Segment2]
	add ecx,80
	mov [Segment2Endpoints],ecx


	;compute the intersection/pivot point
	;this may be real if the segments are joined
	;or virtual if they are not
	mov eax,96      ;intersection
	mov ebx,[Segment1Endpoints]
	mov ecx,[Segment2Endpoints]
	;ecx=address line2 
	mov edx,XC      ;xc,yc intersection point
	sysenter


	;compute length of segment to rotate
	mov eax,94           ;getslope
	mov ebx,[Segment1Endpoints]
	sysenter             ;st0=dx,st1=dy
	mov eax,95           ;getlength
	sysenter             ;st0=length
	fstp qword [Length]  ;save for later


	;get angle of reference segment2
	mov eax,94            ;getslope
	mov ebx,[Segment2Endpoints]
	sysenter
	fpatan                 ;st0=angle,radians
	fstp qword [Angle_ref] ;save Angle of ref segment2


	;which endpoint is the intersection ?
	mov esi,[Segment1]  ;segment to modify
	mov ebx,XC          ;pivot
	call WhichSegmentEndpoint  ;return eax=1,2 or failure=0
	cmp eax,0
	jz .error


	;compute angle of segment to rotate
	fld  qword [Angle]     ;amount to move +/-
	fadd qword [Angle_ref] ;angle of ref segment
	fstp qword [Angle]


	;xnew = xc + Lcos(Angle_ref + Angle)
	;ynew = yc + Lsin(Angle_ref + Angle)
	mov esi,[Segment1]
	;eax is provided by WhichSegmentEndpoint
	mov dword [Pivot],eax
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian
	jmp .success


.error:
	mov eax,59  ;error-segments require common endpoint
	jmp .done

.success:
	mov eax,0  ;default feedback message index
.done:
	mov ebx,0  ;default left mouse handler
	mov dword [EntrKeyProc],0  ;default 
	mov dword [FlipKeyProc],SegmentModifyAngle_33
	call UnselectAll
	ret




SegmentModifyAngle_33:

	;we got here after user hit the flip key

	fldpi
	fadd qword [Angle]
	fstp qword [Angle]

	mov eax,[Pivot]
	mov esi,[Segment1]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian

	ret




;*****************************************************
;SegmentModifyLength
;here we change the length of a segment 
;base on keyboard input
;user is prompted to
;* pick segment to modify
;* pick fixed endpoint
;* enter new length from keyboard
;*******************************************************


SegmentModifyLength:

;	dumpstr str50

	;prompt user to select segment to modify
;	mov eax,77 ;feedback message index
;	mov ebx,0  ;idle left mouse handler
;	mov dword [PassToPaint],SegmentModifyLength_11
;	ret

;	as of Jan 2016 user must preselect segment to modify
;	then Rclick to invoke segment modify popup


SegmentModifyLength_11:

	dumpstr str51

	;this is a post paint handler
	;we got here after user selected a segment to modify length

	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,0
	jz .done

	mov dword [object],ebx  ;save selected segment

	;bring up comprompt and prompt user for new length
	mov eax,54  ;comprompt
	mov ebx,str95
	mov ecx,compromptbuf
	sysenter
	jnz .done

	mov eax,93           ;str2st0
	mov ebx,compromptbuf
	sysenter             ;st0=length

	fstp qword [Length]  ;save new length

	;get starting address of segment endpoints
	mov ebx,[object]
	add ebx,80

	;now get the angle of this segment relative to P1
	mov eax,94          ;getslope
	;ebx=address of endpoints
	sysenter            ;st0=dx, st1=dy
	fpatan              ;st0=angle,radians
	fstp qword [Angle]  ;save Angle relative to P1


	;prompt user to pick fixed reference endpoint 
	mov eax,44   ;feedback message index

	;and set left mouse handler for endpoint selection
	mov ebx,SegmentModifyLength_22

.done:
	ret



SegmentModifyLength_22:

	dumpstr str52

	;this is a left mouse handler
	;we got here after user picked the fixed endpoint
	;of segment to modify length

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save reference point
	fstp qword [XC]
	fstp qword [YC]

	;are we modifying P1 or P2 of segment to modify length ?
	mov esi,[object]    ;segment to modify
	mov ebx,XC          ;pivot
	call WhichSegmentEndpoint  ;return eax=1,2 or failure=0


	;eax=FixedEndpoint is set by WhichSegmentEndpoint
	mov esi,[object]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian


.done:
	;reset handlers and feedback message to defaults
	mov eax,0   ;feedback message index
	mov ebx,0   ;default left mouse handler
	call UnselectAll

	ret






;**********************************************
;SegmentModifyHorizontal
;make a line segment horizontal
;user is prompted to pick a segment to modify
;and pick the pivot point
;***********************************************


SegmentModifyHorizontal:

;	dumpstr str90

	;prompt user to select segment to modify
;	mov eax,78 ;feedback message index
;	mov ebx,0  ;idle left mouse handler
;	mov dword [PassToPaint],SegmentModifyHorizontal_11
;	ret

;	as of Jan 2016 user must preselect segment to modify
;	and Rclick to invoke segment modify popup



SegmentModifyHorizontal_11:

	;this is a post paint handler
	;we got here after user selected a segment to modify horizontal

	dumpstr str91

	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,0
	jz .done

	mov dword [object],ebx  ;save selected segment

	;get length of segment
	mov esi,[object]
	lea ebx,[esi+80]

	mov eax,94           ;getslope
	;ebx=address of vector
	sysenter
	mov eax,95           ;getlength
	sysenter             ;st0=length
	fstp qword [Length]  ;save for later

	;prompt user to select a pivot/ref point
	mov eax,25   ;feedback message index

	;set new left mouse handler
	mov ebx,SegmentModifyHorizontal_22

.done:
	ret




SegmentModifyHorizontal_22:

	dumpstr str92

	;this is a left mouse handler
	;we got here after user selected a segment ref point


	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save reference point
	fstp qword [XC]
	fstp qword [YC] 

	;the angle of a horizontal segment is 0 or 180 deg
	;the user may use the flip key as desired
	fldpi
	fstp qword [Angle]

	;get which endpoint is the pivot
	mov esi,[object]  ;our object
	mov ebx,XC        ;our pivot
	call WhichSegmentEndpoint ;eax=1 or 2 endpoint designation

	cmp eax,0
	jz .done

	mov [Pivot],eax   ;save for flip
	mov esi,[object]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian

.done:
	;reset handlers and feedback message to defaults
	mov eax,0  ;feedback message index
	mov ebx,0  ;default left mouse handler
	mov dword [FlipKeyProc],SegmentModifyHorizontal_33
	call UnselectAll
	ret



SegmentModifyHorizontal_33:

	;we got here after user hit the flip key

	fldpi
	fadd qword [Angle]
	fstp qword [Angle]

	mov eax,[Pivot]
	mov esi,[object]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian

	ret





;**********************************************
;Segment Modify Vertical
;make a line segment vertical
;user is prompted to pick a segment to modify
;and pick the pivot point
;hit the "f" flip key if you dont like the result
;***********************************************


SegmentModifyVertical:

;	dumpstr str96

	;prompt user to select segment to modify
;	mov eax,79 ;feedback message index
;	mov ebx,0  ;idle left mouse handler
;	mov dword [PassToPaint],SegmentModifyVertical_11
;	ret

;	as of Jan 2016 user must preselect segment to modify
;	and Rclick to invoke segment modify popup



SegmentModifyVertical_11:

	;this is a post paint handler
	;we got here after user selected a seg to modify vertical

	dumpstr str97

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .done

	mov dword [object],ebx  ;save selected segment

	;get length of segment
	mov esi,[object]
	lea ebx,[esi+80]

	mov eax,94            ;getslope
	;ebx=address of vector
	sysenter
	mov eax,95             ;getlength
	sysenter               ;st0=length
	fstp qword [Length]    ;save for later

	;prompt user to select a pivot/ref point
	mov eax,27   ;feedback message index

	;set new left mouse handler
	mov ebx,SegmentModifyVertical_22

.done:
	ret



SegmentModifyVertical_22:

	dumpstr str98

	;this is a left mouse handler
	;we got here after user selected a segment ref point

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save reference point
	fstp qword [XC] 
	fstp qword [YC] 


	;the angle of a vertical segment is 90 or 270 deg
	;the user may use the flip key as desired
	fld qword [deg90]
	fstp qword [Angle]


	;get which endpoint is the pivot
	mov esi,[object]  ;our object
	mov ebx,XC        ;our pivot
	call WhichSegmentEndpoint ;eax=1 or 2 endpoint designation

	cmp eax,0
	jz .done


	mov [Pivot],eax   ;save for flip
	mov esi,[object]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian

.done:

	;reset handlers and feedback message to defaults
	mov eax,0  ;feedback message index
	mov ebx,0  ;default left mouse handler
	mov dword [FlipKeyProc],SegmentModifyVertical_33
	call UnselectAll

	ret



SegmentModifyVertical_33:

	;we got here after user hit the flip key

	fldpi
	fadd qword [Angle]
	fstp qword [Angle]

	mov eax,[Pivot]
	mov esi,[object]
	mov ebx,Length
	mov ecx,Angle
	call SegmentPolar2Cartesian

	ret






;***************************************************
;SegmentModifyEndpoint
;move P1 or P2 segment endpoint to a new location
;via mouse picks
;***************************************************

SegmentModifyEndpoint:

	;prompt user to select segment to modify
;	mov eax,67 ;feedback message index
;	mov ebx,0  ;idle left mouse handler
;	mov dword [PassToPaint],SegmentModifyEndpoint_11
;	ret

;	as of Jan 2016 the user must preselect the segment
;	then Rclick to invoke the segment modify popup



SegmentModifyEndpoint_11:

	;this is a post paint handler
	;we got here after user selected segement to modify

	dumpstr str114

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .done

	mov dword [object],ebx  ;save selected segment

	;prompt user to pick endpoint to move
	mov eax,45   ;feedback message index
	
	;and set new left mouse handler
	mov ebx,SegmentModifyEndpoint_22
	jmp .done


.done:
	ret


SegmentModifyEndpoint_22:

	;this is a left mouse handler
	;we got here after user picked an endpoint to move


	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save reference point
	fstp qword [point1X]
	fstp qword [point1Y]

	;prompt user to pick destination point
	mov eax,46  ;feedback message index

	;and set new left mouse handler
	mov ebx,SegmentModifyEndpoint_33

	ret



SegmentModifyEndpoint_33:

	;this is a left mouse handler
	;we got here after user picked desitination endpoint

	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save reference point
	fstp qword [point2X]
	fstp qword [point2Y]


	;get which endpoint is the one to move
	mov esi,[object]          ;our object
	mov ebx,point1X           ;our endpoint to move
	call WhichSegmentEndpoint ;eax=1 or 2 endpoint designation

	cmp eax,0
	jz .done
	cmp eax,1
	jz .moveP1

	;P2 was selected so move P2
	fld  qword [point2X]
	fstp qword [esi+96]
	fld  qword [point2Y]
	fstp qword [esi+104]
	jmp .done


.moveP1:

	;P1 was selected so move P1
	fld  qword [point2X]
	fstp qword [esi+80]
	fld  qword [point2Y]
	fstp qword [esi+88]

.done:

	;reset handlers and feedback message to defaults
	mov eax,0  ;feedback message index
	mov ebx,0  ;default left mouse handler
	call UnselectAll

	ret







SegmentModifyOrtho:

	;this allows the user to toggle "ortho" mode on/off
	;ortho mode forces the line segment to be either
	;horizontal or vertical
	
	cmp dword [OrthoMode],0
	jz .1

	mov dword [OrthoMode],0
	mov eax,58  ;feedback message index for "OrthoMode=off"
	jmp .done
.1:
	mov dword [OrthoMode],1
	mov eax,57  ;feedback message index for "OrthoMode=on"

.done:
	mov ebx,0   ;left mouse handler
	call UnselectAll
	ret






SegmentModifyLayer:

	;get address of selected object
	mov eax,TCD_SEGMENT
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
	mov [esi+4],edi      ;change layer number

.done:
	mov eax,0
	mov ebx,0
	ret




	ret




;*************************************************************
;segmentread  version=01
;this procedure is called when reading a tcd file
;with object type == TCD_SEGMENT

;input:
;esi= address of segment object data to read in tcd file
;     see segmentwrite for format of this data

;return: 
;esi is incremented to start of next object

;make sure all the reads here match the writes in segmentwrite
;**************************************************************

public segmentread

	pushad

	;at this point esi does not point to the start of the tcd file
	;esi should point to the start of a new TCD_SEGMENT object data
	;in the tcd file
	;when we are done esi should be set to point to the start of the
	;next object in the tcd file

	push esi  ;preserve starting address of TCD_SEGMENT data in tcd file


	call CreateBLink
	;returns esi=address of object link 

	mov edi,esi
	pop esi
	
	;so in this procedure:
	;esi=address to read TCD_SEGMENT object data in tcd file
	;edi=address to write TCD_SEGMENT object data to link list


	;make sure we have the correct version ?? (later)


	;object type
	;FileOpenTCD already read the first byte to make sure
	;it was a TCD_SEGMENT
	mov eax,[esi]          ;eax should = TCD_SEGMENT
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
	mov dword [edi+20],segmentpaint
	mov dword [edi+24],segmentdelete
	mov dword [edi+28],segmentcopy
	mov dword [edi+32],segmentmove
	mov dword [edi+36],segmentmirror
	mov dword [edi+40],segmodify
	mov dword [edi+44],segmentwrite
	mov dword [edi+48],segmentread
	mov dword [edi+52],segmentselect
	mov dword [edi+56],segmentscale
	mov dword [edi+60],segmentdump
	mov dword [edi+64],segmentselectdrag
	mov dword [edi+68],segmentpdf

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

	;xmid
	fld  qword [esi+64]
	fstp qword [edi+112]

	;ymid
	fld  qword [esi+72]
	fstp qword [edi+120]


	;debug: esi=address of link, lets see what weve got
	;call DumpLink


	popad

	;at the start of this proc
	;esi pointed to the start of the object data
	;there are 80 bytes of object data in version=01
	;so now esi must point to the start of the next objects data
	;FileOpenTCD requires this
	add esi,80


	ret




;********************************************************
;segmentwrite  version=01  qtybytes=80

;this procedure is called when writting a tcd file
;the total qty bytes written must be an even multiple of 16
;pad with zeros if necessary. this is so each object in the 
;file starts on a 16 byte boundry and so is easy to read
;with xxd

;input:
;edi= destination memory address
;esi= address of segment in link list
;return:
;eax=qty bytes written
;*********************************************************

segmentwrite:

	push esi  ;must preserve


	;dword object type   offset 0
	mov [edi], dword TCD_SEGMENT
	add edi,4  ;inc the destination address


	;an 8 byte ascii string representing the name of the object
	;ascii bytes 'SEGMENT ' 
	mov byte [edi],0x53     ;S
	mov byte [edi+1],0x45   ;E
	mov byte [edi+2],0x47   ;G
	mov byte [edi+3],0x4d   ;M
	mov byte [edi+4],0x45   ;E
	mov byte [edi+5],0x4e   ;N
	mov byte [edi+6],0x54   ;T
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

	;qword xmid  offset 64
	fld qword [esi+112]
	fstp qword [edi]
	add edi,8

	;qword ymid  offset 72
	fld qword [esi+120]
	fstp qword [edi]
	add edi,8


	;return eax=qty bytes written
	mov eax,80

	pop esi  ;must restore
	;and edi is incremented by qty of bytes written 

	ret



;*********************************************
;segmentmove

;see notes for segment copy
;all we do is redefine object coordinates by 
;DeltaX and DeltaY

;input: 
;esi=address of segment to move 
;push address of qword DeltaX      [ebp+12]
;push address of qword DeltaY      [ebp+8]
;**********************************************

segmentmove:

	push ebp
	mov ebp,esp

	dumpstr str24

	;esi is address of selected link to move

	mov eax,[ebp+12]  ;eax=address of qword DeltaX
	mov ebx,[ebp+8]   ;ebx=address of qword DeltaY


	;x1=x1+[DeltaX]
	fld  qword [esi+80]
	fadd qword [eax] 
	fstp qword [esi+80] 
	;y1=y1+[DeltaY]
	fld  qword [esi+88] 
	fadd qword [ebx]
	fstp qword [esi+88] 
	;x2=x2+[DeltaX]
	fld  qword [esi+96] 
	fadd qword [eax]
	fstp qword [esi+96] 
	;y2=y2+[DeltaY]
	fld  qword [esi+104] 
	fadd qword [ebx]
	fstp qword [esi+104]


	call SaveMidPoint
	
	pop ebp
	retn 8  ;cleanup 2 args



;***************************************************
;segmentcopy
;function to create a child segment 
;that is offset from the parent segment
;X = X + [DeltaX]
;Y = Y + [DeltaY]
;qword [DeltaX] and [DeltaY] are generally determined
;by Left Mouse Copy Object when user makes 2 mouse clicks

;input: 
;esi=address of segment to copy  
;push address of qword DeltaX      [ebp+12]
;push address of qword DeltaY      [ebp+8]

;return:
;esi=address of new SEGMENT object
;****************************************************

segmentcopy:

	push ebp
	mov ebp,esp

	dumpstr str02


	;edi is address of parent segment
	mov edi,esi

	mov eax,[ebp+12]  ;eax=address of DeltaX
	mov ebx,[ebp+8]   ;ebx=address of DeltaY


	;this function takes no inputs
	call CreateBLink
	;returns esi = address of child segment 


	;new segment will have the same properties as the old
	mov dword [esi],TCD_SEGMENT      ;type=line


	;copy layer number
	mov ecx,[edi+4]
	mov [esi+4],ecx

	mov dword [esi+8],0           ;set as not selected
	mov dword [esi+12],2          ;qty points
	mov dword [esi+16],0          ;dat pointer
	mov dword [esi+20],segmentpaint  
	mov dword [esi+24],segmentdelete 
	mov dword [esi+28],segmentcopy   
	mov dword [esi+32],segmentmove   
	mov dword [esi+36],segmentmirror 
	mov dword [esi+40],segmodify 
	mov dword [esi+44],segmentwrite  
	mov dword [esi+48],segmentread   
	mov dword [esi+52],segmentselect 
	mov dword [esi+56],segmentscale  
	mov dword [esi+60],segmentdump
	mov dword [esi+64],segmentselectdrag
	mov dword [esi+68],segmentpdf

	;now get X1 then add DeltaX and save to new link X1
	fld  qword [edi+80] 
	fadd qword [eax]    ;x1+DeltaX
	fstp qword [esi+80] 

	;and repeat for Y1, X2, Y2
	fld  qword [edi+88] 
	fadd qword [ebx]    ;y1+DeltaY
	fstp qword [esi+88] 
	fld  qword [edi+96] 
	fadd qword [eax]    ;x2+DeltaX
	fstp qword [esi+96] 
	fld  qword [edi+104] 
	fadd qword [ebx]    ;y2+DeltaY
	fstp qword [esi+104] 

	call SaveMidPoint
	
	pop ebp
	retn 8  ;cleanup 2 args






;********************************************************
;segmentselect
;this is the object selection proc for segments
;this function is our line "hit test" function
;this function is called from IdleLeftMouseHandler

;first we test if mouse is within the 
;bounding box  defined by segment endpoints
;then we test if mouse is on the inifinite line

;if both tests pass then we toggle the segments selection state [esi+8]
;segment paint is responsible for drawing the line selected

;finally we build a complex string using printf
;that will display the segment properties:
;"x1,y1,x2,y2,length,angle"


;input:
;esi = address of SEGMENT object to check
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

;*********************************************************

segmentselect:

	push ebp
	mov ebp,esp
	sub esp,4  ;stack locals
	;[ebp-4]    ;saved address of object link

	dumpstr str1

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
	lea ebx,[esi+144]  ;address x1,y1,x2,y2 inflated clipped bounding box
	mov eax,86         ;tlib function ptinrect
	sysenter
	jnz .nopick        ;mouse is not within bounding box

	
	

	;segselbuf is a 32 byte buffer reserved
	;the first 16 bytes are mouse x,y where the user picked
	;the 2nd 16 bytes are the x,y point projected on the line
	;here we copy the mouse x,y to segselbuf
	mov eax,[ebp+12]  ;eax=address MOUSEXF
	fld  qword [eax]
	fstp qword [segselbuf]
	mov eax,[ebp+16]  ;eax=address MOUSEYF
	fld  qword [eax]
	fstp qword [segselbuf+8]



	;project Mouse point onto our line segment
	;the first 16 bytes of segselbuf is MOUSEXF,MOUSEYF
	;this function will fill in the last 16 bytes of segselbuf
	;with the projected point coordinates
	mov esi,[ebp-4]     ;address of object
	mov eax,98          ;tlib function projectpointtoline
	lea ebx,[esi+80]    ;ebx=address of our line segment
	mov ecx,segselbuf   
	sysenter




	;get length of segment defined by mouse x,y -> projected point
	;in floating obj coordinates
	mov eax,94        ;getslope
	mov ebx,segselbuf 
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



	;if we got here mouse is on the infinite line
	;we have a selection


	;now toggle the line selection state to 1,0,1,0...
	;this allows repeated left mouse clicks to change
	;the linetype from normal->selected->normal...
	mov esi,[ebp-4]
	mov eax,[esi+8]
	not eax          ;flip all bits
	and eax,1        ;mask off all but bit0
	mov [esi+8],eax  ;save selection state



	;now use printf to build a string
	;to display SEGMENT PROPERTIES
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



	;compute DX,DY,Length,Angle of segment
	lea ebx,[esi+80]
	mov eax,94        ;getslope
	;ebx= start of array of 4 qwords x1,y1,x2,y2
	sysenter          ;returns st0=dx, st=dy

	fst  qword [sel_DX]   ;save for Angle later
	fxch st1              ;st0=dy, st1=dx
	fst  qword [sel_DY]   ;save for Angle later
	fxch st1              ;st0=dx, st1=dy restored in proper order
	mov eax,95            ;getlength
	sysenter              ;st0=length




	fstp qword [sel_Length]
	fld  qword [sel_DY] 
	fld  qword [sel_DX]   ;st0=dx, st1=dy
	fpatan                ;st0=angle,radians
	mov eax,99            ;tlib function rad2deg
	sysenter              ;convert st0 to deg
	fstp qword [sel_Angle] 




	;save the layer, its included 
	mov eax,[esi+4]
	mov [sel_Layer],eax
	

	;call printf to build the segment properties string
	;the string looks like this:
	;x1=xxx y1=xxx x2=xxx y2=xxx dx=xxx dy=xxx len=xxx ang=xxx lay=xxx
	;the string is stored in a 100 byte buffer in the main module
	mov eax,57         ;printf
	mov ebx,segargtype
	mov ecx,QTYARGSEGPROP
	mov esi,segarglist
	mov edi,[ebp+20]   ;address printf buffer
	sysenter




	;we have a mouse pick on a line segment
	mov eax,1  ;selection = YES
	jmp .done


.nopick:
	dumpstr str1a
	mov eax,0   ;selection = NO

.done:
	mov esp,ebp  ;deallocate locals
	pop ebp
	retn 16









;**************************************************************
;segmentpaint

;this is the paint & hit testing proc for segments/lines

;a segment needs two endpoints
;this routine must properly handle the painting
;during all phases of object creation:
;	* before any points are defined [1]
;	* after 1 point is defined      [2]
;	* after both points are defined [3]

;[1] at qty points = 0 the new link is created after the user
;presses the 'L' key but the endpoints are not yet defined
;so we dont paint anything

;[2] at qty points = 1 the user has defined the first endpoint P1
;by either mouse click or keyboard entry so we draw a temp line
;from P1 to the mouse x,y

;[3] at qty points = 2 both endpoints P1 and P2 are defined so
;draw the line using its assigned layer properties


;input: 
;esi=address of SEGMENT object in link list to draw
;push address of qword zoom           [ebp+32]
;push address of qword xorg           [ebp+28]
;push address of qword yorg           [ebp+24]
;push dword [mousex] screen coord     [ebp+20]
;push dword [mousey] screen coord     [ebp+16]
;push address of qword MOUSEXF        [ebp+12]
;push address of qword MOUSEYF        [ebp+8]

;return:
;eax=0 mouse is not over an endpoint or near this segment
;eax=1 mouse is over segement start/mid/end point
;eax=2 mouse is "near" the segment somewhere between the endpoints
;ebx = X screen coordinates of YellowBoxPoint
;ecx = Y screen coordinates of YellowBoxPoint
;edx = address of YellowBoxPoint float coordinates for GetMousePoint

;***************************************************************

segmentpaint:

	push ebp
	mov ebp,esp
	sub esp,12  ;make space on stack for local variables
	;[ebp-4]  segment color
	;[ebp-8]  segment linetype (may be over ridden if selected)
	;[ebp-12] address of segment object in link list


	;save the object address for later since esi is often trashed
	mov [ebp-12],esi




	;retrieve the segments linetype & color from the layer index
	mov ecx,[esi+4]   ;ecx=segment layer index
	call GetLayItems
	;this function returns:
	;eax=layer name
	; bl=visibility
	; cl=color
	;edx=linetype
	;edi=dword [currentlayer]
	;esi=preserved
	mov [ebp-4],ecx    ;save segment color for later
	mov [ebp-8],edx    ;save segment linetype for later




	;through out this routine ebp must be preserved
	;we use this register to access input data on the stack

	;edi holds address of buffer to store unclipped endpoints
	;this buffer is used to draw a templine and
	;used to compute the clipped endpoints
	mov edi,UnclippedEndpoints

	;note esi and edi must be preserved
	;throughout this function across all tlib calls
	;esi=address of line segment
	;edi=address of UnclippedEndpoints
	;later on edi will hold address of the clipped endpoints


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


	;X1 convert to screen coordinates
	mov eax,[ebp+32]         ;eax=address zoom
	mov ebx,[ebp+28]         ;ebx=address xorg
	mov ecx,[ebp+24]         ;ecx=address yorg

	fld   qword [esi+80]     ;st0=X1
	fmul  qword [eax]        ;zoom
	fadd  qword [ebx]        ;st0=(X1*zoom) + xorg
	fistp dword [edi+0]      ;save x1 unclipped as pixel and pop fpu

	;Y1 convert
	fld   qword [esi+88] 
	fmul  qword [eax]
	fadd  qword [ecx]        ;st0=y1*zoom + yorg
	fistp dword [edi+4]      ;save y1 unclipped

	;X2,Y2 are defined by the mouse, usually




	;OrthoMode = "on"  draw horizontal or vertical temp line
	;OrthoMode = "off"  draw Oblique temp line
	;Ortho can be toggled on/off from the main menu
	cmp dword [OrthoMode],0
	jz .notOrtho



	;Templine-Horizontal
	;***********************
	;test if the user wants a horizontal line
	;if (MOUSEY-Y1) < somethreshold, we will force a horizontal line
	;autocadd calls this "ortho"

	mov ebx,[ebp+16]  ;ebx=mousey
	sub ebx,[edi+4]   ;ebx=mousey-y1
	mov eax,100       ;absval(b)
	sysenter
	cmp eax,10
	ja .notHorizontal

	;draw a horizontal temp line
	push esi             ;preserve
	push edi             ;preserve
	push ebp             ;preserve
	mov eax,30           ;draw line function
	mov ebx,[ebp-8]      ;linetype
	mov ecx,[edi+0]      ;x1
	mov edx,[edi+4]      ;y1
	mov esi,[ebp+20]     ;esi=mousex=x2
	mov edi,[edi+4]      ;y2=y1
	mov ebp,[ebp-4]      ;color
	sysenter
	pop ebp
	pop edi
	pop esi


	;save mousex,y1 to a temp buffer
	;and flag this as a yellowbox endpoint
	;otherwise after the 2nd mouse click 
	;the horizontal line will have P2 defined by the mouse x,y only
	;and our line will end up being not quite horizontal
	mov eax,[ebp+12]              ;eax=address MOUSEXF
	fld  qword [eax]              ;st0=MOUSEXF
	fstp qword [YellowBoxPoint]   ;x2
	fld  qword [esi+88]           ;y1
	fstp qword [YellowBoxPoint+8] ;y2=y1 horizontal

	;return values
	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,YellowBoxPoint   ;address YellowBoxPoint
	jmp .done
	
.notHorizontal:
	



	;Templine-Vertical
	;***********************
	;test if the user wants a vertical line
	;if (MOUSEX-X1) < somethreshold, we will force a vertical line

	mov ebx,[ebp+20]  ;mousex
	sub ebx,[edi+0]   ;x1
	mov eax,100       ;tlib function absval(b)
	sysenter
	cmp eax,10
	ja .notVertical

	;draw a Vertical temp line
	push esi             ;preserve
	push edi             ;preserve
	push ebp             ;preserve
	mov eax,30           ;draw line function
	mov ebx,[ebp-8]      ;linetype
	mov ecx,[edi+0]      ;x1
	mov edx,[edi+4]      ;y1
	mov esi,[edi+0]      ;x2=x1
	mov edi,[ebp+16]     ;y2=mousey
	mov ebp,[ebp-4]      ;color
	sysenter
	pop ebp
	pop edi
	pop esi



	;save x1,mousey to a temp buffer
	;and flag this as a yellowbox endpoint
	;otherwise after the 2nd mouse click 
	;the vertical line will have P2 defined by the mouse x,y only
	;and our line will end up being not quite vertical
	fld  qword [esi+80]           ;x2=x1
	fstp qword [YellowBoxPoint]
	mov eax,[ebp+8]               ;eax=address MOUSEYF
	fld  qword [eax]              ;y1=MOUSEYF
	fstp qword [YellowBoxPoint+8]

	;return values
	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,YellowBoxPoint   ;address YellowBoxPoint
	jmp .done
	
.notVertical:
.notOrtho:
	



	;Oblique templine
	;*********************
	;draw a general templine from P1 -> mouse
	push esi             ;preserve
	push edi             ;preserve
	push ebp             ;preserve
	mov eax,30           ;line
	mov ebx,[ebp-8]      ;linetype
	mov ecx,[edi+0]      ;x1
	mov edx,[edi+4]      ;y1
	mov esi,[ebp+20]     ;mousex
	mov edi,[ebp+16]     ;mousey
	mov ebp,[ebp-4]      ;color
	sysenter
	pop ebp
	pop edi
	pop esi

	;the templine does not get any yellow box testing
	;since the user can not pick P2 off the screen
	;and we assume he does not scroll P1 off the screen
	;if the user pans P1 off the screen the temp line will
	;not be drawn so you must zoom out instead
	jmp .doneNoReturn





.bothEndpointsDefined:


	;if we got here both endpoints are defined
	;*******************************************

	;convert the floating point line segment endpoints
	;to UNclipped screen/pixel coordinates


	;convert x1,y1 qword float to dword int
	lea esi,[esi+80]               ;address of x1,y1 float
	push esi
	mov edi,UnclippedEndpoints     ;address to store x1,y1 int
	call float2int


	;convert x2,y2 qword float to dword int
	pop esi
	add esi,16                      ;address of x2,y2 float
	lea edi,[UnclippedEndpoints+8]  ;address to store x2,y2 int
	call float2int
	





	;now clip the line endpoints to the 800x600 pixel screen
	;this is needed if the user pans segments off the screen
	push ebp      ;perserve
	mov eax,90    ;tlib function lineclip
	mov esi,UnclippedEndpoints
	mov ebp,[ebp-12]  ;address of segment object
	add ebp,160       ;address to store clipped screen coordinates
	sysenter
	;returns value in eax, 0=success, nonzero=failure
	pop ebp



	;returns eax=0 success clipped endpoints are written
	;if eax is non-zero then the line should not be drawn 
	;eax=1 general clipping error
	;eax=2 zero length line
	;eax=3 trivial reject, both endpoints not visible
	cmp eax,0
	jnz .lineClipFailure






	;esi=address of seg object
	mov esi,[ebp-12]


	;if we got here
	;segment is partial or totally exposed on the screen
	;if the object was previously off screen we will 
	;change the selected state from 
	;2=offscreen to "0=unselected
	;so that it may now be drawn and selected
	cmp dword [esi+8],2
	jnz .getLinetype

	dumpstr str79
	mov dword [esi+8],0  ;mark unselected


.getLinetype:

	;get the segment linetype from the link
	mov ebx,[ebp-8]      

	;is the segment selected ?
	cmp dword [esi+8],1  
	jnz .paintTheLine

	;over-ride the linetype with "selected" type
	mov ebx, 0xc2108420  




.paintTheLine:

	;if we got here all or part of the line segment is visible
	;use the line assigned layer properties
	;if selected we use special dashed line type
	;use clipped screen coordinates


	mov edi,[ebp-12]  ;address of segment object


	push esi             ;preserve
	push edi             ;preserve
	push ebp             ;preserve
	mov eax,30           ;draw line function
	;ebx=linetype
	mov ecx,[edi+160]    ;x1  clipped screen coordinates (pixels)
	mov edx,[edi+164]    ;y1     ditto
	mov esi,[edi+168]    ;x2     ditto
	mov edi,[edi+172]    ;y2     ditto
	mov ebp,[ebp-4]      ;color
	sysenter
	pop ebp              ;restore
	pop edi              ;restore
	pop esi              ;restore





	;*******************************************
	;Yellow Box Testing    (Mouse Hover)
	;*******************************************

	;we test here for mouse hover:
	; * mouse close to START point
	; * mouse close to END   point
	; * mouse close to MID   point
	; * mouse close to NEAR  point

	;the yellow box marker is drawn in main.s  paint routine
	;segment->paint returns values in eax,ebx,ecx,edx for this



	;copy clipped endpoints to InflatedBoundingBox
	cld
	mov esi,[ebp-12]  ;address of segment object
	add esi,160       ;address of clipped screen coordinates
	mov edi,InflatedBoundingBox
	mov ecx,16
	repmovsb


	;set size of InflatedBoundingBox
	;we need to do this otherwise the yellow "near" marker
	;will not show properly on horizontal or vertical lines
	;inflaterect will overwrite our original values with larger ones
	;it will also swap the coordinates so x2>x1 and y2>y1
	mov eax,120  ;inflaterect
	mov esi,InflatedBoundingBox
	mov edi,10   ;amount to inflate rect all around, pixels
	sysenter





	;save the InflatedBoundingBox coordinates to object link
	;for benefit of segmentselect 
	cld
	mov esi,InflatedBoundingBox
	mov edi,[ebp-12]  ;edi=address of object
	add edi,144       ;offset+144 in link stores these coordinates
	mov ecx,16
	repmovsb
	
	


	;is the mouse inside the bounding box ?
	;we are using the InflatedBoundingBox coordinates
	mov eax,86                   ;tlib function ptinrect
	mov ebx,InflatedBoundingBox  ;address x1,y1,x2,y2 rect corners
	mov ecx,[ebp+20]             ;mousex
	mov edx,[ebp+16]             ;mousey
	sysenter
	jnz .notNEAR     ;mouse is not within bounding box







	;START test
	;test for mouse close/over the START point P1
	;**********************************************

	;if the mouse is within 10 pixels of the START/END/MID
	;point we draw a yellow box. This allows one to pick the endpoint
	;of a line that falls on the imaginary extension of another line
	;just move the mouse slightly away from this endpoint to change
	;from "near" to "endpoint" select.


	;just make sure we have these important pointer set correctly
	mov esi,[ebp-12]  ;address of segment object



	;is mousex within 10 pixels of segment x1 ?
	mov ebx,[ebp+20]        ;mousex
	sub ebx,[esi+160]       ;x1 clipped screen coordinate
	mov eax,100             ;tlib function absval(b)
	sysenter                ;returns eax=|ebx|

	cmp eax,10              ;mouse must be within this many pixels
	ja .doneSTART           ;mouse is not close enough


	;is mousey within 10 pixels of segment y1 ?
	mov ebx,[ebp+16]        ;mousey
	sub ebx,[esi+164]       ;y1 clipped screen coordinate
	mov eax,100             ;tlib function absval(b)
	sysenter                ;returns eax=|ebx|

	cmp eax,10
	ja .doneSTART           ;mouse is not close enough


	;return values
	;the yellow box will be drawn in main.s paint routine
	mov eax,1          ;mouse is over P1 point
	mov ebx,[edi+0]    ;X screen coordinates of YellowBoxPoint
	mov ecx,[edi+4]    ;Y screen coordinates of YellowBoxPoint
	lea edx,[esi+80]   ;address of YellowBoxPoint float
	jmp .done

.doneSTART:






	;END test
	;test for mouse close to END point P2
	;*****************************************

	;is mousex within 10 pixels of segment x2 ?
	mov eax,100       ;tlib function absval(b)
	mov ebx,[ebp+20]  ;mousex
	sub ebx,[esi+168] ;x2 clipped screen coordinate
	sysenter

	cmp eax,10
	ja .doneEND


	;is mousey within 10 pixels of segment y2 ?
	mov eax,100       ;absval(b)
	mov ebx,[ebp+16]  ;mousey
	sub ebx,[esi+172] ;y2 clipped screen coordinate
	sysenter

	cmp eax,10
	ja .doneEND


	;return values
	;the yellow box will be drawn in main.s paint routine
	mov eax,1          ;mouse is over P2 point
	mov ebx,[edi+8]    ;X screen coordinates of YellowBoxPoint
	mov ecx,[edi+12]   ;Y screen coordinates of YellowBoxPoint
	lea edx,[esi+96]   ;address of YellowBoxPoint float
	jmp .done


.doneEND:




	;MID test
	;test for mouse close to MID point
	;************************************

	;the midpoint is now stored in the link
	;xmid=offset 112, ymid=offset 120


	;convert midpoint as dword screen coordinates Xmid,Ymid
	mov eax,[ebp+32]         ;eax=address zoom
	mov ebx,[ebp+28]         ;ebx=address xorg
	mov ecx,[ebp+24]         ;ecx=address yorg

	fld   qword [esi+112]  ;st0=xmid
	fmul  qword [eax]      ;tempx1*zoom
	fadd  qword [ebx]      ;tempX1*zoom + xorg
	fistp dword [Xmid]     ;save as Xmid
	fld   qword [esi+120]  ;st0=ymid
	fmul  qword [eax]      ;tempY1*zoom
	fadd  qword [ecx]      ;tempY1*zoom + yorg
	fistp dword [Ymid]     ;save as Ymid

	;now is mouse within 10 pixels ?
	mov eax,100      ;absval(b)
	mov ebx,[ebp+20] ;mousex
	sub ebx,[Xmid]
	sysenter
	cmp eax,10
	ja .doneMIDPOINT

	mov eax,100       ;absval(b)
	mov ebx,[ebp+16]  ;mousey
	sub ebx,[Ymid]
	sysenter
	cmp eax,10
	ja .doneMIDPOINT


	;return values
	;the yellow box will be drawn in main.s paint routine
	mov eax,1          ;mouse is over mid
	mov ebx,[Xmid]     ;X screen coordinates of YellowBoxPoint
	mov ecx,[Ymid]     ;Y screen coordinates of YellowBoxPoint
	lea edx,[esi+112]  ;address of YellowBoxPoint mid
	jmp .done


.doneMIDPOINT:





	;NEAR test
	;test for mouse anywhere along the line defined by endpoints
	;autocad calls this "near"
	;*******************************************************


	;save segment defined by mouse and projected point as vector5
	mov eax,[ebp+12]        ;address MOUSEXF
	fld  qword [eax]
	fstp qword [vector5]    ;x1
	mov ebx,[ebp+8]         ;address MOUSEYF
	fld  qword [ebx]
	fstp qword [vector5+8]  ;y1
	fldz                    ;init x2,y2 to zero
	fst  qword [vector5+16] ;x2 our projected point x = xnear
	fstp qword [vector5+24] ;y2 our projected point y = ynear


	;save points of our esi segment as vector6
	mov esi,[ebp-12]   ;esi=address of segment object
	fld  qword [esi+80]
	fstp qword [vector6]
	fld  qword [esi+88]
	fstp qword [vector6+8]
	fld  qword [esi+96]
	fstp qword [vector6+16]
	fld  qword [esi+104]
	fstp qword [vector6+24]



	;project mouse to segment
	;x2,y2 of vector5 is the projected point
	mov eax,98       ;projectpointtoline
	mov ebx,vector6  ;x1,y1,x2,y2
	mov ecx,vector5  ;MOUSEXF,MOUSEYF,0,0
	sysenter
	;returns ProjX,ProjY in the last 16 bytes of vector5



	;compute length of segment from mouse to projected point
	;this invisible segment is perpendicular to the selected segment
	mov eax,94       ;getslope
	mov ebx,vector5
	sysenter         ;st0=dx, st1=dy
	mov eax,95       ;getlength
	sysenter         ;st0=length


	;convert distance from float to pixel int
	;multiply floating point distance by zoom factor
	mov eax,[ebp+32]   ;eax=address zoom
	fmul  qword [eax]  ;st0=distance * zoom
	fistp dword [zoom_pixel]
	

	;we define "near" as mouse being within 5 pixels of the line
	cmp dword [zoom_pixel],5
	ja .doneNEAR  ;mouse is not "near"


	;if we got here mouse is near

	;convert projected point x,y from float2int screen coordinates
	lea esi,[vector5+16]
	mov edi,Xnear
	call float2int


	;save xnear,ynear to the object link
	mov esi,[ebp-12]  ;address of segment object
	fld  qword [vector5+16]
	fstp qword [esi+128]  ;save xnear
	fld  qword [vector5+24]
	fstp qword [esi+136]  ;save ynear


	;return values
	;the yellow "L" will be drawn in main.s paint routine
	mov eax,2             ;mouse is near
	mov ebx,[Xnear]       ;X screen coordinate of YellowBoxPoint
	mov ecx,[Ynear]       ;Y screen coordinate of YellowBoxPoint
	lea edx,[esi+128]     ;address of YellowBoxPoint
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

.lineClipFailure:

	;set segment select state ->2 to indicate 
	;object is off screen, if the object was previously 
	;selected, it will be not so
	;dumpstr str78
	mov esi,[ebp-12]   ;esi=address of object
	mov dword [esi+8],2

	;zero out the Clipped & Inflated screen coordinates
	cld
	mov ecx,16
	mov al,0
	lea edi,[esi+144]
	repstosb

	;use sparingly as this will flood the dump for every 
	;line that falls off the screen
	;dumpstr str38
	;fall thru

.notNEAR:
.doneNoReturn:
	;mouse is not over any endpoint or near this segment
	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,0

.done:
;return values are in eax,ebx,ecx,edx
;eax=0 mouse is not over an endpoint or near this segment
;eax=1 mouse is over segement start/mid/end point
;eax=2 mouse is "near" the segment somewhere between the endpoints
;ebx = X screen coordinates of YellowBoxPoint
;ecx = Y screen coordinates of YellowBoxPoint
;edx = address of YellowBoxPoint float coordinates for GetMousePoint

	mov esp,ebp       ;deallocate local variables
	pop ebp
	retn 28           ;cleanup 7 args on stack






;********************************************
;segcreate

;create a new link in the list by mouse picking
;user is prompted to make 2 Lclicks
;the segment gets assigned the current layer
;the segment endpoints are set to all 0.0
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
;esi=address of newly created line segment
;*********************************************

public segcreate

	push ebp
	mov ebp,esp

	dumpstr str104


	call CreateBLink
	;test return value, esi holds address of link


	;initialize values for the line object
	mov dword [esi],TCD_SEGMENT 
	mov eax,[ebp+8]        ;current layer
	mov [esi+4],eax        ;layer index
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],0   ;qty points defined so far
	mov dword [esi+16],0   ;dat pointer
	mov dword [esi+20],segmentpaint
	mov dword [esi+24],segmentdelete
	mov dword [esi+28],segmentcopy
	mov dword [esi+32],segmentmove
	mov dword [esi+36],segmentmirror
	mov dword [esi+40],segmodify
	mov dword [esi+44],segmentwrite
	mov dword [esi+48],segmentread
	mov dword [esi+52],segmentselect
	mov dword [esi+56],segmentscale
	mov dword [esi+60],segmentdump
	mov dword [esi+64],segmentselectdrag
	mov dword [esi+68],segmentpdf

	;and zero out the x1,y1,x2,y2,xmid,ymid endpoint coordinates
	fldz
	fst  qword [esi+80] 
	fst  qword [esi+88]  
	fst  qword [esi+96]  
	fst  qword [esi+104] 
	fst  qword [esi+112]
	fstp qword [esi+120]


	;save the object link address for the other segmentcreate procs
	mov [object],esi


	;set feedback message and LeftMouse handler
	mov eax,1   ;prompt user: <line> make 2 Lclicks
	mov ebx, segmentcreate_11  ;left mouse handler

	pop ebp
	retn 4




segmentcreate_11:

	;we got here after user made a Lclick to define 
	;the starting endpoint of a line segment

	dumpstr str104a

	call GetMousePnt
	;returns st0=MOUSEX, st1=MOUSEY (or yellowbox)

	;get address of segment we are creating
	mov esi,[object]

	;save x1,y1 to the link
	fstp qword [esi+80]  ;save st0->x and pop the fpu so y1=st0
	fstp qword [esi+88]  ;save st0->y  and pop the fpu

	;1 endpoint defined so far
	mov dword [esi+12],1

	;set feedback message and LeftMouse handler
	mov eax,1   ;prompt user: <line> make 2 Lclicks
	mov ebx,segmentcreate_22

	ret




segmentcreate_22:

	;we got here after user made a Lclick to define 
	;the ending endpoint of a line segment

	dumpstr str104b

	call GetMousePnt
	;returns st0=MOUSEX, st1=MOUSEY (or yellowbox)

	;get address of segment we are creating
	mov esi,[object]

	;save x2,y2 to the link
	fstp qword [esi+96]  ;save st0->x and pop the fpu so y1=st0
	fstp qword [esi+104] ;save st0->y  and pop the fpu

	;2 endpoints defined - done
	mov dword [esi+12],2  ;qty points


	;save midpoint to the link at offset xmid=112, ymid=120
	call SaveMidPoint


	;for debug: esi address of new segment
	;call DumpLink


	;return new left mouse handler
	mov eax,0   ;default feedback message
	mov ebx,0   ;default left mouse handler



	ret




;********************************************************
;segcreatek

;create a new segment via the keyboard
;user is prompted to enter both endpoints via keyboard

;the first endpoint must be entered as absolute x,y

;the 2nd endpoint may be entered as:
; x,y           [, seperated value absolute]
; length<angle  [< seperated value relative]
; dx+dy         [+ seperated value relative]


;*********************************************************

public segcreatek

	dumpstr str23

	;prompt user to enter x,y values
	mov esi,str17   ;address of comprompt string
	call GetKeyboardPoint

	;return:
	;eax=0 no input, user hit ESC, unknown values entered
	;eax=1 absolute x,y
	;eax=2 relative length<angle
	;eax=3 relative dx+dy
	;ebx=address 1st qword value
	;ecx=address 2nd qword value

	cmp eax,0  ;no input
	jz .done

	;save x,y starting point
	fld qword [ebx]
	fstp qword [X1]
	fld qword [ecx]
	fstp qword [Y1]


	;prompt user to enter ending point
	mov esi,str18   ;address of comprompt string
	call GetKeyboardPoint

	cmp eax,0  ;no input
	jz .done

	;save ending point values, these may be absolute or relative
	fld qword [ebx]
	fstp qword [X2]
	fld qword [ecx]
	fstp qword [Y2]


	cmp eax,1
	jz .3
	cmp eax,2
	jz .1
	cmp eax,3
	jz .2


.1:  
	;length<angle
	;given: 
	;X2=length, Y2=angle
	;we compute:
	;x2 = x1 + length * cos(angle)
	;y2 = y1 + length * sin(angle)

	fld qword [Y2]         ;st0=angle,deg
	fmul qword [deg2rad]   ;st0=angle,rad
	fsincos                ;st0=cos(angle), st1=sin(angle)
	fmul qword [X2]        ;st0=length*cos(angle) st1=...
	fadd qword [X1]        ;x2=x1+length*cos(angle) st1=...
	fxch st1               ;st0=sin(angle), st1=x1+...
	fmul qword [X2]        ;st0=length*sin(angle) st1=...
	fadd qword [Y1]        ;y2=y1+length*sin(angle) st1=...
	fstp qword [Y2]
	fstp qword [X2]
	jmp .3



.2:
     ;dx+dy
	;given: 
	;X2=dx, Y2=dy
	;we compute: 
	;x2=x1+dx, y2=y1+dy

	fld  qword [X1]  ;st0=X1
	fadd qword [X2]  ;st0=X1+dx
	fstp qword [X2]  ;save X2=X1+dx
	fld  qword [Y1]  ;st0=Y1
	fadd qword [Y2]  ;st0=Y1+dy
	fstp qword [Y2]  ;save Y2=Y1+dy

.3:

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


	;create new link, assign default handlers, assign endpoints

	call CreateBLink
	;test return value, esi holds address of link


	;initialize values for the line object
	mov dword [esi],TCD_SEGMENT 
	mov [esi+4],edi        ;layer index
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],2   ;qty points
	mov dword [esi+16],0   ;dat pointer
	mov dword [esi+20],segmentpaint 
	mov dword [esi+24],segmentdelete 
	mov dword [esi+28],segmentcopy   
	mov dword [esi+32],segmentmove   
	mov dword [esi+36],segmentmirror 
	mov dword [esi+40],segmodify 
	mov dword [esi+44],segmentwrite
	mov dword [esi+48],segmentread   
	mov dword [esi+52],segmentselect 
	mov dword [esi+56],segmentscale  
	mov dword [esi+60],segmentdump
	mov dword [esi+64],segmentselectdrag
	mov dword [esi+68],segmentpdf

	;and assign endpoint coordinates to the object link
	fld  qword [X1]
	fstp qword [esi+80]
	fld  qword [Y1]
	fstp qword [esi+88]
	fld  qword [X2]
	fstp qword [esi+96]
	fld  qword [Y2]
	fstp qword [esi+104]


	;save midpoint to the link at offset xmid=112, ymid=120
	call SaveMidPoint

.done:
	ret







;***************************************************************
;segcreatemk

;create a new segment with mouse and keyboard
;user is prompted to mouse pick the 1st endpoint

;the 2nd endpoint may be entered as:
; x,y           [, seperated value absolute]
; length<angle  [< seperated value relative]
; dx+dy         [+ seperated value relative]

;input:none
;return:
;eax=feedback message index
;ebx=left mouse handler

;****************************************************************

public segcreatemk

	dumpstr str25

	;feedback message to prompt user to pick starting point
	mov eax,63

	;set new left mouse handler
	mov ebx,segmentcreatemk_11

	ret


segmentcreatemk_11:

	dumpstr str26

	;this is a left mouse handler
	;we got here after user selected the starting endpoint

	call GetMousePnt
	;returns st0=MOUSEX, st1=MOUSEY (or yellowbox)

	;save the starting point temporarily
	fstp qword [X1]
	fstp qword [Y1]


	;the code from here on down is almost identical
	;to segmentcreatek


	;prompt user to enter endpoint via keyboard
	mov esi,str27   ;address of comprompt string
	call GetKeyboardPoint

	;return:
	;eax=0 no input, user hit ESC, unknown values entered
	;eax=1 absolute x,y
	;eax=2 relative length<angle
	;eax=3 relative dx+dy
	;ebx=address 1st qword value
	;ecx=address 2nd qword value

	cmp eax,0  ;no input
	jz .done

	;save ending point values, these may be absolute or relative
	fld qword [ebx]
	fstp qword [X2]
	fld qword [ecx]
	fstp qword [Y2]

	cmp eax,1
	jz .3
	cmp eax,2
	jz .1
	cmp eax,3
	jz .2


.1:  
	;length<angle
	;given: 
	;X2=length, Y2=angle
	;we compute:
	;x2 = x1 + length * cos(angle)
	;y2 = y1 + length * sin(angle)

	fld qword [Y2]         ;st0=angle,deg
	fmul qword [deg2rad]   ;st0=angle,rad
	fsincos                ;st0=cos(angle), st1=sin(angle)
	fmul qword [X2]        ;st0=length*cos(angle) st1=...
	fadd qword [X1]        ;x2=x1+length*cos(angle) st1=...
	fxch st1               ;st0=sin(angle), st1=x1+...
	fmul qword [X2]        ;st0=length*sin(angle) st1=...
	fadd qword [Y1]        ;y2=y1+length*sin(angle) st1=...
	fstp qword [Y2]
	fstp qword [X2]
	jmp .3



.2:
     ;dx+dy
	;given: 
	;X2=dx, Y2=dy
	;we compute: 
	;x2=x1+dx, y2=y1+dy

	fld  qword [X1]  ;st0=X1
	fadd qword [X2]  ;st0=X1+dx
	fstp qword [X2]  ;save X2=X1+dx
	fld  qword [Y1]  ;st0=Y1
	fadd qword [Y2]  ;st0=Y1+dy
	fstp qword [Y2]  ;save Y2=Y1+dy

.3:

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


	;create new link, assign default handlers, assign endpoints

	call CreateBLink
	;test return value, esi holds address of link


	;initialize values for the line object
	mov dword [esi],TCD_SEGMENT 
	mov [esi+4],edi        ;layer index
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],2   ;qty points
	mov dword [esi+16],0   ;dat pointer
	mov dword [esi+20],segmentpaint 
	mov dword [esi+24],segmentdelete 
	mov dword [esi+28],segmentcopy   
	mov dword [esi+32],segmentmove   
	mov dword [esi+36],segmentmirror 
	mov dword [esi+40],segmodify 
	mov dword [esi+44],segmentwrite
	mov dword [esi+48],segmentread   
	mov dword [esi+52],segmentselect 
	mov dword [esi+56],segmentscale  
	mov dword [esi+60],segmentdump
	mov dword [esi+64],segmentselectdrag
	mov dword [esi+68],segmentpdf

	;and assign endpoint coordinates to the object link
	fld  qword [X1]
	fstp qword [esi+80]
	fld  qword [Y1]
	fstp qword [esi+88]
	fld  qword [X2]
	fstp qword [esi+96]
	fld  qword [Y2]
	fstp qword [esi+104]


	;save midpoint to the link at offset xmid=112, ymid=120
	call SaveMidPoint

.done:

	;must assign these or will get a page fault
	mov eax,0  ;default feedback message
	mov ebx,0  ;default left mouse handler

	ret






;******************************************************
;segcreateMI

;create a segment with Mouse and Intersection

;the 1st point is a mouse pick end/mid/near/scratch
;the 2nd point is at the intersection of 2 existing segments

;input:follow the prompts
;return:none

linemi_P1x:
dq 0.0
linemi_P1y:
dq 0.0
linemi_seg1:
dd 0
linemi_seg2:
dd 0
;*******************************************************

public segcreateMI

	dumpstr str70

	;feedback message to prompt user to make mouse pick for P1
	mov eax,80 ;feedback message index
	mov ebx,segmentcreateMI_11 ;left mouse handler

	ret



segmentcreateMI_11:

	;this is a left mouse handler
	;we got here after user selected P1

	dumpstr str71

	;get P1
	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save P1
	fstp qword [linemi_P1x]
	fstp qword [linemi_P1y]


	;feedback message to prompt user to pick seg1 for intersection
	mov eax,81 ;feedback message index
	mov ebx,0  ;idle left mouse handler
	mov dword [PassToPaint],segmentcreateMI_22

	ret


segmentcreateMI_22:

	;this is a post paint handler
	;we got here after user picked seg1 for intersection

	dumpstr str72

	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,1   ;do we have 1 selected object ?
	jnz .error

	;save address of seg1
	mov [linemi_seg1],ebx

	;prompt user to select seg2 for intersection
	mov eax,82  ;feedback message index
	mov ebx,0   ;idle left mouse handler
	mov dword [PassToPaint],segmentcreateMI_33
	jmp .done

.error:
	dumpstr str53  ;insufficient selections
	mov eax,0
	mov ebx,0
.done:
	ret




segmentcreateMI_33:

	dumpstr str73

	;this is a post paint handler
	;we got here after user selected seg2 for intersection

	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,2   ;do we have 2 selected objects ?
	jnz .error

	;determine which of the selected objects is seg2
	cmp ebx,[linemi_seg1]
	jz .1

	;the 1st selected object is seg2
	mov [linemi_seg2],ebx
	jmp .2

.1:  ;the 1st selected object is seg1
	mov [linemi_seg2],ecx

.2:

	;set address of endpoints for intersection
	mov esi,[linemi_seg1]
	add esi,80
	;esi=starting address of x1,y1,x2,y2 endpoints for seg1
	mov edi,[linemi_seg2]
	add edi,80
	;edi=starting address of x1,y1,x2,y2 endpoints for seg2


	;compute intersection point P1
	mov eax,96          ;tlib intersection function
	mov ebx,esi         ;address seg1
	mov ecx,edi         ;address seg2
	mov edx,pIntersect  ;storage for intersection point
	sysenter
	cmp eax,0
	jnz .error   ;no intersection, lines are parallel



	;get the current layer information
	mov ecx,0  ;dumy layer index
	call GetLayItems
	;this function returns:
	;eax=layer name
	; bl=visibility
	; cl=color
	;edx=linetype
	;edi=dword [currentlayer]
	;esi=preserved


	;create new segement
	call CreateBLink
	;test return value, esi holds address of link


	;initialize values for the line object
	mov dword [esi],TCD_SEGMENT 
	mov [esi+4],edi        ;layer index from GetLayerItems
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],2   ;qty points defined=2
	mov dword [esi+16],0   ;dat pointer=null
	mov dword [esi+20],segmentpaint
	mov dword [esi+24],segmentdelete
	mov dword [esi+28],segmentcopy
	mov dword [esi+32],segmentmove
	mov dword [esi+36],segmentmirror
	mov dword [esi+40],segmodify
	mov dword [esi+44],segmentwrite
	mov dword [esi+48],segmentread
	mov dword [esi+52],segmentselect
	mov dword [esi+56],segmentscale
	mov dword [esi+60],segmentdump
	mov dword [esi+64],segmentselectdrag
	mov dword [esi+68],segmentpdf


	;save x1,y1,x2,y2 endpoint coordinates to the object link
	fld  qword [linemi_P1x]
	fstp qword [esi+80]
	fld  qword [linemi_P1y]
	fstp qword [esi+88]
	fld  qword [pIntersect]
	fstp qword [esi+96]
	fld  qword [pIntersect+8]
	fstp qword [esi+104]

	;save the mid point to the link
	call SaveMidPoint


.error:
	mov eax,0   ;new feedback message index
	mov ebx,0   ;left mouse handler
	call UnselectAll
	ret






;*************************************************************
;segcreMPD2
;create segment with P1=mouse pick end/mid/near/scratch
;and P2 is perpendicular-to and coincident to an existing segment
;input:follow the prompts
;return:none
;***************************************************************

public segcreMPD2

	dumpstr str67

	;feedback message to prompt user to make mouse pick for P1
	mov eax,83 ;feedback message index
	mov ebx,segmentcreateMPD2_11 ;left mouse handler

	ret



segmentcreateMPD2_11:

	dumpstr str68

	;this is a left mouse handler
	;we got here after user selected P1 endpoint

	;get P1
	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF

	;save P1 to vector1
	fstp qword [vector1]
	fstp qword [vector1+8]
	;and zero out x2,y2
	fldz
	fst  qword [vector1+16]
	fstp qword [vector1+24]


	;feedback message to prompt user to pick seg1 for perpendicular-to
	mov eax,84 ;feedback message index
	mov ebx,0  ;idle left mouse handler
	mov dword [PassToPaint],segmentcreateMPD2_22

	ret



segmentcreateMPD2_22:

	dumpstr str69

	;this is a post paint handler
	;we got here after user selected a segment to be perpendicular-to

	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,1   ;do we have 1 selected object ?
	jnz .done


	;get address of the endpoints of the perpendicular-to segment
	add ebx,80

	;vector1 consists of 4 qwords x1,y1,x2,y2
	;x1,y1 is P1 the users first mouse pick
	;x2,y2 is the endpoint of our new line segment that is
	;perpendicular-to and coincident with


	;compute x2,y2 using tlib function projectpointtoline
	mov eax,98        ;projectpointtoline
	;ebx = address of ;Line12 perpendicular-to line
	mov ecx,vector1  
	sysenter
	;x2,y2 is written to vector1 offsets 16,24



	;get the current layer information
	mov ecx,0  ;dumy layer index
	call GetLayItems
	;this function returns:
	;eax=layer name
	; bl=visibility
	; cl=color
	;edx=linetype
	;edi=dword [currentlayer]
	;esi=preserved


	;create new segement
	call CreateBLink
	;test return value, esi holds address of link


	;initialize values for the line object
	mov dword [esi],TCD_SEGMENT 
	mov [esi+4],edi        ;layer index from GetLayerItems
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],2   ;qty points defined=2
	mov dword [esi+16],0   ;dat pointer=null
	mov dword [esi+20],segmentpaint
	mov dword [esi+24],segmentdelete
	mov dword [esi+28],segmentcopy
	mov dword [esi+32],segmentmove
	mov dword [esi+36],segmentmirror
	mov dword [esi+40],segmodify
	mov dword [esi+44],segmentwrite
	mov dword [esi+48],segmentread
	mov dword [esi+52],segmentselect
	mov dword [esi+56],segmentscale
	mov dword [esi+60],segmentdump
	mov dword [esi+64],segmentselectdrag
	mov dword [esi+68],segmentpdf


	;and save the x1,y1,x2,y2 endpoint coordinates to the object link
	fld  qword [vector1]
	fst  qword [esi+80]
	fld  qword [vector1+8]
	fstp qword [esi+88]
	fld  qword [vector1+16]
	fst  qword [esi+96]
	fld  qword [vector1+24]
	fst  qword [esi+104]

	call SaveMidPoint


.done:
	mov eax,0  ;feedback message index
	mov ebx,0  ;left mouse handler
	call UnselectAll
	ret





;***********************************************************
;segcreIPD2
;create a segment where P1 is defined by the intersection
;of 2 lines and the new segment is perpendicular-to another
;segment and P2 is coincident to the perpendicular-to segment
;input:follow the prompts
;return:none
;***********************************************************

public segcreIPD2

	dumpstr str74

	;feedback message to prompt user to select seg1 for intersection
	mov eax,85 ;feedback message index
	mov ebx,0  ;default left mouse handler
	mov dword [PassToPaint],segmentcreateIPD2_11

	ret



segmentcreateIPD2_11:

	dumpstr str75

	;this is a post paint handler
	;we got here after user picked seg1 for intersection

	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,1   ;do we have 1 selected object ?
	jnz .error

	;save seg1 address
	mov [Segment1],ebx


	;feedback message to prompt user to select seg2 for intersection
	mov eax,86 ;feedback message index
	mov ebx,0  ;default left mouse handler
	mov dword [PassToPaint],segmentcreateIPD2_22
	jmp .done

.error:
	mov eax,0
	mov ebx,0
.done:
	ret




segmentcreateIPD2_22:

	dumpstr str76

	;this is a post paint handler
	;we got here after user picked seg2 for intersection

	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,2   ;do we have 2 selected objects ?
	jnz .error

	;determine which of the selected objects is seg2
	cmp ebx,[Segment1]
	jz .1

	;the 1st selected object is seg2
	mov [Segment2],ebx
	jmp .2

.1:  ;the 1st selected object is seg1
	mov [Segment2],ecx

.2:

	;feedback message to prompt user to select perpendicular-to segment
	mov eax,87 ;feedback message index
	mov ebx,0  ;default left mouse handler
	mov dword [PassToPaint],segmentcreateIPD2_33
	call UnselectAll
	jmp .done

.error:
	mov eax,0
	mov ebx,0
.done:
	ret




segmentcreateIPD2_33:

	dumpstr str77

	;this is a post paint handler
	;we got here after user selected segment to be perpendicular to 

	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,1   ;do we have 1 selected object ?
	jnz .error

	;save seg3 address of segment to be perpendicular to 
	mov [Segment3],ebx


	;set address of endpoints for intersection
	mov esi,[Segment1]
	add esi,80
	;esi=starting address of x1,y1,x2,y2 endpoints for seg1
	mov edi,[Segment2]
	add edi,80
	;edi=starting address of x1,y1,x2,y2 endpoints for seg2


	;compute intersection point P1
	mov eax,96          ;tlib intersection function
	mov ebx,esi         ;address seg1
	mov ecx,edi         ;address seg2
	mov edx,vector1     ;storage for intersection point
	sysenter
	cmp eax,0
	jnz .error   ;no intersection, lines are parallel

	;clear out offsets 16,24 of vector1
	;this will become P2 of new segment
	fldz
	fst  qword [vector1+16]
	fstp qword [vector1+24]


	;get address of endpoints for Segment3
	mov esi,[Segment3]
	add esi,80


	;compute x2,y2 using tlib function projectpointtoline
	mov eax,98          ;projectpointtoline
	mov ebx,esi         ;address of Line12
	mov ecx,vector1     ;address of Line34 
	sysenter
	;x2,y2 is written to vector1 offsets 16,24



	;get the current layer information
	mov ecx,0  ;dumy layer index
	call GetLayItems
	;this function returns:
	;eax=layer name
	; bl=visibility
	; cl=color
	;edx=linetype
	;edi=dword [currentlayer]
	;esi=preserved


	;create new segement
	call CreateBLink
	;test return value, esi holds address of link


	;initialize values for the line object
	mov dword [esi],TCD_SEGMENT 
	mov [esi+4],edi        ;layer index from GetLayerItems
	mov dword [esi+8],0    ;visibility state = unselected
	mov dword [esi+12],2   ;qty points defined=2
	mov dword [esi+16],0   ;dat pointer=null
	mov dword [esi+20],segmentpaint
	mov dword [esi+24],segmentdelete
	mov dword [esi+28],segmentcopy
	mov dword [esi+32],segmentmove
	mov dword [esi+36],segmentmirror
	mov dword [esi+40],segmodify
	mov dword [esi+44],segmentwrite
	mov dword [esi+48],segmentread
	mov dword [esi+52],segmentselect
	mov dword [esi+56],segmentscale
	mov dword [esi+60],segmentdump
	mov dword [esi+64],segmentselectdrag
	mov dword [esi+68],segmentpdf


	;and save the x1,y1,x2,y2 endpoint coordinates to the object link
	fld  qword [vector1]
	fst  qword [esi+80]
	fld  qword [vector1+8]
	fstp qword [esi+88]
	fld  qword [vector1+16]
	fst  qword [esi+96]
	fld  qword [vector1+24]
	fst  qword [esi+104]

	call SaveMidPoint



.error:
.done:
	mov eax,0
	mov ebx,0
	call UnselectAll
	ret
	



;*************************************************************
;OffsetSegK
;Offset Segment via Keyboard
;create one new segment that is parallel/offset from existing
;user must enter amount to offset from the keyboard

;x1,y1,x2,y2 are endpoints of the selected line segment to offset
;x3,y3,x4,y4 are the endpoints of the new offset line segment

;input:none
;return:
;eax=feedback message index
;ebx=left mouse handler

;**************************************************************

public OffsetSegK

	dumpstr str56

	;prompt the user to select objects to offset
	mov eax,14   ;FeedbackMessageIndex

	;set left mouse handler for object selection
	mov ebx,0   ;IdleLeftMouseHandler

	mov dword [PassToPaint],OffsetSegmentK_11

	call UnselectAll

	ret



OffsetSegmentK_11:

	;this is a post paint handler
	;we got here after user selected a segment to offset
	;and one paint cycle was completed

	dumpstr str57

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .error  ;failed to find a selected segment

	mov [object],ebx  ;save address of selected segment


	;get the amount of offset from user via keyboard
	;user may use the "f" flip key to change direction of offset
	mov eax,54            ;comprompt
	mov ebx,str58         ;prompt string
	mov ecx,compromptbuf  ;dest buffer
	sysenter
	jnz .done  ;user hit ESC

	mov eax,93           ;str2st0
	mov ebx,compromptbuf
	sysenter             ;st0=amount to offset
	fstp qword [offset]  ;save amount of offset for later


	mov eax,[object]
	lea edx,[eax+80] ;starting address of endpoints of selected seg
	;global qword [offset] is defined by keyboard entry already
	call OffsetSegmentMakeNewLink
	jmp .done

.error:
	mov eax,53  ;feedback message "no selection"
	mov ebx,0   ;default left mouse handler
	ret
.done:
	mov eax,0   ;default feedback message
	mov ebx,0   ;default left mouse handler
	ret         ;done offset segment via keyboard






;************************************************************
;OffsetSegmentMakeNewLink
;this function does the work of creating a new link
;and defining its endpoints as offset 
;it also defines the flip key handler

;input:
;edx=starting address of endpoints of segment to be offset
;global qword [offset] holds the amount of offset
;return: new offset link with defined endpoints
;*************************************************************

OffsetSegmentMakeNewLink:

	push edx    ;preserve
	mov ecx,0   ;dumy layer index
	call GetLayItems
	;returns many items including edi=dword [currentlayer]
	pop edx

	;create a new segment object
	call CreateBLink
	mov dword [esi],TCD_SEGMENT     ;type=line
	mov [esi+4],edi               ;current layer
	mov dword [esi+8],0           ;visibility state = unselected
	mov dword [esi+12],2          ;qty points
	mov dword [esi+16],0          ;dat pointer
	mov dword [esi+20],segmentpaint  
	mov dword [esi+24],segmentdelete 
	mov dword [esi+28],segmentcopy   
	mov dword [esi+32],segmentmove   
	mov dword [esi+36],segmentmirror 
	mov dword [esi+40],segmodify 
	mov dword [esi+44],segmentwrite  
	mov dword [esi+48],segmentread   
	mov dword [esi+52],segmentselect 
	mov dword [esi+56],segmentscale  
	mov dword [esi+60],segmentdump
	mov dword [esi+64],segmentselectdrag
	mov dword [esi+68],segmentpdf



	;now use tlib offset function 
	;to determine new segment endpoints x3,y3,x4,y4
	;this function will save directly to our link list offset object
	mov eax,111        ;tlib function "offset"
	mov ebx,edx        ;address of endpoints of selected segment
	mov [Segment1],ebx ;save for flip
	lea ecx,[esi+80]   ;address new offset segment endpoints
	mov [Segment2],ecx ;save for flip
	mov edx,offset     ;address qword amount of offset
	sysenter

	
.done:
	;reset left mouse & ENTER handlers & feedback message to defaults
	mov eax,0   ;feedback message index
	mov ebx,0   ;default left mouse handler
	mov dword [EntrKeyProc],0
	mov dword [FlipKeyProc],OffsetFlipHandler
	call UnselectAll
	ret





OffsetFlipHandler:
	;if you dont like the direction of the offset
	;just press the "f" key to change the sign of the offset amount
	;and recalculate the new segment endpoints
	;or user could have entered + or - offset 

	fld qword [offset]
	fchs  ;change sign
	fstp qword [offset]

	;let tlib compute new segment x1,y1,x2,y2 endpoints
	mov eax,111        ;offset
	mov ebx,[Segment1] ;address of endpoints of selected segment
	mov ecx,[Segment2] ;address new segment endpoints
	mov edx,offset     ;address qword amount of offset
	sysenter

	ret










;***************************************************
;OffsetSegM
;Offset Segment via the Mouse
;user is prompted to select a segment to offset
;then make a mouse pick out in space or select an 
;existing enpoint to determine the amount of offset

off_Segment1:
dd 0
;***************************************************

public OffsetSegM

	dumpstr str59

	;prompt the user to select objects to offset
	mov eax,14   ;FeedbackMessageIndex

	;set left mouse handler for object selection
	mov ebx,0   ;IdleLeftMouseHandler

	mov dword [PassToPaint],OffsetSegmentM_11

	call UnselectAll

	ret



OffsetSegmentM_11:

	;this is a post paint handler
	;we got here after user selected a segment to offset
	;and one paint cycle was completed

	dumpstr str60

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .error  ;failed to find a selected segment

	mov [off_Segment1],ebx  ;save address of selected segment to offset

	;now prompt user to make a mouse click to define
	;the amount of offset, this may be on an endpoint
	;or out in space
	mov eax,21 ;feedback message index
	mov ebx,0  ;idle left mouse handler
	mov dword [PassToPaint],OffsetSegmentM_22

.error:
	ret




OffsetSegmentM_22:

	;this is a Post Paint handler
	;we got here after the user made a Lclick 
	;to define amount of offset
	;and one paint cycle was completed

	dumpstr str61

	;get point to offset to
	;call GetMousePoint, returns st0=MOUSEXF, st1=MOUSEYF
	call GetMousePnt

	fstp qword [X1] ;X1=MOUSEXF
	fstp qword [Y1] ;Y1=MOUSEYF

	;zero out the projected point
	fldz
	fst  qword [X2] ;X2 of projected point, init=0
	fstp qword [Y2] ;Y2 of projected point, init=0


	;project point to selected segment
	mov eax,98           ;projectpointtoline
	mov ebx,[off_Segment1]
	lea ebx,[ebx+80]     ;x1,y1,x2,y2 of segment to offset
	mov ecx,X1           ;X1,Y1,X2,Y2 where X2,Y2=0
	sysenter            
	;returns projected point in X2,Y2
	

	;compute DX,DY from mouse to projected point
	fld  qword [X1]
	fsub qword [X2]  ;st0=X1-X2=DX
	fld  qword [Y1]  ;st0=Y1, st1=DX
	fsub qword [Y2]  ;st0=Y1-Y2=DY, st1=DX
	

	;get layer information
	push edx    ;preserve
	mov ecx,0   ;dumy layer index
	call GetLayItems
	;returns many items including edi=dword [currentlayer]
	pop edx

	;create a new segment object
	call CreateBLink
	mov dword [esi],TCD_SEGMENT     ;type=line
	mov [esi+4],edi                 ;current layer
	mov dword [esi+8],0             ;visibility state = unselected
	mov dword [esi+12],2            ;qty points
	mov dword [esi+16],0            ;dat pointer
	mov dword [esi+20],segmentpaint  
	mov dword [esi+24],segmentdelete 
	mov dword [esi+28],segmentcopy   
	mov dword [esi+32],segmentmove   
	mov dword [esi+36],segmentmirror 
	mov dword [esi+40],segmodify 
	mov dword [esi+44],segmentwrite  
	mov dword [esi+48],segmentread   
	mov dword [esi+52],segmentselect 
	mov dword [esi+56],segmentscale  
	mov dword [esi+60],segmentdump
	mov dword [esi+64],segmentselectdrag
	mov dword [esi+68],segmentpdf


	;now add DX,DY to Segment1 endpoint coordinates
	;these are the endpoint coordinates of the offset segment
	;I am using this method instead of OffsetSegmentMakeNewLink
	;because this method puts the new offset segment exactly
	;where you mouse pick, whereas OffsetSegmentMakeNewLink
	;may put the segment on the wrong side and force you to use
	;the flip key handler
	mov eax,[off_Segment1]
	fld  qword [eax+80]  ;st0=x1, st1=DY, st2=DX
	fadd st2             ;st0=x1+DX, ...
	fstp qword [esi+80]  ;save x1 offset segment

	fld  qword [eax+88]  ;st0=y1, st1=DY, st2=DX
	fadd st1             ;st0=y1+DY, ...
	fstp qword [esi+88]  ;save y1 offset segment

	fld  qword [eax+96]  ;st0=x2, ...
	fadd st2             ;st0=x2+DX, ...
	fstp qword [esi+96]  ;save x2 offset segment

	fld  qword [eax+104] ;st0=y2, ...
	fadd st1             ;st0=y2+DY, ...
	fstp qword [esi+104] ;save y2 offset segment

	ffree st0
	ffree st1


	call SaveMidPoint

.done:
	mov eax,0  ;default feedback message
	mov ebx,0  ;default left mouse handler
	mov dword [FlipKeyProc],OffsetFlipHandler
	call UnselectAll
	ret 








;******************************************************************
;RotateSegK
;Rotate Segment via Keyboard
;rotate one or more objects via keyboard input
;rotation is relative to its current position

;actions occur in the following order:
;[1] user is prompted to select objects then hit ENTER
;[2] user is prompted to enter rotation angle, degrees
;[3] user is prompted to select the xc,yc rotation point with mouse
;*******************************************************************

public RotateSegK

	;prompt the user to select segments to rotate & hit ENTER
	mov eax,13  ;feedback message index

	;set left mouse handler for object selection
	mov ebx,0   ;IdleLeftMouseHandler

	;after objects are selected, user must hit ENTER
	mov dword [EntrKeyProc],RotateSegmentsK_11

	call UnselectAll

	ret




RotateSegmentsK_11:

	;this is an ENTER key handler

	;prompt the user to enter rotation angle
	mov eax,54           ;comprompt
	mov ebx,str40        ;prompt string
	mov ecx,compromptbuf ;dest buf
	sysenter
	jnz .done  ;user hit ESC

	;convert to float
	mov eax,93            ;str2st0
	mov ebx,compromptbuf  
	sysenter              ;st0=angle,deg
	fmul qword [deg2rad]  ;st0=angle,rad
	fstp qword [Angle]    ;save the rotation angle as radians

	;and tell the user to pick the center of rotation
	mov eax,5  ;feedback message index
	mov dword [LftMousProc],RotateSegmentsK_22

.done:
	ret



RotateSegmentsK_22:

	;this is a left mouse handler

	;esi=address of headlink
	;all left mouse handlers get esi=address of headlink

	;get center of rotation
	;call GetMousePoint, returns st0=x, st1=y
	call GetMousePnt
	fstp qword [XC] 
	fstp qword [YC] 


	;now go thru the link list 
	;and rotate each selected object

.findObjectToRotate:
	push esi             ;save link address for later
	cmp dword [esi+8],1  ;is object selected ?
	jnz .nextLink


	;call tlib rotate 
	;we do not create new objects here 
	;we modify existing object coordinates
	push esi          ;preserve
	mov eax,108       ;rotateline
	lea ebx,[esi+80]  ;address of segment coordinates to rotate
	mov ecx,X1        ;address to store rotated coordinates
	mov edx,Angle     ;address of rotation angle,radians
	mov esi,XC        ;address of center point coordinates
	sysenter
	pop esi
	
	;save new endpoint coordinates to object link
	fld  qword [X1] 
	fstp qword [esi+80]   ;save new x1
	fld  qword [Y1] 
	fstp qword [esi+88]   ;save new y1
	fld  qword [X2] 
	fstp qword [esi+96]   ;save new x2
	fld  qword [Y2] 
	fstp qword [esi+104]  ;save new y2

	call SaveMidPoint


.nextLink:
	pop esi              ;retrieve address of current link
	mov esi,[esi+76]     ;esi=address of next link
	cmp esi,0            ;is next link address valid ?
	jnz .findObjectToRotate


.done:

	;reset left mouse, ENTER, feedback message to defaults
	mov eax,0  ;feedback message index
	mov ebx,0  ;idle left mouse handler
	mov dword [EntrKeyProc],0 

	call UnselectAll

	ret





;*********************************************************
;RotateSegM
;Rotate Segment via Mouse

;rotate a collection of segments via mouse picks
;actions occur in the following order:

;1) user is prompted to select objects and hit ENTER
;2) user is prompted to pick center point of rotation "O"
;3) user is prompted to pick point "B" on selected objects
;4) user is prompted to pick point "C" out in space or on
;   another object

;the angle of rotation is determined by the angle <BOC

;**********************************************************

public RotateSegM

	dumpstr str28

	;prompt user to select segments to rotate & hit ENTER
	mov eax,13  ;feedback message index

	;set left mouse handler for object selection
	mov ebx,0   ;IdleLeftMouseHandler

	;after objects are selected, user must hit ENTER
	mov dword [EntrKeyProc],RotateSegmentsM_11

	call UnselectAll

	ret


RotateSegmentsM_11:

	;this is an ENTER key handler
	;we got here after user selected segments to rotate

	dumpstr str29

	;and tell the user to pick the center of rotation O
	mov eax,5  ;feedback message index
	mov dword [LftMousProc],RotateSegmentsM_22

	ret




RotateSegmentsM_22:

	;this is a left mouse handler
	;we got here after user picked the center of rotation

	dumpstr str30

	;get center of rotation
	;call GetMousePoint, returns st0=x, st1=y
	call GetMousePnt
	fstp qword [XC] 
	fstp qword [YC] 

	;prompt user to pick ref endpoint B on selected objects
	mov eax,30  ;feedback message index
	mov ebx,RotateSegmentsM_33
	ret



RotateSegmentsM_33:

	;this is a left mouse handler
	;we got here after user picked a ref endpoint B on objects to rotate

	dumpstr str31

	;get and save ref endpoint B
	call GetMousePnt
	fstp qword [X1]
	fstp qword [Y1]

	;prompt user to pick destination endpoint C 
	mov eax,34
	mov ebx,RotateSegmentsM_44

	ret



RotateSegmentsM_44:

	;this is a left mouse handler
	;we got here after user picked a destination endpoint C

	;headlink is public

	dumpstr str32a


	;get and save ref destination endpoint C
	call GetMousePnt
	fstp qword [X2]
	fstp qword [Y2]


	;store x1,y1,x2,y2 for vector1 = segment BO
	fld  qword [XC]
	fstp qword [vector1]
	fld  qword [YC]
	fstp qword [vector1+8]
	fld  qword [X1]
	fstp qword [vector1+16]
	fld  qword [Y1]
	fstp qword [vector1+24]

	;store x1,y1,x2,y2 for vector2 = segment C0
	fld  qword [XC]
	fstp qword [vector2]
	fld  qword [YC]
	fstp qword [vector2+8]
	fld  qword [X2]
	fstp qword [vector2+16]
	fld  qword [Y2]
	fstp qword [vector2+24]
	

	;now compute the angle <BOC
	;we use tlib function "getangleinc"
	mov eax,109      ;getangleinc
	mov ebx,vector1  ;segment B0
	mov ecx,vector2  ;segment C0
	sysenter
	;returns included angle in st0
	;it will always be > 0 so we need flip key handler some times
	fstp qword [Angle]    ;save the rotation angle,radians
	

	;now go thru the link list 
	;and rotate each selected object
	;this code same as rotate by keyboard

	mov esi,[headlink]

.findObjectToRotate:
	push esi             ;save link address for later
	cmp dword [esi+8],1  ;is object selected ?
	jnz .nextLink


	;call tlib rotate 
	;we do not create new objects here 
	;we modify existing object coordinates
	push esi          ;preserve
	mov eax,108       ;rotateline
	lea ebx,[esi+80]  ;address of segment coordinates to rotate
	mov ecx,X1        ;address to store rotated coordinates
	mov edx,Angle     ;address of rotation angle,radians
	mov esi,XC        ;address of center point coordinates
	sysenter
	pop esi
	
	;save new endpoint coordinates to object link
	fld  qword [X1] 
	fstp qword [esi+80]   ;save new x1
	fld  qword [Y1] 
	fstp qword [esi+88]   ;save new y1
	fld  qword [X2] 
	fstp qword [esi+96]   ;save new x2
	fld  qword [Y2] 
	fstp qword [esi+104]  ;save new y2

	call SaveMidPoint


.nextLink:
	pop esi              ;retrieve address of current link
	mov esi,[esi+76]     ;esi=address of next link
	cmp esi,0            ;is next link address valid ?
	jnz .findObjectToRotate


.done:

	;reset left mouse, ENTER, feedback message to defaults
	mov eax,0  ;feedback message index
	mov ebx,0  ;idle left mouse handler
	mov dword [EntrKeyProc],0
	mov dword [FlipKeyProc],RotateSegmentsM_55
	;done unselect all, need selected objects for flip key handler
	ret





RotateSegmentsM_55:

	dumpstr str32b

	;this is a flip key handler
	;the above rotate by mouse always rotates + CCW
	;so if we need a negative rotation ...

	;change the Angle two twice the negative
	;this will rotate the selected objects back where they were
	;plus rotate back another -Angle
	fld qword [Angle]
	fmul qword [Two]
	fchs 
	fstp qword [Angle]  ;Angle=-2*Angle


	;now go thru the link list 
	;and rotate each selected object by -90deg


	mov esi,[headlink]  ;headlink is public

.findObjectToRotate:

	push esi             ;save link address for later
	cmp dword [esi+8],1  ;is object selected ?
	jnz .nextLink


	;call tlib rotate 
	;we do not create new objects here 
	;we modify existing object coordinates
	push esi          ;preserve
	mov eax,108       ;rotateline
	lea ebx,[esi+80]  ;address of segment coordinates to rotate
	mov ecx,X1        ;address to store rotated coordinates
	mov edx,Angle     ;address of rotation angle,radians
	mov esi,XC        ;address of center point coordinates
	sysenter
	pop esi
	
	;save new endpoint coordinates to object link
	fld  qword [X1] 
	fstp qword [esi+80]   ;save new x1
	fld  qword [Y1] 
	fstp qword [esi+88]   ;save new y1
	fld  qword [X2] 
	fstp qword [esi+96]   ;save new x2
	fld  qword [Y2] 
	fstp qword [esi+104]  ;save new y2

	call SaveMidPoint


.nextLink:
	pop esi              ;retrieve address of current link
	mov esi,[esi+76]     ;esi=address of next link
	cmp esi,0            ;is next link address valid ?
	jnz .findObjectToRotate


.done:
	;reset left mouse, ENTER, feedback message to defaults
	mov eax,0  ;feedback message index
	mov ebx,0  ;idle left mouse handler
	call UnselectAll
	;the user may only flip once
	;flipping more than once means doubling and negating the 
	;Angle again which leads to unpredicatable crazy rotations.
	ret








;**********************************************************
;TrimSeg
;Trim Segments
;this is trim and extend all in one shot

;user is prompted as follows:
;1) select cutting line
;2) select segments to trim (may repeat as needed)
;3) hit ESCAPE to quit the function

;the endpoint of the segment to trim that is on the 
;mouse side of the cutting line will be redefined
;to be at the virtual or real intersection of the 
;cutting line and the segment to trim

tr_CuttingLineObject:
dd 0
tr_CuttingLine:  ;stores x1,y1,x2,y2 of cutting line
db0 32
tr_Segment2Trim: ;stores x1,y1,x2,y2 of segment2trim
db0 32
tr_Mouse:        ;stores MOUSEXF,MOUSEYF
db0 16
;************************************************************

public TrimSeg

	dumpstr str110

	;prompt user to select cutting line
	mov eax,28  ;feedback message index

	;set left mouse handler for object selection
	mov ebx,0   ;IdleLeftMouseHandler 

	;after objects are selected
	mov dword [PassToPaint],Trim_11

	ret




Trim_11:

	;this is a post paint handler
	;we got here after user selected a cutting line

	dumpstr str111

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .done  ;failed to find a selected segment
	;returns ebx=address of 1st selected object

	;save endpoints of the cutting line
	fld  qword [ebx+80] 
	fstp qword [tr_CuttingLine]
	fld  qword [ebx+88] 
	fstp qword [tr_CuttingLine+8]
	fld  qword [ebx+96] 
	fstp qword [tr_CuttingLine+16]
	fld  qword [ebx+104] 
	fstp qword [tr_CuttingLine+24]

	;we must unselect the cutting line
	;so that Trim_22 GetSelObj can correctly
	;identify the object to trim
	;perhaps we can temporarily change the color of
	;the cuttingline or make it thicker in order
	;to distinguish it ???
	call UnselectAll

	;prompt user to select segment(s) to trim
	mov eax,29  ;feedback message index
	mov ebx,0   ;default left mouse handler
	mov dword [PassToPaint],Trim_22

.done:
	ret




Trim_22:

	;this is a post paint handler
	;we got here after user selected a segment to trim

	;this code is written to be infinitely repeatable
	;the user may continue to trim as many lines as desired
	;until user hits ESC
	;so dont modify this code to make it a "one time" prc

	dumpstr str112

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .done  ;failed to find a selected segment


	;save address in link list of object to trim for later
	mov [object],ebx


	;save endpoints of segment to trim
	fld  qword [ebx+80]
	fstp qword [tr_Segment2Trim]
	fld  qword [ebx+88]
	fstp qword [tr_Segment2Trim+8]
	fld  qword [ebx+96]
	fstp qword [tr_Segment2Trim+16]
	fld  qword [ebx+104]
	fstp qword [tr_Segment2Trim+24]



	;compute intersection point of cutting line and segment to trim
	mov eax,96          ;tlib intersection function
	mov ebx,tr_CuttingLine
	mov ecx,tr_Segment2Trim
	mov edx,pIntersect  ;intersection point is filled in
	sysenter
	;returns XC,YC intersection point and eax=0
	;if eax=2 lines are parallel and do not cross
	cmp eax,2
	jz .done



	;get mouse position where user picked on segment to trim
	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF
	fstp qword [tr_Mouse]     ;mousexf
	fstp qword [tr_Mouse+8]   ;mouseyf


	;use ptinrect to determine which side of cutting line
	;the mouse is on, code is simto corner segments


	;set bounding rectangle
	;we use the intersection point and
	;segment2trim  P1 as the bounding box
	fld  qword [pIntersect]        ;x intersection
	fstp qword [boundrect]
	fld  qword [pIntersect+8]      ;y intersection
	fstp qword [boundrect+8]
	fld  qword [tr_Segment2Trim]   ;x1 of Segment2Trim
	fstp qword [boundrect+16]
	fld  qword [tr_Segment2Trim+8] ;y1 of Segment2Trim
	fstp qword [boundrect+24]



	;test if mouse is within the bounding box
	mov eax,97         ;tlib function pointinrectfloat
	mov ebx,boundrect  ;ebx=address of rect corners
	mov ecx,tr_Mouse   ;ecx=address of MOUSEXF,MOUSEYF
	sysenter      	;ZF is set if Point is within bounding box
	jz .1              ;mouse is within bounding box


	;mouse is between P2 and intersection point
	;redefine P2 at intersection
	mov eax,[object]          ;eax=address segment2trim
	fld  qword [pIntersect]   ;intersection x
	fstp qword [eax+96]       ;save x2
	fld  qword [pIntersect+8] ;intersection y
	fstp qword [eax+104]      ;save y2

	jmp .done


.1:
	;mouse is between P1 and intersection point
	;redefine P1 at intersection
	mov eax,[object]          ;eax=address segment2trim
	fld  qword [pIntersect]   ;intersection x
	fstp qword [eax+80]       ;save x1
	fld  qword [pIntersect+8] ;intersection y
	fstp qword [eax+88]       ;save y1



.done:

	;update the midpoint 
	mov esi,[object]
	call SaveMidPoint

	;the user may continue to select segments to trim
	;must hit ESCAPE to get out of this function
	mov eax,29  ;feedback message index
	mov ebx,0   ;default left mouse handler
	mov dword [PassToPaint],Trim_22

	call UnselectAll

	ret








;**********************************************************
;ExtndTrmSeg
;Extend or Trim Segments

;segment endpoints closest to the mouse are redefined
;at the intersection of the cutting line and the segment
;to extend/trim

;the TCAD main menu has seperate selections for trim
;and extend but they both call this function

;user is prompted as follows:
;1) select cutting line
;2) select segments to extend/trim (may repeat as needed)
;3) hit ESCAPE to quit the function

tr_Segment2Extend: ;stores x1,y1,x2,y2 of segment2extend
db0 32

;************************************************************

public ExtndTrmSeg

	;prompt user to select cutting line
	mov eax,61  ;feedback message index

	;set left mouse handler for object selection
	mov ebx,0   ;IdleLeftMouseHandler 

	;after objects are selected
	mov dword [PassToPaint],ExtendTrim_11

	ret



ExtendTrim_11:

	;this is a post paint handler
	;we got here after user selected a cutting line

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .done  ;failed to find a selected segment
	;returns ebx=address of 1st selected object

	;save endpoints of the cutting line
	fld  qword [ebx+80] 
	fstp qword [tr_CuttingLine]
	fld  qword [ebx+88] 
	fstp qword [tr_CuttingLine+8]
	fld  qword [ebx+96] 
	fstp qword [tr_CuttingLine+16]
	fld  qword [ebx+104] 
	fstp qword [tr_CuttingLine+24]

	call UnselectAll

	;prompt user to select segment(s) to trim
	mov eax,62  ;feedback message index
	mov ebx,0   ;default left mouse handler
	mov dword [PassToPaint],ExtendTrim_22

.done:
	ret




ExtendTrim_22:

	;this is a post paint handler
	;we got here after user selected a segment to extend

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,0
	jz .done  ;failed to find a selected segment


	;save address in link list of object to extend for later
	mov [object],ebx


	;save endpoints of segment to extend
	fld  qword [ebx+80]
	fstp qword [tr_Segment2Extend]
	fld  qword [ebx+88]
	fstp qword [tr_Segment2Extend+8]
	fld  qword [ebx+96]
	fstp qword [tr_Segment2Extend+16]
	fld  qword [ebx+104]
	fstp qword [tr_Segment2Extend+24]



	;compute intersection point of cutting line and segment to extend
	mov eax,96          ;tlib intersection function
	mov ebx,tr_CuttingLine
	mov ecx,tr_Segment2Extend
	mov edx,pIntersect  ;intersection point is filled in
	sysenter
	;returns XC,YC intersection point and eax=0
	;if eax=2 lines are parallel and do not cross
	cmp eax,2
	jz .done



	;get mouse position where user picked on segment to trim
	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF
	fstp qword [tr_Mouse]     ;mousexf
	fstp qword [tr_Mouse+8]   ;mouseyf


	;use GetNearPnt to determine which endpoint of the segment
	;is closest to the mouse, the closest endpoint will be
	;redefined at pIntersect

	push [object]  ;address of object to extend
	push tr_Mouse  ;address of mouse location 
	call GetNearPnt
	;returns eax=0 P is closest to x1,y1 or
	;            1 P is closest to x2,y2
	cmp eax,1
	jz .1


	;if we got here mouse is closest to x1,y1
	;extend/redefine P1 at intersection
	mov eax,[object]          ;eax=address segment2trim
	fld  qword [pIntersect]   ;intersection x
	fstp qword [eax+80]       ;save x1
	fld  qword [pIntersect+8] ;intersection y
	fstp qword [eax+88]       ;save y1
	jmp .done


.1:  
	;mouse is closest to x2,y2
	;extend/redefine P2 at intersection
	mov eax,[object]          ;eax=address segment2trim
	fld  qword [pIntersect]   ;intersection x
	fstp qword [eax+96]       ;save x2
	fld  qword [pIntersect+8] ;intersection y
	fstp qword [eax+104]      ;save y2


.done:

	;update the midpoint 
	mov esi,[object]
	call SaveMidPoint


	;the user may continue to select segments to extend
	;must hit ESCAPE to get out of this function
	mov eax,62  ;feedback message index
	mov ebx,0   ;default left mouse handler
	mov dword [PassToPaint],ExtendTrim_22

	call UnselectAll

	ret








;**********************************************************
;CornerSeg
;Corner Segments

;this is double trim/extend of both segment endpoints

;user is prompted as follows:
;1) select segment #1 near endpoint to be redefined at corner
;2) select segment #2 near endpoint to be redefined at corner

;the real or virtual intersection of the segments 
;is computed to be the corner
;if the segments do not cross then segments are extended
;if segments cross then they are trimmed

;globals reserved for CornerSegments
cs_Segment1:
dd 0
cs_Segment2:
dd 0
cs_Mouse1:
db0 16
cs_Mouse2:
db0 16
cs_Vector1:
db0 32
cs_Vector2:
db0 32
cs1nearest:
dd 0
cs2nearest:
dd 0

;************************************************************

public CornerSeg

	dumpstr str5

	;prompt user to select segment #1
	mov eax,32  ;feedback message index

	;set left mouse handler for object selection
	mov ebx,0

	;proc address gets passed to IdleLeftMouseHandler
	;which passes it on to PostPaintHandler
	mov dword [PassToPaint],Corner_11

	ret



Corner_11:

	;this is a PostPaintHandler
	;we get here after the user picked segment #1

	dumpstr str6


	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,1   ;do we have 1 selected object ?
	jnz .error  ;failed to find a selected segment



	;save address of 1st selected segment #1
	mov dword [cs_Segment1],ebx


	;save endpoints as "vector1"
	fld  qword [ebx+80]
	fstp qword [cs_Vector1]
	fld  qword [ebx+88]
	fstp qword [cs_Vector1+8] 
	fld  qword [ebx+96]
	fstp qword [cs_Vector1+16] 
	fld  qword [ebx+104]
	fstp qword [cs_Vector1+24] 



	;determine which endpoint is closest to the mouse


	;get mouse position
	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF
	fstp qword [cs_Mouse1]   ;MOUSEXF
	fstp qword [cs_Mouse1+8] ;MOUSEYF


	;use GetNearPnt to determine which endpoint of the segment
	;is closest to the mouse, the closest endpoint will be
	;redefined at pIntersect

	push [cs_Segment1]  ;address of object to extend
	push cs_Mouse1      ;address of mouse location 
	call GetNearPnt
	;returns eax=0 P is closest to x1,y1 or
	;            1 P is closest to x2,y2

	;save the nearest endpoint of seg1
	mov [cs1nearest],eax

	jmp .done


.error:
	mov eax,53  ;feedback message index = "no selection"
	mov ebx,0  ;left mouse handler
	mov dword [PassToPaint],0
	ret

.done:

	;prompt user to select segment #2
	mov eax,33  ;FeedbackMessageIndex]
	mov ebx,0  ;left mouse handler
	mov dword [PassToPaint],Corner_22
	ret






Corner_22:

	;this is a PostPaintHandler
	;we get here after the user picked segment #2
	;both seg #1 and seg #2 should be selected

	dumpstr str7


	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,2  ;do we have 2 selected objects ?
	jnz .done  ;failed to find a selected segment



	;now determine which selected object is
	;NOT the first selected object
	cmp dword [cs_Segment1],ebx
	jz .1
	mov eax,ebx  ;ebx holds address of 2nd object selected
	jmp .2
.1:
	mov eax,ecx   ;ecx holds address of 2nd object selected
.2:

	;save address of 2nd selected segment
	mov dword [cs_Segment2],eax

	;save endpoints as "vector2"
	fld  qword [eax+80]
	fstp qword [cs_Vector2] 
	fld  qword [eax+88]
	fstp qword [cs_Vector2+8] 
	fld  qword [eax+96]
	fstp qword [cs_Vector2+16] 
	fld  qword [eax+104]
	fstp qword [cs_Vector2+24] 



	;get mouse position
	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF
	fstp qword [cs_Mouse2]   ;MOUSEXF
	fstp qword [cs_Mouse2+8] ;MOUSEYF


	;get which endpoint of Segment2 is closest the mouse
	push [cs_Segment2]  ;address of object to extend
	push cs_Mouse2      ;address of mouse location 
	call GetNearPnt
	;returns eax=0 P is closest to x1,y1 or
	;            1 P is closest to x2,y2

	;save the nearest endpoint of seg1
	mov [cs2nearest],eax




	;at this point we have 2 selected segments


	;compute intersection of Segment1 and Segment2
	;save intersection as Point1
	mov eax,96      ;intersection
	mov ebx,cs_Vector1
	mov ecx,cs_Vector2 
	mov edx,pIntersect  ;storage for intersection point
	sysenter
	cmp eax,0
	jnz .error1   ;no intersection, lines are parallel



	;now redefine endpoint of Segment1 at intersection
	mov esi,[cs_Segment1]    ;esi=address of Segment1
	fld qword [pIntersect+8] ;st0=pIntersect_y
	fld qword [pIntersect]   ;st0=pIntersect_x, st1=pIntersect_y

	cmp dword [cs1nearest],1
	jz .3

	;P1 of Segment1 is to be redefined at intersection
	fstp qword [esi+80]
	fstp qword [esi+88]
	jmp .4


.3:  ;P2 of Segment1 is to be redefined at intersection
	fstp qword [esi+96]
	fstp qword [esi+104]

.4: 
	;now redefine endpoint of Segment2 at intersection
	mov esi,[cs_Segment2]    ;esi=address of Segment2
	fld qword [pIntersect+8] ;st0=pIntersect_y
	fld qword [pIntersect]   ;st0=pIntersect_x, st1=pIntersect_y

	cmp dword [cs2nearest],1
	jz .5

	;P1 of Segment2 is to be redefined at intersection
	fstp qword [esi+80]
	fstp qword [esi+88]
	jmp .done


.5:  ;P2 of Segment2 is to be redefined at intersection
	fstp qword [esi+96]
	fstp qword [esi+104]
	jmp .done



.error1:
	dumpstr str8

.done:

	;update the midpoints
	mov esi,[cs_Segment1]
	call SaveMidPoint
	mov esi,[cs_Segment2]
	call SaveMidPoint

	call UnselectAll
	mov eax,0  ;feedback message index
	mov ebx,0  ;idle left mouse handler
	ret







;**********************************************************
;ChamferSeg
;Chamfer Segments

;this code is based on CornerSegments

;we compute the intersection of 2 selected segments
;instead of defining the endpoints at the intersection
;we use tlib "chamfer" function to clip the corner

;the endpoints closest to the intersection are redefined
;to be coincident with the chamfer segment

;if the selected line segments are at 90 degrees
;then this produces a std 45 deg corner chamfer

;user is prompted as follows:
;1) select segment #1
;2) select segment #2

;reserved globals
ChamferVector:  ;storage for x1,y1,x2,y2 qword floats
db0 32
;************************************************************

public ChamferSeg

	dumpstr str20

	;prompt user to select segment #1
	mov eax,54  ;feedback message index

	;set left mouse handler for object selection
	mov ebx,0

	;proc address gets passed to IdleLeftMouseHandler
	;which passes it on to PostPaintHandler
	mov dword [PassToPaint],ChamferSegments_11

	ret



ChamferSegments_11:

	;this is a PostPaintHandler
	;we get here after the user picked segment #1

	dumpstr str21


	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,1  ;do we have 1 selected object ?
	jnz .1     ;failed to find a selected segment



	;save address of 1st selected segment #1
	mov dword [cs_Segment1],ebx
	;save endpoints as "vector1"
	fld  qword [ebx+80]
	fstp qword [cs_Vector1]
	fld  qword [ebx+88]
	fstp qword [cs_Vector1+8] 
	fld  qword [ebx+96]
	fstp qword [cs_Vector1+16] 
	fld  qword [ebx+104]
	fstp qword [cs_Vector1+24] 


	;get mouse position where user picked on segment #1
	call GetMousePnt
	;returns st0=qword MOUSEXF, st1=qword MOUSEYF
	;save mouse position as Point1
	fstp qword [cs_Mouse1]     ;mousexf
	fstp qword [cs_Mouse1+8]   ;mouseyf


	jmp .done


.1:

	;we got here if the user made a Lclick but failed to
	;select a TCD_SEGMENT, repeat the prompt
	mov eax,54  ;feedback message index = "no selection"
	mov ebx,0   ;left mouse handler
	mov dword [PassToPaint],ChamferSegments_11
	ret

.done:

	;prompt user to select segment #2
	mov eax,55  ;FeedbackMessageIndex]
	mov ebx,0  ;left mouse handler
	mov dword [PassToPaint],ChamferSegments_22
	ret




ChamferSegments_22:

	;this is a PostPaintHandler
	;we get here after the user picked segment #2

	push ebp
	mov ebp,esp

	dumpstr str22


	mov eax,TCD_SEGMENT
	call GetSelObj
	;returns:
	;eax=qty selected objects (0,1,2)
	;ebx=address obj1 selected
	;ecx=address obj2 selected
	cmp eax,2  ;do we have 2 selected objects ?
	jnz .done  ;failed to find a selected segment



	;now determine which selected object is
	;NOT the first selected object
	cmp dword [cs_Segment1],ebx
	jz .1
	mov eax,ebx   ;ebx holds address of 2nd object selected
	jmp .2
.1:
	mov eax,ecx   ;ecx holds address of 2nd object selected
.2:

	;save address of 2nd selected segment
	mov dword [cs_Segment2],eax
	;save endpoints as "vector2"
	fld  qword [eax+80]
	fstp qword [cs_Vector2] 
	fld  qword [eax+88]
	fstp qword [cs_Vector2+8] 
	fld  qword [eax+96]
	fstp qword [cs_Vector2+16] 
	fld  qword [eax+104]
	fstp qword [cs_Vector2+24] 




	;at this point we have 2 selected segments, now


	;compute intersection of cs_Segment1 and cs_Segment2
	;save intersection as Point1
	mov eax,96      ;intersection
	mov ebx,cs_Vector1
	mov ecx,cs_Vector2 
	mov edx,pIntersect  ;storage for intersection point
	sysenter

	cmp eax,0
	jnz .error   ;no intersection, lines are parallel




	;the tlib chamfer function requires P1 be the intersection 
	;point, so this may swap the order in which the user created
	;the segment, here we determine which endpoint of the segment
	;is closest to the intersection, the point then furthest from
	;the intersection automatically becomes P2



	;which endpoint of cs_Segment1 is closest the intersection ?
	push [cs_Segment1]
	push pIntersect
	call GetNearPnt
	;returns eax=0 if P1 nearest else eax=1 if P2 nearest

	cmp eax,0
	jz .3


	;P2 is closest
	;define cs_Vector1 to go from pIntersect->Seg1(P1)
	mov eax,[cs_Segment1]
	fld  qword [pIntersect]     
	fstp qword [cs_Vector1] 
	fld  qword [pIntersect+8]  
	fstp qword [cs_Vector1+8]
	;assign Seg1(P1)to cs_Vector1(P2)
	fld  qword [eax+80]
	fstp qword [cs_Vector1+16]
	fld  qword [eax+88]
	fstp qword [cs_Vector1+24]
	jmp .4

.3:
	;P1 is closest
	;define cs_Vector1 to go from pIntersect->Seg1(P2)
	mov eax,[cs_Segment1]
	fld qword [pIntersect]      ;load intersection x
	fstp qword [cs_Vector1]     ;x1=intersection x
	fld qword [pIntersect+8]    ;load intersection y
	fstp qword [cs_Vector1+8]   ;y1=intersection y
	;ChamferSegments_11 already assigned x2,y2 correctly 

.4:

	;which endpoint of cs_Vector2 is closest the intersection ?
	push [cs_Segment2]
	push pIntersect
	call GetNearPnt
	;returns eax=0 is P1 nearest else eax=1 if P2 nearest

	cmp eax,0
	jz .5


	;P2 is closest
	;define cs_Vector2 to go from pIntersect->Seg2(P1)
	mov eax,[cs_Segment2]
	fld qword [pIntersect]      ;load intersection x
	fstp qword [cs_Vector2]     ;x2=intersection x
	fld qword [pIntersect+8]    ;load intersection y
	fstp qword [cs_Vector2+8]  ;y2=intersection y
	;assign Seg2(P1)to cs_Vector2(P2)
	fld  qword [eax+80]
	fstp qword [cs_Vector2+16]
	fld  qword [eax+88]
	fstp qword [cs_Vector2+24]
	jmp .6

.5:
	;P1 is closest
	;define cs_Vector2 to go from pIntersect->Seg2(P2)
	mov eax,[cs_Segment2]
	fld qword [pIntersect]      ;load intersection x
	fstp qword [cs_Vector2]     ;x1=intersection x
	fld qword [pIntersect+8]    ;load intersection y
	fstp qword [cs_Vector2+8]   ;y1=intersection y
	;we already assigned x2,y2 to cs_Vector2 above

.6:


	;now we have cs_Vector1 and cs_Vector2
	;sharing a common intersection point


	;compute endpoints of chamfer segment
	;the endpoints of the chamfer segment are equi-distant
	;from the intersection point
	mov eax,44             ;tlib chamfer function
	mov ebx,cs_Vector1
	mov ecx,cs_Vector2
	mov edx,ChamferVector  ;storage for chamfer segment endpoints
	mov esi,ChamferSize    ;user gave us this via SetChamferSize
	sysenter


	;if you dont want to trim the original segments back to chamfer
	;then uncommend out this line
	;jmp .skiptrim


	;now redefine P1 of cs_Segment1 to be P1 of the Chamfer segment
	mov esi,[cs_Segment1]
	fld  qword [ChamferVector]  
	fstp qword [esi+80] 
	fld  qword [ChamferVector+8] 
	fstp qword [esi+88]
	;and copy cs_Vector1(P2) to the object link P2
	fld  qword [cs_Vector1+16]
	fstp qword [esi+96]
	fld  qword [cs_Vector1+24]
	fstp qword [esi+104]


	;now redefine P1 of cs_Segment2 to be P2 of the Chamfer segment
	mov esi,[cs_Segment2]
	fld  qword [ChamferVector+16]
	fstp qword [esi+80]
	fld  qword [ChamferVector+24]
	fstp qword [esi+88]
	;and copy cs_Vector2(P2) to the object link P2
	fld  qword [cs_Vector2+16]
	fstp qword [esi+96]
	fld  qword [cs_Vector2+24]
	fstp qword [esi+104]


.skiptrim:


	;create the chamfer line segment

	mov ecx,0   ;dumy layer index
	call GetLayItems
	;returns many items including edi=dword [currentlayer]

	
	;create new blank chamfer segment
	call CreateBLink              ;esi=address new link
	mov dword [esi],TCD_SEGMENT   ;type=line
	mov [esi+4],edi               ;current layer
	mov dword [esi+8],0           ;visibility state = unselected
	mov dword [esi+12],2          ;qty points
	mov dword [esi+16],0          ;dat pointer
	mov dword [esi+20],segmentpaint  
	mov dword [esi+24],segmentdelete 
	mov dword [esi+28],segmentcopy   
	mov dword [esi+32],segmentmove   
	mov dword [esi+36],segmentmirror 
	mov dword [esi+40],segmodify 
	mov dword [esi+44],segmentwrite  
	mov dword [esi+48],segmentread   
	mov dword [esi+52],segmentselect 
	mov dword [esi+56],segmentscale  
	mov dword [esi+60],segmentdump
	mov dword [esi+64],segmentselectdrag
	mov dword [esi+68],segmentpdf

	;chamfer endpoints
	fld  qword [ChamferVector]  ;x1
	fstp qword [esi+80]
	fld  qword [ChamferVector+8] ;y1
	fstp qword [esi+88]
	fld  qword [ChamferVector+16] ;x2
	fstp qword [esi+96]
	fld  qword [ChamferVector+24]
	fstp qword [esi+104]

	call SaveMidPoint

	jmp .done


.error:
	dumpstr str8

.done:

	;update the midpoints 
	mov esi,[cs_Segment1]
	call SaveMidPoint
	mov esi,[cs_Segment2]
	call SaveMidPoint

	call UnselectAll
	mov eax,0  ;feedback message index
	mov ebx,0  ;idle left mouse handler

	pop ebp
	ret











;**********************************************************************
;RedefineSegmentEndpoint
;this function will redefine the x,y coordinate of a segment endpoint
;based on a user selected endpoint 
;and some calculated values for the new endpoint location
;GetMousePoint is typically used to select an endpoint
;the problem with GetMousePoint is we dont know if this is p1 or p2
;this function resolves that problem and redefines the endpont
;input:
;esi=address of segment in the link list
;ebx=address of selected endpoint coordinates x,y qword float 16 bytes
;ecx=address of calculated endpoint coordinates   qword float 16 bytes
;return:none
;**********************************************************************

RedefineSegmentEndpoint:


	;did the user select p1 endpoint or p2 ?
	;we compare only the X values

	fld qword [esi+80]  ;load x1 of segment
	fld qword [ebx]     ;load x1 of selected endpoint
	fcomi st1     
	jz .modifyP1


	;redefine P2
	ffree st0  ;fcomi needs ffree ffree
	ffree st1
	fld  qword [ecx]
	fstp qword [esi+96] 
	fld  qword [ecx+8]
	fstp qword [esi+104] 
	jmp .done


.modifyP1:

	;redefine P1
	ffree st0  ;fcomi needs ffree ffree
	ffree st1
	fld  qword [ecx] 
	fstp qword [esi+80]
	fld  qword [ecx+8] 
	fstp qword [esi+88] 

.done:
	ret





;*************************************************
;WHICHSEGMENTENDPOINT

;this function determines which point of a segment 
;matches some other x,y endpoint data typically
;returned by GetMousePoint
;the point coordinates are qword float 16 bytes

;input:
;esi= Address of segment in link list
;ebx= Address of x,y point coordinates from GetMousePoint
;return:  
;success: eax=1 for EP1 and eax=2 for EP2
;failure: eax=0 no match

;************************************************

WhichSegmentEndpoint:


	;test P1x
	fld qword [esi+80]  ;load x1 of segment
	fld qword [ebx]     ;load x of given point
	fcomi st1
	jnz .tryP2

	;test P1y
	ffree st0
	ffree st1
	fld qword [esi+88]  ;load y1 of segment
	fld qword [ebx+8]   ;load y of given point
	fcomi st1
	jz .matchesP1



.tryP2:
	;test P2x
	ffree st0
	ffree st1
	fld qword [esi+96]  ;load x2 of segment
	fld qword [ebx]     ;load x of given point
	fcomi st1
	jnz .noMatch

	;test P2y
	ffree st0
	ffree st1
	fld qword [esi+104] ;load y1 of segment
	fld qword [ebx+8]   ;load y of given point
	fcomi st1
	jz .matchesP2


	;fall thru no match


.noMatch:
	;if we got here we have no match
	ffree st0
	ffree st1
	mov eax,0
	jmp .done


.matchesP1:
	ffree st0
	ffree st1
	mov eax,1
	jmp .done

.matchesP2:
	ffree st0
	ffree st1
	mov eax,2

.done:
	mov ebx,eax
	dumpebx ebx,str39,0
	ret




;*************************************************************
;GetNearPnt
;Get Nearest Point

;determine which endpoint of a segment
;is nearest to another point
;all endpoints are qword float coordinates

;input:
;push Address of segment in link list          [ebp+12]
;push Address of Px,Py qword point coordinates [ebp+8]

;return:  
;success: eax=0, point P is closest to segment endpoint x1,y1
;         eax=1, point P is closest to segment endpoint x2,y2

;the method here is to look at min[abs(dx) + abs(dy)]
;this avoids the more costly square and square root functions
;**************************************************************


public GetNearPnt

	push ebp
	mov ebp,esp

	dumpstr str10

	mov edi,[ebp+12]  ;edi=address of object in link list
	mov esi,[ebp+8]   ;esi=address of point


	;compute abs(x1-Px)
	fld  qword [edi+80] ;st0=x1
	fsub qword [esi]    ;st0=x1-Px
	fabs                ;st0=abs(x1-Px)


	;compute abs(y1-Py)
	fld  qword [edi+88] ;st0=y1, st1=...
	fsub qword [esi+8]  ;st0=y1-Py, st1=...
	fabs                ;st0=abs(y1-Py), st1=abs(x1-Px)


	;dx+dy
	fadd st1            ;st0=abs(y1-Py)+abs(x1-Px), st1=...
	ffree st1           ;free st1


	;repeat the above for x2,y2

	;compute abs(x2-Px)
	fld  qword [edi+96] ;st0=x2, st1=abs(...
	fsub qword [esi]    ;st0=x2-Px, st1=...
	fabs                ;st0=abs(x2-Px), st1=...

	;compute abs(y2-Py)
	fld  qword [edi+104] ;st0=y2, st1=..., st2=...
	fsub qword [esi+8]   ;st0=y2-Py, st1=..., st2=...
	fabs                 ;st0=abs(y2-Py), st1=..., st2=...
	fadd st1             ;st0=abs(y2-Py)+abs(x2-Px), st1=...
                          ;st2=abs(y1-Py)+abs(x1-Px)


	;compare st0 with st2
	;st0 = abs(y2-Py) + abs(x2-Px)
	;st2 = abs(y1-Py) + abs(x1-Px)
	fcomi st2
	jc .1

	;we are not testing the ZF flag which indicates equality
	;we better not have a zero length segment

	;if we got here the point P is closest to x1y1 
	mov eax,0  ;return value
	jmp .done

.1:  ;point P is closer to segment x2,y2
	mov eax,1  ;return value

.done:
	mov ebx,eax
	dumpebx ebx,str9,0
	ffree st0
	ffree st1
	ffree st2

	pop ebp
	retn 8  ;cleanup 2 args on stack




;********************************************************
;SEGMENTPOLAR2CARTESIAN

;modify the x,y coordinates of a segment endpoint
;based on a Length<Angle input
;this is polar->cartestian calculation
;the Length and Angle are qword floats in memory

;the segment Angle is relative to P1
;if eax=2 then we add 180 deg to Angle

;the value of eax typically comes from a call
;to WhichEndpoint()

;input:
;esi=address of segment object in link list
;eax=which endpoint is the Fixed/Reference Point
;    eax=1 P1 is fixed so modify P2
;    eax=2 P2 is fixed so modify P1
;ebx=address of qword Length in memory
;ecx=address of qword Angle in memory

;return:
;x,y value is saved directly to segment object link list
;**********************************************************

SegmentPolar2Cartesian:

	push eax
	push ebx
	push ecx        ;because sysexit corrupts ecx
	dumpstr str117  ;this corrupts eax,ebx
	pop ecx
	pop ebx
	pop eax

;for debug comment out this jmp
jmp .1   

	;for debug dump segment address
	push eax
	push ebx
	push ecx
	dumpebx esi,str118,0
	pop ecx
	pop ebx
	pop eax

	;for debug dump which endpoint
	push eax
	push ebx
	push ecx
	mov ebx,eax
	mov eax,9  ;dumpebx
	mov ecx,str119
	mov edx,0
	sysenter
	pop ecx
	pop ebx
	pop eax

	;for debug dump length
	fld qword [ebx]
	push eax
	push ebx
	push ecx
	dumpstr str120
	;dumpst0  this wont assemble
	ffree st0
	pop ecx
	pop ebx
	pop eax

	;for debug dump angle
	fld qword [ecx]
	push eax
	push ebx
	push ecx
	dumpstr str121
	;dumpst0  this wont assemble
	ffree st0
	pop ecx
	pop ebx
	pop eax

;end of debug code
.1:



	;jmp on value of WhichEndpoint
	cmp eax,1
	jz .modifyP2
	cmp eax,2
	jz .modifyP1

	;if we got here we have invalid endpoint spec
	jz .error


.modifyP1:

	;Angle=Angle+180 
	fldpi                ;st0=3.14159...
	fadd qword [ecx]     ;st0=Angle+180


	;x1 = x2 + Length*cos(Angle)
	;y1 = y2 + Length*sin(Angle)
	fsincos              ;st0=cos, st1=sin
	fmul qword [ebx]     ;st0=Lcos, st1=sin
	fadd qword [esi+96]  ;st0=x2+Lcos
	fstp qword [esi+80]  ;save x1, st0=sin
	fmul qword [ebx]     ;st0=Lsin
	fadd qword [esi+104] ;st0=y2+Lsin
	fstp qword [esi+88]  ;save y1
	jmp .done



.modifyP2:

	;x2 = x1 + Length*cos(Angle)
	;y2 = y1 + Length*sin(Angle)
	fld qword [ecx]      ;st0=angle
	fsincos              ;st0=cos, st1=sin
	fmul qword [ebx]     ;st0=Lcos, st1=sin
	fadd qword [esi+80]  ;st0=x1+Lcos
	fstp qword [esi+96]  ;save x2, st0=sin
	fmul qword [ebx]     ;st0=Lsin
	fadd qword [esi+88]  ;st0=y1+Lsin
	fstp qword [esi+104] ;save y2
	jmp .done

.error:
	dumpstr str122
.done:
	ret








;**************************************************
;SetChamSize
;Set Chamfer Size
;this function is invoked from the Misc menu
;allows the user to input a value for chamfer size
;the ChamferSegment function uses this value

ChamferSize:
dq 10.0
;**************************************************

public SetChamSize

	;prompt user to enter size of chamfer as qword float
	mov eax,54            ;comprompt
	mov ebx,str126        ;prompt string
	mov ecx,compromptbuf  ;destination buffer
	sysenter

	mov eax,93               ;str2st0
	mov ebx,compromptbuf
	sysenter                  ;st0=chamfer size

	fstp qword [ChamferSize]  ;save global qword [ChamferSize]

	;so everytime you invoke the chamfer function
	;you will get this size by default 
	;unless you change it first

	ret







;*************************************************************
;GetKeyboardPoint

;a general purpose function to getting object coordinates
;as input from the user via the keyboard and comprompt

;all numerical values must be floating point base 10 with decimal

;there are 3 possible types of data to be entered:

;[1] user enters comma seperated values
;e.g. 10.2,15.9
;this is absolute x,y endpoint coordinate

;[2] user enters < seperated values
;e.g. 10.0<45.0
;this is a Length<Angle entry
;the angle is in degrees
;this is used to define the 2nd endpoint of a segment
;e.g. x2 = x1 + Length*cos(angle)
;e.g. y2 = y1 + Length*sin(angle)

;[3] user enters plus seperated values
;this is used to define the 2nd endpoint of a segment
;e.g. 10.0+15.1
;this is a dx dy entry
;x2 = x1 + dx
;y2 = y1 + dy

;input: esi=address of string to display 
;       comprompt will display this message to get user input

;return:
;eax=0 no input, user hit ESC, unknown values entered
;ebx and ecx also = 0

;eax=1 absolute x,y
;eax=2 relative length<angle
;eax=3 relative dx+dy

;if eax is nonzero then we save to global qwords the 
;floating point values and return the address of these values
;ebx= address of 1st qword value (x or length or dx)
;ecx= address of 2nd qword value (y or angle  or dy)

gkp_FirstValue:
dq 0.0
gkp_SecondValue:
dq 0.0
;**************************************************************


GetKeyboardPoint:

	dumpstr str16

	;invoke comprompt, get user input
	
	mov eax,54            ;comprompt
	mov ebx,esi           ;prompt string
	mov ecx,compromptbuf  ;destination buffer
	sysenter
	jnz .quit  ;user hit ESC


	;test for + seperated values
	mov eax,107          ;strchr
	mov bl,43            ;+
	mov edi,compromptbuf ;parent string
	sysenter
	jnz .doPlusSepValu

	;test for , seperated values
	mov eax,107
	mov bl,44  ;comma
	mov edi,compromptbuf
	sysenter
	jnz .doCommaSepValu

	;test for < seperated values
	mov eax,107
	mov bl,60  ;<
	mov edi,compromptbuf
	sysenter
	jnz .doLeftArrowSepValu

	;if we got here we dont know what the user entered
	jmp .error



.doPlusSepValu:

	;******************
	;  dx+dy relative
	;  eax=3
	;******************

	;user may compute x2,y2 as follows
	;x2 = x1 + dx
	;y2 = y1 + dy


	;if we got here we have plus seperated values
	;split into substrings written to buffer
	mov eax,74            ;splitstr
	mov ebx,compromptbuf  ;parent string
	mov ecx,43            ;seperator byte ascii 43 is '+'
	mov edx,2             ;max 2 substrings
	mov esi,buffer        ;storage for substring addresses
	sysenter

	;convert substrings to qwords
	mov eax,93             ;str2st0
	mov ebx,compromptbuf
	sysenter
	;st0=dx

	fstp qword [gkp_FirstValue]

	mov eax,93             ;str2st0
	mov ebx,[buffer]       ;2nd substring
	sysenter
	;st0=dy

	fstp qword [gkp_SecondValue]

	mov eax,3   ;return dx+dy
	mov ebx,gkp_FirstValue
	mov ecx,gkp_SecondValue
	jmp .done




.doLeftArrowSepValu:

	;*******************************
	;  Length<Angle relative to x1
	;  the angle must be in degrees
	;  eax=2
	;*******************************

	;user may compute x2,y2 as follows:
	;x2 = x1 + Length*cos(angle)
	;y2 = y1 + Length*sin(angle)


	;if we got here we have plus seperated values
	;split into substrings written to buffer
	mov eax,74              ;splitstr
	mov ebx,compromptbuf    ;parent string
	mov ecx,60              ;seperator byte ascii 60 is '<'
	mov edx,2               ;max qty substrings
	mov esi,buffer          ;storage for substring addresses
	sysenter


	;convert substrings to qwords
	mov eax,93             ;str2st0
	mov ebx,compromptbuf   ;parent string
	sysenter               ;st0=Length
	;st0=length

	fstp qword [gkp_FirstValue]  ;length

	mov eax,93             ;str2st0
	mov ebx,[buffer]
	sysenter            
	;st0=angle

	fstp qword [gkp_SecondValue]  ;angle

	mov eax,2  ;return length<angle
	mov ebx,gkp_FirstValue
	mov ecx,gkp_SecondValue
	jmp .done



.doCommaSepValu:

	;*****************
	;  X,Y absolute
	;  eax=1
	;*****************


	;split into substrings written to buffer
	mov eax,74           ;splitstr
	mov ebx,compromptbuf ;parent string
	mov ecx,44           ;seperator byte
	mov edx,2            ;max qty substrings
	mov esi,buffer       ;address to store substring addresses
	sysenter


	;convert substrings to qwords
	mov eax,93            ;str2st0
	mov ebx,compromptbuf
	sysenter
	;st0=X

	fstp qword [gkp_FirstValue]

	mov eax,93            ;str2st0
	mov ebx,[buffer]
	sysenter
	;st0=Y

	fstp qword [gkp_SecondValue]

	;return:
	mov eax,1  
	mov ebx,gkp_FirstValue
	mov ecx,gkp_SecondValue
	jmp .done


.quit:
.error:
	;return error, bad input, user hit ESC
	mov eax,0  
	mov ebx,0
	mov ecx,0
.done:
	ret








;************************************************
;segmentdump
;dump the various fields of a segment link

;input: esi=address of link
;return: none

;locals
DLstr0:
db 0xa
db 'TCD_SEGMENT',0
DLstra:
db 'address of segment object/link',0
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
DLstr6:
db 'paint proc',0
DLstr7:
db 'delete proc',0
DLstr8:
db 'copy proc',0
DLstr9:
db 'move proc',0
DLstr10:
db 'write proc',0
DLstr11:
db 'read proc',0
DLstr12:
db 'selection proc',0
DLstr12a:
db 'scale proc',0
DLstr12b:
db 'dump proc',0
DLstr12c:
db 'select by dragbox proc',0
DLstr13:
db 'previous link',0
DLstr14:
db 'next link',0

segstr15a:
db 'x1=',0
segstr15b:
db 'y1=',0
segstr15c:
db 'x2=',0
segstr15d:
db 'y2=',0
segstr15e:
db 'xmid=',0
segstr15f:
db 'ymid=',0
segstr15g:
db 'xnear=',0
segstr15h:
db 'ynear=',0


DLstr16:
db 'mirror proc',0
DLstr17:
db 'edit proc',0
DLstr18a:
db 'x1 clipped inflated screen coord',0
DLstr18b:
db 'y1 clipped inflated screen coord',0
DLstr18c:
db 'x2 clipped inflated screen coord',0
DLstr18d:
db 'y2 clipped inflated screen coord',0
DLstr19a:
db 'x1 screen coordinate, pixels',0
DLstr19b:
db 'y1 screen coordinate, pixels',0
DLstr19c:
db 'x2 screen coordinate, pixels',0
DLstr19d:
db 'y2 screen coordinate, pixels',0
;************************************************

segmentdump:

	dumpstr DLstr0

	mov ebx,[esi]   ;obj type
	dumpebx ebx,DLstr1,0

	mov ebx,esi     ;address of segment object/link
	dumpebx ebx,DLstra,0

	mov ebx,[esi+4] ;layer index
	dumpebx ebx,DLstr2,0

	mov ebx,[esi+8] ;selected state
	dumpebx ebx,DLstr3,0

	mov ebx,[esi+12] ;qty points defined so far
	dumpebx ebx,DLstr4,0

	mov ebx,[esi+16] ;dat pointer
	dumpebx ebx,DLstr5,0

	;these proc addresses are not very interesting



	mov ebx,[esi+72] ;previous link
	dumpebx ebx,DLstr13,0

	mov ebx,[esi+76] ;next link
	dumpebx ebx,DLstr14,0



	;X1
	fld qword [esi+80]  ;x1
	mov eax,36          ;dumpst0
	mov ebx,segstr15a
	sysenter
	ffree st0

	;Y1
	fld qword [esi+88]  ;y1
	mov eax,36          ;dumpst0
	mov ebx,segstr15b
	sysenter
	ffree st0

	;X2
	fld qword [esi+96]  ;x2
	mov eax,36          ;dumpst0
	mov ebx,segstr15c
	sysenter
	ffree st0

	;Y2
	fld qword [esi+104]  ;y2
	mov eax,36           ;dumpst0
	mov ebx,segstr15d
	sysenter
	ffree st0

	;Xmid
	fld qword [esi+112]  ;xmid
	mov eax,36           ;dumpst0
	mov ebx,segstr15e
	sysenter
	ffree st0

	;Ymid
	fld qword [esi+120]  ;ymid
	mov eax,36           ;dumpst0
	mov ebx,segstr15f
	sysenter
	ffree st0

	;Xnear
	fld qword [esi+128]  ;Xnear
	mov eax,36           ;dumpst0
	mov ebx,segstr15g
	sysenter
	ffree st0

	;Ynear
	fld qword [esi+136]  ;Ynear
	mov eax,36           ;dumpst0
	mov ebx,segstr15h
	sysenter
	ffree st0



	mov ebx,[esi+144]       ;x1 clipped inflated
	dumpebx ebx,DLstr18a,3  ;decimal

	mov ebx,[esi+148]       ;y1 clipped inflated
	dumpebx ebx,DLstr18b,3

	mov ebx,[esi+152]       ;x2 clipped inflated
	dumpebx ebx,DLstr18c,3

	mov ebx,[esi+156]       ;y2 clipped inflated
	dumpebx ebx,DLstr18d,3


	mov ebx,[esi+160]       ;x1 screen coordinate
	dumpebx ebx,DLstr19a,3

	mov ebx,[esi+164]       ;y1 screen coordinate
	dumpebx ebx,DLstr19b,3

	mov ebx,[esi+168]       ;x2 screen coordinate
	dumpebx ebx,DLstr19c,3

	mov ebx,[esi+172]       ;y2 screen coordinate
	dumpebx ebx,DLstr19d,3

	ret





;*********************************************
;segementselectdrag

;this procedure is called from main.s
;when a user makes a drag box
;if both endpoints of the segment
;are inside the drag box
;then we mark the segment as selected

;note the drag box upper left should be picked first
;then the lower right
;so that x2>x1 and y2>y1 in screen coordinates

;input:
;esi=address of segment object in link list
;edi=address of dragbox x1,y1,x2,y2 16 bytes

;return:none
;**********************************************

segmentselectdrag:

	dumpstr str106

	;we use the inflated/clipped screen coordinates
	;at offsets 144,148,152,156


	;is the segment off screen ? (trivial reject)
	;segmentpaint lineclipping sets this
	cmp dword [esi+8],2   ;2=segment is off screen
	jz .done



	;is segment endpoint x1,y1 inside bounding box ?
	;**************************************************
	mov eax,86          ;tlib ptinrect
	mov ebx,edi         ;address of dragbox coordinates
	mov ecx,[esi+144]   ;object x1 screen coordinate
	mov edx,[esi+148]   ;object y1 screen coordinate
	sysenter
	jnz .outsideBox


	;is segment endpoint x2,y2 inside bounding box ?
	;****************************************************
	mov eax,86          ;tlib ptinrect
	mov ebx,edi         ;address of dragbox coordinates
	mov ecx,[esi+152]   ;object x2 screen coordinate
	mov edx,[esi+156]   ;object y2 screen coordinate
	sysenter
	jnz .outsideBox


	;if we got here both endpoints are inside the dragbox

	dumpstr str107

	;if we got here both endpoints are inside the dragbox
	;mark the object as selected
	mov dword [esi+8],1
	jmp .done

.outsideBox:
	dumpstr str108

.done:
	ret





;********************************************
;SaveMidPoint

;call this function after every time you
;  * create a new segment
;  * modify a segment endpoint

;this function will recompute the midpoint
;and write xmid,ymid back to the link
;xmid,ymid is stored at offset 112,120

;input:esi=address of segment object
;return:none
;*********************************************

SaveMidPoint:

	;xmid
	fld  qword [esi+80]      ;st0=x1
	fadd qword [esi+96]      ;st0=x1+x2
	fmul qword [oneovertwo]  ;st0=(x1+x2)/2
	fstp qword [esi+112]     ;store xmid

	;ymid
	fld  qword [esi+88]      ;st0=y1
	fadd qword [esi+104]     ;st0=y1+y2
	fmul qword [oneovertwo]  ;st0=(y1+y2)/2
	fstp qword [esi+120]     ;save ymid

	ret

	



;a function that does nothing
objectstub:
	ret






;***************************************************************
;segmentpdf

;this is an object->writepdf procedure for TCD_SEGMENTS
;writes a TCD_SEGMENT object to a pdf graphic stream

;this function will write the following pdf commands:

;x y m  
;this is a MoveTo command

;x y l
;this is a LineTo command

;r g b RG
;this declares DeviceRGB color space with pen color r g b

;S
;this is the stroke operator (draw the line)


;all x,y coordinates are the clipped screen coordinates (pixels)
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


segmentpdf:

	push ebp
	mov ebp,esp
	sub esp,8  ;local variables
	;[ebp-4]    address of pdf graphic stream
	;[ebp-8]    address of segment object in link list


	;edi holds destination address for PDF graphic stream
	;throughout this proc edi must be preserved and incremented
	;with every byte written to the graphic stream buffer

	mov [ebp-4],edi  ;save destination stream address
	mov [ebp-8],esi  ;save address of segment object for later


	dumpstr str128



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

	;this tlib function will generate 3 pdf strings
	;x1 y1 m
	;x2 y2 l
	;S
	mov ebx,[esi+160]   ;x1
	mov ecx,[esi+164]   ;y1
	mov edx,[esi+168]   ;x2
	mov esi,[esi+172]   ;y2
	;edi=destination pdf buffer
	mov eax,124         ;linepdf
	sysenter


	;done writting PDF graphic stream commands 
	;for one TCD_SEGMENT


.done:

	;must return address of object in esi
	mov esi,[ebp-8]

	;edi holds address of end of graphic stream

	mov esp,ebp  ;deallocate locals
	pop ebp
	ret





;**********************************************************
;                   THE END
;**********************************************************
     


;just a friendly reminder to use double indirection
;when passing the address of a qword to any function in this
;file from the main.s

;e.g. assume the qword address is on the stack at ebp+8

;mov eax,[ebp+8]  ;retrieve address of qword
;fadd [eax]       ;add value to st0


;mov eax,3  ;dumpreg
;sysenter

;mov eax,9     ;dumpebx
;mov ecx,dum2  ;address string
;mov edx,0     ;dword register size







                                        