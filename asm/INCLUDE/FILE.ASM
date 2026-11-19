;=============================================================================
; GESTIONE DEI FILES DI TESTO: fOpen, fClose, fCreate
; fReadBuffer, fWriteBuffer, fGetC, fPutC
; Attenzione: lettura e scrittura sono bufferizzate
;=============================================================================
fileS         SEGMENT PARA PUBLIC 'CODE'
              ASSUME  CS:fileS
;
;       apre un file e imposta l'handle
;               INPUT:  SI points at the file handle
;                       DX points at ASCII file name
;                       AL Read: 0 Write: 1
fOpen           PROC FAR
                mov     ah, 3dh         ;Open the file
                ;mov     al, 0           ;Open for reading
                ;lea     dx, ReadFileName    ;Presume DS points at filename
                int     21h             ; segment.
                jc      fOpenError
                mov     [si], ax       ;Save file handle
                ret
fOpenError:
                call    ErrFOpen
                ret
fOpen           ENDP
;
;       crea un file
;               INPUT:  CX file attribute (7: shareable, 0: read only)
;                       DX points at ASCII file name
fCreate         PROC FAR
                mov     cx,0
                mov     ah, 3Ch         ;create the file
                int     21h             ; segment.
                jc      fCreateError
                mov     [si], ax       ;Save file handle
                ret
fCreateError:
                call    ErrFCreate
                ret
fCreate           ENDP
;
;       chiude un file
;               INPUT:  SI points at the file handle
fClose          PROC FAR
EOF:            mov     bx, [si]
                mov     ah, 3eh         ;Close file
                int     21h
                jc      fCloseError
                ret
fCloseError:
                call    ErrFClose
                ret
fClose          ENDP
;
;       legge un buffer di dati
;               INPUT:  SI points at the file handle
;                       DX points at the data buffer
fReadBuffer     PROC FAR
                push    ax
                push    si
                push    dx
                push    bx
                push    cx
                mov     al,0
                mov     ah,3fh          ;Read data from the file
                ;lea     dx, Buffer      ;Address of data buffer
                mov     cx, 256           ;Read 256 bytes
                mov     bx, [si]        ;Get file handle value
                int     21h
                jc      fReadBufferError
                ;mov     bx, ax          ;Save for later
                ;mov     cx, ax
                jcxz    fReadBufferEOF
                pop     cx
                pop     bx
                pop     dx
                pop     si
                pop     ax
                ret
fReadBufferError:
                call    ErrFRead
                ret
fReadBufferEOF:
                call    FClose
                ret
fReadBuffer     ENDP
;
;       scrive un buffer di dati
;               INPUT:  SI points at the file handle
;                       DX points at the data buffer
fWriteBuffer     PROC FAR
                push    ax
                push    si
                push    dx
                push    bx
                push    cx
                mov     al,1
                mov     ah,40h          ;Write data from the file
                ;lea     dx, Buffer      ;Address of data buffer
                mov     cx, [di]           ;write 256 bytes
                mov     bx, [si]        ;Get file handle value
                int     21h
                jc      fWriteBufferError
                ;mov     bx, ax          ;Save for later
                ;mov     cx, ax
                pop     cx
                pop     bx
                pop     dx
                pop     si
                pop     ax
                ret
fWriteBufferError:
                call    ErrFWrite
                ret
fWriteBuffer    ENDP
;
;       legge un carattere dal buffer indicato, se il buffer finisce ne carica uno nuovo
;               INPUT:  SI points at the file handle
;                       DX points at the data buffer
;                       DI points at the index of the buffer
fGetC           PROC FAR
                push    si
                mov     si,dx
                add     si,[di]
                mov     al,[si]
                inc     word ptr [di]
                pop     si
                cmp     word ptr [di], 256          ;Reach EOF yet?
                je      fGetcNewBuffer
                ret
fGetcNewBuffer:
                mov     word ptr [di],0
                call    fReadBuffer
                ret
fGetC           ENDP
;
;       scrive un carattere nel buffer indicato, se il buffer finisce lo scrive e lo svuota
;               INPUT:  SI points at the file handle
;                       DX points at the data buffer
;                       DI points at the index of the buffer
;                       AL carattere da scrivere
fPutC           PROC FAR
                push    si
                mov     si,dx
                add     si,[di]
                mov     [si],al
                inc     word ptr [di]
                pop     si
                cmp     word ptr [di], 256          ;Reach EOF yet?
                je      fPutcNewBuffer
                ret
fPutcNewBuffer:
                call far ptr fWriteBuffer
                mov     word ptr [di],0
                ret
fPutC           ENDP
fileS      ENDS