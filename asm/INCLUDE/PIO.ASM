;=============================================================================
; Funzioni per gestire la lettura del file pseudo-codice e la scrittura del
; file assembly. Sono indipendenti, semplicemente cambiando queste procedure
; si può leggere da tastiera e scrivere su display, ad esempio
;=============================================================================
pIOS         SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:pIOS
;
; gets next char from the stream and put it into LOOK and AX
;
pGetChar   PROC    FAR
           push dx
           push si
           push di
            lea  dx,ReadBuffer
            lea  si,ReadFHandle
            lea  di,ReadBufferIndex
            call fGetC
           ;call char_in         ;leggo un carattere
           mov Look,al          ;lo salvo in Look
           cmp al,CR            ;se è un ritorno a capo
           jne SkipCRcontrol
           push ax
           call new_line
           mov ax,NLine         ;allora
           inc ax
           call wor2dec         ;scrivo anche il numero di riga
           mov al,':'
           call char_out
           mov al,TAB
           call char_out
           inc NLine            ;incremento il numero di righe visitate
                                ;per gestire meglio gli errori
           pop ax
           jmp pGetCharEND
SkipCRcontrol:
           cmp al,LF            ;se è un ritorno a capo
           je pGetCharEND
           call CHAR_OUT        ;lo visualizzo
pGetCharEND:
           pop di
           pop si
           pop dx
           ret
pGetChar   ENDP
;
; output a char into the stream
;
output_char    PROC    FAR
           ;call char_out
           push dx
           push si
           push di
           push ax
            lea  dx,WriteBuffer         ;preparo i parametri
            lea  si,WriteFHandle        ;per scrivere un carattere
            lea  di,WriteBufferIndex    ;su file
            call fPutC                  ;la bufferizzazione è 
           pop ax                       ;gestita automaticamente da fPutC
           pop di                       ;non devo preoccuparmene
           pop si
           pop dx
           ret
output_char    ENDP
;
; output a string into the stream
;
output_str    PROC    FAR
           ;call dsp_str
          push si
output_str1  LABEL NEAR
          mov  al,ds:[si]
          cmp  al,0
          je   output_str2            ; je fine
          call output_char
          inc  si
          jmp  output_str1            ; prossimo carattere
output_str2  LABEL NEAR
          pop  si
          ret
           ret
output_str    ENDP
;
; legge una stringa terminata da INVIO (CR)
; scrive dentro si e termina con 0
ReadString      PROC FAR
        push ax
        push si
ReadStringWhile:
        call char_in
        call char_out
        cmp al,CR
        je ReadStringEND
        mov [si],al
        inc si
        jmp ReadStringWhile
ReadStringEND:
        mov byte ptr [si],0
        pop si
        pop ax
ReadString      ENDP
pIOS      ENDS