; FloFile - проводник: диски, файлы, меню Delete, окно ошибки
; Подключается из kernel32.asm (%include)

; FloFile: проводник
files_open:
    cmp byte [d2_files], 0
    jne .r
    mov al, 1
    call z_hide_others
    call splash_start
    mov byte [d2_files], 1
    mov byte [fl_view], 0
    mov byte [fl_scr], 0
    mov byte [fl_disk], 0
    mov byte [fl_sys], 0
    mov byte [fl_par], 0
    mov byte [fl_dep], 0
    mov byte [d2_nm], 0
    mov byte [d2_ctx], 0
    mov byte [d2_fmenu], 0
    call files_list
    call fs_pc_scan
    call wait_end
    jmp redraw
.r: ret

; flopsys из main: FloFile сразу внутри системной папки на диске C
files_open_sys:
    mov al, 1
    call z_hide_others
    call splash_start
    mov byte [d2_files], 1
    mov byte [fl_view], 1
    mov byte [fl_scr], 0
    mov byte [fl_disk], 0
    mov byte [fl_sys], 1
    mov byte [fl_par], 0
    mov byte [fl_dep], 0
    mov byte [d2_nm], 0
    mov byte [d2_ctx], 0
    mov byte [d2_fmenu], 0
    call files_list
    call fs_pc_scan
    call wait_end
    jmp redraw

files_close:
    mov byte [d2_files], 0
    mov byte [d2_nm], 0
    mov byte [d2_fmenu], 0
    mov byte [d2_ctx], 0
    mov al, 1
    call z_restore
    jmp redraw

; Список файлов выбранного диска
files_list:
    pushad
    mov al, [fl_par]
    mov [fs_par], al
    movzx eax, byte [fl_disk]
    mov edi, fl_names
    call fs_list
    mov esi, lst_ids
    mov edi, fl_ids
    mov ecx, 33
    rep movsb
    mov al, [lst_n]
    mov [fl_cnt], al
    mov al, [lst_st]
    mov [fl_st], al
    cmp byte [fl_sys], 0
    jne .sys
    cmp byte [fl_disk], 0               ; на диске C первой лежит папка flopsys
    jne .e
    cmp byte [fl_par], 0
    jne .e
    cmp byte [fl_st], 0
    jne .e
    cmp byte [fl_cnt], 31
    jae .e
    movzx ecx, byte [fl_cnt]
    jecxz .ni
.si:mov al, [fl_ids + ecx - 1]
    mov [fl_ids + ecx], al
    loop .si
.ni:mov byte [fl_ids], 0
    movzx ecx, byte [fl_cnt]
    shl ecx, 4
    jecxz .nm
    mov esi, fl_names
    add esi, ecx
    dec esi
    mov edi, esi
    add edi, 16
.m: mov al, [esi]
    mov [edi], al
    dec esi
    dec edi
    loop .m
.nm:mov esi, s_system16
    mov edi, fl_names
    call .cp
    inc byte [fl_cnt]
    jmp .e
.sys:
    mov edi, fl_names                   ; внутри flopsys: уровень 1 - корень, 2 - programs
    movzx ebx, byte [fl_sys]
    mov esi, [sys_tab + ebx * 4]
    movzx edx, byte [sys_n + ebx]
    mov [fl_cnt], dl
    mov byte [fl_st], 0
.sl:call .cp
    dec edx
    jnz .sl
.e: popad
    ret
.cp:push edi
    mov ecx, 16
.c1:lodsb
    mov [edi], al
    inc edi
    test al, al
    loopnz .c1
    pop edi
    mov byte [edi + 15], 0
    add edi, 16
    ret

files_draw:
    pushad
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    RECT 0, 0, 800, 600, C_WHITE
    RECT 0, 38, 800, 2, C_BLACK
    mov esi, s_files
    call strlen
    shl ecx, 4
    mov eax, 800
    sub eax, ecx
    shr eax, 1
    mov [t_x], eax
    mov dword [t_y], 2
    mov dword [r_c], C_BLACK
    call draw_big
    RECT 0, 78, 800, 2, C_BLACK
    cmp byte [d2_fmenu], 0
    je .fm0
    RECT 4, 40, 80, 36, C_BLACK
    mov dword [r_c], C_WHITE
    jmp .fm1
.fm0:
    mov dword [r_c], C_BLACK
.fm1:
    mov dword [t_x], 12
    mov dword [t_y], 44
    mov esi, s_file
    call draw_big
    cmp byte [fl_view], 0
    jne .v1
    xor ebp, ebp
.pc:imul ebx, ebp, DT_ESZ              ; карточка только у существующих дисков
    cmp byte [dtab + ebx], 0
    je .pn
    call pc_card
.pn:inc ebp
    cmp ebp, DT_N
    jb .pc
    jmp .menu
.v1:
    movzx ebx, byte [fl_disk]
    imul ebx, DT_ESZ
    mov al, [dtab + ebx]
    mov [s_dk + 5], al
    mov [s_dkf + 5], al
    mov [s_dkp + 5], al
    mov [s_dke + 5], al
    movzx ebx, byte [fl_sys]
    mov esi, [ttl_tab + ebx * 4]
    test ebx, ebx
    jnz .tt
    cmp byte [fl_dep], 0
    je .tt
    mov esi, fl_path
    call strlen
    cmp ecx, 36
    jbe .tt
    sub ecx, 36
    add esi, ecx
.tt:mov dword [t_x], 24
    mov dword [t_y], 92
    mov dword [r_c], C_BLACK
    call draw_big
    mov eax, 632
    mov ebx, 42
    mov ecx, 164
    mov edx, 36
    mov esi, s_back
    xor edi, edi
    call wbtn
    xor ebp, ebp
.ro:movzx eax, byte [fl_scr]
    add eax, ebp
    movzx ebx, byte [fl_cnt]
    cmp eax, ebx
    jae .none
    shl eax, 4
    lea esi, [fl_names + eax]
    jmp .draw
.none:
    test ebp, ebp
    jnz .next
    mov esi, st_empty
    cmp byte [fl_st], 1
    jne .s2
    mov esi, st_nodisk
.s2:cmp byte [fl_st], 2
    jne .draw
    mov esi, st_nofs
.draw:
    mov dword [t_x], 12
    mov eax, ebp
    shl eax, 5
    add eax, 130
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    call draw_big
.next:
    inc ebp
    cmp ebp, 14
    jb .ro
    cmp byte [fl_cnt], 14
    jbe .menu
    mov eax, 778
    mov ebx, 130
    mov ecx, 448
    xor edx, edx
    mov esi, 448
    mov dword [sb_w], 20
    movzx edi, byte [fl_cnt]
    shl edi, 5
    movzx ebp, byte [fl_scr]
    shl ebp, 5
    call sbar
    mov dword [sb_w], 16
.menu:
    cmp byte [d2_fmenu], 0
    je .fe
    RECT 8, 84, 120, 88, C_BLACK
    RECT 4, 80, 120, 88, C_BLACK
    RECT 6, 82, 116, 84, C_WHITE
    RECT 6, 124, 116, 2, C_BLACK
    mov dword [r_c], C_BLACK
    mov dword [t_x], 12
    mov dword [t_y], 86
    mov esi, s_dk_t
    call draw_big
    mov dword [t_y], 130
    mov esi, s_exit
    call draw_big
.fe:cmp byte [d2_ctx], 0
    je .fn
    call ctx_draw
.fn:cmp byte [d2_nm], 0
    je .e
    call nm_draw
.e: popad
    ret

; Карточка диска ebp на экране "This PC": имя, полоска занятого места. Карточки по две в ряд
pc_card:
    pushad
    mov eax, ebp
    shr eax, 1
    imul eax, 120
    add eax, 96
    mov [pc_y], eax
    mov eax, ebp
    and eax, 1
    imul eax, 382
    add eax, 24
    mov [pc_cx], eax
    RECTM [pc_cx], [pc_y], 370, 112, C_BLACK
    mov eax, [pc_y]
    add eax, 2
    mov [pc_y2], eax
    mov eax, [pc_cx]
    add eax, 2
    mov [pc_x], eax
    RECTM [pc_x], [pc_y2], 366, 108, C_WHITE
    imul ebx, ebp, DT_ESZ
    mov al, [dtab + ebx]
    mov [s_dk + 5], al
    mov eax, [pc_cx]
    add eax, 16
    mov [t_x], eax
    mov eax, [pc_y]
    add eax, 12
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_dk
    call draw_big
    mov al, [pc_st + ebp]
    test al, al
    jz .ok
    mov esi, s_nodisk2
    cmp al, 1
    je .msg
    mov esi, s_nofmt2
.msg:
    mov eax, [pc_cx]
    add eax, 16
    mov [t_x], eax
    mov eax, [pc_y]
    add eax, 60
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    call draw_big
    jmp .r
.ok:
    mov eax, [pc_y]                     ; полоска: рамка 2 пикселя, внутри чёрным занятое
    add eax, 56
    mov [pc_y2], eax
    mov eax, [pc_cx]
    add eax, 16
    mov [pc_x], eax
    RECTM [pc_x], [pc_y2], 338, 40, C_BLACK
    mov eax, [pc_y]
    add eax, 58
    mov [pc_y2], eax
    mov eax, [pc_cx]
    add eax, 18
    mov [pc_x], eax
    RECTM [pc_x], [pc_y2], 334, 36, C_WHITE
    mov ecx, [pc_tot + ebp * 4]
    test ecx, ecx
    jz .r
    mov eax, ecx
    sub eax, [pc_free + ebp * 4]
    mov esi, eax                        ; занято
    imul eax, 334
    xor edx, edx
    div ecx
    test eax, eax
    jz .nf
    mov [pc_w], eax
    RECTM [pc_x], [pc_y2], [pc_w], 36, C_BLACK
.nf:
    mov ecx, [pc_tot + ebp * 4]
    mov eax, esi
    imul eax, 100
    xor edx, edx
    div ecx
    mov edi, pc_buf
    call u32str
    mov byte [edi], '%'
    mov byte [edi + 1], 0
    mov esi, pc_buf
    call strlen
    shl ecx, 3
    mov eax, [pc_cx]
    add eax, 185
    sub eax, ecx
    sub eax, 8
    mov [pc_x], eax
    shl ecx, 1
    add ecx, 16
    mov [pc_w], ecx
    RECTM [pc_x], [pc_y2], [pc_w], 36, C_WHITE
    mov eax, [pc_x]
    add eax, 8
    mov [t_x], eax
    mov eax, [pc_y2]
    add eax, 2
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, pc_buf
    call draw_big
.r: popad
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

; Что под мышью в Files: 27 File, 28 Exit, 36 Disks, 150..157 карточки дисков, 29 Back, 80..93 строки,
; 95 Delete (меню у файла), 96 - мимо меню
files_hit:
    cmp byte [d2_nm], 0
    jne nm_hit
    mov esi, [m_x]
    mov edi, [m_y]
    cmp byte [d2_ctx], 0
    je .nc
    mov edx, 39                         ; высота меню - 1
    cmp byte [d2_ctx], 3
    je .tl
    cmp byte [d2_ctx], 1
    jne .hh
    cmp byte [ctx_m], 0
    jne .hh
.tl:mov edx, 79
.hh:mov eax, [ctx_x]
    cmp esi, eax
    jb .cx
    add eax, 112
    cmp esi, eax
    ja .cx
    mov eax, [ctx_y]
    cmp edi, eax
    jb .cx
    add eax, edx
    cmp edi, eax
    ja .cx
    mov eax, edi
    sub eax, [ctx_y]
    xor ecx, ecx
    cmp eax, 40
    jb .sl
    mov ecx, 1                          ; вторая кнопка
.sl:cmp byte [d2_ctx], 2
    jne .c3
    mov al, 97
    ret
.c3:cmp byte [d2_ctx], 3
    jne .c1
    mov al, 190
    add al, cl
    ret
.c1:mov al, 95                          ; меню файла: Rename сверху, Delete снизу
    cmp byte [ctx_m], 0
    jne .c1r
    test ecx, ecx
    jnz .c1r
    mov al, 94
.c1r:
    ret
.cx:mov al, 96
    ret
.nc:cmp byte [d2_fmenu], 0
    je .nm
    cmp esi, 4
    jb .nm
    cmp esi, 124
    ja .nm
    cmp edi, 80
    jb .nm
    cmp edi, 123
    ja .m2
    mov al, 36
    ret
.m2:cmp edi, 168
    ja .nm
    mov al, 28
    ret
.nm:cmp esi, 4
    jb .v
    cmp esi, 84
    ja .v
    cmp edi, 40
    jb .v
    cmp edi, 76
    ja .v
    mov al, 27
    ret
.v: cmp byte [fl_view], 0
    jne .v1
    mov eax, edi                        ; карточки: 2 в ряд, ряд 120, колонка 382
    sub eax, 96
    jl .z
    cmp eax, 480
    jae .z
    xor edx, edx
    mov ecx, 120
    div ecx
    cmp edx, 112
    jae .z
    mov ebx, eax                        ; ряд
    mov eax, esi
    sub eax, 24
    jl .z
    xor edx, edx
    mov ecx, 382
    div ecx
    cmp eax, 1
    ja .z
    cmp edx, 370
    jae .z
    lea eax, [eax + ebx * 2]            ; номер диска
    imul edx, eax, DT_ESZ
    cmp byte [dtab + edx], 0
    je .z
    add al, 150
    ret
.v1:cmp esi, 632
    jb .r1
    cmp esi, 796
    ja .r1
    cmp edi, 42
    jb .r1
    cmp edi, 78
    ja .r1
    mov al, 29
    ret
.r1:cmp esi, 778
    jb .r2
    cmp byte [fl_cnt], 14
    jbe .r2
    cmp edi, 130
    jb .r2
    cmp edi, 578
    jae .r2
    mov al, 99
    ret
.r2:mov eax, edi
    sub eax, 130
    jl .z
    cmp eax, 448
    jae .z
    shr eax, 5
    add al, 80
    ret
.z: xor al, al
    ret

; Нажали мышью в Files: al - что
files_press:
    cmp byte [d2_nm], 0
    jne nm_press
    cmp al, 99
    jne .nb99
    mov byte [sb_drag], 17
    mov byte [sb_ctx], 3
    call sb_grab
    cmp byte [sb_drag], 0
    je .r99
    call sb_set
.r99:ret
.nb99:
    cmp al, 94
    jne .n94
    mov al, 3
    jmp nm_open
.n94:cmp al, 97
    jne .n97
    mov byte [d2_ctx], 3
    jmp redraw
.n97:cmp al, 190
    jb .n19
    cmp al, 191
    ja .n19
    sub al, 189
    jmp nm_open
.n19:
    cmp al, 96
    jne .f0
    mov byte [d2_ctx], 0
    jmp redraw
.f0:cmp al, 95
    jne .f1
    jmp files_delete
.f1:cmp al, 27
    jne .f2
    xor byte [d2_fmenu], 1
    jmp files_draw
.f2:cmp al, 28
    jne .f3
    jmp files_close
.f3:cmp al, 36
    jne .f4
    mov byte [d2_fmenu], 0
    jmp dk_open
.f4:cmp al, 150
    jb .f5
    cmp al, 157
    ja .f5
    sub al, 150
    mov [fl_disk], al
    mov byte [fl_view], 1
    mov byte [fl_scr], 0
    mov byte [fl_sys], 0
    mov byte [fl_par], 0
    mov byte [fl_dep], 0
    mov byte [d2_fmenu], 0
    call wait_start
    call files_list
    call wait_end
    jmp files_draw
.f5:cmp al, 29
    jne .f6
    mov byte [d2_fmenu], 0
    mov byte [fl_scr], 0
    cmp byte [fl_sys], 0
    je .fb0
    cmp byte [fl_sys], 1
    jbe .fu0
    mov byte [fl_sys], 1                ; из programs - в flopsys
    jmp .fu1
.fu0:
    mov byte [fl_sys], 0                ; из flopsys - в список диска
.fu1:
    call wait_start
    call files_list
    call wait_end
    jmp files_draw
.fb0:
    cmp byte [fl_dep], 0
    je .fb1
    call fl_up
    jmp .fu1
.fb1:
    mov byte [fl_view], 0
    call wait_start
    call fs_pc_scan
    call wait_end
    jmp files_draw
.f6:cmp al, 80
    jb .f7
    cmp al, 93
    ja .f7
    mov byte [d2_fmenu], 0
    sub al, 80
    add al, [fl_scr]
    cmp al, [fl_cnt]
    jae files_draw
    cmp byte [fl_sys], 0
    jne sys_row                         ; строка в системной папке
    cmp byte [fl_disk], 0
    jne .fr2
    cmp byte [fl_st], 0
    jne .fr2
    cmp byte [fl_par], 0
    jne .fr2
    test al, al
    jnz .fr2
    mov byte [fl_sys], 1                ; первая запись на диске C - папка flopsys
    mov byte [fl_scr], 0
    call wait_start
    call files_list
    call wait_end
    jmp files_draw
.fr2:
    movzx esi, al
    shl esi, 4
    cmp byte [fl_names + esi + 15], 1
    jne .nfo
    call fl_enter                       ; папка: войти
    call wait_start
    call files_list
    call wait_end
    jmp files_draw
.nfo:
    add esi, fl_names
    mov dl, [fl_par]
    mov [fs_par], dl
    mov al, [fl_disk]
    call is_pcf
    jc .pcf
    jmp text_open_named
.pcf:
    jmp paint_open_named
.f7:cmp byte [d2_fmenu], 0
    je .r
    mov byte [d2_fmenu], 0
    jmp files_draw
.r: ret

; Нажали на строку al в системной папке: папки открываются, программы запускаются, ошибки показываются
sys_row:
    movzx ebx, al
    movzx eax, byte [fl_sys]
    cmp eax, 2
    je .prog
    ja files_draw
    cmp ebx, 1                          ; flopsys: only programs is a subfolder
    jae files_draw
    lea eax, [ebx + 2]
    mov [fl_sys], al
    mov byte [fl_scr], 0
    call wait_start
    call files_list
    call wait_end
    jmp files_draw
.prog:
    test ebx, ebx
    jnz .p1
    jmp text_open                       ; FloText.sys
.p1:cmp ebx, 1
    je files_draw                       ; FloFile.sys: он уже открыт
    cmp ebx, 2
    jne .p3
    jmp calc_open                       ; FloCalc.sys: калькулятор поверх FloFile
.p3:cmp ebx, 4
    jne .p4
    jmp paint_open                      ; FloPaint.sys
.p4:cmp byte [d2_tm], 0                 ; FloTasks.sys
    jne files_draw
    jmp tm_toggle

; Стрелки вверх (0x90) и вниз (0x91) в Files и Esc
files_key:
    cmp byte [d2_nm], 0
    jne nm_key
    cmp al, 27
    jne .a
    cmp byte [d2_ctx], 0
    je .m
    mov byte [d2_ctx], 0
    jmp redraw
.m: cmp byte [d2_fmenu], 0
    je .c
    mov byte [d2_fmenu], 0
    jmp files_draw
.c: jmp files_close
.a: cmp byte [fl_view], 0
    je .r
    cmp al, 0x90
    jne .d
    cmp byte [fl_scr], 0
    je .r
    dec byte [fl_scr]
    jmp files_draw
.d: cmp al, 0x91
    jne .r
    mov al, [fl_scr]
    add al, 14
    cmp al, [fl_cnt]
    jae .r
    inc byte [fl_scr]
    jmp files_draw
.r: ret

; Правая кнопка в Files: на файле - Rename и Delete, на пустом месте - Create
files_rclick:
    cmp byte [d2_nm], 0
    jne .r
    cmp byte [d2_ctx], 0
    je .a
    mov byte [d2_ctx], 0
    jmp redraw
.a: cmp byte [fl_view], 0
    je .r
    mov al, [t_id]
    cmp al, 80
    jb .em
    cmp al, 93
    ja .em
    sub al, 80
    add al, [fl_scr]
    cmp al, [fl_cnt]
    jae .em
    mov byte [ctx_m], 0
    cmp byte [fl_disk], 0
    jne .nsy
    cmp byte [fl_sys], 0
    jne .sy
    cmp byte [fl_par], 0
    jne .nsy
    cmp byte [fl_st], 0
    jne .nsy
    test al, al
    jnz .nsy
.sy:mov byte [ctx_m], 2                 ; flopsys и системные файлы: удалять нельзя
.nsy:
    mov [ctx_i], al
    mov byte [d2_ctx], 1
    jmp .pos
.em:cmp byte [fl_sys], 0                ; пустое место: меню Create
    jne .r
    cmp byte [fl_st], 0
    jne .r
    cmp byte [d2_fmenu], 0
    jne .r
    mov al, [t_id]
    test al, al
    jz .e2
    cmp al, 80
    jb .r
    cmp al, 93
    ja .r
.e2:mov byte [d2_ctx], 2
.pos:
    mov eax, [m_x]
    cmp eax, 680
    jbe .x
    mov eax, 680
.x: mov [ctx_x], eax
    mov eax, [m_y]
    cmp eax, 510
    jbe .y
    mov eax, 510
.y: mov [ctx_y], eax
    jmp ctx_draw
.r: ret

; Меню: у файла (Rename, Delete), на пустом месте (Create), выбор Folder / Text
ctx_draw:
    pushad
    cmp byte [d2_ctx], 1
    jne .nf
    movzx eax, byte [ctx_i]
    movzx ebx, byte [fl_scr]
    sub eax, ebx
    shl eax, 5
    add eax, 130
    mov [pc_y], eax
    movzx esi, byte [ctx_i]
    shl esi, 4
    add esi, fl_names
    call strlen
    shl ecx, 4
    add ecx, 12
    mov [pc_w], ecx
    RECTM 6, [pc_y], [pc_w], 2, C_BLACK
    mov eax, [pc_y]
    add eax, 30
    mov [pc_y2], eax
    RECTM 6, [pc_y2], [pc_w], 2, C_BLACK
    RECTM 6, [pc_y], 2, 32, C_BLACK
    mov eax, [pc_w]
    add eax, 4
    mov [pc_x], eax
    RECTM [pc_x], [pc_y], 2, 32, C_BLACK
.nf:mov dword [pc_h], 40
    cmp byte [d2_ctx], 3
    je .tall
    cmp byte [d2_ctx], 1
    jne .h
    cmp byte [ctx_m], 0
    jne .h
.tall:
    mov dword [pc_h], 80
.h: mov eax, [ctx_x]
    add eax, 4
    mov [pc_x], eax
    mov eax, [ctx_y]
    add eax, 4
    mov [pc_y2], eax
    RECTM [pc_x], [pc_y2], 112, [pc_h], C_BLACK
    mov eax, [ctx_x]
    mov [cw_x], eax
    mov eax, [ctx_y]
    mov [cw_y], eax
    xor eax, eax
    xor ebx, ebx
    mov ecx, 112
    mov edx, 40
    xor edi, edi
    cmp byte [d2_ctx], 2
    je .cr
    cmp byte [d2_ctx], 3
    je .sb
    cmp byte [ctx_m], 0
    jne .dl
    mov esi, s_rename
    call wbtn
    mov ebx, 40
.dl:mov esi, s_delete
    call wbtn
    jmp .e
.cr:mov esi, s_create
    call wbtn
    jmp .e
.sb:mov esi, s_folder
    call wbtn
    mov ebx, 40
    mov esi, s_text
    call wbtn
.e: popad
    ret

; Нажали Delete
files_delete:
    mov byte [d2_ctx], 0
    cmp byte [ctx_m], 0
    je .fl
    mov byte [d2_err], 0x31                ; системная папка
    movzx eax, byte [fl_sys]
    test eax, eax
    jz .se
    mov byte [d2_err], 0x33                ; системный файл
    cmp eax, 2
    jne .n2
    mov byte [d2_err], 0x32                ; программа
    jmp .se
.n2:cmp eax, 1
    jne .se
    cmp byte [ctx_i], 1
    jae .se
    mov byte [d2_err], 0x31                ; programs - папки
.se:jmp redraw
.fl:mov al, [fl_disk]
    call fs_setdisk
    jc .e
    mov al, [fl_par]
    mov [fs_par], al
    movzx edx, byte [ctx_i]
    movzx eax, byte [fl_ids + edx]
    shl edx, 4
    lea esi, [fl_names + edx]
    cmp byte [esi + 15], 1
    jne .del
    call dir_has_child                  ; папку с файлами удалять нельзя
    jnc .del
    mov byte [d2_err], 0x35
    jmp redraw
.del:
    call file_delete
.e: call files_list
    jmp redraw

; Войти в папку - строка al
fl_enter:
    pushad
    movzx edx, al
    movzx ebx, byte [fl_dep]
    cmp ebx, 4
    jae .r
    mov al, [fl_par]
    mov [fl_stk + ebx], al
    test ebx, ebx
    jnz .have
    mov esi, s_dk
    mov edi, fl_path
.c0:lodsb
    stosb
    test al, al
    jnz .c0
.have:
    mov edi, fl_path
.fe:cmp byte [edi], 0
    je .fz
    inc edi
    jmp .fe
.fz:mov eax, edi
    sub eax, fl_path
    mov [fl_pl + ebx], al
    mov byte [edi], '/'
    inc edi
    mov esi, edx
    shl esi, 4
    add esi, fl_names
.cn:lodsb
    stosb
    test al, al
    jnz .cn
    movzx eax, byte [fl_ids + edx]
    mov [fl_par], al
    inc byte [fl_dep]
    mov byte [fl_scr], 0
.r: popad
    ret

; Выйти из папки на уровень выше
fl_up:
    pushad
    movzx ebx, byte [fl_dep]
    dec ebx
    mov [fl_dep], bl
    mov al, [fl_stk + ebx]
    mov [fl_par], al
    movzx eax, byte [fl_pl + ebx]
    mov byte [fl_path + eax], 0
    popad
    ret

; Окно ввода имени: al = 1 папка, 2 текстовый документ, 3 переименование
nm_open:
    pushad
    mov [d2_nm], al
    mov byte [d2_ctx], 0
    mov byte [dl_len], 0
    mov byte [dl_car], 0
    mov byte [dl_anc], 0xFF
    mov byte [dl_name], 0
    mov byte [dl_app], 0
    mov byte [sel_drag], 0
    mov byte [dl_nohint], 1             ; подсказка .txt только у нового текста
    cmp al, 2
    jne .n2
    mov byte [dl_nohint], 0
.n2:cmp al, 3
    jne .go
    movzx esi, byte [ctx_i]
    shl esi, 4
    add esi, fl_names
    xor ecx, ecx
.cp:mov al, [esi + ecx]
    test al, al
    jz .ce
    mov [dl_name + ecx], al
    inc ecx
    jmp .cp
.ce:mov byte [dl_name + ecx], 0
    mov [dl_len], cl
    mov [dl_car], cl
.go:popad
    jmp redraw

nm_close:
    mov byte [d2_nm], 0
    jmp redraw

nm_hit:
    mov esi, [m_x]
    mov edi, [m_y]
    cmp edi, 266
    jb .z
    cmp edi, 302
    jbe .f
    cmp edi, 328
    jb .z
    cmp edi, 372
    ja .z
    cmp esi, 224
    jb .z
    cmp esi, 384
    jbe .ok
    cmp esi, 416
    jb .z
    cmp esi, 576
    ja .z
    mov al, 193
    ret
.f: cmp esi, 224                        ; поле имени
    jb .z
    cmp esi, 576
    ja .z
    mov al, 47
    ret
.ok:mov al, 192
    ret
.z: mov al, 96
    ret

; CF = в набранном имени есть точка
nm_dot:
    push ebx
    xor ebx, ebx
.l: cmp bl, [dl_len]
    jae .n
    cmp byte [dl_name + ebx], '.'
    je .y
    inc ebx
    jmp .l
.y: pop ebx
    stc
    ret
.n: pop ebx
    clc
    ret

nm_press:
    cmp al, 47
    jne .a
    push dword [qx0]                    ; поле имени: поставить палку, начать выделять
    mov dword [qx0], 220
    call dlg_mcell
    pop dword [qx0]
    mov [dl_car], al
    mov [dl_anc], al
    mov byte [sel_drag], 2
    jmp nm_input
.a: cmp al, 192
    jne .c
    jmp nm_commit
.c: cmp al, 193
    jne .r
    jmp nm_close
.r: ret

; Клавиши в окне имени: Esc и Enter тут, остальное (выделение, Ctrl+A/C/X/V) - как в окне Save to
nm_key:
    cmp al, 27
    je nm_close
    cmp al, 13
    je nm_commit
    jmp dlg_key

; Готово: создать папку / текст или переименовать
nm_commit:
    pushad
    cmp byte [dl_len], 0
    je .r
    mov esi, dl_name
    mov edi, nm_full
    mov ecx, 14                         ; с точкой - имя как набрано
    call nm_dot
    jc .c
    cmp byte [d2_nm], 2                 ; текст без точки - дописываем .txt
    jne .c
    mov ecx, 10
.c: lodsb
    test al, al
    jz .ce
    stosb
    loop .c
.ce:cmp byte [d2_nm], 2
    jne .z
    call nm_dot
    jc .z
    mov esi, s_txt
.x: lodsb
    stosb
    test al, al
    jnz .x
    jmp .z2
.z: mov byte [edi], 0
.z2:
    mov al, [fl_disk]
    call fs_setdisk
    jc .e7
    mov al, [fl_par]
    mov [fs_par], al
    cmp byte [d2_nm], 3
    je .ren
    mov esi, nm_full                    ; такое имя уже есть?
    call dir_find
    jnc .e5
    cmp byte [d2_nm], 2
    je .txt
    mov esi, nm_full
    call dir_mkdir
    jc .e7
    jmp .ok
.txt:
    mov esi, nm_full
    xor ecx, ecx
    call file_write
    jc .e7
    jmp .ok
.ren:
    movzx esi, byte [ctx_i]
    shl esi, 4
    add esi, fl_names
    mov edx, nm_full
    call dir_rename
    jc .e5
.ok:mov byte [d2_nm], 0
    call files_list
    popad
    jmp redraw
.e5:mov byte [d2_nm], 0
    mov byte [d2_err], 0x34
    popad
    jmp redraw
.e7:mov byte [d2_nm], 0
    mov byte [d2_err], 0x43
    popad
    jmp redraw
.r: popad
    ret

nm_draw:
    pushad
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    RECT 208, 208, 400, 200, C_BLACK
    RECT 200, 200, 400, 200, C_BLACK
    RECT 202, 202, 396, 196, C_WHITE
    RECT 202, 240, 396, 2, C_BLACK
    movzx ebx, byte [d2_nm]
    mov esi, [nm_ttl_tab + ebx * 4 - 4]
    call strlen
    shl ecx, 4
    mov eax, 800
    sub eax, ecx
    shr eax, 1
    mov [t_x], eax
    mov dword [t_y], 206
    mov dword [r_c], C_BLACK
    call draw_big
    call nm_input
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    mov eax, 224
    mov ebx, 328
    mov ecx, 160
    mov edx, 44
    mov esi, s_ok
    xor edi, edi
    call wbtn
    mov eax, 416
    mov esi, s_cancel
    call wbtn
    popad
    ret

; Поле ввода - то же, что в окне Save to (выделение, палочка, копирование), только на другом месте
nm_input:
    pushad
    push dword [qx0]
    push dword [qy0]
    push dword [dlg_w]
    mov dword [qx0], 220
    mov dword [qy0], 182
    mov dword [dlg_w], 360
    call dlg_name_draw
    pop dword [dlg_w]
    pop dword [qy0]
    pop dword [qx0]
    popad
    ret

; окно ошибки
; Old exported renderer is no longer used: error UI is in kernel.
err_draw:
    ret

; данные FloFile
d2_files    db 0
fl_view     db 0
fl_scr      db 0
fl_sbo      dd 0
fl_disk     db 0
fl_sys      db 0
fl_cnt      db 0
fl_st       db 0
d2_fmenu    db 0
d2_ctx      db 0
ctx_m       db 0
ctx_i       db 0
d2_err      db 0
ctx_x       dd 0
ctx_y       dd 0
pc_y        dd 0
pc_y2       dd 0
pc_x        dd 0
pc_cx       dd 0
pc_w        dd 0
pc_buf      times 8 db 0
fl_names    times 33 * 16 db 0
fl_ids      times 34 db 0
fl_par      db 0                        ; номер открытой папки (0 - корень диска)
fl_dep      db 0                        ; на сколько папок вглубь зашли
fl_stk      times 5 db 0
fl_pl       times 5 db 0
fl_path     times 80 db 0
d2_nm       db 0                        ; окно имени: 0 нет, 1 папка, 2 текст, 3 переименовать
nm_full     times 24 db 0
nm_ext      dd 0
pc_h        dd 0
e_l1        dd 0
e_l2        dd 0
s_files     db "FloFile", 0
s_dk        db "Disk X", 0
s_dkf       db "Disk X/flopsys", 0
s_dkp       db "Disk X/flopsys/programs", 0
ttl_tab     dd s_dk, s_dkf, s_dkp, s_dkp
sys_tab     dd 0, sys_l1, sys_l2, sys_l1
sys_n       db 0, 1, 5, 0
sys_l1      db "programs", 0
sys_l2      db "FloText.sys", 0, "FloFile.sys", 0, "FloCalc.sys", 0, "FloTasks.sys", 0, "FloPaint.sys", 0
s_dk_t      db "Disks", 0
s_back      db "Back", 0
s_nodisk2   db "No disk", 0
s_nofmt2    db "Not formatted", 0
st_empty    db "(empty)", 0
st_nodisk   db "no disk", 0
st_nofs     db "not formatted", 0
s_system16  db "flopsys", 0
s_txt       db ".txt", 0
s_delete    db "Delete", 0
s_rename    db "Rename", 0
s_create    db "Create", 0
s_folder    db "Folder", 0
s_text      db "Text", 0
s_nt1       db "New folder", 0
s_nt2       db "New text", 0
s_nt3       db "Rename", 0
nm_ttl_tab  dd s_nt1, s_nt2, s_nt3
s_ok        db "OK", 0
