@echo off
rem Builds MAIN.EXE, the compiler, with JWasm (JWASMR.EXE runs in DOS).
rem With MASM 5.1 instead:  MASM MAIN; then LINK MAIN;
JWASMR -Zm -mz MAIN.ASM
