; Floppy 32: ядро в защищённом режиме (32 бита). Рабочий стол из Floppy 1.1, мышь и клавиатура без BIOS
org 0x10000
bits 32

C_BLACK equ 0
C_BLUE  equ 1
C_DBLUE equ 2
C_GRAY  equ 7
C_GRAY2 equ 8
C_WHITE equ 15
VGA     equ 0xA0000

%include "src/include/macros.inc"
%include "src/include/kconst.inc"
%assign MI 0
%macro MAPI 1
%1 equ MJ + 5 * MI
%assign MI MI + 1
%endmacro
%include "src/include/mapilist.inc"
%include "src/include/modvars.inc"
%assign TI 0
%macro TAPI 1
%1 equ TJ + 5 * TI
%assign TI TI + 1
%endmacro
%include "src/include/tapilist.inc"
%include "src/include/textvars.inc"
%assign PI 0
%macro PAPI 1
%1 equ PJ + 5 * PI
%assign PI PI + 1
%endmacro
%include "src/include/papilist.inc"
%include "src/include/paintvars.inc"
%assign FI 0
%macro FAPI 1
%1 equ FJ + 5 * FI
%assign FI FI + 1
%endmacro
%include "src/include/fapilist.inc"
%include "src/include/filevars.inc"
%assign BI 0
%macro BAPI 1
%1 equ BJ + 5 * BI
%assign BI BI + 1
%endmacro
%include "src/include/bapilist.inc"
%include "src/include/boilvars.inc"
%assign II 0
%macro IAPI 1
%1 equ IJ + 5 * II
%assign II II + 1
%endmacro
%include "src/include/iapilist.inc"
%include "src/include/itgevars.inc"
%macro KAPI 1
    jmp near %1
%endmacro

; Начало ядра: сюда прыгает загрузчик; дальше таблица переходов и переменные для модулей .sys
kernel_entry:
    jmp near start
times 0x10 - ($ - $$) db 0
%include "src/include/kapilist.inc"
times 0x200 - ($ - $$) db 0
%macro KVD 2
%1: dd %2
%endmacro
%macro KVB 2
%1: db %2
%endmacro
%macro KVS 2
%1: times %2 db 0
%endmacro
%include "src/include/kvarlist.inc"
times 0x600 - ($ - $$) db 0

start:
    cld
    ; После BIOS-чтения itge + FloCalendar переносим календарь из временного
    ; диапазона файловых буферов 0x50000..0x51FFF в свободную RAM 0x54000.
    ; До disk_init / fs_pc_scan эта область ещё не используется.
    mov esi, 0x50000
    mov edi, 0x54000
    mov ecx, 16 * 512 / 4
    rep movsd
    mov edi, KBSS                       ; переменные-буферы лежат за ядром, их обнуляем
    mov ecx, KBSS_N / 4
    xor eax, eax
    rep stosd
    call font_init
    call set_palette
    call draw_desktop
    mov dword [wait_min], WAIT_BOOT
    call disk_init
    call boot_main
    call st_load                        ; сохранённые настройки из Settings
    call fs_pc_scan                     ; пустые диски форматируются сами, чтобы сразу можно было сохранять
    call calendar_reload_ata            ; проверить реальное содержимое FloCalendar в pm.img через ATA
    call sys_install                    ; на диске C - настоящая папка flopsys с программами
    call idt_init
    call mouse_init
    sti
    call wait_end
    call ist_check                      ; first check installation: no boot splash before installer
    cmp byte [d2_ist], 0
    jne .installation_pending
    call bs_finish                      ; 4-second splash only for already installed OS
    call redraw
.installation_pending:
    call wl_check                       ; окно welcome
    cmp byte [d2_wl], 0
    je .nwl0
    call redraw
.nwl0:
    call cursor_show
    mov byte [fs3_alert_ready], 1
.main:
    cmp byte [fs3_alert_pending], 0
    je .no_fs3_alert
    mov byte [fs3_alert_pending], 0
    mov byte [fs3_alert_active], 1
    call cursor_hide
    call fs3_alert_draw
.no_fs3_alert:
    hlt
    call keys
    cmp byte [fs3_alert_active], 0
    jne .main                        ; ignore mouse/background drawing in alert
    call clock_tick
    cmp byte [m_dirty], 0
    je .main
    mov byte [m_dirty], 0
    call paint_sync
    call cursor_hide
    call mouse_event
    call cursor_show
    jmp .main

; Перед перерисовкой курсора и фигур ждём обратный ход луча монитора: курсор и фигура не рвутся посреди кадра, мерцает меньше
paint_sync:
    push eax
    push ecx
    push edx
    mov dx, 0x3DA
    mov ecx, 60000
.a: in al, dx
    test al, 8
    jz .b
    dec ecx
    jnz .a
.b: mov ecx, 60000
.c: in al, dx
    test al, 8
    jnz .d
    dec ecx
    jnz .c
.d: pop edx
    pop ecx
    pop eax
.r: ret

; Клавиши: калькулятору (если открыт), остальные пока выбрасываем
keys:
.l: mov al, [kq_r]
    cmp al, [kq_w]
    je .e
    movzx ebx, al
    mov dl, [kq + ebx]
    inc al
    mov [kq_r], al
    mov al, dl
    cmp byte [fs3_alert_active], 0
    je .fs3_alert_not_active
    cmp al, 13                        ; Enter only (keyboard layout independent)
    jne .l
    mov byte [fs3_alert_active], 0
    call redraw
    call cursor_show
    jmp .l
.fs3_alert_not_active:
    cmp byte [d2_egg], 0
    je .ne2
    call cursor_hide
    call egg_close
    call cursor_show
    jmp .l
.ne2:
    cmp byte [d2_ist], 0
    je .ni
    call cursor_hide
    call ist_key
    call cursor_show
    jmp .l
.ni:cmp byte [d2_wl], 0
    je .nwk
    call cursor_hide
    call wl_key
    call cursor_show
    jmp .l
.nwk:
    cmp byte [pw_open], 0
    je .not_power_key
    cmp al, 5                      ; Ctrl+E = System > File > Exit
    je .power_cancel_key
    cmp al, 27                     ; Escape cancels power dialog
    je .power_cancel_key
    cmp al, 13                     ; Enter confirms power off
    jne .l
    cmp byte [pw_min], 0           ; hidden dialog must not activate on Enter
    jne .l
    call cursor_hide
    call power_off
.power_cancel_key:
    call cursor_hide
    mov byte [pw_open], 0
    mov byte [pw_min], 0
    call redraw
    call cursor_show
    jmp .l
.not_power_key:
    cmp al, 5                           ; Ctrl+E закрывает диспетчер задач, если он открыт
    jne .nte
    cmp byte [d2_tm], 0
    je .nte
    push eax
    call fz_active
    cmp al, 9
    pop eax
    jne .nte
    call cursor_hide
    call tm_exit
    call cursor_show
    jmp .l
.nte:
    cmp al, 5                           ; Ctrl+E закрывает календарь, если он открыт
    jne .ncte
    cmp byte [d2_cal], 0
    je .ncte
    push eax
    call fz_active
    cmp al, 8
    pop eax
    jne .ncte
    call cursor_hide
    call cal_exit
    call cursor_show
    jmp .l
.ncte:
    cmp al, 0x92
    jne .nt
    call cursor_hide
    call tm_toggle
    call cursor_show
    jmp .l
.nt:call hp_key                          ; открыта справка: любая клавиша её закрывает
    jnc .nhk
    mov byte [hp_on], 0
    jmp .l
.nhk:cmp byte [sv_who], 0
    jne .sv
    cmp byte [d2_err], 0
    jne .er
    cmp byte [d2_dlg], 0                ; modal input must override floating windows
    jne .dl
    ; Recompute keyboard focus from the same Z-order used by redraw/hit.
    push eax
    call fz_active
    mov [fz_key_owner], al
    pop eax
    cmp byte [fz_key_owner], 4
    je .tr
    cmp byte [fz_key_owner], 7
    je .cc
    cmp byte [d2_dk], 0
    je .skip_dk_key
    push eax
    call fz_active
    cmp al, 5
    pop eax
    je .dk
.skip_dk_key:
    cmp byte [d2_dlg], 0
    jne .dl
    cmp byte [d2_boil], 0
    jne .bo
    cmp byte [d2_itge], 0
    jne .it
    cmp byte [d2_paint], 0
    jne .pa
    cmp byte [calc_foc], 0              ; последний клик был по калькулятору - клавиши ему
    je .nf3
    cmp byte [d2_calc], 0
    jne .cc
.nf3:
    cmp byte [d2_text], 0
    jne .tx
    cmp byte [d2_files], 0
    jne .fl
    cmp byte [d2_calc], 0
    je .ck
    cmp byte [fz_key_owner], 7
    jne .ck
    call cursor_hide
    call calc_key
    call cursor_show
    jmp .l
.ck:cmp al, 5                           ; Ctrl+E закрывает верхнее из окон About, Settings, Clock
    jne .l
    call cursor_hide
    call fz_exit_top
    call cursor_show
    jmp .l
.cc:call cursor_hide
    call calc_key
    call cursor_show
    jmp .l
.sv:call cursor_hide
    cmp al, 5                      ; Ctrl+E = Save changes? File > Exit (cancel)
    je .sv_exit
    cmp dl, 27
    jne .sv1
    call sv_cancel
    jmp .sv2
.sv_exit:
    call sv_cancel
    jmp .sv2
.sv1:cmp dl, 13
    jne .sv2
    cmp byte [sv_min], 0             ; don't confirm a minimized question
    jne .sv2
    call sv_yes
.sv2:call cursor_show
    jmp .l
.er:call cursor_hide
    mov byte [d2_err], 0
    call redraw
    call cursor_show
    jmp .l
.tr:call cursor_hide
    call tr_key
    call cursor_show
    jmp .l
.dk:call cursor_hide
    call dk_key
    call cursor_show
    jmp .l
.dl:call cursor_hide
    call dlg_key
    call cursor_show
    jmp .l
.pa:call cursor_hide
    call paint_key
    call cursor_show
    jmp .l
.bo:call cursor_hide
    call boil_key
    call cursor_show
    jmp .l
.it:call cursor_hide
    push eax
    mov al, [shift]
    mov [it_shift], al
    pop eax
    call itge_key
    call cursor_show
    jmp .l
.tx:call cursor_hide
    call text_key
    call cursor_show
    jmp .l
.fl:call cursor_hide
    call files_key
    call cursor_show
    jmp .l
.e: ret

; Цвета: 1 - синий, 2 - тёмно-синий (как в Floppy 1.1), 8 - серая тень курсора
set_palette:
    mov dx, 0x3C8
    mov al, 1
    out dx, al
    inc dx
    mov al, 10
    out dx, al
    out dx, al
    mov al, 63
    out dx, al
    mov al, 2
    dec dx
    out dx, al
    inc dx
    mov al, 2
    out dx, al
    out dx, al
    mov al, 37
    out dx, al
    jmp pal_theme

draw_desktop:
    pushad
    RECT 0, 0, 800, 600, 3
    xor ebx, ebx                        ; фон: тонкие полоски через пиксель
.s: mov eax, ebx
    shl eax, 2
    mov [r_x], eax
    mov dword [r_y], 0
    mov dword [r_w], 2
    mov dword [r_h], 600
    mov dword [r_c], 4
    call fill_rect
    inc ebx
    cmp ebx, 200
    jb .s
    CRECT 13, 13, 388, 290, C_BLACK, 3, 2, 2, 4     ; окно: жёсткая тень
    CRECT 8, 8, 383, 285, C_BLACK, 3, 2, 2, 4
    CRECT 9, 9, 382, 284, C_WHITE, 2, 1, 1, 3
    call draw_button
    call draw_about_btn
    call draw_settings_btn
    call power_button_draw
    call draw_clock
    cmp byte [si_err], 0                ; установка системных файлов не удалась: показать номер ошибки
    je .nerr
    mov al, [si_err]
    add al, '0'
    mov [si_msg + 9], al
    mov dword [t_x], 40
    mov dword [t_y], 250
    mov dword [r_c], C_BLACK
    mov esi, si_msg
    call draw_big
    cmp byte [si_err], 1
    jne .nerr
    mov edi, si_dbg                     ; p - диск есть, st - состояние, f - форматирование не удалось, n - секторов
    mov al, 'p'
    stosb
    mov al, '='
    stosb
    mov al, [si_d0]
    add al, '0'
    stosb
    mov al, ' '
    stosb
    mov al, 's'
    stosb
    mov al, '='
    stosb
    mov al, [si_d2]
    add al, '0'
    stosb
    mov al, ' '
    stosb
    mov al, 'f'
    stosb
    mov al, '='
    stosb
    mov al, [si_d3]
    add al, '0'
    stosb
    mov al, ' '
    stosb
    mov al, 'n'
    stosb
    mov al, '='
    stosb
    mov eax, [si_d1]
    call u32str
    mov byte [edi], 0
    mov dword [t_x], 40
    mov dword [t_y], 290
    mov esi, si_dbg
    call draw_big
    mov edi, si_dbg                     ; ещё раз: m - открылся ли диск (0 да) и состояние, r - чтение сектора 512, потом что в нём
    mov al, 'm'
    stosb
    mov al, '='
    stosb
    mov al, [si_d4]
    add al, '0'
    stosb
    mov al, [si_d5]
    add al, '0'
    stosb
    mov al, ' '
    stosb
    mov al, 'r'
    stosb
    mov al, '='
    stosb
    mov al, [si_d6]
    add al, '0'
    stosb
    mov al, ' '
    stosb
    mov eax, [si_d7]
    call u32str
    mov byte [edi], 0
    mov dword [t_x], 40
    mov dword [t_y], 330
    mov esi, si_dbg
    call draw_big
.nerr:
    popad
    ret

; Кнопка Floppy: обычная или вдавленная (pressed = 1)
draw_button:
    pushad
    RECT 40, 36, 180, 56, C_WHITE
    cmp byte [pressed], 1
    je .p
    CRECT 24, 22, 106, 44, C_BLACK, 2, 1, 1, 2
    CRECT 22, 20, 104, 42, C_BLACK, 2, 1, 1, 2
    CRECT 23, 21, 103, 41, C_WHITE, 1, 0, 0, 1
    mov dword [sp_x], 28
    mov dword [sp_y], 25
    mov byte [sp_inv], 0
    call draw_sprite
    mov dword [t_x], 96
    mov dword [t_y], 46
    mov dword [r_c], C_BLACK
    mov esi, s_floppy
    call draw_big
    jmp .e
.p: CRECT 24, 22, 106, 44, C_BLACK, 2, 1, 1, 2
    mov dword [sp_x], 30
    mov dword [sp_y], 27
    mov byte [sp_inv], 1
    call draw_sprite
    mov dword [t_x], 100
    mov dword [t_y], 50
    mov dword [r_c], C_WHITE
    mov esi, s_floppy
    call draw_big
.e: popad
    ret

; Рисунок дискеты 16x11 (точки по 2x2) в sp_x, sp_y (половинные точки)
draw_sprite:
    pushad
    mov esi, flop_img
    xor ebx, ebx
.r: xor edi, edi
.c: lodsb
    cmp al, '.'
    je .n
    mov ah, C_GRAY
    cmp al, 'k'
    jne .w
    mov ah, C_BLACK
    cmp byte [sp_inv], 0
    je .d
    mov ah, C_WHITE
    jmp .d
.w: cmp al, 'w'
    jne .d
    mov ah, C_WHITE
    cmp byte [sp_inv], 0
    je .d
    mov ah, C_BLACK
.d: movzx eax, ah
    mov [r_c], eax
    mov eax, [sp_x]
    add eax, edi
    shl eax, 1
    mov [r_x], eax
    mov eax, [sp_y]
    add eax, ebx
    shl eax, 1
    mov [r_y], eax
    mov dword [r_w], 2
    mov dword [r_h], 2
    call fill_rect
.n: inc edi
    cmp edi, 16
    jb .c
    inc ebx
    cmp ebx, 11
    jb .r
    popad
    ret

; Прямоугольник со срезанными углами (как d2_crect в Floppy 1.1): координаты половинные, 1 клетка = 2 точки
crect:
    pushad
    mov eax, [cr_y0]
    mov [cr_y], eax
.row:
    mov eax, [cr_y]
    cmp eax, [cr_y1]
    jg .done
    xor ebx, ebx                        ; ebx - срез слева, ecx - справа
    xor ecx, ecx
    mov edx, eax
    sub edx, [cr_y0]                    ; edx - строка сверху
    mov esi, [cr_y1]
    sub esi, eax                        ; esi - строка снизу
    cmp edx, 0
    jne .i1
    mov ebx, [cr_tl]
    mov ecx, [cr_tr]
    jmp .j
.i1:cmp edx, 1
    jne .j
    mov ebx, [cr_tl]
    shr ebx, 1
    mov ecx, [cr_tr]
    shr ecx, 1
.j: cmp esi, 0
    jne .j1
    mov eax, [cr_bl]
    cmp eax, ebx
    jbe .a
    mov ebx, eax
.a: mov eax, [cr_br]
    cmp eax, ecx
    jbe .draw
    mov ecx, eax
    jmp .draw
.j1:cmp esi, 1
    jne .draw
    mov eax, [cr_bl]
    shr eax, 1
    cmp eax, ebx
    jbe .c
    mov ebx, eax
.c: mov eax, [cr_br]
    shr eax, 1
    cmp eax, ecx
    jbe .draw
    mov ecx, eax
.draw:
    mov eax, [cr_x0]
    add eax, ebx
    shl eax, 1
    mov [r_x], eax
    mov eax, [cr_x1]
    sub eax, ecx
    inc eax
    shl eax, 1
    sub eax, [r_x]
    mov [r_w], eax
    mov eax, [cr_y]
    shl eax, 1
    mov [r_y], eax
    mov dword [r_h], 2
    mov eax, [cr_c]
    mov [r_c], eax
    call fill_rect
    inc dword [cr_y]
    jmp .row
.done:
    popad
    ret

; Крупная строка esi (16x32): шрифт BIOS 8x16, каждая точка - квадрат 2x2. Точка t_x, t_y, цвет r_c
draw_big:
    pushad
    call ui_tr
    mov eax, [t_x]
    mov [bg_x], eax
.ch:lodsb
    test al, al
    jz .e
    movzx eax, al
    shl eax, 4
    add eax, [0x500]
    mov ebp, eax
    xor ebx, ebx                        ; строка 0..15
.row:
    movzx eax, byte [ebp + ebx]
    mov edx, 0x80
    xor edi, edi
.col:
    test eax, edx
    jz .sk
    push eax
    push edx
    mov eax, edi
    shl eax, 1
    add eax, [bg_x]
    mov [r_x], eax
    mov eax, ebx
    shl eax, 1
    add eax, [t_y]
    mov [r_y], eax
    mov dword [r_w], 2
    mov dword [r_h], 2
    call fill_rect
    pop edx
    pop eax
.sk:shr edx, 1
    inc edi
    cmp edi, 8
    jb .col
    inc ebx
    cmp ebx, 16
    jb .row
    add dword [bg_x], 16
    jmp .ch
.e: popad
    ret

; Прямоугольник с обрезкой по clp_x0.. clp_y1: r_x, r_y, r_w, r_h, цвет r_c, r_fn (0 или 0x18 - переворот цветов)
fill_rect:
    pushad
    push dword [r_x]
    push dword [r_y]
    push dword [r_w]
    push dword [r_h]
    mov eax, [r_x]
    mov edx, eax
    add edx, [r_w]
    cmp eax, [clp_x0]
    jge .a
    mov eax, [clp_x0]
.a: cmp edx, [clp_x1]
    jle .b
    mov edx, [clp_x1]
.b: sub edx, eax
    jle .skip
    mov [r_x], eax
    mov [r_w], edx
    mov eax, [r_y]
    mov edx, eax
    add edx, [r_h]
    cmp eax, [clp_y0]
    jge .c
    mov eax, [clp_y0]
.c: cmp edx, [clp_y1]
    jle .d
    mov edx, [clp_y1]
.d: sub edx, eax
    jle .skip
    mov [r_y], eax
    mov [r_h], edx
    call fill_rect0
.skip:
    pop dword [r_h]
    pop dword [r_w]
    pop dword [r_y]
    pop dword [r_x]
    popad
    ret

; Прямоугольник: r_x, r_y, r_w, r_h, цвет r_c (карта планарная: 4 плоскости, 100 байт в строке)
fill_rect0:
    pushad
    mov dx, 0x3CE
    mov ax, 0x0005
    out dx, ax
    mov ah, [r_fn]
    mov al, 3
    out dx, ax
    mov ax, 0x0F01
    out dx, ax
    mov ah, [r_c]
    mov al, 0
    out dx, ax
    mov dx, 0x3C4
    mov ax, 0x0F02
    out dx, ax
    mov esi, [r_y]
    mov ebp, [r_h]
.row:
    mov eax, esi
    imul eax, 100
    add eax, VGA
    mov edi, eax
    mov ecx, [r_x]
    mov ebx, ecx
    shr ebx, 3                      ; первый байт
    mov edx, ecx
    add edx, [r_w]
    dec edx                         ; последний пиксель
    mov eax, edx
    shr eax, 3                      ; последний байт
    and ecx, 7
    mov ch, 0xFF
    shr ch, cl                      ; маска слева
    and edx, 7
    mov cl, 7
    sub cl, dl
    mov dh, 0xFF
    shl dh, cl                      ; маска справа
    add edi, ebx
    sub eax, ebx
    mov bh, dh                      ; bh - маска справа, ch - слева
    mov edx, eax                    ; edx - сколько байт после первого
    jnz .many
    and ch, bh
    mov ah, ch
    call put_byte
    jmp .next
.many:
    mov ah, ch
    call put_byte
    inc edi
    dec edx                         ; сколько полных байт в середине
    jz .last
    mov ecx, edx
    mov dx, 0x3CE                   ; середина: все точки, маску ставим один раз
    mov ax, 0xFF08
    out dx, ax
    cmp dword [r_fn], 0
    jne .xr
    xor eax, eax
    rep stosb
    jmp .last
.xr:mov al, [edi]                       ; при XOR перед каждой записью нужно прочитать байт (защёлки)
    mov [edi], al
    inc edi
    loop .xr
.last:
    mov ah, bh
    call put_byte
.next:
    inc esi
    dec ebp
    jnz .row
    popad
    ret

; ah - маска пикселей, edi - байт видеопамяти: записать цветом из set/reset
put_byte:
    push eax
    push edx
    mov dx, 0x3CE
    mov al, 8
    out dx, ax
    mov al, [edi]
    mov [edi], al
    pop edx
    pop eax
    ret

; прерывания
IDT     equ 0x40000

idt_init:
    pushad
    mov edi, IDT
    mov ecx, 48
    mov ebx, exc_handler
.e: call idt_gate                   ; сначала все ловим одним обработчиком (исключения и пустые прерывания)
    loop .e
    mov edi, IDT                        ; ошибки процессора 0..31 - экран смерти
    mov esi, pn_tab
    mov ecx, 32
.x: mov ebx, [esi]
    call idt_gate
    add esi, 4
    loop .x
    mov edi, IDT + 8 * 0x21
    mov ebx, kbd_irq
    call idt_gate
    mov edi, IDT + 8 * 0x2C
    mov ebx, mouse_irq
    call idt_gate
    mov edi, IDT + 8 * 0x20             ; таймер: считает тики (нужны курсору-будильнику)
    mov ebx, timer_irq
    call idt_gate
    lidt [idtr]
    mov al, 0x11                        ; контроллер прерываний: IRQ 0-7 -> 0x20.., IRQ 8-15 -> 0x28..
    out 0x20, al
    out 0xA0, al
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al
    mov al, 4
    out 0x21, al
    mov al, 2
    out 0xA1, al
    mov al, 1
    out 0x21, al
    out 0xA1, al
    mov al, 0xF8                        ; включены: таймер(закрытый), клавиатура, связь с вторым
    out 0x21, al
    mov al, 0xEF                        ; включена мышь (IRQ 12)
    out 0xA1, al
    mov al, 0x34                        ; таймер 0: режим 2, период 65536 (по счётчику меряет время игра Boil)
    out 0x43, al
    xor al, al
    out 0x40, al
    out 0x40, al
    popad
    ret

; Запись в таблице прерываний: edi - куда, ebx - адрес обработчика; edi вперёд на 8
idt_gate:
    push ebx
    mov [edi], bx
    mov word [edi + 2], 0x08
    mov word [edi + 4], 0x8E00
    shr ebx, 16
    mov [edi + 6], bx
    pop ebx
    add edi, 8
    ret

exc_handler:
    cli
.h: hlt
    jmp .h
irq_empty:
    push eax
    mov al, 0x20
    out 0x20, al
    pop eax
    iretd
timer_irq:                              ; 18 раз в секунду
    inc dword [ticks]
    push eax
    mov al, 0x20
    out 0x20, al
    pop eax
    iretd

; клавиатура
kbd_init:
    in al, 0x60                         ; вынуть то, что там застряло
    ret

kbd_irq:
    pushad
    in al, 0x64                         ; байт должен быть от клавиатуры (бит 5 = 0)
    and al, 0x21
    cmp al, 1
    jne .e
    in al, 0x60
    cmp al, 0xE0                        ; расширенные клавиши: пока только стрелки вверх и вниз
    jne .ne0
    mov byte [ext], 1
    jmp .e
.ne0:
    cmp byte [ext], 0
    je .ne1
    mov byte [ext], 0
    cmp al, 0x48
    jne .u1
    mov al, 0x90
    jmp .p2
.u1:cmp al, 0x50
    jne .u2
    mov al, 0x91
    jmp .p2
.u2:mov bl, al                          ; остальные расширенные клавиши (для itge): влево, вправо, Home, End, Delete, PgUp, PgDn
    mov esi, ext_map
.u3:mov ah, [esi]
    test ah, ah
    jz .e
    cmp ah, bl
    je .u4
    add esi, 2
    jmp .u3
.u4:mov al, [esi + 1]
    jmp .p2
.ne1:
    mov bl, al
    and bl, 0x7F
    cmp bl, 0x2A
    je .sh
    cmp bl, 0x36
    je .sh
    cmp bl, 0x1D
    je .ct
    cmp bl, 0x38
    je .at
    test al, 0x80                       ; отпускание клавиши - буква не нужна
    jnz .e
    cmp al, 0x0F                        ; Ctrl+Tab переключает раскладку
    jne .nt
    cmp byte [ctrl], 0
    je .nt
    xor byte [kb_ru], 1
    jmp .e
.nt:cmp al, 0x39
    ja .e
    movzx ebx, al
    mov al, [sc_norm + ebx]
    cmp byte [shift], 0
    je .n1
    mov al, [sc_shift + ebx]
.n1:cmp byte [kb_ru], 0                 ; русская раскладка (с Ctrl и Alt остаются английские буквы)
    je .p
    cmp byte [ctrl], 0
    jne .p
    cmp byte [alt], 0
    jne .p
    mov al, [sc_ru + ebx]
    cmp byte [shift], 0
    je .p
    mov al, [sc_rus + ebx]
.p: cmp byte [ctrl], 0
    je .p2
    cmp al, 'A'                         ; Ctrl+Shift+буква: коды 0xA0..0xB9
    jb .lc
    cmp al, 'Z'
    ja .lc
    add al, 0x5F
    jmp .p2
.lc:cmp al, 'a'
    jb .p2
    cmp al, 'z'
    ja .p2
    and al, 0x1F                        ; Ctrl+буква: коды 1..26
    cmp al, 0x14
    jne .p2
    cmp byte [alt], 0                   ; Ctrl+Alt+T - диспетчер задач
    je .p2
    mov al, 0x92
.p2:test al, al
    jz .e
    movzx ebx, byte [kq_w]
    mov [kq + ebx], al
    inc byte [kq_w]
    jmp .e
.sh:test al, 0x80
    jnz .sh0
    cmp byte [shift], 0
    jne .e
    mov byte [shift], 1
    jmp .e
.sh0:mov byte [shift], 0
    jmp .e
.ct:test al, 0x80
    jnz .ct0
    cmp byte [ctrl], 0
    jne .e
    mov byte [ctrl], 1
    jmp .e
.ct0:mov byte [ctrl], 0
    jmp .e
.at:test al, 0x80
    setz byte [alt]
.e: mov al, 0x20
    out 0x20, al
    popad
    iretd

; мышь PS/2
kbc_wait_in:                            ; ждём, пока можно писать контроллеру
    in al, 0x64
    test al, 2
    jnz kbc_wait_in
    ret
kbc_wait_out:                           ; ждём, пока есть что читать
    in al, 0x64
    test al, 1
    jz kbc_wait_out
    ret
mouse_send:                             ; байт al - мыши
    push eax
    call kbc_wait_in
    mov al, 0xD4
    out 0x64, al
    call kbc_wait_in
    pop eax
    out 0x60, al
    call kbc_wait_out
    in al, 0x60                         ; подтверждение 0xFA
    ret

mouse_init:
    pushad
    call kbc_flush                      ; в контроллере мог остаться байт от клавиши из меню загрузки
    call kbc_wait_in
    mov al, 0xA8                        ; включить порт мыши
    out 0x64, al
    call kbc_flush
    call kbc_wait_in
    mov al, 0x20                        ; прочитать настройки
    out 0x64, al
    call kbc_wait_out
    in al, 0x60
    or al, 3                            ; разрешить прерывания клавиатуры и мыши
    and al, 0xCF                        ; включить часы клавиатуры и мыши
    mov bl, al
    call kbc_wait_in
    mov al, 0x60
    out 0x64, al
    call kbc_wait_in
    mov al, bl
    out 0x60, al
    mov al, 0xF6                        ; настройки по умолчанию
    call mouse_send
    mov al, 0xF4                        ; присылай движения
    call mouse_send
    popad
    ret

; Выбросить всё, что лежит в контроллере клавиатуры
kbc_flush:
    push eax
    push ecx
    mov ecx, 64
.l: in al, 0x64
    test al, 1
    jz .e
    in al, 0x60
    loop .l
.e: pop ecx
    pop eax
    ret

mouse_irq:
    pushad
    in al, 0x64                         ; байт должен быть от мыши (бит 5), иначе забывать
    and al, 0x21
    cmp al, 0x21
    jne .done
    in al, 0x60
    movzx ebx, byte [mp_i]
    cmp ebx, 0
    jne .ok
    test al, 8                          ; первый байт всегда с единицей в бите 3, иначе мы сбились
    jz .done
.ok:mov [mp + ebx], al
    inc ebx
    cmp ebx, 3
    jb .sv
    xor ebx, ebx
    movzx eax, byte [mp]
    mov [m_btn], al
    and byte [m_btn], 7
    movsx ecx, byte [mp + 1]            ; на сколько сдвинули по x
    movsx edx, byte [mp + 2]            ; по y (вверх - плюс)
    add [m_x], ecx
    sub [m_y], edx
    cmp dword [m_x], 0
    jge .x1
    mov dword [m_x], 0
.x1:cmp dword [m_x], 799
    jle .y0
    mov dword [m_x], 799
.y0:cmp dword [m_y], 0
    jge .y1
    mov dword [m_y], 0
.y1:cmp dword [m_y], 599
    jle .d
    mov dword [m_y], 599
.d: mov byte [m_dirty], 1
.sv:mov [mp_i], bl
.done:
    mov al, 0x20
    out 0xA0, al
    out 0x20, al
    popad
    iretd

; окно main
MV_CW   equ 176                         ; размер содержимого main: если окно меньше - появляются полоски
MV_CH   equ 256

; Цвета и рамки окна: origin cw_x, cw_y, размер win_w x win_h
cwin:
    pushad
    mov eax, [cw_x]
    sar eax, 1
    mov [cwn_x], eax
    mov eax, [cw_y]
    sar eax, 1
    mov [cwn_y], eax
    mov esi, cwin_tab
    mov ecx, 3
.l: movsx eax, byte [esi]
    add eax, [cwn_x]
    mov [cr_x0], eax
    mov eax, [win_w]
    shr eax, 1
    movsx edx, byte [esi + 2]
    add eax, edx
    add eax, [cwn_x]
    mov [cr_x1], eax
    movsx eax, byte [esi + 1]
    add eax, [cwn_y]
    mov [cr_y0], eax
    mov eax, [win_h]
    shr eax, 1
    movsx edx, byte [esi + 3]
    add eax, edx
    add eax, [cwn_y]
    mov [cr_y1], eax
    movzx eax, byte [esi + 4]
    mov [cr_c], eax
    movzx eax, byte [esi + 5]
    mov [cr_tl], eax
    movzx eax, byte [esi + 6]
    mov [cr_tr], eax
    movzx eax, byte [esi + 7]
    mov [cr_bl], eax
    movzx eax, byte [esi + 8]
    mov [cr_br], eax
    call crect
    add esi, 9
    dec ecx
    jnz .l
    popad
    ret

; Крестик 24x22 в точке eax, ebx; edi = 1 - нажат (чёрный квадрат, белый крестик)
xbtn:
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
    xor ecx, ecx
.l: mov eax, ecx
    shl eax, 1
    mov ebx, eax
    add eax, [xb_x]
    add eax, 6
    mov [r_x], eax
    add ebx, [xb_y]
    add ebx, 4
    mov [r_y], ebx
    mov dword [r_w], 4
    mov dword [r_h], 2
    mov eax, [xb_fg]
    mov [r_c], eax
    call fill_rect
    mov eax, [xb_x]
    add eax, 18
    mov ebx, ecx
    shl ebx, 1
    sub eax, ebx
    mov [r_x], eax
    call fill_rect
    inc ecx
    cmp ecx, 7
    jb .l
    popad
    ret

; Кнопка свернуть 24x22: свободная, без обводки, как xbtn.
; eax, ebx = экранные координаты, edi = 1 при нажатии.
mbtn:
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
    mov dword [r_h], 3
    mov eax, [xb_fg]
    mov [r_c], eax
    call fill_rect
    popad
    ret

; AL = ID заголовочной кнопки. EDI = 1 только если она нажата.
; Не трогает остальные регистры (используется и модулями .sys).
title_button_state:
    xor edi, edi
    cmp byte [title_down], al
    jne .no
    mov edi, 1
.no:ret

; Button latch for ordinary window controls (not titlebar buttons).
; ui_btn_owner: 1 Disks, 2 Format?, 3 Save/Open, 4 Tasks,
;               5 FloFile Name, 6 Replace?.
; AL = hit ID, DL = window owner. EDI returns pressed flag for wbtn.
ui_button_state:
    xor edi, edi
    cmp dl, [ui_btn_owner]
    jne .ret
    cmp al, [ui_btn_id]
    jne .ret
    mov edi, 1
.ret:ret

; AL = ID, DL = owner. Caller redraws to show the pressed state.
ui_button_capture:
    mov [ui_btn_id], al
    mov [ui_btn_owner], dl
    ret

; Кнопка "<" 24x22
lbtn:
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
    xor ecx, ecx
.l: mov eax, ecx
    sub eax, 3
    jge .p
    neg eax
.p: shl eax, 1
    add eax, [xb_x]
    add eax, 7
    mov [r_x], eax
    mov ebx, ecx
    shl ebx, 1
    add ebx, [xb_y]
    add ebx, 4
    mov [r_y], ebx
    mov dword [r_w], 4
    mov dword [r_h], 2
    mov eax, [xb_fg]
    mov [r_c], eax
    call fill_rect
    inc ecx
    cmp ecx, 7
    jb .l
    popad
    ret

btn_colors:                             ; edi = 1: цвета наоборот
    mov dword [xb_bg], C_WHITE
    mov dword [xb_fg], C_BLACK
    test edi, edi
    jz .r
    mov dword [xb_bg], C_BLACK
    mov dword [xb_fg], C_WHITE
.r: ret

; esi = подпись пункта ebx (0..2) в текущей папке main (0 - нет пункта)
mlabel:
    movzx esi, byte [mv_view]
    shl esi, 3
    add esi, ebx
    mov esi, [mv_tab + esi * 4]
    ret

; Где пункт ebx: ecx - сдвиг вправо в точках, edx - номер ряда. В programs пункты по три в ряд
mpos:
    mov edx, ebx
    xor ecx, ecx
    cmp byte [mv_view], 1
    jne .r
    mov eax, ebx
    xor edx, edx
    mov ecx, 3
    div ecx
    imul ecx, edx, 160
    mov edx, eax
.r: ret

mi_xs   dd 0
mi_wx   dd 0

; Пункт ebx (0..2) целиком: тень, рамка, середина, подпись; edi = 1 - нажат
mitem:
    pushad
    mov [mi_inv], edi
    call mlabel
    mov [mi_l], esi
    mov dword [mi_wx], 0
    cmp ebx, 6                          ; FloCalendar: кнопка шире
    jne .nwx
    mov dword [mi_wx], 34
.nwx:call mpos
    mov [mi_xs], ecx
    imul ebx, edx, 28
    mov [mi_k], ebx
    mov eax, [mx0]
    sub eax, [msx]
    add eax, [mi_xs]
    sar eax, 1
    mov [mi_x], eax
    mov eax, [my0]
    sub eax, [msy]
    sar eax, 1
    add eax, ebx
    mov [mi_y], eax
    mov esi, mi_tab
    mov ecx, 3
.l: movzx eax, byte [esi]
    add eax, [mi_x]
    mov [cr_x0], eax
    movzx eax, byte [esi + 2]
    add eax, [mi_x]
    add eax, [mi_wx]
    mov [cr_x1], eax
    movzx eax, byte [esi + 1]
    add eax, [mi_y]
    mov [cr_y0], eax
    movzx eax, byte [esi + 3]
    add eax, [mi_y]
    mov [cr_y1], eax
    movzx eax, byte [esi + 4]
    cmp ecx, 1
    jne .nc
    cmp dword [mi_inv], 0
    je .nc
    mov eax, C_BLACK
.nc:mov [cr_c], eax
    movzx eax, byte [esi + 5]
    mov [cr_tl], eax
    mov [cr_tr], eax
    mov [cr_bl], eax
    mov [cr_br], eax
    call crect
    add esi, 6
    dec ecx
    jnz .l
    mov eax, [mx0]                      ; подпись: x +24, y +4 от верха пункта
    sub eax, [msx]
    add eax, [mi_xs]
    add eax, 24
    mov [t_x], eax
    mov eax, [my0]
    sub eax, [msy]
    add eax, [mi_k]
    add eax, [mi_k]
    add eax, 52
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    cmp dword [mi_inv], 0
    je .tb
    mov dword [r_c], C_WHITE
.tb:mov esi, [mi_l]
    call draw_big
    popad
    ret

; Размеры видимой части и полосок, прокрутка не дальше конца
mlayout:
    pushad
    mov dword [mv_ch], MV_CH
    mov dword [mv_cw], MV_CW
    cmp byte [mv_view], 1               ; в programs по три программы в ряд
    jne .mc
    mov dword [mv_cw], 504
.mc:    mov eax, [mw]
    sub eax, 4
    mov [mv_vw], eax
    mov eax, [mh]
    sub eax, 42
    mov [mv_vh], eax
    mov byte [vbar], 0
    mov byte [hbar], 0
    mov eax, [mv_ch]
    cmp [mv_vh], eax
    jge .a
    mov byte [vbar], 1
    sub dword [mv_vw], 16
.a: mov eax, [mv_cw]
    cmp [mv_vw], eax
    jge .b
    mov byte [hbar], 1
    sub dword [mv_vh], 16
.b: cmp byte [vbar], 0
    jne .c
    mov eax, [mv_ch]
    cmp [mv_vh], eax
    jge .c
    mov byte [vbar], 1
    sub dword [mv_vw], 16
.c: mov eax, [mv_ch]
    add eax, 7
    sub eax, [mv_vh]
    jge .d1
    xor eax, eax
.d1:and eax, -8
    cmp [msy], eax
    jle .d2
    mov [msy], eax
.d2:mov eax, [mv_cw]
    add eax, 7
    sub eax, [mv_vw]
    jge .d3
    xor eax, eax
.d3:and eax, -8
    cmp [msx], eax
    jle .d4
    mov [msx], eax
.d4:popad
    ret

mclip_on:
    mov eax, [mx0]
    add eax, 2
    mov [clp_x0], eax
    add eax, [mv_vw]
    mov [clp_x1], eax
    mov eax, [my0]
    add eax, 40
    mov [clp_y0], eax
    add eax, [mv_vh]
    mov [clp_y1], eax
    ret
mclip_off:
    mov dword [clp_x0], 0
    mov dword [clp_y0], 0
    mov dword [clp_x1], 800
    mov dword [clp_y1], 600
    ret

main_show:
    pushad
    call mlayout
    mov eax, [mx0]
    mov [cw_x], eax
    mov eax, [my0]
    mov [cw_y], eax
    mov eax, [mw]
    mov [win_w], eax
    mov eax, [mh]
    mov [win_h], eax
    call cwin
    mov eax, [mx0]
    add eax, 2
    mov [r_x], eax
    mov eax, [my0]
    add eax, 38
    mov [r_y], eax
    mov eax, [mw]
    sub eax, 4
    mov [r_w], eax
    mov dword [r_h], 2
    mov dword [r_c], C_BLACK
    call fill_rect
    mov eax, [mw]                       ; заголовок main по центру
    sub eax, 64
    shr eax, 1
    add eax, [mx0]
    mov [t_x], eax
    mov eax, [my0]
    add eax, 2
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_main
    call draw_big
    mov eax, [mx0]
    add eax, [mw]
    sub eax, 32
    mov ebx, [my0]
    add ebx, 8
    xor edi, edi
    call xbtn
    cmp byte [mv_view], 0
    je .it
    mov eax, [mx0]
    add eax, 8
    mov ebx, [my0]
    add ebx, 8
    xor edi, edi
    call lbtn
.it:call mclip_on
    xor ebx, ebx
.sl:call mlabel
    test esi, esi
    jz .nx
    push ebx
    xor edi, edi
    call mitem
    pop ebx
.nx:inc ebx
    cmp ebx, 7
    jb .sl
    call mclip_off
    cmp byte [vbar], 0
    je .nv
    mov eax, [mx0]
    add eax, [mw]
    sub eax, 18
    mov ebx, [my0]
    add ebx, 40
    mov ecx, [mh]
    sub ecx, 58
    xor edx, edx
    mov esi, [mv_vh]
    mov edi, [mv_ch]
    mov ebp, [msy]
    call sbar
.nv:cmp byte [hbar], 0
    je .nh
    mov eax, [mx0]
    add eax, 2
    mov ebx, [my0]
    add ebx, [mh]
    sub ebx, 18
    mov ecx, [mw]
    sub ecx, 20
    mov edx, 1
    mov esi, [mv_vw]
    mov edi, [mv_cw]
    mov ebp, [msx]
    call sbar
.nh:mov eax, [mx0]                      ; чёрный квадрат: за него растягивают окно
    add eax, [mw]
    sub eax, 18
    mov [r_x], eax
    mov eax, [my0]
    add eax, [mh]
    sub eax, 18
    mov [r_y], eax
    mov dword [r_w], 16
    mov dword [r_h], 16
    mov dword [r_c], C_BLACK
    call fill_rect
    popad
    ret

; Полоса прокрутки: eax, ebx - угол, ecx - длина, edx = 1 горизонтальная, esi - видимая часть, edi - всё, ebp - сдвиг
sbar:
    pushad
    mov [sb_x], eax
    mov [sb_y], ebx
    mov [sb_l], ecx
    mov [sb_h], edx
    mov [sb_s], ebp
    mov [r_x], eax
    mov [r_y], ebx
    mov dword [r_c], C_BLACK
    test edx, edx
    jnz .h1
    mov eax, [sb_w]
    mov [r_w], eax
    mov [r_h], ecx
    jmp .d1
.h1:mov [r_w], ecx
    mov dword [r_h], 16
.d1:call fill_rect
    add dword [r_x], 2
    add dword [r_y], 2
    sub dword [r_w], 4
    sub dword [r_h], 4
    mov dword [r_c], C_DBLUE
    call fill_rect
    mov ecx, [sb_l]
    call sblen
    mov [sb_n], eax
    mov ecx, [sb_l]
    sub ecx, 4
    sub ecx, eax
    mov eax, ecx
    imul eax, [sb_s]
    mov ebx, edi
    sub ebx, esi
    jle .p0
    xor edx, edx
    div ebx
    jmp .pp
.p0:xor eax, eax
.pp:mov ebx, [sb_x]
    add ebx, 2
    mov ecx, [sb_y]
    add ecx, 2
    mov dword [r_c], C_BLACK
    cmp dword [sb_h], 0
    jne .hh
    add ecx, eax
    mov [r_x], ebx
    mov [r_y], ecx
    mov eax, [sb_w]
    sub eax, 4
    mov [r_w], eax
    mov eax, [sb_n]
    mov [r_h], eax
    jmp .dr
.hh:add ebx, eax
    mov [r_x], ebx
    mov [r_y], ecx
    mov eax, [sb_n]
    mov [r_w], eax
    mov dword [r_h], 12
.dr:call fill_rect
    add dword [r_x], 2                  ; ползунок: чёрная рамка, внутри белый
    add dword [r_y], 2
    sub dword [r_w], 4
    sub dword [r_h], 4
    cmp dword [r_w], 0
    jle .dz
    cmp dword [r_h], 0
    jle .dz
    mov dword [r_c], C_WHITE
    call fill_rect
.dz:popad
    ret

; длина ползунка: ecx - длина полосы, esi - видимая часть, edi - всё -> eax
sblen:
    push ebx
    push edx
    mov eax, ecx
    sub eax, 4
    imul eax, esi
    mov ebx, edi
    xor edx, edx
    div ebx
    cmp eax, 16
    jae .a
    mov eax, 16
.a: mov edx, ecx
    sub edx, 4
    cmp eax, edx
    jbe .b
    mov eax, edx
.b: pop edx
    pop ebx
    ret

; Куда сдвинуть, если ползунок тянут: eax - начало полосы, ebx - мышь, ecx - длина, esi, edi -> eax
sbcalc:
    push ebx
    push ecx
    push edx
    sub ebx, eax
    call sblen
    mov edx, eax                        ; edx - длина ползунка
    sub ebx, [sb_off]
    sub ebx, 2
    jge .p
    xor ebx, ebx
.p: mov eax, ecx
    sub eax, 4
    sub eax, edx                        ; ход ползунка
    jle .z
    mov ecx, eax
    mov edx, edi
    sub edx, esi                        ; ход содержимого
    jle .z
    mov eax, ebx
    imul eax, edx
    mov ebx, edx
    xor edx, edx
    div ecx
    cmp eax, ebx
    jbe .c
    mov eax, ebx
.c: and eax, -8
    jmp .o
.z: xor eax, eax
.o: pop edx
    pop ecx
    pop ebx
    ret

; Какой ползунок тянут (sb_drag 17 вертикальный, 18 горизонтальный): eax - начало полосы, ebx - мышь,
; ecx - длина, esi - видно, edi - всего, ebp - сдвиг, [sb_vp] - адрес сдвига
sb_params:
    cmp byte [sb_ctx], 5
    jne .nd5
    mov eax, [qy0]                      ; окно Save to / Open: список файлов
    add eax, [dl_ly]
    mov ebx, [m_y]
    mov ecx, [dl_vis]
    shl ecx, 5
    mov esi, ecx
    movzx edi, byte [dl_cnt]
    shl edi, 5
    movzx ebp, byte [dl_scr]
    shl ebp, 5
    mov [dl_sbo], ebp
    mov dword [sb_vp], dl_sbo
    ret
.nd5:
    cmp byte [sb_ctx], 4
    jb .nst
    mov eax, [st_x]                     ; Settings: ползунок размера курсора
    add eax, ST_X0
    mov ebx, [m_x]
    mov ecx, 240
    mov esi, 8
    mov edi, 32
    mov ebp, [cu_scale]
    dec ebp
    shl ebp, 3
    mov [st_sbo], ebp
    mov dword [sb_vp], st_sbo
    ret
.nst:
    cmp byte [sb_ctx], 2
    jb .old
    je .tx
    mov eax, 130                        ; FloFile
    mov ebx, [m_y]
    mov ecx, 448
    mov esi, 448
    movzx edi, byte [fl_cnt]
    shl edi, 5
    movzx ebp, byte [fl_scr]
    shl ebp, 5
    mov [fl_sbo], ebp
    mov dword [sb_vp], fl_sbo
    ret
.tx:call tx_total                       ; FloText
    shl eax, 5
    mov edi, eax
    mov eax, 86
    mov ebx, [m_y]
    mov ecx, 512
    mov esi, 512
    movzx ebp, byte [t2_top]
    shl ebp, 5
    mov [t2_sbo], ebp
    mov dword [sb_vp], t2_sbo
    ret
.old:
    cmp byte [sb_ctx], 0
    je .main
    cmp byte [sb_drag], 17
    jne .ch
    mov eax, [calc_y0]
    add eax, 80
    mov ebx, [m_y]
    mov ecx, [calc_h]
    sub ecx, 98
    mov esi, [cvh]
    mov edi, CALC_CH
    mov ebp, [csy]
    mov dword [sb_vp], csy
    ret
.ch:mov eax, [calc_x0]
    add eax, 2
    mov ebx, [m_x]
    mov ecx, [calc_w]
    sub ecx, 20
    mov esi, [cvw]
    mov edi, CALC_CW
    mov ebp, [csx]
    mov dword [sb_vp], csx
    ret
.main:
    cmp byte [sb_drag], 17
    jne .mh
    mov eax, [my0]
    add eax, 40
    mov ebx, [m_y]
    mov ecx, [mh]
    sub ecx, 58
    mov esi, [mv_vh]
    mov edi, [mv_ch]
    mov ebp, [msy]
    mov dword [sb_vp], msy
    ret
.mh:mov eax, [mx0]
    add eax, 2
    mov ebx, [m_x]
    mov ecx, [mw]
    sub ecx, 20
    mov esi, [mv_vw]
    mov edi, [mv_cw]
    mov ebp, [msx]
    mov dword [sb_vp], msx
    ret

win_show:
    cmp byte [sb_ctx], 5
    jne .nd5
    mov eax, [dl_sbo]
    shr eax, 5
    mov [dl_scr], al
    jmp dlg_draw
.nd5:
    cmp byte [sb_ctx], 0
    je main_show
    cmp byte [sb_ctx], 2
    jb calc_draw
    je .tx
    cmp byte [sb_ctx], 4
    jb .fl
    mov eax, [st_sbo]
    shr eax, 3
    inc eax
    cmp eax, [cu_scale]
    je .nsv
    mov [cu_scale], eax
    call st_save
.nsv:jmp st_draw
.fl:mov eax, [fl_sbo]
    shr eax, 5
    mov [fl_scr], al
    jmp files_draw
.tx:mov eax, [t2_sbo]
    shr eax, 5
    mov [t2_top], al
    jmp text_draw

; Ползунок тянут мышью
sb_set:
    cmp byte [sb_ctx], 4
    je st_slset
    pushad
    call sb_params
    call sbcalc
    cmp byte [sb_ctx], 5
    je .snap
    cmp byte [sb_ctx], 2
    jb .ns
    cmp byte [sb_ctx], 3
    ja .ns
.snap:
    and eax, -32
.ns:    mov edi, [sb_vp]
    cmp eax, [edi]
    je .r
    mov [edi], eax
    call cursor_hide
    call win_show
    call cursor_show
.r: popad
    ret

; Взяли ползунок: запоминаем, за какое место; мимо ползунка - страница в ту сторону
sb_grab:
    pushad
    call sb_params
    sub ebx, eax
    sub ebx, 2
    push ebx
    push ecx
    call sblen
    mov edx, eax                        ; edx - длина ползунка
    pop ecx
    sub ecx, 4
    sub ecx, edx                        ; ход ползунка
    mov ebx, edi
    sub ebx, esi                        ; ход содержимого
    xor eax, eax
    test ebx, ebx
    jle .t0
    mov eax, ecx
    imul eax, ebp
    push edx
    xor edx, edx
    div ebx
    pop edx
.t0:pop ebx                             ; мышь от начала дорожки
    sub ebx, eax                        ; от начала ползунка
    jl .mid
    cmp ebx, edx
    jge .mid
    mov [sb_off], ebx
    jmp .r
.mid:test ebx, ebx
    jl .up
    mov eax, ebp
    mov ecx, esi
    and ecx, -8
    add eax, ecx
    mov ecx, edi
    add ecx, 7
    sub ecx, esi
    jge .m1
    xor ecx, ecx
.m1:and ecx, -8
    cmp eax, ecx
    jbe .st
    mov eax, ecx
    jmp .st
.up:mov eax, ebp
    mov ecx, esi
    and ecx, -8
    sub eax, ecx
    jge .st
    xor eax, eax
.st:mov edi, [sb_vp]
    mov [edi], eax
    call win_show
    mov byte [sb_drag], 0
.r: popad
    ret

; Контур окна (XOR: второй раз стирает): точка dr_nx, dr_ny, размер dr_w x dr_h
outline:
    pushad
    mov dword [r_fn], 0x18
    mov dword [r_c], 15
    mov eax, [dr_nx]
    mov [r_x], eax
    mov eax, [dr_ny]
    mov [r_y], eax
    mov eax, [dr_w]
    mov [r_w], eax
    mov dword [r_h], 2
    call fill_rect
    mov eax, [dr_ny]
    add eax, [dr_h]
    sub eax, 2
    mov [r_y], eax
    call fill_rect
    mov eax, [dr_ny]
    mov [r_y], eax
    mov dword [r_w], 2
    mov eax, [dr_h]
    mov [r_h], eax
    call fill_rect
    mov eax, [dr_nx]
    add eax, [dr_w]
    sub eax, 2
    mov [r_x], eax
    call fill_rect
    mov dword [r_fn], 0
    popad
    ret

; Начало перетаскивания: mode 1 - двигаем main, 6 - растягиваем main
file_drag_context:
    mov [d_ctx], al                    ; AL=13 Name, AL=14 Properties
    ret

drag_start:
    pushad
    mov dword [dr_minw], 160
    mov dword [dr_minh], 104
    cmp byte [d_ctx], 0
    je .nsw
    mov dword [dr_minw], 192
    mov dword [dr_minh], 120
    cmp byte [d_ctx], 3
    jne .nm3
    mov dword [dr_minw], 288
    mov dword [dr_minh], 136
.nm3:
    cmp byte [d_ctx], 2
    jne .nm2
    mov dword [dr_minw], 352            ; диалог Save/Open
    mov dword [dr_minh], 292
.nm2:
    cmp byte [d_ctx], 4
    jne .nm4
    mov dword [dr_minw], 352            ; Floppy_143: узкое окно, команды в два ряда
    mov dword [dr_minh], 288            ; минимум: 1 строка списка и все органы управления
    cmp dword [dk_w], DK_W
    jae .nm4                            ; при ширине >= 432 достаточно одного ряда кнопок
    mov dword [dr_minh], 336
.nm4:
    cmp byte [d_ctx], 5
    jne .nm5
    mov dword [dr_minw], 256
    mov dword [dr_minh], 320
.nm5:
    cmp byte [d_ctx], 6
    jne .nm6
    mov dword [dr_minw], 480           ; Settings: чтобы всё влезало
    mov dword [dr_minh], 440
.nm6:
    cmp byte [d_ctx], 7
    jne .nm7
    mov dword [dr_minw], 352            ; Clock
    mov dword [dr_minh], 282
.nm7:
    cmp byte [d_ctx], 8
    jne .nm8
    mov dword [dr_minw], 320            ; Terminal
    mov dword [dr_minh], 198
.nm8:
    cmp byte [d_ctx], 9                 ; FloCalendar: leave room for 7 dates and 6 rows
    jne .nm9
    mov dword [dr_minw], 352
    mov dword [dr_minh], 320
.nm9:
    call swap_ctx
.nsw:
    mov [drag], bl
    mov eax, [mw]
    mov [dr_w], eax
    mov [rs_w0], eax
    mov eax, [mh]
    mov [dr_h], eax
    mov [rs_h0], eax
    mov eax, [m_x]
    mov [dr_ox], eax
    mov eax, [m_y]
    mov [dr_oy], eax
    mov eax, [mx0]
    mov [dr_nx], eax
    mov eax, [my0]
    mov [dr_ny], eax
    cmp bl, 1
    jne .go
    sub dword [dr_ox], eax              ; схватили за место внутри окна
    mov eax, [m_x]
    sub eax, [mx0]
    mov [dr_ox], eax
    mov eax, [m_y]
    sub eax, [my0]
    mov [dr_oy], eax
.go:
    cmp byte [drag], 1
    jne .draw_outline
    mov byte [cu_kind], 9            ; four arrows throughout active window dragging
.draw_outline:
    call outline
    popad
    ret

drag_move:
    pushad
    cmp byte [drag], 6
    je .rs
    mov eax, [m_x]                      ; двигаем: x кратен 8, y кратен 2
    sub eax, [dr_ox]
    jge .x1
    xor eax, eax
.x1:mov ecx, 792
    sub ecx, [mw]
    cmp eax, ecx
    jle .x2
    mov eax, ecx
.x2:and eax, -8
    mov edx, [m_y]
    sub edx, [dr_oy]
    jge .y1
    xor edx, edx
.y1:mov ecx, 592
    sub ecx, [mh]
    cmp edx, ecx
    jle .y2
    mov edx, ecx
.y2:and edx, -2
    cmp eax, [dr_nx]
    jne .go
    cmp edx, [dr_ny]
    je .r
.go:push eax
    push edx
    call outline
    pop edx
    pop eax
    mov [dr_nx], eax
    mov [dr_ny], edx
    call outline
    jmp .r
.rs:mov eax, [rs_w0]                    ; растягиваем: размер кратен 8, не меньше 160x104
    add eax, [m_x]
    sub eax, [dr_ox]
    cmp eax, [dr_minw]
    jge .w1
    mov eax, [dr_minw]
.w1:mov ecx, 792
    sub ecx, [mx0]
    cmp eax, ecx
    jle .w2
    mov eax, ecx
.w2:and eax, -4
    cmp byte [d_ctx], 4
    jne .keep_min_h
    mov dword [dr_minh], 288
    cmp eax, DK_W
    jae .keep_min_h
    mov dword [dr_minh], 336
.keep_min_h:
    mov edx, [rs_h0]
    add edx, [m_y]
    sub edx, [dr_oy]
    cmp edx, [dr_minh]
    jge .h1
    mov edx, [dr_minh]
.h1:mov ecx, 592
    sub ecx, [my0]
    cmp edx, ecx
    jle .h2
    mov edx, ecx
.h2:and edx, -4
    cmp eax, [dr_w]
    jne .ch
    cmp edx, [dr_h]
    je .r
.ch:push eax
    push edx
    call outline
    pop edx
    pop eax
    mov [dr_w], eax
    mov [dr_h], edx
    call outline
.r: popad
    ret

drag_end:
    pushad
    call outline
    cmp byte [drag], 6
    je .e6
    mov eax, [dr_nx]
    mov [mx0], eax
    mov eax, [dr_ny]
    mov [my0], eax
    jmp .e
.e6:mov eax, [dr_w]
    mov [mw], eax
    mov eax, [dr_h]
    mov [mh], eax
.e: mov byte [drag], 0
    mov byte [cu_kind], 0            ; pointer returns to normal after release
    cmp byte [d_ctx], 0
    je .nsw
    call swap_ctx
    mov byte [d_ctx], 0
.nsw:
    call redraw
    popad
    ret

; Поменять местами положение и размер main и калькулятора (чтобы тащить любое окно одним кодом)
swap_ctx:
    mov esi, calc_x0
    cmp byte [d_ctx], 2
    jne .a
    mov esi, qx0
.a: cmp byte [d_ctx], 3
    jne .b
    mov esi, tm_x
.b: cmp byte [d_ctx], 4
    jne .c
    mov esi, dk_x
.c: cmp byte [d_ctx], 5
    jne .c2
    mov esi, ab_x
.c2:cmp byte [d_ctx], 6
    jne .c3
    mov esi, st_x
.c3:cmp byte [d_ctx], 7
    jne .c4
    mov esi, ck_x
.c4:cmp byte [d_ctx], 8
    jne .c5
    mov esi, tr_x
    jmp .d
.c5:cmp byte [d_ctx], 9
    jne .modal_sv
    mov esi, cal_x
    jmp .d
.modal_sv:
    cmp byte [d_ctx], 10
    jne .modal_err
    mov esi, sv_x
    jmp .d
.modal_err:
    cmp byte [d_ctx], 11
    jne .modal_pw
    mov esi, err_x
    jmp .d
.modal_pw:
    cmp byte [d_ctx], 12
    jne .modal_nm
    mov esi, pw_x
    jmp .d
.modal_nm:
    cmp byte [d_ctx], 13
    jne .modal_pr
    mov esi, nm_x
    jmp .d
.modal_pr:
    cmp byte [d_ctx], 14
    jne .modal_dk_child
    mov esi, pr_x
    jmp .d
.modal_dk_child:
    cmp byte [d_ctx], 15
    jne .modal_replace_child
    mov esi, dk_conf_x
    jmp .d
.modal_replace_child:
    cmp byte [d_ctx], 16
    jne .d
    mov esi, dl_conf_x
.d: mov eax, [mx0]
    xchg eax, [esi]
    mov [mx0], eax
    mov eax, [my0]
    xchg eax, [esi + 4]
    mov [my0], eax
    mov eax, [mw]
    xchg eax, [esi + 8]
    mov [mw], eax
    mov eax, [mh]
    xchg eax, [esi + 12]
    mov [mh], eax
    ret

redraw:
    cmp byte [d2_egg], 0
    jne egg_draw
    cmp byte [d2_ist], 0
    jne ist_draw
    cmp byte [d2_wl], 0
    jne wl_draw
    call draw_desktop
 .a: cmp byte [d2_files], 0
    je .b
    call files_draw
.b: cmp byte [d2_text], 0
    je .c
    call text_draw
.c: cmp byte [d2_paint], 0
    je .c2
    call paint_draw
.c2:
.c3:cmp byte [d2_boil], 0
    je .c4
    call boil_draw
.c4:cmp byte [d2_itge], 0
    je .d
    call itge_draw
.d: call mn_pdraw
    ; Independent Format? dialog can be behind Disks or above it.
    cmp byte [dk_confirm], 0
    je .no_dk_back
    cmp byte [dk_conf_top], 0
    jne .no_dk_back
    call dk_confirm_draw
.no_dk_back:
    call fz_draw                          ; Main, Calc, Calendar, Tasks and floats in Z-order
    cmp byte [dk_confirm], 0
    je .no_dk_front
    cmp byte [dk_conf_top], 0
    je .no_dk_front
    call dk_confirm_draw
.no_dk_front:
    ; The Format restore tab remains accessible when Disks is above it.
    cmp byte [dk_confirm], 0
    je .no_dk_badge
    cmp byte [dk_conf_top], 0
    jne .no_dk_badge
    call dk_conf_back_badge_draw
.no_dk_badge:
    cmp byte [d2_dlg], 0                ; system file modal remains above ordinary windows
    je .h3
    call dlg_draw
.h3:call mn_arrow
    call core_err_mini_draw
    cmp byte [d2_err], 0
    je .f
    call core_err_draw
.f: cmp byte [sv_who], 0
    je .f2
    call sv_draw
.f2:
    cmp byte [pw_open], 0
    je .no_power_overlay
    call power_dialog_draw
.no_power_overlay:
    ret

; Окно "Save changes?": Cancel, Yes, No. sv_who: 1 FloPaint, 2 itge, 3 linked FloPaint, 4 FloText
sv_ask:
    mov byte [sv_btn_down], 0
    mov [sv_who], al
    mov byte [sv_file_menu], 0
    mov byte [sv_min], 0
    mov byte [sv_after], 0
    jmp redraw

sv_cancel:
    mov byte [sv_btn_down], 0
    mov byte [sv_file_menu], 0
    mov byte [sv_min], 0
    mov byte [sv_who], 0
    mov byte [sv_after], 0
    jmp redraw

sv_no:
    mov byte [sv_btn_down], 0
    mov byte [sv_min], 0
    movzx eax, byte [sv_who]
    mov byte [sv_who], 0
    mov byte [sv_after], 0
    cmp al, 3
    je .p3
    cmp al, 4
    je .t4
    cmp al, 1
    jne .i
    jmp paint_close
.p3:mov byte [pa_dirty], 0              ; рисунок в FloPaint не нужен - открываем картинку
    jmp it_ep_go
.t4:jmp text_close
.i: jmp itge_close

sv_yes:
    mov byte [sv_btn_down], 0
    mov byte [sv_min], 0
    mov al, [sv_who]
    mov [sv_after], al
    mov byte [sv_who], 0
    call redraw
    cmp byte [sv_after], 3
    je .y3
    cmp byte [sv_after], 1
    jne .i
    call paint_save
    jmp .a
.y3:call paint_save
    cmp byte [d2_dlg], 0                ; открылось окно Save to - картинку откроем после сохранения
    jne .r
    mov byte [sv_after], 0
    cmp byte [pa_dirty], 0              ; не сохранилось - ничего не открываем
    jne .r
    jmp it_ep_go
.i: cmp byte [sv_after], 4
    jne .i2
    call text_save
    jmp .a
.i2:call it_save
.a: cmp byte [d2_dlg], 0                ; открылось окно Save to - закроем после сохранения
    jne .r
    movzx eax, byte [sv_after]
    mov byte [sv_after], 0
    cmp al, 1
    jne .b
    jmp paint_close
.b: cmp al, 2
    je itge_close
    cmp al, 4
    jne .r
    call text_changed                   ; never close if write failed
    jc .r
    jmp text_close
.r: ret

 ; Return the hit index for Save changes? normal buttons:
; 1 Cancel, 2 Yes, 3 No; 0 outside. No action is performed on mouse-down.
sv_btn_hit:
    xor eax, eax
    cmp byte [sv_who], 0
    je .none
    cmp byte [sv_min], 0
    jne .none
    mov eax, [m_y]
    sub eax, [sv_y]
    cmp eax, 164
    jb .none
    cmp eax, 200
    ja .none
    mov eax, [m_x]
    sub eax, [sv_x]
    cmp eax, 12
    jb .none
    cmp eax, 124
    jbe .cancel
    cmp eax, 136
    jb .none
    cmp eax, 248
    jbe .yes
    cmp eax, 260
    jb .none
    cmp eax, 372
    jbe .no
.none:
    xor eax, eax
    ret
.cancel:
    mov al, 1
    ret
.yes:
    mov al, 2
    ret
.no:
    mov al, 3
    ret

sv_click:
    call sv_btn_hit
    cmp al, 1
    je sv_cancel
    cmp al, 2
    je sv_yes
    cmp al, 3
    je sv_no
    ret

sv_draw:
    pushad
    push dword [cw_x]
    push dword [cw_y]
    cmp byte [sv_min], 0
    je .expanded
    mov dword [cw_x], 0
    mov dword [cw_y], 0
    mov eax, 646
    mov ebx, 508
    mov ecx, 144
    mov edx, 36
    mov esi, sv_mini_title
    xor edi, edi
    call wbtn
    jmp .done
.expanded:
    MODRECT sv_x, sv_y, 8, 8, 384, 216, C_BLACK
    MODRECT sv_x, sv_y, 0, 0, 384, 216, C_BLACK
    MODRECT sv_x, sv_y, 2, 2, 380, 212, C_WHITE
    MODRECT sv_x, sv_y, 2, 40, 380, 2, C_BLACK
    mov eax, [sv_x]
    mov ebx, [sv_y]
    add ebx, 4
    mov edx, 384
    mov esi, sys_title_text
    call sys_modal_center
    mov eax, [sv_x]
    mov ebx, [sv_y]
    add ebx, 112
    mov edx, 384
    mov esi, s_svq
    call sys_modal_center
    mov al, 204
    call title_button_state
    mov eax, [sv_x]
    add eax, 316
    mov ebx, [sv_y]
    add ebx, 8
    call mbtn
    mov al, 205
    call title_button_state
    mov eax, [sv_x]
    add eax, 350
    mov ebx, [sv_y]
    add ebx, 8
    call xbtn
    mov eax, [sv_x]
    mov [cw_x], eax
    mov eax, [sv_y]
    mov [cw_y], eax
    xor edi, edi
    mov eax, 12
    mov ebx, 164
    mov ecx, 112
    mov edx, 36
    mov esi, s_cancel
    cmp byte [sv_btn_down], 1
    jne .cancel_up
    mov edi, 1
.cancel_up:
    call wbtn
    mov eax, 136
    mov ebx, 164
    mov ecx, 112
    mov edx, 36
    mov esi, s_yes
    xor edi, edi
    cmp byte [sv_btn_down], 2
    jne .yes_up
    mov edi, 1
.yes_up:
    call wbtn
    mov eax, 260
    mov ebx, 164
    mov ecx, 112
    mov edx, 36
    mov esi, s_no
    xor edi, edi
    cmp byte [sv_btn_down], 3
    jne .no_up
    mov edi, 1
.no_up:
    call wbtn
    mov eax, [sv_x]
    mov ebx, [sv_y]
    mov ecx, 384
    mov dl, [sv_file_menu]
    call sys_file_draw
.done:
    pop dword [cw_y]
    pop dword [cw_x]
    popad
    ret

sv_min db 0
sv_btn_down db 0                 ; pressed button, commit only on mouse release
sv_file_menu db 0
sv_mini_title db "Save", 0
sv_minus db "-", 0
sv_cross db "X", 0
sv_x dd 208
sv_y dd 216
sv_w dd 384
sv_h dd 216
s_svq       db "Save changes?", 0

; Что под мышью (dx = x, cx = y): 1 кнопка Floppy, 2/13/14 пункты main, 8 заголовок, 9 крестик, 15 назад,
; 16 чёрный квадрат, 17 и 18 полоски; 0 - ничего
hit:
    push ebx
    push esi
    push edi
    mov byte [t_own], 0
    mov byte [fz_hown], 0
    xor al, al
    cmp byte [d2_ist], 0                ; идёт установка: мышь ничего не нажимает
    jne .ret
    cmp byte [d2_egg], 0                ; пасхалка на весь экран: мышь ничего не нажимает
    jne .ret
    mov edx, [m_x]
    mov ecx, [m_y]
    cmp byte [pw_open], 0
    je .not_power_hit
    call power_dialog_hit
    jmp .ret
.not_power_hit:
    cmp byte [d2_wl], 0                 ; welcome на весь экран: только OK и галочка
    je .nwl
    call wl_hit
    jmp .ret
.nwl:
    cmp byte [err_min_code], 0
    je .no_minierr
    cmp edx, 486
    jb .no_minierr
    cmp edx, 618
    ja .no_minierr
    cmp ecx, 508
    jb .no_minierr
    cmp ecx, 544
    ja .no_minierr
    mov al, 191
    jmp .ret
.no_minierr:
    cmp byte [sv_who], 0
    je .nsv0
    cmp byte [sv_min], 0
    je .sv_expanded
    cmp edx, 646
    jb .ret
    cmp edx, 790
    ja .ret
    cmp ecx, 508
    jb .ret
    cmp ecx, 544
    ja .ret
    mov al, 206                         ; restore Save changes?
    jmp .ret
.sv_expanded:
    mov esi, edx
    sub esi, [sv_x]
    js .ret
    mov edi, ecx
    sub edi, [sv_y]
    js .ret
    xor al, al
    cmp esi, 384
    ja .ret
    cmp edi, 216
    ja .ret
    mov dl, [sv_file_menu]
    call sys_file_hit
    test al, al
    jnz .ret
    ; Same title controls as Error: minus, close, then drag region.
    cmp edi, 6
    jb .sv_buttons
    cmp edi, 38
    ja .sv_buttons
    cmp esi, 312
    jb .sv_drag
    cmp esi, 342
    jbe .sv_minus
    cmp esi, 346
    jb .sv_buttons
    cmp esi, 376
    jbe .sv_cross
    jmp .sv_buttons
.sv_minus:
    mov al, 204
    jmp .ret
.sv_cross:
    mov al, 205
    jmp .ret
.sv_drag:
    cmp edi, 4
    jb .sv_buttons
    cmp edi, 44
    ja .sv_buttons
    cmp esi, 8
    jb .sv_buttons
    cmp esi, 376
    ja .sv_buttons
    mov al, 199                         ; Save changes? move handle
    jmp .ret
.sv_buttons:
    cmp edi, 164
    jb .ret
    cmp edi, 200
    ja .ret
    cmp esi, 12
    jb .ret
    cmp esi, 372
    ja .ret
    mov al, 63
    jmp .ret
.nsv0:
    cmp byte [d2_err], 0
    je .ne
    ; Error is modal; Tasks underneath cannot intercept its mouse clicks.
    mov esi, edx
    sub esi, [err_x]
    js .ret
    mov edi, ecx
    sub edi, [err_y]
    js .ret
    xor al, al
    cmp esi, 264
    ja .ret
    cmp edi, 256
    ja .ret
    mov dl, [err_file_menu]
    call sys_file_hit
    test al, al
    jnz .ret
    ; OK button in content area
    cmp esi, 90
    jb .err_header
    cmp esi, 174
    ja .err_header
    cmp edi, 196
    jb .err_header
    cmp edi, 230
    ja .err_header
    mov al, 63
    jmp .ret
.err_header:
    cmp edi, 6
    jb .ret
    cmp edi, 38
    ja .ret
    cmp esi, 188
    jb .err_drag
    cmp esi, 218
    jbe .err_min
    cmp esi, 220
    jb .ret
    cmp esi, 252
    ja .ret
    mov al, 192                       ; close X; separate from OK for press animation
    jmp .ret
.err_min:
    mov al, 190                       ; minimize -
    jmp .ret
.err_drag:
    cmp esi, 4
    jb .ret
    mov al, 198                       ; error title can be dragged
    jmp .ret
.ne:
    cmp byte [d2_dlg], 0                ; modal Save/Open blocks underlying windows
    je .normal_windows
    call dlg_hit
    jmp .ret
.normal_windows:
    cmp byte [dk_conf_top], 0
    je .ordinary_fz_hit
    call dk_conf_screen_hit
    jnc .ordinary_fz_hit
    mov byte [fz_hown], 5
    jmp .ret
.ordinary_fz_hit:
    call fz_hit
    jnc .no_fz_hit
    cmp byte [fz_hown], 6               ; Main's controls are handled below
    je .nc
    jmp .ret
.no_fz_hit:
    cmp byte [dk_conf_top], 0
    jne .no_child_back_hit
    call dk_conf_screen_hit
    jnc .no_child_back_hit
    mov byte [fz_hown], 5
    jmp .ret
.no_child_back_hit:
    ; Uncovered desktop/fullscreen app: lower Disks/Tasks cannot steal hits.
    call hp_hit                         ; кнопка Help и её панель
    jc .ret
    cmp byte [d2_boil], 0
    je .nbo
    call boil_hit
    jmp .ret
.nbo:cmp byte [d2_itge], 0
    je .nit
    call itge_hit
    jmp .ret
.nit:cmp byte [d2_paint], 0
    je .np0
    call paint_hit
    jmp .ret
.np0:cmp byte [d2_calc], 0              ; калькулятор рисуется поверх FloText и FloFile: сначала смотрим его
    je .nd0
    bt dword [z_fz_hidden_mask], 7      ; hidden calculator may not intercept fullscreen clicks
    jc .nd0
    cmp byte [d2_text], 0
    jne .tc
    cmp byte [d2_files], 0
    je .nd0
.tc:push ebp
    call calc_hit
    pop ebp
    test al, al
    jz .nd0
    mov byte [t_own], 1
    jmp .ret
.nd0:cmp byte [d2_text], 0
    je .nt
    call text_hit
    jmp .ret
.nt:cmp byte [d2_files], 0
    je .nf
    call files_hit
    jmp .ret
.nf:cmp byte [d2_calc], 0
    je .nc
    bt dword [z_fz_hidden_mask], 7
    jc .nc
    push ebp
    call calc_hit
    pop ebp
    jmp .ret
.nc:cmp byte [d2_main], 0
    je .fl
    mov esi, edx
    sub esi, [mx0]
    mov edi, ecx
    sub edi, [my0]
    mov eax, [mw]
    add eax, 4
    cmp esi, eax
    ja .fl
    mov eax, [mh]
    add eax, 4
    cmp edi, eax
    ja .fl
    cmp byte [mv_view], 0
    je .b1
    cmp esi, 8
    jb .b1
    cmp esi, 32
    ja .b1
    cmp edi, 8
    jb .b1
    cmp edi, 30
    ja .b1
    mov al, 15
    jmp .ret
.b1:mov eax, [mw]
    sub eax, 32
    cmp esi, eax
    jb .b2
    add eax, 24
    cmp esi, eax
    ja .b2
    cmp edi, 8
    jb .b2
    cmp edi, 30
    ja .b2
    mov al, 9
    jmp .ret
.b2:mov eax, [mw]
    sub eax, 18
    cmp esi, eax
    jb .b4
    mov ebx, [mh]
    sub ebx, 18
    cmp edi, ebx
    jb .rc
    mov al, 16
    jmp .ret
.rc:cmp byte [vbar], 0
    je .b4
    cmp edi, 40
    jb .b4
    mov al, 17
    jmp .ret
.b4:mov ebx, [mh]
    sub ebx, 18
    cmp edi, ebx
    jb .b5
    cmp byte [hbar], 0
    je .b5
    cmp esi, 2
    jb .b5
    mov al, 18
    jmp .ret
.b5:cmp esi, 4
    jb .it
    mov eax, [mw]
    sub eax, 32
    cmp esi, eax
    ja .it
    cmp edi, 2
    jb .it
    cmp edi, 36
    ja .it
    mov al, 8
    jmp .ret
.it:cmp esi, 2
    jb .z
    mov eax, [mv_vw]
    add eax, 2
    cmp esi, eax
    jae .z
    cmp edi, 40
    jb .z
    mov eax, [mv_vh]
    add eax, 40
    cmp edi, eax
    jae .z
    add esi, [msx]
    add edi, [msy]
    xor ebx, ebx
.il:push esi
    call mlabel
    mov eax, esi
    pop esi
    test eax, eax
    jz .in
    call mpos
    mov eax, esi
    sub eax, ecx
    cmp eax, 16
    jb .in
    mov ecx, 160
    cmp ebx, 6                          ; кнопка FloCalendar шире: надпись длиннее
    jne .nw6
    mov ecx, 228
.nw6:cmp eax, ecx
    jae .in
    imul eax, edx, 56
    add eax, 48
    cmp edi, eax
    jb .in
    add eax, 40
    cmp edi, eax
    ja .in
    mov al, 2
    test ebx, ebx
    jz .ret
    mov al, 13
    cmp ebx, 1
    je .ret
    mov al, 14
    cmp ebx, 2
    je .ret
    mov al, 19                          ; FloPaint
    cmp ebx, 3
    je .ret
    mov al, 22                          ; FloClock
    cmp ebx, 4
    je .ret
    mov al, 23                          ; FloItge
    cmp ebx, 5
    je .ret
    mov al, 24                          ; FloCalendar
    jmp .ret
.in:inc ebx
    cmp ebx, 7
    jb .il
.z: xor al, al
    jmp .ret
.fl:cmp edx, 44                         ; desktop buttons: left edge
    jb .z
    cmp ecx, 40
    jb .z
    cmp ecx, 84
    jbe .f1
    cmp ecx, 104
    jb .z
    cmp ecx, 148
    ja .s1
    cmp edx, 208                         ; About button original width
    ja .z
    mov al, 20
    jmp .ret
.s1:cmp ecx, 168
    jb .z
    cmp ecx, 212
    ja .s2
    cmp edx, 208                         ; Setting button: same width as About / Floppy
    ja .z
    mov al, 21
    jmp .ret
.s2:cmp ecx, 232
    jb .z
    cmp ecx, 276
    ja .z
    cmp edx, 208
    ja .z
    mov al, 25                          ; Shut Down, fourth desktop button
    jmp .ret
.f1:cmp edx, 208                         ; Floppy button original width
    ja .z
    mov al, 1
.ret:
    pop edi
    pop esi
    pop ebx
    ret

; Мышь сдвинулась или кнопка поменялась
mouse_event:
    pushad
    call hit
    mov [t_id], al
    cmp byte [pw_open], 0
    jne .power_modal_cursor
    cmp byte [sv_who], 0
    jne .power_modal_cursor
    cmp byte [d2_err], 0
    jne .power_modal_cursor
    call mn_find
    jmp .after_mn_find
.power_modal_cursor:
    mov byte [mn_ov], 0
.after_mn_find:
    cmp byte [pan_resize], 0
    jne .pan_resize_cursor
    cmp byte [mn_ov], 0
    je .nmo
    cmp byte [mn_ov], 0x84
    je .pan_resize_cursor
    cmp byte [mn_ov], 0x85
    je .pan_blank_cursor
    mov byte [t_id], 0                  ; над кнопкой "минус" или стрелкой: ничего другого не нажимается
    mov byte [cu_kind], 1
    jmp .nk
.pan_resize_cursor:
    mov byte [t_id], 0
    mov byte [cu_kind], 11
    jmp .nk
.pan_blank_cursor:
    mov byte [t_id], 0
    mov byte [cu_kind], 0
    jmp .nk
.nmo:
    mov byte [cu_kind], 0               ; стрелка
    test al, al
    jz .nk
    cmp al, 8
    je .nk
    cmp al, 196                         ; FloFile new name dialog title
    je .move_hover
    cmp al, 197                         ; FloFile properties dialog title
    je .move_hover
    cmp al, 198                         ; Error title
    je .move_hover
    cmp al, 199                         ; Save changes? title
    je .move_hover
    cmp al, 200                         ; Shut Down dialog upper part
    je .move_hover
    cmp al, 74
    je .nk
    cmp al, 41
    je .nk
    cmp al, 96
    je .nk
    cmp al, 57
    je .nk
    cmp al, 120
    je .nk
    cmp al, 122
    je .nk
    cmp al, 175                         ; календарь: заголовок и окно - стрелка
    je .nk
    cmp al, 178
    je .nk
    cmp al, 136
    je .nk
    cmp al, 233                        ; independent Format? titlebar
    je .move_hover
    cmp al, 234                        ; independent Replace? titlebar
    je .move_hover
    cmp al, 241
    je .nk
    cmp al, 243
    je .nk
    cmp al, 237
    je .nk
    cmp al, 239
    je .nk
    cmp al, 218
    je .nk
    cmp al, 220
    je .trcursor
    cmp al, 219
    je .sz
    cmp al, 246
    je .nk
    cmp al, 247
    je .nk
    cmp al, 229
    jne .n229
    call pa_ckind                       ; над холстом курсор зависит от инструмента
    mov [cu_kind], al
    jmp .nk
.trcursor:
    ; Actual command line, not the terminal border or the history area.
    call tr_mouse_offset
    jnc .nk
    mov byte [cu_kind], 2
    jmp .nk
.move_hover:
    ; four arrows are shown by drag_start only while dragging
    jmp .nk
.n229:
    ; Disks has codes 133/134/135, also used by FloItge objects.
    ; Give Disks' Create/Delete/Close the finger cursor instead.
    cmp byte [d2_dk], 0
    je .n_dkbuttons
    cmp byte [dk_confirm], 0
    jne .n_dkbuttons
    cmp al, 133
    jb .n_dkbuttons
    cmp al, 135
    jbe .dkfinger
.n_dkbuttons:
    cmp al, 133                         ; itge: угол картинки - стрелка размера, картинка - стрелка на 4 стороны
    jb .n133
    cmp al, 135
    ja .n133
    mov bl, 3
    je .i9
    cmp al, 134
    jne .i3
    mov bl, 8
.i3:mov [cu_kind], bl
    jmp .nk
.i9:mov byte [cu_kind], 9
    jmp .nk
.dkfinger:
    mov byte [cu_kind], 1
    jmp .nk
.n133:
    ; Disks size control: 157 numeric field, 158 KB/MB switch.
    ; Only use the cursor override when Disks owns this hit.
    cmp byte [fz_hown], 5
    jne .n_disks_sizes
    cmp byte [d2_dk], 0
    je .n_disks_sizes
    cmp byte [dk_confirm], 0
    jne .n_disks_sizes
    cmp al, 157
    je .disk_size_caret
    cmp al, 158
    je .disk_size_finger
    jmp .n_disks_sizes
.disk_size_caret:
    mov byte [cu_kind], 2
    jmp .nk
.disk_size_finger:
    mov byte [cu_kind], 1
    jmp .nk
.n_disks_sizes:
    cmp al, 130                         ; itge: лист и пусто - стрелка, текст - палочка
    je .nk
    cmp al, 132
    je .nk
    mov byte [cu_kind], 1               ; над кнопкой - палец
    cmp al, 131
    je .ib
    cmp al, 6
    je .ib
    cmp al, 47
    je .ib
    cmp al, 138
    jne .nib
.ib:
    mov byte [cu_kind], 2               ; над текстом - палочка
    jmp .nk
.nib:
    cmp al, 16
    je .sz
    cmp al, 121
    je .sz
    cmp al, 137
    je .sz
    cmp al, 170
    je .sz
    cmp al, 169                         ; FloCalendar black resize square
    je .sz
    cmp al, 242
    je .sz
    cmp al, 238
    je .sz
    cmp al, 254
    je .sz
    cmp al, 79
    jne .nk
.sz:mov byte [cu_kind], 3               ; над чёрным квадратом - стрелка размера
.nk:cmp byte [sb_drag], 0              ; пока тянут ползунок - рука
    je .nk1
    mov byte [cu_kind], 1
.nk1:cmp byte [drag], 6
    jne .nk1b
    mov byte [cu_kind], 3
    jmp .nk2
.nk1b:cmp byte [drag], 1             ; тянут заголовок окна - стрелка на 4 стороны
    jne .nk2
    mov byte [cu_kind], 9
.nk2:
    cmp byte [d2_itge], 0               ; itge: пока тянут картинку или текст - свой курсор
    je .nk3
    cmp byte [it_drag], 1
    jne .nk4
    mov byte [cu_kind], 9
    jmp .nk3
.nk4:cmp byte [it_drag], 3
    jne .nk5
    mov al, [it_cur]
    mov [cu_kind], al
    jmp .nk3
.nk5:cmp byte [it_drag], 4
    jne .nk3
    mov byte [cu_kind], 2
.nk3:
    mov al, [m_btn]
    shr al, 1
    and al, 1
    cmp al, [rb_old]
    je .norb
    mov [rb_old], al
    test al, al
    jz .norb
    cmp byte [sv_who], 0
    jne .norb
    cmp byte [d2_dlg], 2                ; окно Open: правая кнопка - Rename / Delete
    jne .nrd
    call dlg_rclick
    jmp .r
.nrd:
    cmp byte [d2_itge], 0               ; itge: правая кнопка - Copy / Delete / Paste
    je .nri
    cmp byte [d2_dlg], 0
    jne .norb
    call itge_rclick
    jmp .r
.nri:
    cmp byte [d2_files], 0
    je .norb
    cmp byte [d2_text], 0
    jne .norb
    cmp byte [d2_dlg], 0
    jne .norb
    cmp byte [d2_err], 0
    jne .norb
    call files_rclick
    jmp .r
.norb:
    movzx ebx, byte [m_btn]
    and bl, 1
    cmp byte [tr_sel_drag], 0
    je .not_trselect
    test bl, bl
    jz .tr_release
    call tr_mouse_move
    jmp .r
.tr_release:
    mov byte [tr_sel_drag], 0
.not_trselect:
    cmp byte [it_drag], 0
    je .nid
    test bl, bl
    jz .nid
    call itge_move
    jmp .r
.nid:
    cmp byte [pa_drag], 0
    je .npd
    test bl, bl
    jz .npd
    call paint_move
    jmp .r
.npd:
    cmp byte [sb_drag], 0
    je .nsb
    test bl, bl
    jz .nsb
    call sb_set
    jmp .r
.nsb:
    cmp byte [sel_drag], 0
    je .nsd
    test bl, bl
    jz .nsd
    cmp byte [sel_drag], 2
    jne .dsm
    call dlg_sel_move
    jmp .r
.dsm:
    cmp byte [sel_drag], 3
    jne .tsm
    call dk_sel_move
    jmp .r
.tsm:
    call tx_sel_move
    jmp .r
.nsd:
    cmp byte [drag], 0
    je .edge
    test bl, bl
    jz .edge
    call drag_move
    jmp .r
.edge:
    cmp byte [pan_resize], 0
    je .pan_no_drag
    test bl, bl
    jz .pan_end_drag
    call pan_resize_move
    jmp .r
.pan_end_drag:
    mov byte [pan_resize], 0
    mov byte [btn_old], 0
    call st_save
    call redraw
    jmp .r
.pan_no_drag:
    cmp bl, [btn_old]
    je .r
    mov [btn_old], bl
    cmp byte [pw_open], 0
    je .not_pw_event
    test bl, bl
    jz .pw_rel
    mov al, [t_id]
    cmp al, 200
    jne .pw_button_press
    mov byte [pw_down], 0
    mov byte [d_ctx], 12
    mov bl, 1
    call drag_start
    jmp .r
.pw_button_press:
    mov [pw_down], al
    call redraw                      ; show the standard pressed button
    jmp .r
.pw_rel:
    cmp byte [drag], 0
    je .pw_regular_release
    call drag_end
    jmp .r
.pw_regular_release:
    mov al, [pw_down]
    mov byte [pw_down], 0
    test al, al
    jz .r
    cmp al, [t_id]
    je .pw_activate
    call redraw                      ; released outside: restore white buttons
    jmp .r
.pw_activate:
    cmp al, 193                         ; File menu in System window
    je .pw_file
    cmp al, 194                         ; File -> Exit
    je .pw_cancel
    cmp al, 181                         ; Cancel
    je .pw_cancel
    cmp al, 202                         ; X = cancel, never shutdown
    je .pw_cancel
    cmp al, 201                         ; minimize confirmation, preserve state
    jne .pw_not_min
    mov byte [pw_min], 1
    call redraw
    jmp .r
.pw_not_min:
    cmp al, 203                         ; restore minimized confirmation
    jne .pw_not_restore
    mov byte [pw_min], 0
    call redraw
    jmp .r
.pw_not_restore:
    cmp al, 180                         ; OK: confirmed shutdown
    jne .pw_refresh
    call power_off
.pw_refresh:
    call redraw
    jmp .r
.pw_file:
    xor byte [pw_file_menu], 1
    call redraw
    jmp .r
.pw_cancel:
    mov byte [pw_file_menu], 0
    mov byte [pw_open], 0
    mov byte [pw_min], 0
    call redraw
    jmp .r
.not_pw_event:
    test bl, bl
    jz .rel
    ; Shared native title buttons: scope each ID to its live window.
    ; IDs overlap with ordinary controls in other apps (e.g. Terminal 217,
    ; FloFile OK 192 and FloItge palette 172), so NEVER intercept by ID alone.
    mov al, [t_id]
    cmp al, 204
    je .native_sv_check
    cmp al, 205
    je .native_sv_check
    cmp al, 190
    je .native_err_check
    cmp al, 192
    je .native_err_check
    cmp al, 216
    je .native_format_check
    cmp al, 217
    je .native_format_check
    cmp al, 213
    je .native_replace_check
    cmp al, 214
    je .native_replace_check
    cmp al, 207
    je .native_name_check
    cmp al, 208
    je .native_name_check
    cmp al, 210
    je .native_props_check
    cmp al, 211
    je .native_props_check
    cmp al, 240
    je .native_about_check
    cmp al, 245
    je .native_settings_check
    cmp al, 168
    je .native_calendar_check
    cmp al, 159
    je .native_calendar_check
    cmp al, 244
    jne .other_down
    cmp byte [d2_ab], 0
    je .other_down
    mov byte [ab_ok_down], 1
    call redraw
    jmp .r
.native_sv_check:
    cmp byte [sv_who], 0
    jne .native_down
    jmp .other_down
.native_err_check:
    cmp byte [d2_err], 0
    jne .native_down
    jmp .other_down
.native_format_check:
    cmp byte [dk_confirm], 0
    jne .native_down
    jmp .other_down
.native_replace_check:
    cmp byte [d2_conf], 0
    jne .native_down
    jmp .other_down
.native_name_check:
    cmp byte [d2_nm], 0
    jne .native_down
    jmp .other_down
.native_props_check:
    ; d2_pr belongs to FloFile.sys and is not visible to the kernel.
    ; FloFile returns 210/211 for the property-window title buttons.
    ; Scope these IDs to the running FloFile application.
    cmp byte [d2_files], 0
    jne .native_down
    jmp .other_down
.native_about_check:
    cmp byte [fz_hown], 1
    jne .other_down
    cmp byte [d2_ab], 0
    jne .native_down
    jmp .other_down
.native_settings_check:
    cmp byte [fz_hown], 2
    jne .other_down
    cmp byte [d2_st], 0
    jne .native_down
    jmp .other_down
.native_calendar_check:
    cmp byte [fz_hown], 8
    jne .other_down
    cmp byte [d2_cal], 0
    je .other_down
    mov edx, [m_x]
    sub edx, [cal_x]
    js .other_down
    cmp edx, [cal_x + 8]
    ja .other_down
    mov edx, [m_y]
    sub edx, [cal_x + 4]
    js .other_down
    cmp edx, [cal_x + 12]
    ja .other_down
    jmp .native_down
.native_down:
    mov [title_down], al
    mov dl, [fz_hown]
    test dl, dl
    jz .native_redraw
    call fz_top
.native_redraw:
    call redraw
    jmp .r
.other_down:
    cmp byte [mn_ov], 0
    jne .mnp
    jmp .nmp
.mnp:
    cmp byte [mn_ov], 0x84
    jne .pan_regular_press
    mov byte [pan_resize], 1
    jmp .r
.pan_regular_press:
    mov al, [mn_ov]
    mov [mn_pr], al
    call redraw
    jmp .r
.nmp:
    cmp byte [d2_egg], 0                ; пасхалка: любой клик - назад
    je .neg
    call egg_close
    jmp .r
.neg:
    cmp byte [sv_who], 0
    je .nsv1
    mov al, [t_id]
    cmp al, 193                          ; File button
    je .sv_file
    cmp al, 194                          ; File -> Exit
    je .sv_file_exit
    cmp al, 204
    jne .sv_not_min
    mov byte [sv_min], 1
    call redraw
    jmp .r
.sv_file:
    xor byte [sv_file_menu], 1
    call redraw
    jmp .r
.sv_file_exit:
    call sv_cancel
    jmp .r
.sv_not_min:
    cmp al, 205
    jne .sv_not_close
    call sv_cancel
    jmp .r
.sv_not_close:
    cmp al, 206
    jne .sv_not_restore
    mov byte [sv_min], 0
    call redraw
    jmp .r
.sv_not_restore:
    cmp al, 199
    jne .sv_button_click
    mov byte [d_ctx], 10
    mov bl, 1
    call drag_start
    jmp .r
.sv_button_click:
    call sv_btn_hit
    test al, al
    jz .r
    mov [sv_btn_down], al
    call redraw
    jmp .r
.nsv1:
    cmp byte [d2_wl], 0
    je .nwl1
    mov al, [t_id]
    call wl_press
    jmp .r
.nwl1:
    mov al, [t_id]                      ; нажали
    cmp al, 191                        ; restore minimized Error window
    jne .not_restore_error
    ; FloFile also uses hit ID 191 for New Notepad. Do not steal
    ; that click unless an Error window is actually minimized.
    cmp byte [err_min_code], 0
    je .not_restore_error
    ; Only the minimized Error badge owns ID 191 in this screen area.
    ; A FloFile Notepad context-menu item may use the same ID elsewhere.
    cmp dword [m_x], 486
    jb .not_restore_error
    cmp dword [m_x], 618
    ja .not_restore_error
    cmp dword [m_y], 508
    jb .not_restore_error
    cmp dword [m_y], 544
    ja .not_restore_error
    mov al, [err_min_code]
    mov byte [err_min_code], 0
    mov [d2_err], al
    call redraw
    jmp .r
.not_restore_error:
.nmzp:
    cmp byte [d2_err], 0
    je .ne1
    cmp al, 64                          ; диспетчер задач работает и при ошибке
    jb .er1
    cmp al, 69
    jbe .er2
    cmp al, 120
    jb .er1
    cmp al, 123
    ja .er1
.er2:
    call tm_press
    jmp .r
.er1:
    cmp al, 193
    je .err_file
    cmp al, 194
    je .err_file_exit
    cmp al, 198
    jne .err_buttons
    mov byte [d_ctx], 11
    mov bl, 1
    call drag_start
    jmp .r
.err_file:
    xor byte [err_file_menu], 1
    call redraw
    jmp .r
.err_file_exit:
    mov byte [err_file_menu], 0
    mov byte [d2_err], 0
    call redraw
    jmp .r
.err_buttons:
    cmp al, 63                         ; Error OK: animate on press, act on release
    jne .err_other_buttons
    mov dl, 7
    call ui_button_capture
    call redraw
    jmp .r
.err_other_buttons:
    cmp al, 190
    je .minerr
    cmp al, 63
    jne .r
    mov byte [err_file_menu], 0
    mov byte [d2_err], 0
    call redraw
    jmp .r
.minerr:
    mov byte [err_file_menu], 0
    mov al, [d2_err]
    mov [err_min_code], al
    mov byte [d2_err], 0
    call redraw
    jmp .r
.ne1:
    ; Dispatch by actual topmost WINDOW, not ambiguous shared hit IDs.
    ; A click on a blank title/body also raises that window.
    mov dl, [fz_hown]
    test dl, dl
    jz .z_legacy
    push eax                             ; redraw called on raise must not replace hit ID
    call fz_front
    pop eax
    mov dl, [fz_hown]
    cmp dl, 1
    je .z_ab
    cmp dl, 2
    je .z_st
    cmp dl, 3
    je .z_ck
    cmp dl, 4
    je .z_tr
    cmp dl, 5
    je .z_dk
    cmp dl, 6
    je .z_main
    cmp dl, 7
    je .z_calc
    cmp dl, 8
    je .z_cal
    cmp dl, 9
    je .z_tm
    jmp .r
.z_ab:call ab_press
    jmp .r
.z_st:call st_press
    jmp .r
.z_ck:call ck_press
    jmp .r
.z_tr:mov byte [tr_foc], 1
    call tr_press
    jmp .r
.z_dk:
    cmp byte [dk_confirm], 0
    je .dk_regular
    ; Click the exposed Disks parent to raise it above Format?.
    ; While confirmation exists, underlying actions remain locked.
    cmp byte [dk_conf_top], 0
    je .dk_child_behind
    call dk_conf_screen_hit
    jc .dk_modal_down
    mov byte [dk_conf_top], 0
    call redraw
    jmp .r
.dk_child_behind:
    push eax                            ; child hit-testing changes AL
    call dk_conf_back_badge_hit
    jc .dk_raise_child
    call dk_conf_screen_hit
    jc .dk_raise_child
    pop eax
    jmp .dk_parent_drag
.dk_raise_child:
    pop eax
    mov byte [dk_conf_top], 1
    call redraw
    jmp .r
.dk_parent_drag:
    cmp al, 136
    jne .r
    mov byte [d_ctx], 4
    mov bl, 1
    call drag_start
    jmp .r
.dk_regular:
    cmp al, 133                        ; Create
    je .dk_regular_down
    cmp al, 134                        ; Delete
    je .dk_regular_down
    cmp al, 135                        ; Close
    je .dk_regular_down
    cmp al, 152                        ; Format
    je .dk_regular_down
    cmp al, 158                        ; KB/MB unit toggle
    jne .dk_direct_down
.dk_regular_down:
    mov dl, 1
    call ui_button_capture
    call redraw
    jmp .r
.dk_modal_down:
    cmp al, 153                        ; Cancel
    je .dk_modal_button
    cmp al, 154                        ; Format (destructive, on release only)
    jne .dk_direct_down
.dk_modal_button:
    mov dl, 2
    call ui_button_capture
    call redraw
    jmp .r
.dk_direct_down:
    call dk_press
    jmp .r
.z_main:jmp .nc2
.z_calc:mov byte [calc_foc], 1
    jmp .cp
.z_cal:call cal_press
    jmp .r
.z_tm:
    cmp al, 65
    jne .tm_direct_down
    mov dl, 4
    mov ah, [tm_hr]
    mov [ui_btn_row], ah
    call ui_button_capture
    call redraw
    jmp .r
.tm_direct_down:
    call tm_press
    jmp .r
.z_legacy:
    ; When a fullscreen application is active and no floating window
    ; actually owns the hit, do not route raw IDs to covered windows.
    ; Their IDs can overlap app controls (Terminal, Calendar, etc.).
    push eax
    call mn_prog
    pop eax
    jnz .ntm1
    ; FloItge palette cells have IDs 171..174. The calendar uses
    ; 172..179, so its early dispatch used to steal Blue/Gray/White
    ; clicks from the FloItge palette (hit=AC, press never called).
    ; FloItge is a fullscreen application and its hit-test takes
    ; precedence whenever it is open. Keep calendar ID routing for
    ; all other situations.
    cmp byte [d2_itge], 0
    je .cal_hit
    cmp al, 171
    jb .cal_hit
    cmp al, 174
    ja .cal_hit
    mov dl, [shift]
    mov [it_shift], dl
    call itge_press
    jmp .r
.cal_hit:
    cmp al, 159                         ; FloCalendar X (distinct from FloItge palette)
    je .cal_specific
    cmp al, 166                         ; restore minimized FloCalendar
    je .cal_specific
    cmp al, 168                         ; native title minus
    je .cal_specific
    cmp al, 169                         ; FloCalendar resize corner (no other hit uses 169)
    jne .cal_existing
.cal_specific:
    cmp byte [d2_cal], 0
    je .ncal1
    call cal_press
    jmp .r
.cal_existing:
    cmp al, 172                         ; календарь
    jb .ncal1
    cmp al, 179
    ja .ncal1
    call cal_press
    jmp .r
.ncal1:
    cmp al, 217
    jb .ntr1
    cmp al, 222
    ja .ntr1
    mov dl, 4
    call fz_front
    call tr_press
    jmp .r
.ntr1:
    mov byte [tr_foc], 0
    cmp al, 227                         ; About: File и Exit
    je .abp
    cmp al, 228
    je .abp
    cmp al, 124                         ; Settings: Region (язык, раскладка, пояс)
    je .stp
    cmp al, 125
    je .stp
    cmp al, 139
    je .stp
    cmp al, 141
    je .stp
    cmp al, 158                         ; Settings: File и Exit
    je .stp
    cmp al, 167
    je .stp
    cmp al, 223
    je .ckp
    cmp al, 224
    je .ckp
    cmp al, 236
    jb .nck1
    cmp al, 239
    ja .nck1
.ckp:
    mov dl, 3
    call fz_front
    call ck_press
    jmp .r
.nck1:
    cmp al, 245
    jb .nst1
    cmp al, 255
    ja .nst1
.stp:
    mov dl, 2
    call fz_front
    call st_press
    jmp .r
.nst1:
    cmp al, 240
    jb .nab1
    cmp al, 244
    ja .nab1
.abp:
    mov dl, 1
    call fz_front
    call ab_press
    jmp .r
.nab1:
    cmp byte [fz_hown], 5
    jne .ndk1
    cmp byte [d2_dk], 0
    je .ndk1
    cmp al, 128                         ; нажали на окно Disks - оно наверх
    jb .dkp
    cmp al, 149
    ja .dkp
    mov dl, 5
    call fz_front
.dkp:
    call dk_press
    jmp .r
.ndk1:
    cmp al, 64
    jb .ntm1
    cmp al, 69
    jbe .tmp
    cmp al, 120
    jb .ntm1
    cmp al, 123
    ja .ntm1
.tmp:
    call tm_press
    jmp .r
.ntm1:
    cmp byte [d2_dlg], 0
    je .nd1
    cmp al, 53                         ; Save / Open
    je .dlg_regular_down
    cmp al, 54                         ; Cancel
    je .dlg_regular_down
    cmp al, 60                         ; Replace? Yes
    je .dlg_modal_down
    cmp al, 61                         ; Replace? No
    jne .dlg_direct_down
.dlg_modal_down:
    mov dl, 6
    jmp .dlg_latch
.dlg_regular_down:
    mov dl, 3
.dlg_latch:
    call ui_button_capture
    call redraw
    jmp .r
.dlg_direct_down:
    call dlg_press
    jmp .r
.nd1:
    call hp_press
    jc .r
    cmp byte [d2_boil], 0
    je .nbo1
    call boil_press
    jmp .r
.nbo1:
    cmp byte [d2_itge], 0
    je .nit1
    mov dl, [shift]
    mov [it_shift], dl
    call itge_press
    jmp .r
.nit1:
    cmp byte [d2_paint], 0
    je .np1
    mov byte [calc_foc], 0
    call paint_press
    jmp .r
.np1:
    cmp byte [t_own], 0                 ; нажали на калькулятор поверх FloText или FloFile
    je .nd1b
    mov byte [calc_foc], 1
    jmp .cp
.nd1b:
    mov byte [calc_foc], 0
    cmp byte [d2_text], 0
    je .nt2
    jmp .tp
.nt2:
    cmp byte [d2_files], 0
    je .nf2
    cmp byte [d2_nm], 0
    je .file_direct_down
    cmp al, 192                        ; Name: OK
    je .file_name_down
    cmp al, 193                        ; Name: Cancel
    jne .file_direct_down
.file_name_down:
    mov dl, 5
    call ui_button_capture
    call redraw
    jmp .r
.file_direct_down:
    call files_press
    jmp .r
.nf2:
    cmp byte [d2_calc], 0
    je .nc2
    jmp .cp
.nc2:
    cmp al, 25
    jne .ns25
    mov byte [pressed], 4
    call power_button_draw
    jmp .r
.ns25:
    cmp al, 21
    jne .ns21
    mov byte [pressed], 3
    call draw_settings_btn
    jmp .r
.ns21:
    cmp al, 20
    jne .nab2
    mov byte [pressed], 2
    call draw_about_btn
    jmp .r
.nab2:
    cmp al, 1
    jne .o2
    mov byte [pressed], 1
    call draw_button
    jmp .r
.o2:cmp al, 8
    jne .o3
    mov bl, 1
    call drag_start
    jmp .r
.o3:cmp al, 16
    jne .o4
    mov bl, 6
    call drag_start
    jmp .r
.o4:cmp al, 17
    je .sb
    cmp al, 18
    jne .o5
.sb:mov [sb_drag], al
    call sb_grab
    cmp byte [sb_drag], 0
    je .r
    call sb_set
    jmp .r
.o5:cmp al, 2
    je .an
    cmp al, 13
    je .an
    cmp al, 14
    je .an
    cmp al, 19
    je .an
    cmp al, 22
    je .an
    cmp al, 23
    je .an
    cmp al, 24
    je .an
    cmp al, 9
    je .an
    cmp al, 15
    jne .r
.an:mov [ap_id], al
    mov edi, 1
    call anim
    jmp .r
.tp:                                    ; нажали мышь в Text
    cmp al, 4
    jne .t1
    xor byte [t_menu], 1
    call text_draw
    jmp .r
.t1:cmp al, 5
    jne .t2
    call text_exit
    jmp .r
.t2:cmp al, 6
    jne .t2b
    call tx_click
    jmp .r
.t2b:cmp al, 98
    jne .t3
    mov byte [sb_drag], 17
    mov byte [sb_ctx], 2
    call sb_grab
    cmp byte [sb_drag], 0
    je .r
    call sb_set
    jmp .r
.t3:cmp al, 10
    jb .t4
    cmp al, 12
    ja .t4
    mov byte [t_menu], 0
    call text_draw
    cmp al, 10
    jne .t3b
    call text_save
    jmp .r
.t3b:
    cmp al, 11
    jne .t3c
    mov al, 1
    call dlg_open
    jmp .r
.t3c:
    mov al, 2
    call dlg_open
    jmp .r
.t4:cmp byte [t_menu], 0
    je .r
    mov byte [t_menu], 0
    call text_draw
    jmp .r
.cp:                                    ; нажали мышь, пока открыт калькулятор
    cmp al, 72
    jne .c1
    xor byte [calc_menu], 1
    call calc_draw
    jmp .r
.c1:cmp byte [calc_menu], 0
    je .c2
    cmp al, 73
    je .c2
    mov byte [calc_menu], 0             ; нажали мимо меню - оно закрывается
    call calc_draw
    cmp al, 74
    jb .r
.c2:cmp al, 74
    jne .c3
    mov bl, 1
    mov byte [d_ctx], 1
    call drag_start
    jmp .r
.c3:cmp al, 79
    jne .c4
    mov bl, 6
    mov byte [d_ctx], 1
    call drag_start
    jmp .r
.c4:cmp al, 77
    je .c5
    cmp al, 78
    jne .c6
.c5:sub al, 60                          ; 17 / 18 как у main
    mov [sb_drag], al
    mov byte [sb_ctx], 1
    call sb_grab
    cmp byte [sb_drag], 0
    je .r
    call sb_set
    jmp .r
.c6:cmp al, 71
    je .c7
    cmp al, 73
    je .c7
    cmp al, 100
    jb .r
    call calc_press
    jmp .r
.c7:mov [ap_id], al
    mov edi, 1
    call anim
    jmp .r
.rel:
    cmp byte [sv_btn_down], 0
    je .ui_button_release
    call sv_btn_hit
    cmp al, [sv_btn_down]
    jne .sv_button_cancel
    mov byte [sv_btn_down], 0
    push eax
    call redraw
    pop eax
    cmp al, 1
    je .sv_release_cancel
    cmp al, 2
    je .sv_release_yes
    cmp al, 3
    je .sv_release_no
    jmp .r
.sv_release_cancel:
    call sv_cancel
    jmp .r
.sv_release_yes:
    call sv_yes
    jmp .r
.sv_release_no:
    call sv_no
    jmp .r
.sv_button_cancel:
    mov byte [sv_btn_down], 0
    call redraw
    jmp .r
.ui_button_release:
    cmp byte [ui_btn_id], 0
    je .check_title_release
    mov al, [ui_btn_id]
    mov dl, [ui_btn_owner]
    mov byte [ui_btn_id], 0
    mov byte [ui_btn_owner], 0
    cmp al, [t_id]
    jne .ui_button_cancel
    cmp dl, 1
    jne .ui_not_disks
    cmp byte [dk_confirm], 0
    jne .ui_button_cancel
    cmp byte [d2_dk], 0
    je .ui_button_cancel
    cmp byte [fz_hown], 5
    jne .ui_button_cancel
    jmp .ui_button_activate
.ui_not_disks:
    cmp dl, 2
    jne .ui_not_format
    cmp byte [dk_confirm], 0
    je .ui_button_cancel
    cmp byte [fz_hown], 5
    jne .ui_button_cancel
    jmp .ui_button_activate
.ui_not_format:
    cmp dl, 3
    jne .ui_not_dlg
    cmp byte [d2_dlg], 0
    je .ui_button_cancel
    cmp byte [d2_conf], 0
    jne .ui_button_cancel
    jmp .ui_button_activate
.ui_not_dlg:
    cmp dl, 4
    jne .ui_not_tasks
    cmp byte [d2_tm], 0
    je .ui_button_cancel
    cmp byte [fz_hown], 9
    jne .ui_button_cancel
    mov ah, [ui_btn_row]
    cmp ah, [tm_hr]
    jne .ui_button_cancel
    jmp .ui_button_activate
.ui_not_tasks:
    cmp dl, 5
    jne .ui_not_name
    cmp byte [d2_nm], 0
    je .ui_button_cancel
    jmp .ui_button_activate
.ui_not_name:
    cmp dl, 7
    jne .ui_not_error
    cmp byte [d2_err], 0
    je .ui_button_cancel
    jmp .ui_button_activate
.ui_not_error:
    cmp dl, 6
    jne .ui_button_cancel
    cmp byte [d2_conf], 0
    je .ui_button_cancel
.ui_button_activate:
    push eax
    push edx
    call redraw
    pop edx
    pop eax
    cmp dl, 1
    je .ui_disks_action
    cmp dl, 2
    je .ui_disks_action
    cmp dl, 3
    je .ui_dlg_action
    cmp dl, 6
    je .ui_dlg_action
    cmp dl, 4
    je .ui_tasks_action
    cmp dl, 5
    je .ui_files_action
    cmp dl, 7
    je .ui_error_action
    jmp .r
.ui_disks_action:
    call dk_press
    jmp .r
.ui_dlg_action:
    call dlg_press
    jmp .r
.ui_tasks_action:
    call tm_press
    jmp .r
.ui_files_action:
    call files_press
    jmp .r
.ui_error_action:
    mov byte [err_file_menu], 0
    mov byte [d2_err], 0
    call redraw
    jmp .r
.ui_button_cancel:
    call redraw
    jmp .r
.check_title_release:
    cmp byte [title_down], 0
    je .ordinary_release
    mov al, [title_down]
    mov byte [title_down], 0
    cmp al, [t_id]
    jne .native_cancel
    cmp al, 204
    je .native_sv_min
    cmp al, 205
    je .native_sv_close
    cmp al, 190
    je .native_err_min
    cmp al, 192
    je .native_err_close
    cmp al, 216
    je .native_dk
    cmp al, 217
    je .native_dk
    cmp al, 213
    je .native_dlg
    cmp al, 214
    je .native_dlg
    cmp al, 207
    je .native_nm
    cmp al, 208
    je .native_nm
    cmp al, 210
    je .native_pr
    cmp al, 211
    je .native_pr
    cmp al, 240
    je .native_ab
    cmp al, 245
    je .native_st
    cmp al, 168
    je .native_cal
    cmp al, 159
    je .native_cal
    jmp .native_cancel
.native_sv_min:
    mov byte [sv_min], 1
    jmp .native_cancel
.native_sv_close:
    call sv_cancel
    jmp .r
.native_err_min:
    mov byte [err_file_menu], 0
    mov al, [d2_err]
    mov [err_min_code], al
    mov byte [d2_err], 0
    jmp .native_cancel
.native_err_close:
    mov byte [err_file_menu], 0
    mov byte [d2_err], 0
    jmp .native_cancel
.native_dk:
    call dk_confirm_press
    jmp .r
.native_dlg:
    call dlg_press
    jmp .r
.native_nm:
    ; FloFile.sys exports files_press, not the module-private nm_press.
    call files_press
    jmp .r
.native_pr:
    ; FloFile.sys exports files_press, not the module-private pr_press.
    call files_press
    jmp .r
.native_ab:
    call ab_press
    jmp .r
.native_st:
    call st_press
    jmp .r
.native_cal:
    call cal_press
    jmp .r
.native_cancel:
    call redraw
    jmp .r
.ordinary_release:
    cmp byte [ab_ok_down], 0
    je .no_ab_ok_release
    mov byte [ab_ok_down], 0
    cmp byte [t_id], 244
    jne .ab_ok_cancel
    mov al, 244
    call ab_press
    jmp .r
.ab_ok_cancel:
    call redraw
    jmp .r
.no_ab_ok_release:
    cmp byte [mn_pr], 0
    je .nmr
    call mn_release
    jmp .r
.nmr:
    cmp byte [d2_wl], 0
    je .nwr
    call wl_release
    jmp .r
.nwr:
    cmp byte [d2_boil], 0
    je .nbr
    call boil_release
.nbr:
    cmp byte [d2_itge], 0
    je .nir
    call itge_release
.nir:
    call paint_release
    mov byte [sb_drag], 0
    mov byte [sb_ctx], 0
    mov byte [sel_drag], 0
    cmp byte [drag], 0
    je .nd
    call drag_end
    jmp .r
.nd:cmp byte [calc_pr], 0xFF
    je .nd2
    call calc_release
    jmp .r
.nd2:cmp byte [ap_id], 0
    je .np
    movzx eax, byte [ap_id]             ; кнопка поднимается; если мышь всё ещё на ней - нажатие засчитано
    mov byte [ap_id], 0
    push eax
    xor edi, edi
    call anim
    pop eax
    cmp al, [t_id]
    jne .r
    call click
    jmp .r
.np:cmp byte [pressed], 0
    je .r
    cmp byte [pressed], 4
    jne .not_pw_button
    mov byte [pressed], 0
    call power_button_draw
    cmp byte [t_id], 25
    jne .r
    mov byte [pw_open], 1
    mov byte [pw_file_menu], 0
    mov byte [pw_min], 0
    call redraw                    ; return through mouse_event to restore pushad
    jmp .r
.not_pw_button:
    cmp byte [pressed], 2
    jne .rb2
    mov byte [pressed], 0
    call draw_about_btn
    cmp byte [t_id], 20
    jne .r
    call ab_open
    jmp .r
.rb2:
    cmp byte [pressed], 3
    jne .rb1
    mov byte [pressed], 0
    call draw_settings_btn
    cmp byte [t_id], 21
    jne .r
    call st_open
    jmp .r
.rb1:
    mov byte [pressed], 0
    call draw_button
    cmp byte [t_id], 1
    jne .r
    cmp byte [d2_main], 0               ; Floppy: restore Main if behind another window
    je .op
    cmp byte [fz_ord + 8], 6
    je .close_main
    mov dl, 6
    call fz_front
    jmp .r
.close_main:
    mov byte [d2_main], 0
    call redraw
    jmp .r
.op:mov byte [d2_main], 1
    mov dl, 6
    call fz_top
    call redraw
.r: popad
    ret

; Нажатие на кнопку al засчитано
click:
    cmp al, 13
    jne .n13
    cmp byte [mv_view], 1
    je files_open
    cmp byte [mv_view], 0
    je files_open_sys
    ret
.n13:
    cmp al, 71
    je calc_exit
    cmp al, 73
    je calc_exit
    cmp al, 14
    jne .n14
    cmp byte [mv_view], 1
    je calc_open
    cmp byte [mv_view], 0
    jne .n14
    mov byte [mv_view], 2               ; games: список игр внутри main
    mov dword [msx], 0
    mov dword [msy], 0
    jmp redraw
.n14:
    cmp al, 19
    jne .n19
    cmp byte [mv_view], 1
    je paint_open
.n19:
    cmp al, 22
    jne .n22
    cmp byte [mv_view], 1
    je ck_open
.n22:
    cmp al, 23
    jne .n23
    cmp byte [mv_view], 1
    je itge_open
.n23:
    cmp al, 24
    jne .n24
    cmp byte [mv_view], 1
    je cal_open
.n24:
    cmp al, 9
    jne .a
    mov byte [d2_main], 0               ; крестик: main закрывается
    jmp redraw
.a: cmp al, 15
    jne .b
    mov byte [mv_view], 0
    mov dword [msx], 0
    mov dword [msy], 0
    jmp redraw
.b: cmp al, 2
    jne .r
    cmp byte [mv_view], 0
    je .v0
    cmp byte [mv_view], 1
    je text_open
    cmp byte [mv_view], 2
    je boil_open
    ret
.v0:
    mov byte [mv_view], 1               ; папка programs
    cmp dword [mw], 520                 ; три кнопки в ряд: окно пошире
    jae .wok
    mov dword [mw], 520
.wok:
    mov eax, [mx0]
    add eax, [mw]
    cmp eax, 790
    jbe .wfit
    mov eax, 790
    sub eax, [mw]
    mov [mx0], eax
.wfit:
    mov dword [msx], 0
    mov dword [msy], 0
    jmp redraw
.r: ret

; Нарисовать кнопку al: edi = 1 нажата, 0 обычная
anim:
    pushad
    cmp al, 73
    je .r
    cmp al, 71
    jne .n71
    mov eax, [calc_x0]
    add eax, [calc_w]
    sub eax, 32
    mov ebx, [calc_y0]
    add ebx, 8
    call xbtn
    jmp .r
.n71:
    cmp al, 9
    je .mx
    cmp al, 15
    je .lb
    xor ebx, ebx
    cmp al, 2
    je .k
    inc ebx
    cmp al, 13
    je .k
    inc ebx
    cmp al, 14
    je .k
    inc ebx
    cmp al, 19
    je .k
    inc ebx
    cmp al, 22
    je .k
    inc ebx
    cmp al, 23
    je .k
    inc ebx
.k: call mclip_on
    call mitem
    call mclip_off
    jmp .r
.mx:mov eax, [mx0]
    add eax, [mw]
    sub eax, 32
    mov ebx, [my0]
    add ebx, 8
    call xbtn
    jmp .r
.lb:mov eax, [mx0]
    add eax, 8
    mov ebx, [my0]
    add ebx, 8
    call lbtn
.r: popad
    ret

; курсор мыши (обычно 17 строк; изменение высоты панели: 19 строк исходного PNG)
CU_H    equ 34
CU_B    equ 5                           ; сколько байт в ширину берёт курсор

cursor_hide:
    cmp byte [cu_on], 0
    je .r
    call cursor_restore
    mov byte [cu_on], 0
.r: ret
cursor_show:
    cmp byte [d2_ist], 0                ; в окне установки мышки нет
    jne .already
    cmp byte [cu_on], 0                 ; курсор уже нарисован: второй раз не рисуем, иначе остаётся копия
    jne .already
    cmp byte [cu_kind], 7
    jne .nk7
    call pa_eraser_cur
.nk7:
    mov ecx, [cu_scale]                 ; во сколько точек рисуется пиксель курсора (квадрат ластика всегда 2)
    cmp byte [cu_kind], 7
    jne .sc
    mov ecx, 2
.sc:mov [cu_s], ecx
    imul edx, ecx, 17
    cmp byte [cu_kind], 11              ; только курсор изменения высоты панели: 19 строк PNG
    jne .height_ready
    imul edx, ecx, 19
.height_ready:
    mov [cu_h], edx
    lea edx, [ecx * 2 + 1]
    mov [cu_b], edx
    movzx eax, byte [cu_kind]           ; какой рисунок и где горячая точка
    imul eax, 24
    add eax, cu_info
    mov edx, [eax]
    mov [cu_ptr], edx
    mov edx, [eax + 4]
    imul edx, ecx
    sar edx, 1
    add edx, [m_x]
    jge .x0
    xor edx, edx
.x0:mov [cu_x], edx
    mov edx, [eax + 8]
    imul edx, ecx
    sar edx, 1
    add edx, [m_y]
    jge .y0
    xor edx, edx
.y0:mov [cu_y], edx
    call cursor_save
    call cursor_paint
    mov byte [cu_on], 1
.already:
    ret

; Адрес первого байта строки esi курсора в видеопамяти: eax; CF = строки нет на экране
cu_row:
    mov eax, [cu_y]
    add eax, esi
    cmp eax, 600
    jae .no
    imul eax, 100
    add eax, VGA
    mov ecx, [cu_x]
    shr ecx, 3
    add eax, ecx
    clc
    ret
.no:stc
    ret

; Фон под курсором хранится в видеопамяти за экраном (после 60000-го байта каждой плоскости).
; Копирование через защёлки (режим записи 1): все четыре плоскости меняются одной записью,
; поэтому при стирании и рисовании курсора не мелькают промежуточные цвета
CU_OFF  equ VGA + 60000

cursor_save:
    pushad
    mov dx, 0x3CE
    mov ax, 0x0105                      ; режим записи 1: пишутся защёлки
    out dx, ax
    mov dx, 0x3C4
    mov ax, 0x0F02
    out dx, ax
    xor esi, esi
.row:
    call cu_row
    jc .next
    mov ebx, eax                        ; строка на экране
    mov eax, esi
    imul eax, [cu_b]
    add eax, CU_OFF
    mov edi, eax                        ; та же строка за экраном
    xor ecx, ecx
.b: mov eax, [cu_x]
    shr eax, 3
    add eax, ecx
    cmp eax, 100
    jae .nb
    mov al, [ebx + ecx]
    mov [edi + ecx], al
.nb:inc ecx
    cmp ecx, [cu_b]
    jb .b
.next:
    inc esi
    cmp esi, [cu_h]
    jb .row
    popad
    ret

cursor_restore:
    pushad
    mov dx, 0x3CE
    mov ax, 0x0105
    out dx, ax
    mov dx, 0x3C4
    mov ax, 0x0F02
    out dx, ax
    xor esi, esi
.row:
    call cu_row
    jc .next
    mov ebx, eax
    mov eax, esi
    imul eax, [cu_b]
    add eax, CU_OFF
    mov edi, eax
    xor ecx, ecx
.b: mov eax, [cu_x]
    shr eax, 3
    add eax, ecx
    cmp eax, 100
    jae .nb
    mov al, [edi + ecx]
    mov [ebx + ecx], al
.nb:inc ecx
    cmp ecx, [cu_b]
    jb .b
.next:
    inc esi
    cmp esi, [cu_h]
    jb .row
    popad
    ret

; Долгая работа (диск, запуск окна): курсор превращается в будильник. Звать, когда курсор спрятан (внутри mouse_event / keys)
; Вызовы можно вкладывать: будильник уйдёт, когда закончится самый внешний
WAIT_MIN    equ 5                       ; будильник виден не меньше 5 тиков (около 1/4 секунды)
WAIT_BOOT   equ 18                      ; при запуске системы - около секунды

wait_start:
    inc byte [cu_busy]
    cmp byte [cu_busy], 1
    jne .r
    pushad
    mov al, [cu_kind]
    mov [cu_kind_old], al
    mov byte [cu_kind], 4
    mov eax, [ticks]
    mov [wait_t0], eax
    mov dword [wait_min], WAIT_MIN
    mov eax, [m_x]
    mov [cp_x], eax
    mov eax, [m_y]
    mov [cp_y], eax
    call cursor_hide
    call cursor_show
    popad
.r: ret

; Пока идёт долгая работа (курсор - будильник), мышь всё равно двигается: звать из циклов ожидания диска
cu_pump:
    cmp byte [cu_busy], 0
    je .r
    push eax
    mov eax, [m_x]
    cmp eax, [cp_x]
    jne .mv
    mov eax, [m_y]
    cmp eax, [cp_y]
    je .e
.mv:pushad
    mov eax, [m_x]
    mov [cp_x], eax
    mov eax, [m_y]
    mov [cp_y], eax
    call cursor_hide
    call cursor_show
    popad
.e: pop eax
.r: ret

cp_x    dd 0
cp_y    dd 0

wait_end:
    cmp byte [cu_busy], 0
    je .r
    dec byte [cu_busy]
    jnz .r
    pushad
.w: mov eax, [ticks]
    sub eax, [wait_t0]
    cmp eax, [wait_min]
    jae .d
    hlt
    call cu_pump
    jmp .w
.d: mov al, [cu_kind_old]
    mov [cu_kind], al
    call cursor_hide                    ; вернуть то, что было под будильником
    popad
.r: ret

; Нарисовать курсор: маски всех строк считаются заранее в памяти, потом три прохода (середина - цвет 5, чёрное - 0,
; тень - 8). Режим записи 3: цвет точки берётся из регистра set/reset, а маска - из самого записанного байта,
; поэтому все плоскости меняются сразу и порт на каждый байт не нужен
cursor_paint:
    pushad
    xor esi, esi
.pre:
    mov eax, esi                        ; строка рисунка = строка точек / масштаб
    xor edx, edx
    div dword [cu_s]
    mov ebx, [cu_ptr]
    lea ebx, [ebx + eax * 4]            ; в рисунке подряд по 17 словам (или 19 для панели): k, w, s
    mov ebp, esi
    imul ebp, 27
    add ebp, cu_msk
    mov eax, [ebx]
    mov [cu_dst], ebp
    call cu_expand
    mov edx, 68                         ; маски других курсоров: 17 строк по 4 байта
    cmp byte [cu_kind], 11
    jne .mask_offset_ready
    mov edx, 76                         ; точный PNG панели: 19 строк по 4 байта
.mask_offset_ready:
    mov eax, [ebx + edx]
    add ebp, 9
    mov [cu_dst], ebp
    call cu_expand
    mov edx, 136                        ; начало третьей маски обычного курсора
    cmp byte [cu_kind], 11
    jne .shadow_offset_ready
    mov edx, 152                        ; начало третьей маски PNG 16x19
.shadow_offset_ready:
    mov eax, [ebx + edx]
    add ebp, 9
    mov [cu_dst], ebp
    call cu_expand
    inc esi
    cmp esi, [cu_h]
    jb .pre
    mov dx, 0x3C4
    mov ax, 0x0F02
    out dx, ax
    mov dx, 0x3CE
    mov ax, 0x0305                      ; режим записи 3
    out dx, ax
    mov ax, 0x0003                      ; без логики
    out dx, ax
    mov ax, 0xFF08
    out dx, ax
    mov dword [cp_pl], 0                ; номер прохода 0..2
.pass:
    mov ecx, [cp_pl]
    movzx eax, byte [cp_col + ecx]
    mov ah, al
    mov al, 0                           ; set/reset: цвет прохода
    mov dx, 0x3CE
    out dx, ax
    xor esi, esi
.row:
    call cu_row
    jc .next
    mov edi, eax                        ; строка на экране
    mov eax, esi
    imul eax, 27
    add eax, cu_msk
    mov ecx, [cp_pl]
    movzx edx, byte [cp_off + ecx]
    add eax, edx
    mov ebx, eax                        ; маска этой строки для этого прохода
    xor ecx, ecx
.b: mov eax, [cu_x]
    shr eax, 3
    add eax, ecx
    cmp eax, 100
    jae .nb
    movzx edx, byte [ebx + ecx]
    test edx, edx
    jz .nb
    mov al, [edi + ecx]                 ; защёлки: что было на экране
    mov [edi + ecx], dl                 ; маска: где поставить цвет
.nb:inc ecx
    cmp ecx, [cu_b]
    jb .b
.next:
    inc esi
    cmp esi, [cu_h]
    jb .row
    inc dword [cp_pl]
    cmp dword [cp_pl], 3
    jb .pass
    popad
    ret

cp_col  db 5, 0, 8                      ; середина, чёрное, тень
cp_off  db 9, 0, 18                     ; где их маски в cu_msk

; Строка рисунка eax (16 пикселей по 2 бита) -> растянуть в cu_s раз и сдвинуть на cu_x mod 8 вправо: cu_q[0..8]
cu_expand:
    push ebx
    push ecx
    push edx
    push edi
    mov dword [cu_v], 0
    mov dword [cu_v + 4], 0
    mov dword [cu_v + 8], 0
    xor ebx, ebx                        ; номер пикселя
.j: mov ecx, 31
    sub ecx, ebx
    sub ecx, ebx
    mov edx, eax
    shr edx, cl
    test dl, 1
    jz .nj
    mov edi, ebx
    imul edi, [cu_s]                    ; номер первого бита
    mov ecx, [cu_s]
.k: push ecx
    mov ecx, edi
    and ecx, 7
    mov dl, 0x80
    shr dl, cl
    mov ecx, edi
    shr ecx, 3
    or [cu_v + 1 + ecx], dl
    pop ecx
    inc edi
    loop .k
.nj:inc ebx
    cmp ebx, 16
    jb .j
    mov ecx, [cu_x]
    and ecx, 7
    xor ebx, ebx
.s: movzx edx, byte [cu_v + ebx]
    shl edx, 8
    mov dl, [cu_v + ebx + 1]
    shr edx, cl
    mov edi, [cu_dst]
    mov [edi + ebx], dl
    inc ebx
    cmp ebx, 9
    jb .s
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

idtr    dw 48 * 8 - 1
        dd IDT
shift   db 0
ctrl    db 0
ext     db 0
rb_old  db 0
kq_r    db 0
kq_w    db 0
kq      equ KBSS + 0x700
m_btn   db 0
btn_old db 0
pressed db 0
pw_open db 0
pw_min db 0
pw_down db 0
; Standard button press latch (same semantics as the Shutdown window).
ui_btn_id db 0
ui_btn_owner db 0
ui_btn_row db 0
err_file_menu db 0
title_down db 0                      ; shared native title-button press/release state
m_dirty db 0
mp_i    db 0
mp      db 0, 0, 0
cu_x    dd 0
cu_y    dd 0
cu_on   db 0
cu_kind db 0
cu_busy db 0                            ; 1 - идёт долгая работа, курсор - будильник
cu_kind_old db 0
wait_t0 dd 0
wait_min dd WAIT_MIN
cu_ptr  dd 0
cp_vid  dd 0
cp_pl   dd 0
cp_fw   dd 0
cp_fs   dd 0
cp_k    dd 0
cp_s    dd 0
cp_m    dd 0
cu_dst  dd 0
cu_q    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
cu_v    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
cu_s    dd 2
cu_h    dd 34
cu_b    dd 5
t_own   db 0                            ; 1 - мышь над калькулятором, который лежит поверх FloText или FloFile
ap_id   db 0
drag    db 0
d_ctx   db 0
dr_minw dd 160
dr_minh dd 104
d2_main db 0
mv_view db 0
vbar    db 0
hbar    db 0
mx0     dd 140
my0     dd 140
mw      dd 400
mh      dd 300
msx     dd 0
msy     dd 0
mv_vw   dd 0
mv_vh   dd 0
dr_nx   dd 0
dr_ny   dd 0
dr_w    dd 0
dr_h    dd 0
dr_ox   dd 0
dr_oy   dd 0
rs_w0   dd 0
rs_h0   dd 0
sb_x    dd 0
sb_y    dd 0
sb_l    dd 0
sb_h    dd 0
sb_s    dd 0
sb_n    dd 0
sb_off  dd 0
sb_vp   dd 0
xb_x    dd 0
xb_y    dd 0
xb_bg   dd 0
xb_fg   dd 0
cwn_x   dd 0
cwn_y   dd 0
mi_x    dd 0
mi_y    dd 0
mi_k    dd 0
mi_l    dd 0
mi_inv  dd 0
bg_x    dd 0
sp_x    dd 0
sp_y    dd 0
sp_inv  db 0
cr_x0   dd 0
cr_y0   dd 0
cr_x1   dd 0
cr_y1   dd 0
cr_y    dd 0
cr_c    dd 0
cr_tl   dd 0
cr_tr   dd 0
cr_bl   dd 0
cr_br   dd 0
s_floppy db "Floppy", 0
s_main   db "main", 0
s_programs db "programs", 0
s_flopsys db "flopsys", 0
s_ftext  db "FloText", 0
s_ffile  db "FloFile", 0
s_games  db "games", 0
s_gboil db "FloBoil", 0
s_fcalc  db "FloCalc", 0
s_fpaint db "FloPaint", 0
s_fclock db "FloClock", 0
s_fitge db "FloItge", 0
s_fcal db "FloCalendar", 0
mv_tab  dd s_programs, s_flopsys, s_games, 0, 0, 0, 0, 0
        dd s_ftext, s_ffile, s_fcalc, s_fpaint, s_fclock, s_fitge, s_fcal, 0
        dd s_gboil, 0, 0, 0, 0, 0, 0, 0
mv_ch   dd 256
mv_cw   dd 176
cwin_tab db 3, 3, 3, 3, C_BLACK, 2, 2, 2, 3
         db 0, 0, 0, 0, C_BLACK, 2, 2, 1, 2
         db 1, 1, -1, -1, C_WHITE, 1, 1, 0, 1
mi_tab  db 10, 26, 82, 46, C_BLACK, 1
        db 8, 24, 80, 44, C_BLACK, 1
        db 9, 25, 79, 43, C_WHITE, 0
; рисунки курсора: адрес, сдвиг по x, сдвиг по y (стрелка, палец, палочка (пока стрелка), размер)
cu_info dd cur_arrow_k, 0, 0, 0, 0, 0
        dd cur_hand_k, 0, 0, 0, 0, 0
        dd cur_ibeam_k, -8, -16, 0, 0, 0
        dd cur_size_k, -8, -8, 0, 0, 0
        dd cur_clock_k, -16, -16, 0, 0, 0
        dd cur_brush_k, -4, -26, 0, 0, 0
        dd cur_bucket_k, -16, -28, 0, 0, 0
        dd cu_dyn, 0, 0, 0, 0, 0               ; квадрат ластика: размер зависит от толщины, строит pa_eraser_cur
        dd cur_sizeb_k, -8, -8, 0, 0, 0        ; 8: стрелка размера в другую сторону (itge)
        dd cur_move_k, -8, -8, 0, 0, 0         ; 9: стрелка на 4 стороны, перемещение (itge)
        dd cur_cross_k, -16, -16, 0, 0, 0      ; 10: крест (FloPaint: линия, квадрат и круг), точка касания в середине
        dd cur_vresize_k, -8, -8, 0, 0, 0    ; 11: vertical resize for the panel
; клавиши (сканкоды набора 1): обычные и с Shift, 0 - нет буквы
ext_map db 0x4B, 0x93, 0x4D, 0x94, 0x47, 0x95, 0x4F, 0x96, 0x53, 0x97, 0x49, 0x98, 0x51, 0x99, 0, 0
sc_norm db 0, 27, "1234567890-=", 8, 9, "qwertyuiop[]", 13, 0, "asdfghjkl;'`", 0, "\zxcvbnm,./", 0, "*", 0, " "
sc_shift db 0, 27, "!@#$%^&*()_+", 8, 9, "QWERTYUIOP{}", 13, 0, 'ASDFGHJKL:"~', 0, "|", "ZXCVBNM<>?", 0, "*", 0, " "
; русская раскладка (ЙЦУКЕН, коды как в кодировке 1251, Ё и ё - 0xBE и 0xBF): обычные и с Shift
sc_ru db 0, 27, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 8, 9, 233, 246, 243, 234, 229, 237, 227, 248, 249, 231, 245, 250, 13, 0, 244, 251, 226, 224, 239, 240, 238, 235, 228, 230, 253, 191, 0, 92, 255, 247, 241, 236, 232, 242, 252, 225, 254, 46, 0, 42, 0, 32
sc_rus db 0, 27, 33, 34, 35, 59, 37, 58, 63, 42, 40, 41, 95, 43, 8, 9, 201, 214, 211, 202, 197, 205, 195, 216, 217, 199, 213, 218, 13, 0, 212, 219, 194, 192, 207, 208, 206, 203, 196, 198, 221, 190, 0, 124, 223, 215, 209, 204, 200, 210, 220, 193, 222, 44, 0, 42, 0, 32
cur_arrow_k dd 0xC0000000, 0xF0000000, 0xCC000000, 0xC3000000, 0xC0C00000, 0xC0300000, 0xC00C0000, 0xC0030000, 0xC000C000, 0xC00FF000, 0xC30C0000, 0xCCC30000, 0xF0C30000, 0xC030C000, 0x0030C000, 0x000F0000, 0x00000000
cur_arrow_w dd 0x00000000, 0x00000000, 0x30000000, 0x3C000000, 0x3F000000, 0x3FC00000, 0x3FF00000, 0x3FFC0000, 0x3FFF0000, 0x3FF00000, 0x3CF00000, 0x303C0000, 0x003C0000, 0x000F0000, 0x000F0000, 0x00000000, 0x00000000
cur_arrow_s dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0003FC00, 0x03000000, 0x0F00C000, 0x3C000000, 0x30003000, 0x0000F000, 0x0003C000
cur_hand_k dd 0x00F00000, 0x030C0000, 0x030C0000, 0x030C0000, 0x030FC000, 0x030C3F00, 0xF30C30C0, 0xCF000030, 0xC3000030, 0x30000030, 0x30000030, 0x0C0000C0, 0x0C0000C0, 0x03000300, 0x03FFFF00, 0x00000000, 0x00000000
cur_hand_w dd 0x00000000, 0x00F00000, 0x00F00000, 0x00F00000, 0x00F00000, 0x00F3C000, 0x00F3CF00, 0x30FFFFC0, 0x3CFFFFC0, 0x0FFFFFC0, 0x0FFFFFC0, 0x03FFFF00, 0x03FFFF00, 0x00FFFC00, 0x00000000, 0x00000000, 0x00000000
cur_hand_s dd 0x00000000, 0x00000000, 0x00030000, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000C, 0x0000000C, 0x0000000C, 0x0000003C, 0x00000030, 0x000000F0, 0x000000C0, 0x00FFFFC0, 0x00000000
cur_size_k dd 0x00000000, 0x0FF00000, 0x300C0000, 0x30F00000, 0x33300000, 0x33CC0000, 0x0C330000, 0x000CC000, 0x00033000, 0x0000CC30, 0x000033CC, 0x00000CCC, 0x00000F0C, 0x0000300C, 0x00000FF0, 0x00000000, 0x00000000
cur_size_w dd 0x00000000, 0x00000000, 0x0FF00000, 0x0F000000, 0x0CC00000, 0x0C300000, 0x000C0000, 0x00030000, 0x0000C000, 0x00003000, 0x00000C30, 0x00000330, 0x000000F0, 0x00000FF0, 0x00000000, 0x00000000, 0x00000000
cur_size_s dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
; курсор-будильник: 16 x 17 (чёрный, белый, тень)
cur_sizeb_k dd 0x00000000, 0x00000FF0, 0x0000300C, 0x00000F0C, 0x00000CCC, 0x000033CC, 0x0000CC30, 0x00033000, 0x000CC000, 0x0C330000, 0x33CC0000, 0x33300000, 0x30F00000, 0x300C0000, 0x0FF00000, 0x00000000, 0x00000000
cur_sizeb_w dd 0x00000000, 0x00000000, 0x00000FF0, 0x000000F0, 0x00000330, 0x00000C30, 0x00003000, 0x0000C000, 0x00030000, 0x000C0000, 0x0C300000, 0x0CC00000, 0x0F000000, 0x0FF00000, 0x00000000, 0x00000000, 0x00000000
cur_sizeb_s dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
cur_cross_k dd 0x00000000, 0x00000000, 0x00008000, 0x00008000, 0x00008000, 0x00008000, 0x00008000, 0x00008000, 0x0AAAAAA8, 0x00008000, 0x00008000, 0x00008000, 0x00008000, 0x00008000, 0x00008000, 0x00000000, 0x00000000
cur_cross_w dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
cur_cross_s dd 0x00000000, 0x00000000, 0x00000000, 0x00002000, 0x00002000, 0x00002000, 0x00002000, 0x00002000, 0x00000000, 0x02AA2AAA, 0x00002000, 0x00002000, 0x00002000, 0x00002000, 0x00002000, 0x00002000, 0x00000000
cur_vresize_k dd 0x00030000, 0x000CC000, 0x00303000, 0x00C00C00, 0x00FCFC00, 0x000CC000, 0x000CC000, 0x000CC000, 0x000CC000, 0x000CC000, 0x000CC000, 0x000CC000, 0x000CC000, 0x00FCFC00, 0x00C00C00, 0x00303000, 0x000CC000, 0x00030000, 0x00000000
cur_vresize_w dd 0x00000000, 0x00030000, 0x000FC000, 0x003FF000, 0x00030000, 0x00030000, 0x00030000, 0x00030000, 0x00030000, 0x00030000, 0x00030000, 0x00030000, 0x00030000, 0x00030000, 0x003FF000, 0x000FC000, 0x00030000, 0x00000000, 0x00000000
cur_vresize_s dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
cur_move_k dd 0x0003C000, 0x000C3000, 0x00300C00, 0x00F00F00, 0x030C30C0, 0x0F0C30F0, 0x30F00F0C, 0xC0000003, 0xC0000003, 0x30F00F0C, 0x0F0C30F0, 0x030C30C0, 0x00F00F00, 0x00300C00, 0x000C3000, 0x0003C000, 0x00000000
cur_move_w dd 0x00000000, 0x0003C000, 0x000FF000, 0x000FF000, 0x0003C000, 0x0003C000, 0x0F0FF0F0, 0x3FFFFFFC, 0x3FFFFFFC, 0x0F0FF0F0, 0x0003C000, 0x0003C000, 0x000FF000, 0x000FF000, 0x0003C000, 0x00000000, 0x00000000
cur_move_s dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
cur_clock_k dd 0x0FC003F0, 0x30300C0C, 0x30FFFF0C, 0x0FC003F0, 0x030000C0, 0x0C030030, 0x0C030030, 0x3003000C, 0x3003000C, 0x3003F00C, 0x3000000C, 0x0C000030, 0x0C000030, 0x030000C0, 0x00FFFF00, 0x03C003C0, 0x0F0000F0
cur_clock_w dd 0x00000000, 0x0FC003F0, 0x0F0000F0, 0x003FFC00, 0x00FFFF00, 0x03FCFFC0, 0x03FCFFC0, 0x0FFCFFF0, 0x0FFCFFF0, 0x0FFC0FF0, 0x0FFFFFF0, 0x03FFFFC0, 0x03FFFFC0, 0x00FFFF00, 0x00000000, 0x00000000, 0x00000000
cur_clock_s dd 0x00000000, 0x00000000, 0x00000003, 0x0000000F, 0x0000003C, 0x00000000, 0x0000000C, 0x00000000, 0x00000003, 0x00000003, 0x00000003, 0x0000000F, 0x0000000C, 0x0000003C, 0x000000F0, 0x003FFC00, 0x00F00000
cu_dyn  equ KBSS + 0x800
cur_brush_k dd 0x00000000, 0x000000F0, 0x0000030C, 0x00000C0C, 0x00003030, 0x0000C0C0, 0x00030300, 0x000C0C00, 0x00F03000, 0x03FCC000, 0x0FFF0000, 0x0FFF0000, 0x0FFC0000, 0x0FF00000, 0x00000000, 0x00000000, 0x00000000
cur_brush_w dd 0x00000000, 0x00000000, 0x000000F0, 0x000003F0, 0x00000FC0, 0x00003F00, 0x0000FC00, 0x0003F000, 0x000FC000, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
cur_brush_s dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
cur_bucket_k dd 0x00000000, 0x00FFFF00, 0x03C003C0, 0x030000C0, 0x3FFFFFFC, 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C, 0x3000000C, 0x0C000030, 0x0C000030, 0x030000C0, 0x00FFFFC0, 0x00000000, 0x00000000, 0x00000000
cur_bucket_w dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
cur_bucket_s dd 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0FFFFFF0, 0x0FFFFFF0, 0x0FFFFFF0, 0x0FFFFFF0, 0x0FFFFFF0, 0x03FFFFC0, 0x03FFFFC0, 0x00FFFF00, 0x00000000, 0x00000000, 0x00000000, 0x00000000
flop_img:
    db "kkkkkkkkkkkkkkk."
    db "kwwkGGGGGGkwwwk."
    db "kwwkGGkkkGkwwwk."
    db "kwwkGGGGGGkwwwk."
    db "kwwwwwwwwwwwwwk."
    db "kwkkkkkkkkkkkwk."
    db "kwwwwwwwwwwwwwk."
    db "kwkkkkkkkkwwwwk."
    db "kwwwwwwwwwwwwwk."
    db "kwwwwwwwwwwwwwk."
    db "kkkkkkkkkkkkkkk."

; окна и системы (каждая в своём файле)
%include "src/kernel/common.asm"
%include "src/kernel/error_core.asm"
%include "src/filesystems/fs.asm"
%include "src/filesystems/fs3_catalog.asm"
%include "src/filesystems/fs3_read.asm"
%include "src/filesystems/fs3_write.asm"
%include "src/filesystems/fs3_ops.asm"
%include "src/filesystems/fs3_stream.asm"
%include "src/filesystems/fs3_test.asm"
%include "src/kernel/sysinst.asm"
%include "src/desktop/dialog.asm"
%include "src/desktop/clock.asm"
%include "src/desktop/terminal.asm"
%include "src/desktop/winmenu.asm"
%include "src/desktop/power.asm"
%include "src/desktop/help.asm"
%include "src/kernel/install.asm"
%include "src/desktop/tasks.asm"
%include "src/desktop/calendar_api.inc"
%include "src/desktop/about.asm"
%include "src/desktop/bootsplash.asm"
%include "src/desktop/settings.asm"
%include "src/desktop/loading.asm"
%include "src/desktop/zorder.asm"
%include "src/kernel/panic.asm"
%include "src/filesystems/fs3_alert.asm"
%include "src/desktop/egg.asm"
%include "src/desktop/zfloat.asm"
%include "src/desktop/minimize.asm"
%include "src/desktop/welcome.asm"
%include "src/filesystems/disks.asm"
; Перечитывание модуля FloCalendar из pm.img после инициализации ATA.
; При загрузке BIOS мог не доставить или повредить сектора модуля.
; Данные пользователя и файловая система не изменяются; только RAM 0x54000..0x55FFF.
; pm.img: boot (1), kernel (256), calc (8), text (16), paint (32),
; file (48), boil (12), itge (64) -> FloCalendar starts at LBA 437.
calendar_reload_ata:
    pushad
    push dword [cur_base]
    push dword [cur_size]
    movzx eax, byte [cur_drive]
    push eax
    mov byte [cur_drive], 0
    mov dword [cur_base], 0
    mov dword [cur_size], 0
    mov eax, 437
    mov ebx, 0x54000
    mov ecx, 16
.read:
    push ecx
    call lba_read
    pop ecx
    jc .fail
    inc eax
    add ebx, 512
    loop .read
    jmp .restore
.fail:
    ; Prevent installer from treating incomplete module as valid.
    mov dword [0x54000], 0
.restore:
    pop eax
    mov [cur_drive], al
    pop dword [cur_size]
    pop dword [cur_base]
    popad
    ret

; Свой шрифт: копия шрифта BIOS в памяти, поверх неё знаки 32..126 из flofont
FONT_RAM equ 0x1C0000
font_init:
    pushad
    cld
    mov esi, [0x500]
    mov edi, FONT_RAM
    mov ecx, 1024
    rep movsd
    mov esi, flofont
    mov edi, FONT_RAM + 32 * 16
    mov ecx, 95 * 16 / 4
    rep movsd
    mov esi, RUFONT                     ; русские буквы: 0xBE Ё, 0xBF ё, 0xC0..0xFF А..я
    mov edi, FONT_RAM + 0xBE * 16
    mov ecx, 66 * 16 / 4
    rep movsd
    mov dword [0x500], FONT_RAM
    popad
    ret

%include "src/desktop/flofont.inc"

; Русский интерфейс: если он включён и строка esi лежит в образе (не введена пользователем), ищем её в словаре; esi - перевод. Остальные регистры не меняются
ui_tr:
    cmp byte [ui_ru], 0
    je .r
    cmp esi, 0x60000
    jae .r
    push eax
    push ebx
    push edx
    push edi
    mov edx, ru_dict
.n: movzx eax, byte [edx]
    test eax, eax
    jz .no
    lea edi, [edx + 1]
    mov ebx, esi
.c: mov al, [ebx]
    cmp al, [edi]
    jne .sk
    test al, al
    jz .f
    inc ebx
    inc edi
    jmp .c
.sk:movzx eax, byte [edx]
    add edx, eax
    jmp .n
.f: lea esi, [edi + 1]
.no:pop edi
    pop edx
    pop ebx
    pop eax
.r: ret
%include "src/desktop/ru_dict.inc"
cu_msk equ KBSS + 0x900              ; маски курсора (1836 байт), вне образа
%include "src/boot/bootmenu.asm"
times 256 * 512 - ($ - $$) db 0
