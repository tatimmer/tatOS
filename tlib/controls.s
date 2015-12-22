;tatOS/tlib/controls.s


;functions to collect user input

;comprompt
;pickoption

;see also:
;gets.s  
;list.s
;dropdown.s


;admittedly these controls are lacking in artwork, style, functionality, you name it
;I tend to use comprompt to get user input and not spend much time on the others
;the choice of controls is lacking (no button ? radio, checkbox ...)
;the coding needs more functionality (position on screen, optional use of mouse or key...)
;muliple instances are not possible for some of these because of the use of globals
;some capture the keyboard and mouse and will not yield until destroyed

;in general each control has its own paint loop
;each control will perserve the calling programs screen with backbufsave & backbufrestore





;****************************************************************************
;comprompt
;command line with prompt string
;this is your general function to call for getting user input via keyboard

;the string entered by the user is stored in the destination buffer 0 terminated
;make the destination buffer at least 100 bytes to store 80 characters

;input
;push address of 0 terminated prompt string    [ebp+12]
;push address of destination buffer            [ebp+8]

;returns ZF set on success, clear on error (user hit ESC key)

;this function draws to the bottom 2 lines on the screen
;the top line displays a prompt string
;the next line displays an 80char gets editbox
;use this function to get a string of user input
;the user input may be a single decimal or hex number
;or a single ascii string
;or a series of comma seperated values
;see function splitstring() in string.s to handle comma seperated values
;colors are hard coded
;prompt: yellow text on black 
;getsbox: black text on yellow with red caret
;*******************************************************************************

comprompt:

	push ebp
	mov ebp,esp

	push dword [YORIENT]  ;save calling programs YORIENTation
	mov dword [YORIENT],1 ;comprompt will always be at bottom of screen

	push ebx
	push ecx
	push edx
	push esi
	

	call backbufsave

	;background for prompt string
	STDCALL 0,570,800,15,BLA,fillrect


	;we do not want "gets" to display whats in the destination buffer
	;this presents a blank edit box with every comprompt invocation
	mov edi,[ebp+8]
	mov byte [edi],0


	;prompt string
	mov esi,[ebp+12]
	STDCALL FONT01,0,570,esi,0xfdef,puts  


	;display the gets editbox along the bottom of screen
	;red caret, black text on yellow
	;edi=buffer to store string
	mov ebx,0       ;x
	mov eax,585     ;y
	mov ecx,80      ;maxnumchars
	mov edi,[ebp+8] ;destination buffer
	mov edx,LRE     ;colors 00ccbbtt
	shl edx,16      ;caret
	mov dh,YEL      ;background
	mov dl,BLA      ;text
	call gets       ;gets has its own paint loop
	jnz .done    
	;zf is clear if user escaped


	
.done:

	call backbufrestore
	call swapbuf

	pop esi
	pop edx
	pop ecx
	pop ebx
	pop dword [YORIENT]  ;restore calling programs YORIENTation

	pop ebp
	retn 8
	




;*********************************************************
;pickoption
;this routine puts up a dialog box with a list of options
;a "gets" edit control is provided to collect user input
;this option box is drawn over top of calling app 
;upper left corner of the screen. 
;program execution is blocked until user hits ENTER or ESCAPE 

;input
;push address of Title string       [ebp+20]
;push address of Options string     [ebp+16]
;push width of dialog box           [ebp+12]
;push height of dialog box          [ebp+8]

;return:
;on ENTER  eax=numerical value user entered starting with 0
;on ESCAPE eax=0xffffffff

;the Options string must be a 0 terminated multi-line string
;each line ends with NL except the last ends with 0
;the option numbers should begin with 0 
;suggested format for multiline string:
;db '0=option1 text',NL
;db '1=option2 text',NL
;db '2=option3 text',NL
;db '3=option4 text',0

;the gets edit control is drawn 15 pixels from the bottom
;the multiline string is drawn starting after the title string
;calling program should pick a "height" value such that gets
;edit control does not over write last line of multiline string

;the colors used for this control are
;background = light gray 0xf6
;text = black 0xef
;these are the same colors as menu.s

;locals
pickoptionstor times 50 db 0
pickstr1:
db 'pickoption return value',0
;**********************************************************

pickoption:

	push ebp
	mov ebp,esp

	push dword [YORIENT]
	mov dword [YORIENT],1

	;zero out the buffer to store option string
	mov edi,pickoptionstor
	mov ecx,10
	mov al,0
	call memset
		
	;background rectangle (white with black text)
	push 0
	push 0
	push dword [ebp+12] 
	push dword [ebp+8] 
	push 0xf6      ;gray background same as menu.s
	call fillrect


	;display the title string
	push FONT02
	push 0
	push 2
	push dword [ebp+20] 
	push 0xefff
	call puts


	;draw a line under the title string
	mov ebx,0         ;x
	mov ecx,17        ;y
	mov edx,[ebp+12]  ;length
	mov esi,BLA       ;color
	call hline


	;display the multiline string of options
	push FONT02
	push 0              ;x
	push 25             ;y
	push dword [ebp+16] ;string
	push 0xefff
	call putsml


	;display a > just left of the edit control
	mov ebx,FONT01  ;font
	mov ecx,62      ;ascii 62 is >
	mov edx,0xeff6  ;colors
	mov esi,0       ;xloc
	mov edi,[ebp+8] ;height of dialog box
	sub edi,15      ;yloc 15 pixels up from bottom
	call putc


	;display the edit box at top left
	mov ebx,15              ;xloc
	mov eax,edi             ;yloc
	mov ecx,4               ;maxnumchars 2b entered
	mov edi,pickoptionstor  ;address to store entry
	mov edx,0xf5f6ef        ;colors ccbbtt
	call gets               ;calls swapbuf to make things show up
	jnz .escape



	;we got here after user hit ENTER

	;convert user entry string to number in eax
	mov esi,pickoptionstor
	call str2eax
	jmp .done


.escape:
	mov eax,0xffffffff
.done:
	STDCALL pickstr1,0,dumpeax
	pop dword [YORIENT]
	pop ebp
	retn 16



 



