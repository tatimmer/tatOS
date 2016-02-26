;tatOS/boot/gdtidttss.s

;rev Jan 2016

;this file is included in boot2.s
;it contains the gdt, idt, tss and default isr's & irq's
;the keyboard and mouse irq are in seperate files

;note to self: expand on some of these interrupt service routines
;like irqd1: could at least implement a counter to keep track when
;you have a "flood" of interrupts. also display interrupt counter
;from the shell. also irq5 and/or irq7 or irq11 may be used for ehci

;Jan 22, 2016   irq12 ps2 mouse code is removed


;**********************************************************
;           GDT
;global descriptor table
;our code and data share the same 4gig address space
;flat memory model
;protection will be provided via paging
;the point of these descriptors is to provide a way
;for the processor to identify kernel code & user code
;**********************************************************

align 0x10

gdt_desc:
	;the descriptor limit is always (8n-1) 
	;n=number of descriptors in the table
	;each descriptor is 8 bytes
	dw gdt_end - gdt - 1  ;gdt limit/size
	dd gdt                ;gdt linear physical address, i.e. start of gdt



gdt:               ;null descriptor is reqd here
	dd 0          
	dd 0
	
gdt_kernel_code:   ;Selector = 0x08  (kernel code)
	dw 0xffff      ;seg limit      bits 15:0
	dw 0           ;base address   bits 15:0
	db 0           ;base address   bits 23:16
	db 10011010b   ;Present, DPL=00 kernel Ring0, S=1 code/data, type=1010 code execute read
	db 0xcf        ;G=4k units, D=1 32bit addresses, AVL=notused, seg limit bits 19:16
	db 0           ;base address   bits 31:24
	
gdt_kernel_datastack: ;Selector = 0x10 (kernel data + stack)
	dw 0xffff
	dw 0
	db 0
	db 10010010b   ;Present, DPL=00 kernel Ring0, S=1 code/data, type=0010 data r/w expand up
	db 0xcf        ;G=4k units, B=1 32bit addresses, AVL=notused, seg limit bits 19:16
	db 0

gdt_user_code:    ;Selector = 0x18  (user code)
	dw 0xffff          
	dw 0              
	db 0             
	db 11111010b  ;Present, DPL=11 user Ring3, S=1 code/data, type=1010 code execute read
	db 0xcf
	db 0
	
gdt_user_datastack:  ;Selector = 0x20 (user data + stack)
	dw 0xffff
	dw 0
	db 0
	db 11110010b  ;Present, DPL=11 user Ring3, S=1 code/data, type=0010 data r/w expand up
	db 0xcf
	db 0


;the TSS descriptor is a so called "system descriptor" (not a code/data descriptor)
;see boot2.s where the tss_segment_base_lo/mid/hi values are assigned dynamically
;tom im not sure we got the segment limit correct here ????
;the TSS is reserved starting at 0x90000, see doc/memorymap for details
;we need this for sysenter/sysexit
;TSS is needed for sysenter/sysexit and interrupts with privilege change

gdt_tss_descriptor:       ;Selector = 0x28 (task state segment)
	dw 0x0070             ;seg limit 0x70=112 bytes = size of TSS segment ???
	dw 0                  ;seg base bits 15:0
	db 9                  ;seg base bits 16:23
	db 10001001b          ;present, DPL=00 Ring0, S=0 system, type=1001 32bit TSS available
	db 0                  ;g=0, AVL=0, limit 19:16=0
	db 0                  ;seg base bits 31:24

	
gdt_end:











;************************************************************************
;          IDT
;interrupt descriptor table
;the first 32 (0-31) are software interrupts (processor exceptions)
;the next  16 (32-47) are hardware interrupts
;to see Linux interrupt assignments do <cat /proc/interrupts>

;tom note since we hardcode the offsets into the lowword of each idt descriptor
;the value of these offsets must by < 0x10000
;i.e. these isr's must be loaded to an address < 0x10000 in memory
;otherwise we are in trouble since we assign the hiword offset to 0
;more advanced os's will assign these offsets dynamically

;all these descriptors are "interrupt gates", no task or trap gates here
;************************************************************************

;real mode interrupt vector table descriptor
ridtr:              
	dw 0x03ff       ;limit
	dd 0            ;base



align 0x10


idt_desc:
	dw idt_end - idt - 1  ;idt limit/size
	dd idt                ;idt linear physical address


idt:   
	;interrupts 00, div by 0 (fault)
	dw ir0          ;offset bits 15:0, this is entry point of isr for this interrupts
	dw 0x08         ;seg selector, kernel code
	db 0            ;0 for interrupt gate
	db 0x8e         ;P=1 present, DPL=0, 01110 for interrupt gate
	dw 0            ;offset bits 16:31, set to 0 if isr entry is address 0xffff or less
	
	dw ird          ;interrupt 01, RESERVED by Intel 
	dw 0x08
	db 0
	db 0xe0         ;P=0 not present, we mark all reserved interrupts as not present 
	dw 0

	dw ir2          ;interrupt 02, NMI nonmaskable (interrupt)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ird         ;interrupt 03, breakpoint (trap)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ir4         ;interrupt 04, overflow (trap)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ir5         ;interrupt 05, BOUND range exceeded (fault)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ir6         ;interrupt 06, invalid opcode (fault)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ird         ;interrupt 07, no math coprocessor (fault)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ir8         ;interrupt 08, double fault (abort-error code)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ird         ;interrupt 09, coproc segment overrun (fault)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ir10         ;interrupt 10, invalide tss (fault-error code)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ir11         ;int 11, segment not present (fault-error code)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ir12         ;interrupt 12, stack seg (fault-error code)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ir13         ;interrupt 13, gen protection (fault-error code)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ir14         ;interrupt 14, page (fault-error code)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ird         ;interrupt 15, RESERVED
	dw 0x08
	db 0
	db 0xe0        ;P=0 not present        
	dw 0

	dw ir16        ;interrupt 16, FPU coprocessor (fault)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ird         ;interrupt 17, alignment check (fault-error code)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ird         ;interrupt 18, machine check (abort)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw ird         ;interrupt 19, SIMD floating point (fault)
	dw 0x08
	db 0
	db 0x8e        
	dw 0



	;20-31 are reserved unnamed exceptions
	dw ird         ;interrupt 20 intel reserved
	dw 0x08
	db 0
	db 0xe0        ;P=0 not present 
	dw 0

	dw ird         ;interrupt 21 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0

	dw ird         ;interrupt 22 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0

	dw ird         ;interrupt 23 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0

	dw ird         ;interrupt 24 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0

	dw ird         ;interrupt 25 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0

	dw ird         ;interrupt 26 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0

	dw ird         ;interrupt 27 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0

	dw ird         ;interrupt 28 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0

	dw ird         ;interrupt 29 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0

	dw ird         ;interrupt 30 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0

	dw ird         ;interrupt 31 intel reserved
	dw 0x08
	db 0
	db 0xe0        
	dw 0


;interrupts 32-255 are User defined non-reserved
;we reprogrammed the pic to put 16 hdwre interrupts  here
;so they dont conflict with the above software ints
;pic1, irq0-irq7, port 0x20
;pic2, irq8-irq15, port 0xa0

                   ;start of PIC1 interrupts
	dw irq0        ;interrupt 32=0x20, irq0, system timer/PIT
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irq1        ;interrupt 33, irq1, ps2 keyboard
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd1       ;interrupt 34, irq2, int from 2nd pic
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd1       ;interrupt 35, irq3, com2 (seriel port)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd1       ;interrupt 36, irq4, com1
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd1       ;interrupt 37, irq5, lpt2
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd1       ;interrupt 38, irq6, floppy disc
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd1       ;interrupt 39, irq7, lpt1
	dw 0x08
	db 0
	db 0x8e        
	dw 0

					;**************************
                    ;start of PIC2 interrupts
					;**************************
	dw irqd2        ;interrupt 40=0x28, irq8, real time clock
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd2        ;interrupt 41, irq9, general i/o
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd2        ;interrupt 42, irq10, general i/o
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irq11        ;interrupt 43, irq11, usb controller (see irq11.s)
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd2        ;interrupt 44, irq12, ps2 mouse
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd2        ;interrupt 45, irq13, coprocessor
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd2        ;interrupt 46, irq14, hard disc
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	dw irqd2        ;interrupt 47, irq15, general i/o
	dw 0x08
	db 0
	db 0x8e        
	dw 0

	;if you want kernel services
	;use 0x30 = 48
	
idt_end:





;*****************************************************
;Interrupt Service Routines
;these are processor faults/traps/aborts
;refer to "IA-32 Intel Software Developers Manual"
;Vol 3: System Programming Guide"
;for details

;abort= non-recoverable, does not always give a return address
;trap=return address points to instruction after faulty instruction
;fault=return address points to faulty instruction

;Interrupts 8,10,11,12,13,14,17 push an error code on the stack
;the others do not

;all these isr's operate the same way:
;	*save registers to global memory
;	*print a message to the bottom of the screen
;	*enable interrupts
;   *hang

;we may be leaving some orphan values on the stack 

;to continue operating, type CTRL+ALT+DEL
;boot/keyboard.s will send you back to the shell.s

;most isr's will leave EIP, cs, Eflags on the stack
;some will leave ErrorCode, EIP, cs, Eflags
;if there is a privilege level change then
;the stack will contain ErrorCode, EIP, cs, Eflags, ESP, ss

;*****************************************************


ird: ;default software interrupt handler

	;every trap/fault/exception 
	;that we havent bothered to identify uniquely
	;ends up here

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax

	;type of interrupt
	STDCALL FONT01,0,500,_default,[KERNELTXTCOLOR],[PUTS] 

	pop eax  ;EIP
	STDCALL 0,540,[KERNELTXTCOLOR],intstrEIP,[PUTEAXSTR] 

	pop eax  ;cs
	STDCALL 0,560,[KERNELTXTCOLOR],intstrCS,[PUTEAXSTR] 

	pop eax  ;eflags
	STDCALL 0,580,[KERNELTXTCOLOR],intstrEFLAGS,[PUTEAXSTR] 

	call [SWAPBUF]
	sti  ;enable interrupts otherwise CTRL+ALT+DEL wont work
	jmp  $






ir0:  ;division by 0

	;heres some code to generate this error
	;mov eax,1  mov ebx,0   mov edx,0  div ebx
	;this interrupt does not general an error code

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax

	;type of interrupt
	STDCALL FONT01,0,500,_divby0,[KERNELTXTCOLOR],[PUTS] 

	pop eax  ;EIP
	STDCALL 0,540,[KERNELTXTCOLOR],intstrEIP,[PUTEAXSTR] 

	pop eax  ;cs
	STDCALL 0,560,[KERNELTXTCOLOR],intstrCS,[PUTEAXSTR] 

	pop eax  ;eflags
	STDCALL 0,580,[KERNELTXTCOLOR],intstrEFLAGS,[PUTEAXSTR] 

	call [SWAPBUF]
	sti  ;enable interrupts otherwise CTRL+ALT+DEL wont work
	jmp  $




ir2: ;Non Maskable NMI

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax

	;type of interrupt
	STDCALL FONT01,0,500,_NMI,[KERNELTXTCOLOR],[PUTS] 

	pop eax  ;EIP
	STDCALL 0,540,[KERNELTXTCOLOR],intstrEIP,[PUTEAXSTR] 

	pop eax  ;cs
	STDCALL 0,560,[KERNELTXTCOLOR],intstrCS,[PUTEAXSTR] 

	pop eax  ;eflags
	STDCALL 0,580,[KERNELTXTCOLOR],intstrEFLAGS,[PUTEAXSTR] 

	call [SWAPBUF]
	sti  ;enable interrupts otherwise CTRL+ALT+DEL wont work
	jmp  $




ir4: ;overflow
	;see the INTO instruction
	STDCALL 4,_overflow,defaultISRhandler
	jmp $


ir5: ;out of bounds
	;see the BOUND instruction
	STDCALL 5,_bounds,defaultISRhandler
	jmp $


ir6: ;invalid opcode

	;you get this by messing up your stack
	;by not balancing push/pop
	;this interrupt does not general an error code

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax

	;type of interrupt
	STDCALL FONT01,0,500,_invalop,[KERNELTXTCOLOR],[PUTS] 

	pop eax  ;EIP
	STDCALL 0,540,[KERNELTXTCOLOR],intstrEIP,[PUTEAXSTR] 

	pop eax  ;cs
	STDCALL 0,560,[KERNELTXTCOLOR],intstrCS,[PUTEAXSTR] 

	pop eax  ;eflags
	STDCALL 0,580,[KERNELTXTCOLOR],intstrEFLAGS,[PUTEAXSTR] 

	call [SWAPBUF]
	sti  ;enable interrupts otherwise CTRL+ALT+DEL wont work
	jmp  $





ir8: ;Double Fault

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax

	;type of interrupt
	STDCALL FONT01,0,500,_dblflt,[KERNELTXTCOLOR],[PUTS] 

	pop eax  ;EIP
	STDCALL 0,540,[KERNELTXTCOLOR],intstrEIP,[PUTEAXSTR] 

	pop eax  ;cs
	STDCALL 0,560,[KERNELTXTCOLOR],intstrCS,[PUTEAXSTR] 

	pop eax  ;eflags
	STDCALL 0,580,[KERNELTXTCOLOR],intstrEFLAGS,[PUTEAXSTR] 

	call [SWAPBUF]
	sti  ;enable interrupts otherwise CTRL+ALT+DEL wont work
	jmp  $




ir10:  ;Invalid TSS Exception
	STDCALL 10,_invtss,defaultISRhandler
	jmp $


ir11:  ;Segment Not Present
	STDCALL 11,_segnotP,defaultISRhandler
	jmp $


ir12: ;Stack fault

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax

	;type of interrupt
	STDCALL FONT01,0,500,_stackflt,[KERNELTXTCOLOR],[PUTS] 

	pop eax  ;error code
	STDCALL 0,520,[KERNELTXTCOLOR],intstrERROR,[PUTEAXSTR] 

	pop eax  ;EIP
	STDCALL 0,540,[KERNELTXTCOLOR],intstrEIP,[PUTEAXSTR] 

	pop eax  ;cs
	STDCALL 0,560,[KERNELTXTCOLOR],intstrCS,[PUTEAXSTR] 

	pop eax  ;eflags
	STDCALL 0,580,[KERNELTXTCOLOR],intstrEFLAGS,[PUTEAXSTR] 

	call [SWAPBUF]
	sti  ;enable interrupts otherwise CTRL+ALT+DEL wont work
	jmp  $





ir13: ;General Protection Fault

	;you can get this error by messing up the image file
	;expanding tlib but not updating tedit org or boot2 jmp

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax

	;type of interrupt
	STDCALL FONT01,0,500,_genpro,[KERNELTXTCOLOR],[PUTS] 

	pop eax  ;error code
	STDCALL 0,520,[KERNELTXTCOLOR],intstrERROR,[PUTEAXSTR] 

	pop eax  ;EIP
	STDCALL 0,540,[KERNELTXTCOLOR],intstrEIP,[PUTEAXSTR] 

	pop eax  ;cs
	STDCALL 0,560,[KERNELTXTCOLOR],intstrCS,[PUTEAXSTR] 

	pop eax  ;eflags
	STDCALL 0,580,[KERNELTXTCOLOR],intstrEFLAGS,[PUTEAXSTR] 

	call [SWAPBUF]
	sti  ;enable interrupts otherwise CTRL+ALT+DEL wont work
	jmp  $



ir14:  ;Page Fault

	;this fault generates an error code on the stack
	;the bits of the error code are as follows:
	;bit0  P protection 
	;      0=fault caused by a not present page 
	;      1=fault caused by a page level protection page
	;bit1  W/R 
	;      0=read access fault 
	;      1=write access fault
	;bit2  U/S
	;      0=fault while processor was in supervisor mode
	;      1=fault while processor was in user mode
	;bit3 RSVD
	;      0=fault not caused by reserved bit violation
	;      1=fault caused by reserv bits set to 1 in page directory
	;bit4 I/D
	;      0=fault not caused by instruction fetch
	;      1=fault caused by instruction fetch

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax

	;type of interrupt
	STDCALL FONT01,0,500,_pageflt,[KERNELTXTCOLOR],[PUTS] 

	pop eax  ;error code
	STDCALL 0,520,[KERNELTXTCOLOR],intstrERROR,[PUTEAXSTR] 

	pop eax  ;EIP
	STDCALL 0,540,[KERNELTXTCOLOR],intstrEIP,[PUTEAXSTR] 

	pop eax  ;cs
	STDCALL 0,560,[KERNELTXTCOLOR],intstrCS,[PUTEAXSTR] 

	pop eax  ;eflags
	STDCALL 0,580,[KERNELTXTCOLOR],intstrEFLAGS,[PUTEAXSTR] 

	call [SWAPBUF]
	sti  ;enable interrupts otherwise CTRL+ALT+DEL wont work
	jmp  $



;there is no interrupt #15
	
	
ir16: ;FPU Fault
	STDCALL 16,_fpu,defaultISRhandler
	jmp $
	




;********************************************
;defaultISRhandler
;input
;push ir number	                    [ebp+12]
;push address of string to display  [ebp+8]
;********************************************
defaultISRhandler:
	push ebp
	mov ebp,esp

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax


	call [GETREGINFO]

	sti  ;enable interrupts otherwise CTRL+ALT+DEL wont work

	mov dword [XOFFSET],0
	mov dword [YOFFSET],0
	mov dword [YORIENT],1
	mov eax,[ebp+12]
	mov dword [0x5b0],eax

	;message at bottom of screen, type of interrupt
	STDCALL FONT01,0,500,[ebp+8],[KERNELTXTCOLOR],[0x1000c] ;puts

	;this should be the value of EIP where the offense occurred
	;look at the dump after assembly to find the matching "Assypoint"
	mov eax,[_interstor1]
	STDCALL 0,530,[KERNELTXTCOLOR],0,[PUTEAX] 

	;this should be the value of CS code segment which is 08
	mov eax,[_interstor2]
	STDCALL 0,560,[KERNELTXTCOLOR],0,[PUTEAX]

	call [SWAPBUF]
	pop ebp
	retn 8	


_interstor1 dd 0
_interstor2 dd 0


;interrupt messages displayed at bottom of screen
_default  db  'ird:Default processor exception',0
_divby0   db  'Interrupt 00-Division by zero',0
_NMI      db  'Interrupt 02-NonMaskable NMI',0
_overflow db  'Interrupt 04-Overflow',0
_bounds   db  'Interrupt 05-Out of Bounds',0
_invalop  db  'Interrupt 06-Invalid opcode',0
_dblflt   db  'Interrupt 08-Double Fault',0
_invtss   db  'Interrupt 10-Invalid TSS',0
_segnotP  db  'Interrupt 11-Segment Not Present',0
_stackflt db  'Interrupt 12-Stack Fault',0
_genpro   db  'Interrupt 13-General Protection Fault',0
_pageflt  db  'Interrupt 14-Page Fault',0
_fpu      db  'Interrupt 16-FPU Fault',0


intstrEFLAGS db 'EFLAGS',0
intstrCS     db 'CS',0
intstrEIP    db 'EIP',0
intstrERROR  db 'ErrorCode',0
intstr01     db 'this is interrupt irqd1',0
intstr02     db 'this is interrupt irqd2',0



;********************************************************
;        hardware interrupt service routines
;********************************************************





;********************************************
; irq0
; PIT: Programmable Interrupt Timer
; this is the interrupt service routine for the pit
; referred to as the 8253 controller 
; or system timer

; see pic.s which initializes the pit
; and sets the firing rate
; to about 1000 hits per second
;******************************************


irq0:  
	cli	  ;disable interrupts
	pushad 

	;I tried some code in here to push ds,es,fs,gs
	;then assign 0x10 kernel data selector values
	;then just after end of interrupt we pop ds,es,fs,gs
	;but doing this is not reqd
	;see discussion in tlibentry.s

	;count up to 0xffffffff then 
	;roll over to 0 and continue
	inc dword [PITCOUNTER]

	;end of interrupt
	mov al,0x20 
	out 0x20,al  
	
	popad	 
	sti  ;enable interrupts
	iret  



;default handler for pic1 interrupts
irqd1:  
	cli	
	pushad
	push ds
	push es
	push fs
	push gs

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax


	STDCALL intstr01,[DUMPSTR]

	or dword [0x50c],100000000b

	;end of interrupt (eoi) signal for pic1
	mov al,0x20
	out 0x20,al  

	pop gs
	pop fs
	pop es
	pop ds
	popad
	sti
	iret



;default handler for pic2 interrupts
irqd2:  
	cli
	pushad
	push ds
	push es
	push fs
	push gs

	;set kernel data selectors
	mov ax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax


	STDCALL intstr02,[DUMPSTR]

	or dword [0x50c],1000000000b
	
	;EndOfInterrupt:any pic2 interrupt must also acknowledge pic1
	mov al,0x20
	out 0x20,al  ;eoi for pic1
	out 0xa0,al  ;eoi for pic2

	pop gs
	pop fs
	pop es
	pop ds
	popad
	sti
	iret



;note to programmers:
;your irq's must use "end of interrupt" and preserve registers
;otherwise you will have no end of frustration 


