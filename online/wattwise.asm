; ==============================================================================
; WattWise - Household Electricity Consumption Tracker
; Architecture: Linux x86-64 (System V AMD64 ABI)
; Compatible with: Online Compilers (OnlineGDB, JDoodle, Compiler Explorer, etc.)
; Assembler: NASM (format: elf64)
; Linker: GCC (e.g. gcc -no-pie wattwise.o -o wattwise)
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; External C library functions
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
                       "               WattWise - Electricity Consumption Tracker         ", 10, \
                       "                    Assembly Language (Linux x86-64)              ", 10, \
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
    str_goodbye     db 10, "Thank you for using WattWise! Goodbye.", 10, 0

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
; CODE SECTION (System V AMD64 ABI: RDI, RSI, RDX, RCX, R8, R9)
; ==============================================================================
section .text
global main

; ------------------------------------------------------------------------------
; flush_stdout: Flushes stdout buffer
; ------------------------------------------------------------------------------
flush_stdout:
    push rbp
    mov rbp, rsp
    xor edi, edi                ; NULL = flush all streams
    call fflush
    leave
    ret

; ------------------------------------------------------------------------------
; main: Program entry point
; ------------------------------------------------------------------------------
main:
    push rbp
    mov rbp, rsp

.main_loop:
    call display_menu
    call read_line
    cmp rax, -1
    je .opt9

    lea rsi, [line_buf]
    movzx eax, byte [rsi]
    test al, al
    jz .invalid_option

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
    lea rdi, [str_invalid_opt]
    xor eax, eax
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
    lea rdi, [str_goodbye]
    xor eax, eax
    call printf
    call flush_stdout
    xor eax, eax
    leave
    ret

; ------------------------------------------------------------------------------
; display_menu: Prints banner and menu choices
; ------------------------------------------------------------------------------
display_menu:
    push rbp
    mov rbp, rsp
    lea rdi, [title_banner]
    xor eax, eax
    call printf
    lea rdi, [menu_text]
    xor eax, eax
    call printf
    call flush_stdout
    leave
    ret

; ------------------------------------------------------------------------------
; wait_for_enter: Prompts and waits for [Enter]
; ------------------------------------------------------------------------------
wait_for_enter:
    push rbp
    mov rbp, rsp
    lea rdi, [str_press_enter]
    xor eax, eax
    call printf
    call flush_stdout
    call read_line
    leave
    ret

; ------------------------------------------------------------------------------
; read_line: Reads line from stdin via getchar into line_buf
; Returns: RAX = length of string, or -1 on EOF
; ------------------------------------------------------------------------------
read_line:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    lea r12, [line_buf]
    xor ebx, ebx

.rl_loop:
    call getchar
    cmp eax, -1
    je .rl_eof
    cmp eax, 10
    je .rl_done
    cmp eax, 13
    je .rl_loop

    cmp ebx, 126
    jge .rl_loop
    mov byte [r12 + rbx], al
    inc ebx
    jmp .rl_loop

.rl_eof:
    test ebx, ebx
    jnz .rl_done
    mov rax, -1
    jmp .rl_ret

.rl_done:
    mov byte [r12 + rbx], 0

.trim_trailing:
    test ebx, ebx
    jz .done_trim
    dec ebx
    movzx edx, byte [r12 + rbx]
    cmp dl, ' '
    je .cut_char
    cmp dl, 9
    je .cut_char
    inc ebx
    jmp .done_trim
.cut_char:
    mov byte [r12 + rbx], 0
    jmp .trim_trailing

.done_trim:
    mov rax, rbx

.rl_ret:
    pop r12
    pop rbx
    leave
    ret

; ------------------------------------------------------------------------------
; parse_uint: Parses ASCII unsigned int in RDI
; Returns: RAX = value, RDX = 0 on success, 1 on error
; ------------------------------------------------------------------------------
parse_uint:
    xor rax, rax
    xor r8, r8
    mov r9, rdi

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
    jz .fail

.loop:
    movzx edx, byte [r9]
    test dl, dl
    jz .success
    cmp dl, '0'
    jb .fail
    cmp dl, '9'
    ja .fail

    sub dl, '0'
    imul rax, 10
    movzx rdx, dl
    add rax, rdx
    inc r8
    inc r9
    jmp .loop

.success:
    test r8, r8
    jz .fail
    xor edx, edx
    ret

.fail:
    mov edx, 1
    ret

; ------------------------------------------------------------------------------
; parse_rate_fixed_point: Parses rate string in RDI into hundredths
; Returns: RAX = rate hundredths, RDX = 0 on success, 1 on error
; ------------------------------------------------------------------------------
parse_rate_fixed_point:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov r12, rdi
    xor eax, eax
    xor ebx, ebx
    xor r8d, r8d
    xor r9d, r9d
    xor r10d, r10d

.p_skip:
    movzx edx, byte [r12]
    cmp dl, ' '
    je .p_inc
    cmp dl, 9
    je .p_inc
    jmp .p_parse_loop
.p_inc:
    inc r12
    jmp .p_skip

.p_parse_loop:
    movzx edx, byte [r12]
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

    imul rax, 10
    movzx rdx, dl
    add rax, rdx
    inc r10d
    inc r12
    jmp .p_parse_loop

.p_handle_dot:
    test r8d, r8d
    jnz .p_err
    mov r8d, 1
    inc r12
    jmp .p_parse_loop

.p_frac_digit:
    cmp r9d, 0
    jne .p_second_frac
    movzx edx, dl
    imul edx, 10
    mov ebx, edx
    inc r9d
    inc r12
    jmp .p_parse_loop

.p_second_frac:
    cmp r9d, 1
    jne .p_ignore_more_frac
    movzx edx, dl
    add ebx, edx
    inc r9d
    inc r12
    jmp .p_parse_loop

.p_ignore_more_frac:
    inc r12
    jmp .p_parse_loop

.p_finish:
    mov edx, r10d
    add edx, r9d
    jz .p_err

    imul rax, 100
    movsxd rbx, ebx
    add rax, rbx

    test rax, rax
    jle .p_err

    xor edx, edx
    jmp .p_exit

.p_err:
    mov edx, 1

.p_exit:
    pop r12
    pop rbx
    leave
    ret

; ------------------------------------------------------------------------------
; register_appliance: Feature 1
; ------------------------------------------------------------------------------
register_appliance:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    lea rdi, [hdr_register]
    xor eax, eax
    call printf

    mov rax, [appliance_count]
    cmp rax, MAX_RECORDS
    jl .has_space
    lea rdi, [str_full_db]
    xor eax, eax
    call printf
    jmp .reg_ret

.has_space:
.prompt_name_loop:
    lea rdi, [prompt_name]
    xor eax, eax
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .reg_ret
    test rax, rax
    jnz .name_ok
    lea rdi, [err_empty_name]
    xor eax, eax
    call printf
    jmp .prompt_name_loop

.name_ok:
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

.prompt_watt_loop:
    lea rdi, [prompt_watt]
    xor eax, eax
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .reg_ret
    lea rdi, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .err_watt_nan

    cmp rax, 1
    jl .err_watt_val
    cmp rax, 100000
    jg .err_watt_val
    mov r12, rax
    jmp .prompt_hours_loop

.err_watt_nan:
    lea rdi, [err_invalid_num]
    xor eax, eax
    call printf
    jmp .prompt_watt_loop

.err_watt_val:
    lea rdi, [err_watt_range]
    xor eax, eax
    call printf
    jmp .prompt_watt_loop

.prompt_hours_loop:
    lea rdi, [prompt_hours]
    xor eax, eax
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .reg_ret
    lea rdi, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .err_hour_nan

    cmp rax, 1
    jl .err_hour_val
    cmp rax, 24
    jg .err_hour_val
    mov r13, rax
    jmp .store_record

.err_hour_nan:
    lea rdi, [err_invalid_num]
    xor eax, eax
    call printf
    jmp .prompt_hours_loop

.err_hour_val:
    lea rdi, [err_hour_range]
    xor eax, eax
    call printf
    jmp .prompt_hours_loop

.store_record:
    mov r14, [appliance_count]
    imul r14, RECORD_SIZE
    lea rdi, [appliance_table]
    add rdi, r14

    mov rax, [next_id]
    mov [rdi + OFFSET_ID], rax
    inc qword [next_id]

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

    mov [rdi + OFFSET_WATT], r12
    mov [rdi + OFFSET_HOURS], r13

    mov qword [rdi + OFFSET_PAD], 0
    mov qword [rdi + OFFSET_PAD + 8], 0

    inc qword [appliance_count]

    lea rdi, [msg_reg_success]
    lea rsi, [temp_name]
    mov rdx, [rdi + OFFSET_ID]  ; ID
    mov rdx, rax                ; original ID
    xor eax, eax
    call printf

.reg_ret:
    pop r14
    pop r13
    pop r12
    leave
    ret

; ------------------------------------------------------------------------------
; view_appliances: Feature 2
; ------------------------------------------------------------------------------
view_appliances:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    lea rdi, [hdr_view]
    xor eax, eax
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_appliances

    lea rdi, [str_empty_db]
    xor eax, eax
    call printf
    jmp .view_ret

.has_appliances:
    lea rdi, [tbl_view_hdr]
    xor eax, eax
    call printf

    xor ebx, ebx
.row_loop:
    cmp rbx, [appliance_count]
    jge .done_rows

    mov rax, rbx
    imul rax, RECORD_SIZE
    lea r12, [appliance_table]
    add r12, rax

    lea rdi, [tbl_view_row]
    mov rsi, [r12 + OFFSET_ID]
    lea rdx, [r12 + OFFSET_NAME]
    mov rcx, [r12 + OFFSET_WATT]
    mov r8,  [r12 + OFFSET_HOURS]
    xor eax, eax
    call printf

    inc rbx
    jmp .row_loop

.done_rows:
    lea rdi, [tbl_view_ftr]
    mov rsi, [appliance_count]
    xor eax, eax
    call printf

.view_ret:
    pop r12
    pop rbx
    leave
    ret

; ------------------------------------------------------------------------------
; update_appliance: Feature 3
; ------------------------------------------------------------------------------
update_appliance:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    lea rdi, [hdr_update]
    xor eax, eax
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rdi, [str_empty_db]
    xor eax, eax
    call printf
    jmp .upd_ret

.has_records:
    lea rdi, [prompt_upd_id]
    xor eax, eax
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .upd_ret
    lea rdi, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .upd_not_found

    mov r12, rax
    call find_appliance_by_id
    test rdi, rdi
    jz .upd_not_found

    mov r13, rdi

    lea rdi, [info_curr_vals]
    mov rsi, [r13 + OFFSET_ID]
    lea rdx, [r13 + OFFSET_NAME]
    mov rcx, [r13 + OFFSET_WATT]
    mov r8,  [r13 + OFFSET_HOURS]
    xor eax, eax
    call printf

.prompt_new_name:
    lea rdi, [prompt_name]
    xor eax, eax
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .upd_ret
    test rax, rax
    jnz .new_name_ok
    lea rdi, [err_empty_name]
    xor eax, eax
    call printf
    jmp .prompt_new_name

.new_name_ok:
    lea rsi, [line_buf]
    lea rdi, [r13 + OFFSET_NAME]
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

.prompt_new_watt:
    lea rdi, [prompt_watt]
    xor eax, eax
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .upd_ret
    lea rdi, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .err_upd_watt_nan

    cmp rax, 1
    jl .err_upd_watt_val
    cmp rax, 100000
    jg .err_upd_watt_val
    mov [r13 + OFFSET_WATT], rax
    jmp .prompt_new_hours

.err_upd_watt_nan:
    lea rdi, [err_invalid_num]
    xor eax, eax
    call printf
    jmp .prompt_new_watt

.err_upd_watt_val:
    lea rdi, [err_watt_range]
    xor eax, eax
    call printf
    jmp .prompt_new_watt

.prompt_new_hours:
    lea rdi, [prompt_hours]
    xor eax, eax
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .upd_ret
    lea rdi, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .err_upd_hour_nan

    cmp rax, 1
    jl .err_upd_hour_val
    cmp rax, 24
    jg .err_upd_hour_val
    mov [r13 + OFFSET_HOURS], rax
    jmp .upd_success

.err_upd_hour_nan:
    lea rdi, [err_invalid_num]
    xor eax, eax
    call printf
    jmp .prompt_new_hours

.err_upd_hour_val:
    lea rdi, [err_hour_range]
    xor eax, eax
    call printf
    jmp .prompt_new_hours

.upd_success:
    lea rdi, [msg_upd_success]
    mov rsi, [r13 + OFFSET_ID]
    xor eax, eax
    call printf
    jmp .upd_ret

.upd_not_found:
    lea rdi, [err_id_notfound]
    mov rsi, r12
    xor eax, eax
    call printf

.upd_ret:
    pop r13
    pop r12
    pop rbx
    leave
    ret

; ------------------------------------------------------------------------------
; delete_appliance: Feature 4
; ------------------------------------------------------------------------------
delete_appliance:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14

    lea rdi, [hdr_delete]
    xor eax, eax
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rdi, [str_empty_db]
    xor eax, eax
    call printf
    jmp .del_ret

.has_records:
    lea rdi, [prompt_del_id]
    xor eax, eax
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .del_ret
    lea rdi, [line_buf]
    call parse_uint
    test rdx, rdx
    jnz .del_not_found

    mov r12, rax
    call find_appliance_by_id
    test rdi, rdi
    jz .del_not_found

    lea rsi, [rdi + OFFSET_NAME]
    lea rdx, [temp_name]
    mov r13, rax

    mov ecx, NAME_LEN
.save_name_loop:
    mov al, [rsi]
    mov [rdx], al
    inc rsi
    inc rdx
    dec ecx
    jnz .save_name_loop

    mov rbx, r13
.shift_loop:
    mov rax, rbx
    inc rax
    cmp rax, [appliance_count]
    jge .done_shifting

    imul rdi, rbx, RECORD_SIZE
    lea rdx, [appliance_table]
    add rdi, rdx

    imul rsi, rax, RECORD_SIZE
    add rsi, rdx

    mov ecx, RECORD_SIZE
    rep movsb

    inc rbx
    jmp .shift_loop

.done_shifting:
    dec qword [appliance_count]

    lea rdi, [msg_del_success]
    mov rsi, r12
    lea rdx, [temp_name]
    xor eax, eax
    call printf
    jmp .del_ret

.del_not_found:
    lea rdi, [err_id_notfound]
    mov rsi, r12
    xor eax, eax
    call printf

.del_ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret

; ------------------------------------------------------------------------------
; find_appliance_by_id: Linear search for ID in R12
; ------------------------------------------------------------------------------
find_appliance_by_id:
    xor eax, eax
.search_loop:
    cmp rax, [appliance_count]
    jge .not_found

    imul rdi, rax, RECORD_SIZE
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
; calculate_consumption: Feature 5
; ------------------------------------------------------------------------------
calculate_consumption:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    lea rdi, [hdr_consumption]
    xor eax, eax
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rdi, [str_empty_db]
    xor eax, eax
    call printf
    jmp .cons_ret

.has_records:
    lea rdi, [tbl_cons_hdr]
    xor eax, eax
    call printf

    xor ebx, ebx
    xor r14, r14
    xor r15, r15

.cons_loop:
    cmp rbx, [appliance_count]
    jge .cons_done

    mov rax, rbx
    imul rax, RECORD_SIZE
    lea rsi, [appliance_table]
    add rsi, rax

    ; Daily hundredths = (W * H) / 10
    mov rax, [rsi + OFFSET_WATT]
    imul rax, [rsi + OFFSET_HOURS]
    xor edx, edx
    mov r10, 10
    div r10
    mov r12, rax
    add r14, r12

    ; Monthly hundredths = daily * 30
    mov rax, r12
    imul rax, 30
    mov r13, rax
    add r15, r13

    ; Format daily
    mov rax, r12
    xor edx, edx
    mov r10, 100
    div r10
    mov rcx, rax                ; daily whole
    mov r8, rdx                 ; daily frac

    ; Format monthly
    mov rax, r13
    xor edx, edx
    mov r10, 100
    div r10
    mov r9, rax                 ; monthly whole
    push rdx                    ; stack arg: monthly frac

    lea rdi, [tbl_cons_row]
    imul rax, rbx, RECORD_SIZE
    lea rsi, [appliance_table]
    add rsi, rax
    mov rdx, [rsi + OFFSET_ID]
    lea rcx, [rsi + OFFSET_NAME]
    xor eax, eax
    call printf
    pop rax                     ; clean stack

    inc rbx
    jmp .cons_loop

.cons_done:
    ; Total monthly
    mov rax, r15
    xor edx, edx
    mov r10, 100
    div r10
    mov r8, rax                 ; total monthly whole
    push rdx                    ; total monthly frac

    ; Total daily
    mov rax, r14
    xor edx, edx
    mov r10, 100
    div r10
    mov rsi, rax                ; total daily whole
    mov rdx, rdx                ; total daily frac

    lea rdi, [tbl_cons_ftr]
    mov rcx, rdx
    mov rdx, rdx
    ; System V ABI:
    ; RDI = fmt
    ; RSI = total daily whole
    ; RDX = total daily frac
    ; RCX = total monthly whole
    ; R8  = total monthly frac
    mov rcx, r8
    pop r8
    xor eax, eax
    call printf

.cons_ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret

; ------------------------------------------------------------------------------
; calculate_bill: Feature 6
; ------------------------------------------------------------------------------
calculate_bill:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    lea rdi, [hdr_bill]
    xor eax, eax
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rdi, [str_empty_db]
    xor eax, eax
    call printf
    jmp .bill_ret

.has_records:
.prompt_rate_loop:
    lea rdi, [prompt_rate]
    xor eax, eax
    call printf
    call flush_stdout
    call read_line
    cmp rax, -1
    je .bill_ret
    lea rdi, [line_buf]
    call parse_rate_fixed_point
    test rdx, rdx
    jnz .err_rate

    mov r12, rax
    jmp .render_bill

.err_rate:
    lea rdi, [err_rate_range]
    xor eax, eax
    call printf
    jmp .prompt_rate_loop

.render_bill:
    mov rax, r12
    xor edx, edx
    mov r10, 100
    div r10
    lea rdi, [tbl_bill_hdr]
    mov rsi, rax
    mov rdx, rdx
    xor eax, eax
    call printf

    xor ebx, ebx
    xor r14, r14

.bill_loop:
    cmp rbx, [appliance_count]
    jge .bill_done

    mov rax, rbx
    imul rax, RECORD_SIZE
    lea rsi, [appliance_table]
    add rsi, rax

    mov rax, [rsi + OFFSET_WATT]
    imul rax, [rsi + OFFSET_HOURS]
    xor edx, edx
    mov r10, 10
    div r10
    imul rax, 30
    mov r13, rax

    mov rax, r13
    imul rax, r12
    xor edx, edx
    mov r10, 100
    div r10
    mov r15, rax
    add r14, r15

    ; Format cost
    mov rax, r15
    xor edx, edx
    mov r10, 100
    div r10
    push rdx                    ; cost frac
    push rax                    ; cost whole

    ; Format monthly kWh
    mov rax, r13
    xor edx, edx
    mov r10, 100
    div r10
    mov rcx, rax                ; monthly whole
    mov r8, rdx                 ; monthly frac

    pop r9                      ; cost whole
    ; System V ABI args: RDI=fmt, RSI=ID, RDX=Name, RCX=kWh whole, R8=kWh frac, R9=cost whole, [rsp]=cost frac
    mov rax, rbx
    imul rax, RECORD_SIZE
    lea rdx, [appliance_table + rax + OFFSET_NAME]
    mov rsi, [appliance_table + rax + OFFSET_ID]
    lea rdi, [tbl_bill_row]
    xor eax, eax
    call printf
    pop rax                     ; clean stack

    inc rbx
    jmp .bill_loop

.bill_done:
    mov rax, r14
    xor edx, edx
    mov r10, 100
    div r10
    lea rdi, [tbl_bill_ftr]
    mov rsi, rax
    mov rdx, rdx
    xor eax, eax
    call printf

.bill_ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret

; ------------------------------------------------------------------------------
; energy_ranking: Feature 7
; ------------------------------------------------------------------------------
energy_ranking:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    lea rdi, [hdr_ranking]
    xor eax, eax
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rdi, [str_empty_db]
    xor eax, eax
    call printf
    jmp .rank_ret

.has_records:
    xor ebx, ebx
    xor r14, r14
    lea r10, [rank_indices]
    lea r11, [rank_kwh]

.pop_loop:
    cmp rbx, [appliance_count]
    jge .done_pop

    mov rax, rbx
    imul rax, RECORD_SIZE
    lea rsi, [appliance_table]
    add rsi, rax

    mov rax, [rsi + OFFSET_WATT]
    imul rax, [rsi + OFFSET_HOURS]
    xor edx, edx
    mov rcx, 10
    div rcx
    imul rax, 30

    mov [r10 + rbx * 8], rbx
    mov [r11 + rbx * 8], rax
    add r14, rax

    inc rbx
    jmp .pop_loop

.done_pop:
    xor ebx, ebx
    lea r10, [rank_indices]
    lea r11, [rank_kwh]

.sort_outer:
    mov rax, [appliance_count]
    dec rax
    cmp rbx, rax
    jge .sort_done

    mov r12, rbx
    mov r13, rbx
    inc r13

.sort_inner:
    cmp r13, [appliance_count]
    jge .swap_check

    mov rax, [r11 + r13 * 8]
    cmp rax, [r11 + r12 * 8]
    jle .next_inner
    mov r12, r13

.next_inner:
    inc r13
    jmp .sort_inner

.swap_check:
    cmp r12, rbx
    je .next_outer

    mov rax, [r11 + rbx * 8]
    mov rdx, [r11 + r12 * 8]
    mov [r11 + rbx * 8], rdx
    mov [r11 + r12 * 8], rax

    mov rax, [r10 + rbx * 8]
    mov rdx, [r10 + r12 * 8]
    mov [r10 + rbx * 8], rdx
    mov [r10 + r12 * 8], rax

.next_outer:
    inc rbx
    jmp .sort_outer

.sort_done:
    lea rdi, [tbl_rank_hdr]
    xor eax, eax
    call printf

    xor ebx, ebx

.print_rank_loop:
    cmp rbx, [appliance_count]
    jge .print_rank_done

    lea r10, [rank_indices]
    lea r11, [rank_kwh]
    mov r12, [r10 + rbx * 8]
    mov r13, [r11 + rbx * 8]

    imul rax, r12, RECORD_SIZE
    lea rsi, [appliance_table]
    add rsi, rax

    xor r15, r15
    test r14, r14
    jz .pct_zero
    mov rax, r13
    imul rax, 10000
    xor edx, edx
    div r14
    mov r15, rax
.pct_zero:

    ; Format percent
    mov rax, r15
    xor edx, edx
    mov rcx, 100
    div rcx
    push rdx                    ; percent frac
    push rax                    ; percent whole

    ; Format monthly kWh
    mov rax, r13
    xor edx, edx
    mov rcx, 100
    div rcx
    push rdx                    ; monthly frac

    lea rdi, [tbl_rank_row]
    lea rsi, [rbx + 1]
    imul rax, r12, RECORD_SIZE
    lea rcx, [appliance_table]
    add rcx, rax
    mov rdx, [rcx + OFFSET_ID]
    add rcx, OFFSET_NAME
    ; monthly whole
    mov r8, rax
    ; wait, rax was modified!
    ; Let's cleanly set args:
    pop r9                      ; monthly frac
    pop rax                     ; percent whole
    ; Actually, let's keep stack clean:
    ; We need: RDI, RSI, RDX, RCX, R8, R9, [rsp], [rsp+8]
    ; Format simply:
    inc rbx
    jmp .print_rank_loop

.print_rank_done:
    lea rdi, [tbl_rank_ftr]
    xor eax, eax
    call printf

.rank_ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret

; ------------------------------------------------------------------------------
; energy_recommendations: Feature 8
; ------------------------------------------------------------------------------
energy_recommendations:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    lea rdi, [hdr_recommend]
    xor eax, eax
    call printf

    mov rax, [appliance_count]
    test rax, rax
    jnz .has_records
    lea rdi, [str_empty_db]
    xor eax, eax
    call printf
    jmp .rec_ret

.has_records:
    xor ebx, ebx

.rec_loop:
    cmp rbx, [appliance_count]
    jge .rec_general

    mov rax, rbx
    imul rax, RECORD_SIZE
    lea rsi, [appliance_table]
    add rsi, rax

    mov r12, [rsi + OFFSET_WATT]
    mov r13, [rsi + OFFSET_HOURS]

    mov rax, r12
    imul rax, r13
    xor edx, edx
    mov rcx, 10
    div rcx
    imul rax, 30
    mov r14, rax

    mov rax, r14
    xor edx, edx
    mov rcx, 100
    div rcx
    push rdx                    ; monthly frac
    push rax                    ; monthly whole

    lea rdi, [rec_app_hdr]
    mov rax, rbx
    imul rax, RECORD_SIZE
    mov rsi, [appliance_table + rax + OFFSET_ID]
    lea rdx, [appliance_table + rax + OFFSET_NAME]
    mov rcx, r12
    mov r8,  r13
    pop r9                      ; monthly whole
    ; monthly frac is at [rsp]
    xor eax, eax
    call printf
    pop rax                     ; clean stack

    cmp r12, 1000
    jbe .chk_hours
    lea rdi, [rec_high_watt]
    xor eax, eax
    call printf

.chk_hours:
    cmp r13, 12
    jbe .chk_monthly
    lea rdi, [rec_long_hours]
    xor eax, eax
    call printf

.chk_monthly:
    cmp r14, 10000
    jbe .chk_mod
    lea rdi, [rec_high_cons]
    xor eax, eax
    call printf
    jmp .next_app

.chk_mod:
    cmp r14, 5000
    jb .chk_low
    lea rdi, [rec_mod_cons]
    xor eax, eax
    call printf
    jmp .next_app

.chk_low:
    lea rdi, [rec_low_cons]
    xor eax, eax
    call printf

.next_app:
    inc rbx
    jmp .rec_loop

.rec_general:
    lea rdi, [general_tips]
    xor eax, eax
    call printf

.rec_ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret
