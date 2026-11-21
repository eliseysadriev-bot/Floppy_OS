; Floppy 32: загрузчик. Читает ядро, включает режим 800x600, переходит в 32-битный защищённый режим
org 0x7C00
bits 16
KSEC equ 256                    ; сколько секторов ядра читаем

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    mov [bdrv], dl
    mov cx, KSEC / 64           ; читаем ядро с диска в 0x10000 кусками по 64 сектора
.rk:push cx
    mov si, dap
    mov ah, 0x42
    mov dl, [bdrv]
    int 0x13
    pop cx
    jc fail
    add dword [dap + 8], 64
    add word [dap + 6], 0x800
    loop .rk
    call 0x2F40:0x0000          ; меню загрузки (лежит в конце ядра): Floppy или DOS
    mov si, dap2                ; читаем модуль FloCalc.sys в 0x30000
    mov ah, 0x42
    mov dl, [bdrv]
    int 0x13
    jc fail
    mov si, dap3                ; читаем модуль FloText.sys в 0x34000
    mov ah, 0x42
    mov dl, [bdrv]
    int 0x13
    jc fail
    mov si, dap4                ; читаем модуль FloPaint.sys в 0x38000
    mov ah, 0x42
    mov dl, [bdrv]
    int 0x13
    jc fail
    mov si, dap5                ; читаем модуль FloFile.sys в 0x42000
    mov ah, 0x42
    mov dl, [bdrv]
    int 0x13
    jc fail
    mov si, dap6                ; читаем модуль Boil.sys в 0x3C000
    mov ah, 0x42
    mov dl, [bdrv]
    int 0x13
    jc fail
    mov si, dap7                ; FloItge.sys: 64 сектора в 0x48000
    mov ah, 0x42
    mov dl, [bdrv]
    int 0x13
    jc fail
    mov si, dap8                ; FloCalendar.sys: 16 секторов в 0x50000
    mov ah, 0x42
    mov dl, [bdrv]
    int 0x13
    jc fail
    mov ax, 0x8800             ; contiguous extended memory, in KiB
    int 0x15
    jnc .memory
    xor ax, ax
.memory:
    mov [0x504], ax
    mov ax, 0x1130              ; где в памяти лежит шрифт 8x16 (пока BIOS ещё работает)
    mov bh, 6
    int 0x10
    movzx eax, word [es:0]      ; (es здесь уже указывает на шрифт, адрес берём ниже)
    xor eax, eax
    mov ax, es
    shl eax, 4
    movzx ebx, bp
    add eax, ebx
    xor cx, cx
    mov es, cx
    mov [0x500], eax            ; адрес шрифта для ядра
    mov ax, 0x6A                ; графика 800x600, 16 цветов
    int 0x10
    in al, 0x92                 ; открыть адреса выше 1 МБ (A20)
    or al, 2
    out 0x92, al
    cli                         ; прерывания BIOS могли включиться снова: без этого IRQ0 падает в пустую IDT
    lgdt [gdtr]
    mov eax, cr0
    or al, 1
    mov cr0, eax
    jmp 0x08:pm
fail:
    mov ax, 0x0E21
    int 0x10
    jmp $

bits 32
pm:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    jmp 0x10000

bits 16
bdrv    db 0
dap     db 16, 0
        dw 64
        dw 0x0000, 0x1000
        dq 1
dap2    db 16, 0
        dw 8
        dw 0x0000, 0x3000
        dq 257
dap3    db 16, 0
        dw 16
        dw 0x0000, 0x3400
        dq 265
dap4    db 16, 0
        dw 32
        dw 0x0000, 0x3800
        dq 281
dap5    db 16, 0
        dw 48
        dw 0x0000, 0x4200
        dq 313
dap6    db 16, 0
        dw 12
        dw 0x0000, 0x3C00
        dq 361
dap7    db 16, 0
        dw 64
        dw 0x0000, 0x4800
        dq 373
dap8    db 16, 0
        dw 16
        dw 0x0000, 0x5000
        dq 437
align 8
gdt     dq 0
        dq 0x00CF9A000000FFFF   ; 0x08: код, 4 ГБ
        dq 0x00CF92000000FFFF   ; 0x10: данные, 4 ГБ
gdtr    dw 23
        dd gdt
times 510 - ($ - $$) db 0
dw 0xAA55
