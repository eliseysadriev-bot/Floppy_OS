; itge - improved text graphics editor (версия 2: как Word, плюс картинки). Включается в itgesys.asm
; Серый фон, белые страницы A4, слева колонка кнопок, текст набирается как в Word, картинки лежат свободно.
; Формат .sga: "SGA2", размеры, картинки, клетки текста (по 4 байта: знак, флаги, цвет, размер).

IT_TMAX  equ 10000                      ; знаков в документе (последний всегда перевод строки)
IT_TXT   equ 0xA60000                   ; клетки текста: знак, флаги (1 жирный, 2 подчёркнутый, 4 курсив, биты 3-4 выравнивание у перевода строки), цвет, размер 1..3
IT_CBTXT equ 0xA70000                   ; буфер копирования текста
IT_LN    equ 0xA80000                   ; строки: начало, конец, y в документе, dw x (слово) и высота (слово)
IT_LMAX  equ 1024
IT_UND   equ 0xA90000                   ; отмена: IT_UNDN снимков по IT_USZ байт
IT_UNDN  equ 6
IT_UTMP  equ 0xAF0000                   ; временное место при отмене и возврате (один снимок)
IT_USZ   equ 0x10000
IT_PIC   equ 0xA00000                   ; картинки: IT_PICN мест по 64 КБ (до 256 на 256, по байту на точку)
IT_PICN  equ 6
IT_CBPIC equ 0xF00000                   ; буфер копирования картинки
IT_EXP   equ 0xB00000
IT_SHD   equ 0xC00000                   ; то, что сейчас на экране в области документа (чтобы выводить только изменившееся)                   ; сюда рисуется страница при экспорте
IT_OMAX  equ 16                         ; картинок на листе
IT_ESZ   equ 64                         ; запись картинки: +0 тип (2), +4 cx, +8 cy (центр в документе), +12 угол, +16 sw, +20 sh, +24 место, +28 dw, +32 dh
IT_MENUN equ 6                          ; пунктов в меню File
PGW      equ 512                        ; страница
PGH      equ 724
PGM      equ 32                         ; поля
PGGAP    equ 20                         ; промежуток между страницами
PGMAX    equ 6
TXTW     equ PGW - 2 * PGM
TXTH     equ PGH - 2 * PGM
VX0      equ 72                         ; область документа
VY0      equ 80
VW       equ 712
VH       equ 520
SBX      equ 784                        ; полоса прокрутки
PGX      equ 169                        ; левый край страницы на экране
RMH      equ 34                         ; высота пункта правого меню
RMW      equ 216                        ; ширина

%macro RC 5                             ; прямоугольник через it_rect (экран или буфер экспорта)
    mov dword [r_x], %1
    mov dword [r_y], %2
    mov dword [r_w], %3
    mov dword [r_h], %4
    mov dword [r_c], %5
    call it_rect
%endmacro

itge_open:
    cmp byte [d2_itge], 0
    jne .r
    mov al, 5
    call z_hide_others
    mov byte [d2_itge], 1
    mov byte [it_drag], 0
    mov byte [it_menu], 0
    mov byte [it_cp], 0
    mov byte [it_rm], 0
    mov byte [it_have], 0
    mov byte [it_focus], 0
    mov byte [it_tobuf], 0
    mov dword [it_sel], -1
    mov byte [it_nm], 0
    mov byte [it_dsk], 0xFF
    call it_new
    call it_pal_on
    jmp redraw
.r: ret

; Закрыть itge: если есть несохранённое, спросить
itge_exit:
    cmp byte [it_mod], 0
    je itge_close
    mov al, 2
    jmp sv_ask

itge_close:
    mov byte [it_mod], 0
    mov byte [d2_itge], 0
    mov byte [it_drag], 0
    call set_palette                    ; цвета системы обратно
    mov al, 5
    call z_restore
    jmp redraw

; Новый пустой документ
it_new:
    pushad
    mov dword [it_n], 1
    mov dword [IT_TXT], 0x0100000A      ; один перевод строки: знак 10, флаги 0, цвет 0, размер 1
    mov dword [it_p], 0
    mov dword [it_a], 0
    mov dword [it_on], 0
    mov dword [it_sel], -1
    mov dword [it_scroll], 0
    mov dword [it_dy], VY0
    mov dword [it_us], 0
    mov dword [it_re], 0
    mov byte [it_fl], 0
    mov byte [it_col], 0
    mov byte [it_sz], 1
    mov byte [it_have], 1
    mov byte [it_mod], 0
    mov byte [it_focus], 0
    mov byte [it_lastop], 0
    call it_layout
    popad
    ret

; Раскладка текста по строкам и страницам: IT_LN, it_nl, it_np. it_ovf = 1, если не влезает
it_layout:
    pushad
    cld
    mov dword [it_ovf], 0
    xor ebx, ebx                        ; начало строки
    mov dword [ly_nl], 0
    mov dword [ly_pg], 0
    mov dword [ly_y], 0
.line:
    cmp ebx, [it_n]
    jae .done
    mov esi, ebx                        ; конец абзаца: оттуда выравнивание
.f1:cmp esi, [it_n]
    jae .f2
    cmp byte [IT_TXT + esi * 4], 10
    je .f2
    inc esi
    jmp .f1
.f2:movzx eax, byte [IT_TXT + esi * 4 + 1]
    shr eax, 3
    and eax, 3
    mov [ly_al], eax
    xor ecx, ecx                        ; ширина строки
    xor edx, edx                        ; высота строки
    mov edi, ebx
    mov dword [ly_sp], -1
.c: cmp edi, [it_n]
    jae .fin
    movzx eax, byte [IT_TXT + edi * 4 + 3]
    mov ebp, eax
    shl ebp, 3                          ; ширина знака
    shl eax, 4                          ; высота знака
    cmp byte [IT_TXT + edi * 4], 10
    je .nl
    lea esi, [ecx + ebp]
    cmp esi, TXTW
    ja .wrap
    mov ecx, esi
    cmp eax, edx
    jbe .h1
    mov edx, eax
.h1:cmp byte [IT_TXT + edi * 4], 32
    jne .nx
    mov [ly_sp], edi
    mov [ly_spw], ecx
    mov [ly_sph], edx
.nx:inc edi
    jmp .c
.wrap:
    mov eax, [ly_sp]
    cmp eax, ebx
    jl .fin                             ; пробела в строке нет: рвём здесь
    lea edi, [eax + 1]                  ; рвём после пробела
    mov ecx, [ly_spw]
    mov edx, [ly_sph]
    jmp .fin
.nl:cmp eax, edx
    jbe .n2
    mov edx, eax
.n2:inc edi                             ; перевод строки входит в строку
.fin:
    cmp edi, ebx
    ja .ok
    lea edi, [ebx + 1]
.ok:test edx, edx
    jnz .hh
    mov edx, 16
.hh:mov eax, TXTW
    sub eax, ecx
    jns .a0
    xor eax, eax
.a0:mov ebp, [ly_al]
    cmp ebp, 1
    jne .a1
    shr eax, 1
    jmp .a3
.a1:cmp ebp, 2
    je .a3
    xor eax, eax
.a3:mov [ly_x], eax
    mov eax, [ly_y]
    add eax, edx
    cmp eax, TXTH
    jbe .fit
    cmp dword [ly_y], 0
    je .fit
    inc dword [ly_pg]
    mov dword [ly_y], 0
.fit:
    cmp dword [ly_pg], PGMAX
    jae .ovf
    cmp dword [ly_nl], IT_LMAX
    jae .ovf
    mov eax, [ly_nl]
    shl eax, 4
    lea ebp, [IT_LN + eax]
    mov [ebp], ebx
    mov [ebp + 4], edi
    mov eax, [ly_pg]
    imul eax, PGH + PGGAP
    add eax, PGGAP + PGM
    add eax, [ly_y]
    mov [ebp + 8], eax
    mov eax, [ly_x]
    mov [ebp + 12], ax
    mov [ebp + 14], dx
    add [ly_y], edx
    inc dword [ly_nl]
    mov ebx, edi
    jmp .line
.ovf:
    mov dword [it_ovf], 1
    jmp .out
.done:
    mov eax, [ly_pg]
    inc eax
    mov [it_np], eax
    mov eax, [ly_nl]
    mov [it_nl], eax
.out:
    popad
    ret

; eax = индекс клетки -> eax = номер строки
it_lineof:
    push ebx
    push ecx
    push edx
    mov ecx, [it_nl]
    xor ebx, ebx
.l: lea edx, [ebx + 1]
    cmp edx, ecx
    jae .f
    mov edx, ebx
    shl edx, 4
    cmp eax, [IT_LN + edx + 4]
    jb .f
    inc ebx
    jmp .l
.f: mov eax, ebx
    pop edx
    pop ecx
    pop ebx
    ret

; eax = индекс клетки, esi = номер строки -> eax = x от левого края текста страницы
it_xof:
    push ebx
    push ecx
    push edx
    push esi
    mov ebx, esi
    shl ebx, 4
    add ebx, IT_LN
    mov ecx, [ebx]
    xor edx, edx
.l: cmp ecx, eax
    jae .d
    movzx esi, byte [IT_TXT + ecx * 4 + 3]
    shl esi, 3
    add edx, esi
    inc ecx
    jmp .l
.d: movzx ecx, word [ebx + 12]
    add edx, ecx
    mov eax, edx
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Строка eax и x от края текста (edx) -> eax = индекс клетки
it_charat:
    push ebx
    push ecx
    push esi
    push edi
    mov ebx, eax
    shl ebx, 4
    add ebx, IT_LN
    movzx ecx, word [ebx + 12]
    sub edx, ecx                        ; x внутри строки
    mov ecx, [ebx]                      ; начало
    mov esi, [ebx + 4]
    dec esi                             ; последняя клетка строки: дальше курсор встать не может
    xor edi, edi
.l: cmp ecx, esi
    jae .e
    movzx eax, byte [IT_TXT + ecx * 4 + 3]
    shl eax, 3
    mov ebx, eax
    shr ebx, 1
    add ebx, edi
    cmp edx, ebx
    jl .e
    add edi, eax
    inc ecx
    jmp .l
.e: mov eax, ecx
    pop edi
    pop esi
    pop ecx
    pop ebx
    ret

; Какая клетка текста под мышью: eax; CF = мышь не над страницей
it_texthit:
    push ebx
    push ecx
    push edx
    mov eax, [m_y]
    sub eax, [it_dy]                    ; y в документе
    xor ebx, ebx
.l: cmp ebx, [it_nl]
    jae .last
    mov edx, ebx
    shl edx, 4
    movzx ecx, word [IT_LN + edx + 14]
    add ecx, [IT_LN + edx + 8]
    cmp eax, ecx
    jl .got
    inc ebx
    jmp .l
.last:
    mov ebx, [it_nl]
    dec ebx
.got:
    mov eax, ebx
    mov edx, [m_x]
    sub edx, [it_px0]
    sub edx, PGM
    call it_charat
    clc
    pop edx
    pop ecx
    pop ebx
    ret

; Страница под мышью? CF = нет
it_inpage:
    push eax
    push ebx
    push edx
    cmp byte [it_have], 0
    je .no
    mov eax, [m_x]
    sub eax, [it_px0]
    jl .no
    cmp eax, PGW
    jae .no
    mov eax, [m_y]
    cmp eax, VY0
    jb .no
    cmp eax, VY0 + VH
    jae .no
    sub eax, [it_dy]
    sub eax, PGGAP
    jl .no
    xor edx, edx
    mov ebx, PGH + PGGAP
    div ebx
    cmp eax, [it_np]
    jae .no
    cmp edx, PGH
    jae .no
    clc
    jmp .r
.no:stc
.r: pop edx
    pop ebx
    pop eax
    ret

; it_lo, it_hi по выделению
it_lohi:
    push eax
    push ebx
    mov eax, [it_a]
    mov ebx, [it_p]
    cmp eax, ebx
    jbe .o
    xchg eax, ebx
.o: mov [it_lo], eax
    mov [it_hi], ebx
    pop ebx
    pop eax
    ret

; Какие знаки печатать дальше: как у знака перед курсором
it_attrs:
    pushad
    mov eax, [it_p]
    test eax, eax
    jz .k
    dec eax
    cmp byte [IT_TXT + eax * 4], 10
    jne .k
    inc eax
.k: lea esi, [IT_TXT + eax * 4]
    mov al, [esi + 1]
    and al, 7
    mov [it_fl], al
    mov al, [esi + 2]
    mov [it_col], al
    mov al, [esi + 3]
    mov [it_sz], al
    popad
    ret

; Выравнивание абзаца с курсором (0, 1, 2) -> eax
it_curalign:
    push ecx
    mov ecx, [it_p]
.l: cmp ecx, [it_n]
    jae .e
    cmp byte [IT_TXT + ecx * 4], 10
    je .e
    inc ecx
    jmp .l
.e: movzx eax, byte [IT_TXT + ecx * 4 + 1]
    shr eax, 3
    and eax, 3
    pop ecx
    ret

; Задать прокрутку eax (в пределах документа)
it_setscroll:
    push ebx
    push edx
    mov ebx, [it_np]
    imul ebx, PGH + PGGAP
    add ebx, PGGAP
    sub ebx, VH
    jge .m
    xor ebx, ebx
.m: cmp eax, ebx
    jle .a
    mov eax, ebx
.a: test eax, eax
    jge .b
    xor eax, eax
.b: mov [it_scroll], eax
    mov edx, VY0
    sub edx, eax
    mov [it_dy], edx
    pop edx
    pop ebx
    ret

; Прокрутить так, чтобы курсор был виден
it_showcaret:
    pushad
    mov eax, [it_p]
    call it_lineof
    shl eax, 4
    mov ebx, [IT_LN + eax + 8]          ; y строки
    movzx ecx, word [IT_LN + eax + 14]
    mov eax, [it_scroll]
    mov edx, ebx
    sub edx, 12
    cmp edx, eax
    jge .d
    mov eax, edx
    jmp .s
.d: lea edx, [ebx + ecx + 12 - VH]
    cmp edx, eax
    jle .s
    mov eax, edx
.s: call it_setscroll
    popad
    ret


; ---------- рисование ----------
; Прямоугольник r_x, r_y, r_w, r_h цвета r_c: на экран или (при экспорте) в память IT_EXP
it_rect:
    cmp byte [it_tobuf], 0
    jne .buf
    jmp fill_rect
.buf:
    cmp byte [it_tobuf], 2
    je it_rect2
    pushad
    mov eax, [r_x]
    mov ebx, [r_y]
    mov ecx, eax
    add ecx, [r_w]                      ; x1
    mov edx, ebx
    add edx, [r_h]                      ; y1
    test eax, eax
    jge .a
    xor eax, eax
.a: cmp ecx, PGW
    jle .b
    mov ecx, PGW
.b: test ebx, ebx
    jge .c
    xor ebx, ebx
.c: cmp edx, [it_exh]
    jle .d
    mov edx, [it_exh]
.d: sub ecx, eax
    jle .r
    sub edx, ebx
    jle .r
    imul edi, ebx, PGW
    add edi, eax
    add edi, IT_EXP
    mov al, [r_c]
    cld
.l: push ecx
    push edi
    rep stosb
    pop edi
    pop ecx
    add edi, PGW
    dec edx
    jnz .l
.r: popad
    ret

; Прямоугольник в буфер области документа (режим 2): картинка собирается в памяти и выводится на экран за один раз, без мерцания
it_rect2:
    pushad
    mov eax, [r_x]
    mov ebx, [r_y]
    mov ecx, eax
    add ecx, [r_w]
    mov edx, ebx
    add edx, [r_h]
    cmp eax, [clp_x0]
    jge .a
    mov eax, [clp_x0]
.a: cmp ecx, [clp_x1]
    jle .b
    mov ecx, [clp_x1]
.b: cmp ebx, [clp_y0]
    jge .c
    mov ebx, [clp_y0]
.c: cmp edx, [clp_y1]
    jle .d
    mov edx, [clp_y1]
.d: sub ecx, eax
    jle .r
    sub edx, ebx
    jle .r
    sub ebx, VY0
    imul edi, ebx, VW
    sub eax, VX0
    add edi, eax
    add edi, IT_EXP
    mov al, [r_c]
    cld
.l: push ecx
    push edi
    rep stosb
    pop edi
    pop ecx
    add edi, VW
    dec edx
    jnz .l
.r: popad
    ret

; Буфер области документа -> экран (прямоугольник clp_*). Строка за строкой: сначала байты плоскостей собираются все сразу, потом пишутся по плоскостям
it_blit:
    pushad
    cld
    mov dx, 0x3CE
    mov ax, 0x0005
    out dx, ax
    mov ax, 0x0003
    out dx, ax
    mov ax, 0x0001
    out dx, ax
    mov ax, 0xFF08
    out dx, ax
    mov ecx, [clp_x0]
    and ecx, 7
    mov eax, 0xFF
    shr eax, cl
    mov [bl_lm], eax
    mov eax, [clp_x1]
    dec eax
    and eax, 7
    mov ecx, 7
    sub ecx, eax
    mov eax, 0xFF
    shl eax, cl
    and eax, 0xFF
    mov [bl_rm], eax
    mov eax, [clp_x0]
    shr eax, 3
    mov [bl_g0], eax
    mov eax, [clp_x1]
    dec eax
    shr eax, 3
    mov [bl_g1], eax
    mov ebx, [clp_y0]
.row:
    cmp ebx, [clp_y1]
    jge .done
    mov ebp, [bl_g0]
    mov edi, bl_row
    mov byte [bl_rd], 0
.g1:cmp ebp, [bl_g1]
    jg .p2
    mov eax, ebx
    sub eax, VY0
    imul eax, VW
    lea esi, [ebp * 8]
    add eax, esi
    sub eax, VX0
    lea esi, [IT_EXP + eax]
    cmp byte [it_shv], 0
    je .gat
    mov eax, [esi]
    cmp eax, [esi + IT_SHD - IT_EXP]
    jne .gat
    mov eax, [esi + 4]
    cmp eax, [esi + 4 + IT_SHD - IT_EXP]
    jne .gat
    mov eax, edi
    sub eax, bl_row
    shr eax, 2
    mov byte [bl_ch + eax], 0
    add edi, 4
    inc ebp
    jmp .g1
.gat:
    mov eax, [esi]
    mov [esi + IT_SHD - IT_EXP], eax
    mov eax, [esi + 4]
    mov [esi + 4 + IT_SHD - IT_EXP], eax
    mov eax, edi
    sub eax, bl_row
    shr eax, 2
    mov byte [bl_ch + eax], 1
    mov byte [bl_rd], 1
    xor edx, edx
    mov ecx, 8
.px:movzx eax, byte [esi]
    inc esi
    and eax, 15
    shl edx, 1
    or edx, [it_spread + eax * 4]
    dec ecx
    jnz .px
    mov [edi], edx
    add edi, 4
    inc ebp
    jmp .g1
.p2:cmp byte [bl_rd], 0
    je .pn2
    mov eax, ebx
    imul eax, 100
    add eax, VGA
    mov [bl_vb], eax
    xor ecx, ecx
.pl:mov [bl_pl], ecx
    mov eax, 1
    shl eax, cl
    mov ah, al
    mov al, 2
    mov dx, 0x3C4
    out dx, ax
    mov ebp, [bl_g0]
    mov esi, bl_row
.g2:cmp ebp, [bl_g1]
    jg .pn
    mov eax, ebp
    sub eax, [bl_g0]
    cmp byte [bl_ch + eax], 0
    je .gn
    mov eax, [esi]
    mov ecx, [bl_pl]
    shl ecx, 3
    shr eax, cl
    mov edi, [bl_vb]
    add edi, ebp
    mov edx, 0xFF
    cmp ebp, [bl_g0]
    jne .e1
    and edx, [bl_lm]
.e1:cmp ebp, [bl_g1]
    jne .e2
    and edx, [bl_rm]
.e2:cmp edx, 0xFF
    je .pw
    mov ecx, eax
    mov al, [edi]
    mov ah, dl
    mov al, 8
    mov dx, 0x3CE
    out dx, ax
    mov eax, ecx
    mov [edi], al
    mov ax, 0xFF08
    out dx, ax
    jmp .gn
.pw:mov [edi], al
.gn:add esi, 4
    inc ebp
    jmp .g2
.pn:mov ecx, [bl_pl]
    inc ecx
    cmp ecx, 4
    jb .pl
.pn2:
    inc ebx
    jmp .row
.done:
    mov byte [it_shv], 1
    mov dx, 0x3C4
    mov ax, 0x0F02
    out dx, ax
    popad
    ret

; Один знак: gch, gx, gy (левый верх), gsz, gfl, gcol
it_glyph:
    pushad
    cld
    movzx esi, byte [gch]
    shl esi, 4
    add esi, [0x500]
    mov eax, [gcol]
    mov [r_c], eax
    xor ebx, ebx                        ; строка шрифта
.row:
    movzx eax, byte [esi + ebx]
    test byte [gfl], 1
    jz .nb
    mov ecx, eax
    shr ecx, 1
    or eax, ecx                         ; жирный
.nb:cmp ebx, 15
    jne .nu
    test byte [gfl], 2
    jz .nu
    mov eax, 0xFF                       ; подчёркивание
.nu:and eax, 0xFF
    jz .nr
    xor edi, edi
    test byte [gfl], 4
    jz .ni
    mov edi, 15
    sub edi, ebx
    imul edi, [gsz]
    shr edi, 2                          ; курсив: верх сдвинут вправо
.ni:xor ecx, ecx
.col:
    cmp ecx, 8
    jae .nr
    mov edx, 0x80
    shr edx, cl
    test eax, edx
    jz .sk
    mov ebp, ecx                        ; начало серии
.ru:inc ecx
    cmp ecx, 8
    jae .rd
    mov edx, 0x80
    shr edx, cl
    test eax, edx
    jnz .ru
.rd:mov edx, ebp
    imul edx, [gsz]
    add edx, edi
    add edx, [gx]
    mov [r_x], edx
    mov edx, ebx
    imul edx, [gsz]
    add edx, [gy]
    mov [r_y], edx
    mov edx, ecx
    sub edx, ebp
    imul edx, [gsz]
    mov [r_w], edx
    mov edx, [gsz]
    mov [r_h], edx
    call it_rect
    jmp .col
.sk:inc ecx
    jmp .col
.nr:inc ebx
    cmp ebx, 16
    jb .row
    popad
    ret

; Всё содержимое области документа в пределах clp_*: страницы, текст, картинки, рамка, курсор
it_view:
    pushad
    cld
    call it_lohi
    cmp byte [it_tobuf], 1
    je .ex
    RC VX0, VY0, VW, VH, C_GRAY
    cmp byte [it_have], 0
    jne .pg
    mov esi, s_hint                     ; документа ещё нет
    call strlen
    shl ecx, 4
    mov eax, VX0 + VW / 2
    shr ecx, 1
    sub eax, ecx
    mov [t_x], eax
    mov dword [t_y], 260
    mov dword [r_c], C_BLACK
    mov esi, s_hint
    call draw_big
    jmp .out
.ex:mov dword [r_x], 0
    mov dword [r_y], 0
    mov dword [r_w], PGW
    mov eax, [it_exh]
    mov [r_h], eax
    mov dword [r_c], C_WHITE
    call it_rect
.pg:xor ebx, ebx
.pl:cmp ebx, [it_np]
    jae .tx
    mov eax, ebx
    imul eax, PGH + PGGAP
    add eax, PGGAP
    add eax, [it_dy]                    ; верх страницы на экране
    cmp byte [it_tobuf], 1
    je .ns
    mov ecx, [it_px0]
    add ecx, 4
    mov [r_x], ecx
    lea ecx, [eax + 4]
    mov [r_y], ecx
    mov dword [r_w], PGW
    mov dword [r_h], PGH
    mov dword [r_c], C_BLACK
    call it_rect                        ; тень
.ns:mov ecx, [it_px0]
    mov [r_x], ecx
    mov [r_y], eax
    mov dword [r_w], PGW
    mov dword [r_h], PGH
    mov dword [r_c], C_WHITE
    call it_rect
    inc ebx
    jmp .pl
.tx:xor ebx, ebx                        ; строки
.ln:cmp ebx, [it_nl]
    jae .pics
    mov edx, ebx
    shl edx, 4
    add edx, IT_LN
    mov eax, [edx + 8]
    add eax, [it_dy]
    mov [vw_y], eax
    movzx ecx, word [edx + 14]
    mov [vw_h], ecx
    add eax, ecx
    cmp eax, [clp_y0]
    jle .nl
    mov eax, [vw_y]
    cmp eax, [clp_y1]
    jge .nl
    movzx eax, word [edx + 12]
    add eax, [it_px0]
    add eax, PGM
    mov [vw_x], eax
    mov esi, [edx]
    mov edi, [edx + 4]
.ch:cmp esi, edi
    jae .nl
    lea ebp, [IT_TXT + esi * 4]
    movzx eax, byte [ebp + 3]
    mov [gsz], eax
    lea ecx, [eax * 8]                  ; ширина знака
    mov eax, [vw_x]
    add eax, ecx
    cmp eax, [clp_x0]
    jle .ad
    mov eax, [vw_x]
    cmp eax, [clp_x1]
    jge .ad
    movzx eax, byte [ebp + 2]
    mov [gcol], eax
    cmp esi, [it_lo]
    jb .ns2
    cmp esi, [it_hi]
    jae .ns2
    mov eax, [vw_x]                     ; выделенный знак: синяя подложка, белые буквы
    mov [r_x], eax
    mov eax, [vw_y]
    mov [r_y], eax
    mov [r_w], ecx
    mov eax, [vw_h]
    mov [r_h], eax
    mov dword [r_c], C_BLACK
    call it_rect
    mov dword [gcol], C_WHITE
.ns2:
    cmp byte [ebp], 10
    je .ad
    mov al, [ebp]
    mov [gch], al
    mov al, [ebp + 1]
    and al, 7
    mov [gfl], al
    mov eax, [gsz]
    shl eax, 4
    mov edx, [vw_h]
    sub edx, eax
    add edx, [vw_y]
    mov [gy], edx
    mov eax, [vw_x]
    mov [gx], eax
    call it_glyph
.ad:add [vw_x], ecx
    inc esi
    jmp .ch
.nl:inc ebx
    jmp .ln
.pics:
    xor ebx, ebx
.po:cmp ebx, [it_on]
    jae .fr
    mov eax, ebx
    imul eax, IT_ESZ
    lea esi, [it_obj + eax]
    cmp byte [it_drag], 1
    jb .dp
    cmp byte [it_drag], 3
    ja .dp
    cmp ebx, [it_sel]
    je .pn                              ; пока двигают - только рамка
.dp:call it_dpic
.pn:inc ebx
    jmp .po
.fr:cmp byte [it_tobuf], 1
    je .out
    mov eax, [it_sel]
    cmp eax, 0
    jl .cr
    cmp eax, [it_on]
    jae .cr
    imul eax, IT_ESZ
    lea esi, [it_obj + eax]
    call it_frame
    jmp .out
.cr:cmp byte [it_focus], 0              ; курсор
    je .out
    mov eax, [it_lo]
    cmp eax, [it_hi]
    jne .out
    mov eax, [it_p]
    call it_lineof
    mov esi, eax
    mov eax, [it_p]
    call it_xof
    mov ebx, esi
    shl ebx, 4
    add eax, [it_px0]
    add eax, PGM
    dec eax
    mov [r_x], eax
    mov eax, [IT_LN + ebx + 8]
    add eax, [it_dy]
    mov [r_y], eax
    mov dword [r_w], 2
    movzx eax, word [IT_LN + ebx + 14]
    mov [r_h], eax
    mov dword [r_c], C_BLACK
    call it_rect
.out:
    popad
    ret

; ---------- картинки ----------
; Геометрия картинки esi на экране: g_cx, g_cy, g_w, g_h, g_cos, g_sin (в 256-х долях)
it_geom:
    pushad
    mov eax, [esi + 4]
    add eax, [it_px0]
    mov [g_cx], eax
    mov eax, [esi + 8]
    add eax, [it_dy]
    mov [g_cy], eax
    mov eax, [esi + 28]
    mov [g_w], eax
    mov eax, [esi + 32]
    mov [g_h], eax
    mov eax, [esi + 12]
    xor edx, edx
    mov ecx, 5
    div ecx
    mov ecx, eax
    call it_sin72
    mov [g_sin], eax
    add ecx, 18
    cmp ecx, 72
    jb .c
    sub ecx, 72
.c: call it_sin72
    mov [g_cos], eax
    popad
    ret

; sin(k * 5 градусов) * 256, k = ecx (0..71) -> eax
it_sin72:
    push ebx
    push ecx
    xor ebx, ebx
    cmp ecx, 36
    jb .a
    sub ecx, 36
    mov ebx, 1
.a: cmp ecx, 18
    jbe .b
    neg ecx
    add ecx, 36
.b: movzx eax, word [it_sintab + ecx * 2]
    test ebx, ebx
    jz .c
    neg eax
.c: pop ecx
    pop ebx
    ret

; Нарисовать картинку esi (белый - прозрачный): для каждой точки экрана обратный поворот в картинку
it_dpic:
    pushad
    cld
    call it_geom
    mov eax, [esi + 24]
    shl eax, 16
    add eax, IT_PIC
    mov [dp_base], eax
    mov eax, [esi + 16]
    mov [dp_sw], eax
    shl eax, 16
    xor edx, edx
    div dword [g_w]
    mov [dp_fx], eax                    ; шаг по картинке на точку экрана (16.16)
    mov eax, [esi + 20]
    shl eax, 16
    xor edx, edx
    div dword [g_h]
    mov [dp_fy], eax
    mov eax, [g_cos]                    ; половины рамки, описывающей повёрнутую картинку
    test eax, eax
    jns .c1
    neg eax
.c1:imul eax, [g_w]
    mov ebx, [g_sin]
    test ebx, ebx
    jns .s1
    neg ebx
.s1:imul ebx, [g_h]
    add eax, ebx
    sar eax, 9
    inc eax
    mov [dp_ex], eax
    mov eax, [g_cos]
    test eax, eax
    jns .c2
    neg eax
.c2:imul eax, [g_h]
    mov ebx, [g_sin]
    test ebx, ebx
    jns .s2
    neg ebx
.s2:imul ebx, [g_w]
    add eax, ebx
    sar eax, 9
    inc eax
    mov [dp_ey], eax
    mov eax, [g_cy]                     ; строки
    sub eax, [dp_ey]
    mov [dp_y], eax
    mov eax, [g_cy]
    add eax, [dp_ey]
    mov [dp_y1], eax
    mov eax, [g_cx]
    sub eax, [dp_ex]
    mov [dp_x0], eax
    mov eax, [g_cx]
    add eax, [dp_ex]
    mov [dp_x1], eax
    mov eax, [dp_x0]                    ; обрезать по clp_*
    cmp eax, [clp_x0]
    jge .x0
    mov eax, [clp_x0]
.x0:mov [dp_x0], eax
    mov eax, [dp_x1]
    cmp eax, [clp_x1]
    jle .x1
    mov eax, [clp_x1]
.x1:mov [dp_x1], eax
    mov eax, [dp_y]
    cmp eax, [clp_y0]
    jge .y0
    mov eax, [clp_y0]
.y0:mov [dp_y], eax
    mov eax, [dp_y1]
    cmp eax, [clp_y1]
    jle .y1
    mov eax, [clp_y1]
.y1:mov [dp_y1], eax
    mov eax, [g_w]
    shr eax, 1
    mov [dp_hw], eax
    mov eax, [g_h]
    shr eax, 1
    mov [dp_hh], eax
.row:
    mov eax, [dp_y]
    cmp eax, [dp_y1]
    jge .end
    mov ebp, [dp_x0]
    cmp ebp, [dp_x1]
    jge .nrow
    mov ebx, ebp
    sub ebx, [g_cx]                     ; rx
    mov ecx, eax
    sub ecx, [g_cy]                     ; ry
    mov esi, ebx
    imul esi, [g_cos]
    mov edx, ecx
    imul edx, [g_sin]
    add esi, edx                        ; U (256-е доли)
    mov edi, ecx
    imul edi, [g_cos]
    imul ebx, [g_sin]
    sub edi, ebx                        ; V
    mov dword [dp_rc], -1               ; серия
.px:cmp ebp, [dp_x1]
    jge .flush
    mov eax, esi
    sar eax, 8
    add eax, [dp_hw]
    js .out
    cmp eax, [g_w]
    jae .out
    mov ecx, edi
    sar ecx, 8
    add ecx, [dp_hh]
    js .out
    cmp ecx, [g_h]
    jae .out
    mul dword [dp_fx]
    shrd eax, edx, 16
    mov ebx, eax                        ; x в картинке
    mov eax, ecx
    mul dword [dp_fy]
    shrd eax, edx, 16
    imul eax, [dp_sw]
    add eax, ebx
    add eax, [dp_base]
    movzx eax, byte [eax]
    cmp eax, 15
    je .out
    cmp eax, [dp_rc]
    jne .nc
    inc dword [dp_rl]
    jmp .nx
.nc:call it_dflush
    mov [dp_rc], eax
    mov [dp_rx], ebp
    mov dword [dp_rl], 1
    jmp .nx
.out:
    call it_dflush
    mov dword [dp_rc], -1
.nx:add esi, [g_cos]
    sub edi, [g_sin]
    inc ebp
    jmp .px
.flush:
    call it_dflush
.nrow:
    inc dword [dp_y]
    jmp .row
.end:
    popad
    ret

; Вывести серию точек одного цвета (dp_rc, dp_rx, dp_rl) в строке dp_y
it_dflush:
    cmp dword [dp_rc], 0
    jl .r
    push eax
    mov eax, [dp_rc]
    mov [r_c], eax
    mov eax, [dp_rx]
    mov [r_x], eax
    mov eax, [dp_y]
    mov [r_y], eax
    mov eax, [dp_rl]
    mov [r_w], eax
    mov dword [r_h], 1
    call it_rect
    pop eax
.r: ret

; Рамка выделенной картинки esi: серые точки по краю и квадратики в углах
it_frame:
    pushad
    call it_geom
    mov eax, [g_w]
    shr eax, 1
    add eax, 4
    mov [fr_hx], eax
    mov eax, [g_h]
    shr eax, 1
    add eax, 4
    mov [fr_hy], eax
    mov dword [r_c], C_GRAY2
    mov ebx, [fr_hx]
    neg ebx
.t: mov eax, ebx
    mov ecx, [fr_hy]
    neg ecx
    call it_fp
    mov eax, ebx
    mov ecx, [fr_hy]
    call it_fp
    add ebx, 6
    cmp ebx, [fr_hx]
    jle .t
    mov ebx, [fr_hy]
    neg ebx
.s: mov ecx, ebx
    mov eax, [fr_hx]
    neg eax
    call it_fp
    mov ecx, ebx
    mov eax, [fr_hx]
    call it_fp
    add ebx, 6
    cmp ebx, [fr_hy]
    jle .s
    xor ebx, ebx                        ; углы: квадратики 8 на 8
.h: mov eax, [fr_hx]
    test ebx, 1
    jz .h1
    neg eax
.h1:mov ecx, [fr_hy]
    test ebx, 2
    jz .h2
    neg ecx
.h2:call it_rot
    sub eax, 4
    sub ecx, 4
    mov [r_x], eax
    mov [r_y], ecx
    mov dword [r_w], 8
    mov dword [r_h], 8
    mov dword [r_c], C_BLACK
    call it_rect
    inc ebx
    cmp ebx, 4
    jb .h
    popad
    ret

; Точка рамки: eax = u, ecx = v (в системе картинки) -> экран, 2 на 2
it_fp:
    pushad
    call it_rot
    dec eax
    dec ecx
    mov [r_x], eax
    mov [r_y], ecx
    mov dword [r_w], 2
    mov dword [r_h], 2
    call it_rect
    popad
    ret

; (eax = u, ecx = v) -> (eax = x, ecx = y) на экране
it_rot:
    push ebx
    push edx
    mov ebx, ecx
    mov ecx, [g_cos]
    imul ecx, eax
    mov edx, ebx
    imul edx, [g_sin]
    sub ecx, edx
    sar ecx, 8                          ; x
    imul eax, [g_sin]
    imul ebx, [g_cos]
    add eax, ebx
    sar eax, 8                          ; y
    add ecx, [g_cx]
    add eax, [g_cy]
    xchg eax, ecx
    pop edx
    pop ebx
    ret


; ---------- экран ----------
; Кнопка: x, y, ширина, высота, строка, edi = 1 - нажата
%macro IBTN 6
    mov eax, %1
    mov ebx, %2
    mov ecx, %3
    mov edx, %4
    mov esi, %5
    mov edi, %6
    call it_btn
%endmacro

it_btn:
    pushad
    mov [bb_x], eax
    mov [bb_y], ebx
    mov [bb_w], ecx
    mov [bb_h], edx
    mov [bb_s], esi
    mov dword [bb_f], C_WHITE
    mov dword [bb_t], C_BLACK
    test edi, edi
    jz .np
    mov dword [bb_f], C_BLACK
    mov dword [bb_t], C_WHITE
.np:mov eax, [bb_x]
    mov [r_x], eax
    mov eax, [bb_y]
    mov [r_y], eax
    mov eax, [bb_w]
    mov [r_w], eax
    mov eax, [bb_h]
    mov [r_h], eax
    mov dword [r_c], C_BLACK
    call fill_rect
    add dword [r_x], 2
    add dword [r_y], 2
    sub dword [r_w], 4
    sub dword [r_h], 4
    mov eax, [bb_f]
    mov [r_c], eax
    call fill_rect
    mov esi, [bb_s]
    call strlen
    shl ecx, 4
    mov eax, [bb_w]
    sub eax, ecx
    shr eax, 1
    add eax, [bb_x]
    mov [t_x], eax
    mov eax, [bb_h]
    sub eax, 32
    shr eax, 1
    add eax, [bb_y]
    mov [t_y], eax
    mov eax, [bb_t]
    mov [r_c], eax
    mov esi, [bb_s]
    call draw_big
    popad
    ret

; Строка esi по центру экрана, t_y задан
it_center:
    mov dword [r_c], C_BLACK
    call strlen
    shl ecx, 4
    mov eax, 800
    sub eax, ecx
    shr eax, 1
    mov [t_x], eax
    jmp draw_big

; Прямоугольник на экране (всегда fill_rect), любые операнды
%macro RC_S 5
    mov eax, %1
    mov [r_x], eax
    mov eax, %2
    mov [r_y], eax
    mov eax, %3
    mov [r_w], eax
    mov eax, %4
    mov [r_h], eax
    mov eax, %5
    mov [r_c], eax
    call fill_rect
%endmacro

; Значок слева: edi = 1 - нажат. eax = x, ebx = y, edx = номер значка (0 цвет, 1..3 выравнивание)
it_icon:
    pushad
    mov [ic_x], eax
    mov [ic_y], ebx
    mov [ic_n], edx
    mov dword [ic_bg], C_WHITE
    mov dword [ic_fg], C_BLACK
    test edi, edi
    jz .a
    mov dword [ic_bg], C_BLACK
    mov dword [ic_fg], C_WHITE
.a: RC_S [ic_x], [ic_y], 48, 48, C_BLACK
    mov eax, [ic_x]
    add eax, 2
    mov ebx, [ic_y]
    add ebx, 2
    RC_S eax, ebx, 44, 44, [ic_bg]
    cmp dword [ic_n], 4
    jae .ar
    cmp dword [ic_n], 0
    jne .al
    mov eax, [ic_fg]                    ; значок цвета: буква A и под ней полоска текущего цвета
    mov [gcol], eax
    mov dword [gsz], 2
    mov dword [gfl], 1
    mov dword [gch], 'A'
    mov eax, [ic_x]
    add eax, 14
    mov [gx], eax
    mov eax, [ic_y]
    add eax, 2
    mov [gy], eax
    call it_glyph
    movzx ebx, byte [it_col]
    mov eax, [ic_x]
    add eax, 8
    mov edx, [ic_y]
    add edx, 36
    RC_S eax, edx, 32, 6, ebx
    jmp .r
.al:                                    ; значок выравнивания: четыре линии
    xor ebx, ebx
.ln:movzx ecx, byte [it_icw + ebx]      ; ширина линии
    mov eax, 32
    sub eax, ecx                        ; свободное место
    cmp dword [ic_n], 2
    jne .l2
    shr eax, 1
    jmp .l4
.l2:cmp dword [ic_n], 3
    je .l4
    xor eax, eax
.l4:add eax, [ic_x]
    add eax, 8
    mov edx, ebx
    imul edx, 9
    add edx, [ic_y]
    add edx, 8
    RC_S eax, edx, ecx, 3, [ic_fg]
    inc ebx
    cmp ebx, 4
    jb .ln
    jmp .r
.ar:                                    ; стрелка назад (4) или вперёд (5)
    mov eax, [ic_x]
    cmp dword [ic_n], 4
    jne .sr
    add eax, 24
    jmp .ss
.sr:add eax, 8
.ss:mov [r_x], eax
    mov eax, [ic_y]
    add eax, 22
    mov [r_y], eax
    mov dword [r_w], 16
    mov dword [r_h], 4
    mov eax, [ic_fg]
    mov [r_c], eax
    call fill_rect
    xor ebx, ebx
.hd:mov eax, [ic_x]
    cmp dword [ic_n], 4
    jne .hr
    lea eax, [eax + ebx * 2 + 8]
    jmp .hs
.hr:add eax, 38
    sub eax, ebx
    sub eax, ebx
.hs:mov [r_x], eax
    mov eax, [ic_y]
    add eax, 23
    sub eax, ebx
    mov [r_y], eax
    mov dword [r_w], 2
    lea eax, [ebx * 2 + 2]
    mov [r_h], eax
    mov eax, [ic_fg]
    mov [r_c], eax
    call fill_rect
    inc ebx
    cmp ebx, 8
    jb .hd
.r: popad
    ret

itge_draw:
    pushad
    cld
    call mclip_off
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    mov byte [it_tobuf], 0
    RECT 0, 0, 800, 80, C_WHITE
    RECT 0, 38, 800, 2, C_BLACK
    RECT 0, 78, 800, 2, C_BLACK
    RECT 0, 80, VX0 - 2, 520, C_WHITE
    RECT VX0 - 2, 80, 2, 520, C_BLACK
    mov dword [r_c], C_BLACK
    mov dword [t_x], 8
    mov dword [t_y], 2
    mov esi, it_nm
    call draw_big
    mov dword [t_y], 2
    mov esi, s_title
    call it_center
    xor edi, edi
    cmp byte [it_menu], 0
    je .f0
    inc edi
.f0:IBTN 4, 42, 80, 34, s_file, edi
    call it_icons
    mov byte [it_shv], 0
    call it_vscreen
    call it_scrollbar
    call it_overlays
    mov al, [it_menu]
    or al, [it_cp]
    or al, [it_rm]
    jz .nov
    mov byte [it_shv], 0
.nov:
    call mn_pdraw
    popad
    ret

; Область документа на экран
it_vscreen:
    pushad
    mov dword [clp_x0], VX0
    mov dword [clp_y0], VY0
    mov dword [clp_x1], VX0 + VW
    mov dword [clp_y1], VY0 + VH
    call it_viewb
    call mclip_off
    popad
    ret

; Нарисовать область документа через буфер (clp_* заданы); без документа - прямо на экран
it_viewb:
    cmp byte [it_have], 0
    jne .b
    mov byte [it_shv], 0
    jmp it_view
.b:
    mov byte [it_tobuf], 2
    call it_view
    mov byte [it_tobuf], 0
    jmp it_blit

; Полоса прокрутки: нужна, только если документ не помещается
it_scrollbar:
    pushad
    mov eax, [it_scroll]
    mov [it_lsc], eax
    mov eax, [it_np]
    mov [it_lnp], eax
    RECT SBX, VY0, 16, VH, C_GRAY
    call it_docheight
    cmp eax, VH
    jle .r
    mov ebx, eax                        ; всего
    RECT SBX, VY0, 16, VH, C_BLACK
    RECT SBX + 2, VY0 + 2, 12, VH - 4, C_GRAY
    mov eax, VH - 4
    imul eax, VH
    xor edx, edx
    div ebx
    cmp eax, 24
    jae .l1
    mov eax, 24
.l1:mov [sb_len], eax
    mov ecx, VH - 4
    sub ecx, eax                        ; ход ползунка
    mov eax, [it_scroll]
    imul eax, ecx
    mov edx, ebx
    sub edx, VH
    jle .p0
    mov ebx, edx
    xor edx, edx
    div ebx
    jmp .p1
.p0:xor eax, eax
.p1:add eax, VY0 + 2
    mov [sb_pos], eax
    mov [r_y], eax
    mov dword [r_x], SBX + 2
    mov dword [r_w], 12
    mov eax, [sb_len]
    mov [r_h], eax
    mov dword [r_c], C_WHITE
    call fill_rect
    mov eax, [sb_pos]
    mov [r_y], eax
    mov dword [r_x], SBX + 2
    mov dword [r_w], 12
    mov dword [r_h], 2
    mov dword [r_c], C_BLACK
    call fill_rect
    mov eax, [sb_pos]
    add eax, [sb_len]
    sub eax, 2
    mov [r_y], eax
    call fill_rect
.r: popad
    ret

; Высота документа -> eax
it_docheight:
    xor eax, eax
    cmp byte [it_have], 0
    je .r
    mov eax, [it_np]
    imul eax, PGH + PGGAP
    add eax, PGGAP
.r: ret

; Меню File, панель цветов и правое меню поверх
it_overlays:
    pushad
    cmp byte [it_menu], 0
    je .nm
    RECT 8, 86, 336, 36 * IT_MENUN, C_BLACK
    RECT 4, 82, 336, 36 * IT_MENUN, C_BLACK
    RECT 6, 84, 332, 36 * IT_MENUN - 4, C_WHITE
    mov dword [t_x], 12
    mov dword [t_y], 84
    xor ebx, ebx
.mi:mov dword [r_c], C_BLACK
    cmp ebx, 4
    jne .m1
    mov dword [r_c], C_GRAY2            ; Print пока не работает
.m1:mov esi, [it_fm + ebx * 4]
    call draw_big
    mov esi, [it_ks + ebx * 4]
    mov dword [t_x], 196
    call draw_big
    mov dword [t_x], 12
    add dword [t_y], 36
    inc ebx
    cmp ebx, IT_MENUN
    jb .mi
.nm:cmp byte [it_cp], 0
    je .ncp
    RECT 76, 90, 184, 48, C_BLACK
    RECT 72, 86, 184, 48, C_BLACK
    RECT 74, 88, 180, 44, C_WHITE
    xor ebp, ebp
.pl:mov eax, ebp
    and eax, 7
    imul eax, 44
    add eax, 76
    mov [r_x], eax
    mov eax, ebp
    shr eax, 3
    imul eax, 44
    add eax, 90
    mov [r_y], eax
    mov dword [r_w], 40
    mov dword [r_h], 40
    mov dword [r_c], C_BLACK
    call fill_rect
    add dword [r_x], 2
    add dword [r_y], 2
    mov dword [r_w], 36
    mov dword [r_h], 36
    movzx eax, byte [it_swc + ebp]
    mov [r_c], eax
    call fill_rect
    inc ebp
    cmp ebp, 4
    jb .pl
.ncp:
    movzx ecx, byte [it_rm]
    test ecx, ecx
    jz .e
    call it_rmcount
    mov [it_rmn], eax
    mov ecx, eax
    imul ecx, RMH
    mov esi, [it_rmx]
    mov edi, [it_rmy]
    lea eax, [esi + 4]
    mov [r_x], eax
    lea eax, [edi + 4]
    mov [r_y], eax
    mov dword [r_w], RMW
    mov [r_h], ecx
    mov dword [r_c], C_BLACK
    call fill_rect
    mov [r_x], esi
    mov [r_y], edi
    call fill_rect
    add dword [r_x], 2
    add dword [r_y], 2
    mov dword [r_w], RMW - 4
    sub ecx, 4
    mov [r_h], ecx
    mov dword [r_c], C_WHITE
    call fill_rect
    mov ebx, it_rm2
    cmp byte [it_rm], 1
    jne .rl
    mov ebx, it_rm1
.rl:xor ebp, ebp
.ri:mov eax, ebp
    imul eax, RMH
    add eax, [it_rmy]
    mov [mi_y], eax
    mov edx, it_ri2
    cmp byte [it_rm], 1
    jne .ic
    mov edx, it_ri1
.ic:movzx edx, byte [edx + ebp]
    call it_rmicon
    mov eax, [it_rmx]
    add eax, 44
    mov [t_x], eax
    mov eax, [mi_y]
    inc eax
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, [ebx + ebp * 4]
    call draw_big
    inc ebp
    cmp ebp, [it_rmn]
    jb .ri
.e: popad
    ret

; Значок пункта правого меню: edx = 0 B, 1 I, 2 U, 3 A+, 4 A-, 5 вырезать, 6 копировать, 7 вставить, 8 удалить
it_rmicon:
    pushad
    mov eax, [it_rmx]
    add eax, 6
    mov [ic_x], eax
    mov eax, [mi_y]
    mov [ic_y], eax
    cmp edx, 5
    jae .bmp
    mov dword [gcol], C_BLACK
    mov dword [gsz], 2
    mov dword [gfl], 0
    mov eax, [ic_x]
    add eax, 8
    mov [gx], eax
    mov eax, [ic_y]
    inc eax
    mov [gy], eax
    mov dword [gch], 'B'
    cmp edx, 0
    jne .i1
    mov dword [gfl], 1
    jmp .g
.i1:cmp edx, 1
    jne .i2
    mov dword [gch], 'I'
    mov dword [gfl], 4
    jmp .g
.i2:cmp edx, 2
    jne .i3
    mov dword [gch], 'U'
    mov dword [gfl], 2
    jmp .g
.i3:mov dword [gch], 'A'
    sub dword [gx], 6
    call it_glyph
    mov dword [gsz], 1
    add dword [gx], 22
    add dword [gy], 12
    mov dword [gch], '+'
    cmp edx, 3
    je .g
    mov dword [gch], '-'
.g: call it_glyph
    jmp .r
.bmp:
    sub edx, 5
    shl edx, 5
    lea esi, [it_bmps + edx]
    xor ebx, ebx
.br:movzx eax, word [esi + ebx * 2]
    xor ecx, ecx
.bc:cmp ecx, 16
    jae .bn
    mov edx, 0x8000
    shr edx, cl
    test eax, edx
    jz .bs
    mov ebp, ecx
.bk:inc ecx
    cmp ecx, 16
    jae .be
    mov edx, 0x8000
    shr edx, cl
    test eax, edx
    jnz .bk
.be:mov edx, ebp
    shl edx, 1
    add edx, [ic_x]
    mov [r_x], edx
    mov edx, ecx
    sub edx, ebp
    shl edx, 1
    mov [r_w], edx
    mov edx, ebx
    shl edx, 1
    add edx, [ic_y]
    inc edx
    mov [r_y], edx
    mov dword [r_h], 2
    mov dword [r_c], C_BLACK
    call fill_rect
    jmp .bc
.bs:inc ecx
    jmp .bc
.bn:inc ebx
    cmp ebx, 16
    jb .br
.r: popad
    ret

; Сколько пунктов в правом меню -> eax
it_rmcount:
    mov eax, 3
    cmp byte [it_rm], 1
    je .r
    mov eax, 9
.r: ret

; Палитра: 2 - зелёный, 3 - голубой, 4 - красный (у системы там цвета рабочего стола), остальные обычные
it_pal_on:
    pushad
    mov esi, it_dac
    mov ecx, 3
.l: mov dx, 0x3C8
    lodsb
    out dx, al
    inc dx
    lodsb
    out dx, al
    lodsb
    out dx, al
    lodsb
    out dx, al
    dec ecx
    jnz .l
    popad
    ret

it_dac    db 2, 0, 42, 0, 3, 0, 42, 42, 4, 42, 0, 0

; Строка esi в edi без нуля в конце
it_cat:
    lodsb
    test al, al
    jz .r
    stosb
    jmp it_cat
.r: ret

; Дождаться обратного хода луча: меньше разрывов картинки
it_vsync:
    push eax
    push ecx
    push edx
    mov dx, 0x3DA
    mov ecx, 60000
.a: in al, dx
    test al, 8
    jz .b
    dec ecx
    jnz .a
.b: mov ecx, 60000
.c: in al, dx
    test al, 8
    jnz .d
    dec ecx
    jnz .c
.d: pop edx
    pop ecx
    pop eax
    ret

; Перерисовать только область документа
it_redraw_view:
    call it_vscreen
    ret

; Квадрат вокруг картинки esi, который она может занять при любом повороте. eax = 0 - начать заново, 1 - добавить к запомненному
it_dirty:
    pushad
    mov ebp, eax
    call it_geom
    mov eax, [g_w]
    add eax, [g_h]
    shr eax, 1
    add eax, 14
    mov ebx, [g_cx]
    sub ebx, eax
    mov ecx, [g_cy]
    sub ecx, eax
    mov edx, [g_cx]
    add edx, eax
    add eax, [g_cy]
    test ebp, ebp
    jz .set
    cmp ebx, [it_ax0]
    jge .a
    mov [it_ax0], ebx
.a: cmp ecx, [it_ay0]
    jge .b
    mov [it_ay0], ecx
.b: cmp edx, [it_ax1]
    jle .c
    mov [it_ax1], edx
.c: cmp eax, [it_ay1]
    jle .e
    mov [it_ay1], eax
    jmp .e
.set:
    mov [it_ax0], ebx
    mov [it_ay0], ecx
    mov [it_ax1], edx
    mov [it_ay1], eax
.e: popad
    ret

; Перерисовать только квадрат it_a*
it_partial:
    pushad
    mov eax, [it_ax0]
    cmp eax, VX0
    jge .a
    mov eax, VX0
.a: and eax, -8
    mov [clp_x0], eax
    mov eax, [it_ay0]
    cmp eax, VY0
    jge .b
    mov eax, VY0
.b: mov [clp_y0], eax
    mov eax, [it_ax1]
    cmp eax, VX0 + VW
    jle .c
    mov eax, VX0 + VW
.c: add eax, 7
    and eax, -8
    cmp eax, VX0 + VW
    jle .c2
    mov eax, VX0 + VW
.c2:mov [clp_x1], eax
    mov eax, [it_ay1]
    cmp eax, VY0 + VH
    jle .d
    mov eax, VY0 + VH
.d: mov [clp_y1], eax
    call it_viewb
    call mclip_off
    popad
    ret


; ---------- ввод: что под мышью, нажатия, движение ----------
it_icons:
    pushad
    call it_curalign
    mov [it_lasta], eax
    xor edi, edi
    cmp byte [it_cp], 0
    je .i0
    inc edi
.i0:mov eax, 8
    mov ebx, 92
    xor edx, edx
    call it_icon
    call it_curalign
    mov ebp, eax
    xor ecx, ecx
.al:xor edi, edi
    cmp byte [it_have], 0
    je .a1
    cmp ebp, ecx
    jne .a1
    inc edi
.a1:mov eax, 8
    mov ebx, ecx
    imul ebx, 60
    add ebx, 152
    lea edx, [ecx + 1]
    push ecx
    call it_icon
    pop ecx
    inc ecx
    cmp ecx, 3
    jb .al
    mov eax, 8
    mov ebx, 332
    mov edx, 4
    xor edi, edi
    call it_icon
    mov eax, 8
    mov ebx, 392
    mov edx, 5
    xor edi, edi
    call it_icon
    popad
    ret

; Перерисовать область документа, полосу прокрутки и значки (без заголовка и меню)
it_refresh:
    pushad
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    call mclip_off
    call it_curalign
    cmp eax, [it_lasta]
    je .ni
    call it_icons
.ni:call it_redraw_view
    mov eax, [it_scroll]
    cmp eax, [it_lsc]
    jne .sb
    mov eax, [it_np]
    cmp eax, [it_lnp]
    je .nb
.sb:call it_scrollbar
.nb:popad
    ret

it_closeall:
    mov byte [it_menu], 0
    mov byte [it_cp], 0
    mov byte [it_rm], 0
    ret

; Картинка esi: eax = u, ecx = v - мышь в системе картинки (центр в нуле, ось по повороту)
it_uv:
    push ebx
    push edx
    call it_geom
    mov eax, [m_x]
    sub eax, [g_cx]
    mov ecx, [m_y]
    sub ecx, [g_cy]
    mov edx, eax
    imul edx, [g_cos]
    mov ebx, ecx
    imul ebx, [g_sin]
    add edx, ebx
    sar edx, 8
    imul eax, [g_sin]
    imul ecx, [g_cos]
    sub ecx, eax
    sar ecx, 8
    mov eax, edx
    pop edx
    pop ebx
    ret

; Картинка esi с центром (eax, ecx): сдвинуть так, чтобы она не выходила за страницы -> eax, ecx
it_fitxy:
    push ebx
    push edx
    push edi
    push ebp
    mov ebp, eax
    mov edi, ecx
    call it_geom
    mov eax, [g_cos]
    test eax, eax
    jns .a
    neg eax
.a: imul eax, [g_w]
    mov ebx, [g_sin]
    test ebx, ebx
    jns .b
    neg ebx
.b: imul ebx, [g_h]
    add eax, ebx
    sar eax, 9
    mov edx, eax
    mov eax, [g_cos]
    test eax, eax
    jns .c
    neg eax
.c: imul eax, [g_h]
    mov ebx, [g_sin]
    test ebx, ebx
    jns .d
    neg ebx
.d: imul ebx, [g_w]
    add eax, ebx
    sar eax, 9
    mov ebx, eax
    mov eax, PGW
    sub eax, edx
    cmp edx, eax
    jg .cx
    cmp ebp, edx
    jge .x1
    mov ebp, edx
.x1:cmp ebp, eax
    jle .x2
    mov ebp, eax
    jmp .x2
.cx:mov ebp, PGW / 2
.x2:mov edx, [it_np]
    imul edx, PGH + PGGAP
    sub edx, ebx
    lea eax, [ebx + PGGAP]
    cmp eax, edx
    jg .cy
    cmp edi, eax
    jge .y1
    mov edi, eax
.y1:cmp edi, edx
    jle .y3
    mov edi, edx
    jmp .y3
.cy:mov edi, PGGAP + PGH / 2
.y3:mov eax, ebp
    mov ecx, edi
    pop ebp
    pop edi
    pop edx
    pop ebx
    ret

; Какая картинка под мышью (сверху вниз): eax = номер или -1
it_pfind:
    push ebx
    push ecx
    push edx
    push esi
    mov ebx, [it_on]
.l: dec ebx
    js .no
    mov eax, ebx
    imul eax, IT_ESZ
    lea esi, [it_obj + eax]
    call it_uv
    mov edx, [g_w]
    shr edx, 1
    add edx, 6
    test eax, eax
    jns .a1
    neg eax
.a1:cmp eax, edx
    jg .l
    mov edx, [g_h]
    shr edx, 1
    add edx, 6
    test ecx, ecx
    jns .a2
    neg ecx
.a2:cmp ecx, edx
    jg .l
    mov eax, ebx
    jmp .e
.no:mov eax, -1
.e: pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Мышь над углом выделенной картинки? eax = 1 да
it_corner:
    push ecx
    push edx
    push esi
    mov eax, [it_sel]
    cmp eax, 0
    jl .no
    cmp eax, [it_on]
    jae .no
    imul eax, IT_ESZ
    lea esi, [it_obj + eax]
    call it_uv
    mov [it_cu], eax
    mov [it_cv], ecx
    test eax, eax
    jns .a
    neg eax
.a: mov edx, [g_w]
    shr edx, 1
    add edx, 4
    sub eax, edx
    jns .b
    neg eax
.b: cmp eax, 7
    ja .no
    test ecx, ecx
    jns .c
    neg ecx
.c: mov edx, [g_h]
    shr edx, 1
    add edx, 4
    sub ecx, edx
    jns .d
    neg ecx
.d: cmp ecx, 7
    ja .no
    mov eax, [it_cu]                    ; в какую сторону смотрит угол на экране: \ или /
    imul eax, [g_cos]
    mov ecx, [it_cv]
    imul ecx, [g_sin]
    sub eax, ecx
    sar eax, 8
    mov edx, eax
    mov eax, [it_cu]
    imul eax, [g_sin]
    mov ecx, [it_cv]
    imul ecx, [g_cos]
    add eax, ecx
    sar eax, 8
    imul eax, edx
    mov byte [it_ck], 133
    test eax, eax
    jg .k1
    mov byte [it_ck], 134
.k1:mov eax, 1
    jmp .e
.no:xor eax, eax
.e: pop esi
    pop edx
    pop ecx
    ret

; Что под мышью: 150 File, 160 Color, 161..163 выравнивание, 170..184 цвета панели, 190.. меню File, 200..208 правое меню,
; 140 полоса прокрутки, 130 картинка или серое место, 131 текст на странице, 132 пусто, 0 ничего
itge_hit:
    mov esi, [m_x]
    mov edi, [m_y]
    cmp byte [it_rm], 0
    je .nrm
    call it_rmcount
    imul eax, RMH
    mov ecx, eax
    mov eax, esi
    sub eax, [it_rmx]
    jl .nrm
    cmp eax, RMW
    jae .nrm
    mov eax, edi
    sub eax, [it_rmy]
    jl .nrm
    cmp eax, ecx
    jae .nrm
    xor edx, edx
    mov ecx, RMH
    div ecx
    add eax, 200
    ret
.nrm:
    cmp byte [it_cp], 0
    je .ncp
    cmp esi, 72
    jb .ncp
    cmp esi, 256
    jae .ncp
    cmp edi, 86
    jb .ncp
    cmp edi, 134
    jae .ncp
    mov eax, esi
    sub eax, 76
    jl .cpz
    xor edx, edx
    mov ecx, 44
    div ecx
    mov ebx, eax
    cmp ebx, 3
    ja .cpz
    mov eax, edi
    sub eax, 90
    jl .cpz
    xor edx, edx
    div ecx
    shl eax, 3
    add ebx, eax
    cmp ebx, 3
    ja .cpz
    lea eax, [ebx + 171]
    ret
.cpz:
    mov al, 132
    ret
.ncp:
    cmp byte [it_menu], 0
    je .nm
    cmp esi, 4
    jb .nm
    cmp esi, 340
    ja .nm
    mov eax, edi
    sub eax, 82
    jl .nm
    cmp eax, 36 * IT_MENUN
    jae .nm
    xor edx, edx
    mov ecx, 36
    div ecx
    add eax, 190
    ret
.nm:cmp edi, 80
    jae .body
    cmp edi, 40
    jb .z
    cmp edi, 76
    ja .z
    cmp esi, 4
    jb .z
    cmp esi, 84
    ja .z
    mov al, 150
    ret
.body:
    cmp esi, VX0
    jae .view
    cmp esi, 8
    jb .z
    cmp esi, 56
    ja .z
    cmp edi, 92
    jb .z
    cmp edi, 140
    jbe .col
    cmp byte [it_have], 0
    je .z
    cmp edi, 152
    jb .z
    cmp edi, 200
    jbe .a1
    cmp edi, 212
    jb .z
    cmp edi, 260
    jbe .a2
    cmp edi, 272
    jb .z
    cmp edi, 320
    jbe .a3
    cmp edi, 332
    jb .z
    cmp edi, 380
    jbe .a4
    cmp edi, 392
    jb .z
    cmp edi, 440
    jbe .a5
    jmp .z
.col:
    mov al, 160
    ret
.a1:mov al, 161
    ret
.a2:mov al, 162
    ret
.a3:mov al, 163
    ret
.a4:mov al, 164
    ret
.a5:mov al, 165
    ret
.view:
    cmp esi, SBX
    jb .doc
    call it_docheight
    cmp eax, VH
    jle .o
    mov al, 140
    ret
.doc:
    cmp byte [it_have], 0
    je .o
    call it_corner
    test eax, eax
    jz .nc
    mov al, [it_ck]
    ret
.nc:call it_pfind
    cmp eax, 0
    jge .pm
    call it_inpage
    jc .p
    mov al, 131
    ret
.pm:mov al, 135
    ret
.p: mov al, 130
    ret
.o: mov al, 132
    ret
.z: xor al, al
    ret

; ---------- мышь нажата (al = что под мышью) ----------
itge_press:
    pushad
    mov dl, al
    cmp byte [it_rm], 0
    je .n0
    movzx ebx, byte [it_rm]
    mov byte [it_rm], 0
    cmp dl, 200
    jb .cl
    cmp dl, 208
    ja .cl
    movzx eax, dl
    sub eax, 200
    call it_rm_do
    jmp .cl
.n0:cmp byte [it_cp], 0
    je .n1
    mov byte [it_cp], 0
    cmp dl, 171
    jb .cl
    cmp dl, 185
    ja .cl
    movzx eax, dl
    sub eax, 171
    ; The text selection was captured when the palette was opened.
    ; A mouse click in the palette must not change the range being styled.
    call it_setcolor
    jmp .cl
.n1:cmp dl, 150
    jne .n2
    xor byte [it_menu], 1
    jmp .cl
.n2:cmp byte [it_menu], 0
    je .n3
    mov byte [it_menu], 0
    cmp dl, 190
    jb .cl
    cmp dl, 190 + IT_MENUN - 1
    ja .cl
    movzx eax, dl
    sub eax, 190
    call it_fm_do
    jmp .r
.n3:cmp dl, 160
    jne .n4
    ; Freeze the current selection on opening Color. The palette is a
    ; separate mouse interaction; the document range must survive it.
    call it_lohi
    mov eax, [it_lo]
    mov [it_cp_a], eax
    mov eax, [it_hi]
    mov [it_cp_p], eax
    ; Keep the selection on screen until a colour is actually chosen.
    mov byte [it_cp], 1
    jmp .cl
.n4:cmp dl, 161
    jb .n5
    cmp dl, 163
    ja .n5
    movzx eax, dl
    sub eax, 161
    call it_align_do
    jmp .cl
.n5:cmp dl, 164
    jne .n5b
    call it_uundo
    jmp .cl
.n5b:cmp dl, 165
    jne .n5c
    call it_uredo
    jmp .cl
.n5c:cmp dl, 140
    jne .n6
    call it_sbpress
    jmp .r
.n6:cmp dl, 130
    jb .r
    cmp dl, 135
    ja .r
    call it_docpress
    jmp .r
.cl:cmp byte [d2_itge], 0               ; из меню открыли FloPaint - itge спрятан, не рисуем поверх
    je .r
    cmp byte [sv_who], 0                ; спрашивают Save changes? - окно уже нарисовано
    jne .r
    call itge_draw
.r: popad
    ret

; Нажатие на полосу прокрутки: ползунок берём там, где нажали
it_sbpress:
    call it_docheight
    cmp eax, VH
    jle .r
    mov eax, [m_y]
    sub eax, [sb_pos]
    jl .tr
    cmp eax, [sb_len]
    jge .tr
    mov [it_pgrab], eax
    jmp .go
.tr:mov eax, [sb_len]
    shr eax, 1
    mov [it_pgrab], eax
.go:mov byte [it_drag], 5
    call it_sbmove
.r: ret

; Прокрутка по положению мыши (ползунок тянут)
it_sbmove:
    pushad
    mov ecx, VH - 4
    sub ecx, [sb_len]
    jle .r
    mov eax, [m_y]
    sub eax, [it_pgrab]
    sub eax, VY0 + 2
    jns .a
    xor eax, eax
.a: cmp eax, ecx
    jle .b
    mov eax, ecx
.b: mov ebx, eax
    call it_docheight
    sub eax, VH
    imul eax, ebx
    xor edx, edx
    div ecx
    cmp eax, [it_scroll]
    je .r
    call it_setscroll
    call it_refresh
.r: popad
    ret

; Нажатие в области документа
it_docpress:
    pushad
    cmp byte [it_have], 0
    je .r
    mov byte [it_msn], 0
    call it_corner
    test eax, eax
    jz .nc
    mov eax, [it_sel]
    imul eax, IT_ESZ
    lea esi, [it_obj + eax]
    mov eax, [esi + 28]
    mov [it_rw0], eax
    mov eax, [esi + 32]
    mov [it_rh0], eax
    mov byte [it_drag], 3
    mov byte [it_cur], 3
    cmp byte [it_ck], 133
    je .r
    mov byte [it_cur], 8
    jmp .r
.nc:call it_pfind
    cmp eax, 0
    jl .tx
    mov [it_sel], eax
    mov byte [it_focus], 0
    imul eax, IT_ESZ
    lea esi, [it_obj + eax]
    mov eax, [m_x]
    mov [it_px], eax
    mov eax, [m_y]
    mov [it_py], eax
    mov eax, [esi + 4]
    mov [it_ox], eax
    mov eax, [esi + 8]
    mov [it_oy], eax
    mov eax, [esi + 12]
    mov [it_oa], eax
    call it_refresh
    mov byte [it_drag], 1
    cmp byte [it_shift], 0
    je .r
    mov byte [it_drag], 2
    jmp .r
.tx:call it_inpage
    jc .gray
    call it_texthit
    mov [it_p], eax
    cmp byte [it_shift], 0
    je .sa
    cmp byte [it_focus], 0
    jne .sb
.sa:mov [it_a], eax
.sb:mov dword [it_sel], -1
    mov byte [it_focus], 1
    mov byte [it_lastop], 0
    mov byte [it_drag], 4
    call it_attrs
    call it_refresh
    jmp .r
.gray:
    cmp dword [it_sel], 0
    jl .r
    mov dword [it_sel], -1
    call it_refresh
.r: popad
    ret

; Первое изменение при перетаскивании: запомнить для отмены
it_msnap:
    cmp byte [it_msn], 0
    jne .r
    pushad
    mov byte [it_msn], 1
    xor al, al
    call it_snapop
    popad
.r: ret

; ---------- мышь двигается с нажатой кнопкой ----------
itge_move:
    pushad
    cmp byte [it_drag], 4
    je .txt
    cmp byte [it_drag], 5
    jne .pic
    call it_sbmove
    jmp .r
.pic:
    mov eax, [it_sel]
    cmp eax, 0
    jl .z
    cmp eax, [it_on]
    jae .z
    imul eax, IT_ESZ
    lea esi, [it_obj + eax]
    cmp byte [it_drag], 3
    je .rs
    cmp byte [it_drag], 1
    jne .rot
    mov eax, [m_x]
    sub eax, [it_px]
    add eax, [it_ox]
    test eax, eax
    jge .x1
    xor eax, eax
.x1:cmp eax, PGW
    jle .x2
    mov eax, PGW
.x2:mov ecx, [m_y]
    sub ecx, [it_py]
    add ecx, [it_oy]
    cmp ecx, PGGAP
    jge .y1
    mov ecx, PGGAP
.y1:mov edx, [it_np]
    imul edx, PGH + PGGAP
    cmp ecx, edx
    jle .y2
    mov ecx, edx
.y2:call it_fitxy
    cmp eax, [esi + 4]
    jne .ch
    cmp ecx, [esi + 8]
    je .r
.ch:call it_msnap
    push eax
    push ecx
    xor eax, eax
    call it_dirty
    pop ecx
    pop eax
    mov [esi + 4], eax
    mov [esi + 8], ecx
    jmp .dd
.rot:
    mov eax, [it_py]
    sub eax, [m_y]
    cdq
    mov ecx, 6
    idiv ecx
    imul eax, 5
    add eax, [it_oa]
.n1:cmp eax, 0
    jge .n2
    add eax, 360
    jmp .n1
.n2:cmp eax, 360
    jb .n3
    sub eax, 360
    jmp .n2
.n3:cmp eax, [esi + 12]
    je .r
    call it_msnap
    push eax
    xor eax, eax
    call it_dirty
    pop eax
    mov [esi + 12], eax
    mov eax, [esi + 4]
    mov ecx, [esi + 8]
    call it_fitxy
    mov [esi + 4], eax
    mov [esi + 8], ecx
    jmp .dd
.rs:                                    ; тянем за угол: размер по расстоянию мыши от центра, пропорции сохраняются
    call it_uv
    test eax, eax
    jns .u1
    neg eax
.u1:shl eax, 1
    sub eax, 8
    cmp eax, 16
    jge .w1
    mov eax, 16
.w1:cmp eax, PGW - 8
    jle .w2
    mov eax, PGW - 8
.w2:mov ebx, eax
    imul eax, [it_rh0]
    xor edx, edx
    div dword [it_rw0]
    cmp eax, 8
    jge .h1
    mov eax, 8
    jmp .h2
.h1:cmp eax, PGH - 8
    jle .h3
    mov eax, PGH - 8
.h2:mov ebx, eax
    imul ebx, [it_rw0]
    push eax
    mov eax, ebx
    xor edx, edx
    div dword [it_rh0]
    mov ebx, eax
    pop eax
    test ebx, ebx
    jnz .h3
    inc ebx
.h3:cmp ebx, [esi + 28]
    jne .rc
    cmp eax, [esi + 32]
    je .r
.rc:push eax
    call it_msnap
    xor eax, eax
    call it_dirty
    pop eax
    mov [esi + 28], ebx
    mov [esi + 32], eax
    mov eax, [esi + 4]
    mov ecx, [esi + 8]
    call it_fitxy
    mov [esi + 4], eax
    mov [esi + 8], ecx
.dd:mov eax, 1
    call it_dirty
    call it_partial
    jmp .r
.txt:                                   ; выделение текста мышью, у края области лист прокручивается
    mov ebx, [it_scroll]
    mov eax, [m_y]
    cmp eax, VY0
    jge .t1
    mov eax, [it_scroll]
    sub eax, 24
    call it_setscroll
    jmp .t2
.t1:cmp eax, VY0 + VH
    jl .t2
    mov eax, [it_scroll]
    add eax, 24
    call it_setscroll
.t2:call it_texthit
    cmp eax, [it_p]
    jne .t3
    cmp ebx, [it_scroll]
    je .r
.t3:mov [it_p], eax
    call it_refresh
    jmp .r
.z: mov byte [it_drag], 0
.r: popad
    ret

itge_release:
    pushad
    movzx eax, byte [it_drag]
    mov byte [it_drag], 0
    test al, al
    jz .r
    cmp al, 4
    jne .n4
    call it_attrs
    jmp .r
.n4:cmp al, 5
    je .r
    cmp byte [it_msn], 0
    je .r
    call it_refresh
.r: popad
    ret

; ---------- правая кнопка: меню картинки (Copy, Delete) или текста ----------
itge_rclick:
    pushad
    call it_closeall
    cmp byte [it_have], 0
    je .d
    mov eax, [m_x]
    cmp eax, VX0
    jb .d
    cmp eax, SBX
    jae .d
    mov eax, [m_y]
    cmp eax, VY0
    jb .d
    call it_pfind
    cmp eax, 0
    jl .tx
    mov [it_sel], eax
    mov byte [it_rm], 1
    jmp .pos
.tx:call it_inpage
    jc .d
    mov eax, [it_a]
    cmp eax, [it_p]
    jne .ks
    call it_texthit
    mov [it_p], eax
    mov [it_a], eax
.ks:mov dword [it_sel], -1
    mov byte [it_focus], 1
    mov byte [it_rm], 2
.pos:
    call it_rmcount
    imul eax, RMH
    mov ebx, 596
    sub ebx, eax
    mov ecx, [m_x]
    cmp ecx, 800 - RMW - 6
    jbe .x
    mov ecx, 800 - RMW - 6
.x: mov [it_rmx], ecx
    mov ecx, [m_y]
    cmp ecx, ebx
    jbe .y
    mov ecx, ebx
.y: mov [it_rmy], ecx
.d: call itge_draw
    popad
    ret

; Пункт правого меню: eax = номер, ebx = 1 у картинки (Copy, Delete), 2 у текста
it_rm_do:
    pushad
    cmp ebx, 1
    jne .t
    test eax, eax
    jnz .pd
    call it_copy
    jmp .r
.pd:cmp eax, 1
    ja .ep
    call it_delpic
    jmp .r
.ep:call it_editpic
    jmp .r
.t: cmp eax, 2
    ja .t2
    mov edx, 1
    test eax, eax
    jz .ff
    mov edx, 4
    cmp eax, 1
    je .ff
    mov edx, 2
.ff:call it_fmtflag
    jmp .r
.t2:cmp eax, 4
    ja .t3
    mov edx, 1
    cmp eax, 3
    je .fs
    mov edx, -1
.fs:call it_fmtsize
    jmp .r
.t3:sub eax, 5
    jnz .c1
    call it_cut
    jmp .r
.c1:cmp eax, 1
    jne .c2
    call it_copy
    jmp .r
.c2:cmp eax, 2
    jne .c3
    call it_paste_any
    jmp .r
.c3:call it_deltext
.r: popad
    ret


; Выбранную картинку открыть в FloPaint. Если там есть несохранённый рисунок, сначала спросим Save changes?
it_editpic:
    pushad
    mov eax, [it_sel]
    cmp eax, 0
    jl .r
    cmp eax, [it_on]
    jae .r
    imul eax, IT_ESZ
    mov ebx, [it_obj + eax + 16]
    mov ecx, [it_obj + eax + 20]
    mov edx, [it_obj + eax + 24]
    mov [it_ep_w], ebx
    mov [it_ep_h], ecx
    mov [it_ep_pl], edx
    cmp byte [pa_dirty], 0
    je .go
    mov al, 3
    call sv_ask
    jmp .r
.go:call it_ep_go
.r: popad
    ret

; Картинку из документа положить на холст FloPaint и открыть его
it_ep_go:
    pushad
    mov eax, [it_ep_pl]
    shl eax, 16
    lea esi, [IT_PIC + eax]
    mov edi, 0x200000
    mov ecx, [it_ep_w]
    imul ecx, [it_ep_h]
    cld
    rep movsb
    mov ebx, [it_ep_w]
    mov ecx, [it_ep_h]
    mov edx, [it_ep_pl]
    call paint_open_link
    popad
    ret

; ---------- отмена ----------
; Запомнить состояние документа (кроме точек картинок) в кольце IT_UND
it_snap:
    pushad
    mov byte [it_mod], 1
    mov dword [it_re], 0
    cld
    mov eax, [it_uh]
    shl eax, 16
    lea edi, [IT_UND + eax]
    mov eax, [it_n]
    stosd
    mov eax, [it_p]
    stosd
    mov eax, [it_on]
    stosd
    xor eax, eax
    stosd
    mov esi, it_obj
    mov ecx, IT_OMAX * IT_ESZ / 4
    rep movsd
    mov esi, IT_TXT
    mov ecx, [it_n]
    rep movsd
    mov eax, [it_uh]
    inc eax
    cmp eax, IT_UNDN
    jb .a
    xor eax, eax
.a: mov [it_uh], eax
    cmp dword [it_us], IT_UNDN
    jae .r
    inc dword [it_us]
.r: popad
    ret

; al = вид правки: 0 - всегда запоминать, иначе подряд идущие правки одного вида (набор, стирание) запоминаются один раз
it_snapop:
    test al, al
    jz .do
    cmp al, [it_lastop]
    je .r
.do:mov [it_lastop], al
    call it_snap
.r: ret

; Отмена от пользователя: снимок и документ меняются местами, чтобы можно было вернуть (Ctrl+Y)
it_uundo:
    pushad
    cmp dword [it_us], 0
    je .r
    dec dword [it_us]
    inc dword [it_re]
    mov eax, [it_uh]
    test eax, eax
    jnz .a
    mov eax, IT_UNDN
.a: dec eax
    mov [it_uh], eax
    call it_uswap
.r: popad
    ret

; Вернуть отменённое
it_uredo:
    pushad
    cmp dword [it_re], 0
    je .r
    dec dword [it_re]
    inc dword [it_us]
    mov eax, [it_uh]
    push eax
    inc eax
    cmp eax, IT_UNDN
    jb .a
    xor eax, eax
.a: mov [it_uh], eax
    pop eax
    call it_uswap
.r: popad
    ret

; Поменять документ и снимок номер eax
it_uswap:
    pushad
    mov ebp, eax
    mov edi, IT_UTMP
    cld
    mov eax, [it_n]
    stosd
    mov eax, [it_p]
    stosd
    mov eax, [it_on]
    stosd
    xor eax, eax
    stosd
    mov esi, it_obj
    mov ecx, IT_OMAX * IT_ESZ / 4
    rep movsd
    mov esi, IT_TXT
    mov ecx, [it_n]
    rep movsd
    mov eax, ebp
    shl eax, 16
    lea esi, [IT_UND + eax]
    lodsd
    mov [it_n], eax
    lodsd
    mov [it_p], eax
    mov [it_a], eax
    lodsd
    mov [it_on], eax
    lodsd
    mov edi, it_obj
    mov ecx, IT_OMAX * IT_ESZ / 4
    rep movsd
    mov edi, IT_TXT
    mov ecx, [it_n]
    rep movsd
    mov dword [it_sel], -1
    mov byte [it_lastop], 0
    mov eax, ebp
    shl eax, 16
    lea edi, [IT_UND + eax]
    mov esi, IT_UTMP
    mov ecx, [esi]
    add ecx, 4 + IT_OMAX * IT_ESZ / 4
    rep movsd
    call it_layout
    call it_attrs
    popad
    ret

it_undo:
    pushad
    cmp dword [it_us], 0
    je .r
    dec dword [it_us]
    mov eax, [it_uh]
    test eax, eax
    jnz .a
    mov eax, IT_UNDN
.a: dec eax
    mov [it_uh], eax
    shl eax, 16
    lea esi, [IT_UND + eax]
    cld
    lodsd
    mov [it_n], eax
    lodsd
    mov [it_p], eax
    mov [it_a], eax
    lodsd
    mov [it_on], eax
    lodsd
    mov edi, it_obj
    mov ecx, IT_OMAX * IT_ESZ / 4
    rep movsd
    mov edi, IT_TXT
    mov ecx, [it_n]
    rep movsd
    mov dword [it_sel], -1
    mov byte [it_lastop], 0
    call it_layout
    call it_attrs
.r: popad
    ret

; ---------- правка текста ----------
; Убрать клетки eax..ebx-1 (последний перевод строки остаётся). Курсор в eax
it_delrange:
    pushad
    mov ecx, [it_n]
    dec ecx
    cmp ebx, ecx
    jbe .a
    mov ebx, ecx
.a: cmp eax, ebx
    jae .s
    mov edx, [it_n]
    sub edx, ebx
    lea edi, [IT_TXT + eax * 4]
    lea esi, [IT_TXT + ebx * 4]
    mov ecx, edx
    cld
    rep movsd
    sub ebx, eax
    sub [it_n], ebx
.s: mov [it_p], eax
    mov [it_a], eax
    popad
    ret

; Вставить ecx клеток из esi в место курсора. CF = не влезло (всё вернулось как было)
it_insblk:
    pushad
    mov ebx, ecx
    mov eax, [it_n]
    add eax, ebx
    cmp eax, IT_TMAX
    ja .fail
    mov edx, [it_n]
    sub edx, [it_p]
    mov edi, [it_n]
    add edi, ebx
    dec edi
    shl edi, 2
    add edi, IT_TXT
    push esi
    mov esi, [it_n]
    dec esi
    shl esi, 2
    add esi, IT_TXT
    mov ecx, edx
    std
    rep movsd
    cld
    pop esi
    mov edi, [it_p]
    shl edi, 2
    add edi, IT_TXT
    mov ecx, ebx
    rep movsd
    add [it_n], ebx
    add [it_p], ebx
    mov eax, [it_p]
    mov [it_a], eax
    call it_layout
    cmp dword [it_ovf], 0
    je .ok
    mov ecx, [it_p]
    mov eax, ecx
    sub eax, ebx
    mov ebx, ecx
    call it_delrange
    call it_layout
.fail:
    popad
    stc
    ret
.ok:popad
    clc
    ret

; Вставить знак al в место курсора с текущими признаками. CF = не влезло
it_insc:
    pushad
    mov [it_tmpc], al
    mov dl, [it_fl]
    and dl, 7
    cmp al, 10
    jne .nf
    call it_curalign
    shl eax, 3
    or dl, al
.nf:mov [it_tmpc + 1], dl
    mov al, [it_col]
    mov [it_tmpc + 2], al
    mov al, [it_sz]
    mov [it_tmpc + 3], al
    mov esi, it_tmpc
    mov ecx, 1
    call it_insblk
    popad
    ret

; Жирный (1), подчёркнутый (2), курсив (4): маска в dl. Без выделения - для следующих знаков
it_fmtflag:
    pushad
    call it_lohi
    mov ecx, [it_lo]
    cmp ecx, [it_hi]
    jne .rng
    xor [it_fl], dl
    jmp .r
.rng:
    mov esi, 1
.ch:cmp ecx, [it_hi]
    jae .cd
    test byte [IT_TXT + ecx * 4 + 1], dl
    jnz .nx
    xor esi, esi
    jmp .cd
.nx:inc ecx
    jmp .ch
.cd:xor eax, eax
    call it_snapop
    mov bl, dl
    not bl
    mov ecx, [it_lo]
.ap:cmp ecx, [it_hi]
    jae .r
    test esi, esi
    jz .st
    and [IT_TXT + ecx * 4 + 1], bl
    jmp .n2
.st:or [IT_TXT + ecx * 4 + 1], dl
.n2:inc ecx
    jmp .ap
.r: popad
    ret

; Размер: edx = +1 или -1. Без выделения - для следующих знаков
it_fmtsize:
    pushad
    call it_lohi
    mov ecx, [it_lo]
    cmp ecx, [it_hi]
    jne .rng
    movzx eax, byte [it_sz]
    add eax, edx
    cmp eax, 1
    jl .r
    cmp eax, 3
    jg .r
    mov [it_sz], al
    jmp .r
.rng:
    xor eax, eax
    call it_snapop
.l: cmp ecx, [it_hi]
    jae .d
    movzx eax, byte [IT_TXT + ecx * 4 + 3]
    add eax, edx
    cmp eax, 1
    jge .a
    mov eax, 1
.a: cmp eax, 3
    jle .b
    mov eax, 3
.b: mov [IT_TXT + ecx * 4 + 3], al
    inc ecx
    jmp .l
.d: call it_layout
    cmp dword [it_ovf], 0
    je .r
    call it_undo
.r: popad
    ret

; Palette command: eax = colour index 0..3.
; Text character layout: [glyph, flags, VGA colour, size].
; This is document formatting, NOT selection highlight formatting.
; The range [it_cp_a,it_cp_p) was captured on opening Color.
; Never call it_attrs here: that routine would overwrite it_col with
; the colour of the character BEFORE the caret.
it_setcolor:
    pushad
    cmp eax, 3
    ja .return
    movzx ebx, byte [it_swc + eax]    ; palette index -> stored VGA colour
    mov [it_color_req], bl

    ; Validate the saved selection rather than relying on a possibly moved
    ; cursor or transient mouse drag state.
    mov esi, [it_cp_a]
    mov edi, [it_cp_p]
    cmp esi, edi
    jbe .ordered
    xchg esi, edi
.ordered:
    mov ecx, [it_n]
    cmp esi, ecx
    jbe .lower_ok
    mov esi, ecx
.lower_ok:
    cmp edi, ecx
    jbe .upper_ok
    mov edi, ecx
.upper_ok:
    cmp esi, edi
    jae .next_input_only

    ; Snapshot the original document before modifying its colour bytes.
    ; Save the range and requested colour in persistent variables, since
    ; other routines may use registers and the current selection.
    mov [it_color_lo], esi
    mov [it_color_hi], edi
    xor eax, eax
    call it_snapop
    mov esi, [it_color_lo]
    mov edi, [it_color_hi]
    movzx ebx, byte [it_color_req]

    ; Write one byte per character. Do not modify text, flags or font size.
    ; Compute the byte address with LEA to avoid aliasing the glyph offset.
.paint:
    cmp esi, edi
    jae .finished
    lea edx, [IT_TXT + esi*4 + 2]
    mov [edx], bl
    inc esi
    jmp .paint
.finished:
    mov [it_col], bl
    mov [it_p], edi
    mov [it_a], edi                  ; remove highlight to reveal real colour
    mov byte [it_focus], 1
    mov byte [it_shv], 0
    ; Verify that the final written colour byte agrees with the request.
    ; Exposed in it_color_ok for debugging without changing other modules.
    lea edx, [IT_TXT + edi*4 - 2]
    mov al, [edx]
    cmp al, bl
    sete al
    mov [it_color_ok], al
    jmp .return
.next_input_only:
    mov [it_col], bl                ; no selection: colour for future typing
    mov byte [it_color_ok], 0
.return:
    popad
    ret

; Выравнивание абзацев выделения: eax = 0 слева, 1 по центру, 2 справа
it_align_do:
    pushad
    mov [it_tmp], eax
    xor eax, eax
    call it_snapop
    call it_lohi
    mov esi, [it_lo]
    mov edi, [it_hi]
    cmp edi, esi
    jbe .e1
    dec edi
.e1:mov ecx, esi
.f: cmp byte [IT_TXT + ecx * 4], 10
    je .g
    inc ecx
    cmp ecx, [it_n]
    jb .f
    jmp .d
.g: mov al, [IT_TXT + ecx * 4 + 1]
    and al, 0xE7
    mov edx, [it_tmp]
    shl edx, 3
    or al, dl
    mov [IT_TXT + ecx * 4 + 1], al
    cmp ecx, edi
    jae .d
    lea esi, [ecx + 1]
    jmp .e1
.d: call it_layout
    popad
    ret

; ---------- картинки ----------
; Какое место картинок свободно: eax = номер или -1
it_freeslot:
    push ecx
    push edx
    push esi
    xor ecx, ecx
.s: cmp ecx, IT_PICN
    jae .no
    xor edx, edx
    mov esi, it_obj
.o: cmp edx, [it_on]
    jae .free
    cmp [esi + 24], ecx
    je .used
    add esi, IT_ESZ
    inc edx
    jmp .o
.used:
    inc ecx
    jmp .s
.free:
    mov eax, ecx
    jmp .e
.no:mov eax, -1
.e: pop esi
    pop edx
    pop ecx
    ret

; Поставить картинку edi посередине видимой части листа
it_place:
    mov eax, PGW / 2
    mov ecx, [it_on]
    imul ecx, 14
    add eax, ecx
    cmp eax, PGW
    jbe .a
    mov eax, PGW / 2
.a: mov [edi + 4], eax
    mov eax, [it_scroll]
    add eax, VH / 2
    mov ecx, [edi + 32]
    shr ecx, 1
    add ecx, PGGAP
    cmp eax, ecx
    jge .b
    mov eax, ecx
.b: mov edx, [it_np]
    imul edx, PGH + PGGAP
    cmp eax, edx
    jle .c
    mov eax, edx
.c: mov [edi + 8], eax
    ret

; Убрать выделенную картинку
it_delpic:
    pushad
    mov eax, [it_sel]
    cmp eax, 0
    jl .r
    cmp eax, [it_on]
    jae .r
    xor eax, eax
    call it_snapop
    mov eax, [it_sel]
    mov edx, [it_on]
    dec edx
    sub edx, eax
    imul eax, IT_ESZ
    lea edi, [it_obj + eax]
    lea esi, [edi + IT_ESZ]
    imul ecx, edx, IT_ESZ / 4
    cld
    rep movsd
    dec dword [it_on]
    mov dword [it_sel], -1
.r: popad
    ret

; ---------- буфер обмена ----------
it_copy:
    pushad
    cld
    mov eax, [it_sel]
    cmp eax, 0
    jl .tx
    cmp eax, [it_on]
    jae .r
    imul eax, IT_ESZ
    lea esi, [it_obj + eax]
    push esi
    mov edi, it_cbobj
    mov ecx, IT_ESZ / 4
    rep movsd
    pop esi
    mov ecx, [esi + 16]
    imul ecx, [esi + 20]
    mov eax, [esi + 24]
    shl eax, 16
    lea esi, [IT_PIC + eax]
    mov edi, IT_CBPIC
    rep movsb
    mov byte [it_cbk], 2
    mov dword [clip_len], 0             ; image is not plain text
    mov byte [fclip_ok], 0
    jmp .r
.tx:call it_lohi
    mov ecx, [it_hi]
    sub ecx, [it_lo]
    jbe .r
    mov [it_cbn], ecx
    ; Shared plain-text clipboard: byte 0 of each 4-byte FloItge cell.
    ; Keep the old rich local copy for pasting formats inside FloItge.
    mov [clip_len], ecx
    mov esi, [it_lo]
    lea esi, [IT_TXT + esi * 4]
    mov edi, clip_buf
    push ecx
.shared:
    mov al, [esi]
    mov [edi], al
    add esi, 4
    inc edi
    dec ecx
    jnz .shared
    pop ecx
    mov esi, [it_lo]
    shl esi, 2
    add esi, IT_TXT
    mov edi, IT_CBTXT
    rep movsd
    mov byte [it_cbk], 1
    mov byte [fclip_ok], 0
.r: popad
    ret

; Убрать выделенное (текст или картинку)
it_deltext:
    pushad
    cmp dword [it_sel], 0
    jge .pic
    call it_lohi
    mov eax, [it_lo]
    cmp eax, [it_hi]
    je .r
    xor eax, eax
    call it_snapop
    mov eax, [it_lo]
    mov ebx, [it_hi]
    call it_delrange
    call it_layout
    jmp .r
.pic:
    call it_delpic
.r: popad
    ret

it_cut:
    call it_copy
    jmp it_deltext

; Вставить: файл .pcf из FloFile или то, что скопировали здесь
it_paste_any:
    cmp byte [fclip_ok], 1
    je it_paste_pcf
    ; Global text takes precedence, including text copied from FloText/FloTerm.
    cmp dword [clip_len], 0
    jne it_paste_shared
    cmp byte [it_cbk], 2
    je it_paste_pic
    ret

; Convert the global byte clipboard to FloItge 4-byte text cells.
; FloItge's rich text clipboard is kept separately for image support.
it_paste_shared:
    pushad
    mov ecx, [clip_len]
    cmp ecx, IT_TMAX - 1
    jbe .lenok
    mov ecx, IT_TMAX - 1
.lenok:
    mov esi, clip_buf
    mov edi, IT_CBTXT
    xor ebx, ebx
.loop:
    test ecx, ecx
    jz .ready
    lodsb
    dec ecx
    cmp al, 13                          ; normalise CRLF to one newline
    je .loop
    test al, al                         ; skip embedded NUL
    jz .loop
    mov byte [edi], al
    mov byte [edi + 1], 0               ; plain text, no bold/italic
    mov dl, [it_col]
    mov [edi + 2], dl
    mov dl, [it_sz]
    mov [edi + 3], dl
    add edi, 4
    inc ebx
    jmp .loop
.ready:
    test ebx, ebx
    jz .done
    mov [it_cbn], ebx
    call it_paste_txt
.done:
    popad
    ret

it_paste_txt:
    pushad
    xor eax, eax
    call it_snapop
    mov dword [it_sel], -1
    mov byte [it_focus], 1
    call it_lohi
    mov eax, [it_lo]
    cmp eax, [it_hi]
    je .n
    mov ebx, [it_hi]
    call it_delrange
.n: mov esi, IT_CBTXT
    mov ecx, [it_cbn]
    call it_insblk
    jnc .r
    call it_undo
.r: popad
    ret

it_paste_pic:
    pushad
    cmp dword [it_on], IT_OMAX
    jae .r
    call it_freeslot
    cmp eax, 0
    jl .r
    mov [it_slot], eax
    mov edi, eax
    shl edi, 16
    add edi, IT_PIC
    mov ecx, [it_cbobj + 16]
    imul ecx, [it_cbobj + 20]
    mov esi, IT_CBPIC
    cld
    rep movsb
    xor eax, eax
    call it_snapop
    mov eax, [it_on]
    imul eax, IT_ESZ
    lea edi, [it_obj + eax]
    mov esi, it_cbobj
    mov ecx, IT_ESZ / 4
    rep movsd
    mov eax, [it_on]
    imul eax, IT_ESZ
    lea edi, [it_obj + eax]
    mov eax, [it_slot]
    mov [edi + 24], eax
    call it_place
    mov eax, [it_on]
    mov [it_sel], eax
    inc dword [it_on]
    mov byte [it_focus], 0
.r: popad
    ret


; ---------- клавиши ----------
; Коды: 0x90 вверх, 0x91 вниз, 0x93 влево, 0x94 вправо, 0x95 Home, 0x96 End, 0x97 Delete, 0x98 PgUp, 0x99 PgDn.
; Ctrl: A=1 B=2 C=3 I=9 S=0x13 U=0x15 V=0x16 X=0x18 Z=0x1A
itge_key:
    pushad
    movzx edx, al
    mov al, [it_menu]
    or al, [it_cp]
    or al, [it_rm]
    jz .nm
    cmp dl, 27
    jne .r
    call it_closeall
    call itge_draw
    jmp .r
.nm:mov eax, 0                         ; Ctrl+O
    cmp dl, 0x0F
    je .fm
    mov eax, 1                          ; Ctrl+N
    cmp dl, 0x0E
    je .fm
    mov eax, 3                          ; Ctrl+T
    cmp dl, 0x14
    je .fm
    mov eax, 5                          ; Ctrl+E
    cmp dl, 5
    jne .nfm
.fm:call it_fm_do
    jmp .r
.nfm:
    cmp byte [it_have], 0
    je .r
    cmp dl, 0x13
    jne .k0
    call it_save
    jmp .r
.k0:cmp dl, 0x1A
    jne .k0y
    call it_uundo
    jmp .upd
.k0y:cmp dl, 0x19                       ; Ctrl+Y
    jne .k1
    call it_uredo
    jmp .upd
.k1:cmp dl, 3
    jne .k2
    call it_copy
    jmp .r
.k2:cmp dl, 0x18
    jne .k3
    call it_cut
    jmp .upd
.k3:cmp dl, 0x16
    jne .k4
    call it_paste_any
    jmp .upd
.k4:cmp dl, 1
    jne .k5
    mov dword [it_sel], -1
    mov byte [it_focus], 1
    mov dword [it_a], 0
    mov eax, [it_n]
    dec eax
    mov [it_p], eax
    jmp .upd
.k5:cmp dl, 2
    jne .k6
    mov edx, 1
    call it_fmtflag
    jmp .upd
.k6:cmp dl, 9
    jne .k7
    mov edx, 4
    call it_fmtflag
    jmp .upd
.k7:cmp dl, 0x15
    jne .k8
    mov edx, 2
    call it_fmtflag
    jmp .upd
.k8:cmp dword [it_sel], 0                ; выделена картинка
    jl .tx
    cmp dl, 27
    jne .p1
    mov dword [it_sel], -1
    jmp .upd
.p1:cmp dl, 8
    je .pd
    cmp dl, 0x97
    jne .r
.pd:call it_delpic
    jmp .upd
.tx:cmp byte [it_focus], 0
    je .r
    cmp dl, 0x90
    jb .ed
    cmp dl, 0x99
    ja .r
    cmp dl, 0x92
    je .r
    cmp dl, 0x97
    je .del
    jmp .mv
.ed:cmp dl, 8
    jne .e1
    mov al, 2
    call it_snapop
    call it_lohi
    mov eax, [it_lo]
    mov ebx, [it_hi]
    cmp eax, ebx
    jne .dr
    test eax, eax
    jz .upd
    dec eax
    jmp .dr
.e1:cmp dl, 13
    jne .e2
    xor al, al
    call it_snapop
    call it_lohi
    mov eax, [it_lo]
    cmp eax, [it_hi]
    je .e1a
    mov ebx, [it_hi]
    call it_delrange
.e1a:
    mov al, 10
    call it_insc
    jmp .upd
.e2:cmp dl, 32
    jb .r
    CHKHI dl, .r
    mov al, 1
    call it_snapop
    call it_lohi
    mov eax, [it_lo]
    cmp eax, [it_hi]
    je .e2a
    mov ebx, [it_hi]
    call it_delrange
.e2a:
    mov al, dl
    call it_insc
    jmp .upd
.del:
    mov al, 2
    call it_snapop
    call it_lohi
    mov eax, [it_lo]
    mov ebx, [it_hi]
    cmp eax, ebx
    jne .dr
    mov ecx, [it_n]
    dec ecx
    cmp eax, ecx
    jae .upd
    mov ebx, eax
    inc ebx
.dr:call it_delrange                    ; eax..ebx
    call it_layout
    jmp .upd
.mv:call it_lohi                        ; движение курсора
    cmp dl, 0x93
    jne .m1
    cmp byte [it_shift], 0
    jne .ml
    mov eax, [it_lo]
    cmp eax, [it_hi]
    jne .set
.ml:mov eax, [it_p]
    test eax, eax
    jz .set
    dec eax
    jmp .set
.m1:cmp dl, 0x94
    jne .m2
    cmp byte [it_shift], 0
    jne .mr
    mov eax, [it_lo]
    cmp eax, [it_hi]
    je .mr
    mov eax, [it_hi]
    jmp .set
.mr:mov eax, [it_p]
    inc eax
    mov ecx, [it_n]
    dec ecx
    cmp eax, ecx
    jbe .set
    mov eax, ecx
    jmp .set
.m2:cmp dl, 0x90
    je .up
    cmp dl, 0x91
    je .dn
    cmp dl, 0x95
    je .hm
    cmp dl, 0x96
    je .en
    mov eax, [it_scroll]                ; PgUp, PgDn - только листаем
    cmp dl, 0x98
    jne .pdn
    sub eax, VH - 40
    jmp .pg
.pdn:
    add eax, VH - 40
.pg:call it_setscroll
    call it_refresh
    jmp .r
.up:mov eax, [it_p]
    call it_lineof
    mov ebx, eax
    test eax, eax
    jnz .u1
    xor eax, eax
    jmp .set
.u1:mov esi, ebx
    mov eax, [it_p]
    call it_xof
    mov edx, eax
    dec ebx
    mov eax, ebx
    call it_charat
    jmp .set
.dn:mov eax, [it_p]
    call it_lineof
    mov ebx, eax
    inc ebx
    cmp ebx, [it_nl]
    jb .d1
    mov eax, [it_n]
    dec eax
    jmp .set
.d1:mov esi, eax
    mov eax, [it_p]
    call it_xof
    mov edx, eax
    mov eax, ebx
    call it_charat
    jmp .set
.hm:mov eax, [it_p]
    call it_lineof
    shl eax, 4
    mov eax, [IT_LN + eax]
    jmp .set
.en:mov eax, [it_p]
    call it_lineof
    shl eax, 4
    mov eax, [IT_LN + eax + 4]
    dec eax
.set:
    cmp byte [it_shift], 0
    jne .s1
    mov [it_a], eax
.s1:mov [it_p], eax
    mov byte [it_lastop], 0
    call it_attrs
.upd:
    call it_showcaret
    call it_refresh
.r: popad
    ret

; ---------- меню File ----------
; eax: 0 Open, 1 New, 2 Save, 3 Save to, 4 Export, 5 Print (пока не работает), 6 Exit
it_fm_do:
    pushad
    cmp eax, 0
    jne .n1
    mov al, 2
    call dlg_open_i
    jmp .r
.n1:cmp eax, 1
    jne .n2
    call it_new
    mov byte [it_nm], 0
    mov byte [it_dsk], 0xFF
    mov dword [it_on], 0
    mov dword [it_us], 0
    mov dword [it_re], 0
    mov dword [it_uh], 0
    jmp .dr
.n2:cmp eax, 2
    jne .n3
    cmp byte [it_have], 0
    je .dr
    call it_save
    jmp .r
.n3:cmp eax, 3
    jne .n4
    cmp byte [it_have], 0
    je .dr
    mov al, 1
    call dlg_open_i
    jmp .r
.n4:cmp eax, 5
    jne .dr
    call itge_exit
    jmp .r
.dr:call itge_draw
.r: popad
    ret

; Сохранить: в тот же файл, а если файла ещё нет - спросить, куда
it_save:
    pushad
    cmp byte [it_have], 0
    je .r
    cmp byte [it_dsk], 0xFF
    jne .have
    mov al, 1
    call dlg_open_i
    jmp .r
.have:
    call wait_start
    call itge_pack
    mov al, [it_dsk]
    call fs_setdisk
    jc .out
    mov al, [it_par]
    mov [fs_par], al
    mov esi, it_nm
    call file_write
    mov byte [fs_par], 0
    mov byte [it_mod], 0
.out:
    call wait_end
    call redraw
.r: popad
    ret

; Убрать пустые места в списке картинок (type = 0)
it_packobj:
    pushad
    mov esi, it_obj
    mov edi, it_obj
    xor ebx, ebx
    xor edx, edx
.l: cmp edx, IT_OMAX
    jae .z
    cmp dword [esi], 0
    je .s
    cmp esi, edi
    je .k
    push esi
    push edi
    mov ecx, IT_ESZ / 4
    cld
    rep movsd
    pop edi
    pop esi
.k: add edi, IT_ESZ
    inc ebx
.s: add esi, IT_ESZ
    inc edx
    jmp .l
.z: mov [it_on], ebx
    mov ecx, IT_OMAX
    sub ecx, ebx
    imul ecx, IT_ESZ / 4
    xor eax, eax
    cld
    rep stosd
    popad
    ret

; ---------- файлы ----------
; Документ -> DATA_BUF, ecx = размер. "SGA2", число клеток, число картинок, 32 байта заголовка, 16 записей картинок, клетки, точки картинок по 2 в байте
itge_pack:
    pushad
    cld
    mov edi, DATA_BUF
    mov dword [edi], 0x32414753
    mov eax, [it_n]
    mov [edi + 4], eax
    mov eax, [it_on]
    mov [edi + 8], eax
    xor eax, eax
    mov [edi + 12], eax
    mov [edi + 16], eax
    mov [edi + 20], eax
    mov [edi + 24], eax
    mov [edi + 28], eax
    add edi, 32
    mov esi, it_obj
    mov ecx, IT_OMAX * IT_ESZ / 4
    rep movsd
    mov esi, IT_TXT
    mov ecx, [it_n]
    rep movsd
    xor ebx, ebx
.o: cmp ebx, [it_on]
    jae .done
    mov eax, ebx
    imul eax, IT_ESZ
    lea edx, [it_obj + eax]
    mov ecx, [edx + 16]
    imul ecx, [edx + 20]
    mov esi, [edx + 24]
    shl esi, 16
    add esi, IT_PIC
.p: cmp ecx, 2
    jb .odd
    mov al, [esi]
    shl al, 4
    or al, [esi + 1]
    stosb
    add esi, 2
    sub ecx, 2
    jmp .p
.odd:
    test ecx, ecx
    jz .nx
    mov al, [esi]
    shl al, 4
    stosb
.nx:inc ebx
    jmp .o
.done:
    sub edi, DATA_BUF
    mov [it_psz], edi
    popad
    mov ecx, [it_psz]
    ret

; Открыть файл .sga: esi - имя, al - диск
itge_open_named:
    pushad
    call strlen
    cmp ecx, 5
    jb .sga
    mov ebx, [esi + ecx - 4]
    or ebx, 0x20202020
    cmp ebx, 0x6663702E                 ; .pcf и .txt вставляются в документ
    je .ins
    cmp ebx, 0x7478742E
    jne .sga
.ins:
    popad
    jmp itge_insert_file
.sga:
    call wait_start
    mov [on_disk], al
    mov bl, [fs_par]
    mov [it_tp], bl
    mov edi, fn_buf
.c: lodsb
    stosb
    test al, al
    jnz .c
    mov al, [on_disk]
    call fs_setdisk
    jc .out
    mov esi, fn_buf
    call file_read
    jc .out
    mov [it_fsz], eax
    cmp eax, 32 + IT_OMAX * IT_ESZ + 4
    jb .out
    cmp dword [DATA_BUF], 0x32414753
    jne .out
    mov ecx, [DATA_BUF + 4]
    cmp ecx, 1
    jb .out
    cmp ecx, IT_TMAX
    ja .out
    mov edx, [DATA_BUF + 8]
    cmp edx, IT_OMAX
    ja .out
    mov eax, ecx
    shl eax, 2
    add eax, 32 + IT_OMAX * IT_ESZ
    cmp eax, [it_fsz]
    ja .out
    mov [it_n], ecx
    mov [it_on], edx
    mov esi, DATA_BUF + 32
    mov edi, it_obj
    push ecx
    mov ecx, IT_OMAX * IT_ESZ / 4
    cld
    rep movsd
    pop ecx
    mov edi, IT_TXT
    rep movsd                            ; esi стоит после клеток: дальше точки картинок
    mov [it_ptr], esi
    mov ecx, [it_n]                      ; клетки: размер 1..3, цвет 0..15, последний знак - перевод строки
    mov edi, IT_TXT
.sn:cmp byte [edi + 3], 1
    jb .s1
    cmp byte [edi + 3], 3
    jbe .s2
.s1:mov byte [edi + 3], 1
.s2:cmp byte [edi + 2], 15
    jbe .s3
    mov byte [edi + 2], 0
.s3:add edi, 4
    dec ecx
    jnz .sn
    mov eax, [it_n]
    mov byte [IT_TXT + eax * 4 - 4], 10
    mov esi, [it_ptr]
    xor ebx, ebx
    xor ebp, ebp                         ; следующее место для картинки
.po:cmp ebx, [it_on]
    jae .pd
    mov eax, ebx
    imul eax, IT_ESZ
    lea edx, [it_obj + eax]
    cmp dword [edx], 2
    jne .bad
    cmp ebp, IT_PICN
    jae .bad
    mov ecx, [edx + 16]
    cmp ecx, 1
    jb .bad
    cmp ecx, 256
    ja .bad
    mov eax, [edx + 20]
    cmp eax, 1
    jb .bad
    cmp eax, 256
    ja .bad
    imul ecx, eax                        ; точек
    lea eax, [ecx + 1]
    shr eax, 1
    mov edi, esi
    sub edi, DATA_BUF
    add edi, eax
    cmp edi, [it_fsz]
    ja .bad
    cmp dword [edx + 28], 8
    jb .dwb
    cmp dword [edx + 28], 2000
    jbe .dwa
.dwb:mov eax, [edx + 16]
    mov [edx + 28], eax
.dwa:cmp dword [edx + 32], 8
    jb .dhb
    cmp dword [edx + 32], 2000
    jbe .dha
.dhb:mov eax, [edx + 20]
    mov [edx + 32], eax
.dha:cmp dword [edx + 12], 360
    jb .ang
    mov dword [edx + 12], 0
.ang:mov [edx + 24], ebp
    mov edi, ebp
    shl edi, 16
    add edi, IT_PIC
    inc ebp
.pu:test ecx, ecx
    jz .pn
    lodsb
    mov ah, al
    shr al, 4
    stosb
    dec ecx
    jz .pn
    mov al, ah
    and al, 15
    stosb
    dec ecx
    jmp .pu
.bad:
    mov dword [edx], 0                   ; картинка не поместилась или файл обрезан
.pn:inc ebx
    jmp .po
.pd:call it_packobj
    mov dword [it_sel], -1
    mov dword [it_p], 0
    mov dword [it_a], 0
    mov dword [it_us], 0
    mov dword [it_re], 0
    mov dword [it_uh], 0
    mov byte [it_have], 1
    mov byte [it_mod], 0
    mov byte [it_focus], 0
    mov byte [it_lastop], 0
    mov byte [it_fl], 0
    mov byte [it_col], 0
    mov byte [it_sz], 1
    call it_layout
    cmp dword [it_ovf], 0
    je .ok
    call it_new                          ; файл повреждён: пустой лист
    mov dword [it_on], 0
    jmp .out
.ok:xor eax, eax
    call it_setscroll
    mov esi, fn_buf
    mov edi, it_nm
.n: lodsb
    stosb
    test al, al
    jnz .n
    mov al, [on_disk]
    mov [it_dsk], al
    mov bl, [it_tp]
    mov [it_par], bl
.out:
    call wait_end
    call redraw
    popad
    ret

; Вставить картинку .pcf, скопированную в FloFile (Copy или Ctrl+C)
it_paste_pcf:
    pushad
    cmp byte [fclip_ok], 1
    jne .r
    mov esi, fclip_nm
    call strlen
    cmp ecx, 5
    jb .r
    cmp dword [fclip_nm + ecx - 4], 0x6663702E   ; ".pcf"
    jne .r
    cmp dword [it_on], IT_OMAX
    jae .r
    call it_freeslot
    cmp eax, 0
    jl .r
    mov [it_slot], eax
    call wait_start
    movzx eax, byte [fclip_dsk]
    call fs_setdisk
    jc .out
    movzx eax, byte [fclip_par]
    mov [fs_par], al
    mov esi, fclip_nm
    call file_read
    mov byte [fs_par], 0
    jc .out
    mov [it_fsz], eax
    cmp eax, 16
    jb .out
    cmp dword [DATA_BUF], 0x31464350     ; "PCF1"
    jne .out
    mov ebx, [DATA_BUF + 4]
    mov ecx, [DATA_BUF + 8]
    cmp ebx, 1
    jb .out
    cmp ebx, 2000
    ja .out
    cmp ecx, 1
    jb .out
    cmp ecx, 2000
    ja .out
    mov eax, ebx
    imul eax, ecx
    inc eax
    shr eax, 1
    add eax, 16
    cmp eax, [it_fsz]
    ja .out
    mov [it_pw0], ebx
    mov esi, 1                          ; во сколько раз уменьшить, чтобы влезло в 256 на 256
.sc:mov eax, ebx
    add eax, esi
    dec eax
    xor edx, edx
    div esi
    cmp eax, 256
    ja .big
    mov eax, ecx
    add eax, esi
    dec eax
    xor edx, edx
    div esi
    cmp eax, 256
    jbe .ok
.big:
    inc esi
    jmp .sc
.ok:mov [it_sc], esi
    mov eax, ebx
    add eax, esi
    dec eax
    xor edx, edx
    div esi
    mov [it_nw], eax
    mov eax, ecx
    add eax, esi
    dec eax
    xor edx, edx
    div esi
    mov [it_nh], eax
    mov edi, [it_slot]
    shl edi, 16
    add edi, IT_PIC
    xor ebp, ebp                        ; строка новой картинки
.ry:cmp ebp, [it_nh]
    jae .made
    xor ecx, ecx                        ; столбец
.rx:cmp ecx, [it_nw]
    jae .rn
    mov dword [it_best], 15             ; из блока точек берём первую не белую: тонкие линии не пропадают
    xor esi, esi
.dy:cmp esi, [it_sc]
    jae .pk
    mov eax, ebp
    imul eax, [it_sc]
    add eax, esi
    cmp eax, [DATA_BUF + 8]
    jae .pk
    imul eax, [it_pw0]
    xor ebx, ebx
.dx:cmp ebx, [it_sc]
    jae .dn
    mov edx, ecx
    imul edx, [it_sc]
    add edx, ebx
    cmp edx, [it_pw0]
    jae .dn
    add edx, eax
    push eax
    mov eax, edx
    shr eax, 1
    mov al, [DATA_BUF + 16 + eax]
    test dl, 1
    jnz .lo
    shr al, 4
.lo:and al, 15
    cmp al, 15
    je .nx2
    movzx eax, al
    mov [it_best], eax
    pop eax
    jmp .pk
.nx2:
    pop eax
    inc ebx
    jmp .dx
.dn:inc esi
    jmp .dy
.pk:mov al, [it_best]
    stosb
    inc ecx
    jmp .rx
.rn:inc ebp
    jmp .ry
.made:
    xor eax, eax
    call it_snapop
    mov eax, [it_on]
    imul eax, IT_ESZ
    lea edi, [it_obj + eax]
    push edi
    mov ecx, IT_ESZ / 4
    xor eax, eax
    cld
    rep stosd
    pop edi
    mov dword [edi], 2
    mov eax, [it_nw]
    mov [edi + 16], eax
    mov [edi + 28], eax
    mov eax, [it_nh]
    mov [edi + 20], eax
    mov [edi + 32], eax
    mov eax, [it_slot]
    mov [edi + 24], eax
    call it_place
    mov eax, [it_on]
    mov [it_sel], eax
    inc dword [it_on]
    mov byte [it_focus], 0
.out:
    call wait_end
.r: popad
    ret

; Экспорт в DATA_BUF (имя в fn_buf): расширение .txt - текст, иначе страница, которая сейчас вверху экрана, как картинка .pcf. ecx = размер
itge_export:
    pushad
    cld
    mov esi, fn_buf
    call strlen
    cmp ecx, 4
    jb .pcf
    mov eax, [fn_buf + ecx - 4]
    or eax, 0x20202020
    cmp eax, 0x7478742E                  ; ".txt"
    jne .pcf
    mov esi, IT_TXT
    mov edi, DATA_BUF
    mov ecx, [it_n]
.t: mov al, [esi]
    add esi, 4
    cmp al, 10
    jne .tc
    mov al, 13
    stosb
    mov al, 10
.tc:stosb
    dec ecx
    jnz .t
    sub edi, DATA_BUF
    mov [it_psz], edi
    jmp .out
.pcf:
    mov eax, [it_scroll]
    add eax, 40
    xor edx, edx
    mov ecx, PGH + PGGAP
    div ecx
    cmp eax, [it_np]
    jb .pg
    mov eax, [it_np]
    dec eax
.pg:imul eax, PGH + PGGAP
    add eax, PGGAP                       ; верх страницы в документе
    push dword [it_px0]
    push dword [it_dy]
    push dword [it_a]
    push dword [it_p]
    neg eax
    mov [it_dy], eax
    mov dword [it_px0], 0
    mov eax, [it_p]
    mov [it_a], eax
    mov byte [it_tobuf], 1
    mov dword [it_exh], PGH
    mov dword [clp_x0], 0
    mov dword [clp_y0], 0
    mov dword [clp_x1], PGW
    mov dword [clp_y1], PGH
    call it_view
    mov byte [it_tobuf], 0
    call mclip_off
    pop dword [it_p]
    pop dword [it_a]
    pop dword [it_dy]
    pop dword [it_px0]
    mov esi, IT_EXP
    mov edi, DATA_BUF
    mov dword [edi], 0x31464350
    mov dword [edi + 4], PGW
    mov dword [edi + 8], PGH
    mov dword [edi + 12], 0
    add edi, 16
    mov ecx, PGW * PGH / 2
.m: movzx eax, byte [esi]
    and eax, 15
    mov al, [it_pmap + eax]
    shl al, 4
    movzx edx, byte [esi + 1]
    and edx, 15
    or al, [it_pmap + edx]
    stosb
    add esi, 2
    dec ecx
    jnz .m
    sub edi, DATA_BUF
    mov [it_psz], edi
.out:
    popad
    mov ecx, [it_psz]
    ret

; ---------- данные ----------
it_swc    db 0, 1, 7, 15                    ; цвета Itge: чёрный, синий, серый, белый
it_pmap   db 0, 1, 8, 8, 8, 8, 8, 8, 8, 1, 8, 8, 8, 8, 8, 15       ; цвета для экспорта в .pcf: чёрный, синий, серый, белый
it_sintab dw 0, 22, 44, 66, 88, 108, 128, 147, 165, 181, 196, 210, 222, 233, 241, 247, 252, 255, 256
it_icsq   db 6, 6, 4, 22, 6, 2, 6, 20, 1, 22, 20, 3
it_icw    db 32, 20, 28, 16
s_title   db "FloItge", 0
s_file    db "File", 0
s_hint    db "File > New", 0
s_f0      db "Open...", 0
s_f1      db "New", 0
s_f2      db "Save", 0
s_f3      db "Save to...", 0
s_f4      db "Export", 0
s_f5      db "Print", 0
s_f6      db "Exit", 0
s_bold    db "Bold", 0
s_ital    db "Italic", 0
s_undl    db "Underline", 0
s_big     db "Bigger", 0
s_small   db "Smaller", 0
s_cut     db "Cut", 0
s_copy    db "Copy", 0
s_paste   db "Paste", 0
s_del     db "Delete", 0
s_it_fp   db "FloPaint", 0
it_ep_w   dd 0
it_ep_h   dd 0
it_ep_pl  dd 0
it_fm     dd s_f0, s_f1, s_f2, s_f3, s_f5, s_f6
it_ks     dd s_k_o, s_k_n, s_k_s, s_k_ss, s_k_p, s_k_e
it_rm1    dd s_copy, s_del, s_it_fp
it_rm2    dd s_bold, s_ital, s_undl, s_big, s_small, s_cut, s_copy, s_paste, s_del
it_have   db 0
it_focus  db 0
it_menu   db 0
it_cp     db 0
it_rm     db 0
it_lastop db 0
it_cbk    db 0
it_tobuf  db 0
it_bmps:
    dw 0x4002, 0x2004, 0x1008, 0x0810, 0x0420, 0x0240, 0x0180, 0x0180, 0x0240, 0x0420, 0x381C, 0x4422, 0x4422, 0x4422, 0x381C, 0x0000
    dw 0x7F80, 0x4080, 0x4080, 0x40FE, 0x4082, 0x4082, 0x7F82, 0x0082, 0x0082, 0x00FE, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
    dw 0x07E0, 0x0420, 0x3FFC, 0x2004, 0x2FF4, 0x2004, 0x2FF4, 0x2004, 0x2FF4, 0x2004, 0x2F84, 0x2004, 0x3FFC, 0x0000, 0x0000, 0x0000
    dw 0x0000, 0x600C, 0x3018, 0x1830, 0x0C60, 0x06C0, 0x0380, 0x0380, 0x06C0, 0x0C60, 0x1830, 0x3018, 0x600C, 0x0000, 0x0000, 0x0000
    dw 0x0000, 0x000C, 0x001E, 0x003C, 0x0078, 0x00F0, 0x01E0, 0x03C0, 0x0780, 0x0F00, 0x1E00, 0x3C00, 0x7800, 0x6000, 0x4000, 0x0000
it_ri1    db 6, 8, 9
it_ri2    db 0, 1, 2, 3, 4, 5, 6, 7, 8
it_rmn    dd 0
mi_y      dd 0
it_ck     db 133
it_cu     dd 0
it_cv     dd 0
bl_pl     dd 0
bl_lm     dd 0
bl_rm     dd 0
bl_g0     dd 0
bl_g1     dd 0
bl_vb     dd 0
it_spread dd 0x00000000, 0x00000001, 0x00000100, 0x00000101, 0x00010000, 0x00010001, 0x00010100, 0x00010101, 0x01000000, 0x01000001, 0x01000100, 0x01000101, 0x01010000, 0x01010001, 0x01010100, 0x01010101
bl_row    times 96 dd 0
bl_ch     times 96 db 0
bl_rd     db 0
it_shv    db 0
bl_mask   dd 0
it_lasta  dd -1
it_lsc    dd -1
it_lnp    dd -1
it_msn    db 0
it_fl     db 0
it_col    db 0
it_sz     db 1
it_tp     db 0
it_tmpc   dd 0
it_rmx    dd 0
it_rmy    dd 0
it_n      dd 1
it_p      dd 0
it_a      dd 0
it_cp_a   dd 0                          ; normalized selection start for Color
it_cp_p   dd 0                          ; normalized selection end (exclusive)
it_color_lo dd 0                        ; range saved across Undo snapshot
it_color_hi dd 0
it_color_req db 0                       ; requested VGA colour
it_color_ok db 0                        ; 1 if last written byte matches request
it_lo     dd 0
it_hi     dd 0
it_on     dd 0
it_sel    dd -1
it_nl     dd 0
it_np     dd 1
it_ovf    dd 0
it_scroll dd 0
it_dy     dd VY0
it_px0    dd PGX
it_exh    dd PGH
it_us     dd 0
it_re     dd 0
it_uh     dd 0
it_cbn    dd 0
it_psz    dd 0
it_fsz    dd 0
it_ptr    dd 0
it_tmp    dd 0
it_slot   dd 0
it_pw0    dd 0
it_sc     dd 1
it_nw     dd 0
it_nh     dd 0
it_best   dd 15
it_px     dd 0
it_py     dd 0
it_ox     dd 0
it_oy     dd 0
it_oa     dd 0
it_rw0    dd 1
it_rh0    dd 1
it_pgrab  dd 0
it_ax0    dd 0
it_ay0    dd 0
it_ax1    dd 0
it_ay1    dd 0
ly_nl     dd 0
ly_pg     dd 0
ly_y      dd 0
ly_al     dd 0
ly_sp     dd 0
ly_spw    dd 0
ly_sph    dd 0
ly_x      dd 0
gch       dd 0
gx        dd 0
gy        dd 0
gsz       dd 0
gfl       dd 0
gcol      dd 0
vw_x      dd 0
vw_y      dd 0
vw_h      dd 0
g_cx      dd 0
g_cy      dd 0
g_w       dd 0
g_h       dd 0
g_cos     dd 256
g_sin     dd 0
dp_base   dd 0
dp_sw     dd 0
dp_fx     dd 0
dp_fy     dd 0
dp_ex     dd 0
dp_ey     dd 0
dp_x0     dd 0
dp_x1     dd 0
dp_y      dd 0
dp_y1     dd 0
dp_hw     dd 0
dp_hh     dd 0
dp_rc     dd -1
dp_rx     dd 0
dp_rl     dd 0
fr_hx     dd 0
fr_hy     dd 0
bb_x      dd 0
bb_y      dd 0
bb_w      dd 0
bb_h      dd 0
bb_s      dd 0
bb_f      dd 0
bb_t      dd 0
ic_x      dd 0
ic_y      dd 0
ic_n      dd 0
ic_bg     dd 0
ic_fg     dd 0
sb_len    dd 0
sb_pos    dd 0
it_cbobj  times IT_ESZ db 0
it_obj    times IT_OMAX * IT_ESZ db 0

; Открыть файл в itge: .pcf вставляется картинкой, .txt - текстом в место курсора. esi = имя, al = диск, fs_par = папка
itge_insert_file:
    pushad
    mov [if_dsk], al
    mov al, [fs_par]
    mov [if_par], al
    mov edi, if_nm
    mov ecx, 16
    cld
    rep movsb
    call itge_open
    cmp byte [it_have], 0
    je .r
    mov esi, if_nm
    call strlen
    cmp ecx, 5
    jb .r
    mov eax, [if_nm + ecx - 4]
    or eax, 0x20202020
    cmp eax, 0x6663702E                  ; ".pcf"
    je .pcf
    cmp eax, 0x7478742E                  ; ".txt"
    je .txt
    jmp .r
.pcf:
    mov esi, fclip_ok                    ; буфер копирования FloFile на время вставки сохраняем
    mov edi, if_sv
    mov ecx, 19
    rep movsb
    mov esi, if_nm
    mov edi, fclip_nm
    mov ecx, 16
    rep movsb
    mov al, [if_dsk]
    mov [fclip_dsk], al
    mov al, [if_par]
    mov [fclip_par], al
    mov byte [fclip_ok], 1
    call it_paste_pcf
    mov esi, if_sv
    mov edi, fclip_ok
    mov ecx, 19
    rep movsb
    call redraw
    jmp .r
.txt:
    call wait_start
    mov al, [if_dsk]
    call fs_setdisk
    jc .tend
    mov al, [if_par]
    mov [fs_par], al
    mov esi, if_nm
    call file_read
    mov byte [fs_par], 0
    jc .tend
    mov ecx, eax
    mov esi, DATA_BUF
    mov edi, IT_CBTXT
    xor ebx, ebx
    mov edx, IT_TMAX
    sub edx, [it_n]
.tl:test ecx, ecx
    jz .tf
    dec ecx
    movzx eax, byte [esi]
    inc esi
    cmp al, 13
    je .tl
    cmp al, 9
    jne .t1
    mov al, ' '
.t1:cmp al, 10
    je .t2
    cmp al, 32
    jb .tl
    CHKHI al, .tl
.t2:cmp ebx, edx
    jae .tf
    movzx eax, al
    movzx ebp, byte [it_col]
    shl ebp, 16
    or eax, ebp
    movzx ebp, byte [it_sz]
    shl ebp, 24
    or eax, ebp
    mov [edi], eax
    add edi, 4
    inc ebx
    jmp .tl
.tf:test ebx, ebx
    jz .tend
    mov [it_cbn], ebx
    mov byte [it_cbk], 1
    call it_paste_txt
    call it_showcaret
    call it_refresh
.tend:
    call wait_end
    call redraw
.r: popad
    ret

if_dsk db 0
if_par db 0
if_nm  times 16 db 0
if_sv  times 20 db 0

s_k_s   db "Ctrl + S", 0
s_k_ss  db "Ctrl + T", 0
s_k_o   db "Ctrl + O", 0
s_k_n   db "Ctrl + N", 0
s_k_e   db "Ctrl + E", 0
s_k_p   db "Ctrl + P", 0
s_k_empty db 0
