;=============================================================================
; RUNTIME.ASM - runtime library for the compiler and for the programs it
; generates. Keyboard and screen I/O through the BIOS, decimal conversion,
; the SETcc emulation (the 8086 has no SETcc instructions) and exit to DOS.
;
; Every procedure is FAR and preserves all registers except the ones it
; returns a value in.
;=============================================================================
RuntimeS  SEGMENT PARA PUBLIC 'CODE'
          ASSUME CS:RuntimeS
;
; Reads a key without echo and returns its ASCII code in AX (AH = 0).
; Extended keys (arrows, function keys) return 0.
CHAR_IN   PROC FAR
          mov  ah,0
          int  16h
          xor  ah,ah
          ret
CHAR_IN   ENDP
;
; Writes the character in AL to the screen (BIOS teletype).
CHAR_OUT  PROC FAR
          push ax
          push bx
          mov  ah,0Eh
          mov  bx,0007h              ; page 0, light grey
          int  10h
          pop  bx
          pop  ax
          ret
CHAR_OUT  ENDP
;
; Moves the cursor to the start of the next line.
NEW_LINE  PROC FAR
          push ax
          mov  al,13
          call CHAR_OUT
          mov  al,10
          call CHAR_OUT
          pop  ax
          ret
NEW_LINE  ENDP
;
; Writes the zero-terminated string at DS:SI.
DSP_STR   PROC FAR
          push ax
          push si
dspLoop:  mov  al,[si]
          cmp  al,0
          je   dspEnd
          call CHAR_OUT
          inc  si
          jmp  dspLoop
dspEnd:   pop  si
          pop  ax
          ret
DSP_STR   ENDP
;
; Writes AX as a signed decimal number.
WOR2DEC   PROC FAR
          push ax
          push bx
          push cx
          push dx
          test ax,ax
          jns  w2dPositive
          push ax
          mov  al,'-'
          call CHAR_OUT
          pop  ax
          neg  ax                    ; -32768 stays 8000h, printed as 32768
w2dPositive:
          mov  bx,10
          xor  cx,cx
w2dDivide:
          xor  dx,dx
          div  bx                    ; unsigned: also right for 8000h
          push dx                    ; digits come out last to first
          inc  cx
          test ax,ax
          jnz  w2dDivide
w2dPrint: pop  ax
          add  al,'0'
          call CHAR_OUT
          loop w2dPrint
          pop  dx
          pop  cx
          pop  bx
          pop  ax
          ret
WOR2DEC   ENDP
;
; Reads a signed decimal number from the keyboard, with echo, and returns it
; in AX. Accepts an optional leading '-' and up to 5 digits; Backspace
; deletes, Enter ends. Other keys are ignored. Values wrap at 16 bits.
DEC2BIN   PROC FAR
          push bx
          push cx
          push dx
          push si
          xor  bx,bx                 ; value so far
          xor  cx,cx                 ; digits typed
          xor  si,si                 ; 1 if negative
d2bKey:   call CHAR_IN
          cmp  al,13
          je   d2bEnter
          cmp  al,8
          je   d2bBack
          cmp  al,'-'
          je   d2bMinus
          cmp  al,'0'
          jb   d2bKey
          cmp  al,'9'
          ja   d2bKey
          cmp  cx,5
          jae  d2bKey
          call CHAR_OUT
          push ax
          mov  ax,bx                 ; value = value * 10 + digit
          mov  dx,10
          mul  dx
          mov  bx,ax
          pop  ax
          and  ax,0Fh
          add  bx,ax
          inc  cx
          jmp  d2bKey
d2bMinus: cmp  cx,0                  ; only as the first character
          jne  d2bKey
          cmp  si,0
          jne  d2bKey
          mov  si,1
          call CHAR_OUT
          jmp  d2bKey
d2bBack:  cmp  cx,0
          jne  d2bDigit
          cmp  si,0
          je   d2bKey
          mov  si,0                  ; delete the '-'
          jmp  d2bErase
d2bDigit: mov  ax,bx                 ; value = value / 10
          xor  dx,dx
          push cx
          mov  cx,10
          div  cx
          pop  cx
          mov  bx,ax
          dec  cx
d2bErase: mov  al,8                  ; backspace, space, backspace
          call CHAR_OUT
          mov  al,' '
          call CHAR_OUT
          mov  al,8
          call CHAR_OUT
          jmp  d2bKey
d2bEnter: mov  ax,bx
          cmp  si,0
          je   d2bDone
          neg  ax
d2bDone:  pop  si
          pop  dx
          pop  cx
          pop  bx
          ret
DEC2BIN   ENDP
;
; Ends the program with exit code 0 (DOS) or 1 (DOS_ERR).
DOS       PROC FAR
          mov  ax,4C00h
          int  21h
DOS       ENDP
DOS_ERR   PROC FAR
          mov  ax,4C01h
          int  21h
DOS_ERR   ENDP
;
;=============================================================================
; SETcc emulation. Called right after CMP BX,AX: AX = 1 if the condition
; holds, 0 otherwise. Comparisons are signed, like the integers.
;=============================================================================
SETE      PROC FAR
          mov  ax,1
          je   seteOk
          xor  ax,ax
seteOk:   ret
SETE      ENDP
SETNE     PROC FAR
          mov  ax,1
          jne  setneOk
          xor  ax,ax
setneOk:  ret
SETNE     ENDP
SETG      PROC FAR
          mov  ax,1
          jg   setgOk
          xor  ax,ax
setgOk:   ret
SETG      ENDP
SETL      PROC FAR
          mov  ax,1
          jl   setlOk
          xor  ax,ax
setlOk:   ret
SETL      ENDP
SETGE     PROC FAR
          mov  ax,1
          jge  setgeOk
          xor  ax,ax
setgeOk:  ret
SETGE     ENDP
SETLE     PROC FAR
          mov  ax,1
          jle  setleOk
          xor  ax,ax
setleOk:  ret
SETLE     ENDP
RuntimeS  ENDS
