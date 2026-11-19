;=============================================================================
; DATA: stack and data segments of the compiler. Keywords, global state,
; symbol table, file buffers, error messages and the pieces of assembly
; text the code generator writes.
;=============================================================================
; CONSTANTS
TAB             equ     9
CR              equ     13
LF              equ     10
EOFCHR          equ     1Ah     ;returned by fGetC at the end of the file
;
MaxEntry        equ     100     ;maximum number of symbols (variables, arrays, strings)
MaxName         equ     15      ;longest name or number kept (longer ones are truncated)
NKW             equ     19      ;number of keywords + 1
;=============================================================================
; STACK. Big, because PushString keeps whole strings on it while the
; recursive descent parser nests blocks and expressions.
PILA      SEGMENT STACK
          DB  128 DUP('STACK   ')
PILA      ENDS
;=============================================================================
DATI_S    SEGMENT 'DATA'
;=============================================================================
; ========================= KEYWORDS =========================================
sPROGRAM        db      "PROGRAM",0
sBEGIN          db      "BEGIN",0
sEND            db      "END",0
sENDIF          db      "ENDIF",0
sENDWHILE       db      "ENDWHILE",0
sENDLOOP        db      "ENDLOOP",0
sENDMASM        db      "ENDMASM",0
sMASMcomment1   db      ";***** MASM",CR,LF,0
sMASMcomment2   db      ";***** ENDMASM",CR,LF,0
chrCOMMENT      db      ";"
KWlist          db      'IF',0, 'ELSE',0, 'ENDIF',0, 'WHILE',0, 'ENDWHILE',0
                db      'READ',0, 'WRITE',0, 'VAR',0, 'END',0, 'WRITEINT',0
                db      'READINT',0, 'MASM',0, 'ENDMASM',0, 'NEWLINE',0
                db      'LOOP',0,'ENDLOOP',0, 'WRITESTR',0, 'ARRAY',0
; token type for each reserved word above; 'x' (position 0) = identifier
KWcode          db      'xileweRWveIJmMNLeSA'
;=============================================================================
;========================== GLOBAL STATE =====================================
LCount          dw      0               ;next label number
NEntry          dw      0               ;symbols in the table
NLine           dw      1               ;current source line
Look            db      0               ;lookahead character
Token           db      0               ;token type of the current token
Value           db      MaxName+1 DUP(0) ;lexeme of the current token
TmpValue        db      MaxName+1 DUP(0)
sLabel1         db      8 DUP(0)
sLabel2         db      8 DUP(0)
sInit           db      "1: ",0
sIntro          db      "Pseudo-Pascal to 8086 assembly compiler - Lorenzo Dal Col, 2006",CR,LF,0
sAskName        db      "Source file name, without the .PAS extension: ",0
;========================== SYMBOL TABLE
SymbTable       db      (MaxEntry+1)*16 DUP(0)  ;array[1..MaxEntry] of string[16]
SType           db      MaxEntry+1 DUP(0)       ;array[1..MaxEntry] of char
;========================== FILES
FileName        db      9 DUP(0)
ReadExtension   db      '.PAS'
ReadFileName    db      13 DUP(0)
ReadFHandle     dw      0
ReadBuffer      db      256 DUP(0)
ReadBufferIndex dw      0
ReadBufferSize  dw      0               ;bytes read into ReadBuffer
WriteExtension  db      '.ASM'
WriteFileName   db      13 DUP(0)
WriteFHandle    dw      0
WriteBuffer     db      256 DUP(0)
WriteBufferIndex dw     0
;=============================================================================
;========================== ERROR MESSAGES ===================================
sErrLineNumber  db      "[LINE: ",0
sErrError       db      "] Error: ",0
sErrExpected    db      " Expected",0
sErrIdentifier  db      "Identifier",0
sErrNumber      db      "Number",0
sVariableName   db      "Variable Name",0
sErrCharIdent   db      "Char Identifier (')",0
sErrCharIdent2  db      "Final Char Identifier (')",0
sErrStringIdent db      "String Identifier ($)",0
sErrDuplicate   db      " Duplicated symbol declaration",0
sErrUndefined   db      " Undefined symbol",0
sErrTableFull   db      " Table of symbols is FULL",0
sErrString      db      "String ($)",0
sErrString2     db      '"',0
sErrAssignment  db      "=",0
sErrArray1      db      "[",0
sErrArray2      db      "]",0
sStringIdent    db      'String Identifier ($)',0
sMathFactor     db      "Math Factor",0
sErrEOF         db      "Unexpected end of file",0
;===================== FILE I/O ERRORS
sErrFOpen       db      CR,LF,"Can't open the source file.",0
sErrFRead       db      CR,LF,"Can't read the source file.",0
sErrFWrite      db      CR,LF,"Can't write the output file.",0
sErrFClose      db      CR,LF,"Can't close a file.",0
sErrFCreate     db      CR,LF,"Can't create the output file.",0
;=============================================================================
;========================== GENERATED ASSEMBLY ===============================
sCRLF           db      CR,LF,0
sCX             db      'CX',0
sParentAperta   db      '(',0
sParentChiusa   db      ')',0
sQuadChiusa     db      ']',0
sUguale         db      '=',0
sHeader         db      '           INCLUDE RUNTIME.ASM',CR,LF
                db      'PilaS      SEGMENT STACK',CR,LF
                db      '           db      32 DUP(''STACK   '')',CR,LF
                db      'PilaS      ENDS',CR,LF
                db      'DatiS      SEGMENT',CR,LF
                db      0
sProlog         db      'DatiS      ENDS',CR,LF
                db      'MainS      SEGMENT PARA ''CODE''',CR,LF
                db      '           ASSUME  CS:MainS, SS:PilaS, DS:DatiS',CR,LF
                db      'PrgPrin    PROC    FAR',CR,LF
                db      'lInizio    LABEL   NEAR',CR,LF
                db      '     mov     ax,SEG DatiS        ; DS = data segment',CR,LF
                db      '     mov     ds,ax',CR,LF
                db      0
sEpilog         db      '        jmp dos',CR,LF
                db      'PrgPrin    ENDP',CR,LF
                db      'MainS      ENDS',CR,LF
                db      'END     lInizio',CR,LF
                db      0
sAllocate       db      '      dw      0        ',CR,LF,0
sAllocateString db      '      db       ',0
sAllocateString2 db     ',0',CR,LF,0
sAllocateArray  db      '       dw      ',0
sAllocateArray2 db      ' dup(0)',CR,LF,0
sBranchFalse1   db      'TEST AX,1    ;set the flags from AX',0
sBranchFalse2   db      'JNE skip',0
sBranchFalse3   db      'JMP ',0
sBranchFalse4   db      'skip',0
sBranch         db      'JMP    ',0
sLoop           db      'LOOP ',0
sMOV            db      'MOV ',0
sStore2         db      ', AX           ;store',0
sStoreArray1    db      'POP BX        ;array index',CR,LF
                db      'ADD BX,BX     ;words: index * 2',CR,LF,0
sStoreArray1BIS db      'POP AX',CR,LF,0
sStoreArray2    db      '[BX], AX       ;store array',CR,LF,0
sLoadVar        db      'MOV AX, ',0
sLoadArray      db      "MOV BX, AX    ;array index",CR,LF
                db      'ADD BX,BX     ;words: index * 2',CR,LF
                db      'MOV AX, ',0
sLoadArrayBX    db      '[BX]',CR,LF,0
sChar_In        db      'CALL Char_In',CR,LF,0
sChar_Out       db      'CALL Char_Out',CR,LF,0
sWriteInteger   db      'CALL Wor2Dec',CR,LF,0
sReadInteger    db      'CALL DEC2BIN           ;read a decimal number into AX',CR,LF,0
sWriteString1   db      'LEA SI, ',0
sWriteString2   db      'CALL DSP_STR',CR,LF,0
sNewLine        db      'CALL NEW_LINE',CR,LF,0
sPush           db      'PUSH AX',CR,LF,0
sClear          db      'XOR AX,AX     ;AX = 0',CR,LF,0
sPopBX          db      'POP BX',CR,LF,0
sPopAdd         db      'ADD AX,BX',CR,LF,0
sPopSub         db      'SUB AX,BX',CR,LF,'NEG AX',CR,LF,0
sPopMul         db      'IMUL BX       ;DX:AX = AX * BX, keep AX',CR,LF,0
sPopDiv         db      'POP BX        ;dividend',CR,LF
                db      'XCHG AX,BX    ;AX = dividend, BX = divisor',CR,LF
                db      'CWD           ;sign-extend AX into DX',CR,LF
                db      'IDIV BX       ;AX = DX:AX / BX',CR,LF,0
sPopAnd         db      'AND AX,BX',CR,LF,0
sPopOr          db      'OR AX,BX',CR,LF,0
sPopXor         db      'XOR AX,BX',CR,LF,0
sPopCompare     db      'CMP BX,AX',CR,LF,0
sNotIt          db      'NOT AX',CR,LF,0
sSetEqual       db      'CALL SETE        ;set if equal',CR,LF,0
sSetNEqual      db      'CALL SETNE       ;set if not equal',CR,LF,0
sSetGreater     db      'CALL SETG        ;set if greater',CR,LF,0
sSetLess        db      'CALL SETL        ;set if less',CR,LF,0
sSetLessOrEqual db      'CALL SETLE       ;set if <=',CR,LF,0
sSetGreaterOrEqual db   'CALL SETGE       ;set if >=',CR,LF,0
DATI_S    ENDS
          ASSUME DS:DATI_S, ES:DATI_S
