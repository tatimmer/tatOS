;tatOS/tlib/memset.s

;******************************************
;memset
;set all bytes in memory to the same value 

;input
;edi = starting address of memory
;ecx = qty bytes
; al = byte value to be place in memory

;no return value

;note nothing is preserved
;eax,ecx and edi are affected
;******************************************

memset:
	cld         ;increment
	rep stosb   ;al->edi do ecx times
	ret



;*****************************************
;memsetd
;same as above except works on dwords

;input
;edi = starting address of memory
;eax = dword value to be placed in memory
;ecx = qty dwords
;******************************************

memsetd:
	cld         ;increment
	rep stosd   ;eax->edi do ecx times
	ret




;if your looking for memcpy
;see strcpy and strncpy in string.s


