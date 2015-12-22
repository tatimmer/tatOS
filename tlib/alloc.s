;tatOS/tlib/alloc.s



;alloc
;free



;the alloc function can only be used by kernel
;userland apps should reserve their own memory after their exe
;they get a 4mb page which should be plenty

;this is a new memory allocator for tatOS
;it uses a Memory Allocator Table (MAT) similar to the FAT16 table
;on a tatOS flash drive

;we reserve 5meg for our "heap" and the MAT table 
;memory is allocated in clusters of 1 page or 0x1000 bytes 
;we have max 1275 clusters available to allocate
;1275 clusters of 1 page will occupy from 0x1400000 to 0x18fb000

;the MAT table consists of 1275 word entries 
;we locate the start of the MAT at 0x18ff000 in memory which is just after the heap
;each word represents one cluster of memory
;on startup tatOS inits the MAT table to all 0000 entries

;a 0000 entry indicates memory is available
;a ffff entry indicates end of allocated memory
;any value from 0001->00fe indicates the location of the next cluster in the chain

;example to mark the MAT:

;if the first request for memory is less than 1 page then the first word of the MAT table is 
;marked with 00ff indicating memory taken and no more clusters in the chain

;if the first request for memory is say 5 pages then the MAT is marked as follows:
;cluster0 = 0001 
;cluster1 = 0002 
;cluster2 = 0003 
;cluster3 = 0004 
;cluster4 = 00ff

;the benefit of this allocator over the previous is that memory can be freed 
;at any time/order regardless of when it was allocated. 
;Also allocated memory blocks need not be contiguous.

;tatos.init inits the MAT with all zeros


;******************************************************************
;alloc
;allocate memory from our "heap" and return the address
;for kernel functions only

;input:
;ecx=qty bytes requested from our "heap"

;return:
;success: ZF is clear, esi=address in heap of memory block
;failure: ZF is set,   esi=0

ALLOCBUFFERSTART equ 0x1400000 
ALLOCBUFFEREND   equ 0x18fb000
STARTOFMAT       equ 0x18ff000
ENDOFMAT         equ 0x18ff9f6
allocbytespercluster dd 0x1000
allocqtyclustersreqd dd 0
allocStartOfMemory   dd 0
allocCurrentCluster  dd 0

allocstr1 db 'alloc',0
allocstr2 db 'alloc: failed to find first available cluster',0
allocstr3 db 'alloc: failed to find next available cluster',0
allocstr4 db 'alloc: memory address returned',0
;******************************************************************

alloc:

	pushad

	;compute qty clusters required
	xor edx,edx
	mov eax,ecx
	div dword [allocbytespercluster]  ;eax=qty clusters if remainder is 0
	cmp edx,0                         ;if any remainder need 1 more cluster
	jz .doneqtyclusters
	add eax,1                         ;one more cluster needed
.doneqtyclusters:
	mov [allocqtyclustersreqd],eax    ;save for later
	


	;find first available cluster in the MAT
	;*****************************************

	cld
	mov esi,STARTOFMAT
	mov ecx,-1   ;ecx=cluster number  

.ReadCluster:

	lodsw   ;ax=[esi], esi++
	inc ecx

	cmp ax,0
	jz .FoundFirstCluster

	cmp ecx,1275
	jb .ReadCluster

	;if we got here we have looked thru the entire MAT
	;and failed to find 
	STDCALL allocstr2,dumpstr
	jmp .error

.FoundFirstCluster:

	;ecx=first available cluster number

	;compute address in heap corresponding to this starting cluster
	mov esi,ecx
	shl esi,12  ;times 0x1000 bytes per cluster
	add esi,ALLOCBUFFERSTART
	mov [allocStartOfMemory],esi
	


	;Mark the MAT for a single cluster 
	;**********************************

	cmp dword [allocqtyclustersreqd],1
	ja .markmultipleclusters
	;get address of starting cluster
	lea edi,[STARTOFMAT+ecx*2]   
	;mark MAT cluster as terminate
	mov word [edi],0xffff   ;mark as terminate 
	jmp .success




	;Mark the MAT for Multiple Clusters
	;**************************************

.markmultipleclusters:

	;routine to find and mark multiple entries in MAT
	;this code was taken from fat16.s and adapted accordingly 
   
	;set CurrentCluster equal to the startingcluster
	mov [allocCurrentCluster],ecx

	;set esi to address of cluster after startingcluster
	add ecx,1
	lea esi,[STARTOFMAT+ecx*2]   

	;loop counter is 1 less than qty clusters reqd
	mov edx,[allocqtyclustersreqd]
	sub edx,1        ;edx=loop counter

.findNextAvailableCluster:

	mov ax,[esi]     ;get cluster num

	cmp ax,0         ;test for 00
	jz .markCluster

	cmp esi,ENDOFMAT ;test for end of the MAT which means we failed
	jb .nextCluster

	;if we got here we failed to find the next available cluster
	STDCALL allocstr3,dumpstr
	jmp .error

.nextCluster:

	add esi,2  ;increment address of cluster to check by 1 word
	jmp .findNextAvailableCluster

.markCluster:

	;esi holds address of NextAvailableCluster

	;compute ax = index of NextAvailableCluster 
	mov eax,esi
	sub eax,STARTOFMAT         
	shr eax,1   ;divide by 2 because MAT clusters are words

	;save number of NextAvailableCluster at the CurrentCluster position	
	mov ebx,[allocCurrentCluster]
	lea edi,[STARTOFMAT+ebx*2]    ;get address of current cluster 

	;mark the MAT CurrentCluster with number of NextAvailableCluster
	mov [edi],ax                 

	;save CurrentCluster as NextAvailableCluster
	mov [allocCurrentCluster],eax

	;decrement qtyclusters marked
	sub edx,1
	jnz .nextCluster


	;mark the last cluster as terminate
	lea edi,[STARTOFMAT+eax*2]   ;eax will be last cluster 
	mov word [edi],0xffff        ;mark the MAT as terminate



.success:
	or eax,1
	jmp .done
.error:	
	mov dword [allocStartOfMemory],0
	xor eax,eax
.done:
	mov eax,[allocStartOfMemory]
	STDCALL allocstr4,0,dumpeax     ;memory address returned
	popad
	mov esi,[allocStartOfMemory]  ;return value
	ret







;***************************************************************
;free
;frees the memory returned by alloc

;input:
;esi=address in heap of memory block to free
;this must be an address that was returned by the alloc function
;otherwise undefined behavior

;return:
;ZF is clear on success and set on error

freestr1 db 'free',0
freestr2 db 'free: cluster number out of range',0
freestr3 db 'free: error reading MAT',0
freestr4 db 'free: starting cluster number',0

freeNextCluster dw 0
;***************************************************************

free:

	pushad

	;compute starting cluster number in MAT
	mov eax,esi
	sub eax,ALLOCBUFFERSTART
	shr eax,12   ;divide by 0x1000 bytes per cluster
	;eax=cluster number
	;STDCALL freestr4,0,dumpeax


	;check that cluster number is 0-1275 
	cmp eax,0
	jl .outofrange
	cmp eax,1275
	jge .outofrange




	;read the MAT starting with the first cluster
	;and mark appropriate cluster 00 for reuse
	;*****************************************************

	cld
	;eax=is initiated to the starting cluster number

.ReadCluster:

	lea esi,[STARTOFMAT+eax*2]   

	;just a check to make sure we dont read beyond the MAT
	cmp esi,ENDOFMAT
	ja .errorReadingMAT

	;read the value of the next cluster in the chain
	mov ax,[esi]

	cmp ax,0     ;if we started correctly, we should never find a 00 empty cluster
	jz .errorReadingMAT

	cmp ax,0xffff
	jz .FreeLastCluster

	;mark the cluster as available
	mov word [esi],0 
	
	jmp .ReadCluster


.FreeLastCluster:
	mov word [esi],0 
	jmp .success



.errorReadingMAT:
	STDCALL freestr3,dumpstr
	xor eax,eax
	jmp .done
.outofrange:
	STDCALL freestr2,dumpstr
	xor eax,eax
	jmp .done
.success:
	or eax,1
	;fall thru
.done:
	popad
	ret



