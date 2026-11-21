; Окно Settings (кнопка Settings на рабочем столе под кнопкой About): цвет стола, цвет и размер курсора, часы
; Подключается из kernel32.asm (%include)
; Окно таскается за заголовок (d_ctx = 6)

; Номера в hit: 245 крестик, 246 заголовок, 247 внутри окна, 254 квадрат в углу (размер окна), 248/249 цвет стола - и +, 250/251 цвет курсора - и +,
; 252 ползунок размера курсора, 253 кнопка часов
; Строки окна: верх 64, 120, 176, 232 (от верха окна); кнопки начинаются на 216 правее левого края

ST_X0   equ 232

; Настройки лежат в секторе ST_SECT главного диска: цвет стола, цвет курсора, размер курсора, часы
ST_SECT equ 482

st_save:
    pushad
    push dword [cur_drive]
    push dword [cur_base]
    push dword [cur_size]
    mov edi, IST_DIR
    xor eax, eax
    mov ecx, 128
    cld
    rep stosd
    mov edi, IST_DIR
    mov dword [edi], 'SETG'
    mov al, [dk_theme]
    mov [edi + 4], al
    mov al, [cu_theme]
    mov [edi + 5], al
    mov al, [cu_scale]
    mov [edi + 6], al
    mov al, [clk_on]
    mov [edi + 7], al
    mov al, [ui_ru]
    mov [edi + 8], al
    mov al, [tz_off]
    mov [edi + 9], al
    mov al, [kb_ru]
    mov [edi + 10], al
    mov al, [wl_hidden]
    mov [edi + 11], al           ; Welcome preference, no separate file
    mov al, [pan_height]
    mov [edi + 12], al           ; bottom panel height, persistent
    mov eax, ST_SECT
    mov dl, [sys_dsk]
    mov ebx, IST_DIR
    call ist_wr
    call ata_flush
    pop dword [cur_size]
    pop dword [cur_base]
    pop dword [cur_drive]
    popad
    ret

; При запуске: взять сохранённые настройки, если они есть
st_load:
    pushad
    push dword [cur_drive]
    push dword [cur_base]
    push dword [cur_size]
    mov eax, ST_SECT
    mov dl, [sys_dsk]
    mov ebx, IST_DIR
    call ist_rd
    jc .r
    mov esi, IST_DIR
    cmp dword [esi], 'SETG'
    jne .r
    cmp byte [esi + 4], 3
    ja .r
    cmp byte [esi + 5], 3
    ja .r
    movzx eax, byte [esi + 6]
    cmp eax, 1
    jb .r
    cmp eax, 4
    ja .r
    cmp byte [esi + 7], 1
    ja .r
    cmp byte [esi + 8], 1
    ja .r
    movsx eax, byte [esi + 9]
    cmp eax, -12
    jl .r
    cmp eax, 14
    jg .r
    cmp byte [esi + 10], 1
    ja .r
    mov al, [esi + 8]
    mov [ui_ru], al
    mov al, [esi + 9]
    mov [tz_off], al
    mov al, [esi + 10]
    mov [kb_ru], al
    cmp byte [esi + 11], 1
    ja .legacy_welcome
    mov al, [esi + 11]
    mov [wl_hidden], al
.legacy_welcome:
    mov al, [esi + 12]
    cmp al, 64
    jb .old_panel
    cmp al, 150
    ja .old_panel
    mov [pan_height], al
.old_panel:
    mov al, [esi + 4]
    mov [dk_theme], al
    mov al, [esi + 5]
    mov [cu_theme], al
    movzx eax, byte [esi + 6]
    mov [cu_scale], eax
    mov al, [esi + 7]
    mov [clk_on], al
    call pal_theme
.r: pop dword [cur_size]
    pop dword [cur_base]
    pop dword [cur_drive]
    popad
    ret

st_open:
    mov dl, 2
    call fz_top
    mov byte [d2_st], 1
    mov byte [st_menu], 0
    jmp redraw

st_exit:
    mov byte [st_menu], 0
    mov byte [d2_st], 0
    jmp redraw

; Прямоугольник внутри окна: eax, ebx - угол, ecx, edx - размер, цвет в r_c
st_box:
    add eax, [st_x]
    add ebx, [st_y]
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    jmp fill_rect

; Подпись esi в строке ebx (от верха окна)
st_label:
    mov eax, [st_x]
    add eax, 16
    mov [t_x], eax
    mov eax, [st_y]
    add eax, ebx
    add eax, 2
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    jmp draw_big

; Расстояние между строками (от верха окна 48): зависит от высоты окна -> eax
st_pitch:
    mov eax, [st_h]
    sub eax, 136
    shr eax, 2
    and eax, -2
    ret

; Верх строки eax (0..3) -> eax
st_rowy:
    push edx
    mov edx, eax
    call st_pitch
    imul eax, edx
    add eax, 132
    pop edx
    ret

; Строка выбора цвета: [sk_y] - верх строки (сверху подпись, ниже кнопки), [sk_idx] - какой цвет,
; [sk_pal] - номер цвета в палитре, [sk_nm] - имена (по 8 байт), [sk_lb] - подпись
st_pick:
    pushad
    mov ebx, [sk_y]
    mov esi, [sk_lb]
    call st_label
    mov eax, 16
    mov ebx, [sk_y]
    add ebx, 36
    mov ecx, 40
    mov edx, 36
    mov esi, s_lt
    xor edi, edi
    call wbtn
    mov eax, 108
    mov ebx, [sk_y]
    add ebx, 36
    mov ecx, 40
    mov edx, 36
    mov esi, s_gt
    xor edi, edi
    call wbtn
    mov dword [r_c], C_BLACK            ; цвет в рамке
    mov eax, 62
    mov ebx, [sk_y]
    add ebx, 36
    mov ecx, 42
    mov edx, 36
    call st_box
    mov eax, [sk_pal]
    mov [r_c], eax
    mov eax, 64
    mov ebx, [sk_y]
    add ebx, 38
    mov ecx, 38
    mov edx, 32
    call st_box
    mov eax, [st_x]                     ; название цвета
    add eax, 160
    mov [t_x], eax
    mov eax, [st_y]
    add eax, [sk_y]
    add eax, 38
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, [sk_idx]
    shl esi, 3
    add esi, [sk_nm]
    call draw_big
    popad
    ret

st_draw:
    pushad
    mov eax, [st_x]
    mov [cw_x], eax
    mov eax, [st_y]
    mov [cw_y], eax
    mov dword [r_c], C_BLACK
    mov eax, 8
    mov ebx, 8
    mov ecx, [st_w]
    mov edx, [st_h]
    call st_box
    xor eax, eax
    xor ebx, ebx
    call st_box
    mov dword [r_c], C_WHITE
    mov eax, 2
    mov ebx, 2
    mov ecx, [st_w]
    sub ecx, 4
    mov edx, [st_h]
    sub edx, 4
    call st_box
    mov dword [r_c], C_BLACK
    mov eax, 2
    mov ebx, 40
    mov ecx, [st_w]
    sub ecx, 4
    mov edx, 2
    call st_box
    mov eax, 2
    mov ebx, 80
    mov ecx, [st_w]
    sub ecx, 4
    mov edx, 2
    call st_box
    mov eax, [st_w]
    sub eax, 18                         ; чёрный квадрат: за него растягивают окно
    mov ebx, [st_h]
    sub ebx, 18
    mov ecx, 16
    mov edx, 16
    call st_box
    mov eax, [st_w]                     ; заголовок по центру
    sub eax, 160
    shr eax, 1
    and eax, -8
    add eax, [st_x]
    mov [t_x], eax
    mov eax, [st_y]
    add eax, 4
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_settings
    call draw_big
    mov eax, [st_x]
    add eax, [st_w]
    sub eax, 32
    mov ebx, [st_y]
    add ebx, 8
    mov al, 245
    call title_button_state
    mov eax, [st_x]
    add eax, [st_w]
    sub eax, 32
    mov ebx, [st_y]
    add ebx, 8
    call xbtn
    mov eax, 16                         ; вкладки
    mov ebx, 88
    mov ecx, 88
    mov edx, 36
    mov esi, s_tab0
    xor edi, edi
    cmp byte [st_sec], 0
    jne .v0
    inc edi
.v0:call wbtn
    mov eax, 112
    mov ecx, 208
    mov esi, s_tab1
    xor edi, edi
    cmp byte [st_sec], 1
    jne .v1
    inc edi
.v1:call wbtn
    mov eax, 328
    mov ecx, 120
    mov esi, s_tab2
    xor edi, edi
    cmp byte [st_sec], 2
    jne .v2
    inc edi
.v2:call wbtn
    cmp byte [st_sec], 2
    je .rg
    cmp byte [st_sec], 0
    jne .tm
    xor eax, eax                        ; цвет рабочего стола
    call st_rowy
    mov [sk_y], eax
    movzx eax, byte [dk_theme]
    mov [sk_idx], eax
    mov dword [sk_pal], 3
    mov dword [sk_nm], dk_names
    mov dword [sk_lb], s_st_desk
    call st_pick
    mov eax, 1                          ; цвет курсора
    call st_rowy
    mov [sk_y], eax
    movzx eax, byte [cu_theme]
    mov [sk_idx], eax
    mov dword [sk_pal], 5
    mov dword [sk_nm], cu_names
    mov dword [sk_lb], s_st_ccol
    call st_pick
    mov eax, 2                          ; размер курсора
    call st_rowy
    mov ebx, eax
    mov esi, s_st_csize
    call st_label
    call st_slider
    mov eax, 3                          ; часы
    call st_rowy
    mov ebx, eax
    push ebx
    mov esi, s_st_clock
    call st_label
    pop ebx
    add ebx, 36
    mov esi, s_off
    movzx edi, byte [clk_on]
    test edi, edi
    jz .c1
    mov esi, s_on
.c1:mov eax, 16
    mov ecx, 120
    mov edx, 36
    call wbtn
    call st_menudraw
    popad
    ret
.rg:                                    ; вкладка Region: язык, раскладка, часовой пояс
    mov ebx, 132
    mov esi, s_st_lang
    call st_label
    mov ebx, 168
    mov esi, s_lang_en
    cmp byte [ui_ru], 0
    je .g1
    mov esi, s_lang_ru
.g1:mov eax, 16
    mov ecx, 136
    mov edx, 36
    xor edi, edi
    call wbtn
    mov ebx, 204
    mov esi, s_st_lay
    call st_label
    mov ebx, 240
    mov esi, s_kb_en
    cmp byte [kb_ru], 0
    je .g2
    mov esi, s_kb_ru
.g2:mov eax, 16
    mov ecx, 136
    mov edx, 36
    xor edi, edi
    call wbtn
    mov ebx, 276
    mov esi, s_st_tz
    call st_label
    mov ebx, 312
    mov eax, 16
    mov ecx, 40
    mov edx, 36
    mov esi, s_lt
    xor edi, edi
    call wbtn
    mov eax, 196
    mov esi, s_gt
    call wbtn
    mov dword [r_c], C_BLACK            ; поле с поясом
    mov eax, 62
    mov ebx, 312
    mov ecx, 128
    mov edx, 36
    call st_box
    mov dword [r_c], C_WHITE
    mov eax, 64
    mov ebx, 314
    mov ecx, 124
    mov edx, 32
    call st_box
    call tz_fmt
    mov esi, tz_buf
    call strlen
    shl ecx, 4
    mov eax, 128
    sub eax, ecx
    shr eax, 1
    add eax, 62
    add eax, [st_x]
    mov [t_x], eax
    mov eax, [st_y]
    add eax, 316
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, tz_buf
    call draw_big
    call st_menudraw
    popad
    ret
.tm:xor ebp, ebp
.tl:imul ebx, ebp, 52
    add ebx, 136
    push ebx
    mov esi, [dt_lab + ebp * 4]
    call st_label
    pop ebx
    mov eax, 200
    mov ecx, 40
    mov edx, 36
    mov esi, s_lt
    xor edi, edi
    call wbtn
    mov eax, 340
    mov esi, s_gt
    call wbtn
    mov [sk_y], ebx
    mov dword [r_c], C_BLACK            ; поле со значением
    mov eax, 250
    mov ecx, 80
    mov edx, 36
    call st_box
    mov dword [r_c], C_WHITE
    mov eax, 252
    mov ebx, [sk_y]
    add ebx, 2
    mov ecx, 76
    mov edx, 32
    call st_box
    mov eax, [dt_h + ebp * 4]           ; число в строку: 2 цифры, у года 4
    mov edi, 2
    cmp ebp, 4
    jne .d2
    mov edi, 4
.d2:mov byte [dt_buf + edi], 0
    mov ecx, edi
    mov esi, 10
.dl:xor edx, edx
    div esi
    add dl, '0'
    mov [dt_buf + ecx - 1], dl
    dec ecx
    jnz .dl
    mov eax, 80                         ; по центру поля
    mov ecx, edi
    shl ecx, 4
    sub eax, ecx
    shr eax, 1
    add eax, 250
    add eax, [st_x]
    mov [t_x], eax
    imul eax, ebp, 52
    add eax, 138
    add eax, [st_y]
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, dt_buf
    call draw_big
    inc ebp
    cmp ebp, 5
    jb .tl
    call st_menudraw
    popad
    ret

; Кнопка File и меню с Exit поверх всего
st_menudraw:
    pushad
    mov eax, [st_x]
    mov ebx, [st_y]
    movzx edi, byte [st_menu]
    call wm_file
    cmp byte [st_menu], 0
    je .r
    mov eax, [st_x]
    mov ebx, [st_y]
    call wm_menu
.r: popad
    ret

; Ползунок размера курсора как в FloPaint, только крупнее: линия и ручка; число справа. Тянется на всю ширину окна
st_slider:
    pushad
    mov eax, 2
    call st_rowy
    add eax, 36
    mov [sk_y], eax                     ; верх полосы ползунка
    mov dword [r_c], C_WHITE
    mov eax, 4
    mov ebx, [sk_y]
    sub ebx, 2
    mov ecx, [st_w]
    sub ecx, 8
    mov edx, 40
    call st_box
    mov dword [r_c], C_BLACK
    mov eax, 16
    mov ebx, [sk_y]
    add ebx, 15
    mov ecx, [st_w]
    sub ecx, 80
    mov edx, 6
    call st_box
    mov ecx, [st_w]                     ; ход ручки: длина линии - ширина ручки
    sub ecx, 96
    mov eax, [cu_scale]
    dec eax
    imul eax, ecx
    xor edx, edx
    mov ecx, 3
    div ecx
    add eax, 16
    push eax
    mov dword [r_c], C_BLACK
    mov ebx, [sk_y]
    add ebx, 2
    mov ecx, 16
    mov edx, 32
    call st_box
    pop eax
    add eax, 2
    mov dword [r_c], C_WHITE
    mov ebx, [sk_y]
    add ebx, 4
    mov ecx, 12
    mov edx, 28
    call st_box
    mov eax, [cu_scale]
    add al, '0'
    mov [st_num], al
    mov eax, [st_x]
    add eax, [st_w]
    sub eax, 48
    mov [t_x], eax
    mov eax, [st_y]
    add eax, [sk_y]
    add eax, 2
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, st_num
    call draw_big
    popad
    ret

; Ручку тянут (или нажали на линию): размер 1..4 из положения мыши
st_slset:
    pushad
    mov ebp, [st_w]
    sub ebp, 96                         ; ход ручки
    mov eax, [m_x]
    sub eax, [st_x]
    sub eax, 24
    jge .a
    xor eax, eax
.a: cmp eax, ebp
    jbe .b
    mov eax, ebp
.b: shl eax, 2
    xor edx, edx
    lea ecx, [ebp + 1]
    div ecx
    inc eax
    cmp eax, [cu_scale]
    je .r
    mov [cu_scale], eax
    call st_save
    call st_slider
.r: popad
    ret

; Под мышью окно Settings? CF = 1: да, al = 245..254; CF = 0: мимо окна
st_hit:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov esi, [m_x]
    sub esi, [st_x]
    jl .no
    mov edi, [m_y]
    sub edi, [st_y]
    jl .no
    cmp esi, [st_w]
    ja .no
    cmp edi, [st_h]
    ja .no
    mov eax, [st_w]                     ; квадрат в углу
    sub eax, 18
    cmp esi, eax
    jb .nc
    mov eax, [st_h]
    sub eax, 18
    cmp edi, eax
    jb .nc
    mov al, 254
    jmp .y
.nc:cmp edi, 40
    jae .rows
    mov eax, [st_w]                     ; крестик
    sub eax, 32
    cmp esi, eax
    jb .t
    add eax, 24
    cmp esi, eax
    ja .t
    cmp edi, 8
    jb .t
    cmp edi, 30
    ja .t
    mov al, 245
    jmp .y
.t: cmp edi, 2
    jb .in
    mov eax, [st_w]
    sub eax, 36
    cmp esi, eax
    ja .in
    cmp esi, 4
    jb .in
    mov al, 246
    jmp .y
.rows:
    mov dl, [st_menu]
    call wm_hit                         ; File (158) и Exit (167)
    test al, al
    jz .nf
    cmp al, 1
    mov al, 158
    je .y
    mov al, 167
    jmp .y
.nf:cmp edi, 88                         ; полоса вкладок
    jb .in
    cmp edi, 124
    ja .rw
    mov bl, 1
    cmp esi, 16
    jb .in
    cmp esi, 104
    jbe .tb
    mov bl, 2
    cmp esi, 112
    jb .in
    cmp esi, 320
    jbe .tb
    mov bl, 3
    cmp esi, 328
    jb .in
    cmp esi, 448
    ja .in
.tb:mov [st_sub], bl
    mov al, 255
    jmp .y
.rw:cmp byte [st_sec], 1
    je .tmr
    ja .rgr
    call st_pitch
    mov ecx, eax
    mov eax, edi
    sub eax, 132
    jl .in
    xor edx, edx
    div ecx
    sub edx, 36                         ; кнопки и ползунок - нижние 36 точек строки
    jl .in
    cmp edx, 36
    jae .in
    cmp eax, 2
    je .sl
    ja .ck
    lea ebx, [eax * 2 + 248]
    cmp esi, 16
    jb .in
    cmp esi, 56
    jbe .id
    cmp esi, 108
    jb .in
    cmp esi, 148
    ja .in
    inc ebx
.id:mov eax, ebx
    jmp .y
.tmr:                                   ; раздел Time & date: пять строк по 52, кнопки < и > в нижних 36
    mov eax, edi
    sub eax, 136
    jl .in
    xor edx, edx
    mov ecx, 52
    div ecx
    cmp eax, 4
    ja .in
    cmp edx, 36
    jae .in
    lea ebx, [eax * 2 + 10]
    cmp esi, 200
    jb .in
    cmp esi, 240
    jbe .tbt
    cmp esi, 340
    jb .in
    cmp esi, 380
    ja .in
    inc ebx
.tbt:
    mov [st_sub], bl
    mov al, 255
    jmp .y
.sl:cmp esi, 16
    jb .in
    mov eax, [st_w]
    sub eax, 64
    cmp esi, eax
    ja .in
    mov al, 252
    jmp .y
.ck:cmp eax, 3
    ja .in
    cmp esi, 16
    jb .in
    cmp esi, 136
    ja .in
    mov al, 253
    jmp .y
.rgr:                                   ; вкладка Region: строки по 72, кнопки в нижних 36
    mov eax, edi
    sub eax, 132
    jl .in
    xor edx, edx
    mov ecx, 72
    div ecx
    sub edx, 36
    jl .in
    cmp eax, 2
    ja .in
    je .rgz
    cmp esi, 16
    jb .in
    cmp esi, 152
    ja .in
    mov bl, 124
    test eax, eax
    jz .rgy
    mov bl, 125
.rgy:mov al, bl
    jmp .y
.rgz:cmp esi, 16
    jb .in
    cmp esi, 56
    jbe .zm
    cmp esi, 196
    jb .in
    cmp esi, 236
    ja .in
    mov al, 141
    jmp .y
.zm:mov al, 139
    jmp .y
.in:mov al, 247
.y: stc
    jmp .o
.no:clc
.o: pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Нажали мышью в окне Settings: al - что
st_press:
    cmp al, 124                         ; Region: язык, раскладка, пояс - и +
    je .rg1
    cmp al, 125
    je .rg1
    cmp al, 139
    je .rg1
    cmp al, 141
    jne .f0
.rg1:
    mov byte [st_menu], 0
    cmp al, 124
    jne .r2
    xor byte [ui_ru], 1
    jmp .rgs
.r2:cmp al, 125
    jne .r3
    xor byte [kb_ru], 1
    jmp .rgs
.r3:movsx edx, byte [tz_off]
    cmp al, 141
    je .r4
    dec edx
    cmp edx, -12
    jge .r5
    mov edx, 14
    jmp .r5
.r4:inc edx
    cmp edx, 14
    jle .r5
    mov edx, -12
.r5:mov [tz_off], dl
    mov word [clk_v], 0xFFFF
.rgs:
    call st_save
    jmp redraw
.f0:cmp al, 158
    jne .f1
    xor byte [st_menu], 1
    jmp redraw
.f1:cmp al, 167
    je st_exit
    cmp byte [st_menu], 0               ; нажали мимо меню - оно закрывается
    je .f2
    mov byte [st_menu], 0
    push eax
    call redraw
    pop eax
.f2:cmp al, 245
    jne .a
    mov byte [d2_st], 0
    jmp redraw
.a: cmp al, 246
    jne .b
    mov bl, 1
    mov byte [d_ctx], 6
    jmp drag_start
.b: cmp al, 248
    jb .r
    cmp al, 249
    ja .c
    mov dl, -1
    cmp al, 248
    je .b1
    mov dl, 1
.b1:add [dk_theme], dl
    and byte [dk_theme], 3
    call pal_theme
    call st_save
    jmp st_draw
.c: cmp al, 251
    ja .d
    mov dl, 1
    cmp al, 251
    je .c1
    mov dl, -1
.c1:add [cu_theme], dl
    and byte [cu_theme], 3
    call pal_theme
    call st_save
    jmp st_draw
.d: cmp al, 252
    jne .e
    mov byte [sb_drag], 18
    mov byte [sb_ctx], 4
    jmp st_slset
.e: cmp al, 254
    jne .f
    mov bl, 6
    mov byte [d_ctx], 6
    jmp drag_start
.f: cmp al, 253
    jne .g
    xor byte [clk_on], 1
    call st_save
    jmp redraw
.g: cmp al, 255
    jne .r
    movzx eax, byte [st_sub]
    cmp eax, 3
    ja .tmb
    dec eax                             ; вкладка 1, 2 или 3
    mov [st_sec], al
    jne .tmo
    jmp redraw
.tmo:
    call dt_read
    jmp redraw
.tmb:
    call dt_change
    jmp redraw
.r: ret

; Время и дата: значения часов компьютера. dt_h, dt_mi, dt_d, dt_mo, dt_y подряд (местное время)
dt_read:
    pushad
    mov edi, dt_h
    call rtc_get
    mov esi, dt_h
    movsx edx, byte [tz_off]
    call tz_apply
    popad
    ret

; Записать значения в часы компьютера (секунды не трогаем)
dt_write:
    pushad
    mov esi, dt_h                       ; местное время переводим обратно в UTC
    mov edi, tw_buf
    mov ecx, 5
    cld
    rep movsd
    mov esi, tw_buf
    movsx edx, byte [tz_off]
    neg edx
    call tz_apply
.w: mov al, 0x0A
    out 0x70, al
    in al, 0x71
    test al, 0x80
    jnz .w
    mov al, 0x0B
    out 0x70, al
    in al, 0x71
    mov cl, al
    or al, 0x80
    mov ah, al
    mov al, 0x0B
    out 0x70, al
    mov al, ah
    out 0x71, al                        ; часы остановлены на запись
    mov esi, dt_regs
    mov edi, tw_buf
    mov ebx, 5
.l: mov eax, [edi]
    cmp ebx, 1
    jne .y
    sub eax, 2000
.y: test cl, 4
    jnz .b
    mov dl, 10                          ; в двоично-десятичный вид
    div dl
    shl al, 4
    or al, ah
.b: mov dl, al
    lodsb
    out 0x70, al
    mov al, dl
    out 0x71, al
    add edi, 4
    dec ebx
    jnz .l
    mov al, 0x0B
    out 0x70, al
    mov al, cl
    and al, 0x7F
    out 0x71, al                        ; часы снова идут
    mov word [clk_v], 0xFFFF            ; часы на столе перерисуются
    popad
    ret

; Дней в месяце dt_mo года dt_y -> eax
dt_dim:
    mov eax, [dt_mo]
    movzx eax, byte [dt_dm + eax - 1]
    cmp dword [dt_mo], 2
    jne .r
    test byte [dt_y], 3
    jnz .r
    inc eax
.r: ret

; Нажали < или > в строке: st_sub = 10 + 2 * строка + (0 - минус, 1 - плюс)
dt_change:
    pushad
    movzx ebx, byte [st_sub]
    sub ebx, 10
    mov edx, ebx
    shr ebx, 1                          ; строка 0..4
    and edx, 1
    mov esi, [dt_lo + ebx * 4]
    mov edi, [dt_hi + ebx * 4]
    cmp ebx, 2
    jne .nd
    call dt_dim
    mov edi, eax
.nd:mov eax, [dt_h + ebx * 4]
    test edx, edx
    jz .m
    inc eax
    cmp eax, edi
    jbe .s
    mov eax, esi
    jmp .s
.m: dec eax
    cmp eax, esi
    jge .s
    mov eax, edi
.s: mov [dt_h + ebx * 4], eax
    call dt_dim                         ; месяц или год поменялись: день не больше числа дней
    cmp [dt_d], eax
    jbe .w
    mov [dt_d], eax
.w: call dt_write
    popad
    ret

; Цвета 3 и 4 (рабочий стол) и 5 (середина курсора) из выбранных наборов
pal_theme:
    pushad
    movzx esi, byte [dk_theme]
    imul esi, 6
    add esi, dk_tab
    mov al, 3
    call pal_rgb
    add esi, 3
    mov al, 4
    call pal_rgb
    movzx esi, byte [cu_theme]
    imul esi, 3
    add esi, cu_tab
    mov al, 5
    call pal_rgb
    popad
    ret

; Цвет al := три байта из esi
pal_rgb:
    mov dx, 0x3C8
    out dx, al
    inc dx
    mov al, [esi]
    out dx, al
    mov al, [esi + 1]
    out dx, al
    mov al, [esi + 2]
    out dx, al
    ret

; Кнопка Settings на рабочем столе под About: обычная или вдавленная (pressed = 3)
draw_settings_btn:
    pushad
    RECT 40, 164, 180, 56, C_WHITE
    cmp byte [pressed], 3
    je .p
    CRECT 24, 86, 106, 108, C_BLACK, 2, 1, 1, 2
    CRECT 22, 84, 104, 106, C_BLACK, 2, 1, 1, 2
    CRECT 23, 85, 103, 105, C_WHITE, 1, 0, 0, 1
    mov esi, s_settings                 ; надпись по центру кнопки
    call strlen
    shl ecx, 3
    mov eax, 126
    sub eax, ecx
    mov [t_x], eax
    mov dword [t_y], 174
    mov dword [r_c], C_BLACK
    call draw_big
    jmp .e
.p: CRECT 24, 86, 106, 108, C_BLACK, 2, 1, 1, 2
    mov esi, s_settings
    call strlen
    shl ecx, 3
    mov eax, 130
    sub eax, ecx
    mov [t_x], eax
    mov dword [t_y], 178
    mov dword [r_c], C_WHITE
    call draw_big
.e: popad
    ret

; Часовой пояс в строку tz_buf: UTC+3, UTC-5, UTC+14
tz_fmt:
    pushad
    mov edi, tz_buf
    mov byte [edi], 'U'
    mov byte [edi + 1], 'T'
    mov byte [edi + 2], 'C'
    add edi, 3
    movsx eax, byte [tz_off]
    mov dl, '+'
    test eax, eax
    jns .p
    neg eax
    mov dl, '-'
.p: mov [edi], dl
    inc edi
    cmp eax, 10
    jb .o
    mov byte [edi], '1'
    inc edi
    sub eax, 10
.o: add al, '0'
    mov [edi], al
    mov byte [edi + 1], 0
    popad
    ret

; Час al (0..23) со сдвигом по часовому поясу -> al
tz_hour:
    push ecx
    push edx
    movzx eax, al
    movsx edx, byte [tz_off]
    lea eax, [eax + edx + 48]
    xor edx, edx
    mov ecx, 24
    div ecx
    mov eax, edx
    pop edx
    pop ecx
    ret

; Дней в месяце [esi + 12] года [esi + 16] -> eax
tz_dim:
    mov eax, [esi + 12]
    movzx eax, byte [dt_dm + eax - 1]
    cmp dword [esi + 12], 2
    jne .r
    test byte [esi + 16], 3
    jnz .r
    inc eax
.r: ret

; Прибавить edx часов к дате и времени в пяти числах по адресу esi: час, минута, день, месяц, год
tz_apply:
    pushad
    mov eax, [esi]
    add eax, edx
    jns .h
    add eax, 24                         ; вчера
    mov [esi], eax
    dec dword [esi + 8]
    cmp dword [esi + 8], 1
    jge .d
    dec dword [esi + 12]
    cmp dword [esi + 12], 1
    jge .m
    mov dword [esi + 12], 12
    dec dword [esi + 16]
.m: call tz_dim
    mov [esi + 8], eax
.d: jmp .e
.h: cmp eax, 24
    jb .s
    sub eax, 24                         ; завтра
    mov [esi], eax
    inc dword [esi + 8]
    call tz_dim
    cmp [esi + 8], eax
    jbe .e
    mov dword [esi + 8], 1
    inc dword [esi + 12]
    cmp dword [esi + 12], 12
    jbe .e
    mov dword [esi + 12], 1
    inc dword [esi + 16]
    jmp .e
.s: mov [esi], eax
.e: popad
    ret

; Часы компьютера (UTC) в пять чисел по адресу edi: час, минута, день, месяц, год
rtc_get:
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
    mov esi, dt_regs
    mov ebx, 5
.l: lodsb
    out 0x70, al
    in al, 0x71
    test cl, 4
    jnz .b
    call bcd
.b: movzx eax, al
    mov [edi], eax
    add edi, 4
    dec ebx
    jnz .l
    add dword [edi - 4], 2000
    popad
    ret

; Часы: время из CMOS -> eax = часы * 256 + минуты
rtc_read:
    push ebx
    push ecx
    push edx
.w: mov al, 0x0A                        ; ждём, пока часы не обновляются
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
    mov bh, al
    mov al, 2
    out 0x70, al
    in al, 0x71
    mov bl, al
    test cl, 4
    jnz .bin
    mov al, bh
    call bcd
    mov bh, al
    mov al, bl
    call bcd
    mov bl, al
.bin:
    mov al, bh
    call tz_hour
    mov bh, al
    movzx eax, bx
    pop edx
    pop ecx
    pop ebx
    ret

; al (двоично-десятичное) -> al
bcd:
    push ecx
    mov ah, al
    shr ah, 4
    and al, 0x0F
    mov cl, ah
    shl ah, 3
    add ah, cl
    add ah, cl
    add al, ah
    pop ecx
    ret

; Часы на рабочем столе (справа вверху белого поля), если включены
draw_clock:
    cmp byte [clk_on], 0
    je .r
    pushad
    call rtc_read
    mov [clk_v], ax
    movzx edx, ah
    movzx ecx, al
    mov eax, edx
    mov bl, 10
    div bl
    add ax, '00' 
    mov [clk_s], al
    mov [clk_s + 1], ah
    mov eax, ecx
    div bl
    add ax, '00'
    mov [clk_s + 3], al
    mov [clk_s + 4], ah
    RECT 668, 20, 96, 36, C_WHITE
    mov dword [t_x], 676
    mov dword [t_y], 22
    mov dword [r_c], C_BLACK
    mov esi, clk_s
    call draw_big
    popad
.r: ret

; Что-то лежит поверх места, где часы? CF = 1: да
clock_covered:
    cmp byte [d2_files], 0
    jne .y
    cmp byte [d2_text], 0
    jne .y
    cmp byte [d2_paint], 0
    jne .y
    cmp byte [d2_boil], 0
    jne .y
    cmp byte [d2_itge], 0
    jne .y
    cmp byte [d2_calc], 0
    jne .y
    cmp byte [d2_dlg], 0
    jne .y
    cmp byte [d2_tm], 0
    jne .y
    cmp byte [d2_ab], 0
    jne .y
    cmp byte [d2_st], 0
    jne .y
    cmp byte [d2_dk], 0
    jne .y
    cmp byte [d2_err], 0
    jne .y
    cmp byte [d2_main], 0
    je .n
    cmp dword [mx0], 768
    jge .n
    mov eax, [mx0]
    add eax, [mw]
    add eax, 4
    cmp eax, 668
    jle .n
    cmp dword [my0], 56
    jge .n
    mov eax, [my0]
    add eax, [mh]
    add eax, 4
    cmp eax, 20
    jle .n
.y: stc
    ret
.n: clc
    ret

; Каждые полсекунды: минута сменилась - подправить часы (если их ничто не закрывает)
clock_tick:
    cmp byte [d2_ist], 0
    jne .r
    cmp byte [d2_wl], 0
    jne .r
    call ck_tick
    cmp byte [clk_on], 0
    je .r
    mov eax, [ticks]
    sub eax, [clk_t]
    cmp eax, 9
    jb .r
    mov eax, [ticks]
    mov [clk_t], eax
    call rtc_read
    cmp ax, [clk_v]
    je .r
    call clock_covered
    jc .r
    call cursor_hide
    call draw_clock
    call cursor_show
.r: ret

d2_st       db 0
st_menu     db 0
dk_theme    db 0
cu_theme    db 0
clk_on      db 1
st_x        dd 128                      ; x, y, w, h подряд: swap_ctx таскает окно
st_y        dd 100
st_w        dd 480
st_h        dd 456
st_sbo      dd 0
cu_scale    dd 2                        ; 1..4 точек на пиксель курсора (2 - обычный)
clk_t       dd 0
clk_v       dw 0xFFFF
clk_s       db "00:00", 0
st_num      db "2", 0, 0
sk_y        dd 0
sk_idx      dd 0
sk_pal      dd 0
sk_nm       dd 0
sk_lb       dd 0
s_settings  db "Setting", 0
s_st_desk   db "Desktop color", 0
s_st_ccol   db "Cursor color", 0
s_st_csize  db "Cursor size", 0
s_st_clock  db "Clock", 0
s_st_lang   db "Language", 0
s_lang_en   db "English", 0
s_lang_ru   db 0xD0, 0xF3, 0xF1, 0xF1, 0xEA, 0xE8, 0xE9, 0
s_tab0      db "Main", 0
s_tab1      db "Time & date", 0
s_tab2      db "Region", 0
s_st_lay    db "Keyboard layout", 0
s_st_tz     db "Time zone", 0
tz_off      db 0                        ; часовой пояс: часы от UTC, -12..14
tz_buf      db "UTC+00", 0, 0
tw_buf      times 5 dd 0
s_dt0       db "Hours", 0
s_dt1       db "Minutes", 0
s_dt2       db "Day", 0
s_dt3       db "Month", 0
s_dt4       db "Year", 0
dt_lab      dd s_dt0, s_dt1, s_dt2, s_dt3, s_dt4
dt_regs     db 4, 2, 7, 8, 9
dt_dm       db 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
dt_lo       dd 0, 0, 1, 1, 2000
dt_hi       dd 23, 59, 31, 12, 2099
dt_h        dd 0
dt_mi       dd 0
dt_d        dd 1
dt_mo       dd 1
dt_y        dd 2000
dt_buf      db "0000", 0
st_sec      db 0
st_sub      db 0
s_lt        db "<", 0
s_gt        db ">", 0
s_on        db "On", 0
s_off       db "Off", 0
; в системе четыре цвета: синий, серый, чёрный, белый
; цвета стола: светлый и тёмный (каждый R, G, B 0..63)
dk_tab      db 10, 10, 63, 2, 2, 37
            db 42, 42, 42, 28, 28, 28
            db 0, 0, 0, 0, 0, 0
            db 63, 63, 63, 48, 48, 48
dk_names    db "Blue", 0, 0, 0, 0
            db "Gray", 0, 0, 0, 0
            db "Black", 0, 0, 0
            db "White", 0, 0, 0
cu_tab      db 63, 63, 63
            db 42, 42, 42
            db 10, 10, 63
            db 0, 0, 0
cu_names    db "White", 0, 0, 0
            db "Gray", 0, 0, 0, 0
            db "Blue", 0, 0, 0, 0
            db "Black", 0, 0, 0
