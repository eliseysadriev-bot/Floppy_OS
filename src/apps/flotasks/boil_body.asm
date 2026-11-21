; Boil - игра на весь экран. Включается в boilsys.asm
; Сверху всегда File (меню Record и Exit), справа вверху серия побед, кнопки Start и Stop на самой микроволновке
; Игра задаёт число секунд от 1.00 до 5.50: включи микроволновку и выключи ровно через столько.
; Ошибка не больше 0.3 с - победа. Рекорд - больше всего побед подряд, лежит в flopsys/games/boil/record.txt

BO_BG  equ C_GRAY                          ; цвет фона игры
BO_TOL equ 30                           ; допуск в сотых секунды

boil_open:
    cmp byte [d2_boil], 0
    jne .r
    mov al, 4
    call z_hide_others
    mov byte [d2_boil], 1
    mov byte [bo_state], 0
    mov dword [bo_streak], 0
    call bo_load
    call bo_newtarget
    jmp redraw
.r: ret

boil_close:
    mov byte [d2_boil], 0
    mov al, 4
    call z_restore
    jmp redraw

; Клавиши: Esc - выход (или закрыть меню), пробел и Enter - Start / Stop
boil_key:
    pushad
    cmp byte [bo_view], 0
    je .nv
    mov byte [bo_view], 0
    call boil_draw
    jmp .r
.nv:cmp al, 5                       ; Ctrl+E - выйти
    je .ex
    cmp al, 27
    jne .a
    cmp byte [bo_menu], 0
    je .ex
    mov byte [bo_menu], 0
    call boil_draw
    jmp .r
.ex:call boil_close
    jmp .r
.a: cmp al, 32
    je .b
    cmp al, 13
    jne .r
.b: cmp byte [bo_state], 1
    je .st
    call bo_start
    jmp .r
.st:call bo_stop
.r: popad
    ret

; Под мышью: 150 File, 151 Start, 152 Stop, 153 Record, 154 Exit (пункты меню), 0 - ничего
boil_hit:
    mov esi, [m_x]
    mov edi, [m_y]
    cmp byte [bo_view], 0               ; окно рекордов: нажимается только Ok
    je .nv
    cmp esi, 340
    jb .z
    cmp esi, 460
    ja .z
    cmp edi, 288
    jb .z
    cmp edi, 324
    ja .z
    mov al, 155
    ret
.nv:    cmp byte [bo_menu], 0
    je .nm
    cmp esi, 4
    jb .nm
    cmp esi, 268
    ja .nm
    mov eax, edi
    sub eax, 82
    jl .nm
    cmp eax, 72
    jae .nm
    xor edx, edx
    mov ecx, 36
    div ecx
    add eax, 153
    ret
.nm:cmp esi, 4
    jb .b
    cmp esi, 84
    ja .b
    cmp edi, 40
    jb .b
    cmp edi, 76
    ja .b
    mov al, 150
    ret
.b: cmp esi, 430
    jb .z
    cmp esi, 536
    ja .z
    cmp edi, 280
    jb .z
    cmp edi, 324
    jbe .s1
    cmp edi, 344
    jb .z
    cmp edi, 388
    ja .z
    mov al, 152
    ret
.s1:mov al, 151
    ret
.z: xor al, al
    ret

boil_press:
    pushad
    cmp byte [bo_view], 0               ; окно рекордов: кнопка Ok опускается, закрывается при отпускании
    je .nv
    cmp al, 155
    jne .r
    mov byte [bo_pb], 3
    call boil_draw
    jmp .r
.nv:cmp al, 150
    jne .a
    xor byte [bo_menu], 1
    call boil_draw
    jmp .r
.a: cmp byte [bo_menu], 0
    je .b
    mov byte [bo_menu], 0
    cmp al, 153
    je .rec
    cmp al, 154
    je .ex
    call boil_draw
    jmp .r
.rec:
    mov byte [bo_view], 1
    call boil_draw
    jmp .r
.ex:call boil_close
    jmp .r
.b: cmp al, 151
    jne .c
    mov byte [bo_pb], 1
    call bo_start
    jmp .r
.c: cmp al, 152
    jne .r
    mov byte [bo_pb], 2
    call bo_stop
.r: popad
    ret

; Мышь отпущена: кнопки поднимаются
boil_release:
    pushad
    movzx eax, byte [bo_pb]
    test eax, eax
    jz .r
    mov byte [bo_pb], 0
    cmp eax, 3
    jne .d
    cmp byte [t_id], 155
    jne .d
    mov byte [bo_view], 0               ; Ok нажали и отпустили на нём
.d: call boil_draw
.r: popad
    ret

; Включить микроволновку
bo_start:
    pushad
    cmp byte [bo_state], 1
    je .dr
    call bo_now
    mov [bo_t0], eax
    mov [bo_e0], edx
    mov byte [bo_state], 1
.dr:call boil_draw
    popad
    ret

; Выключить: сравнить время с числом
bo_stop:
    pushad
    cmp byte [bo_state], 1
    jne .dr
    call bo_now                         ; время снимаем первым делом
    sub eax, [bo_t0]
    sub edx, [bo_e0]
    cmp eax, 60000
    jbe .ok
    mov eax, 60000
    xor edx, edx
.ok:shl eax, 16
    add eax, edx                        ; прошло тактов таймера
    mov ecx, 100
    mul ecx
    mov ecx, 1193182
    div ecx                             ; сотые доли секунды
    mov [bo_res], eax
    sub eax, [bo_target]
    jge .p
    neg eax
.p: mov [bo_diff], eax
    cmp eax, BO_TOL
    jg .lose
    mov byte [bo_win], 1
    inc dword [bo_streak]
    mov eax, [bo_streak]
    cmp eax, [bo_rec]
    jbe .done
    mov [bo_rec], eax                   ; новый рекорд
    call bo_save
    jmp .done
.lose:
    mov byte [bo_win], 0
    mov dword [bo_streak], 0
.done:
    mov byte [bo_state], 2
    call bo_newtarget                   ; следующее число видно сразу
.dr:call boil_draw
    popad
    ret

; Точное время: eax = тики, edx = такты таймера внутри тика (таймер 0 в режиме 2, период 65536)
bo_now:
    push ebx
    pushfd
    cli
    xor al, al
    out 0x43, al                        ; защёлкнуть счётчик
    in al, 0x40
    mov dl, al
    in al, 0x40
    mov dh, al
    mov al, 0x0A                        ; ждёт ли прерывание таймера
    out 0x20, al
    in al, 0x20
    mov bl, al
    mov eax, [ticks]
    movzx edx, dx
    neg edx
    and edx, 0xFFFF                     ; прошло в этом тике
    test bl, 1
    jz .n
    cmp edx, 32768
    jae .n
    inc eax
.n: popfd
    pop ebx
    ret

; Новое число от 1.00 до 5.50
bo_newtarget:
    pushad
    call bo_now
    shl eax, 16
    xor eax, edx
    xor [bo_seed], eax
    mov eax, [bo_seed]
    imul eax, 1103515245
    add eax, 12345
    mov [bo_seed], eax
    shr eax, 8
    xor edx, edx
    mov ecx, 451
    div ecx
    add edx, 100
    mov [bo_target], edx
    popad
    ret

; Папка flopsys/games/boil на диске C. CF = нет такой
bo_enter:
    push ebx
    push esi
    xor eax, eax
    call fs_setdisk
    jc .f
    mov byte [fs_par], 0
    mov ebx, bo_path
.l: mov esi, [ebx]
    test esi, esi
    jz .ok
    call dir_find
    jc .f
    call dir_last_id
    mov [fs_par], al
    add ebx, 4
    jmp .l
.ok:pop esi
    pop ebx
    clc
    ret
.f: pop esi
    pop ebx
    stc
    ret

bo_load:
    pushad
    mov dword [bo_rec], 0
    call bo_enter
    jc .r
    mov esi, s_recname
    call file_read
    jc .r
    mov esi, DATA_BUF
    xor ebx, ebx
.d: movzx eax, byte [esi]
    sub eax, '0'
    cmp eax, 9
    ja .e
    imul ebx, 10
    add ebx, eax
    inc esi
    jmp .d
.e: mov [bo_rec], ebx
.r: mov byte [fs_par], 0
    popad
    ret

bo_save:
    pushad
    call bo_enter
    jc .r
    mov edi, DATA_BUF
    mov eax, [bo_rec]
    call u32str
    mov byte [edi], 0
    mov ecx, edi
    sub ecx, DATA_BUF
    mov esi, s_recname
    call file_write
.r: mov byte [fs_par], 0
    popad
    ret

; Строка esi в edi без нуля в конце
bo_cat:
    call ui_tr                          ; по-русски берём перевод надписи
.l: lodsb
    test al, al
    jz .r
    stosb
    jmp .l
.r: ret

; eax (сотые) -> "S.HH" в edi
bo_fmt:
    push eax
    push ecx
    push edx
    xor edx, edx
    mov ecx, 100
    div ecx
    call u32str
    mov byte [edi], '.'
    inc edi
    mov eax, edx
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [edi], al
    inc edi
    add dl, '0'
    mov [edi], dl
    inc edi
    pop edx
    pop ecx
    pop eax
    ret

; Строка esi по центру экрана, t_y уже задан
bo_centerw:
    mov dword [r_c], C_WHITE
    jmp bo_c2
bo_center:
    mov dword [r_c], C_BLACK
bo_c2:
    call strlen
    shl ecx, 4
    mov eax, 800
    sub eax, ecx
    shr eax, 1
    mov [t_x], eax
    jmp draw_big

; Кнопка: x, y, ширина, высота, строка, номер (нажатая кнопка рисуется чёрной)
%macro BBTN 6
    mov eax, %1
    mov ebx, %2
    mov ecx, %3
    mov edx, %4
    mov esi, %5
    mov edi, %6
    call bo_btn
%endmacro

bo_btn:
    pushad
    mov [bb_x], eax
    mov [bb_y], ebx
    mov [bb_w], ecx
    mov [bb_h], edx
    mov [bb_s], esi
    mov dword [bb_f], C_WHITE
    mov dword [bb_t], C_BLACK
    movzx eax, byte [bo_pb]
    cmp eax, edi
    jne .np
    mov dword [bb_f], C_BLACK
    mov dword [bb_t], C_WHITE
.np:mov eax, [bb_x]
    mov [r_x], eax
    mov eax, [bb_y]
    mov [r_y], eax
    mov eax, [bb_w]
    mov [r_w], eax
    mov eax, [bb_h]
    mov [r_h], eax
    mov dword [r_c], C_BLACK
    call fill_rect
    add dword [r_x], 2
    add dword [r_y], 2
    sub dword [r_w], 4
    sub dword [r_h], 4
    mov eax, [bb_f]
    mov [r_c], eax
    call fill_rect
    mov esi, [bb_s]
    call strlen
    shl ecx, 4
    mov eax, [bb_w]
    sub eax, ecx
    shr eax, 1
    add eax, [bb_x]
    mov [t_x], eax
    mov eax, [bb_h]
    sub eax, 32
    shr eax, 1
    add eax, [bb_y]
    mov [t_y], eax
    mov eax, [bb_t]
    mov [r_c], eax
    mov esi, [bb_s]
    call draw_big
    popad
    ret

; Строка esi, центр по x = eax, y = ebx, цвет ecx
bo_cxt:
    mov [r_c], ecx
    mov [t_y], ebx
    push eax
    call strlen
    shl ecx, 3
    pop eax
    sub eax, ecx
    mov [t_x], eax
    jmp draw_big

boil_draw:
    pushad
    cld
    call mclip_off
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    RECT 0, 0, 800, 600, BO_BG
    RECT 0, 0, 800, 78, C_WHITE         ; заголовок белый
    RECT 0, 38, 800, 2, C_BLACK
    RECT 0, 78, 800, 2, C_BLACK
    mov dword [t_y], 2
    mov esi, s_title
    call bo_center
    cmp byte [bo_menu], 0               ; кнопка File
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
    RECT 0, 460, 800, 140, C_BLUE       ; столешница
    RECT 0, 460, 800, 2, C_BLACK
    RECT 244, 100, 320, 48, C_BLACK     ; табличка: когда выключать
    RECT 240, 96, 320, 48, C_BLACK
    RECT 242, 98, 316, 44, C_BLUE
    mov edi, bo_buf
    mov esi, s_target
    call bo_cat
    mov eax, [bo_target]
    call bo_fmt
    mov esi, s_sec
    call bo_cat
    mov byte [edi], 0
    mov dword [t_y], 104
    mov esi, bo_buf
    call bo_centerw
    RECT 76, 166, 500, 300, C_BLACK     ; микроволновка: тень, корпус, ножки
    RECT 70, 160, 500, 300, C_BLACK
    RECT 72, 162, 496, 296, C_WHITE
    RECT 100, 460, 50, 8, C_BLACK
    RECT 490, 460, 50, 8, C_BLACK
    RECT 94, 184, 304, 252, C_BLACK     ; дверца
    mov ebx, C_BLACK                    ; внутри тёмно, включена - синий свет
    mov ebp, C_GRAY                     ; цвет чашки
    cmp byte [bo_state], 1
    jne .nl
    mov ebx, C_BLUE
    mov ebp, C_BLACK
.nl:RECTM 96, 186, 300, 248, ebx
    RECTM 190, 396, 112, 4, ebp         ; блюдце
    RECTM 276, 340, 24, 36, ebp         ; ручка
    RECTM 276, 344, 20, 28, ebx
    RECTM 216, 332, 64, 64, ebp         ; чашка
    RECTM 218, 334, 60, 60, ebx
    RECT 218, 344, 60, 50, C_WHITE      ; молоко
    cmp byte [bo_state], 1
    jne .ns
    RECT 232, 312, 8, 8, C_WHITE        ; пар
    RECT 250, 292, 8, 8, C_WHITE
    RECT 236, 272, 8, 8, C_WHITE
    RECT 256, 252, 6, 6, C_WHITE
.ns:RECT 400, 260, 6, 100, C_GRAY       ; ручка дверцы
    RECT 400, 260, 6, 2, C_BLACK
    RECT 400, 358, 6, 2, C_BLACK
    RECT 416, 184, 140, 252, C_BLACK    ; панель
    RECT 418, 186, 136, 248, C_GRAY
    RECT 430, 204, 106, 48, C_BLACK     ; дисплей
    mov ebx, C_BLACK                    ; выключен - чёрный, включена - синий
    cmp byte [bo_state], 1
    jne .nd
    mov ebx, C_BLUE
.nd:RECTM 432, 206, 102, 44, ebx
    cmp byte [bo_state], 2
    jne .ds
    mov esi, s_win                      ; результат на дисплее
    cmp byte [bo_win], 0
    jne .dw
    mov esi, s_miss
.dw:call strlen
    shl ecx, 4
    mov eax, 102
    sub eax, ecx
    shr eax, 1
    add eax, 432
    mov [t_x], eax
    mov dword [t_y], 212
    mov dword [r_c], C_WHITE
    call draw_big
.ds:BBTN 430, 280, 106, 44, s_start, 1
    BBTN 430, 344, 106, 44, s_stop, 2
    RECT 430, 402, 106, 2, C_BLACK      ; решётка
    RECT 430, 410, 106, 2, C_BLACK
    RECT 430, 418, 106, 2, C_BLACK
    RECT 606, 176, 170, 110, C_BLACK    ; карточка серии побед
    RECT 600, 170, 170, 110, C_BLACK
    RECT 602, 172, 166, 106, C_WHITE
    mov esi, s_streak
    mov eax, 685
    mov ebx, 182
    mov ecx, C_BLACK
    call bo_cxt
    mov edi, bo_buf
    mov eax, [bo_streak]
    call u32str
    mov byte [edi], 0
    mov esi, bo_buf
    mov eax, 685
    mov ebx, 228
    mov ecx, C_BLUE
    call bo_cxt
    cmp byte [bo_menu], 0
    je .nm
    RECT 8, 82, 264, 76, C_BLACK        ; меню File: Record, Exit
    RECT 4, 78, 264, 76, C_BLACK
    RECT 6, 80, 260, 72, C_WHITE
    mov dword [r_c], C_BLACK
    mov dword [t_x], 12
    mov dword [t_y], 82
    mov esi, s_m_rec
    call draw_big
    mov dword [t_y], 118
    mov esi, s_exit
    call draw_big
    mov dword [t_x], 124
    mov esi, s_k_e
    call draw_big
.nm:cmp byte [bo_view], 0
    je .e
    RECT 208, 178, 400, 160, C_BLACK    ; окно рекордов
    RECT 200, 170, 400, 160, C_BLACK
    RECT 202, 172, 396, 156, C_WHITE
    mov dword [t_y], 178
    mov esi, s_recs
    call bo_center
    mov edi, bo_buf
    mov esi, s_best
    call bo_cat
    mov eax, [bo_rec]
    call u32str
    mov byte [edi], 0
    mov dword [t_y], 218
    mov esi, bo_buf
    call bo_center
    mov edi, bo_buf
    mov esi, s_now
    call bo_cat
    mov eax, [bo_streak]
    call u32str
    mov byte [edi], 0
    mov dword [t_y], 250
    mov esi, bo_buf
    call bo_center
    BBTN 340, 288, 120, 36, s_ok, 3
.e: call mn_pdraw
    popad
    ret

bo_state  db 0                          ; 0 ждёт, 1 включена, 2 результат
bo_win    db 0
bo_menu   db 0
bo_pb     db 0                          ; какая кнопка нажата: 1 Start, 2 Stop, 3 Ok
bb_x dd 0
bb_y dd 0
bb_w dd 0
bb_h dd 0
bb_s dd 0
bb_f dd 0
bb_t dd 0
bo_view   db 0
bo_target dd 300
bo_t0     dd 0
bo_e0     dd 0
bo_res    dd 0
bo_diff   dd 0
bo_streak dd 0
bo_rec    dd 0
bo_seed   dd 12345
bo_path   dd s_flopsys, s_games, s_boil, 0
s_flopsys db "flopsys", 0
s_games   db "games", 0
s_boil    db "boil", 0
s_recname db "record.txt", 0
s_title   db "FloBoil", 0
s_file    db "File", 0
s_exit    db "Exit", 0
s_k_e     db "Ctrl + E", 0
s_m_rec   db "Record", 0
s_recs    db "Records", 0
s_best    db "Best streak: ", 0
s_now     db "Streak now: ", 0
s_target  db "Turn off at ", 0
s_sec     db " s", 0
s_start   db "Start", 0
s_stop    db "Stop", 0
s_win     db "Win!", 0
s_miss    db "Miss", 0
s_ok      db "Ok", 0
s_streak  db "Streak", 0
bo_buf    times 64 db 0
