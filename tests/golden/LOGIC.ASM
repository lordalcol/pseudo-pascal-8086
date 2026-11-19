           INCLUDE RUNTIME.ASM
PilaS      SEGMENT STACK
           db      32 DUP('STACK   ')
PilaS      ENDS
DatiS      SEGMENT
A      dw      0        
B      dw      0        
D      dw      0        
I      dw      0        
T      dw      0        
V       dw      12 dup(0)
$sep      db       ", ",0
$done      db       "done",0
DatiS      ENDS
MainS      SEGMENT PARA 'CODE'
           ASSUME  CS:MainS, SS:PilaS, DS:DatiS
PrgPrin    PROC    FAR
lInizio    LABEL   NEAR
     mov     ax,SEG DatiS        ; DS = data segment
     mov     ds,ax
MOV AX, 7
MOV A, AX           ;store
MOV AX, 3
MOV B, AX           ;store
MOV AX, A
PUSH AX
MOV AX, B
POP BX
SUB AX,BX
NEG AX
PUSH AX
MOV AX, 2
POP BX
ADD AX,BX
PUSH AX
MOV AX, 1
POP BX
SUB AX,BX
NEG AX
MOV D, AX           ;store
MOV AX, D
CALL Wor2Dec
LEA SI, $sep
CALL DSP_STR
MOV AX, A
PUSH AX
MOV AX, B
POP BX        ;dividend
XCHG AX,BX    ;AX = dividend, BX = divisor
CWD           ;sign-extend AX into DX
IDIV BX       ;AX = DX:AX / BX
PUSH AX
MOV AX, B
POP BX
IMUL BX       ;DX:AX = AX * BX, keep AX
CALL Wor2Dec
LEA SI, $sep
CALL DSP_STR
XOR AX,AX     ;AX = 0
PUSH AX
MOV AX, A
POP BX
SUB AX,BX
NEG AX
PUSH AX
MOV AX, 10
POP BX
ADD AX,BX
CALL Wor2Dec
LEA SI, $sep
CALL DSP_STR
MOV AX, A
PUSH AX
MOV AX, B
PUSH AX
MOV AX, 10
POP BX
SUB AX,BX
NEG AX
PUSH AX
MOV AX, 2
POP BX
IMUL BX       ;DX:AX = AX * BX, keep AX
POP BX
SUB AX,BX
NEG AX
CALL Wor2Dec
LEA SI, $sep
CALL DSP_STR
XOR AX,AX     ;AX = 0
PUSH AX
MOV AX, 20
PUSH AX
MOV AX, 3
POP BX        ;dividend
XCHG AX,BX    ;AX = dividend, BX = divisor
CWD           ;sign-extend AX into DX
IDIV BX       ;AX = DX:AX / BX
POP BX
SUB AX,BX
NEG AX
CALL Wor2Dec
LEA SI, $sep
CALL DSP_STR
MOV AX, A
PUSH AX
XOR AX,AX     ;AX = 0
PUSH AX
MOV AX, B
POP BX
SUB AX,BX
NEG AX
POP BX
IMUL BX       ;DX:AX = AX * BX, keep AX
CALL Wor2Dec
CALL NEW_LINE
MOV AX, A
PUSH AX
MOV AX, B
POP BX
CMP BX,AX
CALL SETG        ;set if greater
NOT AX
MOV T, AX           ;store
MOV AX, T
PUSH AX
MOV AX, 1
POP BX
AND AX,BX
CALL Wor2Dec
MOV AX, A
PUSH AX
MOV AX, B
POP BX
CMP BX,AX
CALL SETL        ;set if less
NOT AX
MOV T, AX           ;store
MOV AX, T
PUSH AX
MOV AX, 1
POP BX
AND AX,BX
CALL Wor2Dec
MOV AX, A
PUSH AX
MOV AX, 7
POP BX
CMP BX,AX
CALL SETE        ;set if equal
PUSH AX
MOV AX, B
PUSH AX
MOV AX, 3
POP BX
CMP BX,AX
CALL SETE        ;set if equal
POP BX
XOR AX,BX
CALL Wor2Dec
MOV AX, A
PUSH AX
MOV AX, 7
POP BX
CMP BX,AX
CALL SETE        ;set if equal
PUSH AX
MOV AX, B
PUSH AX
MOV AX, 4
POP BX
CMP BX,AX
CALL SETE        ;set if equal
POP BX
OR AX,BX
CALL Wor2Dec
MOV AX, A
PUSH AX
MOV AX, 7
POP BX
CMP BX,AX
CALL SETNE       ;set if not equal
PUSH AX
MOV AX, B
PUSH AX
MOV AX, 3
POP BX
CMP BX,AX
CALL SETGE       ;set if >=
PUSH AX
MOV AX, B
PUSH AX
MOV AX, 3
POP BX
CMP BX,AX
CALL SETLE       ;set if <=
POP BX
AND AX,BX
POP BX
OR AX,BX
CALL Wor2Dec
CALL NEW_LINE
MOV AX, 0
MOV I, AX           ;store
L1:
MOV AX, I
PUSH AX
MOV AX, 12
POP BX
CMP BX,AX
CALL SETL        ;set if less
TEST AX,1    ;set the flags from AX
JNE skipL0
JMP L0
skipL0:
MOV AX, I
PUSH AX
MOV AX, I
PUSH AX
MOV AX, I
POP BX
IMUL BX       ;DX:AX = AX * BX, keep AX
PUSH AX
MOV AX, 5
PUSH AX
MOV AX, I
POP BX
IMUL BX       ;DX:AX = AX * BX, keep AX
POP BX
SUB AX,BX
NEG AX
POP BX        ;array index
ADD BX,BX     ;words: index * 2
MOV V[BX], AX       ;store array
MOV AX, I
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV I, AX           ;store
JMP    L1
L0:
MOV AX, 0
MOV I, AX           ;store
L3:
MOV AX, I
PUSH AX
MOV AX, 12
POP BX
CMP BX,AX
CALL SETL        ;set if less
TEST AX,1    ;set the flags from AX
JNE skipL2
JMP L2
skipL2:
MOV AX, I
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, V[BX]
PUSH AX
MOV AX, 0
POP BX
CMP BX,AX
CALL SETL        ;set if less
TEST AX,1    ;set the flags from AX
JNE skipL4
JMP L4
skipL4:
MOV AX, '-'
CALL Char_Out
JMP    L5
L4:
MOV AX, I
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, V[BX]
PUSH AX
MOV AX, 0
POP BX
CMP BX,AX
CALL SETE        ;set if equal
TEST AX,1    ;set the flags from AX
JNE skipL6
JMP L6
skipL6:
MOV AX, '0'
CALL Char_Out
JMP    L7
L6:
MOV AX, I
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, V[BX]
PUSH AX
MOV AX, 20
POP BX
CMP BX,AX
CALL SETG        ;set if greater
TEST AX,1    ;set the flags from AX
JNE skipL8
JMP L8
skipL8:
MOV AX, '#'
CALL Char_Out
JMP    L9
L8:
MOV AX, '+'
CALL Char_Out
L9:
L7:
L5:
MOV AX, I
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV I, AX           ;store
JMP    L3
L2:
CALL NEW_LINE
MOV AX, 3
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, V[BX]
PUSH AX
MOV AX, 9
POP BX
ADD AX,BX
PUSH AX
XOR AX,AX     ;AX = 0
PUSH AX
MOV AX, 1
POP BX
SUB AX,BX
NEG AX
POP BX
SUB AX,BX
NEG AX
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, V[BX]
CALL Wor2Dec
CALL NEW_LINE
MOV AX, 0
MOV I, AX           ;store
MOV AX, 3
MOV CX, AX           ;store
L10:
MOV AX, I
PUSH AX
MOV AX, 1
POP BX
CMP BX,AX
CALL SETE        ;set if equal
TEST AX,1    ;set the flags from AX
JNE skipL11
JMP L11
skipL11:
MOV AX, 'b'
CALL Char_Out
JMP    L12
L11:
MOV AX, 'a'
CALL Char_Out
L12:
MOV AX, I
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV I, AX           ;store
LOOP L10
CALL NEW_LINE
LEA SI, $done
CALL DSP_STR
LEA SI, $sep
CALL DSP_STR
LEA SI, $done
CALL DSP_STR
        jmp dos
PrgPrin    ENDP
MainS      ENDS
END     lInizio
