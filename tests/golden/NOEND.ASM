           INCLUDE RUNTIME.ASM
PilaS      SEGMENT STACK
           db      32 DUP('STACK   ')
PilaS      ENDS
DatiS      SEGMENT
DatiS      ENDS
MainS      SEGMENT PARA 'CODE'
           ASSUME  CS:MainS, SS:PilaS, DS:DatiS
PrgPrin    PROC    FAR
lInizio    LABEL   NEAR
     mov     ax,SEG DatiS        ; DS = data segment
     mov     ds,ax
CALL NEW_LINE
        jmp dos
PrgPrin    ENDP
MainS      ENDS
END     lInizio
