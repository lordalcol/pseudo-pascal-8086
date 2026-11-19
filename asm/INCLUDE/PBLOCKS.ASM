;=============================================================================
; THE PARSER: one procedure per grammar rule, calling each other
; recursively, and calling the code generator as they go.
;
;   <bool_expr>   ::= <bool_term> (('|' | '~') <bool_term>)*
;   <bool_term>   ::= <not_factor> ('&' <not_factor>)*
;   <not_factor>  ::= ['!'] <relation>
;   <relation>    ::= <expression> [<relop> <expression>]
;   <expression>  ::= [<addop>] <term> (<addop> <term>)*
;   <term>        ::= <factor> (<mulop> <factor>)*
;   <factor>      ::= <number> | 'c' | <variable> | <array> '[' <bool_expr> ']'
;                   | '(' <bool_expr> ')'
;=============================================================================
pBlocksS    SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:pBlocksS
;=============================================================================
; RELATIONS (= <> < > <= >=)
;=============================================================================
;
; Parses the right-hand expression and compares it with the saved left one
;
pCompareExpression   PROC    FAR
            call far ptr pExpression
            call wPopCompare
            ret
pCompareExpression   ENDP
;
; Skips the second character of the operator, then as above
;
pNextExpression   PROC    FAR
            call pNext
            call pCompareExpression
            ret
pNextExpression   ENDP
;
pEqual   PROC    FAR
            call pNextExpression
            call wSetEqual
            ret
pEqual   ENDP
;
pNotEqual   PROC    FAR
            call pNextExpression
            call wSetNEqual
            ret
pNotEqual   ENDP
;
pLessOrEqual   PROC    FAR
            call pNextExpression
            call wSetLessOrEqual
            ret
pLessOrEqual   ENDP
;
; < can start <, <= or <>
;
pLess   PROC    FAR
            call pNext
            mov  al,Token
            cmp  al,'='              ;<=
                jne  pLessSkip1
                call pLessOrEqual
                jmp  pLessEND
pLessSkip1:
            cmp  al,'>'              ;<>
                jne  pLessELSE
                call pNotEqual
                jmp  pLessEND
pLessELSE:
            call pCompareExpression  ;<
            call wSetLess
pLessEND:
            ret
pLess   ENDP
;
; > can start > or >=
;
pGreater   PROC    FAR
            call pNext
            mov  al,Token
            cmp  al,'='              ;>=
                jne  pGreaterELSE
                call pNextExpression
                call wSetGreaterOrEqual
                jmp  pGreaterEND
pGreaterELSE:
                call pCompareExpression  ;>
                call wSetGreater
pGreaterEND:
            ret
pGreater   ENDP
;
; <relation> ::= <expression> [<relop> <expression>]
;
pRelation   PROC    FAR
            call far ptr pExpression
            mov al,Token
            call isRelop
            jnz pRelationEND
            call wPush             ;save the left side
            cmp  al,'='
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
; ARITHMETIC EXPRESSIONS
;=============================================================================
;
; <not_factor> ::= ['!'] <relation>
;
pNotFactor   PROC    FAR
            mov al,Token
            cmp al,'!'
            jne pNotFactorElse
            call pNext
            call pRelation
            call wNotIt
            jmp  pNotFactorEND
pNotFactorElse:
            call pRelation
pNotFactorEND:
            ret
pNotFactor   ENDP
;
; <factor>: a parenthesis, a variable, an array element or a constant
;
pFactor     PROC    FAR
    mov   al,Token
    cmp   al,'('                ;( <bool_expr> )
    jne   pFactorElse1
        call  pNext
        call  far ptr  pBoolExpression
        lea   si,sParentChiusa
        call  pMatchString_nx
        jmp   pFactorEND
pFactorElse1:
mov   al,Token
        cmp   al,'x'            ;variable or array
        jne   pFactorElse2
            lea   si,Value
            call  PushString    ;keep the name while looking ahead
            call  pNext
            mov   al,Token
            cmp   al,'['
            je   pFactorElse3
                lea    si,TmpValue      ;variable
                call   PopString
                mov    di,si
                call   wLoadVar
                jmp    pFactorEND
        pFactorElse3:
                call   pNext            ;array: compute the index
                call   far ptr pBoolExpression
                lea    si,sQuadChiusa
                call   pMatchString_nx
                lea    si,TmpValue
                call   PopString
                mov    di,si
                call   wLoadArray
                jmp    pFactorEND
    pFactorElse2:
            mov  al,Token
            cmp  al,'#'         ;number or character constant
            jne  pFactorElse4
                lea  si,Value
                call wLoadConst
                call pNext
                jmp  pFactorEND
        pFactorElse4:
                lea  si,sMathFactor
                call ErrExpected
pFactorEND:
            ret
pFactor     ENDP
;
pMultiply        PROC    FAR
            call pNext
            call pFactor
            call wPopMul
            ret
pMultiply        ENDP
;
pDivide   PROC    FAR
            call pNext
            call pFactor
            call wPopDiv
            ret
pDivide   ENDP
;
; <term> ::= <factor> (<mulop> <factor>)*
;
pTerm   PROC    FAR
            call pFactor
pTermWhile:
            mov  al,Token
            call isMulop
            jnz  pTermEND
                call wPush
                cmp  al,'*'
                   jne  pTermSkip1
                   call pMultiply
                   jmp  pTermWhile
pTermSkip1:
                cmp  al,'/'
                   jne  pTermWhile
                   call pDivide
                   jmp  pTermWhile
pTermEND:
            ret
pTerm   ENDP
;
pAdd        PROC    FAR
            call pNext
            call pTerm
            call wPopAdd
            ret
pAdd        ENDP
;
pSubtract   PROC    FAR
            call pNext
            call pTerm
            call wPopSub
            ret
pSubtract   ENDP
;
; <expression> ::= [<addop>] <term> (<addop> <term>)*
; A leading sign works as 0 + term or 0 - term
;
pExpression   PROC    FAR
            mov  al,Token
            call isAddop
            jnz  pExpressionElse
            call wClear
            jmp  pExpressionWhile
pExpressionElse:
            call pTerm
pExpressionWhile:
            mov  al,Token
            call isAddop
            jnz  pExpressionEND
                call wPush
                cmp  al,'+'
                   jne  pExpressionSkip1
                   call pAdd
                   jmp  pExpressionWhile
pExpressionSkip1:
                cmp  al,'-'
                   jne  pExpressionWhile
                   call pSubtract
                   jmp  pExpressionWhile
pExpressionEND:
            ret
pExpression   ENDP
;=============================================================================
; BOOLEAN EXPRESSIONS ( ! & | ~ )
;=============================================================================
;
; <bool_term> ::= <not_factor> ('&' <not_factor>)*
;
pBoolTerm   PROC    FAR
            call pNotFactor
pBoolTermWhile:
            mov  al,Token
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
pBoolOr   PROC    FAR
            call pNext
            call pBoolTerm
            call wPopOr
            ret
pBoolOr   ENDP
;
pBoolXOr   PROC    FAR
            call pNext
            call pBoolTerm
            call wPopXOr
            ret
pBoolXOr   ENDP
;
; <bool_expr> ::= <bool_term> (('|' | '~') <bool_term>)*
;
pBoolExpression   PROC    FAR
            call pBoolTerm
pBoolExpressionWhile:
            mov  al,Token
            call isOrOp
            jnz  pBoolExpressionEND
            call wPush
           cmp  al,'|'
               jne  pBoolExpressionSkip1
               call pBoolOr
               jmp  pBoolExpressionWhile
pBoolExpressionSkip1:
           cmp  al,'~'
               jne  pBoolExpressionWhile
               call pBoolXor
               jmp  pBoolExpressionWhile
pBoolExpressionEND:
            ret
pBoolExpression   ENDP
;
; Writes a new label "Ln" at SI, n = LCount, and increments LCount
;
pNewLabel   PROC    FAR
            push ax
            push bx
            push cx
            push dx
            push di
            mov  di,si
            mov  byte ptr [di],'L'
            inc  di
            mov  ax,LCount
            mov  bx,10
            xor  cx,cx
pNewLabelDiv:
            xor  dx,dx                  ;digits come out last to first
            div  bx
            push dx
            inc  cx
            test ax,ax
            jnz  pNewLabelDiv
pNewLabelPut:
            pop  dx
            add  dl,'0'
            mov  [di],dl
            inc  di
            loop pNewLabelPut
            mov  byte ptr [di],0
            pop  di
            pop  dx
            pop  cx
            pop  bx
            pop  ax
            inc LCount
            ret
pNewLabel   ENDP
;=============================================================================
; CONTROL STRUCTURES
;=============================================================================
;
; IF <bool_expr> <block> [ELSE <block>] ENDIF
;
pDoIf       PROC    FAR
            call  pNext
            call  pBoolExpression       ;the condition
            lea   si,sLabel1
            call  pNewLabel             ;Label1
            call  PushString
            lea   si,sLabel2
            dec   LCount
            call  pNewLabel             ;Label2 = Label1
            call  PushString
            call  wBranchFalse          ;if false, go to Label2
            call  far ptr pBlock_nx     ;THEN block
            mov   al,Token
            cmp   al,'l'                ;ELSE?
            jne   pDoIfSkip
            call  pNext
            lea   si,sLabel2
            call  PopString             ;drop Label2
            call  pNewLabel             ;new Label2: the end of the IF
            call  wBranch               ;THEN block jumps to the end
            lea   si,sLabel1
            call  PopString
            call  PushString
            lea   si,sLabel2
            call  PushString
            lea   si,sLabel1
            call  wPostLabel            ;ELSE starts at Label1
            call  far ptr pBlock_nx     ;ELSE block
pDoIfSkip:
            lea   si,sLabel2
            call  PopString
            call  wPostLabel            ;Label2:
            lea   si,sLabel1
            call  PopString
            lea   si,sENDIF
            call  pMatchString_nx
            ret
pDoIf       ENDP
;
; WHILE <bool_expr> <block> ENDWHILE
;
pDoWhile    PROC    FAR
            call  pNext
            lea   si,sLabel2
            call  pNewLabel             ;Label2: after the loop
            call  PushString
            lea   si,sLabel1
            call  pNewLabel             ;Label1: the test
            call  PushString
            call  wPostLabel
            lea   si,sLabel2
            call  PushString
            call  pBoolExpression       ;the condition
            lea   si,sLabel2
            call  PopString
            call  wBranchFalse          ;if false, leave
            call  far ptr pBlock_nx     ;the body
            lea   si,sENDWHILE
            call  pMatchString_nx
            lea   si,sLabel1
            call  PopString
            call  wBranch               ;back to the test
            lea   si,sLabel2
            call  PopString
            call  wPostLabel
            ret
pDoWhile    ENDP
;
; LOOP <count> <block> ENDLOOP: runs the block <count> times with the 8086
; LOOP instruction (CX), so the block must not change CX
;
pDoLoop     PROC    FAR
            call  pNext
            call  pBoolExpression       ;the count...
            lea   si,sCX                ;...into CX
            call  wStore
            lea   si,sLabel1
            call  pNewLabel
            call  PushString
            call  wPostLabel
            call  far ptr pBlock_nx     ;the body
            lea   si,sENDLOOP
            call  pMatchString_nx
            lea   si,sLabel1
            call  PopString
            call  wLoop
            ret
pDoLoop     ENDP
;=============================================================================
; BUILT-IN INPUT/OUTPUT
;=============================================================================
;
; Reads a character into a variable or array element
;
pReadVar     PROC    FAR
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
           lea  si,sChar_In
           call output_str
           call pNext
           mov  al,Token
           cmp  al,'['
           jne  pReadVarNoArray
           call wPush           ;array: save the character, compute the index
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
; Reads an integer into a variable or array element
;
pReadIntVar     PROC    FAR
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
           lea  si,sReadInteger
           call output_str
           call pNext
           mov  al,Token
           cmp  al,'['
           jne  pReadIntVarNoArray
           call wPush           ;array: save the number, compute the index
           call pNext
           call pBoolExpression
           lea  si,sQuadChiusa
           call pMatchString_nx
           call wPush
           lea  si,TmpValue
           call PopString
           mov  bx,0
           call wStoreArray
           jmp  pReadIntVarEND
pReadIntVarNoArray:
           lea  si,TmpValue
           call PopString
           call wStore
pReadIntVarEND:
            ret
pReadIntVar     ENDP
;
; READ(v1, v2, ...): reads characters
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
; WRITE(e1, e2, ...): writes characters
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
; READINT(v1, v2, ...): reads integers
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
; WRITEINT(e1, e2, ...): writes integers
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
; WRITESTR($s1, $s2, ...): writes string constants
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
            call  pNext
            mov   al,Token
            cmp   al,','
            jne   pDoWriteStrFinish
                call pNext
            jmp   pDoWriteStrWhile
pDoWriteStrFinish:
            lea   si,sParentChiusa
            call  pMatchString_nx
            ret
pDoWriteString     ENDP
;
; MASM ... ENDMASM: copies the lines in between to the output as they are.
; The first word of each line comes through the scanner, so it is in upper
; case, and lines that start with a comment are dropped.
;
pDoMasm     PROC    FAR
            lea si,sMASMcomment1
            call  output_str
pDoMasmWhile1:
            call  pNext
            call  pScan
            mov al,Token
            cmp   al,'M'                ;ENDMASM
            je    pDoMasmFinish
            cmp   al,EOFCHR
            jne   pDoMasmLine
            lea   si,sENDMASM
            call  ErrExpected
pDoMasmLine:
            lea   si,Value
            call  output_str
            mov   al,' '
            call  output_char
        pDoMasmWhile2:                  ;the rest of the line
                mov   al,Look
                cmp   al,CR
                je    pDoMasmSkipWhile2
                cmp   al,EOFCHR
                je    pDoMasmSkipWhile2
                call  pGetChar
                cmp   al,CR
                je    pDoMasmSkipWhile2
                cmp   al,LF
                je    pDoMasmWhile2
                cmp   al,EOFCHR
                je    pDoMasmSkipWhile2
                call  output_char
                jmp   pDoMasmWhile2
pDoMasmSkipWhile2:
            call  wNewLine
            jmp   pDoMasmWhile1
pDoMasmFinish:
            lea si,sMASMcomment2
            call  output_str
            call  pNext
            ret
pDoMasm     ENDP
;
; NEWLINE
;
pDoNewLine     PROC    FAR
            lea   si,sNewLine
            call  output_str
            call  pNext
            ret
pDoNewLine     ENDP
;=============================================================================
; ASSIGNMENT
;=============================================================================
;
; <variable> ['[' <bool_expr> ']'] '=' <bool_expr>
;
pAssignment     PROC    FAR
            lea  di,Value
            call pInTable
            cmp  cx,0
            jne  pAssignmentSkip1
            call ErrUndefined
pAssignmentSkip1:
            lea  si,Value
            call PushString             ;keep the name
            call pNext
            mov  al,Token
            mov  bx,0
            cmp  al,'['                 ;array element?
            jne  pAssignmentSkipArray
            call pNext
            call pBoolExpression        ;the index
            lea  si,sQuadChiusa
            call pMatchString_nx
            call wPush
            mov  bx,1
pAssignmentSkipArray:
            push bx
            lea  si,sUguale
            call pMatchString_nx
            call pBoolExpression        ;the value
            pop  bx
            lea  si,TmpValue
            call PopString
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
; BLOCK: statements up to ENDxxx, ELSE or END, each one handed to its
; procedure by its token
;=============================================================================
;
pBlock_nx   PROC    FAR
pBlockWhile:
           mov al,Look
           call pScan
           mov  al,Token
           call isEndBlock
           jnz   pBlockSkipGOTOend      ;(a conditional jump can't reach
           jmp pBlockEND                ; that far)
pBlockSkipGOTOend:
           cmp  al,EOFCHR
               jne  pBLockSkip0
               call ErrEOF
pBLockSkip0:
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
           cmp  al,'S'
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
               call pAssignment         ;anything else is an assignment
pBlockFINISH:
           jmp  pBlockWhile
pBlockEND:
           ret
pBlock_nx   ENDP
;
pBlocksS  ENDS
