// Test helpers: the programs and what the real compiler did with them in
// DOSBox (written by scripts/dos.mjs).
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const read = (path: string): string | null =>
  existsSync(path) ? readFileSync(path, 'latin1').replace(/\r\n/g, '\n') : null;

export interface GoldenCase {
  name: string;
  source: string;
  /** Assembly written by MAIN.EXE, null if it failed. */
  asm: string | null;
  /** The compiler's last screen. */
  log: string;
  /** Keys typed into the compiled program, null if it wasn't run. */
  keys: string | null;
  /** The compiled program's last screen. */
  out: string | null;
}

export function goldenCases(): GoldenCase[] {
  const cases: GoldenCase[] = [];
  for (const dir of ['examples', 'tests/programs']) {
    for (const file of readdirSync(join(root, dir)).filter((f) => /\.PAS$/i.test(f))) {
      const name = file.replace(/\.PAS$/i, '').toUpperCase();
      const g = (ext: string) => read(join(root, 'tests/golden', `${name}.${ext}`));
      const keys = read(join(root, 'tests/keys', `${name}.KEY`));
      cases.push({
        name,
        source: readFileSync(join(root, dir, file), 'latin1'),
        asm: g('ASM'),
        log: g('LOG') ?? '',
        keys: keys === null ? null : keys.replace(/\n$/, '').replace(/\\n/g, '\r').replace(/\\e/g, '\x1b').replace(/\\b/g, '\b'),
        out: g('OUT'),
      });
    }
  }
  return cases;
}
