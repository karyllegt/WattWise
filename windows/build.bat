@echo off
REM ==============================================================================
REM WattWise - Build Script for Windows x86-64
REM Requirements: NASM and MinGW-w64 GCC in PATH
REM ==============================================================================

echo [WattWise Build] Assembling with NASM (win64)...
nasm -f win64 wattwise.asm -o wattwise.obj
if errorlevel 1 (
    echo [ERROR] NASM assembly failed.
    exit /b 1
)

echo [WattWise Build] Linking with GCC...
gcc wattwise.obj -o wattwise.exe
if errorlevel 1 (
    echo [ERROR] Linking failed.
    exit /b 1
)

echo.
echo ==================================================================
echo [SUCCESS] Build complete! Executable generated: wattwise.exe
echo Run wattwise.exe to start the application.
echo ==================================================================
