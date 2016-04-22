;tatOS/usb/checkCSW.s


;a CSW CommandStatusWrapper is what is returned in the status phase
;of a scsi bulk transfer, its 13 bytes of goodies 

;call this function after inquiry, request sense, test unit ready, 
;read10, write10, read capacity

;our CSW looks like: 55 53 42 53 DD CC BB AA 00 00 00 00 00


;********************************************
;CheckCSWstatus

;memory for scsiCSW is reserved in usb.s

;check last byte of the CSW (bCSWStatus)
;00=command passed 
;01=failed 
;02=phase error
;03,04=Reserved (Obsolete)
;05-ff=Reserved

;input:esi=address of CSW
;      for uhci its scsiCSW
;      for ehci its 0xb70000

;return:
;eax=0 success and eax=1 on failure
;same as all other usb transactions
;sets CF if command passed else clears CF on failure

cswstr1 db 'CSW bCSWStatus = FAIL',0
cswstr2 db 'CSW bCSWStatus = FAIL-PHASE ERROR',0
cswstr3 db 'CSW bCSWStatus = FAIL-Reserved',0
cswstr4 db 'CSW bCSWStatus = Command Passed',0
;********************************************

CheckCSWstatus:

	;first dump the Command Status Wrapper
	STDCALL esi,13,dumpmem  


	;get the CSW status byte
	mov al, [esi+12]  

	cmp al,0
	jz .commandpassed
	cmp al,1
	jz .commandfailed
	cmp al,2
	jz .phaseerror


	;al>2 : failed reserved
	STDCALL cswstr3,dumpstr 
	clc
	mov eax,1
	jmp .done

.commandpassed:
	STDCALL cswstr4,dumpstr 
	stc
	mov eax,0
	jmp .done

.commandfailed:
	STDCALL cswstr1,dumpstr 
	clc
	mov eax,1
	jmp .done

.phaseerror:
	STDCALL cswstr2,dumpstr 
	clc
	mov eax,1

.done:
	ret






;this function is currently not used as of Aug 2012
;but I think it should be
;****************************************************
;CheckCSWSignatureTag
;check the CSW signature and tag
;the device should return this 
;as the signature and tag of the CSW
;expectedCSW (defined in uhci.s)
;db 0x55,0x53,0x42,0x53,0xdd,0xcc,0xbb,0xaa
;on a failed transaction you may see something like this
;db ff ff ff ff ff ff ff ff
;input
;none
;return
;sets CF on success,  clears CF on invalid Signature/Tag
checkcsw db 'USB Status Transport invalid CSW Signature&Tag',0
;****************************************************
CheckCSWSignatureTag:

	mov esi,scsiCSW
	mov edi,expectedCSW
	mov ecx,8
	cld
	repe cmpsb
	je .done
	STDCALL checkcsw,dumpstr 

.done:
	ret


