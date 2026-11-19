// A line-by-line port of the 8086 assembly compiler in asm/ to TypeScript.
// Each method matches the procedure of the same name (pNext, pDoIf...), and
// the output is the same, byte for byte: the tests check it against what
// MAIN.EXE writes in DOSBox (tests/golden).

const CR = 13;
const LF = 10;
const TAB = 9;
const EOFCHR = 0x1a;
const CRLF = '\r\n';
const MAX_ENTRY = 100;
const MAX_NAME = 15;

const KW_LIST = ['IF', 'ELSE', 'ENDIF', 'WHILE', 'ENDWHILE', 'READ', 'WRITE', 'VAR', 'END', 'WRITEINT',
  'READINT', 'MASM', 'ENDMASM', 'NEWLINE', 'LOOP', 'ENDLOOP', 'WRITESTR', 'ARRAY'];
/** One-letter token per keyword; position 0 ('x') is a plain identifier. */
const KW_CODE = 'xileweRWveIJmMNLeSA';

export const INTRO = 'Pseudo-Pascal to 8086 assembly compiler - Lorenzo Dal Col, 2006';

const HEADER =
  '           INCLUDE RUNTIME.ASM' + CRLF +
  'PilaS      SEGMENT STACK' + CRLF +
  "           db      32 DUP('STACK   ')" + CRLF +
  'PilaS      ENDS' + CRLF +
  'DatiS      SEGMENT' + CRLF;
const PROLOG =
  'DatiS      ENDS' + CRLF +
  "MainS      SEGMENT PARA 'CODE'" + CRLF +
  '           ASSUME  CS:MainS, SS:PilaS, DS:DatiS' + CRLF +
  'PrgPrin    PROC    FAR' + CRLF +
  'lInizio    LABEL   NEAR' + CRLF +
  '     mov     ax,SEG DatiS        ; DS = data segment' + CRLF +
  '     mov     ds,ax' + CRLF;
const EPILOG =
  '        jmp dos' + CRLF +
  'PrgPrin    ENDP' + CRLF +
  'MainS      ENDS' + CRLF +
  'END     lInizio' + CRLF;
const ARRAY_INDEX = 'POP BX        ;array index' + CRLF + 'ADD BX,BX     ;words: index * 2' + CRLF;
const LOAD_ARRAY = 'MOV BX, AX    ;array index' + CRLF + 'ADD BX,BX     ;words: index * 2' + CRLF + 'MOV AX, ';

export interface CompileError {
  line: number;
  message: string;
}

export interface CompileResult {
  /** The generated assembly (CR LF line ends), or null if compiling failed. */
  asm: string | null;
  /** Everything the compiler printed on screen, as bytes in a string. */
  console: string;
  error: CompileError | null;
  /** For each line of `asm`, the source line being compiled when it was written (1-based). */
  sourceLines: number[];
}

class Stop extends Error {}

class Compiler {
  private readonly src: Uint8Array;
  private pos = 0;
  private look = 0;
  /** Token type: one letter, as in the assembly. */
  private token = '';
  /** Lexeme of the current token. */
  private value = '';
  private tmpValue = '';
  private label1 = '';
  private label2 = '';
  private lCount = 0;
  private nLine = 1;
  private nEntry = 0;
  private readonly symbols: string[] = new Array(MAX_ENTRY + 1).fill('');
  private readonly sType: string[] = new Array(MAX_ENTRY + 1).fill('');
  /** PushString / PopString: the strings the assembly keeps on the stack. */
  private readonly strings: string[] = [];
  private out = '';
  private readonly lines: number[] = [];
  private con = '';
  error: CompileError | null = null;

  constructor(source: string) {
    this.src = new Uint8Array(source.length);
    for (let i = 0; i < source.length; i++) {
      const c = source.charCodeAt(i);
      this.src[i] = c < 256 ? c : 63; // '?' for what a DOS file can't hold
    }
  }

  run(): CompileResult {
    try {
      this.pInit();
      this.pMatchString('PROGRAM');
      this.output(HEADER);
      this.pTopDecls();
      this.pMatchString('BEGIN');
      this.output(PROLOG);
      this.pBlock();
      this.pMatchString('END');
      this.output(EPILOG);
    } catch (e) {
      if (!(e instanceof Stop)) throw e;
    }
    return {
      asm: this.error ? null : this.out,
      console: this.con,
      error: this.error,
      sourceLines: this.error ? [] : this.lines,
    };
  }

  // Read through calls, so TypeScript doesn't narrow them across the calls
  // that change them.
  private tok(): string { return this.token; }
  private lookChar(): number { return this.look; }

  // ---------------------------------------------------------------- errors

  private fail(message: string): never {
    this.con += CRLF + `[LINE: ${this.nLine}] Error: ` + message;
    this.error = { line: this.nLine, message };
    throw new Stop();
  }
  private errExpected(what: string): never { return this.fail(what + ' Expected'); }
  private errDuplicate(name: string): never { return this.fail(name + ' Duplicated symbol declaration'); }
  private errUndefined(name: string): never { return this.fail(name + ' Undefined symbol'); }
  private errTableFull(name: string): never { return this.fail(name + ' Table of symbols is FULL'); }
  private errEOF(): never { return this.fail('Unexpected end of file'); }

  // ---------------------------------------------------------------- I/O

  private fGetC(): number {
    return this.pos < this.src.length ? this.src[this.pos++]! : EOFCHR;
  }

  /** Next source character into look, echoed on screen with line numbers. */
  private pGetChar(): number {
    let c: number;
    do c = this.fGetC(); while (c === CR);
    if (c === LF) {
      this.look = CR;
      this.con += CRLF + (this.nLine + 1) + ': ';
      this.nLine++;
      return CR;
    }
    this.look = c;
    if (c !== EOFCHR) this.con += c === TAB ? ' ' : String.fromCharCode(c);
    return c;
  }

  private output(text: string): void {
    for (let i = 0; i < text.length; i++) {
      if (text.charCodeAt(i) === LF) this.lines.push(this.nLine);
    }
    this.out += text;
  }

  private pushString(s: string): void { this.strings.push(s); }
  private popString(): string { return this.strings.pop() ?? ''; }

  // ---------------------------------------------------------------- characters

  private static isAlpha(c: number): boolean { return (((c | 0x20) - 97) & 0xff) <= 25; }
  private static isDigit(c: number): boolean { return c >= 48 && c <= 57; }
  private static isAlNum(c: number): boolean { return Compiler.isDigit(c) || Compiler.isAlpha(c); }
  private static isWhite(c: number): boolean { return c === 32 || c === TAB || c === CR || c === LF || c === 59; }
  private static toUpper(c: number): number { return c >= 97 && c <= 122 ? c & 0x5f : c; }
  private static isEndBlock(t: string): boolean { return t === 'e' || t === 'l'; }
  private static isOrOp(t: string): boolean { return t === '|' || t === '~'; }
  private static isAddop(t: string): boolean { return t === '+' || t === '-'; }
  private static isMulop(t: string): boolean { return t === '*' || t === '/'; }
  private static isRelop(t: string): boolean { return t === '=' || t === '<' || t === '>'; }

  // ---------------------------------------------------------------- scanner

  private pSkipComment(c: number): void {
    while (c !== CR && c !== EOFCHR) c = this.pGetChar();
    if (c === CR) this.pGetChar();
  }

  private pSkipWhite(): number {
    for (;;) {
      const c = this.look;
      if (!Compiler.isWhite(c)) return c;
      if (c === 59) this.pSkipComment(c);
      else this.pGetChar();
    }
  }

  private pGetName(): void {
    let c = this.pSkipWhite();
    if (!Compiler.isAlpha(c)) this.errExpected('Identifier');
    this.token = 'x';
    let v = '';
    do {
      c = Compiler.toUpper(c);
      if (v.length < MAX_NAME) v += String.fromCharCode(c);
      c = this.pGetChar();
    } while (Compiler.isAlNum(c));
    this.value = v;
  }

  private pGetNum(): void {
    let c = this.pSkipWhite();
    if (!Compiler.isDigit(c)) this.errExpected('Number');
    this.token = '#';
    let v = '';
    do {
      if (v.length < MAX_NAME) v += String.fromCharCode(c);
      c = this.pGetChar();
    } while (Compiler.isDigit(c));
    this.value = v;
  }

  private pGetIntChar(): void {
    let c = this.pSkipWhite();
    if (c !== 39) this.errExpected("Char Identifier (')");
    this.token = '#';
    let v = "'";
    c = this.pGetChar();
    v += String.fromCharCode(c);
    c = this.pGetChar();
    if (c !== 39) {
      this.value = v;
      this.errExpected("Final Char Identifier (')");
    }
    this.value = v + "'";
    this.pGetChar();
  }

  private pGetStringName(): void {
    let c = this.look;
    if (c !== 36) this.errExpected('String Identifier ($)');
    this.token = '$';
    let v = '';
    do {
      if (v.length < MAX_NAME) v += String.fromCharCode(c);
      c = this.pGetChar();
    } while (Compiler.isAlNum(c));
    this.value = v;
  }

  private pGetOp(): void {
    const c = this.pSkipWhite();
    this.token = String.fromCharCode(c);
    this.value = this.token;
    this.pGetChar();
  }

  private pNext(): void {
    this.pSkipWhite();
    const c = this.look;
    if (Compiler.isAlpha(c)) this.pGetName();
    else if (Compiler.isDigit(c)) this.pGetNum();
    else if (c === 39) this.pGetIntChar();
    else if (c === 36) this.pGetStringName();
    else if (c === EOFCHR) {
      this.token = String.fromCharCode(EOFCHR);
      this.value = '';
    } else this.pGetOp();
  }

  private pScan(): void {
    if (this.token === 'x') this.token = KW_CODE[KW_LIST.indexOf(this.value) + 1]!;
  }

  private pMatchString(s: string): void {
    if (this.value !== s) this.errExpected(s);
    this.pNext();
  }

  // ---------------------------------------------------------------- symbol table

  private pInTable(name: string): boolean {
    for (let i = 1; i <= MAX_ENTRY; i++) if (this.symbols[i] === name) return true;
    return false;
  }

  private pAddEntry(): void {
    if (this.pInTable(this.value)) this.errDuplicate(this.value);
    if (this.nEntry === MAX_ENTRY) this.errTableFull(this.value);
    this.nEntry++;
    this.sType[this.nEntry] = this.token;
    this.symbols[this.nEntry] = this.value;
  }

  // ---------------------------------------------------------------- declarations

  private pAlloc(): void {
    this.pNext();
    this.pScan();
    if (this.token !== 'x') this.errExpected('Variable Name');
    this.pAddEntry();
    this.output(this.value + '      dw      0        ' + CRLF);
    this.pNext();
  }

  private pAllocString(): void {
    if (this.token !== '$') this.errExpected('String ($)');
    this.pAddEntry();
    this.output(this.value + '      db       ');
    this.pSkipWhite();
    if (this.look !== 61) this.errExpected('=');
    this.pGetChar();
    this.pSkipWhite();
    if (this.lookChar() !== 34) this.errExpected('"');
    this.output('"');
    for (;;) {
      const c = this.pGetChar();
      if (c === CR || c === EOFCHR) this.errExpected('"');
      this.output(String.fromCharCode(c));
      if (c === 34) break;
    }
    this.output(',0' + CRLF);
    this.pGetChar();
    this.pNext();
  }

  private pAllocArray(): void {
    this.pNext();
    this.pScan();
    if (this.token !== 'x') this.errExpected('Variable Name');
    this.pAddEntry();
    this.output(this.value + '       dw      ');
    if (this.look !== 91) this.errExpected('[');
    this.pGetChar();
    this.pNext();
    if (this.tok() !== '#') this.errExpected('Number');
    this.output(this.value);
    this.pNext();
    if (this.tok() !== ']') this.errExpected(']');
    this.output(' dup(0)' + CRLF);
    this.pNext();
  }

  private pTopDecls(): void {
    for (;;) {
      this.pScan();
      const t = this.token;
      if (t === 'v') {
        this.pAlloc();
        while (this.token === ',') this.pAlloc();
      } else if (t === '$') {
        this.pAllocString();
      } else if (t === 'A') {
        this.pAllocArray();
        while (this.token === ',') this.pAllocArray();
      } else return;
    }
  }

  private pInit(): void {
    this.con += INTRO + CRLF + '1: ';
    this.pGetChar();
    this.pNext();
  }

  // ---------------------------------------------------------------- code generator

  private wNewLabel(): string {
    return 'L' + this.lCount++;
  }
  private wBranchFalse(label: string): void {
    this.output('TEST AX,1    ;set the flags from AX' + CRLF + 'JNE skip' + label + CRLF +
      'JMP ' + label + CRLF + 'skip' + label + ':' + CRLF);
  }
  private wBranch(label: string): void { this.output('JMP    ' + label + CRLF); }
  private wPostLabel(label: string): void { this.output(label + ':' + CRLF); }
  private wPush(): void { this.output('PUSH AX' + CRLF); }
  private wStore(name: string): void { this.output('MOV ' + name + ', AX           ;store' + CRLF); }
  private wStoreArray(name: string, valueInAX: boolean): void {
    this.output(ARRAY_INDEX + (valueInAX ? '' : 'POP AX' + CRLF) + 'MOV ' + name + '[BX], AX       ;store array' + CRLF);
  }
  private wLoadVar(name: string): void {
    if (!this.pInTable(name)) this.errUndefined(name);
    this.output('MOV AX, ' + name + CRLF);
  }
  private wLoadArray(name: string): void {
    if (!this.pInTable(name)) this.errUndefined(name);
    this.output(LOAD_ARRAY + name + '[BX]' + CRLF);
  }

  // ---------------------------------------------------------------- expressions

  private pCompareExpression(): void {
    this.pExpression();
    this.output('POP BX' + CRLF + 'CMP BX,AX' + CRLF);
  }
  private pNextExpression(): void {
    this.pNext();
    this.pCompareExpression();
  }

  private pRelation(): void {
    this.pExpression();
    const t = this.token;
    if (!Compiler.isRelop(t)) return;
    this.wPush();
    if (t === '=') {
      this.pNextExpression();
      this.output('CALL SETE        ;set if equal' + CRLF);
    } else if (t === '<') {
      this.pNext();
      if (this.token === '=') {
        this.pNextExpression();
        this.output('CALL SETLE       ;set if <=' + CRLF);
      } else if (this.token === '>') {
        this.pNextExpression();
        this.output('CALL SETNE       ;set if not equal' + CRLF);
      } else {
        this.pCompareExpression();
        this.output('CALL SETL        ;set if less' + CRLF);
      }
    } else {
      this.pNext();
      if (this.token === '=') {
        this.pNextExpression();
        this.output('CALL SETGE       ;set if >=' + CRLF);
      } else {
        this.pCompareExpression();
        this.output('CALL SETG        ;set if greater' + CRLF);
      }
    }
  }

  private pNotFactor(): void {
    if (this.token === '!') {
      this.pNext();
      this.pRelation();
      this.output('NOT AX' + CRLF);
    } else this.pRelation();
  }

  private pFactor(): void {
    if (this.token === '(') {
      this.pNext();
      this.pBoolExpression();
      this.pMatchString(')');
    } else if (this.token === 'x') {
      this.pushString(this.value);
      this.pNext();
      if (this.tok() !== '[') {
        this.tmpValue = this.popString();
        this.wLoadVar(this.tmpValue);
      } else {
        this.pNext();
        this.pBoolExpression();
        this.pMatchString(']');
        this.tmpValue = this.popString();
        this.wLoadArray(this.tmpValue);
      }
    } else if (this.token === '#') {
      this.output('MOV AX, ' + this.value + CRLF);
      this.pNext();
    } else this.errExpected('Math Factor');
  }

  private pTerm(): void {
    this.pFactor();
    while (Compiler.isMulop(this.token)) {
      this.wPush();
      if (this.token === '*') {
        this.pNext();
        this.pFactor();
        this.output('POP BX' + CRLF + 'IMUL BX       ;DX:AX = AX * BX, keep AX' + CRLF);
      } else {
        this.pNext();
        this.pFactor();
        this.output('POP BX        ;dividend' + CRLF + 'XCHG AX,BX    ;AX = dividend, BX = divisor' + CRLF +
          'CWD           ;sign-extend AX into DX' + CRLF + 'IDIV BX       ;AX = DX:AX / BX' + CRLF);
      }
    }
  }

  private pExpression(): void {
    if (Compiler.isAddop(this.token)) this.output('XOR AX,AX     ;AX = 0' + CRLF);
    else this.pTerm();
    while (Compiler.isAddop(this.token)) {
      this.wPush();
      const add = this.token === '+';
      this.pNext();
      this.pTerm();
      this.output(add ? 'POP BX' + CRLF + 'ADD AX,BX' + CRLF : 'POP BX' + CRLF + 'SUB AX,BX' + CRLF + 'NEG AX' + CRLF);
    }
  }

  private pBoolTerm(): void {
    this.pNotFactor();
    while (this.token === '&') {
      this.wPush();
      this.pNext();
      this.pNotFactor();
      this.output('POP BX' + CRLF + 'AND AX,BX' + CRLF);
    }
  }

  private pBoolExpression(): void {
    this.pBoolTerm();
    while (Compiler.isOrOp(this.token)) {
      this.wPush();
      const or = this.token === '|';
      this.pNext();
      this.pBoolTerm();
      this.output('POP BX' + CRLF + (or ? 'OR AX,BX' : 'XOR AX,BX') + CRLF);
    }
  }

  // ---------------------------------------------------------------- statements

  private pDoIf(): void {
    this.pNext();
    this.pBoolExpression();
    this.label1 = this.wNewLabel();
    this.pushString(this.label1);
    this.lCount--;
    this.label2 = this.wNewLabel();
    this.pushString(this.label2);
    this.wBranchFalse(this.label2);
    this.pBlock();
    if (this.token === 'l') {
      this.pNext();
      this.label2 = this.popString();
      this.label2 = this.wNewLabel();
      this.wBranch(this.label2);
      this.label1 = this.popString();
      this.pushString(this.label1);
      this.pushString(this.label2);
      this.wPostLabel(this.label1);
      this.pBlock();
    }
    this.label2 = this.popString();
    this.wPostLabel(this.label2);
    this.label1 = this.popString();
    this.pMatchString('ENDIF');
  }

  private pDoWhile(): void {
    this.pNext();
    this.label2 = this.wNewLabel();
    this.pushString(this.label2);
    this.label1 = this.wNewLabel();
    this.pushString(this.label1);
    this.wPostLabel(this.label1);
    this.pushString(this.label2);
    this.pBoolExpression();
    this.label2 = this.popString();
    this.wBranchFalse(this.label2);
    this.pBlock();
    this.pMatchString('ENDWHILE');
    this.label1 = this.popString();
    this.wBranch(this.label1);
    this.label2 = this.popString();
    this.wPostLabel(this.label2);
  }

  private pDoLoop(): void {
    this.pNext();
    this.pBoolExpression();
    this.wStore('CX');
    this.label1 = this.wNewLabel();
    this.pushString(this.label1);
    this.wPostLabel(this.label1);
    this.pBlock();
    this.pMatchString('ENDLOOP');
    this.label1 = this.popString();
    this.output('LOOP ' + this.label1 + CRLF);
  }

  /** READ / READINT of one variable or array element. */
  private pReadVar(call: string): void {
    this.pushString(this.value);
    if (this.token !== 'x') this.errExpected('Variable Name');
    if (!this.pInTable(this.value)) this.errUndefined(this.value);
    this.output(call);
    this.pNext();
    if (this.tok() === '[') {
      this.wPush();
      this.pNext();
      this.pBoolExpression();
      this.pMatchString(']');
      this.wPush();
      this.tmpValue = this.popString();
      this.wStoreArray(this.tmpValue, false);
    } else {
      this.tmpValue = this.popString();
      this.wStore(this.tmpValue);
    }
  }

  private pDoRead(call: string): void {
    this.pNext();
    this.pMatchString('(');
    for (;;) {
      this.pReadVar(call);
      if (this.token !== ',') break;
      this.pNext();
    }
    this.pMatchString(')');
  }

  private pDoWrite(call: string): void {
    this.pNext();
    this.pMatchString('(');
    for (;;) {
      this.pExpression();
      this.output(call);
      if (this.token !== ',') break;
      this.pNext();
    }
    this.pMatchString(')');
  }

  private pDoWriteString(): void {
    this.pNext();
    this.pMatchString('(');
    for (;;) {
      if (this.token !== '$') this.errExpected('String Identifier ($)');
      this.output('LEA SI, ' + this.value + CRLF + 'CALL DSP_STR' + CRLF);
      this.pNext();
      if (this.tok() !== ',') break;
      this.pNext();
    }
    this.pMatchString(')');
  }

  private pDoMasm(): void {
    this.output(';***** MASM' + CRLF);
    for (;;) {
      this.pNext();
      this.pScan();
      if (this.token === 'M') break;
      if (this.token === String.fromCharCode(EOFCHR)) this.errExpected('ENDMASM');
      this.output(this.value + ' ');
      while (this.look !== CR && this.look !== EOFCHR) {
        const c = this.pGetChar();
        if (c === CR || c === EOFCHR) break;
        if (c !== LF) this.output(String.fromCharCode(c));
      }
      this.output(CRLF);
    }
    this.output(';***** ENDMASM' + CRLF);
    this.pNext();
  }

  private pAssignment(): void {
    if (!this.pInTable(this.value)) this.errUndefined(this.value);
    this.pushString(this.value);
    this.pNext();
    let isArray = false;
    if (this.token === '[') {
      this.pNext();
      this.pBoolExpression();
      this.pMatchString(']');
      this.wPush();
      isArray = true;
    }
    this.pMatchString('=');
    this.pBoolExpression();
    this.tmpValue = this.popString();
    if (isArray) this.wStoreArray(this.tmpValue, true);
    else this.wStore(this.tmpValue);
  }

  private pBlock(): void {
    for (;;) {
      this.pScan();
      const t = this.token;
      if (Compiler.isEndBlock(t)) return;
      if (t === String.fromCharCode(EOFCHR)) this.errEOF();
      switch (t) {
        case 'i': this.pDoIf(); break;
        case 'w': this.pDoWhile(); break;
        case 'L': this.pDoLoop(); break;
        case 'R': this.pDoRead('CALL Char_In' + CRLF); break;
        case 'W': this.pDoWrite('CALL Char_Out' + CRLF); break;
        case 'I': this.pDoWrite('CALL Wor2Dec' + CRLF); break;
        case 'J': this.pDoRead('CALL DEC2BIN           ;read a decimal number into AX' + CRLF); break;
        case 'S': this.pDoWriteString(); break;
        case 'm': this.pDoMasm(); break;
        case 'N':
          this.output('CALL NEW_LINE' + CRLF);
          this.pNext();
          break;
        default: this.pAssignment();
      }
    }
  }
}

/** Compiles pseudo-Pascal source, like `MAIN NAME` on DOS. */
export function compile(source: string): CompileResult {
  return new Compiler(source).run();
}
