;tatOS/usb/hubdesc.s


;hubGetHubDescriptor

;code to issue the usb HUB Descriptor Request
;the hub must first be "configured" before issueing this request




HubDescriptorRequest:
db 0xa0    ;bmRequestType for GetHubDescriptor
db 6       ;bRequest=06=GET_DESCRIPTOR
dw 0x2900  ;wValue=29 for HUB and 00 for index
dw 0       ;wIndex
dw 8       ;wLength=bytes data returned in data phase 



hubHDstr1 db '********** hub HUB Descriptor COMMAND Transport **********',0
hubHDstr2 db '********** hub HUB Descriptor DATA    Transport **********',0
hubHDstr3 db '********** hub HUB Descriptor STATUS  Transport **********',0
hubHDstr4 db 'hub bNbrPorts qty downstream ports',0


;intel ehci with root hub VID=8086h, DID=1e2dh

;the first 8 bytes look like this
;09 29 06 09 00 32 00 00
;09=bDescLength
;29=bDescriptorType=HUB descriptor
;06=bNbrPorts, qty of downstream ports, note my asus laptop has only 3  ehci ports !
;00 09=wHubCharacteristics (power switching, over current, TT think time, port indicators)
;32=bPwrOn2PwrGood
;00=bHubContrCurrent
;00=DeviceRemovable


;************************************************************
;hubGetHubDescriptor
;control transfer code for the usb hub
;for use with ehci controller having root hub only
;input:none
;return:none
;************************************************************

GetHubDescriptor:


	;Command Transport
	;********************
	STDCALL hubHDstr1,dumpstr

	;copy request to data buffer 0xb70000
	mov esi,HubDescriptorRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;Device Descriptor Request is 8 bytes long
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error



	;Data Transport
	;*****************
	STDCALL hubHDstr2,dumpstr

	;the descriptor length is variable
	;you should request 8 bytes then examine the first byte bDescLength
	;then request bDescLength to get the full descriptor
	;all we are interested in here is the 3rd byte bNbrPorts

	;generate 1 usb Transfer Descriptor
	mov eax,8   ;qty bytes to receive
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error


	;copy the Hub Descriptor bytes received to 0x6040 for permanent storage
	mov esi,0xb70000
	mov edi,0x6040
	mov ecx,8
	call strncpy

	;dump the 8 bytes we got
	STDCALL 0x6040,8,dumpmem 

	;and dump the bNbrPorts (qty of downstream ports)
	mov al,[HUB_BQTYDOWNSTREAMPORTS]  
	STDCALL hubHDstr4,2,dumpeax




	;Status Transport
	;*******************
	STDCALL hubHDstr3,dumpstr

	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,0  ;PID_OUT	
	mov ecx,1  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error




.success:
	mov eax,0
	jmp .done
.error:
	mov eax,1
.done:
	ret


