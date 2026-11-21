; Floppy_156: FSM3 damaged-volume warning. Only invoked by UI main loop
; (not boot/interrupt). Does not change disk data. Enter returns desktop.
fs3_alert_draw:
    pushad
    call mclip_off
    mov dword [cw_x], 0
    mov dword [cw_y], 0
    RECT 0, 0, 800, 600, C_BLACK
    call pn_logo                      ; blue floppy icon from panic.asm
    mov dword [r_c], C_WHITE
    mov esi, fs3a_t1
    mov ecx, 290
    call pn_line
    mov esi, fs3a_t2
    mov ecx, 330
    call pn_line
    mov esi, fs3a_t3
    mov ecx, 370
    call pn_line
    mov esi, fs3a_t4
    mov ecx, 420
    call pn_line
    mov esi, fs3a_t5
    mov ecx, 470
    call pn_line
    popad
    ret

fs3a_t1 db "Floppy OS - FSM3 disk error", 0
fs3a_t2 db "Damaged file system or read error", 0
fs3a_t3 db "Writing to this disk is blocked", 0
fs3a_t4 db "Check a copy of the disk image", 0
fs3a_t5 db "Press Enter to return to desktop", 0
fs3_alert_pending db 0
fs3_alert_active db 0
fs3_alert_ready db 0
fs3_seen db 0
