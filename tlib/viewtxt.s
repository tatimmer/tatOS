;tatOS/tlib/viewtxt.s


;*********************************************************
;viewtxt
;this is a simple ascii text viewer
;this function is written to view the contents of the DUMP
;we are currently scanning a max of 2meg to look for the 
;0 terminator which marks EndOfFile

;to exit you must hit the "ESCAPE" key 

;you can copy 1000 bytes to the CLIPBOARD starting at the
;first byte at the very top of the viewable screen by pressing 'c'

;scrollup, scrolldn, pageup, pagedn, home, end are enabled
;PageUp advances 500 chars and PageDN backs up 500 chars
;CTRL+PageUP, CTRL+PageDN move by 10,000 chars

;the ruler is a horizontal gray rect moved with "u" or "d" keys

;note viewtxt uses black text on 0xff background color
;if entry 0xff in the dac is changed to black the text wont show

;input
;esi = starting address in memory of 0 terminated ascii text 

;locals
viewtxtstartaddress    dd 0
viewtxtoffset          dd 0
viewtxtoffset2lastpage dd 0
viewrulerYloc          dd 0   ;gray rectangle starts at top use u/d keys to move

viewbytecountbuf times 32 db 0
viewtxtMenu db 'viewtxt: F1=SaveToFlash, ESC=quit, c=CopyToClip, Arrow=Up/Dn, Home-End-PageUp-PageDn',0
viewtxtstr1  db 'Enter 11 char filename',0
;********************************************************************************

viewtxt:


	;this control requires topdown orientation
	push dword [YORIENT]  ;save calling programs Yorientation
	mov dword [YORIENT],1 ;set Yorientation to top down


	;save starting address 
	mov [viewtxtstartaddress],esi

	;all we do is manipulate this offset
	mov dword [viewtxtoffset],0


	;find end of file and offset to view last page 
	mov edi,[viewtxtstartaddress]
	mov ecx,0x200000 ;max file size
	mov al,0
	cld
	repne scasb  ;scan for al, repeat while not equal, edi++, ecx-- 
	
	;edi points to 0 terminator
	sub edi,[viewtxtstartaddress]

	;back up more so last chars are viewable
	sub edi,40
	mov [viewtxtoffset2lastpage],edi



.mainloop:


	;PAINT 
	call backbufclear  


	;draw a horizontal rectangle across the page as a ruler/guide
	;ruler is light gray rect 15 pixels hi
	;use the u/d keys to move the ruler up or down
	STDCALL 0,[viewrulerYloc],800,15,LGR,fillrect


	;display a page of text starting at esi using putsml
	mov esi,[viewtxtstartaddress]
	add esi,[viewtxtoffset]
	STDCALL FONT01,0,0,esi,0xefff,putsml 
	;returns address of next char to display in esi


	;display the program menu 
	STDCALL FONT02,0,589,viewtxtMenu,0xeffe,puts


	;show byte offset from beginning of "file"
	mov eax,[viewtxtoffset]
	STDCALL viewbytecountbuf,0,0,eax2dec
	STDCALL FONT02,700,589,viewbytecountbuf,0xeffe,puts 


	call [SWAPBUF] 
	;end paint



	;block waiting for keypress
	call getc
	
	cmp al,PAGEDN
	jz near .doPageDown
	cmp al,PAGEUP
	jz near .doPageUp
	cmp al,DOWN
	jz near .doDown
	cmp al,UP
	jz near .doUp
	cmp al,HOME
	jz near .doHome
	cmp al,END
	jz near .doEnd
	cmp al,ESCAPE
	jz near .doEscape
	cmp al,'c'
	jz near .doCopy
	cmp al,'u'
	jz near .doUpRuler
	cmp al,'d'
	jz near .doDnRuler
	cmp al,F1
	jz near .doF1

	jmp .mainloop


.doPageDown:
	cmp byte [CTRLKEYSTATE],0
	jz .advance500
	add dword [viewtxtoffset],10000  ;advance by 10,000 chars if CTRL down
	jmp .continuePageDown
.advance500:
	add dword [viewtxtoffset],500  ;advance by 500 chars
.continuePageDown:
	mov ebx,[viewtxtoffset2lastpage]
	cmp ebx,[viewtxtoffset]
	jns near .mainloop
	mov [viewtxtoffset],ebx
	jmp .mainloop
	
	
.doPageUp:
	cmp byte [CTRLKEYSTATE],0
	jz .backup500
	sub dword [viewtxtoffset],10000  ;backup by 10000 chars if CTRL down
	jmp .continuePageUp
.backup500:
	sub dword [viewtxtoffset],500   ;backup by 5000 chars if CTRL down
.continuePageUp:
	jns near .mainloop
	mov dword [viewtxtoffset],0
	jmp .mainloop


.doDown:
	;advance 100 char
	add dword [viewtxtoffset],100
	mov ebx,[viewtxtoffset2lastpage]
	cmp ebx,[viewtxtoffset]
	jns near .mainloop
	mov [viewtxtoffset],ebx
	jmp near .mainloop
	
	
.doUp:
	;move back 100 char
	sub dword [viewtxtoffset],100
	jns near .mainloop
	mov dword [viewtxtoffset],0
	jmp near .mainloop


.doHome:
	;HOME=move to top of text
	mov dword [viewtxtoffset],0
	jmp .mainloop


.doEnd:
	;END=move to bottom of text
	mov ebx,[viewtxtoffset2lastpage]
	mov [viewtxtoffset],ebx
	jmp .mainloop


.doEscape:
	;hit ESC to quit the program
	pop dword [YORIENT]  ;save calling programs Yorientation
	ret 


.doUpRuler:
	;move the horizontal ruler up
	;we increment by 15 pixels because putsml uses font01
	;which uses 15 pixel vertical spacing
	cmp dword [viewrulerYloc],0
	jz .mainloop  ;clamp at top of screen
	sub dword [viewrulerYloc],15
	jmp .mainloop


.doDnRuler:
	;move the horizontal ruler down
	cmp dword [viewrulerYloc],585
	jz .mainloop   ;clamp at bottom of screen
	add dword [viewrulerYloc],15
	jmp .mainloop


.doCopy:
	;just press the 'c' key to copy 1000 bytes
	;starting at the very top of the screen
	mov edi,CLIPBOARD
	mov dword [edi],1000
	add edi,4
	mov esi,[viewtxtstartaddress]
	add esi,[viewtxtoffset]
	mov ecx,1000
	call strncpy
	jmp .mainloop


.doF1:  ;save viewtxt 0 terminated string to Flash Drive

	;count qty bytes in string
	mov eax,[viewtxtstartaddress] ;starting memory address
	call strlen  ;ecx=qty bytes

	;prompt user to enter new filename and save at COMPROMPTBUF
	push viewtxtstr1
	call fatgetfilename
	jnz .mainloop

	;write the file to CWD
	push dword [viewtxtstartaddress]    ;start of file data
	push ecx                ;qty bytes
	call fatwritefile       ;returns eax=0 on success, nonzero=failure

	jmp .mainloop




;*************** end of viewtext main ********************************






