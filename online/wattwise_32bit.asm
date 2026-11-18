; =============================================================================
; WattWise - Household Electricity Consumption Tracker
; Portable online-compiler build: 32-bit NASM / Linux int 0x80
; Target: JDoodle NASM and OneCompiler Assembly (32-bit sample environment)
; No C library, no external libraries, no separate build commands.
;
; Paste this entire file into the NASM/Assembly editor and press Run.
; Appliance record: ID (4) + Wattage (4) + Hours/day (4) + Name (32) = 44 bytes.
; Maximum records: 20. Consumption is stored in hundredths of kWh.
; Electricity rate is entered in PHP per kWh (e.g. 12.50).
; =============================================================================

BITS 32

%define SYS_READ       3
%define SYS_WRITE      4
%define SYS_EXIT       1
%define STDIN          0
%define STDOUT         1
%define MAX_RECORDS    20
%define NAME_SIZE      32
%define RECORD_SIZE    44
%define OFF_ID         0
%define OFF_WATTS      4
%define OFF_HOURS      8
%define OFF_NAME       12

section .data
    title db 10, '============================================================',10, '        WattWise - Household Electricity Tracker',10, '              32-bit NASM Assembly',10, '============================================================',10,0
    menu db 10,'[1] Register Appliance',10,'[2] View Appliances',10,'[3] Update Appliance',10,'[4] Delete Appliance',10,'[5] Calculate Electricity Consumption',10,'[6] Estimate Electricity Bill',10,'[7] Energy Consumption Ranking',10,'[8] Energy-Saving Recommendations',10,'[9] Exit',10,'Choose an option (1-9): ',0
    invalid_choice db 10,'[!] Invalid choice. Enter a number from 1 to 9.',10,0
    empty_db db 10,'[i] No appliances registered yet. Register an appliance first.',10,0
    full_db db 10,'[!] Maximum capacity reached (20 appliances).',10,0
    goodbye db 10,'Thank you for using WattWise. Goodbye!',10,0
    press_enter db 10,'Press Enter to return to the menu...',0

    hdr_register db 10,'>>> REGISTER APPLIANCE <<<',10,0
    prompt_name db 'Appliance name (max 31 characters): ',0
    prompt_watts db 'Rated wattage in watts (1-100000): ',0
    prompt_hours db 'Daily operating hours (1-24): ',0
    err_name db '[!] Name cannot be blank.',10,0
    err_number db '[!] Invalid number. Enter digits only.',10,0
    err_watts db '[!] Wattage must be from 1 to 100000.',10,0
    err_hours db '[!] Hours must be from 1 to 24.',10,0
    registered db '[+] Appliance registered. Assigned ID: ',0

    hdr_view db 10,'>>> REGISTERED APPLIANCES <<<',10,0
    label_id db 'ID: ',0
    label_name db ' | Name: ',0
    label_watts db ' | Wattage: ',0
    label_hours db ' W | Hours/day: ',0
    suffix_hours db ' hours',10,0
    total_records db 'Total registered appliances: ',0

    hdr_update db 10,'>>> UPDATE APPLIANCE <<<',10,0
    prompt_update_id db 'Enter the appliance ID to update: ',0
    current_details db 'Current details - Name: ',0
    current_watts db ' | Wattage: ',0
    current_hours db ' | Hours/day: ',0
    updated_msg db 10,'[+] Appliance successfully updated.',10,0

    hdr_delete db 10,'>>> DELETE APPLIANCE <<<',10,0
    prompt_delete_id db 'Enter the appliance ID to delete: ',0
    deleted_msg db '[+] Appliance successfully deleted.',10,0
    not_found db '[!] Appliance ID not found.',10,0

    hdr_consumption db 10,'>>> ELECTRICITY CONSUMPTION ANALYSIS <<<',10,'Formula: kWh = (Watts x Hours) / 1000; monthly estimate = daily x 30',10,0
    daily_label db 'Daily consumption: ',0
    monthly_label db 'Monthly consumption (30 days): ',0
    total_daily_label db 'TOTAL HOUSEHOLD DAILY CONSUMPTION: ',0
    total_monthly_label db 'TOTAL HOUSEHOLD MONTHLY CONSUMPTION: ',0
    kwh_suffix db ' kWh',10,0
    no_usage db '[i] No consumption data to calculate.',10,0

    hdr_bill db 10,'>>> ELECTRICITY BILL ESTIMATE <<<',10,0
    prompt_rate db 'Electricity rate per kWh in PHP (e.g. 12.50): ',0
    err_rate db '[!] Rate must be between PHP 0.01 and PHP 100.00.',10,0
    bill_rate_label db 'Rate applied: PHP ',0
    bill_usage_label db ' | Monthly usage: ',0
    bill_cost_label db ' | Estimated cost: PHP ',0
    total_bill_label db 10,'TOTAL ESTIMATED MONTHLY BILL: PHP ',0

    hdr_ranking db 10,'>>> ENERGY CONSUMPTION RANKING <<<',10,'Highest monthly consumption appears first.',10,0
    rank_label db 'Rank ',0
    rank_id_label db ' | ID ',0
    rank_name_label db ' | ',0
    rank_usage_label db ' | Monthly: ',0
    rank_share_label db ' kWh | Share: ',0
    percent_suffix db '%',10,0
    highest_label db 10,'Highest consumer: ',0
    no_total db '[i] Total usage is zero; ranking share cannot be calculated.',10,0

    hdr_recommend db 10,'>>> ENERGY-SAVING RECOMMENDATIONS <<<',10,0
    rec_device db 10,'Appliance: ',0
    rec_watts db ' | ',0
    rec_hours db ' W | ',0
    rec_monthly db ' hours/day | ',0
    rec_kwh db ' kWh/month',10,0
    rec_high_watts db '  [!] HIGH POWER: Avoid running this appliance together with other heavy loads. Consider an energy-efficient alternative.',10,0
    rec_long_hours db '  [!] LONG OPERATING TIME: Use a timer and switch the appliance off when it is not needed.',10,0
    rec_high_usage db '  [!] HIGH CONSUMPTION (>100 kWh/month): Prioritize this appliance when reducing household electricity use.',10,0
    rec_moderate db '  [i] MODERATE CONSUMPTION (50-100 kWh/month): Clean and maintain the appliance regularly.',10,0
    rec_low db '  [+] LOW CONSUMPTION (<50 kWh/month): Consumption is relatively low.',10,0
    general_tips db 10,'GENERAL ENERGY-SAVING TIPS',10,'1. Unplug devices that remain on standby.',10,'2. Keep refrigerator coils clean and maintain suitable temperature settings.',10,'3. Use LED lighting where possible.',10,'4. Run washing machines with full loads.',10,0

    dot db '.',0
    zero_char db '0',0
    newline db 10,0

section .bss
    appliances resb (MAX_RECORDS * RECORD_SIZE)
    appliance_count resd 1
    next_id resd 1
    linebuf resb 128
    input_len resd 1
    target_id resd 1
    current_ptr resd 1
    loop_index resd 1
    total_daily resd 1
    total_monthly resd 1
    rate_cents resd 1
    item_cost resd 1
    total_bill_lo resd 1
    total_bill_hi resd 1
    temp_value resd 1
    temp_value2 resd 1
    temp_fraction resd 1
    temp_whole resd 1
    numbuf resb 32
    u64_hi resd 1
    u64_lo resd 1
    u64_qhi resd 1
    u64_qlo resd 1
    rank_indices resd MAX_RECORDS
    rank_usage resd MAX_RECORDS
    rank_i resd 1
    rank_j resd 1
    rank_temp resd 1

section .text
global _start

_start:
    mov dword [next_id], 1
    mov esi, title
    call print_z

main_loop:
    mov esi, menu
    call print_z
    call read_line
    cmp eax, -1
    je exit_program
    mov esi, linebuf
    call parse_uint
    jc bad_choice
    cmp eax, 1
    je do_register
    cmp eax, 2
    je do_view
    cmp eax, 3
    je do_update
    cmp eax, 4
    je do_delete
    cmp eax, 5
    je do_consumption
    cmp eax, 6
    je do_bill
    cmp eax, 7
    je do_ranking
    cmp eax, 8
    je do_recommendations
    cmp eax, 9
    je exit_program

bad_choice:
    mov esi, invalid_choice
    call print_z
    call pause_menu
    jmp main_loop

do_register:
    call register_appliance
    call pause_menu
    jmp main_loop

do_view:
    call view_appliances
    call pause_menu
    jmp main_loop

do_update:
    call update_appliance
    call pause_menu
    jmp main_loop

do_delete:
    call delete_appliance
    call pause_menu
    jmp main_loop

do_consumption:
    call calculate_consumption
    call pause_menu
    jmp main_loop

do_bill:
    call calculate_bill
    call pause_menu
    jmp main_loop

do_ranking:
    call energy_ranking
    call pause_menu
    jmp main_loop

do_recommendations:
    call energy_recommendations
    call pause_menu
    jmp main_loop

exit_program:
    mov esi, goodbye
    call print_z
    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80

; -----------------------------------------------------------------------------
; print_z: print null-terminated string at ESI. Preserves general registers.
; -----------------------------------------------------------------------------
print_z:
    push eax
    push ebx
    push ecx
    push edx
    push edi
    mov edi, esi
    xor edx, edx
.pz_count:
    cmp byte [edi+edx], 0
    je .pz_write
    inc edx
    jmp .pz_count
.pz_write:
    test edx, edx
    jz .pz_done
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, esi
    int 0x80
.pz_done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; -----------------------------------------------------------------------------
; read_line: reads one line from stdin into linebuf; returns length in EAX.
; Returns -1 on EOF before any character. Reads one byte per syscall so pasted
; multi-line test input is not accidentally consumed as one line.
; -----------------------------------------------------------------------------
read_line:
    push ebp
    push ebx
    push ecx
    push edx
    xor ebp, ebp
.rl_next:
    mov eax, SYS_READ
    mov ebx, STDIN
    mov ecx, linebuf
    add ecx, ebp
    mov edx, 1
    int 0x80
    cmp eax, 0
    jle .rl_eof
    mov al, [linebuf+ebp]
    cmp al, 10
    je .rl_done
    cmp al, 13
    je .rl_next
    cmp ebp, 126
    jae .rl_next
    inc ebp
    jmp .rl_next
.rl_eof:
    test ebp, ebp
    jnz .rl_done
    mov eax, -1
    jmp .rl_return
.rl_done:
    mov byte [linebuf+ebp], 0
    mov [input_len], ebp
    mov eax, ebp
.rl_return:
    pop edx
    pop ecx
    pop ebx
    pop ebp
    ret

; -----------------------------------------------------------------------------
; parse_uint: ESI -> decimal digits. Returns EAX=value, CF=0; invalid CF=1.
; Allows surrounding spaces but no signs or other trailing characters.
; -----------------------------------------------------------------------------
parse_uint:
    push ebx
    push ecx
    push edi
    mov edi, esi
    xor eax, eax
    xor ecx, ecx
.pu_lead:
    mov bl, [edi]
    cmp bl, ' '
    je .pu_skip_lead
    cmp bl, 9
    je .pu_skip_lead
    jmp .pu_digits
.pu_skip_lead:
    inc edi
    jmp .pu_lead
.pu_digits:
    mov bl, [edi]
    cmp bl, '0'
    jb .pu_trailing
    cmp bl, '9'
    ja .pu_trailing
    imul eax, eax, 10
    jo .pu_bad
    movzx ebx, bl
    sub ebx, '0'
    add eax, ebx
    jc .pu_bad
    inc ecx
    inc edi
    jmp .pu_digits
.pu_trailing:
    test ecx, ecx
    jz .pu_bad
    cmp bl, ' '
    je .pu_skip_tail
    cmp bl, 9
    je .pu_skip_tail
    test bl, bl
    jnz .pu_bad
    clc
    jmp .pu_exit
.pu_skip_tail:
    inc edi
    jmp .pu_trailing
.pu_bad:
    stc
.pu_exit:
    pop edi
    pop ecx
    pop ebx
    ret

; -----------------------------------------------------------------------------
; parse_rate: ESI -> decimal PHP rate such as 12, 12.5, or 12.50.
; Returns EAX=centavos, CF=0 on success; CF=1 on invalid input.
; Accepts at most two fractional digits and a maximum rate of PHP 100.00.
; -----------------------------------------------------------------------------
parse_rate:
    push ebx
    push ecx
    push edx
    push edi
    mov edi, esi
.pr_leading:
    mov bl, [edi]
    cmp bl, ' '
    je .pr_lead_skip
    cmp bl, 9
    je .pr_lead_skip
    jmp .pr_whole_start
.pr_lead_skip:
    inc edi
    jmp .pr_leading
.pr_whole_start:
    xor eax, eax
    xor ecx, ecx
.pr_whole:
    mov bl, [edi]
    cmp bl, '0'
    jb .pr_after_whole
    cmp bl, '9'
    ja .pr_after_whole
    imul eax, eax, 10
    jo .pr_bad
    movzx ebx, bl
    sub ebx, '0'
    add eax, ebx
    jc .pr_bad
    inc ecx
    inc edi
    jmp .pr_whole
.pr_after_whole:
    test ecx, ecx
    jz .pr_bad
    imul eax, eax, 100
    jo .pr_bad
    mov [temp_value], eax
    xor ebx, ebx
    cmp byte [edi], '.'
    jne .pr_trailing
    inc edi
    mov bl, [edi]
    cmp bl, '0'
    jb .pr_fraction_end
    cmp bl, '9'
    ja .pr_fraction_end
    movzx ebx, bl
    sub ebx, '0'
    imul ebx, ebx, 10
    inc edi
    mov dl, [edi]
    cmp dl, '0'
    jb .pr_fraction_end
    cmp dl, '9'
    ja .pr_fraction_end
    movzx edx, dl
    sub edx, '0'
    add ebx, edx
    inc edi
    jmp .pr_trailing
.pr_fraction_end:
    ; A single fractional digit is interpreted as tenths (12.5 = 12.50).
    jmp .pr_trailing
.pr_trailing:
    mov dl, [edi]
    cmp dl, ' '
    je .pr_skip_tail
    cmp dl, 9
    je .pr_skip_tail
    test dl, dl
    jnz .pr_bad
    mov eax, [temp_value]
    add eax, ebx
    cmp eax, 10000
    ja .pr_bad
    test eax, eax
    jz .pr_bad
    clc
    jmp .pr_exit
.pr_skip_tail:
    inc edi
    jmp .pr_trailing
.pr_bad:
    stc
.pr_exit:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; -----------------------------------------------------------------------------
; print_uint: print unsigned integer in EAX. Preserves EAX and other registers.
; -----------------------------------------------------------------------------
print_uint:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    lea edi, [numbuf+31]
    mov byte [edi], 0
    mov ebx, 10
    test eax, eax
    jnz .pu_convert
    dec edi
    mov byte [edi], '0'
    jmp .pu_output
.pu_convert:
    xor edx, edx
    div ebx
    add dl, '0'
    dec edi
    mov [edi], dl
    test eax, eax
    jnz .pu_convert
.pu_output:
    mov esi, edi
    call print_z
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; -----------------------------------------------------------------------------
; print_fixed: print EAX as a number with two decimal places (hundredths).
; -----------------------------------------------------------------------------
print_fixed:
    push eax
    push ebx
    push edx
    mov ebx, 100
    xor edx, edx
    div ebx
    mov [temp_whole], eax
    mov [temp_fraction], edx
    mov eax, [temp_whole]
    call print_uint
    mov esi, dot
    call print_z
    mov eax, [temp_fraction]
    cmp eax, 10
    jae .pf_two
    mov esi, zero_char
    call print_z
.pf_two:
    mov eax, [temp_fraction]
    call print_uint
    pop edx
    pop ebx
    pop eax
    ret

; -----------------------------------------------------------------------------
; print_u64: print unsigned 64-bit integer in EDX:EAX.
; -----------------------------------------------------------------------------
print_u64:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov [u64_hi], edx
    mov [u64_lo], eax
    lea edi, [numbuf+31]
    mov byte [edi], 0
    mov ebx, 10
.p64_loop:
    mov eax, [u64_hi]
    xor edx, edx
    div ebx
    mov [u64_qhi], eax
    mov eax, [u64_lo]
    div ebx
    mov [u64_qlo], eax
    add dl, '0'
    dec edi
    mov [edi], dl
    mov eax, [u64_qhi]
    mov [u64_hi], eax
    mov eax, [u64_qlo]
    mov [u64_lo], eax
    or eax, [u64_hi]
    jnz .p64_loop
    mov esi, edi
    call print_z
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; -----------------------------------------------------------------------------
; print_fixed64: print EDX:EAX as hundredths with two decimal places.
; -----------------------------------------------------------------------------
print_fixed64:
    push eax
    push ebx
    push ecx
    push edx
    mov [u64_hi], edx
    mov [u64_lo], eax
    mov ebx, 100
    mov eax, [u64_hi]
    xor edx, edx
    div ebx
    mov [u64_qhi], eax
    mov eax, [u64_lo]
    div ebx
    mov [u64_qlo], eax
    mov [temp_fraction], edx
    mov edx, [u64_qhi]
    mov eax, [u64_qlo]
    call print_u64
    mov esi, dot
    call print_z
    mov eax, [temp_fraction]
    cmp eax, 10
    jae .pf64_two
    mov esi, zero_char
    call print_z
.pf64_two:
    mov eax, [temp_fraction]
    call print_uint
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; -----------------------------------------------------------------------------
; ask_uint: ESI=prompt. Reads and parses one unsigned integer. CF=1 on error.
; -----------------------------------------------------------------------------
ask_uint:
    call print_z
    call read_line
    cmp eax, -1
    je .au_bad
    mov esi, linebuf
    call parse_uint
    ret
.au_bad:
    stc
    ret

; -----------------------------------------------------------------------------
; pause_menu
; -----------------------------------------------------------------------------
pause_menu:
    mov esi, press_enter
    call print_z
    call read_line
    ret

; -----------------------------------------------------------------------------
; calc_monthly: EDI=record, returns EAX=monthly consumption in hundredths kWh.
; -----------------------------------------------------------------------------
calc_monthly:
    mov eax, [edi+OFF_WATTS]
    mul dword [edi+OFF_HOURS]
    imul eax, eax, 3
    ret

; -----------------------------------------------------------------------------
; find_id: target_id global. Returns EDI=record pointer or EDI=0.
; -----------------------------------------------------------------------------
find_id:
    mov ecx, [appliance_count]
    mov edi, appliances
.fi_loop:
    test ecx, ecx
    jz .fi_missing
    mov eax, [edi+OFF_ID]
    cmp eax, [target_id]
    je .fi_found
    add edi, RECORD_SIZE
    dec ecx
    jmp .fi_loop
.fi_missing:
    xor edi, edi
.fi_found:
    ret

; -----------------------------------------------------------------------------
; copy_name_to_record: EDI=record pointer. Copies linebuf into 32-byte name.
; -----------------------------------------------------------------------------
copy_name_to_record:
    push eax
    push ecx
    push esi
    push edi
    lea edi, [edi+OFF_NAME]
    xor eax, eax
    mov ecx, NAME_SIZE
    rep stosb
    mov edi, [current_ptr]
    lea edi, [edi+OFF_NAME]
    mov esi, linebuf
    mov ecx, [input_len]
    cmp ecx, NAME_SIZE-1
    jbe .cn_copy
    mov ecx, NAME_SIZE-1
.cn_copy:
    rep movsb
    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; -----------------------------------------------------------------------------
; register_appliance
; -----------------------------------------------------------------------------
register_appliance:
    mov esi, hdr_register
    call print_z
    cmp dword [appliance_count], MAX_RECORDS
    jb .reg_room
    mov esi, full_db
    call print_z
    ret
.reg_room:
    mov eax, [appliance_count]
    imul eax, RECORD_SIZE
    lea edi, [appliances+eax]
    mov [current_ptr], edi
    mov eax, [next_id]
    mov [edi+OFF_ID], eax
    mov esi, prompt_name
    call print_z
    call read_line
    cmp eax, -1
    je .reg_done
    cmp dword [input_len], 0
    jne .reg_name_ok
    mov esi, err_name
    call print_z
    ret
.reg_name_ok:
    mov edi, [current_ptr]
    call copy_name_to_record
    mov esi, prompt_watts
    call ask_uint
    jc .reg_bad_number
    cmp eax, 1
    jb .reg_bad_watts
    cmp eax, 100000
    ja .reg_bad_watts
    mov edi, [current_ptr]
    mov [edi+OFF_WATTS], eax
    mov esi, prompt_hours
    call ask_uint
    jc .reg_bad_number
    cmp eax, 1
    jb .reg_bad_hours
    cmp eax, 24
    ja .reg_bad_hours
    mov edi, [current_ptr]
    mov [edi+OFF_HOURS], eax
    inc dword [appliance_count]
    inc dword [next_id]
    mov esi, registered
    call print_z
    mov edi, [current_ptr]
    mov eax, [edi+OFF_ID]
    call print_uint
    mov esi, newline
    call print_z
    ret
.reg_bad_number:
    mov esi, err_number
    call print_z
    ret
.reg_bad_watts:
    mov esi, err_watts
    call print_z
    ret
.reg_bad_hours:
    mov esi, err_hours
    call print_z
.reg_done:
    ret

; -----------------------------------------------------------------------------
; view_appliances
; -----------------------------------------------------------------------------
view_appliances:
    mov esi, hdr_view
    call print_z
    cmp dword [appliance_count], 0
    jne .view_loop_start
    mov esi, empty_db
    call print_z
    ret
.view_loop_start:
    mov dword [loop_index], 0
    mov edi, appliances
.view_loop:
    mov esi, label_id
    call print_z
    mov eax, [edi+OFF_ID]
    call print_uint
    mov esi, label_name
    call print_z
    lea esi, [edi+OFF_NAME]
    call print_z
    mov esi, label_watts
    call print_z
    mov eax, [edi+OFF_WATTS]
    call print_uint
    mov esi, label_hours
    call print_z
    mov eax, [edi+OFF_HOURS]
    call print_uint
    mov esi, suffix_hours
    call print_z
    inc dword [loop_index]
    add edi, RECORD_SIZE
    mov eax, [loop_index]
    cmp eax, [appliance_count]
    jb .view_loop
    mov esi, total_records
    call print_z
    mov eax, [appliance_count]
    call print_uint
    mov esi, newline
    call print_z
    ret

; -----------------------------------------------------------------------------
; update_appliance
; -----------------------------------------------------------------------------
update_appliance:
    mov esi, hdr_update
    call print_z
    cmp dword [appliance_count], 0
    jne .upd_ask
    mov esi, empty_db
    call print_z
    ret
.upd_ask:
    mov esi, prompt_update_id
    call ask_uint
    jc .upd_bad
    mov [target_id], eax
    call find_id
    test edi, edi
    jz .upd_missing
    mov [current_ptr], edi
    mov esi, current_details
    call print_z
    lea esi, [edi+OFF_NAME]
    call print_z
    mov esi, current_watts
    call print_z
    mov eax, [edi+OFF_WATTS]
    call print_uint
    mov esi, current_hours
    call print_z
    mov eax, [edi+OFF_HOURS]
    call print_uint
    mov esi, newline
    call print_z
    mov esi, prompt_name
    call print_z
    call read_line
    cmp eax, -1
    je .upd_done
    cmp dword [input_len], 0
    je .upd_bad_name
    mov edi, [current_ptr]
    call copy_name_to_record
    mov esi, prompt_watts
    call ask_uint
    jc .upd_bad
    cmp eax, 1
    jb .upd_bad_w
    cmp eax, 100000
    ja .upd_bad_w
    mov edi, [current_ptr]
    mov [edi+OFF_WATTS], eax
    mov esi, prompt_hours
    call ask_uint
    jc .upd_bad
    cmp eax, 1
    jb .upd_bad_h
    cmp eax, 24
    ja .upd_bad_h
    mov edi, [current_ptr]
    mov [edi+OFF_HOURS], eax
    mov esi, updated_msg
    call print_z
    ret
.upd_bad:
    mov esi, err_number
    call print_z
    ret
.upd_bad_name:
    mov esi, err_name
    call print_z
    ret
.upd_bad_w:
    mov esi, err_watts
    call print_z
    ret
.upd_bad_h:
    mov esi, err_hours
    call print_z
    ret
.upd_missing:
    mov esi, not_found
    call print_z
.upd_done:
    ret

; -----------------------------------------------------------------------------
; delete_appliance
; -----------------------------------------------------------------------------
delete_appliance:
    mov esi, hdr_delete
    call print_z
    cmp dword [appliance_count], 0
    jne .del_ask
    mov esi, empty_db
    call print_z
    ret
.del_ask:
    mov esi, prompt_delete_id
    call ask_uint
    jc .del_bad
    mov [target_id], eax
    call find_id
    test edi, edi
    jz .del_missing
    mov [current_ptr], edi
    mov eax, edi
    sub eax, appliances
    xor edx, edx
    mov ebx, RECORD_SIZE
    div ebx
    mov [loop_index], eax
    mov eax, [appliance_count]
    sub eax, [loop_index]
    dec eax
    jz .del_last
    imul eax, RECORD_SIZE
    mov ecx, eax
    mov esi, [current_ptr]
    lea edi, [esi+RECORD_SIZE]
    rep movsb
.del_last:
    dec dword [appliance_count]
    mov esi, deleted_msg
    call print_z
    ret
.del_bad:
    mov esi, err_number
    call print_z
    ret
.del_missing:
    mov esi, not_found
    call print_z
    ret

; -----------------------------------------------------------------------------
; calculate_consumption
; -----------------------------------------------------------------------------
calculate_consumption:
    mov esi, hdr_consumption
    call print_z
    cmp dword [appliance_count], 0
    jne .cons_start
    mov esi, empty_db
    call print_z
    ret
.cons_start:
    mov dword [total_daily], 0
    mov dword [total_monthly], 0
    mov dword [loop_index], 0
    mov edi, appliances
.cons_loop:
    mov eax, [edi+OFF_WATTS]
    mul dword [edi+OFF_HOURS]
    mov ebx, 10
    div ebx
    mov [temp_value], eax
    add [total_daily], eax
    mov eax, [edi+OFF_WATTS]
    mul dword [edi+OFF_HOURS]
    imul eax, eax, 3
    mov [temp_value2], eax
    add [total_monthly], eax
    mov esi, label_id
    call print_z
    mov eax, [edi+OFF_ID]
    call print_uint
    mov esi, label_name
    call print_z
    lea esi, [edi+OFF_NAME]
    call print_z
    mov esi, newline
    call print_z
    mov esi, daily_label
    call print_z
    mov eax, [temp_value]
    call print_fixed
    mov esi, kwh_suffix
    call print_z
    mov esi, monthly_label
    call print_z
    mov eax, [temp_value2]
    call print_fixed
    mov esi, kwh_suffix
    call print_z
    inc dword [loop_index]
    add edi, RECORD_SIZE
    mov eax, [loop_index]
    cmp eax, [appliance_count]
    jb .cons_loop
    mov esi, total_daily_label
    call print_z
    mov eax, [total_daily]
    call print_fixed
    mov esi, kwh_suffix
    call print_z
    mov esi, total_monthly_label
    call print_z
    mov eax, [total_monthly]
    call print_fixed
    mov esi, kwh_suffix
    call print_z
    ret

; -----------------------------------------------------------------------------
; calculate_bill. Rate is entered in PHP and stored internally as centavos.
; Per-device bill in centavos = monthly_kWh_hundredths * rate_centavos / 100.
; Household total is accumulated as a 64-bit value.
; -----------------------------------------------------------------------------
calculate_bill:
    mov esi, hdr_bill
    call print_z
    cmp dword [appliance_count], 0
    jne .bill_rate
    mov esi, empty_db
    call print_z
    ret
.bill_rate:
    mov esi, prompt_rate
    call print_z
    call read_line
    cmp eax, -1
    je .bill_bad_rate
    mov esi, linebuf
    call parse_rate
    jc .bill_bad_rate
    mov [rate_cents], eax
    mov esi, bill_rate_label
    call print_z
    mov eax, [rate_cents]
    call print_fixed
    mov esi, newline
    call print_z
    mov dword [total_bill_lo], 0
    mov dword [total_bill_hi], 0
    mov dword [loop_index], 0
    mov edi, appliances
.bill_loop:
    call calc_monthly
    mov [temp_value], eax
    mul dword [rate_cents]
    mov ebx, 100
    div ebx
    mov [item_cost], eax
    add [total_bill_lo], eax
    adc dword [total_bill_hi], 0
    lea esi, [edi+OFF_NAME]
    call print_z
    mov esi, bill_usage_label
    call print_z
    mov eax, [temp_value]
    call print_fixed
    mov esi, bill_cost_label
    call print_z
    mov eax, [item_cost]
    call print_fixed
    mov esi, newline
    call print_z
    inc dword [loop_index]
    add edi, RECORD_SIZE
    mov eax, [loop_index]
    cmp eax, [appliance_count]
    jb .bill_loop
    mov esi, total_bill_label
    call print_z
    mov edx, [total_bill_hi]
    mov eax, [total_bill_lo]
    call print_fixed64
    mov esi, newline
    call print_z
    ret
.bill_bad_rate:
    mov esi, err_rate
    call print_z
    ret

; -----------------------------------------------------------------------------
; energy_ranking: build monthly usage array and sort descending.
; -----------------------------------------------------------------------------
energy_ranking:
    mov esi, hdr_ranking
    call print_z
    cmp dword [appliance_count], 0
    jne .rank_build
    mov esi, empty_db
    call print_z
    ret
.rank_build:
    mov dword [loop_index], 0
    mov dword [total_monthly], 0
    mov edi, appliances
.rank_build_loop:
    call calc_monthly
    mov ebx, [loop_index]
    mov [rank_usage+ebx*4], eax
    mov [rank_indices+ebx*4], ebx
    add [total_monthly], eax
    inc dword [loop_index]
    add edi, RECORD_SIZE
    mov eax, [loop_index]
    cmp eax, [appliance_count]
    jb .rank_build_loop
    cmp dword [total_monthly], 0
    jne .rank_sort_start
    mov esi, no_total
    call print_z
    ret
.rank_sort_start:
    mov dword [rank_i], 0
.rank_outer:
    mov eax, [appliance_count]
    dec eax
    cmp [rank_i], eax
    jae .rank_print_start
    mov eax, [rank_i]
    inc eax
    mov [rank_j], eax
.rank_inner:
    mov eax, [rank_j]
    cmp eax, [appliance_count]
    jae .rank_next_outer
    mov ebx, [rank_i]
    mov ecx, [rank_indices+ebx*4]
    mov ebx, [rank_j]
    mov edx, [rank_indices+ebx*4]
    mov eax, [rank_usage+ecx*4]
    cmp eax, [rank_usage+edx*4]
    jae .rank_no_swap
    mov [rank_temp], ecx
    mov [rank_indices+ebx*4], ecx
    mov ebx, [rank_i]
    mov [rank_indices+ebx*4], edx
.rank_no_swap:
    inc dword [rank_j]
    jmp .rank_inner
.rank_next_outer:
    inc dword [rank_i]
    jmp .rank_outer
.rank_print_start:
    mov dword [rank_i], 0
.rank_print_loop:
    mov eax, [rank_i]
    cmp eax, [appliance_count]
    jae .rank_highest
    mov esi, rank_label
    call print_z
    mov eax, [rank_i]
    inc eax
    call print_uint
    mov esi, rank_id_label
    call print_z
    mov ebx, [rank_i]
    mov ecx, [rank_indices+ebx*4]
    mov eax, ecx
    imul eax, RECORD_SIZE
    lea edi, [appliances+eax]
    mov eax, [edi+OFF_ID]
    call print_uint
    mov esi, rank_name_label
    call print_z
    lea esi, [edi+OFF_NAME]
    call print_z
    mov esi, rank_usage_label
    call print_z
    mov eax, [rank_usage+ecx*4]
    call print_fixed
    mov esi, rank_share_label
    call print_z
    mov eax, [rank_usage+ecx*4]
    mov ebx, 10000
    mul ebx
    div dword [total_monthly]
    call print_fixed
    mov esi, percent_suffix
    call print_z
    inc dword [rank_i]
    jmp .rank_print_loop
.rank_highest:
    mov esi, highest_label
    call print_z
    mov ebx, [rank_indices]
    mov eax, ebx
    imul eax, RECORD_SIZE
    lea edi, [appliances+eax]
    lea esi, [edi+OFF_NAME]
    call print_z
    mov esi, newline
    call print_z
    ret

; -----------------------------------------------------------------------------
; energy_recommendations
; -----------------------------------------------------------------------------
energy_recommendations:
    mov esi, hdr_recommend
    call print_z
    cmp dword [appliance_count], 0
    jne .rec_start
    mov esi, empty_db
    call print_z
    ret
.rec_start:
    mov dword [loop_index], 0
    mov edi, appliances
.rec_loop:
    mov [current_ptr], edi
    mov esi, rec_device
    call print_z
    lea esi, [edi+OFF_NAME]
    call print_z
    mov esi, rec_watts
    call print_z
    mov eax, [edi+OFF_WATTS]
    call print_uint
    mov esi, rec_hours
    call print_z
    mov eax, [edi+OFF_HOURS]
    call print_uint
    mov esi, rec_monthly
    call print_z
    call calc_monthly
    mov [temp_value], eax
    call print_fixed
    mov esi, rec_kwh
    call print_z
    mov edi, [current_ptr]
    cmp dword [edi+OFF_WATTS], 1000
    jbe .rec_check_hours
    mov esi, rec_high_watts
    call print_z
.rec_check_hours:
    mov edi, [current_ptr]
    cmp dword [edi+OFF_HOURS], 12
    jbe .rec_check_usage
    mov esi, rec_long_hours
    call print_z
.rec_check_usage:
    mov eax, [temp_value]
    cmp eax, 10000
    ja .rec_high
    cmp eax, 5000
    jae .rec_moderate
    mov esi, rec_low
    call print_z
    jmp .rec_next
.rec_high:
    mov esi, rec_high_usage
    call print_z
    jmp .rec_next
.rec_moderate:
    mov esi, rec_moderate
    call print_z
.rec_next:
    inc dword [loop_index]
    mov edi, [current_ptr]
    add edi, RECORD_SIZE
    mov eax, [loop_index]
    cmp eax, [appliance_count]
    jb .rec_loop
    mov esi, general_tips
    call print_z
    ret
