;tatOS/usb/inituhci.s


;functions to init the usb UHCI controller
;Get the base address needed for usb transactions. 
;Also resets the usb controller and sets up the frame list and 
;queue heads for usbmass/bulk and usbmouse/interrupt transactions
;the bus:dev:fun:00 of the primary UHCI controller is saved at 0x560=UHCIBUSDEVFUN
;values for the uhci companion controllers are saved at UHCIBUSDEVFUNCOM1, UHCIBUSDEVFUNCOM2


;Jan 2011, cleaned up code to include only register modifications
;see show_uhci_reg which can be displayed from USB CENTRAL



;*******************************
;          DATA
;*******************************

usbUstr0 db 'UHCI USB Controller Init',0
usbUstr4 db 'UHCI PCI USB i/o space base address, USBBA',0
usbUstr5 db 'UHCI PCI Index Register Base Address',0
usbUstr8 db 'UHCI Setting Bus Master Enable',0
usbUstr9 db 'UHCI Reset Controller',0
usbUstr10 db 'UHCI Fill in Frame List',0
usbUstr11 db 'UHCI Zero out FRNUM',0
usbUstr12 db 'UHCI Set max packet',0
usbUstr13 db 'UHCI Start Controller',0
usbUstr14 db 'UHCI done controller init',0




;**************************************************************
;initUHCI
;prepare the uhci controller for usb transactions
;this function is used to init the "primary" uhci
;and may also be used to init "companion" uhci controllers

;input:eax = BUS:DEV:FUN pci config address of UHCI controller
;            this may be a UHCI primary controller or a companion controller
;            in tatos the permissable values for eax are:
;            [UHCIBUSDEVFUN],[UHCIBUSDEVFUNCOM1],[UHCIBUSDEVFUNCOM2]
;return:none

;the pci_config_address is the bus:dev:fun number of the 
;uhci controller with bit31 set to enable and bits[7:0] clear
;see tlib/pci.s for details
;the pci_config_address of the primary uhci is stored at 0x560
;the primary uhci is the one found by the bios in boot2.s
;**************************************************************


initUHCI:

	;first save the uhci bus:dev:fun to our local storage
	mov [uhcibusdevfun],eax

	STDCALL usbUstr0,putscroll

	;PCI Config: Command register  (byte offset 4-5), Set Bus Master Enable Bit
	STDCALL usbUstr8,putscroll  
	mov eax,[uhcibusdevfun]
	mov ebx,4  ;register/offset 
	call pciReadDword
	;returns status reg in hiword and command reg in loword

	;set bus master enable and i/0 space enable bits
	or eax,101b  

	;write new value to the pci Config Command Register
	mov ecx,eax              ;ecx=value to be written
	mov eax,[uhcibusdevfun]  ;pci_config_address
	mov ebx,4                ;register/offset 
	call pciWriteDword



	;get UHCI controller base address UHCIBASEADD
	;this is the important one needed for usb transactions
	STDCALL usbUstr4,putscroll  
	mov eax,[uhcibusdevfun]  
	call uhcibaseaddress



	;done with PCI Config registers
	;now we deal with the controller I/O space registers



;********************************************************
;resetuhcicontroller
;the controller runs all the time
;like a wild horse
;cycling thru the frame list
;a transaction occurs 
;when you connect the first td in a linked list of td's
;to a qh which is pointed to by an entry in the frame list
;at first we make all entries in the frame list
;point to the same qh
;later you can get fancy by mixing control, bulk, iso
;a transaction ends when the tds making up the transaction
;are marked "inactive" by the controller
;or marked "stall" or the 5sec timeout expires
;********************************************************



	;first we HCRESET the controller
	;this stops the controller
	;also affects bits 8,3:0 of PORTSC
	STDCALL usbUstr9,putscroll  
	mov dx,[UHCIBASEADD]
	in ax,dx    ;read it in
	or ax,10b   ;enable bit1 for HCRESET
	out dx,ax   ;send it back


	;Important !!!
	;we used to pause for 1 sec but it seemed awfully long
	;so then I changed the pause to 200ms and it worked fine 
	;on my old PIII, but later when I tried initmouse on my new Asus netbook
	;the initmouse transactions were failing with CRC/timeout errors in run.s
	;so I changed this pause back to 1 second and now on the Asus the initmouse
	;works quite, snappy. So dont skimp on this pause and all will be well.
	mov ebx,1000
	call sleep



	;Sep 2009-init our Queue Heads QH
	;QH1 = 0x1005000 reserved for interrupt transfers (usb mouse)
	;it holds the address of the next QH (horizontal move)
	;QH2 = 0x1005100 reserved for control & bulk transfers 
	mov dword [0x1005000],0x1005102  ;QH1 1st dword holds address of QH2 w/bit1 set for QH
	mov dword [0x1005000+4],1        ;QH1 2nd dword is terminate - no more QH's in list
	mov dword [0x1005100],1          ;QH2 1st dword terminate - no horizontal TD's 
	mov dword [0x1005100+4],1        ;QH2 2nd dword terminate - no TD chain to execute

	
	;fill each entry in the frame list 
	;with the address of our first QH
	;our FRAMELIST starts at 0x1000000
	;there are 1024 dword entries in the list
	STDCALL usbUstr10,putscroll  
	cld
	mov ecx,1024
	mov eax,0x1005000   ;address of our first QH goes in the frame list
	or eax,10b          ;item points to qh, valid ptr
	mov edi,0x1000000   ;start address of framelist
	rep stosd


	;now assign FRAMELIST to FLBASEADD 
	;this tells the controller where the list starts in memory
	mov dx,[UHCIBASEADD]
	add dx,0x08        ;i/o address=base+8
	mov eax,0x1000000  ;start address of framelist
	out dx,eax     


	;zero out FRNUM
	STDCALL usbUstr11,putscroll  
	mov dx,[UHCIBASEADD]
	add dx,0x06  ;i/o address=base+6
	in ax,dx
	and ax,1111100000000000b
	out dx,ax     


	;set max packet size=64 bytes for FULL speed
	STDCALL usbUstr12,putscroll  
	mov dx,[UHCIBASEADD]
	in ax,dx
	or ax,10000000b  ;bit7=1 for 64 byte packet max
	out dx,ax


	;restart the controller
	STDCALL usbUstr13,putscroll  
	mov dx,[UHCIBASEADD]
	in ax,dx
	or ax,1  ;bit0=1 for run
	out dx,ax

	;done with setting up the usb UHCI controller
	STDCALL usbUstr14,putscroll  

	ret





