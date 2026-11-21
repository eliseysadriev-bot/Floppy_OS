; Floppy OS 2.0 - Shut Down button and confirmation dialog.
; The fourth desktop button is placed under Setting (not in Main).
; No filesystem writes are performed on shutdown.

power_button_draw:
    pushad
    RECT 40, 228, 180, 56, C_WHITE
    cmp byte [pressed], 4
    je .pressed
    CRECT 24, 118, 106, 140, C_BLACK, 2, 1, 1, 2
    CRECT 22, 116, 104, 138, C_BLACK, 2, 1, 1, 2
    CRECT 23, 117, 103, 137, C_WHITE, 1, 0, 0, 1
    mov esi, pw_title
    call strlen
    shl ecx, 3
    mov eax, 126
    sub eax, ecx
    mov [t_x], eax
    mov dword [t_y], 238
    mov dword [r_c], C_BLACK
    call draw_big
    jmp .done
.pressed:
    CRECT 24, 118, 106, 140, C_BLACK, 2, 1, 1, 2
    mov esi, pw_title
    call strlen
    shl ecx, 3
    mov eax, 130
    sub eax, ecx
    mov [t_x], eax
    mov dword [t_y], 242
    mov dword [r_c], C_WHITE
    call draw_big
.done:
    popad
    ret

 ; Confirmation dialog follows the system Save changes? dialog (sv_draw).
; Keep the window at (208,218); its height accommodates File, question and buttons.
; Standard wbtn draws the border, centers 16px text, and handles pressed state.
power_dialog_draw:
    pushad
    push dword [cw_x]
    push dword [cw_y]
    cmp byte [pw_min], 0
    je .expanded
    mov dword [cw_x], 0
    mov dword [cw_y], 0
    mov eax, 646
    mov ebx, 468
    mov ecx, 144
    mov edx, 36
    mov esi, pw_mini_title
    xor edi, edi
    call wbtn
    jmp .done
.expanded:
    MODRECT pw_x, pw_y, 6, 6, 390, 232, C_BLACK
    MODRECT pw_x, pw_y, 0, 0, 390, 232, C_BLACK
    MODRECT pw_x, pw_y, 2, 2, 386, 228, C_WHITE
    MODRECT pw_x, pw_y, 2, 40, 386, 2, C_BLACK
    mov eax, [pw_x]
    mov ebx, [pw_y]
    add ebx, 4
    mov edx, 390
    mov esi, sys_title_text
    call sys_modal_center
    mov eax, [pw_x]
    mov ebx, [pw_y]
    add ebx, 116
    mov edx, 390
    mov esi, pw_question
    call sys_modal_center

    ; Same frameless title controls as Main/About. Dark while pressed.
    xor edi, edi
    cmp byte [pw_down], 201
    jne .minus_normal
    mov edi, 1
.minus_normal:
    mov eax, [pw_x]
    add eax, 324
    mov ebx, [pw_y]
    add ebx, 8
    call mbtn
    xor edi, edi
    cmp byte [pw_down], 202
    jne .cross_normal
    mov edi, 1
.cross_normal:
    mov eax, [pw_x]
    add eax, 358
    mov ebx, [pw_y]
    add ebx, 8
    call xbtn
    mov eax, [pw_x]
    mov [cw_x], eax
    mov eax, [pw_y]
    mov [cw_y], eax
    mov eax, 26
    mov ebx, 172
    mov ecx, 160
    mov edx, 40
    xor edi, edi
    cmp byte [pw_down], 180
    jne .draw_off
    mov edi, 1
.draw_off:
    mov esi, pw_ok
    call wbtn

    mov eax, 202
    mov ebx, 172
    mov ecx, 160
    mov edx, 40
    xor edi, edi
    cmp byte [pw_down], 181
    jne .draw_cancel
    mov edi, 1
.draw_cancel:
    mov esi, pw_cancel
    call wbtn
    mov eax, [pw_x]
    mov ebx, [pw_y]
    mov ecx, 390
    mov dl, [pw_file_menu]
    call sys_file_draw
.done:
    pop dword [cw_y]
    pop dword [cw_x]
    popad
    ret

; Relative hit zones in the original 390x176 dialog.
power_dialog_hit:
    cmp byte [pw_min], 0
    je .expanded
    xor al, al
    cmp edx, 646
    jb .none
    cmp edx, 790
    ja .none
    cmp ecx, 468
    jb .none
    cmp ecx, 504
    ja .none
    mov al, 203                         ; restore
    ret
.expanded:
    mov esi, edx
    sub esi, [pw_x]
    js .none
    mov edi, ecx
    sub edi, [pw_y]
    js .none
    xor al, al
    cmp esi, 390
    ja .done
    cmp edi, 232
    ja .done
    mov dl, [pw_file_menu]
    call sys_file_hit
    test al, al
    jnz .done
    ; Title buttons are tested before dragging the header.
    cmp edi, 6
    jb .buttons
    cmp edi, 38
    ja .buttons
    cmp esi, 320
    jb .drag_title
    cmp esi, 350
    jbe .min_button
    cmp esi, 354
    jb .buttons
    cmp esi, 384
    jbe .close_button
    jmp .buttons
.min_button:
    mov al, 201
    ret
.close_button:
    mov al, 202
    ret
.drag_title:
    cmp edi, 8
    jb .buttons
    cmp edi, 80
    ja .buttons
    cmp esi, 8
    jb .buttons
    cmp esi, 382
    ja .buttons
    mov al, 200
    ret
.buttons:
    cmp edi, 172
    jb .done
    cmp edi, 212
    ja .done
    cmp esi, 26
    jb .done
    cmp esi, 186
    ja .cancel
    mov al, 180
    ret
.cancel:
    cmp esi, 202
    jb .done
    cmp esi, 362
    ja .done
    mov al, 181
.done:
    ret
.none:
    xor al, al
    ret

; QEMU/Bochs legacy ACPI shutdown. Real PCs may need ACPI FADT/S5
; discovery, which is NOT implemented here. Fall back to a halted screen.
power_off:
    call bs_shutdown                    ; отдельный экран, часы, 1.5 секунды
    cli
    mov dx, 0x604
    mov ax, 0x2000
    out dx, ax
    mov dx, 0xB004
    out dx, ax
    mov dx, 0x4004
    mov ax, 0x3400
    out dx, ax
    ; If power was not cut, stop the operating system safely.
    RECT 0, 0, 800, 600, C_BLACK
    mov dword [r_c], C_WHITE
    mov dword [t_x], 80
    mov dword [t_y], 270
    mov esi, pw_manual
    call draw_big
.halt:
    hlt
    jmp .halt

pw_x        dd 208
pw_y        dd 218
pw_w        dd 390
pw_h        dd 232
pw_file_menu db 0
pw_title    db "Shut Down", 0
pw_ok       db "Ok", 0
pw_minus    db "-", 0
pw_cross    db "X", 0
pw_mini_title db "Power", 0
pw_cancel   db "Cancel", 0
pw_question db "Shut down computer?", 0
pw_manual   db "You can now turn off your computer.", 0
