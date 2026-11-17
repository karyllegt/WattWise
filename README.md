# WattWise: Household Electricity Consumption Tracker

**WattWise** is a lightweight, high-performance console application written in **NASM x86-64 Assembly Language**. It enables households to track electric appliance usage, calculate daily and monthly energy consumption (kWh), estimate electricity bills in Philippine Pesos (PHP), rank appliances by energy usage, and receive personalized energy-saving recommendations.

All data is managed in-memory using an efficient, contiguous 72-byte record structure with zero external database dependencies.

---

## 1. Project Overview

- **Project Name:** WattWise
- **Language:** Assembly Language (NASM x86-64)
- **Target OS:** Windows x64 (Microsoft ABI) & Linux x86-64 (System V ABI for Online Compilers)
- **Runtime Model:** In-memory fixed-array database (up to 20 appliances)
- **Arithmetic:** 2-decimal fixed-point integer mathematics (hundredths scale factor)
- **Purpose:** Academic demonstration of low-level data structures, system calling conventions, stack alignment, arithmetic logic, and algorithm implementation in modern 64-bit Assembly.

---

## 2. System Requirements

### For Windows x86-64 (Local Development):
- **Operating System:** Windows 10 / 11 (64-bit).
- **Assembler:** NASM 2.15 or newer (tested on NASM 3.01).
- **Linker / C Toolchain:** MinGW-w64 GCC 8.0+ (tested on GCC 16.2.0 with UCRT/MSVCRT).
- **Shell:** Command Prompt (`cmd.exe`) or PowerShell.
- **Hardware Architecture:** x86-64 / AMD64.

### For Online Compilers (Linux x86-64):
- **Compatible Platforms:** OnlineGDB, JDoodle, Compiler Explorer, Replit.
- **Compiler Mode:** NASM / Assembly (x86-64 Linux).
- **Linker Flag:** `gcc -no-pie` (if linking via GCC).

---

## 3. Project Folder Structure

```
WattWise/
│
├── windows/
│   ├── wattwise.asm          # Windows x86-64 NASM source code (Microsoft ABI)
│   ├── build.bat             # 1-click build script for Windows
│   ├── wattwise.exe          # Compiled 64-bit Windows executable
│   └── README.md             # Windows-specific quick reference
│
├── online/
│   └── wattwise.asm          # Linux x86-64 NASM source code (System V ABI)
│
├── documentation/
│   ├── system-architecture.md# System architecture, calling conventions & memory layout
│   ├── CODE_EXPLANATION.md   # Technical & beginner-friendly procedure documentation + defense Q&A
│   └── TEST_REPORT.md        # Comprehensive quality assurance and 3-cycle test report
│
└── README.md                 # Primary project guide and user manual
```

---

## 4. Installation and Setup

### Step 1: Install NASM
1. Download the NASM installer for Windows from the official website: [https://www.nasm.us](https://www.nasm.us).
2. Alternatively, install via WinGet in PowerShell:
   ```powershell
   winget install NASM.NASM
   ```
3. Verify installation:
   ```cmd
   nasm -v
   ```

### Step 2: Install MinGW-w64 GCC Toolchain
1. Download MinGW-w64 from [WinLibs](https://winlibs.com) or install via WinGet:
   ```powershell
   winget install BrechtSanders.WinLibs.POSIX.UCRT
   ```
2. Verify installation:
   ```cmd
   gcc --version
   ```

### Step 3: Configure PATH in Windows
Ensure that both `nasm.exe` and `gcc.exe` are added to your System or User `PATH` environment variable:
1. Press `Win + R`, type `sysdm.cpl`, and press Enter.
2. Under the **Advanced** tab, click **Environment Variables**.
3. Under **User variables**, select `Path` and click **Edit**.
4. Add the directories containing `nasm.exe` and `gcc.exe`.
5. Open a new terminal window to verify both commands run.

### Step 4: Configure Visual Studio Code (Optional)
To edit and build inside Visual Studio Code:
1. Install the extension **"NASM Language Support"** by *florianghirelli*.
2. Open the `WattWise` project folder.
3. Open the integrated terminal (`Ctrl + \``) to assemble and execute.

---

## 5. Compilation Instructions

### Windows Compilation

Open Command Prompt or PowerShell in the `windows/` directory:

```cmd
cd windows
```

#### Option A: Using the Automated Build Script
Run the provided `build.bat`:
```cmd
build.bat
```

#### Option B: Manual Command-Line Compilation
1. **Assemble the source code:**
   ```cmd
   nasm -f win64 wattwise.asm -o wattwise.obj
   ```
   - `-f win64`: Specifies the 64-bit Windows PE/COFF object format.
   - `-o wattwise.obj`: Names the generated object file.

2. **Link the object file:**
   ```cmd
   gcc wattwise.obj -o wattwise.exe
   ```
   - Uses GCC as the linker driver to link with the standard C runtime (`msvcrt`/`ucrt`).
   - Produces the standalone binary `wattwise.exe`.

---

## 6. How to Run the Program

In the `windows/` folder, run:

```cmd
.\wattwise.exe
```

The main menu appears:

```
==================================================================
               WattWise - Electricity Consumption Tracker         
                       Assembly Language (x86-64)                 
==================================================================
  [1] Register Appliance
  [2] View All Appliances
  [3] Update Appliance
  [4] Delete Appliance
  [5] Calculate Electricity Consumption
  [6] Calculate Electricity Bill
  [7] Energy Consumption Ranking
  [8] Energy Saving Recommendations
  [9] Exit Program
------------------------------------------------------------------
Select an option (1-9): 
```

Type a number from `1` to `9` and press Enter to select an action. After each operation finishes, press Enter to return to the menu.

---

## 7. Online Compiler Instructions

If you are on Linux or using an online browser-based compiler (e.g., [OnlineGDB](https://www.onlinegdb.com)):

1. Open **OnlineGDB** and set the Language to **Assembly (NASM)**.
2. Copy the entire contents of `online/wattwise.asm` into the online editor.
3. If the platform asks for compile flags or uses GCC to link:
   ```bash
   nasm -f elf64 wattwise.asm -o wattwise.o
   gcc -no-pie wattwise.o -o wattwise
   ```
4. Click **Run**.
5. *Note:* The online version uses the **System V AMD64 ABI** (`RDI`, `RSI`, `RDX`, `RCX`, `R8`, `R9`) standard on Linux.

---

## 8. Application Features

| Menu Option | Feature | Detailed Description |
|---|---|---|
| **[1]** | **Register Appliance** | Prompts for Appliance Name (max 31 chars), Wattage (1 to 100,000 W), and Daily Operating Hours (1 to 24 hrs). Assigns a sequential unique ID and stores the record in memory. Up to 20 appliances can be stored. |
| **[2]** | **View All Appliances** | Renders an ASCII table showing all registered appliances, their unique IDs, power ratings, and daily operating hours. |
| **[3]** | **Update Appliance** | Searches for an existing appliance by ID, displays its current configuration, and allows in-place modification of Name, Wattage, and Hours with full input validation. |
| **[4]** | **Delete Appliance** | Removes an appliance by ID and automatically shifts all subsequent records in memory using hardware-accelerated block moves (`rep movsb`), ensuring no memory gaps remain. |
| **[5]** | **Calculate Consumption** | Computes daily and monthly electricity usage in kilowatt-hours (kWh) using fixed-point math: $\text{Daily} = (W \times H)/1000$, $\text{Monthly} = \text{Daily} \times 30$. Displays individual usage and total household consumption. |
| **[6]** | **Calculate Bill** | Prompts for the local electricity tariff (PHP/kWh, e.g. 12.00 or 11.85). Calculates itemized monthly costs per appliance and summarizes the total estimated household monthly bill. |
| **[7]** | **Energy Ranking** | Sorts all appliances in descending order of monthly consumption using Selection Sort. Displays each appliance's rank, monthly kWh, and percentage share of total household energy. Highlights the #1 highest consumer. |
| **[8]** | **Recommendations** | Evaluates appliances against energy-efficiency thresholds (High Wattage $>1000\text{W}$, Long Hours $>12\text{h}$, High Consumption $>100\text{ kWh}$) and outputs actionable energy-saving advice. |
| **[9]** | **Exit Program** | Terminates the application cleanly with a goodbye message and returns code 0 to the operating system. |

---

## 9. Sample Usage & Walkthrough

### Scenario: Registering an Electric Fan and Computing Its Bill

```text
Select an option (1-9): 1

>>> [1] REGISTER NEW APPLIANCE <<<
Enter appliance name: Electric Fan
Enter rated wattage (Watts, 1 - 100000): 75
Enter daily operating hours (1 - 24): 8

[+] Appliance 'Electric Fan' successfully registered with ID #1!

Press [Enter] to return to the main menu...
```

### Viewing Electricity Consumption (Option 5):
```text
>>> [5] ELECTRICITY CONSUMPTION ANALYSIS <<<
Formula: Daily kWh = (Watts * Hours) / 1000
         Monthly kWh = Daily kWh * 30 days
+------+------------------------+-----------------+-------------------+
| ID   | Appliance Name         | Daily Usage     | Monthly Usage     |
+------+------------------------+-----------------+-------------------+
| 1    | Electric Fan           |          0.60 kWh |           18.00 kWh |
+------+------------------------+-----------------+-------------------+
| TOTAL HOUSEHOLD CONSUMPTION   |          0.60 kWh |           18.00 kWh |
+-------------------------------+-----------------+-------------------+
```

### Estimating Electricity Bill (Option 6 at PHP 12.00/kWh):
```text
>>> [6] ELECTRICITY BILL ESTIMATION <<<
Calculates estimated monthly cost based on electricity rate.
Enter electricity tariff rate per kWh (PHP, e.g. 12.00): 12.00

Rate Applied: PHP 12.00 per kWh (30-day projection)
+------+------------------------+-------------------+--------------------+
| ID   | Appliance Name         | Monthly Usage     | Monthly Cost (PHP) |
+------+------------------------+-------------------+--------------------+
| 1    | Electric Fan           |           18.00 kWh | PHP            216.00 |
+------+------------------------+-------------------+--------------------+
| TOTAL ESTIMATED MONTHLY BILL                       | PHP            216.00 |
+---------------------------------------------------+--------------------+
```

---

## 10. Troubleshooting

| Symptom / Error | Cause | Practical Solution |
|---|---|---|
| `'nasm' is not recognized as an internal or external command` | NASM directory is not in the system PATH. | Add `C:\Users\<User>\AppData\Local\bin\NASM` (or your NASM install location) to System Environment Variables. |
| `'gcc' is not recognized as an internal or external command` | MinGW-w64 GCC is not in the system PATH. | Install MinGW-w64 and add its `bin/` directory to PATH. |
| `relocation truncated to fit: IMAGE_REL_AMD64_ADDR32` | SIB addressing used 32-bit absolute displacements against `.bss`. | Use RIP-relative `lea` to load the array base pointer, then add register offsets. (Already resolved in current code). |
| Program crashes immediately when calling `printf` | Misaligned stack pointer (`RSP % 16 != 0`). | Ensure every procedure adjusts RSP so that RSP is 16-byte aligned before `CALL`. (Already resolved in current code). |
| `[!] Error: Invalid numeric input.` | User typed non-digit characters (e.g. letters or negative signs). | Enter clean positive whole numbers (e.g. `75` or `12`). |
| Missing DLL errors (`msvcrt.dll` or `api-ms-win-crt-...`) | Outdated C runtime on legacy Windows installations. | Install the Microsoft Visual C++ Redistributable or run via MinGW-w64 shell. |

---

## 11. Limitations

1. **In-Memory Storage Only:** Records are stored exclusively in the `.bss` memory section. All records disappear when the application terminates.
2. **Fixed Capacity:** The system stores a maximum of 20 appliances to ensure deterministic memory bounds without dynamic heap management.
3. **Monthly Calculation Model:** Monthly calculations assume a standard 30-day billing cycle ($30 \times \text{Daily kWh}$).
4. **Tariff Flat Rate:** Bill estimation applies a single flat per-kWh rate rather than multi-tiered consumption block tariffs.

---

## 12. Credits & Academic Information

- **Course:** Computer Organization and Assembly Language Programming
- **Project Title:** WattWise — Household Electricity Consumption Tracker
- **Architecture:** x86-64 / AMD64 (NASM)
- **Target OS:** Windows 10/11 & Linux (Online)
- **Year:** Academic Year 2026
