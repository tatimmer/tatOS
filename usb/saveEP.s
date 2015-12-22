;tatOS/usb/saveepnum.s

;******************************************************
;SaveEPnum

;input
;al=bEndpointAddress (3rd byte of Endpoint Descriptor)

;result
;extracts the endpoint number from bEndpointAddress
;and saves to either EPIN or EPOUT as appropriate
;0x81 indicates an IN endpoint number=1
;0x02 indicates an OUT endpoint number=2

saveEPstr1 db 'BULKEPOUT',0
saveEPstr2 db 'BULKEPIN',0
;******************************************************



SaveEPnum:

	;check if bit7 is set indicating IN endpoint
	bt eax,7
	jc .INendpoint

	;OUT endpoint
	;*************
	and al,0xf                ;mask off the low nibble EP number
	mov [BULKOUTENDPOINT],al  ;save EPOUT
	and eax,0xff              ;mask off upper bits
	STDCALL saveEPstr1,2,dumpeax
	jmp .done

.INendpoint:
	and al,0xf    
	mov [BULKINENDPOINT],al ;save EPIN
	and eax,0xff   
	STDCALL saveEPstr2,2,dumpeax

.done:
	ret



