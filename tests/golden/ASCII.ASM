           INCLUDE RUNTIME.ASM
PilaS      SEGMENT STACK
           db      32 DUP('STACK   ')
PilaS      ENDS
DatiS      SEGMENT
KEY      dw      0        
$title      db       "Press keys to see their ASCII codes. Esc quits.",0
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
CALL Char_In
MOV KEY, AX           ;store
L1:
MOV AX, KEY
PUSH AX
MOV AX, 27
POP BX
CMP BX,AX
CALL SETNE       ;set if not equal
TEST AX,1    ;set the flags from AX
JNE skipL0
JMP L0
skipL0:
MOV AX, KEY
CALL Char_Out
MOV AX, ':'
CALL Char_Out
MOV AX, ' '
CALL Char_Out
MOV AX, KEY
CALL Wor2Dec
CALL NEW_LINE
CALL Char_In
MOV KEY, AX           ;store
JMP    L1
L0:
        jmp dos
PrgPrin    ENDP
MainS      ENDS
END     lInizio
