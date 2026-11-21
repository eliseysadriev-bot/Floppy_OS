; Диалог Save to / Open
; Подключается из kernel32.asm (%include)

; диалог Save to / Open
%macro WRECT 5                          ; прямоугольник от угла диалога: x, y, ширина, высота, цвет
    mov eax, %1
    add eax, [cw_x]
    mov [r_x], eax
    mov eax, %2
    add eax, [cw_y]
    mov [r_y], eax
    mov dword [r_w], %3
    mov dword [r_h], %4
    mov dword [r_c], %5
    call fill_rect
%endmacro
%macro WRECTX 5                         ; как WRECT, но x - ячейка памяти
    mov eax, %1
    add eax, [cw_x]
    mov [r_x], eax
    mov eax, %2
    add eax, [cw_y]
    mov [r_y], eax
    mov dword [r_w], %3
    mov dword [r_h], %4
    mov dword [r_c], %5
    call fill_rect
%endmacro
%macro WRECTW 5                         ; от угла диалога: x, y, ширина = dlg_w - %3, высота, цвет
    mov eax, %1
    add eax, [cw_x]
    mov [r_x], eax
    mov eax, %2
    add eax, [cw_y]
    mov [r_y], eax
    mov eax, [dlg_w]
    sub eax, %3
    mov [r_w], eax
    mov dword [r_h], %4
    mov dword [r_c], %5
    call fill_rect
%endmacro
%macro WRECTV 5                         ; x, y - ячейки памяти (от угла диалога), ширина, высота, цвет
    mov eax, [%1]
    add eax, [cw_x]
    mov [r_x], eax
    mov eax, [%2]
    add eax, [cw_y]
    mov [r_y], eax
    mov dword [r_w], %3
    mov dword [r_h], %4
    mov dword [r_c], %5
    call fill_rect
%endmacro
%macro HITR 5                           ; esi, edi - мышь от угла диалога
    cmp esi, %1
    jb %%n
    cmp esi, %2
    ja %%n
    cmp edi, %3
    jb %%n
    cmp edi, %4
    ja %%n
    mov al, %5
    ret
%%n:
%endmacro

; al = 1 - сохранить, 2 - открыть
dlg_open:
    mov byte [dl_app], 0
    jmp dlg_open_in

; То же для FloPaint (файлы .pcf)
dlg_open_p:
    mov byte [dl_app], 1
    jmp dlg_open_in

; То же для itge (файлы .sga)
dlg_open_i:
    mov byte [dl_app], 2
    jmp dlg_open_in

; Экспорт из itge (имя не подставляем, расширение можно менять)
dlg_open_x:
    mov byte [dl_app], 3
dlg_open_in:
    mov byte [dlg_file_menu], 0
    call wait_start
    mov [d2_dlg], al
    mov byte [d2_conf], 0
    mov byte [dl_conf_file_menu], 0
    mov byte [dl_conf_min], 0
    mov byte [dl_scr], 0
    mov al, [sys_dsk]                   ; диалог открывается на главном диске
    mov [dl_disk], al
    mov byte [dl_len], 0
    mov byte [dl_car], 0
    mov byte [dl_name], 0
    mov byte [dl_anc], 0xFF
    mov byte [dl_nohint], 0
    mov byte [dl_par], 0
    mov word [dl_fs3par], 0
    mov byte [dl_fs3page], 0
    mov byte [dl_dep], 0
    mov byte [dl_sel], 0xFF
    mov byte [dl_ren], 0
    mov byte [dl_ctx], 0
    mov esi, t2_nm
    mov al, [t2_dsk]
    cmp byte [dl_app], 0
    je .ha
    mov esi, pa_nm
    mov al, [pa_dsk]
    cmp byte [dl_app], 1
    je .ha
    mov esi, it_nm
    mov al, [it_dsk]
    cmp byte [dl_app], 3
    jne .ha
    mov al, 0xFF
.ha:cmp al, 0xFF
    je .l
    mov [dl_disk], al                   ; уже есть файл: диск и имя оттуда
    cmp byte [d2_dlg], 2                ; при открытии имя не подставляем: файл выбирают в списке
    je .l
    mov edi, dl_name
    xor ecx, ecx
.c: lodsb
    stosb
    test al, al
    jz .ce
    inc ecx
    jmp .c
.ce:mov [dl_len], cl
    mov [dl_car], cl
.l: cmp byte [dl_app], 3
    jne .nx
    mov byte [dl_nohint], 1             ; экспорт: формат - настоящий текст в поле, его можно стереть и заменить
    mov esi, it_nm
    mov edi, dl_name
    xor ecx, ecx
.xn:cmp ecx, 10
    jae .xe
    mov al, [esi + ecx]
    test al, al
    jz .xe
    cmp al, '.'
    je .xe
    mov [edi + ecx], al
    inc ecx
    jmp .xn
.xe:mov [dl_car], cl
    mov dword [edi + ecx], 0x6167732E   ; ".sga"
    mov byte [edi + ecx + 4], 0
    add ecx, 4
    mov [dl_len], cl
.nx:call dlg_list
    call wait_end
    jmp redraw

dlg_list:
    pushad
    movzx eax, byte [dl_disk]
    mov edi, dl_names
    mov dword [lst_ext], 0x7478742E
    cmp byte [dl_app], 0
    jne .nt0
    cmp byte [d2_dlg], 2                ; Open в FloText: ещё .sec (пасхалка)
    jne .le
    mov dword [lst_ext], 2
    jmp .le
.nt0:
    mov dword [lst_ext], 0x6663702E
    cmp byte [dl_app], 1
    je .le
    mov dword [lst_ext], 0x6167732E
    cmp byte [dl_app], 2
    jne .le
    cmp byte [d2_dlg], 2                ; Open в itge: ещё .pcf и .txt
    jne .le
    mov dword [lst_ext], 1
.le:
    mov dl, [dl_par]
    mov [fs_par], dl
    cmp byte [dl_app], 0
    jne .list
    call fs_setdisk
    cmp byte [lst_st], 3
    jne .list
    mov dword [lst_ext], 0
    movzx edx, word [dl_fs3par]
    mov [fs3_folder_id], edx
    mov dl, [dl_fs3page]
    mov [fs_par], dl
.list:
    mov byte [lst_dirs], 1
    call fs_list
    mov byte [lst_dirs], 0
    mov byte [fs_par], 0
    mov dword [lst_ext], 0
    mov esi, lst_ids
    mov edi, dl_ids
    mov ecx, 8
    cld
    rep movsd
    mov al, [lst_n]
    mov [dl_cnt], al
    mov al, [lst_st]
    mov byte [dl_fs3], 0
    cmp al, 4
    jne .status
    cmp byte [dl_app], 0
    jne .status
    mov byte [dl_fs3], 1
    mov esi, fs3_list_hi
    mov edi, dl_ids_hi
    mov ecx, 8
    rep movsd
    xor eax, eax
.status:
    mov [dl_st], al
    popad
    ret

; Зашли в другую папку (или вышли): список заново
dlg_newdir:
    mov byte [dl_scr], 0
    mov byte [dl_sel], 0xFF
    call dlg_list
    jmp dlg_draw

dlg_cancel:
    mov byte [dlg_file_menu], 0
    mov byte [sv_after], 0
    cmp byte [dl_ctx], 0                ; сначала закрываем меню, потом переименование, потом сам диалог
    je .nc
    mov byte [dl_ctx], 0
    jmp dlg_draw
.nc:cmp byte [dl_ren], 0
    je .cl
    mov byte [dl_ren], 0
    mov byte [dl_len], 0
    mov byte [dl_car], 0
    mov byte [dl_sel], 0xFF
    jmp dlg_draw
.cl:mov byte [d2_dlg], 0
    mov byte [d2_conf], 0
    mov byte [dl_conf_file_menu], 0
    mov byte [dl_conf_min], 0
    mov byte [sel_drag], 0
    jmp redraw

dlg_draw:
    pushad
    mov eax, [qx0]
    mov [cw_x], eax
    mov eax, [qy0]
    mov [cw_y], eax
    call dlg_calc                       ; сколько строк влезает, где окно "Replace?"
    mov eax, [dlg_w]
    mov [win_w], eax
    mov eax, [dlg_h]
    mov [win_h], eax
    call cwin
    WRECTW 2, 38, 4, 2, C_BLACK
    mov esi, s_saveto
    cmp byte [d2_dlg], 1
    jne .nsv
    cmp byte [dl_app], 3
    jne .t
    mov esi, s_export
    jmp .t
.nsv:
    mov esi, s_open
    cmp byte [dl_ren], 0
    je .t
    mov esi, s_dl_ren
.t: call strlen
    shl ecx, 4
    mov eax, [dlg_w]
    sub eax, ecx
    shr eax, 1
    add eax, [cw_x]
    mov [t_x], eax
    mov eax, [cw_y]
    add eax, 2
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    call draw_big
    xor ebp, ebp
.d: xor edi, edi
    movzx eax, byte [dl_disk]
    cmp eax, ebp
    jne .n
    mov edi, 1
.n: mov eax, ebp
    imul eax, 56
    add eax, 88
    mov ebx, 42
    mov ecx, 48
    mov edx, 36
    lea esi, [ebp * 2 + s_disks]
    call wbtn
    inc ebp
    cmp ebp, 3
    jb .d
.up: cmp byte [dl_dep], 0
    je .na
    mov eax, 256
    mov ebx, 42
    mov ecx, 48
    mov edx, 36
    mov esi, s_up
    xor edi, edi
    call wbtn
.na:cmp byte [d2_dlg], 2               ; при открытии поля имени нет
    jne .dn
    cmp byte [dl_ren], 0
    je .nn
.dn:call dlg_name_draw
.nn:xor ebp, ebp                        ; три строки списка
.ro:movzx eax, byte [dl_scr]
    add eax, ebp
    movzx ebx, byte [dl_cnt]
    cmp eax, ebx
    jae .none
    shl eax, 4
    lea esi, [dl_names + eax]
    jmp .draw
.none:
    test ebp, ebp
    jnz .next
    mov esi, st_empty
    cmp byte [dl_st], 1
    jne .s2
    mov esi, st_nodisk
.s2:cmp byte [dl_st], 2
    jne .draw
    mov esi, st_nofs
.draw:
    mov eax, [cw_x]
    add eax, 12
    mov [t_x], eax
    mov eax, ebp
    shl eax, 5
    add eax, [dl_ly]
    add eax, [cw_y]
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    cmp byte [d2_dlg], 2
    jne .dr2
    movzx eax, byte [dl_scr]
    add eax, ebp
    cmp al, [dl_sel]
    jne .dr2
    push esi                            ; выбранный файл: чёрная плашка, белые буквы
    call strlen
    shl ecx, 4
    add ecx, 12
    mov eax, [cw_x]
    add eax, 6
    mov [r_x], eax
    mov eax, [t_y]
    mov [r_y], eax
    mov [r_w], ecx
    mov dword [r_h], 32
    mov dword [r_c], C_BLACK
    call fill_rect
    pop esi
    mov dword [r_c], C_WHITE
.dr2:
    push esi
    call draw_big
    pop esi
    cmp byte [esi + 15], 1              ; папка: справа косая черта
    jne .next
    cmp esi, dl_names
    jb .next
    cmp esi, dl_names + 512
    jae .next
    call strlen
    shl ecx, 4
    add ecx, [t_x]
    mov [t_x], ecx
    mov esi, s_slash
    call draw_big
.next:
    inc ebp
    cmp ebp, [dl_vis]
    jb .ro
    movzx eax, byte [dl_cnt]            ; файлов больше, чем строк: справа ползунок
    cmp eax, [dl_vis]
    jbe .nbar
    mov eax, [qx0]
    add eax, [dlg_w]
    sub eax, 22
    mov ebx, [qy0]
    add ebx, [dl_ly]
    mov ecx, [dl_vis]
    shl ecx, 5
    xor edx, edx
    mov esi, ecx
    movzx edi, byte [dl_cnt]
    shl edi, 5
    movzx ebp, byte [dl_scr]
    shl ebp, 5
    mov dword [sb_w], 16
    call sbar
.nbar:
    mov eax, 24
    mov ebx, [dlg_h]
    sub ebx, 60
    mov ecx, 152
    mov edx, 36
    mov esi, s_save
    cmp byte [d2_dlg], 1
    je .b
    mov esi, s_open
    cmp byte [dl_ren], 0
    je .b
    mov esi, s_dl_ok
.b: push eax
    mov al, 53
    push edx
    mov dl, 3
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    mov eax, 188
    mov ebx, [dlg_h]
    sub ebx, 60
    mov ecx, 132
    mov edx, 36
    mov esi, s_cancel
    push eax
    mov al, 54
    push edx
    mov dl, 3
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    mov eax, [dlg_w]                    ; квадрат в углу: за него растягивают окно
    sub eax, 18
    add eax, [cw_x]
    mov [r_x], eax
    mov eax, [dlg_h]
    sub eax, 18
    add eax, [cw_y]
    mov [r_y], eax
    mov dword [r_w], 16
    mov dword [r_h], 16
    mov dword [r_c], C_BLACK
    call fill_rect
    mov eax, [qx0]
    mov ebx, [qy0]
    mov ecx, [dlg_w]
    mov dl, [dlg_file_menu]
    call sys_file_draw
    cmp byte [d2_conf], 0
    je .e
    cmp byte [dl_conf_min], 0
    je .conf_visible
    ; Minimized child confirmation, drawn as the standard small restore button.
    push dword [cw_x]
    push dword [cw_y]
    mov dword [cw_x], 0
    mov dword [cw_y], 0
    mov eax, 646
    mov ebx, 348
    mov ecx, 144
    mov edx, 36
    mov esi, dl_conf_mini_label
    xor edi, edi
    call wbtn
    pop dword [cw_y]
    pop dword [cw_x]
    jmp .e
.conf_visible:
    ; Render the 320x208 child at its own screen Y, not dragged with Save/Open.
    push dword [cw_y]
    mov eax, [dl_conf_y]
    sub eax, 78
    mov [cw_y], eax
    mov eax, [dl_ox]                    ; вопрос "Replace?" посреди диалога
    add eax, 4
    mov [dl_t1], eax
    WRECTX [dl_t1], 82, 320, 208, C_BLACK
    WRECTX [dl_ox], 78, 320, 208, C_BLACK
    mov eax, [dl_ox]
    add eax, 2
    mov [dl_t1], eax
    WRECTX [dl_t1], 80, 316, 204, C_WHITE
    WRECTX [dl_t1], 118, 316, 2, C_BLACK
    mov eax, [cw_x]
    add eax, [dl_ox]
    mov ebx, [cw_y]
    add ebx, 82
    mov edx, 320
    mov esi, sys_title_text
    call sys_modal_center
    mov eax, [cw_x]
    add eax, [dl_ox]
    mov ebx, [cw_y]
    add ebx, 168
    mov edx, 320
    mov esi, s_replace
    call sys_modal_center
    mov al, 213
    call title_button_state
    mov eax, [cw_x]
    add eax, [dl_ox]
    add eax, 250
    mov ebx, [cw_y]
    add ebx, 86
    call mbtn
    mov al, 214
    call title_button_state
    mov eax, [cw_x]
    add eax, [dl_ox]
    add eax, 284
    mov ebx, [cw_y]
    add ebx, 86
    call xbtn
    mov eax, [dl_ox]
    add eax, 24
    mov ebx, 236
    mov ecx, 96
    mov edx, 40
    mov esi, s_yes
    push eax
    mov al, 60
    push edx
    mov dl, 6
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    mov eax, [dl_ox]
    add eax, 168
    mov ebx, 236
    mov ecx, 96
    mov edx, 40
    mov esi, s_no
    push eax
    mov al, 61
    push edx
    mov dl, 6
    call ui_button_state
    pop edx
    pop eax
    call wbtn
    mov eax, [cw_x]
    add eax, [dl_ox]
    mov ebx, [cw_y]
    add ebx, 78
    mov ecx, 320
    mov dl, [dl_conf_file_menu]
    call sys_file_draw
    pop dword [cw_y]
.e: cmp byte [dl_ctx], 0
    je .ex
    WRECTV dl_cxb, dl_cyb, 112, 80, C_BLACK
    WRECTV dl_cx, dl_cy, 112, 80, C_BLACK
    WRECTV dl_cx2, dl_cy2, 108, 76, C_WHITE
    mov dword [r_c], C_BLACK
    mov eax, [dl_cx]
    add eax, [cw_x]
    add eax, 8
    mov [t_x], eax
    mov eax, [dl_cy]
    add eax, [cw_y]
    add eax, 4
    mov [t_y], eax
    mov esi, s_dl_ren
    call draw_big
    add dword [t_y], 40
    mov esi, s_dl_del
    call draw_big
.ex:
    popad
    ret

; Размер диалога -> сколько строк списка влезает (не меньше 3) и где окно "Replace?"
dlg_calc:
    pushad
    mov ebx, 126                        ; где начинается список; при открытии поля имени нет и список выше
    mov ecx, 192
    cmp byte [d2_dlg], 2
    jne .nl
    cmp byte [dl_ren], 0
    jne .nl
    mov ebx, 90
    mov ecx, 156
.nl:mov [dl_ly], ebx
    mov eax, [dlg_h]
    sub eax, ecx
    shr eax, 5
    cmp eax, 3
    jae .a
    mov eax, 3
.a: cmp eax, 12
    jbe .b
    mov eax, 12
.b: mov [dl_vis], eax
    movzx ecx, byte [dl_cnt]            ; прокрутка не дальше, чем нужно
    sub ecx, eax
    jae .c
    xor ecx, ecx
.c: cmp [dl_scr], cl
    jbe .d
    mov [dl_scr], cl
.d: mov eax, [dlg_w]
    sub eax, 320
    shr eax, 1
    and eax, -4
    cmp byte [d2_conf], 0
    je .centered
    mov eax, [dl_conf_x]
    sub eax, [qx0]
.centered:
    mov [dl_ox], eax
    popad
    ret

; Стрелка: eax - x, edx = 0 вверх, 1 вниз
dlg_arrow:
    pushad
    mov [da_x], eax
    mov [da_d], edx
    mov ebx, 42
    mov ecx, 36
    mov edx, 36
    xor edi, edi
    mov esi, s_none
    call wbtn
    xor ecx, ecx
.k: mov eax, ecx
    shl eax, 2
    add eax, 4
    cmp dword [da_d], 0
    je .w
    mov edx, 24
    sub edx, eax
    mov eax, edx
.w: mov [r_w], eax
    shr eax, 1
    mov edx, [da_x]
    add edx, 18
    sub edx, eax
    add edx, [cw_x]
    mov [r_x], edx
    mov eax, ecx
    shl eax, 2
    add eax, 52
    add eax, [cw_y]
    mov [r_y], eax
    mov dword [r_h], 4
    mov dword [r_c], C_BLACK
    call fill_rect
    inc ecx
    cmp ecx, 5
    jb .k
    popad
    ret

; Поле имени: буквы (выделенные - белым по чёрному), палочка, .txt
dlg_name_draw:
    pushad
    mov eax, [qx0]
    mov [cw_x], eax
    mov eax, [qy0]
    mov [cw_y], eax
    WRECTW 4, 84, 8, 36, C_BLACK
    WRECTW 6, 86, 12, 32, C_WHITE
    call dlg_sel_range
    mov edx, eax                        ; dl - с какой, dh - до какой
    xor ebx, ebx
.l: cmp bl, [dl_len]
    jae .e
    mov eax, ebx
    shl eax, 4
    add eax, [cw_x]
    add eax, 12
    mov [t_x], eax
    mov [r_x], eax
    mov eax, [cw_y]
    add eax, 86
    mov [t_y], eax
    mov [r_y], eax
    mov ecx, C_BLACK
    cmp bl, dl
    jb .nsel
    cmp bl, dh
    jae .nsel
    mov dword [r_w], 16
    mov dword [r_h], 32
    mov dword [r_c], C_BLACK
    call fill_rect
    mov ecx, C_WHITE
    jmp .ch
.nsel:
    mov ecx, C_BLACK
.ch:mov al, [dl_name + ebx]
    mov [t2_tmp], al
    mov [r_c], ecx
    mov esi, t2_tmp
    push ebx
    push edx
    call draw_big
    pop edx
    pop ebx
    inc ebx
    jmp .l
.e: cmp dl, dh
    jne .t
    movzx eax, byte [dl_car]
    shl eax, 4
    add eax, [cw_x]
    add eax, 12
    mov [r_x], eax
    mov eax, [cw_y]
    add eax, 86
    mov [r_y], eax
    mov dword [r_w], 2
    mov dword [r_h], 32
    mov dword [r_c], C_BLACK
    call fill_rect
.t: cmp byte [dl_nohint], 0
    jne .done
    xor ebx, ebx                        ; если точка уже набрана, расширение не дописываем
.dt:cmp bl, [dl_len]
    jae .nd
    cmp byte [dl_name + ebx], '.'
    je .done
    inc ebx
    jmp .dt
.nd:movzx eax, byte [dl_len]
    shl eax, 4
    add eax, [cw_x]
    add eax, 18
    mov [t_x], eax
    mov eax, [cw_y]
    add eax, 86
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_txt
    cmp byte [dl_app], 0
    je .sx
    mov esi, s_pcf
    cmp byte [dl_app], 1
    je .sx
    mov esi, s_sga
.sx:call draw_big
.done:
    popad
    ret

; выделено: al - с какой буквы, ah - до какой (пусто: al = ah)
dlg_sel_range:
    xor eax, eax
    mov al, [dl_anc]
    cmp al, 0xFF
    je .n
    mov ah, [dl_car]
    cmp al, ah
    jbe .r
    xchg al, ah
.r: ret
.n: xor eax, eax
    ret

dlg_sel_del:
    pushad
    call dlg_sel_range
    cmp al, ah
    je .r
    movzx esi, ah
    movzx edi, al
    movzx ecx, byte [dl_len]
    sub ecx, esi
    inc ecx
    add esi, dl_name
    add edi, dl_name
    cld
    rep movsb
    sub byte [dl_len], ah
    add byte [dl_len], al
    mov [dl_car], al
    mov byte [dl_anc], 0xFF
.r: popad
    ret

; убрать букву под палкой
dlg_del1:
    pushad
    movzx ebx, byte [dl_car]
    movzx ecx, byte [dl_len]
    sub ecx, ebx
    jbe .r
    lea esi, [dl_name + ebx + 1]
    lea edi, [dl_name + ebx]
    cld
    rep movsb
    dec byte [dl_len]
.r: popad
    ret

; вставить букву al там, где палка
dlg_ins:
    pushad
    call dlg_sel_del
    cmp byte [dl_len], 14
    jae .r
    movzx ebx, byte [dl_len]
    movzx ecx, byte [dl_car]
.l: cmp ebx, ecx
    jl .d
    mov dl, [dl_name + ebx]
    mov [dl_name + ebx + 1], dl
    dec ebx
    jmp .l
.d: movzx ebx, byte [dl_car]
    mov [dl_name + ebx], al
    inc byte [dl_len]
    inc byte [dl_car]
    mov byte [dl_anc], 0xFF            ; вставленное не должно оставаться выделенным
.r: popad
    ret

dlg_copy:
    pushad
    call dlg_sel_range
    cmp al, ah
    je .r
    movzx esi, al
    movzx ecx, ah
    sub ecx, esi
    mov [clip_len], ecx
    xor ebx, ebx
.l: mov al, [dl_name + esi]
    mov [clip_buf + ebx], al
    inc esi
    inc ebx
    loop .l
.r: popad
    ret

; CF - символ al нельзя в имени файла
dlg_char_ok:
    cmp al, '.'
    je .y
    cmp al, '-'
    je .y
    cmp al, '_'
    je .y
    cmp al, '0'
    jb .n
    cmp al, '9'
    jbe .y
    cmp al, 'A'
    jb .n
    cmp al, 'Z'
    jbe .y
    cmp al, 'a'
    jb .n
    cmp al, 'z'
    jbe .y
    cmp al, 0xBE                        ; русские буквы
    jae .y
    jmp .n
.y: clc
    ret
.n: stc
    ret

; мышь в поле имени: какая буква ближе (eax)
dlg_mcell:
    mov eax, [m_x]
    sub eax, [qx0]
    sub eax, 4
    jge .a
    xor eax, eax
.a: shr eax, 4
    movzx ebx, byte [dl_len]
    cmp eax, ebx
    jbe .r
    mov eax, ebx
.r: ret

dlg_sel_move:
    pushad
    cmp byte [d2_nm], 0
    jne .nm
    call dlg_mcell
    cmp al, [dl_car]
    je .r
    mov [dl_car], al
    call dlg_name_draw
.r: popad
    ret
.nm:
    push dword [qx0]
    mov eax, [nm_x]
    add eax, 20
    mov [qx0], eax
    call dlg_mcell
    pop dword [qx0]
    cmp al, [dl_car]
    je .r
    mov [dl_car], al
    call nm_input
    jmp .r

; Клавиша в диалоге (al - символ)
dlg_key:
    pushad
    cmp al, 5                           ; Ctrl+E = File > Exit on top modal
    jne .not_ctrl_e
    cmp byte [d2_conf], 0
    je .cancel
    call dlg_conf_no                     ; Replace? closes; Save/Open stays
    jmp .r
.not_ctrl_e:
    cmp byte [d2_conf], 0
    je .normal_key
    cmp byte [dl_conf_min], 0
    je .normal_key
    cmp al, 27                        ; Escape cancels minimized Replace?
    jne .r                           ; no hidden confirmation via Enter
    call dlg_conf_no
    jmp .r
.normal_key:
    cmp al, 27
    je .cancel
    cmp al, 13
    je .ok
    cmp byte [dl_fs3], 0
    je .mode
    cmp al, 14
    je .next_page
    cmp al, 16
    je .prev_page
.mode:
    cmp byte [d2_dlg], 2                ; при открытии поля имени нет: остальные клавиши не нужны
    jne .kk
    cmp byte [dl_ren], 0
    je .r
    jmp .kk
.next_page:
    cmp byte [dl_fs3page], 31
    jae .r
    inc byte [dl_fs3page]
    jmp .page
.prev_page:
    cmp byte [dl_fs3page], 0
    je .r
    dec byte [dl_fs3page]
.page:
    call dlg_newdir
    jmp .r
.kk:cmp al, 8
    je .bs
    cmp al, 1
    je .all
    cmp al, 3
    je .copy
    cmp al, 0x18
    je .cut
    cmp al, 0x16
    je .paste
    call dlg_char_ok
    jc .r
    call dlg_ins
    jmp .upd
.bs:
    call dlg_sel_range
    cmp al, ah
    jne .del
    cmp byte [dl_car], 0
    je .r
    dec byte [dl_car]
.del:
    call dlg_sel_range
    cmp al, ah
    je .d1
    call dlg_sel_del
    jmp .upd
.d1:call dlg_del1
    jmp .upd
.all:
    mov byte [dl_anc], 0
    mov al, [dl_len]
    mov [dl_car], al
    jmp .upd
.cut:
    call dlg_copy
    call dlg_sel_del
    jmp .upd
.copy:
    call dlg_copy
    jmp .r
.paste:
    xor ebx, ebx
.pl:cmp ebx, [clip_len]
    jae .upd
    mov al, [clip_buf + ebx]
    push ebx
    call dlg_char_ok
    jc .pn
    call dlg_ins
.pn:pop ebx
    inc ebx
    jmp .pl
.upd:
    cmp byte [d2_nm], 0                 ; то же поле ввода работает и в окне имени FloFile
    jne .un
    call dlg_name_draw
    jmp .r
.un:call nm_input
    jmp .r
.ok:call dlg_ok
    jmp .r
.cancel:
    call dlg_cancel
.r: popad
    ret

; Кнопка Save / Open
dlg_ok:
    cmp byte [dl_ren], 0
    jne dlg_rename_do
    pushad
    cmp byte [dl_len], 0
    je .r
    mov esi, dl_name
    call dl_mkname
    call dlg_mount_file
    jc .error
    cmp byte [d2_dlg], 2
    je .open
    mov byte [dl_replace], 0
    mov esi, fn_buf
    cmp byte [lst_st], 3
    jne .legacy
    call fs3o_find
    jnc .replace
    cmp eax, -1
    jne .error
    jmp .go
.legacy:
    call dir_find
    jc .go
.replace:
    mov byte [dl_replace], 1
    mov byte [d2_conf], 1               ; спросить, заменить ли
    mov eax, [dlg_w]
    sub eax, 320
    shr eax, 1
    and eax, -4
    add eax, [qx0]
    mov [dl_conf_x], eax
    mov eax, [qy0]
    add eax, 78
    mov [dl_conf_y], eax
    mov byte [dlg_file_menu], 0
    mov byte [dl_conf_file_menu], 0
    mov byte [dl_conf_min], 0
    call dlg_draw
    jmp .r
.go:call dlg_commit
    jmp .r
.open:
    mov esi, fn_buf
    mov al, [dl_disk]
    mov byte [d2_dlg], 0
    cmp byte [dl_app], 0
    jne .po
    call text_open_named
    jmp .r
.po:cmp byte [dl_app], 1
    jne .io
    call paint_open_named
    jmp .r
.io:call itge_open_named
    jmp .r
.error:
    mov al, 0x36
    call core_err_raise
.r: popad
    ret

dlg_mount_file:
    mov al, [dl_disk]
    call fs_setdisk
    jnc .ready
    cmp byte [dl_app], 0
    jne .bad
    cmp byte [lst_st], 3
    jne .bad
    movzx eax, word [dl_fs3par]
    mov [fs3_folder_id], eax
.ready:
    clc
    ret
.bad:
    stc
    ret

dl_mkname:
    mov al, [dl_par]                    ; диалог работает с папкой dl_par
    mov [fs_par], al
    cmp byte [dl_app], 0
    jne .pi
    jmp mkname
.pi:cmp byte [dl_app], 1
    je mkname_p
    jmp mkname_s

dlg_conf_yes:
    pushad
    mov byte [d2_conf], 0
    mov byte [dl_conf_file_menu], 0
    mov byte [dl_conf_min], 0
    mov esi, dl_name
    call dl_mkname
    call dlg_mount_file
    jc .error
    call dlg_commit
    jmp .r
.error:
    mov al, 0x36
    call core_err_raise
.r: popad
    ret

dlg_conf_no:
    mov byte [d2_conf], 0
    mov byte [dl_conf_file_menu], 0
    mov byte [dl_conf_min], 0
    jmp redraw                   ; erase mini restore button outside dialog

; Записать текст в файл fn_buf на выбранном диске, запомнить имя, закрыть диалог
dlg_commit:
    pushad
    call wait_start
    cmp byte [dl_app], 0
    je .tx
    cmp byte [dl_app], 1
    jne .it
    call pa_pack
    jmp .wr
.it:call itge_pack                     ; Export из itge теперь тоже .sga
    jmp .wr
.tx:
    mov esi, fn_buf
    mov dl, [dl_replace]
    call text_write_to
    jmp .written
.wr:mov esi, fn_buf
    call file_write
.written:
    mov byte [fs_par], 0
    jc .error
    cmp byte [dl_app], 3                ; экспорт: имя документа не меняется
    jne .ne
    mov byte [d2_dlg], 0
    mov byte [d2_conf], 0
    call wait_end
    call redraw
    jmp .r
.ne:    mov edi, t2_nm
    mov ebx, t2_dsk
    cmp byte [dl_app], 0
    je .sv
    mov edi, pa_nm
    mov ebx, pa_dsk
    cmp byte [dl_app], 1
    je .sv
    mov edi, it_nm
    mov ebx, it_dsk
.sv:mov al, [dl_disk]
    mov [ebx], al
    mov al, [dl_par]
    mov [ebx + 1], al                   ; t2_par / pa_par / it_par
    cmp byte [dl_app], 0
    jne .copy_name
    movzx eax, word [dl_fs3par]
    mov [t2_fs3parent], eax
.copy_name:
    mov esi, fn_buf                     ; имя целиком, с расширением
.c: lodsb
    stosb
    test al, al
    jnz .c
    mov byte [d2_dlg], 0
    mov byte [d2_conf], 0
    cmp byte [dl_app], 0                ; FloText: save snapshot after successful Save to
    jne .nmt
    call text_snapshot
.nmt:cmp byte [dl_app], 1
    jne .nm1
    mov byte [pa_dirty], 0
.nm1:cmp byte [dl_app], 2
    jne .nm2
    mov byte [it_mod], 0
.nm2:
    call files_list
    call wait_end
    call redraw
    movzx eax, byte [sv_after]          ; сохраняли перед закрытием программы - закрываем
    test eax, eax
    jz .r
    cmp al, 3
    jne .n3
    mov byte [sv_after], 0              ; сохраняли рисунок FloPaint, чтобы открыть в нём картинку из itge
    call it_ep_go
    jmp .r
.n3:cmp al, 4                         ; FloText after Save to
    jne .n4
    cmp byte [dl_app], 0
    jne .r
    mov byte [sv_after], 0
    call text_close
    jmp .r
.n4:cmp al, [dl_app]
    jne .r
    mov byte [sv_after], 0
    cmp al, 1
    jne .ci
    call paint_close
    jmp .r
.ci:call itge_close
    jmp .r
.error:
    call wait_end
    mov al, 0x36
    call core_err_raise
    popad
    ret
.r: call wait_end
    popad
    ret

; Что под мышью в диалоге: 41 заголовок, 42..44 диски, 45, 46 стрелки, 47 имя, 180.. файлы, 53 Save/Open, 54 Cancel, 170 угол,
; 60 Yes, 61 No
dlg_hit:
    call dlg_calc
    mov esi, [m_x]
    sub esi, [qx0]
    mov edi, [m_y]
    sub edi, [qy0]
    cmp byte [d2_conf], 0
    je .nc
    cmp byte [dl_conf_min], 0
    je .conf_expanded
    xor al, al
    mov eax, [m_x]
    cmp eax, 646
    jb .conf_hit_none
    cmp eax, 790
    ja .conf_hit_none
    mov eax, [m_y]
    cmp eax, 348
    jb .conf_hit_none
    cmp eax, 384
    ja .conf_hit_none
    mov al, 215                       ; restore Replace?
    ret
.conf_hit_none:
    xor al, al
    ret
.conf_expanded:
    ; Independent confirmation geometry: position is no longer parent-relative.
    mov esi, [m_x]
    sub esi, [dl_conf_x]
    js .conf_hit_none
    cmp esi, 320
    ja .conf_hit_none
    mov edi, [m_y]
    sub edi, [dl_conf_y]
    js .conf_hit_none
    cmp edi, 208
    ja .conf_hit_none
    mov dl, [dl_conf_file_menu]
    call sys_file_hit
    test al, al
    jnz .conf_file_hit
    HITR 244, 274, 8, 40, 213       ; minus
    HITR 278, 308, 8, 40, 214       ; close/cancel
    HITR 24, 120, 158, 198, 60      ; Yes
    HITR 168, 264, 158, 198, 61     ; No
    HITR 8, 304, 4, 40, 234         ; child title drag (not parent)
    xor al, al
    ret
.conf_file_hit:
    ret
.nc:cmp byte [dl_ctx], 0               ; открыто меню Rename / Delete
    je .nctx
    mov ecx, [dl_cx]
    lea eax, [ecx + 111]
    mov edx, [dl_cy]
    lea ebx, [edx + 39]
    HITR ecx, eax, edx, ebx, 55
    add edx, 40
    lea ebx, [edx + 39]
    HITR ecx, eax, edx, ebx, 56
    mov al, 57                          ; мимо меню: просто закрыть его
    ret
.nctx:
    mov dl, [dlg_file_menu]
    call sys_file_hit
    test al, al
    jnz .file_hit
    mov ebx, [dlg_w]
    mov edx, [dlg_h]
    lea ecx, [ebx - 18]                 ; квадрат в правом нижнем углу
    lea eax, [edx - 18]
    HITR ecx, ebx, eax, edx, 170
    lea ecx, [ebx - 32]
    HITR 4, ecx, 2, 36, 41
    HITR 88, 136, 42, 78, 42
    HITR 144, 192, 42, 78, 43
    HITR 200, 248, 42, 78, 44
    cmp byte [dl_dep], 0
    je .noup
    HITR 256, 304, 42, 78, 62
.noup:
    movzx eax, byte [dl_cnt]            ; ползунок справа от списка
    cmp eax, [dl_vis]
    jbe .nb58
    cmp byte [dl_ren], 0
    jne .nb58
    lea ecx, [ebx - 22]
    cmp esi, ecx
    jb .nb58
    lea ecx, [ebx - 6]
    cmp esi, ecx
    ja .nb58
    mov ecx, edi
    sub ecx, [dl_ly]
    jl .nb58
    mov eax, [dl_vis]
    shl eax, 5
    cmp ecx, eax
    jae .nb58
    mov al, 58
    ret
.nb58:
    cmp byte [d2_dlg], 2                ; при открытии поля имени нет
    jne .f47
    cmp byte [dl_ren], 0
    je .s47
.f47:
    lea ecx, [ebx - 4]
    HITR 4, ecx, 84, 120, 47
.s47:
    lea ecx, [edx - 60]
    lea eax, [edx - 24]
    HITR 24, 176, ecx, eax, 53
    HITR 188, 320, ecx, eax, 54
    cmp byte [dl_ren], 0                ; пока переименовываем - список не трогаем
    jne .z
    mov eax, edi
    sub eax, [dl_ly]
    jl .z
    mov ecx, [dl_vis]
    shl ecx, 5
    cmp eax, ecx
    jae .z
    cmp esi, 4
    jb .z
    lea ecx, [ebx - 26]
    cmp esi, ecx
    ja .z
    shr eax, 5
    add al, 180
    ret
.z: xor al, al
    ret
.file_hit:
    ret

; Нажали мышью в диалоге: al - что
dlg_press:
    cmp al, 193
    je .sys_file_toggle
    cmp al, 194
    je .sys_file_exit
    cmp al, 213
    jne .not_min
    cmp byte [d2_conf], 0
    je .r
    mov byte [dl_conf_min], 1
    jmp redraw
.sys_file_toggle:
    cmp byte [d2_conf], 0
    je .top_file_toggle
    xor byte [dl_conf_file_menu], 1
    jmp redraw
.top_file_toggle:
    xor byte [dlg_file_menu], 1
    jmp redraw
.sys_file_exit:
    cmp byte [d2_conf], 0
    je .top_file_exit
    jmp dlg_conf_no
.top_file_exit:
    jmp dlg_cancel
.not_min:
    cmp al, 214
    je dlg_conf_no
    cmp al, 215
    jne .not_restore
    mov byte [dl_conf_min], 0
    jmp redraw
.not_restore:
    cmp al, 58
    jne .n58
    mov byte [sb_drag], 17
    mov byte [sb_ctx], 5
    call sb_grab
    cmp byte [sb_drag], 0
    je .r58
    call sb_set
.r58:ret
.n58:
    cmp al, 55
    je dlg_ctx_ren
    cmp al, 56
    je dlg_ctx_del
    cmp al, 57
    jne .n57
    mov byte [dl_ctx], 0
    jmp dlg_draw
.n57:
    cmp al, 62
    jne .nup
    movzx ebx, byte [dl_dep]
    test ebx, ebx
    jz .r
    dec ebx
    mov [dl_dep], bl
    mov al, [dl_stk + ebx]
    mov [dl_par], al
    mov ax, [dl_fs3stk + ebx*2]
    mov [dl_fs3par], ax
    mov byte [dl_fs3page], 0
    jmp dlg_newdir
.nup:
    cmp al, 60
    jne .a
    jmp dlg_conf_yes
.a: cmp al, 61
    jne .b
    jmp dlg_conf_no
.b: cmp al, 170
    jne .b2
    mov bl, 6                           ; квадрат в углу: растягиваем диалог
    mov byte [d_ctx], 2
    jmp drag_start
.b2:cmp al, 234                        ; Replace? child title
    jne .parent_title
    mov bl, 1
    mov byte [d_ctx], 16
    jmp drag_start
.parent_title:
    cmp al, 41
    jne .c
    mov bl, 1
    mov byte [d_ctx], 2
    jmp drag_start
.c: cmp al, 42
    jb .d
    cmp al, 44
    ja .d
    sub al, 42
    mov [dl_disk], al
    mov byte [dl_par], 0
    mov word [dl_fs3par], 0
    mov byte [dl_fs3page], 0
    mov byte [dl_dep], 0
    mov byte [dl_scr], 0
    mov byte [dl_sel], 0xFF
    mov byte [dl_ren], 0
    mov byte [dl_len], 0
    mov byte [dl_car], 0
    call dlg_list
    jmp dlg_draw
.d: cmp al, 45
    jne .e
    cmp byte [dl_scr], 0
    je .r
    dec byte [dl_scr]
    jmp dlg_draw
.e: cmp al, 46
    jne .f
    mov al, [dl_scr]
    add al, [dl_vis]
    cmp al, [dl_cnt]
    jae .r
    inc byte [dl_scr]
    jmp dlg_draw
.f: cmp al, 47
    jne .g
    call dlg_mcell
    mov [dl_car], al
    mov [dl_anc], al
    mov byte [sel_drag], 2
    jmp dlg_name_draw
.g: cmp al, 53
    jne .h
    jmp dlg_ok
.h: cmp al, 54
    jne .i
    jmp dlg_cancel
.i: cmp al, 180
    jb .r
    cmp al, 195
    ja .r
    sub al, 180
    add al, [dl_scr]
    cmp al, [dl_cnt]
    jae .r
    movzx esi, al
    shl esi, 4
    cmp byte [dl_names + esi + 15], 1
    jne .nfo
    movzx ebx, byte [dl_dep]            ; папка: войти
    cmp ebx, 4
    jae .r
    mov dl, [dl_par]
    mov [dl_stk + ebx], dl
    mov dx, [dl_fs3par]
    mov [dl_fs3stk + ebx*2], dx
    inc byte [dl_dep]
    shr esi, 4
    mov al, [dl_ids + esi]
    cmp byte [dl_fs3], 1
    je .fs3_dir
    mov [dl_par], al
    jmp dlg_newdir
.fs3_dir:
    mov ah, [dl_ids_hi + esi]
    mov [dl_fs3par], ax
    mov byte [dl_fs3page], 0
    jmp dlg_newdir
.nfo:
    mov byte [dl_dbl], 0
    cmp byte [d2_dlg], 2                ; при открытии: клик выбирает, быстрый второй клик открывает
    jne .nd2
    cmp al, [dl_sel]
    jne .nd1
    mov edx, [ticks]
    sub edx, [dl_ct]
    cmp edx, 10
    ja .nd1
    mov byte [dl_dbl], 1
.nd1:
    mov [dl_sel], al
    mov edx, [ticks]
    mov [dl_ct], edx
.nd2:
    movzx esi, al
    shl esi, 4
    add esi, dl_names
    mov edi, dl_name
    xor ecx, ecx
.cp:mov al, [esi]
    test al, al
    jz .cpe
    cmp byte [dl_fs3], 0
    jne .exact
    cmp al, '.'
    jne .nsc
    cmp byte [dl_app], 0                ; FloText: файл .sec остаётся с расширением (пасхалка)
    jne .cpe
    cmp dword [esi], 0x6365732E
    jne .cpe
    mov dword [edi], 0x6365732E
    add edi, 4
    add ecx, 4
    jmp .cpe
.exact:
    cmp ecx, 14
    jb .put_name
    jmp .cpe
.nsc:
    cmp ecx, 10
    jae .cpe
.put_name:
    mov [edi], al
    inc edi
    inc esi
    inc ecx
    jmp .cp
.cpe:
    mov byte [edi], 0
    mov [dl_len], cl
    mov [dl_car], cl
    mov byte [dl_anc], 0xFF
    cmp byte [dl_dbl], 0
    je dlg_draw
    jmp dlg_ok
.r: ret


; Правая кнопка в окне Open: выбрать файл под мышью и показать меню Rename / Delete
dlg_rclick:
    pushad
    cmp byte [dl_fs3], 0
    jne .r
    cmp byte [d2_conf], 0
    jne .r
    cmp byte [dl_ren], 0
    jne .r
    call dlg_hit
    cmp al, 180
    jb .r
    cmp al, 195
    ja .r
    movzx esi, al                       ; на папке меню Rename / Delete не нужно
    sub esi, 180
    movzx ebx, byte [dl_scr]
    add esi, ebx
    cmp esi, 32
    jae .r
    shl esi, 4
    cmp byte [dl_names + esi + 15], 1
    je .r
    mov byte [dl_sel], 0xFF             ; правый клик не должен считаться двойным
    mov byte [dl_ctx], 0
    call dlg_press                      ; выбирает файл
    cmp byte [dl_sel], 0xFF
    je .r
    mov eax, [m_x]
    sub eax, [qx0]
    mov ebx, [dlg_w]
    sub ebx, 116
    cmp eax, ebx
    jbe .x
    mov eax, ebx
.x: mov [dl_cx], eax
    add eax, 4
    mov [dl_cxb], eax
    sub eax, 2
    mov [dl_cx2], eax
    mov eax, [m_y]
    sub eax, [qy0]
    mov ebx, [dlg_h]
    sub ebx, 84
    cmp eax, ebx
    jbe .y
    mov eax, ebx
.y: mov [dl_cy], eax
    add eax, 4
    mov [dl_cyb], eax
    sub eax, 2
    mov [dl_cy2], eax
    mov byte [dl_ctx], 1
    call dlg_draw
.r: popad
    ret

; Меню: Delete
dlg_ctx_del:
    pushad
    mov byte [dl_ctx], 0
    movzx esi, byte [dl_sel]
    cmp esi, 0xFF
    je .r
    shl esi, 4
    add esi, dl_names
    mov al, [dl_disk]
    call fs_setdisk
    jc .r
    mov al, [dl_par]
    mov [fs_par], al
    call file_delete
    mov byte [fs_par], 0
    call dlg_list
    mov byte [dl_sel], 0xFF
    mov byte [dl_len], 0
    mov byte [dl_car], 0
    call dlg_draw
.r: popad
    ret

; Меню: Rename - появляется поле имени с названием файла
dlg_ctx_ren:
    pushad
    mov byte [dl_ctx], 0
    movzx esi, byte [dl_sel]
    cmp esi, 0xFF
    je .r
    shl esi, 4
    add esi, dl_names
    mov edi, dl_old
    mov ecx, 16
    cld
    rep movsb
    mov byte [dl_ren], 1
    call dlg_draw
.r: popad
    ret

; Кнопка OK при переименовании
dlg_rename_do:
    pushad
    cmp byte [dl_len], 0
    je .r
    mov esi, dl_name
    call dl_mkname                      ; новое имя с расширением -> fn_buf
    mov al, [dl_disk]
    call fs_setdisk
    jc .r
    mov esi, dl_old
    mov edx, fn_buf
    call dir_rename
    jc .bad
    mov byte [dl_ren], 0
    call dlg_list
    mov byte [dl_sel], 0xFF
    mov byte [dl_len], 0
    mov byte [dl_car], 0
    call dlg_draw
    jmp .r
.bad:
    mov byte [d2_err], 0x34                ; такое имя уже есть
    call redraw
.r: popad
    ret

; данные диалога
dl_sel      db 0xFF                     ; выбранная строка списка при открытии
dl_dbl      db 0
dl_par      db 0
dl_dep      db 0
dl_stk      times 4 db 0
dl_ids      times 32 db 0
dl_fs3      db 0
dl_fs3page  db 0
dl_fs3par   dw 0
dl_fs3stk   times 4 dw 0
dl_ids_hi   times 32 db 0
dl_replace  db 0
s_up        db "Up", 0
s_slash     db "/", 0
dl_ren      db 0                        ; 1 - идёт переименование
dl_ctx      db 0                        ; 1 - открыто меню Rename / Delete
dl_ct       dd 0                        ; время последнего клика по строке
dl_ly       dd 126                      ; где начинается список
dl_cx       dd 0
dl_cy       dd 0
dl_cxb      dd 0
dl_cyb      dd 0
dl_cx2      dd 0
dl_cy2      dd 0
dl_old      times 16 db 0
dl_sbo      dd 0                        ; сдвиг ползунка списка
s_dl_ren    db "Rename", 0
s_dl_del    db "Delete", 0
s_dl_ok     db "OK", 0
d2_dlg      db 0
dlg_file_menu db 0
d2_conf     db 0
dl_conf_min db 0
dl_conf_file_menu db 0
dl_disk     db 0
dl_scr      db 0
dl_cnt      db 0
dl_st       db 0
da_x        dd 0
da_d        dd 0
dl_vis      dd 3                        ; сколько строк списка видно (зависит от высоты диалога)
dl_ox       dd 64                       ; child x relative to Save/Open for drawing
dl_conf_x  dd 200                      ; independent Replace? screen position
dl_conf_y  dd 200
dl_conf_w  dd 320                      ; drag_start uses 4 consecutive dwords
dl_conf_h  dd 208
dl_t1       dd 0
dlg_h       dd 292
dl_names    equ KBSS + 0x400
s_saveto    db "Save to", 0
s_export    db "Export", 0
s_open      db "Open", 0
s_save      db "Save", 0
s_cancel    db "Cancel", 0
s_replace   db "Replace?", 0
s_yes       db "Yes", 0
s_no        db "No", 0
s_none      db 0
s_disks     db "C", 0, "O", 0, "I", 0


; Standard titlebar buttons in the nested Replace? confirmation.
dl_conf_minus db "-", 0
dl_conf_close db "X", 0
dl_conf_mini_label db "Replace", 0
