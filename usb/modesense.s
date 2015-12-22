;tatOS/usb/modesense.s

;for reference only, not assembled into tatos.img, out of date do not use 2012


;ModeSense
;this transaction returns 4 bytes of seemingly useless info
;but both Linux and Windows do this transaction during mounting
;it seems to be required for some devices to "wake up".

;Jan 2009: I have removed this call from mountpd because 
;it caused a Lexar pen drive to barf on data transport 
;my SimpleTech, Burton SledDrive and Toshiba pen drives 
;all enumerate just fine without this command

;Sep 2009 the supporting functions have been removed
;this file is archive only


align 0x10


;Command Block Wrapper for SCSI ModeSense(6) (31 bytes)
ModeSenseRequest:
dd 0x43425355   ;dCBWSignature
dd 0xaabbccdd   ;dCBWTag  (just make it up)
dd 4            ;dCBWDataTransferLength (during tdData)
db 0x80         ;bmCBWFlags (tdData direction 0x80=IN 00=OUT)
db 0            ;bCBWLun
db 6            ;bCBWCBLength, ModeSense6 is a 6 byte command
;CBWCB (16 bytes) see the SCSI ModeSense(6) Command
db 0x1a         ;SCSI operation code for ModeSense(6)
db 0            ;SCSI reserved
db 0x3f         ;SCSI page code (3f=return ALL pages)
db 0            ;SCSI Reserved
db 192          ;SCSI allocation length ???
db 0            ;SCSI Control
times 10 db 0   ;USBmass CBWCB must be 16 bytes long



;THIS CODE IS NOT UP TO DATE AS OF NOV 2009 AND WILL NOT WORK
;FOR HISTORICAL REFERENCE ONLY

ModeSense:

	push mpdstr33
	call [PUTSCROLL]


	push ModeSenseRequest
	push 0x5300    ;device returns data transport here
	push 4         ;qty bytes returned by device in data transport
	call buildSCSItransaction

	mov edi,BULKQUEUEHEAD
	call runtransaction
	jc .done  ;serious error

	call CheckCSWstatus
	jc .done  ;command passed

.done:
	ret







