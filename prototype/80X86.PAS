       {--------------------------------------------------------------}
       program Tiny11;

       {--------------------------------------------------------------}
       { Constant Declarations }

       const TAB = ^I;
             CR  = ^M;
             LF  = ^J;

             LCount: integer = 0;
             NEntry: integer = 0;


       {--------------------------------------------------------------}
       { Type Declarations }

       type Symbol = string[8];

            SymTab = array[1..1000] of Symbol;

            TabPtr = ^SymTab;


       {--------------------------------------------------------------}
       { Variable Declarations }

       var Look : char;             { Lookahead Character }
           Token: char;             { Encoded Token       }
           Value: string[16];       { Unencoded Token     }


       const MaxEntry = 100;

       var ST   : array[1..MaxEntry] of Symbol;
           SType: array[1..MaxEntry] of char;


       {--------------------------------------------------------------}
       { Definition of Keywords and Token Types }

       const NKW =   18;
             NKW1 = 19;

       const KWlist: array[1..NKW] of Symbol =
                     ('IF', 'ELSE', 'ENDIF', 'WHILE', 'ENDWHILE',
                      'READ', 'WRITE', 'VAR', 'END', 'WRITEINT',
                      'READINT', 'MASM', 'ENDMASM', 'NEWLINE',
                      'LOOP','ENDLOOP', 'WRITESTR', 'ARRAY' );

       const KWcode: string[NKW1] = 'xileweRWveIJmMNLe§A';

       var f,fread: text;
       var nline: integer;
       const basepath = '';
       {--------------------------------------------------------------}
       { Read New Character From Input Stream }

       procedure GetChar;
       begin
          Read(fread,Look);
          if look=CR then nline:=nline+1;
       end;

       {--------------------------------------------------------------}
       { Output a String on file }

       procedure Output(s: string);
       begin
          Write(f, s);
       end;

       {--------------------------------------------------------------}
       { Output a String on file with CRLF }

       procedure OutputLn(s: string);
       begin
          Output(s+CR+LF);
       end;

       {--------------------------------------------------------------}
       { Report an Error }

       procedure Error(s: string);
       begin
          WriteLn('');
          WriteLn(^G + '[LINE: ',nline,'] Error: ' + s + '.');
       end;


       {--------------------------------------------------------------}
       { Report Error and Halt }

       procedure Abort(s: string);
       begin
          Error(s);
          Halt;
       end;


       {--------------------------------------------------------------}
       { Report What Was Expected }

       procedure Expected(s: string);
       begin
          Abort(s + ' Expected');
       end;

       {--------------------------------------------------------------}
       { Report an Undefined Identifier }

       procedure Undefined(n: string);
       begin
          Abort('Undefined Identifier ' + n);
       end;


       {--------------------------------------------------------------}
       { Report a Duplicate Identifier }

       procedure Duplicate(n: string);
       begin
          Abort('Duplicate Identifier ' + n);
       end;


       {--------------------------------------------------------------}
       { Check to Make Sure the Current Token is an Identifier }

       procedure CheckIdent;
       begin
          if Token <> 'x' then Expected('Identifier');
       end;


       {--------------------------------------------------------------}
       { Recognize an Alpha Character }

       function IsAlpha(c: char): boolean;
       begin
          IsAlpha := UpCase(c) in ['A'..'Z'];
       end;


       {--------------------------------------------------------------}
       { Recognize a Decimal Digit }

       function IsDigit(c: char): boolean;
       begin
          IsDigit := c in ['0'..'9'];
       end;


       {--------------------------------------------------------------}
       { Recognize an AlphaNumeric Character }

       function IsAlNum(c: char): boolean;
       begin
          IsAlNum := IsAlpha(c) or IsDigit(c);
       end;


       {--------------------------------------------------------------}
       { Recognize an Addop }

       function IsAddop(c: char): boolean;
       begin
          IsAddop := c in ['+', '-'];
       end;


       {--------------------------------------------------------------}
       { Recognize a Mulop }

       function IsMulop(c: char): boolean;
       begin
          IsMulop := c in ['*', '/'];
       end;


       {--------------------------------------------------------------}
       { Recognize a Boolean Orop }

       function IsOrop(c: char): boolean;
       begin
          IsOrop := c in ['|', '~'];
       end;


       {--------------------------------------------------------------}
       { Recognize a Relop }

       function IsRelop(c: char): boolean;
       begin
          IsRelop := c in ['=', '#', '<', '>'];
       end;

       {--------------------------------------------------------------}
       { Recognize White Space }

       function IsWhite(c: char): boolean;
       begin
          IsWhite := c in [' ', TAB, CR, LF, ';'];
       end;
       {--------------------------------------------------------------}
       
       {--------------------------------------------------------------}
       { Skip A Comment Field }

       procedure SkipComment;
       begin
          while Look <> CR do begin
             GetChar;
             {if Look = '{' then SkipComment;}
          end;
          GetChar;
       end;
       {--------------------------------------------------------------}

       {--------------------------------------------------------------}
       { Skip Over Leading White Space }

       procedure SkipWhite;
       begin
          while IsWhite(Look) do begin
             if Look = ';' then
                SkipComment
             else
                GetChar;
          end;
       end;
       {--------------------------------------------------------------}


       {--------------------------------------------------------------}
       { Table Lookup }

       function Lookup(T: TabPtr; s: string; n: integer): integer;
       var i: integer;
           found: Boolean;
       begin
          found := false;
          i := n;
          while (i > 0) and not found do
             if s = T^[i] then
                found := true
             else
                dec(i);
          Lookup := i;
       end;


       {--------------------------------------------------------------}
       { Locate a Symbol in Table }
       { Returns the index of the entry.  Zero if not present. }

       function Locate(N: Symbol): integer;
       begin
          Locate := Lookup(@ST, n, NEntry);
       end;


       {--------------------------------------------------------------}
       { Look for Symbol in Table }

       function InTable(n: Symbol): Boolean;
       begin
          InTable := Lookup(@ST, n, NEntry) <> 0;
       end;


       {--------------------------------------------------------------}
       { Check to See if an Identifier is in the Symbol Table         }
       { Report an error if it's not. }


       procedure CheckTable(N: Symbol);
       begin
          if not InTable(N) then Undefined(N);
       end;


       {--------------------------------------------------------------}
       { Check the Symbol Table for a Duplicate Identifier }
       { Report an error if identifier is already in table. }


       procedure CheckDup(N: Symbol);
       begin
          if InTable(N) then Duplicate(N);
       end;


       {--------------------------------------------------------------}
       { Add a New Entry to Symbol Table }

       procedure AddEntry(N: Symbol; T: char);
       begin
          CheckDup(N);
          if NEntry = MaxEntry then Abort('Symbol Table Full');
          Inc(NEntry);
          ST[NEntry] := N;
          SType[NEntry] := T;
       end;

       {--------------------------------------------------------------}
       { Match a Specific Input String }
       procedure Next; Forward;
       procedure MatchString(x: string);
       begin
          if Value <> x then Expected('''' + x + '''');
          Next;
       end;

       {--------------------------------------------------------------}
       { Get an Identifier }

       procedure GetName;
       begin
          SkipWhite;
          if Not IsAlpha(Look) then Expected('Identifier');
          Token := 'x';
          Value := '';
          repeat
             Value := Value + UpCase(Look);
             GetChar;
          until not IsAlNum(Look);
       end;


       {--------------------------------------------------------------}
       { Get a Number }

       procedure GetNum;
       begin
          SkipWhite;
          if not IsDigit(Look) then Expected('Number');
          Token := '#';
          Value := '';
          repeat
             Value := Value + Look;
             GetChar;
          until not IsDigit(Look);
       end;

       {--------------------------------------------------------------}
       { Get a Char }
          
       procedure GetIntChar;
       begin
          if Look<>'''' then Expected('Starter char identifier ('')');
          Token := '#';
          GetChar;
          Value:=''''+Look+'''';
          GetChar;
          if Look<>'''' then Expected('Final char identifier ('')');
          getchar;
       end;

       {--------------------------------------------------------------}
       { Get a String }

       procedure GetStringName;
       begin
          if Look<>'$' then Expected('String Identifier ($)');
          Token := '$';
          Value := '';
          repeat
             Value := Value + UpCase(Look);
             GetChar;
          until not IsAlNum(Look);
       end;
          
       {--------------------------------------------------------------}
       { Get an Operator }

       procedure GetOp;
       begin
          SkipWhite;
          Token := Look;
          Value := Look;
          GetChar;
       end;
          
       {--------------------------------------------------------------}
       { Get the Next Input Token }

       procedure Next;
       begin
          SkipWhite;
          if IsAlpha(Look) then GetName
          else if IsDigit(Look) then GetNum
          else if Look='''' then GetIntChar
          else if Look='$' then GetStringName
          else GetOp;
       end;
          
       {--------------------------------------------------------------}
       { Scan the Current Identifier for Keywords }

       procedure Scan;
       begin
          if Token = 'x' then
             Token := KWcode[Lookup(Addr(KWlist), Value, NKW) + 1];
       end;
          
       {--------------------------------------------------------------}
       { Output a String with Tab }

       procedure Emit(s: string);
       begin
          Output(TAB + s);
       end;


       {--------------------------------------------------------------}
       { Output a String with Tab and CRLF }

       procedure EmitLn(s: string);
       begin
          Emit(s);
          OutputLn('');
       end;

{######################################## codici ###############################
################################################################################}

       {--------------------------------------------------------------}
       { Generate a Unique Label }

       function NewLabel: string;
       var S: string;
       begin
          Str(LCount, S);
          NewLabel := 'L' + S;
          Inc(LCount);
       end;


       {--------------------------------------------------------------}
       { Post a Label To Output }

       procedure PostLabel(L: string);
       begin
          OutputLn(L + ':');
       end;


       {---------------------------------------------------------------}
       { Clear the Primary Register }

       procedure Clear;
       begin
          EmitLn('XOR AX,AX     ;porta AX a zero');
          {EmitLn('CLR D0');}
       end;


       {---------------------------------------------------------------}
       { Negate the Primary Register }

       procedure Negate;
       begin
          EmitLn('NEG AX');
          { EmitLn('NEG D0');}
       end;


       {---------------------------------------------------------------}
       { Complement the Primary Register }

       procedure NotIt;
       begin
          EmitLn('NOT AX');
          {EmitLn('NOT D0');}
       end;


       {---------------------------------------------------------------}
       { Load a Constant Value to Primary Register }

       procedure LoadConst(n: string);
       begin
          Emit('MOV ');
          OutputLn('AX, ' + n);
          {Emit('MOVE #');
          OutputLn(n, ',D0');}
       end;


       {---------------------------------------------------------------}
       { Load a Variable to Primary Register }

       procedure LoadVar(Name: string);
       begin
          if not InTable(Name) then Undefined(Name);
          EmitLn('MOV AX, ' + Name);
          {EmitLn('MOVE ' + Name + '(PC),D0');}
       end;

       {---------------------------------------------------------------}
       { Load an ARRAY value to Primary Register }

       procedure LoadArray(Name: string);
       begin
          if not InTable(Name) then Undefined(Name);
          EmitLn('MOV BX, AX    ;sposto l''indice dell''array appena calcolato');
          EmitLn('ADD BX,BX     ;moltiplico per due BX, poichè uso word');
          EmitLn('MOV AX, ' + Name + '[BX]');
          {EmitLn('MOVE ' + Name + '(PC),D0');}
       end;

       {---------------------------------------------------------------}
       { Push Primary onto Stack }

       procedure Push;
       begin
          EmitLn('PUSH AX');
          {EmitLn('MOVE D0,-(SP)');}
       end;


       {---------------------------------------------------------------}
       { Add Top of Stack to Primary }

       procedure PopAdd;
       begin
          EmitLn('POP BX');
          EmitLn('ADD AX,BX');
          {EmitLn('ADD (SP)+,D0');}
       end;


       {---------------------------------------------------------------}
       { Subtract Primary from Top of Stack }

       procedure PopSub;
       begin
          EmitLn('POP BX');
          EmitLn('SUB AX,BX');
          EmitLn('NEG AX');
          {EmitLn('SUB (SP)+,D0');
          EmitLn('NEG D0');}
       end;


       {---------------------------------------------------------------}
       { Multiply Top of Stack by Primary }

       procedure PopMul;
       begin
          EmitLn('POP BX');
          EmitLn('IMUL BX       ;eax(32)=ax(16)*bx(16) ;uso solo ax, in caso inserire un controllo overflow');
          {EmitLn('MULS (SP)+,D0');}
       end;


       {---------------------------------------------------------------}
       { Divide Top of Stack by Primary }

       procedure PopDiv;
       begin
          EmitLn('MOV DX, 0     ;preparo per la divisione');
          EmitLn('POP BX        ;raccolgo il dividendo');
          EmitLn('XCHG AX,BX    ;scambio divisore e dividendo');
          EmitLn('IDIV BX       ;ax(16)=dx:ax(32) / bx(16)');
          {EmitLn('MOVE (SP)+,D7');
          EmitLn('EXT.L D7');
          EmitLn('DIVS D0,D7');
          EmitLn('MOVE D7,D0');}
       end;


       {---------------------------------------------------------------}
       { AND Top of Stack with Primary }

       procedure PopAnd;
       begin
          EmitLn('POP BX');
          EmitLn('AND AX,BX');
          {EmitLn('AND (SP)+,D0');}
       end;


       {---------------------------------------------------------------}
       { OR Top of Stack with Primary }

       procedure PopOr;
       begin
          EmitLn('POP BX');
          EmitLn('OR AX,BX');
          {EmitLn('OR (SP)+,D0');}
       end;
       
       {---------------------------------------------------------------}
       { XOR Top of Stack with Primary }

       procedure PopXor;
       begin
          EmitLn('POP BX');
          EmitLn('XOR AX,BX');
          {EmitLn('EOR (SP)+,D0');}
       end;


       {---------------------------------------------------------------}
       { Compare Top of Stack with Primary }

       procedure PopCompare;
       begin
          EmitLn('POP BX');
          EmitLn('CMP BX,AX');
          {EmitLn('CMP (SP)+,D0');}
       end;


       {---------------------------------------------------------------}
       { Set D0 If Compare was = }

       procedure SetEqual;
       begin
           EmitLn('CALL SETE    ;set if equal');
          {EmitLn('SETE AX       ;set if equal');}
          {EmitLn('SEQ D0');
          EmitLn('EXT D0');}
       end;


       {---------------------------------------------------------------}
       { Set D0 If Compare was != }

       procedure SetNEqual;
       begin
           EmitLn('CALL SETNE       ;set if NOT equal');
          {EmitLn('SETNE AX       ;set if NOT equal');}
          {EmitLn('SNE D0');
          EmitLn('EXT D0');}
       end;


       {---------------------------------------------------------------}
       { Set D0 If Compare was > }

       procedure SetGreater;
       begin
          EmitLn('CALL SETA      ;set if Greater');
          {EmitLn('SETA AX       ;set if Greater');}
          {EmitLn('SLT D0');
          EmitLn('EXT D0');}
       end;


       {---------------------------------------------------------------}
       { Set D0 If Compare was < }

       procedure SetLess;
       begin
           EmitLn('CALL SETB       ;set if Less');
         {EmitLn('SETB AX       ;set if Less');}
          {EmitLn('SGT D0');
          EmitLn('EXT D0');}
       end;


       {---------------------------------------------------------------}
       { Set D0 If Compare was <= }

       procedure SetLessOrEqual;
       begin
           EmitLn('CALL SETBE       ;set if <=');
         {EmitLn('SETBE AX       ;set if <=');}
          {EmitLn('SGE D0');
          EmitLn('EXT D0');}
       end;


       {---------------------------------------------------------------}
       { Set D0 If Compare was >= }

       procedure SetGreaterOrEqual;
       begin
         EmitLn('CALL SETAE       ;set if >=');
         {EmitLn('SETAE AX       ;set if >=');}
          {EmitLn('SLE D0');
          EmitLn('EXT D0');}
       end;


       {---------------------------------------------------------------}
       { Store Primary to Variable }

       procedure Store(Name: string);
       begin
          EmitLn('MOV '+Name+', AX');
          {EmitLn('LEA ' + Name + '(PC),A0');
          EmitLn('MOVE D0,(A0)')}
       end;

       {---------------------------------------------------------------}
       { Store Array to Variable }

       procedure StoreArray(Name: string; isAssign: boolean);
       begin
          EmitLn('POP BX        ;sposto l''indice dell''array appena calcolato');
          EmitLn('ADD BX,BX     ;moltiplico per due BX, poichè uso word');
          if NOT isAssign then EmitLn('POP AX');
          EmitLn('MOV ' + Name + '[BX], AX');
       end;

       {---------------------------------------------------------------}
       { Branch Unconditional  }

       procedure Branch(L: string);
       begin
          EmitLn('JMP ' + L);
          {EmitLn('BRA ' + L);}
       end;


       {---------------------------------------------------------------}
       { Branch False }

       procedure BranchFalse(L: string);
       begin
           EmitLn('TEST AX,1    ;faccio il refresh dei flag secondo AX');
           EmitLn('JNE skip' + L);
           EmitLn('JMP ' + L);
           EmitLn('skip'+L+': ');
          {EmitLn('TST D0');
          EmitLn('BEQ ' + L);}
       end;


       {---------------------------------------------------------------}
       { Read Variable to Primary Register }
       procedure BoolExpression; Forward;
       procedure ReadIt(Name: string);
       begin
          EmitLn('CALL Char_In           ;da rifare (solo 8bit ora)');
          {EmitLn('BSR READ');}
          Next;
          if Token='[' then begin
                Push;
                Next;
                BoolExpression;
                MatchString(']');
                Push;
                StoreArray(Name,FALSE)
          end else begin
              Store(Name);
          end;
       end;


       { Write from Primary Register }

       procedure WriteIt;
       begin
          EmitLn('CALL Char_Out          ;da rifare (solo 8bit ora)');
          {EmitLn('BSR WRITE');}
       end;

       {---------------------------------------------------------------}
       { Read Integer to Primary Register }

       procedure ReadInteger(Name: string);
       begin
          EmitLn('CALL DEC2BIN           ; Legge un n decim da tast, lo converte in bin e lo ritorna in AX');
          {EmitLn('BSR READ');}
          Next;
          if Token='[' then begin
                Push;
                Next;
                BoolExpression;
                MatchString(']');
                Push;
                StoreArray(Name,FALSE)
          end else begin
              Store(Name);
          end;
       end;

       { Write from Primary Register }

       procedure NewLine;
       begin
          EmitLn('CALL NEW_LINE');
       end;
       
       
       { Write Integer from Primary Register }

       procedure WriteInteger;
       begin
          EmitLn('CALL Wor2Dec');
       end;
       
       { Write String }

       procedure WriteString;
       begin
          EmitLn('LEA SI,' + Value);
          EmitLn('CALL DSP_STR');
       end;
       
       {--------------------------------------------------------------}
       { Write Header Info }

       procedure Header;
       begin
           OutputLn('           INCLUDE set_if.ASM');
           OutputLn('           INCLUDE util_prg.ASM');
           OutputLn('           INCLUDE GIOBE.ASM');
           OutputLn('PilaS      SEGMENT STACK');
           OutputLn('           db      32 DUP(''STACK   '')');
           OutputLn('PilaS      ENDS');
           OutputLn('DatiS      SEGMENT');
          {OutputLn('WARMST', TAB, 'EQU $A01E');}
       end;


       {--------------------------------------------------------------}
       { Write the Prolog }

       procedure Prolog;
       begin
          OutputLn('DatiS      ENDS');
          OutputLn('MainS      SEGMENT PARA ''CODE''');
          OutputLn('           ASSUME  CS:MainS, SS:PilaS, DS:DatiS');
          OutputLn('PrgPrin    PROC    FAR');
          OutputLn('lInizio    LABEL   NEAR');
          OutputLn('     mov     ax,SEG DatiS        ; Imposta indirizzabilità');
          OutputLn('     mov     ds,ax               ; del segmento dati');
          {PostLabel('MAIN');}
       end;


       {--------------------------------------------------------------}
       { Write the Epilog }

       procedure Epilog;
       begin
          OutputLn('        jmp dos');
          OutputLn('PrgPrin    ENDP');
          OutputLn('MainS      ENDS');
          OutputLn('END     lInizio');
          {EmitLn('DC WARMST');
          EmitLn('END MAIN');}
       end;

{################################### fine codici ###############################
################################################################################}

       {---------------------------------------------------------------}
       { Allocate Storage for a Static Variable }

       procedure Allocate(Name, Val: string);
       begin
           OutputLn(Name + '      dw      ' + Val);
          {OutputLn(Name, ':', TAB, 'DC ', Val);}
       end;
       
       {---------------------------------------------------------------}
       { Allocate Storage for a String Variable }

       procedure AllocateString(Name, Val: string);
       begin
           OutputLn(Name + '      db      ' + Val + ',0');
          {OutputLn(Name, ':', TAB, 'DC ', Val);}
       end;
       
       {---------------------------------------------------------------}
       { Parse and Translate a Math Factor }

       procedure Factor;
       var Name: string;
       begin
          if Token = '(' then begin
             Next;
             BoolExpression;
             MatchString(')');
             end
          else begin
             if Token = 'x' then begin
                Name:=Value;
                Next;
                if Token<>'[' then
                    LoadVar(Name)
                else begin
                    Next;
                    BoolExpression;
                    MatchString(']');
                    LoadArray(Name)
                end;
             end
             else if Token = '#' then begin
                LoadConst(Value);
                Next;
             end else Expected('Math Factor');
          end;
       end;


       {--------------------------------------------------------------}
       { Recognize and Translate a Multiply }

       procedure Multiply;
       begin
          Next;
          Factor;
          PopMul;
       end;


       {-------------------------------------------------------------}
       { Recognize and Translate a Divide }

       procedure Divide;
       begin
          Next;
          Factor;
          PopDiv;
       end;


       {---------------------------------------------------------------}
       { Parse and Translate a Math Term }

       procedure Term;
       begin
          Factor;
          while IsMulop(Token) do begin
             Push;
             case Token of
              '*': Multiply;
              '/': Divide;
             end;
          end;
       end;


       {--------------------------------------------------------------}
       { Recognize and Translate an Add }

       procedure Add;
       begin
          Next;
          Term;
          PopAdd;
       end;


       {-------------------------------------------------------------}
       { Recognize and Translate a Subtract }

       procedure Subtract;
       begin
          Next;
          Term;
          PopSub;
       end;


       {---------------------------------------------------------------}
       { Parse and Translate an Expression }

       procedure Expression;
       begin
          if IsAddop(Token) then
             Clear
          else
             Term;
          while IsAddop(Token) do begin
             Push;
             case Token of
              '+': Add;
              '-': Subtract;
             end;
          end;
       end;


       {---------------------------------------------------------------}
       { Get Another Expression and Compare }

       procedure CompareExpression;
       begin
          Expression;
          PopCompare;
       end;


       {---------------------------------------------------------------}
       { Get The Next Expression and Compare }

       procedure NextExpression;
       begin
          Next;
          CompareExpression;
       end;


       {---------------------------------------------------------------}
       { Recognize and Translate a Relational "Equals" }

       procedure Equal;
       begin
          NextExpression;
          SetEqual;
       end;


       {---------------------------------------------------------------}
       { Recognize and Translate a Relational "Less Than or Equal" }

       procedure LessOrEqual;
       begin
          NextExpression;
          SetLessOrEqual;
       end;


       {---------------------------------------------------------------}
       { Recognize and Translate a Relational "Not Equals" }

       procedure NotEqual;
       begin
          NextExpression;
          SetNEqual;
       end;


       {---------------------------------------------------------------}
       { Recognize and Translate a Relational "Less Than" }

       procedure Less;
       begin
          Next;
          case Token of
            '=': LessOrEqual;
            '>': NotEqual;
          else begin
                  CompareExpression;
                  SetLess;
               end;
          end;
       end;


       {---------------------------------------------------------------}
       { Recognize and Translate a Relational "Greater Than" }

       procedure Greater;
       begin
          Next;
          if Token = '=' then begin
             NextExpression;
             SetGreaterOrEqual;
             end
          else begin
             CompareExpression;
             SetGreater;
          end;
       end;


       {---------------------------------------------------------------}
       { Parse and Translate a Relation }


       procedure Relation;
       begin
          Expression;
          if IsRelop(Token) then begin
             Push;
             case Token of
              '=': Equal;
              '<': Less;
              '>': Greater;
             end;
          end;
       end;


       {---------------------------------------------------------------}
       { Parse and Translate a Boolean Factor with Leading NOT }

       procedure NotFactor;
       begin
          if Token = '!' then begin
             Next;
             Relation;
             NotIt;
             end
          else
             Relation;
       end;


       {---------------------------------------------------------------}
       { Parse and Translate a Boolean Term }

       procedure BoolTerm;
       begin
          NotFactor;
          while Token = '&' do begin
             Push;
             Next;
             NotFactor;
             PopAnd;
          end;
       end;


       {--------------------------------------------------------------}
       { Recognize and Translate a Boolean OR }

       procedure BoolOr;
       begin
          Next;
          BoolTerm;
          PopOr;
       end;


       {--------------------------------------------------------------}
       { Recognize and Translate an Exclusive Or }

       procedure BoolXor;
       begin
          Next;
          BoolTerm;
          PopXor;
       end;


       {---------------------------------------------------------------}
       { Parse and Translate a Boolean Expression }

       procedure BoolExpression;
       begin
          BoolTerm;
          while IsOrOp(Token) do begin
             Push;
             case Token of
              '|': BoolOr;
              '~': BoolXor;
             end;
          end;
       end;

       {--------------------------------------------------------------}
       { Parse and Translate an Assignment Statement }

       procedure Assignment;
       var Name: string;
       var arr: boolean;
       begin
          arr:=FALSE;
          CheckTable(Value);
          Name := Value;
          Next;
          if Token='[' then begin
                Next;
                BoolExpression;
                MatchString(']');
                Push;
                arr:=TRUE;
          end;
          MatchString('=');
          BoolExpression;
          if arr then begin
              StoreArray(Name,TRUE)
          end
          else
              Store(Name);
       end;


       {---------------------------------------------------------------}
       { Recognize and Translate an IF Construct }

       procedure Block; Forward;

       procedure DoIf;
       var L1, L2: string;
       begin
          Next;
          BoolExpression;
          L1 := NewLabel;
          L2 := L1;
          BranchFalse(L1);
          Block;
          if Token = 'l' then begin
             Next;
             L2 := NewLabel;
             Branch(L2);
             PostLabel(L1);
             Block;
          end;
          PostLabel(L2);
          MatchString('ENDIF');
       end;


       {--------------------------------------------------------------}
       { Parse and Translate a WHILE Statement }

       procedure DoWhile;
       var L1, L2: string;
       begin
          Next;
          L1 := NewLabel;
          L2 := NewLabel;
          PostLabel(L1);
          BoolExpression;
          BranchFalse(L2);
          Block;
          MatchString('ENDWHILE');
          Branch(L1);
          PostLabel(L2);
       end;

       {--------------------------------------------------------------}
       { Parse and Translate a LOOP Statement }

       procedure DoLoop;
       var L1: string;
       begin
          Next;
          BoolExpression;
          Store('CX');
          L1 := NewLabel;
          PostLabel(L1);
          Block;
          MatchString('ENDLOOP');
          EmitLn('LOOP ' + L1);
       end;

       {--------------------------------------------------------------}
       { Read a Single Variable }

       procedure ReadVar;
       begin
          CheckIdent;
          CheckTable(Value);
          ReadIt(Value);
          {Next;}
       end;


       {--------------------------------------------------------------}
       { Process a Read Statement }

       procedure DoRead;
       begin
          Next;
          MatchString('(');
          ReadVar;
          while Token = ',' do begin
             Next;
             ReadVar;
          end;
          MatchString(')');
       end;


       {--------------------------------------------------------------}
       { Process a Write Statement }

       procedure DoWrite;
       begin
          Next;
          MatchString('(');
          Expression;
          WriteIt;
          while Token = ',' do begin
             Next;
             Expression;
             WriteIt;
          end;
          MatchString(')');
       end;

       {--------------------------------------------------------------}
       { Process a NewLine Statement }

       procedure DoNewLine;
       begin
            NewLine;
            Next;
       end;
          
       {--------------------------------------------------------------}
       { Read a Single Variable Integer }

       procedure ReadIntVar;
       begin
          CheckIdent;
          CheckTable(Value);
          ReadInteger(Value);
          {Next;}
       end;
          
       {--------------------------------------------------------------}
       { Process a Read Integer Statement }

       procedure DoReadInt;
       begin
          Next;
          MatchString('(');
          ReadIntVar;
          while Token = ',' do begin
             Next;
             ReadIntVar;
          end;
          MatchString(')');
       end;


       {--------------------------------------------------------------}
       { Process a Write Integer Statement }

       procedure DoWriteInt;
       begin
          Next;
          MatchString('(');
          Expression;
          WriteInteger;
          while Token = ',' do begin
             Next;
             Expression;
             WriteInteger;
          end;
          MatchString(')');
       end;
          
       {--------------------------------------------------------------}
       { Process a Write STRING Statement }

       procedure DoWriteString;
       begin
          Next;
          MatchString('(');
          if Token<>'$' then Expected('String Identifier ($)');
          WriteString;
          Next;
          while Token = ',' do begin
             Next;
             if Token<>'$' then Expected('String Identifier ($)');
             WriteString;
             Next;
          end;
          MatchString(')');
       end;

       {--------------------------------------------------------------}
       { Process a MASM Statement (FREE Assembly into language) }
          
       procedure DoMasm;
          var rowBuffer: string;
       begin
          rowBuffer:='';
          Next;
          Scan;
          while Token<>'M' do begin
            rowBuffer:= rowBuffer + TAB + Value + ' ';
            while Look<>CR do begin
                GetChar;
                rowBuffer:=rowBuffer + Look;
            end;
            rowBuffer:=rowBuffer + LF;
            Next;
            Scan;
          end;
            OutputLn(';************************** MASM');
          Output(rowBuffer);
            OutputLn(';************************** ENDMASM');
          Next;
       end;
          
       {--------------------------------------------------------------}
       { Parse and Translate a Block of Statements }
          
       procedure Block;
       begin
          Scan;
          while not(Token in ['e', 'l']) do begin
             case Token of
              'i': DoIf;
              'w': DoWhile;
              'L': DoLoop;
              'R': DoRead;
              'W': DoWrite;
              'I': DoWriteInt;
              'J': DoReadInt;
              '§': DoWriteString;
              'm': DoMasm;
              'N': DoNewLine;
             else Assignment;
             end;
             Scan;
          end;
       end;


       {--------------------------------------------------------------}
       { Allocate Storage for a Variable }

       procedure Alloc;
       begin
          Next;
          if Token <> 'x' then Expected('Variable Name');
          CheckDup(Value);
          AddEntry(Value, 'v');
          Allocate(Value, '0');
          Next;
       end;
          
       {--------------------------------------------------------------}
       { Allocate Storage for a Variable }

       procedure AllocArray;
         var Name,Dim: string;
       begin
          Next;
          if Token <> 'x' then Expected('Variable Name');
          Name:=Value;
          CheckDup(Name);
          AddEntry(Name, 'v');
          Next;
          if Token<>'[' then Expected('Array Index Symbol [');
          Next;
          if Token<>'#' then Expected('Index Number');
          Dim:=Value;
          Next;
          if Token<>']' then Expected('Array Index Symbol ]');
          Allocate(Name, Dim + ' dup(0)');
          Next;
       end;

       {--------------------------------------------------------------}
       { Allocate Storage for a String }

       procedure AllocString;
        var Name,Stringa: string;
       begin
          if Token <> '$' then Expected('String ($)');
          Name:=Value;
          SkipWhite;
          if Look<>'=' then Expected('Symbol =');
          GetChar;
          SkipWhite;
          if Look<>'"' then Expected('Starter String Identifier (")');
          Stringa:='"';
          GetChar;
          while(Look<>'"') do begin
              Stringa:=Stringa + Look;
              GetChar;
          end;
          getchar;
          Stringa:=Stringa + '"';
          CheckDup(Value);
          AddEntry(Value, '$');
          AllocateString(Name, Stringa);
          Next;
       end;
          
       {--------------------------------------------------------------}
       { Parse and Translate Global Declarations }

       procedure TopDecls;
       begin
          Scan;
          while (Token = 'v') OR (Token = '$') OR (Token = 'A') do begin
             if (Token = 'v') then begin
                 Alloc;
                 while Token = ',' do
                    Alloc;
             end else if (Token = '$') then begin
                 AllocString;
                     end else if (Token = 'A') then begin
                                 AllocArray;
                                 while Token = ',' do
                                    AllocArray;
                             end;
             Scan;
          end;
       end;


       {--------------------------------------------------------------}
       { Initialize }

       procedure Init;
       var nomefile: string;
       begin
            write('Inserire il nome del file da compilare senza estensione (.pas): ');
            read(nomefile);
            assign(fread, basepath+nomefile+'.pas');
            reset(fread);
            assign(f, basepath+nomefile+'.asm');
            rewrite(f);
            nline:=0;
          GetChar;
          Next;
       end;


       {--------------------------------------------------------------}
       { Main Program }

       begin
          Init;
          MatchString('PROGRAM');
          Header;
          TopDecls;
          MatchString('BEGIN');
          Prolog;
          Block;
          MatchString('END');
          Epilog;
          Close(f);
          Writeln('File scritto con successo. (INVIO)');
          ReadLn;
       end.
       {--------------------------------------------------------------}