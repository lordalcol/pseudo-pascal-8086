           INCLUDE RUNTIME.ASM
PilaS      SEGMENT STACK
           db      32 DUP('STACK   ')
PilaS      ENDS
DatiS      SEGMENT
X      dw      0        
Y      dw      0        
OP      dw      0        
KESC      dw      0        
$title      db       "RUNNING CALCULATOR (operators: + - * / then a number and Enter, Esc quits)",0
DatiS      ENDS
MainS      SEGMENT PARA 'CODE'
           ASSUME  CS:MainS, SS:PilaS, DS:DatiS
PrgPrin    PROC    FAR
lInizio    LABEL   NEAR
     mov     ax,SEG DatiS        ; DS = data segment
     mov     ds,ax
LEA SI, $title
CALL DSP_STR
CALL NEW_LINE
CALL NEW_LINE
MOV AX, 27
MOV KESC, AX           ;store
MOV AX, 0
MOV X, AX           ;store
MOV AX, X
CALL Wor2Dec
CALL Char_In
MOV OP, AX           ;store
MOV AX, OP
CALL Char_Out
L1:
MOV AX, OP
PUSH AX
MOV AX, KESC
POP BX
CMP BX,AX
CALL SETNE       ;set if not equal
TEST AX,1    ;set the flags from AX
JNE skipL0
JMP L0
skipL0:
CALL DEC2BIN           ;read a decimal number into AX
MOV Y, AX           ;store
MOV AX, '='
CALL Char_Out
CALL NEW_LINE
MOV AX, OP
PUSH AX
MOV AX, '+'
POP BX
CMP BX,AX
CALL SETE        ;set if equal
TEST AX,1    ;set the flags from AX
JNE skipL2
JMP L2
skipL2:
MOV AX, X
PUSH AX
MOV AX, Y
POP BX
ADD AX,BX
MOV X, AX           ;store
L2:
MOV AX, OP
PUSH AX
MOV AX, '-'
POP BX
CMP BX,AX
CALL SETE        ;set if equal
TEST AX,1    ;set the flags from AX
JNE skipL3
JMP L3
skipL3:
MOV AX, X
PUSH AX
MOV AX, Y
POP BX
SUB AX,BX
NEG AX
MOV X, AX           ;store
L3:
MOV AX, OP
PUSH AX
MOV AX, '*'
POP BX
CMP BX,AX
CALL SETE        ;set if equal
TEST AX,1    ;set the flags from AX
JNE skipL4
JMP L4
skipL4:
MOV AX, X
PUSH AX
MOV AX, Y
POP BX
IMUL BX       ;DX:AX = AX * BX, keep AX
MOV X, AX           ;store
L4:
MOV AX, OP
PUSH AX
MOV AX, '/'
POP BX
CMP BX,AX
CALL SETE        ;set if equal
TEST AX,1    ;set the flags from AX
JNE skipL5
JMP L5
skipL5:
MOV AX, X
PUSH AX
MOV AX, Y
POP BX        ;dividend
XCHG AX,BX    ;AX = dividend, BX = divisor
CWD           ;sign-extend AX into DX
IDIV BX       ;AX = DX:AX / BX
MOV X, AX           ;store
L5:
MOV AX, X
CALL Wor2Dec
CALL Char_In
MOV OP, AX           ;store
MOV AX, OP
CALL Char_Out
JMP    L1
L0:
        jmp dos
PrgPrin    ENDP
MainS      ENDS
END     lInizio
