; Кнопка Help рядом с File у программ на весь экран: выпадающая панель с подсказками
; Подключается из kernel32.asm (%include)
; Программа: 1 FloFile, 2 FloText, 3 FloPaint, 4 FloBoil, 5 FloItge. Кнопка x 92..172, y 42..76. Код мыши 197

; Какая программа на весь экран открыта -> al (0 - никакой)
hp_id:
    cmp byte [d2_boil], 0
    jne .b
    cmp byte [d2_itge], 0
    jne .i
    cmp byte [d2_paint], 0
    jne .p
    cmp byte [d2_text], 0
    jne .t
    cmp byte [d2_files], 0
    jne .f
    xor al, al
    ret
.b: mov al, 4
    ret
.i: mov al, 5
    ret
.p: mov al, 3
    ret
.t: mov al, 2
    ret
.f: mov al, 1
    ret

; Нарисовать кнопку Help у программы на весь экран
hp_draw:
    pushad
    call hp_id
    test al, al
    jz .r
    movzx ecx, al
    xor eax, eax
    xor ebx, ebx
    call hp_win
.r: popad
    ret

; Прямоугольник со сдвигом hp_ox, hp_oy: eax, ebx - угол, ecx, edx - размер, цвет в r_c
hp_rc:
    add eax, [hp_ox]
    add ebx, [hp_oy]
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    jmp fill_rect

; Ширина кнопки Help -> ecx (по-русски надпись длиннее)
hp_bw:
    mov ecx, 80
    cmp byte [ui_ru], 0
    je .r
    mov ecx, 112
.r: ret

; Кнопка Help и, если она нажата, панель. Окно начинается в (eax, ebx), ecx - номер справки (1..6)
hp_win:
    pushad
    mov [hp_ox], eax
    mov [hp_oy], ebx
    mov [hp_cur], ecx
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    mov eax, [hp_cur]
    cmp [hp_on], al
    jne .fn
    mov dword [r_c], C_BLACK
    mov eax, 92
    mov ebx, 42
    call hp_bw
    mov edx, 34
    call hp_rc
    mov dword [r_c], C_WHITE
    jmp .ft
.fn:mov dword [r_c], C_BLACK
    mov eax, 92
    mov ebx, 42
    call hp_bw
    mov edx, 34
    call hp_rc
    mov dword [r_c], C_WHITE
    mov eax, 94
    mov ebx, 44
    call hp_bw
    sub ecx, 4
    mov edx, 30
    call hp_rc
    mov dword [r_c], C_BLACK
.ft:mov eax, [hp_ox]
    add eax, 100
    mov [t_x], eax
    mov eax, [hp_oy]
    add eax, 44
    mov [t_y], eax
    mov esi, s_hp_help
    call draw_big
    mov eax, [hp_cur]
    cmp [hp_on], al
    jne .r
    mov esi, [hp_tab + eax * 4]
    mov [hp_p], esi
    xor ecx, ecx                        ; сколько строк
    xor edx, edx                        ; самая длинная
.sc:cmp byte [esi], 0
    je .sd
    xor ebx, ebx
.ln:cmp byte [esi + ebx], 0
    je .le
    inc ebx
    jmp .ln
.le:push ecx
    call strlen                         ; длина с учётом перевода
    mov edi, ecx
    pop ecx
    cmp edi, edx
    jbe .nm
    mov edx, edi
.nm:inc ecx
    lea esi, [esi + ebx + 1]
    jmp .sc
.sd:shl edx, 4
    add edx, 28
    mov [hp_w], edx
    imul ecx, 36
    add ecx, 8
    mov [hp_h], ecx
    mov dword [r_c], C_BLACK
    mov eax, 8
    mov ebx, 84
    mov ecx, [hp_w]
    mov edx, [hp_h]
    call hp_rc
    mov eax, 4
    mov ebx, 80
    call hp_rc
    mov dword [r_c], C_WHITE
    mov eax, 6
    mov ebx, 82
    mov ecx, [hp_w]
    sub ecx, 4
    mov edx, [hp_h]
    sub edx, 4
    call hp_rc
    mov dword [r_c], C_BLACK
    mov eax, [hp_oy]
    add eax, 84
    mov [t_y], eax
    mov esi, [hp_p]
.tl:cmp byte [esi], 0
    je .r
    mov eax, [hp_ox]
    add eax, 12
    mov [t_x], eax
    call draw_big
.sk:lodsb
    test al, al
    jnz .sk
    add dword [t_y], 36
    jmp .tl
.r: popad
    ret

; Мышь над кнопкой Help или над открытой панелью? CF = 1: да, al = 197. Остальные регистры целы
hp_hit:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    call hp_id
    test al, al
    jz .no
    mov bl, al
    mov esi, [m_x]
    mov edi, [m_y]
    cmp esi, 92
    jb .pn
    mov eax, 172
    cmp byte [ui_ru], 0
    je .nbw
    add eax, 32
.nbw:cmp esi, eax
    ja .pn
    cmp edi, 42
    jb .pn
    cmp edi, 76
    jbe .yes
.pn:cmp [hp_on], bl
    jne .no
    cmp esi, 4
    jb .no
    mov eax, [hp_w]
    add eax, 4
    cmp esi, eax
    ja .no
    cmp edi, 80
    jb .no
    mov eax, [hp_h]
    add eax, 80
    cmp edi, eax
    ja .no
.yes:
    mov al, 197
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    stc
    ret
.no:pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    clc
    ret

; Нажали мышью (al - что под ней). CF = 1: справка забрала нажатие
hp_press:
    push eax
    push ebx
    mov bl, al
    cmp bl, 118                         ; Help у калькулятора
    je .calc
    cmp byte [hp_on], 6
    jb .fs
    mov byte [hp_on], 0                 ; нажали мимо справки калькулятора или календаря
    call redraw
    jmp .yes
.calc:
    cmp byte [d2_calc], 0
    je .no
    cmp byte [hp_on], 6
    jne .co
    mov byte [hp_on], 0
    jmp .cr
.co:mov byte [calc_menu], 0
    mov byte [hp_on], 6
.cr:call redraw
    jmp .yes
.fs:call hp_id
    test al, al
    jz .stale
    cmp bl, 197
    je .tog
    cmp [hp_on], al                     ; нажали мимо - панель закрывается
    jne .no
    mov byte [hp_on], 0
    call redraw
    jmp .yes
.tog:
    cmp [hp_on], al
    je .cl
    mov [hp_new], al
    mov byte [hp_on], 0
    mov al, 198                         ; меню File у программы - закрыть, как будто нажали мимо
    call hp_prog_press
    mov al, [hp_new]
    mov [hp_on], al
    call redraw
    jmp .yes
.cl:mov byte [hp_on], 0
    call redraw
.yes:
    pop ebx
    pop eax
    stc
    ret
.stale:
    mov byte [hp_on], 0
.no:pop ebx
    pop eax
    clc
    ret

; Нажатие al отдаём программе на весь экран (id в hp_new)
hp_prog_press:
    cmp byte [hp_new], 4
    je boil_press
    cmp byte [hp_new], 5
    je itge_press
    cmp byte [hp_new], 3
    je paint_press
    cmp byte [hp_new], 2
    jne .fl
    mov byte [t_menu], 0
    ret
.fl:jmp files_press

; Клавиша при открытой справке: панель закрывается, клавиша не действует. CF = 1 - так и было
hp_key:
    cmp byte [hp_on], 0
    je .n
    push eax
    push ebx
    mov bl, [hp_on]
    mov byte [hp_on], 0
    cmp bl, 6
    jae .rd
    call hp_id
    cmp al, bl
    jne .st
.rd:call redraw
.st:pop ebx
    pop eax
    stc
    ret
.n: clc
    ret

hp_new      db 0
hp_p        dd 0
hp_ox       dd 0
hp_oy       dd 0
hp_cur      dd 0
s_hp_help   db "Help", 0
hp_tab      dd 0, hp_files, hp_text, hp_paint, hp_boil, hp_itge, hp_calc, hp_cal

hp_files    db "Double click a disk or folder to open", 0
            db "Right click a file: Rename, Delete, Copy", 0
            db "Right click empty space: create", 0
            db "Back - go up one folder", 0
            db 0
hp_text     db "Type with the keyboard", 0
            db "Select text with the mouse", 0
            db "Ctrl + A - select all", 0
            db "Ctrl + C - copy, Ctrl + X - cut", 0
            db "Ctrl + V - paste", 0
            db 0
hp_paint    db "Pick a tool on the left and draw", 0
            db "Slider - brush size, squares - colors", 0
            db "Ctrl + Z - undo", 0
            db "Ctrl + Y - redo", 0
            db 0
hp_boil     db "Press Start to turn the microwave on", 0
            db "Press Stop at the time shown", 0
            db "Miss by less than 0.3 s - you win", 0
            db "File - Record shows your best streak", 0
            db 0
hp_itge     db "Type text, click a picture to select it", 0
            db "Right click a picture for more", 0
            db "Ctrl + B bold, I italic, U underline", 0
            db "Ctrl + Z - undo, Ctrl + Y - redo", 0
            db "Ctrl + A select, C copy, X cut, V paste", 0
            db 0
hp_calc     db "Click the buttons", 0
            db "or use the keyboard", 0
            db "Enter - equals", 0
            db "Backspace - erase", 0
            db "Esc or C - clear", 0
            db 0
hp_cal      db "The current month", 0
            db "Today - black square", 0
            db 0
