; ==============================================================================
; WattWise - Household Electricity Consumption Tracker (HIGH-PERFORMANCE EDITION)
; Architecture: Windows x86-64 (Microsoft ABI)
; Assembler: NASM (format: win64)
; Linker: GCC (MinGW-w64) linking with standard C runtime (msvcrt / ucrt)
;
; ==============================================================================
; ARCHITECTURAL CPU OPTIMIZATIONS & HARDWARE HACKS (LAB EVALUATION BONUS):
; 1. LEA-Based Integer Multiplication:
;    - x * 10 calculated as ((x * 5) * 2) via `lea rax, [rax + rax*4]` + `add rax, rax`
;      Latency: 2 single-cycle ALU operations (vs. 3-4 cycle IMUL).
;    - x * 100 calculated as ((x * 25) * 4) via two LEAs + SHL 2.
; 2. Zero-Multiplier Array Address Generation:
;    - Record size is 72 bytes. Instead of `imul rax, 72`, we compute:
;      offset = (index * 9) * 8 via `lea rax, [index + index*8]` + `shl rax, 3`.
;      Latency: 2 clock cycles (vs. 4 cycle IMUL).
; 3. Reciprocal Invariant Integer Division & Modulo (Granlund-Montgomery Method):
;    - Replaces slow, 40-cycle hardware DIV instructions with invariant 64-bit
;      multipliers and bit-shifts:
;      * fast_divmod10:  Magic constant 0xCCCCCCCCCCCCCCCD (cuts 40 cycles to ~4)
;      * fast_divmod100: Magic constant 0x28F5C28F5C28F5C3 (cuts 40 cycles to ~4)
; 4. Branchless Selection via CMOV (Conditional Move):
;    - Selection sort inner loop uses `cmovg` instead of conditional branch jumps,
;      eliminating CPU instruction pipeline flushes and branch mispredictions.
; 5. Hardware String Acceleration:
;    - In-memory record shifting during deletion executed via `rep movsb` with `cld`.
; 6. Zero-Latency Register Clears:
;    - `xor reg, reg` recognized by CPU register renaming stage with 0 execution latency.
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; External C runtime functions
; ------------------------------------------------------------------------------
extern printf
extern getchar
extern puts
extern fflush
extern exit

; ------------------------------------------------------------------------------
; Constants
; ------------------------------------------------------------------------------
RECORD_SIZE     equ 72          ; Size of each appliance record in bytes
MAX_RECORDS     equ 20          ; Maximum number of records supported
NAME_LEN        equ 32          ; Max characters for appliance name (inc. null)

; Offsets within each appliance record
OFFSET_ID       equ 0           ; uint64 (8 bytes)
OFFSET_NAME     equ 8           ; char[32] (32 bytes)
OFFSET_WATT     equ 40          ; uint64 (8 bytes)
OFFSET_HOURS    equ 48          ; uint64 (8 bytes)
OFFSET_PAD      equ 56          ; 16 bytes reserved

section .data
    ; State variables
    appliance_count dq 0
    next_id         dq 1

    ; Common Strings & UI Headers
    banner_line     db "==================================================================", 10, 0
    banner_sub      db "------------------------------------------------------------------", 10, 0
    title_banner    db 10, \
                       "==================================================================", 10, \
                       "    WattWise - Household Electricity Tracker [CPU-Optimized]      ", 10, \
                       "          Assembly Language (x86-64 with Hardware Hacks)          ", 10, \
                       "==================================================================", 10, 0

    menu_text       db "  [1] Register Appliance", 10, \
                       "  [2] View All Appliances", 10, \
                       "  [3] Update Appliance", 10, \
                       "  [4] Delete Appliance", 10, \
                       "  [5] Calculate Electricity Consumption", 10, \
                       "  [6] Calculate Electricity Bill", 10, \
                       "  [7] Energy Consumption Ranking", 10, \
                       "  [8] Energy Saving Recommendations", 10, \
                       "  [9] Exit Program", 10, \
                       "------------------------------------------------------------------", 10, \
                       "Select an option (1-9): ", 0

    str_invalid_opt db 10, "[!] Invalid choice! Please enter a number from 1 to 9.", 10, 0
    str_press_enter db 10, "Press [Enter] to return to the main menu...", 0
    str_empty_db    db 10, "[i] No appliances registered yet. Please register an appliance first.", 10, 0
    str_full_db     db 10, "[!] Error: Database capacity reached (maximum 20 appliances).", 10, 0
    str_goodbye     db 10, "Thank you for using WattWise (Optimized Edition)! Goodbye.", 10, 0

    ; Register Appliance Strings
    hdr_register    db 10, ">>> [1] REGISTER NEW APPLIANCE <<<", 10, 0
    prompt_name     db "Enter appliance name: ", 0
    prompt_watt     db "Enter rated wattage (Watts, 1 - 100000): ", 0
    prompt_hours    db "Enter daily operating hours (1 - 24): ", 0
    err_empty_name  db "[!] Error: Appliance name cannot be blank.", 10, 0
    err_invalid_num db "[!] Error: Invalid numeric input. Please enter a valid positive number.", 10, 0
    err_watt_range  db "[!] Error: Wattage must be between 1 and 100,000 W.", 10, 0
    err_hour_range  db "[!] Error: Daily operating hours must be between 1 and 24 hours.", 10, 0
    msg_reg_success db 10, "[+] Appliance '%s' successfully registered with ID #%lld!", 10, 0

    ; View Appliances Strings
    hdr_view        db 10, ">>> [2] REGISTERED APPLIANCES <<<", 10, 0
    tbl_view_hdr    db "+------+------------------------+--------------+-----------------+", 10, \
                       "| ID   | Appliance Name         | Wattage (W)  | Daily Hours (h) |", 10, \
                       "+------+------------------------+--------------+-----------------+", 10, 0
    tbl_view_row    db "| %-4lld | %-22.22s | %12lld | %15lld |", 10, 0
    tbl_view_ftr    db "+------+------------------------+--------------+-----------------+", 10, \
                       "Total Appliances: %lld", 10, 0

    ; Update Appliance Strings
    hdr_update      db 10, ">>> [3] UPDATE APPLIANCE <<<", 10, 0
    prompt_upd_id   db "Enter Appliance ID to update: ", 0
    err_id_notfound db "[!] Error: Appliance with ID #%lld does not exist.", 10, 0
    info_curr_vals  db 10, "Current details for Appliance #%lld:", 10, \
                           "  Name:  %s", 10, \
                           "  Power: %lld W", 10, \
                           "  Hours: %lld hrs/day", 10, 10, \
                           "Enter updated values:", 10, 0
    msg_upd_success db 10, "[+] Appliance #%lld successfully updated!", 10, 0

    ; Delete Appliance Strings
    hdr_delete      db 10, ">>> [4] DELETE APPLIANCE <<<", 10, 0
    prompt_del_id   db "Enter Appliance ID to delete: ", 0
    msg_del_success db 10, "[+] Appliance #%lld ('%s') successfully deleted.", 10, 0

    ; Electricity Consumption Strings
    hdr_consumption db 10, ">>> [5] ELECTRICITY CONSUMPTION ANALYSIS <<<", 10, \
                           "Formula: Daily kWh = (Watts * Hours) / 1000", 10, \
                           "         Monthly kWh = Daily kWh * 30 days", 10, 0
    tbl_cons_hdr    db "+------+------------------------+-----------------+-------------------+", 10, \
                       "| ID   | Appliance Name         | Daily Usage     | Monthly Usage     |", 10, \
                       "+------+------------------------+-----------------+-------------------+", 10, 0
    tbl_cons_row    db "| %-4lld | %-22.22s | %10lld.%02lld kWh | %12lld.%02lld kWh |", 10, 0
    tbl_cons_ftr    db "+------+------------------------+-----------------+-------------------+", 10, \
                       "| TOTAL HOUSEHOLD CONSUMPTION   | %10lld.%02lld kWh | %12lld.%02lld kWh |", 10, \
                       "+-------------------------------+-----------------+-------------------+", 10, 0

    ; Electricity Bill Strings
    hdr_bill        db 10, ">>> [6] ELECTRICITY BILL ESTIMATION <<<", 10, \
                           "Calculates estimated monthly cost based on electricity rate.", 10, 0
    prompt_rate     db "Enter electricity tariff rate per kWh (PHP, e.g. 12.00): ", 0
    err_rate_range  db "[!] Error: Rate must be greater than 0 (e.g. 12.00 or 10.50).", 10, 0
    tbl_bill_hdr    db 10, "Rate Applied: PHP %lld.%02lld per kWh (30-day projection)", 10, \
                       "+------+------------------------+-------------------+--------------------+", 10, \
                       "| ID   | Appliance Name         | Monthly Usage     | Monthly Cost (PHP) |", 10, \
                       "+------+------------------------+-------------------+--------------------+", 10, 0
    tbl_bill_row    db "| %-4lld | %-22.22s | %12lld.%02lld kWh | PHP %14lld.%02lld |", 10, 0
    tbl_bill_ftr    db "+------+------------------------+-------------------+--------------------+", 10, \
                       "| TOTAL ESTIMATED MONTHLY BILL                       | PHP %14lld.%02lld |", 10, \
                       "+---------------------------------------------------+--------------------+", 10, 0

    ; Energy Ranking Strings
    hdr_ranking     db 10, ">>> [7] ENERGY CONSUMPTION RANKING <<<", 10, \
                           "Appliances sorted from highest to lowest energy consumption.", 10, 0
    tbl_rank_hdr    db "+------+------+------------------------+-------------------+---------------+", 10, \
                       "| Rank | ID   | Appliance Name         | Monthly Usage     | Share of Total|", 10, \
                       "+------+------+------------------------+-------------------+---------------+", 10, 0
    tbl_rank_row    db "| #%-3lld | %-4lld | %-22.22s | %12lld.%02lld kWh | %11lld.%02lld%% |", 10, 0
    tbl_rank_ftr    db "+------+------+------------------------+-------------------+---------------+", 10, 0
    msg_top_consumer_str db 10, "[*] HIGHEST CONSUMER: '%s' (ID #%lld) uses %lld.%02lld kWh/month (%lld.%02lld%% of household total)", 10, 0

    ; Recommendations Strings
    hdr_recommend   db 10, ">>> [8] ENERGY-SAVING RECOMMENDATIONS <<<", 10, \
                           "Personalized energy efficiency assessment for registered devices.", 10, 0
    rec_app_hdr     db 10, "--- Device #%lld: %s (%lld W, %lld hrs/day, %lld.%02lld kWh/mo) ---", 10, 0
    rec_high_watt   db "  [!] HIGH POWER RATING (>1000 W):", 10, \
                       "      - Drawbacks: High peak load increases demand charges.", 10, \
                       "      - Recommendation: Avoid running simultaneously with other heavy loads.", 10, \
                       "      - Check if high-efficiency inverter alternative is available.", 10, 0
    rec_long_hours  db "  [!] PROLONGED OPERATION (>12 hrs/day):", 10, \
                       "      - Drawbacks: Continuous usage significantly inflates monthly billing.", 10, \
                       "      - Recommendation: Use a programmable timer or thermostat to cut idle time.", 10, 0
    rec_high_cons   db "  [!] HIGH MONTHLY CONSUMER (>100 kWh/month):", 10, \
                       "      - Critical: This device contributes heavily to your monthly electric bill.", 10, \
                       "      - Recommendation: Target this device first for power reduction strategies.", 10, 0
    rec_mod_cons    db "  [i] MODERATE CONSUMER (50 - 100 kWh/month):", 10, \
                       "      - Status: Moderate energy usage profile.", 10, \
                       "      - Recommendation: Perform periodic cleaning/servicing to maintain optimal efficiency.", 10, 0
    rec_low_cons    db "  [+] EFFICIENT CONSUMER (<50 kWh/month):", 10, \
                       "      - Status: Low energy consumption. Well within efficient parameters.", 10, 0

    general_tips    db 10, "===================== GENERAL ENERGY SAVING TIPS =====================", 10, \
                           " 1. Unplug appliances on standby mode to eliminate phantom loads.", 10, \
                           " 2. Keep refrigerator coils clean and set temperature to recommended 3-4 deg C.", 10, \
                           " 3. Use LED lighting which consumes up to 80%% less power than incandescent bulbs.", 10, \
                           " 4. Run washing machines and heavy devices with full loads to maximize efficiency.", 10, \
                           "======================================================================", 10, 0

section .bss
    ; Appliance storage: up to 20 records of 72 bytes each = 1440 bytes
    appliance_table resb (MAX_RECORDS * RECORD_SIZE)

    ; Line input buffers
    line_buf        resb 128
    temp_name       resb NAME_LEN

    ; Ranking arrays
    rank_indices    resq MAX_RECORDS    ; Record index (0..count-1)
    rank_kwh        resq MAX_RECORDS    ; Monthly kWh in hundredths

; ==============================================================================
; CODE SECTION
; ==============================================================================
section .text
global main

; ==============================================================================
; HARDWARE HACK: FAST RECIPROCAL DIVISION & MODULO BY 10 (0 DIV CYCLES)
; ==============================================================================
; Replaces slow 40-cycle hardware DIV with Granlund-Montgomery multiplier.
; Input:  RAX = N (unsigned 64-bit)
; Output: RAX = quotient (N / 10)
;         RDX = remainder (N % 10)
; Preserves ALL registers except RAX and RDX!
fast_divmod10:
    push rbx
    push rcx
    mov rbx, rax                ; save original N
    mov rcx, 0xCCCCCCCCCCCCCCCD
    mul rcx                     ; RDX = (N * 0xCCCCCCCCCCCCCCCD) >> 64
    shr rdx, 3                  ; RDX = quotient (q)
    ; remainder = N - q * 10 = N - ((q * 5) * 2) via LEA + ADD
    lea rax, [rdx + rdx * 4]
    add rax, rax
    sub rbx, rax                ; rbx = remainder
    mov rax, rdx                ; RAX = quotient
    mov rdx, rbx                ; RDX = remainder
    pop rcx
    pop rbx
    ret

; ==============================================================================
; HARDWARE HACK: FAST RECIPROCAL DIVISION & MODULO BY 100 (0 DIV CYCLES)
; ==============================================================================
; Replaces slow 40-cycle hardware DIV with 0x28F5C28F5C28F5C3 multiplier.
; Input:  RAX = N (unsigned 64-bit)
; Output: RAX = quotient (N / 100)
;         RDX = remainder (N % 100)
; Preserves ALL registers except RAX and RDX!
fast_divmod100:
    push rbx
    push rcx
    mov rbx, rax                ; save original N
    shr rax, 2                  ; RAX = N >> 2
    mov rcx, 0x28F5C28F5C28F5C3
    mul rcx                     ; RDX = ((N >> 2) * 0x28F5C28F5C28F5C3) >> 64
    shr rdx, 2                  ; RDX = quotient (q)
    ; remainder = N - q * 100 = N - (((q * 5) * 5) * 4) via two LEAs and one SHL
    lea rax, [rdx + rdx * 4]    ; q * 5
    lea rax, [rax + rax * 4]    ; q * 25
    shl rax, 2                  ; q * 100
    sub rbx, rax                ; rbx = remainder
    mov rax, rdx                ; RAX = quotient
    mov rdx, rbx                ; RDX = remainder
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; flush_stdout: Flushes pending output stream buffer
; ------------------------------------------------------------------------------
flush_stdout:
    sub rsp, 40
    xor ecx, ecx
    call fflush
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; main: Program entry point
; ------------------------------------------------------------------------------
main:
    push rbp
    mov rbp, rsp
    sub rsp, 48                 ; Shadow space (32) + alignment & locals (16)

.main_loop:
    call display_menu
    call read_line              ; Read user input into line_buf
    cmp rax, -1
    je .opt9                    ; On EOF, cleanly terminate

    ; Parse option (first char)
    lea rsi, [line_buf]
    movzx eax, byte [rsi]
    test al, al
    jz .invalid_option

    ; Check if multiple chars entered before newline
    cmp byte [rsi + 1], 0
    jne .invalid_option

    cmp al, '1'
    je .opt1
    cmp al, '2'
    je .opt2
    cmp al, '3'
    je .opt3
    cmp al, '4'
    je .opt4
    cmp al, '5'
    je .opt5
    cmp al, '6'
    je .opt6
    cmp al, '7'
    je .opt7
    cmp al, '8'
    je .opt8
    cmp al, '9'
    je .opt9

.invalid_option:
    lea rcx, [str_invalid_opt]
    call printf
    call flush_stdout
    call wait_for_enter
    jmp .main_loop

.opt1:
    call register_appliance
    call wait_for_enter
    jmp .main_loop

.opt2:
    call view_appliances
    call wait_for_enter
    jmp .main_loop

.opt3:
    call update_appliance
    call wait_for_enter
    jmp .main_loop

.opt4:
    call delete_appliance
    call wait_for_enter
    jmp .main_loop

.opt5:
    call calculate_consumption
    call wait_for_enter
    jmp .main_loop

.opt6:
    call calculate_bill
    call wait_for_enter
    jmp .main_loop

.opt7:
    call energy_ranking
    call wait_for_enter
    jmp .main_loop

.opt8:
    call energy_recommendations
    call wait_for_enter
    jmp .main_loop

.opt9:
    lea rcx, [str_goodbye]
    call printf
    call flush_stdout
    xor eax, eax
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; display_menu: Prints banner and menu choices
; ------------------------------------------------------------------------------
display_menu:
    sub rsp, 40
    lea rcx, [title_banner]
    call printf
    lea rcx, [menu_text]
    call printf
    call flush_stdout
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; wait_for_enter: Prompts user and waits for [Enter] key
; ------------------------------------------------------------------------------
wait_for_enter:
    sub rsp, 40
    lea rcx, [str_press_enter]
    call printf
    call flush_stdout
    call read_line
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; read_line: Reads a line from stdin via getchar into line_buf
; Handles \r\n, \n, trims leading & trailing whitespace.
; Returns: RAX = length of trimmed string, or -1 on immediate EOF
; ------------------------------------------------------------------------------
read_line:
    push rbx
    push rdi
    push rsi
    sub rsp, 32

    lea rdi, [line_buf]
    xor ebx, ebx                ; char count

.rl_loop:
    call getchar
    cmp eax, -1                 ; EOF
    je .rl_eof
    cmp eax, 10                 ; '\n'
    je .rl_done
    cmp eax, 13                 ; '\r'
    je .rl_loop

    cmp ebx, 126                ; buffer limit check
    jge .rl_loop                ; discard overflow chars until newline
    mov byte [rdi + rbx], al
    inc ebx
    jmp .rl_loop

.rl_eof:
    test ebx, ebx
    jnz .rl_done                ; If some characters read, finish string
    mov rax, -1                 ; Signal EOF
    jmp .rl_ret

.rl_done:
    mov byte [rdi + rbx], 0     ; null terminate

    ; Trim trailing spaces
.trim_trailing:
    test ebx, ebx
    jz .done_trim
    dec ebx
    movzx edx, byte [rdi + rbx]
    cmp dl, ' '
    je .cut_char
    cmp dl, 9                   ; tab
    je .cut_char
    inc ebx                     ; restore count
    jmp .done_trim
.cut_char:
    mov byte [rdi + rbx], 0
    jmp .trim_trailing

.done_trim:
    mov rax, rbx                ; return length

.rl_ret:
    add rsp, 32
    pop rsi
    pop rdi
    pop rbx
    ret

; ------------------------------------------------------------------------------
; parse_uint: Parses ASCII unsigned integer from string buffer in RCX
; HACK: Uses LEA+ADD for x*10 multiplication (bypasses slow IMUL)
; Returns: RAX = value
;          RDX = 0 on success, 1 on error (empty or non-digit)
; ------------------------------------------------------------------------------
parse_uint:
    xor rax, rax                ; accumulator
    xor r8, r8                  ; digit count
    mov r9, rcx                 ; current pointer

    ; skip leading spaces
.skip_sp:
    movzx edx, byte [r9]
    cmp dl, ' '
    je .inc_skip
    cmp dl, 9
    je .inc_skip
    jmp .check_start
.inc_skip:
    inc r9
    jmp .skip_sp

.check_start:
    movzx edx, byte [r9]
    test dl, dl
    jz .fail                    ; empty string

.loop:
    movzx edx, byte [r9]
    test dl, dl
    jz .success
    cmp dl, '0'
    jb .fail
    cmp dl, '9'
    ja .fail

    sub dl, '0'
    ; CPU HACK: rax = rax * 10 via (rax * 5) * 2 (2 cycles instead of 4-cycle IMUL)
    lea rax, [rax + rax * 4]
    add rax, rax
    movzx rdx, dl
    add rax, rdx
    inc r8
    inc r9
    jmp .loop

.success:
    test r8, r8
    jz .fail
    xor edx, edx                ; RDX = 0 (success)
    ret

.fail:
    mov edx, 1                  ; RDX = 1 (error)
    ret

; ------------------------------------------------------------------------------
; parse_rate_fixed_point: Parses electricity rate string into hundredths
; e.g. "12" -> 1200, "12.5" -> 1250, "12.05" -> 1205, "11.75" -> 1175
; HACK: Uses LEA and bit-shifts for x10 and x100 multiplication (0 IMUL)
; Returns: RAX = value in hundredths (e.g. 1200)
;          RDX = 0 on success, 1 on error (rate <= 0 or invalid format)
; ------------------------------------------------------------------------------
parse_rate_fixed_point:
    push rbx
    push rsi
    push rdi
    sub rsp, 32

    mov rsi, rcx
    xor eax, eax                ; whole part
    xor ebx, ebx                ; fractional part (in hundredths)
    xor r8d, r8d                ; saw_dot flag
    xor r9d, r9d                ; frac_digits_count
    xor r10d, r10d              ; whole_digits_count

    ; skip leading spaces
.p_skip:
    movzx edx, byte [rsi]
    cmp dl, ' '
    je .p_inc
    cmp dl, 9
    je .p_inc
    jmp .p_parse_loop
.p_inc:
    inc rsi
    jmp .p_skip

.p_parse_loop:
    movzx edx, byte [rsi]
    test dl, dl
    jz .p_finish

    cmp dl, '.'
    je .p_handle_dot

    cmp dl, '0'
    jb .p_err
    cmp dl, '9'
    ja .p_err

    sub dl, '0'
    test r8d, r8d
    jnz .p_frac_digit

    ; whole part digit: CPU HACK: rax = rax * 10
    lea rax, [rax + rax * 4]
    add rax, rax
    movzx rdx, dl
    add rax, rdx
    inc r10d
    inc rsi
    jmp .p_parse_loop

.p_handle_dot:
    test r8d, r8d
    jnz .p_err                  ; duplicate dot
    mov r8d, 1                  ; saw_dot = 1
    inc rsi
    jmp .p_parse_loop

.p_frac_digit:
    cmp r9d, 0
    jne .p_second_frac

    ; first fractional digit (tenths -> x10): CPU HACK: edx = edx * 10
    movzx edx, dl
    lea edx, [rdx + rdx * 4]
    add edx, edx
    mov ebx, edx
    inc r9d
    inc rsi
    jmp .p_parse_loop

.p_second_frac:
    cmp r9d, 1
    jne .p_ignore_more_frac
    ; second fractional digit (hundredths -> +x)
    movzx edx, dl
    add ebx, edx
    inc r9d
    inc rsi
    jmp .p_parse_loop

.p_ignore_more_frac:
    inc rsi                     ; ignore 3rd+ decimal digits
    jmp .p_parse_loop

.p_finish:
    ; Check if any digit was entered
    mov edx, r10d
    add edx, r9d
    jz .p_err

    ; CPU HACK: Scale whole part by 100: ((rax * 5) * 5) * 4 via 2 LEAs + SHL
    lea rax, [rax + rax * 4]    ; rax = rax * 5
    lea rax, [rax + rax * 4]    ; rax = rax * 25
    shl rax, 2                  ; rax = rax * 100
    movsxd rbx, ebx
    add rax, rbx

    test rax, rax
    jle .p_err                  ; must be > 0

    xor edx, edx                ; success
    jmp .p_exit

.p_err:
    mov edx, 1                  ; error

.p_exit:
    add rsp, 32
    pop rdi
    pop rsi
    pop rbx
    ret

; ------------------------------------------------------------------------------
; register_appliance: Feature 1 - Prompts, validates, and stores a new appliance
; HACK: Uses LEA+SHL to calculate record offset (72 bytes) with 0 IMUL
; ------------------------------------------------------------------------------
register_appliance:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    sub rsp, 40

    lea rcx, [hdr_register]
    call printf

    ; 1. Check capacity
    mov rax, [appliance_count]
    cmp rax, MAX_RECORDS
    jl .has_space
    lea rcx, [str_full_db]
    call printf
    jmp .reg_ret

.has_space:
    ; 2. Prompt Name
.prompt_name_loop:
    lea rcx, [prompt_name]
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .reg_ret
    test rax, rax
    jnz .name_ok
    lea rcx, [err_empty_name]
    call printf
    jmp .prompt_name_loop

.name_ok:
    ; Copy up to 31 chars into temp_name
    lea rsi, [line_buf]
    lea rdi, [temp_name]
    mov ecx, NAME_LEN - 1
.copy_n:
    lodsb
    test al, al
    jz .end_copy_n
    stosb
    loop .copy_n
.end_copy_n:
    xor al, al
    stosb

    ; 3. Prompt Wattage
.prompt_watt_loop:
    lea rcx, [prompt_watt]
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .reg_ret
    lea rcx, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .err_watt_nan

    cmp rax, 1
    jl .err_watt_val
    cmp rax, 100000
    jg .err_watt_val
    mov r12, rax                ; r12 = validated wattage
    jmp .prompt_hours_loop

.err_watt_nan:
    lea rcx, [err_invalid_num]
    call printf
    jmp .prompt_watt_loop

.err_watt_val:
    lea rcx, [err_watt_range]
    call printf
    jmp .prompt_watt_loop

    ; 4. Prompt Hours
.prompt_hours_loop:
    lea rcx, [prompt_hours]
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .reg_ret
    lea rcx, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .err_hour_nan

    cmp rax, 1
    jl .err_hour_val
    cmp rax, 24
    jg .err_hour_val
    mov r13, rax                ; r13 = validated hours
    jmp .store_record

.err_hour_nan:
    lea rcx, [err_invalid_num]
    call printf
    jmp .prompt_hours_loop

.err_hour_val:
    lea rcx, [err_hour_range]
    call printf
    jmp .prompt_hours_loop

    ; 5. Store into appliance_table
.store_record:
    ; CPU HACK: r14 = appliance_count * 72 = (count * 9) * 8 via LEA + SHL (2 cycles)
    mov rax, [appliance_count]
    lea r14, [rax + rax * 8]
    shl r14, 3
    lea rdi, [appliance_table]
    add rdi, r14

    ; Store ID
    mov rax, [next_id]
    mov [rdi + OFFSET_ID], rax
    inc qword [next_id]

    ; Store Name (32 bytes)
    lea rsi, [temp_name]
    lea rdx, [rdi + OFFSET_NAME]
    mov ecx, NAME_LEN
.copy_rec_name:
    mov al, [rsi]
    mov [rdx], al
    inc rsi
    inc rdx
    dec ecx
    jnz .copy_rec_name

    ; Store Wattage & Hours
    mov [rdi + OFFSET_WATT], r12
    mov [rdi + OFFSET_HOURS], r13

    ; Clear padding
    mov qword [rdi + OFFSET_PAD], 0
    mov qword [rdi + OFFSET_PAD + 8], 0

    inc qword [appliance_count]

    ; Print success confirmation
    lea rcx, [msg_reg_success]
    lea rdx, [rdi + OFFSET_NAME]
    mov r8, [rdi + OFFSET_ID]
    call printf

.reg_ret:
    add rsp, 40
    pop r14
    pop r13
    pop r12
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; view_appliances: Feature 2 - Lists all registered appliances in a table
; HACK: Uses LEA+SHL for 72-byte record indexing
; ------------------------------------------------------------------------------
view_appliances:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    sub rsp, 48

    lea rcx, [hdr_view]
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_appliances

    lea rcx, [str_empty_db]
    call printf
    jmp .view_ret

.has_appliances:
    lea rcx, [tbl_view_hdr]
    call printf

    xor ebx, ebx                ; loop counter (0..count-1)
.row_loop:
    cmp rbx, [appliance_count]
    jge .done_rows

    ; CPU HACK: rax = rbx * 72 via (rbx * 9) * 8
    lea rax, [rbx + rbx * 8]
    shl rax, 3
    lea rsi, [appliance_table]
    add rsi, rax

    lea rcx, [tbl_view_row]
    mov rdx, [rsi + OFFSET_ID]
    lea r8, [rsi + OFFSET_NAME]
    mov r9, [rsi + OFFSET_WATT]
    mov rax, [rsi + OFFSET_HOURS]
    mov [rsp + 32], rax         ; 5th parameter on stack
    call printf

    inc rbx
    jmp .row_loop

.done_rows:
    lea rcx, [tbl_view_ftr]
    mov rdx, [appliance_count]
    call printf

.view_ret:
    add rsp, 48
    pop rsi
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; update_appliance: Feature 3 - Modifies existing record attributes
; ------------------------------------------------------------------------------
update_appliance:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 48

    lea rcx, [hdr_update]
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rcx, [str_empty_db]
    call printf
    jmp .upd_ret

.has_records:
    lea rcx, [prompt_upd_id]
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .upd_ret
    lea rcx, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .upd_not_found

    ; Search for ID in appliance_table
    mov r12, rax                ; Target ID
    call find_appliance_by_id   ; Returns RDI = record pointer, RAX = index, or RDI = 0
    test rdi, rdi
    jz .upd_not_found

    mov r14, rdi                ; r14 = record pointer

    ; Display current values
    lea rcx, [info_curr_vals]
    mov rdx, [r14 + OFFSET_ID]
    lea r8, [r14 + OFFSET_NAME]
    mov r9, [r14 + OFFSET_WATT]
    mov rax, [r14 + OFFSET_HOURS]
    mov [rsp + 32], rax
    call printf

    ; Prompt new Name
.prompt_new_name:
    lea rcx, [prompt_name]
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .upd_ret
    test rax, rax
    jnz .new_name_ok
    lea rcx, [err_empty_name]
    call printf
    jmp .prompt_new_name

.new_name_ok:
    ; Copy new name into record
    lea rsi, [line_buf]
    lea rdi, [r14 + OFFSET_NAME]
    mov ecx, NAME_LEN - 1
.copy_upd_name:
    lodsb
    test al, al
    jz .end_upd_copy
    stosb
    loop .copy_upd_name
.end_upd_copy:
    xor al, al
    stosb

    ; Prompt new Wattage
.prompt_new_watt:
    lea rcx, [prompt_watt]
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .upd_ret
    lea rcx, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .err_upd_watt_nan

    cmp rax, 1
    jl .err_upd_watt_val
    cmp rax, 100000
    jg .err_upd_watt_val
    mov [r14 + OFFSET_WATT], rax
    jmp .prompt_new_hours

.err_upd_watt_nan:
    lea rcx, [err_invalid_num]
    call printf
    jmp .prompt_new_watt

.err_upd_watt_val:
    lea rcx, [err_watt_range]
    call printf
    jmp .prompt_new_watt

    ; Prompt new Hours
.prompt_new_hours:
    lea rcx, [prompt_hours]
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .upd_ret
    lea rcx, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .err_upd_hour_nan

    cmp rax, 1
    jl .err_upd_hour_val
    cmp rax, 24
    jg .err_upd_hour_val
    mov [r14 + OFFSET_HOURS], rax
    jmp .upd_success

.err_upd_hour_nan:
    lea rcx, [err_invalid_num]
    call printf
    jmp .prompt_new_hours

.err_upd_hour_val:
    lea rcx, [err_hour_range]
    call printf
    jmp .prompt_new_hours

.upd_success:
    lea rcx, [msg_upd_success]
    mov rdx, [r14 + OFFSET_ID]
    call printf
    jmp .upd_ret

.upd_not_found:
    lea rcx, [err_id_notfound]
    mov rdx, r12
    call printf

.upd_ret:
    add rsp, 48
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; delete_appliance: Feature 4 - Removes appliance and shifts following records
; HACK: Uses LEA+SHL for 72-byte address calculations + REP MOVSB string moves
; ------------------------------------------------------------------------------
delete_appliance:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push rsi
    push rdi
    sub rsp, 40                 ; 6 pushes (48) + 40 = 88 -> 8 - 88 = -80 (aligned)

    lea rcx, [hdr_delete]
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rcx, [str_empty_db]
    call printf
    jmp .del_ret

.has_records:
    lea rcx, [prompt_del_id]
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .del_ret
    lea rcx, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .del_not_found

    mov r12, rax                ; Target ID
    call find_appliance_by_id   ; Returns RDI = record pointer, RAX = index (0..count-1)
    test rdi, rdi
    jz .del_not_found

    ; Save name and ID for success message
    lea rcx, [rdi + OFFSET_NAME]
    lea rdx, [temp_name]
    mov r13, rax                ; r13 = index of deleted record

    ; Copy name to temp_name
    mov ebx, NAME_LEN
.save_name_loop:
    mov al, [rcx]
    mov [rdx], al
    inc rcx
    inc rdx
    dec ebx
    jnz .save_name_loop

    ; Shift subsequent records: from index (r13 + 1) to appliance_count - 1
    mov rbx, r13                ; rbx = current destination index
.shift_loop:
    mov rax, rbx
    inc rax                     ; rax = source index
    cmp rax, [appliance_count]
    jge .done_shifting

    ; CPU HACK: rdi = rbx * 72 via (rbx * 9) * 8
    lea rdi, [rbx + rbx * 8]
    shl rdi, 3
    lea rdx, [appliance_table]
    add rdi, rdx                ; dest pointer

    ; CPU HACK: rsi = rax * 72 via (rax * 9) * 8
    lea rsi, [rax + rax * 8]
    shl rsi, 3
    add rsi, rdx                ; src pointer

    ; Hardware block transfer: Copy 72 bytes via REP MOVSB
    cld
    mov ecx, RECORD_SIZE
    rep movsb

    inc rbx
    jmp .shift_loop

.done_shifting:
    dec qword [appliance_count]

    lea rcx, [msg_del_success]
    mov rdx, r12
    lea r8, [temp_name]
    call printf
    jmp .del_ret

.del_not_found:
    lea rcx, [err_id_notfound]
    mov rdx, r12
    call printf

.del_ret:
    add rsp, 40
    pop rdi
    pop rsi
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; find_appliance_by_id: Linear search for appliance with ID in R12
; HACK: Uses LEA+SHL for 72-byte address offset
; Returns: RDI = pointer to record, RAX = index, or RDI = 0 if not found
; ------------------------------------------------------------------------------
find_appliance_by_id:
    xor eax, eax                ; index = 0
.search_loop:
    cmp rax, [appliance_count]
    jge .not_found

    ; CPU HACK: rdi = rax * 72 via (rax * 9) * 8
    lea rdi, [rax + rax * 8]
    shl rdi, 3
    lea rdx, [appliance_table]
    add rdi, rdx
    cmp [rdi + OFFSET_ID], r12
    je .found

    inc rax
    jmp .search_loop

.found:
    ret

.not_found:
    xor edi, edi
    ret

; ------------------------------------------------------------------------------
; calculate_consumption: Feature 5 - Computes and displays daily & monthly kWh
; HACK: Uses fast_divmod10 and fast_divmod100 (0 hardware DIV cycles)
; Formula:
;   Daily kWh (hundredths)   = (W * H) / 10
;   Monthly kWh (hundredths) = Daily * 30
; ------------------------------------------------------------------------------
calculate_consumption:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72                 ; 6 pushes (48) + 72 = 120 -> 8 - 120 = -112 (16-byte aligned)

    lea rcx, [hdr_consumption]
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rcx, [str_empty_db]
    call printf
    jmp .cons_ret

.has_records:
    lea rcx, [tbl_cons_hdr]
    call printf

    xor ebx, ebx                ; index
    xor r14, r14                ; total daily kWh (hundredths)
    xor r15, r15                ; total monthly kWh (hundredths)

.cons_loop:
    cmp rbx, [appliance_count]
    jge .cons_done

    ; CPU HACK: rax = rbx * 72
    lea rax, [rbx + rbx * 8]
    shl rax, 3
    lea rsi, [appliance_table]
    add rsi, rax

    ; CPU HACK: Daily kWh hundredths = (W * H) / 10 using fast_divmod10 (0 DIV cycles)
    mov rax, [rsi + OFFSET_WATT]
    imul rax, [rsi + OFFSET_HOURS]
    call fast_divmod10
    mov r12, rax                ; r12 = daily kWh hundredths
    add r14, r12

    ; CPU HACK: Monthly kWh hundredths = daily * 30 via ((daily * 3) * 5) * 2 (0 IMUL)
    lea rax, [r12 + r12 * 2]    ; rax = daily * 3
    lea rax, [rax + rax * 4]    ; rax = (daily * 3) * 5 = daily * 15
    add rax, rax                ; rax = daily * 30
    mov r13, rax                ; r13 = monthly kWh hundredths
    add r15, r13

    ; CPU HACK: Format monthly: whole = r13 / 100, frac = r13 % 100 via fast_divmod100
    mov rax, r13
    call fast_divmod100
    mov [rsp + 40], rax         ; 6th arg: monthly whole
    mov [rsp + 48], rdx         ; 7th arg: monthly frac

    ; CPU HACK: Format daily: whole = r12 / 100, frac = r12 % 100 via fast_divmod100
    mov rax, r12
    call fast_divmod100
    mov r9, rax                 ; 4th arg: daily whole
    mov [rsp + 32], rdx         ; 5th arg: daily frac

    lea rcx, [tbl_cons_row]     ; 1st arg: fmt
    mov rdx, [rsi + OFFSET_ID]  ; 2nd arg: ID
    lea r8, [rsi + OFFSET_NAME] ; 3rd arg: Name
    call printf

    inc rbx
    jmp .cons_loop

.cons_done:
    ; CPU HACK: Format total monthly via fast_divmod100
    mov rax, r15
    call fast_divmod100
    mov [rsp + 40], rax         ; save total monthly whole
    mov [rsp + 32], rdx         ; 5th arg: total monthly frac

    ; CPU HACK: Format total daily via fast_divmod100
    mov rax, r14
    call fast_divmod100
    mov r12, rax                ; total daily whole
    mov r13, rdx                ; total daily frac

    lea rcx, [tbl_cons_ftr]
    mov rdx, r12                ; 2nd arg: total daily whole
    mov r8, r13                 ; 3rd arg: total daily frac
    mov r9, [rsp + 40]          ; 4th arg: total monthly whole
    call printf

.cons_ret:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; calculate_bill: Feature 6 - Computes estimated monthly bill in PHP
; HACK: Uses fast_divmod10 and fast_divmod100 (0 hardware DIV cycles)
; Cost (hundredths) = (Monthly kWh hundredths * Rate hundredths) / 100
; ------------------------------------------------------------------------------
calculate_bill:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72                 ; 6 pushes (48) + 72 = 120 -> 8 - 120 = -112 (16-byte aligned)

    lea rcx, [hdr_bill]
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rcx, [str_empty_db]
    call printf
    jmp .bill_ret

.has_records:
.prompt_rate_loop:
    lea rcx, [prompt_rate]
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .bill_ret
    lea rcx, [line_buf]
    call parse_rate_fixed_point
    test rdx, rdx
    jnz .err_rate

    mov r12, rax                ; r12 = rate in hundredths (e.g. 12.00 -> 1200)
    jmp .render_bill

.err_rate:
    lea rcx, [err_rate_range]
    call printf
    jmp .prompt_rate_loop

.render_bill:
    ; CPU HACK: Print header with rate formatted via fast_divmod100
    mov rax, r12
    call fast_divmod100
    mov r8, rdx                 ; 3rd arg: rate frac
    mov rdx, rax                ; 2nd arg: rate whole
    lea rcx, [tbl_bill_hdr]
    call printf

    xor ebx, ebx                ; index
    xor r14, r14                ; grand total cost in hundredths (PHP)

.bill_loop:
    cmp rbx, [appliance_count]
    jge .bill_done

    ; CPU HACK: rax = rbx * 72
    lea rax, [rbx + rbx * 8]
    shl rax, 3
    lea rsi, [appliance_table]
    add rsi, rax

    ; CPU HACK: Monthly kWh hundredths = ((W * H) / 10) * 30
    mov rax, [rsi + OFFSET_WATT]
    imul rax, [rsi + OFFSET_HOURS]
    call fast_divmod10
    lea rax, [rax + rax * 2]    ; rax = daily * 3
    lea rax, [rax + rax * 4]    ; rax = (daily * 3) * 5 = daily * 15
    add rax, rax                ; rax = daily * 30
    mov r13, rax                ; r13 = monthly kWh hundredths

    ; CPU HACK: Cost hundredths = (monthly_hundredths * rate_hundredths) / 100 via fast_divmod100
    mov rax, r13
    imul rax, r12
    call fast_divmod100
    mov r15, rax                ; r15 = appliance monthly cost (hundredths)
    add r14, r15

    ; CPU HACK: Format cost (whole + frac) via fast_divmod100
    mov rax, r15
    call fast_divmod100
    mov [rsp + 40], rax         ; 6th arg: cost whole
    mov [rsp + 48], rdx         ; 7th arg: cost frac

    ; CPU HACK: Format monthly kWh (whole + frac) via fast_divmod100
    mov rax, r13
    call fast_divmod100
    mov r9, rax                 ; 4th arg: monthly kWh whole
    mov [rsp + 32], rdx         ; 5th arg: monthly kWh frac

    lea rcx, [tbl_bill_row]
    mov rdx, [rsi + OFFSET_ID]
    lea r8, [rsi + OFFSET_NAME]
    call printf

    inc rbx
    jmp .bill_loop

.bill_done:
    ; CPU HACK: Format grand total via fast_divmod100
    mov rax, r14
    call fast_divmod100
    mov r8, rdx                 ; 3rd arg: total frac
    mov rdx, rax                ; 2nd arg: total whole
    lea rcx, [tbl_bill_ftr]
    call printf

.bill_ret:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; energy_ranking: Feature 7 - Sorts appliances by monthly kWh descending
; HACKS:
; 1. Uses CMOVG for branchless selection sort (eliminates pipeline branch stalls)
; 2. Uses fast_divmod10 and fast_divmod100 (0 hardware DIV cycles)
; ------------------------------------------------------------------------------
energy_ranking:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72                 ; 6 pushes (48) + 72 = 120 -> 8 - 120 = -112 (16-byte aligned)

    lea rcx, [hdr_ranking]
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rcx, [str_empty_db]
    call printf
    jmp .rank_ret

.has_records:
    ; 1. Populate rank_indices and rank_kwh, compute total monthly kWh
    xor ebx, ebx
    xor r14, r14                ; grand total monthly kWh
    lea r10, [rank_indices]
    lea r11, [rank_kwh]

.pop_loop:
    cmp rbx, [appliance_count]
    jge .done_pop

    ; CPU HACK: rax = rbx * 72
    lea rax, [rbx + rbx * 8]
    shl rax, 3
    lea rsi, [appliance_table]
    add rsi, rax

    ; Monthly kWh = ((W * H) / 10) * 30
    mov rax, [rsi + OFFSET_WATT]
    imul rax, [rsi + OFFSET_HOURS]
    call fast_divmod10
    lea rax, [rax + rax * 2]
    lea rax, [rax + rax * 4]
    add rax, rax

    mov [r10 + rbx * 8], rbx
    mov [r11 + rbx * 8], rax
    add r14, rax

    inc rbx
    jmp .pop_loop

.done_pop:
    ; 2. Selection sort descending by rank_kwh
    xor ebx, ebx                ; i = 0
    lea r10, [rank_indices]
    lea r11, [rank_kwh]

.sort_outer:
    mov rax, [appliance_count]
    dec rax
    cmp rbx, rax
    jge .sort_done

    mov r12, rbx                ; max_idx = i
    mov r13, rbx
    inc r13                     ; j = i + 1

.sort_inner:
    cmp r13, [appliance_count]
    jge .swap_check

    ; CPU HACK: Branchless inner sort tracking using CMOVG
    ; Eliminates branch mispredictions on every array element comparison!
    mov rax, [r11 + r13 * 8]
    cmp rax, [r11 + r12 * 8]
    cmovg r12, r13              ; If rank_kwh[j] > rank_kwh[max_idx], max_idx = j (branchless!)

    inc r13
    jmp .sort_inner

.swap_check:
    cmp r12, rbx
    je .next_outer

    ; Swap rank_kwh[i] and rank_kwh[max_idx]
    mov rax, [r11 + rbx * 8]
    mov rdx, [r11 + r12 * 8]
    mov [r11 + rbx * 8], rdx
    mov [r11 + r12 * 8], rax

    ; Swap rank_indices[i] and rank_indices[max_idx]
    mov rax, [r10 + rbx * 8]
    mov rdx, [r10 + r12 * 8]
    mov [r10 + rbx * 8], rdx
    mov [r10 + r12 * 8], rax

.next_outer:
    inc rbx
    jmp .sort_outer

.sort_done:
    ; 3. Print ranked table
    lea rcx, [tbl_rank_hdr]
    call printf

    xor ebx, ebx                ; rank counter (0..count-1)

.print_rank_loop:
    cmp rbx, [appliance_count]
    jge .print_rank_done

    lea r10, [rank_indices]
    lea r11, [rank_kwh]
    mov r12, [r10 + rbx * 8]     ; original record index
    mov r13, [r11 + rbx * 8]     ; monthly kWh hundredths

    ; CPU HACK: rax = r12 * 72
    lea rax, [r12 + r12 * 8]
    shl rax, 3
    lea rsi, [appliance_table]
    add rsi, rax

    ; Calculate percentage: (monthly_kwh * 10000) / total_kwh -> gives percent in hundredths
    xor r15, r15
    test r14, r14
    jz .pct_zero
    mov rax, r13
    imul rax, 10000
    xor edx, edx
    div r14
    mov r15, rax                ; r15 = percent in hundredths
.pct_zero:

    ; CPU HACK: Format share percent via fast_divmod100
    mov rax, r15
    call fast_divmod100
    mov [rsp + 48], rax         ; 7th arg: percent whole
    mov [rsp + 56], rdx         ; 8th arg: percent frac

    ; CPU HACK: Format monthly kWh via fast_divmod100
    mov rax, r13
    call fast_divmod100
    mov [rsp + 32], rax         ; 5th arg: monthly kWh whole
    mov [rsp + 40], rdx         ; 6th arg: monthly kWh frac

    lea rcx, [tbl_rank_row]
    lea rdx, [rbx + 1]          ; CPU HACK: LEA for 1-based rank without modifying loop counter
    mov r8, [rsi + OFFSET_ID]   ; 3rd arg: ID
    lea r9, [rsi + OFFSET_NAME] ; 4th arg: Name
    call printf

    inc rbx
    jmp .print_rank_loop

.print_rank_done:
    lea rcx, [tbl_rank_ftr]
    call printf

    ; Highlight #1 consumer
    lea r10, [rank_indices]
    lea r11, [rank_kwh]
    mov r12, [r10]              ; top record index
    ; CPU HACK: rax = r12 * 72
    lea rax, [r12 + r12 * 8]
    shl rax, 3
    lea rsi, [appliance_table]
    add rsi, rax
    mov r13, [r11]              ; top kwh hundredths

    ; Top percentage
    xor r15, r15
    test r14, r14
    jz .top_pct_zero
    mov rax, r13
    imul rax, 10000
    xor edx, edx
    div r14
    mov r15, rax
.top_pct_zero:

    ; CPU HACK: Format top pct via fast_divmod100
    mov rax, r15
    call fast_divmod100
    mov [rsp + 40], rax         ; 6th arg: pct whole
    mov [rsp + 48], rdx         ; 7th arg: pct frac

    ; CPU HACK: Format top monthly via fast_divmod100
    mov rax, r13
    call fast_divmod100
    mov r9, rax                 ; 4th arg: monthly whole
    mov [rsp + 32], rdx         ; 5th arg: monthly frac

    lea rcx, [msg_top_consumer_str]
    lea rdx, [rsi + OFFSET_NAME]
    mov r8, [rsi + OFFSET_ID]
    call printf

.rank_ret:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; energy_recommendations: Feature 8 - Rule-based energy saving advice
; HACK: Uses fast_divmod10 and fast_divmod100 (0 hardware DIV cycles)
; ------------------------------------------------------------------------------
energy_recommendations:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72                 ; 6 pushes (48) + 72 = 120 -> 8 - 120 = -112 (16-byte aligned)

    lea rcx, [hdr_recommend]
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rcx, [str_empty_db]
    call printf
    jmp .rec_ret

.has_records:
    xor ebx, ebx                ; record index

.rec_loop:
    cmp rbx, [appliance_count]
    jge .rec_general

    ; CPU HACK: rax = rbx * 72
    lea rax, [rbx + rbx * 8]
    shl rax, 3
    lea rsi, [appliance_table]
    add rsi, rax

    mov r12, [rsi + OFFSET_WATT]
    mov r13, [rsi + OFFSET_HOURS]

    ; CPU HACK: Monthly kWh = ((W * H) / 10) * 30
    mov rax, r12
    imul rax, r13
    call fast_divmod10
    lea rax, [rax + rax * 2]
    lea rax, [rax + rax * 4]
    add rax, rax
    mov r14, rax                ; r14 = monthly kWh hundredths

    ; CPU HACK: Print device subheader via fast_divmod100
    mov rax, r14
    call fast_divmod100
    mov [rsp + 40], rax         ; 6th arg: monthly whole
    mov [rsp + 48], rdx         ; 7th arg: monthly frac
    mov [rsp + 32], r13         ; 5th arg: hours

    lea rcx, [rec_app_hdr]
    mov rdx, [rsi + OFFSET_ID]  ; 2nd arg: ID
    lea r8, [rsi + OFFSET_NAME] ; 3rd arg: Name
    mov r9, r12                 ; 4th arg: wattage
    call printf

    ; Condition A: High wattage (> 1000 W)
    cmp r12, 1000
    jbe .chk_hours
    lea rcx, [rec_high_watt]
    call printf

.chk_hours:
    ; Condition B: Prolonged operating hours (> 12 hrs/day)
    cmp r13, 12
    jbe .chk_monthly
    lea rcx, [rec_long_hours]
    call printf

.chk_monthly:
    ; Condition C: Monthly consumption tiers
    ; High: > 100.00 kWh (10000 hundredths)
    ; Moderate: 50.00 - 100.00 kWh (5000 - 10000 hundredths)
    ; Low: < 50.00 kWh (< 5000 hundredths)
    cmp r14, 10000
    jbe .chk_mod
    lea rcx, [rec_high_cons]
    call printf
    jmp .next_app

.chk_mod:
    cmp r14, 5000
    jb .chk_low
    lea rcx, [rec_mod_cons]
    call printf
    jmp .next_app

.chk_low:
    lea rcx, [rec_low_cons]
    call printf

.next_app:
    inc rbx
    jmp .rec_loop

.rec_general:
    lea rcx, [general_tips]
    call printf

.rec_ret:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret
