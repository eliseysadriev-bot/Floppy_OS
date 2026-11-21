; Экран смерти: рисунок дискеты и текст. Показывается при kernel panic (ошибка процессора 0..31)
; и по команде panic в Terminal. После показа система останавливается.
; Подключается из kernel32.asm (%include)

; Для каждой ошибки процессора своя маленькая заглушка: кладёт номер ошибки и прыгает в kpanic
%assign pn_n 0
%rep 32
pn_s %+ pn_n:
    push dword pn_n
    jmp kpanic
%assign pn_n pn_n + 1
%endrep

pn_tab:                                 ; адреса заглушек для таблицы прерываний
%assign pn_n 0
%rep 32
    dd pn_s %+ pn_n
%assign pn_n pn_n + 1
%endrep

kpanic:
    cli
    pop eax                             ; номер ошибки процессора
kpanic2:                                ; сюда прыгает команда panic: eax = 0xFF
    mov esp, 0x90000
    mov [pn_num], eax
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    mov dword [r_fn], 0
    call mclip_off                      ; рисуем на весь экран
    RECT 0, 0, 800, 600, C_BLACK
    call pn_logo
    mov dword [r_c], C_WHITE
    mov esi, pn_t1
    mov ecx, 290
    call pn_line
    mov edi, pn_buf                     ; вторая строка собирается: Kernel panic: ...
    mov esi, pn_t2
    call pn_cat
    cmp dword [pn_num], 0xFF
    jne .exc
    mov esi, pn_t4
    call pn_cat
    jmp .go
.exc:
    mov esi, pn_t3
    call pn_cat
    mov eax, [pn_num]
    xor edx, edx
    mov ebx, 10
    div ebx                             ; eax - десятки, edx - единицы
    test eax, eax
    jz .one
    add al, '0'
    stosb
.one:
    mov al, dl
    add al, '0'
    stosb
.go:
    xor al, al
    stosb
    mov esi, pn_buf
    mov ecx, 340
    call pn_line
    mov esi, pn_t5
    mov ecx, 410
    call pn_line
.h: hlt
    jmp .h

; Копирует строку из esi в edi (без нуля в конце), edi вперёд
pn_cat:
    lodsb
    test al, al
    jz .e
    stosb
    jmp pn_cat
.e: ret

; Строка esi по центру экрана, ecx - y. Цвет r_c
pn_line:
    xor eax, eax
.l: cmp byte [esi + eax], 0
    je .d
    inc eax
    jmp .l
.d: shl eax, 4                          ; буква 16 точек
    mov edx, 800
    sub edx, eax
    shr edx, 1
    mov [t_x], edx
    mov [t_y], ecx
    jmp draw_big

; Рисунок дискеты 32x32 из About, каждая точка 6x6, по центру сверху. Чёрная рамка здесь белая
pn_logo:
    pushad
    xor ebp, ebp
.row:
    xor ebx, ebx
.col:
    mov eax, ebp
    shl eax, 5
    add eax, ebx
    movzx edx, byte [ab_pic + eax]
    mov esi, C_WHITE
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
    mov eax, ebx
    imul eax, 6
    add eax, 304
    mov [r_x], eax
    mov eax, ebp
    imul eax, 6
    add eax, 60
    mov [r_y], eax
    mov dword [r_w], 6
    mov dword [r_h], 6
    call fill_rect
    inc ebx
    cmp ebx, 32
    jb .col
    inc ebp
    cmp ebp, 32
    jb .row
    popad
    ret

pn_num  dd 0
pn_buf  times 48 db 0
pn_t1   db "Floppy 1.1 has crashed", 0
pn_t2   db "Kernel panic: ", 0
pn_t3   db "exception ", 0
pn_t4   db "panic command", 0
pn_t5   db "Restart the computer", 0
