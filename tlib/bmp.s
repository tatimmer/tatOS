;tatos/tlib/bmp.s

;functions to deal with Windows 256 color bitmaps
;convertbmp24grayBTS, convertbmp256BTS, convertBTSbmp, ShowBMPinfo


;The Windows bitmap file has the following format:

;the first 14 bytes are called the BITMAPFILEHEADER
;offset 0 byte 'B'
;offset 1 byte 'M'
;offset 2 dword size of file 
;offset 6 word reserved = 0
;offset 8 word reserved = 0
;offset 10 dword offset to start of bits

;next comes the 40 byte (0x28) BITMAPINFOHEADER
;there are several differant types of headers each with its own length
;the 40 byte long header is most common and the only one tatOS supports
;offset 14 dword size of structure = 40 identifies this as a BITMAPINFOHEADER
;offset 18 dword bmwidth
;offset 22 dword bmheight
;offset 26 word number of bit planes = 1
;offset 28 word bits/pixel = 8 for our 256 color, could be 1,4,8,16,24,32
;offset 30 dword compression = 0 uncompressed, 1=compressed
;offset 34 dword size of image = bmwidth*bmheight*bytes/pixel
;offset 38 dword horizontal resolution
;offset 42 dword vertical resolution
;offset 46 dword number of colors used = 0x0100 = 256
;offset 50 dword number of important colors

;Color Table  
;if included, starts at offset 54=0x36 and ends at offset 1078=0x436
;256 bgr0 values in groups of 4 bytes, 1024 bytes total
;24bit DIB does not normally have a color table (but I guess some may)

;Bits
;start at offset 54 if color table not included
;start at offset 1078 if color table is included
;after this comes the bits
;for 8 bit/pixel 256 color bmp's each pixel is one byte
;for 24 bit/pixel each pixel is represented by 3 bytes
;pixel information is stored "bottom up" like math/engineering coordinate systems
;the first pixel in the bmp file is the lower left corner of the image
;the last pixel in the bmp file is the upper right corner of the image
;if your image width is not a multiple of 4 there are padding bytes
;at the end of each scanline
;we dont have any code support for padding bytes so make sure your bmp is /4

;you can make a Windows 8 bit/pixel 256 color bitmap on Linux as follows:
;first make your image with gimp and save as 24bit/pixel .bmp 
;then convert to 8bit 256 color with Imagemagik "convert" like this:
;convert -colors 256 -depth 8 -compress none image24bit.bmp image8bit.bmp




bmpstr1 db 'failed to read BM',0
bmpstr2 db 'bmp24grayBTS:image is not 24 bpp',0
bmpstr3 db 'image is wider than 800',0
bmpstr4 db 'image is taller than 600',0
bmpstr5 db 'image is not 8 bpp',0
bmpstr6 db 'image is not 256 colors',0
bmpstr7 db 'image is compressed',0
bmpstr8 db 'image width is not a multiple of 4',0
bmpstr9 db 'failed to find 40 byte BITMAPINFOHEADER',0
bmpstr10 db 'sizeof BITMAPINFOHEADER',0
bmpstr11 db 'bitmap width',0
bmpstr12 db 'bitmap height',0
bmpstr13 db 'convertbmp256BTS',0
bmpstr14 db 'bits/pixel',0
bmpstr15 db 'compression',0
bmpstr16 db 'number of colors used',0
bmpstr17 db 'Should be 0x42 or capital B',0
bmpstr18 db 'Should be 0x4d or capital M',0
bmpstr19 db 'Address of Windows 256 color bitmap',0
bmpstr20 db 'Address of BTS file custom palette',0
bmpstr21 db 'done convertbmp256BTS success',0
bmpstr22 db 'building color palette translation table from windows to tatOS',0
bmpstr23 db 'translating the windows bits to tatOS',0
bmpstr24 db 'windows rgb *********************************',0
bmpstr25 db 'color error term',0
bmpstr26 db 'BTSclosestcolormatch',0
bmpstr27 db 'BTSindexwindowspalette',0
bmpstr28 db 'tatos rgb',0
bmpstr29 db 'BTSindextatospalette',0
bmpstr30 db 'convertbmp24grayBTS',0
bmpstr31 db 'BTS filesize',0
bmpstr32 db 'filesize',0
bmpstr33 db 'offset to start of bits',0
bmpstr34 db 'size of BITMAPINFOHEADER',0
bmpstr35 db 'bits/pixel, number of bitplanes',0
bmpstr36 db 'ShowBMPinfo',0
bmpstr37 db 'size of image',0
bmpstr38 db 'number of colors used',0
bmpstr39 db 'address of pixel upper left corner windows bmp',0
bmpstr40 db 'starting address of windows bmp file',0
bmpstr41 db 'palette type unsupported',0
bmpstr42 db 'convertBTSbmp',0
bmpstr43 db 'convertBTSbmp return value in ecx',0
bmpstr44 db 'bmwidth is 0',0
bmpstr45 db 'bmheight is 0',0





;*******************************************************************
;convertbmp24grayBTS
;this function converts a Windows DIB bitmap to grayscale BTS file
;the bitmap must be a 24 bit per pixel uncompressed (3 bytes/pixel)
;bitmap width must be divisible by 4

;input
;edi =  address in memory of Windows 24bit DIB color bitmap 

;return
;on success ecx=BTS filesize else ecx=0 on error
;The grayscale BTS file is written to the IMAGEBUFFER

;the algorithm to display a real world image as grayscale 
;is simple, just average the rgb components
;then scale from 255 (8bit) to max 64 (6bit) for the DAC
;since we have only 64 grayscale colors
;index into gray palette = [(r+g+b)/3] * 64 / 255
;ref "Programming Windows" by Charles Petzold 
;***********************************************************

convertbmp24grayBTS:

	STDCALL bmpstr30,dumpstr

	;dump starting address of bmp file
	mov eax,edi
	STDCALL bmpstr40,0,dumpeax

	;check for "BM"
	cmp byte [edi],'B'
	jnz near .error1
	cmp byte [edi+1],'M'
	jnz near .error1

	;ignore the rest of the bitmapfileheader
	;now read parts of the bitmapinfoheader

	;get the bmwidth
	mov eax,[edi+18]
	mov [bmwidth],eax ;save for later
	STDCALL bmpstr11,0,dumpeax

	;width cant be > 800
	cmp eax,800
	ja near .error3

	;width must be a multiple of 4
	mov eax,[bmwidth]
	and eax,3   ;eax=modulus after division
	jnz near .error7


	;get the bmheight
	mov eax,[edi+22]
	mov [bmheight],eax 
	STDCALL bmpstr12,0,dumpeax

	;height cant be greater than 600
	cmp eax,600
	ja near .error4
	
	;get bits per pixel, it must be 24
	mov dx,[edi+28]
	cmp dx,24
	jnz near .error2



	;start writting our BTS file
	mov byte [IMAGEBUFFER],'B'
	mov byte [IMAGEBUFFER+1],'T'
	mov byte [IMAGEBUFFER+2],'S'

	;file version number
	mov byte [IMAGEBUFFER+3],1

	;bitmap width
	mov eax,[bmwidth]
	mov dword [IMAGEBUFFER+4],eax 

	;bitmap height
	mov eax,[bmheight]
	mov dword [IMAGEBUFFER+8],eax  ;height

	;palette type = 1 
	;use tatOS gray palette 
	;no palette included in BTS file
	mov dword [IMAGEBUFFER+12],1 



	;compute the total qty bits in the grayscale image
	xor edx,edx
	mul dword [bmwidth]  ;eax=bmheight*bmwidth 
	mov ecx,eax          ;ecx=total qty bits 


	;save the BTS filesize
	mov [BTSfilesize],ecx
	add dword [BTSfilesize],16  ;add the BTS1 header size


	;prepare to translate the bits

	;make esi hold the address of the upper left pixel in the Windows image
	;this address is near the end of the windows bits
	mov esi,edi
	add esi,[edi+10]    ;add offset to start of bits 
	add esi,[edi+34]    ;add size of image = bmwidth*bmheight*bytes/pixel
	sub esi,[bmwidth]   ;backup to start of last row of bits
	sub esi,[bmwidth]   ;backup to start of last row of bits
	sub esi,[bmwidth]   ;backup to start of last row of bits
	;we backup 3 times because 24bit has 3 bytes/pixel
	mov eax,esi
	STDCALL bmpstr39,0,dumpeax


	;make edi point to start of BTS bits 
	lea edi,[IMAGEBUFFER+16]


	;its very tempting to just go thru the entire Windows bits array
	;and copy the first Windows bit to the last bit of the tatOS array
	;this will work but results in a mirror image


.graybitsouterloop: 

	mov ecx,[bmwidth]
	
	;preserve address at beginning of scanline
	push esi    

.graybitsinnerloop:  ;move right to end of scanline

	;now average and write the bits
	;gray bit = (r+g+b)/3 * 64 / 255
	xor eax,eax
	xor ebx,ebx
	xor edx,edx
	mov al,[esi]    ;b
	mov bl,[esi+1]  ;g
	add eax,ebx
	mov bl,[esi+2]  ;r
	add eax,ebx
	mov ebx,3
	div ebx      ;eax/3
	shr eax,2    ;convert 8bit value to 6bit (*64/256)

	;write the grayscale tatOS bit
	mov [edi],al

	;increment
	add esi,3
	inc edi
	loop .graybitsinnerloop

	pop esi  ;restore address to beginning of scanline
	sub esi,[bmwidth]     ;move up 1 scanline
	sub esi,[bmwidth]     ;move up 1 scanline
	sub esi,[bmwidth]     ;move up 1 scanline
	;again must do this 3 times because 24bit is 3 bytes per pixel
	dec dword [bmheight]  ;this will destroy bmheight but we dont need it anymore
	jnz .graybitsouterloop


.success:
	mov ecx,[BTSfilesize]
	mov eax,ecx
	STDCALL bmpstr31,0,dumpeax
	jmp .done

.error1:
	STDCALL bmpstr1,dumpstr
	jmp .doneError
.error2:
	STDCALL bmpstr2,dumpstr
	jmp .doneError
.error3:
	STDCALL bmpstr3,dumpstr
	jmp .doneError
.error4:
	STDCALL bmpstr4,dumpstr
	jmp .doneError
.error7:
	STDCALL bmpstr8,dumpstr
	jmp .doneError

.doneError:
	xor ecx,ecx  ;return ecx=0 on error
.done:
	ret 






;*****************************************************************************
;convertbmp256BTS
;convert a Windows 256 color bitmap to a BTS file using the tatOS std palette
;the width of the bitmap must be a multiple of 4 so there are no padding bytes

;input
;edi =  address in memory of Windows 256 color bitmap 
;return: 
;on success ecx=BTS filesize else ecx=0 on error
;The color BTS file is written to the IMAGEBUFFER
;*****************************************************************************

;locals
BTSstartofBMP  dd 0
BTSfilesize  dd 0
BTSwindows_r db 0
BTSwindows_g db 0
BTSwindows_b db 0
BTStatos_r   db 0
BTStatos_g   db 0
BTStatos_b   db 0
BTSerrorterm dd 0
BTSclosestcolormatch   db 0
BTSindexwindowspalette dd 0
BTSindextatospalette   dd 0

;BTScolormap holds the cross reference between the Windows and tatOS _stdpalette
;e.g. if BTScolormap[]=6,120,19,2...
;the color(0) of windows palette matches to color(6) of tatOS _stdpalette
;so replace all 0 bits with 6
;the color(1) of windows palette matches to color(120) of tatOS _stdpalette
;so replace all 1 bits with 120
BTScolormap times 300 db 0   



convertbmp256BTS:

	STDCALL bmpstr13,dumpstr

	;save for later
	mov [BTSstartofBMP],edi

	;check for "BM"
	mov al,[edi]       
	STDCALL bmpstr17,2,dumpeax
	cmp al,0x42   ;'B'
	jnz near .error1
	mov al,[edi+1]
	STDCALL bmpstr18,2,dumpeax
	cmp al,0x4d   ;'M'
	jnz near .error1


	;check for 40 byte BITMAPINFOHEADER
	;there are other headers of differant sizes (version4, version5...)
	mov eax,[edi+14]
	STDCALL bmpstr10,0,dumpeax
	cmp eax,40
	jnz near .error8

	;ignore the rest of the bitmapfileheader
	;now read parts of the bitmapinfoheader

	;get the bmwidth
	mov eax,[edi+18]
	mov [bmwidth],eax ;save for later
	STDCALL bmpstr11,0,dumpeax

	;width cant be > 800
	cmp dword [bmwidth],800
	ja near .error3

	;width must be a multiple of 4
	mov eax,[bmwidth]
	and eax,3   ;eax=modulus after division
	jnz near .error7

	;get the bmheight
	mov eax,[edi+22]
	mov [bmheight],eax
	STDCALL bmpstr12,0,dumpeax

	;height cant be greater than 600
	cmp dword [bmheight],600
	ja near .error4
	

	;check bits per pixel, it must be 8
	xor eax,eax
	mov ax,[edi+28]
	STDCALL bmpstr14,1,dumpeax
	cmp ax,8
	jnz near .error2


	;check for no compression
	mov eax,[edi+30]
	STDCALL bmpstr15,0,dumpeax
	cmp eax,0
	jnz near .error6


	;check for 256 colors
	mov eax,[edi+46]
	STDCALL bmpstr16,0,dumpeax
	cmp eax,256
	jnz near .error5


	;start writting our BTS file
	mov byte [IMAGEBUFFER],'B'
	mov byte [IMAGEBUFFER+1],'T'
	mov byte [IMAGEBUFFER+2],'S'

	;file version number
	mov byte [IMAGEBUFFER+3],1

	;bitmap width
	mov eax,[bmwidth]
	mov dword [IMAGEBUFFER+4],eax 

	;bitmap height
	mov eax,[bmheight]
	mov dword [IMAGEBUFFER+8],eax  ;height

	;palette type = 0 
	;use tatOS std palette 
	;no palette included in BTS file
	mov dword [IMAGEBUFFER+12],0 




	;COLOR TABLE
	;now we deal with the color table
	;the Windows color table starts at offset 54
	;the color table takes up 1024 bytes, 4 bytes per color
	;the Windows color table are bytes values 0->255 ordered b,g,r,0 
	;we must extract and reorder the values as r,g,b and scale 0-64 for DAC
	;we do a nearest color search for each color in the Windows palette
	;we find the closes match to our std palette
	;minimizing the term (deltaR + deltaG + deltaG)


	STDCALL bmpstr22,dumpstr

	mov dword [BTSindexwindowspalette],0

	;init the colormap to all 0xff
	cld
	mov al,0xff
	mov ecx,256
	mov edi,BTScolormap
	rep stosb

	;esi holds starting address of Windows palette
	cld
	mov esi,[BTSstartofBMP]
	add esi,54


.ColorTableOuterLoop: 

	;esi must be preserved

	;get Windows b
	lodsb      
	shr al,2   ;scale from 8bit->6bit
	mov [BTSwindows_b],al

	;get Windows g
	lodsb
	shr al,2  
	mov [BTSwindows_g],al

	;get Windows r
	lodsb
	shr al,2  
	mov [BTSwindows_r],al

	;load the unneeded 0 byte 
	lodsb



	;now go thru every color of the tatOS stdpalette 
	;and find the closest match

	;we increment ecx by 3 bytes for every rgb
	mov ecx,0    

	mov dword  [BTSindextatospalette],0

	;reset error term to some really big + number
	mov dword [BTSerrorterm],99999999

.ColorTableInnerLoop:   ;inner loop on colors in tatOS _stdpalette

	xor eax,eax
	xor edx,edx
	mov al,[_stdpalette+ecx]    ;get r
	sub al,[BTSwindows_r]
	mul eax                   
	mov ebx,eax                 ;ebx=deltaR^2

	xor eax,eax
	xor edx,edx
	mov al,[_stdpalette+ecx+1]  ;get g
	sub al,[BTSwindows_g]
	mul eax
	add ebx,eax                 ;ebx=deltaR^2 + deltaG^2

	xor eax,eax
	xor edx,edx
	mov al,[_stdpalette+ecx+2]  ;get b
	sub al,[BTSwindows_b]
	mul eax
	add ebx,eax                 
	xchg eax,ebx            	;eax=deltaR^2 + deltaG^2 + deltaB^2 = error term




	;is this error term smaller than our current min value ?
	cmp eax,[BTSerrorterm]
	ja .trynextcolor

.foundmatch:
	;we found a color in the tatOS palette thats a perfect or closer match
	;save the new error term
	mov [BTSerrorterm],eax

	;save the index into the tatOS _stdpalette 
	mov eax,[BTSindextatospalette]
	mov [BTSclosestcolormatch],al


.trynextcolor:
	;try the next color in the tatOS stdpalette
	inc dword [BTSindextatospalette]
	add ecx,3
	cmp dword [BTSindextatospalette],0xff
	jbe .ColorTableInnerLoop





	;at this point we have compared every rgb value in the tatOS palette
	;with a single rgb value from the windows bmp palette

	;save the BTSclosescolormatch to our BTScolormap array
	mov al,[BTSclosestcolormatch]
	mov edx,[BTSindexwindowspalette]
	mov [BTScolormap+edx],al  ;save to colormap array


	;get the next rgb from Windows palette
	inc dword [BTSindexwindowspalette]
	cmp dword [BTSindexwindowspalette],256
	jb .ColorTableOuterLoop




	;dump the BTScolormap
	STDCALL BTScolormap,256,dumpmem





	;BITS
	;now we translate the bits
	;the Windows bits are stored bottom up opposite of what we want
	;the bits start at offset 1078, plus windows color bits are 8bit not 6bit
	;we read the windows bit then lookup from our BTScolormap 
	;and write a new bit that corresponds to the tatOS _stdpalette
	STDCALL bmpstr23,dumpstr

	;compute the total qty bits in the image
	mov eax,[bmwidth]
	xor edx,edx
	mul dword [bmheight]   
	mov ecx,eax    ;ecx=width*height 

	;save the filesize
	mov [BTSfilesize],ecx
	add dword [BTSfilesize],16  ;add the BTS1 header size

	;make esi point to top scanline of Windows bits
	;the top scanline is at the end of the Windows bits array
	mov esi,[BTSstartofBMP];start of Windows bitmap file
	add esi,1078        ;add offset to start of bits
	add esi,ecx         ;add size of bits
	sub esi,[bmwidth]   ;backup to start of last row of bits

	;make edi point to start of our BTS bits
	lea edi,[IMAGEBUFFER+16]

	mov edx,[bmheight]

.TranslateBitsOuterLoop: 
	mov ecx,[bmwidth]
	
	;preserve address at beginning of scanline
	push esi    

.innerloopPerscanline:
	;get windows bit to al
	lodsb   ;[esi]->al, esi++
	and eax,0xff

	;lookup corresponding tatOS bit
	mov al,[BTScolormap+eax]

	;save tatOS bit
	stosb   ;[edi]->al, edi++
	loop .innerloopPerscanline

	pop esi  ;restore address to beginning of scanline
	sub esi,[bmwidth] ;move up 1 scanline
	dec edx
	jnz .TranslateBitsOuterLoop


.success:
	mov ecx,[BTSfilesize]  ;return value
	mov eax,ecx
	STDCALL bmpstr31,0,dumpeax
	jmp .done

.error1:
	STDCALL bmpstr1,dumpstr
	jmp .doneError
.error2:
	STDCALL bmpstr5,dumpstr
	jmp .doneError
.error3:
	STDCALL bmpstr3,dumpstr
	jmp .doneError
.error4:
	STDCALL bmpstr4,dumpstr
	jmp .doneError
.error5:
	STDCALL bmpstr6,dumpstr
	jmp .doneError
.error6:
	STDCALL bmpstr7,dumpstr
	jmp .doneError
.error7:
	STDCALL bmpstr8,dumpstr
	jmp .doneError
.error8:
	STDCALL bmpstr9,dumpstr

.doneError:
	xor ecx,ecx  ;return value on error
.done:
	ret 







;**************************************************************
;convertBTSbmp
;convert a tatOS BTS file to windows 256 color 8bpp bmp
;BTS file with custom palettetype=02, is currently unsupported
;input
;edi =  address in memory of tatOS BTS version 01 file
;       see bits.s for a description of the BTS file format
;return: 
;on success ecx=BTS filesize else ecx=0 on error
;The windows bmp file is written to the IMAGEBUFFER
;*************************************************************

addresstatosbits   dd 0

convertBTSbmp:

	;STDCALL bmpstr42,dumpstr

	;check for unsupported BTS palette type 
	cmp dword [edi+12],2
	jnz .donepalettecheck
	STDCALL bmpstr41,putspause  
	jmp .doneError
.donepalettecheck:


	;we assume here the image is palette type 0 or 1
	;set the system palette to match the BTS image
	STDCALL [edi+12],setpalette


	;save address of tatOS bits for later
	;what we are doing here is true for palettetype 00 or 01 only
	;for palette type 02 would need to add 768 bytes for color table
	lea eax,[edi+16]  
	mov [addresstatosbits],eax


	;start writting our bmp file

	;BM
	mov byte [IMAGEBUFFER],'B'
	mov byte [IMAGEBUFFER+1],'M'

	;bmwidth
	mov eax,[edi+4]
	mov [bmwidth],eax
	cmp eax,0
	jnz .donecheckwidth
	STDCALL bmpstr44,putspause  ;error bmwidth=0
	jmp .doneError
.donecheckwidth:

	;bmheight
	mov ebx,[edi+8]
	mov [bmheight],ebx
	cmp ebx,0
	jnz .donecheckheight
	STDCALL bmpstr45,putspause  ;error bmheight=0
	jmp .doneError
.donecheckheight:




	;qtybits & filesize
	xor edx,edx
	mov eax,[bmwidth]
	mul dword [bmheight]
	mov [qtybits],eax   ;save for later
	;filesize=14+40+1024+qtybits = 1078+qtybits
	add eax,1078
	mov dword [IMAGEBUFFER+2],eax
	mov [filesize],eax  

	;reserved1, reserved2
	mov dword [IMAGEBUFFER+6],0

	;offset to start of bits 
	;offset = 14 + 40 + 256*4=1078 ;
	mov dword [IMAGEBUFFER+10],1078

	;40 bytes sizeof(bitmapinfoheader)
	mov dword [IMAGEBUFFER+14],40

	;bmwidth
	mov eax,[bmwidth]
	mov dword [IMAGEBUFFER+18],eax

	;bmheight
	mov eax,[bmheight]
	mov dword [IMAGEBUFFER+22],eax

	;biplanes
	mov ax,1
	mov word [IMAGEBUFFER+26],ax

	;bits per pixel
	mov ax,8
	mov word [IMAGEBUFFER+28],ax

	;compression
	mov dword [IMAGEBUFFER+30],0

	;image size
	mov eax,[qtybits]
	mov dword [IMAGEBUFFER+34],eax

	;horz/vert resolution
	mov dword [IMAGEBUFFER+38],0
	mov dword [IMAGEBUFFER+42],0

	;numcolors
	mov dword [IMAGEBUFFER+46],256

	;number important colors
	mov dword [IMAGEBUFFER+50],0


		
	;color table 
	;we copy either the stdpalette or graypalette whichever is active
	;our palette is only 256 colors * rgb
	;but the windows bitmap file requires another byte
	;after each rgb or 256*4
	;also our DAC palette is 0->64 but windows bitmap is 0-256
	;also the windows bmp requires b,g,r,0 in this order
	;but our PALETTE array is ordered r,g,b like the DAC
	cld
	mov esi,palette  ;copy from the tatoS system palette
	lea edi,[IMAGEBUFFER+54]
	mov ecx,256

.copyColorTable:

	;get tatOS r
	lodsb      
	shl al,2   ;scale from 6bit->8bit
	mov bl,al  ;save r
	;get tatOS g
	lodsb
	shl al,2  
	mov bh,al  ;save g
	;get tatOS b
	lodsb
	shl al,2  

	;write windows b,g,r
	stosb
	mov al,bh
	stosb
	mov al,bl
	stosb
	;add the 0 after rgb  
	mov al,0
	stosb      
	loop .copyColorTable




	;bits
	;each bit is an index into the colortable
	;bmwidth must be multiple of 4 because
	;we add NO padding bytes
	;also the bottom scanline is written first
	;as windows DIB is a bottom up not top down 

	;set esi to start of last scanline of tatOS bits
	mov esi,[addresstatosbits]  
	add esi,[qtybits]
	sub esi,[bmwidth]
	dec esi

	;set edi to start of windows bits
	lea edi,[IMAGEBUFFER+1078]
	cld


.copybits:
	mov ecx,[bmwidth]
	push esi          ;preserve address at beginning of scanline
	rep movsb         ;blast 1 scanline
	pop esi           ;set esi to beginning of scanline just blasted
	sub esi,[bmwidth] ;move up 1 scanline
	dec dword [bmheight]  
	jnz .copybits


.success:
	mov ecx,[filesize]
	jmp .done
.doneError:
	xor ecx,ecx  ;return filesize=0
.done:
	mov eax,ecx
	STDCALL bmpstr43,0,dumpeax
	;reset stdpalette
	STDCALL 0,setpalette
	ret



;****************************************************
;ShowBMPinfo
;function is called by the bitmap viewer
;to display the important various fields of the 
;windows bitmap BIMAPFILEHEADER and BITMAPINFOHEADER
;the file is assumed to be loaded to the IMAGEBUFFER
;input:none
;return:none
;****************************************************

ShowBMPinfo:

	STDCALL FONT01,0,0,bmpstr36,0xefff,puts

	;filesize
	mov eax,[IMAGEBUFFER+2]
	STDCALL 0,20,0xefff,bmpstr32,puteaxstr

	;offset to start of bits
	mov eax,[IMAGEBUFFER+10]
	STDCALL 0,40,0xefff,bmpstr33,puteaxstr

	;size of BITMAPINFOHEADER
	mov eax,[IMAGEBUFFER+14]
	STDCALL 0,60,0xefff,bmpstr34,puteaxstr

	;bmwidth
	mov eax,[IMAGEBUFFER+18]
	STDCALL 0,80,0xefff,bmpstr11,puteaxstr

	;bmheight
	mov eax,[IMAGEBUFFER+22]
	STDCALL 0,100,0xefff,bmpstr12,puteaxstr

	;number of bitplanes (1)
	mov eax,[IMAGEBUFFER+26]
	STDCALL 0,120,0xefff,bmpstr35,puteaxstr

	;compression
	mov eax,[IMAGEBUFFER+30]
	STDCALL 0,140,0xefff,bmpstr15,puteaxstr

	;size of image
	mov eax,[IMAGEBUFFER+34]
	STDCALL 0,160,0xefff,bmpstr37,puteaxstr

	;number of colors used
	mov eax,[IMAGEBUFFER+46]
	STDCALL 0,180,0xefff,bmpstr38,puteaxstr

	ret





