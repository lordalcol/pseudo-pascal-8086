// The "How it works" page: code excerpts straight from the assembly
// sources, output from the real compiler port, and a stepper that runs the
// code an expression compiles to.
import '@fontsource-variable/inter';
import './style.css';
import './docs.css';
import { compile } from './compiler';
import { Machine } from './cpu';
import { highlightAsmLine, highlightSource } from './highlight';

const sources = import.meta.glob('../asm/INCLUDE/*.ASM', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;

const $ = <T extends HTMLElement>(id: string): T => document.getElementById(id) as T;
const esc = (s: string): string => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const asmHtml = (lines: string[]): string => lines.map((l) => highlightAsmLine(l)).join('\n');

/** A procedure from an .ASM file, with the comment lines just above it. */
function procedure(file: string, name: string): string[] {
  const entry = Object.entries(sources).find(([path]) => path.toUpperCase().endsWith('/' + file.toUpperCase()));
  if (!entry) return [`; ${file} not found`];
  const lines = entry[1].replace(/\r\n/g, '\n').split('\n');
  const start = lines.findIndex((l) => new RegExp(`^\\s*${name}\\s+proc\\b`, 'i').test(l));
  if (start < 0) return [`; ${name} not found in ${file}`];
  const end = lines.findIndex((l, i) => i > start && new RegExp(`^\\s*${name}\\s+endp\\b`, 'i').test(l));
  let top = start;
  while (top > 0 && /^\s*;/.test(lines[top - 1]!) && !/^;=+/.test(lines[top - 1]!)) top--;
  return lines.slice(top, end + 1);
}

/** The code between the prolog and the epilog of a compiled program. */
function body(asm: string): string[] {
  const lines = asm.replace(/\r\n$/, '').split('\r\n');
  const from = lines.findIndex((l) => l.trim() === 'mov     ds,ax') + 1;
  const to = lines.findIndex((l) => l.trim() === 'jmp dos');
  return lines.slice(from, to);
}

for (const pre of document.querySelectorAll<HTMLPreElement>('pre[data-proc]')) {
  const [file = '', name = ''] = (pre.dataset.proc ?? '').split(':');
  pre.innerHTML = asmHtml(procedure(file, name));
  const link = document.createElement('a');
  link.className = 'code-source';
  link.href = `https://github.com/lordalcol/pseudo-pascal-8086/blob/main/asm/INCLUDE/${file}`;
  link.textContent = `asm/INCLUDE/${file}`;
  pre.before(link);
}

for (const pre of document.querySelectorAll<HTMLPreElement>('pre[data-source]')) {
  pre.innerHTML = highlightSource(pre.textContent ?? '');
}

for (const pre of document.querySelectorAll<HTMLPreElement>('pre[data-compile]')) {
  const result = compile('program\n' + (pre.dataset.compile ?? '') + '\n');
  pre.innerHTML = result.asm ? asmHtml(body(result.asm)) : esc(result.error?.message ?? '');
}

// ------------------------------------------------------------------ tokens

const TOKENS: [string, string][] = [
  ['x', 'identifier'], ['#', 'integer or character literal'], ['$', 'string constant identifier'], ['v', 'VAR'], ['A', 'ARRAY'],
  ['i', 'IF'], ['l', 'ELSE'], ['w', 'WHILE'], ['L', 'LOOP'], ['e', 'END, ENDIF, ENDWHILE, ENDLOOP'], ['R', 'READ'],
  ['W', 'WRITE'], ['J', 'READINT'], ['I', 'WRITEINT'], ['S', 'WRITESTR'], ['N', 'NEWLINE'], ['m', 'MASM'],
  ['M', 'ENDMASM'], ['+ - * / ( ) ...', 'operators and punctuation: the character itself'],
];
$('tokens').innerHTML = TOKENS.map(([t, what]) => `<div><code>${esc(t)}</code><span>${esc(what)}</span></div>`).join('');

// ------------------------------------------------------------------ stepper

const ui = {
  expr: $<HTMLInputElement>('expr'),
  step: $<HTMLButtonElement>('expr-step'),
  reset: $<HTMLButtonElement>('expr-reset'),
  code: $<HTMLOListElement>('expr-code'),
  ax: $<HTMLElement>('expr-ax'),
  bx: $<HTMLElement>('expr-bx'),
  stack: $<HTMLDivElement>('expr-stack'),
  a: $<HTMLElement>('expr-a'),
  note: $<HTMLParagraphElement>('expr-note'),
};

let machine: Machine | null = null;
let first = 0;
let items: HTMLLIElement[] = [];

const signed = (v: number): number => (v << 16) >> 16;

function show(): void {
  const m = machine;
  if (!m) return;
  ui.ax.textContent = String(signed(m.regs[0]!));
  ui.bx.textContent = String(signed(m.regs[3]!));
  const stack = m.stack(8);
  ui.stack.innerHTML = stack.length ? stack.map((w) => `<b>${signed(w)}</b>`).join('') : '<i>empty</i>';
  ui.a.textContent = String(m.variables().find((v) => v.name === 'A')?.values[0] ?? 0);
  const current = m.line - first;
  items.forEach((li, i) => li.classList.toggle('on', i === current));
  items.forEach((li, i) => li.classList.toggle('done', i < current));
  const finished = m.status === 'done' || current >= items.length;
  ui.step.disabled = finished || m.status === 'error';
  if (m.error) ui.note.textContent = m.error;
  else if (finished) ui.note.textContent = `Done: a = ${ui.a.textContent}.`;
  else ui.note.textContent = current === 0 ? 'Press Step to run the first instruction.' : '';
}

function load(): void {
  machine = null;
  items = [];
  ui.code.textContent = '';
  const result = compile(`program\nvar a,b,c\nbegin\nb = 5\nc = 3\na = ${ui.expr.value}\nend.\n`);
  if (!result.asm) {
    ui.note.textContent = `The compiler says: ${result.error?.message ?? 'error'}`;
    ui.step.disabled = true;
    ui.ax.textContent = ui.bx.textContent = ui.a.textContent = '–';
    ui.stack.textContent = '';
    return;
  }
  const lines = result.asm.replace(/\r\n$/, '').split('\r\n');
  first = lines.findIndex((l) => l.startsWith('MOV C, AX')) + 1; // after c = 3
  const last = lines.findIndex((l) => l.trim() === 'jmp dos');
  for (const line of lines.slice(first, last)) {
    const li = document.createElement('li');
    li.innerHTML = highlightAsmLine(line);
    ui.code.append(li);
    items.push(li);
  }
  const m = Machine.load(result.asm);
  while (m.line !== first && m.status !== 'done' && m.status !== 'error') m.step();
  machine = m;
  show();
}

ui.step.addEventListener('click', () => {
  machine?.step();
  show();
  items.find((li) => li.classList.contains('on'))?.scrollIntoView({ block: 'nearest' });
});
ui.reset.addEventListener('click', load);
let timer = 0;
ui.expr.addEventListener('input', () => {
  clearTimeout(timer);
  timer = window.setTimeout(load, 250);
});
ui.expr.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    e.preventDefault();
    if (!ui.step.disabled) ui.step.click();
  }
});
load();

// ------------------------------------------------------------------ theme

type Theme = 'system' | 'light' | 'dark';
const themeBtn = $<HTMLButtonElement>('theme-btn');
const getTheme = (): Theme => {
  try { return (localStorage.getItem('pp86.theme') as Theme | null) ?? 'system'; } catch { return 'system'; }
};
function applyTheme(theme: Theme): void {
  if (theme === 'system') delete document.documentElement.dataset.theme;
  else document.documentElement.dataset.theme = theme;
  themeBtn.title = `Theme: ${theme} (click to change)`;
}
themeBtn.addEventListener('click', () => {
  const order: Theme[] = ['system', 'light', 'dark'];
  const next = order[(order.indexOf(getTheme()) + 1) % 3]!;
  try { localStorage.setItem('pp86.theme', next); } catch { /* private mode */ }
  applyTheme(next);
});
applyTheme(getTheme());
