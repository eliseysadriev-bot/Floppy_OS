; FloTasks - диспетчер задач (Ctrl+Alt+T)
; Подключается из kernel32.asm (%include)

; FloTasks: диспетчер задач (Ctrl+Alt+T)
; Что запущено: tm_list - виды (0 диспетчер, 1 main, 2 FloText, 3 FloFile, 4 FloCalc, 5 FloPaint, 6 itge, 7 Boil,
; 8 Clock, 9 Terminal, 10 About, 11 Settings, 12 Disks, 13 ошибка), tm_n - сколько
tm_build:
    pushad
    mov byte [tm_list], 0
    mov byte [tm_n], 1
    mov esi, 1
.l: mov ebx, [tm_flags + esi * 4]
    cmp byte [ebx], 0
    jne .ad
    movzx eax, byte [tm_zapp + esi]     ; спрятанное приложение тоже в списке
    test al, al
    jz .n
    call z_has
    jnc .n
.ad:movzx ebx, byte [tm_n]
    mov eax, esi
    mov [tm_list + ebx], al
    inc byte [tm_n]
.n: inc esi
    cmp esi, TM_K
    jb .l
    popad
    ret

tm_toggle:
    xor byte [d2_tm], 1
    jz .c
    mov dl, 9
    call fz_top
    call tm_build
    movzx eax, byte [tm_n]
    imul eax, 40
    add eax, 104
    and eax, -8
    cmp eax, 136
    jae .h
    mov eax, 136
.h: mov [tm_h], eax
    mov byte [tm_menu], 0
.c: jmp redraw

; Прямоугольник внутри окна: eax, ebx - угол, ecx, edx - размер, цвет в r_c
tm_box:
    add eax, [tm_x]
    add ebx, [tm_y]
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    jmp fill_rect

tm_draw:
    pushad
    call tm_build
    mov eax, [tm_x]
    mov [cw_x], eax
    mov eax, [tm_y]
    mov [cw_y], eax
    mov dword [r_c], C_BLACK
    mov eax, 8
    mov ebx, 8
    mov ecx, [tm_w]
    mov edx, [tm_h]
    call tm_box
    xor eax, eax
    xor ebx, ebx
    call tm_box
    mov dword [r_c], C_WHITE
    mov eax, 2
    mov ebx, 2
    mov ecx, [tm_w]
    sub ecx, 4
    mov edx, [tm_h]
    sub edx, 4
    call tm_box
    mov dword [r_c], C_BLACK
    mov eax, 2
    mov ebx, 40
    mov ecx, [tm_w]
    sub ecx, 4
    mov edx, 2
    call tm_box
    mov eax, 2
    mov ebx, 80
    mov ecx, [tm_w]
    sub ecx, 4
    mov edx, 2
    call tm_box
    mov eax, [tm_w]
    sub eax, 18
    mov ebx, [tm_h]
    sub ebx, 18
    mov ecx, 16
    mov edx, 16
    call tm_box
    mov eax, [tm_w]                     ; заголовок по центру
    sub eax, 80
    shr eax, 1
    and eax, -8
    add eax, [tm_x]
    mov [t_x], eax
    mov eax, [tm_y]
    add eax, 4
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_tm
    call draw_big
    mov eax, [tm_x]
    add eax, [tm_w]
    sub eax, 32
    mov ebx, [tm_y]
    add ebx, 8
    xor edi, edi
    call xbtn
    xor ebp, ebp
.r: movzx eax, byte [tm_n]
    cmp ebp, eax
    jae .e
    mov ebx, ebp
    imul ebx, 40
    add ebx, 88                         ; y строки внутри окна
    lea eax, [ebx + 36]
    mov ecx, [tm_h]
    sub ecx, 4
    cmp eax, ecx
    ja .e
    movzx esi, byte [tm_list + ebp]
    mov esi, [tm_names + esi * 4]
    mov eax, [tm_x]
    add eax, 16
    mov [t_x], eax
    mov eax, [tm_y]
    add eax, ebx
    add eax, 2
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    push ebx
    call draw_big
    pop ebx
    mov eax, [tm_w]
    sub eax, 136
    mov ecx, 120
    mov edx, 36
    mov esi, s_tmc
    xor edi, edi
    cmp byte [ui_btn_owner], 4
    jne .button_up
    cmp byte [ui_btn_id], 65
    jne .button_up
    push eax
    mov eax, ebp
    cmp al, [ui_btn_row]
    pop eax
    jne .button_up
    mov edi, 1
.button_up:
    call wbtn
    inc ebp
    jmp .r
.e: mov eax, [tm_x]
    mov ebx, [tm_y]
    movzx edi, byte [tm_menu]
    call wm_file
    cmp byte [tm_menu], 0
    je .nm
    mov eax, [tm_x]
    mov ebx, [tm_y]
    call wm_menu
.nm:popad
    ret

; Под мышью окно диспетчера? CF = 1: да, al = 64 крестик, 65.. Close, 75 заголовок, 76 квадрат, 77 просто окно;
; CF = 0: мимо окна
tm_hit:
    push ebx
    push esi
    push edi
    mov esi, [m_x]
    sub esi, [tm_x]
    jl .no
    mov edi, [m_y]
    sub edi, [tm_y]
    jl .no
    mov eax, [tm_w]
    cmp esi, eax
    ja .no
    mov ebx, [tm_h]
    cmp edi, ebx
    ja .no
    push eax
    mov dl, [tm_menu]
    call wm_hit                         ; кнопка File (66) и пункт Exit (67)
    test al, al
    jz .nw
    add al, 65
    add esp, 4
    jmp .y
.nw:pop eax
    sub eax, 18
    cmp esi, eax
    jb .a
    sub ebx, 18
    cmp edi, ebx
    jb .a
    mov al, 121
    jmp .y
.a: mov eax, [tm_w]
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
    mov al, 64
    jmp .y
.b: mov eax, [tm_w]
    sub eax, 136
    cmp esi, eax
    jb .c
    add eax, 120
    cmp esi, eax
    ja .c
    sub edi, 88
    jl .c
    mov eax, edi
    xor edx, edx
    mov ebx, 40
    div ebx
    cmp edx, 36
    ja .z
    cmp al, [tm_n]
    jae .z
    mov [tm_hr], al                     ; какая строка
    mov al, 65
    jmp .y
.c: mov edi, [m_y]
    sub edi, [tm_y]
    cmp edi, 2
    jb .z
    cmp edi, 36
    ja .z
    mov eax, [tm_w]
    sub eax, 36
    cmp esi, eax
    ja .z
    cmp esi, 4
    jb .z
    mov al, 120
    jmp .y
.z: mov al, 122
.y: stc
    jmp .o
.no:clc
.o: pop edi
    pop esi
    pop ebx
    ret

; Нажали мышью в диспетчере: al - что (64..77)
tm_press:
    cmp al, 66                          ; File
    jne .f1
    xor byte [tm_menu], 1
    jmp redraw
.f1:cmp al, 67                          ; Exit в меню File
    je tm_exit
    cmp byte [tm_menu], 0               ; нажали мимо меню - оно закрывается
    je .f2
    mov byte [tm_menu], 0
    push eax
    call redraw
    pop eax
.f2:cmp al, 64
    jne .a
    mov byte [d2_tm], 0
    jmp redraw
.a: cmp al, 120
    jne .b
    mov bl, 1
    mov byte [d_ctx], 3
    jmp drag_start
.b: cmp al, 121
    jne .c
    mov bl, 6
    mov byte [d_ctx], 3
    jmp drag_start
.c: cmp al, 65
    jne .r
    movzx ebx, byte [tm_hr]             ; Close в строке: закрыть то, что там написано
    movzx eax, byte [tm_list + ebx]
    jmp [tm_kill + eax * 4]
.r: ret

tm_exit:
tm_k0:
    mov byte [tm_menu], 0
    mov byte [d2_tm], 0
    jmp redraw
tm_k1:
    mov byte [d2_main], 0
    jmp redraw
tm_k8:
    mov byte [d2_ck], 0
    jmp redraw
tm_k9:
    mov byte [d2_tr], 0
    mov byte [tr_foc], 0
    mov byte [tr_hid], 0
    jmp redraw
tm_k10:
    mov byte [d2_ab], 0
    jmp redraw
tm_k11:
    mov byte [d2_st], 0
    jmp redraw
tm_k13:
    mov byte [d2_err], 0
    jmp redraw


; данные диспетчера
TM_K        equ 15
tm_n        db 0
tm_menu     db 0
tm_hr       db 0
tm_list     times TM_K db 0
tm_zapp     db 0, 0, 2, 1, 0, 3, 5, 4, 0, 0, 0, 0, 0, 0, 0
tm_x        dd 232
tm_y        dd 160
tm_w        dd 336
tm_h        dd 192
tm_names    dd s_tm, s_main, s_tx_title, s_files, s_flocalc, s_fpaint, s_tmn_it, s_tmn_bo
            dd s_ckt, s_trt, s_about, s_tmn_st, s_dk_t, s_tmn_er, s_tmn_cal
tm_flags    dd d2_tm, d2_main, d2_text, d2_files, d2_calc, d2_paint, d2_itge, d2_boil
            dd d2_ck, d2_tr, d2_ab, d2_st, d2_dk, d2_err, d2_cal
tm_kill     dd tm_k0, tm_k1, text_exit, files_close, calc_exit, paint_close, itge_close, boil_close
            dd tm_k8, tm_k9, tm_k10, tm_k11, dk_close, tm_k13, cal_exit
s_tmn_it    db "FloItge", 0
s_tmn_bo    db "FloBoil", 0
s_tmn_st    db "Setting", 0
s_tmn_er    db "Error", 0
s_tmn_cal   db "FloCalendar", 0
s_tm        db "Tasks", 0
s_tmc       db "Close", 0
alt         db 0
