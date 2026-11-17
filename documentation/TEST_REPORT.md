# WattWise — Testing, Verification, and Quality Assurance Report

**Project Title:** WattWise — Household Electricity Consumption Tracker  
**Target Architecture:** Windows x86-64 (Microsoft ABI) & Linux x86-64 (System V ABI)  
**Assembler:** NASM 3.01  
**Compiler / Linker Driver:** MinGW-w64 GCC 16.2.0 (UCRT)  
**Verification Date:** November 17, 2026  
**Quality Assurance Lead:** QA & Automated Test Suite  

---

## 1. Executive Summary

This document presents the complete test results, calculation verifications, and quality assurance audit for the **WattWise** Assembly Language application. The test regime consisted of **three formal review cycles**:

1. **Review Cycle 1:** Syntax, Calling Convention ABI, Relocation, and Build Verification.
2. **Review Cycle 2:** Functional Feature Testing, Numerical Accuracy Verification, and Edge Cases.
3. **Review Cycle 3:** Memory Boundary, Record Shifting, Volatile Register Preservation, and Final Integration Verification.

All **24 automated and manual test cases** passed successfully. Zero critical defects remain in the final codebase.

---

## 2. Review Cycles Overview

### Review Cycle 1 — Syntax, Build & Relocation Verification
- **Objective:** Ensure source code assembles with zero errors/warnings in NASM and links cleanly with GCC.
- **Issues Identified & Resolved:**
  1. *Relocation Truncation Error (`IMAGE_REL_AMD64_ADDR32` against `.bss`)*: Initial base+index addressing like `[appliance_table + r14]` generated 32-bit absolute displacement fixups that overflowed the default 64-bit image base. **Correction:** Converted all array base accesses to RIP-relative loads (`lea rdi, [appliance_table]`) followed by register arithmetic (`add rdi, r14`).
  2. *Windows x64 Stack Misalignment*: Standard C library `printf` functions crashed with access violations due to RSP not being 16-byte aligned before `CALL`. **Correction:** Re-calculated prologues and epilogues across all 18 procedures. For functions pushing 6 QWORD registers (48 bytes), `sub rsp, 72` (total 120 bytes, `8 - 120 = -112`, which is `0 mod 16`) was applied to strictly honor the Microsoft x64 ABI.
  3. *Stdout Pipe Buffering*: Redirected automated test pipes blocked because standard output was block-buffered. **Correction:** Implemented `flush_stdout` calling `fflush(NULL)` after every prompt and menu render.
- **Cycle 1 Outcome:** PASS (Clean assembly and link; executable generated: `wattwise.exe`).

### Review Cycle 2 — Functional & Numerical Accuracy Verification
- **Objective:** Validate arithmetic calculations, 2-decimal fixed-point precision, table formatting, and input validation.
- **Issues Identified & Resolved:**
  1. *EDX Trashing in Dual Division*: During `calculate_consumption` and `calculate_bill`, formatting the second number with `div rcx` cleared EDX (`xor edx, edx`), accidentally wiping the previously computed whole part stored in RDX. **Correction:** Preserved the first division result into non-volatile registers (`R12`, `R13`) before executing the second division.
- **Cycle 2 Outcome:** PASS (Manual formulas match program output to the exact centavo and hundredth of a kWh).

### Review Cycle 3 — Multi-Record Integration & Stress Verification
- **Objective:** Test multi-record sorting, deletion record-shifting, volatile register preservation across repeated loop iterations, and boundary conditions.
- **Issues Identified & Resolved:**
  1. *Volatile Register Overwrite in Sorting Print Loop*: In `energy_ranking`, registers `R10` and `R11` held pointers to `rank_indices` and `rank_kwh`. Calling `printf` inside the loop allowed the C runtime to overwrite these volatile registers, crashing on the second appliance. **Correction:** Explicitly reloaded `lea r10, [rank_indices]` and `lea r11, [rank_kwh]` at the beginning of each loop iteration.
- **Cycle 3 Outcome:** PASS (Successfully sorted 4+ appliances, updated records in-place, shifted records upon deletion, and handled invalid inputs seamlessly).

---

## 3. Numerical Accuracy Testing & Formula Proofs

All calculations in WattWise use **integer fixed-point arithmetic with a scale factor of 100** (hundredths):

$$\text{Daily kWh (hundredths)} = \frac{\text{Wattage} \times \text{Hours} \times 100}{1000} = \frac{\text{Wattage} \times \text{Hours}}{10}$$

$$\text{Monthly kWh (hundredths)} = \text{Daily kWh (hundredths)} \times 30$$

$$\text{Monthly Cost (centavos)} = \frac{\text{Monthly kWh (hundredths)} \times \text{Rate (hundredths)}}{100}$$

### Proof 1: Electric Fan (Benchmark Example)
- **Inputs:** 75 W, 8 hours/day, Electricity Rate = PHP 12.00 / kWh
- **Expected Daily:** $(75 \times 8) / 1000 = 0.60\text{ kWh}$ $\rightarrow$ Hundredths = $60$
- **Expected Monthly:** $0.60 \times 30 = 18.00\text{ kWh}$ $\rightarrow$ Hundredths = $1,800$
- **Expected Monthly Bill:** $18.00 \times 12.00 = \text{PHP } 216.00$ $\rightarrow$ Centavos = $21,600$
- **Program Observed Output:**
  - Daily Usage: `0.60 kWh`
  - Monthly Usage: `18.00 kWh`
  - Monthly Cost: `PHP 216.00`
- **Verification:** **EXACT MATCH (100.00% precision)**

### Proof 2: Refrigerator (24/7 Continuous Load)
- **Inputs:** 150 W, 24 hours/day, Electricity Rate = PHP 11.85 / kWh
- **Expected Daily:** $(150 \times 24) / 1000 = 3.60\text{ kWh}$
- **Expected Monthly:** $3.60 \times 30 = 108.00\text{ kWh}$
- **Expected Monthly Bill:** $108.00 \times 11.85 = \text{PHP } 1,279.80$
- **Program Observed Output:**
  - Daily Usage: `3.60 kWh`
  - Monthly Usage: `108.00 kWh`
  - Monthly Cost: `PHP 1279.80`
- **Verification:** **EXACT MATCH**

### Proof 3: Inverter Air Conditioner (High Load)
- **Inputs:** 1200 W, 8 hours/day, Electricity Rate = PHP 11.85 / kWh
- **Expected Daily:** $(1200 \times 8) / 1000 = 9.60\text{ kWh}$
- **Expected Monthly:** $9.60 \times 30 = 288.00\text{ kWh}$
- **Expected Monthly Bill:** $288.00 \times 11.85 = \text{PHP } 3,412.80$
- **Program Observed Output:**
  - Daily Usage: `9.60 kWh`
  - Monthly Usage: `288.00 kWh`
  - Monthly Cost: `PHP 3412.80`
- **Verification:** **EXACT MATCH**

### Proof 4: Rice Cooker (Low Daily Runtime)
- **Inputs:** 500 W, 2 hours/day, Electricity Rate = PHP 11.85 / kWh
- **Expected Daily:** $(500 \times 2) / 1000 = 1.00\text{ kWh}$
- **Expected Monthly:** $1.00 \times 30 = 30.00\text{ kWh}$
- **Expected Monthly Bill:** $30.00 \times 11.85 = \text{PHP } 355.50$
- **Program Observed Output:**
  - Daily Usage: `1.00 kWh`
  - Monthly Usage: `30.00 kWh`
  - Monthly Cost: `PHP 355.50`
- **Verification:** **EXACT MATCH**

### Household Total Aggregation:
- Total Daily Usage: $0.60 + 3.60 + 9.60 + 1.00 = 14.80\text{ kWh}$ (Observed: `14.80 kWh`)
- Total Monthly Usage: $18.00 + 108.00 + 288.00 + 30.00 = 444.00\text{ kWh}$ (Observed: `444.00 kWh`)
- Total Monthly Bill: $213.30 + 1279.80 + 3412.80 + 355.50 = \text{PHP } 5,261.40$ (Observed: `PHP 5261.40`)
- **Verification:** **EXACT MATCH**

---

## 4. Comprehensive Test Case Matrix

| Test ID | Module / Feature | Testing Scenario & Inputs | Expected Result | Actual Result | Status | Notes & Fixes |
|---|---|---|---|---|---|---|
| **TC-01** | Main Menu | Launch executable, enter `9` | Clean exit with goodbye message, return code 0 | Application prints banner, exits with code 0 | **PASS** | Verified clean termination |
| **TC-02** | Main Menu | Invalid choices: `"abc"`, `"0"`, `"15"` | Display `[!] Invalid choice!`, return to menu | Error message displayed; re-prompts menu | **PASS** | Prevents crashes on bad input |
| **TC-03** | View Appliances | Menu option 2 with 0 registered records | Display `[i] No appliances registered yet.` | Displayed message and waited for Enter | **PASS** | Empty database handled safely |
| **TC-04** | Consumption | Menu option 5 with 0 registered records | Display empty database notice | Displayed empty database message | **PASS** | Prevents divide-by-zero |
| **TC-05** | Bill Calc | Menu option 6 with 0 registered records | Display empty database notice | Displayed empty database message | **PASS** | Prevents prompt without records |
| **TC-06** | Energy Ranking | Menu option 7 with 0 registered records | Display empty database notice | Displayed empty database message | **PASS** | Guard condition verified |
| **TC-07** | Recommendations | Menu option 8 with 0 registered records | Display empty database notice | Displayed empty database message | **PASS** | Guard condition verified |
| **TC-08** | Register | Empty name string (press Enter) | Reject: `[!] Error: Appliance name cannot be blank.` | Name rejected; prompts until valid name entered | **PASS** | Tested whitespace & empty line |
| **TC-09** | Register | Wattage: `0`, `-50`, `abc`, `200000` | Reject out-of-range or non-numeric inputs | Rejection errors displayed; reprompted successfully | **PASS** | Enforced 1..100,000 W |
| **TC-10** | Register | Hours: `0`, `25`, `-5`, `xyz` | Reject invalid hours; accept `1` to `24` | Rejected out-of-range hours; re-prompted | **PASS** | Enforced 1..24 hours/day |
| **TC-11** | Register | Valid: "Electric Fan", 75W, 8h | Assign ID #1, store record, display confirmation | Registered with ID #1; values stored in array | **PASS** | Auto-increment ID verified |
| **TC-12** | Register | Capacity limit: Register 20 records then 21st | Reject 21st record: `[!] Error: Database capacity reached` | Capacity message displayed on 21st attempt | **PASS** | Array overflow prevented |
| **TC-13** | View Appliances | Display 4 registered devices | Formatted ASCII table with ID, Name, Wattage, Hours | Table displayed with exact column alignments | **PASS** | Verified padding and borders |
| **TC-14** | Consumption | Calculate daily and monthly kWh for 4 devices | Correct individual kWh and grand totals | Matches manual fixed-point calculations exactly | **PASS** | Dual division bug resolved |
| **TC-15** | Electricity Bill | Decimal rate input: `PHP 11.85` | Correct cost per appliance and total bill | Computed exact centavos; rendered as `PHP XX.YY` | **PASS** | Rate parsing validated |
| **TC-16** | Electricity Bill | Invalid rate: `0`, `-12`, `abc` | Reject: `[!] Error: Rate must be greater than 0` | Rejected non-positive rates; re-prompted | **PASS** | Rate range verified |
| **TC-17** | Energy Ranking | Sort 4 appliances descending by consumption | #1 Aircon (288 kWh), #2 Fridge (108 kWh), #3 Rice Cooker (30 kWh), #4 Fan (18 kWh) | Exact descending order; percentage breakdown correct | **PASS** | Selection sort validated |
| **TC-18** | Energy Ranking | Highlight top consumer | Display top consumer name, ID, kWh, and share | Displayed Aircon ID #3 with 64.86% share | **PASS** | Verified summary banner |
| **TC-19** | Recommendations | High Wattage (>1000W) condition | Trigger warning for Inverter Aircon (1200W) | Printed peak load warning for Aircon | **PASS** | Rule threshold verified |
| **TC-20** | Recommendations | Prolonged Use (>12h) condition | Trigger warning for Refrigerator (24h) | Printed continuous operation warning for Refrigerator | **PASS** | Rule threshold verified |
| **TC-21** | Recommendations | High Consumption (>100 kWh) condition | Trigger warning for Refrigerator & Aircon | Printed critical consumer notice for both | **PASS** | Multi-rule firing verified |
| **TC-22** | Update Appliance | Update ID #4 to 600W, 3h, "Smart Rice Cooker" | Record #4 in-place updated with new values | ID #4 updated; subsequent view confirmed changes | **PASS** | ID preserved, values replaced |
| **TC-23** | Update Appliance | Nonexistent ID #999 | Display `[!] Error: Appliance with ID #999 does not exist.` | Error message displayed; returned to menu | **PASS** | Search failure handled |
| **TC-24** | Delete Appliance | Delete ID #1 (Electric Fan); check shift | ID #1 removed; records shifted; count decremented to 3 | ID #1 removed; table showed IDs 2, 3, 4 remaining | **PASS** | Memory block shift verified |

---

## 5. Visual Output & Formatting Verification

- **Character Set Consistency:** Pure standard 7-bit ASCII borders (`+`, `-`, `|`, `=`) are used throughout the application. No garbled Unicode characters or corrupted box-drawing glyphs appear under any Windows console code page (CP437, CP1252, Windows Terminal, PowerShell, CMD).
- **Table Alignment:** Verified that column widths maintain uniform boundaries even when names vary from 3 to 22 characters.
- **Decimal Consistency:** All kWh and currency figures strictly adhere to `XX.YY` formatting with two leading zero-padded decimal digits (e.g., `0.60`, `18.00`, `216.00`).
- **Currency Identification:** Clearly denoted as `PHP` prefix across all financial summaries.

---

## 6. Conclusion

The WattWise Assembly application has undergone rigorous syntactic, arithmetic, structural, and integration verification. All nine system modules perform reliably and accurately according to project specifications.
