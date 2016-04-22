;tatOS/usb/interruptmouse.s

;usbcheckmouse
;usbmouserequest
;getmousexy
;usbShowMouseReport



;code to conduct usb mouse interrupt transactions
;and get the 4 or 5 or whatever byte report from the mouse interrupt IN endpoint
;for uhci controller only because the mouse is a low speed device
;and we only support mouse pluged into "root" port (not into hub)

;the interrupt transaction is nothing but data transport on the IN pipe
;no command transport and no status transport
;the data transport just means if the mouse is moved or a button is clicked
;then the usb controller will write a dword value to our global mousereportbuf

;you have to constantly queue up a request
;then poll the device for a response 
;NAK=0x048807ff indicates the user has not clicked a button or moved the mouse
;since the request was queued up
;the way we check for mouse activity is to set the mousereport buffer to
;something the mouse can not possibly give (09090909) 

;the mouse report is written to "mousereportbuf"
;after a report is given you have to queue up a new request
;and "zero" out the mousereport buffer

;the mouse report bytes are similar for both ps2 and usb mice 
;the only differance is the deltaY is in the opposite direction
;note also that the Manhattan mouse gives a 5 byte report with leading 01 byte 
;the microsoft and Logitech mouse give a traditional 4 byte report
;also the bytes given depend on protocol boot or report (we use report protocol)
;for this reason and because we do not have any code to parse the messy mouse
;report descriptor, you have to run "usb Show Mouse Report" and "calibrate" 
;the usb mouse driver by entering the index of your button click byte. 
;For Logitech and Microsoft the button click byte is the first byte of the 
;mouse report so you enter 00.  For my odd Manhattan mouse the second byte 
;is the button click byte so you enter 01.

;mouse report:
;bb dx dy dz
;the first byte is a bitmask of button clicks
;bit0=left button  (bit set=down, clear=up)
;bit1=right button
;bit2=middle button
;the next byte is delta X movement  (+X right)
;the next byte is delta Y movement  (+Y down)
;the next byte is delta Z movement  (wheel either 1 or 0xff)



;Manhattan Mouse with SetProtocol=boot 
;****************************************
;this mouse is giving 3 bytes (TD = 0x04000002 or NAK=0x048807ff)
;01 11 22
;the 01 byte never changes
;the 11 byte indicates button up/down events 
;the 22 byte indicates movement 2=right, fe=left, ff=up, 1=dn (x & y in 1 byte ??)
;cant seem to get any wheel rotation indicator



;Manhattan Mouse with SetProtocol=report 
;****************************************
;Manhattan mouse is giving 6 bytes  (TD = 0x04000005 or NAK)
;01 11 22 33 44 55 
;the 01 byte never changes - whats the point of this byte ???
;the 11 byte is button clicks same as above
;the 22 byte gives 1,2,3,4... for +delta_X and fe,fd,fc... for -delta_X
;the 33 byte gives same for delta_Y movement
;the 44 byte gives 1 to roll wheel forward and ff to roll backward
;the 55 byte is 00 always
;the coordinate system for mouse movement follows vga graphics
;+x to right and +y down



;Logitech & Microsoft Mouse w/ SetProtocol=report
;***************************************************
;the byte order is as above except no leading 01 byte 
;11 22 33 44
;11 = mouse clicks same as above
;22 = X movement
;33 = Y movement
;44 = wheel movement


align 0x10

;the uhci mouse writes its 4 or 5 or 6 byte report to "mousereportbuf"
;for ehci we have a page aligned address 0x1004000 reserved for the mouse report
mousereportbuf times 10 db 0



;***************************************************************************
;usbShowMouseReport
;this is a usb mouse report demo 
;I wrote this to see what the mouse is doing/what bytes its giving
;just move the mouse, click buttons and scroll the wheel 
;the mouse report is displayed on the screen 
;I did not want to write a lot of code to parse the messy report descriptor
;use this to customize your mouse driver
;after observing the mouse report, go back to tatOS.config and set the 
;appropriate value for MOUSERPRTBTNINDX and reassemble tatOS

;we only display a maximum of 5 bytes of the mouse report
;most mice with 2 buttons & a wheel
;only give 4 bytes of useful information: BtnClick,dx,dy,dWheel
;the Manhatten mouse config descriptor gives wMaxPacketSize=06
;but the first byte is a fixed "01" and then come the 4 bytes of useful info
;we ignore the last byte of this report
;perhaps this mouse has circuitry to support a 4th button ??
;the Microsoft mouse wMaxPacketSize=04 which is standard


;MOUSERPRTBTNINDX is defined in tatOS.config
;to indicate the 0 based index of the button click byte in the mouse report
;if the button click byte is the first byte enter 0 (Logitech/Microsoft)
;if the button click byte is the 2nd   byte enter 1 (Manhattan)

;SetIdleDuration must be set to 00 for normal mouse reporting

;before you run this program you must init the controller and mouse
;from usbcentral

;sample mouse reports for Manhattan mouse:
;this usb mouse gives a 5 byte report, the first byte is always 01
;the buttonclickindex = 01
;LeftButtonDown   01 01 00 00 00

;AnyButtonUp      01 00 00 00 00
;RightButtonDown  01 02 00 00 00
;RightLeftButDown 01 03 00 00 00
;MiddleButtonDown 01 04 00 00 00
;AllButtonsDown   01 07 00 00 00
;remaining reports are same as below except for leading 01 bytes


;sample mouse reports for Microsoft/Logitech:
;these usb mice give a 4 byte report
;the buttonclickindex = 00
;LeftButtonDown   01 00 00 00
;AnyButtonUp      00 00 00 00
;RightButtonDown  02 00 00 00
;MiddleButtonDown 04 00 00 00
;HorizontalMovementRight 00 02 00 00
;HorizontalMovementLeft  00 FE 00 00
;VerticalMovementDown    00 00 02 00
;VerticalMovementUP      00 00 FE 00
;WheelAway               00 00 00 01
;WheelTowards            00 00 00 FF
;Consecutive reports may duplicate each other for mouse move
;and wheel events

;input:none
;return: none
showmousereportstr4:
db 'USB Show Mouse Report',NL 
db 'Move the mouse, click buttons, scroll, observe the report',NL
db 'Observe which byte identifies the button click',NL
db 'To exit, press ESCAPE',0
;*********************************************************************

usbShowMouseReport:

	call usbmouserequest

	;we want the mouse report to be persistant
	;even when not moving the mouse
	;so we do not clear the backbuffer on every paint cycle
	call backbufclear

	;program messages
	STDCALL FONT01,100,50,showmousereportstr4,0xefff,putsml 

.1:

	;must have a sleep here
	;otherwise we never get any response from checkc
	;the ps2 keyboard controller is much slower than the mouse
	mov ebx,5
	call sleep


	;test if user wants to quit
	call checkc  ;zf is set if no key pressed
	jz .2
	cmp al,ESCAPE
	jz near .done


.2:

	;box around the mouse report
	STDCALL 92,195,175,30,BLA,rectangle



%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

	;test for mouse activity 
	cmp dword [mousereportbuf],0x09090909
	jz .3  ;no mouse activity so check for keypress

	;display the raw bytes of the mouse report buf
	STDCALL 100,200,0xfeef,mousereportbuf,5,putmem

%endif

%if USBCONTROLLERTYPE == 2  ;ehci 

	;test for mouse activity 
	cmp dword [0x1004000],0x09090909
	jz .3  ;no mouse activity so check for keypress

	;display the raw bytes of the mouse report buffer
	STDCALL 100,200,0xfeef,0x1004000,5,putmem

%endif


	;reset mouse report buf to 0x09090909 & queue up a new usb mouse request
	call usbmouserequest

.3:
	call swapbuf  ;endpaint
	jmp .1


.done:

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

	;"zero" out the mousereportbuf 
	mov esi,mousereportbuf
	mov dword [esi+MOUSERPRTBTNINDX],0x09090909

%endif

%if USBCONTROLLERTYPE == 2  ;ehci 

	mov dword [0x1004000+MOUSERPRTBTNINDX],0x09090909

%endif


	;queue up a new request
	call usbmouserequest   ;registers are preserved

	ret


	


;***************************************************************************************
;usbcheckmouse

;this is your main function for user apps to check for mouse activity
;place a call to this function in your AppMainLoop after painting

;if there has been mouse activity since the previous time this function was invoked
;then a value is returned in al and a new mouse request is queued up

;this function distinguishes between the "state" of a button and "click" action.
;state means the button is currently down or up
;click action only occurs if the button was previously up and now is down or vicaversa
;state is maintainted by global dwords [LBUTTONDOWN] [RBUTTONDOWN] [MBUTTONDOWN]
;kernel code may test for button state by checking the value of these globals
;1=down, 0=up
;click action is returned in al

;for mouse movement you will note this function does not return a value in a reg
;we update global MOUSEX, MOUSEY used to draw the cursor and MOUSE_DX, MOUSE_DY
;mswindows and linux do not give a report for every mouse movement
;because this would bog down your app
;tatOS AppMainLoop requires continuous painting of the screen 
;apps may use GetMouseXY to retrieve the usb mouse position

;the return value in al will indicate a "change in state" of the button 
;when you press a button bits are set, when you release the button all bits are clear
;if you hold down a button and move the mouse the set bits do not change
;so this does not constitute a change in state
;only a change in location, so the return value in al will be 0 for this case

;wheel movement is differant than button clicks. The wheel gives 01 when rolled toward
;the screen and ff when rolled away but these bits are not cleared except by a button
;click or mouse movement so if you hold the mouse perfectly still and do not click a
;button you can continue to roll the wheel in one direction and the mouse report is
;the same as if you did not touch the mouse at all.

;note also we do not return a value for button "release" only button "down"
;note also we do not report a unique value for multiple buttons held down
;in this case the last button pressed is reported

;see tedit.s F10 function which is userland startup code before letting the app
;do its thing, here we use usbmouserequest to queue up the first mouse request.
;There after this function is responsible for queueing up new mouse requests.

;input:none

;return:
;al=Button or Wheel Change of State
;   0=no change in state of buttons or wheel
;   1=Left   button is clicked
;   2=Right  button is clicked
;   4=Middle button is clicked
;   5=wheel is rolled 'toward' (the screen)
;   6=wheel is rolled 'away'   (from the screen)



;note:
;most Microsoft or Logitech mice only give a 4 button report bb dx dy dz
;because of the peculiar report of my Manhattan mouse 
;with the leading 01 byte there is a %define which must be customized 
;for your particular mouse. see tatOS.config

;locals
oldleftmousestate   db 0   ;1=down, 0=up
oldrightmousestate  db 0
oldmiddlemousestate db 0


;MOUSEX and MOUSEY are the x,y coordinates of the mouse
;but MOUSEY is sensitive to YORIENT
;so for kernel code that only wants to deal with YORIENT=1 we introduce mousey1
;mousey1 is the y coordinate of mouse where y=0 is top of screen and +y is down
;mousey1 is set to 300 in tedit.s every time a user app is started up
;this variable is introduced for the benefit of dropdown.s
mousey1             dd 0   

msrepstr1 db 'usbcheckmouse: process mouse report',0
msrepstr2 db 'usbcheckmouse: no mouse report',0
;***********************************************************************

usbcheckmouse:

	;note this function does not preserve registers
	;tom we should probably fix this !!!!!!!


	;did we get a mouse report ?

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	cmp dword [mousereportbuf],0x09090909
%endif

%if USBCONTROLLERTYPE == 2  ;ehci 
	cmp dword [0x1004000],0x09090909
%endif

	jnz .ProcessReport

	;no mouse button or wheel activity, no movement
%if VERBOSEDUMP 
	STDCALL msrepstr2,dumpstr  ;for debug
%endif

	mov ax,0
	mov dl,0
	mov dword [MOUSE_DX],0
	mov dword [MOUSE_DY],0

	;MOUSEX and MOUSEY are unchanged
	jmp near .done


.ProcessReport:

	;if we got here we have a mouse report

%if VERBOSEDUMP 
	STDCALL msrepstr1,dumpstr  ;for debug
%endif

	;copy the 4 byte mouse report to eax 
	;skip leading 01 byte if Manhattan	

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci
	mov esi,mousereportbuf
%endif

%if USBCONTROLLERTYPE == 2  ;ehci 
	mov esi,0x1004000
%endif

	;esi must be preserved 

	mov eax,[esi+MOUSERPRTBTNINDX]  
	;now eax contains the 4 byte mouse report in reverse


	;Process the mouse report 
	;in eax the bytes are reversed because of Intels little endian
	;bits7:0   contain button down information
	;bits15:8  contain dx mouse movement
	;bits23:16 contain dy mouse movement
	;bits31:24 contain wheel movement


	;save MOUSEX and MOUSE_DX 
	;dx is typically 02 for right movement or fe for left movement
	mov ebx,eax  
	shr ebx,8
	movsx ecx,bl           ;must sign extend, dx may be negative
	mov [MOUSE_DX],ecx     ;save dx
	add dword [MOUSEX], ecx


	;save MOUSEY and MOUSE_DY and mousey1
	mov ebx,eax
	shr ebx,16
	movsx ecx,bl       ;ecx=dy top down
	add [mousey1],ecx  ;update mousey1
	cmp dword [YORIENT],-1
	jnz .notYup
	neg ecx            ;ecx=dy bottom up
.notYup:
	mov [MOUSE_DY],ecx
	add dword [MOUSEY], ecx


	;clamp MOUSEX to 0->799
	cmp dword [MOUSEX],799
	jg .clampXhi
	cmp dword [MOUSEX],0
	jge .doneX
	mov dword [MOUSEX],0
	jmp .doneX
.clampXhi:
	mov dword [MOUSEX],799
.doneX:

	;clamp MOUSEY to 0->599
	cmp dword [MOUSEY],599
	jg .clampYhi
	cmp dword [MOUSEY],0
	jge .doneY
	;cant have negative mouse coordinates
	mov dword [MOUSEY],0
	jmp .doneY
.clampYhi:
	;cant have mouse coordinate greater than 599
	mov dword [MOUSEY],599
.doneY:

	;clamp mousey1 to 0->599
	cmp dword [mousey1],599
	jg .clampY1hi
	cmp dword [mousey1],0
	jge .doneY1
	mov dword [mousey1],0
	jmp .doneY1
.clampY1hi:
	mov dword [mousey1],599
.doneY1:




	;"zero" out our mouse report buffer to something which the mouse
	;can not possibly give as a valid report
	mov dword [esi],0x09090909

	;now that we have a new mouse report buffer
	;we must queue up a new request
	call usbmouserequest   ;registers are preserved



	;eax contains the current up/dn/roll state of the buttons and wheel


	;set globals to indicate the current "state" of the buttons
	;1=down, 0=up
	mov dword [LBUTTONDOWN],0  
	mov dword [RBUTTONDOWN],0
	mov dword [MBUTTONDOWN],0
	bt eax,0
	jnc .doneLbut
	mov dword [LBUTTONDOWN],1
.doneLbut:
	bt eax,1
	jnc .doneRbut
	mov dword [RBUTTONDOWN],1
.doneRbut:
	bt eax,2
	jnc .doneMbut
	mov dword [MBUTTONDOWN],1
.doneMbut:
	



	;test for LEFT button click or release
	;a button click means the button is currently down but previously was up
	mov bh,[oldleftmousestate]
	mov bl,al
	and bl,1  ;mask off bit0
	cmp bx,1
	jz .HaveLeftButtonClick
	cmp bx,0x100
	jz .HaveLeftButtonRelease
	;if we got here there is no change in the button state
	jmp .doneLeftButton
.HaveLeftButtonClick:
	mov al,1   ;return left button is clicked
	mov byte [oldleftmousestate],1
	jmp .done
.HaveLeftButtonRelease:
	mov byte [oldleftmousestate],0
.doneLeftButton:



	;test for RIGHT button click or release
	mov bh,[oldrightmousestate]
	mov bl,al
	shr bl,1  ;move the right button bit1 to bit0
	and bl,1  ;mask off bit0
	cmp bx,1
	jz .HaveRightButtonClick
	cmp bx,0x100
	jz .HaveRightButtonRelease
	;if we got here there is no change in the button state
	jmp .doneRightButton
.HaveRightButtonClick:
	mov al,2   ;return right button is clicked
	mov byte [oldrightmousestate],1
	jmp .done
.HaveRightButtonRelease:
	mov byte [oldrightmousestate],0
.doneRightButton:



	;test for MIDDLE button click or release
	mov bh,[oldmiddlemousestate]
	mov bl,al
	shr bl,2  ;move the middle button bit2 to bit0
	and bl,1  ;mask off bit0
	cmp bx,1
	jz .HavemiddleButtonClick
	cmp bx,0x100
	jz .HavemiddleButtonRelease
	;if we got here there is no change in the button state
	jmp .donemiddleButton
.HavemiddleButtonClick:
	mov al,4   ;return middle button is clicked
	mov byte [oldmiddlemousestate],1
	jmp .done
.HavemiddleButtonRelease:
	mov byte [oldmiddlemousestate],0
.donemiddleButton:



	;if we got here we may have a wheel event
	;01 wheel toward screen
	;ff wheel away from screen
	mov ebx,eax
	shr ebx,24
	and ebx,0xff
	cmp bl,0
	jz .doneWheel
	cmp bl,1
	jz .Toward
	cmp bl,0xff
	jz .Away
	jmp .doneWheel  ;we should never execute this
.Toward:
	mov al,5
	jmp .done
.Away:
	mov al,6
	jmp .done
.doneWheel:


	;if we got here we have no button clicks and no wheel movement
	mov al,0

.done:

	;it is a mistake to call usbmouserequest here
	;because we may get here after checking the mousereportbuf and
	;the mousereportbuf is unchanged. calling usbmouserequest here
	;will result in the mouse seeming sluggish
	;with double Lclicks required

	ret




;*********************************************************
;usbmouserequest
;prepares a mouse interrupt TD and attaches to QH to start
;input:none
;return:none
;*********************************************************

usbmouserequest:

%if ( USBCONTROLLERTYPE == 0 || USBCONTROLLERTYPE == 1 )  ;uhci

	;zero out the first 4 bytes of the mousereportbuf 
	;to something the mouse can not possibly give
	mov dword [mousereportbuf],0x09090909

	;build a new TD
	call uhci_prepareInterruptTD   ;registers are preserved

	;attach TD to second dword of queue head to begin usb transaction
	mov dword [MOUSE_UHCI_INTERRUPT_QH+4],interruptTD  

%endif


%if USBCONTROLLERTYPE == 2  ;ehci 

	;ehci mouse report buffer is 0x1004000 page aligned
	mov dword [0x1004000],0x09090909

	call generate_mouse_TD  ;TD is written to 0x1003500, registers are preserved

	;attach TD to 5th dword of MOUSE_INTERRUPT_QH to begin transaction
	mov dword [MOUSE_INTERRUPT_QH_NEXT_TD_PTR], 0x1003500

%endif

	ret



;*******************************************
;getmousexy
;returns the mouse cursor x,y location
;input:none
;return: eax=mouseX,  ebx=mouseY 
;        esi=mouseDX, edi=mouseDX
;******************************************

getmousexy:
	mov eax,[MOUSEX]
	mov ebx,[MOUSEY]
	mov esi,[MOUSE_DX]
	mov edi,[MOUSE_DY]
	ret


;************************************************
;getmousebutton
;returns the state of a usb mouse button up/down
;input
;returns value of LBUTTONDOWN if ebx=0
;returns value of MBUTTONDOWN if ebx=1
;returns value of RBUTTONDOWN if ebx=2
;return
;eax=1 for down and 0 for up else 0xff on error
;************************************************
	
getmousebutton:

	cmp ebx,0
	jz .left
	cmp ebx,1
	jz .middle
	cmp ebx,2
	jz .right

	;invalid value in ebx
	mov eax,0xff
	jmp .done

.left:
	mov dword eax,[LBUTTONDOWN]
	jmp .done
.middle:
	mov dword eax,[MBUTTONDOWN]
	jmp .done
.right:
	mov dword eax,[RBUTTONDOWN]

.done:
	ret


