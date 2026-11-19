;=============================================================================
; SEGMENTO DEI DATI
;=============================================================================
; COSTANTI
TAB             equ     9
CR              equ     13
LF              equ     10
;
MaxEntry        equ     100     ;massimo numeri di simboli (variabili, array)
NKW             equ     19      ;numero di parole chiave
NKW1            equ     19
;=============================================================================
; IMPOSTO IL SEGMENTO PER LO STACK
PILA      SEGMENT STACK
          DB  128 DUP('STACK   ')       ;molto grande,
PILA      ENDS                          ;deve contenere anche stringhe
;=============================================================================
; IMPOSTO IL SEGMENTO PER I DATI
DATI_S    SEGMENT 'DATA'
;=============================================================================
; ========================= PAROLE CHIAVE DEL LINGUAGGIO =====================
sPROGRAM        db      "PROGRAM",0
sBEGIN          db      "BEGIN",0
sEND            db      "END",0
sENDIF          db      "ENDIF",0
sENDWHILE       db      "ENDWHILE",0
sENDLOOP        db      "ENDLOOP",0
sMASMcomment1   db      ";***** MASM",CR,LF,0
sMASMcomment2   db      ";***** ENDMASM",CR,LF,0
chrCOMMENT      db      ";"
KWlist          db      'IF',0, 'ELSE',0, 'ENDIF',0, 'WHILE',0, 'ENDWHILE',0
                db      'READ',0, 'WRITE',0, 'VAR',0, 'END',0, 'WRITEINT',0
                db      'READINT',0, 'MASM',0, 'ENDMASM',0, 'NEWLINE',0
                db      'LOOP',0,'ENDLOOP',0, 'WRITESTR',0, 'ARRAY',0
KWcode          db      'xileweRWveIJmMNLe§A'
;=============================================================================
;========================== VARIABILI GLOBALI ================================
LCount          dw      0
NEntry          dw      0
NLine           dw      1
Look            db      0
Token           db      0
Value           db      16 DUP(0)
TmpValue        db      16 DUP(0)
sLabel1         db      8 DUP(0)
sLabel2         db      8 DUP(0)
sInit           db      "1:",TAB,0
sIntro          db      "======= COMPILATORE DA PSEUDO-CODICE A ASSEMBLY =======",CR,LF
                db      "Inserire il nome del file da leggere senza estensione (.pas): ",0
;========================== ARRAY
SymbTable       db      MaxEntry DUP(0000h) ;array[1..MaxEntry] of string[16]
SType           db      MaxEntry DUP(0)          ;array[1..MaxEntry] of char
FileName        db      9 DUP(0)
ReadExtension   db      '.PAS'
ReadFileName    db      13 DUP(0)
ReadFHandle     dw      0
ReadBuffer      db      256 DUP(0)
ReadBufferIndex dw      0
WriteExtension  db      '.ASM'
WriteFileName   db      13 DUP(0)
WriteFHandle    dw      0
WriteBuffer      db     256 DUP(0)
WriteBufferIndex dw     0
;=============================================================================
;========================== STRINGHE ERRORI ==================================
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
sErrString      db      " String ($)",0
sErrString2     db      ' string identifier "',0
sErrAssignment  db      " assignment symbol = ",0
sErrArray1      db      " array index identifier [ ",0
sErrArray2      db      " array index identifier ] ",0
sStringIdent    db      'String Identifier ($)',0
sMathFactor     db      " Math Factor ",0
;===================== ERRORI I/O FILE
sErrFOpen       db      CR,LF,"Errore nell'apertura del file. ",0
sErrFRead       db      CR,LF,"Errore nella lettura del file. ",0
sErrFWrite      db      CR,LF,"Errore nella scrittura del file. ",0
sErrFClose      db      CR,LF,"Errore nella chiusura del file. ",0
sErrFCreate     db      CR,LF,"Errore nella creazione del file. ",0
;=============================================================================
;========================== STRINGHE ASM COMPIL. =============================
sCRLF           db      CR,LF,0
sCX             db      'CX',0
sParentAperta   db      '(',0
sParentChiusa   db      ')',0
sQuadChiusa     db      ']',0
sUguale         db      '=',0
sHeader         db      '           INCLUDE INCLUDE\set_if.ASM',CR,LF
                db      '           INCLUDE INCLUDE\util_prg.ASM',CR,LF
                db      '           INCLUDE INCLUDE\GIOBE.ASM',CR,LF
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
                db      '     mov     ax,SEG DatiS        ; Imposta indirizzabilità',CR,LF
                db      '     mov     ds,ax               ; del segmento dati',CR,LF
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
sBranchFalse1   db      'TEST AX,1    ;faccio il refresh dei flag secondo AX',CR,LF,0
sBranchFalse2   db      'JNE skip',0
sBranchFalse3   db      'JMP ',0
sBranchFalse4   db      'skip',0
sBranch         db      'JMP    ',0
sLoop           db      'LOOP ',0
sMOV            db      'MOV ',0
sStore2         db      ', AX           ;store',0
sStoreArray1    db      'POP BX        ;sposto l''indice dell''array appena calcolato',CR,LF
                db      'ADD BX,BX     ;moltiplico per due BX, poichè uso word',CR,LF,0
sStoreArray1BIS db      'POP AX',CR,LF,0
sStoreArray2    db      '[BX], AX       ;store array',CR,LF,0
sLoadVar        db      'MOV AX, ',0
sLoadArray      db      "MOV BX, AX    ;sposto l'indice dell'array appena calcolato",CR,LF
                db      'ADD BX,BX     ;moltiplico per due BX, poichè uso word',CR,LF
                db      'MOV AX, ',0
sLoadArrayBX    db      '[BX]',CR,LF,0
sChar_In        db      'CALL Char_In',CR,LF,0
sChar_Out       db      'CALL Char_Out',CR,LF,0
sWriteInteger   db      'CALL Wor2Dec',CR,LF,0
sReadInteger    db      'CALL DEC2BIN           ; Legge un n decim da tast, lo converte in bin e lo ritorna in AX',CR,LF,0
sWriteString1   db      'LEA SI, ',0
sWriteString2   db      'CALL DSP_STR',CR,LF,0
sNewLine        db      'CALL NEW_LINE',CR,LF,0
sPush           db      'PUSH AX',CR,LF,0
sClear          db      'XOR AX,AX     ;porta AX a zero',CR,LF,0
sPopBX          db      'POP BX',CR,LF,0
sPopAdd         db      'ADD AX,BX',CR,LF,0
sPopSub         db      'SUB AX,BX',CR,LF,'NEG AX',CR,LF,0
sPopMul         db      'IMUL BX       ;eax(32)=ax(16)*bx(16) ;uso solo ax',CR,LF,0
sPopDiv         db      'MOV DX, 0     ;preparo per la divisione',CR,LF
                db      'POP BX        ;raccolgo il dividendo',CR,LF
                db      'XCHG AX,BX    ;scambio divisore e dividendo',CR,LF
                db      'IDIV BX       ;ax(16)=dx:ax(32) / bx(16)',CR,LF,0
sPopAnd         db      'AND AX,BX',CR,LF,0
sPopOr          db      'OR AX,BX',CR,LF,0
sPopXor         db      'XOR AX,BX',CR,LF,0
sPopCompare     db      'CMP BX,AX',CR,LF,0
sNotIt          db      'NOT AX',CR,LF,0
sSetEqual       db      'CALL SETE    ;set if equal',CR,LF,0
sSetNEqual      db      'CALL SETNE       ;set if NOT equal',CR,LF,0
sSetGreater     db      'CALL SETA      ;set if Greater',CR,LF,0
sSetLess        db      'CALL SETB       ;set if Less',CR,LF,0
sSetLessOrEqual db      'CALL SETBE       ;set if <=',CR,LF,0
sSetGreaterOrEqual db   'CALL SETAE       ;set if >=',CR,LF,0
DATI_S    ENDS
