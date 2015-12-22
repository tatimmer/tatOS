
;Project: TCAD
;main02  Dec 18, 2015

;this is the main entry procedure for TCAD
;TCAD is a basic 2d cad program
;tcad assembles with ttasm for the tatOS operating system

;this version supports the following objects:
;  * TCD_SEGMENT

;2do: circle, arc, rectangle, text, dimension



;*****************************************
;	FUNCTION ENTRY POINTS
;	DATA SYMBOLS
;*****************************************

;EXTERN
;FeedbackMessageTable
;TopLevelMenu
;SEGMENT-MODIFY
;TcadMenuJumpTable
;LAYERS
;STRINGS
;StartOfCode
;PAINT
;CHECKC
;HOTKEY
;HANDLELEFTMOUSE
;HandleRightMouse
;HandleMiddleMouse
;HandleWheelAwayScreen
;HandleWheelTowardScreen
;PS2 KEYBOARD
;doEscape
;Pan
;ResetBackground
;FullScreenLinePointer
;DrawXYaxis
;InitLink1        (public)
;SetCurrentLayer
;SetObjectLayerToCurrent
;IDLELEFTMOUSEHANDLER
;doEnterKeyHandler
;EnterKeyDefaultHandler
;FlipKeyDefaultHandler
;DragBoxPaint
;MoveObjects
;CopyObjects
;ScaleObjects
;MirrorObjects
;DeleteSelectedObjects
;RotateLeftMouseHandler
;MeasureAngle3Points
;MeasureAngle2Segments
;MeasureDistance
;SetGridSize
;DrawGrid
;DumpSel
;DumpAll
;GetSelObj          (public)
;GetMousePnt        (public)
;UnselectAll        (public)
;GetLayItems        (public)
;CreateBLink        (public)
;float2int          (public)



;*************************************************************


org STARTOFEXE

;erase the public and extern symbol tables
;this must be done before assembling the main source file
;assembling the secondary source files just appends data to these tables
erasepe  

;assign a unique number to this source file
source 0



;****************
;  EXTERN
;****************

;symbols that are defined in other files
;all extern & public symbols are max 11 bytes

;symbols defined in io.s
extern FileOpenTCD
extern FileSaveTCD
extern tcd2pdf

;symbols defined in seg.s
extern segmodify
extern segcreate
extern segcreatek
extern segcreatemk
extern segcreateMI
extern segcreMPD2
extern segcreIPD2
extern CornerSeg
extern ChamferSeg
extern ExtndTrmSeg
extern OffsetSegK
extern OffsetSegM
extern RotateSegK
extern RotateSegM
extern SetChamSize
extern GetNearPnt





;*********************
;    PUBLIC DWORDS
;*********************

;here we make available to other files in tcad
;certain data symbols. public symbols are max 11 bytes

public LftMousProc
dd 0
public EntrKeyProc
dd 0
public FlipKeyProc
dd 0
public PassToPaint
dd 0
public headlink
dd 0




;*****************
;TCAD Memory Map
;*****************

;tatOS userland code and data may reside in 0x2000000->0x2400000
;for TCAD we divide up this space as follows:

;0x2000000-0x2100000 TCAD executable space available
;as of Nov 2015 TCAD assembles to 0x200fad3

;0x2100000-0x2200000 TCAD link list
;each link is 256 bytes
;this allows for a max of 0x1000 or 4096 graphic objects
equ STARTTCADLINKLIST 0x2100000

;0x2200000-0x2400000 scratch memory to build/load a tcd file
;or to generate a pdf






;**************
;    EQUates
;**************

equ TEMPSEG 1
equ HITOLERANCE 5
equ NOTAVAILABLE 41
equ YES 1
equ COLORGRID 0xdc   


;object types
equ TCD_SEGMENT  0
equ TCD_CIRCLE   1
equ TCD_ARC      2
equ TCD_RECT     3
equ TCD_TEXT     4
equ TCD_DIM      5




;*******************
;   local QWORDS
;*******************

zoom:   
dq 0.0
zoom_reset:
dq 50.0

zoom_inc:
dq 1.2
zoom_min:
dq 1.0

xorg:
dq 0.0
xorg_reset:
dq 20.0

yorg:
dq 0.0
yorg_reset:
dq 20.0

MOUSEXF:
dq 0.0
MOUSEYF:
dq 0.0

originXF:
dq 0.0
originYF:
dq 0.0

;various floating point constants
One:
dq 1.0
Two:
dq 2.0
deg2rad:
dq .0174532
90DEGREES:
dq 1.570796327
HALF:
dq 0.5

ScreenHeight:
dq 600.0
ScreenWidth:
dq 800.0

mx:
dq 1.0
my:
dq 1.0

X1:
dq 0.0
Y1:
dq 0.0
X2:
dq 0.0
Y2:
dq 0.0
XC:
dq 0.0
YC:
dq 0.0

Length:
dq 0.0
Angle:
dq 0.0
Angle_ref:
dq 0.0

DX:
dq 0.0
DY:
dq 0.0
DeltaX:
dq 0.0
DeltaY:
dq 0.0
DXnew:
dq 0.0
DYnew:
dq 0.0

storeQ:
dq 0.0

offset:
dq 0.0
offsetside:
dq 0.0

point1X:
dq 0.0
point1Y:
dq 0.0
point2X:
dq 0.0
point2Y:
dq 0.0

ScaleFactor:
dq 0.0







;******************
;   local DWORDS
;******************

mousex:
dd 0
mousey:
dd 0
mousedx:
dd 0
mousedy:
dd 0
storeD:
dd 0
Layer:
dd 0
linetype:
dd 0
showmouse_xy:
dd 0
leftbuttonqtyclick:
dd 0
ismouseoverpoint:
dd 0
backgroundcolor:
dd 0
originX:
dd 0
originY:
dd 0
sizeoflinklist: ;number of objects in graphic link list
dd 0
stor:
dd 0
storX1:
dd 0
storY1:
dd 0
storX2:
dd 0
storY2:
dd 0
zoom_dump:
dd 0
address_YellowBoxPoint:
dd 0
px:
dd 0
py:
dd 0
qx:
dd 0
qy:
dd 0
object:
dd 0
HaveLeftMousePick:
dd 0
DrawDragBox:
dd 0
leftmouseX:
dd 0
leftmouseY:
dd 0
CurrentObjectLink:     ;address of current object being defined
dd 0
ShowGrid:
dd 0
GridSize:
dd 0
PointerType:
dd 0
Pivot:
dd 0
PointAddress:
dd 0
color:
dd 0
PostPaintHandler:
dd 0
ObjectPaintHitTest:
dd 0
ObjectPaintYellow_X:
dd 0
ObjectPaintYellow_Y:
dd 0
segment1:
dd 0
segment2:
dd 0
LBUTstate:
dd 0





;*******************
;link list pointers
;*******************
;the headlink has been made public see above
taillink:
dd 0
newlink:
dd 0
currentlink:
dd 0




;************************
;   BYTES/ARRAYS
;************************


;storage for building complex strings or whatever 
buffer:
db0 100

;storage for building printf strings to display object properties
;segmentselect will use this to build a string: 
;"x1,y1,x2,y2,length,angle,layer"
ObjectProperties:
db0 100

MirrorLinePoints:
db0 32

;for storage of floating point coordinates x1,y1,x2,y2
vector1:
db0 32

;another storage of floating point coordinates x1,y1,x2,y2
vector2:
db0 32

;local storage for comprompt strings
compromptbuf:
db0 100

;x1,y1,x2,y2 corners of a drag box for object selection
dragbox:
db0 16




;******************
;  local STRINGS
;******************


str1:
db 'HandleLeftMouse',0
str2:
db 'right mouse',0
str3:
db 'middle mouse',0
str4:
db 'wheel away',0
str5:
db 'wheel toward',0
str6:
db 'mouse move',0
str7:
db 'reset zoom,xorg,yorg',0
str9:
db 'GetLayerItem color',0


str10:
db 'Total qty selected objects',0
str11:
db 'Enter key default handler',0
str13:
db '<Move> Select base point',0
str14:
db '<Move> Select destination point',0
str15:
db 'Exiting-insufficient selections',0
str16:
db 'address Paint Oject',0
str17:
db 'layer visibility',0
str18:
db 'layer color',0
str19:
db 'layer linetype',0

str20:
db 'current layer index',0
str21:
db '[Copy] Select objects then ENTER',0
str22:
db 'CreateBlankLink',0
str23:
db 'sizeoflinklist',0
str24:
db 'GetMousePoint',0
str25:
db '[Move] Select objects then ENTER',0
str26:
db 'function not available',0
str27a:
db 'Dump Selected Links',0
str27b:
db 'Dump All Links',0



str31:
db 'doing fxch BAD ZOOM',0
str32:
db 'ScaleObjects',0
str33:
db 'ScaleObjects_11',0
str34:
db 'segment paint',0
str35:
db 'object qty points',0
str36:
db 'intersection point',0
str37:
db 'ScaleObjects_22',0
str38:
db '[SegModVertical] Select segment to modify',0
str39:
db 'LINECLIP return value',0

str40:
db '[Rotate] Enter Rotate Angle,deg,as float',0
str41:
db '[Rotate] Select an endpoint xc,yc as center of rotation',0
str41a:
db '[Rotate] Select ref endpoint on objects to rotate',0
str41b:
db '[Rotate] Select dest endpoint to determine angle of rot',0
str42:
db '[MeasureAngle-3pts] Pick common START point',0
str43:
db '[MeasureAngle-3pts] Pick Endpoint #1',0
str44:
db '[MeasureAngle-3pts] Pick Endpoint #2',0
str45:
db '[MeasureDistance] Pick Endpoint #1',0
str46:
db '[MeasureDistance] Pick Endpoint #2',0
str47:
db '[Rotate] Select objects then hit ENTER',0
str48:
db '[Offset] Select line segment to offset',0
str49:
db '<Copy> Select base point',0

str50:
db '<Copy> Select destination point',0
str51:
db 'Enter Grid Spacing',0
str52:
db '[MousePointer] Enter 0=arrow, 1=line, 2=cross',0
str53:
db '[Mirror] Select mirror line',0
str54:
db '[Mirror] Select Objects to mirror then hit ENTER',0
str55:
db 'menu jmp address',0
str56:
db '[SegModHorizontal] Select segment to modify',0
str57:
db '[SegCreateIPD2] Select line to be perpendicular to',0
str58:
db '[Offset] 0.0=offset by mouse pick, n.n=offset amount, f=flip',0
str59:
db '[OffsetByMousePick] Select destination point for offset',0

str60:
db '[Scale] Select objects then hit ENTER',0
str61:
db '[Scale] Enter scale factor as float',0
str62:
db '[Scale] Select Reference Point',0
str63:
db '[Modify] Select an object to modify and hit ENTER',0
str64:
db 'OrthoMode=On',0
str65:
db 'OrthoMode=Off',0
str66:
db '[SegCreateIPD2] Select segment1 for intersection',0
str67:
db '[SegCreateIPD2] Select segment2 for intersection',0
str68:
db 'Flip key default handler',0
str69:
db '[Modify] Enter new Layer number',0

str70:
db 'Select Pivot Point',0
str71:
db 'Pick which side to rotate towards',0
str72:
db 'Pivot is P1',0
str73:
db 'Pivot is P2',0
str74:
db 'User has picked RIGHT of pivot',0
str75:
db 'User has picked LEFT of pivot',0
str77:
db 'User has picked ABOVE pivot',0
str78:
db 'User has picked BELOW pivot',0
str79:
db 'qty links dumped',0



str81:
db '[SegCreateMPD2] Select P1 endpoint end/mid/near/scratch',0
str82:
db '[Parallel] Select reference endpoint #1',0
str83:
db '[Corner] Select segment #1',0
str84:
db '[Corner] Select segment #2',0
str85:
db '[SegCreateMPD2] Select line to be perpendicular-to',0
str87:
db '[SegModParallel] Select reference endpoint #2',0
str88:
db '[SegModParallel] Select pivot point on segment to rotate',0
str89:
db '[SegModPerpendicular] Select reference endpoint #1',0

str90:
db '[SegModPerpendicular] Select reference endpoint #2',0
str91:
db '[SegModPerpendicular] Select pivot point on segment to rotate',0
str92:
db '[SegModEqual] Select fixed endpoint on segment to modify',0
str93:
db '[SegModEqual] Select reference segment for equal length',0
str94:
db '[SegModLength] Select fixed endpoint on segment to adjust length',0
str95:
db '[SegModLength] Select segment to modify',0
str97:
db '[Endpoint] Select endpoint to move',0
str98:
db '[Endpoint] Select destination endpoint',0
str99:
db '[Midpoint] Select endpoint to move',0

str100:
db '[Midpoint] Select destination segment & hit ENTER',0
str101:
db '[SegmentModifyAngle] Select reference segment',0
str103:
db 'function not available yet',0
str104:
db 'Create Segment',0
str105:
db 'DragBoxPaint',0
str106:
db 'do file open',0
str107:
db 'do file save',0
str108:
db 'function not implemented yet',0
str109:
db 'address linkPrevious',0

str110:
db 'address linkNext',0
str111:
db 'Delete Selected Objects',0
str112:
db 'segment modify',0
str113:
db 'no selection',0
str115:
db 'get selected segment',0
str116a:
db '[GetSelectedObjects] Address 1st selected object',0
str116b:
db '[GetSelectedObjects] Address 2nd selected object',0
str118:
db '[SegP2C]address of segment',0
str119:
db '[SegP2C]which endpoint',0

str120:
db '[SegP2C]qword length',0
str121:
db '[SegP2C]qword angle',0
str122:
db 'invalid endpoint ID',0
str123:
db '[Chamfer] Select segment #1',0
str124:
db '[Chamfer] Select segment #2',0
str125:
db 'float2int',0
str128:
db 'IdleLeftMouseHandler',0
str129:
db '[AngleFrom] error-requires segments with common endpoint',0


str130:
db '[GetMousePoint] base x,y on yellowbox point',0
str131:
db '[GetMousePoint] base x,y on mouse',0
str132:
db 'CopyObjects',0
str133:
db 'CopyObjects_11',0
str134:
db 'CopyObjects_22',0
str135:
db 'CopyObjects_33',0
str136a:
db 0xa
db 'Main.paint',0
str136b:
db 'Main.endpaint',0
str137:
db 'MirrorObjects',0
str138:
db 'MirrorObjects_11',0
str139:
db 'MorrorObjects_22',0

str140:
db '<line> Lpick 2 points',0
str141:
db '[Extend/Trim] Select cutting line',0
str142:
db '[Extend/Trim] Select segments to extend/trim, ESC to quit',0
str143:
db '[Line-mk] Pick segment starting endpoint',0
str145:
db '[SegmentModifyX1Y1] Select segment to modify',0
str146:
db '[SegmentModifyX2Y2] Select segment to modify',0
str147:
db '[SegmentModifyEndpoint] Select segment to modify',0
str148:
db '[SegmentModifyParallelTo] Select segment to modify',0
str149:
db '[SegmentModifyPerpendicularTo] Select segment to modify',0

str150:
db '[MeasureAngle-2seg] Pick seg #1 furthest from virtual intersect',0
str151:
db '[MeasureAngle-2seg] Pick seg #2 furthest from virtual intersect',0
str152:
db 'MeasureAngle2Segments',0
str153:
db 'MeasureAngle2Seg_11',0
str154:
db 'MeasureAngle2Seg_22',0
str155:
db '[Line-im] Pick segment #1 for intersection',0
str156:
db '[Line-im] Pick segment #2 for intersection',0
str157:
db '[Line-im] Pick P2 end/mid/near or scratch point',0
str158:
db '[SegmentModifyEqual] Select segment to modify',0
str159:
db '[SegmentModifyAngle] Select segment to modify',0

str160:
db '[Line-mi] Pick P1 end/mid/near/scratch point',0
str161:
db '[Line-mi] Pick segment #1 for intersection',0
str162:
db '[Line-mi] Pick segment #2 for intersection',0
str163:
db 'Object Link #',0
str164:
db '[IdleLeftMouseHandler] Finish Drag Box',0
str165:
db '******************************************',0



;for debugging where we are in the code sometimes
flag1:
db 'flag1',0
flag2:
db 'flag2',0
flag3:
db 'flag3',0
flag4:
db 'flag4',0





;*****************************
;  Report qty Deleted Objects
;*****************************

;printf data structures

DeletedFBmess:
db0 100

DeletedStr1:
db ' selected objects deleted',0

DeletedQtyObjects:
dd 0

DeletedArgType:
dd 2,3

DeletedArgList:
dd DeletedQtyObjects,DeletedStr1



;******************************
;  Distance Measurement
;******************************

;printf data structures

DistString:
db0 100

DistStringTag:
db 'The distance beween endpoints is ',0

Distance:
dq 0.0

DistType:
dd 3,4

DistList:
dd DistStringTag,Distance






;******************************
;  Included Angle Measurement
;******************************

;printf needs this to build a complex string

AngleIncString:
db0 100

AngleIncStringTag:
db 'The included angle,deg is ',0

AngleInc:
dq 0.0

AngleIncType:
dd 3,4

AngleIncList:
dd AngleIncStringTag,AngleInc








;***********************
;FeedbackMessageTable
;***********************

;for displaying Paint messages during object creation
;for prompting the user and giving feedback
;the string is displayed at bottom left
;hitting ESC will display the default feedback message fbmess1


;this is the default feedback message index=0
;it is a combination string
;the first 4 chars are 'tcad'
;the remainder of the string gives the layer number
fbmess1:
db 'tcad layer0               ',0  

;the layer name starts at offset=5 in the fbmess1 string
equ LAYERNAMEOFFSET,fbmess1+5


strSTUB:
db 'xxx',0


FeedbackMessageTable:                            ;[Index]
dd fbmess1,str140,strSTUB,str13,str14            ;0,1,2,3,4
dd str41,str42,str43,str44,AngleIncString        ;5,6,7,8,9
dd str45,str46,DistString,str47,str48            ;10,11,12,13,14
dd str25,str21,str49,str50,str53                 ;15,16,17,18,19
dd str54,str59,str60,str62,str63                 ;20,21,22,23,24
dd str70,str71,str70,strSTUB,strSTUB             ;25,26,27,28,29
dd str41a,str82,str83,str84,str41b               ;30,31,32,33,34
dd strSTUB,str87,str88,str89,str90               ;35,36,37,38,39
dd str91,str26,str92,str93,str94                 ;40,41,42,43,44
dd str97,str98,str99,str100,str101               ;45,46,47,48,49
dd str103,str104,DeletedFBmess,str113            ;50,51,52,53
dd str123,str124,strSTUB,str64,str65             ;54,55,56,57,58
dd str129,str108,str141,str142,str143            ;59,60,61,62,63
dd strSTUB,str145,str146,str147,str148           ;64,65,66,67,68
dd str149,str150,str151,str155,str156            ;69,70,71,72,73
dd str157,str158,str159,str95,str56              ;74,75,76,77,78
dd str38,str160,str161,str162,str81              ;79,80,81,82,83
dd str85,str66,str67,str57,strSTUB               ;84,85,86,87,88



;to display a particular message just set this value to 0,1,2...
;to display the default feedback message hit ESCAPE
FeedbackMessageIndex:
dd 0




;*********************************
;     TopLevelMenu
;*********************************

;this is the data required to support 
;the tcad top level dropdown menus


;FILE menu
FileTitle:
db 'File',0
File1:
db 'Open tcd (o)',0
File2:
db 'Save tcd (s)',0
File3:
db 'Save pdf',0
File4:
db 'Exit (f12)',0

FileMenuStruc:
dd 0          ;id selected string
dd FileTitle  ;address title string
dd 0          ;x
dd 0          ;y
dd 99         ;w
dd 0          ;h
dd 0          ;expose
dd 4          ;qty strings
dd File1, File2, File3, File4

FileMenuProcTable:
dd doFileOpentcd, doFileSavetcd, doFileSavePDF, doExit






;DRAW menu
drawTitle:
db 'Draw',0
draw1:
db 'Line-mm (l)',0
draw2:
db 'Line-kk',0
draw3:
db 'Line-mk',0
draw4:
db 'Line-mi',0
draw5:
db 'Line-mpd2',0
draw6:
db 'Line-ipd2',0

;future 2do
;Draw4:
;db 'Circle',0
;Draw5:
;db 'Arc',0
;Draw6:
;db 'Text',0
;Draw7:
;db 'Rectangle',0

DrawMenuStruc:
dd 0          ;id selected string
dd drawTitle  ;address title string
dd 100        ;x
dd 0          ;y
dd 99         ;w
dd 0          ;h
dd 0          ;expose
dd 6          ;qty strings
dd draw1,draw2,draw3,draw4,draw5,draw6


DrawMenuProcTable:
dd doLineMM, doLineKK, doLineMK, doLineMI, doLineMP, doLineIP
;dd doCircle, doArc, doText, doRect






;DIMENSION menu
;none of this is implemented as of Dec 2013-future
DimTitle:
db 'Dimension',0
Dim1:
db 'DimLinear',0
Dim2:
db 'DimDia',0
Dim3:
db 'Leader',0

DimMenuStruc:
dd 0          ;id selected string
dd DimTitle   ;address title string
dd 200        ;x
dd 0          ;y
dd 99         ;w
dd 0          ;h
dd 0          ;expose
dd 3          ;qty strings
dd Dim1,Dim2,Dim3

DimMenuProcTable:
dd doDimLin, doDimDia, doLeader





;MODIFY menu
ModTitle:
db 'Modify',0
Mod0:
db 'extend/trim',0
Mod1:
db 'corner',0
Mod2:
db 'chamfer',0
Mod3:
db 'fillet',0
Mod4:
db 'offset-k',0
Mod5:
db 'offset-m',0
Mod6:
db 'rotate-k',0
Mod7:
db 'rotate-m',0
Mod8:
db 'scale',0
Mod9:
db 'mirror',0
Mod10:
db 'move',0
Mod11:
db 'copy',0
Mod12:
db 'layer',0

ModMenuStruc:
dd 0          ;id selected string
dd ModTitle   ;address title string
dd 300        ;x
dd 0          ;y
dd 99         ;w
dd 0          ;h
dd 0          ;expose
dd 13         ;qty strings
dd Mod0,Mod1,Mod2,Mod3,Mod4,Mod5,Mod6
dd Mod7,Mod8,Mod9,Mod10,Mod11,Mod12

ModMenuProcTable:
dd doExtendTrim, doCorner, doChamfer, doFillet
dd doOffsetKeyboard, doOffsetMouse, doRotateKeyboard, doRotateMouse 
dd doScale, doMirror, doMove, doCopy, doLayer






;MISC menu 
;doesnt every program need a "misc"
MiscTitle:
db 'misc',0
Misc1:
db 'ZoomReset (r)',0
Misc2:
db 'grid',0
Misc3:
db 'ChamfSize',0
Misc4:
db 'MeasAng-3pts',0
Misc5:
db 'MeasAng-2seg',0
Misc6:
db 'MeasDist',0
Misc7:
db 'DumpSel',0
Misc8:
db 'DumpAll',0
Misc9:
db 'ViewDump',0



MiscMenuStruc:
dd 0          ;id selected string
dd MiscTitle  ;address title string
dd 400        ;x
dd 0          ;y
dd 99         ;w
dd 0          ;h
dd 0          ;expose
dd 9          ;qty strings
dd Misc1,Misc2,Misc3,Misc4,Misc5,Misc6,Misc7,Misc8,Misc9

MiscMenuProcTable:
dd doZoomReset, doGrid, doChamfSize, doMeasAng1, doMeasAng2
dd doMeasDist,  doDumpSel, doDumpAll, doViewDump





;LAYER Select Menu
;for now you have to hard code all layers here
;future versions will allow the user to add layers dynamically
;while the program is running and save layers in the tcd file

layerSel:
db 'Layer',0
layerstr1:
db '0 default',0
layerstr2:
db '1 red',0
layerstr3:
db '2 center',0
layerstr4:
db '3 dimension',0
layerstr5:
db '4 blue',0
layerstr6:
db '5 cyan',0
layerstr7:
db '6 purple',0
layerstr8:
db '7 brown',0
layerstr9:
db '8 orange',0
layerstr10:
db '9 Ltgray',0


SelectLayerStruc:
dd 0          ;id selected string
dd layerSel   ;address title string
dd 500        ;x
dd 0          ;y
dd 99         ;w
dd 0          ;h
dd 0          ;expose
dd 10         ;qty strings
dd layerstr1,layerstr2,layerstr3,layerstr4,layerstr5
dd layerstr6,layerstr7,layerstr8,layerstr9,layerstr10

;we do not use a proc table to set layers







;SEGMENT-MODIFY Menu
smTitle:
db 'SegMod',0
sm1:
db 'x1,y1-k',0
sm2:
db 'x2,y2-k',0
sm3:
db 'endpoint-m',0
sm4:
db 'para To',0
sm5:
db 'perp To',0
sm6:
db 'tang To',0
sm7:
db 'equal To',0
sm8:
db 'angle From',0
sm9:
db 'length',0
sm10:
db 'horizontal',0
sm11:
db 'vertical',0
sm12:
db 'ortho',0

;not used are "near", "midpoint", "coincident with" and "colinear with"
;near/coincident and midpoint all live in segment paint
;colinear can be done with AngleFrom


SegmentModifyStruc:
dd 0                  ;ID of selected string provided by kernel
dd smTitle            ;title string
dd 600                ;x
dd 0                  ;y
dd 99                 ;width
dd 0                  ;height exposed
dd 0                  ;expose event
dd 12                 ;qty option strings
dd sm1,sm2,sm3,sm4,sm5
dd sm6,sm7,sm8,sm9,sm10
dd sm11,sm12







;*************************************************
;              LAYERS
;*************************************************

;here we reserve memory for layers
;with layers we control visibility, line color & linetype
;each layer is a structure of 32 bytes 
;the LayerTable is an array of structures
;there are 10 predefined layers 
;each layer is accessed in code by LayerTable[index] 
;where index = 0,1,2,3...
;the index number is stored in each object link list data
;use function GetLayerItems() to retrieve layer items
;use function SetLayerItems() to define a layer items

;layer structure:
;offset  size      description
;0       8 bytes   layer name
;8       dword     visibility:  1=visible, 0=not visible
;12      dword     line color (from tatOS std palette)
;16      dword     linetype   (first arg to the tatOS LINE function)
;the remaining 12 bytes are reserved for future use


;here we keep tract of the current layer
;each new object is automatically put into the "current" layer
currentlayer:
dd 0

;qtylayers is incremented with each new layer definition
;make sure we dont exceed 30
qtylayers:
dd 10


currentlayername:
db 'layer0  '


LayerTable:

;LayerTable[0]
db 'layer0  '
dd 1           ;visible
dd 0xfe        ;color white
dd 0xffffffff  ;solid line
db0 12

;LayerTable[1]
db 'layer1  '
dd 1           ;visible
dd 0xf5        ;color red
dd 0xffffffff  ;solid line
db0 12

;LayerTable[2]
db 'center  '
dd 1          
dd 0xfd        ;yellow
dd 0xffffe1f0  ;center line
db0 12

;LayerTable[3]
db 'dimenson'
dd 1
dd 0xf1        ;green
dd 0xffffffff
db0 12

;LayerTable[4]
db 'layer4  '
dd 1
dd 0xf0        ;blue
dd 0xffffffff
db0 12

;LayerTable[5]
db 'layer5  '
dd 1
dd 0xf2        ;cyan
dd 0xffffffff
db0 12

;LayerTable[6]
db 'layer6  '
dd 1
dd 0xf3        ;purple
dd 0xffffffff
db0 12

;LayerTable[7]
db 'layer7  '
dd 1
dd 0xf4        ;brown
dd 0xffffffff
db0 12

;LayerTable[8]
db 'layer8  '
dd 1
dd 0x0b        ;orange
dd 0xffffffff
db0 12

;LayerTable[9]
db 'layer9  '
dd 1
dd 0xf6        ;Lgray
dd 0xffffffff
db0 12



;save another 1000 bytes for future layers
;good enough for 30 more layers
db0 1000








;**************
;    CODE
;**************


..start



	;create top level menu dropdowns
	mov eax,105  ;dropdowncreate
	mov ebx,FileMenuStruc
	sysenter
	mov eax,105  ;dropdowncreate
	mov ebx,DrawMenuStruc
	sysenter
	mov eax,105  ;dropdowncreate
	mov ebx,DimMenuStruc
	sysenter
	mov eax,105  ;dropdowncreate
	mov ebx,ModMenuStruc
	sysenter
	mov eax,105  ;dropdowncreate
	mov ebx,MiscMenuStruc
	sysenter
	mov eax,105  ;dropdowncreate
	mov ebx,SelectLayerStruc
	sysenter
	mov eax,105  ;dropdowncreate
	mov ebx,SegmentModifyStruc
	sysenter
	


	;initialize xorg, yorg, zoom
	fld  qword [xorg_reset]
	fstp qword [xorg]     
	fld  qword [yorg_reset]
	fstp qword [yorg]     
	fld  qword [zoom_reset]
	fstp qword [zoom]

	fclex   ;clear all floating point exceptions


	;Y=0 is at bottom of screen, Y=599 is at top
	;X=0 is at left edge as usual
	mov eax,28  ;setyorient
	mov ebx,-1 
	sysenter


	;necessary house keeping before first object link is created
	call InitLink1
	mov dword [sizeoflinklist],0
	


	;initialize 
	mov dword [FeedbackMessageIndex],0
	mov dword [LftMousProc],IdleLeftMouseHandler 
	mov dword [EntrKeyProc],EnterKeyDefaultHandler
	mov dword [FlipKeyProc], FlipKeyDefaultHandler
	mov dword [PostPaintHandler],0
	mov dword [PassToPaint],0



	;0x20202000 is an ascii string: SPACESPACESPACE0 terminated
	;so if no object is selected with Lclick then
	;in paint the ObjectProperties string is just blank
	mov dword [ObjectProperties],0x20202000
	


	;holds address of object being created with mouse or keyboard
	;else holds 0
	mov dword [CurrentObjectLink],0 


	;start with arrow pointer
	mov dword [PointerType],0 


	;change the background color to black
	mov eax,61  ;setdaccolor
	mov dl,0    ;red
	mov dh,0    ;green
	mov bl,0    ;blue
	mov cl,0xff ;ff=background
	sysenter




;**************
;    PAINT
;**************

AppMainLoop:

	backbufclear

	;use sparingly for debug only since this will flood the dump

	;dumpstr str136a     ;debug: "Paint"


	;get and save mouse movement with every paint loop
	;mousex,mousey are screen coordinates, pixels
	mov eax,64  ;getmousexy
	sysenter   
	mov [mousex],eax 
	mov [mousey],ebx  
	mov [mousedx],esi
	mov [mousedy],edi



	;draw the grid
	cmp dword [ShowGrid],1 
	jnz .doneShowGrid
	call DrawGrid
.doneShowGrid:





	;display the zoom factor at x=580
	fld qword [zoom]
	putst0 FONT02,580,15,0xfeff,2
	ffreep st0




	;convert mouse coordinates to float
	;display MOUSEXF, MOUSEYF lower right at x=650 and 730
	fild dword [mousex]
	fsub dword [xorg]     ;st0=mousex-xorg
	fdiv qword [zoom]     ;st0=(mousex-xorg)/zoom
	fst  qword [MOUSEXF]
	putst0 FONT02,650,15,0xfeff,3
	ffreep st0
	fild dword [mousey]
	fsub qword [yorg] 
	fdiv qword [zoom] 
	fst  qword [MOUSEYF] 
	putst0 FONT02,730,15,0xfeff,3
	ffreep st0





	;PAN (middle mouse button down while moving mouse)
	mov eax,87  ;getmousebutton
	mov ebx,1   ;middle button
	sysenter    ;returns eax 1=dn, 0=up
	cmp eax,1
	jnz DonePan
	call Pan
DonePan:




	;we start at the beginning of every paint cycle
	;by assuming the mouse is not over an object point
	;if the mouse is over an objects point (end/mid/center...)
	;the objects paint routine will return a valid address
	;for that particular object point, otherwise return 0
	;this global is used by GetMousePoint
	mov dword [address_YellowBoxPoint],0

	;we use this to store the result of object->paint hit testing
	mov dword [ObjectPaintHitTest],0



	;go thru the link list and draw the objects
	;*******************************************
	
	;check for empty link list, nothing to draw
	cmp dword [sizeoflinklist],0
	jz DonePaintObjects

	;get address to start of our link list
	mov esi,[headlink]

PaintObject:


	;debug: dump the object we are painting
	;mov eax,[esi+60]  ;eax=object dump proc
	;call eax


	;must preserve address of link
	push esi

	;inputs to object paint proc's
	;object paint proc must cleanup 8 args from stack
	;esi=address of object to paint
	push zoom
	push xorg
	push yorg
	push dword [mousex]
	push dword [mousey]
	push MOUSEXF
	push MOUSEYF

	mov eax,[esi+20] ;get address of paint routine
	call eax         ;call object->paint

	;segment->paint returns the following
	;eax = dword flag to indicate if mouse is over/near this object
	;      0 mouse is not over/near this object
	;      1 mouse is over an object "point"
	;      2 mouse is "near" the object
	;ebx = X screen coordinates of YellowBox point
	;ecx = Y screen coordinates of YellowBox point
	;edx = address of YellowBox point (floating point coordinates)


	;check for valid address of yellow box point
	;we must not overwrite a previously saved address 
	cmp edx,0
	jz .1
	;save address of yellow box point for benefit of GetMousePoint
	mov [address_YellowBoxPoint],edx


	;note that an object "point" hit test takes precedence
	;over the "near" hit test, so that if we have already stored
	;an object point return value, then we ignore anything else

.1:
	cmp dword [ObjectPaintHitTest],1
	jz .3  ;we already stored an object point
	cmp eax,0
	jz .3  ;no storage of point or near reqd for this object
	cmp eax,1
	jz .2  ;store point

	;if we got here we store "near"
	mov dword [ObjectPaintHitTest],2
	mov dword [ObjectPaintYellow_X],ebx
	mov dword [ObjectPaintYellow_Y],ecx
	jmp .3
	
	
.2: ;store point
	mov dword [ObjectPaintHitTest],1
	mov dword [ObjectPaintYellow_X],ebx
	mov dword [ObjectPaintYellow_Y],ecx
	;fall thru

.3:
	pop esi     ;restore address of link


	;get address of next link
	mov esi,[esi+76]

	;are we at the end of the link list ?
	cmp esi,0
	jnz PaintObject
	
DonePaintObjects:



	;Now we will draw our "Yellow" marker hit test result
	;for mouse over an endpoint we draw a yellow box
	;for mouse near a segment we draw a yellow "L"
	

	cmp dword [ObjectPaintHitTest],1   ;point
	jz .drawYellowBox

	cmp dword [ObjectPaintHitTest],2   ;near
	jz .drawYellowL

	jmp .doneYellow



.drawYellowBox:

	;draw Yellow Box over a start/mid/end point
	mov eax,39        ;tlib rectangle function
	mov ebx,[ObjectPaintYellow_X] ;ebx=x1
	sub ebx,5         ;ebx=x1-5
	mov ecx,[ObjectPaintYellow_Y] ;ecx=y1
	sub ecx,5         ;ecx=y1-5
	mov edx,10        ;width=10
	mov esi,10        ;height=10
	mov edi,YEL       ;color
	sysenter

	jmp .doneYellow


.drawYellowL:

	;draw yellow angle at NEAR point
	mov eax,102   ;tlib vline function
	mov ebx,[ObjectPaintYellow_X]
	mov ecx,[ObjectPaintYellow_Y]
	mov edx,10
	mov esi,YEL
	sysenter
	mov eax,101   ;hline
	mov ebx,[ObjectPaintYellow_X]
	mov ecx,[ObjectPaintYellow_Y]
	mov edx,10
	mov esi,YEL
	sysenter


.doneYellow:






	;draw a drag box
	;this requires 2 Lpicks
	cmp dword [DrawDragBox],1 
	jnz DoneDrawDragBox
	call DragBoxPaint
DoneDrawDragBox:



	;show the origin X and Y axis
	call DrawXYaxis


	;show a feedback message
	;this may be a message to prompt the user or 0=default
	;if default feedback message index = 0 is being displayed
	;you will see something like this: "tcad layerX"
	;where X is the current layer number
	;SetCurrentLayer proc modifies message index 0
	mov ecx,[FeedbackMessageIndex]
	mov esi,FeedbackMessageTable[ecx]
	puts FONT02,0,10,esi,0xfeff



	;show the selected Object Properties
	;when you Lclick on an object 
	;the object->selection proc will generate a string
	;and write the address to dword [ObjectProperties]
	puts FONT02,0,575,ObjectProperties,0xfeff

	



	;paint the top level menu dropdowns
	mov eax,106  ;dropdownpaint
	mov ebx,FileMenuStruc
	sysenter
	mov eax,106  ;dropdownpaint
	mov ebx,DrawMenuStruc
	sysenter
	mov eax,106  ;dropdownpaint
	mov ebx,DimMenuStruc
	sysenter
	mov eax,106  ;dropdownpaint
	mov ebx,ModMenuStruc
	sysenter
	mov eax,106  ;dropdownpaint
	mov ebx,MiscMenuStruc
	sysenter
	mov eax,106  ;dropdownpaint
	mov ebx,SelectLayerStruc
	sysenter
	mov eax,106  ;dropdownpaint
	mov ebx,SegmentModifyStruc
	sysenter



	;dumpstr str136b     ;debug: "endpaint"


EndPaint:

	;draw the mouse pointer
	;62=arrow pointer
	;88=cross pointer
	mov eax,62  ;arrowpointer
	sysenter
	;or call FullScreenLinePointer


	;PostPaintHandler
	;this function will only get exected once
	;typically a user will make a selection 
	;then the screen will get rePAINTed to show the selection
	;then the PostPaintHandler gets executed
	;see the "Corner" proc in seg.s for an example
	;see also the end of IdleLeftMouseHandler
	;where the value of PostPaintHandler is assigned
	mov eax,[PostPaintHandler]
	cmp eax,0
	jz .done

	;call the PostPaintHandler
	call eax

	;process return values
	mov [FeedbackMessageIndex],eax
	mov [LftMousProc],ebx

	;prevent this procedure from being executed more than once
	mov dword [PostPaintHandler],0


.done:
	swapbuf
	;endpaint




	;*********************
	;  PS2 KEYBOARD
	;*********************

	mov eax,12  ;checkc
	sysenter    ;return ascii keypress in al
	jz NoKeypress



	;HOTKEY definitions

	cmp al,99   ;'c' circle
	jz doCircle

	cmp al,100  ;'d' distance
	jz doMeasDist

	cmp al,102  ;'f' flip
	jz doFlipKeyHandler

	cmp al,108  ;'l' line by 2 mouse picks
	jz doLineMM

	cmp al,111  ;'o' open tcd
	jz doFileOpentcd

	cmp al,114  ;'r' reset zoom
	jz doZoomReset

	cmp al,115  ;'s'  save tcd
	jz doFileSavetcd


	cmp al,COPY
	jz doCopy

	cmp al,PASTE
	jz doPaste

	cmp al,ESCAPE
	jz doEscape

	cmp al,DELETE
	jz doDelete

	cmp al,MENU
	jz doMenu

	cmp al,ENTER
	jz doEnterKeyHandler

	cmp al,F12
	jz doExit




NoKeypress:



	;*********************
	;  USB MOUSE
	;*********************


	mov eax,63  ;usbcheckmouse
	sysenter    ;al=mousebutton or wheel

	cmp al,0
	jz NoMouseActivity
	cmp al,1   
	jz HandleLeftMouse
	cmp al,2   
	jz HandleRightMouse
	cmp al,4   
	jz HandleMiddleMouse
	cmp al,5
	jz HandleWheelTowardScreen
	cmp al,6
	jz HandleWheelAwayScreen
NoMouseActivity:


	jmp AppMainLoop
	;this is the end of the "AppMainLoop"
	;all code below this point is just function calls
	







;***********************
;    HANDLELEFTMOUSE
;***********************
        
HandleLeftMouse:

	dumpstr str1

	;check for File menu selection
	mov eax,[FileMenuStruc]
	cmp eax,-1
	jz .doneFileMenu
	;get doFileOpen, doFileSave or doExit procedure address
	mov ebx,FileMenuProcTable[eax]
	;and jump to that procedure
	jmp ebx
	jmp AppMainLoop
.doneFileMenu:

	;check for Draw menu selection
	mov eax,[DrawMenuStruc]
	cmp eax,-1
	jz .doneDrawMenu
	;get procedure address
	mov ebx,DrawMenuProcTable[eax]
	;and jump to that procedure
	jmp ebx
	jmp AppMainLoop
.doneDrawMenu:

	;check for Dim menu selection
	mov eax,[DimMenuStruc]
	cmp eax,-1
	jz .doneDimMenu
	;get procedure address
	mov ebx,DimMenuProcTable[eax]
	;and jump to that procedure
	jmp ebx
	jmp AppMainLoop
.doneDimMenu:

	;check for Modify menu selection
	mov eax,[ModMenuStruc]
	cmp eax,-1
	jz .doneModMenu
	;get procedure address
	mov ebx,ModMenuProcTable[eax]
	;and jump to that procedure
	jmp ebx
	jmp AppMainLoop  
.doneModMenu:

	;check for Misc menu selection
	mov eax,[MiscMenuStruc]
	cmp eax,-1
	jz .doneMiscMenu
	;get procedure address
	mov ebx,MiscMenuProcTable[eax]
	;and jump to that procedure
	jmp ebx
	jmp AppMainLoop  
.doneMiscMenu:

	;check for Layer menu selection
	mov eax,[SelectLayerStruc]
	cmp eax,-1
	jz .doneLayerMenu
	call SetCurrentLayer  ;eax=ID of layer to set
	jmp AppMainLoop
.doneLayerMenu: 


	;check for Segment-Modify menu selection
	mov eax,[SegmentModifyStruc]
	cmp eax,-1
	jz .doneSegModMenu
	;pass headlink & current layer to these procs
	;some use them and some dont
	;eax=index into SegmentModifyProcTable, see seg.s
	mov esi,[headlink]      ;in case proc needs it
	mov edi,[currentlayer]  ;in case proc needs it
	call segmodify

	;all segmentmodify procs must return valid values in eax,ebx
	mov [FeedbackMessageIndex],eax
	mov [LftMousProc],ebx

	call UnselectAll
	jmp AppMainLoop
.doneSegModMenu: 




	;save mouse location for drag box
	mov eax,64  ;getmousexy
	sysenter    ;eax=mouseX, ebx=mouseY

	;leftmouseX,leftmouseY are used for drag box
	;they store the upper left starting corner of the drag box
	;the other corner is defined by mousex,mousey
	mov [leftmouseX],eax
	mov [leftmouseY],ebx



	;Finally call the Left Mouse Handler proc
	;this may be IdleLeftMouseHandler
	;or some object creation/modification routine
	;often a series of left mouse clicks 
	;is required to complete a task
	;so the first left mouse handler can assign
	;a second left mouse handler and so on 

	;for functions that need access to the link list
	;we pass address of headlink in esi
	mov esi,[headlink]

	cmp dword [LftMousProc],0
	jz .1

	;note this LeftMouseHandler gets called "before" PAINT
	call [LftMousProc]
	jmp .2

.1:
	call IdleLeftMouseHandler
	;fall thru
.2:
	;all left mouse handler procs must return the following:
	;eax=dword [FeedbackMessageIndex] or 0
	;ebx=dword address of a valid LeftMouseHandler or 0
	mov [FeedbackMessageIndex],eax
	mov [LftMousProc],ebx
	jmp AppMainLoop







;***********************
;    HandleRightMouse
;***********************
        
HandleRightMouse:

	jmp AppMainLoop




;***********************
;    HandleMiddleMouse
;***********************
        
HandleMiddleMouse:
	;the paint routine checks for middle mouse button down to pan
	jmp AppMainLoop



;*************************************************
;    HandleWheelAwayScreen
;    move the camera away from the screen
;    make objects smaller
;    (zoom out)
;    the key to making objects to grow and shrink
;    centered about the mouse 
;    is to use MOUSEXF,MOUSEYF 
;    these are the floating point coordinates 
;    of the mouse computed in paint
;    they are based on the old zoom factor 
;    not the newly inc/dec zoom factor
;*************************************************
        
HandleWheelAwayScreen:
	;dumpstr str4
	;first we decrement the zoom factor
	fld qword [zoom_min] 
	fld qword [zoom]    ;st0=zoom, st1=zoom_min
	;decrement zoom
	fsub qword [zoom_inc]   ;st0=zoom-zoom_inc, st1=zoom_min
	;dont let zoom get any smaller than zoom_min
	fcomi st1
	jnc ZoomGreaterThanMin
	dumpstr str31
	;if we got here than set zoom to zoom_min
	fxch st1   ;st0=zoom_min, st1=zoom-zoom_inc
ZoomGreaterThanMin:
	;save new zoom as (zoom-zoom_inc) but not less than zoom_min
	fstp qword [zoom] 
	ffree st0
	;redefine xorg about the mouse point
	;xorg = xorg + (MOUSEXF*zoom_inc)
	fld  qword [MOUSEXF] 
	fmul qword [zoom_inc] 
	fadd qword [xorg] 
	fstp qword [xorg] 
	;redefine yorg about the mouse point
	;yorg = yorg + (MOUSEYF*zoom_inc)
	fld  qword [MOUSEYF] 
	fmul qword [zoom_inc] 
	fadd qword [yorg] 
	fstp qword [yorg] 
	jmp AppMainLoop



;*********************************
;    HandleWheelTowardScreen
;    move camera closer to screen
;    make objects bigger
;    (zoom in)
;*********************************
        
HandleWheelTowardScreen:
	;dumpstr str5
	;increment zoom
	fld  qword [zoom] 
	fadd qword [zoom_inc] 
	fstp qword [zoom] 
	;redefine xorg about the mouse point
	;xorg = xorg - (MOUSEXF*zoom_inc)
	fld  qword [xorg]         ;st0=xorg
	fld  qword [MOUSEXF]      ;st0=MOUSEXF  st1=xorg
	fmul qword [zoom_inc]     ;st0=MOUSEXF*zoom_inc  st1=xorg
	fsubr st1                 ;st0=xorg-(MOUSEXF*zoom_inc)
	fstp qword [xorg] 
	ffree st0
	;redefine yorg about the mouse point
	;yorg = yorg - (MOUSEYF*zoom_inc)
	fld  qword [yorg] 
	fld  qword [MOUSEYF] 
	fmul qword [zoom_inc] 
	fsubr st1 
	fstp qword [yorg] 
	ffree st0

	;dump zoom,xorg,yorg for debug
	;fld [zoom] q
	;dumpst0
	;ffree st0
	;fld [xorg] q
	;dumpst0
	;ffree st0
	;fld [yorg] q
	;dumpst0
	;ffree st0

	jmp AppMainLoop







;*****************************************
;    Handlers for Menu & Function Keys
;*****************************************



doStub:
	jmp AppMainLoop




doEnterKeyHandler:
	;various functions respond differantly to the enter key
	;often user is prompted to make a selection then hit enter
	;the enter handler can then reassign a left mouse handler
	;dword [EntrKeyProc] stores a valid function entry point
	;the default function entry point is EnterKeyDefaultHandler

	;test for 0 value which means default handler
	cmp dword [EntrKeyProc],0
	jz .1

	;call a particular enter key handler
	call [EntrKeyProc]

	;all enter key handlers must return a feedback message in eax
	mov [FeedbackMessageIndex],eax

	jmp AppMainLoop
.1:
	call EnterKeyDefaultHandler
	jmp AppMainLoop




doFlipKeyHandler:
	;the 'f' flip key is generally used to rotate an object 180 deg
	;many routines like modify->horizontal may put the  object
	;180 deg from where you want it 
	;so just hit the f key to rotate the object 180 deg again
	;dword [FlipKeyProc] stores a valid function entry point
	;the default function entry point is FlipKeyDefaultHandler

	;test for 0 value which means default handler
	cmp dword [FlipKeyProc],0
	jz .1

	;call a particular flip key handler
	call [FlipKeyProc]
	jmp AppMainLoop
.1:
	call FlipKeyDefaultHandler
	jmp AppMainLoop





doFileOpentcd:

	call FileOpenTCD
	;returns eax=address of 28 byte structure
	;dword value of sizeoflinklist
	;qword value of zoom
	;qword value of xorg
	;qword value of yorg
	;else returns eax=0 on error
	cmp eax,0 
	jz AppMainLoop

	mov ebx,[eax] 
	mov [sizeoflinklist],ebx

	fld  qword [eax+4]  ;zoom
	fst  qword [zoom]
	fstp qword [zoom_reset]

	fld  qword [eax+12] ;xorg
	fst  qword [xorg]
	fstp qword [xorg_reset]

	fld  qword [eax+20] ;yorg
	fst  qword [yorg]
	fstp qword [yorg_reset]

	jmp AppMainLoop



doFileSavetcd:
	push [sizeoflinklist]
	push zoom
	push xorg
	push yorg
	call FileSaveTCD
	jmp AppMainLoop


doFileSavePDF: 
	call tcd2pdf
	jmp AppMainLoop


doExit:
	call ResetBackground
	exit  ;return to tatOS







doMove:
	call MoveObjects
	jmp AppMainLoop

doCopy:
	call CopyObjects
	jmp AppMainLoop

doDelete:
	;user must pre-select objects before calling this procedure
	call DeleteSelectedObjects
	jmp AppMainLoop


doPaste:
	jmp AppMainLoop





doLineMM:  ;P1 and P2 by mouse picks
	push [currentlayer]
	call segcreate
	;process return values
	mov [CurrentObjectLink],esi
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop

doLineKK:  ;P1 and P2 by keyboard input
	call segcreatek
	jmp AppMainLoop

doLineMK:  ;P1=mouse pick, P2=keyboard input
	call segcreatemk
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop

doLineMI:  ;P1=mouse, P2=intersection of 2 segments
	call segcreateMI
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop

doLineMP:  ;P1=mouse, P2=perpendicularTo
	call segcreMPD2
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop

doLineIP:  ;P1=intersection, P2=perpendicularTo
	call segcreIPD2
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop


	


doCircle:
	;not implemented yet
	mov dword [FeedbackMessageIndex],50
	jmp AppMainLoop

doArc:
	jmp AppMainLoop

doText:
	jmp AppMainLoop

doRect:
	jmp AppMainLoop



	



doDimLin:
	jmp AppMainLoop

doDimDia:
	jmp AppMainLoop

doLeader:
	jmp AppMainLoop




doCorner:
	call CornerSeg
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop

doFillet:
	mov dword [FeedbackMessageIndex],60 ;not implemented yet
	jmp AppMainLoop

doChamfer:
	call ChamferSeg
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop

doExtendTrim:
	;extend and trim both use the same function
	call ExtndTrmSeg
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop

doOffsetKeyboard:
	call OffsetSegK
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop


doOffsetMouse:
	call OffsetSegM
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop


doRotateKeyboard:
	call RotateSegK
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop


doRotateMouse:
	call RotateSegM
	mov dword [FeedbackMessageIndex],eax
	mov dword [LftMousProc],ebx
	jmp AppMainLoop


doScale:
	call ScaleObjects
	jmp AppMainLoop

doArray:
	jmp AppMainLoop

doMirror:
	call MirrorObjects
	jmp AppMainLoop

doLayer:
	call SetObjectLayerToCurrent
	call UnselectAll
	jmp AppMainLoop



doLetter_r:
doZoomReset:
	;reset zoom, xorg, yorg to default values
	dumpstr str7
	fld  qword [xorg_reset]
	fstp qword [xorg]     
	fld  qword [yorg_reset]
	fstp qword [yorg]     
	fld  qword [zoom_reset]
	fstp qword [zoom]     
	jmp AppMainLoop


doGrid:
	;turn grid on/off
	mov eax,110      ;toggle
	mov ebx,ShowGrid ;address of value to toggle
	sysenter
	cmp dword [ShowGrid],0
	jz AppMainLoop
	call SetGridSize
	jmp AppMainLoop


doChamfSize:
	call SetChamSize
	jmp AppMainLoop


doMeasAng1:  ;3 points
	call MeasureAngle3Points
	jmp AppMainLoop

doMeasAng2:  ;2 segments
	call MeasureAngle2Segments
	jmp AppMainLoop


doMeasDist:
	call MeasureDistance
	jmp AppMainLoop


doViewDump:

	;change the background color to the STD 38/34/27
	mov eax,61     ;setdaccolor
	mov dl,0x38    ;red
	mov dh,0x34    ;green
	mov bl,0x27    ;blue
	mov cl,0xff    ;ff=background
	sysenter

	mov eax,115  ;tlib view dump
	sysenter

	;change the background color back to black
	mov eax,61  ;setdaccolor
	mov dl,0    ;red
	mov dh,0    ;green
	mov bl,0    ;blue
	mov cl,0xff ;ff=background
	sysenter

	jmp AppMainLoop



doDumpSel:
	mov eax,121  ;dumpreset (erases the dump)
	sysenter
	call DumpSel
	jmp doViewDump
	;jmp AppMainLoop


doDumpAll:
	mov eax,121 
	sysenter
	call DumpAll
	jmp doViewDump
	;jmp AppMainLoop





doEscape:

	mov dword [HaveLeftMousePick],0 
	mov dword [DrawDragBox],0 
	mov dword [FeedbackMessageIndex],0 
	mov dword [LftMousProc],IdleLeftMouseHandler 
	mov dword [EntrKeyProc],EnterKeyDefaultHandler
	mov dword [FlipKeyProc], FlipKeyDefaultHandler
	mov dword [PassToPaint],0
	mov dword [ObjectProperties],0x20202000

	call UnselectAll

	jmp AppMainLoop




doMenu:
	;now we have the top level dropdowns so dont need this
	jmp AppMainLoop







;****************************************************************
;                       END OF MAIN
;****************************************************************




;*********************************************
;Pan
;this routine redefines xorg and yorg
;thereby giving the affect of the object
;sliding about on the screen as the user
;moves the mouse with the middle button down
;this works here because we continually 
;redraw the screen in app main loop
;**********************************************

Pan:
	;dumpstr str30
	;increment xorg by MOUSE_DX
	fild dword [mousedx]
	fld  qword [xorg] 
	fadd st1
	fstp qword [xorg] 
	ffreep st0
	;increment yorg by MOUSE_DY
	fild dword [mousedy]
	fld  qword [yorg] 
	fadd st1
	fstp qword [yorg] 
	ffreep st0
	ret



;reset the background color to TAN before program exit
ResetBackground:
	mov eax,61   ;setdaccolor
	mov dl,0x38  ;rd
	mov dh,0x34  ;gr
	mov bl,0x27  ;bl
	mov cl,0xff
	sysenter
	ret   



;******************************************************
;FullScreenLinePointer
;draw mouse cross hairs 
;that extend the full width and height of the screen
;input:none
;return:none
;******************************************************

FullScreenLinePointer:

	;vertical cross hair
	mov eax,30  ;line
	mov ebx,SOLIDLINE
	mov ecx,[mousex] ;x1
	mov edx,0        ;y1
	mov esi,[mousex] ;x2
	mov edi,599      ;y2
	mov ebp,WHI
	sysenter

	;horizontal cross hair
	mov eax,30  ;line
	mov ebx,SOLIDLINE
	mov ecx,0        ;x1
	mov edx,[mousey] ;y1
	mov esi,799      ;x2
	mov edi,[mousey] ;y2
	mov ebp,WHI
	sysenter

	ret




;*********************************************
;DrawXYaxis
;draws the XY axis showing where x=0 and y=0
;+x is right and +y is up
;the length of each axis is 50 pixels unclipped
;input:none
;return:none

;local
AxisUnclipped:
db0 16
AxisClipped:
db0 16
;*********************************************

DrawXYaxis:

	;show the origin X and Y axis
	fld   qword [xorg]       ;floating point
	fistp dword [originX]    ;dword int
	fld   qword [yorg] 
	fistp dword [originY] 


	;Set coordinates of Xaxis unclipped
	;***********************************
	mov eax,[originX]
	mov [AxisUnclipped],eax    ;x1
	add eax,50
	mov [AxisUnclipped+8],eax  ;x2=x1+50

	mov eax,[originY]
	mov [AxisUnclipped+4],eax  ;y1
	mov [AxisUnclipped+12],eax ;y2=y1
	

	;now clip the line endpoints of the Xaxis
	mov eax,90  ;lineclip
	mov esi,AxisUnclipped
	mov ebp,AxisClipped
	sysenter
	cmp eax,1
	jz .paintXaxisDone


	;draw the Xaxis
	mov eax,30               ;line
	mov ebx,0xffffffff       ;linetype
	mov ecx,[AxisClipped]    ;x1
	mov edx,[AxisClipped+4]  ;y1
	mov esi,[AxisClipped+8]  ;x2
	mov edi,[AxisClipped+12] ;y2
	mov ebp,BLU              ;color
	sysenter


.paintXaxisDone:


	;Set coordinates of Yaxis unclipped
	;***********************************
	mov eax,[originX]
	mov [AxisUnclipped],eax    ;x1
	mov [AxisUnclipped+8],eax  ;x2=x1

	mov eax,[originY]
	mov [AxisUnclipped+4],eax  ;y1
	add eax,50
	mov [AxisUnclipped+12],eax ;y2=y1+50
	

	;now clip the line endpoints of the Yaxis
	mov eax,90  ;lineclip
	mov esi,AxisUnclipped
	mov ebp,AxisClipped
	sysenter
	cmp eax,1
	jz .done


	;draw the Yaxis
	mov eax,30               ;line
	mov ebx,0xffffffff       ;linetype
	mov ecx,[AxisClipped]    ;x1
	mov edx,[AxisClipped+4]  ;y1
	mov esi,[AxisClipped+8]  ;x2
	mov edi,[AxisClipped+12] ;y2
	mov ebp,BLU              ;color
	sysenter


.done:
	ret




;*************************************************
;InitLink1
;before we create the very first link of the list
;or if the user deletes all objects 
;we need to call this function
;**************************************************

public InitLink1

	;tatOS reserves memory in the users page
	;after code, the link list begins at STARTOFLINKLIST
	mov esi,STARTTCADLINKLIST
	mov [newlink],esi
	mov [headlink],esi
	mov [taillink],esi

	mov dword [sizeoflinklist],0 
	mov dword [FeedbackMessageIndex],0 
	mov dword [HaveLeftMousePick],0 
	mov dword [DrawDragBox],0

	;we will not reset the current layer to 0
	;if user deletes all objects he may continue to draw
	;in the current layer
	ret




;*********************************************************
;CreateBLink
;Create Blank Link

;version December 2015

;this function allocates some memory for another graphic object
;and attaches the link to the end of our double link list
;each link of the list is 0x100=256 bytes
;the first 112 bytes are common
;the remaining bytes may be used by the object as need be 
;the "dat" pointer also makes provision for unique object data


;The structure of each link is as follows:

;offset  size     description
; 0      dword    object type
; 4      dword    object layer index 
; 8      dword    visibility state
;12      dword    qty points    (defined so far)
;16      dword    dat pointer
;20      dword    address paint  procedure
;24      dword    address delete procedure
;28      dword    address copy   procedure
;32      dword    address move   procedure
;36      dword    address mirror procedure
;40      dword    address modify procedure
;44      dword    address write  procedure
;48      dword    address read   procedure
;52      dword    address select by mouse pick procedure
;56      dword    address scale  procedure
;60      dword    address dump   procedure
;64      dword    address select by dragbox procedure
;68      dword    open-assign stub proc
;72      dword    address of previous link in double link list
;76      dword    address of next link in double link list
;80      qword    X1  object endpoint 1
;88      qword    Y1  object endpoint 1
;96      qword    X2  object endpoint 2  (if applicable)
;104     qword    Y2  object endpoint 2  
;this is the end of the common data



;offset[0]  object type is an unsigned dword integer value
;so far we only support the TCD_SEGMENT object but have plans
;to support others as well.
;0 = TCD_SEGMENT
;1 = TCD_CIRCLE
;2 = TCD_ARC
;3 = TCD_RECTANGLE
;4 = TCD_TEXT
;5 = TCD_DIM

;offset[4] layer index 
;unsigned dword integer
;there is an array of structures with 10 predefined layers
;you can add more by invoking EditLayer from the menu


;offset[8] visiblity state 
;unsigned dword value
;if=0 the object is totally or partially visible and the 
;     object=>paint routine shall draw the object with the 
;     linetype and color of its assigned layer
;if=1 the object is selected and the object paint routine shall 
;     draw the object with a special linetype
;if=2 the object is totally off screen and will not be drawn


;offset[12] qty points (defined so far)
;unsigned dword value
;this is the number of x,y qword floating point pairs 
;stored at offset 80 and following
;all object points are stored as qword floats
;as the object is created this value will increment from 0->1 to
;how every qty points is needed to define the object
;(for segments this goes from 0->1->2 )

;offset[16] "dat" pointer
;dword address
;is an optional pointer to unique object data
;if your object such as a polyline or MTEXT requires more data than
;can be stored in this link use alloc and save the dat pointer
;if unused set dat=0

;offset[20]  paint routine 
;dword address
;this routine draws the object
;if the object is selected this routine displays the object properties
;as a feedback message

;offset[24->71]
;the remaining object procedures are as follows. Most of these operate
;on a collection or group of selected objects. You must supply a valid
;procedure entry point for each of these or just a stub routine.
;delete:    remove object from link list, free unique object data
;copy:      make a duplicate copy of link with new location
;move:      relocate the object x,y position
;mirror:    copy object and locate as mirror image about a mirror line
;edit:      object endpoints or properties may be redefined via COMPROMPT
;write:     write object data to file
;read:      read object data from file 
;select:    object "hit test" routine (left mouse button down)
;scale:     to scale an object larger or smaller
;dump:      writes strings to the dump describing the object properties
;selectbox  select by drag box procedure


;offset[72] address of prev link in the list
;offset[76] address of next link in the list

;offset[80  we reserve 32 bytes for (4) qwords
;these are x1,y1,x2,y2 object coordinates
;not all objects will use all of these and some may need more
;80  qword X1 dbl prec floating point
;88  qword Y1
;96  qword X2
;104 qword Y2

;offset[112->256] available for unique object data
;additional x,y coordinates may be stored
;TCD_TEXT ascii bytes are saved here



;for type=TEXT we need 16 bytes for x,y location
;plus one byte for text height leaving 183 bytes for
;ascii characters

;for type=MTEXT we have same as above but also need
;one byte for width of rectangle that text fits in

;for type=POLYLINE we have enough space for only 12 points

;for type=DIMALIGNED we need ? bytes

;for type=ARC we need ? bytes



;input:none

;return:
;on success ZF is set and esi holds address of the new link
;on failure ZF is clear and esi=0
;**********************************************************

;public symbols can only be 11 bytes
public CreateBLink

	push eax
	push ebx
	push ecx
	push edx
	push edi
	push ebp

	dumpstr str22

	;****************       **************
	;    taillink   *  ---> *  newlink   *
	;****************       **************

	mov ebp, [taillink]  ;the last link of the list currently
	mov esi, [newlink]   ;new links are always appended to the list


	;dump address of newlink being created
	mov eax,esi



	;initialization of link data is the responsiblity
	;of the calling function


	;case 1: the first link of the list
	cmp dword [sizeoflinklist],0 
	jnz .notfirstlink
	mov dword [esi+72],0   ;newlink->prev=0
	mov dword [esi+76],0   ;newlink->next=0
	jmp .SuccessInsert
.notfirstlink:


	;case 2: all other cases append newlink after taillink
	mov [ebp+76],esi       ;taillink->next=newlink
	mov [esi+72],ebp       ;newlink->prev=taillink
	mov dword [esi+76],0   ;newlink->next=0
	mov [taillink],esi     ;save the new taillink


.SuccessInsert:
	xor eax,eax
	;return value
	mov esi,[newlink]
	;increment our link pointer
	;this will be the starting address of the next link
	add dword [newlink],256 
	;increment link count
	inc dword [sizeoflinklist] 

	;check to make sure we havent exceeded 8000 links/objects
	;????????????????

.done:
	pop ebp
	pop edi
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
	





objectstub:
	ret




;**********************************************************
;GetLayItems
;Get Layer Items

;retrieve information about a particular Layer
;input
;ecx=layer index (any layer not necessarily the current layer)
;    this must be a number from 0->9
;    since tcad is currently hardcoded for only 10 layers

;return
;on error CF is set
;on success CF is clear and
;eax=address of 8 byte layer name not 0 terminated
;ebx=visibility in low byte
;ecx=color in low byte
;edx=linetype
;edi=dword [currentlayer]
;esi is preserved

;************************************************************

public GetLayItems

	push esi

	;test to make sure layer index is within range ???
	cmp ecx,[qtylayers]
	jae .error

	shl ecx,5   ;layerindex * 32
	mov esi,LayerTable
	add esi,ecx
	;esi holds address of LayerTable(i)
	

	;eax= address of name
	mov eax,esi
	;stdcall esi,8,[DUMPSTRN]
	push eax

	;ebx= visibiliy in low byte
	mov ebx,[esi+8]
	mov eax,ebx
	;stdcall str17,0,[DUMPEAX]

	;ecx=color in low byte
	mov ecx,[esi+12]
	mov eax,ecx
	;stdcall str18,0,[DUMPEAX]

	;edx=linetype
	mov edx,[esi+16]
	mov eax,edx
	;stdcall str19,0,[DUMPEAX]
	pop eax

	;and we will return this also 
	mov edi,[currentlayer]


	clc  ;success
	jmp .done

.error:
	stc
.done:
	pop esi
	ret
	
	


;********************************************************
;SetCurrentLayer
;allow the user to set the current layer
;from a PickOptionMouse dialog box
;input: eax=ID of current layer to set
;       this value comes from dropdown
;return:none
;********************************************************

SetCurrentLayer:

	push eax  ;perserve

	;save new current layer
	mov [currentlayer],eax
	mov ebx,eax
	dumpebx ebx,str20,0

	;get layer information
	mov ecx,eax
	call GetLayItems
	;returns eax=address of 8 byte layer name not 0 terminated
	jc .done

	;copy the current layer name to fbmess1 default feedback message
	cld
	mov esi,eax
	mov edi,LAYERNAMEOFFSET
	mov ecx,8
	repmovsb

.done:
	pop eax  ;layer ID
	ret





;*************************************************
;SetObjectLayerToCurrent
;set all selected objects to the current layer
	
;input: none
;return: none
;**************************************************

SetObjectLayerToCurrent:

	;we will change all selected segments to the current layer
	;if there are no selected objects then nothing happens

	;go thru the link list
	mov esi,[headlink]
	mov edi,[currentlayer]

.1:
	cmp dword [esi+8],1  ;is object selected ?
	jnz .nextlink

	mov [esi+4],edi      ;set new layer for selected object

.nextlink:
	mov esi,[esi+76]     ;get address of next link
	cmp esi,0            ;is next link address valid ?
	jnz .1

	ret





;********************************************************
;IDLELEFTMOUSEHANDLER
;call this function when there is a left mouse event
;but we are not creating any new objects
;we test for drag box selection
;we test for object hit testing (calls object selection proc)
;input:this function uses a number of globals
;return:eax,ebx see notes below
;********************************************************

IdleLeftMouseHandler:

	dumpstr str128


	;if there are no links/objects then there is nothing to do
	cmp dword [sizeoflinklist],0 
	jz .done


	;has the user already selected the first corner of a drag box ?
	cmp dword [DrawDragBox],1  ;yes
	jz .2                      ;then process the 2nd corner



	;Left Mouse Pick Object Selection
	;***********************************
	;select individual object by mouse picking
	;we go thru the link list and call an object selection proc
	;for each object, the obj sel proc will return a value of 1
	;or 0 in ebx to indicate if the mouse has Lpicked the object
	;if so then eax holds address of feedback message index string
	;to display object properties
	;see "segmentselect" for example of how the obj sel proc works

	mov esi,[headlink]

.1:
	push esi           ;preserve

	;esi=address of object to hit test
	push ObjectProperties  ;pass address of printf buffer
	push MOUSEYF           ;pass address of MOUSEYF
	push MOUSEXF           ;pass address of MOUSEXY
	push zoom              ;pass address of zoom factor
	mov eax,[esi+52]       ;get address of object selection proc
	call eax               ;call object selection proc 
	;returns: 
	;eax=1 have selection or 0 no selection

	pop esi

	cmp eax,1 ;do we have a selection ?
	jz .done  ;break out and display the object properties


	;get address of next link
	mov eax,[esi+76]
	mov esi,eax

	;make sure address is valid
	cmp esi,0
	jnz .1






	;Drag Box Object Selection
	;*****************************
	;ok-the user did not Lpick on a single object
	;so instead we allow creation of a drag box in paint
	;you must Lpick once for the upper left corner
	;then move the mouse down to the lower left corner
	;and Lpick a 2nd time to complete the drag box
	mov dword [DrawDragBox],1 

	;save the first corner of the drag box
	mov eax,[mousex]
	mov [dragbox],eax
	mov eax,[mousey]
	mov [dragbox+4],eax

	mov eax,0   ;default feedback message index
	jmp .done



.2:

	dumpstr str164

	mov dword [DrawDragBox],0 

	;save the 2nd corner of the drag box
	mov eax,[mousex]
	mov [dragbox+8],eax
	mov eax,[mousey]
	mov [dragbox+12],eax
	

	;we get here after the user has completed the 2nd drag box pick
	;now we go thru the link list
	;and call an object "select by dragbox" procedure


	mov esi,[headlink]

.3:
	push esi                ;preserve


	;esi & edi are inputs to object selectbydragbox proc
	;esi=address of object
	mov edi,dragbox

	mov eax,[esi+64]        ;esi=address of selectbydragbox proc
	call eax                ;call it
	;this procedure is responsible to mark the object selected

	pop esi                 ;restore

	;get address of next link
	mov eax,[esi+76]
	mov esi,eax

	;check for end of link list
	cmp esi,0
	jnz .3

	;fall thru




.done:

	;you must allow this function to return to PAINT
	;otherwise selected objects will not appear selected

	mov eax,0  ;default feedback message index
	mov ebx,0  ;idle left mouse handler


	;here we assign a PostPaintHandler
	;the user may want to make a selection which requires
	;a PAINT to make the selection show up
	;then immediately continue execution of a users procedure
	;see MirrorObjects or CornerSegements for examples
	;PassToPaint is a public symbol
	mov ecx,[PassToPaint]
	mov [PostPaintHandler],ecx

	;to ensure that users post paint handler only gets executed 1x
	mov dword [PassToPaint],0


	;do not redefine the enter key or flip key handlers
	;procs like CopyObjects will require that
	;new enter key handlers be set by the previous enter key handler
	;new LeftMouse handlers be set by the previous left mouse handler
	;and so forth

	;return to line immediately after call to [LeftMouseHandler]
	;in HandleLeftMouse

	ret





;*********************************************
;DragBoxPaint
;draw a rectangle defined by the 
;mouse location when the left button
;was clicked (leftmouseX,leftmouseY)
;to the current mouse location (mousex,mousey)
;**********************************************

DragBoxPaint:

	;dumpstr str105  use sparingly floods the dump

	mov eax,30             ;line
	mov ebx, 0xffffffff    ;linetype
	mov ecx,[leftmouseX]   ;x1
	mov edx,[leftmouseY]   ;y1
	mov esi,[mousex]       ;x2
	mov edi,[leftmouseY]   ;y2
	mov ebp,WHI            ;color
	sysenter

	mov eax,30
	mov ebx,0xffffffff
	mov ecx,[leftmouseX] 
	mov edx,[leftmouseY] 
	mov esi,[leftmouseX] 
	mov edi,[mousey]
	mov ebp,WHI
	sysenter

	mov eax,30
	mov ebx,0xffffffff   
	mov ecx,[mousex]
	mov edx,[mousey]
	mov esi,[leftmouseX] 
	mov edi,[mousey]
	mov ebp,WHI
	sysenter

	mov eax,30
	mov ebx,0xffffffff   
	mov ecx,[mousex]
	mov edx,[mousey]
	mov esi,[mousex]
	mov edi,[leftmouseY] 
	mov ebp,WHI
	sysenter

	ret





;************************************************************
;MoveObjects
;move selected objects
;endpoints of existing objects are redefined by dx,dy

;user is prompted in the following order:
; * select objects then hit ENTER
; * select base point
; * select destination point
;*************************************************************

MoveObjects:

	;prompt the user to select objects then hit enter
	mov dword [FeedbackMessageIndex],15 

	;set left mouse handler for object selection
	mov dword [LftMousProc],IdleLeftMouseHandler 

	;after objects are selected, user must hit ENTER
	mov dword [EntrKeyProc],MoveObjects_11

	call UnselectAll

	ret



MoveObjects_11:

	;this is an ENTER key handler

	;prompt user to select the base point
	mov eax,3 

	;set new left mouse handler
	mov dword [LftMousProc],MoveObjects_22

	ret


	
MoveObjects_22:

	;this is a left mouse handler
	;we got here after user picked base point

	call GetMousePnt  ;returns st0=x, st1=y

	;save x1,y1 base point
	fstp qword [X1] 
	fstp qword [Y1]

	;prompt user to select destination point
	mov eax,4               ;feedback message index
	mov ebx,MoveObjects_33  ;new left mouse handler

	ret

	

MoveObjects_33:

	;this is a left mouse handler
	;we got here after user picked destination point

	call GetMousePnt  ;returns st0=x, st1=y

	;compute dx,dy for move operation
	fsub qword [X1] 
	fstp qword [DeltaX] 
	fsub qword [Y1] 
	fstp qword [DeltaY] 
	;object move routines must use DeltaX and DeltaY values
	;in order to define object endpoints


	;now go thru the entire link list
	;for every selected object 
	;we redefine the object endpoints
	;using x1=x1+dx, y1=y1+dy etc...
	mov esi,[headlink]

.moveSelectedObjects:

	;must preserve address of link
	push esi

	;is the object selected 
	cmp dword [esi+8],1 
	jnz .getNextLink

	;if we got here we have a selected object

	;we put 2 args on the stack
	;esi=address of object to move
	push DeltaX       ;address DeltaX
	push DeltaY       ;address DeltaY
	mov eax,[esi+32]  ;get the object move routine address
	call eax          ;call object move routine (i.e. segmentmove...)
	;object move routine must cleanup 2 args on stack


.getNextLink:

	;get address of next link
	pop esi
	mov esi,[esi+76]

	;make sure address is valid
	cmp esi,0
	jnz .moveSelectedObjects



	;done with move objects
	mov eax,0   ;feedback message index
	mov ebx,0   ;new left mouse handler
	mov dword [EntrKeyProc],0  ;default handler
	call UnselectAll

	ret







;*****************************************************************
;CopyObjects
;copy selected objects
;input:none
;return:none
;the code is nearly identical to the move operation 
;the only differance is the feedback messages
;and new objects are created rather than redefining existing ones
;*****************************************************************

CopyObjects:

	dumpstr str132

	;prompt the user to select objects then hit enter
	mov dword [FeedbackMessageIndex],16 

	;set left mouse handler for object selection
	mov dword [LftMousProc],IdleLeftMouseHandler 

	;after objects are selected, user must hit ENTER
	;set function to be called on ENTER keypress
	mov dword [EntrKeyProc],CopyObjects_11

	call UnselectAll

	ret



CopyObjects_11:

	dumpstr str133

	;this is an ENTER key handler

	;prompt user to select the base point
	mov eax,17  ;feedback message index
	mov dword [LftMousProc],CopyObjects_22

	ret


	
CopyObjects_22:  

	;this is a left mouse handler
	;we got here after user picked base point

	dumpstr str134

	call GetMousePnt  ;returns st0=x, st1=y

	;save x1,y1 base point
	fstp qword [X1] 
	fstp qword [Y1] 

	;prompt user to select destination point
	mov eax,18              ;feedback message index
	mov ebx,CopyObjects_33  ;new left mouse handler

	ret

	

CopyObjects_33:

	;this is a left mouse handler
	;we got here after user picked destination point

	dumpstr str135

	call GetMousePnt  ;returns st0=x, st1=y

	;compute dx,dy for copy operation
	fsub qword [X1] 
	fstp qword [DeltaX] 
	fsub qword [Y1] 
	fstp qword [DeltaY] 
	;object move routines must use DeltaX and DeltaY values
	;in order to define object endpoints


	;now go thru the entire link list
	;for every selected object 
	;we create new objects 
	;using x1=x1+dx, y1=y1+dy etc...
	mov esi,[headlink]

.copySelectedObjects:

	;must preserve address of link
	push esi

	;is the object selected 
	cmp dword [esi+8],1 
	jnz .getNextLink

	;if we got here we have a selected object

	;we put 2 args on the stack
	;esi=address of object to move
	push DeltaX       ;address DeltaX
	push DeltaY       ;address DeltaY
	mov eax,[esi+28]  ;get the object copy routine address
	call eax          ;call object copy routine (i.e. segmentcopy...)
	;object copy routine must cleanup 2 args on stack


.getNextLink:

	;get address of next link
	pop esi
	mov esi,[esi+76]

	;make sure address is valid
	cmp esi,0
	jnz .copySelectedObjects


	;done with copy objects
	mov eax,0  ;default feedback message index
	mov ebx,0  ;idle left mouse hanlder
	mov dword [EntrKeyProc],0  ;default handler
	call UnselectAll

	ret







;**********************************
;UnselectAll
;input:none
;return:none
;**********************************

public UnselectAll

	mov esi,[headlink]

.next:
	mov dword [esi+8],0   ;set to unselected
	mov esi,[esi+76]      ;get address of next link
	cmp esi,0       	 ;end of link list test 
	jnz .next

	;makes drag box possible
	mov dword [HaveLeftMousePick],0 

	ret






;**********************************
;DeleteSelectedObjects
;go thru the link list
;and delete all selected objects
;offset 8 in the link is the visibility state
;   0=all or partially visible
;   1=selected
;   2=clipped totally off screen
;input:none
;return:none
;**********************************

DeleteSelectedObjects:

	dumpstr str111

	cmp dword [sizeoflinklist],0
	jz .done


	mov esi,[headlink]

	mov dword [DeletedQtyObjects],0

.mainLoop:

	;in this loop esi must be preserved

	;check for selected at offset=8 in the link
	cmp dword [esi+8],1  ;is object selected ?
	jnz .getNextLink     ;if not get next link

	;save address of link either side of the selected one
	mov eax,[esi+72]  ;eax=linkPrevious
	mov ebx,[esi+76]  ;ebx=linkNext
	push eax
	push esi
	dumpebx ebx,str110,0
	pop esi
	pop eax

	;check for head, tail or some link in the middle
	cmp esi,[headlink]
	jz .deleteHead
	cmp esi,[taillink]
	jz .deleteTail

	;delete links in the middle of the list
	mov [eax+76],ebx  ;linkPrevious->Next = linkNext
	mov [ebx+72],eax  ;linkNext->Previous = linkPrevious
	inc dword [DeletedQtyObjects]
	jmp .decCount
	

.deleteHead:
	;head link only (esi=headlink=taillink)
	cmp esi,[taillink]
	jnz .deleteHeadPlus
	mov dword [sizeoflinklist],0 
	inc dword [DeletedQtyObjects]
	call InitLink1
	jmp .done

.deleteHeadPlus:
	;head link with at least one more object
	mov dword [ebx+72],0   ;linkNext->Previous=0
	mov [headlink],ebx
	inc dword [DeletedQtyObjects]
	jmp .decCount
	

.deleteTail:
	mov edx,eax
	add edx,76          ;add offset for next link
	mov dword [edx],0   ;linkPrevious->Next=0
	mov [taillink],eax
	inc dword [DeletedQtyObjects]


.decCount:
	dec dword [sizeoflinklist] 
	mov ebx,[sizeoflinklist]
	dumpebx ebx,str23,0


.getNextLink:
	mov esi,[esi+76] ;get address of next link in esi
	cmp esi,0  	 ;end of link list test 
	jnz .mainLoop




	;now if user deleted the entire link list
	;we need to call this one again
	cmp dword [sizeoflinklist],0 
	jnz .done
	call InitLink1



.done:

	;build a complex string to tell user
	;how many selected objects were deleted
	;the string will look like this:
	;"xx selected objects deleted"
	;where xx=dword [DeletedQtyObjects]
	mov eax,57              ;printf
	mov ecx,2               ;qty args
	mov ebx,DeletedArgType
	mov esi,DeletedArgList
	mov edi,DeletedFBmess   ;destination string
	sysenter

	;and set the feedback message
	mov dword [FeedbackMessageIndex],52

	ret




;*************************************************************
;GetMousePnt
;Get Mouse Point

;this function is used in Left mouse handlers
;to get Lclick x,y coordinates 
;based on either the position of the mouse or yellowbox
;if the mouse is close to another endpoint where a yellow box
;was visibile when the Lclick occurred 
;then the return value will be the endpoint of the yellow box
;these are floating point object coordinates 
;not screen coordinates

;input: global dword [address_YellowBoxPoint]

;return: st0=qword MOUSEXF st1=qword MOUSEYF 
;        user must fstp or freep these 2 fpu registers when done
;**************************************************************

public GetMousePnt

	cmp dword [address_YellowBoxPoint],0
	jz .1

	;base x,y on yellow box point
	dumpstr str130  

	mov eax,[address_YellowBoxPoint]
	fld qword [eax+8]   ;st0=Y
	fld qword [eax]     ;st0=X, st1=Y
	jmp .done

.1:

	;base x,y on MOUSE position
	dumpstr str131   

	fld qword [MOUSEYF]
	fld qword [MOUSEXF]    ;st0=x, st1=y

.done:

	;for debug
	dumpst0
	fxch st1
	dumpst0
	fxch st1

	ret











;*************************************************************
;MeasureAngle3Points
;provide the included angle between a common start point
;and two other endpoints
;user is prompted to pick points in the following order:
; * common Start point
; * endpoint #1
; * endpoint #2
;return: The included angle is provided as a feedback message

;common usage for this function is to measure the angle between
;2 line segments. The lines must share a common endpoint.
;**************************************************************

MeasureAngle3Points:

	;prompt user to pick common Start point
	mov dword [FeedbackMessageIndex],6 

	;and set new left mouse handler 
	mov dword [LftMousProc],MeasureAngle3Points_11

	ret


MeasureAngle3Points_11:

	;this is a left mouse handler
	;we got here after user picked common Start point

	call GetMousePnt

	;save the common startpoint as x1,y1 for vector1 & vector2
	fst qword [vector1]     ;save x1
	fst qword [vector2]     ;save x1
	fxch st1                ;st0=y1, st1=x1
	fst qword [vector1+8]   ;save y1
	fst qword [vector2+8]   ;save y1
	ffree st0
	ffree st1

	;left mouse handlers must return eax,ebx
	mov eax,7  ;feedback message index
	mov ebx,MeasureAngle3Points_22

	ret


MeasureAngle3Points_22:

	;this is a left mouse handler
	;we got here after user picked the first endpoint

	call GetMousePnt
	;returns st0=MOUSEXF, st1=MOUSEYF

	;save the endpoint x2,y2 for vector1
	fst qword [vector1+16]     ;save x2
	fxch st1
	fst qword [vector1+24]     ;save y2
	ffree st0
	ffree st1

	;left mouse handlers must return eax,ebx
	mov eax,8  ;feedback message index
	mov ebx,MeasureAngle3Points_33  ;left mouse handler

	ret


MeasureAngle3Points_33:

	;this is a left mouse handler
	;we got here after user picked the 2nd endpoint

	call GetMousePnt
	;returns st0=MOUSEXF, st1=MOUSEYF

	;save the endpoint x2,y2 for vector2
	fst qword [vector2+16]     ;save x2
	fxch st1
	fst qword [vector2+24]     ;save y2
	ffree st0
	ffree st1

	;now compute the angle and provide as feedback message
	mov eax,109        ;getangleinc
	mov ebx,vector1
	mov ecx,vector2
	sysenter           ;returns st0=angleinc, radians

	mov eax,99         ;rad2deg
	sysenter           ;st0=angleinc, deg

	fstp qword [AngleInc] 

	mov eax,57             ;printf
	mov ecx,2              ;qty args
	mov ebx,AngleIncType   ;arguments type array
	mov esi,AngleIncList   ;arguments list array
	mov edi,AngleIncString ;destination buffer
	sysenter
	
	;left mouse handlers must return eax,ebx
	mov eax,9  ;feedback message index
	mov ebx,0  ;default left mouse handler

	ret




;*************************************************
;MeasureAngle2Segments

;measure the angle between 2 intersecting segments
;user is prompted to 
;1) pick seg1
;2) pick seg2

;you must pick on the segments closer to the endpoints
;that are furthest from the intersection point
;these 2 endpoints along with the intersection point
;make up the 3 points to define an angle
;if the segment endpoints share a common intersection 
;point and you pick near the intersection point
;you will get a return angle measurement of -???<0000000

mas_seg1:
dd 0
mas_seg2:
dd 0
mas_point1X:
dq 0.0
mas_point1Y:
dq 0.0
mas_point2X:
dq 0.0
mas_point2Y:
dq 0.0
;**************************************************

MeasureAngle2Segments:

	dumpstr str152

	;prompt user to pick segment #1
	mov dword [FeedbackMessageIndex],70

	;set left mouse handler for object selection
	mov dword [LftMousProc],0

	;and set new post paint handler
	mov dword [PassToPaint], MeasureAngle2Seg_11

	ret


MeasureAngle2Seg_11:

	dumpstr str153

	;this is a post paint handler
	;we got here after user selected seg #1

	;save address of seg #1
	mov eax,TCD_SEGMENT
	call GetSelObj
	;eax=qty seleced, ebx=address 1st selected, ecx=address 2nd selected

	cmp eax,1  
	jnz .error

	;save address of seg1
	mov [mas_seg1],ebx


	;save mouse location on seg1
	call GetMousePnt
	fstp qword [mas_point1X]
	fstp qword [mas_point1Y]
	
	;prompt user to pick seg2
	mov eax,71
	mov ebx,0  ;idle left mouse handler
	mov dword [PassToPaint], MeasureAngle2Seg_22
	jmp .done

.error:
	dumpstr str15  ;insufficient selections
	mov eax,0
	mov ebx,0
.done:
	ret



MeasureAngle2Seg_22:

	dumpstr str154

	;this is a post paint handler
	;we got here after user selected seg2

	;save mouse location on seg2
	call GetMousePnt
	;returns st0=MOUSEXF, st1=MOUSEYF
	fstp qword [mas_point2X]
	fstp qword [mas_point2Y]

	;save address of 2 selected segments
	mov eax,TCD_SEGMENT
	call GetSelObj
	;eax=qty seleced, ebx=address 1st selected, ecx=address 2nd selected

	cmp eax,2  ;we must have 2 selected segments
	jnz .error


	;determine which of the 2 selected segments (ebx,ecx) is seg2
	;its the one which is not seg1
	;remember that GetSelectedSegments does not return in picking order
	;but in link list order

	cmp ebx,[mas_seg1]
	jz .1

	;ecx is seg1 so ebx is seg2
	mov [mas_seg2],ebx
	jmp .2


.1:  ;ebx is seg1 so ecx is seg2
	mov [mas_seg2],ecx

.2:
	;compute intersection point
	mov esi,[mas_seg1]
	mov edi,[mas_seg2]
	mov eax,96        ;tlib intersection function
	lea ebx,[esi+80]  ;address of segment1 points
	lea ecx,[edi+80]  ;address of segment2 points
	mov edx,X1        ;address to store intersection point X1,Y1
	sysenter


	;dump the intersection point for debug
	dumpstr str36
	fld qword [X1]
	dumpst0
	ffree st0
	fld qword [Y1]
	dumpst0
	ffree st0



	;find the endpoint on seg1 closest to the mouse pick
	push [mas_seg1]
	push mas_point1X
	call GetNearPnt
	;returns eax=0 or 1



	;build vector1 = Pintersect -> segment1NearestEP
	mov esi,[mas_seg1]
	fld  qword [X1]
	fstp qword [vector1]
	fld  qword [Y1]
	fstp qword [vector1+8]
	
	cmp eax,1
	jz .3
	
	;EP1 is nearest
	fld  qword [esi+80]
	fstp qword [vector1+16]
	fld  qword [esi+88]
	fstp qword [vector1+24]
	jmp .4


.3:
	;EP2 is nearest
	fld  qword [esi+96]
	fstp qword [vector1+16]
	fld  qword [esi+104]
	fstp qword [vector1+24]


.4: ;find the endpoint on seg2 closest to the mouse pick
	push [mas_seg2]
	push mas_point2X
	call GetNearPnt
	;returns eax=0 or 1


	;build vector2 = Pintersect -> segment2NearestEP
	mov esi,[mas_seg2]
	fld  qword [X1]
	fstp qword [vector2]
	fld  qword [Y1]
	fstp qword [vector2+8]
	
	cmp eax,1
	jz .5
	
	;EP1 is nearest
	fld  qword [esi+80]
	fstp qword [vector2+16]
	fld  qword [esi+88]
	fstp qword [vector2+24]
	jmp .6


.5:  ;EP2 is nearest
	fld  qword [esi+96]
	fstp qword [vector2+16]
	fld  qword [esi+104]
	fstp qword [vector2+24]


.6: ;compute angle using tlib getangleinc
	mov eax,109        ;getangleinc
	mov ebx,vector1
	mov ecx,vector2
	sysenter           ;returns st0=angleinc, radians
	mov eax,99         ;rad2deg
	sysenter           ;st0=angleinc, deg

	fstp qword [AngleInc] 

	mov eax,57             ;printf
	mov ecx,2              ;qty args
	mov ebx,AngleIncType   ;arguments type array
	mov esi,AngleIncList   ;arguments list array
	mov edi,AngleIncString ;destination buffer
	sysenter
	
	;left mouse handlers must return eax,ebx
	mov eax,9  ;feedback message index
	mov ebx,0  ;default left mouse handler
	jmp .done

.error:
	dumpstr str15  ;insufficient selections
	mov eax,0
	mov ebx,0
.done:
	ret



;********************************************************
;MeasureDistance
;measure the distance between two end points
;user is prompted to pick points in the following order:
; * endpoint #1
; * endpoint #2
;return: The distance between endpoints is provided 
;as a feedback message
;********************************************************

MeasureDistance:

	;prompt user to pick endpoint #1
	mov dword [FeedbackMessageIndex],10 

	;set new left mouse handler 
	mov dword [LftMousProc],MeasureDistance_11

	ret


MeasureDistance_11:

	;we got here after user picked endpoint #1

	call GetMousePnt

	;save endpoint #1
	fst qword [vector1]     ;save x1
	fxch st1                ;st0=y1, st1=x1
	fst qword [vector1+8]   ;save y1
	ffree st0
	ffree st1

	;left mouse handlers must return eax,ebx
	mov eax,11 
	mov ebx,MeasureDistance_22  ;left mouse handler

	ret


MeasureDistance_22:

	;we got here after user picked endpoint #2

	call GetMousePnt

	;save endpoint #2
	fst qword [vector1+16]     ;save x2
	fxch st1
	fst qword [vector1+24]     ;save y2
	ffree st0
	ffree st1


	;compute the distance
	mov eax,94       ;getslope
	mov ebx,vector1
	sysenter         ;st0=dx, st1=dy
	mov eax,95       ;getlength
	sysenter         ;st0=length

	fstp qword [Distance] 

	mov eax,57        ;printf
	mov ecx,2         ;qty args
	mov ebx,DistType
	mov esi,DistList
	mov edi,DistString
	sysenter

	;left mouse handlers must return eax,ebx
	mov eax,12 ;feedback message index
	mov ebx,0  ;default left mouse handler

	ret




EnterKeyDefaultHandler:
	dumpstr str11
	ret

FlipKeyDefaultHandler:
	dumpstr str68
	ret




;*************************************************************
;SetGridSize & DrawGrid
;the grid is a series of dark gray horizontal and vertical lines
;to aid the user in free hand drawing
;the grid does not respond to pan/zoom, it stays fixed
;the grid is toggled on/off every time you invoke from the menu
;user is prompted to enter spacing which is uniform in x & y
;;*************************************************************

SetGridSize:

	mov eax,54           ;comprompt
	mov ebx,str51        ;prompt string
	mov ecx,compromptbuf ;dest buffer
	sysenter

	mov eax,56           ;str2eax
	mov esi,compromptbuf
	sysenter
	jnz .done

	mov [GridSize],eax

.done:
	ret
	


DrawGrid:

	;set up to draw horizontal lines
	mov ebx,0              ;x
	mov ecx,[GridSize]     ;y
	mov edx,799            ;length
	mov esi,COLORGRID      ;color of grid lines
	;std palette d8->df is black->LiteGray 

.drawHorizontalLines:
	push ecx               ;preserve
	push edx               ;preserve
	mov eax,101            ;hline
	;ebx=x
	;ecx=y
	;edx=length
	;esi=color
	sysenter
	pop edx
	pop ecx
	add ecx,[GridSize]     ;increment y
	cmp ecx,600
	jb .drawHorizontalLines
	

	;set up to draw vertical lines
	mov ebx,[GridSize]     ;x
	mov ecx,0              ;y
	mov edx,599            ;length
	mov esi,COLORGRID      ;color of grid lines

.drawVerticalLines:
	push ecx               ;preserve
	push edx               ;preserve
	mov eax,102            ;vline
	;ebx=x
	;ecx=y
	;edx=length
	;esi=color
	sysenter
	pop edx
	pop ecx
	add ebx,[GridSize]
	cmp ebx,800
	jb .drawVerticalLines

	ret






;******************************************************************
;MirrorObjects
;go thru the link list and make a copy of each selected object
;then redefine endpoints to be mirror image
;input: user is prompted to select mirror line then select objects
;*******************************************************************

MirrorObjects:

	dumpstr str137

	;prompt user to select mirror line
	mov dword [FeedbackMessageIndex],19 

	;set left mouse handler for object selection
	mov dword [LftMousProc],0

	;after mirror line is selected we jump to MirrorObjects_11
	mov dword [PassToPaint],MirrorObjects_11

	ret



MirrorObjects_11:

	;this is a PostPaintHandler
	;we got here after user selected a mirror line

	dumpstr str138

	mov eax,TCD_SEGMENT
	call GetSelObj
	cmp eax,1  ;did we get 1 selection ?
	jnz .done

	mov esi,ebx  ;address of 1st selected object


	;save the mirror line endpoints
	add esi,80  ;esi=address of mirror line x1
	mov edi,MirrorLinePoints
	fld  qword [esi] 
	fstp qword [edi] 
	fld  qword [esi+8] 
	fstp qword [edi+8] 
	fld  qword [esi+16] 
	fstp qword [edi+16] 
	fld  qword [esi+24] 
	fstp qword [edi+24] 


	call UnselectAll  ;dont need the mirror line selected anymore

	;now prompt user to select objects to mirror
	mov eax,20  ;feedback message index

	;set left mouse handler for object selection
	mov ebx,0

	;set function to be called on ENTER keypress
	;after all objects that are to be mirrored are selected
	;selection may be by mouse pick or drag box or any combination
	mov dword [EntrKeyProc],MirrorObjects_22

.done:
	ret



MirrorObjects_22:

	;this is an ENTER key handler
	;we got here after user selected objects to mirror
	;now we are ready to go to work

	dumpstr str139

	;go thru the link list
	mov esi,[headlink]

.1:
	cmp dword [esi+8],1  ;is object selected ?
	jnz .nextLink

	mov eax,[esi+36]     ;get address of object mirror proc

	push MirrorLinePoints ;object mirror proc must cleanup stack
	;esi=address of object to mirror
	call eax             ;call object mirror proc, esi must be preserved

.nextLink:
	mov esi,[esi+76]     ;get address of next link
	cmp esi,0            ;is next link address valid ?
	jnz .1


	;reset  left mouse & ENTER handlers and feedback message to defaults
	mov eax,0   ;feedback message index
	mov dword [LftMousProc],0
	mov dword [EntrKeyProc],0

	call UnselectAll

	ret






;*********************************************************
;GetSelObj
;Get Selected Objects

;a number of functions need the address 
;of only 1 selected object and some need the address of 2
;we loop thru the link list and return the addresses
;of up to 2 selected objects

;note if two objects are returned as selected
;these are not necessarily in the order the user picked
;the first selected object is closest to the headlink
;the 2nd selected object is next closest to the headlink

;input:
;eax=object type (TCD_SEGMENT, TCD_CIRCLE...)

;return:
;eax=qty selected objects else 0 if none selected
;ebx=address of 1st selected object
;ecx=address of 2nd selected object

;**********************************************************

public GetSelObj

	push ebp
	mov ebp,esp
	
	;make space on stack for 4 local dwords
	sub esp,16
	mov [ebp-4],eax      ;save object type
	mov dword [ebp-8],0  ;init qty objects selected
	mov dword [ebp-12],0 ;init address 1st selected object
	mov dword [ebp-16],0 ;init address 2nd selected object


	mov esi,[headlink]
	xor ecx,ecx  ;qty selected objects


.1:  ;loop looking for the 1st selected object
	cmp dword [esi+8],1    ;is object selected ?
	jnz .nextLink

	mov ebx,[esi]          ;get object type
	cmp ebx,[ebp-4]        ;is it the correct object type ?
	jnz .nextLink

	mov [ebp-12],esi       ;save address 1st selected object
	mov dword [ebp-8],1    ;qty selected
	mov ebx,esi
	dumpebx ebx,str116a,0  ;dump the address of selection #1
	jmp .2                 ;look for another selection

.nextLink:
	mov esi,[esi+76]       ;get address of next link
	cmp esi,0              ;is next link address valid ?
	jnz .1
	;end loop selecton #1

	;if we got here we went thru the entire link list
	;and there are no selections
	jmp .done


.2:  ;move to the next link before looping for selection #2
	mov esi,[esi+76]       ;get address of next link
	cmp esi,0              ;is next link address valid ?
	jz .done


.3:
     ;loop looking for a 2nd selected object
	cmp dword [esi+8],1    ;is object selected ?
	jnz .nextLink2

	mov edx,[esi]          ;get object type
	cmp edx,[ebp-4]        ;is it the correct object type ?
	jnz .nextLink2

	mov [ebp-16],esi      ;save address 2nd selected object
	mov dword [ebp-8],2   ;qty selected
	mov ebx,esi
	dumpebx ebx,str116b,0 ;dump the address of selection #2
	jmp .done

.nextLink2:
	mov esi,[esi+76]     ;get address of next link
	cmp esi,0            ;is next link address valid ?
	jnz .3
	;end loop selecton #2


.done:

	;return values:
	mov eax,[ebp-8]  ;qty objects selected (0,1,2)
	mov ebx,[ebp-12] ;address 1st selected object
	mov ecx,[ebp-16] ;address 2nd selected object

	mov esp,ebp  ;deallocate local variables
	pop ebp
	ret




;*************************************************
;ScaleObjects
;scale all selected objects by a scale factor
;input:user is prompted to enter scale factor
;return:none
;object endpoints are scaled as follows:
;x(i) = [x(i)-x(ref)]*ScaleFactor + x(ref)
;y(i) is scaled in a similar fashion
;**************************************************

ScaleObjects:

	dumpstr str32

	;prompt user to select objects to scale
	mov dword [FeedbackMessageIndex],22 

	;set left mouse handler for object selection
	mov dword [LftMousProc],IdleLeftMouseHandler 

	;after objects are selected, user must hit ENTER
	mov dword [EntrKeyProc],ScaleObjects_11

	ret

	


ScaleObjects_11:

	dumpstr str33

	;this is an ENTER key handler
	;we got here after user selected objects and hit ENTER

	;get scale factor from user
	mov eax,54           ;comprompt
	mov ebx,str61        ;address prompt string
	mov ecx,compromptbuf ;address dest buffer
	sysenter
	jnz .done

	mov eax,93           ;str2st0
	mov ebx,compromptbuf
	sysenter             ;st0=scale factor

	fstp qword [ScaleFactor]   ;save it for object scale proc

	;prompt user to select the reference point
	mov eax,23 

	;set left mouse handler for picking reference point
	mov dword [LftMousProc],ScaleObjects_22

.done:
	ret



ScaleObjects_22:

	dumpstr str37

	;this is a left mouse handler
	;we got here after user selected the reference point

	call GetMousePnt  ;returns st0=x, st1=y

	fstp qword [XC]     ;save for object scale proc
	fstp qword [YC] 


	;go thru the link list
	mov esi,[headlink]

.1:

	cmp dword [esi+8],1       ;is object selected ?
	jnz .nextLink

	;get object scale proc address
	mov eax,[esi+56]

	;we put 3 args on the stack for the scaling proc
	;esi=address of object to scale
	push XC          ;address XC ref point
	push YC          ;address YC ref point
	push ScaleFactor ;address scale factor
	call eax         ;call it, must preserve esi

.nextLink:
	mov esi,[esi+76] ;get address of next link
	cmp esi,0        ;is next link address valid ?
	jnz .1


.done:

	mov eax,0  ;feedback message index
	mov ebx,0  ;default left mouse handler
	mov dword [EntrKeyProc],0

	call UnselectAll

	ret








;******************************************************
;DumpSel
;Dump Selected Objects
;user must first select with mouse pick or drag box
;input:none
;return:none

;******************************************************

DumpSel:

	dumpstr str27a

	push ebp
	mov ebp,esp
	sub esp,8  ;allocate 2 dwords on stack
	;[ebp-4]   ;link #
	;[ebp-8]   ;qty links dumped

	mov dword [ebp-4],0  ;init link# 
	mov dword [ebp-8],0  ;init qty links dumped
	mov esi,[headlink]

.1:
	cmp dword [esi+8],1  ;is object selected ?
	jnz .2               ;jmp if not selected


	;we have a selection

	;increment qty links dumped
	add dword [ebp-8],1

	dumpstr str165   ;*******************************

	;dump the link# then the link data
	mov ebx,[ebp-4]
	dumpebx ebx,str163,3  ;dump link# as decimal

	dumpstr str165   ;*******************************

	;get object dump proc
	mov eax,[esi+60]

	call eax  ;call it

.2:  ;not selected
	mov esi,[esi+76]     ;get address of next link
	add dword [ebp-4],1  ;inc link#
	cmp esi,0            ;is next link address valid ?
	jnz .1


	;dump qty links dumped
	mov ebx,[ebp-8]
	dumpebx ebx,str79,3

	mov esp,ebp  ;deallocate locals
	pop ebp
	ret





;******************************************************
;DumpAll
;Dump All Objects/Links
;input:none
;return:none

;******************************************************

DumpAll:

	dumpstr str27b

	push ebp
	mov ebp,esp
	sub esp,8  ;allocate 2 dwords on stack
	;[ebp-4]   ;link #
	;[ebp-8]   ;qty links dumped

	mov dword [ebp-4],0  ;init link#
	mov dword [ebp-8],0  ;init qty links dumped
	mov esi,[headlink]

.1:

	;increment qty links dumped
	add dword [ebp-8],1

	dumpstr str165   ;*******************************

	;dump the link# then the link data
	mov ebx,[ebp-4]
	dumpebx ebx,str163,3   ;dump linknum as decimal

	dumpstr str165   ;*******************************

	;get object dump proc
	mov eax,[esi+60]

	call eax  ;call it

	mov esi,[esi+76]     ;get address of next link
	add dword [ebp-4],1  ;inc link#
	cmp esi,0            ;is next link address valid ?
	jnz .1


	;dump qty links dumped
	mov ebx,[ebp-8]
	dumpebx ebx,str79,3

	mov esp,ebp  ;deallocate locals
	pop ebp
	ret






;***************************************************
;float2int

;convert x,y qword floating point coordinate
;of a single point into dword screen/pixel coordinates

;input esi=address of qword x,y 16 bytes to convert
;      edi = address to store int result x,y 8 bytes
;return:none
;****************************************************

public float2int

	;dumpstr str125  use sparingly, floods the dump

	fld   qword [esi]   ;x float
	fmul  qword [zoom]  
	fadd  qword [xorg] 
	fistp dword [edi]   ;x int

	fld   qword [esi+8] ;y float
	fmul  qword [zoom] 
	fadd  qword [yorg]
	fistp dword [edi+4] ;y int

	ret









;**********************************************************
;                   THE END
;**********************************************************


;2do:
;tom we need an array function, where is it ????
;both linear array and polar


;some handy scrap code 

;str999:
;db 'you are here',0
;stdcall str999,[DUMPSTR]


	;go thru the link list
;	mov esi,[headlink]
;.loopThruLinkList:
;	cmp dword [esi+8],1  ;is object selected ?
;	jnz .nextLink
;	push esi             ;preserve
	;do something with selected object
;	pop esi              ;retrieve
;.nextLink:
;	mov esi,[esi+76]     ;get address of next link
;	cmp esi,0            ;is next link address valid ?
;	jnz .loopThruLinkList




                                                                    