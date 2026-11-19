// Runs the real compiler in DOSBox and records what it does, as the reference
// for the JavaScript port (tests/golden). For each program in examples/ and
// tests/programs/:
//   NAME.ASM  the assembly MAIN.EXE wrote (missing if compiling failed)
//   NAME.LOG  the compiler's screen at the end (the last 25 lines)
//   NAME.OUT  the program's screen at the end, if tests/keys/NAME.KEY exists:
//             the program is assembled with JWasm and run with those keys
//
// Usage: node scripts/dos.mjs [NAME...]
// Needs JWasm (https://github.com/Baron-von-Riedesel/JWasm) on the PATH, or
// its path in the JWASM environment variable. DOSBox comes from the js-dos
// "emulators" package and runs headless.
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { basename, join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const build = join(root, "build");
const golden = join(root, "tests/golden");
const jwasm = process.env.JWASM || "jwasm";
const require = createRequire(import.meta.url);
require("emulators");
const emulators = globalThis.emulators;
emulators.pathPrefix = join(root, "node_modules/emulators/dist/");

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function assemble(cwd, args) {
  try {
    execFileSync(jwasm, ["-q", "-Zm", ...args], { cwd, encoding: "latin1", stdio: "pipe" });
  } catch (e) {
    throw new Error(`jwasm ${args.join(" ")} failed:\n${e.stdout ?? ""}${e.stderr ?? ""}`);
  }
}

// GLFW key codes, which js-dos uses
const SHIFT = 340;
const SHIFTED = { "!": "1", "@": "2", "#": "3", $: "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0", _: "-", "+": "=", "<": ",", ">": ".", "?": "/", ":": ";", '"': "'", "|": "\\", "{": "[", "}": "]", "~": "`" };
function keyCode(ch) {
  if (ch === "\n") return 257;
  if (ch === "\x1b") return 256;
  if (ch === "\b") return 259;
  return ch.toUpperCase().charCodeAt(0);
}

async function typeKeys(ci, keys) {
  for (const ch of keys) {
    let c = ch;
    let shift = /[A-Z]/.test(ch);
    if (SHIFTED[ch]) { c = SHIFTED[ch]; shift = true; }
    const k = keyCode(c);
    if (shift) ci.sendKeyEvent(SHIFT, true);
    ci.sendKeyEvent(k, true);
    await sleep(30);
    ci.sendKeyEvent(k, false);
    if (shift) ci.sendKeyEvent(SHIFT, false);
    await sleep(70);
  }
}

// Boots DOSBox with `files` on C:, runs `command`, types `keys` and returns
// the screen and the files named in `read`.
async function dos(files, command, keys = "", read = []) {
  const base = (await emulators.bundle()).dosboxConf;
  const conf = base.substring(0, base.indexOf("[autoexec]")) +
    "[autoexec]\n@echo off\nmount c .\nc:\ncls\necho.>STARTED.TXT\ncls\n" + command +
    "\nSCRDUMP\necho.>DONE.TXT\n";
  const fs = Object.entries(files).map(([path, contents]) => ({ path: path.toUpperCase(), contents: new Uint8Array(contents) }));
  fs.push({ path: "SCRDUMP.COM", contents: new Uint8Array(readFileSync(join(build, "SCRDUMP.COM"))) });
  const ci = await emulators.dosboxNode([{ dosboxConf: conf, jsdosConf: { version: emulators.version } }, ...fs]);
  const exists = async (f) => { try { await ci.fsReadFile(f); return true; } catch { return false; } };
  try {
    for (let i = 0; !(await exists("STARTED.TXT")); i++) {
      if (i > 100) throw new Error("DOSBox did not start");
      await sleep(100);
    }
    await sleep(500);
    await typeKeys(ci, keys);
    for (let i = 0; !(await exists("DONE.TXT")); i++) {
      if (i > 150) throw new Error(`"${command}" did not finish (waiting for keys?)`);
      await sleep(100);
    }
    const screen = Buffer.from(await ci.fsReadFile("SCREEN.TXT")).toString("latin1")
      .split("\r\n").map((l) => l.trimEnd()).join("\n").replace(/\n+$/, "") + "\n";
    const out = {};
    for (const f of read) out[f] = (await exists(f)) ? Buffer.from(await ci.fsReadFile(f)) : null;
    return { screen, files: out };
  } finally {
    await ci.exit();
  }
}

mkdirSync(build, { recursive: true });
mkdirSync(golden, { recursive: true });
assemble(join(root, "asm"), [`-mz`, `-Fo=${join(build, "MAIN.EXE")}`, "MAIN.ASM"]);
assemble(join(root, "scripts"), [`-bin`, `-Fo=${join(build, "SCRDUMP.COM")}`, "SCRDUMP.ASM"]);
const main = readFileSync(join(build, "MAIN.EXE"));

const sources = [join(root, "examples"), join(root, "tests/programs")]
  .flatMap((dir) => readdirSync(dir).filter((f) => /\.PAS$/i.test(f)).map((f) => join(dir, f)));
const only = process.argv.slice(2).map((n) => n.toUpperCase());
let failed = 0;
for (const src of sources) {
  const name = basename(src, ".PAS").toUpperCase();
  if (only.length && !only.includes(name)) continue;
  try {
    const compiled = await dos({ "MAIN.EXE": main, [`${name}.PAS`]: readFileSync(src) }, `MAIN ${name}`, "", [`${name}.ASM`]);
    writeFileSync(join(golden, `${name}.LOG`), compiled.screen);
    const asm = compiled.files[`${name}.ASM`];
    rmSync(join(golden, `${name}.ASM`), { force: true });
    rmSync(join(golden, `${name}.OUT`), { force: true });
    let note = "compile error";
    if (asm) {
      writeFileSync(join(golden, `${name}.ASM`), asm);
      note = "compiled";
      const keyFile = join(root, "tests/keys", `${name}.KEY`);
      if (existsSync(keyFile)) {
        writeFileSync(join(build, `${name}.ASM`), asm);
        assemble(build, ["-mz", `-I${join(root, "asm")}`, `-Fo=${name}.EXE`, `${name}.ASM`]);
        const keys = readFileSync(keyFile, "utf8").replace(/\r?\n$/, "").replace(/\\n/g, "\n").replace(/\\e/g, "\x1b").replace(/\\b/g, "\b");
        const ran = await dos({ [`${name}.EXE`]: readFileSync(join(build, `${name}.EXE`)) }, name, keys);
        writeFileSync(join(golden, `${name}.OUT`), ran.screen);
        note = "compiled and ran";
      }
    }
    console.log(`${name.padEnd(10)} ${note}`);
  } catch (e) {
    failed++;
    console.log(`${name.padEnd(10)} FAILED: ${e.message}`);
  }
}
process.exit(failed ? 1 : 0);
