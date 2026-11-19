           INCLUDE RUNTIME.ASM
PilaS      SEGMENT STACK
           db      32 DUP('STACK   ')
PilaS      ENDS
DatiS      SEGMENT
AVERYVERYVERYLO      dw      0        
X      dw      0        
DatiS      ENDS
MainS      SEGMENT PARA 'CODE'
           ASSUME  CS:MainS, SS:PilaS, DS:DatiS
PrgPrin    PROC    FAR
lInizio    LABEL   NEAR
     mov     ax,SEG DatiS        ; DS = data segment
     mov     ds,ax
MOV AX, 12345
MOV AVERYVERYVERYLO, AX           ;store
MOV AX, AVERYVERYVERYLO
MOV X, AX           ;store
MOV AX, X
CALL Wor2Dec
        jmp dos
PrgPrin    ENDP
MainS      ENDS
END     lInizio
