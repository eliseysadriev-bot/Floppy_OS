; FloCalc - калькулятор: окно, кнопки, арифметика (число x1000)
; Подключается из kernel32.asm (%include)

; калькулятор FloCalc
CALC_N  equ 18

calc_open:
    cmp byte [d2_calc], 0
    je .new
    mov dl, 7
    call fz_open_window
    jmp redraw
.new:
    call wait_start
    mov dword [csx], 0
    mov dword [csy], 0
    mov byte [d2_calc], 1
    mov dl, 7
    call fz_open_window
    mov byte [calc_foc], 1
    mov byte [calc_menu], 0
    mov byte [calc_pr], 0xFF
    call calc_clear
    call wait_end
    jmp redraw

calc_exit:
    cmp byte [hp_on], 6
    jne .nh
    mov byte [hp_on], 0
.nh:mov byte [d2_calc], 0
    mov byte [calc_foc], 0
    mov byte [calc_menu], 0
    mov byte [calc_pr], 0xFF
    jmp redraw

calc_clear:
    mov dword [calc_cur], 0
    mov dword [calc_acc], 0
    mov byte [calc_op], 0
    mov byte [calc_ent], 0
    mov byte [calc_dot], 0
    mov byte [calc_dec], 0
    mov byte [calc_err], 0
    ret

; Прямоугольник внутри окна калькулятора: eax, ebx - угол, ecx, edx - размер, цвет в r_c
calc_box:
    add eax, [calc_x0]
    add ebx, [calc_y0]
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    jmp fill_rect

calc_draw:
    pushad
    call calc_layout
    mov eax, [calc_x0]
    mov [cw_x], eax
    mov eax, [calc_y0]
    mov [cw_y], eax
    mov eax, [calc_w]
    mov [win_w], eax
    mov eax, [calc_h]
    mov [win_h], eax
    call cwin
    mov dword [r_c], C_BLACK
    mov eax, 2
    mov ebx, 38
    mov ecx, [calc_w]
    sub ecx, 4
    mov edx, 2
    call calc_box
    mov eax, 2
    mov ebx, 78
    call calc_box
    mov eax, [calc_w]                   ; чёрный квадрат: за него растягивают окно
    sub eax, 18
    mov ebx, [calc_h]
    sub ebx, 18
    mov ecx, 16
    mov edx, 16
    call calc_box
    mov eax, [calc_w]                   ; заголовок по центру
    sub eax, 112
    shr eax, 1
    and eax, -8
    add eax, [calc_x0]
    mov [t_x], eax
    mov eax, [calc_y0]
    add eax, 2
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_flocalc
    call draw_big
    mov eax, [calc_x0]
    add eax, [calc_w]
    sub eax, 32
    mov ebx, [calc_y0]
    add ebx, 8
    xor edi, edi
    call xbtn
    cmp byte [calc_menu], 0
    je .fn
    mov eax, 4                          ; File: чёрная кнопка, белая надпись
    mov ebx, 42
    mov ecx, 80
    mov edx, 34
    mov dword [r_c], C_BLACK
    call calc_box
    mov dword [t_x], 12
    mov dword [r_c], C_WHITE
    jmp .ft
.fn:mov eax, 4
    mov ebx, 42
    mov ecx, 80
    mov edx, 34
    mov dword [r_c], C_BLACK
    call calc_box
    mov eax, 6
    mov ebx, 44
    mov ecx, 76
    mov edx, 30
    mov dword [r_c], C_WHITE
    call calc_box
    mov dword [t_x], 12
    mov dword [r_c], C_BLACK
.ft:mov eax, [calc_x0]
    add [t_x], eax
    mov eax, [calc_y0]
    add eax, 46
    mov [t_y], eax
    mov esi, s_file
    call draw_big
    xor ebx, ebx
.b: push ebx
    xor edi, edi
    call calc_btn
    pop ebx
    inc ebx
    cmp ebx, CALC_N
    jb .b
    call calc_disp
    cmp byte [cvb], 0
    je .nv
    mov eax, [calc_x0]
    add eax, [calc_w]
    sub eax, 18
    mov ebx, [calc_y0]
    add ebx, 80
    mov ecx, [calc_h]
    sub ecx, 98
    xor edx, edx
    mov esi, [cvh]
    mov edi, CALC_CH
    mov ebp, [csy]
    call sbar
.nv:cmp byte [chb], 0
    je .nh
    mov eax, [calc_x0]
    add eax, 2
    mov ebx, [calc_y0]
    add ebx, [calc_h]
    sub ebx, 18
    mov ecx, [calc_w]
    sub ecx, 20
    mov edx, 1
    mov esi, [cvw]
    mov edi, CALC_CW
    mov ebp, [csx]
    call sbar
.nh:cmp byte [calc_menu], 0
    je .e
    mov dword [r_c], C_BLACK            ; меню: Exit
    mov eax, 8
    mov ebx, 84
    mov ecx, 232
    mov edx, 44
    call calc_box
    mov eax, 4
    mov ebx, 80
    call calc_box
    mov dword [r_c], C_WHITE
    mov eax, 6
    mov ebx, 82
    mov ecx, 228
    mov edx, 40
    call calc_box
    mov eax, [calc_x0]
    add eax, 12
    mov [t_x], eax
    mov eax, [calc_y0]
    add eax, 86
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    mov esi, s_exit
    call draw_big
    mov eax, [calc_x0]
    add eax, 92
    mov [t_x], eax
    mov esi, s_k_e
    call draw_big
.e: mov eax, [calc_x0]
    mov ebx, [calc_y0]
    mov ecx, 6
    call hp_win
    popad
    ret

; Размеры видимой части и полосок, прокрутка не дальше конца
calc_layout:
    pushad
    mov eax, [calc_w]
    sub eax, 4
    mov [cvw], eax
    mov eax, [calc_h]
    sub eax, 82
    mov [cvh], eax
    mov byte [cvb], 0
    mov byte [chb], 0
    cmp dword [cvh], CALC_CH
    jge .a
    mov byte [cvb], 1
    sub dword [cvw], 16
.a: cmp dword [cvw], CALC_CW
    jge .b
    mov byte [chb], 1
    sub dword [cvh], 16
.b: cmp byte [cvb], 0
    jne .c
    cmp dword [cvh], CALC_CH
    jge .c
    mov byte [cvb], 1
    sub dword [cvw], 16
.c: mov eax, CALC_CH + 7
    sub eax, [cvh]
    jge .d1
    xor eax, eax
.d1:and eax, -8
    cmp [csy], eax
    jle .d2
    mov [csy], eax
.d2:mov eax, CALC_CW + 7
    sub eax, [cvw]
    jge .d3
    xor eax, eax
.d3:and eax, -8
    cmp [csx], eax
    jle .d4
    mov [csx], eax
.d4:popad
    ret

; Начало содержимого (с учётом прокрутки) в cw_x, cw_y и рамка видимой части для рисования
calc_org:
    mov eax, [calc_x0]
    sub eax, [csx]
    mov [cw_x], eax
    mov eax, [calc_y0]
    sub eax, [csy]
    mov [cw_y], eax
    mov eax, [calc_x0]
    add eax, 2
    mov [clp_x0], eax
    add eax, [cvw]
    mov [clp_x1], eax
    mov eax, [calc_y0]
    add eax, 80
    mov [clp_y0], eax
    add eax, [cvh]
    mov [clp_y1], eax
    ret

; Кнопка калькулятора ebx (номер), edi = 1 - нажата
calc_btn:
    pushad
    call calc_org
    imul ebx, 10
    add ebx, calc_tab
    movzx eax, word [ebx]
    movzx ecx, word [ebx + 4]
    movzx edx, word [ebx + 6]
    lea esi, [ebx + 8]
    movzx ebx, word [ebx + 2]
    call wbtn
    call mclip_off
    popad
    ret

; Окошко с числом
calc_disp:
    pushad
    call calc_org
    mov eax, [cw_x]
    add eax, 16
    mov [r_x], eax
    mov eax, [cw_y]
    add eax, 92
    mov [r_y], eax
    mov dword [r_w], 328
    mov dword [r_h], 60
    mov dword [r_c], C_BLACK
    call fill_rect
    add dword [r_x], 2
    add dword [r_y], 2
    mov dword [r_w], 324
    mov dword [r_h], 56
    mov dword [r_c], C_WHITE
    call fill_rect
    call calc_fmt
    mov esi, calc_buf
    call strlen
    shl ecx, 4
    mov eax, [cw_x]
    add eax, 332
    sub eax, ecx
    mov [t_x], eax
    mov eax, [cw_y]
    add eax, 106
    mov [t_y], eax
    mov dword [r_c], C_BLACK
    call draw_big
    call mclip_off
    popad
    ret

; Под мышью в калькуляторе: al = 71 крестик, 72 File, 73 Exit, 74 заголовок, 77, 78 полоски, 79 квадрат,
; 100+ кнопки, 0 - ничего (калькулятор открыт - остальное не нажимается)
calc_hit:
    mov esi, [m_x]
    sub esi, [calc_x0]
    mov edi, [m_y]
    sub edi, [calc_y0]
    cmp byte [calc_menu], 0
    je .nm
    cmp esi, 4
    jb .nm
    cmp esi, 236
    ja .nm
    cmp edi, 80
    jb .nm
    cmp edi, 124
    ja .nm
    mov al, 73
    ret
.nm:cmp byte [hp_on], 6              ; открытая справка
    jne .nhp
    cmp esi, 4
    jb .nhp
    mov eax, [hp_w]
    add eax, 4
    cmp esi, eax
    ja .nhp
    cmp edi, 80
    jb .nhp
    mov eax, [hp_h]
    add eax, 80
    cmp edi, eax
    ja .nhp
    mov al, 118
    ret
.nhp:cmp esi, 92                        ; кнопка Help
    jb .nh2
    mov eax, 172
    cmp byte [ui_ru], 0
    je .nbw
    add eax, 32
.nbw:cmp esi, eax
    ja .nh2
    cmp edi, 42
    jb .nh2
    cmp edi, 76
    ja .nh2
    mov al, 118
    ret
.nh2:test esi, esi
    jl .z
    test edi, edi
    jl .z
    mov eax, [calc_w]
    cmp esi, eax
    ja .z
    mov ebx, [calc_h]
    cmp edi, ebx
    ja .z
    sub eax, 18
    sub ebx, 18
    cmp edi, ebx
    jb .a
    cmp esi, eax
    jb .b
    mov al, 79
    ret
.a: cmp esi, eax
    jb .c
    cmp byte [cvb], 0
    je .c
    cmp edi, 80
    jb .c
    mov al, 77
    ret
.b: cmp byte [chb], 0
    je .c
    cmp esi, 2
    jb .c
    mov al, 78
    ret
.c: mov eax, [calc_w]
    sub eax, 32
    cmp esi, eax
    jb .d
    add eax, 24
    cmp esi, eax
    ja .d
    cmp edi, 8
    jb .d
    cmp edi, 30
    ja .d
    mov al, 71
    ret
.d: mov eax, [calc_w]
    sub eax, 36
    cmp esi, eax
    ja .e
    cmp esi, 4
    jb .e
    cmp edi, 2
    jb .e
    cmp edi, 36
    ja .e
    mov al, 74
    ret
.e: cmp esi, 4
    jb .f
    cmp esi, 84
    ja .f
    cmp edi, 40
    jb .f
    cmp edi, 76
    ja .f
    mov al, 72
    ret
.f: cmp edi, 80
    jb .z
    mov eax, [cvh]
    add eax, 80
    cmp edi, eax
    jae .z
    cmp esi, 2
    jb .z
    mov eax, [cvw]
    add eax, 2
    cmp esi, eax
    jae .z
    mov edx, esi
    add edx, [csx]
    mov ecx, edi
    add ecx, [csy]
    xor ebp, ebp
    mov ebx, calc_tab
.cl:movzx eax, word [ebx]
    cmp edx, eax
    jb .cn
    movzx esi, word [ebx + 4]
    add eax, esi
    cmp edx, eax
    jae .cn
    movzx eax, word [ebx + 2]
    cmp ecx, eax
    jb .cn
    movzx esi, word [ebx + 6]
    add eax, esi
    cmp ecx, eax
    jae .cn
    lea eax, [ebp + 100]
    ret
.cn:add ebx, 10
    inc ebp
    cmp ebx, calc_tab_end
    jb .cl
.z: xor al, al
    ret

; Нажали мышью кнопку калькулятора (al - номер 100+)
calc_press:
    sub al, 100
    mov [calc_pr], al
    movzx ebx, al
    mov edi, 1
    jmp calc_btn

; Отпустили: кнопка поднимается; если мышь всё ещё на ней - нажатие засчитано
calc_release:
    movzx ebx, byte [calc_pr]
    mov byte [calc_pr], 0xFF
    push ebx
    xor edi, edi
    call calc_btn
    pop ebx
    movzx eax, byte [t_id]
    sub eax, 100
    cmp eax, ebx
    jne .r
    imul ebx, 10
    mov al, [calc_tab + ebx + 8]
    call calc_do
    call calc_disp
    call calc_error_popup
.r: ret

; Клавиша в калькуляторе (al)
calc_key:
    pushad
    cmp al, 5                           ; Ctrl+E - выйти
    jne .k0
    popad
    jmp calc_exit
.k0:
    cmp al, 13
    jne .a
    mov al, '='
.a: cmp al, 8
    jne .b
    mov al, '<'
.b: cmp al, 27
    je .c
    cmp al, 'c'
    je .c
    cmp al, 'C'
    jne .d
.c: mov al, 'C'
.d: cmp al, '0'
    jb .e
    cmp al, '9'
    jbe .go
.e: cmp al, '.'
    je .go
    cmp al, '+'
    je .go
    cmp al, '-'
    je .go
    cmp al, '*'
    je .go
    cmp al, '/'
    je .go
    cmp al, '='
    je .go
    cmp al, '<'
    je .go
    cmp al, 'C'
    je .go
    cmp al, 32                          ; Error 5x1: неизвестный знак
    jb .r
    mov byte [calc_err], 1
    call calc_disp
    call calc_error_popup
    jmp .r
.go:call calc_do
    call calc_disp
    call calc_error_popup
.r: popad
    ret

; Число -> строка в calc_buf
calc_fmt:
    pushad
    mov edi, calc_buf
    cmp byte [calc_err], 0
    je .num
    mov esi, s_error
.ce:lodsb
    test al, al
    jz .ced
    stosb
    jmp .ce
.ced:
    mov al, [calc_err]
    add al, '0'
    stosb
    xor al, al
    stosb
    jmp .out
.num:
    mov eax, [calc_cur]
    test eax, eax
    jns .p
    mov byte [edi], '-'
    inc edi
    neg eax
.p: xor edx, edx
    mov ecx, 1000
    div ecx
    mov [calc_fr], edx
    xor ecx, ecx                        ; целая часть цифрами
    mov ebx, 10
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
    mov eax, [calc_fr]                  ; дробь: три цифры в calc_fd
    xor edx, edx
    mov ebx, 100
    div ebx
    add al, '0'
    mov [calc_fd], al
    mov eax, edx
    xor edx, edx
    mov ebx, 10
    div ebx
    add al, '0'
    mov [calc_fd + 1], al
    add dl, '0'
    mov [calc_fd + 2], dl
    cmp byte [calc_ent], 0
    je .res
    cmp byte [calc_dot], 0
    je .end
    mov byte [edi], '.'                 ; ввод с точкой: столько знаков, сколько набрали
    inc edi
    movzx ecx, byte [calc_dec]
    mov esi, calc_fd
    jecxz .end
    rep movsb
    jmp .end
.res:
    cmp dword [calc_fr], 0              ; результат: дробь без нулей на конце
    je .end
    mov byte [edi], '.'
    inc edi
    mov esi, calc_fd
    mov ecx, 3
    rep movsb
.tr:cmp byte [edi - 1], '0'
    jne .end
    dec edi
    jmp .tr
.end:
    mov byte [edi], 0
.out:
    popad
    ret

; Нажали кнопку калькулятора: al - символ
calc_do:
    pushad
    mov [calc_ch], al
    cmp byte [calc_err], 0
    je .ok
    cmp al, 'C'
    jne .out
.ok:
    cmp al, 'C'
    je .clear
    cmp al, '<'
    je .bs
    cmp al, '.'
    je .dot
    cmp al, '='
    je .eq
    cmp al, '0'
    jb .op
    cmp al, '9'
    jbe .dig
.op:
    cmp byte [calc_op], 0
    je .first
    cmp byte [calc_ent], 0
    je .setop
    call calc_apply
    jmp .after
.first:
    mov eax, [calc_cur]
    mov [calc_acc], eax
.after:
    cmp byte [calc_err], 0
    jne .out
    mov eax, [calc_acc]
    mov [calc_cur], eax
.setop:
    mov al, [calc_ch]
    mov [calc_op], al
    mov byte [calc_ent], 0
    jmp .out
.eq:
    cmp byte [calc_op], 0
    jne .eq1
    cmp byte [calc_ent], 0
    jne .out
    cmp dword [calc_cur], 0
    jne .out
    mov byte [calc_err], 2             ; Error 5x2: пустой пример
    jmp .out
.eq1:
    cmp byte [calc_ent], 0
    jne .doeq
    mov eax, [calc_acc]                 ; "5 + =" - второе число то же
    mov [calc_cur], eax
.doeq:
    call calc_apply
    cmp byte [calc_err], 0
    jne .out
    mov eax, [calc_acc]
    mov [calc_cur], eax
    mov byte [calc_op], 0
    mov byte [calc_ent], 0
    jmp .out
.clear:
    call calc_clear
    jmp .out
.dig:
    sub al, '0'
    mov [calc_d], al
    cmp byte [calc_ent], 0
    jne .e1
    call calc_fresh
.e1:
    cmp byte [calc_dot], 0
    jne .frac
    mov eax, [calc_cur]                 ; целая часть: до 6 цифр
    xor edx, edx
    mov ecx, 1000
    div ecx
    cmp eax, 99999
    ja .out
    imul eax, 10
    movzx ecx, byte [calc_d]
    add eax, ecx
    imul eax, 1000
    mov [calc_cur], eax
    jmp .out
.frac:
    movzx ecx, byte [calc_dec]
    cmp cl, 3
    jae .out
    mov ebx, [calc_pw + ecx * 4]
    movzx eax, byte [calc_d]
    mul ebx
    add [calc_cur], eax
    inc byte [calc_dec]
    jmp .out
.dot:
    cmp byte [calc_ent], 0
    jne .d1
    call calc_fresh
.d1:
    mov byte [calc_dot], 1
    jmp .out
.bs:
    cmp byte [calc_ent], 0
    je .out
    cmp byte [calc_dot], 0
    je .int
    cmp byte [calc_dec], 0
    jne .dd
    mov byte [calc_dot], 0
    jmp .out
.dd:
    dec byte [calc_dec]
    movzx ecx, byte [calc_dec]
    mov ebx, [calc_pw + ecx * 4]
    imul ebx, 10
    mov eax, [calc_cur]
    xor edx, edx
    div ebx
    mul ebx
    mov [calc_cur], eax
    jmp .out
.int:
    mov eax, [calc_cur]
    xor edx, edx
    mov ecx, 10000
    div ecx
    imul eax, 1000
    mov [calc_cur], eax
.out:
    popad
    ret

calc_fresh:
    mov dword [calc_cur], 0
    mov byte [calc_dot], 0
    mov byte [calc_dec], 0
    mov byte [calc_ent], 1
    ret

; acc = acc (op) cur. Ошибка (переполнение, деление на 0) - calc_err = 1
calc_apply:
    pushad
    mov eax, [calc_acc]
    mov ebx, [calc_cur]
    mov cl, [calc_op]
    cmp cl, '+'
    je .add
    cmp cl, '-'
    je .sub
    cmp cl, '*'
    je .mul
    test ebx, ebx                       ; деление
    jz .dz
    mov ecx, 1000
    imul ecx
    mov esi, edx
    test esi, esi
    jns .a1
    neg esi
.a1:
    add esi, esi
    add esi, 2
    mov edi, ebx
    test edi, edi
    jns .a2
    neg edi
.a2:
    cmp esi, edi
    ja .err
    idiv ebx
    jmp .store
.add:
    add eax, ebx
    jo .err
    jmp .store
.sub:
    sub eax, ebx
    jo .err
    jmp .store
.mul:
    imul ebx
    cmp edx, -500
    jl .err
    cmp edx, 499
    jg .err
    mov ecx, 1000
    idiv ecx
.store:
    mov [calc_acc], eax
    jmp .out
.dz:
    mov byte [calc_err], 3             ; Error 5x3: деление на ноль
    jmp .out
.err:
    mov byte [calc_err], 4             ; Error 5x4: число слишком большое
.out:
    popad
    ret



; данные калькулятора
; Кнопки (x, y, ширина, высота, символ)
calc_tab:
    dw 16, 164, 76, 48
    db 'C', 0
    dw 100, 164, 76, 48
    db '<', 0
    dw 184, 164, 76, 48
    db '/', 0
    dw 268, 164, 76, 48
    db '*', 0
    dw 16, 220, 76, 48
    db '7', 0
    dw 100, 220, 76, 48
    db '8', 0
    dw 184, 220, 76, 48
    db '9', 0
    dw 268, 220, 76, 48
    db '-', 0
    dw 16, 276, 76, 48
    db '4', 0
    dw 100, 276, 76, 48
    db '5', 0
    dw 184, 276, 76, 48
    db '6', 0
    dw 268, 276, 76, 48
    db '+', 0
    dw 16, 332, 76, 48
    db '1', 0
    dw 100, 332, 76, 48
    db '2', 0
    dw 184, 332, 76, 48
    db '3', 0
    dw 268, 332, 76, 104
    db '=', 0
    dw 16, 388, 160, 48
    db '0', 0
    dw 184, 388, 76, 48
    db '.', 0
calc_tab_end:

calc_pw          dd 100, 10, 1
calc_cur         dd 0
calc_acc         dd 0
calc_fr          dd 0
calc_fd          db 0, 0, 0, 0
calc_op          db 0
calc_ent         db 0
calc_dot         db 0
calc_dec         db 0
calc_err         db 0
calc_ch          db 0
calc_d           db 0
calc_buf         times 20 db 0
s_flocalc        db "FloCalc", 0

; Show shared kernel dialog instead of standalone FloCalc error code string.
calc_error_popup:
    mov al, [calc_err]
    test al, al
    jz .done
    cmp al, 4
    ja .done
    add al, 0x50
    call core_err_raise
.done: ret
