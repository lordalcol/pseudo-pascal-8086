;=============================================================================
; COMPILER I/O: reads the source file and writes the assembly file. Only these
; procedures know about files: changing them is enough to read from the
; keyboard and write to the screen instead.
;=============================================================================
pIOS         SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:pIOS
;
; Reads the next source character into Look and AL, and echoes the source
; on the screen with line numbers as it goes.
;
pGetChar   PROC    FAR
           push dx
           push si
           push di
            lea  dx,ReadBuffer
            lea  si,ReadFHandle
            lea  di,ReadBufferIndex
pGetCharRead:
            call fGetC
           cmp al,CR            ;lines end at LF (DOS CR LF or Unix LF):
           je pGetCharRead      ;skip CR...
           cmp al,LF
           jne SkipCRcontrol
           mov al,CR            ;...and turn LF into CR for the scanner
           mov Look,al
           push ax
           call new_line
           mov ax,NLine         ;show the number of the next line
           inc ax
           call wor2dec
           mov al,':'
           call char_out
           mov al,' '
           call char_out
           inc NLine            ;count lines for the error messages
           pop ax
           jmp pGetCharEND
SkipCRcontrol:
           mov Look,al
           cmp al,EOFCHR
           je pGetCharEND
           cmp al,TAB           ;the BIOS shows TAB as a symbol: echo a space
           jne pGetCharEcho
           push ax
           mov al,' '
           call CHAR_OUT
           pop ax
           jmp pGetCharEND
pGetCharEcho:
           call CHAR_OUT        ;echo
pGetCharEND:
           pop di
           pop si
           pop dx
           ret
pGetChar   ENDP
;
; Writes the character in AL to the output file
;
output_char    PROC    FAR
           push dx
           push si
           push di
           push ax
            lea  dx,WriteBuffer
            lea  si,WriteFHandle
            lea  di,WriteBufferIndex
            call fPutC                  ;fPutC handles the buffering
           pop ax
           pop di
           pop si
           pop dx
           ret
output_char    ENDP
;
; Writes the zero-terminated string at SI to the output file
;
output_str    PROC    FAR
          push si
output_str1  LABEL NEAR
          mov  al,ds:[si]
          cmp  al,0
          je   output_str2
          call output_char
          inc  si
          jmp  output_str1
output_str2  LABEL NEAR
          pop  si
          ret
output_str    ENDP
;
; Reads a line from the keyboard into SI, zero-terminated, at most CX
; characters. Backspace deletes, Enter ends.
ReadString      PROC FAR
        push ax
        push bx
        push si
        xor  bx,bx              ;characters typed
ReadStringWhile:
        call char_in
        cmp al,CR
        je ReadStringEND
        cmp al,8
        je ReadStringBack
        cmp al,' '
        jbe ReadStringWhile     ;ignore control characters and spaces
        cmp bx,cx
        jae ReadStringWhile     ;full
        call char_out
        mov [si+bx],al
        inc bx
        jmp ReadStringWhile
ReadStringBack:
        cmp bx,0
        je ReadStringWhile
        dec bx
        mov al,8
        call char_out
        mov al,' '
        call char_out
        mov al,8
        call char_out
        jmp ReadStringWhile
ReadStringEND:
        mov byte ptr [si+bx],0
        pop si
        pop bx
        pop ax
        ret
ReadString      ENDP
pIOS      ENDS
