// Syntax colouring for the pseudo-Pascal source and the generated assembly.
// Both return HTML with the text escaped.

const esc = (s: string): string => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const span = (cls: string, s: string): string => `<span class="${cls}">${esc(s)}</span>`;

const KEYWORDS = new Set(['PROGRAM', 'BEGIN', 'END', 'VAR', 'ARRAY', 'IF', 'ELSE', 'ENDIF', 'WHILE', 'ENDWHILE',
  'LOOP', 'ENDLOOP', 'MASM', 'ENDMASM']);
const BUILTINS = new Set(['READ', 'WRITE', 'READINT', 'WRITEINT', 'WRITESTR', 'NEWLINE']);

export function highlightSource(text: string): string {
  let out = '';
  let inMasm = false;
  for (const line of text.split('\n')) {
    const word = line.trim().split(/\s+/)[0]?.toUpperCase() ?? '';
    if (inMasm && word !== 'ENDMASM') {
      out += highlightAsmLine(line) + '\n';
      continue;
    }
    if (word === 'MASM') inMasm = true;
    if (word === 'ENDMASM') inMasm = false;
    const re = /(;.*$)|("[^"\n]*"?)|('.?'?)|(\$[A-Za-z0-9]*)|([A-Za-z][A-Za-z0-9]*)|(\d+)|([^\w\s;"'$]+)|(\s+)/gy;
    let m: RegExpExecArray | null;
    let pos = 0;
    while (pos < line.length && (re.lastIndex = pos, (m = re.exec(line)))) {
      const [all, comment, str, chr, strName, ident, num, op] = m;
      if (comment) out += span('t-comment', all);
      else if (str || chr) out += span('t-string', all);
      else if (strName) out += span('t-strname', all);
      else if (ident) {
        const u = ident.toUpperCase();
        out += KEYWORDS.has(u) ? span('t-keyword', all) : BUILTINS.has(u) ? span('t-builtin', all) : esc(all);
      } else if (num) out += span('t-number', all);
      else if (op) out += span('t-op', all);
      else out += esc(all);
      pos = re.lastIndex;
    }
    if (pos < line.length) out += esc(line.slice(pos));
    out += '\n';
  }
  return out.slice(0, -1);
}

const DIRECTIVES = /^(SEGMENT|ENDS|PROC|ENDP|ASSUME|INCLUDE|END|LABEL|DB|DW|DUP|STACK|PARA|FAR|NEAR|SEG|PTR|BYTE|WORD|OFFSET)$/i;
const REGISTERS = /^([ABCD][XLH]|SI|DI|BP|SP|[CDES]S)$/i;

export function highlightAsmLine(line: string): string {
  const re = /(;.*$)|("[^"]*"?|'[^']*'?)|([A-Za-z_$@?.][\w$@?.]*:)|([A-Za-z_$@?.][\w$@?.]*)|(\d[\dA-Fa-f]*[hHbB]?)|(\s+)|(.)/gy;
  let out = '';
  // "NAME dw 0", "NAME PROC FAR": the first word is a name, not an instruction
  const named = /^\s*[^\s;]+\s+(DB|DW|SEGMENT|ENDS|PROC|ENDP|LABEL|EQU)\b/i.test(line);
  let first = true;
  let m: RegExpExecArray | null;
  re.lastIndex = 0;
  while (re.lastIndex < line.length && (m = re.exec(line))) {
    const [all, comment, str, label, ident, num, space] = m;
    if (comment) out += span('t-comment', all);
    else if (str) out += span('t-string', all);
    else if (label) out += span('t-label', all);
    else if (ident) {
      if (DIRECTIVES.test(ident)) out += span('t-directive', all);
      else if (REGISTERS.test(ident)) out += span('t-register', all);
      else if (first) out += span(named ? 't-label' : 't-mnemonic', all);
      else out += esc(all);
      first = false;
    } else if (num) out += span('t-number', all);
    else if (space) out += all;
    else out += esc(all);
  }
  return out;
}
