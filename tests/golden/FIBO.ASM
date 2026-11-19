           INCLUDE RUNTIME.ASM
PilaS      SEGMENT STACK
           db      32 DUP('STACK   ')
PilaS      ENDS
DatiS      SEGMENT
A      dw      0        
B      dw      0        
T      dw      0        
$title      db       "The first 23 Fibonacci numbers (the 24th needs more than 16 bits):",0
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
MOV AX, 0
MOV A, AX           ;store
MOV AX, 1
MOV B, AX           ;store
MOV AX, 23
MOV CX, AX           ;store
L0:
MOV AX, B
CALL Wor2Dec
MOV AX, ' '
CALL Char_Out
MOV AX, A
PUSH AX
MOV AX, B
POP BX
ADD AX,BX
MOV T, AX           ;store
MOV AX, B
MOV A, AX           ;store
MOV AX, T
MOV B, AX           ;store
LOOP L0
        jmp dos
PrgPrin    ENDP
MainS      ENDS
END     lInizio
