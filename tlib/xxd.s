;tatOS/tlib/xxd.s

;xxd
;your general purpose program to display blocks of memory
;16 bytes across the screen, each byte as hex
;starting address far left
;ascii equivalent far right

xxdMENU: 
db 'XXD',NL
db 'Display memory or blocks off your flash drive as ascii hex bytes',NL
db 'Max = 38,000 bytes or 74 blocks',NL
db NL
db '     F1=memory Start of Userland code/data  0x02000000',NL
db '     F2=memory CLIPBOARD   0x01300000',NL
db '     F3=memory IMAGEBUFFER 0x02ba0000',NL
db '     F4=memory USB Transfer Descriptors 0x00d60000',NL
db '     F5=memory Sub Directory entries previously loaded by filemanger',NL
db '     F6=memory Page Directory entries 0x8000',NL
db '     F7=memory Any Address',NL
db NL
db '     F8  = Flash Drive Load File off tatOS formatted FAT16 flash',NL
db '     F9  = Flash Drive Save XXD Buffer to flash',NL
db '     F10 = Flash Drive Load LBA blocks',NL
db '     F11 = Flash Drive Load Clusters',NL
db '       1 = Flash Drive show VBR       0x1900000',NL
db '       2 = Flash Drive show FAT1      0x1900200',NL
db '       3 = Flash Drive show FAT2      0x191e800',NL
db '       4 = Flash Drive show Root Dir  0x193ce00',NL
db NL
db 'ESC=quit',NL
db NL
db 'note:',NL
db '* flash drive VBR, FAT1, FAT2, RootDir displays are from memory',NL
db 0  ;0 terminator
 

xxdstr2 db 'XXD: Enter Starting Memory Address',0
xxdstr3 db 'XXD: ecx exceeds 38,000 bytes',0
xxdstr4 db 'XXD: Select Binary file to display as hex',0
xxdstr5 db 'Save XXD buffer to Flash: enter filename',0
xxdstr6 db 'XXD: Enter flash drive starting LBA block number',0
xxdstr7 db 'xxdLoadBlocksOffFlash',0
xxdstr8 db 'xxdLoadClustersOffFlash',0
xxdstr9 db 'XXD: Enter starting ClUSTER number of tatOS FAT16 flash drive',0


xxdmemory dd 0





xxdutil:

	;clear screen
	call backbufclear

	;title message and instructions
	STDCALL FONT01,75,25,xxdMENU,0xefff,putsml

	call swapbuf

	;wait for the user to press a function key 
	call getc

	cmp al,ESCAPE
	jz near .quit
	cmp al,F1
	jz near .doF1
	cmp al,F2
	jz near .doF2
	cmp al,F3
	jz near .doF3
	cmp al,F4
	jz near .doF4
	cmp al,F5
	jz near .doF5
	cmp al,F6
	jz near .doF6
	cmp al,F7
	jz near .doF7
	cmp al,F8
	jz near .doF8
	cmp al,F9
	jz near .doF9
	cmp al,F10
	jz near .doF10
	cmp al,F11
	jz near .doF11
	cmp al,'1'
	jz near .do1
	cmp al,'2'
	jz near .do2
	cmp al,'3'
	jz near .do3
	cmp al,'4'
	jz near .do4


	;any other keypress sends back to beginning
	jmp xxdutil

.doF1:
	call xxdViewExeCode
	jmp xxdutil

.doF2:
	call xxdViewClipboard
	jmp xxdutil

.doF3:
	call xxdViewImageBuffer
	jmp xxdutil

.doF4:
	call xxdViewTransDesc
	jmp xxdutil

.doF5:
	;function F5 and F6 require you invoke the filemanager first
	;which loads data off flash to global memory
	;if you dont do this all you see are 0000 bytes
	;alternately you can use F10 and compute the LBA yourself
	call xxdViewSubDirEntries
	jmp xxdutil


.doF6:
	call xxdShowPageDirectory
	jmp xxdutil

.doF7:
	call xxdViewAnyMemory	
	jmp xxdutil

.doF8:
	call xxdViewBinaryFile
	jmp xxdutil

.doF9:
	call xxdSaveBufferToFlash
	jmp xxdutil

.doF10:
	call xxdLoadBlocksOffFlash
	jmp xxdutil

.doF11:
	call xxdLoadClustersOffFlash
	jmp xxdutil


.do1:
	;show VBR 
	call xxdViewVBR
	jmp xxdutil


.do2:
	;show FAT1
	call xxdViewFAT1
	jmp xxdutil

.do3:
	;show FAT2
	call xxdViewFAT2
	jmp xxdutil

.do4:
	;show ROOTDIR
	call xxdViewRootDir
	jmp xxdutil


.quit:
	ret





xxdViewAnyMemory:

	;prompt user to enter MemoryAddress 
	;we will automatically dump 38,000 bytes
	;note: xxd does not read the pen drive, it reads memory
	STDCALL xxdstr2,COMPROMPTBUF,comprompt
	jnz .done


	;convert user input string to starting memory address
	mov esi,COMPROMPTBUF
	call str2eax
	;returns our starting address in eax
	jnz .done


	;call XXD
	;XXD will generate a formatted ascii byte stream 
	;starting at 0x900000 
	mov ecx,38000  ;default to dumping 38,000 bytes
	;eax=starting address
	call xxd
	jnz .done

	;call VIEWTXT
	mov esi,0x900000
	call viewtxt

.done:
	ret





xxdViewVBR:
	mov eax,0x1900000  ;starting address
	mov ecx,512        ;qty bytes
	call xxd
	jnz .done
	mov esi,0x900000   ;xxd outputs ascii to 0x900000
	call viewtxt
.done:
	ret

;we can only display a portion of the FATs due to xxd limitation
xxdViewFAT1:
	mov eax,0x1900200  ;starting address
	mov ecx,38000      ;qty bytes, total fat is 124,416 bytes
	call xxd
	jnz .done
	mov esi,0x900000   ;xxd outputs ascii to 0x900000
	call viewtxt
.done:
	ret


xxdViewFAT2:
	mov eax,0x191e800  ;starting address
	mov ecx,38000      ;qty bytes, total fat is 124,416 bytes
	call xxd
	jnz .done
	mov esi,0x900000   ;xxd outputs ascii to 0x900000
	call viewtxt
.done:
	ret

xxdViewRootDir:
	mov eax,0x193ce00  ;starting address
	mov ecx,16384      ;qty bytes, we can display the entire root directory
	call xxd
	jnz .done
	mov esi,0x900000   ;xxd outputs ascii to 0x900000
	call viewtxt
.done:
	ret





xxdViewExeCode:
	mov eax,0x2000000  ;actual start of executable code is STARTOFEXE
	mov ecx,38000      ;xxd can only process 38000 bytes max
	call xxd
	jnz .done
	mov esi,0x900000   ;xxd outputs ascii to 0x900000
	call viewtxt
.done:
	ret



xxdShowPageDirectory:
	mov eax,0x8000     ;start of page directory
	mov ecx,38000      ;xxd can only process 38000 bytes max
	call xxd
	jnz .done
	mov esi,0x900000   ;xxd outputs ascii to 0x900000
	call viewtxt
.done:
	ret






;display 38,000 bytes at the CLIPBOARD
xxdViewClipboard:
	mov eax,CLIPBOARD
	mov ecx,38000  
	call xxd
	jnz .done
	mov esi,0x900000  
	call viewtxt
.done:
	ret


xxdViewImageBuffer:
	mov eax,IMAGEBUFFER
	mov ecx,38000  
	call xxd
	jnz .done
	mov esi,0x900000  
	call viewtxt
.done:
	ret


;view the 32byte directory entries of the CurrentWorkingDirectory
;the first 11 bytes of every directory entry is the filename
;if the first byte = 0xe5 this is a deleted file
;the 12th byte is the file attributes and 0x20=archive file, 0x0f=LFN
;the last 4 bytes are the filesize, and the previous 2 bytes are starting cluster
xxdViewSubDirEntries:
	mov eax,STARTSUBDIR
	mov ecx,32768   ;0x40 blocks
	call xxd
	jnz .done
	mov esi,0x900000  
	call viewtxt
.done:
	ret





;display 1000 bytes at 0xd60000
;these are the usb transfer descriptors generated by prepareTDchain
;useful for debug
xxdViewTransDesc:
	mov eax,0xd60000
	mov ecx,1000
	call xxd
	jnz .done
	mov esi,0x900000  ;xxd outputs ascii to 0x900000
	call viewtxt
.done:
	ret





;load and display a binary file on your FAT16 tatOS formatted flash
xxdViewBinaryFile:

	STDCALL FONT01,0,250,xxdstr4,0xefff,puts

	;user to select a file to open
	mov ebx,0  ;list/display/select files only
	call filemanager
	jz .done   ;user hit escape
	;otherwise the 11char filename string is at FILENAME

	;get the file size
	push FILENAME
	call fatfindfile
	cmp eax,0  ;failed to find file else eax=filesize
	jz .done

	;alloc memory for the file
	mov ecx,eax
	call alloc  ;esi=address of memory
	jz .done
	mov [xxdmemory],esi

	;load the FAT16 file
	push dword [xxdmemory]  ;dest memory address for the file
	call fatreadfile        ;returns eax=filesize
	cmp eax,0               
	jz .done

	;if file is greater than 30,000 we just display 30,000 bytes
	;because thats all the buffer at 0x900000 can handle
	;why not use alloc here Tom instead ???
	mov ecx,eax
	cmp ecx,30000
	jb .doxxd
	mov ecx,30000

.doxxd:
	mov eax,[xxdmemory]
	call xxd
	jnz .freememory

	;display the ascii text xxd buffer to screen
	mov esi,0x900000  
	call viewtxt

.freememory:
	mov esi,[xxdmemory]
	call free

.done:
	ret



;********************************************************
;xxdSaveBufferToFlash
;this routine saves the xxd text file buffer 
;at 0x900000 to Flash
;input: none
;output:none
;********************************************************

xxdSaveBufferToFlash:

	;prompt user to enter 11 char filename and store at COMPROMPTBUF
	push xxdstr5
	call fatgetfilename
	jnz .userhitESC

	;save the file
	push dword 0x900000
	push dword [sizeofXXDbuffer]
	call fatwritefile  ;returns eax=0 on success, nonzero=failure

.userhitESC:
	ret





;**********************************************************************
;xxdLoadBlocksOffFlash
;here we ignore the file system and load blocks off flash directly
;useful if you have a corrupt FAT
;user must enter LBA of starting block
;xxd can only handle 38,000 bytes so we will only load
;70 blocks off the flash
;this code used to be part of DD
;note on a tatos formatted flash the filemanager gives starting cluster number
;to convert this to LBA use LBA = 519 + (clusternum-2) * 64
;see fat.s for details
;**********************************************************************

xxdLoadBlocksOffFlash:

	STDCALL xxdstr7,dumpstr

	;prompt user to enter starting LBA
	STDCALL xxdstr6,COMPROMPTBUF,comprompt
	jnz .done

	;convert user input string to LBA
	mov esi,COMPROMPTBUF
	call str2eax
	;returns our starting LBA in eax
	jnz .done


	;allocate memory for the blocks
	mov ecx,50000  ;qty bytes
	call alloc     ;esi=address of memory
	jz .done
	mov [xxdmemory],esi  ;save for free


	;now read 70 blocks off the flash
	mov ebx,eax  ;starting LBA
	mov ecx,70   ;70 blocks to read
	mov edi,esi  ;memory address
	call read10


	;XXD will generate a formatted ascii byte stream starting at 0x900000 
	mov eax,[xxdmemory]  ;starting memory address
	mov ecx,38000        ;default to dumping 38,000 bytes
	call xxd
	jnz .doneFree

	;call VIEWTXT
	mov esi,0x900000
	call viewtxt


.doneFree:
	mov esi,[xxdmemory]
	call free
	
.done:
	ret




;same as above only user enters "starting cluster number" instead of LBA
xxdLoadClustersOffFlash:

	STDCALL xxdstr8,dumpstr

	;prompt user to enter starting CLUSTER number
	STDCALL xxdstr9,COMPROMPTBUF,comprompt
	jnz .done

	;convert user input string to CLUSTER
	mov esi,COMPROMPTBUF
	call str2eax
	;returns our starting CLUSTER in eax
	jnz .done

	;allocate memory 
	mov ecx,50000  ;qty bytes
	call alloc     ;esi=address of memory
	jz .done
	mov [xxdmemory],esi  ;save for free


	;convert starting cluster number to starting LBA number
	;this only works for tatOS formatted FAT16 flash drive
	;LBAstart = 519 + (ClusterNumber - 2) * 64
	sub eax,2
	mov ebx,64
	xor edx,edx
	mul ebx
	add eax,519
	;eax=LBAstart


	;now read 70 blocks off the flash
	mov ebx,eax  ;starting LBA
	mov ecx,70   ;70 blocks to read
	mov edi,esi  ;memory address
	call read10


	;XXD will generate a formatted ascii byte stream starting at 0x900000 
	mov eax,[xxdmemory]  ;starting memory address
	mov ecx,38000        ;default to dumping 38,000 bytes
	call xxd
	jnz .doneFree

	;call VIEWTXT
	mov esi,0x900000
	call viewtxt


.doneFree:
	mov esi,[xxdmemory]
	call free
	
.done:
	ret





;*****************************************************
;xxdLoadBlocksOffFlash2
;this is used to load the VBR, FAT1, FAT2 and ROOTDIR
;off the flash for display by xxd
;we can only load at most 74 blocks off at one time and display
;because of xxd memory limitation
;each FAT is 0xf3 blocks or 243 so you cant see the entire FAT yet
;input
;ebx=starting LBA
;******************************************************

xxdLoadBlocksOffFlash2:   ;not interactive

	;allocate memory for the blocks
	mov ecx,50000  ;qty bytes
	call alloc     ;esi=address of memory
	jz .done
	mov [xxdmemory],esi  ;save for free


	;read blocks off the flash
	;ebx          ;starting LBA of tatOS formatted flash
	mov ecx,74    ;qty blocks to read (we are limited by xxd to 74 blocks)
	mov edi,esi   ;memory address returned from alloc
	call read10


	;XXD will generate a formatted ascii byte stream starting at 0x900000 
	mov eax,[xxdmemory]  ;starting memory address
	mov ecx,38000        ;default to dumping 38,000 bytes
	call xxd
	jnz .doneFree

	;call VIEWTXT
	mov esi,0x900000
	call viewtxt

.doneFree:
	mov esi,[xxdmemory]
	call free
	
.done:
	ret








;********************************************************
;xxd
;generate a hex/ascii representation of memory
;this routine operates similar to the 
;linux utility by the same name

;input
;eax=Starting memory address 
;ecx=qty bytes to read

;return
;ecx=qty bytes written
;zf is set on success, clear on failure

;the output looks like this:
;each line is 76 bytes + NEWLINE
;xxxxxxxx  90 90 90 ... 90 45 23 45 67   .Paperchine.Serv

;xxxxxxxx represents the byte offset from StartAddress in hex
;then follow 16 bytes represented as hex
;then follow the same 16 bytes represented as ascii
;if there is no ascii equivalent then a dot is used

;note: xxd does not read off the pen drive
;xxd reads and converts memory
;xxd builds a formatted ascii text string in memory
;starting at 0x900000, 3 megs are reserved here
;since xxd needs 77 bytes per line to display 16 bytes of memory
;the maximum qtybytes that can be passed in ecx is
;3,000,000/77 ~= 38000 bytes or 74 blocks
;*********************************************************

_qtybytes dd 0
_qtylines dd 0
_byteoffset dd 0
sizeofXXDbuffer dd 0


xxd:
	push eax
	push ebx
	push edx
	push esi
	push edi
	push ebp


	;check that qtybytes to show does not exceed 
	cmp ecx,38000
	jbe .not2big
	STDCALL xxdstr3,dumpstr
	add eax,1   ;clear zf error
	mov ecx,0   ;return no bytes
	jmp .done
.not2big:


	;initialize
	mov [_qtybytes],ecx
	mov dword [_byteoffset],eax
	;xxd writes to memory pointed to by edi
	mov edi,0x900000    
	;we save ebx for pointer to source memory
	mov ebx,eax           


	;compute qty lines to display
	;we show 16 bytes per line
	mov ebp,ecx
	shr ebp,4  
	inc ebp    ;ebp=qtylines rounded up
	mov [_qtylines],ebp

.showline:

	;write the 8 byte offset at start of line
	mov eax,[_byteoffset]
	mov edx,0         ;convert eax 8 bytes
	call eax2hex


	;write 2 spaces
	mov byte [edi],SPACE
	inc edi
	mov byte [edi],SPACE
	inc edi


	;write the 16 bytes across as hex
	;this takes 2 bytes per plus a space byte 
	mov esi,ebx
	mov ecx,16
	mov edx,2    ;eax2hex, convert al 2 bytes
	cld
.1:
	lodsb        ;al=[esi],esi++
	call eax2hex
	mov byte [edi],SPACE ;seperator
	inc edi
	loop .1


	;write 2 spaces
	mov byte [edi],SPACE
	inc edi
	mov byte [edi],SPACE
	inc edi


	;write the 16 bytes as ascii (or .)
	mov esi,ebx
	mov ecx,16
.2:
	lodsb          ;al=[esi],esi++
	call isascii   ;check for ascii
	jz .showal
	mov byte [edi],'.'
	jmp .incedi
.showal:
	mov [edi],al
.incedi:
	inc edi
	loop .2


	;write a NEWLINE
	mov byte [edi],NEWLINE
	inc edi


	;increment for next line
	add dword [_byteoffset],16
	add ebx,16
	dec ebp
	jnz .showline


	;compute total length of xxd generated ascii text
	;=qtylines * 77 bytes/line
	mov eax,77
	mul dword [_qtylines]
	mov ecx,eax                ;return length of xxd string
	mov [sizeofXXDbuffer],eax  ;save to global
	xor eax,eax                ;set zf success
	

	;0 terminator 
	mov byte [edi],0
	
.done:
	pop ebp
	pop edi
	pop esi
	pop edx
	pop ebx
	pop eax
	ret
