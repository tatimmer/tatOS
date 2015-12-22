;tatOS/usb/clearep.s


;code to conduct the Clear Feature ENDPOINT_HALT control transaction

;use this for flash drive bulkin or bulkout endpoints only, not control endpoint0


ClearFeatureEndpointHaltRequest:
db 0x2     ;bmRequestType=02=endpoint
db 1       ;bRequest=01=CLEAR_FEATURE
dw 0       ;wValue=00=Feature Selector ENDPOINT_HALT
dw 0       ;wIndex = endpoint number
dw 0       ;wLength=0




cfstr1 db '********** Flash Clear Feature ENDPOINT_HALT  COMMAND transport **********',0
cfstr2 db '********** Flash Clear Feature ENDPOINT_HALT  STATUS  transport **********',0


;********************************************************
;ClearFeatureEndpointHalt

;input:ax=endpoint number to clear
;return: eax=0 on success, 1 on error
;********************************************************

ClearFeatureEndpointHalt:

	;write endpoint # into the request
	mov word [ClearFeatureEndpointHaltRequest+4],ax


	;Command Transport
	;********************
	STDCALL cfstr1,dumpstr

	;copy request to data buffer 0xb70000
	mov esi,ClearFeatureEndpointHaltRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error




	;Data Transport
	;*****************
	;there is no data transport



	;Status Transport
	;*******************
	STDCALL cfstr2,dumpstr

	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,1  ;PID = IN	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,FLASH_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error




.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret





