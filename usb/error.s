;tatOS/usb/error.s


;code to check for USBSTS transaction errors
;the ehci and uhci both have a bit in the status register USBSTS
;that is set if a transfer descriptor fails.
;this often happens during initflash
;the solution I have is to manually reinit the controller and 
;run initflash a second time and then it always succeeds
;all this code does is check this error bit 


errorstr db 'USB Error Interrupt-TD has Failed-Reinit controller & Flash',0


;***********************************************************
;ehciControllerError
;input:none
;return: ZF is set on success, clear on error 
;***********************************************************

ehciControllerError:

	;get the value of USBSTS status register for ehci
	mov esi,[EHCIOPERBASE]  ;get start of oper reg
	mov eax,[esi+4]  ;OperationalBase + 4 = USBSTS
	mov ebx,eax               ;save copy

	;the Error Interrupt is bit1 of USBSTS
	;this bit is set if a TD has failed, often happens during initflash
	shr eax,1
	and eax,1  ;1AND1=1,  0AND1=0
	jz .done   ;ZF is set on success, no TD error

	;try to clear the error bit in USBSTS, not sure if this works 
	STDCALL errorstr,putscroll
	or ebx,10b     ;bit1 is R/WC so to clear it we write a 1
	mov [esi],ebx  ;save USBSTS back with bit1 cleared
	or eax,1       ;clear ZF on error

.done:
	ret




;***********************************************************
;Aug 2012 I have updated ehciControllerError but not this one
;uhciControllerError
;input:none
;return: ZF is set on success, clear on error 
;***********************************************************

uhciControllerError:

	mov dx,[UHCIBASEADD]
	add dx,2
	in ax,dx  ;read in USBSTS

	shr eax,1
	and eax,1

	jz .done   ;ZF is set on success, no TD error
	pushfd     ;preserve flags
	STDCALL errorstr,putspause
	popfd

.done:
	ret





