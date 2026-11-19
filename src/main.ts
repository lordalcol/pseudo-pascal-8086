import '@fontsource-variable/inter';
import './style.css';
import { compile, type CompileResult } from './compiler';
import { AsmError, hex, Machine, REGISTER_NAMES } from './cpu';
import { EXAMPLES } from './examples';
import { highlightAsmLine, highlightSource } from './highlight';
import { ROWS, Screen } from './screen';

const $ = <T extends HTMLElement>(id: string): T => {
  const el = document.getElementById(id);
  if (!el) throw new Error(`#${id} missing`);
  return el as T;
};

const ui = {
  examples: $<HTMLSelectElement>('examples'),
  exampleInfo: $<HTMLParagraphElement>('example-info'),
  run: $<HTMLButtonElement>('run-btn'),
  runLabel: $<HTMLSpanElement>('run-label'),
  pause: $<HTMLButtonElement>('pause-btn'),
  step: $<HTMLButtonElement>('step-btn'),
  stop: $<HTMLButtonElement>('stop-btn'),
  speed: $<HTMLSelectElement>('speed'),
  status: $<HTMLSpanElement>('status'),
  source: $<HTMLTextAreaElement>('source'),
  highlight: $<HTMLPreElement>('highlight'),
  gutter: $<HTMLDivElement>('src-gutter'),
  cursorPos: $<HTMLSpanElement>('cursor-pos'),
  compileError: $<HTMLParagraphElement>('compile-error'),
  tabAsm: $<HTMLButtonElement>('tab-asm'),
  tabLog: $<HTMLButtonElement>('tab-log'),
  asmView: $<HTMLDivElement>('asm-view'),
  logView: $<HTMLDivElement>('log-view'),
  asmSize: $<HTMLSpanElement>('asm-size'),
  download: $<HTMLButtonElement>('download-btn'),
  screen: $<HTMLDivElement>('screen'),
  screenHint: $<HTMLSpanElement>('screen-hint'),
  keyInput: $<HTMLInputElement>('key-input'),
  steps: $<HTMLSpanElement>('steps'),
  runError: $<HTMLParagraphElement>('run-error'),
  regs: $<HTMLDivElement>('regs'),
  flags: $<HTMLDivElement>('flags'),
  vars: $<HTMLDivElement>('vars'),
  stack: $<HTMLDivElement>('stack'),
  share: $<HTMLButtonElement>('share-btn'),
  theme: $<HTMLButtonElement>('theme-btn'),
  langBtn: $<HTMLButtonElement>('lang-btn'),
  langDialog: $<HTMLDialogElement>('lang-dialog'),
  langClose: $<HTMLButtonElement>('lang-close'),
};

const store = {
  get(key: string): string | null {
    try { return localStorage.getItem(`pp86.${key}`); } catch { return null; }
  },
  set(key: string, value: string): void {
    try { localStorage.setItem(`pp86.${key}`, value); } catch { /* private mode */ }
  },
};

// ------------------------------------------------------------------ state

type RunState = 'idle' | 'running' | 'paused' | 'waiting' | 'done' | 'error';

let result: CompileResult = compile('');
let programName = 'PROGRAM';
let machine: Machine | null = null;
let runState: RunState = 'idle';
let screen = new Screen();
let frame = 0;
let lastTime = 0;
let budget = 0;
let lastDebug = 0;
let prevRegs: number[] = [];
let asmLines: HTMLDivElement[] = [];
let markedAsm = -1;

// ------------------------------------------------------------------ editor

const LINE_HEIGHT = 21; // matches .editor-layer line-height (14px * 1.5)

function renderSource(): void {
  const text = ui.source.value;
  ui.highlight.innerHTML = highlightSource(text) + '\n';
  const lines = text.split('\n').length;
  let g = '';
  for (let i = 1; i <= lines; i++) g += `<span data-line="${i}">${i}</span>`;
  ui.gutter.innerHTML = g;
  markSourceLine();
  syncScroll();
}

const band = document.createElement('div');
band.hidden = true;
ui.highlight.before(band);

function syncScroll(): void {
  placeBand();
  ui.highlight.scrollTop = ui.source.scrollTop;
  ui.highlight.scrollLeft = ui.source.scrollLeft;
  ui.gutter.scrollTop = ui.source.scrollTop;
}

/** Highlights the source line of the running instruction, or the error line. */
function markSourceLine(): void {
  let line = 0;
  let cls = '';
  if (result.error) {
    line = result.error.line;
    cls = 'error';
  } else if (machine && runState !== 'idle') {
    const asmLine = machine.line;
    if (asmLine >= 0) line = result.sourceLines[asmLine] ?? 0;
  }
  for (const el of ui.gutter.querySelectorAll('.on, .error')) el.classList.remove('on', 'error');
  if (line) ui.gutter.querySelector(`[data-line="${line}"]`)?.classList.add(cls || 'on');
  band.hidden = !line;
  band.className = `line-band ${cls || 'on'}`;
  band.dataset.line = String(line);
  placeBand();
}

function placeBand(): void {
  const line = Number(band.dataset.line || 0);
  band.style.top = `${12 + (line - 1) * LINE_HEIGHT - ui.source.scrollTop}px`;
}

function updateCursorPos(): void {
  const before = ui.source.value.slice(0, ui.source.selectionStart);
  const line = before.split('\n').length;
  const col = before.length - before.lastIndexOf('\n');
  ui.cursorPos.textContent = `${line}:${col}`;
}

// ------------------------------------------------------------------ compiling

let compileTimer = 0;

function recompile(): void {
  result = compile(ui.source.value);
  const err = result.error;
  ui.compileError.hidden = !err;
  if (err) ui.compileError.textContent = `Line ${err.line}: ${err.message}`;
  renderAsm();
  renderLog();
  renderSource();
  updateButtons();
}

function renderAsm(): void {
  ui.asmView.textContent = '';
  asmLines = [];
  markedAsm = -1;
  if (!result.asm) {
    ui.asmView.innerHTML = `<p class="empty">No assembly: the compiler stopped at an error. The <b>Compiler screen</b> tab shows what it printed.</p>`;
    ui.asmSize.textContent = '';
    return;
  }
  const lines = result.asm.replace(/\r\n$/, '').split('\r\n');
  const frag = document.createDocumentFragment();
  lines.forEach((line, i) => {
    const div = document.createElement('div');
    div.className = 'ln';
    div.innerHTML = `<span class="no">${i + 1}</span><span class="code">${highlightAsmLine(line) || ' '}</span>`;
    frag.append(div);
    asmLines.push(div);
  });
  ui.asmView.append(frag);
  ui.asmSize.textContent = `${lines.length} lines`;
}

function renderLog(): void {
  const s = new Screen();
  s.write(result.console);
  ui.logView.innerHTML = screenHtml(s, false);
}

function markAsmLine(scroll: boolean): void {
  const line = machine && runState !== 'idle' ? machine.line : -1;
  if (line === markedAsm) return;
  asmLines[markedAsm]?.classList.remove('on');
  markedAsm = line;
  const el = asmLines[line];
  if (!el) return;
  el.classList.add('on');
  if (scroll) {
    const view = ui.asmView;
    const top = el.offsetTop - view.offsetTop;
    if (top < view.scrollTop + 20 || top > view.scrollTop + view.clientHeight - 40) {
      view.scrollTop = top - view.clientHeight / 2;
    }
  }
}

// ------------------------------------------------------------------ DOS screen

const escHtml = (s: string): string => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function screenHtml(s: Screen, cursor: boolean): string {
  let html = '';
  for (let r = 0; r < ROWS; r++) {
    const text = s.rowText(r);
    if (cursor && r === s.row) {
      html += `<div>${escHtml(text.slice(0, s.col))}<span class="cursor">${escHtml(text[s.col] ?? ' ')}</span>${escHtml(text.slice(s.col + 1))}</div>`;
    } else html += `<div>${escHtml(text)}</div>`;
  }
  return html;
}

let shownVersion = -1;
let shownCursor = false;

function renderScreen(force = false): void {
  const cursor = runState === 'running' || runState === 'waiting' || runState === 'paused';
  if (!force && screen.version === shownVersion && cursor === shownCursor) return;
  shownVersion = screen.version;
  shownCursor = cursor;
  ui.screen.innerHTML = screenHtml(screen, cursor);
}

// ------------------------------------------------------------------ debugger view

function renderDebug(): void {
  const m = machine;
  ui.runError.hidden = !(m && m.error);
  if (m?.error) ui.runError.textContent = m.error;
  if (!m) {
    ui.regs.innerHTML = '';
    ui.flags.innerHTML = '';
    ui.vars.innerHTML = '<p class="empty">Run or step the program to see its variables.</p>';
    ui.stack.innerHTML = '';
    ui.steps.textContent = '';
    return;
  }
  ui.steps.textContent = `${m.steps.toLocaleString('en')} instructions`;

  const order = [0, 3, 1, 2, 6, 7, 5, 4]; // AX BX CX DX SI DI BP SP
  const values = order.map((i) => m.regs[i]!);
  ui.regs.innerHTML = order
    .map((i, k) => {
      const v = values[k]!;
      const changed = prevRegs.length && prevRegs[k] !== v;
      return `<div class="reg${changed ? ' changed' : ''}"><span class="name">${REGISTER_NAMES[i]}</span><span class="hex">${hex(v)}</span><span class="dec">${(v << 16) >> 16}</span></div>`;
    })
    .join('');
  prevRegs = values;

  const flags: [string, boolean, string][] = [
    ['O', m.of, 'Overflow'], ['D', m.df, 'Direction'], ['I', m.ifl, 'Interrupts'], ['S', m.sf, 'Sign'],
    ['Z', m.zf, 'Zero'], ['A', m.af, 'Auxiliary carry'], ['P', m.pf, 'Parity'], ['C', m.cf, 'Carry'],
  ];
  ui.flags.innerHTML = flags
    .map(([f, on, title]) => `<span class="flag${on ? ' on' : ''}" title="${title} flag: ${on ? 1 : 0}">${f}</span>`)
    .join('');

  const vars = m.variables();
  ui.vars.innerHTML = vars.length
    ? vars
        .map((v) => {
          let value: string;
          if (v.text !== null && v.name.startsWith('$')) value = `<span class="str">"${escHtml(v.text)}"</span>`;
          else if (v.values.length === 1) value = String(v.values[0]);
          else {
            const shown = v.values.slice(0, 24).join(' ');
            value = `<span class="arr">[${shown}${v.values.length > 24 ? ' …' : ''}]</span>`;
          }
          return `<div class="var"><span class="name">${escHtml(v.name)}</span><span class="val">${value}</span></div>`;
        })
        .join('')
    : '<p class="empty">No variables.</p>';

  const stack = m.stack(10);
  ui.stack.innerHTML = stack.length
    ? stack.map((w, i) => `<div class="word"><span class="off">SP+${i * 2}</span><span class="hex">${hex(w)}</span><span class="dec">${(w << 16) >> 16}</span></div>`).join('')
    : '<p class="empty">Empty</p>';
}

// ------------------------------------------------------------------ running

const STATUS: Record<RunState, string> = {
  idle: 'Ready',
  running: 'Running',
  paused: 'Paused',
  waiting: 'Waiting for a key',
  done: 'Finished',
  error: 'Stopped',
};

function setState(s: RunState): void {
  runState = s;
  ui.status.dataset.state = s === 'idle' ? 'idle' : s === 'waiting' ? 'input' : s === 'done' ? 'halted' : s;
  ui.status.textContent = s === 'done' && machine?.exitCode ? `Finished (exit code ${machine.exitCode})` : STATUS[s];
  ui.screenHint.textContent = s === 'waiting' ? 'The program is waiting: type on the screen' : 'Click the screen and type';
  ui.screen.classList.toggle('waiting', s === 'waiting');
  updateButtons();
}

function updateButtons(): void {
  const live = runState === 'running' || runState === 'waiting';
  const canRun = !!result.asm;
  ui.run.disabled = live || !canRun;
  ui.runLabel.textContent = runState === 'paused' ? 'Continue' : 'Run';
  ui.pause.disabled = !live;
  ui.step.disabled = runState === 'running' || (!canRun && !machine);
  ui.stop.disabled = runState === 'idle' || runState === 'done' || runState === 'error';
  ui.download.disabled = !result.asm;
}

/** Loads the current assembly into a fresh machine. */
function load(): boolean {
  if (!result.asm) return false;
  screen = new Screen();
  try {
    machine = Machine.load(result.asm, screen);
  } catch (e) {
    machine = null;
    const msg = e instanceof AsmError ? `Assembly line ${e.line + 1}: ${e.message}` : String(e);
    ui.runError.hidden = false;
    ui.runError.textContent = msg;
    setState('error');
    return false;
  }
  prevRegs = [];
  ui.runError.hidden = true;
  return true;
}

const speed = (): number => Number(ui.speed.value);

function start(): void {
  if (runState === 'paused' && machine) {
    resume();
    return;
  }
  stopLoop();
  if (!load()) return;
  renderScreen(true);
  resume();
}

function resume(): void {
  setState('running');
  ui.screen.focus({ preventScroll: true });
  lastTime = performance.now();
  budget = 0;
  frame = requestAnimationFrame(tick);
}

function tick(now: number): void {
  const m = machine;
  if (!m) return;
  const sp = speed();
  let n: number;
  if (sp === Infinity) n = 2_000_000;
  else {
    budget = Math.min(budget + ((now - lastTime) / 1000) * sp, sp + 1);
    n = Math.floor(budget);
    budget -= n;
  }
  lastTime = now;
  const t0 = performance.now();
  // At full speed, run in slices of about 12 ms so the page stays responsive.
  let status = m.status;
  if (n > 0) {
    if (sp === Infinity) {
      do status = m.run(20_000);
      while (status === 'running' && performance.now() - t0 < 12);
    } else status = m.run(n);
  }
  afterRun(status, sp !== Infinity || now - lastDebug > 100);
  if (status === 'running' || status === 'ready') frame = requestAnimationFrame(tick);
  else if (status === 'waiting') frame = 0;
}

function afterRun(status: string, full: boolean): void {
  if (status === 'waiting') setState('waiting');
  else if (status === 'done') setState('done');
  else if (status === 'error') setState('error');
  renderScreen();
  if (full || runState !== 'running') {
    lastDebug = performance.now();
    renderDebug();
    markAsmLine(speed() <= 1000 || runState !== 'running');
    markSourceLine();
  }
}

function stopLoop(): void {
  if (frame) cancelAnimationFrame(frame);
  frame = 0;
}

function pause(): void {
  stopLoop();
  setState('paused');
  renderScreen(true);
  renderDebug();
  markAsmLine(true);
  markSourceLine();
}

function step(): void {
  if (!machine || runState === 'idle' || runState === 'done' || runState === 'error') {
    stopLoop();
    if (!load()) return;
    setState('paused');
    renderScreen(true);
    renderDebug();
    markAsmLine(true);
    markSourceLine();
    return;
  }
  stopLoop();
  const status = machine.step();
  if (status === 'waiting') setState('waiting');
  else if (status === 'done') setState('done');
  else if (status === 'error') setState('error');
  else setState('paused');
  renderScreen(true);
  renderDebug();
  markAsmLine(true);
  markSourceLine();
}

function stop(): void {
  stopLoop();
  setState('idle');
  renderScreen(true);
  renderDebug();
  markAsmLine(false);
  markSourceLine();
}

function sendKey(ascii: number, scan = 0): void {
  const m = machine;
  if (!m || runState === 'idle' || runState === 'done' || runState === 'error') return;
  m.pushKey(ascii, scan);
  if (runState === 'waiting') resume();
}

// ------------------------------------------------------------------ events

const SCAN: Record<string, [number, number]> = {
  Enter: [13, 0x1c], Backspace: [8, 0x0e], Escape: [27, 0x01], Tab: [9, 0x0f],
  ArrowUp: [0, 0x48], ArrowDown: [0, 0x50], ArrowLeft: [0, 0x4b], ArrowRight: [0, 0x4d],
  Home: [0, 0x47], End: [0, 0x4f], Delete: [0, 0x53],
};

ui.screen.addEventListener('keydown', (e) => {
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  const special = SCAN[e.key];
  if (special) sendKey(special[0], special[1]);
  else if (e.key.length === 1 && e.key.charCodeAt(0) < 256) sendKey(e.key.charCodeAt(0));
  else return;
  e.preventDefault();
});

ui.keyInput.addEventListener('input', () => {
  for (const ch of ui.keyInput.value) if (ch.charCodeAt(0) < 256) sendKey(ch.charCodeAt(0));
  ui.keyInput.value = '';
});
ui.keyInput.addEventListener('keydown', (e) => {
  const special = SCAN[e.key];
  if (special && (e.key !== 'Backspace' || ui.keyInput.value === '')) {
    sendKey(special[0], special[1]);
    e.preventDefault();
  }
});
for (const b of document.querySelectorAll<HTMLButtonElement>('[data-key]')) {
  b.addEventListener('click', () => {
    const k = Number(b.dataset.key);
    sendKey(k, k === 13 ? 0x1c : k === 8 ? 0x0e : 1);
  });
}

ui.run.addEventListener('click', start);
ui.pause.addEventListener('click', pause);
ui.step.addEventListener('click', step);
ui.stop.addEventListener('click', stop);
ui.speed.addEventListener('change', () => {
  store.set('speed', ui.speed.value);
  budget = 0;
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
    e.preventDefault();
    if (!ui.run.disabled) start();
  } else if (e.key === 'F10') {
    e.preventDefault();
    if (!ui.step.disabled) step();
  } else if (e.key === 'F8') {
    e.preventDefault();
    if (!ui.pause.disabled) pause();
  } else if (e.key === 'F5' && e.shiftKey) {
    e.preventDefault();
    if (!ui.stop.disabled) stop();
  }
});

ui.source.addEventListener('input', () => {
  if (runState !== 'idle') stop();
  machine = null;
  renderDebug();
  renderSource();
  store.set('source', ui.source.value);
  clearTimeout(compileTimer);
  compileTimer = window.setTimeout(recompile, 200);
  if (ui.examples.value !== '') {
    const ex = EXAMPLES.find((x) => x.name === ui.examples.value);
    if (ex && ex.source !== ui.source.value) {
      ui.examples.value = '';
      ui.exampleInfo.textContent = '';
      programName = 'PROGRAM';
    }
  }
});
ui.source.addEventListener('scroll', syncScroll);
ui.source.addEventListener('keydown', (e) => {
  if (e.key === 'Tab' && !e.shiftKey && !e.ctrlKey) {
    e.preventDefault();
    document.execCommand('insertText', false, '    ');
  }
});
for (const ev of ['keyup', 'click', 'select'] as const) ui.source.addEventListener(ev, updateCursorPos);

function selectTab(log: boolean): void {
  ui.tabAsm.setAttribute('aria-selected', String(!log));
  ui.tabLog.setAttribute('aria-selected', String(log));
  ui.asmView.hidden = log;
  ui.logView.hidden = !log;
}
ui.tabAsm.addEventListener('click', () => selectTab(false));
ui.tabLog.addEventListener('click', () => selectTab(true));

ui.download.addEventListener('click', () => {
  if (!result.asm) return;
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([result.asm], { type: 'text/plain' }));
  a.download = `${programName}.ASM`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
});

function loadSource(text: string, name: string): void {
  if (runState !== 'idle') stop();
  machine = null;
  programName = name;
  ui.source.value = text;
  ui.source.scrollTop = 0;
  recompile();
  screen = new Screen();
  renderScreen(true);
  renderDebug();
}

for (const ex of EXAMPLES) ui.examples.add(new Option(ex.title, ex.name));
ui.examples.add(new Option('Your program', ''));
ui.examples.addEventListener('change', () => {
  const ex = EXAMPLES.find((x) => x.name === ui.examples.value);
  ui.exampleInfo.textContent = ex?.info ?? '';
  if (ex) {
    loadSource(ex.source, ex.name);
    store.set('source', ex.source);
    history.replaceState(null, '', location.pathname + location.search);
  }
});

// Share links carry the program in the URL hash.
const toBase64Url = (s: string): string =>
  btoa(String.fromCharCode(...new TextEncoder().encode(s))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const fromBase64Url = (s: string): string =>
  new TextDecoder().decode(Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0)));

ui.share.addEventListener('click', async () => {
  const url = `${location.origin}${location.pathname}#src=${toBase64Url(ui.source.value)}`;
  history.replaceState(null, '', url);
  try {
    await navigator.clipboard.writeText(url);
    toast('Link copied');
  } catch {
    toast('Link is in the address bar');
  }
});

function toast(text: string): void {
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = text;
  document.body.append(el);
  setTimeout(() => el.remove(), 1800);
}

type Theme = 'system' | 'light' | 'dark';
function applyTheme(theme: Theme): void {
  if (theme === 'system') delete document.documentElement.dataset.theme;
  else document.documentElement.dataset.theme = theme;
  ui.theme.title = `Theme: ${theme} (click to change)`;
  ui.theme.setAttribute('aria-label', ui.theme.title);
}
ui.theme.addEventListener('click', () => {
  const order: Theme[] = ['system', 'light', 'dark'];
  const current = (store.get('theme') as Theme | null) ?? 'system';
  const next = order[(order.indexOf(current) + 1) % order.length]!;
  store.set('theme', next);
  applyTheme(next);
});

ui.langBtn.addEventListener('click', () => ui.langDialog.showModal());
ui.langClose.addEventListener('click', () => ui.langDialog.close());
ui.langDialog.addEventListener('click', (e) => {
  if (e.target === ui.langDialog) ui.langDialog.close();
});

// ------------------------------------------------------------------ start-up

applyTheme((store.get('theme') as Theme | null) ?? 'system');
const savedSpeed = store.get('speed');
if (savedSpeed && [...ui.speed.options].some((o) => o.value === savedSpeed)) ui.speed.value = savedSpeed;

// #src=... is a shared program; #example=PRIMES opens an example; &run starts it.
const params = new URLSearchParams(location.hash.slice(1));
const hash = params.get('src');
const linked = EXAMPLES.find((x) => x.name === (params.get('example') ?? '').toUpperCase());
let initial: { text: string; name: string } | null = linked ? { text: linked.source, name: linked.name } : null;
if (hash && !linked) {
  try {
    initial = { text: fromBase64Url(hash), name: 'PROGRAM' };
  } catch { /* bad link */ }
}
const saved = store.get('source');
if (!initial && saved) initial = { text: saved, name: 'PROGRAM' };
const first = EXAMPLES[0]!;
const match = EXAMPLES.find((x) => x.source === (initial?.text ?? first.source));
ui.examples.value = match ? match.name : initial ? '' : first.name;
ui.exampleInfo.textContent = match?.info ?? (initial ? '' : first.info);
loadSource(initial?.text ?? first.source, match?.name ?? (initial ? 'PROGRAM' : first.name));
setState('idle');
updateCursorPos();
if (params.has('run') && result.asm) start();
