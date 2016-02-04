;tatOS/tlib/fontHershey.inc

;rev: 12/23/15


;0 = HERSHEYROMANLARGE  Font03 -> Hershey Roman Single Line Large
;1 = HERSHEYGOTHIC      Font04 -> Hershey Gothic
;2 = HERSHEYROMANSMALL  Font05 -> Hershey Roman Single Line Small


;Hershey Fonts for tatOS

;the hershey font encodings come from the website of paulbourke.net
;Pauls encoding includes additional information
;there are almost 4000 character glyphs in this collection
;so tatOS is only scratching the surface by offering a few

;the first 4 columns in the Bourke/Heshey encoding
;is a number representing the qty of coordinate pairs
;I have eliminated this number from the encoding since here we are 0 terminated
;the next two bytes are the Xextents

;a Hershey glyph is a line drawing encoded as an ascii string
;the bytes in the string should be treated as x,y pairs

;the tatOS encoding of the string is as follows:
;the first 2 bytes are the left and right bounds (xmin, xmax)
;the next 2 bytes are a MoveTo x,y
;the next 2 bytes are a LineTo x,y
;thereafter is a series of LineTo 

;a SPACE followed by R is a MoveTo and the next 2 bytes will be LineTo

;subtract the ascii value of the letter 'R' (which is 82) 
;to get a signed integer coordinate
;see the notes for putcHershey in tlib/put.s

;the xmin and xmax define invisible vertical lines each side of the character
;they include some "air" space 
;use these to space the characters properly in a string
;the origin of the character is generally at 0 midway between xmin and xmax
;the +X axis of the character points to the right
;the +Y axis of the character points down
;see picture below showing xaxis, yaxis, xmin, xmax

;the Hershey font will be drawn upright regardless of the value of YORIENT

;the Hershey font set does not strictly follow ascii, it has some special
;chars, there are holes in this table and some glyphs I made on my own

;for making new Hershey glyphs you need these handy numbers
;the ascii char is followed by its numerical value then the Hershey coordinate
;*******************************************************************************

;letter,AsciiDecimal,HersheyCoordinate
;B, 66, -16
;C, 67, -15
;D, 68, -14
;E, 69, -13
;F, 70, -12
;G, 71, -11
;H, 72, -10
;I, 73, -9
;J, 74, -8
;K, 75, -7
;L, 76, -6
;M, 77, -5
;N, 78, -4
;O, 79, -3
;P, 80, -2
;Q, 81, -1
;R, 82, 0
;S, 83, 1
;T, 84, 2
;U, 85, 3
;V, 86, 4
;W, 87, 5
;X, 88, 6
;Y, 89, 7
;Z, 90, 8
;[, 91, 9
;\, 92, 10
;], 93, 11
;^, 94, 12  
;_, 95, 13  uscore
;`, 96, 14  Btick
;a, 97, 15
;b, 98, 16



;this illustrates the coordinate system for each Hershey glyph
;and the Xextents

;      |          |             |
;      |          |             |
;      |          |      +X     |
;      |   -------o------->     |
;      |          |             |
;      |          |             |
;      |          |             |
;      |	      V +Y          |
;      |                        |
;      |                        |
;     xmin                     xmax




;if you want to see what all the hershey fonts look like,
;there is a good Linux or Windows app at:
;http://www.efg2.com/Lab/OtherProjects/Hershey.htm
;see also tatOS/apps/HERSHEY






;*********************************************
;Font03
;This is the Hershey Roman Font lookup table
;single line thickness, large size
;*********************************************

HersheyRoman03:

;    0x20     0x21       0x22        0x23     0x24
dd Space03, Exclaim03, DblQuote03, Pound03, Dollar03,

;    0x25     0x26     0x27      0x28      0x29
dd   Prcnt03, Amper03, Squote03, Lparan03, Rparan03,

;   0x2a      0x2b   0x2c    0x2d     0x2e      0x2f
dd Aster03, Plus03, Comma03, Dash03, Period03, Fslash03

;   0x30    0x31   0x32   0x33     0x34    0x35    0x36   ;0 1 2 3 4 5 6
dd Zero03, One03, Two03, Three03, Four03, Five03, Six03

;  0x37       0x38    0x39   0x3a     0x3b    0x3c        ;7 8 9 : ; <
dd Seven03, Eight03, Nine03, Colon03, Semi03, Larrow03

;   0x3d    0x3e      0x3f      0x40                      ;= > ? @
dd Equal03, Rarrow03, Quest03,  At03,

;  0x41  0x42  0x43  0x44  0x45  0x46  0x47  0x48  0x49  ;capital letters A-I
dd A03,  B03,  C03,  D03,  E03,  F03,  G03,  H03,  I03

;  0x4a  0x4b  0x4c  0x4d  0x4e  0x4f  0x50  0x51  0x52  ;capital letters J-R
dd J03,  K03,  L03,  M03,  N03,  O03,  P03,  Q03,  R03

;  0x53  0x54  0x55  0x56  0x57  0x58  0x59  0x5a        ;capital letters S-Z
dd S03,  T03,  U03,  V03,  W03,  X03,  Y03,  Z03
          
;  0x5b      0x5c      0x5d      0x5e     0x5f     0x60
dd Lbrkt03, Bslash03, Rbrkt03, Caret03, Uscore03, Btick03  ;[ \ ] ^ _ `

;  0x61  0x62  0x63  0x64  0x65  0x66  0x67  0x68  0x69
dd a03,  b03,  c03,  d03,  e03,  f03,  g03,  h03,  i03   ;lower case a-i

;0x6a    0x6b  0x6c  0x6d  0x6e  0x6f  0x70  0x71  0x72
dd j03,  k03,  l03,  m03,  n03,  o03,  p03,  q03,  r03   ;lower case j-r

;  0x73 0x74  0x75  0x76  0x77  0x78  0x79  0x7a
dd s03, t03,  u03,  v03,  w03,  x03,  y03,  z03          ;lower case s-z

;  0x7b       0x7c     0x7d       0x7e
dd Lbrace03,  Pipe03,  Rbrace03,  Tilde03                ;{ | } ~

;not displayable ascii
dd box03







;**********************************************************************
;Font03
;Hershey Roman Font Encoding
;These are our Hershey Roman font glyph ascii string encodings
;each character is drawn with a (1) thickness line
;(some hershey fonts are drawn thicker using multiple lines)
;at scale=1 the upper case 'A' is height=   widht=       (pixels)
;at scale=1 the lower case 'a' is height=   widht=       (pixels)
;
;**********************************************************************




;these are the upper case letters A-Z  hershey 501-527
;*******************************************************

A03:
db 'I[RFJ[ RRFZ[ RMTWT',0

B03:
db 'G\KFK[ RKFTFWGXHYJYLXNWOTP RKPTPWQXRYTYWXYWZT[K[',0

C03:
db 'H]ZKYIWGUFQFOGMILKKNKSLVMXOZQ[U[WZYXZV',0

D03:
db 'G\KFK[ RKFRFUGWIXKYNYSXVWXUZR[K[',0

E03:
db 'H[LFL[ RLFYF RLPTP RL[Y[',0

F03:
db 'HZLFL[ RLFYF RLPTP',0

G03:
db 'H]ZKYIWGUFQFOGMILKKNKSLVMXOZQ[U[WZYXZVZS RUSZS',0

H03:
db 'G]KFK[ RYFY[ RKPYP',0

I03:
db 'NVRFR[',0

J03:
db 'JZVFVVUYTZR[P[NZMYLVLT',0

K03:
db 'G\KFK[ RYFKT RPOY[',0

L03:
db 'HYLFL[ RL[X[',0

M03:
db 'F^JFJ[ RJFR[ RZFR[ RZFZ[',0

N03:
db 'G]KFK[ RKFY[ RYFY[',0

O03:
db 'G]PFNGLIKKJNJSKVLXNZP[T[VZXXYVZSZNYKXIVGTFPF',0

P03:
db 'G\KFK[ RKFTFWGXHYJYMXOWPTQKQ',0

Q03:
db 'G]PFNGLIKKJNJSKVLXNZP[T[VZXXYVZSZNYKXIVGTFPF RSWY]',0

R03:
db 'G\KFK[ RKFTFWGXHYJYLXNWOTPKP RRPY[',0

S03:
db 'H\YIWGTFPFMGKIKKLMMNOOUQWRXSYUYXWZT[P[MZKX',0

T03:
db 'JZRFR[ RKFYF',0

U03:
db 'G]KFKULXNZQ[S[VZXXYUYF',0

V03:
db 'I[JFR[ RZFR[',0

W03:
db 'F^HFM[ RRFM[ RRFW[ R\FW[',0

X03:
db 'H\KFY[ RYFK[',0

Y03:
db 'I[JFRPR[ RZFRP',0

Z03:
db 'H\YFK[ RKFYF RK[Y[',0







;these are lower case a-z  hershey #601-626
;**********************************************

a03:
db 'I\XMX[ RXPVNTMQMONMPLSLUMXOZQ[T[VZXX',0

b03:
db 'H[LFL[ RLPNNPMSMUNWPXSXUWXUZS[P[NZLX',0

c03:
db 'I[XPVNTMQMONMPLSLUMXOZQ[T[VZXX',0

d03:
db 'I\XFX[ RXPVNTMQMONMPLSLUMXOZQ[T[VZXX',0

e03:
db 'I[LSXSXQWOVNTMQMONMPLSLUMXOZQ[T[VZXX',0

f03:
db 'MYWFUFSGRJR[ ROMVM',0

g03:
db 'I\XMX]W`VaTbQbOa RXPVNTMQMONMPLSLUMXOZQ[T[VZXX',0

h03:
db 'I\MFM[ RMQPNRMUMWNXQX[',0

i03:
db 'NVQFRGSFREQF RRMR[',0

j03:
db 'MWRFSGTFSERF RSMS^RaPbNb',0

k03:
db 'IZMFM[ RWMMW RQSX[',0

l03:
db 'NVRFR[',0

m03:
db 'CaGMG[ RGQJNLMOMQNRQR[ RRQUNWMZM\N]Q][',0

n03:
db 'I\MMM[ RMQPNRMUMWNXQX[',0

o03:
db 'I\QMONMPLSLUMXOZQ[T[VZXXYUYSXPVNTMQM',0

p03:
db 'H[LMLb RLPNNPMSMUNWPXSXUWXUZS[P[NZLX',0

q03:
db 'I\XMXb RXPVNTMQMONMPLSLUMXOZQ[T[VZXX',0

r03:
db 'KXOMO[ ROSPPRNTMWM',0

s03:  
db 'J[XPWNTMQMNNMPNRPSUTWUXWXXWZT[Q[NZMX',0

t03:
db 'MYRFRWSZU[W[ ROMVM',0

u03:
db 'I\MMMWNZP[S[UZXW RXMX[',0

v03:
db 'JZLMR[ RXMR[',0

w03:
db 'G]JMN[ RRMN[ RRMV[ RZMV[',0

x03:
db 'J[MMX[ RXMM[',0

y03:
db 'JZLMR[ RXMR[P_NaLbKb',0

z03:
db 'J[XMM[ RMMXM RM[X[',0





;numbers 0-9 are hershey #700-709
;************************************

Zero03:
db 'H\QFNGLJKOKRLWNZQ[S[VZXWYRYOXJVGSFQF',0

One03:
db 'H\NJPISFS[',0

Two03:
db 'H\LKLJMHNGPFTFVGWHXJXLWNUQK[Y[',0

Three03:
db 'H\MFXFRNUNWOXPYSYUXXVZS[P[MZLYKW',0

Four03:
db 'H\UFKTZT RUFU[',0

Five03:
db 'H\WFMFLOMNPMSMVNXPYSYUXXVZS[P[MZLYKW',0

Six03:
db 'H\XIWGTFRFOGMJLOLTMXOZR[S[VZXXYUYTXQVOSNRNOOMQLT',0

Seven03:
db 'H\YFO[ RKFYF',0

Eight03:
db 'H\PFMGLILKMMONSOVPXRYTYWXYWZT[P[MZLYKWKTLRNPQOUNWMXKXIWGTFPF',0

Nine03:
db 'H\XMWPURRSQSNRLPKMKLLINGQFRFUGWIXMXRWWUZR[P[MZLX',0




;these are all the special characters like space, pound, dollar etc...
;*********************************************************************

Space03:
db 'MWRRRR',0

Exclaim03:
db 'MWRFRT RRYQZR[SZRY',0         ;hershey #714

DblQuote03:  ;hershey #717
db 'JZNFNM RVFVM',0               ;hershey #717

Pound03:
db 'H]SBLb RYBRb RLOZO RKUYU',0   ;hershey #733

Dollar03:    ;hershey #719
db 'H\PBP_ RTBT_ RYIWGTFPFMGKIKKLMMNOOUQWRXSYUYXWZT[P[MZKX',0  

Amper03:   ;hershey #734
db 'E_\O\N[MZMYNXPVUTXRZP[L[JZIYHWHUISJRQNRMSKSIRGPFNGMIMKNNPQUXWZY[[[\Z\Y',0  

Squote03:
db 'NVRFRM',0                   ;hershey #716

Lparan03:
db 'KYVBTDRGPKOPOTPYR]T`Vb',0   ;hershey #721

Rparan03:
db 'KYNBPDRGTKUPUTTYR]P`Nb',0   ;hershey #722

Aster03:
db 'JZRLRX RMOWU RWOMU',0       ;hershey #728

Plus03:
db 'E_RIR[ RIR[R',0             ;hershey #725

Comma03:
db 'MWSZR[QZRYSZS\R^Q_',0       ;hershey #711

Dash03:
db 'E_IR[R',0                   ;hershey #724

Period03:
db 'MWRYQZR[SZRY',0             ;hershey #710

Fslash03:
db 'G][BIb',0                   ;hershey #720

Colon03:
db 'MWRMQNROSNRM RRYQZR[SZRY',0  ;hershey #712

Semi03:
db 'MWRMQNROSNRM RSZR[QZRYSZS\R^Q_',0   ;hershey #713

Larrow03:
db 'JZWLMRWX',0                 ;hershey #1241

Equal03:
db 'E_IO[O RIU[U',0             ;hershey #726

Rarrow03:
db 'JZMLWRMX',0                 ;hershey #1242

Quest03:
db 'I[LKLJMHNGPFTFVGWHXJXLWNVORQRT RRYQZR[SZRY',0  ;hershey #715

Pipe03:
db 'NVRBRb',0                   ;hershey #723

Lbrkt03:
db 'KYUBOBObUb',0               ;home made

Rbrkt03:
db 'KYOBUBUbOb',0               ;home made

Bslash03:
db 'KYIB[b',0                   ;home made based on 720 Fslash

Caret03:
db 'KYXNRFLN',0                 ;home made

Uscore03:
db 'KYV^N^',0                   ;home made

Btick03:
db 'KTRNMF',0                   ;home made

Prcnt03:    ;hershey #1271
db 'JZXKLX ROKPLPNOOMOLNLLMKOKSLVLXK RUTTUTWUXWXXWXUWTUT',0  

At03:       ;hershey #1273
db 'J[UPSOQOPQPRQTSTUS RUOUSVTXTYRYQXNVLSKRKOLMNLQLRMUOWRXSXVW',0  

Lbrace03:   ;hershey #1225
db 'LWSHQIPJPLRNSP RQIPL RSNRQ RPJQLSNSPRQPRRSSTSVQXPZ RRSSV RPXQ[ RSTRVPXPZQ[S\',0

Rbrace03:   ;hershey #1226
db 'MXQHSITJTLRNQP RSITL RQNRQ RTJSLQNQPRQTRRSQTQVSXTZ RRSQV RTXS[ RQTRVTXTZS[Q\',0

Tilde03:    ;hershey #1246
db 'JZLTLRMPOPUSWSXR RLRMQOQUTWTXRXP',0


;a box character so we have something to display for undefined glyphs
;xmin=-4, xmax=+4
box03:
db 'MWNVNNVNVVNV',0


;some glyphs not included in our font table yet maybe some day
;this is a small circle hi up used as degrees symbol as in degF
;  218 10NVQMPNPPQQSQTPTNSMQM

;this is a right arrow symbol like this ->
;  232  7LXSOVRSU RNRVR










;*********************************************
;Font04
;This is the Hershey Gothic Font lookup table
;it is quite incomplete
;only A-Z and a-z
;*********************************************

HersheyGothic:

;    0x20     0x21       0x22        0x23     0x24
dd Space03, box04, box04, box04, box04,

;    0x25     0x26    0x27      0x28       0x29
dd   box04, box04, box04, box04, box04,

;   0x2a      0x2b   0x2c    0x2d     0x2e      0x2f
dd box04, box04, box04, box04, box04, box04

;   0x30    0x31   0x32   0x33     0x34    0x35    0x36
dd box04, box04, box04, box04, box04, box04, box04        ;need 0-6

;  0x37       0x38    0x39   0x3a     0x3b    0x3c
dd box04, box04, box04, box04, box04, box04               ;need 7-9:;<

;   0x3d    0x3e      0x3f      0x40  
dd box04, box04, box04, box04,

;  0x41  0x42  0x43  0x44  0x45  0x46  0x47  0x48  0x49
dd A04,  B04,  C04,  D04,  E04,  F04,  G04,  H04,  I04

;  0x4a  0x4b  0x4c  0x4d  0x4e  0x4f  0x50  0x51  0x52
dd J04,  K04,  L04,  M04,  N04,  O04,  P04,  Q04,  R04

;  0x53  0x54  0x55  0x56  0x57  0x58  0x59  0x5a
dd S04,  T04,  U04,  V04,  W04,  X04,  Y04,  Z04
          
;  0x5b      0x5c      0x5d      0x5e     0x5f     0x60
dd box04,    box04,    box04,   box04,  box04,    box04

;  0x61  0x62  0x63  0x64  0x65  0x66  0x67  0x68  0x69
dd a04,  b04,  c04,  d04,  e04,  f04,  g04,  h04,  i04

;0x6a    0x6b  0x6c  0x6d  0x6e  0x6f  0x70  0x71  0x72
dd j04,  k04,  l04,  m04,  n04,  o04,  p04,  q04,  r04

;0x73   0x74  0x75  0x76  0x77  0x78  0x79  0x7a
dd s04, t04,  u04,  v04,  w04,  x04,  y04,  z04

;0x7b      0x7c     0x7d     0x7e
dd box04,  box04,  box04,  box04

;not displayable ascii
dd box04






;**********************************************************************
;Font04
;Hershey Gothic Font Encoding
;These are the UPPER case Hershey Gothic glyphs 3501-3526
;these are complex glyphs with lots of lines
;I chose these over the 3800 series caps because these look more "Romanish"
;for letters like A,S,V,E... at scale=2 the size of these letters is:
;top: Ycenter-25     (for all caps)
;bottom: Ycenter+19
;the tail of letter y extends down to Ycenter+33
;**********************************************************************

A04:
db 'G]LINGPFRFSGZW[X]X RQGRHYXZZ[YYX RNGPGQHXXYZZ[[[]X RLMMLOKPKQL R'
db 'PLPM RMLOLPN RG[IYKXNXPY RJYNYOZ RG[JZMZN[PY RRJLX RNSVS',0

B04:
db 'F^HHJFMFOGQF RKGNG RHHJGLHOHQF RMKLLKNKOIOHPHRIQKQKW RLMLU RIPLP'
db ' RMKMTLVKW RRIQJPLPU RQKQS RRIRRQTPU RRIXFZG[I[KYMUO RXGZIZK RVGXHYIYLWN'
db ' RWNZP[R[X RYPZRZW RWNXOYQYX RJ[MYPXTXWY RLZOYTYVZ RJ[NZSZU[WYYX[X RUOUX'
db ' RURYR RUUYU',0

C04:
db 'E]NGLHJJILHOHSIVJXMZP[S[VZXYZW[U RJKINISKWNYQZTZWY RNGLIKKJNJRKU'
db 'NXQYTYWXYW[U RPJPV RQJQT RRIRSQUPV RPJRIUFWGYGZF RTGVHXH RSHUIWIYHZF RWI'
db 'WX',0

D04:
db 'G^IFWFYGZIZX RKGWGYIYW RIFJGLHWHXIXX ROKNLMNMOKOJPJRKQMQMV RNMNT'
db ' RKPNP ROKOSNUMV RI[LYOXSXVY RKZNYSYUZ RI[MZRZT[VYXXZX RRHRX RRMTNVNXM'
db ' RRSTRVRXS',0

E04:
db 'G]IHKFMFOGQF RLGNG RIHKGMHOHQF RNKMLLNLOJOIPIRJQLQLW RMMMU RJPMP'
db ' RNKNTMVLW RQMRJSHTGVFXF[G RTHVGXGZH RRJSIUHWHYI[G RQURRSPTOVOXP RTPVPWQ'
db ' RRRSQUQVRXP RK[NYRXWX[Y RMZPYWYZZ RK[OZVZY[[Y RQMQX',0

F04:
db 'F]JHLFOFQGSF RMGPG RJHLGNHQHSF RPKOLNNNOLOKPKRLQNQNV ROMOT RLPOP'
db ' RPKPSOUNV RSJSYRZQZMXKXIYG[ RTJTX RTPXP RPZOZMYJY RUIUOXO RXQUQUWTYP[N['
db 'LZJZG[ RSJUIXFZG\G]F RWGYH[H RVHXIZI\H]F RXIXW',0

G04:
db 'E^NGLHJJILHOHRIUJWLYNZQ[U[XZZX[V[SZQYPWOUO RJKINISJV RNGLIKKJNJS'
db 'KVLXNZ RYXZWZSYQ RU[WZXYYWYSXQWPUO RPJPW RQJQU RRIRTQVPW RPJRIUFWGYGZF'
db ' RTGVHXH RSHUIWIYHZF RYHUOU[ RUSYS RUVYV',0

H04:
db 'F^HHJFMFOGQF RKGNG RHHJGLHOHQF RMKLLKNKOIOHPHRIQKQKW RLMLU RIPLP'
db ' RMKMTLVKW RJ[MYPXSXUY RLZOYRYTZ RJ[NZQZS[UY RRIQJPLPU RQKQS RRIRRQTPU'
db ' RRITGVFXFZG RWGXGYH RTGVGXIZG RUOWNYLZM[P[TZXX[ RXMYNZPZUYX RWNXNYPYUX['
db ' RUOUY RURYR RUUYU',0

I04:
db 'I\LHNFQFTGVF ROGSG RLHNGQHTHVF RSKRLQNQOOONPNROQQQQV RRMRT ROPRP'
db ' RSKSSRUQV RYHWJVMVXUZSZOXMXKYI[ RWKWW RRZQZOYLY RYHXJXVWXUZS[P[NZKZI[',0

J04:
db 'H\LHNFQFTGVF ROGSG RLHNGQHTHVF RSKRLQNQOOONPNROQQQQV RRMRT ROPRP'
db ' RSKSSRUQV RYHWJVMVXUZ RWKWW RYHXJXVWXUZR[O[LZJXJVKULUMVLWKW RJVMV',0

K04:
db 'F^HHJFMFOGQF RKGNG RHHJGLHOHQF RMKLLKNKOIOHPHRIQKQKW RLMLU RIPLP'
db ' RMKMTLVKW RJ[MYPXSXUY RLZNYRYTZ RJ[NZQZS[UY RRIQJPLPU RQKQS RRIRRQTPU'
db ' RRITGVFXFZG RWGXGYH RTGVGXIZG RUOXLYM[N RWMYN[N R[NYQWSUU RWSYTZX[Z\Z'
db ' RYVZZ RWSXTYZZ[[[\Z RUOUY',0

L04:
db 'G]IHKFNFPGRF RLGOG RIHKGMHPHRF RNKMLLNLOJOIPIRJQLQLW RMMMU RJPMP'
db ' RNKNTMVLW RK[NYRXWX[Y RMZPYWYZZ RK[OZVZY[[Y RSIRJQLQU RRKRS RSISRRTQU'
db ' RSIUGWFYF[G RXGYGZH RUGWGYI[G RWGWX',0

M04:
db 'D`LJKKJMJOHOGPGRHQJQJU RKLKS RHPKP RLJLRKTJU RE[GYIXKXMYNYOX RHY'
db 'KYMZ RE[GZJZL[M[NZOX RLJPFTJTWUYVY RPGSJSXRYSZTYSX RPPSP RNHOHRKROOO'
db ' ROQRQRXQYS[VYWX RTJXF\J\W]Y^Y RXG[J[X]Z RXP[P RVHWHZKZOWO RWQZQZY\[^Y'
db ' ROHOX RWHWX',0

N04:
db 'E^GIIGKFMFOGQJVUXXYY RMGOIPKVWYZ RIGKGMHOKTVVYWZY[ RVHXIZI\H]F R'
db 'WGYH[H RVHXFZG\G]F RKOIOHPHRIQKQ RIPKP RG[IYKXNXPY RJYMYOZ RG[JZMZN[PY'
db ' RKGKX RYIY[ RRLSMUNWNYM RKTMSQSST',0

O04:
db 'E_NFLGJIIKHNHRIUJWLYNZQ[S[VZXYZW[U\R\N[KZIXGVFUGRIOJ RJJIMISJV R'
db 'NFLHKJJMJSKVLXNZ RZV[S[MYIXH RVZXXYVZSZMYKWHUG ROJOW RPJPU RQJQTPVOW'
db ' RUGUZ RUMWNXNZM RUSWRXRZS',0

P04:
db 'H^KFLGMIMOKOJPJRKQMQMYJ[MZMbO` RMHNJN` RKPNP RKFMGNHOJO` ROKRIVF'
db 'ZJZX RVGYJYX RTHUHXKXY RRXUXXY RSYUYWZ RRZTZV[XYZX RRIR_ RRMTNVNXM'
db ' RRSTRVRXS',0

Q04:
db 'E_NFLGJIIKHNHRIUJWLYNZP[T[VZXYZW[U\R\N[KZIXGVFUGRIOJ RJJIMISJV R'
db 'NFLHKJJMJSKVLXNZ RZV[S[MYIXH RVZXXYVZSZMYKWHUG ROJOW RPJPU RQJQTPVOW'
db ' RUGUZ RUMWNXNZM RUSWRXRZS RP[QZRZT[X`Za[a RT\V_XaYa RRZS[VaXbZb[a',0

R04:
db 'F^HHJFMFOGQF RKGNG RHHJGLHOHQF RMKLLKNKOIOHPHRIQKQKW RLMLU RIPLP'
db ' RMKMTLVKW RJ[MYPXRXUY RLZNYRYTZ RJ[NZQZS[UY RRIQJPLPU RQKQS RRIRRQTPU'
db ' RRIUGWFYGZIZLYNXOTQRR RWGXGYIYMXN RUGWHXJXMWOTQ RTQVRWSZX[Y\Y RWTYX[Z'
db ' RTQVSXYZ[\Y',0

S04:
db 'G^UITHRGOF RVHTG RWGSFOFLGKHJJKLLMONWNYOZPZRYU RKKLLOMXMZN[O[QZS'
db ' RKHKJLKOLYL[M\O\QYUU[ RIOJPLQUQVRVSUU RJQLRTRUS RIOIPJRLSSSUTUU RI[LYPX'
db 'SXVY RKZNYRYUZ RI[MZRZU[ RWGUISL RRNPQ ROSMUKVJVJUKV',0

T04:
db 'E]JJILHOHSIVKYMZP[S[VZXYZW[U RISJVLXNYQZTZWY RJJIMIQJTLWNXQYTYWX'
db 'YW[U RHIIGKFOFUGYG[F RPGTHXH RHIIHKGNGTIWIYH[F RSIRJPKPV RQKQT RRJRSQUPV'
db ' RWIWX',0

U04:
db 'F^HHJFLFOGQF RKGNG RHHJGMHOHQF RKJJLIOISJVKXMZP[S[VZXYZ[\Y RJSKV'
db 'NYQZTZ RKJJNJQKTLVNXQYUYXX RUIQJPLPV RQKQT RRJRSQUPV RUIWHYFZG\HZIZW[Y\Y'
db ' RYIZHYGXHYIYX[Z RWHXIXX RUIUY RUNXN RURXR',0

V04:
db 'G^JFKGLILOJOIPIRJQLQLXJY RLHMJMX RJPMP RNYQYSZ RJFLGMHNJNXRXUY R'
db 'JYMYPZR[UYXXZX RRJUIWHYFZG\HZIZX RYIZHYGXHYIYW RWHXIXX RRJRX RRMTNVNXM R'
db 'RSTRVRXS',0

W04:
db 'E`HFIGJIJOHOGPGRHQJQJXHY RJHKJKX RHPKP RLYNYPZ RHFJGKHLJLXOXQY R'
db 'HYKYNZO[QYTXVYW[YY\X ROHRFTHTXWXYY RRGSHSX ROHQHRIRXQY RWYXZ RWHZF\H\X R'
db 'ZG[H[X RWHYHZIZXYY ROHOX RWHWX RONRN RORRR RWNZN RWRZR',0

X04:
db 'G]HIJGLFNFOGWYXZZZ RMGNHVYWZ RJGLGMHUZV[X[ZZ\X RWFYG[G\F RWGXHZH'
db ' RVHWIYI[H\F RH[IYKXMXNY RJYLYMZ RH[IZKZM[ RWFSO RQRM[ RLPPP RSPXP',0

Y04:
db 'G^JFKGLILOJOIPIRJQLQLXJY RLHMJMX RJPMP RNYQYSZ RJFLGMHNJNXRXUY R'
db 'JYMYPZR[UYXX RRJUIWHYFZG\HZIZ^Y`WbUaQ`L` RYIZHYGXHYIYY RWHXIXXZ[ RXaV`S`'
db ' RY`V_P_L` RRJRX RRMTNVNXM RRSTRVRXS',0

Z04:
db 'H\XGWIROOSMWJ[ RVKNV RZFWJUNRRMXLZ RJHLFOGUGZF RKGOHSHWG RJHNIRI'
db 'VHXG RLZNYRXVXZY RMZQYUYYZ RJ[OZUZX[ZY RMPQP RTPXP',0





;**********************************************************************
;These are the lower case Hershey Gothic glyphs 3900-3926
;with 800x600 pixel at scale=1 these glyphs look filled in
;for letters like a,s,v,e... at scale=2 the size of these letters is:
;top: Ycenter-10
;bottom: Ycenter+19
;the tail of letter y extends down to Ycenter+33
;the top stem of letter h extends up to Ycenter-25 same as the capitals
;**********************************************************************


a04:
db 'J[PQMTMXP[TY RNTNXPZ ROROWRZ RRSMNNMONNO RONSNUMWOWXXY RUNVOVXUY'
db 'VZWYVX RSNUPUXTYV[XY',0

b04:
db 'IZNHLFMJMXP[UYWX RNHNXPZ RNHPFOJOWRZ ROOTMWPWX RTNVPVX RRNUQUY',0

c04:
db 'KWNPNYP[RY ROPOYPZ RPOPXQYRY RNPTMVOTPRN RSNUO',0

d04:
db 'JZRMMPMXP[RZUYWY RNPNXPZ ROOOWRZ RPIPFQIWPWY RPIVPVX RPIMIPJUPUY',0

e04:
db 'KXNPNYP[RY ROPOYPZ RPOPXQYRY RNPTMWQPU RSNVQ RRNUR',0

f04:
db 'KWOIOXNYP[ RPIPXOYPZQYPX RQHQXRYP[ ROIUFWHUISG RTGVH RLMOM RQMUM',0

g04:
db 'J[MPMXP[UY RNPNXPZ ROOOWRZ RMPOOTMWPW]V_U`SaQaO`MaObQa RTNVPV]U_'
db ' RPaNa RRNUQU^T`Sa',0

h04:
db 'I[NHLFMJMXLYN[ RNHNXMYNZOYNX RNHPFOJOXPYN[ ROORNTMWPWYT]T`UbVbT`'
db ' RTNVPVYU[ RRNUQUZT]',0

i04:
db 'MWRFPHRJTHRF RRGQHRISHRG RRMPOQPQXPYR[ RRPSORNQORPRXQYRZSYRX RRM'
db 'TOSPSXTYR[',0

j04:
db 'MWRFPHRJTHRF RRGQHRISHRG RRMPOQPQYT] RRPSORNQORPRYS[ RRMTOSPSZT]'
db 'T`RbPaPbRb',0

k04:
db 'IZNHLFMJMXLYN[ RNHNXMYNZOYNX RNHPFOJOXPYN[ ROPRNTMVPSROU RSNUP R'
db 'RNTQ RRSSTTYV[XY RSSTUUYVZ RSRTSVXWYXY',0

l04:
db 'MWRHPFQJQXPYR[ RRHRXQYRZSYRX RRHTFSJSXTYR[',0

m04:
db 'E_GOHOIPIXHYJ[ RINJOJXIYJZKYJX RGOIMKOKXLYJ[ RKONNPMSOSXTYR[ RPN'
db 'RORXQYRZSYRX RNNQPQXPYR[ RSOVNXM[O[X\YZ[ RXNZOZXYYZZ[YZX RVNYPYXXYZ[',0

n04:
db 'I[KOLOMPMXLYN[ RMNNONXMYNZOYNX RKOMMOOOXPYN[ ROORNTMWOWXXYV[ R'
db 'TNVOVXUYVZWYVX RRNUPUXTYV[',0

o04:
db 'JZMPMXP[UYWX RNPNXPZ ROOOWRZ RMPOOTMWPWX RTNVPVX RRNUQUY',0

p04:
db 'IZLMMOMXKYMYM_LbN` RNON` RLMNNOOOXQYRZ RNYOYQZ ROZP[UYWX ROZO_Pb'
db 'N` ROORNTMWPWX RTNVPVX RRNUQUY',0

q04:
db 'J[MPMXP[UY RNPNXPZ ROOOWRZ RMPOOTMWPW_XbV` RTNVPV` RRNUQU_TbV`',0

r04:
db 'KXMONOOPOXNYP[ RONPOPXOYPZQYPX RMOOMQOQXRYP[ RQOUMWOUPSN RTNVO',0

s04:
db 'JZMPMSOUURWTWX RNPNSOT ROOOSPT RUSVTVX RTSUTUY RMPSMVNTOQN RRNUN'
db ' RWXQ[MYOXSZ ROYQZ',0

t04:
db 'MWRHPFQJQXPYR[ RRHRXQYRZSYRX RRHTFSJSXTYR[ RNMQM RSMVM',0

u04:
db 'I[KOLOMPMYP[UY RMNNONYPZ RKOMMOOOXRZ RVMXOWPWXXYYY RVPWOVNUOVPVY'
db 'WZ RVMTOUPUYW[YY',0

v04:
db 'I[LMMOMXQ[SYWW RMNNONXQZ RLMNNOOOWRYSY RVMXOWPWW RVPWOVNUOVPVW R'
db 'VMTOUPUX',0

w04:
db 'E_HMIOIXM[OYQX RINJOJXMZ RHMJNKOKWNYOY RRMPOQPQXU[WY[W RRPSORNQO'
db 'RPRXUZ RRMTOSPSWVYWY RZM\O[P[W RZP[OZNYOZPZW RZMXOYPYX',0

x04:
db 'I[LONPUZV[XY RMNOOUYWZ RLONMONVXXY RXMVMVOXOXMVOSS RQUNYL[N[NYLY'
db 'L[ RNTQT RSTVT',0

y04:
db 'I[KOLOMPMYP[UY RMNNONYPZ RKOMMOOOXRZ RVMXOWPW]V_U`SaQaO`MaObQa R'
db 'VPWOVNUOVPV^U_ RPaNa RVMTOUPU^T`Sa',0

z04:
db 'L[RNOPOORNTMWOWSRU RTNVOVS RRNUPUSTT RRUWWW]V_U`SaQaO`MaObQa RVW'
db 'V^U_ RPaNa RTVUWU^T`Sa',0



box04:
db 'MWNVNNVNVVNV',0




;******************************************************
;Font05
;This is the Hershey Small Roman Font lookup table
;single line thickness, small size
;******************************************************

HersheyRoman05:

;    0x20     0x21       0x22        0x23     0x24
dd Space05, Exclaim05, DblQuote05, Pound05, Dollar05,

;    0x25     0x26    0x27      0x28       0x29
dd   Prcnt05, Amper05, Squote05, Lparan05, Rparan05,       ; % & ' ( )

;   0x2a      0x2b   0x2c    0x2d     0x2e      0x2f
dd Aster05, Plus05, Comma05, Dash05, Period05, Fslash05    ; * + , - . /

;   0x30    0x31   0x32   0x33     0x34    0x35    0x36
dd Zero05, One05, Two05, Three05, Four05, Five05, Six05    ; 0 1 2 3 4 5 6

;  0x37       0x38    0x39   0x3a     0x3b    0x3c
dd Seven05, Eight05, Nine05, Colon05, Semi05, Larrow05     ;7 8 9 : ; <

;   0x3d    0x3e      0x3f      0x40  
dd Equal05, Rarrow05, Quest05,  At05                       ; = > ? @

;  0x41  0x42  0x43  0x44  0x45  0x46  0x47  0x48  0x49
dd A05,  B05,  C05,  D05,  E05,  F05,  G05,  H05,  I05

;  0x4a  0x4b  0x4c  0x4d  0x4e  0x4f  0x50  0x51  0x52
dd J05,  K05,  L05,  M05,  N05,  O05,  P05,  Q05,  R05

;  0x53  0x54  0x55  0x56  0x57  0x58  0x59  0x5a
dd S05,  T05,  U05,  V05,  W05,  X05,  Y05,  Z05
          
;  0x5b     0x5c      0x5d     0x5e     0x5f      0x60
dd Lbrkt05, Bslash05, Rbrkt05, Caret05, Uscore05, Btick05  ; [ \ ] ^ _ `

;  0x61  0x62  0x63  0x64  0x65  0x66  0x67  0x68  0x69
dd A05,  B05,  C05,  D05,  E05,  F05,  G05,  H05,  I05      ;should be a-i

;0x6a    0x6b  0x6c  0x6d  0x6e  0x6f  0x70  0x71  0x72
dd J05,  K05,  L05,  M05,  N05,  O05,  P05,  Q05,  R05      ;should be j-r

;0x73   0x74  0x75  0x76  0x77  0x78  0x79  0x7a
dd S05, T05,  U05,  V05,  W05,  X05,  Y05,  Z05             ;should be s-z

;0x7b      0x7c     0x7d     0x7e
dd box05,  Pipe05,  box05,   Tilde05
;dd Lbrace05,  Pipe05,  Rbrace05,  Tilde05              still need these

;not displayable ascii
dd box05




;**********************************************************************
;Font05
;Hershey Roman Small
;These are our Hershey Roman font glyph ascii string encodings
;this font is a smaller overall height compared to Font03
;the Hershey set only has the upper case glyphs A-Z and digits 0-9
;there are also some additional ascii like *-=/&, some custome made.
;these are simple glyphs drawn with a single pixel thin lines
;this font is about as small as can be made with line drawing

;for creating new glyphs keep in mind the following:
;all these glyphs are max 9 pixels tall
; * all upper case letters go from y=-5 to y=+4
; * the letter 'I'  Xextents are xmin=-2 and xmax=+2
; * the letter 'L'  Xextents are xmin=-5 and xmax=+4
;**********************************************************************

A05:
db 'MWRMNV RRMVV RPSTS',0

B05:
db 'MWOMOV ROMSMUNUPSQ ROQSQURUUSVOV',0

C05:
db 'MXVNTMRMPNOPOSPURVTVVU',0

D05:
db 'MWOMOV ROMRMTNUPUSTURVOV',0

E05:
db 'MWOMOV ROMUM ROQSQ ROVUV',0

F05:
db 'MVOMOV ROMUM ROQSQ',0

G05:
db 'MXVNTMRMPNOPOSPURVTVVUVR RSRVR',0

H05:
db 'MWOMOV RUMUV ROQUQ',0

I05:
db 'PTRMRV',0

J05:
db 'NUSMSTRVPVOTOS',0

K05:
db 'MWOMOV RUMOS RQQUV',0

L05:
db 'MVOMOV ROVUV',0

M05:
db 'LXNMNV RNMRV RVMRV RVMVV',0

N05:
db 'MWOMOV ROMUV RUMUV',0

O05:
db 'MXRMPNOPOSPURVSVUUVSVPUNSMRM',0

P05:
db 'MWOMOV ROMSMUNUQSROR',0

Q05:
db 'MXRMPNOPOSPURVSVUUVSVPUNSMRM RSTVW',0

R05:
db 'MWOMOV ROMSMUNUQSROR RRRUV',0

S05:
db 'MWUNSMQMONOOPPTRUSUUSVQVOU',0

T05:
db 'MWRMRV RNMVM',0

U05:
db 'MXOMOSPURVSVUUVSVM',0

V05:
db 'MWNMRV RVMRV',0

W05:
db 'LXNMPV RRMPV RRMTV RVMTV',0

X05:
db 'MWOMUV RUMOV',0

Y05:
db 'MWNMRQRV RVMRQ',0

Z05:
db 'MWUMOV ROMUM ROVUV',0


;a box character so we have something to display for undefined glyphs
;xmin=-4, xmax=+4
box05:
db 'MWNVNNVNVVNV',0




;numbers 0-9
;************

Zero05:
db 'MWRMPNOPOSPURVTUUSUPTNRM',0

One05:
db 'MWPORMRV',0

Two05:
db 'MWONQMSMUNUPTROVUV',0

Three05:
db 'MWONQMSMUNUPSQ RRQSQURUUSVQVOU',0

Four05:
db 'MWSMSV RSMNSVS',0

Five05:
db 'MWPMOQQPRPTQUSTURVQVOU RPMTM',0

Six05:
db 'MWTMRMPNOPOSPURVTUUSTQRPPQOS',0

Seven05:
db 'MWUMQV ROMUM',0

Eight05:
db 'MWQMONOPQQSQUPUNSMQM RQQOROUQVSVUUURSQ',0

Nine05:
db 'MWUPTRRSPROPPNRMTNUPUSTURVPV',0



;special chars
;******************

Space05:
db 'MWRRRR',0

Exclaim05:
;db 'PURMRR RSMSR RRURVSVSURU',0
db 'PTRMRS RQUQVRVRUQU',0

DblQuote05:
db 'NUPMPQ RSMSQ',0

Pound05:
db 'MXRLPW RULSW ROPVP ROSVS',0

Dollar05:
db 'MWUNSMQMONOPQQTRUSUUSVQVOU RRLRW',0

Amper05:
db 'LXVRURTSSURVOVNUNSORRQSPSNRMPMONOPQSSUUVVV',0

Squote05:
db 'PTRMRQ',0

Lparan05:
db 'OVTLRNQPQSRUTW',0

Rparan05:
db 'NUPLRNSPSSRUPW',0

Aster05:
db 'MWRORU ROPUT RUPOT',0

Plus05:
db 'LXRNRV RNRVR',0

Comma05:
db 'PUSVRVRUSUSWRY',0

Dash05:
db 'LXNRVR',0

Period05:
db 'PURURVSVSURU',0

Fslash05:
db 'MWVLNW',0

Colon05:
db 'PURPRQSQSPRP RRURVSVSURU',0

Semi05:
db 'PURPRQSQSPRP RSVRVRUSUSWRY',0

Equal05:
db 'LXNPVP RNTVT',0

Quest05:
db 'NWPNRMSMUNUPRQRRSRSQUP RRURVSVSURU',0

Pipe05:
db 'PTRLRW',0


;all the following glyphs are either home made or
;modified from the original Paul Bourke Hershey

Lbrkt05:
db 'OVSMQMQVSV',0

Rbrkt05:
db 'QWSMUMUVSV',0

Bslash05:
db 'NVOMUV',0

Uscore05:
db 'NVOWUW',0

Caret05:
db 'NVUQRMOQ',0

Btick05:
db 'NTPMTQ',0

Tilde05:
db 'NVOSQQSSUQ',0

Prcnt05:
db 'MVNNONOONONN RVNNV RUUVUVVUVUU',0

At05:
db 'MWTSTQSPQPPQPSQTSTTSVSVPUOSNQNOONPNTOUQVTV',0

Larrow05:
db 'NVUUORUO',0

Rarrow05:
db 'NVOUUROO',0


;some glyphs not included in our font table yet maybe some day
;this is a small circle hi up used as degrees symbol as in degF
;  218 10NVQMPNPPQQSQTPTNSMQM

;this is a right arrow symbol like this ->
;  232  7LXSOVRSU RNRVR



