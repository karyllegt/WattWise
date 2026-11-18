# WattWise (Windows x86-64 Version)

This directory contains the Windows x86-64 source code and build automation scripts for **WattWise**.

---

## 1. Files in This Directory

- `wattwise.asm`: Standard baseline NASM source code targeting the Microsoft x64 Calling Convention.
- `wattwise_with_hacks.asm`: High-Performance edition implementing hardware CPU hacks (reciprocal division, LEA scaling, branchless CMOV sort).
- `build.bat`: Windows batch script that assembles and links `wattwise.asm` into `wattwise.exe`.
- `build_hacks.bat`: Windows batch script that assembles and links `wattwise_with_hacks.asm` into `wattwise_with_hacks.exe`.
- `wattwise.exe`: Compiled 64-bit baseline executable.
- `wattwise_with_hacks.exe`: Compiled 64-bit CPU-optimized executable.

---

## 2. Requirements

- **Operating System:** Windows 10 or 11 (64-bit).
- **Assembler:** NASM 2.15+ (tested on NASM 3.01).
- **Toolchain:** MinGW-w64 GCC (with UCRT or MSVCRT runtime).

---

## 3. How to Build

### Option A: Using 1-Click Batch Scripts (Recommended)

- **To build the Baseline Edition:**
  ```cmd
  build.bat
  ```

- **To build the High-Performance Edition (with CPU Hacks):**
  ```cmd
  build_hacks.bat
  ```

### Option B: Manual Command Line

- **Baseline:**
  ```cmd
  nasm -f win64 wattwise.asm -o wattwise.obj
  gcc -m64 wattwise.obj -o wattwise.exe
  ```

- **High-Performance Edition:**
  ```cmd
  nasm -f win64 wattwise_with_hacks.asm -o wattwise_with_hacks.obj
  gcc -m64 wattwise_with_hacks.obj -o wattwise_with_hacks.exe
  ```

---

## 4. How to Run

```cmd
:: Run baseline:
.\wattwise.exe

:: Run optimized edition:
.\wattwise_with_hacks.exe
```

Follow the on-screen menu to register appliances, calculate power consumption, estimate bills, rank energy consumers, and view energy recommendations.

---

## 5. Architectural CPU Hacks Highlight

See **`../documentation/CODE_EXPLANATION_HACKS.md`** for detailed cycle counts and mathematical proofs for the hardware hacks implemented in `wattwise_with_hacks.asm`:
- **Reciprocal Division:** Replaces 40-cycle `div` with invariant multipliers (`0xCCCCCCCCCCCCCCCD` and `0x28F5C28F5C28F5C3`), cutting latency to 4 cycles.
- **LEA Multiplication:** Single-cycle ALU operations for $\times 10$, $\times 100$, $\times 30$, and 72-byte record indexing.
- **Branchless Sort:** `cmovg` eliminates pipeline flushes from branch mispredictions.
