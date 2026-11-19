;=============================================================================
; PROCEDURE CHE SCRIVONO IN MODO DINAMICO I "PEZZI" DI ASSEMBLY COMPILATO
; IL CODICE EMESSO E' UN MIX TRA STRINGHE COSTANTI PRESE DAL SEGMENTO DEI
; DATI E STRINGHE DINAMICHE GENERATE AL VOLO DAL COMPILATORE E PASSATE
; ATTRAVERSO SI
;=============================================================================
;
; Le seguenti istruzioni non sono commentate, poichè non sono interessanti
; dal punto di vista logico. E' sufficiente leggere le stringhe costanti
; caricate dal segmento DATI per intuire il funzionamento di ciascuna.
;
wINSTRS      SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:wINSTRS
wNewLine  PROC    FAR
           push si
           lea si,sCRLF
           call output_str
           pop si
           ret
wNewLine  ENDP
;
; write header of masm file
;
wHeader    PROC    FAR
           push si
           lea si,sHeader
           call output_str
           pop si
           ret
wHeader    ENDP
;
; write prolog of masm file
;
wProlog    PROC    FAR
           push si
           lea si,sProlog
           call output_str
           pop si
           ret
wProlog    ENDP
;
; write header of masm file
;
wEpilog    PROC    FAR
           push si
           lea si,sEpilog
           call output_str
           pop si
           ret
wEpilog    ENDP
;
; write allocation code
;
wAllocate  PROC    FAR
           push si
           lea si,Value
           call output_str
           lea si,sAllocate
           call output_str
           pop si
           ret
wAllocate  ENDP

wAllocateString  PROC    FAR
           push si
           lea si,Value
           call output_str
           lea si,sAllocateString
           call output_str
           pop si
           ret
wAllocateString  ENDP
wAllocateString2  PROC    FAR
           push si
           lea si,sAllocateString2
           call output_str
           pop si
           ret
wAllocateString2  ENDP

wAllocateArray  PROC    FAR
           push si
           lea si,Value
           call output_str
           lea si,sAllocateArray
           call output_str
           pop si
           ret
wAllocateArray  ENDP
wAllocateArray2  PROC    FAR
           lea si,sAllocateArray2
           call output_str
           ret
wAllocateArray2  ENDP

wLoop   PROC   FAR
            push  si
            lea   si,sLoop
            call  output_str
            pop   si
            call  output_str
            call  wNewLine
            ret
wLoop   ENDP

wBranchFalse  PROC    FAR
           push si
           lea  si,sBranchFalse1
           call output_str
           call wNewLine
           lea  si,sBranchFalse2
           call output_str
           pop  si
           call output_str
           call wNewLine
           push si
           lea  si,sBranchFalse3
           call output_str
           pop  si
           call output_str
           call wNewLine
           push si
           lea  si,sBranchFalse4
           call output_str
           pop  si
           call output_str
           push ax
           mov al,':'
           call output_char
           pop ax
           call wNewLine
           ret
wBranchFalse  ENDP

wBranch  PROC    FAR
           push si
           lea  si,sBranch
           call output_str
           pop  si
           push si
           call output_str
           call wNewLine
           pop  si
           ret
wBranch  ENDP

wPostLabel  PROC    FAR
           call output_str
           push ax
           mov  al,':'
           call output_char
           call wNewLine
           pop  ax
           ret
wPostLabel  ENDP

wPush   PROC    FAR
            push  ax
            lea si,sPush
            call output_str
            pop   ax
            ret
wPush   ENDP

wPopAdd   PROC    FAR
            lea si,sPopBX
            call output_str
            lea si,sPopAdd
            call output_str
            ret
wPopAdd   ENDP

wPopSub   PROC    FAR
            lea si,sPopBX
            call output_str
            lea si,sPopSub
            call output_str
            ret
wPopSub   ENDP

wPopMul   PROC    FAR
            lea si,sPopBX
            call output_str
            lea si,sPopMul
            call output_str
            ret
wPopMul   ENDP

wPopDiv   PROC    FAR
            lea si,sPopDiv
            call output_str
            ret
wPopDiv   ENDP

wPopAnd   PROC    FAR
            lea si,sPopBX
            call output_str
            lea si,sPopAnd
            call output_str
            ret
wPopAnd   ENDP

wPopOr   PROC    FAR
            lea si,sPopBX
            call output_str
            lea si,sPopOr
            call output_str
            ret
wPopOr   ENDP

wPopXOr   PROC    FAR
            lea si,sPopBX
            call output_str
            lea si,sPopXOr
            call output_str
            ret
wPopXOr   ENDP

wPopCompare   PROC    FAR
            lea si,sPopBX
            call output_str
            lea si,sPopCompare
            call output_str
            ret
wPopCompare   ENDP

wSetEqual   PROC    FAR
            lea si,sSetEqual
            call output_str
            ret
wSetEqual   ENDP

wSetNEqual   PROC    FAR
            lea si,sSetNEqual
            call output_str
            ret
wSetNEqual   ENDP

wSetGreater   PROC    FAR
            lea si,sSetGreater
            call output_str
            ret
wSetGreater   ENDP

wSetLess   PROC    FAR
            lea si,sSetLess
            call output_str
            ret
wSetLess   ENDP

wSetLessOrEqual   PROC    FAR
            lea si,sSetLessOrEqual
            call output_str
            ret
wSetLessOrEqual   ENDP

wSetGreaterOrEqual   PROC    FAR
            lea si,sSetGreaterOrEqual
            call output_str
            ret
wSetGreaterOrEqual   ENDP




wClear   PROC    FAR
            lea si,sClear
            call output_str
            ret
wClear   ENDP

wNotIt   PROC    FAR
            lea si,sNotIt
            ret
wNotIt   ENDP

wStore    PROC    FAR
            push si
            lea si,sMOV
            call output_str
            pop si
            call output_str
            lea si,sStore2
            call output_str
            call wNewLine
            ret
wStore    ENDP

wStoreArray    PROC    FAR
            push si
            lea si,sStoreArray1
            call output_str
            cmp bx,0
            jne wStoreArraySkip
            lea si,sStoreArray1BIS
            call output_str            
wStoreArraySkip:
            lea si,sMOV
            call output_str
            pop si
            call output_str
            lea si,sStoreArray2
            call output_str
            ret
wStoreArray    ENDP

wLoadVar        PROC    FAR
           call far ptr pInTable
           cmp  cx,0
           jne  wLoadVarSkip
           call ErrUndefined
wLoadVarSkip:
            push si
            lea si,sLoadVar
            call output_str
            pop  si
            call output_str
            call wNewLine
            ret
wLoadVar        ENDP

wLoadArray        PROC    FAR
           call far ptr pInTable
           cmp  cx,0
           jne  wLoadArraySkip
           call ErrUndefined
wLoadArraySkip:
            push si
            lea si,sLoadArray
            call output_str
            pop  si
            call output_str
            lea si,sLoadArrayBX
            call output_str
            ret
wLoadArray        ENDP

wLoadConst        PROC    FAR
            push si
            lea si,sLoadVar
            call output_str
            pop  si
            call output_str
            call wNewLine
            ret
wLoadConst        ENDP

wWriteString    PROC    FAR
            lea di,Value
            lea si,sWriteString1
            call output_str
            xchg di,si
            call output_str
            call wNewLine
            lea si,sWriteString2
            call output_str
            ret
wWriteString    ENDP

wINSTRS      ENDS