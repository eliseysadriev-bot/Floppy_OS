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
    mov byte [fl_fs3page], 0
    mov byte [fl_fs3view], 0
    mov word [fl_fs3parent], 0
    mov byte [fl_sel], 0xFF
    call fl_main
    mov [fl_disk], al
    mov byte [fl_insys], 0
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

; flopsys из main: FloFile сразу внутри системной папки на диске C (настоящая папка flopsys)
files_open_sys:
    mov al, 1
    call z_hide_others
    call splash_start
    mov byte [d2_files], 1
    mov byte [fl_view], 1
    mov byte [fl_scr], 0
    mov byte [fl_fs3view], 0
    mov byte [fl_fs3page], 0
    mov word [fl_fs3parent], 0
    mov byte [fl_sel], 0xFF
    call fl_main
    mov [fl_disk], al
    mov byte [fl_insys], 0
    mov byte [fl_par], 0
    mov byte [fl_dep], 0
    mov byte [d2_nm], 0
    mov byte [d2_ctx], 0
    mov byte [d2_fmenu], 0
    xor eax, eax
    call fs_setdisk
    jc .go
    mov byte [fs_par], 0
    mov esi, s_system16
    call dir_find
    jc .go
    call dir_last_id                   ; al = номер папки flopsys
    mov [fl_par], al
    mov byte [fl_stk], 0
    mov byte [fl_pl], 6
    mov byte [fl_dep], 1
    mov byte [fl_insys], 1
    mov esi, s_dk
    mov edi, fl_path
.c0:lodsb
    stosb
    test al, al
    jnz .c0
    dec edi
    mov esi, s_system16
    mov byte [edi], '/'
    inc edi
.c1:lodsb
    stosb
    test al, al
    jnz .c1
.go:call files_list
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
    mov byte [fl_sel], 0xFF             ; после любого обновления списка выделения нет
    ; In the FSM3 preview fs_par is repurposed as a 0..31 page number.
    ; On FSM2 disks it retains the legacy folder ID.
    mov al, [fl_par]
    cmp byte [fl_fs3view], 0
    je .set_folder
    mov al, [fl_fs3page]
.set_folder:
    mov [fs_par], al
    movzx eax, word [fl_fs3parent]
    mov [fs3_folder_id], eax
    movzx eax, byte [fl_disk]
    mov edi, fl_names
    call fs_list
    mov esi, fs3_list_hi
    mov edi, fl_ids_hi
    mov ecx, 33
    cld
    rep movsb
    mov esi, lst_ids
    mov edi, fl_ids
    mov ecx, 33
    rep movsb
    mov al, [lst_n]
    mov [fl_cnt], al
    movzx eax, al                       ; всё поместилось (или стало меньше) - список не должен остаться прокрученным
    sub eax, 14
    jns .sc
    xor eax, eax
.sc:cmp [fl_scr], al
    jbe .sk
    mov [fl_scr], al
.sk:
    ; FSM3 preview returns a distinctive exported lst_st=4 marker.
    ; Do NOT reference fs_state here: it is private to kernel fs.asm.
    mov byte [fl_fs3view], 0
    cmp byte [lst_st], 4
    jne .normal
    mov byte [fl_fs3view], 1
    mov byte [lst_st], 0           ; valid read-only preview, normal UI status
.normal:
    mov al, [lst_st]
    mov [fl_st], al
.e: popad
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
    RECT 4, 42, 80, 34, C_BLACK
    mov dword [r_c], C_WHITE
    jmp .fm1
.fm0:
    RECT 4, 42, 80, 34, C_BLACK
    RECT 6, 44, 76, 30, C_WHITE
    mov dword [r_c], C_BLACK
.fm1:
    mov dword [t_x], 12
    mov dword [t_y], 46
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
    mov esi, s_dk
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
    cmp byte [fl_fs3view], 0
    je .no_fs3_label
    mov dword [t_x], 370
    mov dword [t_y], 96
    mov dword [r_c], C_BLACK
    mov esi, s_fs3_preview
    call draw_big
.no_fs3_label:
    mov eax, 716
    mov ebx, 42
    mov ecx, 80
    mov edx, 34
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
    movzx eax, byte [fl_scr]
    add eax, ebp
    cmp al, [fl_sel]
    jne .nsel
    push esi                            ; выделенная строка: чёрная плашка, белые буквы
    call strlen
    shl ecx, 4
    add ecx, 12
    mov [pc_w], ecx
    mov eax, [t_y]
    mov [pc_y], eax
    RECTM 6, [pc_y], [pc_w], 32, C_BLACK
    pop esi
    mov dword [r_c], C_WHITE
    jmp .dr2
.nsel:
    mov dword [r_c], C_BLACK
.dr2:
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
    RECT 8, 84, 264, 88, C_BLACK
    RECT 4, 80, 264, 88, C_BLACK
    RECT 6, 82, 260, 84, C_WHITE
    mov dword [r_c], C_BLACK
    mov dword [t_x], 12
    mov dword [t_y], 86
    mov esi, s_dk_t
    call draw_big
    mov dword [t_x], 124
    mov esi, s_k_d
    call draw_big
    mov dword [t_x], 12
    mov dword [t_y], 130
    mov esi, s_exit
    call draw_big
    mov dword [t_x], 124
    mov esi, s_k_e
    call draw_big
.fe:cmp byte [d2_ctx], 0
    je .fn
    call ctx_draw
.fn:cmp byte [d2_nm], 0
    je .pq
    call nm_draw
.pq:cmp byte [d2_pr], 0
    je .e
    call pr_draw
.e: call mn_pdraw
    popad
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
    ; fs_pc_scan returns status 3 for a valid FSM3 volume.
    ; Do not treat a recognized FSM3 disk as unformatted.
    cmp al, 3
    jne .msg
    mov esi, s_pc_fsm3
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
    ; Show at least one pixel for genuinely occupied data clusters.
    ; Otherwise a small TXT on a 1 MB drive looks like an empty drive.
    test eax, eax
    jnz .bar_width_ok
    test esi, esi
    jz .nf
    mov eax, 1
.bar_width_ok:
    mov [pc_w], eax
    RECTM [pc_x], [pc_y2], [pc_w], 36, C_BLACK
.nf:
    mov ecx, [pc_tot + ebp * 4]
    mov eax, esi
    imul eax, 100
    xor edx, edx
    div ecx
    ; Fractional but nonzero usage: display <1% (not 0%).
    test eax, eax
    jnz .whole_percent
    test esi, esi
    jz .whole_percent
    mov dword [pc_buf], 0x0025313C  ; '<1%' followed by NUL
    jmp .percent_ready
.whole_percent:
    mov edi, pc_buf
    call u32str
    mov byte [edi], '%'
    mov byte [edi + 1], 0
.percent_ready:
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

; Что под мышью в Files: 27 File, 28 Exit, 36 Disks, 150..157 карточки дисков, 29 Back, 80..93 строки,
; 95 Delete (меню у файла), 96 - мимо меню
files_hit:
    cmp byte [d2_pr], 0
    jne pr_hit
    cmp byte [d2_nm], 0
    jne nm_hit
    mov esi, [m_x]
    mov edi, [m_y]
    cmp byte [d2_ctx], 0
    je .nc
    cmp byte [d2_ctx], 2
    jne .old
    mov eax, [ctx_x]                    ; меню на пустом месте: Folder, Notepad, Paint
    cmp esi, eax
    jb .cx
    add eax, 127
    cmp esi, eax
    ja .cx
    mov eax, [ctx_y]
    cmp edi, eax
    jb .cx
    add eax, 117
    cmp edi, eax
    ja .cx
    mov eax, edi
    sub eax, [ctx_y]
    sub eax, 2
    jns .r0
    xor eax, eax
.r0:xor edx, edx
    mov ecx, 38
    div ecx
    cmp eax, 2
    jbe .q1
    mov eax, 2
.q1:cmp eax, 2
    je .q2
    add al, 190                         ; 190 Folder, 191 Notepad
    ret
.q2:mov al, 194                         ; Paint
    ret
.old:
    mov edx, 39                         ; высота меню - 1
    cmp byte [d2_ctx], 3
    je .tl
    cmp byte [d2_ctx], 1
    jne .hh
    mov edx, 79                         ; защищённый файл: Delete, Settings
    cmp byte [ctx_m], 0
    jne .hh
    mov edx, 159                        ; у файла пункты: Rename, Delete, Copy, Settings
    movzx eax, byte [ctx_k]
    imul eax, 40
    add edx, eax
    jmp .hh
.tl:mov edx, 79
.hh:call ctx_wid
    mov eax, [ctx_x]
    cmp esi, eax
    jb .cx
    add eax, [ctx_w]
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
    cmp byte [d2_ctx], 1
    jne .nok
    cmp byte [ctx_m], 0
    jne .nok
    movzx ecx, byte [ctx_k]
    test ecx, ecx
    jz .nok
    imul ecx, 40
    cmp eax, ecx
    jae .oks
    xor edx, edx                        ; пункт Open in ...
    mov ecx, 40
    div ecx
    add al, 100
    ret
.oks:sub eax, ecx
.nok:xor ecx, ecx
    cmp eax, 40
    jb .sl
    mov ecx, 1                          ; вторая кнопка
    cmp eax, 80
    jb .sl
    mov ecx, 2                          ; третья: Copy
    cmp eax, 120
    jb .sl
    mov ecx, 3                          ; четвёртая: Settings
.sl:cmp byte [d2_ctx], 2
    jne .c3
    mov al, 97
    ret
.c3:cmp byte [d2_ctx], 3
    jne .c1
    mov al, 190
    add al, cl
    ret
.c1:mov al, 95                          ; меню файла: Rename, Delete, Copy, Settings
    cmp byte [ctx_m], 0
    jne .c1p
    cmp ecx, 3
    jne .c1b
    mov al, 102                         ; Settings
    ret
.c1b:
    cmp ecx, 2
    jne .c1a
    mov al, 98                          ; Copy
    ret
.c1a:
    test ecx, ecx
    jnz .c1r
    mov al, 94
.c1r:
    ret
.c1p:
    cmp ecx, 1                          ; защищённый файл: Delete и Settings
    jne .c1r
    mov al, 102
    ret
.cx:mov al, 96
    ret
.nc:cmp byte [d2_fmenu], 0
    je .nm
    cmp esi, 4
    jb .nm
    cmp esi, 268
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
.v1:cmp esi, 716
    jb .r1
    cmp esi, 796
    ja .r1
    cmp edi, 42
    jb .r1
    cmp edi, 76
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
    ; Keep legacy Open With and Paint actions blocked on FSM3.
    ; Copy now records the FSM3 parent; Ctrl+V uses the streaming path.
    cmp byte [fl_fs3view], 0
    je .ordinary
    cmp al, 100
    je .preview_noop
    cmp al, 101
    je .preview_noop
    cmp al, 194
    je .preview_noop
    jmp .ordinary
.preview_noop:
    ret
.ordinary:
    cmp byte [d2_pr], 0
    jne pr_press
    cmp byte [d2_nm], 0
    jne nm_press
    cmp al, 102
    jne .no102
    jmp pr_open
.no102:
    cmp al, 100
    jb .no1
    cmp al, 101
    ja .no1
    jmp fl_openwith
.no1:    cmp al, 99
    jne .nb99
    mov byte [sb_drag], 17
    mov byte [sb_ctx], 3
    call sb_grab
    cmp byte [sb_drag], 0
    je .r99
    call sb_set
.r99:ret
.nb99:
    cmp al, 98
    jne .nb98
    mov byte [d2_ctx], 0
    movzx eax, byte [ctx_i]
    call fl_copy
    jmp redraw
.nb98:
    cmp al, 94
    jne .n94
    mov al, 3
    jmp nm_open
.n94:cmp al, 97
    jne .n97
    mov byte [d2_ctx], 3
    jmp redraw
.n97:cmp al, 194
    jne .n94b
    mov al, 4
    jmp nm_open                         ; Paint
.n94b:cmp al, 190
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
    mov byte [fl_fs3view], 0
    mov byte [fl_fs3page], 0
    mov word [fl_fs3parent], 0
    mov byte [fl_insys], 0
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
    cmp byte [fl_dep], 0
    je .fb1
    cmp byte [fl_fs3view], 0
    je .legacy_back
    call fl_fs3up
    jmp .fu1
.legacy_back:
    call fl_up
.fu1:
    call wait_start
    call files_list
    call wait_end
    jmp files_draw
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
    cmp al, [fl_sel]                    ; один клик выделяет строку, второй (быстро) открывает
    jne .sel
    mov edx, [ticks]
    sub edx, [fl_ct]
    cmp edx, 10
    jbe .fr2
.sel:
    mov [fl_sel], al
    mov edx, [ticks]
    mov [fl_ct], edx
    jmp files_draw
.fr2:
    ; FSM3 read-only preview: open ordinary .txt in FloText,
    ; without exposing folder traversal or any FSM2 write operations.
    cmp byte [fl_fs3view], 0
    je .legacy_open
    movzx esi, al
    shl esi, 4
    cmp byte [fl_names + esi + 15], 1
    jne .fs3_file
    call fl_fs3enter              ; enter FSM3 nested directory
    call files_list
    jmp files_draw
.fs3_file:
    lea esi, [fl_names + esi]
    call fl_istxt
    jnc files_draw               ; only .txt files are opened here
    movzx eax, word [fl_fs3parent]
    mov [fs3_folder_id], eax
    mov byte [fs_par], 0          ; legacy parent is not used for FSM3
    mov al, [fl_disk]
    jmp text_open_named
.legacy_open:
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
    cmp byte [fl_insys], 0
    je .nsy
    call fl_istxt                       ; .txt внутри flopsys (например record.txt) открывается как обычный текст
    jnc sys_run                         ; в flopsys .sys-файлы запускаются
.nsy:
    call fl_issga                       ; документ itge (.sga): открыть в itge
    jnc .nsg
    push esi
    call itge_open
    pop esi
    mov al, [fl_disk]
    jmp itge_open_named
.nsg:
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

; Нажали на файл esi (имя, 16 байт) внутри flopsys: программы запускаются, ошибки показываются
sys_run:
    mov edi, run_names
    xor ebx, ebx
.l: cmp byte [edi], 0
    je files_draw
    call fl_streq
    je .hit
.s: mov al, [edi]
    inc edi
    test al, al
    jnz .s
    inc ebx
    jmp .l
.hit:
    cmp ebx, 9
    jne .n9
    jmp 0x54010                        ; FloCalendar.sys: same cal_open entry as Main -> Programs
.n9:
    cmp ebx, 8
    jne .n8
    jmp boil_open                       ; FloBoil.sys
.n8:cmp ebx, 7
    jne .n7
    jmp tr_open                         ; FloTerm.sys
.n7:cmp ebx, 6
    jne .n6
    jmp ck_open                         ; FloClock.sys
.n6:cmp ebx, 5
    ja files_draw
    jne .nit
    jmp itge_open                       ; itge.sys
.nit:
    cmp ebx, 4
    je .tm
    test ebx, ebx
    jnz .p1
    jmp text_open                       ; FloText.sys
.p1:cmp ebx, 1
    je files_draw                       ; FloFile.sys: он уже открыт
    cmp ebx, 2
    jne .p3
    jmp calc_open                       ; FloCalc.sys: калькулятор поверх FloFile
.p3:jmp paint_open                      ; FloPaint.sys
.tm:cmp byte [d2_tm], 0                 ; FloTasks.sys
    jne files_draw
    jmp tm_toggle

; Имя esi кончается на .sga? CF = да (esi не меняется)
fl_issga:
    push esi
    push ecx
    xor ecx, ecx
.l: cmp byte [esi + ecx], 0
    je .e
    inc ecx
    jmp .l
.e: cmp ecx, 4
    jb .n
    cmp dword [esi + ecx - 4], 0x6167732E
    jne .n
    pop ecx
    pop esi
    stc
    ret
.n: pop ecx
    pop esi
    clc
    ret

; Имя esi кончается на .txt? CF = да (esi не меняется)
fl_istxt:
    push esi
    push ecx
    xor ecx, ecx
.l: cmp byte [esi + ecx], 0
    je .e
    inc ecx
    jmp .l
.e: cmp ecx, 4
    jb .n
    cmp dword [esi + ecx - 4], '.txt'
    je .yes
    cmp dword [esi + ecx - 4], '.TXT'
    jne .n
.yes:
    pop ecx
    pop esi
    stc
    ret
.n: pop ecx
    pop esi
    clc
    ret

; Строки esi и edi равны? ZF = да (esi и edi не меняются)
fl_streq:
    push esi
    push edi
.l: mov al, [esi]
    cmp al, [edi]
    jne .n
    test al, al
    jz .y
    inc esi
    inc edi
    jmp .l
.y: pop edi
    pop esi
    xor eax, eax                        ; ZF = 1
    ret
.n: pop edi
    pop esi
    or eax, 1                           ; ZF = 0
    ret

; Главный диск: с которого загрузились (0 C, 1 O, 2 I) -> al
fl_main:
    mov al, [0x4F1]
    sub al, 0x80
    cmp al, 2
    jbe .o
    xor al, al
.o: ret

; Строка al - системная (flopsys на главном диске или всё, что внутри)? CF = да
fl_prot:
    cmp byte [fl_insys], 0
    jne .y
    push eax
    call fl_main
    cmp [fl_disk], al
    pop eax
    jne .n
    cmp byte [fl_dep], 0
    jne .n
    push eax                            ; fl_streq портит al, а там номер строки
    push esi
    push edi
    movzx esi, al
    shl esi, 4
    add esi, fl_names
    mov edi, s_system16
    call fl_streq
    pop edi
    pop esi
    pop eax
    je .y
    push eax
    push esi
    push edi
    movzx esi, al
    shl esi, 4
    add esi, fl_names
    mov edi, s_itgep
    call fl_streq
    pop edi
    pop esi
    pop eax
    jne .n
.y: stc
    ret
.n: clc
    ret

; Стрелки вверх (0x90) и вниз (0x91) в Files и Esc
files_key:
    cmp byte [d2_pr], 0
    jne pr_key
    cmp byte [d2_nm], 0
    jne nm_key
    cmp al, 5                           ; Ctrl+E - выйти
    je files_close
    cmp al, 4                           ; Ctrl+D - открыть Disks
    jne .kd
    mov byte [d2_fmenu], 0
    jmp dk_open
.kd:    cmp al, 27
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
    ; FSM3 listing: Ctrl+N next 32 records; Ctrl+P previous.
    ; Paging never invokes the legacy FSM2 writer.
    cmp byte [fl_fs3view], 0
    je .legacy_keys
    cmp al, 14                         ; Ctrl+N
    je .fs3_next
    cmp al, 16                         ; Ctrl+P
    je .fs3_prev
.legacy_keys:
    cmp al, 3                           ; Ctrl+C - copy source selection
    jne .cc
    movzx eax, byte [fl_sel]
    jmp fl_copy
.cc:
    cmp al, 22                          ; Ctrl+V - FSM3 in-volume copy
    jne .arrow_up
    cmp byte [fl_fs3view], 1
    jne .r
    call fl_fs3paste
    ret
.arrow_up:
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
.fs3_next:
    cmp byte [fl_fs3page], 31
    jae .r
    inc byte [fl_fs3page]
    jmp .fs3_refresh
.fs3_prev:
    cmp byte [fl_fs3page], 0
    je .r
    dec byte [fl_fs3page]
.fs3_refresh:
    mov byte [fl_scr], 0
    call files_list
    jmp files_draw
.r: ret

; Запомнить файл из строки eax списка для вставки (папки нельзя)
fl_copy:
    pushad
    cmp al, [fl_cnt]
    jae .r
    movzx esi, al
    shl esi, 4
    add esi, fl_names
    cmp byte [esi + 15], 1
    je .r
    mov edi, fclip_nm
    mov ecx, 16
    cld
    rep movsb
    mov al, [fl_disk]
    mov [fclip_dsk], al
    mov byte [fclip_fs3], 0
    cmp byte [fl_fs3view], 1
    jne .fsm2
    mov ax, [fl_fs3parent]
    mov [fclip_fs3parent], ax
    mov byte [fclip_fs3], 1
    jmp .ready
.fsm2:
    mov al, [fl_par]
    mov [fclip_par], al
.ready:
    mov byte [fclip_ok], 1
.r: popad
    ret

; Paste a copied file into a different FSM3 directory on the same disk.
; Do not use DATA_BUF or the FSM2 byte-sized parent identifiers.
fl_fs3paste:
    pushad
    cmp byte [fclip_ok], 1
    jne .out
    cmp byte [fclip_fs3], 1
    jne .out
    mov al, [fl_disk]
    cmp al, [fclip_dsk]
    jne .out                         ; no cross-disk copy in this stage
    call fs_setdisk
    jnc .out                         ; refuse FSM2 volumes
    cmp byte [lst_st], 3
    jne .out
    movzx eax, word [fclip_fs3parent]
    movzx edx, word [fl_fs3parent]
    mov esi, fclip_nm
    call fs3_copy_file
    jnc .refresh
    mov byte [d2_err], 0x43         ; existing generic filesystem error
.refresh:
    call files_list
    call redraw
.out:
    popad
    ret

; Правая кнопка в Files: на файле - Rename и Delete, на пустом месте - Create
files_rclick:
    cmp byte [d2_pr], 0
    jne .r
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
    call fl_prot
    jnc .nsy
    mov byte [ctx_m], 2                 ; flopsys и системные файлы: удалять нельзя
.nsy:
    mov [ctx_i], al
    mov [fl_sel], al                    ; правый клик тоже выделяет
    mov byte [d2_ctx], 1
    mov byte [ctx_k], 0
    cmp byte [ctx_m], 0
    jne .pos
    call fl_openk                       ; какие программы могут открыть этот файл
    jmp .pos
.em:cmp byte [fl_insys], 0              ; пустое место: меню Create (в flopsys нельзя)
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
    cmp byte [d2_ctx], 1
    jne .nc1
    movzx eax, byte [ctx_k]
    imul eax, 40
    neg eax
    add eax, 430
    cmp [ctx_y], eax
    jbe .nc0
    mov [ctx_y], eax
.nc0:
    mov eax, 640
    cmp byte [ctx_k], 0
    je .cap
    mov eax, 560
.cap:
    cmp [ctx_x], eax
    jbe .nc1
    mov [ctx_x], eax
.nc1:
    cmp byte [d2_ctx], 2
    jne .dr
    cmp dword [ctx_x], 664              ; меню Folder/Notepad/Paint выше и шире остальных
    jbe .xc
    mov dword [ctx_x], 664
.xc:cmp dword [ctx_y], 476
    jbe .dr
    mov dword [ctx_y], 476
.dr:jmp ctx_draw
.r: ret

; Меню: у файла (Rename, Delete), на пустом месте (Create), выбор Folder / Text
ctx_draw:
    cmp byte [d2_ctx], 2
    je ctx_menu3
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
.nf:call ctx_wid
    mov dword [pc_h], 40
    cmp byte [d2_ctx], 3
    je .tall
    cmp byte [d2_ctx], 1
    jne .h
    mov dword [pc_h], 80                ; защищённый файл: Delete, Settings
    cmp byte [ctx_m], 0
    jne .h
    mov dword [pc_h], 160               ; Rename, Delete, Copy, Settings
    movzx eax, byte [ctx_k]             ; и сверху пункты Open in ...
    imul eax, 40
    add [pc_h], eax
    jmp .h
.tall:
    mov dword [pc_h], 80
.h: mov eax, [ctx_x]
    add eax, 4
    mov [pc_x], eax
    mov eax, [ctx_y]
    add eax, 4
    mov [pc_y2], eax
    RECTM [pc_x], [pc_y2], [ctx_w], [pc_h], C_BLACK
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
    mov eax, [ctx_x]                    ; Rename / Delete: просто слова, без линии между ними
    mov [pc_x], eax
    mov eax, [ctx_y]
    mov [pc_y2], eax
    RECTM [pc_x], [pc_y2], [ctx_w], [pc_h], C_BLACK
    mov eax, [ctx_x]
    add eax, 2
    mov [pc_x], eax
    mov eax, [ctx_y]
    add eax, 2
    mov [pc_y2], eax
    mov eax, [pc_h]
    sub eax, 4
    mov [pc_w], eax
    mov eax, [ctx_w]
    sub eax, 4
    mov [pc_x2], eax
    RECTM [pc_x], [pc_y2], [pc_x2], [pc_w], C_WHITE
    mov dword [r_c], C_BLACK
    mov eax, [ctx_x]
    add eax, 8
    mov [t_x], eax
    mov eax, [ctx_y]
    add eax, 4
    mov [t_y], eax
    cmp byte [ctx_m], 0
    jne .dl
    xor ebp, ebp                        ; пункты Open in ...
.ol:movzx eax, byte [ctx_k]
    cmp ebp, eax
    jae .od
    movzx eax, byte [ctx_t]
    lea eax, [eax * 2 + ebp]
    mov esi, [ctx_ol + eax * 4]
    push ebp
    call draw_big
    pop ebp
    add dword [t_y], 40
    inc ebp
    jmp .ol
.od:mov esi, s_rename
    call draw_big
    add dword [t_y], 40
.dl:mov esi, s_delete
    call draw_big
    cmp byte [ctx_m], 0
    jne .st
    add dword [t_y], 40
    mov esi, s_copy
    call draw_big
.st:add dword [t_y], 40
    mov esi, s_settings
    call draw_big
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

; Ширина меню: у файла со списком Open in ... шире
ctx_wid:
    mov dword [ctx_w], 112
    cmp byte [d2_ctx], 1
    jne .r
    mov dword [ctx_w], 144              ; слово Settings шире остальных
    cmp byte [ctx_m], 0
    jne .r
    cmp byte [ctx_k], 0
    je .r
    mov dword [ctx_w], 232
.r: cmp byte [ui_ru], 0                 ; по-русски слова длиннее
    je .rr
    cmp dword [ctx_w], 256
    jae .rr
    mov dword [ctx_w], 256
.rr:ret

; Файл с номером al: сколько программ могут его открыть (ctx_k) и какого он типа (ctx_t: 0 .pcf, 1 .txt, 2 .sga)
fl_openk:
    pushad
    mov byte [ctx_k], 0
    cmp byte [fl_insys], 0
    jne .r
    movzx esi, al
    shl esi, 4
    cmp byte [fl_names + esi + 15], 1
    je .r
    add esi, fl_names
    call fl_issga
    jnc .n1
    mov byte [ctx_t], 2
    mov byte [ctx_k], 1
    jmp .r
.n1:call is_pcf
    jnc .n2
    mov byte [ctx_t], 0
    mov byte [ctx_k], 2
    jmp .r
.n2:call fl_istxt
    jnc .r
    mov byte [ctx_t], 1
    mov byte [ctx_k], 2
.r: popad
    ret

; Выбрали в меню файла пункт Open in ...: al = 100 + номер пункта
fl_openwith:
    movzx edx, al
    sub edx, 100
    mov byte [d2_ctx], 0
    movzx eax, byte [ctx_t]
    lea eax, [eax * 2 + edx]
    movzx esi, byte [ctx_i]
    shl esi, 4
    add esi, fl_names
    mov dl, [fl_par]
    mov [fs_par], dl
    test eax, eax
    jnz .a1
    mov al, [fl_disk]
    jmp paint_open_named
.a1:cmp eax, 1
    je .it
    cmp eax, 3
    je .it
    cmp eax, 2
    jne .a4
    mov al, [fl_disk]
    jmp text_open_named
.it:mov al, [fl_disk]
    jmp itge_insert_file
.a4:push esi
    call itge_open
    pop esi
    mov al, [fl_disk]
    jmp itge_open_named

; Меню на пустом месте: Folder, Notepad, Paint - просто слова, без линий между ними
ctx_menu3:
    pushad
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    mov eax, [ctx_x]
    add eax, 4
    mov [pc_x], eax
    mov eax, [ctx_y]
    add eax, 4
    mov [pc_y2], eax
    RECTM [pc_x], [pc_y2], 128, 118, C_BLACK
    RECTM [ctx_x], [ctx_y], 128, 118, C_BLACK
    mov eax, [ctx_x]
    add eax, 2
    mov [pc_x], eax
    mov eax, [ctx_y]
    add eax, 2
    mov [pc_y2], eax
    RECTM [pc_x], [pc_y2], 124, 114, C_WHITE
    mov dword [r_c], C_BLACK
    mov eax, [ctx_x]
    add eax, 8
    mov [t_x], eax
    mov eax, [ctx_y]
    add eax, 5
    mov [t_y], eax
    mov esi, s_folder
    call draw_big
    add dword [t_y], 38
    mov esi, s_notepad
    call draw_big
    add dword [t_y], 38
    mov esi, s_paintn
    call draw_big
    popad
    ret

; Нажали Delete
files_delete:
    mov byte [d2_ctx], 0
    cmp byte [ctx_m], 0
    je .fl
    movzx esi, byte [ctx_i]             ; какая это системная вещь: папка, программа (Flo...) или системный файл
    shl esi, 4
    add esi, fl_names
    mov byte [d2_err], 0x31                ; системная папка
    cmp byte [esi + 15], 1
    je .se
    mov byte [d2_err], 0x33                ; системный файл
    mov eax, [esi]
    and eax, 0xFFFFFF
    cmp eax, 0x6F6C46                   ; "Flo" - программа
    jne .se
    mov byte [d2_err], 0x32
.se:jmp redraw
.fl:mov al, [fl_disk]
    call fs_setdisk
    jnc .del_mounted
    cmp byte [lst_st], 3
    jne .e
.del_mounted:
    mov al, [fl_par]
    cmp byte [fl_fs3view], 0
    je .del_parent
    xor al, al
.del_parent:
    mov [fs_par], al
    movzx ecx, word [fl_fs3parent]
    mov [fs3_folder_id], ecx
    movzx edx, byte [ctx_i]
    movzx eax, byte [fl_ids + edx]
    shl edx, 4
    lea esi, [fl_names + edx]
    cmp byte [esi + 15], 1
    jne .del
    cmp byte [fl_fs3view], 0
    jne .del                 ; FSM3 delete checks children independently
    call dir_has_child                  ; папку с файлами удалять нельзя
    jnc .del
    mov byte [d2_err], 0x35
    jmp redraw
.del:
    call file_delete
.e: call files_list
    jmp redraw

; FSM3 folder navigation: slot+1 is 16-bit, never truncate to fl_par.
; FloFile still uses its existing path/depth UI for both filesystem versions.
fl_fs3enter:
    pushad
    movzx edx, al                    ; preserve clicked row before using AX
    movzx ebx, byte [fl_dep]
    cmp ebx, 4
    jae .done
    mov ax, [fl_fs3parent]
    mov [fl_fs3stack + ebx*2], ax
    movzx ecx, byte [fl_ids + edx]
    movzx esi, byte [fl_ids_hi + edx]
    shl esi, 8
    or ecx, esi
    cmp ecx, 1
    jb .done
    cmp ecx, 1024
    ja .done
    mov [fl_fs3parent], cx
    mov al, dl                        ; restore clicked row for legacy path updater
    call fl_enter                     ; updates existing path and depth UI
    mov byte [fl_fs3page], 0
    mov byte [fl_scr], 0
.done:
    popad
    ret

fl_fs3up:
    pushad
    movzx ebx, byte [fl_dep]
    test ebx, ebx
    jz .done
    dec ebx
    mov ax, [fl_fs3stack + ebx*2]
    mov [fl_fs3parent], ax
    call fl_up
    mov byte [fl_fs3page], 0
    mov byte [fl_scr], 0
.done:
    popad
    ret

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
    test ebx, ebx
    jnz .ni
    cmp byte [fl_fs3view], 1
    je .ni                         ; FSM3 folder names are ordinary folders
    push eax
    call fl_main                        ; flopsys на главном диске
    cmp [fl_disk], al
    pop eax
    jne .ni
    mov esi, edx
    shl esi, 4
    add esi, fl_names
    mov edi, s_system16
    call fl_streq
    je .is
    mov esi, edx
    shl esi, 4
    add esi, fl_names
    mov edi, s_itgep
    call fl_streq
    jne .ni
.is:mov byte [fl_insys], 1
.ni:movzx eax, byte [fl_ids + edx]
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
    test ebx, ebx
    jnz .r
    mov byte [fl_insys], 0
.r: popad
    ret

; В поле имени сразу стоит расширение esi (4 буквы), курсор перед ним
nm_pre:
    push eax
    push ecx
    xor ecx, ecx
.c: mov al, [esi + ecx]
    mov [dl_name + ecx], al
    inc ecx
    test al, al
    jnz .c
    dec ecx
    mov [dl_len], cl
    mov byte [dl_car], 0
    pop ecx
    pop eax
    ret

; Окно ввода имени: al = 1 папка, 2 текстовый документ, 3 переименование, 4 рисунок
nm_open:
    pushad
    mov byte [nm_file_menu], 0
    mov byte [nm_min], 0
    mov [d2_nm], al
    mov byte [d2_ctx], 0
    mov byte [dl_len], 0
    mov byte [dl_car], 0
    mov byte [dl_anc], 0xFF
    mov byte [dl_name], 0
    mov byte [dl_app], 0
    mov byte [sel_drag], 0
    mov byte [dl_nohint], 1             ; ".txt" / ".pcf" - настоящий текст в поле, его можно стереть и заменить
    cmp al, 2
    jne .n2
    mov esi, s_txt
    call nm_pre
.n2:cmp al, 4
    jne .n4
    mov byte [dl_app], 1
    mov esi, s_pcf
    call nm_pre
.n4:cmp al, 3
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
    mov byte [nm_file_menu], 0
    mov byte [nm_min], 0
    mov byte [d2_nm], 0
    jmp redraw

nm_hit:
    cmp byte [nm_min], 0
    je .expanded
    mov esi, [m_x]
    cmp esi, 646
    jb .z
    cmp esi, 790
    ja .z
    mov edi, [m_y]
    cmp edi, 428
    jb .z
    cmp edi, 464
    ja .z
    mov al, 209                         ; restore Name window
    ret
.expanded:
    mov esi, [m_x]
    sub esi, [nm_x]
    js .z
    mov edi, [m_y]
    sub edi, [nm_y]
    js .z
    cmp esi, 400
    ja .z
    cmp edi, 280
    ja .z
    ; Native title controls (minus and close), ahead of dragging.
    cmp edi, 6
    jb .field
    cmp edi, 38
    ja .field
    cmp esi, 330
    jb .drag_title
    cmp esi, 360
    jbe .btn_min
    cmp esi, 364
    jb .field
    cmp esi, 394
    jbe .btn_close
    jmp .field
.btn_min:
    mov al, 207
    ret
.btn_close:
    mov al, 208
    ret
.drag_title:
    cmp edi, 4
    jb .field
    cmp edi, 38
    ja .field
    cmp esi, 8
    jb .field
    cmp esi, 392
    ja .field
    mov al, 196
    ret
.field:
    mov dl, [nm_file_menu]
    call sys_file_hit
    test al, al
    jnz .file_menu_hit
    cmp edi, 128
    jb .z
    cmp edi, 164
    jbe .name
    cmp edi, 204
    jb .z
    cmp edi, 248
    ja .z
    cmp esi, 24
    jb .z
    cmp esi, 184
    jbe .ok
    cmp esi, 216
    jb .z
    cmp esi, 376
    ja .z
    mov al, 193
    ret
.file_menu_hit:
    add al, 37                        ; 230 File, 231 Exit (no 193 Cancel collision)
    ret
.name:
    cmp esi, 24
    jb .z
    cmp esi, 376
    ja .z
    mov al, 47
    ret
.ok:
    mov al, 192
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
    cmp al, 230
    je .menu_toggle
    cmp al, 231
    je nm_close
    cmp al, 207
    jne .not_min
    mov byte [nm_min], 1
    jmp redraw
.menu_toggle:
    xor byte [nm_file_menu], 1
    jmp redraw
.not_min:
    cmp al, 208
    je nm_close
    cmp al, 209
    jne .not_restore
    mov byte [nm_min], 0
    jmp redraw
.not_restore:
    cmp al, 196
    jne .name_actions
    mov al, 13
    call file_drag_context
    mov bl, 1
    jmp drag_start
.name_actions:
    cmp al, 47
    jne .a
    push dword [qx0]                    ; поле имени: поставить палку, начать выделять
    mov eax, [nm_x]
    add eax, 20
    mov [qx0], eax
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
    cmp al, 5                           ; Ctrl+E = File > Exit (Name modal)
    je nm_close
    cmp al, 27
    je nm_close
    cmp byte [nm_min], 0           ; Enter must not commit when minimized
    jne .minimized
    cmp al, 13
    je nm_commit
    jmp dlg_key
.minimized:
    ret

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
    cmp byte [d2_nm], 2                 ; текст без точки - дописываем .txt, рисунок - .pcf
    je .e10
    cmp byte [d2_nm], 4
    jne .c
.e10:mov ecx, 10
.c: lodsb
    test al, al
    jz .ce
    stosb
    loop .c
.ce:cmp byte [d2_nm], 2
    je .ext
    cmp byte [d2_nm], 4
    jne .z
.ext:call nm_dot
    jc .z
    mov esi, s_txt
    cmp byte [d2_nm], 4
    jne .x
    mov esi, s_pcf
.x: lodsb
    stosb
    test al, al
    jnz .x
    jmp .z2
.z: mov byte [edi], 0
.z2:
    mov al, [fl_disk]
    call fs_setdisk
    jnc .fsm2
    cmp byte [lst_st], 3
    jne .e7
    cmp byte [fl_fs3view], 1
    jne .e7
    movzx eax, word [fl_fs3parent]
    mov [fs3_folder_id], eax
    mov byte [fs_par], 0          ; FSM2 parent not used by FSM3
    cmp byte [d2_nm], 2
    je .fs3_txt
    cmp byte [d2_nm], 1
    je .fs3_mkdir
    cmp byte [d2_nm], 3
    je .fs3_rename
    jmp .e7                      ; image creation unsupported on FSM3
.fs3_txt:
    mov esi, nm_full
    xor ecx, ecx
    call file_write
    jc .e7
    jmp .ok
.fs3_mkdir:
    mov esi, nm_full
    call dir_mkdir
    jc .e7
    jmp .ok
.fs3_rename:
    movzx esi, byte [ctx_i]
    shl esi, 4
    add esi, fl_names
    mov edx, nm_full
    call dir_rename
    jc .e5
    jmp .ok
.fsm2:
    mov al, [fl_par]
    mov [fs_par], al
    cmp byte [d2_nm], 3
    je .ren
    mov esi, nm_full                    ; такое имя уже есть?
    call dir_find
    jnc .e5
    cmp byte [d2_nm], 2
    je .txt
    cmp byte [d2_nm], 4
    je .pcf
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
.pcf:                                   ; пустой белый рисунок 680 x 500 (формат PCF1)
    mov edi, DATA_BUF
    mov dword [edi], 0x31464350
    mov dword [edi + 4], 680
    mov dword [edi + 8], 500
    mov dword [edi + 12], 0
    add edi, 16
    mov ecx, 42500
    mov eax, 0xFFFFFFFF
    cld
    rep stosd
    mov esi, nm_full
    mov ecx, 170016
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
.ok:mov byte [nm_min], 0
    mov byte [d2_nm], 0
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
    cmp byte [nm_min], 0
    je .expanded
    mov dword [cw_x], 0
    mov dword [cw_y], 0
    mov eax, 646
    mov ebx, 428
    mov ecx, 144
    mov edx, 36
    mov esi, nm_mini_label
    xor edi, edi
    call wbtn
    jmp .done
.expanded:
    MODRECT nm_x, nm_y, 8, 8, 400, 280, C_BLACK
    MODRECT nm_x, nm_y, 0, 0, 400, 280, C_BLACK
    MODRECT nm_x, nm_y, 2, 2, 396, 276, C_WHITE
    MODRECT nm_x, nm_y, 2, 2, 396, 38, C_WHITE
    MODRECT nm_x, nm_y, 2, 40, 396, 2, C_BLACK
    mov eax, [nm_x]
    mov ebx, [nm_y]
    add ebx, 6
    mov edx, 400
    mov esi, nm_sys_title
    call sys_modal_center
    movzx ecx, byte [d2_nm]
    mov esi, [nm_ttl_tab + ecx * 4 - 4]
    mov eax, [nm_x]
    mov ebx, [nm_y]
    add ebx, 88
    mov edx, 400
    call sys_modal_center
    mov al, 207
    call title_button_state
    mov eax, [nm_x]
    add eax, 334
    mov ebx, [nm_y]
    add ebx, 8
    call mbtn
    mov al, 208
    call title_button_state
    mov eax, [nm_x]
    add eax, 368
    mov ebx, [nm_y]
    add ebx, 8
    call xbtn
    call nm_input
    mov eax, [nm_x]
    mov [cw_x], eax
    mov eax, [nm_y]
    mov [cw_y], eax
    mov eax, 24
    mov ebx, 204
    mov ecx, 160
    mov edx, 44
    mov esi, s_ok
    push eax
    mov al, 192
    push edx
    mov dl, 5
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    mov eax, 216
    mov esi, s_cancel
    push eax
    mov al, 193
    push edx
    mov dl, 5
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    mov eax, [nm_x]
    mov ebx, [nm_y]
    mov ecx, 400
    mov dl, [nm_file_menu]
    call sys_file_draw
    ; FloFile's fullscreen painter expects desktop coordinates afterwards.
    mov dword [cw_x], 0
    mov dword [cw_y], 0
.done:
    popad
    ret

; Поле ввода - то же, что в окне Save to (выделение, палочка, копирование), только на другом месте
nm_input:
    pushad
    push dword [qx0]
    push dword [qy0]
    push dword [dlg_w]
    mov eax, [nm_x]
    add eax, 20
    mov [qx0], eax
    mov eax, [nm_y]
    add eax, 42
    mov [qy0], eax
    mov dword [dlg_w], 360
    call dlg_name_draw
    pop dword [dlg_w]
    pop dword [qy0]
    pop dword [qx0]
    popad
    ret

; окно ошибки
; Legacy FAPI entry, no longer used. Kernel renders Error window.
err_draw:
    ret

; данные FloFile
fl_view     db 0
fl_disk     db 0
fl_insys   db 0                        ; 1 - мы внутри системной папки flopsys
fl_st       db 0
fl_fs3view  db 0                      ; FSM3 separate catalog handling
fl_fs3page  db 0                      ; 32 pages, 32 entries each
fl_fs3parent dw 0                     ; current FSM3 parent ID: 0..1024
fl_fs3stack times 5 dw 0             ; 16-bit parent navigation history
fl_ids_hi   times 34 db 0             ; upper byte of FSM3 entry IDs
fclip_fs3 db 0                          ; clipboard contains FSM3 source
fclip_fs3parent dw 0                   ; full 16-bit source parent ID
d2_fmenu    db 0
d2_ctx      db 0
ctx_m       db 0
ctx_k       db 0
ctx_t       db 0
ctx_w       dd 112
pc_x2       dd 0
ctx_ol      dd s_opaint, s_oitge, s_otext, s_oitge, s_oitge, 0
ctx_i       db 0
fl_sel      db 0xFF                    ; выделенная строка списка (0xFF - никакой)
fl_ct       dd 0                       ; когда был последний клик (для двойного)
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
nm_full     times 24 db 0
nm_ext      dd 0
pc_h        dd 0
e_l1        dd 0
e_l2        dd 0
s_files     db "FloFile", 0
s_dk        db "Disk X", 0
s_dkf       db "Disk X/flopsys", 0
s_dkp       db "Disk X/flopsys/programs", 0
s_dk_t      db "Disks", 0
s_back      db "Back", 0
s_nodisk2   db "No disk", 0
s_nofmt2    db "Not formatted", 0
s_pc_fsm3   db "FSM3", 0
st_empty    db "(empty)", 0
st_nodisk   db "no disk", 0
st_nofs     db "not formatted", 0
s_copy      db "Copy", 0
s_k_e       db "Ctrl + E", 0
s_k_d       db "Ctrl + D", 0
s_opaint    db "Open in Paint", 0
s_otext     db "Open in Text", 0
s_oitge     db "Open in itge", 0
s_system16  db "flopsys", 0
s_itgep     db "itge_program", 0
s_txt       db ".txt", 0
s_delete    db "Delete", 0
s_rename    db "Rename", 0
s_create    db "Create", 0
s_folder    db "Folder", 0
s_text      db "Text", 0
s_notepad   db "Notepad", 0
s_paintn    db "Paint", 0
s_pcf       db ".pcf", 0
s_nt1       db "New folder", 0
s_nt2       db "New notepad", 0
s_nt3       db "Rename", 0
s_nt4       db "New paint", 0
nm_ttl_tab  dd s_nt1, s_nt2, s_nt3, s_nt4
s_ok        db "OK", 0
run_names   db "FloText.sys", 0, "FloFile.sys", 0, "FloCalc.sys", 0, "FloPaint.sys", 0, "FloTasks.sys", 0, "FloItge.sys", 0, "FloClock.sys", 0, "FloTerm.sys", 0, "FloBoil.sys", 0, "FloCalendar.sys", 0
            db 0

; Окно Settings у файла или папки: два раздела File и Format
pr_open:
    pushad
    mov byte [pr_file_menu], 0
    mov byte [pr_min], 0
    movzx esi, byte [ctx_i]
    shl esi, 4
    add esi, fl_names
    mov edi, pr_name
    mov ecx, 16
    cld
    rep movsb
    mov dword [pr_sz], 0
    mov dword [pr_cr], 0
    mov dword [pr_mo], 0
    movzx eax, byte [fl_disk]
    call fs_setdisk
    jc .nf
    mov al, [fl_par]
    mov [fs_par], al
    mov esi, pr_name
    call dir_find
    jc .nf
    mov eax, [edi + 16]
    mov [pr_sz], eax
    movzx eax, word [edi + 26]
    movzx ecx, byte [edi + 28]
    shl ecx, 16
    or eax, ecx
    mov [pr_cr], eax
    movzx eax, word [edi + 29]
    movzx ecx, byte [edi + 31]
    shl ecx, 16
    or eax, ecx
    mov [pr_mo], eax
.nf:mov byte [d2_pr], 1
    mov byte [d2_ctx], 0
    popad
    jmp redraw

pr_hit:
    cmp byte [pr_min], 0
    je .expanded
    mov esi, [m_x]
    cmp esi, 646
    jb .z
    cmp esi, 790
    ja .z
    mov edi, [m_y]
    cmp edi, 388
    jb .z
    cmp edi, 424
    ja .z
    mov al, 212
    ret
.expanded:
    mov esi, [m_x]
    sub esi, [pr_x]
    js .z
    mov edi, [m_y]
    sub edi, [pr_y]
    js .z
    cmp esi, 480
    ja .z
    cmp edi, 368
    ja .z
    cmp edi, 6
    jb .tabs
    cmp edi, 38
    ja .tabs
    cmp esi, 410
    jb .drag_title
    cmp esi, 440
    jbe .min_button
    cmp esi, 444
    jb .tabs
    cmp esi, 474
    jbe .close_button
    jmp .tabs
.min_button:
    mov al, 210
    ret
.close_button:
    mov al, 211
    ret
.drag_title:
    cmp esi, 8
    jb .tabs
    cmp esi, 472
    ja .tabs
    mov al, 197
    ret
.tabs:
    mov dl, [pr_file_menu]
    call sys_file_hit
    test al, al
    jnz .file_menu_hit
    cmp edi, 100
    jb .b
    cmp edi, 140
    ja .b
    cmp esi, 20
    jb .z
    cmp esi, 160
    jbe .t1
    cmp esi, 176
    jb .z
    cmp esi, 316
    ja .z
    mov al, 104
    ret
.t1:mov al, 103
    ret
.b: cmp edi, 306
    jb .z
    cmp edi, 350
    ja .z
    cmp esi, 160
    jb .z
    cmp esi, 320
    ja .z
    mov al, 105
    ret
.file_menu_hit:
    add al, 37                        ; 230 File, 231 Exit
    ret
.z: mov al, 96
    ret

pr_press:
    cmp al, 230
    je .menu_toggle
    cmp al, 231
    je .close_menu_window
    cmp al, 210
    jne .not_min
    mov byte [pr_min], 1
    jmp redraw
.menu_toggle:
    xor byte [pr_file_menu], 1
    jmp redraw
.close_menu_window:
    mov byte [pr_file_menu], 0
    mov byte [pr_min], 0
    mov byte [d2_pr], 0
    jmp redraw
.not_min:
    cmp al, 211
    jne .not_close
    mov byte [pr_min], 0
    mov byte [d2_pr], 0
    jmp redraw
.not_close:
    cmp al, 212
    jne .not_restore
    mov byte [pr_min], 0
    jmp redraw
.not_restore:
    cmp al, 197
    jne .property_actions
    mov al, 14
    call file_drag_context
    mov bl, 1
    jmp drag_start
.property_actions:
    cmp al, 103
    jne .a
    mov byte [d2_pr], 1
    jmp files_draw
.a: cmp al, 104
    jne .b
    mov byte [d2_pr], 2
    jmp files_draw
.b: cmp al, 105
    jne .r
    mov byte [pr_min], 0
    mov byte [d2_pr], 0
    jmp redraw
.r: ret

pr_key:
    cmp al, 5                           ; Ctrl+E = File > Exit (Properties modal)
    je .c
    cmp al, 27
    je .c
    cmp al, 13
    jne .r
.c: mov byte [pr_min], 0
    mov byte [d2_pr], 0
    jmp redraw
.r: ret

; Добавить в строку pr_buf: строку esi, символ al, число eax, две цифры al, дату eax
pr_cat:
    cmp esi, pr_name                    ; имя файла не переводим
    jb .tr
    cmp esi, pr_name + 16
    jb .nt
.tr:call ui_tr
.nt:push edi
    mov edi, [pr_p]
.l: lodsb
    test al, al
    jz .e
    stosb
    jmp .l
.e: mov [pr_p], edi
    pop edi
    ret

pr_ch:
    push edi
    mov edi, [pr_p]
    stosb
    mov [pr_p], edi
    pop edi
    ret

pr_num:
    push edi
    mov edi, [pr_p]
    call u32str
    mov [pr_p], edi
    pop edi
    ret

pr_2d:
    push edi
    mov edi, [pr_p]
    aam
    add ax, 0x3030
    xchg al, ah
    stosw
    mov [pr_p], edi
    pop edi
    ret

pr_date:
    test eax, eax
    jnz .k
    mov esi, s_unk
    jmp pr_cat
.k: push ebx
    mov ebx, eax
    shr eax, 20
    add eax, 2020
    call pr_num
    mov al, '-'
    call pr_ch
    mov eax, ebx
    shr eax, 16
    and eax, 15
    call pr_2d
    mov al, '-'
    call pr_ch
    mov eax, ebx
    shr eax, 11
    and eax, 31
    call pr_2d
    mov al, ' '
    call pr_ch
    mov eax, ebx
    shr eax, 6
    and eax, 31
    call pr_2d
    mov al, ':'
    call pr_ch
    mov eax, ebx
    and eax, 63
    call pr_2d
    pop ebx
    ret

; Начать строку: надпись esi
pr_beg:
    mov dword [pr_p], pr_buf
    jmp pr_cat

; Вывести строку pr_buf в y = eax
pr_out:
    mov edi, [pr_p]
    mov byte [edi], 0
    sub eax, 92
    add eax, [pr_y]
    mov [t_y], eax
    mov eax, [pr_x]
    add eax, 20
    mov [t_x], eax
    mov dword [r_c], C_BLACK
    mov esi, pr_buf
    jmp draw_big

; Тип файла по имени: esi -> тип в al (0 папка, 1 .txt, 2 .pcf, 3 .sga, 4 .sys, 5 другой, 6 без расширения)
pr_type:
    cmp byte [pr_name + 15], 1
    jne .f
    xor eax, eax
    ret
.f: xor ecx, ecx
    xor edx, edx
.l: mov al, [pr_name + ecx]
    test al, al
    jz .e
    cmp al, '.'
    jne .n
    lea edx, [ecx + 1]
.n: inc ecx
    jmp .l
.e: test edx, edx
    jnz .x
    mov al, 6
    ret
.x: mov [pr_ext], edx
    mov eax, [pr_name + edx]
    or eax, 0x20202020
    and eax, 0x00FFFFFF
    cmp byte [pr_name + edx + 3], 0
    jne .o
    cmp eax, 'txt'
    jne .p
    mov al, 1
    ret
.p: cmp eax, 'pcf'
    jne .q
    mov al, 2
    ret
.q: cmp eax, 'sga'
    jne .s
    mov al, 3
    ret
.s: cmp eax, 'sys'
    jne .o
    mov al, 4
    ret
.o: mov al, 5
    ret

pr_draw:
    pushad
    cmp byte [pr_min], 0
    je .expanded
    mov dword [cw_x], 0
    mov dword [cw_y], 0
    mov eax, 646
    mov ebx, 388
    mov ecx, 144
    mov edx, 36
    mov esi, pr_mini_label
    xor edi, edi
    call wbtn
    jmp .done
.expanded:
    MODRECT pr_x, pr_y, 8, 8, 480, 368, C_BLACK
    MODRECT pr_x, pr_y, 0, 0, 480, 368, C_BLACK
    MODRECT pr_x, pr_y, 2, 2, 476, 364, C_WHITE
    MODRECT pr_x, pr_y, 2, 2, 476, 38, C_WHITE
    MODRECT pr_x, pr_y, 2, 40, 476, 2, C_BLACK
    mov eax, [pr_x]
    mov ebx, [pr_y]
    add ebx, 6
    mov edx, 480
    mov esi, pr_sys_title
    call sys_modal_center
    mov al, 210
    call title_button_state
    mov eax, [pr_x]
    add eax, 414
    mov ebx, [pr_y]
    add ebx, 8
    call mbtn
    mov al, 211
    call title_button_state
    mov eax, [pr_x]
    add eax, 448
    mov ebx, [pr_y]
    add ebx, 8
    call xbtn
    mov eax, [pr_x]
    mov [cw_x], eax
    mov eax, [pr_y]
    mov [cw_y], eax
    mov eax, 20
    mov ebx, 100
    mov ecx, 140
    mov edx, 40
    mov esi, s_pfile
    xor edi, edi
    cmp byte [d2_pr], 1
    jne .t1
    inc edi
.t1:call wbtn
    mov eax, 176
    mov esi, s_pformat
    xor edi, edi
    cmp byte [d2_pr], 2
    jne .t2
    inc edi
.t2:call wbtn
    cmp byte [d2_pr], 2
    je .fmt
    mov esi, s_pname
    call pr_beg
    mov esi, pr_name
    call pr_cat
    mov eax, 252
    call pr_out
    mov esi, s_psize
    call pr_beg
    cmp byte [pr_name + 15], 1
    jne .sz
    mov esi, s_pfolder
    call pr_cat
    jmp .so
.sz:mov eax, [pr_sz]
    call pr_num
    mov esi, s_pbytes
    call pr_cat
.so:mov eax, 286
    call pr_out
    mov esi, s_pcreated
    call pr_beg
    mov eax, [pr_cr]
    call pr_date
    mov eax, 320
    call pr_out
    mov esi, s_pmod
    call pr_beg
    mov eax, [pr_mo]
    call pr_date
    mov eax, 354
    call pr_out
    jmp .ok
.fmt:
    call pr_type
    movzx ebx, al
    mov esi, s_ptype
    call pr_beg
    mov esi, [pr_tn + ebx * 4]
    call pr_cat
    mov eax, 252
    call pr_out
    mov esi, s_pext
    call pr_beg
    cmp ebx, 5
    ja .nx
    test ebx, ebx
    jz .nx
    mov al, '.'
    call pr_ch
    mov esi, pr_name
    add esi, [pr_ext]
    call pr_cat
    jmp .xo
.nx:mov esi, s_pnone
    call pr_cat
.xo:mov eax, 286
    call pr_out
    mov esi, s_popens
    call pr_beg
    mov esi, [pr_on + ebx * 4]
    call pr_cat
    mov eax, 320
    call pr_out
.ok:mov eax, [pr_x]
    mov [cw_x], eax
    mov eax, [pr_y]
    mov [cw_y], eax
    mov eax, 160
    mov ebx, 306
    mov ecx, 160
    mov edx, 44
    mov esi, s_ok
    xor edi, edi
    call wbtn
    mov eax, [pr_x]
    mov ebx, [pr_y]
    mov ecx, 480
    mov dl, [pr_file_menu]
    call sys_file_draw
    mov dword [cw_x], 0
    mov dword [cw_y], 0
.done:
    popad
    ret

d2_pr       db 0
pr_p        dd 0
pr_sz       dd 0
pr_cr       dd 0
pr_mo       dd 0
pr_ext      dd 0
pr_name     times 16 db 0
pr_buf      times 48 db 0
s_settings  db "Settings ", 0             ; пробел в конце нужен, чтобы по-русски было "Свойства", а не "Настройки"
s_pfile     db "File", 0
s_pformat   db "Format", 0
s_pname     db "Name: ", 0
s_psize     db "Size: ", 0
s_pbytes    db " bytes", 0
s_pfolder   db "folder", 0
s_pcreated  db "Created: ", 0
s_pmod      db "Modified: ", 0
s_unk       db "unknown", 0
s_ptype     db "Type: ", 0
s_pext      db "Extension: ", 0
s_popens    db "Opens in: ", 0
s_pnone     db "none", 0
s_ty0       db "Folder", 0
s_ty1       db "Text", 0
s_ty2       db "Picture", 0
s_ty3       db "itge document", 0
s_ty4       db "Program", 0
s_ty5       db "File", 0
s_on0       db "FloFile", 0
s_on1       db "FloText", 0
s_on2       db "FloPaint", 0
s_on3       db "FloItge", 0
s_on4       db "system", 0
s_on5       db "nothing", 0
pr_tn       dd s_ty0, s_ty1, s_ty2, s_ty3, s_ty4, s_ty5, s_ty5
pr_on       dd s_on0, s_on1, s_on2, s_on3, s_on4, s_on5, s_on5

s_fs3_preview db 0

; Standard window title controls and minimized restore captions (FloFile).
nm_minus_label db "-", 0
nm_close_label db "X", 0
nm_mini_label db "Name", 0
pr_minus_label db "-", 0
pr_close_label db "X", 0
pr_mini_label db "Props", 0

; FloFile modal window File/Exit menu states. Kept outside FAPI/KVAR fixed blocks.
nm_file_menu db 0
pr_file_menu db 0
nm_sys_title db "System", 0
pr_sys_title db "System", 0
