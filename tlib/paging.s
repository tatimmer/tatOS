;tatOS/tlib/paging.s

;code to build page directory entries for 4mb (0x400000 bytes per page) paging
;elementary identy mapping for now since we currently only support 1 userland process
;our page table is 1024 directory entries starting at 0x8000
;we map all pages as present, the first 8 are for kernel, the next 2 for user
;the remaining pages are for kernel

;page  0: 0x00000000->0x00400000   kernel
;page  1: 0x00400000->0x00800000   kernel
;page  2: 0x00800000->0x00c00000   kernel
;page  3: 0x00c00000->0x01000000   kernel
;page  4: 0x01000000->0x01400000   kernel
;page  5: 0x01400000->0x01800000   kernel
;page  6: 0x01800000->0x01c00000   kernel
;page  7: 0x01c00000->0x02000000   kernel
;page  8: 0x02000000->0x02400000   userland code and data
;page  9: 0x02400000->0x02800000   reserved for another future userland process
;page 10: 0x02800000->0x02c00000   kernel
;page 11 -> page 1023 is all reserved for the kernel


;in case your app gets a page fault interrupt #14:
;the ErrorCode is as follows:
;[7] = page present, access caused by write, processor in user mode
;[5] = page present, access caused by read,  processor in user mode
;check the dump messages after a ttasm assemble to find the offending
;instruction with the matching EIP value 

;if page fault EIP=0, this is most likely caused by an unbalanced userland stack
;a 'ret' instruction has popped a 0 byte off the stack and attemped to 'jmp 0'
;and this causes the fault.



;future: 
;reserve page 10,11 for another userland process
;this process will have its own page directory entries 
;we map process 2 page 10 to STARTOFEXE same as user process 1
;and mark process 1 pages 8,9 as not present 
;for our small apps we really dont need to reserve 2 4mb pages for each process
;one 4mb page is probably sufficient


;the bottom 8 bits are important in the page directory entry
;0x83 = supervisor, read/write, 4mb, present
;0x87 = user, read/write, 4mb, present
;we need read/write for flat binary code and data mixed
;a couple bits Im not real sure of yet
;bit3 PWT set to 0 to allow write back caching 
;bit4 PCD set to 0 to allow page or page table to be cached

;if you run xxd right after tatOS starts up
;you will see the processor has modified the first entry at 0x8000
;so the low byte now reads 0xe3 instead of 0x83
;the processor sets bit5 accessed and bit6 dirty

;note tlibentry.s has a Validate macro and userland addresses
;that are hardcoded, so if we changing from identity map paging 
;so userland code starting at address 00000000 then we must
;also make changes to tlibentry.s accordingly tom !!!



;********************************************
;BuildPageDirectory
;here we write to memory starting at 0x8000
;our 1024 page directory entries
;this code is executed in tatOSinit.s
;first we make 8 entries for kernel
;the 2 entries for userland
;then the remaining entries for kernel
;input:none
;return:none
;********************************************

BuildPageDirectory:

	cld

	;prepare for the first 8 pages for kernel/supervisor 
	;the PageBaseAddress starts at 0 because we are identity mapping
	;set the low byte to 0x83 for supervisor, read/write, 4mb, present
	mov eax,0x83

	;init the destination for the directory entry
	mov edi,0x8000

	;init the loop counter for 8 kernel entries
	mov ecx,8



	;write the 1st 8 kernel page directory entries
	;************************************************

.1:
	;now write the 4mb page directory entry to memory
	mov [edi],eax

	;increment the destination memory address
	add edi,4

	;increment the Page Base Address by 4mb
	add eax,0x400000

	loop .1
	;done writting the first 8 kernel page entries




 	;now write 2 userland page entries
	;************************************

	;set the low byte to 0x87 for user, read/write, 4mb, present
	mov al,0x87

	;write the first userland entry
	mov [edi],eax
	add edi,4
	add eax,0x400000

	;write the 2nd userland entry
	mov [edi],eax
	add edi,4
	add eax,0x400000




	;now write the remaining entries up to 4gib
	;********************************************

	;change the low byte to 0x83 for kernel
	mov al,0x83

	;8+2+1014=1024 4mb pages 
	mov ecx,1014

.2:
	;now write the 4mb page directory entry to memory
	mov [edi],eax

	;increment the destination memory address
	add edi,4

	;increment the Page Base Address by 4mb
	add eax,0x400000

	loop .2

	ret




