;=============================================================================
; GENERAL PROCEDURES: the lexer (scanner), the symbol table, the
; declarations, reserved word lookup, file names and start-up.
;
; The lexer leaves the lexeme of each token in Value and its token type, one
; letter, in Token: 'x' identifier, '#' integer or character literal, '$'
; string constant identifier, a keyword letter from KWcode (after pScan), or
; the operator character itself.
;=============================================================================
pGENERALS    SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:pGENERALS
;
; Skips a comment: everything up to the end of the line
;
pSkipComment   PROC    FAR
pSkCommWhile:
           cmp al,CR
           je   pSkCommEND
           cmp al,EOFCHR
           je   pSkCommEOF
           call pGetChar
           jmp pSkCommWhile
pSkCommEND:
           call pGetChar
pSkCommEOF:
           ret
pSkipComment   ENDP
;
; Skips white space (spaces, tabs, new lines) and comments
;
pSkipWhite_nx   PROC    FAR
pWhiteWhile:
        mov  al,Look
	CALL isWhite
	JNZ pSkipWhiteEND
	CMP al,chrCOMMENT       ;a comment starts with ;
        JNE pSkipNoComment
            call pSkipComment
            JMP pWhiteWhile
pSkipNoComment:
            CALL pGetChar
            JMP pWhiteWhile
pSkipWhiteEND:
           ret
pSkipWhite_nx   ENDP
;
; Scans an identifier into Value, in upper case
;
pGetName   PROC    FAR
           push si
           push bx
           lea bx,Value
           call pSkipWhite_nx
           call isAlpha
           jz   pGetNskipError
           lea  si,sErrIdentifier
           call ErrExpected
pGetNskipError:
           mov Token,'x'
           mov si,0
pGetNrepeat:
           call ToUpper
           cmp si,MaxName       ;keep the first MaxName characters
           jae pGetNskip
           mov [bx][si],al
           inc si
pGetNskip:
           call pGetChar
           call isAlNum         ;go on while alphanumeric
           jz   pGetNrepeat
           mov byte ptr [bx][si],0
           pop bx
           pop si
           ret
pGetName   ENDP
;
; Scans an unsigned integer into Value
;
pGetNum   PROC    FAR
           push si
           push bx
           lea bx,Value
           call pSkipWhite_nx
           call isDigit
           jz   pGetNumskipError
           lea  si,sErrNumber
           call ErrExpected
pGetNumskipError:
           mov Token,'#'
           mov si,0
pGetNumrepeat:
           cmp si,MaxName
           jae pGetNumskip
           mov [bx][si],al
           inc si
pGetNumskip:
           call pGetChar
           call isDigit
           jz pGetNumrepeat
           mov byte ptr [bx][si],0
           pop bx
           pop si
           ret
pGetNum    ENDP
;
; Scans a character constant 'c' into Value, quotes included: MASM takes it
; as is
;
pGetIntChar   PROC    FAR
           push si
           push bx
           lea bx,Value
           call pSkipWhite_nx
           cmp al,"'"
           jz   pGetICskipError
           lea  si,sErrCharIdent
           call ErrExpected
pGetICskipError:
           mov Token,'#'
           mov si,0
           mov [bx][si],al      ;opening '
           inc si
           call pGetChar
           mov [bx][si],al      ;the character
           inc si
           call pGetChar
           cmp al,"'"
           je   pGetICskipError2
           lea  si,sErrCharIdent2
           call ErrExpected
pGetICskipError2:
           mov [bx][si],al      ;closing '
           inc si
           mov byte ptr [bx][si],0
           call pGetChar
           pop bx
           pop si
           ret
pGetIntChar    ENDP
;
; Scans the name of a string constant: $name
;
pGetStringName   PROC    FAR
           push si
           push bx
           lea bx,Value
           cmp  al,'$'
           jz   pGetSskipError
           lea  si,sErrStringIdent
           call ErrExpected
pGetSskipError:
           mov Token,'$'
           mov si,0
pGetSrepeat:
           cmp si,MaxName
           jae pGetSskip
           mov [bx][si],al
           inc si
pGetSskip:
           call pGetChar
           call isAlNum
           jz pGetSrepeat
           mov byte ptr [bx][si],0
           pop bx
           pop si
           ret
pGetStringName    ENDP
;
; Scans an operator: one character, which is also the token
;
pGetOp   PROC    FAR
           call pSkipWhite_nx
           mov Token,al
           lea si,Value
           mov [si],al
           inc si
           mov byte ptr [si],0
           call pGetChar
           ret
pGetOp   ENDP
;
; Scans the next token, choosing by its first character
;
pNext   PROC    FAR
           mov al,Look
           call pSkipWhite_nx
           mov  al,Look
           call IsAlpha
           jnz   pNextSkip1
           call pGetName        ;letter: identifier or keyword
           ret
pNextSkip1:
           call IsDigit
           jnz   pNextSkip2
           call pGetNum         ;digit: number
           ret
pNextSkip2:
           cmp al,"'"
           jnz   pNextSkip3
           call pGetIntChar     ;quote: character constant 'c'
           ret
pNextSkip3:
           cmp al,"$"
           jnz   pNextSkip4
           call pGetStringName  ;$: string constant name
           ret
pNextSkip4:
           cmp al,EOFCHR
           jne   pNextSkip5
           mov Token,al         ;end of file: Token = EOFCHR, Value = ""
           mov Value,0
           ret
pNextSkip5:
           call pGetOp          ;anything else: operator
           ret
pNext   ENDP
;
; Table lookup: finds a string in a list of zero-terminated strings
;       input:  SI -> the list
;               DI -> the string to look for
;               AX = number of strings in the list + 1
;       output: CX = position, 1-based, or 0 if not found
;
pLookup    PROC    FAR
           push bx
           mov  bx,1
pLookupWhile:
           call strcmp
           jz  pLookupEND       ;found
           inc  bx
           cmp  bx,ax           ;end of the list?
           jne  pLookupAvanza
           mov  cx,0            ;not found
           pop  bx
           ret
pLookupAvanza:
           inc  si              ;skip to the next string
           cmp  byte ptr [si],0
           jne  pLookupAvanza
           inc  si
           jmp   pLookupWhile
pLookupEND:
           mov  cx,bx
           pop  bx
           ret
pLookup    ENDP
;
; Looks for the string at DI in the symbol table: CX = 1 if found, else 0
;
pInTable   PROC    FAR
           push ax
           push si
           lea  si,SymbTable+16  ;entry 1
           mov  ax,MaxEntry
pInTableWhile:
           call strcmp
           jz pInTableEqual
           add si,16
           dec ax
           cmp ax,0
           jne pInTableWhile
           mov cx,0
           pop si
           pop ax
           ret
pInTableEqual:
           mov  cx,1
           pop  si
           pop  ax
           ret
pInTable   ENDP
;
; Adds Value to the symbol table, with type Token
;
pAddEntry   PROC    FAR
           push  bx
           lea  di,Value
           call pInTable
           cmp  cx,0
           je  pAddEntrySkipError1
           call ErrDuplicate
pAddEntrySkipError1:
           mov  cx,NEntry
           cmp  cx,MaxEntry
           jne  pAddEntrySkipError2
           call ErrTableFull
pAddEntrySkipError2:
           inc  cx
           mov  NEntry,cx
           mov  bl,Token
           mov  si,cx
           lea  si,SType[si]
           mov  [si],bl         ;SType[NEntry] = Token
           xchg  ax,cx
           mov  bl,16
           mul  bl              ;AX = NEntry * 16
           xchg  ax,cx
           mov  si,cx           ;SymbTable[NEntry] = Value
           lea  si,SymbTable[si]
           lea  di,Value
           call StrCpy
           pop  bx
           ret
pAddEntry   ENDP
;
; Turns an identifier into a keyword token, if it is one
;
pScan      PROC    FAR
           mov al,Token
           cmp al,'x'
           jne pScanEND
           lea si,KWlist
           lea di,Value
           mov ax,NKW
           call pLookup         ;CX = keyword number, 0 if none
           lea  si,KWcode
           add  si,cx
           mov al,[si]          ;Token = KWcode[CX]
           mov Token,al
pScanEND:
           ret
pScan      ENDP
;
;   Declares a variable: name dw 0
;
pAlloc_nx  PROC    FAR
           call pNext
           call pScan
           cmp  al,'x'
           je   pAlloc_START
           lea  si,sVariableName
           call ErrExpected
pAlloc_START:
           mov  bx,'v'
           call pAddEntry
           call wAllocate
           call pNext
           ret
pAlloc_nx  ENDP
;
;   Declares a string constant: $name = "text"  ->  $name db "text",0
;
pAllocString_nx  PROC    FAR
           push bx
           mov  bl,Token
           cmp  bl,'$'
           je   pAllocStrSkip1
           lea  si,sErrString
           call ErrExpected
pAllocStrSkip1:
           mov  bx,'$'
           call pAddEntry
           call wAllocateString
           call pSkipWhite_nx
           mov  al,look
           cmp  al,'='
           je   pAllocStrSkip2
           lea  si,sErrAssignment
           call ErrExpected
pAllocStrSkip2:
           call pGetChar
           call pSkipWhite_nx
           mov  al,look
           cmp  al,'"'
           je   pAllocStrSkip3
           lea  si,sErrString2
           call ErrExpected
pAllocStrSkip3:
           call output_char     ;copy the text, quotes included
pAllocStrContinue:
           call pGetChar
           cmp  al,CR           ;the text must end on the same line
           je   pAllocStrUnclosed
           cmp  al,EOFCHR
           je   pAllocStrUnclosed
           call output_char
           cmp  al,'"'
           je   pAllocStrEND
           jmp  pAllocStrContinue
pAllocStrUnclosed:
           lea  si,sErrString2
           call ErrExpected
pAllocStrEND:
           call wAllocateString2
           call pGetChar
           call pNext
           pop  bx
           ret
pAllocString_nx  ENDP
;
;   Declares an array: name[size]  ->  name dw size dup(0)
;
pAllocArray_nx  PROC    FAR
           call pNext
           call pScan
           cmp  al,'x'
           je   pAllocArrSkip1
           lea  si,sVariableName
           call ErrExpected
pAllocArrSkip1:
           mov  bx,'v'
           call pAddEntry
           call wAllocateArray
           mov  al,look
           cmp  al,'['
           je   pAllocArrSkip2
           lea  si,sErrArray1
           call ErrExpected
pAllocArrSkip2:
           call pGetChar
           call pNext
           mov  al,Token
           cmp  al,'#'
           je   pAllocArrSkip3
           lea  si,sErrNumber
           call ErrExpected
pAllocArrSkip3:
           lea  si,Value
           call output_str
           call pNext
           mov  al,Token
           cmp  al,']'
           je   pAllocArrSkip4
           lea  si,sErrArray2
           call ErrExpected
pAllocArrSkip4:
           call wAllocateArray2
           call pNext
           ret
pAllocArray_nx  ENDP
;
; Declarations: any number of  var a,b,c  /  array a[n],b[m]  /  $s = "text"
;
pTopDecls_nx   PROC    FAR
ptdINIZIO:
           call pScan
           mov al,Token
           cmp  al,'v'
           je   ptdWhile
           cmp  al,'$'
           je   ptdWhile
           cmp  al,'A'
           je   ptdWhile
           jmp  ptdEND          ;not a declaration: done
ptdWhile:
ptdVar:    cmp  al,'v'
           jne  ptdString
           call pAlloc_nx       ;var: one variable...
           mov  al,Token
ptdVarWh:             cmp  al,','       ;...and one more after each comma
                      je  ptdSkip
                      jmp  ptdINIZIO
            ptdSkip:  call pAlloc_nx
                      mov  al,token
                      jmp  ptdVarWh
ptdString: cmp  al,'$'
           jne  ptdArray
           call pAllocString_nx ;string constant
           jmp  ptdInizio
ptdArray:  cmp  al,'A'
           jne  ptdINIZIO
           call pAllocArray_nx  ;array: one array...
           mov  al,Token
ptdArrWh:             cmp  al,','       ;...and one more after each comma
                      je  ptdArrSkip
                      jmp  ptdINIZIO
            ptdArrSkip:  call pAllocArray_nx
                      mov  al,token
                      jmp  ptdArrWh
ptdEND:
           ret
pTopDecls_nx   ENDP
;
; Checks that the current token is the string at SI, then scans the next one
;
pMatchString_nx   PROC    FAR
           push di
           lea di,Value
           push ax
           mov ax,ds
           mov es,ax
           pop ax
           call strcmp
           jz pMatchEqual
           call ErrExpected     ;"<SI> Expected"
pMatchEqual:
           call pNext
           pop di
           ret
pMatchString_nx   ENDP
;
; Copies the file name at SI to DI; DI ends after it
;
pMakeFileName PROC  FAR
ParseFileName:
            cmp  byte ptr [si],0
            je   pMakeFileNameEND
            mov  al,[si]
            mov  [di],al
            inc  si
            inc  di
            jmp  ParseFileName
pMakeFileNameEND:
            ret
pMakeFileName ENDP
;
; Appends the 4-character extension at SI at DI
;
pAttachExtension PROC  FAR
            mov  cx,4
            rep movsb
            ret
pAttachExtension ENDP
;
; Copies the first word of the command line (ES = PSP) into FileName, up to
; 8 characters and without the extension
;
pCommandLine PROC  FAR
            push si
            push di
            mov  si,81h
            mov  cl,es:[80h]    ;command line length
            xor  ch,ch
            lea  di,FileName
            xor  bx,bx          ;characters copied
pCmdSkip:   jcxz pCmdEnd        ;skip leading spaces
            mov  al,es:[si]
            cmp  al,' '
            ja   pCmdCopy
            inc  si
            dec  cx
            jmp  pCmdSkip
pCmdCopy:   jcxz pCmdEnd
            mov  al,es:[si]
            cmp  al,' '
            jbe  pCmdEnd
            cmp  al,'.'
            je   pCmdEnd
            cmp  bx,8
            jae  pCmdEnd
            mov  [di+bx],al
            inc  bx
            inc  si
            dec  cx
            jmp  pCmdCopy
pCmdEnd:    mov  byte ptr [di+bx],0
            pop  di
            pop  si
            ret
pCommandLine ENDP
;
; Start-up: gets the file name, opens NAME.PAS, creates NAME.ASM and scans
; the first token
;
pInit_nx   PROC    FAR
            lea  si,sIntro
            call dsp_str
            cmp  FileName,0     ;no name on the command line: ask
            jne  pInitHaveName
            lea  si,sAskName
            call dsp_str
            lea  si,FileName
            mov  cx,8
            call ReadString
            call new_line
pInitHaveName:
            lea  si,FileName    ;NAME.PAS
            lea  di,ReadFileName
            call pMakeFileName
            lea  si,ReadExtension
            call pAttachExtension
            lea  si,FileName    ;NAME.ASM
            lea  di,WriteFileName
            call pMakeFileName
            lea  si,WriteExtension
            call pAttachExtension
            lea  dx,ReadFileName ;open the source and read the first block
            lea  si,ReadFHandle
            mov  al,0           ;read
            call fOpen
            lea  dx,ReadBuffer
            lea  di,ReadBufferIndex
            call fReadBuffer
            lea  dx,WriteFileName ;create the output file
            lea  si,WriteFHandle
            call fCreate
            ;========================= START
            lea si,sInit                ;"1:" before the first source line
            call dsp_str
            call pGetChar
            call pNext
            ret
pInit_nx   ENDP
;
; Writes what is left in the output buffer and closes both files
;
pTerminate   PROC    FAR
            lea  si,ReadFHandle
            call fClose
            lea  dx,WriteBuffer
            lea  si,WriteFHandle
            lea  di,WriteBufferIndex
            call fWriteBuffer
            call fClose
           ret
pTerminate   ENDP
pGENERALS  ENDS
