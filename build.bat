@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM  VCHIP-8 build script (Windows)
REM  Emulator created by giygas.
REM
REM  Prerequisites (must be on PATH):
REM    - NASM            https://www.nasm.us/
REM    - MinGW-w64 gcc    https://www.mingw-w64.org/
REM    - SDL2 MinGW-w64 development package
REM        https://github.com/libsdl-org/SDL/releases
REM        (grab "SDL2-devel-x.xx.x-mingw.zip", extract it somewhere, and
REM         point SDL2_PATH below at the extracted x86_64-w64-mingw32 folder)
REM ============================================================================

set "ROOT=%~dp0"
set "SRC=%ROOT%src"
set "OUT=%ROOT%build"

REM ---- EDIT THIS if your SDL2 dev package lives somewhere else ----
if not defined SDL2_PATH set "SDL2_PATH=C:\SDL2-mingw\x86_64-w64-mingw32"

if not exist "%OUT%" mkdir "%OUT%"

echo [VCHIP-8] Assembling src\windows\main.asm ...
REM NOTE: use a forward slash here, not a trailing backslash -- a backslash
REM immediately before a closing quote is parsed as an escaped quote by
REM MSVCRT-style argv parsing (which nasm.exe uses), which would otherwise
REM swallow the rest of the command line into this one argument.
nasm -f win64 -I"%SRC%/" -o "%OUT%\main.obj" "%SRC%\windows\main.asm"
if errorlevel 1 goto :error

echo [VCHIP-8] Compiling icon resource ...
set "ROOT_FS=%ROOT:\=/%"
windres -I "%ROOT_FS%" "%ROOT%vchip8.rc" -O coff -o "%OUT%\icon.res"
if errorlevel 1 goto :error

echo [VCHIP-8] Linking ...
gcc -o "%OUT%\vchip8.exe" "%OUT%\main.obj" "%OUT%\icon.res" -mwindows -L"%SDL2_PATH%\lib" -lSDL2 -luser32 -lcomdlg32
if errorlevel 1 goto :error

echo [VCHIP-8] Build complete: %OUT%\vchip8.exe
echo Copy SDL2.dll from "%SDL2_PATH%\bin" into %OUT% before running,
echo then run:  vchip8.exe ^<path-to-rom^>
goto :eof

:error
echo.
echo [VCHIP-8] Build failed.
exit /b 1
