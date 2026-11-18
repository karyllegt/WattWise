@echo off
setlocal enabledelayedexpansion

echo ====================================================================
echo  WattWise (Hardware Hacks Edition) - Build Script (x86-64 Windows)
echo ====================================================================
echo.

:: 1. Check for NASM
where nasm >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] NASM assembler not found in PATH!
    echo Please install NASM or add it to your system PATH.
    pause
    exit /b 1
)

:: 2. Check for GCC
where gcc >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] MinGW-w64 GCC linker not found in PATH!
    echo Please install MinGW-w64 GCC or add it to your system PATH.
    pause
    exit /b 1
)

:: 3. Assemble wattwise_with_hacks.asm with NASM
echo [*] Step 1: Assembling wattwise_with_hacks.asm to win64 object file...
nasm -f win64 wattwise_with_hacks.asm -o wattwise_with_hacks.obj
if %ERRORLEVEL% neq 0 (
    echo [ERROR] NASM assembly failed!
    pause
    exit /b 1
)
echo [+] Assembly successful: wattwise_with_hacks.obj created.
echo.

:: 4. Link with GCC
echo [*] Step 2: Linking with GCC (C runtime / MSVCRT)...
gcc -m64 wattwise_with_hacks.obj -o wattwise_with_hacks.exe
if %ERRORLEVEL% neq 0 (
    echo [ERROR] GCC linking failed!
    pause
    exit /b 1
)
echo [+] Linking successful: wattwise_with_hacks.exe created!
echo.

echo ====================================================================
echo  BUILD COMPLETE! Run 'wattwise_with_hacks.exe' to launch the program.
echo ====================================================================
echo.
endlocal
