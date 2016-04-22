;tatOS/boot/boot1.s  

;Jan 2010 Added Fat12 Volume Boot Record
;allows tatOS to be booted from floppy disc or flash drive 
;it seems older computers with built-in floppy drives
;can boot just fine from floppy disk without a Volume Boot Record (VBR)
;But now to boot from flash drive requires a little extra work
;Because the flash drive can be formatted like a hard drive or a floppy
;So we add here a VBR suitable for a floppy
;the bios of a newer computer can on boot read our VBR
;and know that the pen drive is formatted like a floppy.
;tested on an HP Pavillion and Acer laptop and it works
;some folks say it is better to format the flash like a hard disc
;In order to determine the various parameters for the FAT12 VBR  
;I made a Win98 boot disk then used dd and xxd to view the contents
;note our tatOS.img file does not actually implement the FAT12 file system
;we are just trying to inform the bios so booting from flash is successful
;note this FAT12 VBR may not work if your bios expects your flash drive to 
;be formatted like a hard drive having a partition table. 

;boot1.s
;loads boot2.s to 0x600
;this is the 512 byte executable bootsector loaded by bios
;note there is no partition table 

;just a little bit about the floppy
;SECTOR-TRACK-CYLINDER-HEAD etc
;each side of the floppy is divided up into 80 concentric rings
;each ring is called a track. Each track is divided up into 18 sectors.
;each sector can hold 512 bytes. 
;18 sectors/track * 80 tracks/side * 2 sides = 2880 total qty sectors on a floppy
;2880 sectors * 512 bytes/sector = 1,474,560 bytes on a floppy (1.44 MB 3.5" disc)
;cylinder is just another name for track
;for BIOS int13,2 Read Disc Sectors:
;sectors are numbered 1,2,3...18
;tracks are numbered 0,1,2...79
;head is 0 for the first side and 1 for the second side on a floppy

;your bios now has 3 options for booting tatOS:
;    * old computer with internal floppy disc drive
;    * new computer use flash drive formatted like floppy
;    * new computer use external floppy disc drive w/usb attach






bits 16
org 7c00h  
	
;this define appears in boot1.s and boot2.s
%define SIZEOFBOOT2 15


	;***********************************************************
	;              Volume Boot Record
	;              FAT12 floppy disc
	;  this information is to aide the bios
	;  for booting from flash drive formatted like a floppy
	;***********************************************************


	;2 byte jump to operating system boot code
	jmp short Start

	nop

	;8 byte OEM ID
	db 'tatOS   '

	;BIOS parameter block

	;offset11 bytes per sector
	dw 512

	;offset13 sectors per cluster
	db 64

	;qty reserved sectors
	dw 500

	;qty FATS (File Allocation Table)
	db 2

	;offset17 max qty root directory entries
	dw 0x200

	;total sectors small (Floppy Disk Drive size of volume)
	dw 2880

	;offset21 media descriptor (0xf0=floppy, 0xf8=hard/pen drive)
	db 0xf0

	;offset22 sectors per FAT 
	;(ToshibaFlashDrive=0xf3, BlueFlashDrive=0xf7, SledDrive=0xff)
	dw 0xf3

	;sectors per track
	dw 18

	;offset26 qty heads
	dw 2

	;qty hidden sectors
	dd 0

	;offset32 total sectors large (Hard drive size of partition)
	dd 0


	;Extended Bios Parameter Block for Fat12 and Fat16


	;offset36 physical drive number (hard drives us 0x80)
	db 0

	;reserved
	db 0

	;offset38 extended boot signature
	db 0x29

	;id seriel number
	dd 0x3b8fa221

	;offset43 volume label
	times 11 db 0x20

	;offset54 file system type
	db 'FAT16   '



	;****************************
	;Operating System Boot Code
	;****************************

Start:


	cli    ;clear/disable interrupts
	mov ax, 0
	mov ds,ax
	mov es,ax
	mov ss,ax
	;set the stack pointer, make sure its aligned
	;do not use 0xffff (thanks to SpyderTL)
	;the first push will dec sp to 0xfffe, the next push will dec to 0xfffc ... 
	mov sp,0
	sti   


	;save drive num  we are booting from
	mov [0x505],dl


	;text mode 80x25, 16 color
	mov ax,0x03
	int 10h


	;welcome
	mov si,str1
	call biosprint


	;echo drive num
	mov si,str2
	call biosprint
	mov ax,0
	mov al,[0x505]
	call putax
	mov si,_buf
	call biosprint
	mov si,nl
	call biosprint




readboot2:
	mov bx,0x600    ;memory location for start of boot2
	mov ah,2        ;bios read sector function
	;******************************************
	;QTY SECTORS TO LOAD=sizeof boot2
	;see times directive at bottom of boot2.s
	mov al,SIZEOFBOOT2 
	;******************************************
	mov ch,0        ;cylinder
	mov cl,2        ;sector (starting for boot2)
	mov dh,0        ;head
	mov dl,[0x505]  ;drivenum
	int 13h         ;call bios 
	jnc .goto0x600  ;success

	;error-reset disc drive
	mov si,str3
	call biosprint
	mov ah,0
	mov dl,[0x505]
	int 13h
	jmp readboot2


.goto0x600:
	mov si,str4
	call biosprint

	;jmp to start of boot2
	;it is important to specify both seg:off here
	;because I think bios int13 changes the seg
	jmp 0:0x600
	






;*******************************************************
;biosprint
;put address of null terminated string in si
;******************************************************
biosprint: 
	lodsb           ; load byte from si to al and incr 
	or al, al       ; test for 0 terminator
	jz .done_print  ; detect end of string
	mov ah, 0Eh     ; bios function writes char in al
	int 10h         ; call bios 
	jmp biosprint   ; continue until we reach 0
.done_print:
	ret
	
	
;convert contents of ax to ascii hex string in _buf
putax:
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
	
	
_buf times 5 db 0
str1 db 'Welcome to tatOS',10,13,0
str2 db 'Booting from drive number   ',0
str3 db 'Bios int13-2 read disc error-trying again',10,13,0
str4 db 'Jumping to 0x600',10,13,0
nl   db 10,13,0


;bios will only load sector lba=0 (512 bytes)
times 510-($-$$) db 0

;this is the boot signature
dw 0xAA55





