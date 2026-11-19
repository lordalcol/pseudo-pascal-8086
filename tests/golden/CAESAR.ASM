           INCLUDE RUNTIME.ASM
PilaS      SEGMENT STACK
           db      32 DUP('STACK   ')
PilaS      ENDS
DatiS      SEGMENT
K      dw      0        
CESC      dw      0        
$title      db       "Type some text: each letter shifts by one. Esc quits.",0
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
MOV AX, 27
MOV CESC, AX           ;store
CALL Char_In
MOV K, AX           ;store
L1:
MOV AX, K
PUSH AX
MOV AX, CESC
POP BX
CMP BX,AX
CALL SETNE       ;set if not equal
TEST AX,1    ;set the flags from AX
JNE skipL0
JMP L0
skipL0:
MOV AX, K
PUSH AX
MOV AX, 'a'
POP BX
CMP BX,AX
CALL SETGE       ;set if >=
PUSH AX
MOV AX, K
PUSH AX
MOV AX, 'z'
POP BX
CMP BX,AX
CALL SETLE       ;set if <=
POP BX
AND AX,BX
PUSH AX
MOV AX, K
PUSH AX
MOV AX, 'A'
POP BX
CMP BX,AX
CALL SETGE       ;set if >=
PUSH AX
MOV AX, K
PUSH AX
MOV AX, 'Z'
POP BX
CMP BX,AX
CALL SETLE       ;set if <=
POP BX
AND AX,BX
POP BX
OR AX,BX
TEST AX,1    ;set the flags from AX
JNE skipL2
JMP L2
skipL2:
MOV AX, K
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV K, AX           ;store
L2:
MOV AX, K
CALL Char_Out
CALL Char_In
MOV K, AX           ;store
JMP    L1
L0:
        jmp dos
PrgPrin    ENDP
MainS      ENDS
END     lInizio
