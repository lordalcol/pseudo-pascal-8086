// An 80x25 text screen that behaves like the BIOS teletype output
// (INT 10h, AH=0Eh), which is what the compiler and the compiled programs
// write to on DOS.

export const COLS = 80;
export const ROWS = 25;

// Code page 437, the PC character set: what bytes 0-31 and 127-255 look like
// on screen.
const CP437_LOW = ' ☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼';
const CP437_HIGH =
  '⌂ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ';

export function cp437(byte: number): string {
  if (byte < 32) return CP437_LOW[byte] ?? ' ';
  if (byte >= 127) return CP437_HIGH[byte - 127] ?? ' ';
  return String.fromCharCode(byte);
}

export class Screen {
  /** Character codes, row by row. */
  readonly cells = new Uint8Array(COLS * ROWS);
  row = 0;
  col = 0;
  /** Bumped on every change, so a view can tell when to redraw. */
  version = 0;

  constructor() {
    this.clear();
  }

  clear(): void {
    this.cells.fill(32);
    this.row = 0;
    this.col = 0;
    this.version++;
  }

  private scroll(): void {
    this.cells.copyWithin(0, COLS);
    this.cells.fill(32, COLS * (ROWS - 1));
  }

  private lineFeed(): void {
    if (this.row === ROWS - 1) this.scroll();
    else this.row++;
  }

  /** BIOS teletype: CR, LF, backspace and bell act; everything else prints. */
  put(byte: number): void {
    byte &= 0xff;
    switch (byte) {
      case 13:
        this.col = 0;
        break;
      case 10:
        this.lineFeed();
        break;
      case 8:
        if (this.col > 0) this.col--;
        break;
      case 7:
        break;
      default:
        this.cells[this.row * COLS + this.col] = byte;
        if (++this.col === COLS) {
          this.col = 0;
          this.lineFeed();
        }
    }
    this.version++;
  }

  write(text: string): void {
    for (let i = 0; i < text.length; i++) this.put(text.charCodeAt(i));
  }

  /** Writes a character at the cursor without moving it (INT 10h, AH=09h/0Ah). */
  poke(byte: number, count = 1): void {
    let p = this.row * COLS + this.col;
    for (let i = 0; i < count && p < this.cells.length; i++) this.cells[p++] = byte & 0xff;
    this.version++;
  }

  moveTo(row: number, col: number): void {
    this.row = Math.max(0, Math.min(ROWS - 1, row));
    this.col = Math.max(0, Math.min(COLS - 1, col));
    this.version++;
  }

  /** The screen as plain text (bytes as Latin-1), lines trimmed, trailing blank lines dropped. */
  text(): string {
    const lines: string[] = [];
    for (let r = 0; r < ROWS; r++) {
      let line = '';
      for (let c = 0; c < COLS; c++) line += String.fromCharCode(this.cells[r * COLS + c] ?? 32);
      lines.push(line.trimEnd());
    }
    while (lines.length && lines[lines.length - 1] === '') lines.pop();
    return lines.join('\n') + '\n';
  }

  /** One row as it looks on a PC (code page 437). */
  rowText(r: number): string {
    let line = '';
    for (let c = 0; c < COLS; c++) line += cp437(this.cells[r * COLS + c] ?? 32);
    return line;
  }
}
