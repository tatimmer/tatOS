;tatOS/usb/queuehead.s


;code to modify an ehci queue head to insert the address and endpoint num


;note we are modifying the QH "on the fly" without shutting down the 
;asynch list or first removing the QH from the list
;see the ehci spec for "doorbell" and "handshake" discussions about this
;we could have some bad side affects since the ehci maintains a cache
;for now we have not seen a problem


;**************************************************************
;modify_ehci_qh
;the 2nd dword of the ehci QH contains the endpoint and address
;input: eax=address of queue head to modify
;       ebx=unique usb device address that we assign (see usb.s)
;       ecx=endpoint number (read from 3rd byte of endpoint descriptor)
;return:
;**************************************************************

modify_ehci_qh:

	mov edx,[eax+4]     ;read the 2nd dword of QH
	or edx,ebx          ;set new address
	shl ecx,8           ;shift the endpoint #
	or edx,ecx          ;set new endpoint #
	mov [eax+4],edx     ;save the QH 2nd dword 

	ret





