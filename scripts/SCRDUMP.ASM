; SCRDUMP.COM - writes the 80x25 text screen to SCREEN.TXT, one line per row.
; Used by scripts/dos.mjs to read what a program showed. jwasm -bin
        .model tiny
        .code
        org 100h
start:  push cs
        pop ds
        mov ax,0B800h
        mov es,ax
        xor si,si
        lea di,buf
        mov cx,25
row:    push cx
        mov cx,80
col:    mov al,es:[si]
        mov [di],al
        inc di
        add si,2
        loop col
        mov byte ptr [di],13
        mov byte ptr [di+1],10
        add di,2
        pop cx
        loop row
        mov ah,3Ch
        xor cx,cx
        lea dx,fname
        int 21h
        mov bx,ax
        mov ah,40h
        mov cx,25*82
        lea dx,buf
        int 21h
        mov ah,3Eh
        int 21h
        mov ax,4C00h
        int 21h
fname   db 'SCREEN.TXT',0
buf     db 25*82 dup(?)
        end start
