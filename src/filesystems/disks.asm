; Окно Disks (File -> Disks в FloFile): создать и удалить виртуальный диск
; Подключается из kernel32.asm (%include)
; Окно можно таскать за заголовок (d_ctx = 4), его высота зависит от числа дисков

; окно Disks (File -> Disks в FloFile)
DK_W        equ 544                     ; ширина окна

dk_open:
    call wait_start
    mov byte [d2_dk], 1
    mov byte [dk_sel], 0xFF
    mov byte [dk_len], 0
    mov byte [dk_name], 0
    mov byte [dk_car], 0
    mov byte [dk_anc], 0xFF
    mov byte [dk_msg], 0
    mov byte [dk_menu], 0
    mov byte [dk_confirm], 0
    mov byte [dk_conf_top], 0
    ; 360 KB is the old default (second preset size).
    mov byte [dk_focus], 0
    mov byte [dk_size_car], 3          ; initial caret at end of "360"
    mov byte [dk_size_anc], 0xFF       ; no selection in Size
    mov byte [dk_unit], 0                 ; 0 = KB, 1 = MB
    mov byte [dk_size_len], 3
    mov dword [dk_size_text], 0x00303633 ; ASCII "360", null
    mov word [dk_size_text + 4], 0     ; erase any old 5-digit value on reopen
    mov dword [dk_w], DK_W
    mov dword [dk_h], 320               ; начальная высота, потом под список
    mov dword [dk_hmin], 0
    mov byte [dk_scroll], 0
    call dk_scan
    mov eax, [dk_rows]                  ; при открытии показать все диски, если они помещаются
    shl eax, 5
    add eax, 288
    cmp eax, 576
    jbe .initial_height
    mov eax, 576
.initial_height:
    mov [dk_h], eax
    call dk_layout
    mov eax, 800                        ; окно по центру экрана
    sub eax, [dk_w]
    shr eax, 1
    and eax, -8
    mov [dk_x], eax
    mov eax, 600
    sub eax, [dk_h]
    shr eax, 1
    and eax, -2
    mov [dk_y], eax
    mov dl, 5
    call fz_top
    call wait_end
    jmp redraw

dk_exit:
dk_close:
    mov byte [dk_menu], 0
    mov byte [dk_confirm], 0
    mov byte [dk_conf_top], 0
    mov byte [d2_dk], 0
    call fs_pc_scan
    jmp redraw

; Размеры дисков из dtab -> dk_sz (в секторах, 0 - диска нет); заодно считаем, сколько строк в списке
dk_scan:
    pushad
    mov dword [dk_rows], 1
    xor ebx, ebx
.l: imul esi, ebx, DT_ESZ
    add esi, dtab
    xor eax, eax
    cmp byte [esi], 0
    je .s
    lea ecx, [ebx + 1]
    mov [dk_rows], ecx
    mov eax, [esi + 6]
    test eax, eax
    jnz .s
    movzx edx, byte [esi + 1]
    mov eax, [dk_total + edx * 4]
.s: mov [dk_sz + ebx * 4], eax
    inc ebx
    cmp ebx, DT_N
    jb .l
    call dk_layout
    popad
    ret

; Где что стоит в окне (y внутри окна) и какая высота: зависит от числа строк в списке
dk_layout:
    ; Floppy_143: размер окна задаёт пользователь. Список дисков занимает
    ; только доступную область, невидимые строки доступны кнопками < и >.
    mov eax, [dk_h]
    mov ecx, 168                      ; обычные кнопки в один ряд
    cmp dword [dk_w], DK_W
    jae .wide
    mov ecx, 216                      ; узкое окно: команды в два ряда
.wide:
    mov edx, eax
    sub edx, ecx
    mov [dk_ny], edx
    add edx, 44
    mov [dk_sy], edx
    add edx, 44
    mov [dk_my], edx
    mov eax, [dk_h]
    sub eax, 48
    mov [dk_by], eax
    sub eax, 48
    mov [dk_by2], eax
    mov eax, [dk_ny]
    sub eax, 88
    shr eax, 5
    cmp eax, 1
    jae .atleast
    mov eax, 1
.atleast:
    cmp eax, [dk_rows]
    jbe .limit
    mov eax, [dk_rows]
.limit:
    mov [dk_vis], eax
    movzx edx, byte [dk_scroll]
    add edx, eax
    cmp edx, [dk_rows]
    jbe .scroll_ok
    mov edx, [dk_rows]
    sub edx, eax
    mov [dk_scroll], dl
.scroll_ok:
    mov eax, [dk_w]
    cmp eax, DK_W
    jb .compact
    sub eax, 56
    xor edx, edx
    mov ecx, 4
    div ecx
    and eax, -2
    mov [dk_bw], eax
    jmp .sizes
.compact:
    sub eax, 48
    shr eax, 1
    and eax, -2
    mov [dk_bw], eax
.sizes:
    mov eax, [dk_y]
    add eax, [dk_h]
    cmp eax, 592
    jbe .done
    mov eax, 592
    sub eax, [dk_h]
    and eax, -2
    mov [dk_y], eax
.done:ret

; Прямоугольник внутри окна Disks
dk_box:
    add eax, [dk_x]
    add ebx, [dk_y]
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    jmp fill_rect

dk_draw:
    pushad
    call dk_layout
    mov eax, [dk_x]
    mov [cw_x], eax
    mov eax, [dk_y]
    mov [cw_y], eax
    mov dword [r_c], C_BLACK
    mov eax, 8
    mov ebx, 8
    mov ecx, [dk_w]
    mov edx, [dk_h]
    call dk_box
    xor eax, eax
    xor ebx, ebx
    call dk_box
    mov dword [r_c], C_WHITE
    mov eax, 2
    mov ebx, 2
    mov ecx, [dk_w]
    sub ecx, 4
    mov edx, [dk_h]
    sub edx, 4
    call dk_box
    mov dword [r_c], C_BLACK
    mov eax, 2
    mov ebx, 40
    mov ecx, [dk_w]
    sub ecx, 4
    mov edx, 2
    call dk_box
    mov eax, 2
    mov ebx, 80
    mov ecx, [dk_w]
    sub ecx, 4
    mov edx, 2
    call dk_box
    mov eax, [dk_w]                     ; заголовок по центру
    sub eax, 80
    shr eax, 1
    and eax, -8
    add eax, [dk_x]
    mov [t_x], eax
    mov eax, [dk_y]
    add eax, 4
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_dk_t
    call draw_big
    mov eax, [dk_x]
    add eax, [dk_w]
    sub eax, 32
    mov ebx, [dk_y]
    add ebx, 8
    xor edi, edi
    call xbtn
    mov dword [r_c], C_BLACK            ; квадрат в углу: за него растягивают окно
    mov eax, [dk_w]
    sub eax, 18
    mov ebx, [dk_h]
    sub ebx, 18
    mov ecx, 16
    mov edx, 16
    call dk_box
    xor ebp, ebp
.r: call dk_row
    inc ebp
    cmp ebp, DT_N
    jb .r
    mov eax, [dk_x]                     ; Name: и поле имени
    add eax, 16
    mov [t_x], eax
    mov eax, [dk_y]
    add eax, [dk_ny]
    add eax, 4
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_dk_n
    call draw_big
    mov dword [r_c], C_BLACK
    mov eax, 104
    mov ebx, [dk_ny]
    mov ecx, [dk_w]
    sub ecx, 120
    mov edx, 40
    call dk_box
    call dk_name_draw
    call dk_size_draw                   ; numeric size input + KB/MB toggle
    movzx ebx, byte [dk_msg]
    test ebx, ebx
    jz .nm
    mov esi, [dk_msgs + ebx * 4]
    mov dword [r_c], C_BLACK
    mov eax, [dk_x]
    add eax, 16
    mov [t_x], eax
    mov eax, [dk_y]
    add eax, [dk_my]
    mov [t_y], eax
    call draw_big
.nm:xor ebp, ebp                        ; кнопки Create, Delete, Close
.b: mov eax, [dk_bw]
    add eax, 8
    imul eax, ebp
    add eax, 16
    mov ecx, [dk_bw]
    mov esi, [dk_bt + ebp * 4]
    mov ebx, [dk_by]
    cmp dword [dk_w], DK_W
    jae .btn_go
    ; две строки: Create/Delete сверху, Close/Format снизу
    mov eax, ebp
    and eax, 1
    mov edx, [dk_bw]
    add edx, 8
    imul eax, edx
    add eax, 16
    cmp ebp, 2
    jb .btn_upper
    jmp .btn_go
.btn_upper:
    mov ebx, [dk_by2]
.btn_go:
    mov edx, 40
    push eax
    mov eax, ebp
    add al, 133
    cmp al, 136
    jne .button_state
    mov al, 152                       ; Format has a separate hit code
.button_state:
    push edx
    mov dl, 1
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    inc ebp
    cmp ebp, 4
    jb .b
    mov eax, [dk_x]
    mov ebx, [dk_y]
    movzx edi, byte [dk_menu]
    call wm_file
    mov eax, [dk_vis]
    cmp eax, [dk_rows]
    jae .no_pager
    mov eax, [dk_w]
    sub eax, 96
    mov ebx, 44
    mov ecx, 36
    mov edx, 32
    mov esi, s_dk_prev
    xor edi, edi
    call wbtn
    mov eax, [dk_w]
    sub eax, 52
    mov ebx, 44
    mov ecx, 36
    mov edx, 32
    mov esi, s_dk_next
    xor edi, edi
    call wbtn
.no_pager:
    cmp byte [dk_menu], 0
    je .fm
    mov eax, [dk_x]
    mov ebx, [dk_y]
    call wm_menu
.fm:; Confirmation is rendered separately by redraw, not inside Disks.
.done:popad
    ret

; Строка диска ebp: буква, настоящий или виртуальный, размер. Выбранная - белым по чёрному
dk_row:
    pushad
    mov eax, ebp
    movzx edx, byte [dk_scroll]
    cmp eax, edx
    jb .r
    sub eax, edx
    cmp eax, [dk_vis]
    jae .r
    imul esi, ebp, DT_ESZ
    add esi, dtab
    cmp byte [esi], 0
    je .r
    mov eax, ebp
    movzx edx, byte [dk_scroll]
    sub eax, edx
    shl eax, 5
    add eax, [dk_y]
    add eax, 88
    mov [dk_y2], eax
    mov edi, dk_buf
    mov al, [esi]
    stosb
    mov ax, '  '
    stosw
    mov eax, 'real'
    cmp dword [esi + 6], 0
    je .rl
    mov eax, 'virt'
.rl:stosd
    mov ax, '  '
    stosw
    mov eax, [dk_sz + ebp * 4]
    shr eax, 1
    jnz .sz
    mov dword [edi], 'no d'
    mov dword [edi + 4], 'isk'
    add edi, 7
    jmp .e
.sz:mov ecx, ' KB'
    cmp eax, 1024
    jb .kb
    test eax, 1023                      ; don't round user sizes down to MB
    jnz .kb
    shr eax, 10
    mov ecx, ' MB'
.kb:call u32str
    mov [edi], ecx
    add edi, 3
.e: xor al, al
    stosb
    mov dword [r_c], C_BLACK
    movzx eax, byte [dk_sel]
    cmp ebp, eax
    jne .t
    mov eax, [dk_x]
    add eax, 16
    mov [r_x], eax
    mov eax, [dk_y2]
    mov [r_y], eax
    mov eax, [dk_w]
    sub eax, 32
    mov [r_w], eax
    mov dword [r_h], 32
    call fill_rect
    mov dword [r_c], C_WHITE
    jmp .p
.t: mov dword [r_c], C_BLACK
.p: mov eax, [dk_x]
    add eax, 24
    mov [t_x], eax
    mov eax, [dk_y2]
    mov [t_y], eax
    mov esi, dk_buf
    call draw_big
.r: popad
    ret

; Под мышью: 157 поле размера, 158 переключатель KB/MB, 133.. кнопки, 0 - ничего
dk_hit:
    mov esi, [m_x]
    sub esi, [dk_x]
    js .z
    mov edi, [m_y]
    sub edi, [dk_y]
    js .z
    cmp esi, [dk_w]
    ja .z
    cmp edi, [dk_h]
    ja .z
    cmp byte [dk_confirm], 0
    je .normal_hit
    ; While Format? is active, Disks cannot change the target disk or
    ; launch another destructive operation. Its title can still be dragged
    ; when the independent confirmation is behind the parent.
    cmp byte [dk_conf_top], 0
    jne .z
    cmp edi, 40
    jae .z
    mov al, 136
    ret
.normal_hit:
    mov eax, [dk_w]                     ; квадрат в правом нижнем углу
    sub eax, 18
    cmp esi, eax
    jb .nh
    mov eax, [dk_h]
    sub eax, 18
    cmp edi, eax
    jb .nh
    mov al, 137
    ret
.nh:cmp edi, 40
    jae .a
    mov eax, [dk_w]                     ; верхняя полоса: справа крестик, остальное - заголовок
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
    mov al, 128
    ret
.t: mov al, 136
    ret
.a: mov dl, [dk_menu]
    call wm_hit                         ; File и пункт Exit
    test al, al
    jz .pager
    add al, 147
    ret
.pager:
    cmp byte [dk_menu], 0
    jne .a1
    mov eax, [dk_vis]
    cmp eax, [dk_rows]
    jae .a1
    cmp edi, 44
    jb .a1
    cmp edi, 76
    ja .a1
    mov eax, [dk_w]
    sub eax, 96
    cmp esi, eax
    jb .a1
    add eax, 36
    cmp esi, eax
    jb .prev
    add eax, 8
    cmp esi, eax
    jb .a1
    add eax, 36
    cmp esi, eax
    jae .a1
    mov al, 156
    ret
.prev:
    mov al, 155
    ret
.a1:mov eax, edi
    sub eax, 88
    jb .b
    mov edx, [dk_vis]
    shl edx, 5
    cmp eax, edx
    jae .b
    cmp esi, 16
    jb .b
    mov edx, [dk_w]
    sub edx, 16
    cmp esi, edx
    ja .b
    shr eax, 5
    add al, [dk_scroll]
    add al, 140
    ret
.b: mov eax, [dk_ny]                   ; поле имени
    cmp edi, eax
    jb .bb
    add eax, 40
    cmp edi, eax
    ja .bb
    cmp esi, 104
    jb .bb
    mov eax, [dk_w]
    sub eax, 16
    cmp esi, eax
    ja .bb
    mov al, 138
    ret
.bb:mov eax, [dk_sy]                  ; size input and unit button
    cmp edi, eax
    jb .no_size
    add eax, 40
    cmp edi, eax
    ja .no_size
    cmp esi, 104
    jb .no_size
    mov eax, [dk_w]
    sub eax, 120
    cmp esi, eax
    jbe .size_field
    mov eax, [dk_w]
    sub eax, 104
    cmp esi, eax
    jb .no_size
    mov eax, [dk_w]
    sub eax, 16
    cmp esi, eax
    ja .no_size
    mov al, 158                         ; KB/MB toggle
    ret
.size_field:
    mov al, 157                         ; numeric text field
    ret
.no_size:
    cmp dword [dk_w], DK_W
    jb .small_buttons
    mov edx, [dk_by]
    mov ebx, [dk_bw]
    mov cl, 4
    mov al, 133
    call .btn
    jmp .button_done
.small_buttons:
    mov edx, [dk_by2]
    mov ebx, [dk_bw]
    mov cl, 2
    mov al, 133
    call .btn
    jnc .button_done
    mov edx, [dk_by]
    mov ebx, [dk_bw]
    mov cl, 2
    mov al, 135
    call .btn
.button_done:
    jc .z
    cmp al, 136                        ; код 136 уже занят заголовком
    jne .y
    mov al, 152                        ; отдельный код Format
    jmp .y
.z: xor al, al
.y: ret
; ряд кнопок: edx - y, ebx - ширина, cl - число кнопок, al - первый код
.btn:
    movzx ecx, cl
    push ecx
    mov ecx, edi
    sub ecx, edx
    jb .no
    cmp ecx, 40
    ja .no
    mov ecx, esi
    sub ecx, 16
    jb .no
    push eax
    mov eax, ecx
    xor edx, edx
    add ebx, 8
    div ebx
    mov ecx, [esp + 4]                  ; число кнопок (сохранено до push eax)
    cmp eax, ecx
    jae .no2
    sub ebx, 8
    cmp edx, ebx
    jae .no2
    mov ecx, eax
    pop eax
    add al, cl
    add esp, 4                         ; число кнопок
    clc
    ret
.no2:pop eax
.no:pop ecx
    stc
    ret

dk_press:
    cmp byte [dk_confirm], 0
    jne dk_confirm_press
    cmp al, 155
    jne .next_page
    cmp byte [dk_scroll], 0
    je .pager_done
    dec byte [dk_scroll]
    jmp dk_draw
.next_page:
    cmp al, 156
    jne .ordinary
    movzx eax, byte [dk_scroll]
    add eax, [dk_vis]
    cmp eax, [dk_rows]
    jae .pager_done
    inc byte [dk_scroll]
    jmp dk_draw
.pager_done:ret
.ordinary:
    cmp al, 148                         ; File
    jne .f1
    xor byte [dk_menu], 1
    jmp dk_draw
.f1:cmp al, 149                         ; Exit в меню File
    je dk_exit
    cmp byte [dk_menu], 0               ; нажали мимо меню - оно закрывается
    je .f2
    mov byte [dk_menu], 0
    push eax
    call dk_draw
    pop eax
.f2:cmp al, 138
    jne .nn
    call dk_mcell                       ; клик в поле имени: палочка встаёт сюда, дальше тянем выделение
    mov [dk_car], al
    mov [dk_anc], al
    mov byte [dk_focus], 0
    mov byte [dk_size_anc], 0xFF
    mov byte [sel_drag], 3
    jmp dk_draw
.nn:cmp al, 157
    jne .unit_size
    call dk_size_mcell               ; caret follows mouse click
    mov [dk_size_car], al
    mov [dk_size_anc], al            ; drag anchor
    mov byte [dk_focus], 1
    mov byte [dk_anc], 0xFF
    mov byte [sel_drag], 3
    jmp dk_draw
.unit_size:
    cmp al, 158
    jne .actions
    xor byte [dk_unit], 1
    mov byte [dk_focus], 1
    mov byte [dk_msg], 0
    jmp dk_draw
.actions:
    cmp al, 128
    je dk_close
    cmp al, 135
    je dk_close
    cmp al, 133
    je dk_create
    cmp al, 134
    je dk_del
    cmp al, 152
    je dk_format_ask
    cmp al, 137
    jne .nr
    mov bl, 6                           ; квадрат в углу: растягиваем окно
    mov byte [d_ctx], 4
    jmp drag_start
.nr:cmp al, 136
    jne .nt
    mov bl, 1                           ; заголовок: таскаем окно
    mov byte [d_ctx], 4
    jmp drag_start
.nt:cmp al, 140
    jb .z
    cmp al, 147
    ja .z
    sub al, 140
    movzx ebx, al
    imul ebx, DT_ESZ
    cmp byte [dtab + ebx], 0
    je .z
    mov [dk_sel], al
    mov byte [dk_msg], 0
    ; The disk selection keeps the original minimal UI.  Normal
    ; volume usage is shown in FloFile's drive card, not debug messages.
    jmp dk_draw
.z: ret

; Create: имя - слово, буквой диска станет его первая буква
dk_create:
    pushad
    mov byte [dk_msg], 3
    cmp byte [dk_len], 0
    je .r
    mov al, [dk_name]
    cmp al, 'a'
    jb .u
    cmp al, 'z'
    ja .u
    sub al, 32
.u: cmp al, 'A'
    jb .r
    cmp al, 'Z'
    ja .r
    mov [f_name], al
    mov edi, dtab
    mov ecx, DT_N
.f: cmp [edi], al
    je .r
    add edi, DT_ESZ
    loop .f
    call dk_parse_size
    jnc .valid_size
    mov byte [dk_msg], 16              ; invalid/infeasible requested size
    jmp .r
.valid_size:
    mov [f_vsize], eax
    mov byte [dk_msg], 2
    call wait_start                     ; пока пишем на диск - курсор-будильник
    xor al, al
    call fs_setdisk
    call add_core
    jc .r
    mov byte [dk_msg], 1
    mov byte [dk_len], 0
    mov byte [dk_name], 0
    mov byte [dk_car], 0
    mov byte [dk_anc], 0xFF
    mov byte [dk_size_anc], 0xFF
    mov byte [dk_focus], 0
    call dk_scan
.r: call wait_end
    popad
    jmp redraw                          ; высота окна могла поменяться - перерисовываем всё

dk_del:
    pushad
    mov byte [dk_msg], 5
    movzx ebx, byte [dk_sel]
    cmp bl, 0xFF
    je .r
    imul edi, ebx, DT_ESZ
    add edi, dtab
    mov byte [dk_msg], 0
    cmp dword [edi + 6], 0
    jne .go
    mov byte [d2_err], 0x41                ; настоящий диск удалять нельзя: окно Error 4x1
    jmp .r
.go:    call wait_start
    xor al, al
    call fs_setdisk
    mov al, [edi]
    mov [f_name], al
    call del_core
    jc .r
    mov byte [dk_msg], 6
    mov byte [dk_sel], 0xFF
    call dk_scan
.r: call wait_end
    popad
    jmp redraw

; поле имени: палочка, выделение, копировать/вырезать/вставить
; Поле имени рисуется отдельно, чтобы при протяжке мышью не перерисовывать всё окно
dk_name_draw:
    pushad
    mov dword [r_c], C_WHITE
    mov eax, 106
    mov ebx, [dk_ny]
    add ebx, 2
    mov ecx, [dk_w]
    sub ecx, 124
    mov edx, 36
    call dk_box
    call dk_sel_range
    mov edx, eax                        ; dl - с какой буквы выделено, dh - до какой
    xor ebx, ebx
.l: cmp bl, [dk_len]
    jae .e
    mov ecx, C_BLACK
    cmp bl, dl
    jb .ch
    cmp bl, dh
    jae .ch
    push ebx                            ; выделенная буква: чёрный квадрат, белая буква
    push edx
    mov eax, ebx
    shl eax, 4
    add eax, 116
    mov ebx, [dk_ny]
    add ebx, 4
    mov ecx, 16
    mov edx, 32
    mov dword [r_c], C_BLACK
    call dk_box
    pop edx
    pop ebx
    mov ecx, C_WHITE
.ch:mov eax, ebx
    shl eax, 4
    add eax, [dk_x]
    add eax, 116
    mov [t_x], eax
    mov eax, [dk_y]
    add eax, [dk_ny]
    add eax, 4
    mov [t_y], eax
    mov al, [dk_name + ebx]
    mov [dk_chb], al
    mov [r_c], ecx
    mov esi, dk_chb
    push ebx
    push edx
    call draw_big
    pop edx
    pop ebx
    inc ebx
    jmp .l
.e: cmp dl, dh                          ; нет выделения - рисуем палочку
    jne .r
    cmp byte [dk_focus], 0             ; only the active input has a caret
    jne .r
    movzx eax, byte [dk_car]
    shl eax, 4
    add eax, 116
    mov ebx, [dk_ny]
    add ebx, 4
    mov ecx, 2
    mov edx, 32
    mov dword [r_c], C_BLACK
    call dk_box
.r: popad
    ret

; Size entry is a separate, digits-only field. No floating-point needed.
; Screen layout tracks dk_w, including the minimum resizable width of 352.
dk_size_draw:
    pushad
    mov eax, [dk_x]
    add eax, 16
    mov [t_x], eax
    mov eax, [dk_y]
    add eax, [dk_sy]
    add eax, 4
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_dk_size_label
    call draw_big
    mov dword [r_c], C_BLACK
    mov eax, 104
    mov ebx, [dk_sy]
    mov ecx, [dk_w]
    sub ecx, 224
    mov edx, 40
    call dk_box
    mov dword [r_c], C_WHITE
    mov eax, 106
    mov ebx, [dk_sy]
    add ebx, 2
    mov ecx, [dk_w]
    sub ecx, 228
    mov edx, 36
    call dk_box
    ; Same selection/caret behavior as the existing Name field.
    call dk_size_sel_range
    mov edx, eax                     ; DL=start, DH=end
    xor ebx, ebx
.size_char:
    cmp bl, [dk_size_len]
    jae .size_caret
    mov ecx, C_BLACK
    cmp bl, dl
    jb .size_regular
    cmp bl, dh
    jae .size_regular
    push ebx
    push edx
    mov eax, ebx
    shl eax, 4
    add eax, 116
    mov ebx, [dk_sy]
    add ebx, 4
    mov ecx, 16
    mov edx, 32
    mov dword [r_c], C_BLACK
    call dk_box
    pop edx
    pop ebx
    mov ecx, C_WHITE
.size_regular:
    mov eax, ebx
    shl eax, 4
    add eax, [dk_x]
    add eax, 116
    mov [t_x], eax
    mov eax, [dk_y]
    add eax, [dk_sy]
    add eax, 4
    mov [t_y], eax
    mov al, [dk_size_text + ebx]
    mov [dk_size_ch], al
    mov [r_c], ecx
    mov esi, dk_size_ch
    push ebx
    push edx
    call draw_big
    pop edx
    pop ebx
    inc ebx
    jmp .size_char
.size_caret:
    cmp dl, dh                       ; hide caret during selection
    jne .unit
    cmp byte [dk_focus], 1
    jne .unit
    movzx eax, byte [dk_size_car]
    shl eax, 4
    add eax, 116
    mov ebx, [dk_sy]
    add ebx, 4
    mov ecx, 2
    mov edx, 32
    mov dword [r_c], C_BLACK
    call dk_box
.unit:
    mov eax, [dk_w]
    sub eax, 104
    mov ebx, [dk_sy]
    mov ecx, 88
    mov edx, 40
    mov esi, s_dk_unit_kb
    cmp byte [dk_unit], 0
    je .draw_unit
    mov esi, s_dk_unit_mb
.draw_unit:
    push eax
    push edx
    mov al, 158                         ; KB/MB is a real clickable button
    mov dl, 1
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    popad
    ret

; Size editor: five digits max, with mouse selection and shared clipboard.
; See zametki.txt "ПРАВИЛА НА ВСЕГДА" for all text-entry controls.
dk_size_sel_range:
    xor eax, eax
    mov al, [dk_size_anc]
    cmp al, 0xFF
    je .none
    mov ah, [dk_size_car]
    cmp al, ah
    jbe .done
    xchg al, ah
.done:ret
.none:
    xor eax, eax
    ret

dk_size_sel_del:
    pushad
    call dk_size_sel_range
    cmp al, ah
    je .done
    movzx esi, ah
    movzx edi, al
    movzx ecx, byte [dk_size_len]
    sub ecx, esi
    inc ecx                         ; move NUL too
    add esi, dk_size_text
    add edi, dk_size_text
    cld
    rep movsb
    sub byte [dk_size_len], ah
    add byte [dk_size_len], al
    mov [dk_size_car], al
    mov byte [dk_size_anc], 0xFF
.done:popad
    ret

dk_size_del1:
    pushad
    movzx ebx, byte [dk_size_car]
    movzx ecx, byte [dk_size_len]
    sub ecx, ebx
    jbe .done
    lea esi, [dk_size_text + ebx + 1]
    lea edi, [dk_size_text + ebx]
    cld
    rep movsb
    dec byte [dk_size_len]
.done:popad
    ret

dk_size_ins:
    pushad
    mov [dk_size_ch], al
    call dk_size_sel_del
    cmp byte [dk_size_len], 5
    jae .done
    movzx ebx, byte [dk_size_len]
    movzx ecx, byte [dk_size_car]
.shift:
    cmp ebx, ecx
    jl .write
    mov al, [dk_size_text + ebx]
    mov [dk_size_text + ebx + 1], al
    dec ebx
    jmp .shift
.write:
    movzx ebx, byte [dk_size_car]
    mov al, [dk_size_ch]
    mov [dk_size_text + ebx], al
    inc byte [dk_size_len]
    inc byte [dk_size_car]
    mov byte [dk_size_anc], 0xFF
.done:popad
    ret

dk_size_copy:
    pushad
    call dk_size_sel_range
    cmp al, ah
    je .done
    movzx esi, al
    movzx ecx, ah
    sub ecx, esi
    mov [clip_len], ecx
    xor ebx, ebx
.loop:
    mov al, [dk_size_text + esi]
    mov [clip_buf + ebx], al
    inc esi
    inc ebx
    loop .loop
.done:popad
    ret

; Mouse position mapped to the nearest digit boundary in Size.
dk_size_mcell:
    mov eax, [m_x]
    sub eax, [dk_x]
    sub eax, 108
    jge .nonnegative
    xor eax, eax
.nonnegative:
    shr eax, 4
    movzx ebx, byte [dk_size_len]
    cmp eax, ebx
    jbe .done
    mov eax, ebx
.done:ret

; Convert decimal amount in dk_size_text to a whole sector count.
; 1 KB = 1024 bytes, 1 MB = 1048576 bytes. Accepted: 180 KB .. 32 MB.
; On success EAX=sectors, CF=0. All values beyond FSM3_MAX_SECTORS rejected.
dk_parse_size:
    xor eax, eax
    movzx ecx, byte [dk_size_len]
    test ecx, ecx
    jz .bad
    mov esi, dk_size_text
.digit:
    movzx edx, byte [esi]
    cmp dl, '0'
    jb .bad
    cmp dl, '9'
    ja .bad
    sub edx, '0'
    imul eax, eax, 10
    add eax, edx
    cmp eax, 32768                      ; reject early: safe from overflow
    ja .bad
    inc esi
    dec ecx
    jnz .digit
    test eax, eax
    jz .bad
    cmp byte [dk_unit], 0
    jne .mb
    cmp eax, 180
    jb .bad
    shl eax, 1                          ; 1024 / 512
    cmp eax, FS3_MAX_SECTORS
    ja .bad
    clc
    ret
.mb:
    cmp eax, 32
    ja .bad
    shl eax, 11                         ; 1048576 / 512
    clc
    ret
.bad:
    stc
    ret

; выделено: al - с какой буквы, ah - до какой (пусто: al = ah)
dk_sel_range:
    xor eax, eax
    mov al, [dk_anc]
    cmp al, 0xFF
    je .n
    mov ah, [dk_car]
    cmp al, ah
    jbe .r
    xchg al, ah
.r: ret
.n: xor eax, eax
    ret

; убрать выделенные буквы
dk_sel_del:
    pushad
    call dk_sel_range
    cmp al, ah
    je .r
    movzx esi, ah
    movzx edi, al
    movzx ecx, byte [dk_len]
    sub ecx, esi
    inc ecx
    add esi, dk_name
    add edi, dk_name
    cld
    rep movsb
    sub byte [dk_len], ah
    add byte [dk_len], al
    mov [dk_car], al
    mov byte [dk_anc], 0xFF
.r: popad
    ret

; убрать букву под палкой (Delete-подобно, для Backspace после сдвига палки)
dk_del1:
    pushad
    movzx ebx, byte [dk_car]
    movzx ecx, byte [dk_len]
    sub ecx, ebx
    jbe .r
    lea esi, [dk_name + ebx + 1]
    lea edi, [dk_name + ebx]
    cld
    rep movsb                           ; вместе с нулём в конце
    dec byte [dk_len]
.r: popad
    ret

; вставить букву al там, где палка (выделенное заменяется)
dk_ins:
    pushad
    call dk_sel_del
    cmp byte [dk_len], 8
    jae .r
    movzx ebx, byte [dk_len]
    movzx ecx, byte [dk_car]
.l: cmp ebx, ecx
    jl .d
    mov dl, [dk_name + ebx]
    mov [dk_name + ebx + 1], dl
    dec ebx
    jmp .l
.d: movzx ebx, byte [dk_car]
    mov [dk_name + ebx], al
    inc byte [dk_len]
    inc byte [dk_car]
    mov byte [dk_anc], 0xFF            ; вставленное не должно оставаться выделенным
.r: popad
    ret

; выделенное - в буфер обмена
dk_copy:
    pushad
    call dk_sel_range
    cmp al, ah
    je .r
    movzx esi, al
    movzx ecx, ah
    sub ecx, esi
    mov [clip_len], ecx
    xor ebx, ebx
.l: mov al, [dk_name + esi]
    mov [clip_buf + ebx], al
    inc esi
    inc ebx
    loop .l
.r: popad
    ret

; мышь в поле имени: какая буква ближе (eax)
dk_mcell:
    mov eax, [m_x]
    sub eax, [dk_x]
    sub eax, 108
    jge .a
    xor eax, eax
.a: shr eax, 4
    movzx ebx, byte [dk_len]
    cmp eax, ebx
    jbe .r
    mov eax, ebx
.r: ret

; тянем мышью - выделение растёт
dk_sel_move:
    pushad
    cmp byte [dk_focus], 1
    je .size
    call dk_mcell
    cmp al, [dk_car]
    je .r
    mov [dk_car], al
    call dk_name_draw
    jmp .r
.size:
    call dk_size_mcell
    cmp al, [dk_size_car]
    je .r
    mov [dk_size_car], al
    call dk_size_draw
.r: popad
    ret

; Клавиша al: буквы в имя, Backspace стирает, Ctrl+A/C/X/V, Enter - Create, Esc - закрыть
dk_key:
    cmp byte [dk_confirm], 0
    jne dk_confirm_key
    pushad
    cmp al, 5
    je .cl
    cmp al, 27
    je .cl
    cmp al, 13
    je .ok
    cmp byte [dk_focus], 1
    je .size_key
    cmp al, 8
    je .bs
    cmp al, 0x97                   ; Delete, extended-key code
    je .delete_name
    cmp al, 1
    je .all
    cmp al, 3
    je .copy
    cmp al, 0x18
    je .cut
    cmp al, 0x16
    je .paste
    cmp al, ' '
    jbe .r
    CHKHI al, .r
    call dk_ins
    jmp .upd
.size_key:
    cmp al, 8
    je .size_backspace
    cmp al, 0x97
    je .size_delete
    cmp al, 0x93
    je .size_left
    cmp al, 0x94
    je .size_right
    cmp al, 0x95
    je .size_home
    cmp al, 0x96
    je .size_end
    cmp al, 1
    je .size_all
    cmp al, 3
    je .size_copy_only
    cmp al, 0x18
    je .size_cut
    cmp al, 0x16
    je .size_paste
    cmp al, '0'
    jb .r
    cmp al, '9'
    ja .r
    call dk_size_ins
    jmp .upd
.size_backspace:
    call dk_size_sel_range
    cmp al, ah
    jne .size_del_sel
    cmp byte [dk_size_car], 0
    je .r
    dec byte [dk_size_car]
    call dk_size_del1
    jmp .upd
.size_delete:
    call dk_size_sel_range
    cmp al, ah
    jne .size_del_sel
    call dk_size_del1
    jmp .upd
.size_del_sel:
    call dk_size_sel_del
    jmp .upd
.size_left:
    call dk_size_sel_range
    cmp al, ah
    je .size_left_one
    mov [dk_size_car], al
    jmp .size_clear_sel
.size_left_one:
    cmp byte [dk_size_car], 0
    je .r
    dec byte [dk_size_car]
    jmp .size_clear_sel
.size_right:
    call dk_size_sel_range
    cmp al, ah
    je .size_right_one
    mov [dk_size_car], ah
    jmp .size_clear_sel
.size_right_one:
    mov al, [dk_size_car]
    cmp al, [dk_size_len]
    jae .r
    inc byte [dk_size_car]
    jmp .size_clear_sel
.size_home:
    mov byte [dk_size_car], 0
    jmp .size_clear_sel
.size_end:
    mov al, [dk_size_len]
    mov [dk_size_car], al
.size_clear_sel:
    mov byte [dk_size_anc], 0xFF
    jmp .upd
.size_all:
    mov byte [dk_size_anc], 0
    mov al, [dk_size_len]
    mov [dk_size_car], al
    jmp .upd
.size_copy_only:
    call dk_size_copy
    jmp .r
.size_cut:
    call dk_size_copy
    call dk_size_sel_del
    jmp .upd
.size_paste:
    xor ebx, ebx
.size_paste_loop:
    cmp ebx, [clip_len]
    jae .upd
    mov al, [clip_buf + ebx]
    cmp al, '0'
    jb .size_paste_next
    cmp al, '9'
    ja .size_paste_next
    push ebx
    call dk_size_ins
    pop ebx
.size_paste_next:
    inc ebx
    jmp .size_paste_loop
.delete_name:
    call dk_sel_range
    cmp al, ah
    jne .name_delete_selection
    call dk_del1
    jmp .upd
.name_delete_selection:
    call dk_sel_del
    jmp .upd
.bs:call dk_sel_range
    cmp al, ah
    jne .del
    cmp byte [dk_car], 0
    je .r
    dec byte [dk_car]
.del:
    call dk_sel_range
    cmp al, ah
    je .d1
    call dk_sel_del
    jmp .upd
.d1:call dk_del1
    jmp .upd
.all:
    mov byte [dk_anc], 0
    mov al, [dk_len]
    mov [dk_car], al
    jmp .upd
.cut:
    call dk_copy
    call dk_sel_del
    jmp .upd
.copy:
    call dk_copy
    jmp .r
.paste:
    xor ebx, ebx
.pl:cmp ebx, [clip_len]
    jae .upd
    mov al, [clip_buf + ebx]
    cmp al, ' '                         ; пробелы и переводы строк в имя не берём
    jbe .pn
    CHKHI al, .pn
    push ebx
    call dk_ins
    pop ebx
.pn:inc ebx
    jmp .pl
.upd:
    mov byte [dk_msg], 0
    popad
    jmp dk_draw
.fsm3test:
    popad
    pushad
    mov al, [dk_sel]
    call fs3_testfile
    jc .testfail
    mov byte [dk_msg], 14
    jmp .testdone
.testfail:
    mov byte [dk_msg], 15
.testdone:
    popad
    jmp dk_draw
.ok:popad
    jmp dk_create
.cl:popad
    jmp dk_close
.r: popad
    ret


; данные окна Disks
d2_dk       db 0
dk_sel      db 0xFF
dk_len      db 0
dk_car      db 0                        ; где палочка
dk_anc      db 0xFF                     ; откуда выделяли (0xFF - не выделено)
dk_chb      db 0, 0
dk_focus    db 0                       ; 0 name, 1 numeric size
dk_size_car db 3                       ; caret index within Size field
dk_size_anc db 0xFF                    ; selection anchor (FF means none)
dk_size_ch  db 0, 0                    ; temporary single-digit string
    ; Size selector: text field + KB/MB toggle. Keep 360 KB default.
dk_unit     db 0                       ; 0 KB, 1 MB
dk_size_len db 3
dk_size_text db '360', 0, 0, 0
dk_msg      db 0
dk_confirm  db 0                       ; 1 = подтверждение Format
dk_conf_top db 0                       ; 1 = confirmation above Disks, 0 = behind
dk_conf_x   dd 0                       ; independent child window coordinates
dk_conf_y   dd 0
dk_conf_w   dd 416
dk_conf_h   dd 252
dk_confirm_min db 0                     ; 1 = minimized confirmation
dk_conf_menu db 0                      ; File menu for Format dialog
dk_fslot    db 0                       ; индекс выбранного виртуального диска
dk_fletter  db 0
dk_fphys    db 0
dk_fbase    dd 0
dk_fsize    dd 0
dk_fsect    dd 0
dk_x        dd 208                      ; x, y, w, h подряд: swap_ctx таскает окно
dk_y        dd 100
dk_w        dd DK_W
dk_h        dd 344
dk_rows     dd 1
dk_hmin     dd 0
; Floppy_143: прокрутка списка при уменьшении окна
dk_scroll   db 0
dk_vis      dd 1
dk_by2      dd 0
dk_bw       dd 112
dk_ny       dd 0
dk_menu     db 0
dk_sy       dd 0
dk_my       dd 0
dk_by       dd 0
dk_y2       dd 0
dk_name     times 10 db 0
dk_buf      times 24 db 0
dk_sz       times DT_N dd 0
dk_bt       dd s_dk_c, s_dk_d, s_dk_x, s_dk_fmt
dk_msgs     dd 0, s_dk_m1, s_dk_m2, s_dk_m3, s_dk_m4, s_dk_m5, s_dk_m6, s_dk_m7, s_dk_m8, s_dk_m9, s_dk_m10, s_dk_m11, s_dk_m12, s_dk_m13, s_dk_m14, s_dk_m15, s_dk_m16
s_dk_n      db "Name:", 0
s_dk_size_label db "Size:", 0
s_dk_unit_kb db "KB", 0
s_dk_unit_mb db "MB", 0
s_dk_m16    db "Size: 180KB - 32MB", 0
s_dk_c      db "Create", 0
s_dk_d      db "Delete", 0
s_dk_x      db "Close", 0
s_dk_fmt    db "Format", 0
s_dk_m1     db "Disk created", 0
s_dk_m2     db "No free space", 0
s_dk_m3     db "Bad name", 0
s_dk_m4     db "Can't delete this disk", 0
s_dk_m5     db "Pick a disk first", 0
s_dk_m6     db "Disk deleted", 0

; Floppy_141: полное форматирование только виртуальных дисков.
; Здесь не используются fs_setdisk для допуска: он отказывает для неформатированного диска.
; Настоящие C/O/I защищены независимо от выбранного системного диска.
dk_format_ask:
    pushad
    mov byte [dk_msg], 5
    movzx eax, byte [dk_sel]
    cmp eax, 3
    jb .real
    cmp eax, DT_N
    jae .no
    mov [dk_fslot], al
    imul ebx, eax, DT_ESZ
    add ebx, dtab
    cmp byte [ebx], 0
    je .no
    cmp dword [ebx + 6], 0
    je .no
    mov al, [ebx + 1]
    cmp al, 3
    jae .no
    cmp byte [dk_present + eax], 0
    je .no
    mov [dk_fphys], al
    mov al, [ebx]
    mov [dk_fletter], al
    mov eax, [ebx + 2]
    mov [dk_fbase], eax
    mov eax, [ebx + 6]
    mov [dk_fsize], eax
    ; Диапазон виртуального диска не должен выходить за реальный носитель.
    movzx edx, byte [dk_fphys]
    mov ecx, [dk_total + edx * 4]
    mov edx, [dk_fbase]
    test edx, edx
    jz .no
    cmp edx, ecx
    jae .no
    sub ecx, edx
    cmp eax, ecx
    ja .no
    mov byte [dk_msg], 0
    mov byte [dk_confirm], 1
    mov byte [dk_conf_top], 1
    mov byte [dk_conf_menu], 0
    mov byte [dk_confirm_min], 0
    mov eax, [dk_w]
    sub eax, 16
    cmp eax, 416
    jbe .width_ok
    mov eax, 416
.width_ok:
    mov [dk_conf_w], eax
    mov eax, [dk_w]
    sub eax, [dk_conf_w]
    shr eax, 1
    add eax, [dk_x]
    mov [dk_conf_x], eax
    mov eax, [dk_h]
    sub eax, 252
    shr eax, 1
    add eax, [dk_y]
    mov [dk_conf_y], eax
    jmp .no
.real:
    ; Physical C/O/I disks are NEVER formatted; report a numeric-only error.
    mov byte [dk_msg], 0
    mov byte [d2_err], 0x42         ; Error 4x2: attempt to format real disk
.no:popad
    jmp redraw

; Окно подтверждения поверх Disks (координаты внутри окна)
dk_confirm_draw:
    pushad
    push dword [cw_x]
    push dword [cw_y]
    mov eax, [dk_x]
    mov [cw_x], eax
    mov eax, [dk_y]
    mov [cw_y], eax
    mov eax, [dk_conf_x]
    sub eax, [dk_x]
    mov [dk_fx], eax
    mov eax, [dk_conf_y]
    sub eax, [dk_y]
    mov [dk_fy], eax
    mov eax, [dk_conf_w]
    mov [dk_fw], eax
    cmp byte [dk_confirm_min], 0
    je .expanded
    push dword [cw_x]
    push dword [cw_y]
    mov eax, [dk_x]
    mov [cw_x], eax
    mov eax, [dk_y]
    mov [cw_y], eax
    mov eax, [dk_w]
    sub eax, 150
    mov ebx, [dk_h]
    sub ebx, 40
    mov ecx, 144
    mov edx, 36
    mov esi, dk_conf_mini_label
    xor edi, edi
    call wbtn
    pop dword [cw_y]
    pop dword [cw_x]
    jmp .done
.expanded:
    mov eax, [dk_fx]
    mov ebx, [dk_fy]
    mov ecx, [dk_fw]
    mov edx, 252
    mov dword [r_c], C_BLACK
    call dk_box
    mov eax, [dk_fx]
    add eax, 2
    mov ebx, [dk_fy]
    add ebx, 2
    mov ecx, [dk_fw]
    sub ecx, 4
    mov edx, 248
    mov dword [r_c], C_WHITE
    call dk_box
    mov eax, [dk_fx]
    add eax, 2
    mov ebx, [dk_fy]
    add ebx, 2
    mov ecx, [dk_fw]
    sub ecx, 4
    mov edx, 2
    mov ebx, [dk_fy]
    add ebx, 40
    mov dword [r_c], C_BLACK
    call dk_box
    mov eax, [dk_fx]
    add eax, [dk_x]
    mov ebx, [dk_fy]
    add ebx, [dk_y]
    add ebx, 4
    mov edx, [dk_fw]
    mov esi, sys_title_text
    call sys_modal_center
    mov al, 216
    call title_button_state
    mov eax, [dk_x]
    add eax, [dk_fx]
    add eax, [dk_fw]
    sub eax, 70
    mov ebx, [dk_y]
    add ebx, [dk_fy]
    add ebx, 10
    call mbtn
    mov al, 217
    call title_button_state
    mov eax, [dk_x]
    add eax, [dk_fx]
    add eax, [dk_fw]
    sub eax, 34
    mov ebx, [dk_y]
    add ebx, [dk_fy]
    add ebx, 10
    call xbtn
    mov eax, [dk_fx]
    add eax, [dk_x]
    mov ebx, [dk_fy]
    add ebx, [dk_y]
    add ebx, 86
    mov edx, [dk_fw]
    mov esi, s_dk_fmt_title
    call sys_modal_center
    mov eax, [dk_fx]
    add eax, [dk_x]
    mov ebx, [dk_fy]
    add ebx, [dk_y]
    add ebx, 126
    mov edx, [dk_fw]
    mov esi, s_dk_fmt_warn_short
    call sys_modal_center
    mov eax, [dk_fx]
    add eax, 16
    add eax, [dk_x]
    mov [t_x], eax
    mov eax, [dk_fy]
    add eax, [dk_y]
    add eax, 162
    mov [t_y], eax
    mov byte [dk_flabel], 'D'
    mov al, [dk_fletter]
    mov [dk_flabel + 5], al
    mov esi, dk_flabel
    call draw_big
    mov eax, [dk_fx]
    add eax, 16
    mov ebx, [dk_fy]
    add ebx, 202
    mov ecx, 144
    mov edx, 40
    mov esi, s_dk_cancel
    push eax
    mov al, 153
    push edx
    mov dl, 2
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    mov eax, [dk_fx]
    add eax, [dk_fw]
    sub eax, 160
    mov ebx, [dk_fy]
    add ebx, 202
    mov ecx, 144
    mov edx, 40
    mov esi, s_dk_fmt
    push eax
    mov al, 154
    push edx
    mov dl, 2
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    mov eax, [dk_x]
    add eax, [dk_fx]
    mov ebx, [dk_y]
    add ebx, [dk_fy]
    mov ecx, [dk_fw]
    mov dl, [dk_conf_menu]
    call sys_file_draw
.done:
    pop dword [cw_y]
    pop dword [cw_x]
    popad
    ret

; When Disks is raised over the pending confirmation, leave a visible
; restore tab. Without this, a confirmation fully covered by its parent
; would become unreachable by mouse.
dk_conf_back_badge_draw:
    pushad
    push dword [cw_x]
    push dword [cw_y]
    mov eax, [dk_x]
    mov [cw_x], eax
    mov eax, [dk_y]
    mov [cw_y], eax
    mov eax, [dk_w]
    sub eax, 150
    mov ebx, [dk_h]
    sub ebx, 44
    mov ecx, 144
    mov edx, 36
    mov esi, dk_conf_mini_label
    xor edi, edi
    call wbtn
    pop dword [cw_y]
    pop dword [cw_x]
    popad
    ret

dk_conf_back_badge_hit:
    mov eax, [m_x]
    sub eax, [dk_x]
    js .no
    mov edx, [dk_w]
    sub edx, 150
    cmp eax, edx
    jb .no
    add edx, 144
    cmp eax, edx
    ja .no
    mov eax, [m_y]
    sub eax, [dk_y]
    js .no
    mov edx, [dk_h]
    sub edx, 44
    cmp eax, edx
    jb .no
    add edx, 36
    cmp eax, edx
    ja .no
    mov al, 219
    stc
    ret
.no:
    clc
    ret

; Test independent Format? window anywhere on screen. CF=1 means pointer
; belongs to it, even if no action control was hit (AL=0).
; This lets the child be dragged outside its original Disks rectangle.
dk_conf_screen_hit:
    cmp byte [d2_dk], 0
    je .no
    cmp byte [dk_confirm], 0
    je .no
    cmp byte [dk_confirm_min], 0
    je .expanded
    mov eax, [dk_x]
    add eax, [dk_w]
    sub eax, 150
    mov edx, [m_x]
    sub edx, eax
    js .no
    cmp edx, 144
    ja .no
    mov eax, [dk_y]
    add eax, [dk_h]
    sub eax, 40
    mov edx, [m_y]
    sub edx, eax
    js .no
    cmp edx, 36
    ja .no
    jmp .hit
.expanded:
    mov eax, [m_x]
    sub eax, [dk_conf_x]
    js .no
    cmp eax, [dk_conf_w]
    ja .no
    mov eax, [m_y]
    sub eax, [dk_conf_y]
    js .no
    cmp eax, [dk_conf_h]
    ja .no
.hit:
    mov esi, [m_x]
    sub esi, [dk_x]
    mov edi, [m_y]
    sub edi, [dk_y]
    call dk_confirm_hit
    stc
    ret
.no:
    clc
    ret

; Пока открыто подтверждение, остальные элементы Disks недоступны.
dk_confirm_hit:
    cmp byte [dk_confirm_min], 0
    je .expanded
    mov eax, [dk_w]
    sub eax, 150
    cmp esi, eax
    jb .outside
    add eax, 144
    cmp esi, eax
    ja .outside
    mov eax, [dk_h]
    sub eax, 40
    cmp edi, eax
    jb .outside
    add eax, 36
    cmp edi, eax
    ja .outside
    mov al, 219                      ; restore Format?
    ret
.expanded:
    ; File/Exit in child-relative coordinates; parent hit state is preserved.
    push esi
    push edi
    sub esi, [dk_fx]
    sub edi, [dk_fy]
    mov dl, [dk_conf_menu]
    call sys_file_hit
    pop edi
    pop esi
    test al, al
    jnz .menu_hit
    ; Controls are inside the titlebar of the nested confirmation.
    mov eax, edi
    sub eax, [dk_fy]
    cmp eax, 6
    jb .title_drag
    cmp eax, 38
    ja .title_drag
    mov eax, esi
    sub eax, [dk_fx]
    mov edx, [dk_fw]
    sub edx, 76
    cmp eax, edx
    jb .title_drag
    add edx, 30
    cmp eax, edx
    jbe .minus_btn
    add edx, 6
    cmp eax, edx
    jb .title_drag
    add edx, 30
    cmp eax, edx
    jbe .close_btn
    jmp .title_drag
.menu_hit:
    ret
.minus_btn:
    mov al, 216
    ret
.close_btn:
    mov al, 217
    ret
.title_drag:
    mov eax, edi
    sub eax, [dk_fy]
    js .check_buttons
    cmp eax, 40
    ja .check_buttons
    mov eax, esi
    sub eax, [dk_fx]
    js .check_buttons
    cmp eax, [dk_fw]
    ja .check_buttons
    mov al, 233                       ; drag independent Format? window
    ret
.check_buttons:
    mov eax, edi
    sub eax, [dk_fy]
    sub eax, 202
    jb .outside
    cmp eax, 40
    ja .outside
    mov eax, esi
    sub eax, [dk_fx]
    cmp eax, 16
    jb .outside
    cmp eax, 160
    jbe .cancel
    mov edx, [dk_fw]
    sub edx, 160
    cmp eax, edx
    jb .outside
    add edx, 144
    cmp eax, edx
    jbe .format
.outside:
    xor al, al
    ret
.cancel:
    mov al, 153
    ret
.format:
    mov al, 154
    ret

dk_confirm_press:
    cmp al, 193
    je .toggle_file
    cmp al, 194
    je .close_file
    cmp al, 216
    jne .not_min
    mov byte [dk_confirm_min], 1
    jmp redraw
.toggle_file:
    xor byte [dk_conf_menu], 1
    jmp redraw
.close_file:
    mov byte [dk_conf_menu], 0
    mov byte [dk_confirm], 0
    mov byte [dk_confirm_min], 0
    jmp redraw
.not_min:
    cmp al, 217
    jne .not_close
    mov byte [dk_confirm_min], 0
    mov byte [dk_confirm], 0           ; X = cancel, never format
    jmp redraw
.not_close:
    cmp al, 219
    jne .not_restore
    mov byte [dk_confirm_min], 0
    jmp redraw
.not_restore:
    cmp al, 233
    jne .check_actions
    mov byte [d_ctx], 15              ; only the child moves; Disks stays put
    mov bl, 1
    jmp drag_start
.check_actions:
    cmp al, 154
    je dk_format_do
    cmp al, 153
    jne .r
    mov byte [dk_confirm], 0
    mov byte [dk_confirm_min], 0
    jmp redraw
.r:ret

dk_confirm_key:
    ; No hidden 2/3 developer toggle.  New virtual volumes use FSM3.
    cmp al, 5                           ; Ctrl+E = File > Exit (cancel format)
    je .cancel
    cmp al, 27                          ; Esc = отмена
    je .cancel
    cmp al, 13                          ; Enter НЕ форматирует случайно
    jne .r
.cancel:
    mov byte [dk_conf_menu], 0
    mov byte [dk_confirm_min], 0
    mov byte [dk_confirm], 0
    jmp redraw
.r:ret

; Перезаписать нулями ВСЕ сектора виртуального диска, затем создать чистую FSM2.
; В отличие от быстрого форматирования обнуляет и области данных.
dk_format_do:
    mov byte [dk_confirm], 0
    pushad
    mov byte [dk_msg], 7                ; по умолчанию ошибка
    ; повторная проверка: выбранная запись могла измениться
    movzx eax, byte [dk_fslot]
    cmp eax, 3
    jb .done
    cmp eax, DT_N
    jae .done
    imul esi, eax, DT_ESZ
    add esi, dtab
    cmp byte [esi], 0
    je .done
    cmp dword [esi + 6], 0
    je .done
    mov al, [esi]
    cmp al, [dk_fletter]
    jne .done
    mov eax, [esi + 2]
    cmp eax, [dk_fbase]
    jne .done
    mov eax, [esi + 6]
    cmp eax, [dk_fsize]
    jne .done
    mov al, [esi + 1]
    cmp al, [dk_fphys]
    jne .done
    cmp al, 3
    jae .done
    movzx edx, al
    cmp byte [dk_present + edx], 0
    je .done
    mov eax, [dk_fbase]
    test eax, eax
    jz .done
    cmp eax, [dk_total + edx * 4]
    jae .done
    mov ecx, [dk_total + edx * 4]
    sub ecx, eax
    cmp [dk_fsize], ecx
    ja .done
    ; сохранить текущий выбранный физический/виртуальный диск
    push dword [cur_base]
    push dword [cur_size]
    movzx eax, byte [cur_drive]
    push eax
    movzx eax, byte [cur_letter]
    push eax
    mov al, [dk_fphys]
    mov [cur_drive], al
    mov eax, [dk_fbase]
    mov [cur_base], eax
    mov eax, [dk_fsize]
    mov [cur_size], eax
    mov edi, FS2_BUF
    xor eax, eax
    mov ecx, 128
    cld
    rep stosd
    mov dword [dk_fsect], 0
    call wait_start
.zero:
    mov eax, [dk_fsect]
    cmp eax, [dk_fsize]
    jae .filesystem
    mov ebx, FS2_BUF
    call lba_write
    jc .fail
    inc dword [dk_fsect]
    jmp .zero
.filesystem:
    call ata_flush
    ; Ordinary Format creates FSM3 on virtual volumes.  The confirmation
    ; and physical disk protection are unchanged.
    call fs3_format
    jc .fail
    mov byte [dk_msg], 8
.fail:
    call wait_end
    pop eax
    mov [cur_letter], al
    pop eax
    mov [cur_drive], al
    pop dword [cur_size]
    pop dword [cur_base]
    call scan_disks
    call fs_pc_scan
    call dk_scan
.done:
    popad
    jmp redraw

dk_fw       dd 0
dk_fx       dd 0
dk_fy       dd 0
dk_flabel   db "Disk X", 0
s_dk_m10       db "Disk formatted", 0
s_dk_fmt_title db "Format disk?", 0
s_dk_fmt_warn  db "All files will be erased!", 0
s_dk_fmt_warn_short db "All files erased!", 0
s_dk_prev db "<", 0
s_dk_next db ">", 0
s_dk_cancel    db "Cancel", 0
s_dk_m7        db "Format error", 0
s_dk_m8        db "Disk formatted", 0
s_dk_m9        db "Only virtual disks", 0

; FSM3 inspection statuses on selected disk (read-only).
s_dk_m11 db "Disk ready", 0
s_dk_m12 db "Disk ready", 0
s_dk_m13 db "Disk error", 0
s_dk_m14 db "Disk ready", 0
s_dk_m15 db "Disk error", 0

; Titlebar controls and minimized restore label for Format?
dk_conf_minus_label db "-", 0
dk_conf_close_label db "X", 0
dk_conf_mini_label db "Format", 0
