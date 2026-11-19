;=============================================================================
; Le seguenti procedure vengono chiamate quando si verifica un errore durante
; la compilazione o l'IO files.
; Gli errori di compilazione vengono visualizzati in modo dinamico, essi
; visualizzano il numero della riga e la parola chiave che crea il problema
; Le stringhe costanti vengono ricavate dal segmento dei DATI
;=============================================================================
wErrorS         SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:wErrorS
;
; displays a general error with line number and halts the program
wError   PROC    FAR
           push ax
           push si
           call far ptr pTerminate      ;conclude la scrittura e chiude i files
           pop si
           call NEW_LINE
           mov  al,TAB
           call CHAR_OUT
           push si
           lea  si,sErrLineNumber
           call DSP_STR
           mov  ax,NLine
           call Wor2Dec                 ;visualizzo il numero della riga
           lea  si,sErrError
           call DSP_STR                 ;visualizzo la stringa statica ERROR:
           pop si
           pop  ax
           ret
wError   ENDP
;
; displays an error "EXPECTED something"
ErrExpected   PROC    FAR
           call wError                  ;chiamo il generico errore
           call DSP_STR                 ;visualizzo il VALUE in questione
           lea si,sErrExpected
           call DSP_STR
           jmp DOS
ErrExpected   ENDP
;
; displays an error DUPLICATE SYMBOL
ErrDuplicate   PROC    FAR
           call wError                  ;chiamo il generico errore
           call DSP_STR                 ;visualizzo il VALUE in questione
           lea si,sErrDuplicate
           call DSP_STR
           jmp DOS
ErrDuplicate   ENDP
;
; displays an error UNDEFINED symbol
ErrUndefined   PROC    FAR
           call wError                  ;chiamo il generico errore
           call DSP_STR                 ;visualizzo il VALUE in questione
           lea si,sErrUndefined
           call DSP_STR
           jmp DOS
ErrUndefined   ENDP
;
; displays an error "TABLE FULL"
ErrTableFull   PROC    FAR
           call wError                  ;chiamo il generico errore
           call DSP_STR                 ;visualizzo il VALUE in questione
           lea si,sErrTableFull         ;la tabella dei simboli è PIENA
           call DSP_STR
           jmp DOS
ErrTableFull   ENDP
;=============================================================================
; ERRORI VARI NELL' I/O FILE
;=============================================================================
ErrFOpen   PROC    FAR
           lea si,sErrFOpen
           call DSP_STR
           jmp DOS
ErrFOpen   ENDP
ErrFRead   PROC    FAR
           lea si,sErrFRead
           call DSP_STR
           jmp DOS
ErrFRead   ENDP
ErrFWrite  PROC    FAR
           lea si,sErrFWrite
           call DSP_STR
           jmp DOS
ErrFWrite  ENDP
ErrFClose   PROC    FAR
           lea si,sErrFClose
           call DSP_STR
           jmp DOS
ErrFClose   ENDP
ErrFCreate PROC    FAR
           lea si,sErrFCreate
           call DSP_STR
           jmp DOS
ErrFCreate ENDP
wErrorS      ENDS