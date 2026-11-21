; FloPaint - рисовалка на весь экран: холст, кисть, ластик, заливка, линия, прямоугольник, круг, пипетка, текст, отмена, файлы .pcf
; Подключается из kernel32.asm (%include)

; Холст лежит в памяти выше 1 МБ: по байту на точку (номер цвета 0..15). Рядом 10 снимков для отмены.
PA_CANVAS   equ 0x200000
PA_W        equ 680                     ; холст всегда один: почти на весь экран
PA_H        equ 500
PA_SLOT     equ 340000                  ; место под один снимок для отмены (680 x 500)
PA_UNDO     equ 0x500000                ; 10 снимков подряд
PA_STK      equ 0x300000                ; стек заливки
PA_STKEND   equ 0x3F0000
PA_N        equ 10                      ; сколько отмен
PA_CX       equ 108                     ; левый верхний угол холста на экране
PA_CY       equ 90

; Номера для мыши: 200..206 инструменты, 208 ползунок толщины, 213..216 цвета, 229 холст, 230 File,
; 231..235 пункты меню

paint_open:
    cmp byte [d2_paint], 0
    jne .r
    mov al, 3
    call z_hide_others
    call splash_start
    mov byte [d2_paint], 1
    mov byte [pa_menu], 0
    mov byte [pa_drag], 0
    mov byte [pa_text], 0
    mov byte [pa_dsk], 0xFF
    mov byte [pa_tool], 0
    mov byte [pa_size], 3
    mov byte [pa_col], 0
    call paint_new
    call wait_end
    jmp redraw
.r: ret

; Закрыть FloPaint: если есть несохранённое, спросить
paint_exit:
    cmp byte [pa_dirty], 0
    je paint_close
    mov al, 1
    jmp sv_ask

paint_close:
    mov byte [pa_dirty], 0
    mov byte [d2_paint], 0
    mov byte [pa_menu], 0
    mov byte [pa_drag], 0
    mov byte [pa_text], 0
    mov al, 3
    call z_restore
    jmp redraw

; Новая белая картинка
paint_new:
    pushad
    mov dword [pa_w], PA_W
    mov dword [pa_h], PA_H
    mov ecx, PA_W * PA_H
    mov edi, PA_CANVAS
    mov al, 15
    cld
    rep stosb
    mov byte [pa_un_n], 0
    mov byte [pa_re_n], 0
    mov byte [pa_un_top], 0
    mov byte [pa_has], 1
    mov byte [pa_link], 0
    mov byte [pa_dirty], 0
    mov byte [pa_text], 0
    mov byte [pa_drag], 0
    mov byte [pa_dsk], 0xFF
    popad
    ret

; Ящик с цветом: eax, ebx - угол, ecx, edx - размер, esi - цвет
pa_box:
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    mov [r_c], esi
    jmp fill_rect

; Заголовок окна: FloPaint или X:имя.pcf
pa_title:
    pushad
    mov edi, pa_ttl
    cmp byte [pa_dsk], 0xFF
    jne .f
    mov byte [edi], 0                   ; файла нет - слева в заголовке пусто
    popad
    ret
.f: mov esi, pa_nm                      ; только имя: без диска и без расширения
    xor ebx, ebx                        ; ebx - где последняя точка
.n: lodsb
    test al, al
    jz .e
    cmp al, '.'
    jne .p
    mov ebx, edi
.p: stosb
    jmp .n
.e: test ebx, ebx
    jz .z
    mov edi, ebx
.z: mov byte [edi], 0
    popad
    ret

paint_draw:
    pushad
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    RECT 0, 0, 800, 600, C_WHITE
    RECT 0, 38, 800, 2, C_BLACK
    call pa_title
    mov esi, s_paint                    ; по центру - название программы
    call strlen
    shl ecx, 4
    mov eax, 800
    sub eax, ecx
    shr eax, 1
    mov [t_x], eax
    mov dword [t_y], 2
    mov dword [r_c], C_BLACK
    call draw_big
    mov dword [t_x], 8                  ; слева - имя файла без диска и расширения
    mov esi, pa_ttl
    call draw_big
    RECT 0, 78, 800, 2, C_BLACK
    cmp byte [pa_menu], 0
    je .fn
    RECT 4, 42, 80, 34, C_BLACK
    mov dword [r_c], C_WHITE
    jmp .ft
.fn:
    RECT 4, 42, 80, 34, C_BLACK
    RECT 6, 44, 76, 30, C_WHITE
    mov dword [r_c], C_BLACK
.ft:mov dword [t_x], 12
    mov dword [t_y], 44
    mov esi, s_file
    call draw_big
    call pa_tools
    call pa_slider
    call pa_palette
    call pa_arrows
    call pa_frame
    cmp byte [pa_text], 0
    je .mn
    call pa_caret
.mn:cmp byte [pa_menu], 0
    je .e
    RECT 8, 82, 336, 188, C_BLACK
    RECT 4, 78, 336, 188, C_BLACK
    RECT 6, 80, 332, 184, C_WHITE
    mov dword [r_c], C_BLACK
    mov dword [t_x], 12
    mov dword [t_y], 82
    mov esi, s_pa_new
    call draw_big
    mov dword [t_x], 196
    mov esi, s_k_n
    call draw_big
    mov dword [t_x], 12
    mov dword [t_y], 118
    mov esi, s_m_save
    call draw_big
    mov dword [t_x], 196
    mov esi, s_k_s
    call draw_big
    mov dword [t_x], 12
    mov dword [t_y], 154
    mov esi, s_m_saveto
    call draw_big
    mov dword [t_x], 196
    mov esi, s_k_ss
    call draw_big
    mov dword [t_x], 12
    mov dword [t_y], 190
    mov esi, s_m_open
    call draw_big
    mov dword [t_x], 196
    mov esi, s_k_o
    call draw_big
    mov dword [t_x], 12
    mov dword [t_y], 226
    mov esi, s_exit
    call draw_big
    mov dword [t_x], 196
    mov esi, s_k_e
    call draw_big
    mov dword [t_x], 12
.e: call mn_pdraw
    popad
    ret

;  Y строки кнопок слева: eax - номер строки (0..7) -> eax - верх кнопки; между группами зазор
pa_ry:
    push edx
    mov edx, eax
    imul eax, 44
    add eax, 88
    cmp edx, 4
    jb .a
    add eax, 8
    cmp edx, 6
    jb .a
    add eax, 8
.a: pop edx
    ret

; Левая панель: инструменты и Undo (кнопки 0..7), толщина (8..11); кнопки в два столбца
pa_tools:
    pushad
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    RECT 96, 80, 2, 520, C_BLACK
    xor ebp, ebp
.t: xor edi, edi
    mov eax, ebp
    cmp eax, 7
    jb .tl
    je .go
    cmp eax, 12
    jae .go
    sub eax, 8
    cmp al, [pa_size]
    jmp .cm
.tl:cmp al, [pa_tool]
.cm:jne .go
    inc edi
.go:mov [pa_t2], edi
    mov eax, ebp
    and eax, 1
    imul eax, 44
    add eax, 4
    mov [pa_t3], eax
    mov eax, ebp
    shr eax, 1
    call pa_ry
    mov [pa_t4], eax
    mov ebx, eax
    mov eax, [pa_t3]
    mov ecx, 40
    mov edx, 40
    mov esi, s_pa_none
    call wbtn
    call pa_icon
    inc ebp
    cmp ebp, 7
    jb .t
    popad
    ret

; Один слой значка: esi - 32 строки по 32 точки, цвет в pa_t5, угол кнопки pa_t3, pa_t4
pa_layer:
    pushad
    xor ebx, ebx
.r: mov edx, [esi + ebx * 4]
    xor ecx, ecx
.cl:cmp ecx, 32
    jae .nr
    mov eax, 0x80000000
    shr eax, cl
    test edx, eax
    jnz .st
    inc ecx
    jmp .cl
.st:mov edi, ecx
.x: inc ecx
    cmp ecx, 32
    jae .dr
    mov eax, 0x80000000
    shr eax, cl
    test edx, eax
    jnz .x
.dr:pushad
    sub ecx, edi
    lea eax, [edi + 4]
    add eax, [pa_t3]
    add ebx, [pa_t4]
    add ebx, 4
    mov edx, 1
    mov esi, [pa_t5]
    call pa_box
    popad
    jmp .cl
.nr:inc ebx
    cmp ebx, 32
    jb .r
    popad
    ret

; Картинка на кнопке номер ebp: инструменты рисуются по точкам 16x16, толщина - квадратиком
pa_icon:
    pushad
    cmp dword [pa_t2], 0                ; выбранная кнопка: белая площадка внутри чёрной рамки
    je .ns
    mov eax, [pa_t3]
    add eax, 3
    mov ebx, [pa_t4]
    add ebx, 3
    mov ecx, 34
    mov edx, 34
    mov esi, C_WHITE
    call pa_box
.ns:cmp ebp, 8
    jae .e
    mov esi, ebp
    shl esi, 7
    mov [pa_t6], esi
    add esi, pa_iw
    mov dword [pa_t5], 7                ; светло-серый
    call pa_layer
    mov esi, [pa_t6]
    add esi, pa_ic
    mov dword [pa_t5], C_BLACK
    call pa_layer
    mov esi, [pa_t6]
    add esi, pa_ib
    mov dword [pa_t5], C_BLUE
    call pa_layer
.e: popad
    ret

; Палитра слева под толщиной: 4 цвета в два столбца, выбранный в рамке
pa_palette:
    pushad
    xor ebp, ebp
.p: mov eax, ebp
    and eax, 1
    imul eax, 44
    add eax, 4
    mov [pa_t3], eax
    mov eax, ebp
    shr eax, 1
    add eax, 6
    call pa_ry
    mov [pa_t4], eax
    mov eax, [pa_t3]
    mov ebx, [pa_t4]
    mov ecx, 40
    mov edx, 40
    xor esi, esi
    call pa_box
    mov eax, [pa_t3]
    add eax, 2
    mov ebx, [pa_t4]
    add ebx, 2
    mov ecx, 36
    mov edx, 36
    mov esi, C_WHITE
    call pa_box
    movzx esi, byte [pa_pal + ebp]
    mov eax, esi
    cmp al, [pa_col]
    jne .n
    mov eax, [pa_t3]
    add eax, 6
    mov ebx, [pa_t4]
    add ebx, 6
    mov ecx, 28
    mov edx, 28
    jmp .c
.n: mov eax, [pa_t3]
    add eax, 2
    mov ebx, [pa_t4]
    add ebx, 2
    mov ecx, 36
    mov edx, 36
.c: call pa_box
    inc ebp
    cmp ebp, 4
    jb .p
    popad
    ret

; Рамка холста и все его точки
pa_frame:
    pushad
    RECT 98, 80, 702, 520, C_WHITE
    mov eax, PA_CX - 4
    mov ebx, PA_CY - 4
    mov ecx, [pa_w]
    add ecx, 8
    mov edx, [pa_h]
    add edx, 8
    xor esi, esi
    call pa_box
    call pa_canvas_all
    popad
    ret

; Нарисовать все точки холста: одинаковые подряд собираются в один прямоугольник
pa_canvas_all:
    pushad
    xor ebp, ebp
.y: mov eax, ebp
    imul eax, [pa_w]
    lea esi, [PA_CANVAS + eax]
    xor ebx, ebx
.x: mov [pa_rx0], ebx
    movzx ecx, byte [esi + ebx]
    mov [pa_rc], ecx
    mov edx, ebx
.r: inc edx
    cmp edx, [pa_w]
    jae .e
    cmp cl, [esi + edx]
    je .r
.e: mov ebx, edx
    mov eax, [pa_rx0]
    add eax, PA_CX
    mov ecx, edx
    sub ecx, [pa_rx0]
    push ebx
    push esi
    mov ebx, ebp
    add ebx, PA_CY
    mov edx, 1
    mov esi, [pa_rc]
    call pa_box
    pop esi
    pop ebx
    cmp ebx, [pa_w]
    jb .x
    inc ebp
    cmp ebp, [pa_h]
    jb .y
    popad
    ret

; Прямоугольник на экране с обрезкой по холсту: r_x, r_y, r_w, r_h, r_c, r_fn уже стоят
pa_clipfill:
    pushad
    mov dword [clp_x0], PA_CX
    mov dword [clp_y0], PA_CY
    mov eax, [pa_w]
    add eax, PA_CX
    mov [clp_x1], eax
    mov eax, [pa_h]
    add eax, PA_CY
    mov [clp_y1], eax
    call fill_rect
    mov dword [clp_x0], 0
    mov dword [clp_y0], 0
    mov dword [clp_x1], 800
    mov dword [clp_y1], 600
    popad
    ret

; Точка (eax, ebx) цветом pa_cc: в холст и на экран
pa_px:
    cmp eax, 0
    jl .r
    cmp eax, [pa_w]
    jge .r
    cmp ebx, 0
    jl .r
    cmp ebx, [pa_h]
    jge .r
    pushad
    mov ecx, ebx
    imul ecx, [pa_w]
    add ecx, eax
    mov dl, [pa_cc]
    mov [PA_CANVAS + ecx], dl
    add eax, PA_CX
    add ebx, PA_CY
    mov ecx, 1
    mov edx, 1
    movzx esi, byte [pa_cc]
    call pa_box
    popad
.r: ret

; Прямоугольник (eax, ebx - угол, ecx, edx - размер) цветом pa_cc: в холст и на экран, края обрезаются
pa_rectc:
    pushad
    mov esi, eax
    add esi, ecx
    cmp eax, 0
    jge .a
    xor eax, eax
.a: cmp esi, [pa_w]
    jle .b
    mov esi, [pa_w]
.b: sub esi, eax
    jle .r
    mov edi, ebx
    add edi, edx
    cmp ebx, 0
    jge .c
    xor ebx, ebx
.c: cmp edi, [pa_h]
    jle .d
    mov edi, [pa_h]
.d: sub edi, ebx
    jle .r
    mov [pa_t1], eax
    mov [pa_t2], ebx
    mov [pa_t3], esi
    mov [pa_t4], edi
    mov ebp, ebx
    imul ebp, [pa_w]
    add ebp, eax
    add ebp, PA_CANVAS
    mov edx, edi
    mov al, [pa_cc]
    cld
.row:
    mov edi, ebp
    mov ecx, [pa_t3]
    rep stosb
    add ebp, [pa_w]
    dec edx
    jnz .row
    mov eax, [pa_t1]
    add eax, PA_CX
    mov ebx, [pa_t2]
    add ebx, PA_CY
    mov ecx, [pa_t3]
    mov edx, [pa_t4]
    movzx esi, byte [pa_cc]
    call pa_box
.r: popad
    ret

; Мазок кистью в (eax, ebx): круг поперечником pa_dsz точек (ширина каждой строки - корень из n*n - dy*dy)
pa_dab:
    pushad
    movzx ecx, byte [pa_dsz]
    mov [pd_n], ecx
    mov [pd_x], eax
    shr ecx, 1
    sub ebx, ecx
    mov [pd_y], ebx
    xor esi, esi
.l: lea eax, [esi * 2 + 1]
    sub eax, [pd_n]
    imul eax, eax
    mov edx, [pd_n]
    imul edx, edx
    sub edx, eax
    xor ecx, ecx
.s: lea eax, [ecx + 1]
    imul eax, eax
    cmp eax, edx
    ja .sd
    inc ecx
    jmp .s
.sd:test ecx, ecx
    jnz .w
    mov ecx, 1
.w: mov eax, ecx
    shr eax, 1
    neg eax
    add eax, [pd_x]
    mov ebx, [pd_y]
    add ebx, esi
    mov edx, 1
    call pa_rectc
    inc esi
    cmp esi, [pd_n]
    jb .l
    popad
    ret

; Ползунок толщины слева (под инструментами) и пример кисти
pa_slider:
    pushad
    RECT 0, 272, 96, 84, C_WHITE
    RECT 8, 288, 80, 4, C_BLACK
    movzx eax, byte [pa_size]
    dec eax
    imul eax, 70
    xor edx, edx
    mov ecx, 29
    div ecx
    add eax, 8
    mov ebx, 278
    mov ecx, 10
    mov edx, 24
    xor esi, esi
    call pa_box
    mov eax, 8
    movzx ecx, byte [pa_size]
    dec ecx
    imul ecx, 70
    push eax
    mov eax, ecx
    xor edx, edx
    mov ecx, 29
    div ecx
    pop ecx
    add eax, ecx
    add eax, 2
    mov ebx, 280
    mov ecx, 6
    mov edx, 20
    mov esi, C_WHITE
    call pa_box
    RECT 4, 312, 84, 44, C_BLACK
    RECT 6, 314, 80, 40, C_WHITE
    movzx ecx, byte [pa_size]
    mov [pd_n], ecx
    xor esi, esi
.l: lea eax, [esi * 2 + 1]
    sub eax, [pd_n]
    imul eax, eax
    mov edx, [pd_n]
    imul edx, edx
    sub edx, eax
    xor ecx, ecx
.s: lea eax, [ecx + 1]
    imul eax, eax
    cmp eax, edx
    ja .sd
    inc ecx
    jmp .s
.sd:test ecx, ecx
    jnz .w
    mov ecx, 1
.w: mov eax, ecx
    shr eax, 1
    neg eax
    add eax, 46
    mov ebx, 334
    mov edx, [pd_n]
    shr edx, 1
    sub ebx, edx
    add ebx, esi
    mov edx, 1
    push esi
    xor esi, esi
    call pa_box
    pop esi
    inc esi
    cmp esi, [pd_n]
    jb .l
    popad
    ret

; Ползунок: размер из положения мыши
pa_slset:
    mov eax, [m_x]
    sub eax, 8
    jge .a
    xor eax, eax
.a: cmp eax, 70
    jbe .b
    mov eax, 70
.b: imul eax, 29
    xor edx, edx
    mov ecx, 70
    div ecx
    inc eax
    cmp al, [pa_size]
    je .r
    mov [pa_size], al
    jmp pa_slider
.r: ret

; Одна точка предпросмотра: переворот цветов на экране, второй раз стирает
pa_xorpt:
    pushad
    cmp eax, 0
    jl .r
    cmp eax, [pa_w]
    jge .r
    cmp ebx, 0
    jl .r
    cmp ebx, [pa_h]
    jge .r
    add eax, PA_CX
    add ebx, PA_CY
    mov [r_x], eax
    mov [r_y], ebx
    mov dword [r_w], 1
    mov dword [r_h], 1
    mov dword [r_c], 15
    mov dword [r_fn], 0x18
    call fill_rect
    mov dword [r_fn], 0
.r: popad
    ret

; Линия из (eax, ebx) в (ecx, edx): в каждой точке вызывается [pa_pt] (eax - x, ebx - y)
pa_line:
    pushad
    mov [paln_x], eax
    mov [paln_y], ebx
    mov [paln_x1], ecx
    mov [paln_y1], edx
    mov eax, ecx
    sub eax, [paln_x]
    mov ecx, 1
    jge .a
    neg eax
    mov ecx, -1
.a: mov [paln_dx], eax
    mov [paln_sx], ecx
    mov eax, [paln_y1]
    sub eax, [paln_y]
    mov ecx, 1
    jge .b
    neg eax
    mov ecx, -1
.b: neg eax
    mov [paln_dy], eax
    mov [paln_sy], ecx
    mov eax, [paln_dx]
    add eax, [paln_dy]
    mov [paln_er], eax
.l: mov eax, [paln_x]
    mov ebx, [paln_y]
    call [pa_pt]
    mov eax, [paln_x]
    cmp eax, [paln_x1]
    jne .s
    mov eax, [paln_y]
    cmp eax, [paln_y1]
    je .e
.s: mov eax, [paln_er]
    add eax, eax
    cmp eax, [paln_dy]
    jl .n1
    mov ecx, [paln_dy]
    add [paln_er], ecx
    mov ecx, [paln_sx]
    add [paln_x], ecx
.n1:cmp eax, [paln_dx]
    jg .l
    mov ecx, [paln_dx]
    add [paln_er], ecx
    mov ecx, [paln_sy]
    add [paln_y], ecx
    jmp .l
.e: popad
    ret

; Круг с центром (pa_sx, pa_sy) и радиусом eax: точки через [pa_pt]
pa_circle:
    pushad
    mov [pacr_x], eax
    mov dword [pacr_y], 0
    mov ecx, 1
    sub ecx, eax
    mov [pacr_d], ecx
.l: mov eax, [pacr_x]
    cmp eax, [pacr_y]
    jl .e
    mov eax, [pacr_x]
    mov ebx, [pacr_y]
    call .pp
    mov eax, [pacr_x]
    neg eax
    mov ebx, [pacr_y]
    call .pp
    mov eax, [pacr_x]
    mov ebx, [pacr_y]
    neg ebx
    call .pp
    mov eax, [pacr_x]
    neg eax
    mov ebx, [pacr_y]
    neg ebx
    call .pp
    mov eax, [pacr_y]
    mov ebx, [pacr_x]
    call .pp
    mov eax, [pacr_y]
    neg eax
    mov ebx, [pacr_x]
    call .pp
    mov eax, [pacr_y]
    mov ebx, [pacr_x]
    neg ebx
    call .pp
    mov eax, [pacr_y]
    neg eax
    mov ebx, [pacr_x]
    neg ebx
    call .pp
    inc dword [pacr_y]
    mov eax, [pacr_d]
    cmp eax, 0
    jg .big
    mov ecx, [pacr_y]
    lea eax, [eax + ecx * 2 + 1]
    mov [pacr_d], eax
    jmp .l
.big:
    dec dword [pacr_x]
    mov ecx, [pacr_y]
    sub ecx, [pacr_x]
    lea eax, [eax + ecx * 2 + 1]
    mov [pacr_d], eax
    jmp .l
.e: popad
    ret
.pp:add eax, [pa_sx]
    add ebx, [pa_sy]
    call [pa_pt]
    ret

; Фигура от (pa_sx, pa_sy) до (pa_ex, pa_ey) текущим инструментом: линия, прямоугольник или круг, точки через [pa_pt]
pa_shape:
    pushad
    movzx eax, byte [pa_tool]
    cmp eax, 4
    je .rect
    ja .circ
    call pa_xon
    mov eax, [pa_sx]
    mov ebx, [pa_sy]
    mov ecx, [pa_ex]
    mov edx, [pa_ey]
    call pa_line
    call pa_xoff
    jmp .e
.rect:
    cmp dword [pa_pt], pa_xorpt
    jne .rslow
    mov eax, [pa_sx]                    ; предпросмотр: четыре полоски, а не точка за точкой (быстрее - меньше мерцает)
    mov ecx, [pa_ex]
    cmp eax, ecx
    jle .r1
    xchg eax, ecx
.r1:mov [el_x0], eax
    mov [el_x1], ecx
    mov eax, [pa_sy]
    mov ecx, [pa_ey]
    cmp eax, ecx
    jle .r2
    xchg eax, ecx
.r2:mov [el_y0], eax
    mov [el_y1], ecx
    mov eax, [el_x1]
    sub eax, [el_x0]
    inc eax
    mov [el_a2], eax                    ; ширина
    mov eax, [el_y1]
    sub eax, [el_y0]
    inc eax
    mov [el_b2], eax                    ; высота
    mov eax, [el_x0]
    mov ebx, [el_y0]
    mov ecx, [el_a2]
    mov edx, 1
    call pa_xorbox
    cmp dword [el_b2], 1
    jbe .e
    mov eax, [el_x0]
    mov ebx, [el_y1]
    mov ecx, [el_a2]
    mov edx, 1
    call pa_xorbox
    mov edx, [el_b2]
    sub edx, 2
    jle .e
    mov eax, [el_x0]
    mov ebx, [el_y0]
    inc ebx
    mov ecx, 1
    call pa_xorbox
    cmp dword [el_a2], 1
    jbe .e
    mov eax, [el_x1]
    mov ebx, [el_y0]
    inc ebx
    mov ecx, 1
    call pa_xorbox
    jmp .e
.rslow:
    mov eax, [pa_sx]
    mov ebx, [pa_sy]
    mov ecx, [pa_ex]
    mov edx, [pa_sy]
    call pa_line
    mov eax, [pa_ex]
    mov ebx, [pa_sy]
    mov ecx, [pa_ex]
    mov edx, [pa_ey]
    call pa_line
    mov eax, [pa_ex]
    mov ebx, [pa_ey]
    mov ecx, [pa_sx]
    mov edx, [pa_ey]
    call pa_line
    mov eax, [pa_sx]
    mov ebx, [pa_ey]
    mov ecx, [pa_sx]
    mov edx, [pa_sy]
    call pa_line
    jmp .e
.circ:                                  ; овал: вписан в прямоугольник от начала до мыши (как в Paint)
    mov eax, [pa_ex]
    sub eax, [pa_sx]
    jge .p1
    neg eax
.p1:cmp eax, 2
    jb .rect                            ; слишком узкий - рисуем как прямоугольник
    mov eax, [pa_ey]
    sub eax, [pa_sy]
    jge .p2
    neg eax
.p2:cmp eax, 2
    jb .rect
    call pa_xon
    call pa_ellipse
    call pa_xoff
.e: popad
    ret

; Предпросмотр фигуры: точки рисуются быстро - видеорегистры настраиваются один раз на всю фигуру,
; а не на каждую точку (так курсор мыши не мерцает, пока рисуется круг или линия)
pa_xon:
    cmp dword [pa_pt], pa_xorpt
    jne .n
    mov dword [pa_pt], pa_xorfast
    pushad
    mov dx, 0x3CE
    mov ax, 0x0005
    out dx, ax
    mov ax, 0x1803                      ; XOR с тем, что уже на экране
    out dx, ax
    mov ax, 0x0F01
    out dx, ax
    mov ax, 0x0F00                      ; цвет 15 во всех плоскостях - точка переворачивается
    out dx, ax
    mov dx, 0x3C4
    mov ax, 0x0F02
    out dx, ax
    popad
.n: ret

pa_xoff:
    cmp dword [pa_pt], pa_xorfast
    jne .n
    mov dword [pa_pt], pa_xorpt
    pushad
    mov dx, 0x3CE
    mov ax, 0x0003
    out dx, ax
    mov ax, 0xFF08
    out dx, ax
    popad
.n: ret

; Быстрая точка (eax, ebx) внутри холста: только маска бита, чтение, запись
pa_xorfast:
    pushad
    cmp eax, 0
    jl .r
    cmp eax, [pa_w]
    jge .r
    cmp ebx, 0
    jl .r
    cmp ebx, [pa_h]
    jge .r
    add eax, PA_CX
    add ebx, PA_CY
    mov ecx, eax
    imul ebx, 100
    shr eax, 3
    lea edi, [VGA + ebx + eax]
    and ecx, 7
    mov ah, 0x80
    shr ah, cl
    mov al, 8
    mov dx, 0x3CE
    out dx, ax
    mov al, [edi]
    mov [edi], al
.r: popad
    ret

; Овал в прямоугольнике (pa_sx, pa_sy) - (pa_ex, pa_ey): в каждой четверти по строкам, каждая точка ровно один раз
pa_ellipse:
    pushad
    mov eax, [pa_sx]
    mov ecx, [pa_ex]
    cmp eax, ecx
    jle .x
    xchg eax, ecx
.x: mov [el_x0], eax
    mov [el_x1], ecx
    mov eax, [pa_sy]
    mov ecx, [pa_ey]
    cmp eax, ecx
    jle .y
    xchg eax, ecx
.y: mov [el_y0], eax
    mov [el_y1], ecx
    mov eax, [el_x1]                    ; a - полуширина, центры cx0 и cx1 (у нечётной ширины они рядом)
    sub eax, [el_x0]
    shr eax, 1
    mov [el_a], eax
    imul eax, eax
    mov [el_a2], eax
    mov eax, [el_x0]
    add eax, [el_a]
    mov [el_cx0], eax
    mov eax, [el_x1]
    sub eax, [el_a]
    mov [el_cx1], eax
    mov eax, [el_y1]
    sub eax, [el_y0]
    shr eax, 1
    mov [el_b], eax
    imul eax, eax
    mov [el_b2], eax
    mov eax, [el_y0]
    add eax, [el_b]
    mov [el_cy0], eax
    mov eax, [el_y1]
    sub eax, [el_b]
    mov [el_cy1], eax
    mov dword [el_y], 0
.row:
    mov eax, [el_y]
    call el_f
    mov [el_f0], eax
    mov eax, [el_y]
    inc eax
    call el_f
    mov [el_x], eax                     ; от края следующей строки до края этой
.col:
    cmp dword [pa_pt], pa_xorpt
    jne .cs
    call el_xor4                        ; предпросмотр: по полоске на строку
    jmp .nr
.cs:mov eax, [el_x]
    cmp eax, [el_f0]
    ja .nr
    call el_plot4
    inc dword [el_x]
    jmp .col
.nr:inc dword [el_y]
    mov eax, [el_y]
    cmp eax, [el_b]
    jbe .row
    popad
    ret

; Полоски (eax, ebx - угол, ecx, edx - размер, точки холста): переворот цветов на экране, второй раз стирает
pa_xorbox:
    pushad
    add eax, PA_CX
    add ebx, PA_CY
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    mov dword [r_c], 15
    mov dword [r_fn], 0x18
    call pa_clipfill
    mov dword [r_fn], 0
    popad
    ret

; Строка овала целиком (el_x .. el_f0 от центра) во все четыре стороны полосками
el_xor4:
    mov eax, [el_f0]
    sub eax, [el_x]
    inc eax
    mov [el_len], eax
    mov ecx, eax
    cmp dword [el_x], 0
    jne .a
    mov eax, [el_cx0]
    cmp eax, [el_cx1]
    jne .a
    dec ecx                             ; ось: левая и правая половины делят одну точку
.a: mov [el_len2], ecx
    mov eax, [el_cx1]
    add eax, [el_x]
    mov ebx, [el_cy1]
    add ebx, [el_y]
    mov ecx, [el_len]
    mov edx, 1
    call pa_xorbox
    cmp dword [el_len2], 0
    je .b
    mov eax, [el_cx0]
    sub eax, [el_f0]
    mov ebx, [el_cy1]
    add ebx, [el_y]
    mov ecx, [el_len2]
    mov edx, 1
    call pa_xorbox
.b: cmp dword [el_y], 0
    jne .c
    mov eax, [el_cy0]
    cmp eax, [el_cy1]
    je .r
.c: mov eax, [el_cx1]
    add eax, [el_x]
    mov ebx, [el_cy0]
    sub ebx, [el_y]
    mov ecx, [el_len]
    mov edx, 1
    call pa_xorbox
    cmp dword [el_len2], 0
    je .r
    mov eax, [el_cx0]
    sub eax, [el_f0]
    mov ebx, [el_cy0]
    sub ebx, [el_y]
    mov ecx, [el_len2]
    mov edx, 1
    call pa_xorbox
.r: ret

el_len  dd 0
el_len2 dd 0

; eax = строка y от центра -> eax = на сколько вправо от центра идёт овал в этой строке (0 дальше края)
el_f:
    push ebx
    push ecx
    push edx
    push edi
    cmp eax, [el_b]
    ja .z
    imul eax, eax
    mov ebx, [el_b2]
    sub ebx, eax
    mov eax, [el_a2]
    mul ebx
    div dword [el_b2]                   ; a * a * (b * b - y * y) / (b * b)
    mov ebx, eax
    xor eax, eax
    mov ecx, 512
.b: lea edx, [eax + ecx]                ; целый корень по битам
    mov edi, edx
    imul edi, edi
    cmp edi, ebx
    ja .n
    mov eax, edx
.n: shr ecx, 1
    jnz .b
    jmp .r
.z: xor eax, eax
.r: pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; Точка (el_x, el_y) от центра во все четыре стороны; совпадающие точки (на осях) только раз
el_plot4:
    mov dword [el_sk], 0
    cmp dword [el_x], 0
    jne .a
    mov eax, [el_cx0]
    cmp eax, [el_cx1]
    jne .a
    or dword [el_sk], 1
.a: cmp dword [el_y], 0
    jne .b
    mov eax, [el_cy0]
    cmp eax, [el_cy1]
    jne .b
    or dword [el_sk], 2
.b: mov eax, [el_cx1]
    add eax, [el_x]
    mov ebx, [el_cy1]
    add ebx, [el_y]
    call [pa_pt]
    test dword [el_sk], 1
    jnz .c
    mov eax, [el_cx0]
    sub eax, [el_x]
    mov ebx, [el_cy1]
    add ebx, [el_y]
    call [pa_pt]
.c: test dword [el_sk], 2
    jnz .r
    mov eax, [el_cx1]
    add eax, [el_x]
    mov ebx, [el_cy0]
    sub ebx, [el_y]
    call [pa_pt]
    test dword [el_sk], 1
    jnz .r
    mov eax, [el_cx0]
    sub eax, [el_x]
    mov ebx, [el_cy0]
    sub ebx, [el_y]
    call [pa_pt]
.r: ret

el_x0 dd 0
el_x1 dd 0
el_y0 dd 0
el_y1 dd 0
el_a  dd 0
el_b  dd 0
el_a2 dd 0
el_b2 dd 0
el_cx0 dd 0
el_cx1 dd 0
el_cy0 dd 0
el_cy1 dd 0
el_x  dd 0
el_y  dd 0
el_f0 dd 0
el_sk dd 0

; Запомнить холст для отмены
pa_push:
    pushad
    mov byte [pa_dirty], 1
    mov byte [pa_re_n], 0
    movzx eax, byte [pa_un_top]
    imul eax, PA_SLOT
    lea edi, [PA_UNDO + eax]
    mov esi, PA_CANVAS
    mov ecx, [pa_w]
    imul ecx, [pa_h]
    add ecx, 3
    shr ecx, 2
    cld
    rep movsd
    movzx eax, byte [pa_un_top]
    inc eax
    cmp eax, PA_N
    jb .a
    xor eax, eax
.a: mov [pa_un_top], al
    cmp byte [pa_un_n], PA_N
    jae .r
    inc byte [pa_un_n]
.r: popad
    ret

; Отмена: вернуть холст, каким он был перед последним действием
pa_pop:
    pushad
    call pa_endtext
    cmp byte [pa_un_n], 0
    je .r
    movzx eax, byte [pa_un_top]
    dec eax
    jns .a
    mov eax, PA_N - 1
.a: mov [pa_un_top], al
    dec byte [pa_un_n]
    inc byte [pa_re_n]
    imul eax, PA_SLOT
    lea esi, [PA_UNDO + eax]
    call pa_swap
    call pa_canvas_all
    call mn_pdraw
.r: popad
    ret

; Поменять местами холст и снимок esi: так отмена и возврат (Ctrl+Y) не требуют лишнего места
pa_swap:
    pushad
    mov edi, PA_CANVAS
    mov ecx, [pa_w]
    imul ecx, [pa_h]
    add ecx, 3
    shr ecx, 2
.l: mov eax, [esi]
    xchg eax, [edi]
    mov [esi], eax
    add esi, 4
    add edi, 4
    dec ecx
    jnz .l
    popad
    ret

; Вернуть отменённое (Ctrl+Y)
pa_redo:
    pushad
    call pa_endtext
    cmp byte [pa_re_n], 0
    je .r
    movzx eax, byte [pa_un_top]
    mov edx, eax
    inc eax
    cmp eax, PA_N
    jb .a
    xor eax, eax
.a: mov [pa_un_top], al
    inc byte [pa_un_n]
    dec byte [pa_re_n]
    imul edx, PA_SLOT
    lea esi, [PA_UNDO + edx]
    call pa_swap
    call pa_canvas_all
    call mn_pdraw
.r: popad
    ret

; Две кнопки со стрелками под палитрой: назад (отмена) и вперёд
pa_arrows:
    pushad
    mov eax, 8
    call pa_ry
    mov [pa_t4], eax
    xor ebp, ebp
.b: mov eax, ebp
    imul eax, 44
    add eax, 4
    mov [pa_t3], eax
    mov eax, [pa_t3]
    mov ebx, [pa_t4]
    mov ecx, 40
    mov edx, 40
    mov esi, s_pa_none
    xor edi, edi
    call wbtn
    pushad
    mov eax, [pa_t3]
    test ebp, ebp
    jnz .sr
    add eax, 22
    jmp .ss
.sr:add eax, 6
.ss:mov ebx, [pa_t4]
    add ebx, 18
    mov ecx, 12
    mov edx, 4
    xor esi, esi
    call pa_box
    popad
    xor ebx, ebx
.h: pushad
    mov eax, [pa_t3]
    test ebp, ebp
    jnz .hr
    lea eax, [eax + ebx * 2 + 6]
    jmp .hs
.hr:add eax, 32
    sub eax, ebx
    sub eax, ebx
.hs:mov edx, [pa_t4]
    add edx, 19
    sub edx, ebx
    mov ecx, 2
    lea esi, [ebx * 2 + 2]
    mov ebx, edx
    mov edx, esi
    xor esi, esi
    call pa_box
    popad
    inc ebx
    cmp ebx, 8
    jb .h
    inc ebp
    cmp ebp, 2
    jb .b
    popad
    ret

; Заливка с точки (eax, ebx) цветом pa_col: по строкам, места под задания хватает на любую картинку
pa_flood:
    pushad
    cmp eax, 0
    jl .r
    cmp eax, [pa_w]
    jge .r
    cmp ebx, 0
    jl .r
    cmp ebx, [pa_h]
    jge .r
    mov edx, ebx
    imul edx, [pa_w]
    add edx, eax
    movzx ecx, byte [PA_CANVAS + edx]
    mov [papf_t], ecx
    movzx ecx, byte [pa_col]
    cmp ecx, [papf_t]
    je .r
    mov [pa_cc], cl
    mov esi, PA_STK
    shl ebx, 16
    or ebx, eax
    mov [esi], ebx
    add esi, 4
.pop:
    cmp esi, PA_STK
    jbe .r
    sub esi, 4
    mov eax, [esi]
    movzx ebx, ax
    shr eax, 16
    mov [papf_y], eax
    mov ebp, eax
    imul ebp, [pa_w]
    add ebp, PA_CANVAS
    mov [papf_row], ebp
    mov al, [ebp + ebx]
    cmp al, [papf_t]
    jne .pop
    mov edi, ebx
.lf:test edi, edi
    jz .rt
    mov eax, [papf_row]
    mov dl, [eax + edi - 1]
    cmp dl, [papf_t]
    jne .rt
    dec edi
    jmp .lf
.rt:mov ecx, ebx
    mov edx, [pa_w]
    dec edx
.rl:cmp ecx, edx
    jge .fil
    mov eax, [papf_row]
    mov al, [eax + ecx + 1]
    cmp al, [papf_t]
    jne .fil
    inc ecx
    jmp .rl
.fil:
    mov [papf_l], edi
    mov [papf_r], ecx
    mov edx, ecx
    sub edx, edi
    inc edx
    mov [papf_len], edx
    mov eax, [papf_row]
    add eax, edi
    mov edi, eax
    mov al, [pa_cc]
    mov ecx, edx
    cld
    rep stosb
    mov eax, [papf_l]
    add eax, PA_CX
    mov ebx, [papf_y]
    add ebx, PA_CY
    mov ecx, [papf_len]
    mov edx, 1
    push esi
    movzx esi, byte [pa_cc]
    call pa_box
    pop esi
    mov dword [papf_dy], -1
.nr:mov eax, [papf_y]
    add eax, [papf_dy]
    cmp eax, 0
    jl .nn
    cmp eax, [pa_h]
    jge .nn
    imul eax, [pa_w]
    add eax, PA_CANVAS
    mov ebp, eax
    mov ebx, [papf_l]
    xor edi, edi
.sc:cmp ebx, [papf_r]
    jg .nn
    mov al, [ebp + ebx]
    cmp al, [papf_t]
    jne .out
    test edi, edi
    jnz .nx
    mov edi, 1
    cmp esi, PA_STKEND
    jae .nx
    mov eax, [papf_y]
    add eax, [papf_dy]
    shl eax, 16
    or eax, ebx
    mov [esi], eax
    add esi, 4
    jmp .nx
.out:
    xor edi, edi
.nx:inc ebx
    jmp .sc
.nn:cmp dword [papf_dy], 1
    je .pop
    mov dword [papf_dy], 1
    jmp .nr
.r: popad
    ret

; Палочка текста 2x16 в (pa_tx, pa_ty): переворот цветов, второй вызов стирает
pa_caret:
    pushad
    mov eax, [pa_tx]
    add eax, PA_CX
    mov [r_x], eax
    mov eax, [pa_ty]
    add eax, PA_CY
    mov [r_y], eax
    mov dword [r_w], 2
    mov dword [r_h], 16
    mov dword [r_c], 15
    mov dword [r_fn], 0x18
    call pa_clipfill
    mov dword [r_fn], 0
    popad
    ret

; Закончить ввод текста: убрать палочку
pa_endtext:
    cmp byte [pa_text], 0
    je .r
    call pa_caret
    mov byte [pa_text], 0
.r: ret

; Буква al цветом pa_col в (pa_tx, pa_ty), потом сдвиг вправо
pa_char:
    pushad
    movzx esi, al
    shl esi, 4
    add esi, [0x500]
    mov al, [pa_col]
    mov [pa_cc], al
    xor ebx, ebx
.r: movzx edx, byte [esi + ebx]
    xor ecx, ecx
.c: mov eax, 0x80
    shr eax, cl
    test edx, eax
    jz .n
    push ebx
    push ecx
    push edx
    mov eax, [pa_tx]
    add eax, ecx
    add ebx, [pa_ty]
    call pa_px
    pop edx
    pop ecx
    pop ebx
.n: inc ecx
    cmp ecx, 8
    jb .c
    inc ebx
    cmp ebx, 16
    jb .r
    add dword [pa_tx], 8
    popad
    ret

; Стереть букву слева от палочки: вернуть её клетку из снимка, сделанного перед началом текста
pa_unchar:
    pushad
    movzx eax, byte [pa_un_top]
    dec eax
    jns .a
    mov eax, PA_N - 1
.a: imul eax, PA_SLOT
    add eax, PA_UNDO
    mov [pa_t6], eax
    xor ebx, ebx
.r: xor ecx, ecx
.c: mov eax, [pa_tx]
    add eax, ecx
    mov edx, [pa_ty]
    add edx, ebx
    cmp eax, 0
    jl .n
    cmp eax, [pa_w]
    jge .n
    cmp edx, 0
    jl .n
    cmp edx, [pa_h]
    jge .n
    mov [pa_t7], eax
    mov [pa_t8], edx
    imul edx, [pa_w]
    add edx, eax
    add edx, [pa_t6]
    mov al, [edx]
    mov [pa_cc], al
    push ebx
    push ecx
    mov eax, [pa_t7]
    mov ebx, [pa_t8]
    call pa_px
    pop ecx
    pop ebx
.n: inc ecx
    cmp ecx, 8
    jb .c
    inc ebx
    cmp ebx, 16
    jb .r
    popad
    ret

; Клавиша al при вводе текста
pa_textkey:
    pushad
    cmp al, 13
    je .nl
    cmp al, 8
    je .bs
    cmp al, 32
    jb .r
    CHKHI al, .r
    call pa_caret
    mov ebx, [pa_tx]
    add ebx, 8
    cmp ebx, [pa_w]
    jbe .ok
    mov ebx, [pa_tx0]
    mov [pa_tx], ebx
    add dword [pa_ty], 16
.ok:call pa_char
    call pa_caret
    jmp .r
.nl:call pa_caret
    mov eax, [pa_tx0]
    mov [pa_tx], eax
    add dword [pa_ty], 16
    call pa_caret
    jmp .r
.bs:mov eax, [pa_tx]
    cmp eax, [pa_tx0]
    jbe .r
    call pa_caret
    sub dword [pa_tx], 8
    call pa_unchar
    call pa_caret
.r: popad
    ret

; Какой курсор над холстом: кисть - кисточка (5), заливка - ведро (6), ластик - квадрат (7), остальное - стрелка (0)
pa_ckind:
    xor eax, eax
    cmp byte [pa_tool], 0
    jne .e
    mov al, 5
    ret
.e: cmp byte [pa_tool], 1
    jne .f
    mov al, 7
    ret
.f: cmp byte [pa_tool], 2
    jne .g
    mov al, 6
    ret
.g: cmp byte [pa_tool], 3              ; линия, квадрат и круг: крест
    je .x
    cmp byte [pa_tool], 4
    je .x
    cmp byte [pa_tool], 5
    jne .r
.x: mov al, 10
.r: ret

; Мышь в окне FloPaint: что под ней
paint_hit:
    mov esi, [m_x]
    mov edi, [m_y]
    cmp byte [pa_menu], 0
    je .nm
    cmp esi, 4
    jb .nm
    cmp esi, 340
    ja .nm
    mov eax, edi
    sub eax, 82
    jl .nm
    cmp eax, 180
    jae .nm
    xor edx, edx
    mov ecx, 36
    div ecx
    add eax, 231
    ret
.nm:cmp esi, 4
    jb .t
    cmp esi, 84
    ja .t
    cmp edi, 40
    jb .t
    cmp edi, 76
    ja .t
    mov al, 230
    ret
.t: cmp esi, 96
    jae .cv
    cmp esi, 4
    jb .z
    cmp edi, 272
    jb .gr
    cmp edi, 356
    jae .gr
    cmp esi, 92
    jae .z
    mov al, 208
    ret
.gr:mov eax, esi
    sub eax, 4
    xor edx, edx
    mov ecx, 44
    div ecx
    cmp edx, 40
    jae .z
    cmp eax, 1
    ja .z
    mov [pa_t1], eax
    xor ebx, ebx
.rw:mov eax, ebx
    call pa_ry
    cmp edi, eax
    jb .nx
    add eax, 40
    cmp edi, eax
    jb .fnd
.nx:inc ebx
    cmp ebx, 9
    jb .rw
    jmp .z
.fnd:
    lea eax, [ebx * 2]
    add eax, [pa_t1]
    cmp eax, 7
    je .undo
    cmp eax, 12
    jb .id
    cmp eax, 16
    je .un2
    ja .rd2
    add eax, 201
    ret
.un2:mov al, 225
    ret
.rd2:mov al, 226
    ret
.id:add eax, 200
    ret
.undo:
    xor al, al                          ; кнопки отмены нет: отмена на Ctrl+Z
    ret
.cv:mov eax, esi
    sub eax, PA_CX
    jl .z
    cmp eax, [pa_w]
    jge .z
    mov eax, edi
    sub eax, PA_CY
    jl .z
    cmp eax, [pa_h]
    jge .z
    mov al, 229
    ret
.z: xor al, al
    ret

; Нажали мышь в окне FloPaint: al - что под мышью
paint_press:
    pushad
    cmp byte [pa_menu], 0
    je .nm
    cmp al, 231
    jb .cm
    cmp al, 235
    ja .cm
    jmp .item
.cm:mov byte [pa_menu], 0
    call paint_draw
    jmp .r
.nm:cmp al, 230
    jne .nt
    mov byte [pa_menu], 1
    call paint_draw
    jmp .r
.nt:cmp al, 206
    ja .ns
    cmp al, 200
    jb .r
    call pa_endtext
    sub al, 200
    mov [pa_tool], al
    call pa_tools
    jmp .r
.ns:cmp al, 208
    jb .r
    ja .nu
    call pa_slset
    mov byte [pa_drag], 3
    jmp .r
.nu:cmp al, 225
    jne .n21
    call pa_pop
    jmp .r
.n21:cmp al, 226
    jne .nco
    call pa_redo
    jmp .r
.nco:
    cmp al, 216
    ja .ncv
    movzx eax, al
    mov al, [pa_pal + eax - 213]
    mov [pa_col], al
    call pa_tools
    call pa_palette
    jmp .r
.ncv:
    cmp al, 229
    jne .r
    mov eax, [m_x]
    sub eax, PA_CX
    mov [pa_px0], eax
    mov ebx, [m_y]
    sub ebx, PA_CY
    mov [pa_py0], ebx
    movzx ecx, byte [pa_tool]
    cmp ecx, 6
    je .pip
    cmp ecx, 7
    je .txt
    call pa_endtext
    call pa_push
    cmp ecx, 2
    je .fill
    cmp ecx, 3
    jae .shape
    mov al, [pa_col]
    cmp cl, 1
    jne .b1
    mov al, 15
.b1:mov [pa_cc], al
    movzx edx, byte [pa_size]
    mov [pa_dsz], dl
    mov eax, [pa_px0]
    mov [pa_lx], eax
    mov ebx, [pa_py0]
    mov [pa_ly], ebx
    call pa_dab
    mov byte [pa_drag], 1
    jmp .r
.fill:
    mov eax, [pa_px0]
    mov ebx, [pa_py0]
    call pa_flood
    jmp .r
.shape:
    mov al, [pa_col]
    mov [pa_cc], al
    mov al, [pa_size]
    mov [pa_dsz], al
    mov eax, [pa_px0]
    mov [pa_sx], eax
    mov [pa_ex], eax
    mov eax, [pa_py0]
    mov [pa_sy], eax
    mov [pa_ey], eax
    mov byte [pa_pv], 0
    mov byte [pa_drag], 2
    jmp .r
.pip:
    mov edx, ebx
    imul edx, [pa_w]
    add edx, eax
    mov al, [PA_CANVAS + edx]
    mov [pa_col], al
    call pa_tools
    call pa_palette
    jmp .r
.txt:
    call pa_endtext
    call pa_push
    mov eax, [pa_px0]
    mov [pa_tx], eax
    mov [pa_tx0], eax
    mov eax, [pa_py0]
    mov [pa_ty], eax
    mov byte [pa_text], 1
    call pa_caret
    jmp .r
.item:
    mov byte [pa_menu], 0
    cmp al, 231
    jne .i1
    call paint_new
    call redraw
    jmp .r
.i1:cmp al, 232
    jne .i2
    call redraw
    call paint_save
    jmp .r
.i2:cmp al, 233
    jne .i3
    call redraw
    call paint_saveto
    jmp .r
.i3:cmp al, 234
    jne .i4
    call redraw
    mov al, 2
    call dlg_open_p
    jmp .r
.i4:call paint_exit
.r: popad
    ret

; Мышь двигается с нажатой кнопкой: рисуем дальше
paint_move:
    pushad
    cmp byte [pa_drag], 3
    jne .n3
    call pa_slset
    jmp .r
.n3:    mov eax, [m_x]
    sub eax, PA_CX
    mov ebx, [m_y]
    sub ebx, PA_CY
    cmp byte [pa_drag], 1
    jne .shape
    cmp eax, [pa_lx]
    jne .go
    cmp ebx, [pa_ly]
    je .r
.go:mov dword [pa_pt], pa_dab
    mov ecx, eax
    mov edx, ebx
    mov eax, [pa_lx]
    mov ebx, [pa_ly]
    call pa_line
    mov [pa_lx], ecx
    mov [pa_ly], edx
    jmp .r
.shape:
    cmp eax, [pa_ex]
    jne .s1
    cmp ebx, [pa_ey]
    je .r
.s1:mov [pa_t1], eax
    mov [pa_t2], ebx
    mov dword [pa_pt], pa_xorpt
    cmp byte [pa_pv], 0
    je .np
    call pa_shape
.np:mov eax, [pa_t1]
    mov [pa_ex], eax
    mov eax, [pa_t2]
    mov [pa_ey], eax
    call pa_shape
    mov byte [pa_pv], 1
.r: popad
    ret

; Кнопку отпустили: фигура рисуется по-настоящему
paint_release:
    pushad
    cmp byte [pa_drag], 2
    jne .z
    mov dword [pa_pt], pa_xorpt
    cmp byte [pa_pv], 0
    je .c
    call pa_shape
.c: mov dword [pa_pt], pa_dab
    call pa_shape
.z: mov byte [pa_drag], 0
    popad
    ret

; Клавиша al в окне FloPaint
paint_key:
    pushad
    cmp al, 27
    jne .ne
    cmp byte [pa_menu], 0
    je .e1
    mov byte [pa_menu], 0
    call paint_draw
    jmp .r
.e1:cmp byte [pa_text], 0
    je .e2
    call pa_endtext
    jmp .r
.e2:call paint_exit
    jmp .r
.ne:cmp byte [pa_menu], 0
    jne .r
    cmp al, 26
    jne .n1
    call pa_pop
    jmp .r
.n1:cmp al, 25                          ; Ctrl+Y
    jne .n1y
    call pa_redo
    jmp .r
.n1y:cmp al, 0x13
    jne .n1a
    call paint_save
    jmp .r
.n1a:
    mov ah, 231                         ; Ctrl+N
    cmp al, 0x0E
    je .sc
    mov ah, 233                         ; Ctrl+T
    cmp al, 0x14
    je .sc
    mov ah, 234                         ; Ctrl+O
    cmp al, 0x0F
    je .sc
    mov ah, 235                         ; Ctrl+E
    cmp al, 5
    jne .n2
.sc:mov al, ah
    mov byte [pa_menu], 1
    call paint_press
    jmp .r
.n2:cmp byte [pa_text], 0
    je .r
    call pa_textkey
.r: popad
    ret

; Картинка из холста -> DATA_BUF ("PCF1", ширина, высота, 4 байта запаса, потом по 2 точки в байте), ecx = размер
pa_pack:
    pushad
    mov edi, DATA_BUF
    mov dword [edi], 0x31464350
    mov eax, [pa_w]
    mov [edi + 4], eax
    mov eax, [pa_h]
    mov [edi + 8], eax
    mov dword [edi + 12], 0
    add edi, 16
    mov esi, PA_CANVAS
    mov ecx, [pa_w]
    imul ecx, [pa_h]
    mov edx, ecx
    shr ecx, 1
    jz .odd
.p: mov al, [esi]
    shl al, 4
    or al, [esi + 1]
    mov [edi], al
    add esi, 2
    inc edi
    dec ecx
    jnz .p
.odd:
    test edx, 1
    jz .d
    mov al, [esi]
    shl al, 4
    mov [edi], al
    inc edi
.d: sub edi, DATA_BUF
    mov [pa_psz], edi
    popad
    mov ecx, [pa_psz]
    ret

; Save: в тот же файл, а если файла ещё нет - спросить, куда
paint_save:
    pushad
    cmp byte [pa_has], 0
    je .r
    call pa_endtext
    cmp byte [pa_link], 0
    jne pa_save_link
    cmp byte [pa_dsk], 0xFF
    jne .have
    mov al, 1
    call dlg_open_p
    jmp .r
.have:
    call wait_start
    mov esi, pa_nm
    call mkname_p
    mov al, [pa_dsk]
    call fs_setdisk
    jc .e
    mov al, [pa_par]
    mov [fs_par], al
    call pa_pack
    mov esi, fn_buf
    call file_write
    mov byte [pa_dirty], 0
.e: call wait_end
.r: popad
    ret

; Картинка из FloItge: Save кладёт холст обратно в документ
pa_save_link:
    mov eax, [pa_lplace]
    shl eax, 16
    lea edi, [0xA00000 + eax]
    mov esi, PA_CANVAS
    mov ecx, [pa_w]
    imul ecx, [pa_h]
    cld
    rep movsb
    mov byte [it_mod], 1
    mov byte [pa_dirty], 0
    popad
    ret

; Открыть картинку из FloItge: холст уже лежит в PA_CANVAS, ebx - ширина, ecx - высота, edx - место картинки в документе
paint_open_link:
    pushad
    mov [pa_w], ebx
    mov [pa_h], ecx
    mov [pa_lplace], edx
    mov al, 3
    call z_hide_others
    mov byte [d2_paint], 1
    mov byte [pa_has], 1
    mov byte [pa_link], 1
    mov byte [pa_un_n], 0
    mov byte [pa_re_n], 0
    mov byte [pa_un_top], 0
    mov byte [pa_menu], 0
    mov byte [pa_drag], 0
    mov byte [pa_text], 0
    mov byte [pa_dsk], 0xFF
    mov byte [pa_nm], 0
    mov byte [pa_dirty], 0
    call redraw
    popad
    ret

; Save to: всегда спросить, куда
paint_saveto:
    pushad
    cmp byte [pa_has], 0
    je .r
    call pa_endtext
    mov al, 1
    call dlg_open_p
.r: popad
    ret

; Открыть картинку: al - диск, esi - имя файла с расширением
paint_open_named:
    pushad
    call wait_start
    mov [on_disk], al
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
    cmp eax, 16
    jb .out
    cmp dword [DATA_BUF], 0x31464350
    jne .out
    mov ebx, [DATA_BUF + 4]
    mov ecx, [DATA_BUF + 8]
    cmp ebx, 1
    jb .out
    cmp ebx, PA_W
    ja .out
    cmp ecx, 1
    jb .out
    cmp ecx, PA_H
    ja .out
    mov edx, ebx
    imul edx, ecx
    inc edx
    shr edx, 1
    add edx, 16
    cmp edx, eax
    ja .out
    mov [pa_w], ebx
    mov [pa_h], ecx
    mov esi, DATA_BUF + 16
    mov edi, PA_CANVAS
    mov ecx, ebx
    imul ecx, [pa_h]
    mov edx, ecx
    shr ecx, 1
    jz .uo
.u: mov al, [esi]
    mov ah, al
    shr al, 4
    and ah, 15
    mov [edi], al
    mov [edi + 1], ah
    add edi, 2
    inc esi
    dec ecx
    jnz .u
.uo:test edx, 1
    jz .ud
    mov al, [esi]
    shr al, 4
    mov [edi], al
.ud:mov al, 3
    call z_hide_others
    mov byte [d2_paint], 1
    mov byte [pa_has], 1
    mov byte [pa_link], 0
    mov byte [pa_un_n], 0
    mov byte [pa_re_n], 0
    mov byte [pa_un_top], 0
    mov byte [pa_menu], 0
    mov byte [pa_drag], 0
    mov byte [pa_text], 0
    mov al, [on_disk]
    mov [pa_dsk], al
    mov al, [fs_par]
    mov [pa_par], al
    mov esi, fn_buf
    mov edi, pa_nm
.nm:lodsb
    stosb
    test al, al
    jnz .nm
    mov byte [pa_dirty], 0
.ne:
.out:
    call wait_end
    call redraw
    popad
    ret

; esi - имя файла: CF = оно оканчивается на .pcf
is_pcf:
    push esi
    push ecx
    push eax
    xor ecx, ecx
.l: cmp byte [esi + ecx], 0
    je .e
    inc ecx
    cmp ecx, 15
    jb .l
.e: cmp ecx, 5
    jb .n
    cmp dword [esi + ecx - 4], 0x6663702E
    jne .n
    pop eax
    pop ecx
    pop esi
    stc
    ret
.n: pop eax
    pop ecx
    pop esi
    clc
    ret

; данные FloPaint
pa_has      db 0                        ; есть ли холст
pa_link     db 0                        ; 1 - холст из картинки FloItge
pa_lplace   dd 0                        ; место этой картинки в документе
pa_dsz      db 3
pd_n        dd 0
pd_x        dd 0
pd_y        dd 0
pa_col      db 0
pa_cc       db 0
pa_menu     db 0
pa_pv       db 0
pa_text     db 0
pa_un_n     db 0
pa_re_n     db 0
pa_un_top   db 0
pa_w        dd PA_W
pa_h        dd PA_H
pa_pt       dd 0
pa_px0      dd 0
pa_py0      dd 0
pa_lx       dd 0
pa_ly       dd 0
pa_sx       dd 0
pa_sy       dd 0
pa_ex       dd 0
pa_ey       dd 0
pa_tx       dd 0
pa_ty       dd 0
pa_tx0      dd 0
pa_rx0      dd 0
pa_rc       dd 0
pa_psz      dd 0
pa_t1       dd 0
pa_t2       dd 0
pa_t3       dd 0
pa_t4       dd 0
pa_t5       dd 0
pa_t6       dd 0
pa_t7       dd 0
pa_t8       dd 0
paln_x        dd 0
paln_y        dd 0
paln_x1       dd 0
paln_y1       dd 0
paln_dx       dd 0
paln_dy       dd 0
paln_sx       dd 0
paln_sy       dd 0
paln_er       dd 0
pacr_x        dd 0
pacr_y        dd 0
pacr_d        dd 0
papf_t        dd 0
papf_y        dd 0
papf_row      dd 0
papf_l        dd 0
papf_r        dd 0
papf_len      dd 0
papf_dy       dd 0
pa_ttl      times 24 db 0
pa_pal      db 0, 1, 8, 15                      ; чёрный, синий, серый, белый
pa_dn       db 1, 3, 5, 9
pa_dt       dd pa_d1, pa_d3, pa_d5, pa_d9
pa_d1       db 1
pa_d3       db 1, 3, 1
pa_d5       db 3, 5, 5, 5, 3
pa_d9       db 5, 7, 9, 9, 9, 9, 9, 7, 5
pa_icsz     db 4, 8, 14, 22
s_pa_none   db 0
pa_iw       dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
pa_ic       dd 0x00000000, 0x00000000, 0x000000F0, 0x000000F0, 0x0000030C, 0x0000030C, 0x00000C0C, 0x00000C0C
            dd 0x00003030, 0x00003030, 0x0000C0C0, 0x0000C0C0, 0x00030300, 0x00030300, 0x000C0C00, 0x000C0C00
            dd 0x00F03000, 0x00F03000, 0x003CC000, 0x003CC000, 0x000F0000, 0x000F0000, 0x00030000, 0x00030000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x3FFFFFFC, 0x3FFFFFFC
            dd 0x3001800C, 0x3001800C, 0x3001800C, 0x3001800C, 0x3001800C, 0x3001800C, 0x3001800C, 0x3001800C
            dd 0x3001800C, 0x3001800C, 0x3001800C, 0x3001800C, 0x3001800C, 0x3001800C, 0x3001800C, 0x3001800C
            dd 0x3FFFFFFC, 0x3FFFFFFC, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00FFFF00, 0x00FFFF00, 0x03C003C0, 0x03C003C0, 0x030000C0, 0x030000C0
            dd 0x3FFFFFFC, 0x3FFFFFFC, 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C
            dd 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C, 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030
            dd 0x030000C0, 0x030000C0, 0x01FFFF80, 0x01FFFF80, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x0000003C, 0x0000003C, 0x000000FC, 0x000000FC, 0x000003F0, 0x000003F0
            dd 0x00000FC0, 0x00000FC0, 0x00003F00, 0x00003F00, 0x0000FC00, 0x0000FC00, 0x0003F000, 0x0003F000
            dd 0x000FC000, 0x000FC000, 0x003F0000, 0x003F0000, 0x00FC0000, 0x00FC0000, 0x03F00000, 0x03F00000
            dd 0x0FC00000, 0x0FC00000, 0x3F000000, 0x3F000000, 0x3C000000, 0x3C000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0FFFFFF0, 0x0FFFFFF0, 0x0C000030, 0x0C000030
            dd 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030
            dd 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030, 0x0C000030
            dd 0x0FFFFFF0, 0x0FFFFFF0, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x003FFC00, 0x003FFC00, 0x03C003C0, 0x03C003C0, 0x0C000030, 0x0C000030
            dd 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C
            dd 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C, 0x3C00003C, 0x3C00003C, 0x0F0000F0, 0x0F0000F0
            dd 0x03C003C0, 0x03C003C0, 0x003FFC00, 0x003FFC00, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x000000C0, 0x000000C0, 0x000003F0, 0x000003F0, 0x00000FFC, 0x00000FFC
            dd 0x000033F0, 0x000033F0, 0x0000C0C0, 0x0000C0C0, 0x00030300, 0x00030300, 0x000C0C00, 0x000C0C00
            dd 0x00303000, 0x00303000, 0x00C0C000, 0x00C0C000, 0x03030000, 0x03030000, 0x0C0C0000, 0x0C0C0000
            dd 0x0C300000, 0x0C300000, 0x0FC00000, 0x0FC00000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
pa_ib       dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x03C00000, 0x03C00000, 0x0FF00000, 0x0FF00000, 0x0FFC0000, 0x0FFC0000
            dd 0x0FFC0000, 0x0FFC0000, 0x0FF00000, 0x0FF00000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00007FF0, 0x00007FF0, 0x00007FF0, 0x00007FF0, 0x00007FF0, 0x00007FF0, 0x00007FF0, 0x00007FF0
            dd 0x00007FF0, 0x00007FF0, 0x00007FF0, 0x00007FF0, 0x00007FF0, 0x00007FF0, 0x00007FF0, 0x00007FF0
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x0FFFFFF0, 0x0FFFFFF0, 0x0FFFFFF0, 0x0FFFFFF0, 0x0FFFFFF0, 0x0FFFFFF0
            dd 0x0FFFFFF0, 0x0FFFFFF0, 0x0FFFFFF0, 0x0FFFFFF0, 0x03FFFFC0, 0x03FFFFC0, 0x03FFFFC0, 0x03FFFFC0
            dd 0x00FFFF00, 0x00FFFF00, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00030000, 0x00030000
            dd 0x000FC000, 0x000FC000, 0x003F0000, 0x003F0000, 0x00FC0000, 0x00FC0000, 0x03F00000, 0x03F00000
            dd 0x03C00000, 0x03C00000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
pa_lbl      db "B", 0, "E", 0, "F", 0, "L", 0, "R", 0, "C", 0, "P", 0, "T", 0, "1", 0, "3", 0, "5", 0, "9", 0
s_paint     db "FloPaint", 0
s_pa_new    db "New", 0
s_pa_undo   db "Undo", 0

s_k_s   db "Ctrl + S", 0
s_k_ss  db "Ctrl + T", 0
s_k_o   db "Ctrl + O", 0
s_k_n   db "Ctrl + N", 0
s_k_e   db "Ctrl + E", 0
s_k_p   db "Ctrl + P", 0
