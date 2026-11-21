; Окно Loading: картинка дискеты и надпись, пока приложение или система долго грузятся
; Подключается из kernel32.asm (%include)
; Картинка 25 x 38 клеток по 4 точки (буквы K чёрный, B синий, G серый), нарисована самим автором системы

LD_X    equ 240
LD_Y    equ 170
LD_W    equ 320
LD_H    equ 240
LD_PX   equ LD_X + 110                  ; картинка по центру окна
LD_PY   equ LD_Y + 16

; Начало загрузки: сначала окно Loading (курсор в этот момент спрятан), потом курсор-часы
splash_start:
    cmp byte [cu_busy], 0
    jne .n
    call ld_show
.n: jmp wait_start

ld_show:
    pushad
    RECT LD_X + 8, LD_Y + 8, LD_W, LD_H, C_BLACK
    RECT LD_X, LD_Y, LD_W, LD_H, C_BLACK
    RECT LD_X + 2, LD_Y + 2, LD_W - 4, LD_H - 4, C_WHITE
    xor ebp, ebp                        ; строка картинки
.row:
    xor ebx, ebx                        ; клетка в строке
.col:
    cmp ebx, 25
    jae .nr
    mov eax, ebp
    imul eax, 25
    add eax, ebx
    movzx edx, byte [ld_pic + eax]
    mov ecx, 1                          ; длина полоски одного цвета
.run:
    lea eax, [ebx + ecx]
    cmp eax, 25
    jae .go
    mov esi, ebp
    imul esi, 25
    add esi, eax
    cmp dl, [ld_pic + esi]
    jne .go
    inc ecx
    jmp .run
.go:mov esi, C_BLACK
    cmp dl, 'B'
    jne .nb
    mov esi, C_BLUE
.nb:cmp dl, 'G'
    jne .ng
    mov esi, C_GRAY
.ng:mov [r_c], esi
    mov eax, ecx
    shl eax, 2
    mov [r_w], eax
    mov dword [r_h], 4
    mov eax, ebx
    shl eax, 2
    add eax, LD_PX
    mov [r_x], eax
    mov eax, ebp
    shl eax, 2
    add eax, LD_PY
    mov [r_y], eax
    push ecx
    call fill_rect
    pop ecx
    add ebx, ecx
    jmp .col
.nr:inc ebp
    cmp ebp, 38
    jb .row
    mov dword [t_x], LD_X + (LD_W - 112) / 2
    mov dword [t_y], LD_Y + 180
    mov dword [r_c], C_BLACK
    mov esi, s_loading
    call draw_big
    popad
    ret

s_loading   db "Loading", 0
ld_pic:
    db "KKKKKKKKKKKKKKKKKKKKKKKKK"
    db "KKBBBBBBBGGGGGGGGGGGGGGGB"
    db "KKBBBBBBBGGGGGGGGGGGGGGGB"
    db "KKBBBBBBBGGGGGGGBBBBBGGGB"
    db "KKBBBBBBBGGGGGGGBBBBBGGGB"
    db "KKBBBBBBBGGGGGGGBBBBBGGGB"
    db "KKBBBBBBBGGGGGGGBBBBBGGGB"
    db "KKBBBBBBBGGGGGGGBBBBBGGGB"
    db "KKBBBBBBBGGGGGGGBBBBBGGGB"
    db "KKBBBBBBBGGGGGGGBBBBBGGGB"
    db "KKBBBBBBBGGGGGGGBBBBBGGGB"
    db "KKBBBBBBBGGGGGGGGGGGGGGGB"
    db "KKBBBBBBBGGGGGGGGGGGGGGGB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBBBBBBBBBBBBBBBBBB"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKBBBBBBGGGGGGGGGGGGGGGGG"
    db "KKKKKKKKKKKKKKKKKKKKKKKKK"
