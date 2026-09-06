@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM  VCHIP-8 -- one-shot setup + build (Windows)
REM
REM  Downloads everything needed into a local "tools\" folder next to this
REM  script (NASM, w64devkit for gcc, SDL2 mingw dev package), then builds
REM  the emulator. Nothing is installed system-wide and your PATH is only
REM  modified for the lifetime of this script.
REM
REM  Re-running this script is safe -- it skips anything already downloaded.
REM ============================================================================

set "ROOT=%~dp0"
set "TOOLS=%ROOT%tools"
set "OUT=%ROOT%build"
set "NASM_VER=2.16.03"

if not exist "%TOOLS%" mkdir "%TOOLS%"
if not exist "%OUT%" mkdir "%OUT%"

powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12" >nul 2>nul

REM ----------------------------------------------------------------------
REM  1. NASM
REM ----------------------------------------------------------------------
where nasm >nul 2>nul
if !errorlevel! equ 0 (
    echo [setup] nasm already on PATH, skipping download.
    for /f "delims=" %%P in ('where nasm') do set "NASM_DIR=%%~dpP"
) else (
    set "NASM_DIR=%TOOLS%\nasm"
    if exist "!NASM_DIR!\nasm.exe" (
        echo [setup] nasm already downloaded.
    ) else (
        echo [setup] Downloading NASM !NASM_VER! ...
        powershell -NoProfile -Command "Invoke-WebRequest -UseBasicParsing -Uri 'https://www.nasm.us/pub/nasm/releasebuilds/!NASM_VER!/win64/nasm-!NASM_VER!-win64.zip' -OutFile '%TOOLS%\nasm.zip'"
        if not exist "%TOOLS%\nasm.zip" (
            echo [setup] NASM download failed. If !NASM_VER! is no longer current,
            echo         check https://www.nasm.us/pub/nasm/releasebuilds/ and edit
            echo         NASM_VER near the top of this script.
            goto :error
        )
        powershell -NoProfile -Command "Expand-Archive -Path '%TOOLS%\nasm.zip' -DestinationPath '%TOOLS%\nasm_tmp' -Force"
        if not exist "!NASM_DIR!" mkdir "!NASM_DIR!"
        for /f "delims=" %%F in ('dir /s /b "%TOOLS%\nasm_tmp\nasm.exe" 2^>nul') do (
            for %%D in ("%%F") do copy /y "%%~dpD*.exe" "!NASM_DIR!\" >nul
        )
        rd /s /q "%TOOLS%\nasm_tmp" 2>nul
        del "%TOOLS%\nasm.zip" 2>nul
        if not exist "!NASM_DIR!\nasm.exe" (
            echo [setup] Could not locate nasm.exe after extracting.
            goto :error
        )
    )
)
set "PATH=!NASM_DIR!;%PATH%"

REM ----------------------------------------------------------------------
REM  2. GCC (w64devkit -- a standalone, no-installer MinGW-w64 toolchain)
REM ----------------------------------------------------------------------
where gcc >nul 2>nul
if !errorlevel! equ 0 (
    echo [setup] gcc already on PATH, skipping download.
    for /f "delims=" %%P in ('where gcc') do set "GCC_DIR=%%~dpP"
) else (
    set "GCC_DIR=%TOOLS%\w64devkit\bin"
    if exist "!GCC_DIR!\gcc.exe" (
        echo [setup] w64devkit already downloaded.
    ) else (
        echo [setup] Looking up latest w64devkit release ...
        powershell -NoProfile -Command "$r = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/skeeto/w64devkit/releases/latest' -Headers @{'User-Agent'='vchip8-setup'}; $a = $r.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1; if ($a) { Invoke-WebRequest -UseBasicParsing -Uri $a.browser_download_url -OutFile '%TOOLS%\w64devkit.zip' }"
        if not exist "%TOOLS%\w64devkit.zip" (
            echo [setup] w64devkit download failed. Check your internet connection,
            echo         or download it manually from
            echo         https://github.com/skeeto/w64devkit/releases
            goto :error
        )
        echo [setup] Extracting w64devkit ...
        powershell -NoProfile -Command "Expand-Archive -Path '%TOOLS%\w64devkit.zip' -DestinationPath '%TOOLS%\w64devkit_tmp' -Force"
        for /f "delims=" %%F in ('dir /s /b "%TOOLS%\w64devkit_tmp\gcc.exe" 2^>nul') do set "GCC_FOUND=%%~dpF"
        if not defined GCC_FOUND (
            echo [setup] Could not locate gcc.exe inside the downloaded archive.
            goto :error
        )
        REM GCC_FOUND is the "...\w64devkit\bin\" folder -- keep its parent tree
        for %%D in ("!GCC_FOUND!..") do set "W64DK_ROOT=%%~fD"
        if exist "%TOOLS%\w64devkit" rd /s /q "%TOOLS%\w64devkit"
        move "!W64DK_ROOT!" "%TOOLS%\w64devkit" >nul
        rd /s /q "%TOOLS%\w64devkit_tmp" 2>nul
        del "%TOOLS%\w64devkit.zip" 2>nul
        if not exist "!GCC_DIR!\gcc.exe" (
            echo [setup] gcc.exe missing after moving w64devkit into place.
            goto :error
        )
    )
)
set "PATH=!GCC_DIR!;%PATH%"

REM ----------------------------------------------------------------------
REM  3. SDL2 (MinGW dev package)
REM ----------------------------------------------------------------------
set "SDL2_ROOT=%TOOLS%\sdl2\x86_64-w64-mingw32"
if exist "%SDL2_ROOT%\lib\libSDL2.dll.a" (
    echo [setup] SDL2 dev package already downloaded.
) else (
    echo [setup] Looking up latest SDL2 release ...
    powershell -NoProfile -Command "$r = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/libsdl-org/SDL/releases/latest' -Headers @{'User-Agent'='vchip8-setup'}; $a = $r.assets | Where-Object { $_.name -like '*mingw*.zip' } | Select-Object -First 1; if ($a) { Invoke-WebRequest -UseBasicParsing -Uri $a.browser_download_url -OutFile '%TOOLS%\sdl2.zip' }"
    if not exist "%TOOLS%\sdl2.zip" (
        echo [setup] SDL2 download failed. Check your internet connection, or
        echo         download the "*-mingw.zip" package manually from
        echo         https://github.com/libsdl-org/SDL/releases
        goto :error
    )
    echo [setup] Extracting SDL2 ...
    powershell -NoProfile -Command "Expand-Archive -Path '%TOOLS%\sdl2.zip' -DestinationPath '%TOOLS%\sdl2_tmp' -Force"
    for /f "delims=" %%F in ('dir /s /b /ad "%TOOLS%\sdl2_tmp\x86_64-w64-mingw32" 2^>nul') do set "SDL2_FOUND=%%F"
    if not defined SDL2_FOUND (
        echo [setup] Could not locate the x86_64-w64-mingw32 folder inside the
        echo         downloaded SDL2 archive.
        goto :error
    )
    if exist "%TOOLS%\sdl2" rd /s /q "%TOOLS%\sdl2"
    mkdir "%TOOLS%\sdl2"
    move "!SDL2_FOUND!" "%SDL2_ROOT%" >nul
    rd /s /q "%TOOLS%\sdl2_tmp" 2>nul
    del "%TOOLS%\sdl2.zip" 2>nul
    if not exist "%SDL2_ROOT%\lib\libSDL2.dll.a" (
        echo [setup] libSDL2.dll.a missing after moving SDL2 into place.
        goto :error
    )
)
set "SDL2_PATH=%SDL2_ROOT%"

echo.
echo [setup] Toolchain ready:
echo   nasm : !NASM_DIR!
echo   gcc  : !GCC_DIR!
echo   SDL2 : %SDL2_PATH%
echo.

REM ----------------------------------------------------------------------
REM  4. Build
REM ----------------------------------------------------------------------
call "%ROOT%build.bat"
if errorlevel 1 goto :error

REM Stage SDL2.dll next to the executable so it runs out of the box.
copy /y "%SDL2_PATH%\bin\SDL2.dll" "%OUT%\SDL2.dll" >nul

echo.
echo [setup] All done. Run it with:
echo   "%OUT%\vchip8.exe" "%ROOT%roms\ibm_logo.ch8"
goto :eof

:error
echo.
echo [setup] Setup/build failed -- see the messages above.
exit /b 1
