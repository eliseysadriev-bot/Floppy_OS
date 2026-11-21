; Кнопка File и меню с пунктом Exit у плавающих окон Clock и Terminal
; Окно задаёт начало в wm_x, wm_y. Кнопка File: x 4..84, y 44..78. Меню: x 4..236, y 84..128.
; Подключается из kernel32.asm (%include)

; Прямоугольник относительно окна: eax, ebx - угол, ecx, edx - размер, цвет в r_c
wm_box:
    add eax, [wm_x]
    add ebx, [wm_y]
    mov [r_x], eax
    mov [r_y], ebx
    mov [r_w], ecx
    mov [r_h], edx
    jmp fill_rect

; Кнопка File у окна с началом eax, ebx: edi = 1 - меню открыто (кнопка чёрная, надпись белая)
wm_file:
    pushad
    mov [wm_x], eax
    mov [wm_y], ebx
    mov dword [r_c], C_BLACK
    mov eax, 4
    mov ebx, 44
    mov ecx, 80
    mov edx, 34
    call wm_box
    mov dword [r_c], C_WHITE
    test edi, edi
    jnz .t
    mov eax, 6
    mov ebx, 46
    mov ecx, 76
    mov edx, 30
    call wm_box
    mov dword [r_c], C_BLACK
.t: mov eax, [wm_x]
    add eax, 12
    mov [t_x], eax
    mov eax, [wm_y]
    add eax, 48
    mov [t_y], eax
    mov esi, s_wm_file
    call draw_big
    popad
    ret

; Меню File (пункт Exit) у окна с началом eax, ebx
wm_menu:
    pushad
    mov [wm_x], eax
    mov [wm_y], ebx
    mov dword [r_c], C_BLACK
    mov eax, 8
    mov ebx, 88
    mov ecx, 232
    mov edx, 44
    call wm_box
    mov eax, 4
    mov ebx, 84
    call wm_box
    mov dword [r_c], C_WHITE
    mov eax, 6
    mov ebx, 86
    mov ecx, 228
    mov edx, 40
    call wm_box
    mov dword [r_c], C_BLACK
    mov eax, [wm_x]
    add eax, 12
    mov [t_x], eax
    mov eax, [wm_y]
    add eax, 90
    mov [t_y], eax
    mov esi, s_wm_exit
    call draw_big
    mov eax, [wm_x]
    add eax, 92
    mov [t_x], eax
    mov esi, s_wm_key
    call draw_big
    popad
    ret

; Мышь над кнопкой File или пунктом меню? esi, edi - мышь относительно окна, dl - открыто ли меню
; Результат: al = 1 File, 2 Exit, 0 - ни то ни другое
wm_hit:
    xor eax, eax
    cmp esi, 4
    jb .r
    cmp edi, 44
    jb .r
    cmp esi, 84
    ja .m
    cmp edi, 78
    ja .m
    mov al, 1
    ret
.m: test dl, dl
    jz .r
    cmp esi, 236
    ja .r
    cmp edi, 84
    jb .r
    cmp edi, 128
    ja .r
    mov al, 2
.r: ret

wm_x        dd 0
wm_y        dd 0
s_wm_file   db "File", 0
s_wm_exit   db "Exit", 0
s_wm_key    db "Ctrl + E", 0

; System dialogs reuse the exact same File/Exit menu as About/Settings.
; Inputs for sys_file_draw: EAX left, EBX top, ECX full window width, DL=0/1.
; Draw the native black separator at y+80 below File, matching About/Settings.
; Inputs for sys_file_hit: ESI/EDI mouse relative to window, DL=0/1.
; Return: AL=193 File, 194 Exit, or 0 for other positions.
sys_file_draw:
    pushad
    ; The native second separator is below the File row (y=44..78).
    ; Save all arguments for the File button drawing after fill_rect.
    pushad
    lea esi, [eax + 2]
    mov [r_x], esi
    lea esi, [ebx + 80]
    mov [r_y], esi
    lea esi, [ecx - 4]
    mov [r_w], esi
    mov dword [r_h], 2
    mov dword [r_c], C_BLACK
    call fill_rect
    popad
    movzx edi, dl
    call wm_file
    test dl, dl
    jz .done
    call wm_menu
.done:
    popad
    ret

sys_file_hit:
    call wm_hit
    test al, al
    jz .done
    add al, 192
.done:
    ret

; Center 16x32 system text (same draw_big as original windows).
; Input: EAX absolute left, EBX absolute y, EDX window width, ESI NUL text.
sys_modal_center:
    pushad
    mov ebp, eax
    mov edi, edx
    call strlen
    shl ecx, 4
    sub edi, ecx
    sar edi, 1
    add edi, ebp
    mov [t_x], edi
    mov [t_y], ebx
    mov dword [r_c], C_BLACK
    call draw_big
    popad
    ret

sys_title_text db "System", 0
