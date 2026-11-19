// An 8086 simulator that runs MASM source directly: it reads the assembly
// text the compiler writes (and the MASM ... ENDMASM blocks in it), and
// executes it instruction by instruction with real 8086 semantics: 16-bit
// registers, flags, segments, a stack, and a little of DOS and the BIOS.
// The routines of RUNTIME.ASM are built in and behave like the assembly ones.

import { Screen } from './screen';

// ------------------------------------------------------------------ types

type Reg16 = 'AX' | 'CX' | 'DX' | 'BX' | 'SP' | 'BP' | 'SI' | 'DI';
type Reg8 = 'AL' | 'CL' | 'DL' | 'BL' | 'AH' | 'CH' | 'DH' | 'BH';
type SegReg = 'ES' | 'CS' | 'SS' | 'DS';

const REG16: Reg16[] = ['AX', 'CX', 'DX', 'BX', 'SP', 'BP', 'SI', 'DI'];
const REG8: Reg8[] = ['AL', 'CL', 'DL', 'BL', 'AH', 'CH', 'DH', 'BH'];
const SEGREG: SegReg[] = ['ES', 'CS', 'SS', 'DS'];

type Operand =
  | { k: 'r16'; r: number }
  | { k: 'r8'; r: number }
  | { k: 'seg'; r: number }
  | { k: 'imm'; v: number }
  | { k: 'mem'; regs: number[]; disp: number; size: 0 | 1 | 2; seg: number | null }
  | { k: 'label'; name: string };

interface Instr {
  op: string;
  args: Operand[];
  rep: '' | 'REP' | 'REPE' | 'REPNE';
  /** Line in the assembly text (0-based). */
  line: number;
  /** For CALL/JMP to a procedure and RET inside one: whether it is FAR. */
  far: boolean;
}

interface DataSymbol {
  name: string;
  segment: string;
  offset: number;
  /** 1 = DB, 2 = DW */
  unit: 1 | 2;
  /** Number of units declared on the line. */
  count: number;
}

export class AsmError extends Error {
  readonly line: number;
  constructor(line: number, message: string) {
    super(message);
    this.line = line;
  }
}

export type Status = 'ready' | 'running' | 'waiting' | 'done' | 'error';

/** Segment values the simulator gives the program's segments. */
const SEG_BASE = 0x1000;
const VIDEO_SEG = 0xb800;

const BUILTINS = new Set(['CHAR_IN', 'CHAR_OUT', 'NEW_LINE', 'DSP_STR', 'WOR2DEC', 'DEC2BIN', 'DOS', 'DOS_ERR',
  'SETE', 'SETNE', 'SETG', 'SETL', 'SETGE', 'SETLE']);

const JCC: Record<string, string> = {
  JE: 'Z', JZ: 'Z', JNE: 'NZ', JNZ: 'NZ', JA: 'A', JNBE: 'A', JAE: 'NC', JNB: 'NC', JNC: 'NC',
  JB: 'C', JNAE: 'C', JC: 'C', JBE: 'NA', JNA: 'NA', JG: 'G', JNLE: 'G', JGE: 'GE', JNL: 'GE',
  JL: 'L', JNGE: 'L', JLE: 'LE', JNG: 'LE', JS: 'S', JNS: 'NS', JO: 'O', JNO: 'NO',
  JP: 'P', JPE: 'P', JNP: 'NP', JPO: 'NP',
};

const ZERO_OPERAND = new Set(['CWD', 'CBW', 'NOP', 'CLC', 'STC', 'CMC', 'CLD', 'STD', 'CLI', 'STI', 'HLT',
  'PUSHF', 'POPF', 'LAHF', 'SAHF', 'RETF', 'LODSB', 'LODSW', 'STOSB', 'STOSW', 'MOVSB', 'MOVSW',
  'SCASB', 'SCASW', 'CMPSB', 'CMPSW', 'XLAT', 'XLATB']);
const ONE_OPERAND = new Set(['PUSH', 'POP', 'INC', 'DEC', 'NEG', 'NOT', 'MUL', 'IMUL', 'DIV', 'IDIV',
  'JMP', 'CALL', 'INT', 'LOOP', 'LOOPE', 'LOOPZ', 'LOOPNE', 'LOOPNZ', 'JCXZ', ...Object.keys(JCC)]);
const SHIFTS = new Set(['SHL', 'SAL', 'SHR', 'SAR', 'ROL', 'ROR', 'RCL', 'RCR']);
const TWO_OPERAND = new Set(['MOV', 'ADD', 'ADC', 'SUB', 'SBB', 'CMP', 'AND', 'OR', 'XOR', 'TEST', 'XCHG',
  'LEA', ...SHIFTS]);

// ------------------------------------------------------------------ parsing

/** Splits a line at the first ';' that isn't inside quotes. */
function stripComment(line: string): string {
  let q = '';
  for (let i = 0; i < line.length; i++) {
    const c = line[i]!;
    if (q) {
      if (c === q) q = '';
    } else if (c === "'" || c === '"') q = c;
    else if (c === ';') return line.slice(0, i);
  }
  return line;
}

/** Splits at commas outside quotes, brackets and parentheses. */
function splitArgs(text: string): string[] {
  const out: string[] = [];
  let depth = 0;
  let q = '';
  let cur = '';
  for (const c of text) {
    if (q) {
      if (c === q) q = '';
    } else if (c === "'" || c === '"') q = c;
    else if (c === '[' || c === '(') depth++;
    else if (c === ']' || c === ')') depth--;
    else if (c === ',' && depth === 0) {
      out.push(cur.trim());
      cur = '';
      continue;
    }
    cur += c;
  }
  if (cur.trim() !== '' || out.length) out.push(cur.trim());
  return out;
}

function tokenize(text: string, line: number): string[] {
  const toks: string[] = [];
  const re = /\s*(?:('(?:[^']|'')*'|"(?:[^"]|"")*")|([A-Za-z_@$?.][\w@$?.]*)|(\d[\dA-Fa-f]*[HhBbDdOoQq]?)|([[\]()+\-*/:,]))/y;
  let i = 0;
  while (i < text.length) {
    if (/^\s*$/.test(text.slice(i))) break;
    re.lastIndex = i;
    const m = re.exec(text);
    if (!m) throw new AsmError(line, `Can't read "${text.slice(i).trim()}"`);
    toks.push(m[1] ?? m[2] ?? m[3] ?? m[4]!);
    i = re.lastIndex;
  }
  return toks;
}

function parseNumber(tok: string, line: number): number | null {
  if (!/^\d/.test(tok)) return null;
  const t = tok.toUpperCase();
  let v: number;
  if (/^[0-9A-F]+H$/.test(t)) v = parseInt(t.slice(0, -1), 16);
  else if (/^[01]+B$/.test(t)) v = parseInt(t.slice(0, -1), 2);
  else if (/^[0-7]+[OQ]$/.test(t)) v = parseInt(t.slice(0, -1), 8);
  else if (/^\d+D?$/.test(t)) v = parseInt(t, 10);
  else throw new AsmError(line, `Bad number ${tok}`);
  return v;
}

function quotedValue(tok: string): number[] | null {
  if (!/^['"]/.test(tok)) return null;
  const q = tok[0]!;
  const body = tok.slice(1, -1).split(q + q).join(q);
  return Array.from(body, (c) => c.charCodeAt(0) & 0xff);
}

interface Value {
  disp: number;
  regs: number[];
  mem: boolean;
  /** Size of the data symbol it names, if any. */
  size: 0 | 1 | 2;
  label: string | null;
  reg: Operand | null;
}

class OperandParser {
  private toks: string[] = [];
  private i = 0;
  private readonly asm: Assembly;
  private readonly line: number;
  constructor(asm: Assembly, line: number) {
    this.asm = asm;
    this.line = line;
  }

  parse(text: string): Operand {
    this.toks = tokenize(text, this.line);
    this.i = 0;
    let size: 0 | 1 | 2 = 0;
    let seg: number | null = null;
    if (this.peekUpper() === 'BYTE' || this.peekUpper() === 'WORD') {
      size = this.next().toUpperCase() === 'BYTE' ? 1 : 2;
      if (this.peekUpper() === 'PTR') this.next();
    }
    if (SEGREG.includes(this.peekUpper() as SegReg) && this.toks[this.i + 1] === ':') {
      seg = SEGREG.indexOf(this.next().toUpperCase() as SegReg);
      this.next();
    }
    const v = this.expr();
    if (this.i < this.toks.length) throw new AsmError(this.line, `Unexpected "${this.toks[this.i]}" in "${text}"`);
    if (v.reg && !v.mem) return v.reg;
    if (v.label && !v.mem) return { k: 'label', name: v.label };
    if (v.mem) return { k: 'mem', regs: v.regs, disp: v.disp & 0xffff, size: size || v.size, seg };
    if (v.regs.length) throw new AsmError(this.line, `"${text}": registers need [ ]`);
    return { k: 'imm', v: v.disp & 0xffff };
  }

  private peekUpper(): string { return (this.toks[this.i] ?? '').toUpperCase(); }
  private next(): string {
    const t = this.toks[this.i++];
    if (t === undefined) throw new AsmError(this.line, 'Operand ends too early');
    return t;
  }

  private expr(): Value {
    let v = this.term();
    while (this.toks[this.i] === '+' || this.toks[this.i] === '-') {
      const op = this.next();
      const w = this.term();
      if (op === '-' && (w.regs.length || w.reg)) throw new AsmError(this.line, "Can't subtract a register");
      v = this.combine(v, w, op === '+' ? 1 : -1);
    }
    return v;
  }

  private term(): Value {
    let v = this.factor();
    while (this.toks[this.i] === '*' || this.toks[this.i] === '/') {
      const op = this.next();
      const w = this.factor();
      if (v.regs.length || w.regs.length || v.reg || w.reg) throw new AsmError(this.line, "Can't multiply a register");
      v = { ...v, disp: op === '*' ? v.disp * w.disp : Math.trunc(v.disp / w.disp) };
    }
    return v;
  }

  private combine(a: Value, b: Value, sign: number): Value {
    const regs = [...a.regs, ...b.regs];
    for (const r of [a.reg, b.reg]) {
      if (r) {
        if (r.k !== 'r16' || ![3, 5, 6, 7].includes(r.r)) throw new AsmError(this.line, 'Only BX, BP, SI and DI can address memory');
        regs.push(r.r);
      }
    }
    return {
      disp: a.disp + sign * b.disp,
      regs,
      mem: a.mem || b.mem || regs.length > 0,
      size: a.size || b.size,
      label: a.label ?? b.label,
      reg: null,
    };
  }

  private factor(): Value {
    const t = this.next();
    const u = t.toUpperCase();
    const plain: Value = { disp: 0, regs: [], mem: false, size: 0, label: null, reg: null };
    if (t === '-') {
      const v = this.factor();
      return { ...v, disp: -v.disp };
    }
    if (t === '+') return this.factor();
    if (t === '(') {
      const v = this.expr();
      this.expect(')');
      return v;
    }
    if (t === '[') {
      const v = this.expr();
      this.expect(']');
      const inner = v.reg ? this.combine(plain, v, 1) : v;
      const out = { ...inner, mem: true };
      // name[...] continues: [BX][SI]
      if (this.toks[this.i] === '[') return this.combine(out, this.factor(), 1);
      return out;
    }
    const num = parseNumber(t, this.line);
    if (num !== null) return { ...plain, disp: num };
    const chars = quotedValue(t);
    if (chars) return { ...plain, disp: chars.reduce((acc, c) => (acc << 8) | c, 0) };
    if (u === 'OFFSET') {
      const v = this.factor();
      return { ...plain, disp: v.disp };
    }
    if (u === 'SEG') {
      const name = this.next().toUpperCase();
      const seg = this.asm.segmentValue(name, this.line);
      return { ...plain, disp: seg };
    }
    const r16 = REG16.indexOf(u as Reg16);
    if (r16 >= 0) return { ...plain, reg: { k: 'r16', r: r16 } };
    const r8 = REG8.indexOf(u as Reg8);
    if (r8 >= 0) return { ...plain, reg: { k: 'r8', r: r8 } };
    const sr = SEGREG.indexOf(u as SegReg);
    if (sr >= 0) return { ...plain, reg: { k: 'seg', r: sr } };
    const c = this.asm.constants.get(u);
    if (c !== undefined) return { ...plain, disp: c };
    const sym = this.asm.symbols.get(u);
    let v: Value;
    if (sym) v = { ...plain, disp: sym.offset, mem: true, size: sym.unit };
    else if (this.asm.isSegment(u)) v = { ...plain, disp: this.asm.segmentValue(u, this.line) };
    else v = { ...plain, label: u }; // a code label, checked after parsing
    if (this.toks[this.i] === '[') return this.combine(v, this.factor(), 1);
    return v;
  }

  private expect(t: string): void {
    if (this.next() !== t) throw new AsmError(this.line, `Expected ${t}`);
  }
}

/** The program: data, code and labels read from the assembly text. */
class Assembly {
  readonly symbols = new Map<string, DataSymbol>();
  readonly constants = new Map<string, number>();
  readonly labels = new Map<string, number>();
  readonly procs = new Map<string, boolean>(); // name -> FAR
  readonly code: Instr[] = [];
  readonly memory = new Map<number, Uint8Array>();
  private readonly segments = new Map<string, { value: number; size: number; stack: boolean }>();
  entry = 0;
  stackSegment: string | null = null;

  readonly text: string;
  constructor(text: string) {
    this.text = text;
  }

  isSegment(name: string): boolean { return this.segments.has(name); }

  segmentValue(name: string, line: number): number {
    const s = this.segments.get(name);
    if (!s) throw new AsmError(line, `Unknown segment ${name}`);
    return s.value;
  }

  mem(seg: number): Uint8Array {
    let m = this.memory.get(seg);
    if (!m) this.memory.set(seg, (m = new Uint8Array(0x10000)));
    return m;
  }

  load(): void {
    const lines = this.text.split(/\r?\n/);
    const pending: { line: number; op: string; rest: string; proc: string | null }[] = [];
    let seg: string | null = null;
    let proc: string | null = null;
    let entryLabel: string | null = null;

    lines.forEach((raw, line) => {
      const text = stripComment(raw).trim();
      if (!text) return;
      const m = /^([A-Za-z_@$?.][\w@$?.]*)(:?)\s*(.*)$/.exec(text);
      if (!m) throw new AsmError(line, `Can't read "${text}"`);
      let [, first = '', colon, rest = ''] = m;
      let FIRST = first.toUpperCase();
      // NAME: instruction
      if (colon) {
        this.defineLabel(FIRST, line, pending.length);
        if (!rest.trim()) return;
        const m2 = /^([A-Za-z_@$?.][\w@$?.]*)\s*(.*)$/.exec(rest.trim());
        if (!m2) throw new AsmError(line, `Can't read "${rest}"`);
        first = m2[1]!;
        rest = m2[2] ?? '';
        FIRST = first.toUpperCase();
      }
      const words = rest.trim().split(/\s+/);
      const SECOND = (words[0] ?? '').toUpperCase();
      const afterSecond = rest.trim().slice(words[0]?.length ?? 0).trim();

      if (FIRST === 'INCLUDE' || FIRST === 'ASSUME' || FIRST === 'TITLE' || FIRST === 'PAGE' || FIRST === '.8086' ||
        FIRST === '.MODEL' || FIRST === 'NAME' || FIRST === 'PUBLIC' || FIRST === 'EXTRN') return;
      if (FIRST === 'END') {
        if (rest.trim()) entryLabel = rest.trim().toUpperCase();
        return;
      }
      if (SECOND === 'SEGMENT') {
        if (!this.segments.has(FIRST)) {
          this.segments.set(FIRST, { value: SEG_BASE + this.segments.size * 0x1000, size: 0, stack: /\bSTACK\b/i.test(afterSecond) });
        }
        if (this.segments.get(FIRST)!.stack) this.stackSegment = FIRST;
        seg = FIRST;
        return;
      }
      if (SECOND === 'ENDS') {
        seg = null;
        return;
      }
      if (SECOND === 'PROC') {
        this.procs.set(FIRST, /\bFAR\b/i.test(afterSecond));
        this.defineLabel(FIRST, line, pending.length);
        proc = FIRST;
        return;
      }
      if (SECOND === 'ENDP') {
        proc = null;
        return;
      }
      if (SECOND === 'LABEL') {
        this.defineLabel(FIRST, line, pending.length);
        return;
      }
      if (SECOND === 'EQU' || words[0] === '=') {
        const v = new OperandParser(this, line).parse(afterSecond);
        if (v.k !== 'imm') throw new AsmError(line, `EQU needs a number`);
        this.constants.set(FIRST, v.v);
        return;
      }
      if (SECOND === 'DB' || SECOND === 'DW') {
        this.defineData(seg, FIRST, SECOND === 'DB' ? 1 : 2, afterSecond, line);
        return;
      }
      if (FIRST === 'DB' || FIRST === 'DW') {
        this.defineData(seg, null, FIRST === 'DB' ? 1 : 2, rest, line);
        return;
      }
      if (FIRST === 'ORG' || FIRST === 'EVEN' || FIRST === 'ALIGN') return;
      // an instruction
      if (seg === null) throw new AsmError(line, 'Instruction outside a segment');
      pending.push({ line, op: FIRST, rest, proc });
    });

    // Instructions are parsed once every data symbol and label is known.
    for (const p of pending) this.code.push(this.parseInstr(p.line, p.op, p.rest, p.proc));
    for (const ins of this.code) {
      for (const a of ins.args) {
        if (a.k === 'label' && !this.labels.has(a.name) && !BUILTINS.has(a.name)) {
          throw new AsmError(ins.line, `Unknown symbol ${a.name}`);
        }
      }
    }
    if (entryLabel !== null) {
      const e = this.labels.get(entryLabel);
      if (e === undefined) throw new AsmError(lines.length - 1, `Unknown entry point ${entryLabel}`);
      this.entry = e;
    }
  }

  /** Labels point at the next instruction: `index` is how many came before. */
  private defineLabel(name: string, line: number, index: number): void {
    if (this.labels.has(name) || this.symbols.has(name)) throw new AsmError(line, `Symbol already defined: ${name}`);
    this.labels.set(name, index);
  }

  private parseInstr(line: number, op: string, rest: string, proc: string | null): Instr {
    let rep: Instr['rep'] = '';
    if (op === 'REP' || op === 'REPE' || op === 'REPZ' || op === 'REPNE' || op === 'REPNZ') {
      rep = op === 'REP' ? 'REP' : op === 'REPE' || op === 'REPZ' ? 'REPE' : 'REPNE';
      const m = /^([A-Za-z]+)\s*(.*)$/.exec(rest.trim());
      if (!m) throw new AsmError(line, `${op} needs an instruction`);
      op = m[1]!.toUpperCase();
      rest = m[2] ?? '';
    }
    const texts = splitArgs(rest);
    let n = texts.length;
    if (op === 'RET' || op === 'RETF') {
      if (n > 1) throw new AsmError(line, `${op} takes at most one operand`);
    } else if (ZERO_OPERAND.has(op)) {
      if (n) throw new AsmError(line, `${op} takes no operands`);
    } else if (ONE_OPERAND.has(op)) {
      if (n !== 1) throw new AsmError(line, `${op} takes one operand`);
    } else if (TWO_OPERAND.has(op)) {
      if (SHIFTS.has(op) && n === 1) {
        texts.push('1');
        n = 2;
      }
      if (n !== 2) throw new AsmError(line, `${op} takes two operands`);
    } else {
      throw new AsmError(line, `The simulator doesn't support ${op}`);
    }
    const parser = new OperandParser(this, line);
    const args = texts.map((t) => parser.parse(t));
    let far = false;
    if (op === 'CALL' || op === 'JMP') {
      const a = args[0]!;
      if (a.k === 'label') far = this.procs.get(a.name) ?? false;
      else if (op === 'CALL') throw new AsmError(line, 'The simulator only calls labels');
      else throw new AsmError(line, 'The simulator only jumps to labels');
    } else if (op === 'RET') far = proc ? (this.procs.get(proc) ?? false) : false;
    else if (op === 'RETF') far = true;
    if ((JCC[op] || op.startsWith('LOOP') || op === 'JCXZ') && args[0]!.k !== 'label') {
      throw new AsmError(line, `${op} needs a label`);
    }
    return { op, args, rep, line, far };
  }

  private defineData(seg: string | null, name: string | null, unit: 1 | 2, text: string, line: number): void {
    if (seg === null) throw new AsmError(line, 'Data outside a segment');
    const s = this.segments.get(seg)!;
    const bytes: number[] = [];
    let count = 0;
    const parser = new OperandParser(this, line);
    const emit = (item: string): void => {
      const dup = /^(.+?)\s+DUP\s*\((.*)\)$/i.exec(item);
      if (dup) {
        const times = parser.parse(dup[1]!);
        if (times.k !== 'imm') throw new AsmError(line, 'DUP needs a count');
        for (let i = 0; i < times.v; i++) for (const sub of splitArgs(dup[2]!)) emit(sub);
        return;
      }
      if (item === '?') {
        for (let i = 0; i < unit; i++) bytes.push(0);
        count++;
        return;
      }
      const chars = quotedValue(item);
      if (chars && unit === 1 && /^(['"]).*\1$/.test(item)) {
        bytes.push(...chars);
        count += chars.length;
        return;
      }
      const v = parser.parse(item);
      if (v.k !== 'imm') throw new AsmError(line, `"${item}" is not a constant`);
      bytes.push(v.v & 0xff);
      if (unit === 2) bytes.push((v.v >> 8) & 0xff);
      count++;
    };
    for (const item of splitArgs(text)) emit(item);
    if (name) {
      if (this.symbols.has(name) || this.labels.has(name)) throw new AsmError(line, `Symbol already defined: ${name}`);
      this.symbols.set(name, { name, segment: seg, offset: s.size, unit, count });
    }
    this.mem(s.value).set(bytes, s.size);
    s.size += bytes.length;
    if (s.size > 0x10000) throw new AsmError(line, `Segment ${seg} is larger than 64 KB`);
  }

  stackSize(): number {
    return this.stackSegment ? this.segments.get(this.stackSegment)!.size : 0;
  }
  stackValue(): number {
    return this.stackSegment ? this.segments.get(this.stackSegment)!.value : 0xf000;
  }
  dataSegments(): string[] {
    return [...this.segments.entries()].filter(([, s]) => !s.stack).map(([n]) => n);
  }
}

// ------------------------------------------------------------------ machine

export interface Variable {
  name: string;
  /** Values as signed numbers (words) or bytes. */
  values: number[];
  unit: 1 | 2;
  text: string | null;
}

export class Machine {
  readonly screen: Screen;
  status: Status = 'ready';
  error: string | null = null;
  exitCode: number | null = null;
  steps = 0;
  /** Keys waiting to be read: ASCII code | scan code << 8. */
  readonly keys: number[] = [];

  readonly regs = new Uint16Array(8);
  readonly sregs = new Uint16Array(4);
  ip = 0;
  cf = false; zf = false; sf = false; of = false; pf = false; af = false; df = false; ifl = true;

  private dec2bin: { value: number; digits: number; neg: boolean } | null = null;
  private readonly asm: Assembly;

  private constructor(asm: Assembly, screen: Screen) {
    this.asm = asm;
    this.screen = screen;
    const data = asm.dataSegments()[0];
    const ds = data ? asm.segmentValue(data, 0) : SEG_BASE;
    this.sregs[3] = ds; // DS: the loader really sets it to the PSP; the program sets it anyway
    this.sregs[0] = ds;
    this.sregs[2] = asm.stackValue();
    this.sregs[1] = 0x7000;
    this.regs[4] = asm.stackSize() & 0xffff; // SP
    this.ip = asm.entry;
  }

  /** Reads assembly text. Throws AsmError for what it can't run. */
  static load(text: string, screen = new Screen()): Machine {
    const asm = new Assembly(text);
    asm.load();
    return new Machine(asm, screen);
  }

  get code(): readonly Instr[] { return this.asm.code; }

  /** The assembly line of the next instruction, or -1. */
  get line(): number {
    return this.asm.code[this.ip]?.line ?? -1;
  }

  pushKey(ascii: number, scan = 0): void {
    this.keys.push((ascii & 0xff) | ((scan & 0xff) << 8));
    if (this.status === 'waiting') this.status = 'running';
  }

  /** Runs up to `max` instructions; stops early when waiting, done or failed. */
  run(max: number): Status {
    if (this.status === 'done' || this.status === 'error') return this.status;
    this.status = 'running';
    for (let i = 0; i < max; i++) {
      this.step();
      if (this.status !== 'running') break;
    }
    return this.status;
  }

  step(): Status {
    if (this.status === 'done' || this.status === 'error') return this.status;
    const ins = this.asm.code[this.ip];
    if (!ins) return this.halt('The program ran past its last instruction');
    this.status = 'running';
    try {
      this.exec(ins);
    } catch (e) {
      if (e instanceof Wait) {
        this.status = 'waiting';
        return this.status;
      }
      if (e instanceof Fault) return this.halt(e.message);
      throw e;
    }
    if (this.status === 'running') this.steps++;
    return this.status;
  }

  private halt(message: string): Status {
    this.status = 'error';
    this.error = message;
    return this.status;
  }

  private exit(code: number): void {
    this.status = 'done';
    this.exitCode = code;
  }

  // -------------------------------------------------------------- state for the UI

  variables(): Variable[] {
    const out: Variable[] = [];
    for (const s of this.asm.symbols.values()) {
      const m = this.asm.mem(this.asm.segmentValue(s.segment, 0));
      const values: number[] = [];
      for (let i = 0; i < s.count; i++) {
        const o = s.offset + i * s.unit;
        values.push(s.unit === 2 ? ((m[o]! | (m[o + 1]! << 8)) << 16) >> 16 : m[o]!);
      }
      let text: string | null = null;
      if (s.unit === 1) {
        const end = values.indexOf(0);
        text = String.fromCharCode(...values.slice(0, end < 0 ? values.length : end));
      }
      out.push({ name: s.name, values, unit: s.unit, text });
    }
    return out;
  }

  /** The words on the stack, top first. */
  stack(max = 16): number[] {
    const m = this.asm.mem(this.sregs[2]!);
    const out: number[] = [];
    for (let sp = this.regs[4]!; sp < this.asm.stackSize() && out.length < max; sp += 2) {
      out.push(m[sp]! | (m[(sp + 1) & 0xffff]! << 8));
    }
    return out;
  }

  get flagsWord(): number {
    return (this.cf ? 1 : 0) | 2 | (this.pf ? 4 : 0) | (this.af ? 0x10 : 0) | (this.zf ? 0x40 : 0) |
      (this.sf ? 0x80 : 0) | (this.ifl ? 0x200 : 0) | (this.df ? 0x400 : 0) | (this.of ? 0x800 : 0) | 0xf000;
  }
  set flagsWord(v: number) {
    this.cf = !!(v & 1); this.pf = !!(v & 4); this.af = !!(v & 0x10); this.zf = !!(v & 0x40);
    this.sf = !!(v & 0x80); this.ifl = !!(v & 0x200); this.df = !!(v & 0x400); this.of = !!(v & 0x800);
  }

  // -------------------------------------------------------------- registers and memory

  private r8(i: number): number {
    const w = this.regs[i & 3]!;
    return i < 4 ? w & 0xff : w >> 8;
  }
  private setR8(i: number, v: number): void {
    const w = this.regs[i & 3]!;
    this.regs[i & 3] = i < 4 ? (w & 0xff00) | (v & 0xff) : (w & 0xff) | ((v & 0xff) << 8);
  }
  get ax(): number { return this.regs[0]!; }
  set ax(v: number) { this.regs[0] = v; }
  private get al(): number { return this.regs[0]! & 0xff; }
  private set al(v: number) { this.setR8(0, v); }
  private get ah(): number { return this.regs[0]! >> 8; }

  private ea(a: Extract<Operand, { k: 'mem' }>): { seg: number; off: number } {
    let off = a.disp;
    let bp = false;
    for (const r of a.regs) {
      off += this.regs[r]!;
      if (r === 5) bp = true;
    }
    const seg = a.seg !== null ? this.sregs[a.seg]! : bp ? this.sregs[2]! : this.sregs[3]!;
    return { seg, off: off & 0xffff };
  }

  private readByte(seg: number, off: number): number {
    if (seg === VIDEO_SEG) {
      return off & 1 ? 0x07 : (this.screen.cells[off >> 1] ?? 0);
    }
    return this.asm.mem(seg)[off & 0xffff]!;
  }
  private writeByte(seg: number, off: number, v: number): void {
    if (seg === VIDEO_SEG) {
      if (!(off & 1) && off >> 1 < this.screen.cells.length) {
        this.screen.cells[off >> 1] = v & 0xff;
        this.screen.version++;
      }
      return;
    }
    this.asm.mem(seg)[off & 0xffff] = v & 0xff;
  }
  private readWord(seg: number, off: number): number {
    return this.readByte(seg, off) | (this.readByte(seg, (off + 1) & 0xffff) << 8);
  }
  private writeWord(seg: number, off: number, v: number): void {
    this.writeByte(seg, off, v);
    this.writeByte(seg, (off + 1) & 0xffff, v >> 8);
  }

  private sizeOf(a: Operand, other?: Operand): 1 | 2 {
    if (a.k === 'r8') return 1;
    if (a.k === 'r16' || a.k === 'seg') return 2;
    if (a.k === 'mem' && a.size) return a.size;
    if (other) {
      if (other.k === 'r8') return 1;
      if (other.k === 'r16' || other.k === 'seg') return 2;
      if (other.k === 'mem' && other.size) return other.size;
    }
    if (a.k === 'imm' && other === undefined) return 2;
    throw new Fault('Operand size unknown: add BYTE PTR or WORD PTR');
  }

  private get(a: Operand, size: 1 | 2): number {
    switch (a.k) {
      case 'r16': return this.regs[a.r]!;
      case 'r8': return this.r8(a.r);
      case 'seg': return this.sregs[a.r]!;
      case 'imm': return size === 1 ? a.v & 0xff : a.v;
      case 'mem': {
        const { seg, off } = this.ea(a);
        return size === 1 ? this.readByte(seg, off) : this.readWord(seg, off);
      }
      case 'label': throw new Fault(`${a.name} is a label, not a value`);
    }
  }

  private set(a: Operand, size: 1 | 2, v: number): void {
    switch (a.k) {
      case 'r16': this.regs[a.r] = v; return;
      case 'r8': this.setR8(a.r, v); return;
      case 'seg': this.sregs[a.r] = v; return;
      case 'mem': {
        const { seg, off } = this.ea(a);
        if (size === 1) this.writeByte(seg, off, v);
        else this.writeWord(seg, off, v);
        return;
      }
      default: throw new Fault("Can't write to a constant");
    }
  }

  private push(v: number): void {
    const sp = this.regs[4]!;
    if (sp < 2) throw new Fault('Stack overflow');
    this.regs[4] = sp - 2;
    this.writeWord(this.sregs[2]!, sp - 2, v);
  }
  private pop(): number {
    const sp = this.regs[4]!;
    if (sp + 2 > this.asm.stackSize()) throw new Fault('Stack underflow: POP or RET with an empty stack');
    this.regs[4] = sp + 2;
    return this.readWord(this.sregs[2]!, sp);
  }

  // -------------------------------------------------------------- flags

  private szp(v: number, size: 1 | 2): void {
    const mask = size === 1 ? 0xff : 0xffff;
    v &= mask;
    this.zf = v === 0;
    this.sf = (v & (size === 1 ? 0x80 : 0x8000)) !== 0;
    let p = v & 0xff;
    p ^= p >> 4;
    p ^= p >> 2;
    p ^= p >> 1;
    this.pf = (p & 1) === 0;
  }

  private add(a: number, b: number, size: 1 | 2, carry = 0): number {
    const mask = size === 1 ? 0xff : 0xffff;
    const sign = size === 1 ? 0x80 : 0x8000;
    const r = a + b + carry;
    this.cf = r > mask;
    this.of = ((a ^ r) & (b ^ r) & sign) !== 0;
    this.af = ((a ^ b ^ r) & 0x10) !== 0;
    this.szp(r, size);
    return r & mask;
  }

  private sub(a: number, b: number, size: 1 | 2, borrow = 0): number {
    const mask = size === 1 ? 0xff : 0xffff;
    const sign = size === 1 ? 0x80 : 0x8000;
    const r = a - b - borrow;
    this.cf = r < 0;
    this.of = ((a ^ b) & (a ^ r) & sign) !== 0;
    this.af = ((a ^ b ^ r) & 0x10) !== 0;
    this.szp(r, size);
    return r & mask;
  }

  private logic(r: number, size: 1 | 2): number {
    this.cf = false;
    this.of = false;
    this.af = false;
    this.szp(r, size);
    return r & (size === 1 ? 0xff : 0xffff);
  }

  private cond(c: string): boolean {
    switch (c) {
      case 'Z': return this.zf;
      case 'NZ': return !this.zf;
      case 'A': return !this.cf && !this.zf;
      case 'NC': return !this.cf;
      case 'C': return this.cf;
      case 'NA': return this.cf || this.zf;
      case 'G': return !this.zf && this.sf === this.of;
      case 'GE': return this.sf === this.of;
      case 'L': return this.sf !== this.of;
      case 'LE': return this.zf || this.sf !== this.of;
      case 'S': return this.sf;
      case 'NS': return !this.sf;
      case 'O': return this.of;
      case 'NO': return !this.of;
      case 'P': return this.pf;
      case 'NP': return !this.pf;
    }
    return false;
  }

  // -------------------------------------------------------------- execution

  private jump(a: Operand): void {
    if (a.k !== 'label') throw new Fault('Jump target is not a label');
    const target = this.asm.labels.get(a.name);
    if (target === undefined) throw new Fault(`Unknown label ${a.name}`);
    this.ip = target;
  }

  private exec(ins: Instr): void {
    const [a, b] = ins.args;
    const next = this.ip + 1;
    const op = ins.op;

    const jcc = JCC[op];
    if (jcc) {
      if (this.cond(jcc)) this.jump(a!);
      else this.ip = next;
      return;
    }

    switch (op) {
      case 'MOV': {
        const s = this.sizeOf(a!, b);
        this.set(a!, s, this.get(b!, s));
        break;
      }
      case 'XCHG': {
        const s = this.sizeOf(a!, b);
        const t = this.get(a!, s);
        this.set(a!, s, this.get(b!, s));
        this.set(b!, s, t);
        break;
      }
      case 'LEA': {
        if (b!.k !== 'mem') throw new Fault('LEA needs a memory operand');
        this.set(a!, 2, this.ea(b!).off);
        break;
      }
      case 'ADD': case 'ADC': case 'SUB': case 'SBB': case 'CMP': {
        const s = this.sizeOf(a!, b);
        const x = this.get(a!, s);
        const y = this.get(b!, s);
        const c = (op === 'ADC' || op === 'SBB') && this.cf ? 1 : 0;
        const r = op === 'ADD' || op === 'ADC' ? this.add(x, y, s, c) : this.sub(x, y, s, c);
        if (op !== 'CMP') this.set(a!, s, r);
        break;
      }
      case 'AND': case 'OR': case 'XOR': case 'TEST': {
        const s = this.sizeOf(a!, b);
        const x = this.get(a!, s);
        const y = this.get(b!, s);
        const r = this.logic(op === 'OR' ? x | y : op === 'XOR' ? x ^ y : x & y, s);
        if (op !== 'TEST') this.set(a!, s, r);
        break;
      }
      case 'INC': case 'DEC': {
        const s = this.sizeOf(a!);
        const cf = this.cf;
        const r = op === 'INC' ? this.add(this.get(a!, s), 1, s) : this.sub(this.get(a!, s), 1, s);
        this.cf = cf;
        this.set(a!, s, r);
        break;
      }
      case 'NEG': {
        const s = this.sizeOf(a!);
        const v = this.get(a!, s);
        const r = this.sub(0, v, s);
        this.cf = v !== 0;
        this.set(a!, s, r);
        break;
      }
      case 'NOT': {
        const s = this.sizeOf(a!);
        this.set(a!, s, ~this.get(a!, s));
        break;
      }
      case 'MUL': case 'IMUL': {
        const s = this.sizeOf(a!);
        const signed = op === 'IMUL';
        const ext = (v: number, sz: 1 | 2) => (sz === 1 ? (v << 24) >> 24 : (v << 16) >> 16);
        if (s === 1) {
          const x = signed ? ext(this.al, 1) : this.al;
          const y = signed ? ext(this.get(a!, 1), 1) : this.get(a!, 1);
          const r = x * y;
          this.ax = r & 0xffff;
          this.cf = this.of = signed ? r !== ext(r & 0xff, 1) : (r & 0xff00) !== 0;
        } else {
          const x = signed ? ext(this.ax, 2) : this.ax;
          const y = signed ? ext(this.get(a!, 2), 2) : this.get(a!, 2);
          const r = x * y;
          this.ax = r & 0xffff;
          this.regs[2] = Math.floor(r / 0x10000) & 0xffff;
          this.cf = this.of = signed ? r !== ext(r & 0xffff, 2) : r > 0xffff;
        }
        this.szp(this.ax, 2);
        break;
      }
      case 'DIV': case 'IDIV': {
        const s = this.sizeOf(a!);
        const signed = op === 'IDIV';
        const divisorRaw = this.get(a!, s);
        const divisor = signed ? (s === 1 ? (divisorRaw << 24) >> 24 : (divisorRaw << 16) >> 16) : divisorRaw;
        if (divisor === 0) this.divideError();
        if (s === 1) {
          const dividend = signed ? (this.ax << 16) >> 16 : this.ax;
          const q = Math.trunc(dividend / divisor);
          const r = dividend - q * divisor;
          if (signed ? q < -128 || q > 127 : q > 0xff) this.divideError();
          this.ax = ((r & 0xff) << 8) | (q & 0xff);
        } else {
          const raw = this.regs[2]! * 0x10000 + this.ax;
          const dividend = signed && raw >= 0x80000000 ? raw - 0x100000000 : raw;
          const q = Math.trunc(dividend / divisor);
          const r = dividend - q * divisor;
          if (signed ? q < -32768 || q > 32767 : q > 0xffff) this.divideError();
          this.ax = q & 0xffff;
          this.regs[2] = r & 0xffff;
        }
        break;
      }
      case 'CWD':
        this.regs[2] = this.ax & 0x8000 ? 0xffff : 0;
        break;
      case 'CBW':
        this.ax = ((this.al << 24) >> 24) & 0xffff;
        break;
      case 'SHL': case 'SAL': case 'SHR': case 'SAR': case 'ROL': case 'ROR': case 'RCL': case 'RCR': {
        const s = this.sizeOf(a!);
        const mask = s === 1 ? 0xff : 0xffff;
        const msb = s === 1 ? 0x80 : 0x8000;
        const count = this.get(b!, 1) & 0x1f;
        let v = this.get(a!, s);
        if (count === 0) break;
        for (let i = 0; i < count; i++) {
          switch (op) {
            case 'SHL': case 'SAL':
              this.cf = (v & msb) !== 0;
              v = (v << 1) & mask;
              break;
            case 'SHR':
              this.cf = (v & 1) !== 0;
              v >>= 1;
              break;
            case 'SAR':
              this.cf = (v & 1) !== 0;
              v = (v >> 1) | (v & msb);
              break;
            case 'ROL':
              this.cf = (v & msb) !== 0;
              v = ((v << 1) | (this.cf ? 1 : 0)) & mask;
              break;
            case 'ROR':
              this.cf = (v & 1) !== 0;
              v = (v >> 1) | (this.cf ? msb : 0);
              break;
            case 'RCL': {
              const c = this.cf;
              this.cf = (v & msb) !== 0;
              v = ((v << 1) | (c ? 1 : 0)) & mask;
              break;
            }
            case 'RCR': {
              const c = this.cf;
              this.cf = (v & 1) !== 0;
              v = (v >> 1) | (c ? msb : 0);
              break;
            }
          }
        }
        if (op === 'SHL' || op === 'SAL' || op === 'SHR' || op === 'SAR') {
          this.szp(v, s);
          if (count === 1) this.of = op === 'SAR' ? false : op === 'SHR' ? (this.get(a!, s) & msb) !== 0 : ((v & msb) !== 0) !== this.cf;
        } else if (count === 1) {
          this.of = op === 'ROL' || op === 'RCL' ? ((v & msb) !== 0) !== this.cf : ((v ^ (v << 1)) & msb) !== 0;
        }
        this.set(a!, s, v);
        break;
      }
      case 'PUSH':
        this.push(this.get(a!, 2));
        break;
      case 'POP':
        this.set(a!, 2, this.pop());
        break;
      case 'PUSHF':
        this.push(this.flagsWord);
        break;
      case 'POPF':
        this.flagsWord = this.pop();
        break;
      case 'LAHF':
        this.setR8(4, this.flagsWord & 0xff);
        break;
      case 'SAHF':
        this.flagsWord = (this.flagsWord & 0xff00) | this.ah;
        break;
      case 'CLC': this.cf = false; break;
      case 'STC': this.cf = true; break;
      case 'CMC': this.cf = !this.cf; break;
      case 'CLD': this.df = false; break;
      case 'STD': this.df = true; break;
      case 'CLI': this.ifl = false; break;
      case 'STI': this.ifl = true; break;
      case 'NOP': break;
      case 'HLT':
        this.exit(0);
        return;
      case 'JMP': {
        const name = a!.k === 'label' ? a!.name : '';
        if (BUILTINS.has(name) && !this.asm.labels.has(name)) {
          this.builtin(name);
          if (this.status === 'running') this.ip = this.pop(); // a JMP to a routine returns to the caller's caller
          return;
        }
        this.jump(a!);
        return;
      }
      case 'CALL': {
        const name = a!.k === 'label' ? a!.name : '';
        if (BUILTINS.has(name) && !this.asm.labels.has(name)) {
          this.builtin(name);
          if (this.status === 'running') this.ip = next;
          return;
        }
        if (ins.far) this.push(0x3000);
        this.push(next);
        this.jump(a!);
        return;
      }
      case 'RET': case 'RETF': {
        const n = a ? this.get(a, 2) : 0;
        this.ip = this.pop();
        if (ins.far) this.pop();
        this.regs[4] = (this.regs[4]! + n) & 0xffff;
        return;
      }
      case 'LOOP': case 'LOOPE': case 'LOOPZ': case 'LOOPNE': case 'LOOPNZ': {
        const cx = (this.regs[1]! - 1) & 0xffff;
        this.regs[1] = cx;
        const go = cx !== 0 && (op === 'LOOP' || ((op === 'LOOPE' || op === 'LOOPZ') ? this.zf : !this.zf));
        if (go) this.jump(a!);
        else this.ip = next;
        return;
      }
      case 'JCXZ':
        if (this.regs[1] === 0) this.jump(a!);
        else this.ip = next;
        return;
      case 'INT':
        this.interrupt(this.get(a!, 1));
        if (this.status === 'running') this.ip = next;
        return;
      case 'XLAT': case 'XLATB':
        this.al = this.readByte(this.sregs[3]!, (this.regs[3]! + this.al) & 0xffff);
        break;
      default:
        if (/^(LODS|STOS|MOVS|SCAS|CMPS)[BW]$/.test(op)) {
          this.stringOp(op, ins.rep);
          break;
        }
        throw new Fault(`The simulator doesn't support ${op}`);
    }
    this.ip = next;
  }

  private stringOp(op: string, rep: Instr['rep']): void {
    const s: 1 | 2 = op.endsWith('W') ? 2 : 1;
    const step = (this.df ? -1 : 1) * s;
    const once = (): void => {
      const si = this.regs[6]!;
      const di = this.regs[7]!;
      const ds = this.sregs[3]!;
      const es = this.sregs[0]!;
      const rd = (seg: number, off: number) => (s === 1 ? this.readByte(seg, off) : this.readWord(seg, off));
      const wr = (seg: number, off: number, v: number) => (s === 1 ? this.writeByte(seg, off, v) : this.writeWord(seg, off, v));
      const acc = s === 1 ? this.al : this.ax;
      switch (op.slice(0, 4)) {
        case 'LODS':
          if (s === 1) this.al = rd(ds, si);
          else this.ax = rd(ds, si);
          this.regs[6] = si + step;
          break;
        case 'STOS':
          wr(es, di, acc);
          this.regs[7] = di + step;
          break;
        case 'MOVS':
          wr(es, di, rd(ds, si));
          this.regs[6] = si + step;
          this.regs[7] = di + step;
          break;
        case 'SCAS':
          this.sub(acc, rd(es, di), s);
          this.regs[7] = di + step;
          break;
        case 'CMPS':
          this.sub(rd(ds, si), rd(es, di), s);
          this.regs[6] = si + step;
          this.regs[7] = di + step;
          break;
      }
    };
    if (!rep) {
      once();
      return;
    }
    const compares = op.startsWith('SCAS') || op.startsWith('CMPS');
    while (this.regs[1] !== 0) {
      once();
      this.regs[1] = this.regs[1]! - 1;
      if (compares && rep === 'REPE' && !this.zf) break;
      if (compares && rep === 'REPNE' && this.zf) break;
    }
  }

  private divideError(): never {
    this.screen.write('\r\nDivide overflow\r\n');
    throw new Fault('Divide overflow: division by zero, or the result does not fit');
  }

  // -------------------------------------------------------------- keyboard

  private takeKey(): number {
    const k = this.keys.shift();
    if (k === undefined) throw new Wait();
    return k;
  }

  // -------------------------------------------------------------- RUNTIME.ASM

  private builtin(name: string): void {
    switch (name) {
      case 'CHAR_IN':
        this.ax = this.takeKey() & 0xff;
        return;
      case 'CHAR_OUT':
        this.screen.put(this.al);
        return;
      case 'NEW_LINE':
        this.screen.write('\r\n');
        return;
      case 'DSP_STR': {
        const ds = this.sregs[3]!;
        for (let si = this.regs[6]!, n = 0; n < 0x10000; si = (si + 1) & 0xffff, n++) {
          const c = this.readByte(ds, si);
          if (c === 0) break;
          this.screen.put(c);
        }
        return;
      }
      case 'WOR2DEC': {
        const v = (this.ax << 16) >> 16;
        this.screen.write(v < 0 ? '-' + String(v === -32768 ? 32768 : -v) : String(v));
        return;
      }
      case 'DEC2BIN':
        this.readNumber();
        return;
      case 'DOS':
        this.exit(0);
        return;
      case 'DOS_ERR':
        this.exit(1);
        return;
      default: {
        // SETcc after CMP BX,AX
        const c = { SETE: 'Z', SETNE: 'NZ', SETG: 'G', SETL: 'L', SETGE: 'GE', SETLE: 'LE' }[name];
        if (c) {
          this.ax = this.cond(c) ? 1 : 0;
          return;
        }
        throw new Fault(`Unknown routine ${name}`);
      }
    }
  }

  /** DEC2BIN: reads a signed number with echo, as RUNTIME.ASM does. */
  private readNumber(): void {
    const st = (this.dec2bin ??= { value: 0, digits: 0, neg: false });
    for (;;) {
      const key = this.takeKey() & 0xff; // throws Wait, keeping st for later
      if (key === 13) {
        this.ax = st.neg ? -st.value & 0xffff : st.value;
        this.dec2bin = null;
        return;
      }
      if (key === 8) {
        if (st.digits > 0) {
          st.value = Math.floor(st.value / 10);
          st.digits--;
        } else if (st.neg) st.neg = false;
        else continue;
        this.screen.write('\b \b');
      } else if (key === 45) {
        if (st.digits === 0 && !st.neg) {
          st.neg = true;
          this.screen.put(45);
        }
      } else if (key >= 48 && key <= 57 && st.digits < 5) {
        this.screen.put(key);
        st.value = (st.value * 10 + (key - 48)) & 0xffff;
        st.digits++;
      }
    }
  }

  // -------------------------------------------------------------- DOS and BIOS

  private interrupt(n: number): void {
    const ah = this.ah;
    if (n === 0x21) {
      switch (ah) {
        case 0x01: {
          const k = this.takeKey() & 0xff;
          this.screen.put(k);
          this.al = k;
          return;
        }
        case 0x02:
          this.dosOut(this.r8(2));
          return;
        case 0x06:
          if (this.r8(2) === 0xff) {
            const k = this.keys.shift();
            this.zf = k === undefined;
            this.al = k === undefined ? 0 : k & 0xff;
          } else this.dosOut(this.r8(2));
          return;
        case 0x07: case 0x08:
          this.al = this.takeKey() & 0xff;
          return;
        case 0x09: {
          const ds = this.sregs[3]!;
          for (let dx = this.regs[2]!, n2 = 0; n2 < 0x10000; dx = (dx + 1) & 0xffff, n2++) {
            const c = this.readByte(ds, dx);
            if (c === 36) break;
            this.dosOut(c);
          }
          return;
        }
        case 0x2a: {
          const d = new Date();
          this.regs[1] = d.getFullYear();
          this.regs[2] = ((d.getMonth() + 1) << 8) | d.getDate();
          this.al = d.getDay();
          return;
        }
        case 0x2c: {
          const d = new Date();
          this.regs[1] = (d.getHours() << 8) | d.getMinutes();
          this.regs[2] = (d.getSeconds() << 8) | Math.floor(d.getMilliseconds() / 10);
          return;
        }
        case 0x30:
          this.ax = 0x0005;
          return;
        case 0x4c:
          this.exit(this.al);
          return;
      }
      throw new Fault(`INT 21h function ${hex(ah, 2)}h isn't supported by the simulator`);
    }
    if (n === 0x10) {
      switch (ah) {
        case 0x00:
          this.screen.clear();
          return;
        case 0x02:
          this.screen.moveTo(this.r8(6), this.r8(2));
          return;
        case 0x03:
          this.regs[2] = (this.screen.row << 8) | this.screen.col;
          this.regs[1] = 0x0607;
          return;
        case 0x06: case 0x07:
          if (this.al === 0) {
            const saved = [this.screen.row, this.screen.col] as const;
            this.screen.clear();
            this.screen.moveTo(saved[0], saved[1]);
          } else throw new Fault('INT 10h scrolling isn\'t supported by the simulator');
          return;
        case 0x09: case 0x0a:
          this.screen.poke(this.al, this.regs[1]!);
          return;
        case 0x0e:
          this.screen.put(this.al);
          return;
        case 0x0f:
          this.ax = (80 << 8) | 3;
          this.setR8(7, 0);
          return;
      }
      throw new Fault(`INT 10h function ${hex(ah, 2)}h isn't supported by the simulator`);
    }
    if (n === 0x16) {
      if (ah === 0x00 || ah === 0x10) {
        this.ax = this.takeKey();
        return;
      }
      if (ah === 0x01 || ah === 0x11) {
        const k = this.keys[0];
        this.zf = k === undefined;
        if (k !== undefined) this.ax = k;
        return;
      }
      throw new Fault(`INT 16h function ${hex(ah, 2)}h isn't supported by the simulator`);
    }
    if (n === 0x1a && ah === 0x00) {
      const now = new Date();
      const midnight = new Date(now);
      midnight.setHours(0, 0, 0, 0);
      const ticks = Math.floor(((now.getTime() - midnight.getTime()) / 1000) * 18.2065);
      this.regs[1] = ticks >>> 16;
      this.regs[2] = ticks & 0xffff;
      this.al = 0;
      return;
    }
    if (n === 0x20) {
      this.exit(0);
      return;
    }
    throw new Fault(`INT ${hex(n, 2)}h isn't supported by the simulator`);
  }

  /** DOS console output: like the BIOS, but TAB moves to the next multiple of 8. */
  private dosOut(c: number): void {
    if (c === 9) {
      do this.screen.put(32);
      while (this.screen.col % 8 !== 0);
    } else this.screen.put(c);
  }
}

class Wait extends Error {}
class Fault extends Error {}

export function hex(v: number, digits = 4): string {
  return v.toString(16).toUpperCase().padStart(digits, '0');
}

export const REGISTER_NAMES = REG16;
export const SEGMENT_NAMES = SEGREG;
