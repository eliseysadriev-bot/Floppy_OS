; Окно About (кнопка About на рабочем столе под кнопкой Floppy)
; Подключается из kernel32.asm (%include)
; Окно таскается за заголовок и растягивается за квадрат в углу (d_ctx = 5)

; Номера в hit: 240 крестик, 241 заголовок, 242 квадрат в углу, 243 внутри окна, 244 кнопка OK

ab_open:
    mov byte [ab_ok_down], 0
    mov dl, 1
    call fz_top
    mov byte [d2_ab], 1
    mov byte [ab_menu], 0
    jmp redraw

ab_exit:
    mov byte [ab_ok_down], 0
    mov byte [ab_menu], 0
    mov byte [d2_ab], 0
    jmp redraw

; Прямоугольник внутри окна: eax, ebx - угол, ecx, edx - размер, цвет в r_c
ab_box:
    add eax, [ab_x]
    add ebx, [ab_y]
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    jmp fill_rect

; Логотип 32x32: строки букв K (чёрный), B (синий), G (серый), W (белый); рисуется полосками одного цвета
ab_scale:                               ; во сколько раз увеличить логотип (1..4), чтобы всё влезло
    mov eax, [ab_w]
    sub eax, 24
    shr eax, 5
    mov ebx, [ab_h]
    sub ebx, 260
    jns .p
    xor ebx, ebx
.p: shr ebx, 5
    cmp eax, ebx
    jbe .m
    mov eax, ebx
.m: cmp eax, 3
    jbe .c
    mov eax, 3
.c: test eax, eax
    jnz .o
    inc eax
.o: mov [ab_sc], eax
    ret

ab_logo:
    pushad
    call ab_scale
    mov eax, [ab_sc]                    ; логотип по центру окна
    shl eax, 5
    neg eax
    add eax, [ab_w]
    shr eax, 1
    and eax, -2
    add eax, [ab_x]
    mov [ab_lx], eax
    xor ebp, ebp                        ; строка
.row:
    xor ebx, ebx                        ; колонка
.col:
    cmp ebx, 32
    jae .nr
    mov eax, ebp
    shl eax, 5
    add eax, ebx
    movzx edx, byte [ab_pic + eax]
    mov ecx, 1                          ; длина полоски
.run:
    lea eax, [ebx + ecx]
    cmp eax, 32
    jae .go
    mov esi, ebp
    shl esi, 5
    add esi, eax
    cmp dl, [ab_pic + esi]
    jne .go
    inc ecx
    jmp .run
.go:
    mov esi, C_BLACK
    cmp dl, 'B'
    jne .nb
    mov esi, C_BLUE
.nb:cmp dl, 'G'
    jne .ng
    mov esi, 7
.ng:cmp dl, 'W'
    jne .nw
    mov esi, C_WHITE
.nw:mov [r_c], esi
    mov eax, ecx
    imul eax, [ab_sc]
    mov [r_w], eax
    mov eax, [ab_sc]
    mov [r_h], eax
    mov eax, ebx
    imul eax, [ab_sc]
    add eax, [ab_lx]
    mov [r_x], eax
    mov eax, ebp
    imul eax, [ab_sc]
    add eax, [ab_y]
    add eax, 88
    mov [r_y], eax
    push ecx
    call fill_rect
    pop ecx
    add ebx, ecx
    jmp .col
.nr:inc ebp
    cmp ebp, 32
    jb .row
    popad
    ret

; Строка esi на ebx точек ниже верха окна, на 52 правее левого края (крупный шрифт)
ab_line:
    mov eax, [ab_x]
    add eax, 56
    mov [t_x], eax
    mov eax, [ab_y]
    add eax, ebx
    mov [t_y], eax
    jmp draw_big

; Строка esi по центру окна на ebx точек ниже верха; esi идёт дальше за строку
ab_cline:
    push ebx
    xor ecx, ecx
.l: cmp byte [esi + ecx], 0
    je .e
    inc ecx
    jmp .l
.e: shl ecx, 4
    mov eax, [ab_w]
    sub eax, ecx
    shr eax, 1
    and eax, -2
    add eax, [ab_x]
    mov [t_x], eax
    mov eax, [ab_y]
    add eax, ebx
    mov [t_y], eax
    push esi
    call draw_big
    pop esi
    pop ebx
.s: lodsb
    test al, al
    jnz .s
    ret

ab_draw:
    pushad
    mov eax, [ab_x]
    mov [cw_x], eax
    mov eax, [ab_y]
    mov [cw_y], eax
    mov dword [r_c], C_BLACK
    mov eax, 8
    mov ebx, 8
    mov ecx, [ab_w]
    mov edx, [ab_h]
    call ab_box
    xor eax, eax
    xor ebx, ebx
    call ab_box
    mov dword [r_c], C_WHITE
    mov eax, 2
    mov ebx, 2
    mov ecx, [ab_w]
    sub ecx, 4
    mov edx, [ab_h]
    sub edx, 4
    call ab_box
    mov dword [r_c], C_BLACK
    mov eax, 2
    mov ebx, 40
    mov ecx, [ab_w]
    sub ecx, 4
    mov edx, 2
    call ab_box
    mov eax, 2
    mov ebx, 80
    mov ecx, [ab_w]
    sub ecx, 4
    mov edx, 2
    call ab_box
    mov eax, [ab_w]
    sub eax, 18
    mov ebx, [ab_h]
    sub ebx, 18
    mov ecx, 16
    mov edx, 16
    call ab_box
    mov eax, [ab_w]                     ; заголовок по центру
    sub eax, 80
    shr eax, 1
    and eax, -8
    add eax, [ab_x]
    mov [t_x], eax
    mov eax, [ab_y]
    add eax, 4
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_about
    call draw_big
    mov eax, [ab_x]
    add eax, [ab_w]
    sub eax, 32
    mov ebx, [ab_y]
    add ebx, 8
    mov al, 240
    call title_button_state
    mov eax, [ab_x]
    add eax, [ab_w]
    sub eax, 32
    mov ebx, [ab_y]
    add ebx, 8
    call xbtn
    call ab_logo
    mov dword [r_c], C_BLACK
    call ab_scale
    mov eax, [ab_sc]
    shl eax, 5
    add eax, 96
    mov ebx, eax                        ; y первой строки под логотипом
    mov esi, ab_lines
.ln:cmp byte [esi], 0
    je .ld
    call ab_cline
    add ebx, 34
    jmp .ln
.ld:mov eax, [ab_w]                     ; кнопка OK внизу по центру
    sub eax, 120
    shr eax, 1
    and eax, -2
    mov ebx, [ab_h]
    sub ebx, 48
    mov ecx, 120
    mov edx, 36
    mov esi, s_ok
    movzx edi, byte [ab_ok_down]
    call wbtn
    mov eax, [ab_x]
    mov ebx, [ab_y]
    movzx edi, byte [ab_menu]
    call wm_file
    cmp byte [ab_menu], 0
    je .nm
    mov eax, [ab_x]
    mov ebx, [ab_y]
    call wm_menu
.nm:popad
    ret

; Под мышью окно About? CF = 1: да, al = 240..243; CF = 0: мимо окна
ab_hit:
    push ebx
    push esi
    push edi
    mov esi, [m_x]
    sub esi, [ab_x]
    jl .no
    mov edi, [m_y]
    sub edi, [ab_y]
    jl .no
    mov eax, [ab_w]
    cmp esi, eax
    ja .no
    mov ebx, [ab_h]
    cmp edi, ebx
    ja .no
    sub eax, 18
    cmp esi, eax
    jb .a
    sub ebx, 18
    cmp edi, ebx
    jb .a
    mov al, 242
    jmp .y
.a: mov dl, [ab_menu]
    call wm_hit                         ; File (227) и Exit (228)
    test al, al
    jz .a1
    add al, 226
    jmp .y
.a1:mov eax, [ab_w]                     ; кнопка OK
    sub eax, 120
    shr eax, 1
    and eax, -2
    cmp esi, eax
    jb .x
    add eax, 120
    cmp esi, eax
    ja .x
    mov eax, [ab_h]
    sub eax, 48
    cmp edi, eax
    jb .x
    add eax, 36
    cmp edi, eax
    ja .x
    mov al, 244
    jmp .y
.x: mov eax, [ab_w]
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
    mov al, 240
    jmp .y
.b: cmp edi, 2
    jb .z
    cmp edi, 36
    ja .z
    mov eax, [ab_w]
    sub eax, 36
    cmp esi, eax
    ja .z
    cmp esi, 4
    jb .z
    mov al, 241
    jmp .y
.z: mov al, 243
.y: stc
    jmp .o
.no:clc
.o: pop edi
    pop esi
    pop ebx
    ret

; Нажали мышью в окне About
ab_press:
    cmp al, 227
    jne .f1
    xor byte [ab_menu], 1
    jmp redraw
.f1:cmp al, 228
    je ab_exit
    cmp byte [ab_menu], 0               ; нажали мимо меню - оно закрывается
    je .f2
    mov byte [ab_menu], 0
    push eax
    call redraw
    pop eax
.f2:cmp al, 244
    je .cl
    cmp al, 240
    jne .a
.cl:
    mov byte [d2_ab], 0
    jmp redraw
.a: cmp al, 241
    jne .b
    mov bl, 1
    mov byte [d_ctx], 5
    jmp drag_start
.b: cmp al, 242
    jne .r
    mov bl, 6
    mov byte [d_ctx], 5
    jmp drag_start
.r: ret

; Кнопка About на рабочем столе под кнопкой Floppy: обычная или вдавленная (pressed = 2)
draw_about_btn:
    pushad
    RECT 40, 100, 180, 56, C_WHITE
    cmp byte [pressed], 2
    je .p
    CRECT 24, 54, 106, 76, C_BLACK, 2, 1, 1, 2
    CRECT 22, 52, 104, 74, C_BLACK, 2, 1, 1, 2
    CRECT 23, 53, 103, 73, C_WHITE, 1, 0, 0, 1
    mov esi, s_about                    ; надпись по центру кнопки
    call strlen
    shl ecx, 3
    mov eax, 126
    sub eax, ecx
    mov [t_x], eax
    mov dword [t_y], 110
    mov dword [r_c], C_BLACK
    call draw_big
    jmp .e
.p: CRECT 24, 54, 106, 76, C_BLACK, 2, 1, 1, 2
    mov esi, s_about
    call strlen
    shl ecx, 3
    mov eax, 130
    sub eax, ecx
    mov [t_x], eax
    mov dword [t_y], 114
    mov dword [r_c], C_WHITE
    call draw_big
.e: popad
    ret

ab_pic:
    db "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK"
    db "KBBBBBBBBKKKKKKKKKKKKKKBBBBBBBBK"
    db "KBBBBBBBBKKKKKKKKGGGGGKBBBBBBBBK"
    db "KBBBBBBBBKKKKKKKKGGGGGKBBBBBBBBK"
    db "KBBBBBBBBKKKKKKKKGGGGGKBBBBBBBBK"
    db "KBBBBBBBBKKKKKKKKGGGGGKBBBBBBBBK"
    db "KBBBBBBBBKKKKKKKKGGGGGKBBBBBBBBK"
    db "KBBBBBBBBKKKKKKKKGGGGGKBBBBBBBBK"
    db "KBBBBBBBBKKKKKKKKGGGGGKBBBBBBBBK"
    db "KBBBBBBBBKKKKKKKKKKKKKKBBBBBBBBK"
    db "KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK"
    db "KBBBBBBGGGGGGGGGGGGGGGGGGBBBBBBK"
    db "KBBBBBBGGGGGGGGGGGGGGGGGGBBBBBBK"
    db "KBBBBBBGGGGGGGGGGGGGGGGGGBBBBBBK"
    db "KBBBBBBWWWWWWWWWWWWWWWWWWBBBBBBK"
    db "KBBBBBBWWWWWWWWWWWWWWWWWWBBBBBBK"
    db "KBBBBBBWWWWWWWWWWWWWWWWWWBBBBBBK"
    db "KBBBBBBWWWWWWWWWWWWWWWWWWBBBBBBK"
    db "KBBBBBBWWWWWWWWWWWWWWWWWWBBBBBBK"
    db "KBBBBBBWWWWWWWWWWWWWWWWWWBBBBBBK"
    db "KBBBBBBWWWWWWWWWWWWWWWWWWBBBBBBK"
    db "KBBBBBBWWWWWWWWWWWWWWWWWWBBBBBBK"
    db "KBBBBBBWWWWWWWWWWWWWWWWWWBBBBBBK"
    db "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK"
d2_ab       db 0
ab_menu     db 0
ab_ok_down  db 0
ab_x        dd 160                      ; x, y, w, h подряд: swap_ctx таскает окно
ab_y        dd 100
ab_w        dd 480
ab_h        dd 400
ab_tx       dd 0
s_about     db "About", 0
ab_lines   db "Floppy 1.1", 0
            db "Version 1.1", 0
            db "Author: miliyya", 0
            db "Created 11.10.26", 0
            db 0
ab_lx       dd 0
ab_sc       dd 7
