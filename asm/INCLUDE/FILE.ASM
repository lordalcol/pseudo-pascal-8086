;=============================================================================
; BUFFERED TEXT FILES on top of DOS INT 21h: fOpen, fCreate, fClose,
; fReadBuffer, fWriteBuffer, fGetC, fPutC.
; Files are read and written 256 bytes at a time. A buffer is described by:
;       SI -> file handle (word)
;       DX -> 256-byte buffer
;       DI -> index in the buffer (word), followed for reading by the number
;             of bytes in the buffer (word)
;=============================================================================
fileS         SEGMENT PARA PUBLIC 'CODE'
              ASSUME  CS:fileS
;
; Opens a file.        INPUT: SI -> handle, DX -> file name, AL = 0 read, 1 write
fOpen           PROC FAR
                mov     ah, 3Dh
                int     21h
                jc      fOpenError
                mov     [si], ax        ;save the handle
                ret
fOpenError:
                call    ErrFOpen
fOpen           ENDP
;
; Creates (or truncates) a file and opens it for writing.
;                      INPUT: SI -> handle, DX -> file name
fCreate         PROC FAR
                push    cx
                mov     cx,0            ;normal attributes
                mov     ah, 3Ch
                int     21h
                jc      fCreateError
                mov     [si], ax        ;save the handle
                pop     cx
                ret
fCreateError:
                call    ErrFCreate
fCreate         ENDP
;
; Closes a file.       INPUT: SI -> handle
fClose          PROC FAR
                push    ax
                push    bx
                mov     bx, [si]
                mov     ah, 3Eh
                int     21h
                jc      fCloseError
                pop     bx
                pop     ax
                ret
fCloseError:
                call    ErrFClose
fClose          ENDP
;
; Reads the next 256 bytes (fewer at the end of the file) into the buffer,
; sets the index to 0 and the size to the number of bytes read.
fReadBuffer     PROC FAR
                push    ax
                push    bx
                push    cx
                mov     ah, 3Fh
                mov     cx, 256
                mov     bx, [si]
                int     21h
                jc      fReadBufferError
                mov     word ptr [di], 0
                mov     [di+2], ax
                pop     cx
                pop     bx
                pop     ax
                ret
fReadBufferError:
                call    ErrFRead
fReadBuffer     ENDP
;
; Writes the [DI] bytes in the buffer and empties it.
fWriteBuffer    PROC FAR
                push    ax
                push    bx
                push    cx
                mov     ah, 40h
                mov     cx, [di]
                mov     bx, [si]
                int     21h
                jc      fWriteBufferError
                cmp     ax, cx          ;disk full?
                jne     fWriteBufferError
                mov     word ptr [di], 0
                pop     cx
                pop     bx
                pop     ax
                ret
fWriteBufferError:
                call    ErrFWrite
fWriteBuffer    ENDP
;
; Returns the next character in AL, reading a new block when the buffer is
; used up. At the end of the file it returns EOFCHR, again and again.
fGetC           PROC FAR
                push    bx
                mov     bx, [di]
                cmp     bx, [di+2]
                jb      fGetCHave
                cmp     word ptr [di+2], 256    ;a short block was the last one
                jb      fGetCEOF
                call    fReadBuffer
                cmp     word ptr [di+2], 0
                je      fGetCEOF
                xor     bx, bx
fGetCHave:
                push    si
                mov     si, dx
                mov     al, [si+bx]
                pop     si
                inc     word ptr [di]
                pop     bx
                ret
fGetCEOF:
                mov     al, EOFCHR
                pop     bx
                ret
fGetC           ENDP
;
; Adds the character in AL to the buffer and writes the buffer when full.
fPutC           PROC FAR
                push    bx
                push    si
                mov     bx, [di]
                mov     si, dx
                mov     [si+bx], al
                pop     si
                inc     word ptr [di]
                pop     bx
                cmp     word ptr [di], 256
                jne     fPutCDone
                call    fWriteBuffer
fPutCDone:
                ret
fPutC           ENDP
fileS         ENDS
