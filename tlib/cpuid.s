;tatOS/boot/cpuid.s     July 2012

;execute the cpuid instruction
;report basic info about the processor

;for "old" computers the family and model are most important
;refer to Intel AP-485 Processor Identification



cpustr0 db 'Processor Info: CPUID & MSR 0x1B',0
cpustr1 db 'Max input value for basic cpuid',0
cpustr2 db 'Processor Family',0
cpustr3 db 'Processor Model',0
cpustr4 db 'Processor SteppingID/version',0
cpustr5 db 'Brand Index',0
cpustr6 db 'Max Num Logical Processors',0
cpustr7 db 'Local APIC ID (P4 or >)',0
cpustr8 db 'Processor speed, Mhz',0
cpustr9 db 'Bootstrap processor',0
cpustr10 db 'Processor local APIC enabled',0
cpustr11 db 'Value of Model Specific Register 0x1B',0
cpustr12 db 'Floating Point Unit on chip',0
cpustr13 db 'PSE: 4MB pages are supported',0
cpustr14 db 'TSC:Time Stamp Counter, rdtsc supported',0
cpustr15 db 'Processor contains an APIC',0
cpustr16 db 'MMX supported',0
cpustr17 db 'FEATURE INFO RETURNED IN EDX from EAX=1',0
cpustr18 db 'FEATURE INFO RETURNED IN EBX from EAX=1',0
cpustr19 db 'SysEnter & SysExit are supported',0
cpustr20 db 'PTE Global bit in page dir entries is supported',0
cpustr21 db 'CMOV supported',0
cpustr22 db 'PAT page attribute table supported',0
cpustr23 db 'PSE-36 page size extension supported',0



QTY_STRINGS_FOR_LIST_CONTROL equ 24

cpuFeatureInfoEDX dd 0
cpuFeatureInfoEBX dd 0


cpuinfo:

	;get cpu info, build strings, copy to list control buffer directly


	;***************
	;   EAX=0
	;***************

	mov eax,0
	cpuid
	;returns values in eax,ebx,ecx,edx depending on whats in eax


	;max input value 
	;generate our first string directly in the ListControl Buffer
	;which starts at 0x2950000 LISTCTRLBUF
	STDCALL cpustr1,LISTCTRLBUF,eaxstr

	
	;processor vendor ascii string
	;for Intel: "GenuineIntel"
	;for AMD:   "AuthenticAMD"
	mov [LISTCTRLBUF+0x100],ebx
	mov [LISTCTRLBUF+0x104],edx
	mov [LISTCTRLBUF+0x108],ecx
	mov byte [LISTCTRLBUF+0x10c],0


	;***************
	;   EAX=1
	;***************

	mov eax,1
	cpuid


	;save Feature Info for later
	mov [cpuFeatureInfoEDX],edx
	mov [cpuFeatureInfoEBX],ebx


	;cpuid[1]_eax
	mov ebp,eax  ;copy
	and eax,0xf
	STDCALL cpustr4,LISTCTRLBUF+0x200,eaxstr  ;steppingID/version

	mov eax,ebp
	shr eax,4
	and eax,0xf
	STDCALL cpustr3,LISTCTRLBUF+0x300,eaxstr  ;Model

	mov eax,ebp
	shr eax,8
	and eax,0xf
	STDCALL cpustr2,LISTCTRLBUF+0x400,eaxstr  ;Family



	;compute the processor speed mega hertz
	;rdtsc returns the value of the time stamp counter in edx:eax
	;the processor increments this counter every clock cycle
	;we just compute the number of clock cycles in one half second
	;then divide by 1/2 * 1,000,000 to get mega cycles
	rdtsc 
	mov esi,edx
	mov edi,eax

	mov ebx,500
	call sleep

	rdtsc

	sub eax,edi
	sbb edx,esi
	;edx:eax contains the number of processor cycles 
	;elapsed during the half second sleep
	mov ebx,500000
	div ebx   
	;eax contains how many million processor cycles were executed 
	;in the half second sleep
	STDCALL cpustr8,LISTCTRLBUF+0x500,eaxstr  ;Processor speed
	;tom this used to be displayed as signed decimal

	

	;********************************************
	; Feature info returned in ebx from eax=1
	;********************************************

	push cpustr18
	push LISTCTRLBUF+0x600
	call strcpy2


	;brand index
	mov eax,[cpuFeatureInfoEBX]
	and eax,0xff
	STDCALL cpustr5,LISTCTRLBUF+0x700,eaxstr  


	;max number logical processors
	mov eax,[cpuFeatureInfoEBX]
	shr eax,16
	and eax,0xff
	STDCALL cpustr6,LISTCTRLBUF+0x800,eaxstr  


	;Local APIC ID
	mov eax,[cpuFeatureInfoEBX]
	shr eax,24
	and eax,0xff
	STDCALL cpustr7,LISTCTRLBUF+0x900,eaxstr  ;Initial APIC ID





	;*****************************************************
	;read the IA32_APIC_BASE_MSR Model Specific Register
	;*****************************************************
	mov ecx,0x1b
	rdmsr     ;read model specific register
	;return value in edx:eax but only eax has interesting stuff
	;before disabling local apic I get eax=0xfee00900 on two modern computers
	;in boot2 we now disable the local apic and the value is then 0xfee00100
	;bit 8 is set for bootstrap processor in multi processor computers
	;bit 11 is set if the processor local apic is enabled
	mov ebx,eax ;save eax
	STDCALL cpustr11,LISTCTRLBUF+0xa00,eaxstr  ;display value of MSR 0x1b
	mov eax,ebx
	shr eax,8
	and eax,1   ;mask off bit0
	STDCALL cpustr9,LISTCTRLBUF+0xb00,eaxstr  ;bootstrap processor
	mov eax,ebx
	shr eax,11
	and eax,1
	STDCALL cpustr10,LISTCTRLBUF+0xc00,eaxstr  ;APIC enable

	

	;********************************************
	; Feature info returned in edx from eax=1
	;********************************************

	push cpustr17
	push LISTCTRLBUF+0xd00
	call strcpy2

	;fpu on chip	
	mov eax,[cpuFeatureInfoEDX]
	and eax,1
	STDCALL cpustr12,LISTCTRLBUF+0xe00,eaxstr 

	;Page Size Extension
	mov eax,[cpuFeatureInfoEDX]
	shr eax,3
	and eax,1
	STDCALL cpustr13,LISTCTRLBUF+0xf00,eaxstr 

	;Time Stamp Counter
	mov eax,[cpuFeatureInfoEDX]
	shr eax,4
	and eax,1
	STDCALL cpustr14,LISTCTRLBUF+0x1000,eaxstr 

	;APIC on chip
	mov eax,[cpuFeatureInfoEDX]
	shr eax,9
	and eax,1
	STDCALL cpustr15,LISTCTRLBUF+0x1100,eaxstr 

	;SEP SysEnter/SysExit
	;if family==6 & model<3 & stepping<3 then not supported regardless
	mov eax,[cpuFeatureInfoEDX]
	shr eax,11
	and eax,1
	STDCALL cpustr19,LISTCTRLBUF+0x1200,eaxstr 

	;PTE global bit in page directory entry
	mov eax,[cpuFeatureInfoEDX]
	shr eax,13
	and eax,1
	STDCALL cpustr20,LISTCTRLBUF+0x1300,eaxstr 

	;CMOV conditional move 
	mov eax,[cpuFeatureInfoEDX]
	shr eax,15
	and eax,1
	STDCALL cpustr21,LISTCTRLBUF+0x1400,eaxstr 

	;PAT page attribute table
	mov eax,[cpuFeatureInfoEDX]
	shr eax,16
	and eax,1
	STDCALL cpustr22,LISTCTRLBUF+0x1500,eaxstr 

	;PSE-36 page size extension
	mov eax,[cpuFeatureInfoEDX]
	shr eax,17
	and eax,1
	STDCALL cpustr23,LISTCTRLBUF+0x1600,eaxstr 

	;MMX
	mov eax,[cpuFeatureInfoEDX]
	shr eax,23
	and eax,1
	STDCALL cpustr16,LISTCTRLBUF+0x1700,eaxstr 







	;*************************
	;setup the list control
	;*************************
	mov eax,QTY_STRINGS_FOR_LIST_CONTROL ;qty strings in list
	mov ebx,50 ;Ylocation of listcontrol
	call ListControlInit


.appmainloop:
	call backbufclear
	call ListControlPaint

	;program title
	STDCALL FONT01,0,20,cpustr0,0xefff,puts

	call swapbuf
	call getc

	cmp al,ESCAPE
	jnz .appmainloop

	call ListControlDestroy
	ret




