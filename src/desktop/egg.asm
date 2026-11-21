; Пасхалка secret floppy: в FloText написать secret floppy, сохранить как файл .sec и открыть его.
; Тогда система показывает на весь экран текст про автора, как в текстовом режиме. Любая клавиша или клик - назад.
; Подключается из kernel32.asm (%include)

d2_egg  db 0
egg_t0  dd 0

; Проверка файла после чтения: fn_buf - имя, DATA_BUF - содержимое. CF = 1 - это пасхалка, она включена
egg_test:
    pushad
    mov esi, fn_buf
    xor ecx, ecx
.n: cmp byte [esi + ecx], 0
    je .e
    inc ecx
    cmp ecx, 20
    jb .n
    jmp .no
.e: cmp ecx, 5                          ; хотя бы одна буква и .sec
    jb .no
    cmp dword [esi + ecx - 4], 0x6365732E   ; ".sec"
    jne .no
    mov esi, DATA_BUF
    mov edi, egg_key
    mov ecx, 13
.c: mov al, [esi]
    cmp al, 'A'                         ; заглавные буквы считаем строчными
    jb .x
    cmp al, 'Z'
    ja .x
    add al, 32
.x: cmp al, [edi]
    jne .no
    inc esi
    inc edi
    loop .c
    mov byte [d2_egg], 1
    mov eax, [ticks]
    mov [egg_t0], eax
    popad
    stc
    ret
.no:popad
    clc
    ret

; Любая клавиша или клик: вернуться (первую секунду не слушаем, чтобы не закрыть от того же нажатия)
egg_close:
    push eax
    mov eax, [ticks]
    sub eax, [egg_t0]
    cmp eax, 18
    pop eax
    jb .r
    mov byte [d2_egg], 0
    jmp redraw
.r: ret

egg_draw:
    pushad
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    mov dword [r_fn], 0
    call mclip_off
    RECT 0, 0, 800, 600, C_BLACK
    mov dword [r_c], C_GRAY
    mov dword [t_y], 24
    mov esi, egg_txt
.l: cmp byte [esi], 0xFF
    je .d
    mov dword [t_x], 16
    call egg_line
    add dword [t_y], 20
    jmp .l
.d: popad
    ret

; Строка из esi обычным шрифтом 8x16 в t_x, t_y (каждая точка 1x1), esi встаёт за ноль. Цвет r_c
egg_line:
    push ebx
    push ebp
    push edi
    mov eax, [t_x]
    mov [bg_x], eax
.ch:lodsb
    test al, al
    jz .e
    movzx eax, al
    shl eax, 4
    add eax, [0x500]
    mov ebp, eax
    xor ebx, ebx                        ; строка 0..15
.row:
    movzx eax, byte [ebp + ebx]
    mov edx, 0x80
    xor edi, edi
.col:
    test eax, edx
    jz .sk
    push eax
    push edx
    mov eax, edi
    add eax, [bg_x]
    mov [r_x], eax
    mov eax, ebx
    add eax, [t_y]
    mov [r_y], eax
    mov dword [r_w], 1
    mov dword [r_h], 1
    call fill_rect
    pop edx
    pop eax
.sk:shr edx, 1
    inc edi
    cmp edi, 8
    jb .col
    inc ebx
    cmp ebx, 16
    jb .row
    add dword [bg_x], 8
    jmp .ch
.e: pop edi
    pop ebp
    pop ebx
    ret

egg_key db "secret floppy"
egg_txt:
    db "I am the creator of Floppy OS. At first the main project was Xanex OS, but I froze it.", 0
    db "", 0
    db "As I write this text I am 10 years old and today is 01.11.2026.", 0
    db "", 0
    db "I am learning Assembly, I know it, and I even make my own little programs for those who", 0
    db "don't know it.", 0
    db "", 0
    db "My name is Elisey Sadriev and I live in Russia.", 0
    db "", 0
    db "Before creating Floppy OS I made Xanex OS, but then I had an idea: to copy the code I", 0
    db "want from an AI and memorize it, so that I learn Assembly faster. That is why I made the", 0
    db "project CoralOS. The operating system was text-based and many things appeared in it,", 0
    db "until the moment when I wanted to make a graphical interface there. It was hard, so I", 0
    db "started vibe coding.", 0
    db "", 0
    db "If someone is watching this, take a look at the project and remember that this is the", 0
    db "Floppy 1.1 version, the thing I liked. Well, good luck!", 0
    db 0xFF
