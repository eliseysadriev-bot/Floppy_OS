; Меню загрузки: загрузчик читает ядро и вызывает это место (call far 0x2F40:0) ещё в 16 битах.
; Стрелками выбирают, Enter - загрузить. Пункты: Floppy 1.1, Floppy 1.1 на дисках O и I (если его туда установили), MS-DOS (4-й диск, 0x83).
times 0x1F400 - ($ - $$) db 0
bits 16
bm_base:
%define BM(x) ((x) - bm_base)
    push ds
    push es
    xor ax, ax
    mov es, ax
    mov [es:0x4F1], dl                  ; ядру: с какого диска загрузились
    cmp byte [es:0x4F0], 0xA5           ; нас запустили из этого меню с другого диска - меню уже было
    jne .menu
    mov byte [es:0x4F0], 0
    jmp .floppy
.menu:
    mov ax, cs
    mov ds, ax
    cld
    mov byte [BM(bm_n)], 1              ; список пунктов
    mov byte [BM(bm_drv)], 0
    mov word [BM(bm_items)], BM(bm_i1)
    mov dl, 0x81
.fd:mov dword [BM(bm_dap) + 8], 313     ; на диске стоит Floppy, если в секторе 313 есть FloFile (FSYS)
    mov word [BM(bm_dap) + 4], 0x7E00
    mov si, BM(bm_dap)
    mov ah, 0x42
    push dx
    int 0x13
    pop dx
    jc .nf
    cmp dword [es:0x7E00], 'FSYS'
    jne .nf
    movzx bx, byte [BM(bm_n)]
    mov [BM(bm_drv) + bx], dl
    shl bx, 1
    mov word [BM(bm_items) + bx], BM(bm_i2)
    cmp dl, 0x81
    je .o
    mov word [BM(bm_items) + bx], BM(bm_i3)
.o: inc byte [BM(bm_n)]
.nf:inc dl
    cmp dl, 0x83
    jb .fd
    movzx bx, byte [BM(bm_n)]
    mov byte [BM(bm_drv) + bx], 0x83
    shl bx, 1
    mov word [BM(bm_items) + bx], BM(bm_id)
    inc byte [BM(bm_n)]
    mov ax, 0xB800
    mov es, ax
    mov ah, 1                           ; спрятать мигающий курсор
    mov cx, 0x2000
    int 0x10
.draw:
    call bm_paint
.key:
    xor ax, ax
    int 0x16
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .dn
    cmp al, 13
    jne .key
    movzx bx, byte [BM(bm_sel)]
    mov dl, [BM(bm_drv) + bx]
    test dl, dl
    jz .floppy
    mov dword [BM(bm_dap) + 8], 0       ; первый сектор выбранного диска прямо на 0x7C00
    mov word [BM(bm_dap) + 4], 0x7C00
    mov si, BM(bm_dap)
    mov ah, 0x42
    push dx
    int 0x13
    pop dx
    jc .nodos
    xor ax, ax
    mov es, ax
    cmp dl, 0x83
    je .dos
    mov byte [es:0x4F0], 0xA5           ; Floppy на другом диске: второй раз меню не показывать
    jmp .go
.dos:
    mov ax, 3                           ; обычный текстовый экран для DOS
    push dx
    int 0x10
    pop dx
.go:xor ax, ax
    mov ds, ax
    mov es, ax
    jmp 0x0000:0x7C00
.nodos:
    mov byte [BM(bm_err)], 1
    jmp .draw
.up:cmp byte [BM(bm_sel)], 0
    je .key
    dec byte [BM(bm_sel)]
    jmp .draw
.dn:mov al, [BM(bm_sel)]
    inc al
    cmp al, [BM(bm_n)]
    jae .key
    mov [BM(bm_sel)], al
    jmp .draw
.floppy:
    pop es
    pop ds
    retf

; Нарисовать меню: серый фон, чёрные надписи, выбранный пункт - чёрная полоса
bm_paint:
    xor di, di
    mov ax, 0x7020                      ; серый фон
    mov cx, 80 * 25
    rep stosw
    mov si, BM(bm_t)
    mov di, (4 * 80 + (80 - (bm_te - bm_t)) / 2) * 2
    mov ah, 0x70
    call bm_str
    xor bx, bx
.it:mov al, 0x70                        ; чёрные буквы на сером
    cmp bl, [BM(bm_sel)]
    jne .c
    mov al, 0x0F                        ; выбранный - белые буквы на чёрной полосе
.c: mov ah, al
    mov al, ' '
    mov di, bx
    imul di, di, 2 * 80 * 2
    add di, (9 * 80 + 25) * 2
    push di
    mov cx, 30
    rep stosw
    pop di
    add di, 4 * 2
    mov si, bx
    shl si, 1
    mov si, [BM(bm_items) + si]
    call bm_str
    inc bx
    cmp bl, [BM(bm_n)]
    jb .it
    cmp byte [BM(bm_err)], 0
    je .h
    mov si, BM(bm_nd)
    mov di, (18 * 80 + (80 - (bm_nde - bm_nd)) / 2) * 2
    mov ah, 0x70
    call bm_str
.h: mov si, BM(bm_h)
    mov di, (22 * 80 + (80 - (bm_he - bm_h)) / 2) * 2
    mov ah, 0x70
    call bm_str
    ret

; Строка ds:si в es:di цветом ah
bm_str:
    lodsb
    test al, al
    jz .e
    stosw
    jmp bm_str
.e: ret

bm_sel  db 0
bm_err  db 0
bm_n    db 0
bm_drv  db 0, 0, 0, 0
bm_dap  db 16, 0
        dw 1
        dw 0x7C00, 0x0000
        dq 0
bm_items dw 0, 0, 0, 0
bm_i1   db "Floppy 1.1", 0
bm_i2   db "Floppy 1.1 (disk O)", 0
bm_i3   db "Floppy 1.1 (disk I)", 0
bm_id   db "MS-DOS", 0
bm_t    db "Upload from..."
bm_te   db 0
bm_h    db "Choose what to load with the arrow keys and press Enter"
bm_he   db 0
bm_nd   db "No DOS disk"
bm_nde  db 0
bits 32
