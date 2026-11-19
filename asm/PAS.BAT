@echo off
rem PAS name: compiles name.PAS to name.ASM, assembles it with JWasm and runs it.
if "%1"=="" goto usage
MAIN %1
if errorlevel 1 goto end
JWASMR -Zm -mz %1.ASM
if errorlevel 1 goto end
%1
goto end
:usage
echo Usage: PAS name   (compiles name.PAS)
:end
