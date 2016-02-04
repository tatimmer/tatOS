;tatOS/tlib/calc.s

;***************************************************************************
;calculator
;a reverse polish notation calculator
;uses a commandline approach
;displays values as hex,dec,or bin
;supports add,sub,mul,div,imul,idiv,shl,shr,and,or,xor,xchg,not,neg,del
;dword integers only no fpu
;this version uses 2 local dwords value1,value2
;to hold user entries and do operations

;howto
;to enter a constant (value1) just type the constant then enter
;repeat to enter a second constant (value2)
;to perform (value1 + value2) type the string "add" with no quotes then enter 
;this puts the sum as value1 and value2 is cleared out
;to enter hex constant use 0x prefix (i.e. 0xff23)
;to enter binary constant use b suffix (i.e. 10111b)
;invalid entries are silently ignored

;input:none

;Nov 2009
;this program was originally developed on tatOS and assembled 
;with ttasm but I moved it to tlib with access by the shell
;because I was using it often (and dont have multitasking)
;***************************************************************************


calculator:


	;either 0,1,2
	mov dword [stacksize],0 

	;0=unsigned, 0xffffffff=signed
	mov dword [decsign],0 


	;clear the symbtable memory 
	call symtableclear


	;load the "calc" symbol table
	push rpnSymbolTable
	push rpnEndSymbolTable
	call symtableload


	;after I got done painting I decided everything was moved
	;too far right, so instead of changing all the x values
	;we introduce the global XOFFSET 
	mov dword [XOFFSET],-50 


mainloop:

	;paint
	call backbufclear 



	;title of program  "RPN Calculator"
	STDCALL FONT01,100,40,calcstr6,0xefff,puts


	;horiz line under "RPN Calculator" title
	mov ebx,100
	mov ecx,55
	mov edx,140
	mov esi,BLA
	call hline


	;2 long vertical lines at far left and far right end of the table
	mov ebx,100
	mov ecx,100
	mov edx,180
	mov esi,BLA
	call vline

	mov ebx,780
	mov ecx,100
	mov edx,180
	mov esi,BLA
	call vline


	;3 shorter vertical lines in the middle of the table
	mov ebx,170
	mov ecx,100
	mov edx,140
	mov esi,BLA
	call vline

	mov ebx,300
	mov ecx,100
	mov edx,140
	mov esi,BLA
	call vline

	mov ebx,450
	mov ecx,100
	mov edx,140
	mov esi,BLA
	call vline



	;4 long horiz lines
	mov ebx,100
	mov ecx,100
	mov edx,680
	mov esi,BLA
	call hline

	mov ebx,100
	mov ecx,140
	mov edx,680
	mov esi,BLA
	call hline

	mov ebx,100
	mov ecx,240
	mov edx,680
	mov esi,BLA
	call hline

	mov ebx,100
	mov ecx,280
	mov edx,680
	mov esi,BLA
	call hline




	;display the column titles: "stack hex dec bin"
	STDCALL FONT01,180,110,calcstr2,0xf0ff,puts
	STDCALL FONT01,310,110,calcstr3,0xf0ff,puts
	STDCALL FONT01,460,110,calcstr4,0xf0ff,puts



	;show decimal as S=signed or US=unsigned
	cmp dword [decsign],0 
	jz ShowUS
	STDCALL FONT01,360,110,calcstr10,0xf4ff,puts
	jmp displayInput
ShowUS:
	STDCALL FONT01,360,110,calcstr11,0xf4ff,puts



displayInput:
	STDCALL FONT01,110,260,calcstr5,0xefff,puts


	;instructions
	STDCALL FONT01,100,330,Instructions,0xefff,putsml


	;display the '1' and '2'
	STDCALL FONT01,130,170,calcstr8,0xf3ff,puts
	STDCALL FONT01,130,210,calcstr9,0xf3ff,puts



	;display item 1
	cmp dword [stacksize],1 
	jb near GetUserInput
	mov eax,[value1]
	STDCALL 180,170,0xefff,0,puteax
	STDCALL 460,170,0xefff,puteaxbin
	cmp dword [decsign],0 
	jz ShowDec1Unsigned
	STDCALL 310,170,0xefff,1,puteaxdec
	jmp DisplayItem2
ShowDec1Unsigned:
	STDCALL 310,170,0xefff,0,puteaxdec



DisplayItem2:
	cmp dword  [stacksize],2 
	jb GetUserInput
	mov eax,[value2]
	STDCALL 180,210,0xefff,0,puteax
	STDCALL 460,210,0xefff,puteaxbin
	cmp dword [decsign],0 
	jz ShowDec2Unsigned
	STDCALL 310,210,0xefff,1,puteaxdec
	jmp GetUserInput
ShowDec2Unsigned:
	STDCALL 310,210,0xefff,0,puteaxdec





GetUserInput:

	;get string input from user
	;user may enter a number followed by return
	;this will be placed on top of the stack position 1
	;and whats on the stack is pushed down
	;the number may be hex or dec or bin
	;or user may type an operation like add,sub,mul,div,not,xor,neg...
	;e.g. 'add' takes the top two numbers off the stack
	;and adds then together and places the result on the stack
	;hit ESCAPE to quit
	mov ebx,200
	mov eax,260
	mov ecx,20
	mov edi,getsbuf
	mov edx,0x00f3ffef
	call gets
	;ESCAPE clears ZF
	jnz MainDone



	;is it in symbol table ?
	mov esi,getsbuf
	call symlookup
	;returns eax=DataClass, ebx=Symbol, eax=0 if not in table
	;our Symbols are doAdd, doSub, doMul...
	cmp eax,0
	jz TryStringConstant


	;its an operation in our symbol table
	call ebx
	jmp ClearEdit



TryStringConstant:
	mov esi,getsbuf
	call str2eax
	jnz ClearEdit
	;zf is set on successful conversion


	cmp dword [stacksize],0 
	jz SetValue1
	cmp dword [stacksize],1 
	jz SetValue2
	jmp ClearEdit
	

SetValue1:
	mov [value1],eax
	inc dword [stacksize] 
	jmp ClearEdit


SetValue2:
	mov [value2],eax
	inc dword [stacksize] 
	jmp ClearEdit


ClearEdit:
	;clear the gets edit control for next input
	mov edi,getsbuf
	mov byte [edi],0 



MainSwap:
	call [SWAPBUF]
	jmp mainloop



MainDone:
	mov dword [XOFFSET],0  ;reset
	ret

;***************END Main ************************************




;note all these operations work on dwords

;1+2
doAdd:
	cmp dword [stacksize],2 
	jnz doneAdd
	mov eax,[value2]
	add [value1],eax
	mov dword [stacksize],1 
doneAdd:
	ret


;1-2
doSub:
	cmp dword [stacksize],2 
	jnz doneSub
	mov eax,[value2]
	sub [value1],eax
	mov dword [stacksize],1 
doneSub:
	ret


;1*2
doMul:
	cmp dword [stacksize],2 
	jnz doneMul
	mov eax,[value1]
	mov ebx,[value2]
	mul ebx
	mov [value1],eax
	mov dword [stacksize],1 
doneMul:
	ret


;1*2
doIMul:
	cmp dword [stacksize],2 
	jnz doneIMul
	mov eax,[value1]
	mov ebx,[value2]
	imul ebx
	mov [value1],eax
	mov dword [stacksize],1 
doneIMul:
	ret



;1/2
doDiv:
	cmp dword [stacksize],2 
	jnz doneDiv
	xor edx,edx
	mov eax,[value1]
	mov ebx,[value2]
	div ebx
	mov [value1],eax
	mov [value2],edx
doneDiv:
	ret


;1/2
doIDiv:
	cmp dword [stacksize],2 
	jnz doneIDiv
	mov eax,[value1]
	mov ebx,[value2]
	cdq
	idiv ebx
	mov [value1],eax
	mov [value2],edx
doneIDiv:
	ret



;not(1)
doNot:
	cmp dword [stacksize],1 
	jb doneNot
	not dword [value1] 
doneNot:
	ret



;neg(1)
doNeg:
	cmp dword [stacksize],1 
	jb doneNeg
	neg dword [value1] 
doneNeg:
	ret



;1&2  (clear bit)
doAnd:
	cmp dword [stacksize],2 
	jnz doneOr
	mov eax,[value1]
	mov ebx,[value2]
	;and eax,ebx
	db 0x21,0xd8
	mov [value1],eax
	mov dword [stacksize],1 
doneAnd:
	ret



;1|2 (set bit)
doOr:
	cmp dword [stacksize],2 
	jnz doneOr
	mov eax,[value1]
	mov ebx,[value2]
	;or eax,ebx
	db 9,0xd8
	mov [value1],eax
	mov dword [stacksize],1 
doneOr:
	ret



;1^2  (flip bit)
doXor:
	cmp dword [stacksize],2 
	jnz doneXor
	mov eax,[value1]
	mov ebx,[value2]
	;xor eax,ebx
	db 0x31,0xd8
	mov [value1],eax
	mov dword [stacksize],1 
doneXor:
	ret



;1<<2
doShl:
	cmp dword [stacksize],2 
	jnz doneShl
	mov eax,[value1]
	mov ecx,[value2]
	;shl eax,cl
	db 0xd3,0xe0
	mov [value1],eax
	mov dword [stacksize],1 
doneShl:
	ret



;1>>2
doShr:
	cmp dword [stacksize],2 
	jnz doneShr
	mov eax,[value1]
	mov ecx,[value2]
	;shr eax,cl
	db 0xd3,0xe8
	mov [value1],eax
	mov dword [stacksize],1 
doneShr:
	ret



;arithmetic shift right
;same as shr except it sign extends
doSar:
	cmp dword [stacksize],2 
	jnz doneSar
	mov eax,[value1]
	mov ecx,[value2]
	;sar eax,cl
	db 0xd3,0xf8
	mov [value1],eax
	mov dword [stacksize],1 
doneSar:
	ret



;delete value1 and move value2 up 
doDelete:
	cmp dword [stacksize],1 
	jz DeleteValue1
	cmp dword [stacksize],2 
	jz MoveValue2Up
	jmp doneDelete
DeleteValue1:
	mov dword [stacksize],0
	jmp doneDelete
MoveValue2Up:
	mov eax,[value2]
	mov [value1],eax
	mov dword [stacksize],1 
doneDelete:
	ret



;exchange the top two items on the stack
doXchg:
	cmp dword [stacksize],2 
	jnz .done
	mov eax,[value1]
	mov ebx,[value2]
	mov [value1],ebx
	mov [value2],eax
.done:
	ret


;change the sign of decimal representation
doSign:
	not dword [decsign] 
	ret



;set a single bit in value1
;value2 is an unsigned int from (0-31) which identifies which bit to set
doBitSet:
	cmp dword [stacksize],2 
	jnz .done
	mov ecx,[value2]  ;which bit to shift
	cmp ecx,31
	ja .done  ;error-value2 is > 31
	mov eax,1
	shl eax,cl
	mov ebx,[value1]
	or ebx,eax
	mov [value1],ebx
	mov dword [stacksize],1 
.done:
	ret




;*************
;  DATA
;*************

rpnSymbolTable:

db 'add',0    ;command string to enter at the prompt
dd doAdd,1    ;function to execute 
db 'sub',0
dd doSub,1
db 'mul',0
dd doMul,1
db 'div',0
dd doDiv,1
db 'idiv',0
dd doIDiv,1
db 'imul',0
dd doIMul,1


db 'and',0
dd doAnd,1
db 'or',0
dd doOr,1
db 'xor',0
dd doXor,1
db 'neg',0
dd doNeg,1
db 'not',0
dd doNot,1

db 'shl',0
dd doShl,1
db 'shr',0
dd doShr,1
db 'sar',0
dd doSar,1

db 'del',0
dd doDelete,1
db 'xchg',0
dd doXchg,1
db 'sign',0
dd doSign,1
db 'bitset',0
dd doBitSet,1

rpnEndSymbolTable db 'THE-END',0
;end of symbol table




stacksize dd 0
value1 dd 0
value2 dd 0
;0=unsigned, 0xffffffff=signed
decsign dd 0

getsbuf times 30 db 0
buf times 20 db 0

calcstr2 db 'HEX',0
calcstr3 db 'DEC',0
calcstr4 db 'BIN',0
calcstr5 db 'input:',0
calcstr6 db 'RPN Calculator',0
calcstr8 db '1',0
calcstr9 db '2',0
calcstr10 db '(s)',0
calcstr11 db '(us)',0



Instructions:
db 'Enter a hex constant with 0x prefix, binary constant with b suffix',NL
db NL
db 'Supported [2] number operators:',0xa
db 'add (1+2), sub (1-2), mul (1*2), div (1/2, quotient=1, remainder=2)',0xa
db 'imul (1*2), idiv (1/2)',0xa
db 'shl (1<<2), shr (1>>2), sar (sign extend)',0xa 
db 'and (1&2), or (1|2), xor (1^2), xchg (swap 1,2)',0xa
db 'bitset (value1 | 1<<value2)' ,0xa
db 0xa
db 'Supported [1] number operators:',0xa
db 'not (1), neg (1), del (1)',0xa
db 0xa
db 'Toggle the DECimal from unsigned (us) to signed (s) using "sign"',0xa
db NL
db 'example to perform 2+3: 2 enter 3 enter add enter',0





