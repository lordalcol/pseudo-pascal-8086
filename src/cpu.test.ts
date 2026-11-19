import { describe, expect, it } from 'vitest';
import { compile } from './compiler';
import { AsmError, Machine } from './cpu';
import { goldenCases } from './golden';

function runWith(asm: string, keys: string, maxSteps = 5_000_000): Machine {
  const m = Machine.load(asm);
  for (const ch of keys) m.pushKey(ch.charCodeAt(0));
  m.run(maxSteps);
  return m;
}

describe('compiled programs behave as in DOSBox', () => {
  for (const c of goldenCases().filter((g) => g.out !== null)) {
    it(c.name, () => {
      const m = runWith(c.asm!, c.keys!);
      expect(m.error).toBeNull();
      expect(m.status).toBe('done');
      expect(m.screen.text()).toBe(c.out);
    });
  }
});

describe('simulator', () => {
  const program = (body: string, data = '') =>
    `PilaS SEGMENT STACK\r\n db 64 DUP(0)\r\nPilaS ENDS\r\nDatiS SEGMENT\r\n${data}\r\nDatiS ENDS\r\n` +
    `MainS SEGMENT\r\nstart:\r\n mov ax,SEG DatiS\r\n mov ds,ax\r\n${body}\r\n jmp dos\r\nMainS ENDS\r\nEND start\r\n`;

  it('waits for keys and resumes', () => {
    const m = Machine.load(compile('program\nvar k\nbegin\nread(k)\nwrite(k)\nend.\n').asm!);
    expect(m.run(1000)).toBe('waiting');
    m.pushKey(65);
    expect(m.run(1000)).toBe('done');
    expect(m.screen.text()).toBe('A\n');
  });

  it('reads numbers with sign and backspace like DEC2BIN', () => {
    const m = runWith(compile('program\nvar n\nbegin\nreadInt(n)\nnewline\nwriteInt(n*2)\nend.\n').asm!, '-12x3\b4\r');
    expect(m.screen.text()).toBe('-124\n-248\n');
  });

  it('sets flags like an 8086', () => {
    const m = runWith(program(' mov ax,7FFFh\r\n add ax,1\r\n pushf\r\n pop bx\r\n mov x,bx', 'x dw 0'), '');
    const flags = m.variables().find((v) => v.name === 'X')!.values[0]! & 0xffff;
    expect(flags & 0x800).toBe(0x800); // overflow
    expect(flags & 0x80).toBe(0x80); // sign
    expect(flags & 1).toBe(0); // no carry
  });

  it('runs inline assembly: loops, shifts, strings, INT 21h', () => {
    const m = runWith(
      program(
        ' mov cx,3\r\nagain:\r\n mov dl,\'*\'\r\n mov ah,2\r\n int 21h\r\n loop again\r\n' +
          ' mov ax,5\r\n shl ax,1\r\n shl ax,1\r\n mov x,ax\r\n lea dx,msg\r\n mov ah,9\r\n int 21h',
        'x dw 0\r\nmsg db " ok$"',
      ),
      '',
    );
    expect(m.screen.text()).toBe('*** ok\n');
    expect(m.variables().find((v) => v.name === 'X')!.values[0]).toBe(20);
  });

  it('writes to video memory at B800h', () => {
    const m = runWith(program(" mov ax,0B800h\r\n mov es,ax\r\n mov byte ptr es:[160],'Z'"), '');
    expect(m.screen.text()).toBe('\nZ\n');
  });

  it('stops on division by zero', () => {
    const m = runWith(compile('program\nvar a\nbegin\na = 5 / a\nend.\n').asm!, '');
    expect(m.status).toBe('error');
    expect(m.error).toMatch(/Divide overflow/);
  });

  it('reports what it cannot run', () => {
    expect(() => Machine.load(program(' in al,60h'))).toThrow(AsmError);
    try {
      Machine.load(program(' jmp nowhere'));
    } catch (e) {
      expect((e as AsmError).message).toBe('Unknown symbol NOWHERE');
      expect((e as AsmError).line).toBe(10);
    }
  });

  it('catches stack overflow', () => {
    const m = runWith(program('again:\r\n push ax\r\n jmp again'), '');
    expect(m.error).toBe('Stack overflow');
  });
});
