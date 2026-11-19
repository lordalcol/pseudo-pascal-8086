;=============================================================================
; PROCEDURE DI USO GENERALE:
; SCANNER, PARSER, gestione della TABELLA DEI SIMBOLI, proc di allocazione e
; di riconoscimento dei TOKEN (parole chiave)
;=============================================================================
pGENERALS    SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:pGENERALS
;
; controlla se il carattere corrente è "BIANCO" cioè spazio, tab, invio, ecc.
; in questo caso lo salta
;
pSkipComment   PROC    FAR
pSkCommWhile:
           cmp al,CR            ;inizio while
           je   pSkCommEND
           call pGetChar
           jmp pSkCommWhile     ;fine while
pSkCommEND:
           call pGetChar
           ret
pSkipComment   ENDP
;
; controlla se il carattere corrente è "BIANCO" cioè spazio, tab, invio, ecc.
; in questo caso lo salta
;
pSkipWhite_nx   PROC    FAR
pWhiteWhile:
        mov  al,Look
	CALL isWhite            ;inizio il ciclo "while"
	JNZ pSkipWhiteEND
	CMP al,chrCOMMENT       ;se il carattere è l'inizio di un commento
        JNE pSkipNoComment
            call pSkipComment       ;salto l'intero commento
            JMP pWhiteWhile         ;fine ciclo (1)
pSkipNoComment:
            CALL pGetChar            ;altrimenti procedo a eliminare il bianco
            JMP pWhiteWhile         ;fine ciclo (2)
pSkipWhiteEND:
           ret
pSkipWhite_nx   ENDP
;
; rileva la prossima parola "IDENTIFICATORE"
;
pGetName   PROC    FAR
           push si
           push bx
           lea bx,Value
           call pSkipWhite_nx
           call isAlpha                 ;controllo se il carattere è alfa
           jz   pGetNskipError          ;se è alpha procedi...
           lea  si,sErrIdentifier
           call ErrExpected             ;altrimenti ERRORE
pGetNskipError:
           mov Token,'x'
           mov si,0
pGetNrepeat:
           call ToUpper
           mov [bx][si],al             ;value=value+AL
           inc si
           call pGetChar
           call isAlNum                 ;finchè il char è Alfanumerico continuo il ciclo
           jz   pGetNrepeat
           mov byte ptr [bx][si],0      ;alla fine del ciclo chiudo la stringa con 0
           pop bx
           pop si
           ret
pGetName   ENDP
;
; rileva il prossimo numero intero
;
pGetNum   PROC    FAR
           push si
           push bx
           lea bx,Value
           call pSkipWhite_nx
           call isDigit                 ;controllo se il carattere è numerico
           jz   pGetNumskipError        ;se è digit procedi...
           lea  si,sErrNumber
           call ErrExpected             ;altrimenti ERRORE
pGetNumskipError:
           mov Token,'#'
           mov si,0
pGetNumrepeat:
           mov [bx][si],al             ;value=value+AL
           inc si
           call pGetChar
           call isDigit                 ;finchè il char è numerico continuo il ciclo
           jz pGetNumrepeat
           mov byte ptr [bx][si],0      ;alla fine del ciclo chiudo la stringa con 0
           pop bx
           pop si
           ret
pGetNum    ENDP
;
; rileva il prossimo identificatore 'x', cioè un char
;
pGetIntChar   PROC    FAR
           push si
           push bx
           lea bx,Value
           call pSkipWhite_nx
           cmp al,"'"                   ;controllo se il carattere è '
           jz   pGetICskipError          ;se sì procedi...
           lea  si,sErrCharIdent
           call ErrExpected             ;altrimenti ERRORE
pGetICskipError:
           mov Token,'#'
           mov si,0
           mov [bx][si],al             ;SCRIVO IL PRIMO '
           inc si
           call pGetChar                ;prendo un altro carattere dopo '
           mov [bx][si],al             ;SCRIVO IL CHAR
           inc si
           call pGetChar                ;prendo un altro carattere il CHAR
           cmp al,"'"                   ;controllo se il carattere è '
           je   pGetICskipError2          ;se sì procedi...
           lea  si,sErrCharIdent2
           call ErrExpected             ;altrimenti ERRORE
pGetICskipError2:
           mov [bx][si],al             ;SCRIVO IL SECONDO '
           inc si
           mov byte ptr [bx][si],0     ;alla fine del ciclo chiudo la stringa con 0
           call pGetChar
           pop bx
           pop si
           ret
pGetIntChar    ENDP
;
; rileva il prossimo identificatore di costante stringa: $stringa
;
pGetStringName   PROC    FAR
           push si
           push bx
           lea bx,Value
           ;call pSkipWhite_nx
           cmp  al,'$'                 ;controllo se il carattere è inizio stringa $
           jz   pGetSskipError          ;se sì procedi...
           lea  si,sErrStringIdent
           call ErrExpected             ;altrimenti ERRORE
pGetSskipError:
           mov Token,'$'
           mov si,0
pGetSrepeat:
           mov [bx][si],al              ;value=value+AL
           inc si
           call pGetChar
           call isAlNum                 ;finchè il char è Alfanumerico continuo il ciclo
           jz pGetSrepeat
           mov byte ptr [bx][si],0      ;alla fine del ciclo chiudo la stringa con 0
           pop bx
           pop si
           ret
pGetStringName    ENDP
;
; rileva l'operatore
;
pGetOp   PROC    FAR
           call pSkipWhite_nx
           mov Token,al         ;tokenizzo il carattere (operatore) così com'è
           lea si,Value
           mov [si],al
           inc si
           mov byte ptr [si],0
           call pGetChar
           ret
pGetOp   ENDP
;
; rileva il gruppo di caratteri successivi
; se il carattere successivo è alfanumerico cattura la prossima parola
; altrimenti cattura solamente il carattere (un operatore)
;
pNext   PROC    FAR
           mov al,Look
           call pSkipWhite_nx
                                ;FACCIO I VARI CONTROLLI SUL CARATTERE IMMESSO
           mov  al,Look
           call IsAlpha
           jnz   pNextSkip1
           call pGetName        ;se è una lettera catturo un Identifier
           ret
pNextSkip1:
           call IsDigit
           jnz   pNextSkip2
           call pGetNum         ;se è una cifra catturo un numero
           ret
pNextSkip2:
           cmp al,"'"
           jnz   pNextSkip3
           call pGetIntChar     ;se è un apice ' catturo un char 'c'
           ret
pNextSkip3:
           cmp al,"$"
           jnz   pNextSkip4
           call pGetStringName  ;se è $ catturo l'identificatore di una cost. stringa
           ret
pNextSkip4:
           call pGetOp
           ret
pNext   ENDP
;
; Table Lookup: trova la posizione della parola tra le chiavi del linguaggio
;       ingresso: SI punta alla lista di stringhe in cui si vuole cercare
;                 DI punta alla stringa che si deve cercare
;                 AX è il massimo numero di stringhe visitabili nella lista
;       restituisce in CX la posizione
;
pLookup    PROC    FAR
           push bx
           mov  bx,1
pLookupWhile:
           call strcmp
           jz  pLookupEND      ;se le stringhe sono uguali esci
           inc  bx              ; ho fatto un'altra stringa: incremento
           ;controllo se ho raggiunto il numero massimo di stringhe nella lista
           cmp  bx,ax
           jne  pLookupAvanza
           mov  cx,0    ;se ho raggiunto il massimo significa che non ho trovato nulla
           pop  bx
           ret
        pLookupAvanza:
                   inc  si      ;altrimenti vai in cerca della fine della stringa
                   cmp  byte ptr [si],0  ;in KWlist
                   jne  pLookupAvanza           ;se non è 0 avanzo con i caratteri
                   inc  si
                   jmp   pLookupWhile    ;se trova la fine della stringa riparte
                   
pLookupEND:                     ;fine: ho trovato e tokenizzato oppure
                                ;esco per forza con cx a zero
           mov  cx,bx
           pop  bx
           ret
pLookup    ENDP
;
; Look for Symbol in Table
;
pInTable   PROC    FAR
           push ax
           lea  si,SymbTable     ;puntatore alla lista di stringhe
           ;lea  di,Value         ;puntatore alla stringa da cercare
           mov  ax,MaxEntry      ;massimo numero di simboli possibili
pInTableWhile:
           call strcmp
           jz pInTableEqual
           add si,16
           dec ax
           cmp ax,0
           jne pInTableWhile
           mov cx,0
           pop ax
           ret
pInTableEqual:
           mov  cx,1
           pop  ax
           ret
pInTable   ENDP
;
; Add a New Entry to Symbol Table
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
           mov  [si],bl
           xchg  ax,cx
           mov  bl,16
           mul  bl       ;ax := al * 8
           xchg  ax,cx
           ;copio dentro SymbTable[cx] la stringa Value
           mov  si,cx
           lea  si,SymbTable[si]
           lea  di,Value
           call StrCpy
           pop  bx
           ret
pAddEntry   ENDP
;
; Scan the Current Identifier for Keywords
;
pScan      PROC    FAR
           mov al,Token
           cmp al,'x'           ;IF Token = 'x'
           jne pScanEND
           lea si,KWlist        ;puntatore alla lista di stringhe
           lea di,Value         ;puntatore alla stringa da cercare
           mov ax,NKW           ;numero di stringhe presenti nella lista
           call pLookup         ;table lookup returns into CX
           lea  si,KWcode
           add  si,cx
           mov al,[si]    ;prendo il token: il carattere alla posizione CX
           mov Token,al
pScanEND:
           ret
pScan      ENDP
;
;   Allocate Storage for a Variable  
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
;   Allocate Storage for a string
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
           ;call pGetChar
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
           call output_char
pAllocStrContinue:
           call pGetChar
           call output_char
           mov  al,look
           cmp  al,'"'
           je   pAllocStrEND
           jmp  pAllocStrContinue
pAllocStrEND:
           call wAllocateString2
           call pGetChar
           call pNext
           pop  bx
           ret
pAllocString_nx  ENDP
;
;   Allocate Storage for an array
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
           ;call pSkipWhite_nx
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
; rileva e inizializza le dichiarazioni delle variabili
;
pTopDecls_nx   PROC    FAR
ptdINIZIO:
           call pScan           ;creo il TOKEN  
           ;controllo se AL è v,$,A
           mov al,Token         ;uso AL al posto della var. Token
           cmp  al,'v'
           je   ptdWhile        ;inizio il ciclo
           cmp  al,'$'
           je   ptdWhile        ;inizio il ciclo
           cmp  al,'A'
           je   ptdWhile        ;inizio il ciclo
           jmp  ptdEND          ;se arrivo qui esco dal while
ptdWhile:                       ;ciclo while grande
ptdVar:    cmp  al,'v'
           jne  ptdString       ;se AL non è 'v' provo con le stringhe
           call pAlloc_nx       ;SE è 'v' alloco la variabile
           mov  al,Token
ptdVarWh:             cmp  al,','       ;finchè trovo ',' alloco
                      je  ptdSkip       ;se trovo ',' alloco
                      ;call pNext
                      jmp  ptdINIZIO       ;riparto col ciclo grande
            ptdSkip:  call pAlloc_nx
                      mov  al,token
                      jmp  ptdVarWh
ptdString: cmp  al,'$'          ;se è una stringa alloco
           jne  ptdArray        ;se non è una stringa provo con l'array
           call pAllocString_nx ;alloco
           jmp  ptdInizio
ptdArray:  cmp  al,'A'          
           jne  ptdINIZIO       ;se non è un array riparto con il ciclo grande
           call pAllocArray_nx  ;se è un array alloco
           mov  al,Token
ptdArrWh:             cmp  al,','       ;finchè trovo ',' alloco
                      je  ptdArrSkip       ;se trovo ',' alloco
                      ;call pNext
                      jmp  ptdINIZIO       ;riparto col ciclo grande
            ptdArrSkip:  call pAllocArray_nx
                      mov  al,token
                      jmp  ptdArrWh
                      
           call pScan           ;creo il Token
           jmp ptdINIZIO            ;riparto con il ciclo
ptdEND:
           ret
pTopDecls_nx   ENDP
;
; controlla se l'ultima stringa rilevata corrisponde con la richiesta
;
pMatchString_nx   PROC    FAR
           ;controlla se le due stringhe di lunghezza diversa sono uguali
           ; stringa1: Value
           ; stringa2: ds:si
           push di
           lea di,Value         ;carico la prima stinga
           push ax
           mov ax,ds
           mov es,ax            ;es e ds puntano allo stesso segmento
           pop ax
           call strcmp          ;faccio il confronto, se ricevo ZERO sono diverse
           jz pMatchEqual
           call ErrExpected     ;esco con l'errore, mi aspettavo la stringa
                                ;puntata da ds:si
pMatchEqual:
           call pNext
           pop di
           ret
pMatchString_nx   ENDP
;
; copia il nome del file generico dentro la stringa
; per il nome del file completo
; copio da SI a DI
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
; attacco alla posizione indicata da DI la stringa (estensione indicata da SI)
; copio da SI a DI
pAttachExtension PROC  FAR
            mov  cx,4
            rep movsb
            ret
pAttachExtension ENDP
; inizializza la lettura e scrittura del file
;
pInit_nx   PROC    FAR
            lea  si,sIntro
            call dsp_str
            ;leggo il nome del file da leggere senza estensione
            lea  si,FileName
            call ReadString
            call new_line
            ;preparo il nome del file da leggere
            lea  si,FileName
            lea  di,ReadFileName
            call pMakeFileName
            lea  si,ReadExtension
            call pAttachExtension
            ;preparo il nome del file da scrivere
            lea  si,FileName
            lea  di,WriteFileName
            call pMakeFileName
            lea  si,WriteExtension
            call pAttachExtension
            ;apro il file da leggere e leggo il primo blocco
            lea  dx,ReadFileName
            lea  si,ReadFHandle
            mov  al,0           ;READ MODE
            call fOpen
            lea  dx,ReadBuffer
            call fReadBuffer
            ;creo e apro il file da leggere
            lea  dx,WriteFileName
            lea  si,WriteFHandle
            mov  al,1           ;WRITE MODE
            call fCreate
            call fOpen
            ;========================= INIZIO IL PROGRAMMA
            lea si,sInit                ;scrivo la stringa iniziale (1:    )
            call dsp_str
            call pGetChar
            call pNext
            ret
pInit_nx   ENDP
;
; termina la scrittura del file e restituisce un responso
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