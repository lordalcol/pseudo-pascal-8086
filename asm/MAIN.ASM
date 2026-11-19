;=============================================================================
; PSEUDO-PASCAL TO 8086 ASSEMBLY COMPILER
; Reads NAME.PAS and writes NAME.ASM, ready for MASM (or JWasm) and LINK.
; Author: Lorenzo Dal Col
; Date:   14 September 2006 (restored in 2026)
;
; Usage:  MAIN [name]      without the name, it asks for one
;=============================================================================
; MAIN PROGRAM
;=============================================================================
;
INCLUDE   INCLUDE/DATI.ASM              ;variables, symbol table, error messages,
                                        ;generated code strings, file buffers
; STANDALONE LIBRARIES
INCLUDE   RUNTIME.ASM                   ;keyboard and screen I/O, decimal output,
                                        ;exit to DOS (shared with compiled programs)
;
INCLUDE   INCLUDE/WERROR.ASM            ;compile and file I/O error messages
INCLUDE   INCLUDE/CHARS.ASM             ;character classes and strings: isAlpha,
                                        ;isDigit, strcmp, strcpy, PushString, PopString
INCLUDE   INCLUDE/FILE.ASM              ;buffered file I/O: fOpen, fCreate, fClose,
                                        ;fReadBuffer, fWriteBuffer, fGetC, fPutC
; COMPILER
INCLUDE   INCLUDE/PIO.ASM               ;compiler I/O: pGetChar (from the source file),
                                        ;output_str (to the output file), ReadString
INCLUDE   INCLUDE/WINSTR.ASM            ;code generator: writes the assembly text,
                                        ;constant strings plus names from the source
INCLUDE   INCLUDE/PGENERAL.ASM          ;scanner, symbol table, declarations,
                                        ;keyword lookup, file names
INCLUDE   INCLUDE/PBLOCKS.ASM           ;recursive descent parser for statements
                                        ;and expressions; calls the code generator
;
MAIN_S    SEGMENT PARA 'CODE'
          ASSUME CS:MAIN_S, DS:DATI_S, ES:DATI_S
PRG_PRIN  PROC FAR
mainINIZIO:
           mov ax,DATI_S                ;DS = data segment, ES still = PSP
           mov ds,ax
            call pCommandLine           ;file name from the command line, if any
           mov ax,ds
           mov es,ax                    ;ES = data segment too
            call pInit_nx               ;open the files and read the first token
            lea si,sPROGRAM
            call pMatchString_nx        ;MatchString('PROGRAM')
            call wHeader                ;write the header of the .ASM file
            call pTopDecls_nx           ;declarations (var, array, strings): fill the
                                        ;symbol table and allocate the data
            lea si,sBEGIN
            call pMatchString_nx        ;MatchString('BEGIN')
            call wProlog                ;write the start of the code segment
            call pBlock_nx              ;THE CORE: compile every statement up to END.
            lea si,sEND
            call pMatchString_nx        ;MatchString('END')
            call wEpilog                ;write the end of the program
            call pTerminate             ;flush and close the files
            jmp  DOS                    ;back to DOS
PRG_PRIN    ENDP
MAIN_S      ENDS
            END  mainINIZIO
