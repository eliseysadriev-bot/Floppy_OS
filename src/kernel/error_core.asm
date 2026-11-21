; Floppy OS 2.0 error window. Codes encoded in d2_err as (section << 4) | number.
; Sections: 1 Boot, 2 Kernel, 3 FloFile, 4 Disks/FSM2/FSM3, 5 Apps.
; The error window is drawn by the kernel, not by Error4x*.sys modules.
core_err_raise:
    pushad
    mov byte [err_file_menu], 0
    mov [d2_err], al
    call redraw
    popad
    ret

core_err_draw:
    pushad
    push dword [cw_x]
    push dword [cw_y]
    mov dword [cw_x], 0
    mov dword [cw_y], 0
    MODRECT err_x, err_y, 4, 6, 264, 256, C_BLACK
    MODRECT err_x, err_y, 0, 0, 264, 256, C_BLACK
    MODRECT err_x, err_y, 2, 2, 260, 252, C_WHITE
    MODRECT err_x, err_y, 2, 40, 260, 2, C_BLACK
    mov eax, [err_x]
    mov ebx, [err_y]
    add ebx, 4
    mov edx, 264
    mov esi, sys_title_text
    call sys_modal_center
    mov al, 190
    call title_button_state
    mov eax, [err_x]
    add eax, 192
    mov ebx, [err_y]
    add ebx, 8
    call mbtn
    mov al, 192
    call title_button_state
    mov eax, [err_x]
    add eax, 224
    mov ebx, [err_y]
    add ebx, 8
    call xbtn
    mov eax, 2
    add eax, [err_x]
    mov [cw_x], eax
    mov eax, 2
    add eax, [err_y]
    mov [cw_y], eax
    movzx ebx, byte [d2_err]
    mov eax, ebx
    shr eax, 4
    cmp eax, 1
    jb .invalid
    cmp eax, 5
    ja .invalid
    mov [core_err_label + 6], al
    add byte [core_err_label + 6], '0'
    mov eax, ebx
    and eax, 15
    jz .invalid
    cmp eax, 10
    jb .one
    mov byte [core_err_label + 8], '1'
    sub al, 10
    add al, '0'
    mov [core_err_label + 9], al
    mov byte [core_err_label + 10], 0
    jmp .desc
.one:
    add al, '0'
    mov [core_err_label + 8], al
    mov byte [core_err_label + 9], 0
    jmp .desc
.invalid:
    mov byte [core_err_label + 6], '?'
    mov byte [core_err_label + 8], '?'
    mov byte [core_err_label + 9], 0
.desc:
    mov esi, core_err_label
    mov edx, [err_x]
    add edx, 2
    call core_err_center
    mov eax, [err_y]
    add eax, 100
    mov [t_y], eax
    call draw_big
    movzx ebx, byte [d2_err]
    mov eax, ebx
    shr eax, 4
    cmp eax, 5
    ja .unknown
    cmp eax, 1
    jb .unknown
    dec eax
    shl eax, 6
    and ebx, 15
    shl ebx, 2
    add eax, ebx
    mov esi, [core_err_en + eax]
    cmp byte [ui_ru], 0
    je .draw_msg
    mov esi, [core_err_ru + eax]
    jmp .draw_msg
.unknown:
    mov esi, core_err_unknown_en
    cmp byte [ui_ru], 0
    je .draw_msg
    mov esi, core_err_unknown_ru
.draw_msg:
    mov edx, [err_x]
    add edx, 2
    call core_err_center
    mov eax, [err_y]
    add eax, 144
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    call draw_big
    ; wbtn expects coordinates relative to cw_x/cw_y, just like the hit-test.
    ; Place Error's OK inside the dialog, not at absolute screen x=88, y=196.
    mov eax, [err_x]
    mov [cw_x], eax
    mov eax, [err_y]
    mov [cw_y], eax
    mov eax, 88
    mov ebx, 196
    mov ecx, 84
    mov edx, 34
    mov esi, core_err_ok
    push eax
    push edx
    mov al, 63
    mov dl, 7
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    mov eax, [err_x]
    mov ebx, [err_y]
    mov ecx, 264
    mov dl, [err_file_menu]
    call sys_file_draw
    pop dword [cw_y]
    pop dword [cw_x]
    popad
    ret

; Draw a centered 16x32 text line. EDX = left edge for 260px window.
core_err_center:
    call strlen
    shl ecx, 4
    mov eax, 260
    sub eax, ecx
    shr eax, 1
    add eax, edx
    mov [t_x], eax
    ret

; Restorable minimized error window indicator.
core_err_mini_draw:
    cmp byte [err_min_code], 0
    je .done
    pushad
    push dword [cw_x]
    push dword [cw_y]
    mov dword [cw_x], 0
    mov dword [cw_y], 0
    mov eax, 486
    mov ebx, 508
    mov ecx, 132
    mov edx, 36
    mov esi, core_err_title
    xor edi, edi
    call wbtn
    pop dword [cw_y]
    pop dword [cw_x]
    popad
.done:
    ret

err_x dd 268
err_y dd 220
err_w dd 264
err_h dd 256
err_min_code db 0
core_err_title db "Error ", 0
core_err_ok db "OK ", 0
core_err_minus db "-", 0
core_err_cross db "X", 0
core_err_label db "Error 0x00", 0
core_err_unknown_en db "Unknown error", 0
core_err_unknown_ru db 0xCE, 0xF8, 0xE8, 0xE1, 0xEA, 0xE0, 0x20, 0xED, 0xE5, 0xE8, 0xE7, 0xE2, 0xE5, 0xF1, 0xF2, 0xED, 0xE0, 0
core_err_en_1_1 db "Boot error", 0
core_err_ru_1_1 db 0xCE, 0xF8, 0xE8, 0xE1, 0xEA, 0xE0, 0x20, 0xE7, 0xE0, 0xE3, 0xF0, 0xF3, 0xE7, 0xEA, 0xE8, 0
core_err_en_1_2 db "Module missing", 0
core_err_ru_1_2 db 0xCD, 0xE5, 0xF2, 0x20, 0xEC, 0xEE, 0xE4, 0xF3, 0xEB, 0xFF, 0
core_err_en_2_1 db "System error", 0
core_err_ru_2_1 db 0xCE, 0xF8, 0xE8, 0xE1, 0xEA, 0xE0, 0x20, 0xF1, 0xE8, 0xF1, 0xF2, 0xE5, 0xEC, 0xFB, 0
core_err_en_3_1 db "System folder", 0
core_err_ru_3_1 db 0xD1, 0xE8, 0xF1, 0xF2, 0xE5, 0xEC, 0xED, 0xE0, 0xFF, 0x20, 0xEF, 0xE0, 0xEF, 0xEA, 0xE0, 0
core_err_en_3_2 db "System program", 0
core_err_ru_3_2 db 0xCF, 0xF0, 0xEE, 0xE3, 0xF0, 0xE0, 0xEC, 0xEC, 0xE0, 0x20, 0xCE, 0xD1, 0
core_err_en_3_3 db "System file", 0
core_err_ru_3_3 db 0xD1, 0xE8, 0xF1, 0xF2, 0xE5, 0xEC, 0xED, 0xFB, 0xE9, 0x20, 0xF4, 0xE0, 0xE9, 0xEB, 0
core_err_en_3_4 db "Name in use", 0
core_err_ru_3_4 db 0xC8, 0xEC, 0xFF, 0x20, 0xF3, 0xE6, 0xE5, 0x20, 0xE7, 0xE0, 0xED, 0xFF, 0xF2, 0xEE, 0
core_err_en_3_5 db "Folder not empty", 0
core_err_ru_3_5 db 0xCF, 0xE0, 0xEF, 0xEA, 0xE0, 0x20, 0xED, 0xE5, 0x20, 0xEF, 0xF3, 0xF1, 0xF2, 0xE0, 0
core_err_en_3_6 db "Operation failed", 0
core_err_ru_3_6 db 0xCE, 0xF8, 0xE8, 0xE1, 0xEA, 0xE0, 0x20, 0xEE, 0xEF, 0xE5, 0xF0, 0xE0, 0xF6, 0xE8, 0xE8, 0
core_err_en_4_1 db "Physical disk", 0
core_err_ru_4_1 db 0xD4, 0xE8, 0xE7, 0xE8, 0xF7, 0xE5, 0xF1, 0xEA, 0xE8, 0xE9, 0x20, 0xE4, 0xE8, 0xF1, 0xEA, 0
core_err_en_4_2 db "Format forbidden", 0
core_err_ru_4_2 db 0xD4, 0xEE, 0xF0, 0xEC, 0xE0, 0xF2, 0x20, 0xE7, 0xE0, 0xEF, 0xF0, 0xE5, 0xF9, 0xB8, 0xED, 0
core_err_en_4_3 db "Disk is full", 0
core_err_ru_4_3 db 0xC4, 0xE8, 0xF1, 0xEA, 0x20, 0xE7, 0xE0, 0xEF, 0xEE, 0xEB, 0xED, 0xE5, 0xED, 0
core_err_en_4_4 db "Disk I/O error", 0
core_err_ru_4_4 db 0xCE, 0xF8, 0xE8, 0xE1, 0xEA, 0xE0, 0x20, 0xE4, 0xE8, 0xF1, 0xEA, 0xE0, 0
core_err_en_4_5 db "Bad filesystem", 0
core_err_ru_4_5 db 0xCF, 0xEE, 0xE2, 0xF0, 0xE5, 0xE6, 0xE4, 0xE5, 0xED, 0xE0, 0x20, 0xD4, 0xD1, 0
core_err_en_5_1 db "Unknown symbol", 0
core_err_ru_5_1 db 0xCD, 0xE5, 0xE2, 0xE5, 0xF0, 0xED, 0xFB, 0xE9, 0x20, 0xE7, 0xED, 0xE0, 0xEA, 0
core_err_en_5_2 db "Empty expression", 0
core_err_ru_5_2 db 0xCF, 0xF3, 0xF1, 0xF2, 0xEE, 0xE5, 0x20, 0xE2, 0xFB, 0xF0, 0xE0, 0xE6, 0xE5, 0xED, 0xE8, 0xE5, 0
core_err_en_5_3 db "Division by zero", 0
core_err_ru_5_3 db 0xC4, 0xE5, 0xEB, 0xE5, 0xED, 0xE8, 0xE5, 0x20, 0xED, 0xE0, 0x20, 0xED, 0xEE, 0xEB, 0xFC, 0
core_err_en_5_4 db "Number too large", 0
core_err_ru_5_4 db 0xD1, 0xEB, 0xE8, 0xF8, 0xEA, 0xEE, 0xEC, 0x20, 0xE1, 0xEE, 0xEB, 0xFC, 0xF8, 0xEE, 0xE5, 0
core_err_en_5_5 db "Bad command", 0
core_err_ru_5_5 db 0xCD, 0xE5, 0xE2, 0xE5, 0xF0, 0xED, 0xE0, 0xFF, 0x20, 0xEA, 0xEE, 0xEC, 0xE0, 0xED, 0xE4, 0xE0, 0
core_err_en_5_6 db "Path not found", 0
core_err_ru_5_6 db 0xCF, 0xF3, 0xF2, 0xFC, 0x20, 0xED, 0xE5, 0x20, 0xED, 0xE0, 0xE9, 0xE4, 0xE5, 0xED, 0
core_err_en_5_7 db "File not found", 0
core_err_ru_5_7 db 0xD4, 0xE0, 0xE9, 0xEB, 0x20, 0xED, 0xE5, 0x20, 0xED, 0xE0, 0xE9, 0xE4, 0xE5, 0xED, 0
core_err_en_5_8 db "Access denied", 0
core_err_ru_5_8 db 0xCD, 0xE5, 0xF2, 0x20, 0xE4, 0xEE, 0xF1, 0xF2, 0xF3, 0xEF, 0xE0, 0
core_err_en_5_9 db "Drive not ready", 0
core_err_ru_5_9 db 0xC4, 0xE8, 0xF1, 0xEA, 0x20, 0xED, 0xE5, 0x20, 0xE3, 0xEE, 0xF2, 0xEE, 0xE2, 0
core_err_en_5_10 db "Name in use", 0
core_err_ru_5_10 db 0xC8, 0xEC, 0xFF, 0x20, 0xF3, 0xE6, 0xE5, 0x20, 0xE7, 0xE0, 0xED, 0xFF, 0xF2, 0xEE, 0
core_err_en_5_11 db "Cannot create", 0
core_err_ru_5_11 db 0xCD, 0xE5, 0xEB, 0xFC, 0xE7, 0xFF, 0x20, 0xF1, 0xEE, 0xE7, 0xE4, 0xE0, 0xF2, 0xFC, 0
core_err_en_5_12 db "Folder not empty", 0
core_err_ru_5_12 db 0xCF, 0xE0, 0xEF, 0xEA, 0xE0, 0x20, 0xED, 0xE5, 0x20, 0xEF, 0xF3, 0xF1, 0xF2, 0xE0, 0
core_err_en_5_13 db "Filename required", 0
core_err_ru_5_13 db 0xCD, 0xF3, 0xE6, 0xED, 0xEE, 0x20, 0xE8, 0xEC, 0xFF, 0x20, 0xF4, 0xE0, 0xE9, 0xEB, 0xE0, 0
core_err_en_5_14 db "Filename too long", 0
core_err_ru_5_14 db 0xD1, 0xEB, 0xE8, 0xF8, 0xEA, 0xEE, 0xEC, 0x20, 0xE4, 0xEB, 0xE8, 0xED, 0xED, 0xEE, 0xE5, 0x20, 0xE8, 0xEC, 0xFF, 0
core_err_en:
    dd core_err_unknown_en
    dd core_err_en_1_1
    dd core_err_en_1_2
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_en_2_1
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_en_3_1
    dd core_err_en_3_2
    dd core_err_en_3_3
    dd core_err_en_3_4
    dd core_err_en_3_5
    dd core_err_en_3_6
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_en_4_1
    dd core_err_en_4_2
    dd core_err_en_4_3
    dd core_err_en_4_4
    dd core_err_en_4_5
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_unknown_en
    dd core_err_en_5_1
    dd core_err_en_5_2
    dd core_err_en_5_3
    dd core_err_en_5_4
    dd core_err_en_5_5
    dd core_err_en_5_6
    dd core_err_en_5_7
    dd core_err_en_5_8
    dd core_err_en_5_9
    dd core_err_en_5_10
    dd core_err_en_5_11
    dd core_err_en_5_12
    dd core_err_en_5_13
    dd core_err_en_5_14
    dd core_err_unknown_en
core_err_ru:
    dd core_err_unknown_ru
    dd core_err_ru_1_1
    dd core_err_ru_1_2
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_ru_2_1
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_ru_3_1
    dd core_err_ru_3_2
    dd core_err_ru_3_3
    dd core_err_ru_3_4
    dd core_err_ru_3_5
    dd core_err_ru_3_6
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_ru_4_1
    dd core_err_ru_4_2
    dd core_err_ru_4_3
    dd core_err_ru_4_4
    dd core_err_ru_4_5
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_unknown_ru
    dd core_err_ru_5_1
    dd core_err_ru_5_2
    dd core_err_ru_5_3
    dd core_err_ru_5_4
    dd core_err_ru_5_5
    dd core_err_ru_5_6
    dd core_err_ru_5_7
    dd core_err_ru_5_8
    dd core_err_ru_5_9
    dd core_err_ru_5_10
    dd core_err_ru_5_11
    dd core_err_ru_5_12
    dd core_err_ru_5_13
    dd core_err_ru_5_14
    dd core_err_unknown_ru
