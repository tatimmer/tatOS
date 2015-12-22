;tatOS/tlib/sort.s


;**********************************************************
;bubble sort
;This is a bubble sort by Index

;input
;esi=address of Myarray dword elements to sort
;ecx=qty elements in Myarray
;return
;Index array holds the sorted indices of Myarray from min to max

;explanation:
;Myarray contains a collection of dword values to sort
;this routine does not actually sort Myarray elements
;instead it fills an Index array and sorts the indexes
;the "Index" array is the same size as Myarray
;and immediately follows/appends Myarray
;the starting address of the Index array is Myarray+n
;this routine will initially fill "Index" with 0,1,2,3,4...
;then it will sort the Index array according to the 
;order of elements found in Myarray 
;Index(0) holds the index of the smallest element in Myarray
;Index(n-1) holds the index of the largest element in Myarray
;Array and Index are dword arrays

;example:
;Myarray = 9,5,12,2,7,23,13
;qty elements = 7
;After bubblesort is done Myarray will look like this:
;9,5,12,2,7,23,13,  3,1,4,0,2,6,5
;the last element of Myarray is 13
;the first element of the Index array is 3
;"3" is the index of the lowest value in Myarray which is the number 2
;remember our arrays are 0 based index so Myarray(0)=9, Myarray(1)=5 etc...
;"1" is the index of the next lowest value in Myarray which is 5
;"4" is the index of the next lowest value in Myarray which is 7
;the index of the maximum value in Myarray is found at the end of the Index array
;the value is 5 and Myarray(5)=23 which is the max value in Myarray
;get it ?

;caution! remember to allocate enough space for Myarray so Index array
;fits after Myarray, i.e. sizeof(Myarray) must be 2 times the number of dwords
;in Myarray

;******************************************************
;  Myarray(n)            |   Index(n)                 |
;******************************************************
;locals
bubbleNminus1  dd 0
bubblemadeswap dd 0
bubbleMyarray  dd 0  ;starting address of Myarray
bubbleIndex    dd 0  ;starting address of Index



bubblesort:
	pushad

	;storage 
	mov [bubbleMyarray],esi

	;store the starting address of the Index array
	lea eax,[esi+ecx*4]
	mov [bubbleIndex],eax
	
	;fill Index array with 0,1,2,3...n-1
	dec ecx  ;ecx=n-1
	mov [bubbleNminus1],ecx
	mov esi,[bubbleIndex]
.fill:
	mov [esi+ecx*4],ecx
	dec ecx
	jns .fill

.sortfromtop:
	;edx is our index into the Index array (i) 
	;max value is n-1 where n=qty elements in the array
	xor edx,edx              
	mov dword [bubblemadeswap],0  ;keep track if we made a swap or not thru the pass

.get2elements:
	mov esi,[bubbleIndex]
	mov eax,[esi+edx*4]     ;eax=Index(i)
	mov ebx,[esi+edx*4+4]   ;eax=Index(i+1)

	mov esi,[bubbleMyarray]
	mov ecx,[esi+eax*4]     ;ecx=Myarray(Index(i))
	mov edi,[esi+ebx*4]     ;edx=Myarray(Index(i+1))
	cmp ecx,edi             ;make the comparison
	jbe .increment         
.swap:
	mov esi,[bubbleIndex]
	mov [esi+edx*4],ebx       
	mov [esi+edx*4+4],eax
	mov dword [bubblemadeswap],1  ;set swap flag
.increment:
	inc edx
	cmp edx,[bubbleNminus1]
	jb .get2elements

	;check if we did any swapping this pass thru the array
	cmp dword [bubblemadeswap],1
	jz .sortfromtop    ;yes so go back thru the entire array again

	popad
	ret


