; Floppy OS 2.0: minimal startup screen, 800x600 VGA.
; The logo is the original 32x32 ab_pic from About (unchanged pixels).
; Only the STARTUP screen is simplified; the shutdown screen below is unchanged.

bs_start:
    pushad
    call bs_draw
    popad
    ret

; Legacy entry point: no visible progress bar on the minimal startup screen.
bs_progress:
    ret

; Minimal startup: solid blue, 64x64 original logo, small system-font title.
bs_draw:
    pushad
    mov dword [r_fn], 0
    RECT 0, 0, 800, 600, C_BLUE

    ; Original About logo (ab_pic), 32x32 pixels at 2x scale = 64x64.
    ; Bottom-left: x=28..91, y=508..571 (28 px bottom margin).
    xor ebp, ebp
.logo_row:
    xor ebx, ebx
.logo_col:
    mov eax, ebp
    shl eax, 5
    add eax, ebx
    movzx edx, byte [ab_pic + eax]
    mov dword [r_c], C_BLACK
    cmp dl, 'B'
    jne .notblue
    mov dword [r_c], C_BLUE
.notblue:
    cmp dl, 'G'
    jne .notgray
    mov dword [r_c], C_GRAY
.notgray:
    cmp dl, 'W'
    jne .notwhite
    mov dword [r_c], C_WHITE
.notwhite:
    lea eax, [ebx * 2 + 28]
    mov [r_x], eax
    lea eax, [ebp * 2 + 508]
    mov [r_y], eax
    mov dword [r_w], 2
    mov dword [r_h], 2
    call fill_rect
    inc ebx
    cmp ebx, 32
    jb .logo_col
    inc ebp
    cmp ebp, 32
    jb .logo_row

    ; Small built-in VGA font (8x16), aligned with logo center.
    mov dword [r_c], C_WHITE
    mov dword [t_x], 112
    mov dword [t_y], 532
    mov esi, bs_title
    call egg_line

    ; Large centered loading text.
    mov esi, bs_loading_text
    call strlen
    shl ecx, 4                           ; draw_big font = 16 px/char
    mov eax, 800
    sub eax, ecx
    shr eax, 1
    mov [t_x], eax
    mov dword [t_y], 292
    mov dword [r_c], C_WHITE
    mov esi, bs_loading_text
    call draw_big

    popad
    ret

; Keep the original ~4 second startup wait, but draw no progress indicator.
; Timer IRQ is 18.2 Hz; 73 ticks = about four seconds.
bs_finish:
    pushad
    call bs_draw
    mov eax, [ticks]
    mov [bs_t0], eax
.tick:
    mov eax, [ticks]
    sub eax, [bs_t0]
    cmp eax, 73
    jae .done
    hlt
    jmp .tick
.done:
    popad
    ret

; Separate shutdown screen: plain blue, About floppy in upper-right,
; large centered text, and the native clock cursor while timer is running.
; At 18.2 Hz, 28 IRQ ticks is at least 1.5 seconds.
bs_shutdown:
    pushad
    call cursor_hide                     ; remove previous cursor before repainting
    mov dword [r_fn], 0
    RECT 0, 0, 800, 600, C_BLUE

    ; The same 32x32 pixel matrix as the About logo, at native 2x scale.
    xor ebp, ebp
.logo_row:
    xor ebx, ebx
.logo_col:
    mov eax, ebp
    shl eax, 5
    add eax, ebx
    movzx edx, byte [ab_pic + eax]
    mov dword [r_c], C_BLACK
    cmp dl, 'B'
    jne .notblue
    mov dword [r_c], C_BLUE
.notblue:
    cmp dl, 'G'
    jne .notgray
    mov dword [r_c], C_GRAY
.notgray:
    cmp dl, 'W'
    jne .notwhite
    mov dword [r_c], C_WHITE
.notwhite:
    lea eax, [ebx * 2 + 720]
    mov [r_x], eax
    lea eax, [ebp * 2 + 16]
    mov [r_y], eax
    mov dword [r_w], 2
    mov dword [r_h], 2
    call fill_rect
    inc ebx
    cmp ebx, 32
    jb .logo_col
    inc ebp
    cmp ebp, 32
    jb .logo_row

    mov esi, bs_stop_text
    call strlen
    shl ecx, 4                           ; native draw_big font = 16 px/char
    mov eax, 800
    sub eax, ecx
    shr eax, 1
    mov [t_x], eax
    mov dword [t_y], 285
    mov dword [r_c], C_WHITE
    mov esi, bs_stop_text
    call draw_big

    ; Existing clock cursor (cu_kind=4), use the mouse coordinates from IRQs.
    mov byte [cu_kind], 4
    mov byte [cu_busy], 1                ; enables cu_pump updates
    mov eax, [m_x]
    mov [cp_x], eax
    mov eax, [m_y]
    mov [cp_y], eax
    call cursor_show
    mov eax, [ticks]
    mov [bs_t0], eax
.wait:
    mov eax, [ticks]
    sub eax, [bs_t0]
    cmp eax, 28
    jae .done
    hlt
    call cu_pump
    jmp .wait
.done:
    call cursor_hide
    mov byte [cu_busy], 0
    popad
    ret

bs_t0         dd 0
bs_title        db 'Floppy OS 2.0',0
bs_loading_text db 'Loading...',0
bs_stop_text    db 'Shutting down...',0
