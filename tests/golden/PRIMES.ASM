           INCLUDE RUNTIME.ASM
PilaS      SEGMENT STACK
           db      32 DUP('STACK   ')
PilaS      ENDS
DatiS      SEGMENT
SIEVE       dw      500 dup(0)
I      dw      0        
J      dw      0        
N      dw      0        
COUNT      dw      0        
$title      db       "Prime numbers below 500:",0
$total      db       "Primes found: ",0
DatiS      ENDS
MainS      SEGMENT PARA 'CODE'
           ASSUME  CS:MainS, SS:PilaS, DS:DatiS
PrgPrin    PROC    FAR
lInizio    LABEL   NEAR
     mov     ax,SEG DatiS        ; DS = data segment
     mov     ds,ax
MOV AX, 500
MOV N, AX           ;store
LEA SI, $title
CALL DSP_STR
CALL NEW_LINE
MOV AX, 0
MOV COUNT, AX           ;store
MOV AX, 2
MOV I, AX           ;store
L1:
MOV AX, I
PUSH AX
MOV AX, N
POP BX
CMP BX,AX
CALL SETL        ;set if less
TEST AX,1    ;set the flags from AX
JNE skipL0
JMP L0
skipL0:
MOV AX, I
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, SIEVE[BX]
PUSH AX
MOV AX, 0
POP BX
CMP BX,AX
CALL SETE        ;set if equal
TEST AX,1    ;set the flags from AX
JNE skipL2
JMP L2
skipL2:
MOV AX, I
CALL Wor2Dec
MOV AX, ' '
CALL Char_Out
MOV AX, COUNT
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV COUNT, AX           ;store
MOV AX, I
PUSH AX
MOV AX, N
PUSH AX
MOV AX, I
POP BX        ;dividend
XCHG AX,BX    ;AX = dividend, BX = divisor
CWD           ;sign-extend AX into DX
IDIV BX       ;AX = DX:AX / BX
POP BX
CMP BX,AX
CALL SETLE       ;set if <=
TEST AX,1    ;set the flags from AX
JNE skipL3
JMP L3
skipL3:
MOV AX, I
PUSH AX
MOV AX, I
POP BX
IMUL BX       ;DX:AX = AX * BX, keep AX
MOV J, AX           ;store
L5:
MOV AX, J
PUSH AX
MOV AX, N
POP BX
CMP BX,AX
CALL SETL        ;set if less
TEST AX,1    ;set the flags from AX
JNE skipL4
JMP L4
skipL4:
MOV AX, J
PUSH AX
MOV AX, 1
POP BX        ;array index
ADD BX,BX     ;words: index * 2
MOV SIEVE[BX], AX       ;store array
MOV AX, J
PUSH AX
MOV AX, I
POP BX
ADD AX,BX
MOV J, AX           ;store
JMP    L5
L4:
L3:
L2:
MOV AX, I
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV I, AX           ;store
JMP    L1
L0:
CALL NEW_LINE
LEA SI, $total
CALL DSP_STR
MOV AX, COUNT
CALL Wor2Dec
        jmp dos
PrgPrin    ENDP
MainS      ENDS
END     lInizio
