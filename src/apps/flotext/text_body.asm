; FloText - текстовый редактор, файлы текста, курсор-палочка
; Подключается из kernel32.asm (%include)

; FloText: текстовый редактор
TX_ROWS equ 100                         ; всего строк (видно 16, остальное прокручивается)
TX_N    equ 49 * TX_ROWS
TX_SAVED equ 0x1B0000                 ; last successfully saved/opened FloText document (4900 bytes)

text_open:
    cmp byte [d2_text], 0
    jne .r
    mov al, 2
    call z_hide_others
    call splash_start
    call text_blank                     ; каждый новый запуск - пустой текст
    mov byte [d2_text], 1
    mov byte [t_menu], 0
    call wait_end
    jmp redraw
.r: ret

text_blank:
    pushad
    mov edi, t2_buf
    mov ecx, TX_N
    xor eax, eax
    rep stosb
    mov byte [t2_dsk], 0xFF
    mov dword [t2_fs3parent], 0
    mov byte [t2_nm], 0
    mov byte [t2_row], 0
    mov byte [t2_col], 0
    mov byte [t2_top], 0
    mov dword [t2_anc], -1
    mov byte [sel_drag], 0
    call text_snapshot
    popad
    ret

; Snapshot only after a successful load/write. No per-key dirty tracking needed.
text_snapshot:
    pushad
    mov esi, t2_buf
    mov edi, TX_SAVED
    mov ecx, TX_N / 4
    cld
    rep movsd
    popad
    ret

; CF=1 iff current document differs from the last successfully saved/opened version.
text_changed:
    pushad
    mov esi, t2_buf
    mov edi, TX_SAVED
    mov ecx, TX_N / 4
    cld
    repe cmpsd
    popad
    jne .dirty
    clc
    ret
.dirty:
    stc
    ret

; All ordinary close paths must go through text_exit.
text_exit:
    call text_changed
    jnc text_close
    mov al, 4                          ; Save changes? -> FloText
    jmp sv_ask

text_close:
    mov byte [d2_text], 0
    mov byte [t_menu], 0
    mov byte [sel_drag], 0
    mov al, 2
    call z_restore
    jmp redraw

text_draw:
    pushad
    RECT 0, 0, 800, 600, C_WHITE
    RECT 0, 38, 800, 2, C_BLACK
    call make_title
    mov esi, s_ftx                      ; по центру - название программы
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
    mov esi, t2_title
    call draw_big
    RECT 0, 78, 800, 2, C_BLACK
    cmp byte [t_menu], 0
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
    movzx ebx, byte [t2_top]
    imul ebx, 49
    lea edi, [ebx + 16 * 49]
.c: call tx_cell
    inc ebx
    cmp ebx, edi
    jb .c
    call tx_bar
    cmp byte [t_menu], 0
    jne .menu
    call tx_caret_on
    jmp .e
.menu:
    RECT 8, 82, 336, 152, C_BLACK
    RECT 4, 78, 336, 152, C_BLACK
    RECT 6, 80, 332, 148, C_WHITE
    mov dword [r_c], C_BLACK
    mov dword [t_x], 12
    mov dword [t_y], 82
    mov esi, s_m_save
    call draw_big
    mov dword [t_x], 196
    mov esi, s_k_s
    call draw_big
    mov dword [t_x], 12
    mov dword [t_y], 118
    mov esi, s_m_saveto
    call draw_big
    mov dword [t_x], 196
    mov esi, s_k_ss
    call draw_big
    mov dword [t_x], 12
    mov dword [t_y], 154
    mov esi, s_m_open
    call draw_big
    mov dword [t_x], 196
    mov esi, s_k_o
    call draw_big
    mov dword [t_x], 12
    mov dword [t_y], 190
    mov esi, s_exit
    call draw_big
    mov dword [t_x], 196
    mov esi, s_k_e
    call draw_big
    mov dword [t_x], 12
.e: call mn_pdraw
    popad
    ret

; Клетка ebx: белый фон и буква (выделенное - наоборот)
tx_cell:
    pushad
    mov eax, ebx
    xor edx, edx
    mov ecx, 49
    div ecx
    movzx ecx, byte [t2_top]
    sub eax, ecx
    jb .r
    cmp eax, 16
    jae .r
    shl edx, 4
    shl eax, 5
    add eax, 86
    mov [r_x], edx
    mov [t_x], edx
    mov [r_y], eax
    mov [t_y], eax
    mov dword [r_w], 16
    mov dword [r_h], 32
    mov ecx, C_WHITE
    mov edx, C_BLACK
    cmp ebx, [sel_lo]
    jb .ns
    cmp ebx, [sel_hi]
    jae .ns
    mov ecx, C_BLACK
    mov edx, C_WHITE
.ns:mov [r_c], ecx
    push edx
    call fill_rect
    pop edx
    movzx eax, byte [t2_buf + ebx]
    test al, al
    jz .r
    mov [t2_tmp], al
    mov [r_c], edx
    mov esi, t2_tmp
    call draw_big
.r: popad
    ret

; eax = клетка под мышью (с поправкой на края и на конец текста)
tx_mcell:
    mov eax, [m_x]
    or eax, eax
    jge .c1
    xor eax, eax
.c1:shr eax, 4
    cmp eax, 48
    jbe .c2
    mov eax, 48
.c2:mov ecx, eax
    mov eax, [m_y]
    sub eax, 86
    jge .r1
    xor eax, eax
.r1:shr eax, 5
    cmp eax, 15
    jbe .r2
    mov eax, 15
.r2:movzx edx, byte [t2_top]
    add eax, edx
    imul eax, 49
    add eax, ecx

; eax = клетка; палочка не может стоять в пустоте
tx_clamp:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    xor edx, edx
    mov ebx, 49
    div ebx
    mov edi, eax
    mov esi, edx
    mov bl, TX_ROWS - 1
.lr:push ebx
    call tx_rowlen
    pop ebx
    test ecx, ecx
    jnz .lf
    dec bl
    jns .lr
    xor bl, bl
.lf:movzx ebx, bl
    cmp edi, ebx
    jbe .a
    mov edi, ebx
    mov esi, 49
.a: mov ebx, edi
    call tx_rowlen
    cmp esi, ecx
    jbe .b
    mov esi, ecx
.b: mov eax, edi
    imul eax, 49
    add eax, esi
    cmp eax, TX_N - 1
    jbe .c
    mov eax, TX_N - 1
.c: pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; bl = строка -> ecx = сколько в ней букв (до последней непустой клетки)
tx_rowlen:
    movzx ebx, bl
    imul ebx, 49
    add ebx, 48
    mov ecx, 49
.l: cmp byte [t2_buf + ebx], 0
    jne .r
    dec ebx
    loop .l
.r: ret

; убрать клетку под палочкой, остаток строки сдвигается влево
tx_delcell:
    pushad
    movzx ebx, byte [t2_row]
    imul ebx, 49
    movzx edx, byte [t2_col]
    lea esi, [ebx + edx + 1]
    mov ecx, 48
    sub ecx, edx
    jle .z
.l: mov al, [t2_buf + esi]
    mov [t2_buf + esi - 1], al
    inc esi
    loop .l
.z: mov byte [t2_buf + ebx + 48], 0
    lea eax, [ebx + edx]
    lea edx, [ebx + 49]
    call tx_cells
    popad
    ret

; номер клетки eax -> t2_row, t2_col
tx_setcaret:
    xor edx, edx
    mov ebx, 49
    div ebx
    mov [t2_row], al
    mov [t2_col], dl
    ret

tx_cursor_idx:
    movzx eax, byte [t2_row]
    imul eax, 49
    movzx ebx, byte [t2_col]
    add eax, ebx
    ret

; границы выделения sel_lo..sel_hi
tx_sel_calc:
    push eax
    push ebx
    call tx_cursor_idx
    mov ebx, [t2_anc]
    mov dword [sel_lo], 0
    mov dword [sel_hi], 0
    cmp ebx, -1
    je .r
    cmp eax, ebx
    je .r
    jb .a
    xchg eax, ebx
.a: mov [sel_lo], eax
    mov [sel_hi], ebx
.r: pop ebx
    pop eax
    ret

; перерисовать клетки eax .. edx - 1
tx_cells:
    pushad
    mov ebp, eax
    mov esi, edx
.l: cmp ebp, esi
    jae .r
    cmp ebp, TX_N
    jae .r
    mov ebx, ebp
    call tx_cell
    inc ebp
    jmp .l
.r: call mn_over                        ; клетки внизу справа могли закрыть кнопки EN и стрелку
    popad
    ret

; мышь сдвинули при зажатой кнопке: выделение тянется за ней
tx_sel_move:
    pushad
    call tx_mcell
    mov edi, eax
    call tx_cursor_idx
    cmp eax, edi
    je .r
    mov esi, eax
    mov eax, edi
    call tx_setcaret
    call tx_sel_calc
    mov eax, esi
    mov edx, edi
    cmp eax, edx
    jbe .o
    xchg eax, edx
.o: inc edx
    call tx_cells
    call tx_caret_on
.r: popad
    ret

; Нажали мышью в тексте: палочка встаёт в клетку, дальше можно тянуть выделение
tx_click:
    pushad
    cmp byte [t_menu], 0
    je .a
    mov byte [t_menu], 0
    call text_draw
    jmp .r
.a: mov esi, [sel_lo]
    mov edi, [sel_hi]
    call tx_caret_off
    call tx_mcell
    push eax
    call tx_setcaret
    pop eax
    mov [t2_anc], eax
    call tx_sel_calc
    mov eax, esi
    mov edx, edi
    call tx_cells
    mov byte [sel_drag], 1
    call tx_caret_on
.r: popad
    ret

; Тонкая палочка в позиции t2_col, t2_row
tx_caret_on:
    pushad
    mov eax, [sel_lo]
    cmp eax, [sel_hi]
    jne .x
    movzx eax, byte [t2_col]
    shl eax, 4
    mov [r_x], eax
    movzx eax, byte [t2_row]
    movzx ebx, byte [t2_top]
    sub eax, ebx
    jb .x
    cmp eax, 16
    jae .x
    shl eax, 5
    add eax, 86
    mov [r_y], eax
    mov dword [r_w], 2
    mov dword [r_h], 32
    mov dword [r_c], C_BLACK
    call fill_rect
.x: popad
    ret

tx_caret_off:
    pushad
    call tx_cursor_idx
    mov ebx, eax
    call tx_cell
    popad
    ret

; Что под мышью в Text: 4 File, 5 Exit, 6 текст, 10..12 Save / Save to / Open
text_hit:
    mov esi, [m_x]
    mov edi, [m_y]
    cmp byte [t_menu], 0
    je .nm
    cmp esi, 4
    jb .nm
    cmp esi, 340
    ja .nm
    mov eax, edi
    sub eax, 82
    jl .nm
    cmp eax, 144
    jae .nm
    xor edx, edx
    mov ecx, 36
    div ecx
    mov ecx, 10
    cmp eax, 3
    jne .m1
    mov al, 5
    ret
.m1:add eax, ecx
    ret
.nm:cmp esi, 4
    jb .t
    cmp esi, 84
    ja .t
    cmp edi, 40
    jb .t
    cmp edi, 76
    ja .t
    mov al, 4
    ret
.t: cmp edi, 82
    jb .z
    cmp esi, 780
    jb .t6
    push eax
    call tx_total
    cmp eax, 16
    pop eax
    jbe .t6
    mov al, 98
    ret
.t6:mov al, 6
    ret
.z: xor al, al
    ret

; Клавиша в окне Text (al - символ)
text_key:
    pushad
    cmp al, 27                          ; Esc: закрыть меню, а если его нет - окно
    jne .ne
    cmp byte [t_menu], 0
    je .cl
    mov byte [t_menu], 0
    call text_draw
    jmp .r
.cl:call text_exit
    jmp .r
.ne:cmp byte [t_menu], 0
    jne .r
    cmp al, 0x13                        ; Ctrl+S
    jne .nos
    call text_save
    jmp .r
.nos:
    cmp al, 0x14                        ; Ctrl+T
    jne .nsa
    mov al, 1
    call dlg_open
    jmp .r
.nsa:
    cmp al, 0x0F                        ; Ctrl+O
    jne .noo
    mov al, 2
    call dlg_open
    jmp .r
.noo:
    cmp al, 5                           ; Ctrl+E
    jne .noe
    call text_exit
    jmp .r
.noe:
    cmp al, 3
    je .copy
    cmp al, 0x18
    je .cut
    cmp al, 0x16
    je .paste
    cmp al, 1
    je .all
    cmp al, 13
    je .typ
    cmp al, 8
    je .typ
    cmp al, 32
    jb .r
    CHKHI al, .r
.typ:
    mov edx, [sel_lo]
    cmp edx, [sel_hi]
    je .nosel
    push eax
    call tx_sel_del                     ; выделенное заменяется тем, что печатаем
    pop eax
    cmp al, 8
    je .show
.nosel:
    cmp al, 13
    je .enter
    cmp al, 8
    je .bs
    movzx ebx, byte [t2_row]            ; буква вставляется там, где палка, остальное сдвигается
    imul ebx, 49
    movzx edx, byte [t2_col]
    cmp edx, 48
    jae .put
    cmp byte [t2_buf + ebx + 48], 0
    jne .r                              ; строка полная - вставить нельзя
    lea esi, [ebx + 47]
    mov ecx, 48
    sub ecx, edx
.sh:mov ah, [t2_buf + esi]
    mov [t2_buf + esi + 1], ah
    dec esi
    loop .sh
.put:
    lea esi, [ebx + edx]
    mov [t2_buf + esi], al
    mov eax, esi
    lea edx, [ebx + 49]
    call tx_cells
    cmp byte [t2_col], 48
    jb .right
    cmp byte [t2_row], TX_ROWS - 1
    jae .show
    mov byte [t2_col], 0
    inc byte [t2_row]
    jmp .show
.right:
    inc byte [t2_col]
    jmp .show
.enter:                                 ; Enter: всё, что правее палки, уходит на новую строку
    cmp byte [t2_row], TX_ROWS - 1
    jae .show
    mov bl, TX_ROWS - 1
    call tx_rowlen
    test ecx, ecx
    jnz .r                              ; места под новую строку нет
    call tx_caret_off
    movzx ebx, byte [t2_row]
    mov eax, TX_ROWS - 2
    sub eax, ebx
    imul eax, 49
    mov ecx, eax
    jecxz .e1
    mov esi, t2_buf + (TX_ROWS - 1) * 49 - 1
    mov edi, t2_buf + TX_ROWS * 49 - 1
.m: mov al, [esi]
    mov [edi], al
    dec esi
    dec edi
    loop .m
.e1:mov eax, ebx
    inc eax
    imul eax, 49
    lea edi, [t2_buf + eax]
    mov ecx, 49
    xor al, al
    rep stosb
    movzx edx, byte [t2_col]
    mov eax, ebx
    imul eax, 49
    lea esi, [t2_buf + eax + edx]
    mov eax, ebx
    inc eax
    imul eax, 49
    lea edi, [t2_buf + eax]
    mov ecx, 49
    sub ecx, edx
    mov ebp, esi
    rep movsb
    mov edi, ebp
    mov ecx, 49
    sub ecx, edx
    xor al, al
    rep stosb
    mov eax, ebx
    imul eax, 49
    add eax, edx
    mov edx, TX_N
    call tx_cells
    mov byte [t2_col], 0
    inc byte [t2_row]
    jmp .show
.bs:
    cmp byte [t2_col], 0
    jne .bs1
    cmp byte [t2_row], 0
    je .show
    call tx_caret_off                   ; в начале строки: строка приклеивается к предыдущей
    mov bl, [t2_row]
    dec bl
    call tx_rowlen
    push ecx
    mov bl, [t2_row]
    call tx_rowlen
    mov edx, ecx
    pop ecx
    movzx ebx, byte [t2_row]
    dec ebx
    mov [t2_row], bl
    mov eax, ecx
    cmp eax, 48
    jbe .c1
    mov eax, 48
.c1:mov [t2_col], al
    mov eax, ecx
    add eax, edx
    cmp eax, 49
    ja .show
    mov eax, ebx
    imul eax, 49
    lea edi, [t2_buf + eax + ecx]
    lea esi, [t2_buf + eax + 49]
    mov ecx, edx
    rep movsb
    mov eax, ebx
    inc eax
    imul eax, 49
    lea edi, [t2_buf + eax]
    lea esi, [edi + 49]
    mov eax, TX_ROWS - 2
    sub eax, ebx
    imul eax, 49
    mov ecx, eax
    rep movsb
    mov edi, t2_buf + (TX_ROWS - 1) * 49
    mov ecx, 49
    xor al, al
    rep stosb
    mov eax, ebx
    imul eax, 49
    mov edx, TX_N
    call tx_cells
    jmp .show
.bs1:
    dec byte [t2_col]
    call tx_delcell
.show:
    mov dword [t2_anc], -1
    call tx_ensure
    call tx_caret_on
    call tx_bar
.r: popad
    ret
.copy:
    call tx_sel_copy
    jmp .r
.cut:
    mov edx, [sel_lo]
    cmp edx, [sel_hi]
    je .r
    call tx_sel_copy
    call tx_sel_del
    jmp .show
.paste:
    mov ecx, [clip_len]
    jecxz .r
    mov edx, [sel_lo]
    cmp edx, [sel_hi]
    je .p1
    call tx_sel_del
.p1:
    call tx_cursor_idx
    mov esi, eax
    mov ebx, eax
    mov edi, clip_buf
.pl:cmp ebx, TX_N
    jae .pd
    mov al, [edi]
    mov [t2_buf + ebx], al
    inc edi
    inc ebx
    loop .pl
.pd:mov eax, esi
    mov edx, ebx
    call tx_cells
    mov eax, ebx
    cmp eax, TX_N - 1
    jbe .p2
    mov eax, TX_N - 1
.p2:call tx_setcaret
    jmp .show
.all:
    mov dword [t2_anc], 0
    mov eax, TX_N - 1
    call tx_clamp
    push eax
    call tx_setcaret
    call tx_sel_calc
    pop edx
    inc edx
    xor eax, eax
    call tx_cells
    jmp .r

; удалить выделенное
tx_sel_del:
    pushad
    mov esi, [sel_lo]
    mov edi, [sel_hi]
    mov ebx, esi
.z: cmp ebx, edi
    jae .d
    mov byte [t2_buf + ebx], 0
    inc ebx
    jmp .z
.d: mov eax, esi
    call tx_setcaret
    mov dword [t2_anc], -1
    call tx_sel_calc
    mov eax, esi
    mov edx, edi
    call tx_cells
    popad
    ret

; скопировать выделенное в буфер обмена
tx_sel_copy:
    pushad
    mov esi, [sel_lo]
    mov ecx, [sel_hi]
    sub ecx, esi
    jbe .r
    mov [clip_len], ecx
    mov edi, clip_buf
.l: mov al, [t2_buf + esi]
    mov [edi], al
    inc esi
    inc edi
    loop .l
.r: popad
    ret



; Сколько строк занято (не меньше 16 и не меньше строки с палочкой) -> eax
tx_total:
    push ebx
    push ecx
    push edx
    mov ecx, TX_N
.l: cmp byte [t2_buf + ecx - 1], 0
    jne .f
    loop .l
.f: lea eax, [ecx + 48]
    xor edx, edx
    mov ebx, 49
    div ebx
    movzx ecx, byte [t2_top]
    add ecx, 16
    cmp eax, ecx
    jae .a
    mov eax, ecx
.a: cmp eax, 16
    jae .b
    mov eax, 16
.b: pop edx
    pop ecx
    pop ebx
    ret

; Полоса справа (как у main), если текст не помещается
tx_bar:
    pushad
    call tx_total
    cmp eax, 16
    ja .on
    RECT 780, 86, 20, 512, C_WHITE
    popad
    ret
.on:shl eax, 5
    mov edi, eax
    movzx ebp, byte [t2_top]
    shl ebp, 5
    mov eax, 780
    mov ebx, 86
    mov ecx, 512
    xor edx, edx
    mov esi, 512
    mov dword [sb_w], 20
    call sbar
    mov dword [sb_w], 16
    popad
    ret

; Палочка ушла за край - окно прокручивается к ней
tx_ensure:
    push eax
    push ebx
    movzx eax, byte [t2_row]
    movzx ebx, byte [t2_top]
    cmp eax, ebx
    jae .a
    mov [t2_top], al
    jmp .d
.a: sub eax, 15
    jb .ok
    cmp eax, ebx
    jbe .ok
    mov [t2_top], al
.d: call text_draw
.ok:pop ebx
    pop eax
    ret



; Текст из клеток -> DATA_BUF, ecx = размер
text_pack:
    pushad
    mov edi, DATA_BUF
    mov byte [pk_last], 0xFF
    xor ebx, ebx
.fr:xor edx, edx
.fc:mov eax, ebx
    imul eax, 49
    add eax, edx
    cmp byte [t2_buf + eax], 0
    je .fn
    mov [pk_last], bl
.fn:inc edx
    cmp edx, 49
    jb .fc
    inc ebx
    cmp ebx, TX_ROWS
    jb .fr
    cmp byte [pk_last], 0xFF
    je .done
    xor ebx, ebx
.row:
    mov edx, -1
    xor ecx, ecx
.sc:mov eax, ebx
    imul eax, 49
    add eax, ecx
    cmp byte [t2_buf + eax], 0
    je .sn
    mov edx, ecx
.sn:inc ecx
    cmp ecx, 49
    jb .sc
    xor ecx, ecx
.wr:cmp edx, -1
    je .eol
    cmp ecx, edx
    jg .eol
    mov eax, ebx
    imul eax, 49
    add eax, ecx
    mov al, [t2_buf + eax]
    test al, al
    jnz .w1
    mov al, ' '
.w1:stosb
    inc ecx
    jmp .wr
.eol:
    cmp bl, [pk_last]
    jae .nol
    mov byte [edi], 13
    mov byte [edi + 1], 10
    add edi, 2
.nol:
    inc ebx
    cmp bl, [pk_last]
    jbe .row
.done:
    sub edi, DATA_BUF
    mov [pk_size], edi
    popad
    mov ecx, [pk_size]
    ret

; DATA_BUF, [f_size] байт -> клетки текста
text_unpack:
    pushad
    mov dword [t2_anc], -1
    mov byte [t2_top], 0
    mov dword [sel_lo], 0
    mov dword [sel_hi], 0
    mov edi, t2_buf
    mov ecx, TX_N
    xor al, al
    rep stosb
    mov ecx, [f_size]
    test ecx, ecx
    jz .end
    cmp ecx, 6000
    jbe .ok
    mov ecx, 6000
.ok:mov esi, DATA_BUF
    xor ebx, ebx
    xor edx, edx
.l: mov al, [esi]
    inc esi
    cmp al, 13
    je .nx
    cmp al, 10
    jne .ch
    inc ebx
    xor edx, edx
    cmp ebx, TX_ROWS
    jae .end
    jmp .nx
.ch:cmp al, 32
    jb .nx
    CHKHI al, .nx
    cmp edx, 49
    jb .st
    xor edx, edx
    inc ebx
    cmp ebx, TX_ROWS
    jae .end
.st:mov edi, ebx
    imul edi, 49
    add edi, edx
    mov [t2_buf + edi], al
    inc edx
.nx:dec ecx
    jnz .l
.end:
    popad
    ret

; Открыть файл esi (имя с .txt) на диске al в окне Text
text_open_named:
    pushad
    ; AL carries the selected disk. Do not overwrite it while reading
    ; the 16-bit FSM3 parent folder: nested folder IDs are not disk IDs.
    push eax
    mov eax, [fs3_folder_id]
    mov [t2_fs3parent], eax
    pop eax
    call splash_start
    mov [on_disk], al
    mov edi, fn_buf
.c: lodsb
    stosb
    test al, al
    jnz .c
    mov al, [on_disk]
    call fs_setdisk
    jnc .mounted
    ; FSM3 is deliberately not mounted writable by fs_setdisk.
    cmp byte [lst_st], 3
    jne .fail
.mounted:
    mov esi, fn_buf
    call file_read
    jc .fail
    call egg_test                       ; файл .sec с текстом secret floppy - пасхалка
    jc .fail
    call text_unpack
    call text_snapshot
    mov al, [on_disk]
    cmp byte [lst_st], 3
    jne .writable
    ; FSM3 Save is handled by a separate bounded copy-on-write writer.
    ; FloFile itself remains read-only for FSM3 operations.
.writable:
    mov [t2_dsk], al
    mov al, [fs_par]
    mov [t2_par], al
    mov esi, fn_buf
    mov edi, t2_nm
.n: lodsb
    stosb
    test al, al
    jnz .n
.e:
    mov byte [t2_col], 0
    mov byte [t2_row], 0
    mov al, 2
    call z_hide_others
    mov byte [d2_text], 1
    mov byte [t_menu], 0
.fail:
    call wait_end
    call redraw
    popad
    ret

; Save: в тот же файл; если файла ещё нет - спросить, куда (диалог)
text_save:
    pushad
    cmp byte [t2_dsk], 0xFF
    jne .have
    mov al, 1
    call dlg_open
    jmp .r
.have:
    call wait_start
    mov esi, t2_nm
    call mkname
    mov al, [t2_dsk]
    call fs_setdisk
    jnc .selected
    ; A known FSM3 volume is reported via lst_st, not CF=0.
    cmp byte [lst_st], 3
    jne .r
.selected:
    mov al, [t2_par]
    mov [fs_par], al
    mov eax, [t2_fs3parent]
    mov [fs3_folder_id], eax
    call text_pack
    mov esi, fn_buf
    call file_write
    jc .r
    call text_snapshot
.r: call wait_end
    popad
    ret
s_ftx       db "FloText", 0

s_k_s   db "Ctrl + S", 0
s_k_ss  db "Ctrl + T", 0
s_k_o   db "Ctrl + O", 0
s_k_n   db "Ctrl + N", 0
s_k_e   db "Ctrl + E", 0
s_k_p   db "Ctrl + P", 0

; Parent folder for a file opened from an FSM3 subdirectory (not t2_par).
t2_fs3parent dd 0
