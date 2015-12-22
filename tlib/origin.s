;tatOS/tlib/origin.s

;*******************************************************
;origin
;sets the local origin and y axis orientation

;input,push as follows:
;XOFFSET [ebp+16]                          
;YOFFSET [ebp+12]
;YORIENT [ebp+8]

;return:none

;YORIENTation is by default set to 1 which means
;y=0 is along the top of the screen and y=599 
;is at the bottom. If you set YORIENT=-1 then this is
;reversed and y=0 is at bottom and y=599 is at top.

;XOFFSET is from the left edge of the screen
;YOFFSET is from y=0

;after you exit any program or hit Ctrl+Alt+Del
;the following values are reset to default:
;XOFFSET=0
;YOFFSET=0
;YORIENT=1

;XOFFSET, YOFFSET, and YORIENT or global dwords
;see /doc/memorymap

;see also function getpixadd which is affected by
;all these values
;*******************************************************

origin:
	push ebp
	mov ebp,esp
	push eax
	push ebx

	mov eax,[ebp+16]
	mov ebx,[ebp+12]
	mov [XOFFSET],eax
	mov [YOFFSET],ebx

	mov eax,[ebp+8]
	mov [YORIENT],eax

	pop ebx
	pop eax
	pop ebp
	retn 12


