; Кнопка "минус" (свернуть) у окон и программ на весь экран и стрелка справа внизу со списком свёрнутых.
; Коды окон: 0 Main, 1 About, 2 Settings, 3 Clock, 4 Terminal, 5 Disks, 6 FloText, 7 FloFile, 8 FloPaint, 9 FloItge, 10 FloBoil
; Значения mn_ov: код + 1 - минус окна, 0x41 + k - строка k списка, 0x80 - стрелка

mn_fl   dd d2_main, d2_ab, d2_st, d2_ck, d2_tr, d2_dk, d2_text, d2_files, d2_paint, d2_itge, d2_boil
mn_rp   dd mx0, ab_x, st_x, ck_x, tr_x, dk_x
mn_app  db 2, 1, 3, 5, 4

; Кнопка 24x22 в точке eax, ebx; edi = 1 - нажата
mn_btn:
    pushad
    mov [xb_x], eax
    mov [xb_y], ebx
    call btn_colors
    mov dword [r_w], 24
    mov dword [r_h], 22
    mov [r_x], eax
    mov [r_y], ebx
    mov eax, [xb_bg]
    mov [r_c], eax
    call fill_rect
    mov eax, [xb_x]
    add eax, 6
    mov [r_x], eax
    mov eax, [xb_y]
    add eax, 10
    mov [r_y], eax
    mov dword [r_w], 12
    mov dword [r_h], 2
    mov eax, [xb_fg]
    mov [r_c], eax
    call fill_rect
    popad
    ret

; Кнопка у плавающего окна dl (0..5), если оно открыто
mn_fdraw:
    pushad
    movzx edx, dl
    mov esi, [mn_fl + edx * 4]
    cmp byte [esi], 0
    je .r
    mov esi, [mn_rp + edx * 4]
    mov eax, [esi]
    add eax, [esi + 8]
    sub eax, 60
    mov ebx, [esi + 4]
    add ebx, 8
    xor edi, edi
    lea ecx, [edx + 1]
    cmp cl, [mn_pr]
    jne .d
    cmp cl, [mn_ov]
    jne .d
    inc edi
.d: call mn_btn
.r: popad
    ret

; Кнопки у программ на весь экран
mn_pdraw:
    call hp_draw
    pushad
    mov edx, 6
.l: mov esi, [mn_fl + edx * 4]
    cmp byte [esi], 0
    je .n
    xor edi, edi
    lea ecx, [edx + 1]
    cmp cl, [mn_pr]
    jne .d
    cmp cl, [mn_ov]
    jne .d
    inc edi
.d: mov eax, 764
    mov ebx, 8
    call mn_btn
.n: inc edx
    cmp edx, 11
    jb .l
    call mn_arrow
    popad
    ret

; Есть ли программа на весь экран? ZF = 0 - есть
mn_prog:
    mov al, [d2_text]
    or al, [d2_files]
    or al, [d2_paint]
    or al, [d2_itge]
    or al, [d2_boil]
    ret

; Для программ: перерисовать кнопки EN, стрелку и список поверх окна
mn_over:
    pushad
    call mn_arrow
    popad
    ret

 ; Floppy OS 2.0: taskbar was removed by the author.
; Keep only the original EN/RU language switch at its desktop coordinates.
; mn_arrow is retained as an entry point for redraw and fullscreen app APIs.
mn_arrow:
    pushad
    xor edi, edi
    cmp byte [mn_pr], 0x81
    jne .lang
    cmp byte [mn_ov], 0x81
    jne .lang
    inc edi
.lang:
    mov eax, 640
    mov ebx, 508
    test edi, edi
    jz .shadow
    add eax, 4
    add ebx, 4
    jmp .drawlang
.shadow:
    mov dword [r_x], 644
    mov dword [r_y], 512
    mov dword [r_w], 44
    mov dword [r_h], 36
    mov dword [r_c], C_BLACK
    call fill_rect
.drawlang:
    mov ecx, 44
    mov edx, 36
    mov esi, s_kb_en
    cmp byte [kb_ru], 0
    je .langlabel
    mov esi, s_kb_ru
.langlabel:
    ; EN/RU uses absolute desktop coordinates. wbtn normally adds the
    ; current floating window origin (cw_x/cw_y); temporarily zero it.
    push dword [cw_x]
    push dword [cw_y]
    mov dword [cw_x], 0
    mov dword [cw_y], 0
    call wbtn
    pop dword [cw_y]
    pop dword [cw_x]
    popad
    ret

; Compatibility for fullscreen app redraws. The taskbar has no content.
mn_list:
    ret
pan_tick:
    ret
pan_resize_move:
    ret

; Те, что открыты, из маски убираем; список свёрнутых -> mn_lst, их число -> mn_n
mn_build:
    pushad
    xor ecx, ecx
    mov byte [mn_n], 0
.l: mov esi, [mn_fl + ecx * 4]
    cmp byte [esi], 0
    je .c
    btr dword [mn_mask], ecx
.c: bt dword [mn_mask], ecx
    jnc .n
    movzx eax, byte [mn_n]
    mov [mn_lst + eax], cl
    inc byte [mn_n]
.n: inc ecx
    cmp ecx, 11
    jb .l
    popad
    ret

; Мышь над кнопкой окна dl (0..5)? CF = 1 - окно под мышью (дальше не смотрим), mn_ov - если на кнопке
mn_chk:
    pushad
    movzx edx, dl
    mov esi, [mn_fl + edx * 4]
    cmp byte [esi], 0
    je .no
    mov esi, [mn_rp + edx * 4]
    mov eax, [m_x]
    sub eax, [esi]
    js .no
    cmp eax, [esi + 8]
    ja .no
    mov ebx, [m_y]
    sub ebx, [esi + 4]
    js .no
    cmp ebx, [esi + 12]
    ja .no
    mov ecx, [esi + 8]
    sub ecx, 60
    cmp eax, ecx
    jb .yes
    add ecx, 24
    cmp eax, ecx
    ja .yes
    cmp ebx, 8
    jb .yes
    cmp ebx, 30
    ja .yes
    inc edx
    mov [mn_ov], dl
.yes:
    popad
    stc
    ret
.no:popad
    clc
    ret

 ; Mouse hit testing: language button and window minimize controls only.
 ; There is no taskbar handle, resize region or launcher grid.
mn_find:
    pushad
    mov byte [mn_ov], 0
    cmp byte [d2_ist], 0
    jne .out
    cmp byte [d2_wl], 0
    jne .out
    cmp byte [d2_egg], 0
    jne .out
    cmp byte [sv_who], 0
    jne .out
    cmp byte [d2_err], 0
    jne .out
    cmp byte [d2_dlg], 0
    jne .out
    mov eax, [m_x]
    mov ebx, [m_y]
    cmp eax, 640
    jb .windows
    cmp eax, 684
    ja .windows
    cmp ebx, 508
    jb .windows
    cmp ebx, 544
    ja .windows
    mov byte [mn_ov], 0x81
    jmp .out
.windows:
    ; Only draw/hit the minimize control of the topmost window under mouse.
    movzx edx, byte [fz_hown]
    cmp edx, 6
    jne .notmain
    xor edx, edx
    call mn_chk
    jmp .out
.notmain:
    cmp edx, 1
    jb .programs
    cmp edx, 5
    ja .programs
    call mn_chk
    jmp .out
.programs:
    cmp edx, 6
    jae .out                       ; FloCalc/Calendar/Tasks own their title controls
    mov edx, 6
.ploop:
    mov esi, [mn_fl + edx * 4]
    cmp byte [esi], 0
    je .pnext
    mov eax, [m_x]
    mov ebx, [m_y]
    cmp eax, 764
    jb .out
    cmp eax, 788
    ja .out
    cmp ebx, 8
    jb .out
    cmp ebx, 30
    ja .out
    mov eax, edx
    inc eax
    mov [mn_ov], al
    jmp .out
.pnext:
    inc edx
    cmp edx, 11
    jb .ploop
    xor dl, dl
    call mn_chk
    jc .out
.out:
    popad
    ret

; Окно edx свернуть
mn_do:
    pushad
    bts dword [mn_mask], edx
    mov esi, [mn_fl + edx * 4]
    mov byte [esi], 0
    test edx, edx
    jnz .nm
    mov byte [mz_top], 0
.nm:cmp edx, 6
    jb .r
    movzx eax, byte [mn_app + edx - 6]
    call z_restore
.r: popad
    ret

; Окно edx развернуть
mn_restore:
    pushad
    btr dword [mn_mask], edx
    mov esi, [mn_fl + edx * 4]
    cmp edx, 6
    jae .p
    mov byte [esi], 1
    cmp edx, 1
    jb .main_z
    cmp edx, 5
    ja .r
    call fz_top
    jmp .r
.main_z:
    mov dl, 6
    call fz_top
    jmp .r
.p: movzx eax, byte [mn_app + edx - 6]
    call z_hide_others
    mov byte [esi], 1
.r: popad
    ret

; Кнопку отпустили
 ; Only EN/RU and minimize buttons remain; the taskbar is gone.
mn_release:
    pushad
    movzx eax, byte [mn_pr]
    mov byte [mn_pr], 0
    cmp al, [mn_ov]
    jne .done
    cmp al, 0x81
    je .lang
    cmp al, 1
    jb .done
    cmp al, 11
    ja .done
    dec eax
    mov edx, eax
    call mn_do
    jmp .done
.lang:
    xor byte [kb_ru], 1
.done:
    popad
    jmp redraw

; Retained only to read/write the existing Settings disk format.
pan_height db 68
; Never enters resize mode now that the taskbar has been removed.
pan_resize db 0

mn_mask dd 0
mn_ov   db 0
mn_pr   db 0
mn_n    db 0
mn_lst  times 12 db 0
s_kb_en db "EN", 0
s_kb_ru db "RU", 0
