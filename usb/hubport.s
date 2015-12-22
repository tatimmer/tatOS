;tatOS/usb/hubport.s



;HubGetPortStatus
;HubPortReset
;HubPortPower




;code to control the ports of a hub
;specifically developed on my asus laptop with ehci and "root" hub



GetPortStatusRequest:
db 0xa3    ;bmRequestType for GetPortStatus
db 0       ;bRequest=00=GET_STATUS
dw 0       ;wValue use 0
dw 0       ;wIndex, this is portnum 1,2,3...
dw 4       ;wLength=bytes data returned in data phase 


hubportstatus dd 0  ;save the port status dword here

hubportstr1 db 'Hub Get Port Status COMMAND Transport',0
hubportstr2 db 'Hub Get Port Status DATA    Transport',0
hubportstr3 db 'Hub Get Port Status STATUS  Transport',0
hubportstr4 db 'hub port status',0
hubportstr5 db '********** hub port#: port status **********',0


;the GetPortStatus returns 4 bytes of info
;the loword is wPortStatus see table 11-21 usb 2.0 spec
;the hiword is wPortChange see table 11-22
;after SetConfiguration the port status is 0x0
;after HubPortPower the port status is:
;  * for device not present = 0x100 (port is not in the powered off state)
;  * for device present = 0x10101 
;after HubPortReset the port status is:
;  * for device not present = 0x100 
;  * for flash drive present = 0x110503
;      -0503 = device present, port is enabled, port is not powered off, hi speed device
;      -11 = current connect status has changed, reset complete 
;  * for mouse present = 0x110303
;      -0303 = device present, port is enabled, port is not powered off, lo speed device




;*************************************************
;GetHubPortStatus
;retrieves the status dword of a downstream port
;input:eax=port number starting with 1
;return:ebx=hub port status
;       eax=0 on success, 1 on error
;*************************************************

HubGetPortStatus:

	push ecx
	push edx
	push esi
	push edi

	;write the port number into the request
	STDCALL hubportstr5,0,dumpeax
	mov [GetPortStatusRequest+4],ax


	;Command Transport
	;********************
	STDCALL hubportstr1,dumpstr

	;copy request to data buffer 0xb70000
	mov esi,GetPortStatusRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;qty bytes to transfer 
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error



	;Data Transport
	;*****************
	STDCALL hubportstr2,dumpstr

	;generate 1 usb Transfer Descriptor
	mov eax,4   ;qty bytes to transfer (receive)
	mov ebx,1   ;PID = IN	
	mov ecx,1   ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error

	;get the Hub port status dword
	mov eax,[0xb70000]
	mov [hubportstatus],eax


	;dump the hub port status
	STDCALL hubportstr4,0,dumpeax




	;Status Transport
	;*******************
	STDCALL hubportstr3,dumpstr

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
	;return value
	mov ebx,[hubportstatus]
	mov eax,0
	jmp .done
.error:
	mov ebx,0
	mov eax,1
.done:
	pop edi
	pop esi
	pop edx
	pop ecx
	ret






HubPortResetRequest:
db 0x23    ;bmRequestType for SetPortFeature
db 3       ;bRequest=03=SET_FEATURE
dw 4       ;wValue=FeatureSelector=PORT_RESET
dw 0       ;wIndex, this is portnum 1,2,3...
dw 0       ;wLength

hubPRstr1 db 'hub Port Reset COMMAND Transport',0
hubPRstr3 db 'hub Port Reset STATUS  Transport',0
hubPRstr4 db '********** hub port#: resetting hub port number **********',0


;**************************************************************
;HubPortReset
;reset a downstream port of a hub
;input: eax=port number 1,2,3...
;return:eax=0 on success, 1 on error
;*************************************************************

HubPortReset:

	push ecx
	push edx
	push esi
	push edi


	;write the port number into the request
	STDCALL hubPRstr4,0,dumpeax
	mov [HubPortResetRequest+4],ax



	;Command Transport
	;********************
	STDCALL hubPRstr1,dumpstr

	;copy request to data buffer 0xb70000
	mov esi,HubPortResetRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;qty bytes to transfer 
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error



	;Data Transport
	;*****************
	;no data transport




	
	;Status Transport
	;*******************
	STDCALL hubPRstr3,dumpstr

	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,1  ;PID_IN	
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
	pop edi
	pop esi
	pop edx
	pop ecx
	ret






HubPortPowerRequest:
db 0x23    ;bmRequestType for SetPortFeature
db 3       ;bRequest=03=SET_FEATURE
dw 8       ;wValue=FeatureSelector=PORT_POWER
dw 0       ;wIndex, this is portnum 1,2,3...
dw 0       ;wLength

hubPPstr1 db 'Hub Port Power COMMAND Transport',0
hubPPstr3 db 'Hub Port Power STATUS  Transport',0
hubPPstr4 db '********** hub port#: applying power **********',0


;**************************************************************
;HubPortPower
;apply power to a downstream port of a hub
;input: eax=port number 1,2,3...
;return:eax=0 on success, 1 on error
;note after the hub is configured, the ports have no power
;*************************************************************

HubPortPower:

	push ecx
	push edx
	push esi
	push edi


	;write the port number into the request
	STDCALL hubPPstr4,0,dumpeax
	mov [HubPortPowerRequest+4],ax



	;Command Transport
	;********************
	STDCALL hubPPstr1,dumpstr

	;copy request to data buffer 0xb70000
	mov esi,HubPortPowerRequest
	mov edi,0xb70000
	mov ecx,8
	call strncpy

	;generate 1 usb Transfer Descriptor
	mov eax,8  ;qty bytes to transfer 
	mov ebx,2  ;PID = SETUP	
	mov ecx,0  ;data toggle
	call generate_TD

	;attach TD to queue head and run
	mov eax,HUB_CONTROL_QH_NEXT_TD_PTR
	call ehci_run
	jnz near .error



	;Data Transport
	;*****************
	;no data transport


	
	;Status Transport
	;*******************
	STDCALL hubPPstr3,dumpstr

	;generate 1 usb Transfer Descriptor
	mov eax,0  ;qty bytes to transfer
	mov ebx,1  ;PID_IN	
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
	pop edi
	pop esi
	pop edx
	pop ecx
	ret



