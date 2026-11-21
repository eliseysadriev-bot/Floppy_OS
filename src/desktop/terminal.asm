; Окно Terminal (FloTerm.sys из flopsys/programs): строка команд как в DOS, команды работают с настоящей файловой системой Floppy
; Подключается из kernel32.asm. Окно таскается за заголовок и растягивается за квадрат в углу (d_ctx = 8)
; Номера в hit: 217 крестик, 218 заголовок, 219 квадрат в углу, 220 внутри окна
TR_BUF  equ 0x1A0000                    ; строки экрана: TR_L строк по TR_W знаков
TR_L    equ 100
TR_W    equ 80                          ; ширина строки в буфере
TR_C    equ 32                          ; сколько знаков помещается в строку окна

tr_open:
    mov byte [tr_menu], 0
    mov dl, 4
    call fz_top
    cmp byte [d2_tr], 0
    jne .have
    cmp byte [tr_hid], 0                ; терминал спрятался, когда из него запустили программу: всё как было
    je .new
    mov byte [tr_hid], 0
    jmp .have
.new:
    pushad
    call tr_reset
    popad
.have:
    mov byte [d2_tr], 1
    mov byte [tr_foc], 1
    jmp redraw

tr_reset:
    pushad
    mov edi, TR_BUF
    mov ecx, TR_L * TR_W / 4
    mov eax, 0x20202020
    cld
    rep stosd
    xor eax, eax
    mov [tr_ln], eax
    mov [tr_col], eax
    mov al, [sys_dsk]
    mov [tr_dsk], al
    mov byte [tr_par], 0
    mov byte [tr_dep], 0
    mov byte [tr_inlen], 0
    mov byte [tr_selected], 0
    mov byte [tr_sel_drag], 0
    mov byte [tr_last], 0
    mov byte [tr_mode], 0
    mov esi, s_trwel
    call tr_say
    mov esi, s_trhint
    call tr_say
    call tr_nl
    call tr_prompt
    popad
    ret

; Знак al в конец экранного буфера (10 - перевод строки)
tr_ch:
    pushad
    cmp al, 10
    je .nl
    cmp dword [tr_col], TR_C            ; строка кончилась - сначала перевод строки
    jb .w
    call tr_nlr
.w: mov edx, [tr_ln]
    imul edx, TR_W
    add edx, [tr_col]
    mov [TR_BUF + edx], al
    inc dword [tr_col]
    jmp .r
.nl:call tr_nlr
.r: popad
    ret

; Новая строка в буфере (старые уходят вверх)
tr_nlr:
    pushad
    mov dword [tr_col], 0
    inc dword [tr_ln]
    cmp dword [tr_ln], TR_L
    jb .cl
    mov esi, TR_BUF + TR_W
    mov edi, TR_BUF
    mov ecx, (TR_L - 1) * TR_W / 4
    cld
    rep movsd
    mov dword [tr_ln], TR_L - 1
.cl:mov edi, [tr_ln]
    imul edi, TR_W
    add edi, TR_BUF
    mov ecx, TR_W / 4
    mov eax, 0x20202020
    rep stosd
    popad
    ret

; Сообщение номер al: в режиме Floppy - ошибки Floppy, в режиме DOS - как в DOS
tr_msg:
    ; Floppy mode: every command error uses the common kernel dialog.
    ; Code 5x5..5x12 is mapped from terminal messages 0..7.
    cmp byte [tr_mode], 0
    jne .dos
    cmp al, 7
    ja .dos
    add al, 0x55
    mov [d2_err], al
    jmp redraw
.dos:
    movzx eax, al
    cmp eax, 7
    ja .unknown
    mov esi, [tr_dm + eax * 4]
    jmp tr_say
.unknown:
    mov esi, s_trbad
    jmp tr_say

tr_nl:
    push eax
    mov al, 10
    call tr_ch
    pop eax
    ret

tr_puts:
    pushad
.l: lodsb
    test al, al
    jz .e
    call tr_ch
    jmp .l
.e: popad
    ret

tr_say:
    call tr_puts
    jmp tr_nl

tr_num:
    pushad
    mov edi, tr_nb
    call u32str
    mov byte [edi], 0
    mov esi, tr_nb
    call tr_puts
    popad
    ret

tr_2d:
    pushad
    movzx eax, al
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    call tr_ch
    mov al, dl
    add al, '0'
    call tr_ch
    popad
    ret

; Путь: C:\папка\папка
tr_path:
    pushad
    movzx eax, byte [tr_dsk]
    mov al, [tr_dl + eax]
    call tr_ch
    mov al, ':'
    call tr_ch
    mov al, '\'
    call tr_ch
    xor ebx, ebx
.l: cmp bl, [tr_dep]
    jae .e
    test ebx, ebx
    jz .n
    mov al, '\'
    call tr_ch
.n: mov esi, ebx
    shl esi, 4
    add esi, tr_pth
    call tr_puts
    inc ebx
    jmp .l
.e: popad
    ret

tr_prompt:
    pushad
    ; In both command modes show the actual current directory, e.g. C:\flopsys\programs>
    call tr_path
    mov al, '>'
    call tr_ch
    mov al, ' '
    call tr_ch
    mov byte [tr_inlen], 0
    mov byte [tr_selected], 0
    mov byte [tr_sel_drag], 0
    mov eax, [tr_ln]
    mov [tr_startln], eax
    mov eax, [tr_col]
    mov [tr_startcol], eax
    popad
    ret

tr_typ:
    pushad
    movzx ebx, byte [tr_inlen]
    mov [tr_in + ebx], al
    inc byte [tr_inlen]
    call tr_ch
    popad
    ret

tr_bsp:
    pushad
    dec byte [tr_inlen]
    cmp dword [tr_col], 0               ; начало строки - назад на конец прошлой
    jne .a
    dec dword [tr_ln]
    mov dword [tr_col], TR_C
.a: dec dword [tr_col]
    mov ebx, [tr_ln]
    imul ebx, TR_W
    add ebx, [tr_col]
    mov byte [TR_BUF + ebx], 32
    popad
    ret

; Selection boundaries are byte offsets in the current unexecuted command.
; The history screen is not writable, and text there is not selected yet.
tr_copy_selected:
    pushad
    cmp byte [tr_selected], 0
    je .end
    movzx eax, byte [tr_sel_a]
    movzx ebx, byte [tr_sel_b]
    cmp eax, ebx
    jbe .order
    xchg eax, ebx
.order:
    mov ecx, ebx
    sub ecx, eax
    mov [clip_len], ecx
    lea esi, [tr_in + eax]
    mov edi, clip_buf
    cld
    rep movsb
.end:
    popad
    ret

; Delete only the selected input range, preserving the rest of the command.
tr_clear_selected:
    pushad
    cmp byte [tr_selected], 0
    je .end
    mov byte [tr_selected], 0
    movzx eax, byte [tr_sel_a]
    movzx ebx, byte [tr_sel_b]
    cmp eax, ebx
    jbe .order
    xchg eax, ebx
.order:
    cmp ebx, eax
    jbe .end
    ; Make a compact copy before reprinting the command after its prompt.
    xor edi, edi
    xor edx, edx
.copy:
    movzx ecx, byte [tr_inlen]
    cmp edx, ecx
    jae .copied
    cmp edx, eax
    jb .keep
    cmp edx, ebx
    jb .skip
.keep:
    mov cl, [tr_in + edx]
    mov [tr_tmp + edi], cl
    inc edi
.skip:
    inc edx
    jmp .copy
.copied:
    mov byte [tr_tmp + edi], 0
    mov [tr_tmplen], edi
.erase:
    cmp byte [tr_inlen], 0
    je .restore
    call tr_bsp
    jmp .erase
.restore:
    xor ebx, ebx
.rloop:
    cmp ebx, [tr_tmplen]
    jae .end
    mov al, [tr_tmp + ebx]
    call tr_typ
    inc ebx
    jmp .rloop
.end:
    popad
    ret

; Convert mouse coordinates into a current-command offset (0..tr_inlen).
; CF=1 means the mouse is over the editable command, not terminal history.
tr_mouse_offset:
    push ebx
    push ecx
    push edx
    mov eax, [m_y]
    sub eax, [tr_y]
    sub eax, 86
    jc .outside
    xor edx, edx
    mov ecx, 32
    div ecx
    add eax, [tr_fl]
    cmp eax, [tr_startln]
    jb .outside
    sub eax, [tr_startln]
    imul eax, TR_C
    mov ebx, eax
    mov eax, [m_x]
    sub eax, [tr_x]
    sub eax, 10
    jc .outside
    xor edx, edx
    mov ecx, 16
    div ecx
    cmp eax, TR_C
    jae .outside
    add ebx, eax
    sub ebx, [tr_startcol]
    jc .outside
    movzx ecx, byte [tr_inlen]
    cmp ebx, ecx
    jbe .valid
    mov ebx, ecx
.valid:
    mov eax, ebx
    stc
    jmp .done
.outside:
    clc
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; Mouse down in terminal text, then drag to select characters of current input.
tr_mouse_down:
    pushad
    mov byte [tr_sel_drag], 0
    call tr_mouse_offset
    jnc .done
    mov [tr_sel_a], al
    mov [tr_sel_b], al
    mov byte [tr_selected], 0
    mov byte [tr_sel_drag], 1
    call tr_body
.done:
    popad
    ret

tr_mouse_move:
    pushad
    cmp byte [tr_sel_drag], 0
    je .done
    call tr_mouse_offset
    jnc .done
    cmp al, [tr_sel_b]
    je .done
    mov [tr_sel_b], al
    mov byte [tr_selected], 0
    cmp al, [tr_sel_a]
    je .redraw
    mov byte [tr_selected], 1
.redraw:
    call tr_body
.done:
    popad
    ret

; Клавиша al в Terminal
; Закрыть окно Terminal
tr_exit:
    mov byte [tr_menu], 0
    mov byte [d2_tr], 0
    mov byte [tr_foc], 0
    jmp redraw

tr_key:
    pushad
    cmp al, 1                           ; Ctrl+A: select current command input
    je .selectall
    cmp al, 3                           ; Ctrl+C: copy selected input
    je .copy
    cmp al, 0x18                        ; Ctrl+X: cut selected input
    je .cut
    cmp al, 0x16                        ; Ctrl+V: paste shared text
    je .paste
    cmp al, 5                           ; Ctrl+E - выйти
    jne .k0
    popad
    jmp tr_exit
.k0:cmp byte [tr_menu], 0               ; меню открыто: любая клавиша его закрывает
    je .k1
    mov byte [tr_menu], 0
    popad
    jmp redraw
.k1:
    cmp al, 13
    je .ent
    cmp al, 8
    je .bs
    cmp al, 0x90
    je .up
    cmp al, 32
    jb .r
    CHKHI al, .r
    push eax
    call tr_clear_selected
    pop eax
    cmp byte [tr_inlen], 70
    jae .r
    call tr_typ
    jmp .d1
.bs:cmp byte [tr_selected], 0
    je .bsold
    call tr_clear_selected
    jmp .d1
.bsold:cmp byte [tr_inlen], 0
    je .r
    call tr_bsp
    jmp .d1
.up:mov byte [tr_selected], 0
    cmp byte [tr_inlen], 0
    je .u2
    call tr_bsp
    jmp .up
.u2:xor ebx, ebx
.u3:mov al, [tr_last + ebx]
    test al, al
    jz .d
    push ebx
    call tr_typ
    pop ebx
    inc ebx
    jmp .u3

; Current-line selection (no historical output selection in this phase).
.selectall:
    cmp byte [tr_inlen], 0
    je .r
    mov byte [tr_sel_a], 0
    mov al, [tr_inlen]
    mov [tr_sel_b], al
    mov byte [tr_selected], 1
    call tr_body
    jmp .r
.copy:
    cmp byte [tr_selected], 0
    je .r
    call tr_copy_selected
    jmp .r
.cut:
    cmp byte [tr_selected], 0
    je .r
    call tr_copy_selected
    call tr_clear_selected
    jmp .d1
.paste:
    call tr_clear_selected
    mov ecx, [clip_len]
    cmp ecx, 65536
    jbe .validclip
    jmp .r
.validclip:
    mov esi, clip_buf
.pasteloop:
    test ecx, ecx
    jz .d1
    cmp byte [tr_inlen], 70
    jae .d1
    lodsb
    dec ecx
    cmp al, 32
    jb .pasteloop                       ; no multiline command execution
    push ecx
    push esi
    call tr_typ
    pop esi
    pop ecx
    jmp .pasteloop

.ent:
    mov byte [tr_selected], 0
    movzx ebx, byte [tr_inlen]
    mov byte [tr_in + ebx], 0
    test ebx, ebx
    jz .nl0
    mov esi, tr_in
    mov edi, tr_last
    mov ecx, 72
    cld
    rep movsb
.nl0:
    call tr_nl
    call tr_exec
    cmp byte [d2_tr], 0
    jne .p
    cmp byte [tr_hid], 0                ; спрятался: строку приглашения готовим к возвращению
    je .r
    call tr_prompt
    jmp .r
.p: call tr_prompt
.d: call tr_body
    jmp .r
.d1:call tr_upd
.r: popad
    ret

; Разбор и запуск строки tr_in
tr_exec:
    pushad
    mov esi, tr_in
.sp:cmp byte [esi], ' '
    jne .w
    inc esi
    jmp .sp
.w: cmp byte [esi], 0
    je .x
    mov edi, esi
.lw:mov al, [edi]
    test al, al
    jz .le
    cmp al, ' '
    je .le
    cmp al, 'A'
    jb .nl
    cmp al, 'Z'
    ja .nl
    add al, 32
    mov [edi], al
.nl:inc edi
    jmp .lw
.le:cmp byte [edi], 0
    je .na
    mov byte [edi], 0
    inc edi
.sa:cmp byte [edi], ' '
    jne .na
    inc edi
    jmp .sa
.na:mov [tr_arg], edi
    mov [tr_cmd], esi
    cmp byte [esi + 1], ':'
    jne .tab
    cmp byte [esi + 2], 0
    jne .tab
    call tr_drive
    jmp .x
.tab:
    mov ebx, tr_ftab
    cmp byte [tr_mode], 0
    je .t
    mov ebx, tr_tab
.t: cmp byte [ebx], 0
    je .bad
    mov esi, [tr_cmd]
    mov edi, ebx
.c: mov al, [esi]
    cmp al, [edi]
    jne .nx
    test al, al
    jz .found
    inc esi
    inc edi
    jmp .c
.nx:cmp byte [ebx], 0
    je .n2
    inc ebx
    jmp .nx
.n2:add ebx, 5
    jmp .t
.found:
    mov esi, [tr_arg]
    call dword [edi + 1]
    jmp .x
.bad:
    mov al, 0
    call tr_msg
.x: mov byte [fs_par], 0
    popad
    ret

; Диск: c: o: i:
tr_drive:
    mov al, [esi]
    or al, 0x20
    xor ebx, ebx
.f: cmp al, [tr_dlw + ebx]
    je .ok
    inc ebx
    cmp ebx, 3
    jb .f
    mov al, 0
    jmp tr_msg
.ok:mov dl, [tr_dsk]
    mov [tr_dsk], bl
    movzx eax, bl
    call fs_setdisk
    jc .no
    mov byte [tr_dep], 0
    mov byte [tr_par], 0
    ret
.no:mov [tr_dsk], dl
    mov al, 4
    jmp tr_msg

; Диск и папка терминала становятся текущими. CF = диска нет
tr_fs:
    push eax
    movzx eax, byte [tr_dsk]
    call fs_setdisk
    jc .no
    mov al, [tr_par]
    mov [fs_par], al
    pop eax
    clc
    ret
.no:mov al, 4
    call tr_msg
    pop eax
    stc
    ret

; Слово из esi в [edi] (до 14 знаков), esi идёт за слово и пробелы. CF = слова нет
tr_tok:
    push ecx
    xor ecx, ecx
.l: mov al, [esi]
    test al, al
    jz .e
    cmp al, ' '
    je .e
    cmp ecx, 14
    jae .sk
    mov [edi + ecx], al
    inc ecx
.sk:inc esi
    jmp .l
.e: mov byte [edi + ecx], 0
.s2:cmp byte [esi], ' '
    jne .d
    inc esi
    jmp .s2
.d: cmp ecx, 1
    pop ecx
    ret

; Строки esi и edi равны? ZF = да
tr_seq:
    push esi
    push edi
    push eax
.l: mov al, [esi]
    cmp al, [edi]
    jne .x
    test al, al
    jz .x
    inc esi
    inc edi
    jmp .l
.x: pop eax
    pop edi
    pop esi
    ret

; Трогать нельзя? esi - имя. CF = нельзя (flopsys, всё внутри flopsys, файлы .sys)
tr_prot:
    push eax
    push ebx
    push edi
    mov al, [sys_dsk]
    cmp [tr_dsk], al
    jne .ext
    cmp byte [tr_dep], 0
    jne .inf
    mov edi, s_trfl
    call tr_seq
    je .y
    jmp .ext
.inf:
    push esi
    mov esi, tr_pth
    mov edi, s_trfl
    call tr_seq
    pop esi
    je .y
.ext:
    xor ebx, ebx
.l: cmp byte [esi + ebx], 0
    je .e
    inc ebx
    jmp .l
.e: cmp ebx, 4
    jb .n
    cmp dword [esi + ebx - 4], 0x7379732E
    je .y
.n: clc
    jmp .o
.y: stc
.o: pop edi
    pop ebx
    pop eax
    ret

tr_den:
    mov al, 3
    jmp tr_msg

cmd_help:
    cmp byte [tr_mode], 0
    jne .d
    mov esi, s_tfh1
    call tr_say
    mov esi, s_tfh2
    call tr_say
    mov esi, s_tfh3
    call tr_say
    mov esi, s_tfh4
    jmp tr_say
.d: mov esi, s_trh1
    call tr_say
    mov esi, s_trh2
    call tr_say
    mov esi, s_trh3
    call tr_say
    mov esi, s_trh4
    call tr_say
    mov esi, s_trh5
    jmp tr_say

cmd_cls:
    call tr_reset_buf
    ret

tr_reset_buf:
    pushad
    mov edi, TR_BUF
    mov ecx, TR_L * TR_W / 4
    mov eax, 0x20202020
    cld
    rep stosd
    xor eax, eax
    mov [tr_ln], eax
    mov [tr_col], eax
    popad
    ret

cmd_ver:
    mov esi, s_trban
    cmp byte [tr_mode], 0
    jne .d
    mov esi, s_trfv
.d: jmp tr_say

cmd_date:
    call fs_now
    mov ebx, eax
    shr eax, 20
    add eax, 2020
    call tr_num
    mov al, '-'
    call tr_ch
    mov eax, ebx
    shr eax, 16
    and eax, 15
    call tr_2d
    mov al, '-'
    call tr_ch
    mov eax, ebx
    shr eax, 11
    and eax, 31
    call tr_2d
    jmp tr_nl

cmd_time:
    call fs_now
    mov ebx, eax
    shr eax, 6
    and eax, 31
    call tr_2d
    mov al, ':'
    call tr_ch
    mov eax, ebx
    and eax, 63
    call tr_2d
    jmp tr_nl

cmd_exit:
    mov byte [d2_tr], 0
    mov byte [tr_foc], 0
    jmp redraw

cmd_echo:
    mov esi, [tr_arg]
    mov edi, esi
.f: mov al, [edi]
    test al, al
    jz .plain
    cmp al, '>'
    je .red
    inc edi
    jmp .f
.plain:
    jmp tr_say
.red:
    mov ecx, edi
    sub ecx, esi
.tr:test ecx, ecx
    jz .t0
    cmp byte [esi + ecx - 1], ' '
    jne .t0
    dec ecx
    jmp .tr
.t0:mov [tr_len], ecx
    mov [tr_tp], esi
    lea esi, [edi + 1]
.sp:cmp byte [esi], ' '
    jne .nm
    inc esi
    jmp .sp
.nm:mov edi, tr_t1
    call tr_tok
    jc .bad
    call tr_fs
    jc .r
    mov esi, tr_t1
    call tr_prot
    jc tr_den
    mov esi, tr_t1
    call dir_find
    jc .go
    cmp byte [edi + 15], 1
    je .cant
.go:mov esi, [tr_tp]
    mov ecx, [tr_len]
    mov edi, DATA_BUF
    cld
    rep movsb
    mov esi, tr_t1
    mov ecx, [tr_len]
    call file_write
    jc .cant
.r: ret
.bad:
    mov al, 0
    jmp tr_msg
.cant:
    mov al, 6
    jmp tr_msg

cmd_dir:
    call tr_fs
    jc .r
    cmp byte [tr_mode], 0
    jne .dh
    mov esi, s_trff
    call tr_say
    jmp .dl
.dh:mov esi, s_trdir
    call tr_puts
    call tr_path
    call tr_nl
.dl:
    mov byte [lst_dirs], 1
    movzx eax, byte [tr_dsk]
    mov edi, tr_lb
    call fs_list
    mov byte [lst_dirs], 0
    cmp byte [lst_n], 0
    jne .go
    mov esi, s_trempty
    jmp tr_say
.go:mov dword [tr_i], 0
.l: movzx eax, byte [lst_n]
    cmp [tr_i], eax
    jae .e
    mov esi, [tr_i]
    shl esi, 4
    add esi, tr_lb
    mov [tr_cur], esi
    mov eax, [tr_col]
    add eax, 16
    mov [tr_tg], eax
    call tr_puts
.p: mov eax, [tr_col]
    cmp eax, [tr_tg]
    jae .pd
    mov al, ' '
    call tr_ch
    jmp .p
.pd:mov esi, [tr_cur]
    cmp byte [esi + 15], 1
    jne .f
    mov esi, s_trdt
    cmp byte [tr_mode], 0
    jne .dd
    mov esi, s_trfd
.dd:
    call tr_puts
    jmp .n
.f: call dir_find
    jc .n
    mov eax, [edi + 16]
    call tr_num
    mov esi, s_trb
    call tr_puts
.n: call tr_nl
    inc dword [tr_i]
    jmp .l
.e: movzx eax, byte [lst_n]
    call tr_num
    mov esi, s_tri
    jmp tr_say
.r: ret

cmd_cd:
    mov esi, [tr_arg]
    cmp byte [esi], 0
    jne .a
    call tr_path
    jmp tr_nl
.a: cmp byte [esi], '\'
    je .top
    cmp byte [esi], '/'
    jne .b
.top:
    mov byte [tr_dep], 0
    mov byte [tr_par], 0
    ret
.b: cmp word [esi], '..'
    jne .c
    cmp byte [esi + 2], 0
    jne .c
    cmp byte [tr_dep], 0
    je .r
    dec byte [tr_dep]
    movzx ebx, byte [tr_dep]
    mov byte [tr_par], 0
    test ebx, ebx
    jz .r
    mov al, [tr_stk + ebx - 1]
    mov [tr_par], al
.r: ret
.c: mov edi, tr_t1
    call tr_tok
    jc .np
    call tr_fs
    jc .r
    mov esi, tr_t1
    call dir_find
    jnc .found
    ; Directory names are often stored lowercase (e.g. flopsys).
    ; Retry with lowercase ASCII so `cd FLOPSYS` also succeeds.
    mov edi, tr_t1
.lower:
    mov al, [edi]
    test al, al
    jz .retry
    cmp al, 'A'
    jb .next
    cmp al, 'Z'
    ja .next
    add al, 32
    mov [edi], al
.next:
    inc edi
    jmp .lower
.retry:
    mov esi, tr_t1
    call dir_find
    jc .np
.found:
    cmp byte [edi + 15], 1
    jne .np
    cmp byte [tr_dep], 8
    jae .np
    call dir_last_id
    movzx ebx, byte [tr_dep]
    mov [tr_stk + ebx], al
    mov [tr_par], al
    shl ebx, 4
    add ebx, tr_pth
    ; Copy the real directory name (not the typed casing) into the prompt.
    mov esi, edi
    mov edi, ebx
    mov ecx, 15
    cld
    rep movsb
    mov byte [edi], 0
    inc byte [tr_dep]
    ret
.np:mov al, 1
    jmp tr_msg

cmd_md:
    mov esi, [tr_arg]
    mov edi, tr_t1
    call tr_tok
    jc .bad
    call tr_fs
    jc .r
    mov esi, tr_t1
    call tr_prot
    jc tr_den
    mov esi, tr_t1
    call dir_mkdir
    jc .cant
.r: ret
.bad:
    mov al, 0
    jmp tr_msg
.cant:
    mov al, 6
    jmp tr_msg

cmd_rd:
    mov esi, [tr_arg]
    mov edi, tr_t1
    call tr_tok
    jc .bad
    call tr_fs
    jc .r
    mov esi, tr_t1
    call tr_prot
    jc tr_den
    mov esi, tr_t1
    call dir_find
    jc .nf
    cmp byte [edi + 15], 1
    jne .nf
    call dir_last_id
    call dir_has_child
    jc .ne
    mov esi, tr_t1
    call file_delete
    jc .nf
.r: ret
.bad:
    mov al, 0
    jmp tr_msg
.nf:mov al, 1
    jmp tr_msg
.ne:mov al, 7
    jmp tr_msg

cmd_del:
    mov esi, [tr_arg]
    mov edi, tr_t1
    call tr_tok
    jc .bad
    call tr_fs
    jc .r
    mov esi, tr_t1
    call tr_prot
    jc tr_den
    mov esi, tr_t1
    call dir_find
    jc .nf
    cmp byte [edi + 15], 1
    je .nf
    mov esi, tr_t1
    call file_delete
    jc .nf
.r: ret
.bad:
    mov al, 0
    jmp tr_msg
.nf:mov al, 2
    jmp tr_msg

cmd_ren:
    mov esi, [tr_arg]
    mov edi, tr_t1
    call tr_tok
    jc .bad
    mov edi, tr_t2
    call tr_tok
    jc .bad
    call tr_fs
    jc .r
    mov esi, tr_t1
    call tr_prot
    jc tr_den
    mov esi, tr_t2
    call tr_prot
    jc tr_den
    mov esi, tr_t1
    call dir_find
    jc .nf
    mov esi, tr_t1
    mov edx, tr_t2
    call dir_rename
    jc .used
.r: ret
.bad:
    mov al, 0
    jmp tr_msg
.nf:mov al, 2
    jmp tr_msg
.used:
    mov al, 5
    jmp tr_msg

cmd_copy:
    mov esi, [tr_arg]
    mov edi, tr_t1
    call tr_tok
    jc .bad
    mov edi, tr_t2
    call tr_tok
    jc .bad
    call tr_fs
    jc .r
    mov esi, tr_t2
    call tr_prot
    jc tr_den
    mov esi, tr_t1
    call dir_find
    jc .nf
    cmp byte [edi + 15], 1
    je .nf
    mov esi, tr_t2
    call dir_find
    jnc .used
    mov esi, tr_t1
    call file_read
    jc .nf
    mov ecx, eax
    mov esi, tr_t2
    call file_write
    jc .cant
.r: ret
.bad:
    mov al, 0
    jmp tr_msg
.nf:mov al, 2
    jmp tr_msg
.used:
    mov al, 5
    jmp tr_msg
.cant:
    mov al, 6
    jmp tr_msg

cmd_type:
    mov esi, [tr_arg]
    mov edi, tr_t1
    call tr_tok
    jc .bad
    call tr_fs
    jc .r
    mov esi, tr_t1
    call dir_find
    jc .nf
    cmp byte [edi + 15], 1
    je .nf
    mov esi, tr_t1
    call file_read
    jc .nf
    cmp eax, 3000
    jbe .ok
    mov eax, 3000
.ok:mov ecx, eax
    mov esi, DATA_BUF
.l: test ecx, ecx
    jz .e
    lodsb
    dec ecx
    cmp al, 10
    je .p
    cmp al, 32
    jb .l
    CHKHI al, .l
.p: call tr_ch
    jmp .l
.e: cmp dword [tr_col], 0
    je .r
    jmp tr_nl
.r: ret
.bad:
    mov al, 0
    jmp tr_msg
.nf:mov al, 2
    jmp tr_msg

; Тело окна: чёрное поле и текст
tr_box:
    add eax, [tr_x]
    add ebx, [tr_y]
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    jmp fill_rect

tr_glyph:
    pushad
    movzx eax, al
    shl eax, 4
    add eax, [0x500]
    mov ebp, eax
    xor ebx, ebx
.row:
    movzx edx, byte [ebp + ebx]
    test edx, edx
    jz .nr
    xor ecx, ecx
.c: cmp ecx, 8
    jae .nr
    mov eax, 7
    sub eax, ecx
    bt edx, eax
    jnc .n1
    mov esi, ecx
.r1:inc ecx
    cmp ecx, 8
    jae .e1
    mov eax, 7
    sub eax, ecx
    bt edx, eax
    jc .r1
.e1:mov eax, [tr_gx]
    add eax, esi
    mov [r_x], eax
    mov eax, [tr_gy]
    add eax, ebx
    mov [r_y], eax
    mov eax, ecx
    sub eax, esi
    mov [r_w], eax
    mov dword [r_h], 1
    mov dword [r_c], C_WHITE
    call fill_rect
    jmp .c
.n1:inc ecx
    jmp .c
.nr:inc ebx
    cmp ebx, 16
    jb .row
    popad
    ret

; Сколько строк видно (tr_vr) и какая строка буфера сверху -> eax
tr_lay:
    mov eax, [tr_ht]
    sub eax, 98
    shr eax, 5
    mov [tr_vr], eax
    mov eax, [tr_ln]
    inc eax
    sub eax, [tr_vr]
    jns .r
    xor eax, eax
.r: ret

; Перерисовать одну строку буфера eax (если она видна)
tr_drow:
    pushad
    cmp eax, [tr_ln]
    ja .e
    mov ebx, eax
    sub ebx, [tr_fl]
    jb .e
    cmp ebx, [tr_vr]
    jae .e
    mov [tr_rl], eax
    shl ebx, 5
    add ebx, 86
    mov [tr_ry], ebx
    mov dword [r_c], C_WHITE
    mov eax, 4
    mov ecx, [tr_w]
    sub ecx, 8
    mov edx, 32
    call tr_box
    mov eax, [tr_rl]
    imul eax, TR_W
    lea esi, [TR_BUF + eax]
    mov edi, tr_row
    mov ecx, TR_C
    cld
    rep movsb
    mov byte [edi], 0
    mov eax, [tr_ry]
    add eax, [tr_y]
    mov [t_y], eax
    mov eax, [tr_x]
    add eax, 10
    mov [t_x], eax
    mov dword [r_c], C_BLACK
    mov esi, tr_row
    call draw_big
    call tr_selection_overlay
    mov eax, [tr_rl]
    cmp eax, [tr_ln]
    jne .e
    cmp byte [tr_foc], 0
    je .e
    mov ebx, [tr_ry]
    add ebx, 28
    mov eax, [tr_col]
    shl eax, 4
    add eax, 10
    mov ecx, 16
    mov edx, 3
    mov dword [r_c], C_BLACK
    call tr_box
.e: popad
    ret

; Draw a visible selection over the currently typed command (Ctrl+A).
; This phase intentionally does not select historical output.
tr_selection_overlay:
    pushad
    cmp byte [tr_selected], 0
    je .out
    xor ebp, ebp
.next:
    movzx eax, byte [tr_inlen]
    cmp ebp, eax
    jae .out
    movzx eax, byte [tr_sel_a]
    movzx edx, byte [tr_sel_b]
    cmp eax, edx
    jbe .ordered
    xchg eax, edx
.ordered:
    cmp ebp, eax
    jb .skip
    cmp ebp, edx
    jae .skip
    mov eax, [tr_startcol]
    add eax, ebp
    xor edx, edx
    mov ecx, TR_C
    div ecx
    add eax, [tr_startln]
    cmp eax, [tr_rl]
    jne .skip
    ; edx = screen column within this display row
    mov eax, edx
    shl eax, 4
    add eax, 10
    mov [tr_selx], eax
    mov ebx, [tr_ry]
    mov dword [r_c], C_BLACK
    mov ecx, 16
    mov edx, 32
    call tr_box
    mov eax, [tr_x]
    add eax, [tr_selx]
    mov [t_x], eax
    mov eax, [tr_y]
    add eax, [tr_ry]
    mov [t_y], eax
    mov al, [tr_in + ebp]
    mov [tr_onechar], al
    mov byte [tr_onechar + 1], 0
    mov dword [r_c], C_WHITE
    mov esi, tr_onechar
    call draw_big
.skip:
    inc ebp
    jmp .next
.out:
    popad
    ret

tr_body:
    pushad
    mov dword [r_c], C_WHITE
    mov eax, 4
    mov ebx, 82
    mov ecx, [tr_w]
    sub ecx, 8
    mov edx, [tr_ht]
    sub edx, 86
    call tr_box
    call tr_lay
    mov [tr_fl], eax
    xor ebx, ebx
.l: cmp ebx, [tr_vr]
    jae .e
    mov eax, [tr_fl]
    add eax, ebx
    call tr_drow
    inc ebx
    jmp .l
.e: popad
    ret

; После набора одного знака: если ничего не сдвинулось - только две последние строки
tr_upd:
    pushad
    call tr_lay
    cmp eax, [tr_fl]
    jne .full
    mov eax, [tr_ln]
    test eax, eax
    jz .a
    dec eax
    call tr_drow
    inc eax
.a: call tr_drow
    popad
    ret
.full:
    popad
    jmp tr_body

tr_draw:
    pushad
    mov eax, [tr_x]
    mov [cw_x], eax
    mov eax, [tr_y]
    mov [cw_y], eax
    mov dword [r_c], C_BLACK
    mov eax, 8
    mov ebx, 8
    mov ecx, [tr_w]
    mov edx, [tr_ht]
    call tr_box
    xor eax, eax
    xor ebx, ebx
    call tr_box
    mov dword [r_c], C_WHITE
    mov eax, 2
    mov ebx, 2
    mov ecx, [tr_w]
    sub ecx, 4
    mov edx, [tr_ht]
    sub edx, 4
    call tr_box
    mov dword [r_c], C_BLACK
    mov eax, 2
    mov ebx, 40
    mov ecx, [tr_w]
    sub ecx, 4
    mov edx, 2
    call tr_box
    mov eax, 2
    mov ebx, 80
    mov ecx, [tr_w]
    sub ecx, 4
    mov edx, 2
    call tr_box
    mov eax, [tr_w]
    sub eax, 80
    shr eax, 1
    and eax, -8
    add eax, [tr_x]
    mov [t_x], eax
    mov eax, [tr_y]
    add eax, 4
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_trt
    call draw_big
    mov eax, [tr_x]
    add eax, [tr_w]
    sub eax, 32
    mov ebx, [tr_y]
    add ebx, 8
    xor edi, edi
    call xbtn
    call tr_body
    mov eax, [tr_x]
    mov ebx, [tr_y]
    movzx edi, byte [tr_menu]
    call wm_file
    cmp byte [tr_menu], 0
    je .nm
    mov eax, [tr_x]
    mov ebx, [tr_y]
    call wm_menu
.nm:popad
    ret

; Под мышью окно Terminal? CF = 1: да, al = 217..220
tr_hit:
    push ebx
    push esi
    push edi
    mov esi, [m_x]
    sub esi, [tr_x]
    jl .no
    mov edi, [m_y]
    sub edi, [tr_y]
    jl .no
    mov eax, [tr_w]
    cmp esi, eax
    ja .no
    mov ebx, [tr_ht]
    cmp edi, ebx
    ja .no
    push eax
    mov dl, [tr_menu]
    call wm_hit                         ; кнопка File (221) и пункт Exit (222)
    test al, al
    jz .nw
    add al, 220
    add esp, 4
    jmp .y
.nw:pop eax
    sub eax, 18
    cmp esi, eax
    jb .a
    sub ebx, 18
    cmp edi, ebx
    jb .a
    mov al, 220
    jmp .y
.a: mov eax, [tr_w]
    sub eax, 32
    cmp esi, eax
    jb .b
    add eax, 24
    cmp esi, eax
    ja .b
    cmp edi, 8
    jb .b
    cmp edi, 30
    ja .b
    mov al, 217
    jmp .y
.b: cmp edi, 2
    jb .z
    cmp edi, 36
    ja .z
    mov eax, [tr_w]
    sub eax, 36
    cmp esi, eax
    ja .z
    cmp esi, 4
    jb .z
    mov al, 218
    jmp .y
.z: mov al, 220
.y: stc
    jmp .o
.no:clc
.o: pop edi
    pop esi
    pop ebx
    ret


tr_press:
    mov byte [tr_foc], 1
    cmp al, 221                         ; File
    jne .f1
    xor byte [tr_menu], 1
    jmp redraw
.f1:cmp al, 222                         ; Exit в меню File
    jne .f2
    jmp tr_exit
.f2:cmp byte [tr_menu], 0               ; нажали мимо меню - оно закрывается
    je .f3
    mov byte [tr_menu], 0
    push eax
    call redraw
    pop eax
.f3:cmp al, 217
    jne .a
    mov byte [d2_tr], 0
    mov byte [tr_foc], 0
    jmp redraw
.a: cmp al, 218
    jne .b
    mov bl, 1
    mov byte [d_ctx], 8
    jmp drag_start
.b: cmp al, 219
    jne .c
    mov bl, 6
    mov byte [d_ctx], 8
    jmp drag_start
.c: call tr_mouse_down
    jmp tr_body

; Команды старого текстового Floppy 1.1
cmd_about:
    mov esi, s_tfa1
    call tr_say
    mov esi, s_tfa2
    jmp tr_say

cmd_credits:
    mov esi, s_tfc1
    call tr_say
    mov esi, s_tfc2
    call tr_say
    mov esi, s_tfc3
    call tr_say
    mov esi, s_tfc4
    call tr_say
    mov esi, s_tfc5
    jmp tr_say

cmd_panic:                              ; экран смерти по команде
    mov eax, 0xFF
    jmp kpanic2

cmd_reboot:
    mov al, 0xFE
    out 0x64, al
    jmp $

; create имя: новый пустой файл
cmd_create:
    mov esi, [tr_arg]
    xor ecx, ecx
.n: mov al, [esi + ecx]
    test al, al
    jz .ln
    cmp al, ' '
    je .ln
    inc ecx
    jmp .n
.ln:test ecx, ecx
    jnz .l1
    mov byte [d2_err], 0x5D       ; Error 5x13: filename required
    jmp redraw
.l1:cmp ecx, 14
    jbe .l2
    mov byte [d2_err], 0x5E       ; Error 5x14: filename too long
    jmp redraw
.l2:mov edi, tr_t1
    call tr_tok
    call tr_fs
    jc .r
    mov esi, tr_t1
    call tr_prot
    jc tr_den
    mov esi, tr_t1
    call dir_find
    jnc .ex
    mov esi, tr_t1
    xor ecx, ecx
    call file_write
    jc .cant
.r: ret
.ex:mov al, 5
    jmp tr_msg
.cant:
    mov al, 6
    jmp tr_msg

; disk O - перейти на диск
cmd_disk:
    mov esi, [tr_arg]
    cmp byte [esi], 0
    jne tr_drive
    mov al, 0
    jmp tr_msg

; disks - какие диски есть
cmd_disks:
    mov dword [tr_i], 0
.l: cmp dword [tr_i], 3
    jae .e
    mov esi, s_tfdk
    call tr_puts
    mov eax, [tr_i]
    mov al, [tr_dl + eax]
    call tr_ch
    mov eax, [tr_i]
    call fs_setdisk
    jnc .ok
    mov esi, s_tfnone
    call tr_puts
.ok:call tr_nl
    inc dword [tr_i]
    jmp .l
.e: ret

; dos mode / dos mode-no
cmd_dos:
    mov esi, [tr_arg]
    mov edi, esi
.lw:mov al, [edi]
    test al, al
    jz .c
    cmp al, 'A'
    jb .nx
    cmp al, 'Z'
    ja .nx
    add al, 32
    mov [edi], al
.nx:inc edi
    jmp .lw
.c: mov edi, s_tfmode
    call tr_seq
    jne .c2
    mov byte [tr_mode], 1
    mov esi, s_tfdon
    jmp tr_say
.c2:mov edi, s_tfmno
    call tr_seq
    jne .bad
    mov byte [tr_mode], 0
    mov esi, s_tfdoff
    jmp tr_say
.bad:
    mov al, 0
    jmp tr_msg

; run имя: запустить программу или открыть файл из текущей папки
cmd_run:
    mov esi, [tr_arg]
    mov edi, tr_t1
    call tr_tok
    jc .nf
    call tr_fs
    jc .r
    mov esi, tr_t1
    call dir_find
    jc .nf
    cmp byte [edi + 15], 1
    je .nf
    mov edi, tr_runs                    ; программы Floppy
    xor ebx, ebx
.l: cmp byte [edi], 0
    je .doc
    mov esi, tr_t1
    call tr_seq
    je .hit
.s: mov al, [edi]
    inc edi
    test al, al
    jnz .s
    inc ebx
    jmp .l
.hit:
    mov byte [tr_foc], 0
    cmp ebx, 9
    jae .doc
    cmp byte [tr_rhid + ebx], 0         ; программа на весь экран - терминал прячется
    je .go
    call tr_hide
.go:jmp [tr_rjmp + ebx * 4]
.doc:                                   ; документы: .txt - FloText, .pcf - FloPaint, .sga - itge
    mov esi, tr_t1
    xor ecx, ecx
.e: cmp byte [esi + ecx], 0
    je .ee
    inc ecx
    jmp .e
.ee:cmp ecx, 5
    jb .nf
    mov eax, [esi + ecx - 4]
    or eax, 0x20202000
    cmp eax, 0x7478742E
    je .hd
    cmp eax, 0x6663702E
    je .hd
    cmp eax, 0x6167732E
    jne .nf
.hd:call tr_hide
    mov dl, [tr_par]
    mov [fs_par], dl
    cmp eax, 0x7478742E
    jne .d1
    mov al, [tr_dsk]
    jmp text_open_named
.d1:cmp eax, 0x6663702E
    jne .d2
    mov al, [tr_dsk]
    jmp paint_open_named
.d2:cmp eax, 0x6167732E
    jne .d3
    call itge_open
    mov esi, tr_t1
    mov dl, [tr_par]
    mov [fs_par], dl
    mov al, [tr_dsk]
    jmp itge_open_named
.d3:
.nf:mov al, 2
    jmp tr_msg
.r: ret
.self:
    mov byte [tr_foc], 1
    ret

.tm:cmp byte [d2_tm], 0
    jne .r
    jmp tm_toggle

tr_hide:
    mov byte [d2_tr], 0
    mov byte [tr_foc], 0
    mov byte [tr_hid], 1
    ret


d2_tr       db 0
tr_hid      db 0
tr_menu     db 0
tr_mode     db 0                        ; 0 - команды Floppy, 1 - команды DOS
tr_foc      db 0
tr_selected db 0                      ; selected range of current command line
tr_sel_drag db 0
tr_sel_a db 0
tr_sel_b db 0
tr_tmplen dd 0
tr_tmp times 72 db 0
tr_startln dd 0                       ; first input character after prompt
tr_startcol dd 0
tr_selx dd 0
tr_onechar db 0, 0
tr_x        dd 120                      ; x, y, w, h подряд: swap_ctx таскает окно
tr_y        dd 100
tr_w        dd 552
tr_ht       dd 398
tr_ln       dd 0
tr_col      dd 0
tr_inlen    db 0
tr_dsk      db 0
tr_par      db 0
tr_dep      db 0
tr_stk      equ KBSS
tr_pth      equ KBSS + 8
tr_in       equ KBSS + 136
tr_last     equ KBSS + 216
tr_row      equ KBSS + 296
tr_t1       equ KBSS + 336
tr_t2       equ KBSS + 352
tr_nb       equ KBSS + 368
tr_lb       equ KBSS + 384
tr_arg      dd 0
tr_cmd      dd 0
tr_len      dd 0
tr_tp       dd 0
tr_i        dd 0
tr_cur      dd 0
tr_tg       dd 0
tr_gx       dd 0
tr_gy       dd 0
tr_vc       dd 0
tr_vr       dd 0
tr_fl       dd 0
tr_rl       dd 0
tr_ry       dd 0
tr_dl       db "COI"
tr_dlw      db "coi"
s_trt       db "Terminal", 0
s_trban     db "Floppy 1.1 Terminal", 0
s_trhint    db "Type help", 0
s_trbad     db "Bad command or file name", 0
s_trnp      db "Path not found", 0
s_trnf      db "File not found", 0
s_trden     db "Access denied", 0
s_trnd      db "Drive not ready", 0
s_trused    db "Name is already used", 0
s_trcant    db "Can't create it", 0
s_trne      db "Folder is not empty", 0
s_trdir     db "Directory of ", 0
s_trempty   db "(empty)", 0
s_trdt      db "<DIR>", 0
s_trb       db " bytes", 0
s_tri       db " item(s)", 0
s_trfl      db "flopsys", 0
s_trh1      db "dir cd md rd del ren copy", 0
s_trh2      db "type echo date ver cls exit", 0
s_trh3      db "C: O: I: - change the disk", 0
s_trh4      db "echo text > name - new file", 0
%macro TC 2
    db %1, 0
    dd %2
%endmacro
tr_tab:
    TC "help", cmd_help
    TC "cls", cmd_cls
    TC "ver", cmd_ver
    TC "date", cmd_date
    TC "time", cmd_time
    TC "echo", cmd_echo
    TC "dir", cmd_dir
    TC "ls", cmd_dir
    TC "cd", cmd_cd
    TC "md", cmd_md
    TC "mkdir", cmd_md
    TC "rd", cmd_rd
    TC "rmdir", cmd_rd
    TC "del", cmd_del
    TC "erase", cmd_del
    TC "ren", cmd_ren
    TC "rename", cmd_ren
    TC "copy", cmd_copy
    TC "type", cmd_type
    TC "exit", cmd_exit
    TC "dos", cmd_dos
    db 0
tr_runs     db "FloText.sys", 0, "FloFile.sys", 0, "FloCalc.sys", 0, "FloPaint.sys", 0, "FloTasks.sys", 0
            db "FloItge.sys", 0, "FloClock.sys", 0, "FloTerm.sys", 0, "FloBoil.sys", 0
            db 0
tr_rhid     db 1, 1, 1, 1, 1, 1, 1, 0, 1
tr_rjmp     dd text_open, files_open, calc_open, paint_open, cmd_run.tm, itge_open, ck_open, cmd_run.self, boil_open
tr_dm       dd s_trbad, s_trnp, s_trnf, s_trden, s_trnd, s_trused, s_trcant, s_trne
s_trwel     db "Welcome to Floppy 1.1", 0
s_trfv      db "Floppy 1.1", 0
s_trfp      db ":> ", 0
s_trff      db "Files on disk:", 0
s_trfd      db "folder", 0
s_tfa1      db "Floppy 1.1 - 32-bit OS", 0
s_tfa2      db "written in Assembly", 0
s_tfc1      db "I am the developer of Floppy 1.1", 0
s_tfc2      db "and I respect everyone who", 0
s_tfc3      db "has downloaded the code -", 0
s_tfc4      db "after all, this is the", 0
s_tfc5      db "first truly working OS.", 0
s_tfdk      db "Disk ", 0
s_tfnone    db " - none", 0
s_tfmode    db "mode", 0
s_tfmno     db "mode-no", 0
s_tfdon     db "DOS mode", 0
s_tfdoff    db "Floppy mode", 0
s_tfh1      db "dir cd disk disks run read", 0
s_tfh2      db "create delf echo clr time date", 0
s_tfh3      db "ver about credits reboot exit", 0
s_tfh4      db "dos mode - DOS commands", 0
s_trh5      db "dos mode-no - Floppy commands", 0
tr_ftab:
    TC "help", cmd_help
    TC "clr", cmd_cls
    TC "ver", cmd_ver
    TC "about", cmd_about
    TC "credits", cmd_credits
    TC "time", cmd_time
    TC "date", cmd_date
    TC "echo", cmd_echo
    TC "dir", cmd_dir
    TC "cd", cmd_cd
    TC "disk", cmd_disk
    TC "disks", cmd_disks
    TC "run", cmd_run
    TC "read", cmd_type
    TC "create", cmd_create
    TC "delf", cmd_del
    TC "reboot", cmd_reboot
    TC "panic", cmd_panic
    TC "exit", cmd_exit
    TC "dos", cmd_dos
    db 0
