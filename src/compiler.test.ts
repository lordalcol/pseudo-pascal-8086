import { describe, expect, it } from 'vitest';
import { compile } from './compiler';
import { goldenCases } from './golden';
import { Screen } from './screen';

describe('compiler port matches MAIN.EXE in DOSBox', () => {
  for (const c of goldenCases()) {
    it(c.name, () => {
      const result = compile(c.source);
      expect(result.asm === null ? null : result.asm.replace(/\r\n/g, '\n')).toBe(c.asm);
      const screen = new Screen();
      screen.write(result.console);
      expect(screen.text()).toBe(c.log);
    });
  }
});

describe('compiler', () => {
  it('accepts LF and CR LF line ends alike', () => {
    const src = 'program\n var a\nbegin\n a = 1 ; one\n writeInt(a)\nend.\n';
    expect(compile(src.replace(/\n/g, '\r\n')).asm).toBe(compile(src).asm);
  });

  it('reports the line of an error', () => {
    const r = compile('program\r\nbegin\r\n  x = 1\r\nend.\r\n');
    expect(r.asm).toBeNull();
    expect(r.error).toEqual({ line: 3, message: 'X Undefined symbol' });
  });

  it('maps every output line to a source line', () => {
    const r = compile('program\nvar a\nbegin\na = 2\nwriteInt(a)\nend.\n');
    expect(r.sourceLines.length).toBe(r.asm!.split('\r\n').length - 1);
    const lines = r.asm!.split('\r\n');
    expect(r.sourceLines[lines.indexOf('CALL Wor2Dec')]).toBe(6);
  });

  it('numbers labels past 9', () => {
    const body = Array.from({ length: 12 }, () => 'while a < 1\na = 1\nendwhile').join('\n');
    const r = compile(`program\nvar a\nbegin\n${body}\nend.\n`);
    expect(r.asm).toContain('L23:');
  });
});
