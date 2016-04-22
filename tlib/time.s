;tatOS/tlib/time.s


;time related functions:

;sleep, clock
;checktimer, timerstart, timerstop, timerinit


;see /boot/pic.s 
;see irq0 in /boot/gdtidttss.s
;these functions use the pit 
;which is initialized for about 1000 hits per second


;***********************************************
;sleep
;makes use of pit counter value @ PITCOUNTER
;to pause execution of time sensitive graphics
;this is a blocking function

;input
;ebx=amount of milliseconds to pause

;set ebx=1000 to pause for one second
;you can make a simple clock just by displaying 
;a number then sleep(1000) then increment and loop
;see interrupts.s which programs the PIT to
;fire appx once every millisecond
;see also pic.s which must enable the PIT interrupt

;warning: dont call this function while interrupts
;are disabled (cli). It will hang your computer !
;because the value of PITCOUNTER never changes.
;also this function will block keyboard or mouse
;************************************************

sleep:

	;interrupts MUST be enabled (sti)
	;or we will hang the computer
	sti            
	push eax

	mov eax,[PITCOUNTER] ;get value of pit counter
	add eax,ebx          ;eax=value of pit counter + amount of delay

.1:	mov ebx,[PITCOUNTER] ;get value of pit counter again
	cmp eax,ebx          ;are we there yet ?
	ja .1                ;no-keep checking

	pop eax
	ret





;********************************************************************
;checktimer
;this is a non-blocking alternative to sleep
;use this function to implement a clock
;or some other time sensitive action
;when you also need to be checking for keyboard or mouse activity
;the kernel will call a user defined function (callback)
;at regular time intervals you specify

;To use this function:
;1) call timerinit at program startup to set the callbackfunction
;2) call checktimer right after checkc and usbcheckmouse in your app main loop
;3) call timerstart or timerstop usually in response to keyboard action

;input:none
;return:none
;******************************************

checktimer:
	
	;first make sure we have a valid callback function
	cmp dword [TIMERCALLBACK],0
	jz .done


	;check for stop which means the user does not want a callback yet
	cmp dword [TIMERSTART],0
	jz .done
	

	;check if value of PITCOUNTER has exceeded CHECKTIMEELAPSED
	mov eax,[PITCOUNTER] 
	cmp eax,[TIMERELAPSED]          
	jb .done


	;call user defined function
	call [TIMERCALLBACK]


	;reset PITCOUNTER to 0 for next time around app-main-loop
	mov dword [PITCOUNTER],0


.done:
	ret 



timerstart:
	mov dword [TIMERSTART],1
	ret
	
timerstop:
	mov dword [TIMERSTART],0
	ret



;******************************************************************
;timerinit
;init some values used by checktimer
;input:
;ebx=time interval between function calls from kernel, milliseconds
;    to receive a callback function once every second set ebx=1000
;ecx=name of user defined callback function
;    must be within users page !
;return: CF is set if invalid function call else clear if valid
;******************************************************************

timerinit:

	mov [TIMERELAPSED],ebx
	mov [TIMERCALLBACK],ecx
	mov dword [TIMERSTART],0

	;check for valid callback function
	push ecx
	call ValidateUserAddress  ;CF is set on invalid address
	jnc .done

.error:
	mov dword [TIMERCALLBACK],0  ;this will not be called by kernel
.done:
	ret






;********************************************************
;clock
;function returns a time value in milliseconds
;to determine elapsed time within your program
;call this function twice and subtract the two values
;input:none
;return:eax=time in milliseconds
;********************************************************

clock:
	mov eax,[PITCOUNTER]
	ret


