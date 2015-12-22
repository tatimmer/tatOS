;tatOS/usb/info.s


;getflashinfo
;gethubinfo


;kernel functions to copy data to userland pages for examination


;*****************************************************************
;getflashinfo
;this code copies kernel data that was saved during initflash
;to userland for examination. /apps/FlashInfo can 
;display this information. We are talking about the flash drive
;device descriptors, endpoint descriptors, Interface and
;configuration descriptors, and the results from SCSI 
;read capacity and inquiry
;input:edi=userland memory address to copy data to 
;      this should be in the same users page after user code
;return:none
;****************************************************************

getflashinfo:

	;we copy kernel data from 0x5000->0x5224
	cld
	mov ecx,0x224    ;qty bytes2copy
	mov esi,0x5000
	;edi is set by user
	rep movsb

.done:
	ret



;gethubinfo copies the usb hub descriptors saved during inithub.s
;same inputs and same return
gethubinfo:

	;we copy kernel data from 0x6000->0x6048
	cld
	mov ecx,72    ;qty bytes2copy
	mov esi,0x6000
	;edi is set by user
	rep movsb

.done:
	ret



