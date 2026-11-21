 ; Unified Z-order of every non-modal window that can be shown in a small size.
; 1 About, 2 Settings, 3 Clock, 4 Terminal, 5 Disks,
; 6 Main, 7 FloCalc, 8 FloCalendar, 9 FloTasks. Bottom -> top.
; Existing windows keep their d2_* state and stack order when a full app
; temporarily covers them. The hidden mask is maintained in zorder.asm.
fz_ord  db 6, 7, 8, 9, 5, 1, 2, 3, 4
fz_flag dd 0, d2_ab, d2_st, d2_ck, d2_tr, d2_dk, d2_main, d2_calc, d2_cal, d2_tm
fz_drw  dd 0, ab_draw, st_draw, ck_draw, tr_draw, dk_draw, main_show, calc_draw, cal_draw, tm_draw
fz_hts  dd 0, ab_hit, st_hit, ck_hit, tr_hit, fz_dkh, 0, 0, cal_hit, tm_hit
fz_hown db 0                           ; window that owns the current mouse hit
fz_key_owner db 0                       ; last keyboard focus from Z-order

; Disks: CF = 1, если мышь в окне (al - что под ней, 0 - ничего)
fz_dkh:
    mov eax, [m_x]
    sub eax, [dk_x]
    js .n
    cmp eax, [dk_w]
    ja .n
    mov eax, [m_y]
    sub eax, [dk_y]
    js .n
    cmp eax, [dk_h]
    ja .n
    call dk_hit
    stc
    ret
.n: clc
    ret

fz_draw:
    pushad
    xor ecx, ecx
.l: movzx eax, byte [fz_ord + ecx]
    mov esi, [fz_flag + eax * 4]
    cmp byte [esi], 0
    je .n
    bt dword [z_fz_hidden_mask], eax
    jc .n                                ; covered by a fullscreen app
    push ecx
    push eax
    call [fz_drw + eax * 4]
    pop edx
    cmp dl, 6                         ; Main has its own legacy minus button
    jne .not_main
    xor dl, dl
    call mn_fdraw
    jmp .after_min
.not_main:
    cmp dl, 5
    ja .after_min                    ; calc/calendar/tasks use their own title controls
    call mn_fdraw
.after_min:
    pop ecx
.n: inc ecx
    cmp ecx, 9
    jb .l
    popad
    ret

; Geometry for FloCalc: unlike other windows calc_hit does not return CF.
fz_calc_inside:
    mov eax, [m_x]
    sub eax, [calc_x0]
    js .no
    cmp eax, [calc_w]
    ja .no
    mov eax, [m_y]
    sub eax, [calc_y0]
    js .no
    cmp eax, [calc_h]
    ja .no
    stc
    ret
.no:clc
    ret

; Returns CF=1 for the TOPMOST window under the mouse; its identity is
; fz_hown even when no control is under the pointer (AL=0).
fz_hit:
    push ebx
    push ecx
    push edx
    mov byte [fz_hown], 0
    mov ebx, 8
.l: movzx eax, byte [fz_ord + ebx]
    mov esi, [fz_flag + eax * 4]
    cmp byte [esi], 0
    je .n
    bt dword [z_fz_hidden_mask], eax
    jc .n                                ; covered windows cannot receive clicks
    cmp al, 6
    je .main
    cmp al, 7
    je .calc
    push ebx
    call [fz_hts + eax * 4]
    pop ebx
    jc .found
    jmp .n
.main:
    call mz_inside
    jnc .n
    xor al, al
    stc
    jmp .found
.calc:
    call fz_calc_inside
    jnc .n
    push ebx
    push ebp
    call calc_hit
    pop ebp
    pop ebx
    mov byte [t_own], 1
    stc
.found:
    mov dl, [fz_ord + ebx]
    mov [fz_hown], dl
    pop edx
    pop ecx
    pop ebx
    stc
    ret
.n: dec ebx
    jns .l
    pop edx
    pop ecx
    pop ebx
    clc
    ret

; AL = ID of topmost visible window, or zero if none.
fz_active:
    push ecx
    push esi
    mov ecx, 8
.loop:
    movzx eax, byte [fz_ord + ecx]
    mov esi, [fz_flag + eax * 4]
    cmp byte [esi], 0
    je .next
    bt dword [z_fz_hidden_mask], eax
    jnc .ret
.next:
    dec ecx
    jns .loop
    xor eax, eax
.ret:
    pop esi
    pop ecx
    ret

; Ctrl+E: close the topmost window that supports this shortcut.
fz_exit_top:
    mov ebx, 8
.l: movzx eax, byte [fz_ord + ebx]
    mov esi, [fz_flag + eax * 4]
    cmp byte [esi], 0
    je .n
    bt dword [z_fz_hidden_mask], eax
    jc .n                                ; cannot close a covered window
    cmp al, 1
    je .ab
    cmp al, 2
    je .st
    cmp al, 3
    je .ck
    ; Do not close an About/Clock behind an unrelated active window.
    cmp al, 4
    je .other
    cmp al, 5
    je .other
    cmp al, 6
    je .other
    cmp al, 7
    je .other
    cmp al, 8
    je .other
    cmp al, 9
    je .other
.n: dec ebx
    jns .l
    ret
.other:
    mov esi, [fz_flag + eax * 4]
    cmp byte [esi], 0
    jne .return
    jmp .n
.return:
    ret
.ab:cmp byte [d2_ab], 0
    je .n
    jmp ab_exit
.st:cmp byte [d2_st], 0
    je .n
    jmp st_exit
.ck:cmp byte [d2_ck], 0
    je .n
    jmp ck_exit

 ; Open or focus window DL (1..9) in the same ordered stack.
fz_top:
    pushad
    mov byte [mz_top], 0               ; compatibility with old minimize state
    xor ecx, ecx
.find:
    cmp [fz_ord + ecx], dl
    je .shift
    inc ecx
    cmp ecx, 9
    jb .find
    jmp .done                          ; invalid ID: no out-of-range search
.shift:
    cmp ecx, 8
    jae .put
    mov al, [fz_ord + ecx + 1]
    mov [fz_ord + ecx], al
    inc ecx
    jmp .shift
.put:
    mov [fz_ord + 8], dl
    ; Bringing a window to front during a fullscreen app explicitly
    ; reveals only that window; old windows remain covered.
    movzx ecx, dl
    btr dword [z_fz_hidden_mask], ecx
    ; Keep old keyboard focus flags in agreement with active window.
    mov byte [calc_foc], 0
    mov byte [tr_foc], 0
    cmp dl, 7
    jne .notcalc
    mov byte [calc_foc], 1
.notcalc:
    cmp dl, 4
    jne .done
    mov byte [tr_foc], 1
.done:
    popad
    ret

; Called from separately assembled FloCalc/FloCalendar modules (append-only KAPI).
fz_open_window:
    jmp fz_top

fz_front:
    cmp [fz_ord + 8], dl
    jne .raise
    movzx eax, dl
    bt dword [z_fz_hidden_mask], eax
    jnc .r                             ; already topmost AND actually visible
.raise:
    call fz_top
    jmp redraw
.r: ret

; Legacy flag used by a few older controls; Z-order now lives in fz_ord.
mz_top db 0

; CF=1 if the pointer is in Main.
mz_inside:
    push eax
    push esi
    cmp byte [d2_main], 0
    je .no
    mov esi, [m_x]
    sub esi, [mx0]
    js .no
    mov eax, [mw]
    add eax, 4
    cmp esi, eax
    ja .no
    mov esi, [m_y]
    sub esi, [my0]
    js .no
    mov eax, [mh]
    add eax, 4
    cmp esi, eax
    ja .no
    pop esi
    pop eax
    stc
    ret
.no:pop esi
    pop eax
    clc
    ret

mz_raise:
    mov dl, 6
    jmp fz_front

; Часы можно обновлять поверх остальных, только если над ними нет открытого окна. CF = 1 - над часами что-то есть
fz_over_ck:
    push eax
    push ecx
    push esi
    ; Clock's direct tick redraw must not paint over a fullscreen app.
    bt dword [z_fz_hidden_mask], 3
    jc .yes
    mov ecx, 8
.l: movzx eax, byte [fz_ord + ecx]
    cmp eax, 3
    je .no
    mov esi, [fz_flag + eax * 4]
    cmp byte [esi], 0
    jne .yes
    dec ecx
    jns .l
.no:pop esi
    pop ecx
    pop eax
    clc
    ret
.yes:
    pop esi
    pop ecx
    pop eax
    stc
    ret
