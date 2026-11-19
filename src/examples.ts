// The example programs in examples/, with a line about each.

const files = import.meta.glob('../examples/*.PAS', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;

export interface Example {
  name: string;
  title: string;
  info: string;
  source: string;
}

const ABOUT: [name: string, title: string, info: string][] = [
  ['SORT', 'Sort (2006)', 'One of the original 2006 test programs: reads six integers and sorts them. Uses an array, nested loops and LOOP.'],
  ['CALC', 'Calculator (2006)', 'From 2006: a running calculator. Type an operator (+ - * /), then a number and Enter. Esc quits.'],
  ['CAESAR', 'Caesar (2006)', 'From 2006: echoes what you type with every letter shifted by one. Esc quits.'],
  ['PRIMES', 'Primes', 'The sieve of Eratosthenes on a 500-word array.'],
  ['FIBO', 'Fibonacci', 'Fibonacci numbers up to the largest that fits in a signed 16-bit word.'],
  ['GUESS', 'Guess the number', 'A MASM ... ENDMASM block reads the BIOS clock (INT 1Ah) for a random number.'],
  ['ASCII', 'Key codes', 'Shows the ASCII code of each key you press. Esc quits.'],
];

const source = (name: string): string => {
  const entry = Object.entries(files).find(([path]) => path.toUpperCase().endsWith(`/${name}.PAS`));
  return (entry?.[1] ?? '').replace(/\r\n/g, '\n');
};

export const EXAMPLES: Example[] = ABOUT.map(([name, title, info]) => ({ name, title, info, source: source(name) }));
