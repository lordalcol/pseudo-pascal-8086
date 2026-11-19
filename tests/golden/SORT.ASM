           INCLUDE RUNTIME.ASM
PilaS      SEGMENT STACK
           db      32 DUP('STACK   ')
PilaS      ENDS
DatiS      SEGMENT
A       dw      6 dup(0)
I      dw      0        
J      dw      0        
N      dw      0        
TMP      dw      0        
X      dw      0        
Y      dw      0        
$title      db       "SORTS A LIST OF INTEGERS",0
$input1      db       "Enter an integer [",0
$input2      db       "]: ",0
$output      db       "Sorted: ",0
DatiS      ENDS
MainS      SEGMENT PARA 'CODE'
           ASSUME  CS:MainS, SS:PilaS, DS:DatiS
PrgPrin    PROC    FAR
lInizio    LABEL   NEAR
     mov     ax,SEG DatiS        ; DS = data segment
     mov     ds,ax
MOV AX, 6
MOV N, AX           ;store
MOV AX, 0
MOV I, AX           ;store
LEA SI, $title
CALL DSP_STR
CALL NEW_LINE
MOV AX, N
MOV CX, AX           ;store
L0:
LEA SI, $input1
CALL DSP_STR
MOV AX, I
CALL Wor2Dec
LEA SI, $input2
CALL DSP_STR
CALL DEC2BIN           ;read a decimal number into AX
PUSH AX
MOV AX, I
PUSH AX
POP BX        ;array index
ADD BX,BX     ;words: index * 2
POP AX
MOV A[BX], AX       ;store array
CALL NEW_LINE
MOV AX, I
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV I, AX           ;store
LOOP L0
MOV AX, 0
MOV J, AX           ;store
MOV AX, 1
MOV I, AX           ;store
L2:
MOV AX, J
PUSH AX
MOV AX, N
POP BX
CMP BX,AX
CALL SETL        ;set if less
TEST AX,1    ;set the flags from AX
JNE skipL1
JMP L1
skipL1:
L4:
MOV AX, I
PUSH AX
MOV AX, N
POP BX
CMP BX,AX
CALL SETL        ;set if less
TEST AX,1    ;set the flags from AX
JNE skipL3
JMP L3
skipL3:
MOV AX, I
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, A[BX]
PUSH AX
MOV AX, J
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, A[BX]
POP BX
CMP BX,AX
CALL SETL        ;set if less
TEST AX,1    ;set the flags from AX
JNE skipL5
JMP L5
skipL5:
MOV AX, I
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, A[BX]
MOV TMP, AX           ;store
MOV AX, I
PUSH AX
MOV AX, J
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, A[BX]
POP BX        ;array index
ADD BX,BX     ;words: index * 2
MOV A[BX], AX       ;store array
MOV AX, J
PUSH AX
MOV AX, TMP
POP BX        ;array index
ADD BX,BX     ;words: index * 2
MOV A[BX], AX       ;store array
L5:
MOV AX, I
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV I, AX           ;store
JMP    L4
L3:
MOV AX, J
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV J, AX           ;store
MOV AX, J
MOV I, AX           ;store
JMP    L2
L1:
LEA SI, $output
CALL DSP_STR
CALL NEW_LINE
MOV AX, 0
MOV I, AX           ;store
MOV AX, N
MOV CX, AX           ;store
L6:
MOV AX, I
MOV BX, AX    ;array index
ADD BX,BX     ;words: index * 2
MOV AX, A[BX]
CALL Wor2Dec
MOV AX, ' '
CALL Char_Out
MOV AX, I
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV I, AX           ;store
LOOP L6
        jmp dos
PrgPrin    ENDP
MainS      ENDS
END     lInizio
