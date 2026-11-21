; Окно welcome на весь экран: приветствие, логотип дискета, версия и дата создания.
; Показывается при входе. Галочка сохраняется в существующем секторе Settings.
; Подключается из kernel32.asm (%include)

d2_wl   db 0
wl_chk  db 0
wl_pr   db 0
sys_dsk db 0                            ; диск, где стоит система: 0 - C, 1 - O, 2 - I

; Welcome preference lives in the existing Settings sector (ST_SECT,
; offset 11). No FLOPSYS/welcome or FLOWIN/welcome is created.
; Read old flags once for compatibility, without deleting existing data.
wl_hidden db 0

wl_check:
    pushad
    cmp byte [d2_ist], 0
    jne .done
    cmp byte [wl_hidden], 0
    jne .done
    movzx eax, byte [sys_dsk]
    call fs_setdisk
    jc .show
    mov byte [fs_par], 0
    mov esi, si_flopsys
    call dir_find
    jc .show
    call dir_last_id
    mov [fs_par], al
    mov [wl_rootid], al
    ; Legacy location #1: FLOPSYS/welcome, read only.
    mov esi, wl_fn
    call dir_find
    jnc .read_pref
    ; Legacy location #2: FLOPSYS/FLOWIN/welcome, read only.
    mov esi, wl_dn
    call dir_find
    jc .show
    call dir_last_id
    mov [fs_par], al
    mov esi, wl_fn
    call dir_find
    jc .show
.read_pref:
    mov esi, wl_fn
    call file_read
    jc .show
    cmp byte [DATA_BUF], '0'
    jne .show
    mov byte [wl_hidden], 1
    call st_save                  ; persist in Settings, NOT in a file
    jmp .done
.show:
    mov byte [wl_chk], 0
    mov byte [d2_wl], 1
.done:
    mov byte [fs_par], 0
    popad
    ret

; OK (or Enter). Only save if the checkbox was selected.
wl_ok:
    cmp byte [wl_chk], 0
    je .close
    mov byte [wl_hidden], 1
    call st_save
.close:
    mov byte [d2_wl], 0
    jmp redraw

; Что под мышью: 25 - OK, 26 - галочка и её надпись
wl_hit:
    xor eax, eax
    cmp edx, 320
    jb .c
    cmp edx, 480
    ja .c
    cmp ecx, 490
    jb .c
    cmp ecx, 534
    ja .c
    mov al, 25
    ret
.c: cmp edx, 260
    jb .r
    cmp edx, 560
    ja .r
    cmp ecx, 416
    jb .r
    cmp ecx, 456
    ja .r
    mov al, 26
.r: ret

wl_press:
    cmp al, 25
    jne .n25
    mov byte [wl_pr], 1                 ; кнопка вдавилась, нажатие засчитается при отпускании над ней
    jmp redraw
.n25:
    cmp al, 26
    jne .r
    xor byte [wl_chk], 1
    jmp redraw
.r: ret

; Кнопку мыши отпустили
wl_release:
    cmp byte [wl_pr], 0
    je .r
    mov byte [wl_pr], 0
    cmp byte [t_id], 25
    je wl_ok
    jmp redraw
.r: ret

; Enter - OK, пробел - галочка
wl_key:
    cmp al, 13
    je wl_ok
    cmp al, 32
    jne .r
    xor byte [wl_chk], 1
    call redraw
.r: ret

wl_draw:
    pushad
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    RECT 0, 0, 800, 600, C_WHITE
    RECT 0, 0, 800, 6, C_BLACK
    RECT 0, 594, 800, 6, C_BLACK
    RECT 0, 0, 6, 600, C_BLACK
    RECT 794, 0, 6, 600, C_BLACK
    call wl_logo
    mov dword [r_c], C_BLACK
    mov dword [t_x], 232
    mov dword [t_y], 250
    mov esi, wl_t1
    call draw_big
    mov dword [t_x], 312
    mov dword [t_y], 304
    mov esi, wl_t2
    call draw_big
    mov dword [t_x], 264
    mov dword [t_y], 344
    mov esi, wl_t3
    call draw_big
    RECT 264, 420, 36, 36, C_BLACK          ; галочка
    RECT 267, 423, 30, 30, C_WHITE
    cmp byte [wl_chk], 0
    je .nc
    RECT 272, 428, 20, 20, C_BLACK
.nc:mov dword [r_c], C_BLACK
    mov dword [t_x], 312
    mov dword [t_y], 421
    mov esi, wl_t4
    call draw_big
    RECT 320, 490, 160, 44, C_BLACK         ; кнопка OK: белая с чёрной обводкой, при нажатии чёрная
    cmp byte [wl_pr], 0
    jne .pr
    RECT 324, 494, 152, 36, C_WHITE
    mov dword [r_c], C_BLACK
    jmp .ok
.pr:mov dword [r_c], C_WHITE
.ok:mov dword [t_x], 384
    mov dword [t_y], 496
    mov esi, wl_t5
    call draw_big
    popad
    ret

; Логотип: тот же рисунок 32x32, что в окне About (ab_pic), каждая точка 6x6
wl_logo:
    pushad
    xor ebp, ebp                        ; строка
.row:
    xor ebx, ebx                        ; колонка
.col:
    mov eax, ebp
    shl eax, 5
    add eax, ebx
    movzx edx, byte [ab_pic + eax]
    mov esi, C_BLACK
    cmp dl, 'B'
    jne .nb
    mov esi, C_BLUE
.nb:cmp dl, 'G'
    jne .ng
    mov esi, 7
.ng:cmp dl, 'W'
    jne .nw
    mov esi, C_WHITE
.nw:mov [r_c], esi
    mov eax, ebx
    imul eax, 6
    add eax, 304
    mov [r_x], eax
    mov eax, ebp
    imul eax, 6
    add eax, 44
    mov [r_y], eax
    mov dword [r_w], 6
    mov dword [r_h], 6
    call fill_rect
    inc ebx
    cmp ebx, 32
    jb .col
    inc ebp
    cmp ebp, 32
    jb .row
    popad
    ret

wl_rootid db 0
wl_dn   db "flowin", 0   ; legacy preference read only
wl_fn   db "welcome", 0
wl_t1   db "Welcome to Floppy 1.1", 0
wl_t2   db "Version 1.1", 0
wl_t3   db "Created 11.10.26", 0
wl_t4   db "Don't show again", 0
wl_t5   db "OK", 0
