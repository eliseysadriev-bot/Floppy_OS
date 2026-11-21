; FloCalendar - календарь: окно с одним месяцем, стрелки назад и вперёд, сегодня выделен
; Подключается из kernel32.asm (%include). Окно всегда поверх остальных, его можно таскать за заголовок
; Коды мыши: 169 размер, 172 крестик, 173 File, 174 Exit, 175 заголовок, 176 месяц назад, 177 месяц вперёд, 178 просто окно, 179 Help


cal_open:
    cmp byte [d2_cal], 0
    jne .r
    mov byte [d2_cal], 1
    mov dl, 8
    call fz_open_window
    mov byte [cal_menu], 0
    mov byte [cal_pr], 0
    mov byte [cal_min], 0
    call cal_today
    mov eax, [cal_tb + 12]
    mov [cal_vb + 12], eax
    mov eax, [cal_tb + 16]
    mov [cal_vb + 16], eax
.r: jmp redraw

cal_exit:
    cmp byte [hp_on], 7
    jne .nh
    mov byte [hp_on], 0
.nh:mov byte [cal_menu], 0
    mov byte [cal_pr], 0
    mov byte [cal_min], 0
    mov byte [d2_cal], 0
    jmp redraw

; Сегодняшняя дата с учётом часового пояса -> cal_tb (час, минута, день, месяц, год)
cal_today:
    pushad
    mov edi, cal_tb
    call rtc_get
    mov esi, cal_tb
    call cal_get_timezone
    call tz_apply
    cmp dword [cal_tb + 12], 1
    jae .m1
    mov dword [cal_tb + 12], 1
.m1:cmp dword [cal_tb + 12], 12
    jbe .m2
    mov dword [cal_tb + 12], 12
.m2:popad
    ret

; День недели первого числа месяца [cal_vb + 12] года [cal_vb + 16]: eax = 0 (понедельник) .. 6 (воскресенье)
cal_dow1:
    push ebx
    push ecx
    push edx
    push esi
    mov esi, [cal_vb + 16]
    mov ebx, [cal_vb + 12]
    cmp ebx, 3
    jae .a
    dec esi
.a: mov eax, esi
    mov edx, esi
    shr edx, 2
    add eax, edx
    push eax
    mov eax, esi
    xor edx, edx
    mov ecx, 100
    div ecx
    pop edx
    sub edx, eax
    push edx
    mov eax, esi
    xor edx, edx
    mov ecx, 400
    div ecx
    pop edx
    add edx, eax
    movzx eax, byte [cal_t + ebx - 1]
    add eax, edx
    inc eax
    xor edx, edx
    mov ecx, 7
    div ecx
    lea eax, [edx + 6]
    xor edx, edx
    div ecx
    mov eax, edx
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Прямоугольник внутри окна: eax, ebx - угол, ecx, edx - размер, цвет в r_c
cal_box:
    add eax, [cal_x]
    add ebx, [cal_y]
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    jmp fill_rect

cal_draw:
    pushad
    cmp byte [cal_min], 0
    je .expanded
    mov dword [cw_x], 0
    mov dword [cw_y], 0
    mov eax, 646
    mov ebx, 308
    mov ecx, 144
    mov edx, 36
    mov esi, s_cal_minimized
    xor edi, edi
    call wbtn
    jmp .finish
.expanded:
    call cal_today
    mov eax, [cal_x]
    mov [cw_x], eax
    mov eax, [cal_y]
    mov [cw_y], eax
    mov dword [r_c], C_BLACK
    mov eax, 8
    mov ebx, 8
    mov ecx, [cal_w]
    mov edx, [cal_h]
    call cal_box
    xor eax, eax
    xor ebx, ebx
    mov ecx, [cal_w]
    mov edx, [cal_h]
    call cal_box
    mov dword [r_c], C_WHITE
    mov eax, 2
    mov ebx, 2
    mov ecx, [cal_w]
    sub ecx, 4
    mov edx, [cal_h]
    sub edx, 4
    call cal_box
    mov dword [r_c], C_BLACK
    mov eax, 2
    mov ebx, 38
    mov ecx, [cal_w]
    sub ecx, 4
    mov edx, 2
    call cal_box
    mov eax, 2
    mov ebx, 78
    mov ecx, [cal_w]
    sub ecx, 4
    mov edx, 2
    call cal_box
    ; Same 16x16 black resize handle as FloCalc/FloClock.
    mov eax, [cal_w]
    sub eax, 18
    mov ebx, [cal_h]
    sub ebx, 18
    mov ecx, 16
    mov edx, 16
    call cal_box
    mov eax, [cal_w]                    ; заголовок по центру
    sub eax, 176
    shr eax, 1
    and eax, -8
    add eax, [cal_x]
    mov [t_x], eax
    mov eax, [cal_y]
    add eax, 4
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_cal_t
    call draw_big
    mov eax, [cal_x]
    add eax, [cal_w]
    sub eax, 32
    mov ebx, [cal_y]
    add ebx, 8
    mov al, 159
    call title_button_state
    mov eax, [cal_x]
    add eax, [cal_w]
    sub eax, 32
    mov ebx, [cal_y]
    add ebx, 8
    call xbtn
    mov al, 168
    call title_button_state
    mov eax, [cal_x]
    add eax, [cal_w]
    sub eax, 64
    mov ebx, [cal_y]
    add ebx, 8
    call mbtn
    mov dword [r_c], C_BLACK            ; File: тот же размер и надпись на той же высоте, что у Help
    mov eax, 4
    mov ebx, 42
    mov ecx, 80
    mov edx, 34
    call cal_box
    mov dword [r_c], C_WHITE
    mov esi, s_wm_file
    cmp byte [cal_menu], 0
    jne .ft
    mov eax, 6
    mov ebx, 44
    mov ecx, 76
    mov edx, 30
    call cal_box
    mov dword [r_c], C_BLACK
.ft:mov eax, [cal_x]
    add eax, 12
    mov [t_x], eax
    mov eax, [cal_y]
    add eax, 44
    mov [t_y], eax
    call draw_big
    ; Navigation controls: left / right month (always visible).
    mov dword [r_c], C_BLACK
    mov eax, 16
    mov ebx, 90
    mov ecx, 40
    mov edx, 40
    call cal_box
    mov eax, [cal_w]
    sub eax, 56
    mov ebx, 90
    mov ecx, 40
    mov edx, 40
    call cal_box
    mov dword [r_c], C_WHITE
    mov eax, 18
    mov ebx, 92
    mov ecx, 36
    mov edx, 36
    call cal_box
    mov eax, [cal_w]
    sub eax, 54
    mov ebx, 92
    mov ecx, 36
    mov edx, 36
    call cal_box
    mov dword [r_c], C_BLACK
    mov eax, [cal_x]
    add eax, 28
    mov [t_x], eax
    mov eax, [cal_y]
    add eax, 94
    mov [t_y], eax
    mov esi, s_cal_l
    call draw_big
    mov eax, [cal_x]
    add eax, [cal_w]
    sub eax, 44
    mov [t_x], eax
    mov eax, [cal_y]
    add eax, 94
    mov [t_y], eax
    mov esi, s_cal_r
    call draw_big
    mov eax, [cal_vb + 12]              ; "November 2026" по центру окна
    mov esi, [cal_mn + eax * 4 - 4]
    push esi
    call strlen
    pop esi
    mov [cal_tl], ecx
    lea eax, [ecx + 5]
    shl eax, 4
    neg eax
    add eax, [cal_w]
    shr eax, 1
    and eax, -2
    add eax, [cal_x]
    mov [cal_tx], eax
    mov [t_x], eax
    mov eax, [cal_y]
    add eax, 98
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    call draw_big
    mov edi, cal_nb
    mov eax, [cal_vb + 16]
    call u32str
    mov byte [edi], 0
    mov eax, [cal_tl]
    inc eax
    shl eax, 4
    add eax, [cal_tx]
    mov [t_x], eax
    mov eax, [cal_y]
    add eax, 98
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, cal_nb
    call draw_big
    call cal_dow1
    mov [cal_st], eax
    mov esi, cal_vb
    call tz_dim
    mov [cal_nd], eax
    ; Seven equal columns and up to six date rows. At the original
    ; 424x376 size this yields precisely the old 56x36 spacing.
    mov eax, [cal_w]
    sub eax, 32
    xor edx, edx
    mov ecx, 7
    div ecx
    mov [cal_step_x], eax
    mov eax, [cal_h]
    sub eax, 160                       ; 136 top offset + 24 bottom margin
    xor edx, edx
    mov ecx, 6
    div ecx
    mov [cal_step_y], eax
    mov dword [cal_d], 1
.dl:mov eax, [cal_d]                    ; числа месяца
    cmp eax, [cal_nd]
    ja .dn
    add eax, [cal_st]
    dec eax
    xor edx, edx
    mov ecx, 7
    div ecx
    mov ebx, eax
    imul ebx, dword [cal_step_y]
    add ebx, 136
    mov [cal_cy], ebx
    mov esi, edx
    imul esi, dword [cal_step_x]
    add esi, 16
    mov [cal_cx], esi
    mov dword [cal_tc], C_BLACK
    mov eax, [cal_d]
    cmp eax, [cal_tb + 8]
    jne .nt
    mov eax, [cal_vb + 12]
    cmp eax, [cal_tb + 12]
    jne .nt
    mov eax, [cal_vb + 16]
    cmp eax, [cal_tb + 16]
    jne .nt
    mov dword [r_c], C_BLACK            ; сегодня: чёрная клетка, белое число
    mov eax, [cal_cx]
    add eax, 2
    mov ebx, [cal_cy]
    add ebx, 2
    mov ecx, [cal_step_x]
    sub ecx, 4
    mov edx, [cal_step_y]
    sub edx, 4
    call cal_box
    mov dword [cal_tc], C_WHITE
.nt:mov edi, cal_nb
    mov eax, [cal_d]
    call u32str
    mov byte [edi], 0
    mov eax, [cal_step_x]
    cmp dword [cal_d], 10
    jae .two
    sub eax, 16
    jmp .px
.two:sub eax, 32
.px:shr eax, 1
    add eax, [cal_cx]
    add eax, [cal_x]
    mov [t_x], eax
    mov eax, [cal_cy]
    add eax, 2
    add eax, [cal_y]
    mov [t_y], eax
    mov eax, [cal_tc]
    mov [r_c], eax
    mov esi, cal_nb
    call draw_big
    inc dword [cal_d]
    jmp .dl
.dn:cmp byte [cal_menu], 0
    je .nm
    mov eax, [cal_x]
    mov ebx, [cal_y]
    sub ebx, 2
    call wm_menu
.nm:mov eax, [cal_x]
    mov ebx, [cal_y]
    mov ecx, 7
    call hp_win
.finish:
    popad
    ret

; Под мышью окно календаря? CF = 1: да, al = 169 (resize), 172..179; CF = 0: мимо окна
cal_hit:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    cmp byte [cal_min], 0
    je .expanded
    mov esi, [m_x]
    cmp esi, 646
    jb .no
    cmp esi, 790
    ja .no
    mov edi, [m_y]
    cmp edi, 308
    jb .no
    cmp edi, 344
    ja .no
    mov al, 166                         ; restore minimized FloCalendar
    jmp .y
.expanded:
    mov esi, [m_x]
    sub esi, [cal_x]
    jl .no
    mov edi, [m_y]
    sub edi, [cal_y]
    jl .no
    cmp esi, [cal_w]
    ja .no
    cmp edi, [cal_h]
    ja .no
    ; Bottom-right 16x16 resize square: unique hit ID 169.
    mov eax, [cal_w]
    sub eax, 18
    cmp esi, eax
    jb .not_resize
    mov eax, [cal_h]
    sub eax, 18
    cmp edi, eax
    jb .not_resize
    mov al, 169
    jmp .y
.not_resize:
    ; Frameless native minus: immediately left of the X in title row.
    cmp edi, 8
    jb .not_minus
    cmp edi, 30
    ja .not_minus
    mov eax, [cal_w]
    sub eax, 64
    cmp esi, eax
    jb .not_minus
    add eax, 24
    cmp esi, eax
    ja .not_minus
    mov al, 168
    jmp .y
.not_minus:
    cmp edi, 42                         ; Help
    jb .nh
    cmp edi, 76
    ja .nh
    cmp esi, 92
    jb .nh
    call hp_bw
    add ecx, 92
    cmp esi, ecx
    ja .nh
    mov al, 179
    jmp .y
.nh:mov eax, [cal_w]                    ; крестик
    sub eax, 32
    cmp esi, eax
    jb .a
    add eax, 24
    cmp esi, eax
    ja .a
    cmp edi, 8
    jb .a
    cmp edi, 30
    ja .a
    mov al, 159
    jmp .y
.a: add edi, 2                          ; File и Exit: у wm_file рамка выше на 2 точки
    mov dl, [cal_menu]
    call wm_hit
    sub edi, 2
    test al, al
    jz .b
    add al, 172
    jmp .y
.b: ; Month navigation buttons are in the month header row.
    cmp edi, 90
    jb .title
    cmp edi, 130
    jae .title
    cmp esi, 16
    jb .title
    cmp esi, 56
    jb .prev
    mov eax, [cal_w]
    sub eax, 56
    cmp esi, eax
    jb .title
    add eax, 40
    cmp esi, eax
    jae .title
    mov al, 177
    jmp .y
.prev:
    mov al, 176
    jmp .y
.title:
    cmp edi, 2                          ; заголовок
    jb .z
    cmp edi, 36
    ja .z
    mov eax, [cal_w]
    sub eax, 36
    cmp esi, eax
    ja .z
    cmp esi, 4
    jb .z
    mov al, 175
    jmp .y
.z: mov al, 178
.y: stc
    jmp .o
.no:clc
.o: pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Нажали мышью в календаре: al = 169 (resize), 172..179
cal_press:
    cmp al, 167
    jne .not_restore
    mov byte [cal_min], 0
    jmp redraw
.not_restore:
    cmp al, 168
    jne .not_minimize
    mov byte [cal_min], 1
    mov byte [cal_menu], 0
    jmp redraw
.not_minimize:
    cmp al, 179
    jne .nhp
    cmp byte [hp_on], 7                 ; Help: открывается и закрывается
    jne .ho
    mov byte [hp_on], 0
    jmp redraw
.ho:mov byte [cal_menu], 0
    mov byte [hp_on], 7
    jmp redraw
.nhp:
    cmp byte [hp_on], 7                 ; нажали мимо справки - она закрывается
    jne .nh2
    mov byte [hp_on], 0
    jmp redraw
.nh2:
    cmp al, 169                        ; resize with the existing shared drag engine
    jne .not_resize
    mov byte [cal_menu], 0
    mov bl, 6
    call cal_drag_context
    jmp drag_start
.not_resize:
    cmp al, 173
    jne .f1
    xor byte [cal_menu], 1
    jmp redraw
.f1:cmp al, 174
    je cal_exit
    cmp byte [cal_menu], 0              ; нажали мимо меню - оно закрывается
    je .f2
    mov byte [cal_menu], 0
    push eax
    call redraw
    pop eax
.f2:cmp al, 159
    je cal_exit
    cmp al, 176
    je .previous
    cmp al, 177
    je .next
    cmp al, 175
    jne .r
    mov bl, 1
    call cal_drag_context
    jmp drag_start
.previous:
    cmp dword [cal_vb + 12], 1
    jne .pm
    mov dword [cal_vb + 12], 12
    dec dword [cal_vb + 16]
    jmp redraw
.pm:dec dword [cal_vb + 12]
    jmp redraw
.next:
    cmp dword [cal_vb + 12], 12
    jne .nm
    mov dword [cal_vb + 12], 1
    inc dword [cal_vb + 16]
    jmp redraw
.nm:inc dword [cal_vb + 12]
    jmp redraw
.r: ret

; данные календаря
