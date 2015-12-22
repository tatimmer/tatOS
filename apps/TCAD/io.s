
;Project: TCAD
;io02  Dec 18, 2015

;this file contains code and data for reading and writting tcd files
;a tcd file is the native graphics file for TCAD
;this file also contains code for exporting to pdf


;FileSaveTCD   (public)
;FileOpenTCD   (public)
;tcd2pdf       (public)
;Generate_PDF_graphic_stream


;io.exe follows seg.exe in executable memory
;as of Nov 2015 seg.exe ends at 0x200d09c
org 0x200f000

;unique number to identify this source file in the project
source 2


;****************
;  EXTERN
;****************

extern InitLink1
extern segmentread
extern headlink




;*********************
;  Memory Usage
;*********************


;0x2300000-0x2400000 scratch memory to build/load a tcd file
;or to generate a pdf file

equ START_TCDFILE   0x2300000

;0x2300000->0x2350000 allows for a pdf file of max 
;0x50000 or 327,680 bytes
equ START_PDFFILE   0x2300000

;the pdf graphic stream is all the MoveTo LineTo objects
equ START_PDFGSTRM  0x2350000



;****************
;  DWORDS/ARRAYS
;****************


tcdFileSize:
dd 0

stor:
db0 100

tempbuf:
db0 50

;storage for 28 byte structure return values
FileOpenStruc:
db0 28




;******************
;  EQUates
;******************

;object types defined in main.s
equ TCD_SEGMENT  0
equ TCD_CIRCLE   1
equ TCD_ARC      2
equ TCD_RECT     3
equ TCD_TEXT     4
equ TCD_DIM      5
equ TCD_VERSION  2     ;currently supported version number
equ SIZEOFTCDHEADER 48





;*****************
;  PDF Pen Color
;*****************

;we are using the pdf rgb color space

;these are the same colors as used in the TCAD standard 10 layers
;except we modify color0 because in TCAD we use a black background 
;with white pen but in pdf the background is white so we use black pen

;color components are specified as a value from 0->1
;we  take the rgb values from tatOS/tlib/palette.s
;and scale them

;the 'RG' tells pdf we are setting DeviceRGB color space pen color

color0:
db '0 0 0 RG',0xa,0       ;black
color1:
db '1 0 0 RG',0xa,0       ;red
color2:
db '1 1 .33 RG',0xa,0     ;yellow
color3:
db '0 .66 0 RG',0xa,0     ;green
color4:
db '0 0 .66 RG',0xa,0     ;blue
color5:
db '0 .66 .66 RG',0xa,0   ;cyan
color6:
db '.66 0 .66 RG',0xa,0   ;purple
color7:
db '.66 .33 0 RG',0xa,0   ;brown
color8:
db '1 .5 0 RG',0xa,0      ;orange
color9:
db '.66 .66 .66 RG',0xa,0 ;Lgray


PDF_pen_color:
dd color0, color1, color2, color3
dd color4, color5, color6, color7
dd color8, color9




;***********************************
;  STRINGS written to the PDF file
;***********************************

str0:
db 'tcd2pdf',0

str1:
db '%PDF-1.7',0xa,0

str2:
db '1 0 obj',0xa,0
str3:
db '<</Type /Catalog /Pages 2 0 R >>',0xa,0

str4:
db 'endobj',0xa,0

str5:
db '2 0 obj',0xa,0
str6:
db '<</Type /Pages /Count 1/Kids [3 0 R] >>',0xa,0

str7:
db '3 0 obj',0xa,0


;the MediaBox should specify the x and y extents 
;this is the bounding rectangle (convex hull) of all drawing objects
;in future we should look at xmax and ymax of all drawing objects
;and then select the bounding box extents based on xmax,ymax
;with an aspect ratio of 8.5x11
;be careful if you change the size of the media box by addding
;or substracting bytes, then you must update the xref table locators
str8a:
db '<</Type /Page /Parent 2 0 R /MediaBox [0 0 130 100]',0xa,0


;the Contents object number idenfies where our graphic stream
;is stored, 
str8b:
db '/Contents 5 0 R >>',0xa,0



;this is Metadata /Info object to identify the creator of this pdf
;the /Info record in the trailer points to this object
str81:
db '4 0 obj',0xa
db '<< /Creator (github.com/tatimmer/tatOS/apps/TCAD) >>',0xa,0



;our graphic stream commands are object #5
;all the MoveTo LineTo Stroke commands are stored in this object
str9:
db '5 0 obj',0xa,0

str10a:
db '<< /Length ',0

str10b:
db ' >>',0xa,0

str11:
db 'stream',0xa,0

str12:
db 'endstream',0xa,0





;XREF table
str13:
db 'xref',0xa,0

;the number 6 represents the total number of entries in the
;xref table including the first entry 65535
str14:
db '0 6',0xa,0

;this is the XREF table
;we hard code the byte offset to each object
;each one of these xref strings must be 20 bytes
;not counting 0 terminator
str15a:
db '0000000000 65535 f',0x20,0xa,0
str15b:
db '0000000009 00000 n',0x20,0xa,0
str15c:
db '0000000057 00000 n',0x20,0xa,0
str15d:
db '0000000112 00000 n',0x20,0xa,0
str15e:
db '0000000198 00000 n',0x20,0xa,0
str15f:
db '0000000266 00000 n',0x20,0xa,0


str20:
db 'trailer',0xa,0

;the number 6 after Size is again the number of entries in the
;xref table, it must match whats in str14
;the /Info identifys the location of the Metadata Info object
str21:
db '<</Size 6 /Info 4 0 R /Root 1 0 R >>',0xa,0

str22:
db 'startxref',0xa,0

str23:
db '%%EOF',0xa,0




;******************
;  misc STRINGS
;******************


str100:
db '[Generate_PDF_graphic_stream] GetLayItems returned error',0
str127:
db '[tcdFileSave] Enter 11 char filename',0
str128:
db '[tcd2pdf] Enter 11 char filename',0
str129:
db 'FileSaveTCD',0


opentcdstr1:
db '[FileOpenTCD] version',0
opentcdstr2:
db '[FileOpenTCD] qty object in file',0
opentcdstr3:
db '[FileOpenTCD] error not a TCD file',0
opentcdstr4:
db '[FileOpenTCD] error incorrect version #',0
opentcdstr5:
db '[FileOpenTCD] user hit ESC',0
opentcdstr6:
db '[FileOpenTCD] error unsupported object type',0


;set the linetype to solid
strm1:
db '[] 0 d',0xa,0

;dashed patterns are created with [on off] phase
;e.g.  [3 5] 6 d
;this is 3on 5off with a phase of 6

;set line width to 1 "user space unit"
strm2:
db '1 w',0xa,0

;set "round cap" for the line ends
strm3:
db '1 J',0xa,0

;set "round join" where two lines share an endpoint
strm4:
db '1 j',0xa,0




;***********************************************************
;FileSaveTCD    version=02
;save a tcd file
;the file is written to START_TCDFILE then saved to flash
;tcd is the file extension name for a TCAD graphics file

;Oct 2015
;the format of a tcd file is as follows:

;the file header is 48 bytes
;the reason we pad out the header to 48 bytes
;is so that each object data can start on a 16 byte boundry

;offset 00  4 bytes ascii 'TCAD'
;offset 04  dword version number
;offset 08  dword qty objects in the file
;offset 12  dword 0 (not used at this time)
;offset 16  qword zoom
;offset 24  qword xorg
;offset 32  qword yorg
;offset 40  qword 0 (not used at this time)

;after the 48 byte header comes the object data
;at this time only TCD_SEGMENT is supported (see segmentwrite)

;future version of tcd file may write layer info here
;for now layer info is just hardcoded into TCAD

;input:push dword value of [sizeoflinklist]     [ebp+20]
;      push address of qword zoom               [ebp+16]
;      push address of qword xorg               [ebp+12]
;      push address of qword yorg               [ebp+8]

;      user is prompted to enter 11 char filename
;return:none
;*************************************************************

public FileSaveTCD

	push ebp
	mov ebp,esp

	dumpstr str129

	mov esi,START_TCDFILE

	;first write the file header

	;4 bytes ascii 'TCAD' = 0x54434144
	mov [START_TCDFILE],   byte 0x54
	mov [START_TCDFILE+1], byte 0x43
	mov [START_TCDFILE+2], byte 0x41
	mov [START_TCDFILE+3], byte 0x44

	;dword version #  offset 4
	mov dword [START_TCDFILE+4], TCD_VERSION

	;dword qty objects  offset 8
	mov eax,[ebp+20]  ;eax=size of link list
	mov [START_TCDFILE+8], eax

	;dword 0  not used at this time  offset 12
	mov dword [START_TCDFILE+12], 0


	;qword zoom   offsets 16
	mov eax,[ebp+16]  ;eax=address of zoom
	fld qword [eax]   ;load it
	fstp qword [START_TCDFILE+16]  ;save & pop to cleanup fpu

	;qword xorg   offsets 24
	mov eax,[ebp+12]  ;eax=address of xorg
	fld qword [eax]
	fstp qword [START_TCDFILE+24]

	;qword yorg   offsets 32
	mov eax,[ebp+8]  ;eax=address of yorg
	fld qword [eax]
	fstp qword [START_TCDFILE+32]


	;qword 0 offset 40
	fldz
	fstp qword [START_TCDFILE+40]

	
	

	;set edi to address of start of object data  offset 48
	;48=SIZEOFTCDHEADER but ttasm cant handler the equ here
	lea edi,[START_TCDFILE+48]


	;init the filesize to 48 bytes which is the size of the header
	mov dword [tcdFileSize],SIZEOFTCDHEADER
	

	;prepare to go thru the link list and write object data


	;get address to start of our link list
	mov esi,[headlink]

.1:

	;in this loop esi,edi must be preserved

	;get address of object write procedure
	mov eax, [esi+44]

	;call the object write procedure
	call eax
	;returns eax=qty bytes written
	;this should be an even multiple of 16 bytes

	;increment the file size
	add [tcdFileSize],eax

	;get address of next link
	mov esi,[esi+76]

	;test for end of link list
	cmp esi,0
	jnz .1
	

	;prompt user for filename
	mov eax,70      ;fatgetfilename
	mov ebx,str127  ;prompt string
	sysenter      
	jnz .done       ;user hit ESC


	;now write file to flash
	mov eax,71            ;fatwritefile
	mov ebx,START_TCDFILE ;address of file data
	mov ecx,[tcdFileSize] ;obvious
	sysenter


.done:
	pop ebp
	retn 16





;***********************************************************
;FileOpenTCD
;input:none
;return: eax = address of a 28 byte structure
;containing the following values:
;       dword value of sizeoflinklist
;       qword value of zoom    (offset 4)
;       qword value of xorg    (offset 12)
;       qword value of yorg    (offset 20)
;if there is an error, then returns eax=0

;***********************************************************

public FileOpenTCD


	;display filechooser dialog so user may pick a tcd file
	mov eax,73  ;filechooser
	sysenter
	jz .error3  ;user hit ESC


	mov eax,72          ;fatreadfile
	mov ebx,0x2300000   ;address to store file data
	sysenter


	mov esi,START_TCDFILE

	;now read the tcd file header, 48 bytes

	;the first 4 bytes must be 'TCAD'
	cmp [START_TCDFILE],   byte 0x54
	jnz .error1
	cmp [START_TCDFILE+1], byte 0x43
	jnz .error1
	cmp [START_TCDFILE+2], byte 0x41
	jnz .error1
	cmp [START_TCDFILE+3], byte 0x44
	jnz .error1


	;check the version number
	mov eax,TCD_VERSION
	cmp [START_TCDFILE+4], eax
	jnz .error2

	;dump the version #  offset 4
	mov ebx,[START_TCDFILE+4]
	dumpebx ebx,opentcdstr1,0

	;dword qty objects  offset 8
	mov ecx,[START_TCDFILE+8]
	mov ebx,ecx
	dumpebx ebx,opentcdstr2,0  ;ecx is not preserved
	mov [FileOpenStruc],ebx    ;save sizeoflinklist to return struc
	mov ecx,ebx


	;read qword zoom  offset 16
	fld qword [START_TCDFILE+16]
	fstp qword [FileOpenStruc+4] ;save zoom to return struc

	;read qword xorg  offset 24
	fld qword [START_TCDFILE+24]
	fstp qword [FileOpenStruc+12] ;save xorg to return struc

	;read qword yorg  offset 32
	fld qword [START_TCDFILE+32]
	fstp qword [FileOpenStruc+20] ;save yorg to return struc



	;need to call this before first new link is created
	call InitLink1


	;set esi to address of start of object data
	mov esi,START_TCDFILE
	add esi,SIZEOFTCDHEADER  ;skip over the tcd file header


.1:

	;in this loop ecx must be preserved
	;and esi must point to the start of a new object in the file

	;read object type
	mov eax,[esi]

	;check for line segment
	cmp eax,TCD_SEGMENT
	jz .readSegment
	cmp eax,TCD_CIRCLE
	jz .readCircle
	cmp eax,TCD_TEXT
	jz .readText

	;if we got here we have some unsupported object type
	dumpstr opentcdstr6
	mov eax,0  ;error
	jmp .done


.readSegment:
	call segmentread
.readCircle:
.readText:
	loop .1


	;success
	;if we got here we have successfully read all the objects
	;and built a complete tcad link list of those objects
	;return address of 28 byte FileOpenStruc
	mov eax,FileOpenStruc 
	jmp .done


	
.error1:
	dumpstr opentcdstr3
	mov eax,0  ;error
	jmp .done
.error2:
	dumpstr opentcdstr4
	mov eax,0  ;error
	jmp .done
.error3:
	dumpstr opentcdstr5
	mov eax,0  ;error
	;fall thru
.done:
	ret








;**********************************************************
;tcd2pdf

;generate a pdf file of the tcad graphic objects
;the file is written to memory START_PDFFILE

;input: none
;return: none
;**********************************************************

public tcd2pdf

	push ebp
	mov ebp,esp
	sub esp,12
	;[ebp-4]  = dword offset to beginning of xref
	;[ebp-8]  = dword pdf filesize qty bytes
	;[ebp-12] = dword size/qtybytes of graphic stream

	dumpstr str0


	;set destination address for strcpy
	mov edi,START_PDFFILE
	


	;%PDF-1.7
	mov esi,str1
	mov eax,19  ;strcpy
	sysenter



	;1 0 obj   
	;************
	mov esi,str2
	mov eax,19  ;strcpy
	sysenter

	;object #1 data  (Catalog)
	mov esi,str3
	mov eax,19  ;strcpy
	sysenter

	;endobj
	mov esi,str4
	mov eax,19  ;strcpy
	sysenter
	


	;2 0 obj   
	;*************
	mov esi,str5
	mov eax,19  ;strcpy
	sysenter

	;object #2 data  (Pages)
	;Kids = array of indirect references to page objects
	;Count = number of page objects
	mov esi,str6
	mov eax,19  ;strcpy
	sysenter

	;endobj
	mov esi,str4
	mov eax,19  ;strcpy
	sysenter



	;3 0 obj 
	;************
	mov esi,str7
	mov eax,19  ;strcpy
	sysenter

	;object #3 data (Page Object)
	;MediaBox = user space units bounding box of page
	;this should be set to the x and y extents of your graphic
	;objects (i.e. 0,0,xmax,ymax)
	;Parent points back to the Pages
	;Contents is the PDF object number of all the graphic objects
	;ProcSet is an array of procedure set names
	mov esi,str8a
	mov eax,19  ;strcpy
	sysenter

	mov esi,str8b
	mov eax,19  ;strcpy
	sysenter

	;endobj
	mov esi,str4
	mov eax,19  ;strcpy
	sysenter




	;4 0 obj  (Metadata /Info)
	;*****************************
	;here we write a string of Metadata
	;to identify the creator of this pdf file

	mov esi,str81
	mov eax,19  ;strcpy
	sysenter

	;endobj
	mov esi,str4
	mov eax,19  ;strcpy
	sysenter





	;5 0 obj  (graphic stream)
	;***************************

	mov esi,str9
	mov eax,19  ;strcpy
	sysenter


	;<</Length    of graphics data stream
	mov esi,str10a
	mov eax,19  ;strcpy
	sysenter



	;object #5 data  (Graphic objects)
	;now go thru the tcad link list
	;and generate the PDF graphic stream
	;this is all the MoveTo LineTo Stroke commands
	;the stream is written to ADDRESS_PDFGRAPHICSTREAM

	push edi
	call Generate_PDF_graphic_stream
	;returns ecx=length of stream, ecx=0 on error
	mov [ebp-12],ecx  ;save for later
	pop edi
	;edi=address to write next byte to PDF, must be preserved


	cmp ecx,0  ;no graphic stream generated
	jz .error



	;the actual stream length must be written to file as ascii decimal
	;first we convert ebx to an ascii decimal string in temporary stor
	push edi
	mov ebx,ecx     ;ecx=length of stream
	mov eax,55      ;ebx2dec
	mov ecx,stor    ;ecx=address of temp dest buffer
	mov edx,0       ;unsigned dword
	mov esi,0       ;0 terminate
	sysenter
	pop edi


	;copy the string length qty bytes
	mov esi,stor
	mov eax,19  ;strcpy
	sysenter


	;now close the /Length specification with >>
	mov esi,str10b
	mov eax,19  ;strcpy
	sysenter

	;the keyword 'stream'
	mov esi,str11
	mov eax,19  ;strcpy
	sysenter


	;copy the graphic stream to our PDF file in memory
	;we can not use tatOS strcpy because this is limited
	;to 300 bytes max
	cld
	mov esi,START_PDFGSTRM
	;edi=destination        
	mov ecx,[ebp-12] ;qty bytes
	repmovsb



	;endstream
	mov esi,str12
	mov eax,19  ;strcpy
	sysenter


	;endobj
	mov esi,str4
	mov eax,19  ;strcpy
	sysenter




	;compute byte offset to beginning of xref keyword
	mov eax,edi
	sub eax,START_PDFFILE
	mov [ebp-4],eax  ;save byte offset for later




	;XREF  cross reference
	;we have 4 objects
	;each object starts at a predictable offset from 
	;beginning of the file


	;the keyword 'xref'
	mov esi,str13
	mov eax,19  ;strcpy
	sysenter

	;0 5   (first obj num and numobjects)
	mov esi,str14
	mov eax,19  ;strcpy
	sysenter

	;0000000000 65535 f   (the first object is free)
	mov esi,str15a
	mov eax,19  ;strcpy
	sysenter

	;0000000009 00000 n   (obj #1)
	mov esi,str15b
	mov eax,19  ;strcpy
	sysenter

	;0000000056 00000 n   (obj #2)
	mov esi,str15c
	mov eax,19  ;strcpy
	sysenter

	;0000000102 00000 n   (obj #3)
	mov esi,str15d
	mov eax,19  ;strcpy
	sysenter

	;0000000198 00000 n   (obj #4)
	mov esi,str15e
	mov eax,19  ;strcpy
	sysenter

	;0000000266 00000 n   (obj #5) 
	mov esi,str15f
	mov eax,19  ;strcpy
	sysenter



	;trailer
	mov esi,str20
	mov eax,19  ;strcpy
	sysenter

	;"/Size 5" means there are 5 objects in xref
	;"/Root 1 0 R" gives the location of the Catalog
	mov esi,str21
	mov eax,19  ;strcpy
	sysenter

	;startxref
	mov esi,str22
	mov eax,19  ;strcpy
	sysenter


	;convert byte offset to xref keyword to ascii base 10 string
	push edi         ;preserve
	mov eax,55       ;ebx2dec
	mov ebx,[ebp-4]  ;get the byte offset value to be converted
	mov ecx,tempbuf  ;dest buffer
	mov edx,0        ;unsigned dword
	mov esi,0        ;0 terminate	
	sysenter
	pop edi

	;write the byte offset 
	mov esi,tempbuf
	mov eax,19  ;strcpy
	sysenter

	;write end of line
	mov byte [edi],0xa
	inc edi

	;%%EOF
	mov esi,str23
	mov eax,19  ;strcpy
	sysenter


	;compute the filesize
	mov eax,edi
	sub eax,START_PDFFILE
	mov [ebp-8],eax ;save for fatwritefile



.writeFile:

	;prompt user for filename
	mov eax,70      ;fatgetfilename
	mov ebx,str128  ;prompt string
	sysenter      
	jnz .done       ;user hit ESC



	;now write file to flash
	mov eax,71            ;fatwritefile
	mov ebx,START_PDFFILE ;address of file data
	mov ecx,[ebp-8]       ;filesize qty bytes
	sysenter
	jmp .done


.error:

.done:
	mov esp,ebp  ;erase locals, restore esp
	pop ebp
	ret





;***************************************************************
;Generate_PDF_graphic_stream

;convert the tcad link list to a PDF graphic stream
;the graphic stream buffer starts at START_PDFGSTRM
;currently only the TCD_SEGMENT is supported

;this stream includes the following commands:

;[] 0 d 
;this declares the line to be solid no dash pattern

;1 w
;this declares the line to be 1 unit wide

;x y m  
;this is a MoveTo command

;x y l
;this is a LineTo command

;r g b RG
;this declares DeviceRGB color space with pen color r g b

;S
;this is the stroke operator (draw the line)

;we use ascii text here no compression
;where x,y,r,g,b are ascii decimal floating point values

;input:none
;return:ecx=length of stream
;       ecx=0 on error
;***************************************************************

Generate_PDF_graphic_stream:

	push ebp
	mov ebp,esp
	sub esp,8   ;space for 2 local dwords on stack
	;[ebp-4] = address of current object in link list
	;[ebp-8] = current layer


	;initialize the "current" layer
	;0xff is not a valid layer so this will trigger a
	;new pen color declaration immediately
	mov dword [ebp-8],0xffff



	;edi holds destination address for PDF graphic stream
	;throughout this proc edi must be preserved and incremented
	;with every byte written to the graphic stream buffer


	;set the dash pattern to solid,  [] 0 d
	mov esi,strm1
	mov edi,START_PDFGSTRM
	mov eax,19  ;strcpy
	sysenter

	;set the pen width to 1 unit, 1 w
	mov esi,strm2
	mov eax,19  ;strcpy
	sysenter

	;set round cap
	mov esi,strm3
	mov eax,19  ;strcpy
	sysenter

	;set round joint
	mov esi,strm4
	mov eax,19  ;strcpy
	sysenter
	

	;go thru the link list
	mov esi,[headlink]

.1:


	mov [ebp-4],esi  ;save address of object in link list


	;so far we only work with segments
	cmp dword [esi],TCD_SEGMENT
	jnz .nextLink

	;convert segment to PDF graphic stream
	;[esi+80]  x1
	;[esi+88]  y1
	;[esi+96]  x2
	;[esi+104] y2



	;set DeviceRGB space and pen color
	;looks like this: "r g b RG"
	;************************************************

	;ecx=object layer index
	mov ecx,[esi+4]
	;the value in ecx must be from 0->9
	;since TCAD currently only supports 10 layers

	;is the new layer different from the previous ?
	cmp ecx,[ebp-8]
	jz .2  ;skip RG

	;save new layer
	mov [ebp-8],ecx

	;get address of RG string to write to pdf
	mov esi,PDF_pen_color[ecx]

	;write 'r g b RG',0xa  string
	mov eax,19  ;strcpy
	sysenter

.2:


	;the first line is x1 y1 m  where m=MoveTo
	;******************************************

	;convert X1 to ascii string
	mov esi,[ebp-4]     ;esi=address of object
	fld qword [esi+80]  ;st0=x1
	push edi            ;save
	mov eax,119         ;st02str
	mov ebx,tempbuf
	mov ecx,3           ;num decimals
	sysenter
	pop edi             ;restore
	ffree st0

	;write X1 to graphic stream buffer
	mov esi,tempbuf     ;esi is corrupted
	mov eax,19          ;strcpy  
	sysenter

	;write a space
	mov byte [edi],0x20
	inc edi

	;convert Y1 to ascii string 
	mov esi,[ebp-4]     ;restore address of object in link list
	fld qword [esi+88]  ;st0=y1
	push edi            ;save
	mov eax,119         ;st02str
	mov ebx,tempbuf
	mov ecx,3           ;num decimals
	sysenter
	pop edi             ;restore
	ffree st0

	;write Y1 to graphic stream buffer
	mov esi,tempbuf
	mov eax,19  ;strcpy
	sysenter

	;write a space
	mov byte [edi],0x20
	inc edi

	;write the "MoveTo" operator which is lower case 'm'
	mov byte [edi],0x6d
	inc edi

	;write end of line
	mov byte [edi],0xa
	inc edi



	;next line will be x2 y2 l  where l=LineTo
	;*****************************************
	
	;convert X2 to ascii string 
	mov esi,[ebp-4]     ;restore address of object in link list
	fld qword [esi+96]  ;st0=x2
	push edi            ;save
	mov eax,119         ;st02str
	mov ebx,tempbuf
	mov ecx,3           ;num decimals
	sysenter
	pop edi             ;restore
	ffree st0

	;write X2 to graphic stream buffer
	mov esi,tempbuf
	mov eax,19  ;strcpy
	sysenter

	;write a space
	mov byte [edi],0x20
	inc edi

	;convert Y2 to ascii string 
	mov esi,[ebp-4]     ;restore address of object in link list
	fld qword [esi+104] ;st0=y2
	push edi            ;save
	mov eax,119         ;st02str
	mov ebx,tempbuf
	mov ecx,3           ;num decimals
	sysenter
	pop edi             ;restore
	ffree st0

	;write Y2 to graphic stream buffer
	mov esi,tempbuf
	mov eax,19  ;strcpy
	sysenter
	
	;write a space
	mov byte [edi],0x20
	inc edi

	;write the "LineTo" operator which is lower case l
	mov byte [edi],0x6c
	inc edi

	;write end of line
	mov byte [edi],0xa
	inc edi

	;write the "Stroke" operator which is upper case S
	mov byte [edi],0x53
	inc edi

	;write end of line
	mov byte [edi],0xa
	inc edi

	;done writting PDF graphic stream commands for a single line segment


.nextLink:

	mov esi,[ebp-4]      ;esi=address of object
	mov esi,[esi+76]     ;get address of next link
	cmp esi,0            ;is next link address valid ?
	jnz .1


	;0 terminate the graphic stream
	mov byte [edi],0


	;compute the total bytes in the graphic stream
	mov ecx,edi              ;address end-of-stream
	sub ecx,START_PDFGSTRM   ;address start of stream

	;return ecx=qty bytes in graphic stream
	jmp .done

	
.error:
	dumpstr str100
	mov ecx,0    ;return value
.done:
	mov esp,ebp  ;deallocate locals
	pop ebp
	ret







;***************** THE END ********************************






                                          