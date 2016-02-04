;tatOS/boot/boot2.s  

;rev Jan 2016
;%include "boot/mouse.s" irq12  ps2 mouse driver code has been removed
;%include "boot/ps2init.s"  code has been removed  (ps2 keyboard will still work)


;loads tatOS, switches to pmode, sets video mode
;includes irq drivers (ps2 keyboard)

;note all tlib function calls are indirect because
;boot2.s is not included in tlib

;all code in here is pretty much real mode code
;all the pmode init code has been moved to tlib/tatos.init

;do not use any tlib functions to draw to the screen in here
;use the DUMP to display debug messages
;getpixeladd is not properly initialized until tatOSinit.s



%include "tatOS.config"
%include "tlib/tatOS.inc"

;this define appears in boot1.s and boot2.s
%define SIZEOFBOOT2 15

bits 16
org 0x600  

	jmp start_boot2


;*******************************************************
;16 bit real mode functions must be up here

;put lba value to convert in ax 
;returns cyl, head, sect
getchs:
	xor dx,dx
	mov bx,[sectors_per_track]
	div bx
	inc dx
	mov byte [sect],dl
	xor dx,dx
	mov bx,[qtyheads]
	div bx
	mov byte [cyl],al
	mov byte [head],dl
	ret
	
	

;************************************************
;biosprint
;display a 0 terminated ascii string 
;in text mode graphics using the bios
;the string may contain 10,13 linefeed carriage return
;input: si=address of string
;return:none
;*************************************************

biosprint: 
	lodsb           ; load byte from si to al and incr 
	or al,al        ; test for 0 terminator
	jz .done_print  ; detect end of string
	mov ah, 0Eh     ; bios function writes char in al
	int 10h         ; call bios 
	jmp biosprint   ; continue until we reach 0
.done_print:
	ret
	





;convert contents of ax to ascii hex string in _buf
ax2buf:
	pusha 

	mov bp,0
	rol ax,4
	mov cx,ax ;copy
	and ax,0xf
	mov si,4  ;counter
	
.1:
	;this is the amazing code that does it all
	cmp al,10
	sbb al,69h
	das  ;al contains the ascii char
	
	;move ascii char to our 0 terminated buffer
	mov [_buf+bp],al

	;increment some things
	rol cx,4
	mov ax,cx 
	and ax,0xf  
	add bx,10  ;x+10
	inc bp
	dec si
	jnz .1

	popa
	ret
	


;*******************************************************

start_boot2:

	mov si,str1
	call biosprint



	;int 13h/8
	;get sectors/track and qtyheads
	;for possible booting from alternative medium like pen drive
	;can boot from pen drive on Dell laptop at work
	mov ah,8
	mov dl,[0x505]  ;drive# 
	int 13h         ;GetCurrentDriveParameters
	;test for error ??
	and cx,111111b  ;low 6 bits of cl contains sectors/track
	mov [sectors_per_track],cx
	movzx ax,dh     ;this is highest head num not qty
	inc ax
	mov [qtyheads],ax




	
loadBoot2PlusTlib:

	mov ax,[lba]
	call getchs

	push 0
	pop es

	mov dl,[0x505] ;drive# 

	;the cylinder number is actually a 10bit number
	;taken from the 2 hi bits of cl plus ch
	;but for an image file no bigger than a floppy
	;1474560 is lba=2880 which is 80cyl,0hd,1sec
	;so the cyl never gets bigger than 7 bits
	mov ch,[cyl]       ;cylinder
	mov cl,[sect]      ;sector
	mov dh,[head]      ;head
	mov ah,2           ;bios Read Disc Sector 
	mov al,1           ;read 1 sector
	;every sector is loaded from disc
	;to 0:7c00 then moved
	mov bx,0x7c00      ;load sector to es:bx 
	int 13h            ;call bios 
	jnc movesector     ;success

	;error-reset disc drive
	mov ah,0
	mov dl,[0x505]
	int 13h
	jmp loadBoot2PlusTlib


	
	

movesector:
	
	;convert dword memory to segm:offs
	;memory counts up fom 0 to 0x10000 by 0x200 increments
	cmp dword [memory],0x10000
	jb .1

	;increment segment and zero offset
	add word [segm],0x1000  ;increment the segment
	mov word [offs],0       ;zero the offset
	mov dword [memory],0    ;zero 
	jmp .2

	;set offset=memory
.1:	mov ax,[memory]
	mov [offs],ax

	;move the sector
.2:	cld
	mov cx,512  ;move 512 bytes
	mov si,0x7c00   ;0:7c00
	push word [segm]
	pop es
	mov di,[offs]
	rep movsb   ;ds:di->es:di

	;show progress *****... 
	mov si,str2    
	call biosprint 


	;increment for next sector
	inc word [lba]           
	add dword [memory],512 ;bytes/sector


	

	;************************************************
	;lba_max
	;hard code the max lba sector number  
	;lba_max =   sizeof(boot2) 
	;          + sizeof(tlib)
	;where sizeof=qtysectors
	;see "times" directive at bottom of 
	;boot2.s and tlib.s 
	;************************************************

	cmp word[lba],SIZEOFBOOT2+SIZEOFTLIB 
	jbe loadBoot2PlusTlib ;not done loading yet
	

;jmp $  



	;reset 
	push 0
	pop es


	;print a newline after all those *******	
	mov si,str12
	call biosprint


	;kill floppy drive motor
	;what if we boot from cd or flash ??
	mov si,str13
	call biosprint
	mov dx,0x3f2
	mov al,0
	out dx,al



	;use the bios (ax=0xb103, int 1ah) to find the bus:dev:fun of the USB controller
	;this code has been removed from tatOS
	;we now have a pci bus scan function executed from usb central in pmode
	;see usbcentral.s, pci.s and tatOS.config



	;use bios to detect on-board sound - nothing much here, we have no snd driver
	;%include "boot/biossnd.s"



	;use bios to read Real Time Clock Date in BCD
	mov si,str15
	call biosprint
	mov ah,4
	int 0x1a
	mov [0x510],dh ;month
	mov [0x511],dl ;day
	mov [0x512],cl ;year
	mov [0x513],ch ;century
	




	;enable the a20 gate with bios
	mov ax,0x2401
	int 15h   
	;sets CF on error with ah=0x86 function not supported
	;on success CF is clear and ah=0 success
	jc .AlternateA20
	;display a message bios A20 success
	mov si,str8
	call biosprint
	jmp .doneA20

.AlternateA20:
	;alternate enable a20 using ps2 controller
	mov al,0d1h  ;AT
	out 64h,al
	call picpause
	mov al,3
	out 60h,al
	call picpause
	mov al,2     ;ps/2
	out 92h,al
	;did it work ??
	mov si,str9
	call biosprint
.doneA20:

	


	;*******************************************
	; Get graphics mode information using bios
	;*******************************************


	;use bios 4f00 Return VBE controller info
	;this will fill in a VbeInfoBlock
	;this block contains a pointer to a list of available video modes
	;we will probe this list and look for a couple of particular modes
	;and print to the screen if these modes is available
	mov si,str10
	call biosprint

	push es
	mov ax,0x4f00
	mov di,VbeInfoBlock
	int 10h ;call bios
	pop es  ;bios call may destroy our es otherwise

	;on return:
	;ax=vbe return status, al=4f function supported or not
	;ah=00 success, 01 fail, 02 software supports hdwer fails, 03 invalid call 
	cmp ah,0
	jz .success4f00
	;print error message
	mov si,str5  
	call biosprint
	jmp .getModeInfoBlock
.success4f00:


	;if we got here we have a successful VbeInfoBlock


	;display the first 4 bytes of the VbeInfoBlock (VbeSignature)
	;this should say: 'VESA'
	mov al,[VbeInfoBlock]
	mov ah,0xE
	int 10h
	mov al,[VbeInfoBlock+1]
	mov ah,0xE
	int 10h
	mov al,[VbeInfoBlock+2]
	mov ah,0xE
	int 10h
	mov al,[VbeInfoBlock+3]
	mov ah,0xE
	int 10h

	;display the VbeVersion 
	;this should be '0200' or could be '0300'
	mov ax,[VbeInfoBlock+4]
	call ax2buf
	mov si,_buf
	call biosprint
	mov si,str12  ;newline
	call biosprint



	;announce that we will display the modenumber, width, height, BPP
	;for any 800x600 modes available
	mov si,str11
	call biosprint


	;real mode pointer offset
	;in the loop we just increment this by 2 bytes
	mov si,[VideoModeListPtr]  

	;and save for later
	mov [PointerOffset],si

.getModeNumber:

	push es

	;real mode pointer segment
	mov ax,[VideoModeListPtr+2]
	mov es,ax
	;es:si is now a pointer to the next supported mode

	;read the mode number
	mov si,[PointerOffset]
	mov dx,[es:si]

	pop es

	;save mode num for later
	mov [VideoModeNum],dx

	;check if its 0xffff which is end of list
	cmp dx,0xffff
	jz near .doneModeList

	;get the vgamodeinfoblock for this particular video mode
	mov ax,0x4f01             ;bios get MODEINFOBLOCK
	mov cx,dx                 ;our video mode number returned
	mov di, vgamodeinfoblock  ;bios will write to this memory
	int 10h                   ;call bios
	;we should check return values tom !


	;I found on one of my old computers that the ModeAttributes
	;are almost all 0xbb which doesnt say much 

	;we will display ModeNum, bitsperpixel, bytesperscanline
	;for any 800x600 modes available

	;check width
	mov ax,[vgamodeinfoblock + 18]
	cmp ax,800
	jnz .nextMode

	;check height
	mov ax,[vgamodeinfoblock + 20]
	cmp ax,600
	jnz .nextMode

	;if we got here we have an 800x600 pixel mode

	;my old tatOS test machine PIII is VESA0200 
	;I get (4) 800x600 modes available:
	;0103,0008,0320   8bpp,  800 bytes per scanline 
	;0113,000f,0640  15bpp, 1600 bytes per scanline
	;0114,0010,0640  16bpp
	;0115,0018,0960  24bpp, 2400 bytes per scanline

	;my newer ASUS netbook is VESA0300
	;I get (3) 800x600 modes available:
	;0103,0008,0340   8bpp,  832 bytes per scanline
	;0114,0010,0640  
	;0115,0020,0c80  32bpp, 3200 bytes per scanline 

	;my custom built computer at work is VESA0300:
	;I get (4) 800x600 modes available:
	;0102,0004,0064
	;0103,0008,0320
	;0114,0010,0640
	;0115,0020,0c80

	;my Micron pc PIII tatOS development machine
	;I get the same 4 modes as the computer at work

	;note our 0103 mode is universally found on all these machines
	;I would like to include mode 0114 as well in a future release

	;display the mode number
	mov ax,[VideoModeNum]
	call ax2buf
	mov si,_buf
	call biosprint
	mov si,str14  ;comma
	call biosprint

	;display the bitsperpixel
	xor ax,ax
	mov al,[vgamodeinfoblock + 25]  ;al=bits per pixel
	call ax2buf
	mov si,_buf
	call biosprint
	mov si,str14  ;comma
	call biosprint

	;display the bytesperscanline
	mov ax,[vgamodeinfoblock + 16] 
	call ax2buf
	mov si,_buf
	call biosprint
	mov si,str12  ;newline
	call biosprint


	.nextMode:
	;increment the mode number pointer offset
	add word [PointerOffset],2
	jmp .getModeNumber

.doneModeList:








.getModeInfoBlock:

	;now that we are done playing around with displaying 
	;all the possible 800x600 modes, lets get down to the business
	;of setting the mode we really want


	;***********************
	;  800x600x8bpp
	;***********************

	;return vga mode info function
	;someone at osdev suggested I use 4103 instead of 103
	mov si,str16
	call biosprint
	mov ax,0x4f01             ;bios get MODEINFOBLOCK
	mov cx,0x4103             ;800x600x8bpp with LFB 
	mov di, vgamodeinfoblock  ;bios will write to this memory
	int 10h                   ;call bios


	;save bytesperscanline
	;even though we set 800x600 pixel resolution
	;some video adapters have invisible padding bytes
	;at the end of each scanline
	;so we cant use 800 as the width, we use BPSL
	xor eax,eax
	mov ax,[vgamodeinfoblock + 16]
	mov [BPSL],eax



	;message:"setting graphics mode"
	mov si,str17  
	call biosprint
	;message:"press any key to..."
	mov si,str18
	call biosprint


	;bios int 16-0, Wait for Keypress and Read Character
	;so all previous bios print messages may be seen
	xor eax,eax
	int 16h     
	;execution will not continue until user provides keypress


	;set SuperVGA graphics mode 
	mov ax,0x4f02          ;VBE set graphics mode
	mov bx,0x4103          ;800x600x8bpp + LFB
	int 10h
	cmp ah,0 ;success
	jz .saveLFB
	mov si,str4
	call biosprint
	jmp $                  ;stuck without graphic mode


.saveLFB:
	;save address of LFB 
	mov eax,[vgamodeinfoblock+40]
	mov [LFB],eax


	;******************************
	;End setting graphics mode 
	;******************************
	



	;***************************************
	;end of RealMode code
	;start our conversion to pmode
	;no more bios any more
	;***************************************

	cli   ;disable interrupts
	
	
	;load address of our gdt into gdt register
	lgdt [gdt_desc]

	;load address of our idt into idt register
	lidt [idt_desc]
	
		

	;use to enable a20 here

	
	;set pmode bit
	mov eax,cr0 
	or eax,1
	mov cr0,eax
	

	;08h means 8 bytes down from start of gdt
	;is where you will find the code segment descriptor
	jmp 08h:do_pmode
	;no instructions in here
	;and no 16 bit code below this point
bits 32
do_pmode:
	
	
	;0x10=16 bytes from start of gdt is kernel data segment descriptor
	;no longer can we use 0000: absolute segment addressing
	;segments need the offset into gdt for privaledges/size...
	;flat memory model, all segments point to same memory
	mov ax,10h  ;kernel data segment
	mov ds,ax   ;data segment
	mov es,ax   ;extra segment
	mov fs,ax   ;extra segment
	mov gs,ax   ;extra segment
	mov ss,ax   ;stack segment


	;move stack pointer
	;remember its an upside down segment
	;the stack grows numerically 
	;towards smaller addresses (toward our code)
	;we have a combined code/data segment that overlap
	;and the stack is at the end 
	mov esp,0x88888 



	call [DUMPRESET] ;first use of the dump in tatOS 



	;remap the pic hdwre interrupts
	%include "boot/pic.s"



	;our TSS starts at 0x90000
	;write the kernel stack pointer into the tss 
	;we have been using 0x88888, see boot2.s
	mov dword [0x90004],0x88888

	;write the kernel stack segment into the tss
	;we use the kernel data segment selector for the kernel stack
	mov dword [0x90008],0x10

	;load task register with TSS segment descriptor
	;if you put an unlawful value into ax here
	;tatOS will not boot into graphics mode
	mov ax,0x2b       ;0x2b=0x28+3, 3=RPL requested privilege level
	ltr ax            ;load task register

 

	;enable interrupts
	sti


	;jump to start of tatos.init
	;all 32bit pmode initiation/startup code for tatOS
	;has been moved to tlib/tatOS.init
	jmp near [TATOSINIT]






;*******************************************************************
;                         DATA
;*******************************************************************

;bios print messages need 10,13,0 termination
str1 db 'Loading TLIB',10,13,0
str2 db '*',0
str3 db 'Bios failed to load from disc',10,13,0
str4 db 'Bios 0x4f02-Failed to set video mode',10,13,0
str5 db 'Bios 0x4f00 failed',10,13,0
str6 db '1:Remaping the PIC',0
str7 db '2:Enable Interrupts',0
str8 db 'Bios enable A20 success',10,13,0
str9 db 'Enable A20 with ps2 controller',10,13,0
str10 db 'Getting VbeInfoBlock bios 4f00',10,13,0
str11 db 'ModeNum,Bitsperpixel,Bytesperscanline for 800x600 modes',10,13,0
str12 db 10,13,0
str13 db 'Stop floppy drive motor',10,13,0
str14 db ',',0
str15 db 'Reading RealTimeClock',10,13,0
str16 db 'Getting 800x600x8bpp vga mode information bios 4f01',10,13,0
str17 db 'Preparing to set graphics mode using bios 4f02',10,13,0
str18 db 'Press any key to set graphics mode 0103 and continue',10,13,0
str19 db '-',0


cyl  db 0
head db 0
sect db 0
memory dd 0x0        ;memory goes 0->0x10000 then back to 0 

;1000:0000 = 0x10000 start of tlib
segm dw 0x1000       ;starting segment
offs dw 0x0000       ;starting offset

VideoModeNum   dw 0
PointerOffset  dw 0
ModeAttributes dw 0

;************************************************************************
;LBA 
;the floppy image lba values are as follows:
;lba=0 is the bootsector boot1.s loaded by bios on startup
;lba 1,2,3,4,5,6,7,8,9,10,11,12...N is this file boot2.s loaded by boot1.s
;the number here must be 1 greater than sizeof boot2
lba dw SIZEOFBOOT2+1   ;lba_initial = sizeof(boot2) + 1  in sectors
;************************************************************************



%include "boot/keyboard.s"    ;irq1   ps2 keyboard driver
%include "boot/gdtidttss.s"   ;descriptor tables, tss, all other irq's and isr's



;default values for floppy
sectors_per_track dw 18 
qtyheads dw 2


;with vbe1.x this block is 256 bytes, with vbe2.0 its 512 bytes
;we tell the bios we want vbe2 info with the 'VBE2' string
VbeInfoBlock:
db 'VBE2'   ;bios should change this to 'VESA'
dw 2        ;version
dd 0        ;address OEM string
dd 0        ;capabilities
VideoModeListPtr:   
dd 0        ;video mode list pointer, real mode seg:off, first 2 bytes are offset
times 512 db 0


vgamodeinfoblock times 256 db 0

_buf times 5 db 0

;boot1 must load this entire file
;if you change this number of sectors here
;you must update boot1 to load more sectors and
;you must also update lba_max at about line 164 above
;and you must update lba_initial about 20 lines up
;make this as small as possible until nasm gives you a (-) TIMES error on assemble
times 512*SIZEOFBOOT2 - ($-$$) db 0


