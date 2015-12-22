;tatos/tlib/font02.inc

;********************************************************
;font02
;this is a 8x11 small ascii bitmap font
;each bitmap char is 8 pixels wide, 11 pixels hi
;intended for menus or small labels
;since this is not as easy to read as our font01
;most of the strokes are only 1 pixel thick 
;based on a courier font

;the origin of each character bitmap is the upper left
;the bits are 0=background, 1=textcolor

;all chars have the bottom 2 rows as 0 except for the tail letters y,j,g,q,p
;the bitmap only uses bits[6:0] in each row
;bit7 in every row is 0 to serve as space between letters
;see functions putc02 and puts02 which display this font
;*****************************************************************



font02table:

;    0x20     0x21       0x22        0x23     0x24
dd Space02, Exclaim02, DblQuote02, Pound02, Dollar02,

;    0x25     0x26    0x27      0x28        0x29
dd Percnt02, Amper02, Squote02, Lparan02, Rparan02,

;   0x2a      0x2b   0x2c    0x2d    0x2e       0x2f
dd Aster02, Plus02, Comma02, Dash02, Period02, Fslash02

;   0x30    0x31   0x32   0x33     0x34    0x35    0x36
dd Zero02, One02, Two02, Three02, Four02, Five02, Six02

;  0x37       0x38    0x39   0x3a     0x3b    0x3c
dd Seven02, Eight02, Nine02, Colon02, Semi02, Larrow02

;   0x3d    0x3e      0x3f      0x40  
dd Equal02, Rarrow02, Quest02, At02,

;  0x41  0x42  0x43  0x44  0x45  0x46  0x47  0x48  0x49
dd A02,  B02,  C02,  D02,  E02,  F02,  G02,  H02,  I02

;  0x4a  0x4b  0x4c  0x4d  0x4e  0x4f  0x50  0x51  0x52
dd J02,  K02,  L02,  M02,  N02,  O02,  P02,  Q02,  R02

;  0x53  0x54  0x55  0x56  0x57  0x58  0x59  0x5a
dd S02,  T02,  U02,  V02,  W02,  X02,  Y02,  Z02
          
;  0x5b      0x5c      0x5d      0x5e     0x5f      0x60
dd Lbrkt02, Bslash02, Rbrkt02, Caret02, Uscore02, Btick02

;  0x61  0x62  0x63  0x64  0x65  0x66  0x67  0x68  0x69
dd a02,  b02,  c02,  d02,  e02,  f02,  g02,  h02,  i02

;0x6a    0x6b  0x6c  0x6d  0x6e  0x6f  0x70  0x71  0x72
dd j02,  k02,  l02,  m02,  n02,  o02,  p02,  q02,  r02

;0x73   0x74  0x75  0x76  0x77  0x78  0x79  0x7a
dd s02, t02,  u02,  v02,  w02,  x02,  y02,  z02

;0x7b         0x7c     0x7d       0x7e
dd Lbrace02,  Pipe02,  Rbrace02,  Tilde02

;not displayable ascii
dd box02


;********************************************************


;0x20
Space02:
db 0   
db 0   
db 0   
db 0   
db 0   
db 0   
db 0   
db 0   
db 0   
db 0   
db 0   


;0x21
Exclaim02:
db 1000b
db 1000b
db 1000b
db 1000b
db 1000b
db 1000b
db 1000b
db 0
db 1000b
db 0   
db 0   


;0x22
DblQuote02:
db 10100b
db 10100b
db 10100b
db 0
db 0
db 0
db 0
db 0
db 0
db 0   
db 0   


;0x23
Pound02:
db 0001010b
db 0001010b
db 0111111b
db 0010100b
db 0010100b
db 0010100b
db 1111110b
db 0101000b
db 0101000b
db 0   
db 0   

 
;0x24
Dollar02:
db 0001000b
db 0011100b
db 0100010b
db 0100000b
db 0011100b
db 0000010b
db 0100010b
db 0011100b
db 0001000b
db 0   
db 0   


; 0x25
Percnt02:
db 0100000b
db 1010001b
db 0100010b
db 0000100b
db 0001000b
db 0010000b
db 0100010b
db 1000101b
db 0000010b
db 0   
db 0   


;0x26
Amper02:
db 0011000b
db 0100000b
db 0100000b
db 0010000b
db 0110000b
db 1001001b
db 1001010b
db 1000100b
db 0111011b
db 0   
db 0   


;0x27
Squote02:
db 0001000b
db 0001000b
db 0001000b
db 0
db 0
db 0
db 0
db 0
db 0
db 0   
db 0   


;0x28
Lparan02:
db 0001000b
db 0010000b
db 0010000b
db 0100000b
db 0100000b
db 0100000b
db 0010000b
db 0010000b
db 0001000b
db 0   
db 0   


;0x29
Rparan02:
db 0100000b
db 0010000b
db 0010000b
db 0001000b
db 0001000b
db 0001000b
db 0010000b
db 0010000b
db 0100000b
db 0   
db 0   


;0x2a
Aster02:
db 0
db 0
db 0110110b
db 0011100b
db 1111111b
db 0011100b
db 0110110b
db 0
db 0
db 0   
db 0   


;0x2b
Plus02:
db 0
db 0001000b
db 0001000b
db 0001000b
db 1111111b
db 0001000b
db 0001000b
db 0001000b
db 0
db 0   
db 0   



;0x2c
Comma02:
db 0
db 0
db 0
db 0
db 0
db 0
db 0
db 0001000b
db 0010000b
db 0   
db 0   


;0x2d
Dash02:
db 0
db 0
db 0
db 0
db 1111111b
db 0
db 0
db 0
db 0
db 0   
db 0   


;0x2e
Period02:
db 0
db 0
db 0
db 0
db 0
db 0
db 0
db 0
db 0001000b
db 0   
db 0   


;0x2f
Fslash02:
db 0
db 0
db 0000001b
db 0000010b
db 0000100b
db 0001000b
db 0010000b
db 0100000b
db 1000000b
db 0   
db 0   


;0x30
Zero02:
db 0011100b
db 0100010b
db 0100010b
db 0100010b
db 0100010b
db 0100010b
db 0100010b
db 0100010b
db 0011100b
db 0   
db 0   


;0x31
One02:
db 0001000b
db 0111000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0111110b
db 0   
db 0   


;0x32
Two02:
db 0011100b
db 0100010b
db 0000010b
db 0000010b
db 0000100b
db 0001000b
db 0010000b
db 0100000b
db 0111110b
db 0   
db 0   


;0x33
Three02:
db 0011100b
db 0100010b
db 0000010b
db 0000010b
db 0001100b
db 0000010b
db 0000010b
db 0100010b
db 0011100b
db 0   
db 0   


;0x34
Four02:
db 0000100b
db 0001100b
db 0001100b
db 0010100b
db 0010100b
db 0100100b
db 0111110b
db 0000100b
db 0001110b
db 0   
db 0   


;0x35
Five02:
db 0111110b
db 0100000b
db 0100000b
db 0100000b
db 0111100b
db 0000010b
db 0000010b
db 0000010b
db 0011100b
db 0   
db 0   


;0x36
Six02:
db 0001100b
db 0010000b
db 0100000b
db 0100000b
db 0111100b
db 0100010b
db 0100010b
db 0100010b
db 0011100b
db 0   
db 0   


;0x37
Seven02:
db 0111110b
db 0100010b
db 0000010b
db 0000100b
db 0000100b
db 0001000b
db 0001000b
db 0010000b
db 0010000b
db 0   
db 0   


;0x38
Eight02:
db 0011100b
db 0100010b
db 0100010b
db 0100010b
db 0011100b
db 0100010b
db 0100010b
db 0100010b
db 0011100b
db 0   
db 0   


;0x39
Nine02:
db 0011100b
db 0100010b
db 0100010b
db 0100010b
db 0011110b
db 0000010b
db 0000010b
db 0000100b
db 0011000b
db 0   
db 0   


;0x3a
Colon02:
db 0
db 0
db 0
db 0001000b
db 0
db 0
db 0
db 0
db 0001000b
db 0   
db 0   


;0x3b
Semi02:
db 0
db 0
db 0001000b
db 0
db 0
db 0
db 0
db 0001000b
db 0010000b
db 0   
db 0   


;0x3c
Larrow02:
db 0
db 0
db 0000100b
db 0001000b
db 0010000b
db 0100000b
db 0010000b
db 0001000b
db 0000100b
db 0   
db 0   


;0x3d
Equal02:
db 0
db 0
db 0
db 0111110b
db 0
db 0111110b
db 0
db 0
db 0
db 0   
db 0   


;0x3e
Rarrow02:
db 0
db 0
db 0010000b
db 0001000b
db 0000100b
db 0000010b
db 0000100b
db 0001000b
db 0010000b
db 0   
db 0   


;0x3f
Quest02:
db 0011100b
db 0100010b
db 0000010b
db 0000010b
db 0000100b
db 0001000b
db 0001000b
db 0
db 0001000b
db 0   
db 0   


;0x40
At02:
db 0011110b
db 0100001b
db 1001101b
db 1010101b
db 1010101b
db 1010101b
db 1001110b
db 0100000b
db 0011100b
db 0   
db 0   


;0x41
A02:
db 0001000b
db 0001000b
db 0001000b
db 0010100b
db 0010100b
db 0100010b
db 0111110b
db 0100010b
db 1110111b
db 0   
db 0   




;0x42
B02:
db 1111110b
db 0100001b
db 0100001b
db 0100001b
db 0111110b
db 0100001b
db 0100001b
db 0100001b
db 1111110b
db 0   
db 0   



;0x43
C02:
db 0011110b
db 0100001b
db 1000000b
db 1000000b
db 1000000b
db 1000000b
db 1000000b
db 0100001b
db 0011110b
db 0   
db 0   



;0x44
D02:
db 1111100b
db 0100010b
db 0100001b
db 0100001b
db 0100001b
db 0100001b
db 0100001b
db 0100010b
db 1111100b
db 0   
db 0   



;0x45
E02:
db 1111111b
db 0100001b
db 0100000b
db 0100100b
db 0111100b
db 0100100b
db 0100000b
db 0100001b
db 1111111b
db 0   
db 0   
 


;0x46
F02:
db 1111111b
db 0100001b
db 0100000b
db 0100100b
db 0111100b
db 0100100b
db 0100000b
db 0100000b
db 1111000b
db 0   
db 0   
 

;0x47
G02:
db 0011110b
db 0100001b
db 1000000b
db 1000000b
db 1000000b
db 1000011b
db 1000001b
db 0100001b
db 0011110b
db 0   
db 0   


;0x48
H02:
db 1110111b
db 0100010b
db 0100010b
db 0100010b
db 0111110b
db 0100010b
db 0100010b
db 0100010b
db 1110111b
db 0   
db 0   

 

;0x49
I02:
db 0111110b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0111110b
db 0   
db 0   



;0x4a
J02:
db 0011110b
db 0000100b
db 0000100b
db 0000100b
db 0000100b
db 0000100b
db 1000100b
db 1000100b
db 0111000b
db 0   
db 0   



;0x4b
K02:
db 1110011b
db 0100010b
db 0100100b
db 0100100b
db 0101000b
db 0111000b
db 0100100b
db 0100010b
db 1110011b
db 0   
db 0   


;0x4c
L02:
db 1111100b
db 0010000b
db 0010000b
db 0010000b
db 0010000b
db 0010000b
db 0010000b
db 0010001b
db 1111111b
db 0   
db 0   
                 
 

;0x4d
M02:
db 1100011b
db 0100010b
db 0110110b
db 0110110b
db 0101010b
db 0101010b
db 0100010b
db 0100010b
db 1110111b
db 0   
db 0   


;0x4e
N02:
db 1100111b
db 0100010b
db 0110010b
db 0110010b
db 0101010b
db 0100110b
db 0100110b
db 0100010b
db 1110010b
db 0   
db 0   


;0x4f
O02:
db 0011100b
db 0100010b
db 1000001b
db 1000001b
db 1000001b
db 1000001b
db 1000001b
db 0100010b
db 0011100b
db 0   
db 0   



;0x50
P02:
db 1111110b
db 0100001b
db 0100001b
db 0100001b
db 0111110b
db 0100000b
db 0100000b
db 0100000b
db 1111000b
db 0   
db 0   



;0x51
Q02:
db 0011100b
db 0100010b
db 1000001b
db 1000001b
db 1000001b
db 1000001b
db 0100010b
db 0011100b
db 0011011b
db 0   
db 0   




;0x52
R02:
db 1111110b
db 0100001b
db 0100001b
db 0100001b
db 0111110b
db 0100100b
db 0100100b
db 0100010b
db 1110011b
db 0   
db 0   



;0x53
S02:
db 0111110b
db 1000001b
db 1000000b
db 1000000b
db 0111110b
db 0000001b
db 0000001b
db 1000001b
db 0111110b
db 0   
db 0   


;0x54
T02:
db 1111111b
db 1001001b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0011100b
db 0   
db 0   


;0x55
U02:
db 1110111b
db 0100010b
db 0100010b
db 0100010b
db 0100010b
db 0100010b
db 0100010b
db 0100010b
db 0011100b
db 0   
db 0   




;0x56
V02:
db 1110111b
db 0100010b
db 0100010b
db 0100010b
db 0010100b
db 0010100b
db 0010100b
db 0001000b
db 0001000b
db 0   
db 0   



;0x57
W02:
db 1110111b
db 0100010b
db 0100010b
db 0100010b
db 0101010b
db 0101010b
db 0101010b
db 0010100b
db 0010100b
db 0   
db 0   


;0x58
X02:
db 1110111b
db 0100010b
db 0010100b
db 0010100b
db 0001000b
db 0010100b
db 0010100b
db 0100010b
db 1110111b
db 0   
db 0   


;0x59
Y02:
db 1110111b
db 0100010b
db 0100010b
db 0010100b
db 0010100b
db 0001000b
db 0001000b
db 0001000b
db 0011100b
db 0   
db 0   



;0x5a
Z02:
db 1111111b
db 1000010b
db 0000100b
db 0000100b
db 0001000b
db 0010000b
db 0010000b
db 0100001b
db 1111111b
db 0   
db 0   


;0x5b
Lbrkt02:
db 1110000b
db 1000000b
db 1000000b
db 1000000b
db 1000000b
db 1000000b
db 1000000b
db 1000000b
db 1110000b
db 0   
db 0   



;0x5c
Bslash02:
db 0
db 1000000b
db 0100000b
db 0010000b
db 0001000b
db 0000100b
db 0000010b
db 0000001b
db 0
db 0   
db 0   


;0x5d
Rbrkt02:
db 0000111b
db 0000001b
db 0000001b
db 0000001b
db 0000001b
db 0000001b
db 0000001b
db 0000001b
db 0000111b
db 0   
db 0   



;0x5e
Caret02:
db 0
db 0001000b
db 0010100b
db 0100100b
db 0
db 0
db 0
db 0
db 0
db 0   
db 0   


;0x5f
Uscore02:
db 0
db 0
db 0
db 0
db 0
db 0
db 0
db 0
db 1111111b
db 0   
db 0   


;0x60   `
Btick02:
db 0
db 0100000b
db 0010000b
db 0
db 0
db 0
db 0
db 0
db 0
db 0   
db 0   


;0x61
a02:
db 0
db 0
db 0
db 0111100b
db 0000010b
db 0111110b
db 1000010b
db 1000010b
db 0111101b
db 0   
db 0   


;0x62
b02:
db 1100000b
db 0100000b
db 0100000b
db 0111110b
db 0100001b
db 0100001b
db 0100001b
db 0100001b
db 1111110b
db 0   
db 0   



;0x63
c02:
db 0
db 0
db 0
db 0111110b
db 1000001b
db 1000000b
db 1000000b
db 1000001b
db 0111110b
db 0   
db 0   



;0x64
d02:
db 0000110b
db 0000010b
db 0000010b
db 0111110b
db 1000010b
db 1000010b
db 1000010b
db 1000010b
db 0111111b
db 0   
db 0   


;0x65
e02:
db 0
db 0
db 0
db 0111110b
db 1000001b
db 1111111b
db 1000000b
db 1000001b
db 0111110b
db 0   
db 0   


;0x66
f02:
db 0011000b
db 0100000b
db 0100000b
db 1111000b
db 0100000b
db 0100000b
db 0100000b
db 0100000b
db 1111000b
db 0   
db 0   


;0x67
g02:
db 0
db 0   
db 0   
db 0111111b
db 1000010b
db 1000010b
db 1000010b
db 0111110b
db 0000010b
db 0000010b
db 0111100b


;0x68
h02:
db 1100000b
db 0100000b
db 0100000b
db 0101100b
db 0110010b
db 0100010b
db 0100010b
db 0100010b
db 1110111b
db 0   
db 0   


;0x69
i02:
db 0001000b
db 0
db 0
db 0111000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0111110b
db 0   
db 0   


;0x6a
j02:
db 0
db 0   
db 0   
db 1111000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 1110000b


;0x6b
k02:
db 1100000b
db 0100000b
db 0100000b
db 0100110b
db 0100100b
db 0101000b
db 0111000b
db 0100100b
db 1100011b
db 0   
db 0   


;0x6c
l02:
db 0110000b
db 0010000b
db 0010000b
db 0010000b
db 0010000b
db 0010000b
db 0010000b
db 0010000b
db 1111100b
db 0   
db 0   



;0x6d
m02:
db 0
db 0
db 0
db 1110100b
db 0101010b
db 0101010b
db 0101010b
db 0101010b
db 1101011b
db 0   
db 0   


 
;0x6e
n02:
db 0
db 0
db 0
db 1101100b
db 0110010b
db 0100010b
db 0100010b
db 0100010b
db 1110111b
db 0   
db 0   


;0x6f
o02:
db 0
db 0
db 0
db 0111110b
db 1000001b
db 1000001b
db 1000001b
db 1000001b
db 0111110b
db 0   
db 0   


;0x70
p02:
db 0
db 0   
db 0   
db 1111110b
db 0100001b
db 0100001b
db 0100001b
db 0100001b
db 0111110b
db 0100000b
db 1110000b



;0x71
q02:
db 0
db 0   
db 0   
db 0111111b
db 1000010b
db 1000010b
db 1000010b
db 1000010b
db 0111110b
db 0000010b
db 0000111b



;0x72
r02:
db 0
db 0
db 0
db 1110110b
db 0011001b
db 0010000b
db 0010000b
db 0010000b
db 1111100b
db 0   
db 0   


;0x73
s02:
db 0
db 0
db 0
db 0111110b
db 1000001b
db 0111000b
db 0000110b
db 1000001b
db 0111110b
db 0   
db 0   


;0x74
t02:
db 0
db 0100000b
db 0100000b
db 1111000b
db 0100000b
db 0100000b
db 0100000b
db 0100100b
db 0011000b
db 0   
db 0   


;0x75
u02:
db 0
db 0
db 0
db 1100110b
db 0100010b
db 0100010b
db 0100010b
db 0100110b
db 0011011b
db 0   
db 0   


;0x76
v02:
db 0
db 0
db 0
db 1110111b
db 0100010b
db 0100010b
db 0010100b
db 0001000b
db 0001000b
db 0   
db 0   


;0x77
w02:
db 0
db 0
db 0
db 1110111b
db 0100010b
db 0101010b
db 0101010b
db 0010100b
db 0010100b
db 0   
db 0   


;0x78
x02:
db 0
db 0
db 0
db 1110111b
db 0100010b
db 0011100b
db 0011100b
db 0100010b
db 1110111b
db 0   
db 0   



;0x79
y02:
db 0
db 0   
db 0   
db 1110111b
db 0100010b
db 0100010b
db 0010100b
db 0010100b
db 0001000b
db 0001000b
db 0110000b


;0x7a
z02:
db 0
db 0
db 0
db 1111110b
db 1000100b
db 0001000b
db 0010000b
db 0100001b
db 1111110b
db 0   
db 0   


;0x7b  {
Lbrace02:
db 0001100b
db 0010000b
db 0010000b
db 0010000b
db 1100000b
db 0010000b
db 0010000b
db 0010000b
db 0001100b
db 0   
db 0   


;0x7c   |
Pipe02:
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0001000b
db 0   
db 0   


;0x7d  }
Rbrace02:
db 0110000b
db 0001000b
db 0001000b
db 0001000b
db 0000110b
db 0001000b
db 0001000b
db 0001000b
db 0110000b
db 0   
db 0   



;0x7e  ~
Tilde02:
db 0
db 0
db 0
db 0110001b
db 1001001b
db 1000110b
db 0
db 0
db 0
db 0   
db 0   



box02:
db 1111111b
db 1000001b
db 0
db 1000001b
db 0
db 1000001b
db 0
db 1000001b
db 1111111b
db 0   
db 0   


