%macro RECT 5                       ; x, y, ширина, высота, цвет (в настоящих точках)
    mov dword [r_x], %1
    mov dword [r_y], %2
    mov dword [r_w], %3
    mov dword [r_h], %4
    mov dword [r_c], %5
    call fill_rect
%endmacro
%macro RECTM 5                      ; то же, но любые операнды (числа и [переменные])
    mov eax, %1
    mov [r_x], eax
    mov eax, %2
    mov [r_y], eax
    mov eax, %3
    mov [r_w], eax
    mov eax, %4
    mov [r_h], eax
    mov dword [r_c], %5
    call fill_rect
%endmacro
%macro CRECT 9                      ; x0, y0, x1, y1 (половинные точки), цвет, срезы: лев-верх, прав-верх, лев-низ, прав-низ
    mov dword [cr_x0], %1
    mov dword [cr_y0], %2
    mov dword [cr_x1], %3
    mov dword [cr_y1], %4
    mov dword [cr_c], %5
    mov dword [cr_tl], %6
    mov dword [cr_tr], %7
    mov dword [cr_bl], %8
    mov dword [cr_br], %9
    call crect
%endmacro


; Проверка: знак в al можно вводить в текст (ASCII 32..126 или русская буква 0xBE..0xFF), иначе прыжок на метку %1
%macro PRT 1
    cmp al, 32
    jb %1
    cmp al, 126
    jbe %%ok
    cmp al, 0xBE
    jb %1
%%ok:
%endmacro

; Верхняя граница знака: до 126 или русская буква от 0xBE, иначе прыжок на метку %2
%macro CHKHI 2
    cmp %1, 126
    jbe %%ok
    cmp %1, 0xBE
    jb %2
%%ok:
%endmacro

; Draw a rectangle offset from mutable window origin (x/y variables).
%macro MODRECT 7                   ; x variable, y variable, local x/y, width, height, VGA color
    mov eax, [%1]
    add eax, %3
    mov [r_x], eax
    mov eax, [%2]
    add eax, %4
    mov [r_y], eax
    mov dword [r_w], %5
    mov dword [r_h], %6
    mov dword [r_c], %7
    call fill_rect
%endmacro

