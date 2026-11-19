;=============================================================================
; ERRORS. Called when compiling or file I/O fails. Compile errors show the
; source line and the word that caused them, then stop the compiler with
; exit code 1 and delete the incomplete output file.
;=============================================================================
wErrorS         SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:wErrorS
;
; Closes the files and starts the message: "[LINE: n] Error: "
wError   PROC    FAR
           push ax
           push si
           push di
           call far ptr pTerminate      ;flush and close the files
           mov  ah,41h                  ;delete the incomplete output file
           lea  dx,WriteFileName
           int  21h
           call NEW_LINE
           lea  si,sErrLineNumber
           call DSP_STR
           mov  ax,NLine
           call Wor2Dec                 ;line number
           lea  si,sErrError
           call DSP_STR
           pop  di
           pop  si
           pop  ax
           ret
wError   ENDP
;
; "<SI> Expected"
ErrExpected   PROC    FAR
           call wError
           call DSP_STR                 ;what was expected
           lea si,sErrExpected
           call DSP_STR
           jmp DOS_ERR
ErrExpected   ENDP
;
; "<DI> Duplicated symbol declaration"
ErrDuplicate   PROC    FAR
           call wError
           mov  si,di
           call DSP_STR                 ;the symbol
           lea si,sErrDuplicate
           call DSP_STR
           jmp DOS_ERR
ErrDuplicate   ENDP
;
; "<DI> Undefined symbol"
ErrUndefined   PROC    FAR
           call wError
           mov  si,di
           call DSP_STR                 ;the symbol
           lea si,sErrUndefined
           call DSP_STR
           jmp DOS_ERR
ErrUndefined   ENDP
;
; "<DI> Table of symbols is FULL"
ErrTableFull   PROC    FAR
           call wError
           mov  si,di
           call DSP_STR                 ;the symbol
           lea si,sErrTableFull
           call DSP_STR
           jmp DOS_ERR
ErrTableFull   ENDP
;
; "Unexpected end of file"
ErrEOF     PROC    FAR
           call wError
           lea si,sErrEOF
           call DSP_STR
           jmp DOS_ERR
ErrEOF     ENDP
;=============================================================================
; FILE I/O ERRORS
;=============================================================================
ErrFOpen   PROC    FAR
           lea si,sErrFOpen
           call DSP_STR
           jmp DOS_ERR
ErrFOpen   ENDP
ErrFRead   PROC    FAR
           lea si,sErrFRead
           call DSP_STR
           jmp DOS_ERR
ErrFRead   ENDP
ErrFWrite  PROC    FAR
           lea si,sErrFWrite
           call DSP_STR
           jmp DOS_ERR
ErrFWrite  ENDP
ErrFClose   PROC    FAR
           lea si,sErrFClose
           call DSP_STR
           jmp DOS_ERR
ErrFClose   ENDP
ErrFCreate PROC    FAR
           lea si,sErrFCreate
           call DSP_STR
           jmp DOS_ERR
ErrFCreate ENDP
wErrorS    ENDS
