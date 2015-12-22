;tatOS/tlib/rand.s

;***************************************************************
;rand
;pseudo random number generator
;written by Andrew Griffen and Max McGuire
;taken from John Eckerdahls web set

;input
;if ebx=0 then get a new random number and return dword in eax
;if ebx!=0 then assign a new value to RANDSEED and exit

;return: random DWORD in eax

;note RANDSEED is initialize in tatOSinit.s
;but you may need to assign a new value depending

;local
_ranstr1 db 'rand:new RANDSEED',0
_ranstr2 db 'rand:new random number',0
;***************************************************************
	
rand:

	cmp ebx,0
	jz .getrandom
	mov [RANDSEED],ebx  ;save new RANDSEED
	STDCALL _ranstr1,0,dumpebx
	jmp .done

.getrandom:
	
	mov ebx,[RANDSEED]
	mov eax,ebx
	shl eax,2
	add eax,ebx
	xchg al,ah
	mov [RANDSEED],eax

	;with Fern this really fills up the dump and slows down the program
	;STDCALL _ranstr2,0,dumpeax

.done:
	ret




