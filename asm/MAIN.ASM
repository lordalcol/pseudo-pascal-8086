;=============================================================================
; COMPILATORE DA PSEUDO-CODICE PASCAL A CODICE ASSEMBLY TRADUCIBILE CON MASM
; Autore: Lorenzo Dal Col
; Data:   14 settembre 2006
; Email:  lorenzo.dalcol@gmail.com
;=============================================================================
; PROGRAMMA PRINCIPALE
;=============================================================================
;
INCLUDE   INCLUDE/DATI.ASM              ;dichiarazioni var. utilizzate, stringhe codice
                                        ;stringhe degli errori e i buffer per IO files
; LIBRERIE "INDIPENDENTI"
INCLUDE   INCLUDE/UTIL_PRG.ASM          ;libr. "standard": char_in,char_out,dsp_str,dos
INCLUDE   INCLUDE/GIOBE.ASM             ;libr. "standard": wor2dec,wor2asc,ecc
;
INCLUDE   INCLUDE/wError.ASM            ;tutte le procedure per la visualizzazione degli 
                                        ;errori di compilazione e IO files
INCLUDE   INCLUDE/CHARS.ASM             ;proc. utili per chars e stringhe: isAlpha,
                                        ;isNum,strcmp,strcpy, PushString, PopString
INCLUDE   INCLUDE/file.ASM              ;proc. IO file in modalità bufferizzata 
                                        ;(fOpen,fCreate,fClose,fReadBuffer,fWriteBuffer
; LIBRERIE CORRELATE
INCLUDE   INCLUDE/pIO.ASM               ;proc. usate dal programma per IO: pGetChar (da 
                                        ;file), output_str (su file), ReadString
INCLUDE   INCLUDE/wINSTR.ASM            ;proc. per la scrittura del codice ASM compilato: 
                                        ;compongono stringhe costanti con str dinamiche
INCLUDE   INCLUDE/pGENERAL.ASM          ;proc. principali: SCANNER, PARSER, gestione 
                                        ;della TABELLA DEI SIMBOLI, proc di allocazione e
                                        ;di riconoscimento dei TOKEN (parole chiave)
INCLUDE   INCLUDE/pBlocks.ASM           ;proc. collegate fra loro in ricorsione per 
                                        ;l'analisi dei blocchi di codice e le chiamate
                                        ;alle proc. di composizione del codice ASM
;
MAIN_S    SEGMENT PARA 'CODE'
          ASSUME CS:MAIN_S, DS:DATI_S, ES:DATI_S
PRG_PRIN  PROC FAR
mainINIZIO:
           mov ax,DATI_S                ;preparo DS,ES impostati sul segmento dei dati
           mov ds,ax
           mov es,ax
            call pInit_nx               ;Inizializzo lettura, scrittura dei file, e leggo il primo TOKEN
            lea si,sPROGRAM
            call pMatchString_nx        ;MatchString('PROGRAM')
            call wHeader                ;scrivo il codice asm dell' "Header"
            call pTopDecls_nx           ;analizzo la dichiarazione delle variabili (var,array,stringhe), creo la TAB.DEI SIMBOLI e alloco
            lea si,sBEGIN
            call pMatchString_nx        ;MatchString('BEGIN')
            call wProlog                ;scrivo il codice asm del "Prolog"
            call pBlock_nx              ;CUORE DEL PROGRAMMA: analizzo in sequenza tutti i BLOCCHI DI CODICE OPERATIVO fino a END.
            lea si,sEND                 
            call pMatchString_nx        ;MatchString('END')
            call wEpilog                ;scrivo il codice asm finale
            call pTerminate             ;chiudo i files aperti
            jmp  DOS                    ;ritorno al DOS
PRG_PRIN    ENDP
MAIN_S      ENDS
            END  mainINIZIO