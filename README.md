# Pseudo-Pascal to ASM compiler, written in ASM

A compiler for a small Pascal-like language, written in 8086 assembly in 2006. It reads a `.PAS` file and writes MASM assembly for DOS: the output assembles with MASM or [JWasm](https://github.com/Baron-von-Riedesel/JWasm) and runs as a DOS `.EXE`.

In 2026 I restored it. It builds and runs in DOSBox again after ten bug fixes, and a JavaScript port runs it in the browser.

**[Try it in the browser](https://lorenzodalcol.com/personal-projects/compiler/)**: write a program, see the assembly the compiler writes, and run it on a simulated 8086 with a DOS screen, registers, flags and variables. Step through it one instruction at a time and the matching source line lights up.

## The language

```pascal
program
    var a, b, i          ; 16-bit signed integers (also used as characters)
    array v[10]          ; arrays of integers, indexed from 0
    $hello = "Hello!"    ; string constants, for writeStr
begin
    a = 7 * (b + 1) / 2  ; + - * /  and parentheses
    if a > 3 & !(b = 0)  ; = <> < > <= >=   & | ~(xor) !(not)
        writeStr($hello)
    else
        writeInt(a)
    endif
    while i < 10
        v[i] = i * i
        i = i + 1
    endwhile
    loop 3               ; repeats 3 times, with the 8086 LOOP instruction
        write('*')
    endloop
    read(a)              ; a key, without echo
    readInt(b)           ; a number, with echo
    write(a)             ; a character
    newline
    masm                 ; assembly, copied to the output as is
        mov ax, a
        shl ax, 1
        mov b, ax
    endmasm
end.
```

Keywords are case-insensitive, `;` starts a comment, and every block has its own closing keyword. There are no procedures: the 2006 notes list them, with floating point and multi-dimensional arrays, as what was missing.

## How it works

It's a single-pass compiler that does syntax-directed translation, after Jack Crenshaw's [Let's Build a Compiler](https://compilers.iecc.com/crenshaw/). The lexer reads the source one character at a time and gives each token a one-letter token type (`x` for an identifier, `#` for an integer or character literal, `i` for IF, `w` for WHILE...), with the lexeme alongside. A predictive recursive descent parser, one procedure per nonterminal, emits the assembly as it recognises each construct: there is no abstract syntax tree and no intermediate representation. The symbol table is used only to catch undeclared and duplicate identifiers; every variable is a 16-bit word, so there is no type checking.

Code generation treats the 8086 as an accumulator machine with a stack: `AX` is the accumulator, `PUSH AX` saves the left operand of a binary operator while the right one is evaluated, and `POP BX` takes it back. There is no register allocation or optimisation. `a = b + 1` becomes:

```asm
MOV AX, B
PUSH AX
MOV AX, 1
POP BX
ADD AX,BX
MOV A, AX           ;store
```

The 8086 has no `SETcc` instructions, so relational operators call small runtime routines (`SETE`, `SETL`...) that leave 1 or 0 in `AX`, and boolean operators are evaluated in full, without short-circuiting. Jump targets are symbolic labels named before the code that uses them, and the assembler resolves the forward references, so there is no backpatching. Conditional jumps on the 8086 only reach 128 bytes, so every branch is a short jump over a long one.

Writing a recursive descent parser in assembly needs a semantic stack, to keep identifiers and labels while the parsing procedures call each other. `PushString` and `PopString` keep them on the 8086 stack: they take the return address off, push or pop the string one character per word, and put the return address back.

## What's in here

| Path | What |
| --- | --- |
| [`asm/MAIN.ASM`](asm/MAIN.ASM) | The compiler, in 8086 assembly |
| [`asm/INCLUDE/`](asm/INCLUDE) | Its parts: scanner and symbol table (`PGENERAL`), parser (`PBLOCKS`), code generator (`WINSTR`), file I/O, errors, data |
| [`asm/RUNTIME.ASM`](asm/RUNTIME.ASM) | Keyboard and screen I/O, decimal conversion and `SETcc`, for the compiler and the programs it compiles |
| [`examples/`](examples) | Example programs. `SORT`, `CALC` and `CAESAR` are the 2006 test programs, translated from Italian |
| [`prototype/80X86.PAS`](prototype/80X86.PAS) | A Turbo Pascal version of the same compiler, which grew from Crenshaw's TINY |
| [`docs/slides-2006.pdf`](docs/slides-2006.pdf) | The slides from when I presented it, 14 September 2006 (in Italian) |
| [`src/`](src) | The browser version: the compiler ported to TypeScript, the 8086 simulator and the page |
| [`tests/`](tests) | Test programs, and what the real compiler did with them in DOSBox |

## Running it on DOS

You need [DOSBox](https://www.dosbox.com/) (or any DOS) and JWasm. Copy `asm/` and `JWASMR.EXE` (the real-mode DOS build of JWasm) into a folder, mount it in DOSBox, then:

```
BUILD               builds MAIN.EXE
PAS FIBO            compiles FIBO.PAS, assembles FIBO.ASM and runs FIBO.EXE
```

`MAIN name` only compiles. Without a name it asks for one. The compiled programs need `RUNTIME.ASM` next to them when you assemble them.

To build on Windows or Linux with the native JWasm instead:

```bash
cd asm
jwasm -Zm -mz MAIN.ASM
```

`-Zm` turns on MASM 5.1 compatibility, which the 2006 code needs, and `-mz` writes a DOS `.EXE` directly, without a linker.

## The browser version

[`src/compiler.ts`](src/compiler.ts) is the assembly compiler ported line by line: one method per assembly procedure, with the same names. It writes the same output, byte for byte, and prints the same screen, errors included.

[`src/cpu.ts`](src/cpu.ts) runs the assembly. It reads the MASM source, not machine code, and executes it with 8086 semantics: 16-bit registers, all the flags, segments, a 256-byte stack, string instructions, and the parts of DOS and the BIOS that small programs use (`INT 21h` for characters and strings, `INT 10h` for the screen, `INT 16h` for keys, `INT 1Ah` for the clock). Writing to segment `B800h` puts characters on the screen. The routines of `RUNTIME.ASM` are built in and behave like the assembly ones.

```bash
npm install
npm run dev        # http://localhost:5174
npm test           # compiler and simulator tests
npm run build      # static files in dist/
```

### Tests

The tests check the JavaScript against the real thing. `npm run golden` assembles `MAIN.EXE` with JWasm, runs it on every program in `examples/` and `tests/programs/` in a headless DOSBox ([js-dos](https://js-dos.com/)), and saves what it wrote and what it showed in `tests/golden/`. Programs with a key file in `tests/keys/` are also assembled and run with those keys, and their screen is saved too. `npm test` then checks that:

- the TypeScript compiler writes the same `.ASM` and shows the same screen as `MAIN.EXE`, for every program, including the ones with errors
- the simulator, given the same keys, ends with the same screen as DOSBox

`npm run golden` needs JWasm on the `PATH`, or its path in the `JWASM` environment variable.

## What the restoration fixed

The 2006 code was built with MASM and LINK, and the backups in the archive show it was still changing. Getting it to run again meant fixing:

- `ReadString`, which reads the file name, had no `RET` and ran on into the next segment
- the output file was opened a second time, with the file handle as the access mode, which DOS rejects
- the symbol table was 100 bytes, not 100 entries of 16 bytes, so it overwrote what came after it
- labels were `L` plus a single digit, so the eleventh one was `L:`
- `if ... else ... endif` wrote the same label twice
- `a - b + c` and `a / b * c` stopped after the first `-` or `/`
- `!` (not) was parsed but never written to the output
- `writeStr($a, $b)` failed on the comma
- comparisons and printed numbers were unsigned, so `-3` came out as `65533`, after `12`; division didn't sign-extend
- at the end of the file the scanner kept reading old buffer contents

Other changes: the file name can be given on the command line, files with Unix line ends work, errors exit with code 1 and delete the half-written output, and error messages show the name of the symbol. Two I/O libraries I didn't write (GIOBE by Giorgio Ober, and UTIL_PRG) are replaced by `RUNTIME.ASM`. Comments, messages and examples are now in English.

## Credits

- Jack W. Crenshaw, [Let's Build a Compiler](https://compilers.iecc.com/crenshaw/) (1988-1995), which the design follows. `prototype/80X86.PAS` started from his TINY 1.1 and keeps his copyright.
- `IsAlpha`, `IsDigit`, `IsAlNum`, `strcmp`, `StrCpy` and `ToUpper` in `asm/INCLUDE/CHARS.ASM` come from the UCR Standard Library for 80x86 assembly by Randy Hyde, which is public domain.
- [JWasm](https://github.com/Baron-von-Riedesel/JWasm) assembles everything today. [js-dos](https://js-dos.com/) runs DOSBox for the tests.

## License

[MIT](LICENSE), except `prototype/80X86.PAS` (see Credits).
