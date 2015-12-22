;tatOS/tlib/roundmode.s 


;*******************************************
;roundmode
;set the fpu rounding mode

;input
;push 0=nearest (default)       [ebp+8]
;	  1=down toward - infinity
;     2=up toward + infinity 
;     3=truncate

;return:none

;bits 10,11 of the fpu ControlWord control
;the rounding mode.

;this instruction affects the result of frndint
;which rounds st0 to an integer according to 
;the current rounding mode

;e.g. st0=19.876
;near=11.0, dn=10.0, up=11.0, trun=10.0
;e.g. st0=10.456
;near=10.0, dn=10.0, up=11.0, trun=10.0

;note a well behaved app should return the 
;rounding mode to "nearest" when done

;pow for example requires "truncate"

;see "SIMPLY FPU" by "Raymond Filiatreault"

;local variable
_roundCW dw 0
;*******************************************

roundmode:

	push ebp
	mov ebp,esp
	push eax

	;get the current Control Word 
	fstcw word [_roundCW]

	;first clear bits 10,11
	;this sets the default rounding mode to "nearest"
	and word [_roundCW],0xf3ff
	
	;now set bits 10,11 to the selected rounding mode
	mov eax,[ebp+8]
	shl eax,10
	or word [_roundCW],ax

	;save the Control Word with new rounding mode
	fldcw word [_roundCW]

	pop eax
	pop ebp
	retn 4
	

