;=============================================================================
; LE SEGUENTI PROCEDURE, DI FUNZIONAMENTO EVIDENTE, EMULANO LE ISTRUZIONI VALIDE
; MA NON ESISTENTI NELL'8086:
; SETE,SETNE,SETA,SETNA,SETB,SETNB
;=============================================================================
Set_IfS      SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:Set_IfS
; set if equal
SETE     PROC    FAR
           je lSETE
           mov al,0
           ret
    lSETE: mov al,00000001b
           ret
SETE     ENDP
; set if NOT equal
SETNE     PROC    FAR
           jne lSETNE
           mov al,0
           ret
    lSETNE: mov al,00000001b
           ret
SETNE     ENDP
; set if greater (above)
SETA     PROC    FAR
           ja lSETA
           mov al,0
           ret
    lSETA: mov al,00000001b
           ret
SETA     ENDP
; set if less (below)
SETB     PROC    FAR
           jb lSETB
           mov al,0
           ret
    lSETB: mov al,00000001b
           ret
SETB     ENDP
; set if less or equal
SETBE     PROC    FAR
           jbe lSETBE
           mov al,0
           ret
    lSETBE: mov al,00000001b
           ret
SETBE     ENDP
; set if equal
SETAE     PROC    FAR
           jae lSETAE
           mov al,0
           ret
    lSETAE: mov al,00000001b
           ret
SETAE     ENDP
Set_IfS      ENDS
