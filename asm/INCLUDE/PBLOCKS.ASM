;=============================================================================
; TUTTE LE PROCEDURE PER IL RILEVAMENTO DEI BLOCCHI DI CODICE OPERATIVO
;=============================================================================
pBlocksS    SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:pBlocksS
;=============================================================================
; BLOCCHI GENERICI PER ESPRESSIONI RELAZIONALI (= > < )
;=============================================================================
;
; Get Another Expression and Compare
;
pCompareExpression   PROC    FAR
            call far ptr pExpression    ;analizzo l'espressione successiva
            call wPopCompare            ;e la confronto con la precendente
            ret                         ;salvata nel registro principale
pCompareExpression   ENDP
;
; Get The Next Expression and Compare
;
pNextExpression   PROC    FAR
            call pNext
            call pCompareExpression
            ret
pNextExpression   ENDP
;
; Recognize and Translate a Relational "Equals"
;
pEqual   PROC    FAR
            call pNextExpression
            call wSetEqual
            ret
pEqual   ENDP
;
; Recognize and Translate a Relational "NOT Equals"
;
pNotEqual   PROC    FAR
            call pNextExpression
            call wSetNEqual
            ret
pNotEqual   ENDP
;
; Recognize and Translate a Relational "Less OR Equals"
;
pLessOrEqual   PROC    FAR
            call pNextExpression
            call wSetLessOrEqual
            ret
pLessOrEqual   ENDP
;
; Recognize and Translate a Relational "Less"
;
pLess   PROC    FAR
            call pNext
            mov  al,Token            ;CASE OF:
            cmp  al,'='              ;controllo se è un <=
                jne  pLessSkip1
                call pLessOrEqual
                jmp  pLessEND
pLessSkip1:
            cmp  al,'>'              ;controllo se è un <>
                jne  pLessELSE
                call pNotEqual
                jmp  pLessEND
pLessELSE:
            call pCompareExpression
            call wSetLess
pLessEND:
            ret
pLess   ENDP
;
; Recognize and Translate a Relational "Greater"
;
pGreater   PROC    FAR
            call pNext
            mov  al,Token
            cmp  al,'='              ;controllo se è un >=
                jne  pGreaterELSE
                call pNextExpression
                call wSetGreaterOrEqual
                jmp  pGreaterEND
pGreaterELSE:
                call pCompareExpression
                call wSetGreater
pGreaterEND:
            ret
pGreater   ENDP
;
; Parse and Translate a Relation
;
pRelation   PROC    FAR
            call far ptr pExpression
            mov al,Token
            call isRelop           ;Analizzo una relazione BOOLEANA
            jnz pRelationEND       ;confrontando tra loro
            call wPush             ;due espressioni
            cmp  al,'='            ;CASE OF:
                jne  pRelationSkip1
                call pEqual
                jmp  pRelationEND
pRelationSkip1:
            cmp  al,'<'
                jne  pRelationSkip2
                call pLess
                jmp  pRelationEND
pRelationSkip2:
            cmp  al,'>'
                jne  pRelationEND
                call pGreater
pRelationEND:
            ret
pRelation   ENDP
;=============================================================================
; BLOCCHI PER ESPRESSIONI MATEMATICHE (FATTORI E TERMINI CON OPERANDI VARI)
;=============================================================================
;
; Parse and Translate a Boolean Factor with Leading NOT
;
pNotFactor   PROC    FAR
            mov al,Token
            cmp al,'!'          ;controllo se c'è il simbolo NOT
            jne pNotFactorElse  ;se c'è allora continuo normalmente
            call pNext          ;ad analizzare la relazione
            call pRelation      
            call wNotIt         ;alla fine faccio il NOT del risultato
            jmp  pNotFactorEND
pNotFactorElse:
            call pRelation
pNotFactorEND:
            ret
pNotFactor   ENDP
;
; Parse and Translate a Math Factor
;
pFactor     PROC    FAR
    mov   al,Token              ;ANALIZZO UN FATTORE MATEMATICO
    cmp   al,'('                ;se trovo una parentesi
    jne   pFactorElse1          ;continuo l'analisi...
        call  pNext
        call  far ptr  pBoolExpression
        lea   si,sParentChiusa
        call  pMatchString_nx   ;...e mi aspetto una parentesi di chiusura
        jmp   pFactorEND
pFactorElse1:
mov   al,Token
        cmp   al,'x'            ;se il fattore è una variabile
        jne   pFactorElse2
            lea   si,Value
            call  PushString
            call  pNext
            mov   al,Token
            cmp   al,'['        ;controllo se è un array
            je   pFactorElse3
                lea    si,TmpValue
                call   PopString
                mov    di,si
                call   wLoadVar
                jmp    pFactorEND
        pFactorElse3:
                call   pNext    ;analizzo il contenuto dell'indice
                call   far ptr pBoolExpression  ;dell'array
                lea    si,sQuadChiusa
                call   pMatchString_nx
                lea    si,TmpValue
                call   PopString
                mov    di,si
                call   wLoadArray
                jmp    pFactorEND
    pFactorElse2:
            mov  al,Token
            cmp  al,'#'         ;se il fattore è un numero
            jne  pFactorElse4
                lea  si,Value
                call wLoadConst ;lo carico come un immediato
                call pNext
                jmp  pFactorEND
        pFactorElse4:
                lea  si,sMathFactor
                call ErrExpected
pFactorEND:
            ret
pFactor     ENDP
;
; Multiply
;
pMultiply        PROC    FAR
            call pNext
            call pFactor
            call wPopMul
            ret
pMultiply        ENDP
;
; Divide
;
pDivide   PROC    FAR
            call pNext
            call pFactor
            call wPopDiv
            ret
pDivide   ENDP
;
; Parse and Translate a Math Term
;
pTerm   PROC    FAR
            call pFactor
pTermWhile:
            mov  al,Token
            call isMulop                ;analizzo le MOLTIPLICAZIONI
            jnz  pTermEND
                call wPush
                cmp  al,'*'             ;CASE OF:
                   jne  pTermSkip1
                   call pMultiply
                   jmp  pTermWhile
pTermSkip1:
                cmp  al,'/'
                   jne  pTermWhile
                   call pDivide
pTermEND:
            ret
pTerm   ENDP
;
; Addition
;
pAdd        PROC    FAR
            call pNext
            call pTerm
            call wPopAdd
            ret
pAdd        ENDP
;
; Subtraction
;
pSubtract   PROC    FAR
            call pNext
            call pTerm
            call wPopSub
            ret
pSubtract   ENDP
;
; Parse and Translate an Expression
;
pExpression   PROC    FAR
            mov  al,Token
            call isAddop
            jnz  pExpressionElse
            call wClear
            jmp  pExpressionWhile
pExpressionElse:
            call pTerm                 ;recupero un Termine Matematico
pExpressionWhile:
            mov  al,Token
            call isAddop               ;ANALIZZO LE ADDIZIONI
            jnz  pExpressionEND
                call wPush
                cmp  al,'+'            ;CASE OF:
                   jne  pExpressionSkip1
                   call pAdd
                   jmp  pExpressionWhile
pExpressionSkip1:
                cmp  al,'-'
                   jne  pExpressionWhile
                   call pSubtract
pExpressionEND:
            ret
pExpression   ENDP
;=============================================================================
; BLOCCHI PER LE ESPRESSIONI BOOLEANE ( ! & | ~ )
;=============================================================================
;
; analizza un termine booleano
;
pBoolTerm   PROC    FAR
            call pNotFactor
pBoolTermWhile:
            mov  al,Token               ;analizzo un termine BOOLEANO
            cmp  al,'&'
            jne  pBoolTermEND
                call wPush
                call pNext
                call pNotFactor
                call wPopAnd
                jmp  pBoolTermWhile
pBoolTermEND:
            ret
pBoolTerm   ENDP
;
; Recognize and Translate a Boolean OR
;
pBoolOr   PROC    FAR
            call pNext
            call pBoolTerm
            call wPopOr
            ret
pBoolOr   ENDP
;
; Recognize and Translate a Boolean OR
;
pBoolXOr   PROC    FAR
            call pNext
            call pBoolTerm
            call wPopXOr
            ret
pBoolXOr   ENDP
;
; Parse and Translate a Boolean Expression
;
pBoolExpression   PROC    FAR
            call pBoolTerm
pBoolExpressionWhile:
            mov  al,Token
            call isOrOp
            jnz  pBoolExpressionEND     ;ANALIZZO LE ESPRESSIONI BOOLEANE
            call wPush
           cmp  al,'|'                  ;CASE OF:
               jne  pBoolExpressionSkip1
               call pBoolOr
               jmp  pBoolExpressionWhile
pBoolExpressionSkip1:
           cmp  al,'~'
               jne  pBoolExpressionWhile
               call pBoolXor
pBoolExpressionEND:
            ret
pBoolExpression   ENDP
;
; crea una nuova etichetta univoca
;
pNewLabel   PROC    FAR
            push ax
            push si                     ;genero un'etichetta in SI
            mov byte ptr [si],'L'       ;inizia con L
            mov ax,LCount
            inc si
            mov [si],al
            add byte ptr [si],48        ;segue con un numero univoco...
            inc si
            mov byte ptr [si],0
            pop si
            pop ax
            inc LCount                  ;...che viene incrementato
            ret
pNewLabel   ENDP
;=============================================================================
; BLOCCHI PER I COSTRUTTI DI LINGUAGGIO
;=============================================================================
;
; rileva e analizza un blocco IF ELSE ENDIF
;
pDoIf       PROC    FAR
            call  pNext
            call  pBoolExpression       ;ANALIZZO L'ESPRESSIONE BOOLEANA DELL'IF
            lea   si,sLabel1
            call  pNewLabel             ;genero la prima etichetta
            call  PushString            ;push Label1
            lea   si,sLabel2
            dec   LCount
            call  pNewLabel             ;genero la seconda etichetta uguale alla prima
            call  PushString            ;push Label2
            call  wBranchFalse
            call  far ptr pBlock_nx     ;ANALIZZO IL BLOCCO DI CODICE DELL' IF
            mov   al,Token
            cmp   al,'l'                ;cerco il token ELSE
            jne   pDoIfSkip
            call  pNext
            lea   si,sLabel2
            call  PopString             ;pop Label2: elimino
            call  pNewLabel             ;NEW Label2
            call  wBranch
            lea   si,sLabel1
            call  PopString             ;pop Label1
            call  PushString            ;push Label1
            lea   si,sLabel2
            call  PushString            ;push Label2
            call  wPostLabel
            call  far ptr pBlock_nx     ;ANALIZZO IL BLOCCO DI CODICE DELL'ELSE
pDoIfSkip:
            lea   si,sLabel2
            call  PopString             ;pop Label2
            call  wPostLabel
            lea   si,sLabel1
            call  PopString             ;pop Label1: elimino
            lea   si,sENDIF             ;CHIUDO L'IF
            call  pMatchString_nx
            ret
pDoIf       ENDP
;
; rileva e analizza un blocco WHILE ENDWHILE
;
pDoWhile    PROC    FAR
            call  pNext
            lea   si,sLabel2
            call  pNewLabel             ;genero la prima etichetta
            call  PushString            ;push Label2
            lea   si,sLabel1
            call  pNewLabel             ;genero la seconda etichetta
            call  PushString            ;push Label1
            call  wPostLabel            ;stampo l'etichetta
            lea   si,sLabel2
            call  PushString            ;push Label2
            call  pBoolExpression       ;ANALIZZO L'ESPRESSIONE BOOLEANA DEL WHILE
            lea   si,sLabel2
            call  PopString             ;pop Label2
            call  wBranchFalse
            call  far ptr pBlock_nx     ;ANALIZZO IL BLOCCO DI CODICE
            lea   si,sENDWHILE          ;controllo la chiusura del blocco WHILE
            call  pMatchString_nx
            lea   si,sLabel1
            call  PopString             ;pop Label1
            call  wBranch               ;stampo il ritorno all'inizio del WHILE
            lea   si,sLabel2
            call  PopString             ;pop Label2
            call  wPostLabel
            ret
pDoWhile    ENDP
;
; rileva e analizza un blocco LOOP ENDLOOP
;
pDoLoop     PROC    FAR
            call  pNext
            call  pBoolExpression       ;ANALIZZO L'ESPRESSIONE BOOLEANA
            lea   si,sCX                ;salvo in CX
            call  wStore
            lea   si,sLabel1
            call  pNewLabel
            call  PushString            ;push Label1
            call  wPostLabel
            call  far ptr pBlock_nx     ;ANALIZZO IL BLOCCO DI CODICE
            lea   si,sENDLOOP
            call  pMatchString_nx
            lea   si,sLabel1
            call  PopString             ;pop Label1
            call  wLoop
            ret
pDoLoop     ENDP
;=============================================================================
; BLOCCHI PER L'INPUT/OUTPUT NATIVO
;=============================================================================
;
; Read a Single Variabl
; Questa procedura scrive il codice necessario alla lettura di una var.
;
pReadVar     PROC    FAR
           ;CHECKIDENT
           lea  si,Value
           call PushString
           mov  al,Token
           cmp  al,'x'
           je   pReadVarSkip1
           lea  si,sVariableName
           call ErrExpected
pReadVarSkip1:
           lea  di,Value
           call pInTable
           cmp  cx,0
           jne  pReadVarSkip2
           call ErrUndefined
pReadVarSkip2:
           ;ReadIt
           lea  si,sChar_In
           call output_str
           call pNext
           mov  al,Token
           cmp  al,'['
           jne  pReadVarNoArray
;array implementation
           call wPush
           call pNext
           call pBoolExpression
           lea  si,sQuadChiusa
           call pMatchString_nx
           call wPush
           lea  si,TmpValue
           call PopString
           mov  bx,0
           call wStoreArray
           jmp  pReadVarEND
pReadVarNoArray:
           lea  si,TmpValue
           call PopString
           call wStore
pReadVarEND:
            ret
pReadVar     ENDP
;
; Read an Integer Variable
;
pReadIntVar     PROC    FAR
           ;CHECKIDENT
           lea  si,Value
           call PushString
           mov  al,Token
           cmp  al,'x'
           je   pReadIntVarSkip1
           lea  si,sVariableName
           call ErrExpected
pReadIntVarSkip1:
           lea di,Value
           call pInTable
           cmp  cx,0
           jne  pReadIntVarSkip2
           call ErrUndefined
pReadIntVarSkip2:
           ;ReadIt
           lea  si,sReadInteger
           call output_str
           call pNext
           mov  al,Token
           cmp  al,'['
           jne  pReadIntVarNoArray
;array implementation
           call wPush
           call pNext
           call pBoolExpression
           lea  si,sQuadChiusa
           call pMatchString_nx
           call wPush
           lea  si,TmpValue
           call PopString
           mov  bx,0
           call wStoreArray
           jmp  pReadVarEND
pReadIntVarNoArray:
           lea  si,TmpValue
           call PopString
           call wStore
pReadIntVarEND:
            ret
pReadIntVar     ENDP
;
; rileva e analizza l'istruzione READ(char)
;
pDoRead     PROC    FAR
            call  pNext
            lea   si,sParentAperta
            call  pMatchString_nx
pDoReadWhile:
            call  pReadVar
            mov   al,Token
            cmp   al,','
            jne   pDoReadFinish
                call pNext
            jmp   pDoReadWhile
pDoReadFinish:
            lea   si,sParentChiusa
            call  pMatchString_nx
            ret
pDoRead     ENDP
;
; rileva e analizza l'istruzione WRITE(char)
;
pDoWrite     PROC    FAR
            call  pNext
            lea   si,sParentAperta
            call  pMatchString_nx
pDoWriteWhile:
            call  pExpression
            lea   si,sChar_Out
            call  output_str
            mov   al,Token
            cmp   al,','
            jne   pDoWriteFinish
                call pNext
            jmp   pDoWriteWhile
pDoWriteFinish:
            lea   si,sParentChiusa
            call  pMatchString_nx
            ret
pDoWrite     ENDP
;
; rileva e analizza l'istruzione READINT(int)
;
pDoReadInt     PROC    FAR
            call  pNext
            lea   si,sParentAperta
            call  pMatchString_nx
pDoReadIntWhile:
            call  pReadIntVar
            mov   al,Token
            cmp   al,','
            jne   pDoReadIntFinish
                call pNext
            jmp   pDoReadIntWhile
pDoReadIntFinish:
            lea   si,sParentChiusa
            call  pMatchString_nx
            ret
pDoReadInt     ENDP
;
; rileva e analizza l'istruzione WRITEINT(int)
;
pDoWriteInt     PROC    FAR
            call  pNext
            lea   si,sParentAperta
            call  pMatchString_nx
pDoWriteIntWhile:
            call  pExpression
            lea   si,sWriteInteger
            call  output_str
            mov   al,Token
            cmp   al,','
            jne   pDoWriteIntFinish
                call pNext
            jmp   pDoWriteIntWhile
pDoWriteIntFinish:
            lea   si,sParentChiusa
            call  pMatchString_nx
            ret
pDoWriteInt     ENDP
;
; rileva e analizza l'istruzione WRITESTR($string)
;
pDoWriteString     PROC    FAR
            call  pNext
            lea   si,sParentAperta
            call  pMatchString_nx
pDoWriteStrWhile:
            mov   al,Token
            cmp   al,'$'
            je    pDoWriteStrSkip
            lea   si,sStringIdent
            call  ErrExpected
pDoWriteStrSkip:
            call  wWriteString
            mov   al,Token
            cmp   al,','
            jne   pDoWriteStrFinish
                call pNext
            jmp   pDoWriteStrWhile
pDoWriteStrFinish:
            call  pNext
            lea   si,sParentChiusa
            call  pMatchString_nx
            ret
pDoWriteString     ENDP
;
; rileva e analizza un blocco MASM ENDMASM
;
pDoMasm     PROC    FAR
            lea si,sMASMcomment1
            call  output_str
pDoMasmWhile1:
            call  pNext
            call  pScan
            mov al,Token
            cmp   al,'M'
            je    pDoMasmFinish
            lea   si,Value
            call  output_str
            mov   al,' '
            call  output_char
        pDoMasmWhile2:
                mov   al,Look
                cmp   al,CR
                je    pDoMasmSkipWhile2
                call  pGetChar
                call  output_char
                jmp   pDoMasmWhile2
pDoMasmSkipWhile2:
            mov   al,LF
            call  output_char
            jmp   pDoMasmWhile1
pDoMasmFinish:
            lea si,sMASMcomment2
            call  output_str
            call  pNext
            ret
pDoMasm     ENDP
;
; rileva la procedura NEWLINE
;
pDoNewLine     PROC    FAR
            lea   si,sNewLine
            call  output_str
            call  pNext
            ret
pDoNewLine     ENDP
;=============================================================================
; GESTIONE DELLE ASSEGNAZIONI
;=============================================================================
;
; Parse and Translate an Assignment Statement
;
pAssignment     PROC    FAR
            lea  di,Value
            call pInTable
            cmp  cx,0
            jne  pAssignmentSkip1
            call ErrUndefined
pAssignmentSkip1:
            lea  si,Value
            call PushString             ;push Operand Value
            call pNext
            mov  al,Token
            mov  bx,0
            cmp  al,'['                 ;controlla se è un array
            jne  pAssignmentSkipArray
;array implementation
            call pNext
            call pBoolExpression        ;calcola l'indice dell'array
            lea  si,sQuadChiusa
            call pMatchString_nx
            call wPush
            mov  bx,1
pAssignmentSkipArray:
            push bx
            lea  si,sUguale             ;trova il simbolo =
            call pMatchString_nx
            call pBoolExpression
            pop  bx
            lea  si,TmpValue
            call PopString              ;pop Operand
            cmp  bx,1
            jne  pAssignmentSkipStoreArray
            call wStoreArray
            jmp pAssignmentEND
pAssignmentSkipStoreArray:
            call wStore
pAssignmentEND:
            ret
pAssignment     ENDP
;=============================================================================
; BLOCCO PRINCIPALE, SMISTA IL LAVORO ALLE VARIE PROCEDURE A SECONDA DEL TOKEN
;=============================================================================
;
; rileva e analizza il blocco di istruzioni successivo 
;
pBlock_nx   PROC    FAR
pBlockWhile:
           mov al,Look
           call pScan
           mov  al,Token
           call isEndBlock
           jnz   pBlockSkipGOTOend      ;devo fare il salto
           jmp pBlockEND                ;di più di 128 byte
pBlockSkipGOTOend:                      ;CASE OF:
           cmp  al,'i'
               jne  pBLockSkip1
               call pDoIf
               jmp  pBlockFINISH
pBLockSkip1:
           cmp  al,'w'
               jne  pBLockSkip2
               call pDoWhile
               jmp  pBlockFINISH
pBLockSkip2:
           cmp  al,'L'
               jne  pBLockSkip3
               call pDoLoop
               jmp  pBlockFINISH
pBLockSkip3:
           cmp  al,'R'
               jne  pBLockSkip4
               call pDoRead
               jmp  pBlockFINISH
pBLockSkip4:
           cmp  al,'W'
               jne  pBLockSkip5
               call pDoWrite
               jmp  pBlockFINISH
pBLockSkip5:
           cmp  al,'I'
               jne  pBLockSkip6
               call pDoWriteInt
               jmp  pBlockFINISH
pBLockSkip6:
           cmp  al,'J'
               jne  pBLockSkip7
               call pDoReadInt
               jmp  pBlockFINISH
pBLockSkip7:
           cmp  al,'§'
               jne  pBLockSkip8
               call pDoWriteString
               jmp  pBlockFINISH
pBLockSkip8:
           cmp  al,'m'
               jne  pBLockSkip9
               call pDoMasm
               jmp  pBlockFINISH
pBLockSkip9:
           cmp  al,'N'
               jne  pBLockSkip10
               call pDoNewLine
               jmp  pBlockFINISH
pBLockSkip10:
               ;else
               call pAssignment
pBlockFINISH:
           jmp  pBlockWhile
pBlockEND:
           ret
pBlock_nx   ENDP
;
pBlocksS  ENDS 