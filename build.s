;tatOS/build.s
;June 2013

;tatOS is assembled with NASM on Debian Linux
;cat /proc/version reports Linux version 2.6.26-2-686 (Debian 2.6.26-17)
;nasm -v report NASM version 2.03.01 compiled on Jun 18 2008

;all this file does is combine boot1+boot2+tlib = tatOS.img

;boot1 is exactly 1 sector = 512 bytes long
;org = 0x7c00  as usual
incbin "boot/boot1"

;boot1 loads boot2 to org = 0x600
;boot2 loads tlib 
incbin "boot/boot2"

;the org of tlib is 0x10000
;all of tlib is included in tlib.s 
incbin "tlib/tlib"


;for making boot floppy or boot pen drive
;comment out this times directive
;for making bootCD we need to pad out img file to a full floppy
;times 1474560 - ($-$$) db 0


