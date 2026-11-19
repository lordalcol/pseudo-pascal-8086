           INCLUDE RUNTIME.ASM
PilaS      SEGMENT STACK
           db      32 DUP('STACK   ')
PilaS      ENDS
DatiS      SEGMENT
SECRET      dw      0        
GUESS      dw      0        
TRIES      dw      0        
$title      db       "GUESS THE NUMBER (1 to 100)",0
$ask      db       "Your guess: ",0
$low      db       "Too low",0
$high      db       "Too high",0
$win      db       "Got it! Tries: ",0
DatiS      ENDS
MainS      SEGMENT PARA 'CODE'
           ASSUME  CS:MainS, SS:PilaS, DS:DatiS
PrgPrin    PROC    FAR
lInizio    LABEL   NEAR
     mov     ax,SEG DatiS        ; DS = data segment
     mov     ds,ax
LEA SI, $title
CALL DSP_STR
CALL NEW_LINE
;***** MASM
MOV ah,0
INT 1Ah
AND dx,7FFFh
MOV secret,dx
;***** ENDMASM
MOV AX, SECRET
PUSH AX
MOV AX, SECRET
PUSH AX
MOV AX, 100
POP BX        ;dividend
XCHG AX,BX    ;AX = dividend, BX = divisor
CWD           ;sign-extend AX into DX
IDIV BX       ;AX = DX:AX / BX
PUSH AX
MOV AX, 100
POP BX
IMUL BX       ;DX:AX = AX * BX, keep AX
POP BX
SUB AX,BX
NEG AX
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV SECRET, AX           ;store
MOV AX, 0
MOV TRIES, AX           ;store
MOV AX, 0
MOV GUESS, AX           ;store
L1:
MOV AX, GUESS
PUSH AX
MOV AX, SECRET
POP BX
CMP BX,AX
CALL SETNE       ;set if not equal
TEST AX,1    ;set the flags from AX
JNE skipL0
JMP L0
skipL0:
LEA SI, $ask
CALL DSP_STR
CALL DEC2BIN           ;read a decimal number into AX
MOV GUESS, AX           ;store
CALL NEW_LINE
MOV AX, TRIES
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV TRIES, AX           ;store
MOV AX, GUESS
PUSH AX
MOV AX, SECRET
POP BX
CMP BX,AX
CALL SETL        ;set if less
TEST AX,1    ;set the flags from AX
JNE skipL2
JMP L2
skipL2:
LEA SI, $low
CALL DSP_STR
CALL NEW_LINE
L2:
MOV AX, GUESS
PUSH AX
MOV AX, SECRET
POP BX
CMP BX,AX
CALL SETG        ;set if greater
TEST AX,1    ;set the flags from AX
JNE skipL3
JMP L3
skipL3:
LEA SI, $high
CALL DSP_STR
CALL NEW_LINE
L3:
JMP    L1
L0:
LEA SI, $win
CALL DSP_STR
MOV AX, TRIES
CALL Wor2Dec
        jmp dos
PrgPrin    ENDP
MainS      ENDS
END     lInizio
