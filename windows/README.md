# WattWise (Windows x86-64 Version)

This directory contains the Windows x86-64 source code and build automation script for **WattWise**.

---

## 1. Files in This Directory

- `wattwise.asm`: Main NASM source code targeting the Microsoft x64 Calling Convention.
- `build.bat`: Windows batch script that assembles with NASM and links with GCC in one click.
- `wattwise.exe`: Compiled 64-bit executable.

---

## 2. Requirements

- **Operating System:** Windows 10 or 11 (64-bit).
- **Assembler:** NASM 2.15+ (tested on NASM 3.01).
- **Toolchain:** MinGW-w64 GCC (with UCRT or MSVCRT runtime).

---

## 3. How to Build

### Option A: Using `build.bat` (Recommended)
Simply double-click `build.bat` in File Explorer, or run it from CMD/PowerShell:
```cmd
build.bat
```

### Option B: Manual Command Line
Open Command Prompt or PowerShell in this directory:
```cmd
nasm -f win64 wattwise.asm -o wattwise.obj
gcc wattwise.obj -o wattwise.exe
```

---

## 4. How to Run

```cmd
.\wattwise.exe
```
Follow the on-screen menu to register appliances, calculate power consumption, estimate bills, rank energy consumers, and view energy recommendations.
