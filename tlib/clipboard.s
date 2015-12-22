;tatOS/tlib/clipboard.s


;userland code needs these functions to copy data to the 
;clipboard and to obtain data from the clipboard
;the clipboard is 1meg of kernel memory starting at CLIPBOARD
;the first dword at CLIPBOARD is the qty of bytes
;the data starts at CLIPBOARD+4



;***************************************************
;copytoclipboard
;copy data from userland to the clipboard
;the data must all fit within the clipboard
;input:
;push starting address of userland memory [ebp+12]
;push qty bytes to copy                   [ebp+8]
;return: CF is clear on success, set on error
copystr1 db 'copy to clipboard',0
;**************************************************

copytoclipboard:

	push ebp
	mov ebp,esp

	STDCALL copystr1,dumpstr

	;test for valid starting address
	push dword [ebp+12]
	call ValidateUserAddress
	jc .done

	;test for valid ending address
	mov eax,[ebp+12]
	add eax,[ebp+8]
	push eax
	call ValidateUserAddress
	jc .done


	;write the qty of bytes
	mov eax,[ebp+8]	
	mov [CLIPBOARD],eax


	;copy the data from userland to clipboard
	cld
	mov esi,[ebp+12]
	lea edi,[CLIPBOARD+4]
	mov ecx,[ebp+8]
	rep movsb

	clc  ;clear on success

.done:
	pop ebp
	retn 8



;***************************************************
;copyfromclipboard
;copy data from the clipboard to userland memory
;the qty of bytes to copy must already be stored
;at the first dword of CLIPBOARD

;userlands memory received an exact copy of 
;what is in the clipboard so the first dword
;is qty bytes and then starts the data

;input:
;push destination address of userland memory [ebp+8]
;return: CF is clear on success, set on error

copystr2 db 'copy from clipboard',0
;**************************************************

copyfromclipboard:

	push ebp
	mov ebp,esp

	STDCALL copystr2,dumpstr

	;test for valid starting address
	push dword [ebp+8]
	call ValidateUserAddress
	jc .done

	;get the qty of bytes to copy from the clipboard
	mov ecx,[CLIPBOARD]

	;test for valid ending address
	mov eax,[ebp+8]
	add eax,ecx
	push eax
	call ValidateUserAddress
	jc .done


	;copy qty bytes to userland
	mov edi,[ebp+8]
	mov [edi],ecx

	;copy data to userland
	cld
	lea esi,[CLIPBOARD+4]
	add edi,4
	;ecx=qty bytes
	rep movsb

	clc  ;clear on success

.done:
	pop ebp
	retn 4





