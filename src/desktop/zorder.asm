; Порядок окон: полноэкранное приложение (FloFile, FloText, FloPaint), открытое последним,
; оказывается сверху и получает клавиши; прежнее прячется и возвращается, когда верхнее закроют.
; Подключается из kernel32.asm (%include)

; Номера приложений: 1 - FloFile, 2 - FloText, 3 - FloPaint

; Приложение al открывают: остальные открытые прячутся (флаг гасим, номер кладём в стопку)
z_hide_others:
    pushad
    mov byte [hp_on], 0
    movzx ebp, al
    ; Keep the window layer from the previous screen. Fullscreen apps
    ; cover ALL previously visible ordinary windows without closing them.
    ; Window launches from the app can reveal just their own window via
    ; fz_top; on return the previous layer is restored.
    call z_remove                      ; AL is still the fullscreen app ID
    mov eax, [z_fz_hidden_mask]
    mov [z_fz_prev_mask + ebp * 4], eax
    mov dword [z_fz_hidden_mask], 0x3FE ; floating IDs 1..9 are covered
    mov ebx, 1
.l: cmp ebx, ebp
    je .n
    mov esi, [z_flags + ebx * 4]
    cmp byte [esi], 0
    je .n
    mov byte [esi], 0
    movzx ecx, byte [z_n]
    mov [z_stk + ecx], bl
    inc byte [z_n]
.n: inc ebx
    cmp ebx, 6
    jb .l
    mov byte [calc_foc], 0              ; клавиши - новому приложению
    popad
    ret

; Приложение al закрыли (флаг уже погашен): если сверху никого нет - вернуть спрятанное
z_restore:
    pushad
    ; Recover the visibility layer saved when this fullscreen app opened.
    movzx ebp, al
    call z_remove                      ; must use incoming app ID, not saved mask
    mov eax, [z_fz_prev_mask + ebp * 4]
    mov [z_fz_hidden_mask], eax
    cmp byte [d2_files], 0
    jne .r
    cmp byte [d2_text], 0
    jne .r
    cmp byte [d2_paint], 0
    jne .r
    cmp byte [d2_boil], 0
    jne .r
    cmp byte [d2_itge], 0
    jne .r
    cmp byte [z_n], 0
    je .r
    dec byte [z_n]
    movzx eax, byte [z_n]
    movzx eax, byte [z_stk + eax]
    mov esi, [z_flags + eax * 4]
    mov byte [esi], 1
.r: popad
    ret

; Убрать приложение al из стопки (если оно там есть)
z_remove:
    pushad
    xor ecx, ecx
.f: cmp cl, [z_n]
    jae .r
    cmp [z_stk + ecx], al
    je .d
    inc ecx
    jmp .f
.d: inc ecx
    cmp cl, [z_n]
    jae .e
    mov dl, [z_stk + ecx]
    mov [z_stk + ecx - 1], dl
    jmp .d
.e: dec byte [z_n]
.r: popad
    ret

; Приложение al спрятано? CF = 1 - да
z_has:
    push ecx
    xor ecx, ecx
.f: cmp cl, [z_n]
    jae .no
    cmp [z_stk + ecx], al
    je .yes
    inc ecx
    jmp .f
.yes:
    pop ecx
    stc
    ret
.no:pop ecx
    clc
    ret

z_n         db 0
z_stk       times 6 db 0
z_flags     dd 0, d2_files, d2_text, d2_paint, d2_boil, d2_itge
; Visibility of the normal-window layer while a fullscreen app is active.
; Bit IDs match fz_ord. Do NOT change d2_main/d2_* open flags.
z_fz_hidden_mask dd 0
z_fz_prev_mask   times 6 dd 0
