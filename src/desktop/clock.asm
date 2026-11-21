; Окно Clock (FloClock.sys из flopsys/programs): стрелочные и электронные часы
; Подключается из kernel32.asm. Окно таскается за заголовок и растягивается за квадрат в углу (d_ctx = 7)
; Номера в hit: 236 крестик, 237 заголовок, 238 квадрат в углу, 239 внутри окна

; Закрыть окно Clock
ck_exit:
    mov byte [ck_menu], 0
    mov byte [d2_ck], 0
    jmp redraw

ck_open:
    mov byte [ck_menu], 0
    mov dl, 3
    call fz_top
    mov byte [d2_ck], 1
    mov dword [ck_ps], 0xFFFF
    jmp redraw

ck_box:
    add eax, [ck_x]
    add ebx, [ck_y]
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    jmp fill_rect

; Время из часов компьютера: ck_h, ck_m, ck_s
ck_rtc:
    pushad
.w: mov al, 0x0A
    out 0x70, al
    in al, 0x71
    test al, 0x80
    jnz .w
    mov al, 0x0B
    out 0x70, al
    in al, 0x71
    mov cl, al
    mov al, 4
    out 0x70, al
    in al, 0x71
    mov [ck_hr], al
    mov al, 2
    out 0x70, al
    in al, 0x71
    mov [ck_mi], al
    xor al, al
    out 0x70, al
    in al, 0x71
    mov [ck_se], al
    test cl, 4
    jnz .r
    mov al, [ck_hr]
    call bcd
    mov [ck_hr], al
    mov al, [ck_mi]
    call bcd
    mov [ck_mi], al
    mov al, [ck_se]
    call bcd
    mov [ck_se], al
.r: mov al, [ck_hr]
    call tz_hour
    mov [ck_hr], al
    popad
    ret

; Где стоят стрелки: ck_t_h, ck_t_m, ck_t_s (0..59)
ck_pos:
    pushad
    movzx eax, byte [ck_hr]
    xor edx, edx
    mov ecx, 12
    div ecx
    lea edx, [edx + edx * 4]
    movzx eax, byte [ck_mi]
    push edx
    xor edx, edx
    mov ecx, 12
    div ecx
    pop edx
    add eax, edx
    mov [ck_t_h], eax
    movzx eax, byte [ck_mi]
    mov [ck_t_m], eax
    movzx eax, byte [ck_se]
    mov [ck_t_s], eax
    popad
    ret

; Размеры циферблата и места: центр, радиус, электронные часы
ck_lay:
    pushad
    mov eax, [ck_w]
    imul eax, 3
    xor edx, edx
    mov ecx, 5
    div ecx
    mov [ck_fw], eax
    mov ebx, [ck_ht]
    sub ebx, 98
    cmp eax, ebx
    jbe .a
    mov eax, ebx
.a: shr eax, 1
    sub eax, 10
    mov [ck_r], eax
    mov eax, [ck_fw]
    shr eax, 1
    add eax, [ck_x]
    mov [ck_cx], eax
    mov eax, [ck_ht]
    sub eax, 82
    shr eax, 1
    add eax, [ck_y]
    add eax, 82
    mov [ck_cy], eax
    mov eax, [ck_r]
    imul eax, 50
    xor edx, edx
    mov ecx, 100
    div ecx
    mov [ck_lh], eax
    mov eax, [ck_r]
    imul eax, 75
    xor edx, edx
    div ecx
    mov [ck_lm], eax
    mov eax, [ck_r]
    imul eax, 88
    xor edx, edx
    div ecx
    mov [ck_ls], eax
    mov eax, [ck_w]
    sub eax, [ck_fw]
    sub eax, 128
    shr eax, 1
    add eax, [ck_fw]
    add eax, [ck_x]
    mov [ck_dx], eax
    mov eax, [ck_cy]
    sub eax, 16
    mov [ck_dy], eax
    popad
    ret

; Вектор стрелки: ecx = положение 0..59, ebx = длина -> eax = сдвиг по x, edx = сдвиг по y
ck_vec:
    push ecx
    push ebx
    push esi
    mov esi, ecx
    movsx eax, byte [ck_sin + esi]
    imul eax, ebx
    cdq
    mov ecx, 100
    idiv ecx
    push eax
    add esi, 15
    cmp esi, 60
    jb .a
    sub esi, 60
.a: movsx eax, byte [ck_sin + esi]
    imul eax, ebx
    cdq
    idiv ecx
    neg eax
    mov edx, eax
    pop eax
    pop esi
    pop ebx
    pop ecx
    ret

; Одна стрелка: ecx = положение, ebx = длина, esi = толщина, edi = цвет
ck_hand:
    pushad
    mov [ck_th], esi
    mov [ck_col], edi
    mov [ck_len], ebx
    mov [ck_t0], ecx
    xor ebp, ebp
.l: cmp ebp, [ck_len]
    ja .e
    mov ecx, [ck_t0]
    mov ebx, ebp
    call ck_vec
    add eax, [ck_cx]
    add edx, [ck_cy]
    mov esi, [ck_th]
    shr esi, 1
    sub eax, esi
    sub edx, esi
    mov [r_x], eax
    mov [r_y], edx
    mov eax, [ck_th]
    mov [r_w], eax
    mov [r_h], eax
    mov eax, [ck_col]
    mov [r_c], eax
    call fill_rect
    add ebp, 2
    jmp .l
.e: popad
    ret

; Все три стрелки: al = 1 нарисовать, 0 стереть (ck_t_h, ck_t_m, ck_t_s)
ck_hands:
    pushad
    mov [ck_mode], al
    mov edi, C_WHITE
    mov esi, C_WHITE
    test al, al
    jz .a
    mov edi, C_BLACK
    mov esi, C_BLUE
.a: mov [ck_c2], esi
    mov ecx, [ck_t_h]
    mov ebx, [ck_lh]
    mov esi, 6
    call ck_hand
    mov ecx, [ck_t_m]
    mov ebx, [ck_lm]
    mov esi, 4
    call ck_hand
    cmp byte [ck_mode], 0
    je .r
    mov eax, [ck_cx]
    sub eax, 4
    mov [r_x], eax
    mov eax, [ck_cy]
    sub eax, 4
    mov [r_y], eax
    mov dword [r_w], 8
    mov dword [r_h], 8
    mov dword [r_c], C_BLACK
    call fill_rect
.r: popad
    ret

; Квадрат 3 на 3 (или ck_sq) с центром eax, edx
ck_dot:
    pushad
    mov esi, [ck_sq]
    shr esi, 1
    sub eax, esi
    sub edx, esi
    mov [r_x], eax
    mov [r_y], edx
    mov eax, [ck_sq]
    mov [r_w], eax
    mov [r_h], eax
    mov dword [r_c], C_BLACK
    call fill_rect
    popad
    ret

; Кольцо циферблата и риски часов
ck_face:
    pushad
    mov dword [ck_sq], 4
    xor ebx, ebx                        ; x
    mov esi, [ck_r]                     ; y
    mov edi, 1
    sub edi, esi                        ; d
.c: mov eax, [ck_cx]
    add eax, ebx
    mov edx, [ck_cy]
    add edx, esi
    call ck_dot
    mov eax, [ck_cx]
    sub eax, ebx
    mov edx, [ck_cy]
    add edx, esi
    call ck_dot
    mov eax, [ck_cx]
    add eax, ebx
    mov edx, [ck_cy]
    sub edx, esi
    call ck_dot
    mov eax, [ck_cx]
    sub eax, ebx
    mov edx, [ck_cy]
    sub edx, esi
    call ck_dot
    mov eax, [ck_cx]
    add eax, esi
    mov edx, [ck_cy]
    add edx, ebx
    call ck_dot
    mov eax, [ck_cx]
    sub eax, esi
    mov edx, [ck_cy]
    add edx, ebx
    call ck_dot
    mov eax, [ck_cx]
    add eax, esi
    mov edx, [ck_cy]
    sub edx, ebx
    call ck_dot
    mov eax, [ck_cx]
    sub eax, esi
    mov edx, [ck_cy]
    sub edx, ebx
    call ck_dot
    cmp ebx, esi
    jae .t
    inc ebx
    test edi, edi
    jns .n
    lea edi, [edi + ebx * 2 + 1]
    jmp .c
.n: dec esi
    mov eax, ebx
    sub eax, esi
    lea edi, [edi + eax * 2 + 1]
    jmp .c
.t: xor ebp, ebp                        ; 12 рисок
.k: mov ecx, ebp
    imul ecx, 5
    mov dword [ck_sq], 4
    test ebp, 3
    jnz .s
    mov dword [ck_sq], 8
.s: mov ebx, [ck_r]
    sub ebx, 14
    call ck_vec
    add eax, [ck_cx]
    add edx, [ck_cy]
    call ck_dot
    inc ebp
    cmp ebp, 12
    jb .k
    popad
    ret

; Электронные часы ЧЧ:ММ:СС
ck_two:                                 ; al -> две цифры в [edi]
    xor ah, ah
    mov cl, 10
    div cl
    add al, '0'
    add ah, '0'
    mov [edi], al
    mov [edi + 1], ah
    ret

ck_digi:
    pushad
    mov eax, [ck_dx]
    sub eax, 6
    mov [r_x], eax
    mov eax, [ck_dy]
    sub eax, 4
    mov [r_y], eax
    mov dword [r_w], 140
    mov dword [r_h], 40
    mov dword [r_c], C_WHITE
    call fill_rect
    mov edi, ck_str
    mov al, [ck_hr]
    call ck_two
    mov edi, ck_str + 3
    mov al, [ck_mi]
    call ck_two
    mov edi, ck_str + 6
    mov al, [ck_se]
    call ck_two
    mov eax, [ck_dx]
    mov [t_x], eax
    mov eax, [ck_dy]
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, ck_str
    call draw_big
    popad
    ret

ck_draw:
    pushad
    call ck_rtc
    call ck_pos
    call ck_lay
    mov eax, [ck_x]
    mov [cw_x], eax
    mov eax, [ck_y]
    mov [cw_y], eax
    mov dword [r_c], C_BLACK
    mov eax, 8
    mov ebx, 8
    mov ecx, [ck_w]
    mov edx, [ck_ht]
    call ck_box
    xor eax, eax
    xor ebx, ebx
    call ck_box
    mov dword [r_c], C_WHITE
    mov eax, 2
    mov ebx, 2
    mov ecx, [ck_w]
    sub ecx, 4
    mov edx, [ck_ht]
    sub edx, 4
    call ck_box
    mov dword [r_c], C_BLACK
    mov eax, 2
    mov ebx, 40
    mov ecx, [ck_w]
    sub ecx, 4
    mov edx, 2
    call ck_box
    mov eax, 2
    mov ebx, 80
    mov ecx, [ck_w]
    sub ecx, 4
    mov edx, 2
    call ck_box
    mov eax, [ck_w]
    sub eax, 18
    mov ebx, [ck_ht]
    sub ebx, 18
    mov ecx, 16
    mov edx, 16
    call ck_box
    mov eax, [ck_w]
    sub eax, 80
    shr eax, 1
    and eax, -8
    add eax, [ck_x]
    mov [t_x], eax
    mov eax, [ck_y]
    add eax, 4
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_ckt
    call draw_big
    mov eax, [ck_x]
    add eax, [ck_w]
    sub eax, 32
    mov ebx, [ck_y]
    add ebx, 8
    xor edi, edi
    call xbtn
    call ck_face
    mov al, 1
    call ck_hands
    call ck_digi
    mov eax, [ck_t_h]
    mov [ck_ot_h], eax
    mov eax, [ck_t_m]
    mov [ck_ot_m], eax
    mov eax, [ck_t_s]
    mov [ck_ot_s], eax
    movzx eax, byte [ck_se]
    mov [ck_ps], eax
    mov eax, [ck_x]
    mov ebx, [ck_y]
    movzx edi, byte [ck_menu]
    call wm_file
    cmp byte [ck_menu], 0
    je .nm
    mov eax, [ck_x]
    mov ebx, [ck_y]
    call wm_menu
.nm:popad
    ret

; Раз в полсекунды: секунда сменилась - стереть старые стрелки, нарисовать новые
ck_tick:
    cmp byte [d2_ck], 0
    je .r
    cmp byte [ck_menu], 0               ; меню открыто - стрелки под ним не рисуем
    jne .r
    call fz_over_ck                     ; поверх часов другое окно или Tasks - не рисовать сквозь них
    jc .r
    cmp byte [d2_tm], 0
    jne .r
    cmp byte [d2_err], 0
    jne .r
    cmp byte [sv_who], 0
    jne .r
    cmp byte [drag], 0
    jne .r
    mov eax, [ticks]
    sub eax, [ck_tm]
    cmp eax, 9
    jb .r
    mov eax, [ticks]
    mov [ck_tm], eax
    pushad
    call ck_rtc
    movzx eax, byte [ck_se]
    cmp eax, [ck_ps]
    je .x
    mov [ck_ps], eax
    call cursor_hide
    call ck_lay
    call ck_pos
    mov eax, [ck_t_h]
    cmp eax, [ck_ot_h]
    jne .ch
    mov eax, [ck_t_m]
    cmp eax, [ck_ot_m]
    je .nh
.ch:mov eax, [ck_t_h]               ; стрелки сменили место: стереть старые, нарисовать новые
    push eax
    mov eax, [ck_t_m]
    push eax
    mov eax, [ck_ot_h]
    mov [ck_t_h], eax
    mov eax, [ck_ot_m]
    mov [ck_t_m], eax
    xor al, al
    call ck_hands
    pop eax
    mov [ck_t_m], eax
    pop eax
    mov [ck_t_h], eax
    mov [ck_ot_h], eax
    mov eax, [ck_t_m]
    mov [ck_ot_m], eax
    mov al, 1
    call ck_hands
.nh:
    call ck_digi
    call cursor_show
.x: popad
.r: ret

; Под мышью окно Clock? CF = 1: да, al = 236..239
ck_hit:
    push ebx
    push esi
    push edi
    mov esi, [m_x]
    sub esi, [ck_x]
    jl .no
    mov edi, [m_y]
    sub edi, [ck_y]
    jl .no
    mov eax, [ck_w]
    cmp esi, eax
    ja .no
    mov ebx, [ck_ht]
    cmp edi, ebx
    ja .no
    push eax
    mov dl, [ck_menu]
    call wm_hit                         ; кнопка File (223) и пункт Exit (224)
    test al, al
    jz .nw
    add al, 222
    add esp, 4
    jmp .y
.nw:pop eax
    sub eax, 18
    cmp esi, eax
    jb .a
    sub ebx, 18
    cmp edi, ebx
    jb .a
    mov al, 238
    jmp .y
.a: mov eax, [ck_w]
    sub eax, 32
    cmp esi, eax
    jb .b
    add eax, 24
    cmp esi, eax
    ja .b
    cmp edi, 8
    jb .b
    cmp edi, 30
    ja .b
    mov al, 236
    jmp .y
.b: cmp edi, 2
    jb .z
    cmp edi, 36
    ja .z
    mov eax, [ck_w]
    sub eax, 36
    cmp esi, eax
    ja .z
    cmp esi, 4
    jb .z
    mov al, 237
    jmp .y
.z: mov al, 239
.y: stc
    jmp .o
.no:clc
.o: pop edi
    pop esi
    pop ebx
    ret

ck_press:
    cmp al, 223                         ; File
    jne .f1
    xor byte [ck_menu], 1
    jmp redraw
.f1:cmp al, 224                         ; Exit в меню File
    jne .f2
    jmp ck_exit
.f2:cmp byte [ck_menu], 0               ; нажали мимо меню - оно закрывается
    je .f3
    mov byte [ck_menu], 0
    push eax
    call redraw
    pop eax
.f3:cmp al, 236
    jne .a
    mov byte [d2_ck], 0
    jmp redraw
.a: cmp al, 237
    jne .b
    mov bl, 1
    mov byte [d_ctx], 7
    jmp drag_start
.b: cmp al, 238
    jne .r
    mov bl, 6
    mov byte [d_ctx], 7
    jmp drag_start
.r: ret

d2_ck       db 0
ck_menu     db 0
ck_x        dd 140                      ; x, y, w, h подряд: swap_ctx таскает окно
ck_y        dd 100
ck_w        dd 560
ck_ht       dd 402
ck_hr       db 0
ck_mi       db 0
ck_se       db 0
ck_t_h      dd 0
ck_t_m      dd 0
ck_t_s      dd 0
ck_ot_h     dd 0
ck_ot_m     dd 0
ck_ot_s     dd 0
ck_ps       dd 0xFFFF
ck_tm       dd 0
ck_fw       dd 0
ck_r        dd 0
ck_cx       dd 0
ck_cy       dd 0
ck_lh       dd 0
ck_lm       dd 0
ck_ls       dd 0
ck_dx       dd 0
ck_dy       dd 0
ck_th       dd 0
ck_col      dd 0
ck_c2       dd 0
ck_len      dd 0
ck_t0       dd 0
ck_sq       dd 4
ck_mode     db 0
ck_str      db "00:00:00", 0
s_ckt       db "Clock", 0
ck_sin:
    db 0, 10, 21, 31, 41, 50, 59, 67, 74, 81
    db 87, 91, 95, 98, 99, 100, 99, 98, 95, 91
    db 87, 81, 74, 67, 59, 50, 41, 31, 21, 10
    db 0, -10, -21, -31, -41, -50, -59, -67, -74, -81
    db -87, -91, -95, -98, -99, -100, -99, -98, -95, -91
    db -87, -81, -74, -67, -59, -50, -41, -31, -21, -10
