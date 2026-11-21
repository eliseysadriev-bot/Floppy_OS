; Общие кусочки ядра (раньше лежали в калькуляторе): strlen, кнопка wbtn, строки

; Длина строки esi -> ecx (esi не меняется)
strlen:
    push esi
    call ui_tr
    xor ecx, ecx
.l: cmp byte [esi], 0
    je .e
    inc esi
    inc ecx
    jmp .l
.e: pop esi
    ret

; Кнопка: eax, ebx - угол от точки cw_x, cw_y, ecx - ширина, edx - высота, esi - надпись, edi = 1 - нажата (чёрная)
wbtn:
    pushad
    mov [wb_x], eax
    mov [wb_y], ebx
    mov [wb_w], ecx
    mov [wb_h], edx
    mov [wb_s], esi
    mov [wb_i], edi
    add eax, [cw_x]
    mov [r_x], eax
    add ebx, [cw_y]
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    mov dword [r_c], C_BLACK
    call fill_rect
    mov dword [wb_c], C_WHITE
    cmp dword [wb_i], 0
    jne .t
    mov eax, [wb_x]
    add eax, [cw_x]
    add eax, 2
    mov [r_x], eax
    mov eax, [wb_y]
    add eax, [cw_y]
    add eax, 2
    mov [r_y], eax
    mov eax, [wb_w]
    sub eax, 4
    mov [r_w], eax
    mov eax, [wb_h]
    sub eax, 4
    mov [r_h], eax
    mov dword [r_c], C_WHITE
    call fill_rect
    mov dword [wb_c], C_BLACK
.t: mov esi, [wb_s]
    call strlen
    shl ecx, 4
    mov eax, [wb_w]
    sub eax, ecx
    shr eax, 1
    add eax, [wb_x]
    add eax, [cw_x]
    mov [t_x], eax
    mov eax, [wb_h]
    sub eax, 32
    shr eax, 1
    add eax, [wb_y]
    add eax, [cw_y]
    mov [t_y], eax
    mov eax, [wb_c]
    mov [r_c], eax
    mov esi, [wb_s]
    call draw_big
    popad
    ret

wb_x dd 0
wb_y dd 0
wb_w dd 0
wb_h dd 0
wb_s dd 0
wb_i dd 0
wb_c dd 0
s_file           db "File", 0
s_exit           db "Exit", 0
s_flocalc        db "FloCalc", 0

; FloText: файлы
; Заголовок: "FloText" или диск:имя
make_title:
    pushad
    mov edi, t2_title
    cmp byte [t2_dsk], 0xFF
    jne .f
    mov byte [edi], 0                   ; файла нет - слева в заголовке пусто
    popad
    ret
.f: mov esi, t2_nm                      ; только имя: без диска и без расширения
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
    mov edi, ebx                        ; обрезаем ".txt" / ".pcf"
.z: mov byte [edi], 0
    popad
    ret

; Имя esi + ".txt" -> fn_buf
mkname:
    push edx
    mov edx, s_txt
    call mkname_x
    pop edx
    ret

; То же с ".pcf" (картинки FloPaint)
mkname_p:
    push edx
    mov edx, s_pcf
    call mkname_x
    pop edx
    ret

; То же с ".sga" (документы itge)
mkname_s:
    push edx
    mov edx, s_sga
    call mkname_x
    pop edx
    ret

mkname_x:
    pushad
    mov edi, fn_buf
    xor ebx, ebx                        ; ebx = 1, если в имени есть точка
    push esi
.s: mov al, [esi]
    test al, al
    jz .sd
    cmp al, '.'
    jne .sn
    mov ebx, 1
.sn:inc esi
    jmp .s
.sd:pop esi
    mov ecx, 14                         ; с точкой - имя как набрано, без неё - дописываем расширение edx
    test ebx, ebx
    jnz .c
    mov ecx, 10
.c: lodsb
    test al, al
    jz .e
    stosb
    loop .c
.e: test ebx, ebx
    jnz .z
    mov esi, edx
.x: lodsb
    stosb
    test al, al
    jnz .x
    jmp .d
.z: mov byte [edi], 0
.d: popad
    ret


s_tx_title       db "FloText", 0
s_m_save         db "Save", 0
s_m_saveto       db "Save to...", 0
s_m_open         db "Open...", 0

; курсор-палочка
cur_ibeam_k dd 0x3FFF0000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x00C00000, 0x3FFF0000
cur_ibeam_w dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
cur_ibeam_s dd 0x0000C000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x00300000, 0x0000C000

; Буква диска ebx (номер) -> al
dt_letter:
    imul ebx, DT_ESZ
    mov al, [dtab + ebx]
    ret

pe_s        dd 0
s_pcf       db ".pcf", 0
s_sga       db ".sga", 0

; Курсор-квадрат ластика: рамка размером с кисть (чёрная, внутри белая), точка смещена на середину
pa_eraser_cur:
    pushad
    movzx eax, byte [pa_size]
    inc eax
    shr eax, 1
    cmp eax, 1
    jae .a
    mov eax, 1
.a: cmp eax, 16
    jbe .b
    mov eax, 16
.b: mov [pe_s], eax
    neg eax
    mov [cu_info + 7 * 24 + 4], eax
    mov [cu_info + 7 * 24 + 8], eax
    mov edi, cu_dyn
    mov ecx, 51
    xor eax, eax
    cld
    rep stosd
    xor ebx, ebx
.r: cmp ebx, [pe_s]
    jae .d
    mov edx, [pe_s]
    dec edx                             ; последний номер
    xor ecx, ecx
    cmp ebx, 0
    je .full
    cmp ebx, edx
    je .full
    push edx
    xor edx, edx
    call pe_mask                        ; левая клетка (ecx = 0)
    pop edx
    mov esi, eax
    mov ecx, edx
    call pe_mask                        ; правая клетка (ecx = edx)
    or esi, eax
    jmp .sk
.full:
    call pe_mask                        ; ecx = 0, edx = последний
    mov esi, eax
.sk:mov [cu_dyn + ebx * 4], esi
    cmp dword [pe_s], 3
    jb .nx
    mov edx, [pe_s]
    sub edx, 2                          ; внутренний квадрат 1..s-2
    cmp ebx, 1
    jb .nx
    cmp ebx, edx
    ja .nx
    mov ecx, 1
    je .wf
    cmp ebx, 1
    je .wf
    push edx
    mov edx, 1
    call pe_mask                        ; только левая клетка внутреннего квадрата
    pop edx
    mov esi, eax
    mov ecx, edx
    call pe_mask                        ; и правая
    or esi, eax
    jmp .ws
.wf:mov ecx, 1
    call pe_mask
    mov esi, eax
.ws:mov [cu_dyn + 68 + ebx * 4], esi
.nx:inc ebx
    jmp .r
.d: popad
    ret

; Маска клеток курсора от ecx до edx (по 2 бита на клетку); ecx = начало, edx = конец; eax = маска, ecx не меняется
pe_mask:
    push ecx
    push esi
    xor eax, eax
.l: cmp ecx, edx
    ja .e
    mov esi, 3
    push ecx
    add ecx, ecx
    neg ecx
    add ecx, 30
    shl esi, cl
    pop ecx
    or eax, esi
    inc ecx
    jmp .l
.e: pop esi
    pop ecx
    ret


; eax -> десятичные цифры в [edi], edi вперёд
u32str:
    push eax
    push ebx
    push ecx
    push edx
    mov ebx, 10
    xor ecx, ecx
.l: xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .l
.o: pop eax
    add al, '0'
    stosb
    loop .o
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

s_files     db "FloFile", 0
s_dk_t      db "Disks", 0
st_empty    db "(empty)", 0
st_nodisk   db "no disk", 0
st_nofs     db "not formatted", 0
s_txt       db ".txt", 0
s_ok        db "OK", 0
