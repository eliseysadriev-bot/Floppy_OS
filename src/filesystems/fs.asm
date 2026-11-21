; Диски (ATA PIO), файловая система FSM2, виртуальные диски
; Подключается из kernel32.asm (%include)

; диски (ATA PIO) и файловая система FSM2
FS_NEW      equ 512                     ; здесь начинается файловая система
FS_OLD      equ 64                      ; на старых дисках она была здесь
FS_DIRN     equ 8
FSM2_MAGIC  equ 0x324D5346
FSM3_MAGIC  equ 0x334D5346             ; FSM3 first-stage volume format (read/write files disabled)
FS3_DIRN    equ 128                     ; 1024 entries, 64 bytes each
; Stage 1: at most 32 MiB per FSM3 virtual volume. FAT keeps 32-bit
; indices; the RAM cross-link detection bitmap covers 65,536 clusters.
; This does NOT increase the per-file 4 MiB limit.
FS3_MAX_SECTORS equ 65536              ; 32 * 1024 * 1024 / 512
FS3_BITMAP_DWORDS equ FS3_MAX_SECTORS / 32
FS2_BUF     equ 0x50000                 ; буферы файловой системы (свободная память)
FAT_BUF     equ 0x50200
DIR_BUF     equ 0x50400
IDF_BUF     equ 0x50600

; Диск cur_drive: 0 - первичный главный (C), 1 - первичный второй (O), 2 - вторичный главный (I)
ata_base_get:
    movzx eax, byte [cur_drive]
    mov edx, 0x1F0
    cmp eax, 2
    jb .r
    mov edx, 0x170
.r: ret

ata_wait_bsy:
    push ecx
    push edx
    mov edx, [ata_base]
    add edx, 7
    mov ecx, 0x8000000                  ; ждём долго: на Windows QEMU запись в файл образа бывает медленной
.l: call cu_pump
    in al, dx
    test al, 0x80
    jz .ok
    dec ecx
    jnz .l
    stc
    jmp .r
.ok:clc
.r: pop edx
    pop ecx
    ret

ata_wait_drq:
    push ecx
    push edx
    mov edx, [ata_base]
    add edx, 7
    mov ecx, 0x8000000                  ; ждём долго: на Windows QEMU запись в файл образа бывает медленной
.l: call cu_pump
    in al, dx
    test al, 0x80
    jnz .c
    test al, 0x21
    jnz .e
    test al, 8
    jnz .ok
.c: dec ecx
    jnz .l
.e: stc
    jmp .r
.ok:clc
.r: pop edx
    pop ecx
    ret

; eax = сектор, bl = команда: выбрать диск и дать команду на один сектор. CF = ошибка
ata_cmd:
    push ecx
    push esi
    mov esi, eax
    call ata_base_get
    mov [ata_base], edx
    call ata_wait_bsy
    jc .e
    mov eax, esi
    shr eax, 24
    and al, 0x0F
    or al, 0xE0
    test byte [cur_drive], 1
    jz .m
    or al, 0x10
.m: mov edx, [ata_base]
    add edx, 6
    out dx, al
    mov edx, [ata_base]
    add edx, 7
    in al, dx
    in al, dx
    in al, dx
    in al, dx
    call ata_wait_bsy
    jc .e
    mov edx, [ata_base]
    add edx, 2
    mov al, 1
    out dx, al
    inc edx
    mov eax, esi
    out dx, al
    inc edx
    mov eax, esi
    shr eax, 8
    out dx, al
    inc edx
    mov eax, esi
    shr eax, 16
    out dx, al
    mov edx, [ata_base]
    add edx, 7
    mov al, bl
    out dx, al
    clc
.e: pop esi
    pop ecx
    ret

; eax = сектор, ebx = куда положить. CF = ошибка
lba_read:
    pushad
    call lba_map
    jc .f
    mov edi, ebx
    mov bl, 0x20
    call ata_cmd
    jc .f
    call ata_wait_drq
    jc .f
    mov edx, [ata_base]
    mov ecx, 256
    cld
    rep insw
    popad
    clc
    ret
.f: popad
    stc
    ret

; eax = сектор, ebx = откуда писать. CF = ошибка
lba_write:
    pushad
    call lba_map
    jc .f
    mov esi, ebx
    mov bl, 0x30
    call ata_cmd
    jc .f
    call ata_wait_drq
    jc .f
    mov edx, [ata_base]
    mov ecx, 256
    cld
    rep outsw
    call ata_wait_bsy
    jc .f
    test al, 0x21                    ; ATA error or device fault after transfer
    jnz .f
    popad
    clc
    ret

.f: popad
    stc
    ret

; Сбросить кэш диска cur_drive (после записи файла и форматирования, а не после каждого сектора: так в 1000 раз быстрее)
ata_flush:
    pushad
    call ata_base_get
    mov [ata_base], edx
    call ata_wait_bsy
    jc .r
    mov edx, [ata_base]
    add edx, 7
    mov al, 0xE7
    out dx, al
    call ata_wait_bsy
    jc .r
    test al, 0x21                    ; ATA error or device fault after flush
    jz .r
    stc
.r: popad
    ret

; Диск cur_drive: сколько секторов -> eax. CF = диска нет
ata_identify:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    call ata_base_get
    mov [ata_base], edx
    mov al, 0xA0
    test byte [cur_drive], 1
    jz .m
    or al, 0x10
.m: mov edx, [ata_base]
    add edx, 6
    out dx, al
    mov edx, [ata_base]
    add edx, 7
    in al, dx
    in al, dx
    in al, dx
    in al, dx
    in al, dx
    cmp al, 0
    je .no
    cmp al, 0xFF
    je .no
    call ata_wait_bsy
    jc .no
    mov edx, [ata_base]
    add edx, 2
    xor al, al
    out dx, al
    inc edx
    out dx, al
    inc edx
    out dx, al
    inc edx
    out dx, al
    mov edx, [ata_base]
    add edx, 7
    mov al, 0xEC
    out dx, al
    in al, dx
    test al, al
    jz .no
    call ata_wait_drq
    jc .no
    mov edx, [ata_base]
    mov edi, IDF_BUF
    mov ecx, 256
    cld
    rep insw
    mov eax, [IDF_BUF + 120]
    test eax, eax
    jz .no
    clc
    jmp .e
.no:stc
.e: pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; Узнать, какие диски есть
disk_init:
    pushad
    mov dx, 0x3F6                       ; диск не будит процессор прерываниями
    mov al, 2
    out dx, al
    mov dx, 0x376
    out dx, al
    mov edi, dtab                       ; первые три диска - настоящие: C, O, I
    mov esi, dt_letters
    xor ebx, ebx
.dt:mov al, [esi + ebx]
    mov [edi], al
    mov [edi + 1], bl
    mov dword [edi + 2], 0
    mov dword [edi + 6], 0
    add edi, DT_ESZ
    inc ebx
    cmp ebx, 3
    jb .dt
    xor ebx, ebx
.d: mov [cur_drive], bl
    call ata_identify
    jc .no
    mov [dk_total + ebx * 4], eax
    mov byte [dk_present + ebx], 1
    jmp .n
.no:mov dword [dk_total + ebx * 4], 0
    mov byte [dk_present + ebx], 0
.n: inc ebx
    cmp ebx, 3
    jb .d
    mov byte [cur_drive], 0
    call scan_disks                     ; найти виртуальные диски
    popad
    ret

 ; Header probe for coexistence with future FSM3. No disk writes here.
; fs_state = 0 valid FSM2, 2 empty (both headers zero),
;            3 FSM3 (not yet supported), 4 damaged/unknown, 5 I/O failure.
fs_mount:
    pushad
    mov byte [fs_ok], 0
    mov byte [fs_state], 2
    mov byte [fs3_seen], 0
    mov eax, [cur_size]
    test eax, eax
    jz .primary
    cmp eax, FS_NEW
    jbe .small_volume                ; the standard header sector is outside this volume
.primary:
    mov eax, FS_NEW
    call fs_try
    jnc .found
    ; Preserve the diagnosis from LBA 512. LBA 64 lies INSIDE the kernel
    ; on a freshly built pm.img, so its nonzero contents are normal.
    cmp byte [fs_state], 3           ; recognized FSM3: validate header/mirror, never fall back
    je .fsm3
.notfsm3:
    cmp byte [fs_state], 5           ; I/O error: don't guess
    je .out
    mov al, [fs_state]
    mov [fs_primary_state], al
    mov eax, FS_OLD
    call fs_try
    jnc .found
    cmp dword [cur_size], 0
    je .restore_primary
    cmp byte [fs_state], 3
    je .fsm3
.restore_primary:
    mov al, [fs_primary_state]       ; LBA 64 is part of the kernel on the boot disk
    mov [fs_state], al
    jmp .out
.small_volume:
    mov eax, FS_OLD
    call fs_try
    jnc .found
    cmp byte [fs_state], 3
    jne .out
.fsm3:
    mov byte [fs3_seen], 1
    call fs3_validate
    jmp .out
.found:
    ; Validate all geometry before any FAT or directory access.
    mov eax, [FS2_BUF + 4]          ; total sectors
    test eax, eax
    jz .damaged
    movzx ebx, byte [cur_drive]
    mov edx, [dk_total + ebx * 4]
    cmp dword [cur_size], 0
    je .limit
    mov edx, [cur_size]
.limit:
    cmp eax, edx
    ja .damaged
    mov [fs_total], eax
    mov ecx, [FS2_BUF + 8]          ; FAT start
    test ecx, ecx
    jz .damaged
    cmp ecx, eax
    jae .damaged
    mov [fs_fat], ecx
    mov edx, [FS2_BUF + 12]         ; FAT sector count
    test edx, edx
    jz .damaged
    cmp edx, eax
    jae .damaged
    mov [fs_fatn], edx
    add edx, ecx
    jc .damaged
    cmp edx, [FS2_BUF + 16]        ; directory starts immediately after FAT
    jne .damaged
    mov ecx, [FS2_BUF + 20]
    cmp ecx, FS_DIRN               ; FSM2 currently supports exactly 8 directory sectors
    jne .damaged
    mov [fs_dirn], ecx
    mov edx, [FS2_BUF + 16]
    mov [fs_dir], edx
    add edx, ecx
    jc .damaged
    cmp edx, [FS2_BUF + 24]
    jne .damaged
    cmp edx, [fs_total]
    jae .damaged
    mov [fsd_start], edx
    mov eax, [fs_total]
    sub eax, edx
    mov [fs_nclus], eax
    mov byte [fs_ok], 1
    mov byte [fs_state], 0
    jmp .out
.damaged:
    mov byte [fs_state], 4
.out:
    popad
    ret

; Probe one FSM header, eax = LBA. Carry set when not valid FSM2.
fs_try:
    push eax
    push ebx
    push ecx
    push esi
    mov ebx, FS2_BUF
    call lba_read
    jc .io
    cmp dword [FS2_BUF], FSM2_MAGIC
    je .yes
    cmp dword [FS2_BUF], FSM3_MAGIC
    jne .other
    mov byte [fs_state], 3
    jmp .no
.other:
    ; A genuinely empty header must be all zeros, not only zero magic.
    mov esi, FS2_BUF
    mov ecx, 128
.check:
    cmp dword [esi], 0
    jne .unknown
    add esi, 4
    dec ecx
    jnz .check
    jmp .no
.unknown:
    cmp byte [fs_state], 3
    je .no
    mov byte [fs_state], 4
    jmp .no
.io:
    mov byte [fs_state], 5
.no:
    pop esi
    pop ecx
    pop ebx
    pop eax
    stc
    ret
.yes:
    pop esi
    pop ecx
    pop ebx
    pop eax
    clc
    ret

fs_format:
    pushad
    movzx ebx, byte [cur_drive]
    mov eax, [dk_total + ebx * 4]
    cmp dword [cur_size], 0
    je .tot
    mov eax, [cur_size]
.tot:
    mov [fs_total], eax
    mov edx, FS_NEW                    ; обычные диски
    cmp eax, FS_NEW + 64
    jae .base
    mov edx, FS_OLD                    ; 180 КБ: служебная область с сектора 64
    cmp eax, FS_OLD + 64
    jb .fail
.base:
    mov [fs_fmtbase], edx
    sub eax, edx
    sub eax, 1 + FS_DIRN
    add eax, 127
    shr eax, 7
    mov [fs_fatn], eax
    mov eax, [fs_fmtbase]
    inc eax
    mov [fs_fat], eax
    mov ebx, [fs_fat]
    add ebx, [fs_fatn]
    mov [fs_dir], ebx
    mov dword [fs_dirn], FS_DIRN
    add ebx, FS_DIRN
    mov [fsd_start], ebx
    mov edi, FS2_BUF
    mov ecx, 128
    xor eax, eax
    rep stosd
    mov eax, [fs_fat]
    mov ecx, [fs_fatn]
    add ecx, FS_DIRN
.zero:
    mov ebx, FS2_BUF
    call lba_write
    jc .fail
    inc eax
    dec ecx
    jnz .zero
    mov dword [FS2_BUF], FSM2_MAGIC
    mov eax, [fs_total]
    mov [FS2_BUF + 4], eax
    mov eax, [fs_fat]
    mov [FS2_BUF + 8], eax
    mov eax, [fs_fatn]
    mov [FS2_BUF + 12], eax
    mov eax, [fs_dir]
    mov [FS2_BUF + 16], eax
    mov eax, [fs_dirn]
    mov [FS2_BUF + 20], eax
    mov eax, [fsd_start]
    mov [FS2_BUF + 24], eax
    mov eax, [fs_fmtbase]
    mov ebx, FS2_BUF
    call lba_write
    jc .fail
    mov eax, [fs_total]
    sub eax, [fsd_start]
    mov [fs_nclus], eax
    mov byte [fs_ok], 1
    call ata_flush
    popad
    clc
    ret
.fail:
    popad
    stc
    ret

; FSM3 v1 disk layout on an explicitly formatted VIRTUAL disk only.
; 0 header, 1 header mirror, then FAT (32-bit cluster indices),
; then 128 directory sectors (1024 entries of 64 bytes), then data.
; Header fields: signature, total, fat_start, fat_n, dir_start,
; dir_n, data_start, 1024, 64, version=3, xor checksum, mirror_lba.
; A valid FSM3 is still READ-ONLY/UNAVAILABLE to old FSM2 applications.
; Never set fs_ok=1 here until separate FSM3 file operations exist.
fs3_format:
    pushad
    mov eax, [cur_size]
    test eax, eax
    jz .fail                            ; never format physical disks here
    cmp eax, FS3_MAX_SECTORS
    ja .fail                            ; reject volumes beyond checked bitmap capacity
    mov [fs_total], eax
    mov edx, FS_NEW
    cmp eax, FS_NEW + 2 + FS3_DIRN + 2
    jae .base
    mov edx, FS_OLD
    cmp eax, FS_OLD + 2 + FS3_DIRN + 2
    jb .fail
.base:
    mov [fs_fmtbase], edx
    ; One 32-bit FAT entry per 512-byte data cluster.
    sub eax, edx
    sub eax, 2 + FS3_DIRN
    add eax, 127
    shr eax, 7
    mov [fs_fatn], eax
    mov eax, [fs_fmtbase]
    add eax, 2
    mov [fs_fat], eax
    add eax, [fs_fatn]
    mov [fs_dir], eax
    add eax, FS3_DIRN
    cmp eax, [fs_total]
    jae .fail
    mov [fsd_start], eax
    ; Clear the metadata first; confirmation path has already zeroed
    ; every sector of the virtual disk before entering this function.
    mov edi, FS2_BUF
    xor eax, eax
    mov ecx, 128
    cld
    rep stosd
    mov eax, [fs_fat]
    mov ecx, [fs_fatn]
    add ecx, FS3_DIRN
.clear:
    mov ebx, FS2_BUF
    call lba_write
    jc .fail
    inc eax
    dec ecx
    jnz .clear
    mov dword [FS2_BUF], FSM3_MAGIC
    mov eax, [fs_total]
    mov [FS2_BUF + 4], eax
    mov eax, [fs_fat]
    mov [FS2_BUF + 8], eax
    mov eax, [fs_fatn]
    mov [FS2_BUF + 12], eax
    mov eax, [fs_dir]
    mov [FS2_BUF + 16], eax
    mov dword [FS2_BUF + 20], FS3_DIRN
    mov eax, [fsd_start]
    mov [FS2_BUF + 24], eax
    mov dword [FS2_BUF + 28], 1024
    mov dword [FS2_BUF + 32], 64
    mov dword [FS2_BUF + 36], 3
    mov eax, [fs_fmtbase]
    inc eax
    mov [FS2_BUF + 44], eax
    ; XOR checksum across the first ten 32-bit header fields.
    xor eax, eax
    mov esi, FS2_BUF
    mov ecx, 10
.xor:
    xor eax, [esi]
    add esi, 4
    dec ecx
    jnz .xor
    mov [FS2_BUF + 40], eax
    ; Mirror first, primary last. Incomplete format is not accepted.
    mov eax, [FS2_BUF + 44]
    mov ebx, FS2_BUF
    call lba_write
    jc .fail
    mov eax, [fs_fmtbase]
    mov ebx, FS2_BUF
    call lba_write
    jc .fail
    call ata_flush
    mov byte [fs_ok], 0
    mov byte [fs_state], 3
    popad
    clc
    ret
.fail:
    popad
    stc
    ret

; Called when fs_try found an FSM3 signature. Validate layout and
; checksum/mirror; leave fs_ok=0 so FSM2 writers cannot touch FSM3.
fs3_validate:
    pushad
    mov byte [fs_ok], 0
    mov dword [fs3_probe_state], 4
    mov eax, [FS2_BUF + 4]
    cmp eax, FS_OLD + 2 + FS3_DIRN + 2
    jb .bad
    cmp eax, FS3_MAX_SECTORS
    ja .bad                            ; oversized header: never touch its FAT
    movzx ebx, byte [cur_drive]
    mov edx, [dk_total + ebx * 4]
    cmp dword [cur_size], 0
    je .sz
    mov edx, [cur_size]
.sz:cmp eax, edx
    ja .bad
    cmp dword [FS2_BUF + 20], FS3_DIRN
    jne .bad
    cmp dword [FS2_BUF + 28], 1024
    jne .bad
    cmp dword [FS2_BUF + 32], 64
    jne .bad
    cmp dword [FS2_BUF + 36], 3
    jne .bad
    mov eax, [FS2_BUF + 44]
    inc eax
    cmp eax, [FS2_BUF + 8]
    jne .bad                           ; mirror + 1 == FAT start
    mov ecx, [FS2_BUF + 12]
    test ecx, ecx
    jz .bad
    add eax, ecx
    jc .bad
    cmp eax, [FS2_BUF + 16]
    jne .bad
    add eax, FS3_DIRN
    jc .bad
    cmp eax, [FS2_BUF + 24]
    jne .bad
    cmp eax, [FS2_BUF + 4]
    jae .bad
    ; One 32-bit FAT entry per data cluster. Refuse headers whose FAT
    ; cannot describe the full declared data region.
    mov edx, [FS2_BUF + 4]
    sub edx, [FS2_BUF + 24]
    mov ecx, [FS2_BUF + 12]
    cmp ecx, 0x01FFFFFF          ; avoid overflow of FAT sectors * 128
    ja .bad
    shl ecx, 7
    cmp edx, ecx
    ja .bad
    mov eax, [FS2_BUF + 44]
    cmp eax, FS_OLD + 1
    jb .bad
    cmp eax, FS_NEW + 1
    je .checksum
    cmp eax, FS_OLD + 1
    jne .bad
.checksum:
    xor edx, edx
    mov esi, FS2_BUF
    mov ecx, 10
.xor:
    xor edx, [esi]
    add esi, 4
    dec ecx
    jnz .xor
    cmp edx, [FS2_BUF + 40]
    jne .bad
    mov eax, [FS2_BUF + 44]
    mov ebx, FAT_BUF
    call lba_read
    jc .io
    mov esi, FS2_BUF
    mov edi, FAT_BUF
    mov ecx, 12
    repe cmpsd
    jne .bad
    ; Floppy_146: expose validated FSM3 geometry to the read-only
    ; catalog inspector. FSM2 writers remain disabled (fs_ok=0).
    mov eax, [FS2_BUF + 4]
    mov [fs_total], eax
    mov eax, [FS2_BUF + 8]
    mov [fs_fat], eax
    mov eax, [FS2_BUF + 12]
    mov [fs_fatn], eax
    mov eax, [FS2_BUF + 16]
    mov [fs_dir], eax
    mov dword [fs_dirn], FS3_DIRN
    mov eax, [FS2_BUF + 24]
    mov [fsd_start], eax
    mov edx, [fs_total]
    sub edx, eax
    mov [fs_nclus], edx
    mov dword [fs3_probe_state], 3
    jmp .done
.io:mov dword [fs3_probe_state], 5
.bad:
.done:
    mov eax, [fs3_probe_state]
    mov [fs_state], al
    popad
    ret
fs3_probe_state dd 4

; Выбрать диск по номеру al в таблице dtab (0 C, 1 O, 2 I, дальше виртуальные). CF = нет диска или он не форматирован (lst_st: 1 или 2)
fs_setdisk:
    push ebx
    push eax
    push edx
    mov byte [lst_st], 0
    movzx ebx, al
    imul ebx, DT_ESZ
    add ebx, dtab
    cmp byte [ebx], 0
    je .nod
    movzx eax, byte [ebx + 1]
    cmp byte [dk_present + eax], 0
    je .nod
    mov [cur_drive], al
    mov al, [ebx]
    mov [cur_letter], al
    mov eax, [ebx + 2]
    mov [cur_base], eax
    mov eax, [ebx + 6]
    mov [cur_size], eax
    call fs_mount
    cmp byte [fs_ok], 1
    jne .nofs
    pop edx
    pop eax
    pop ebx
    clc
    ret
.nofs:
    mov al, [fs_state]
    mov [lst_st], al
    ; Only alert on a recognized FSM3 whose header/mirror is damaged.
    ; Boot scanning remains silent until fs3_alert_ready is set.
    cmp byte [fs3_seen], 1
    jne .bad
    cmp byte [fs3_alert_ready], 1
    jne .bad
    cmp byte [fs_state], 4
    je .fs3_alert
    cmp byte [fs_state], 5
    jne .bad
.fs3_alert:
    mov byte [fs3_alert_pending], 1
    jmp .bad
.nod:
    mov byte [lst_st], 1
.bad:
    pop edx
    pop eax
    pop ebx
    stc
    ret

; таблица цепочек (FAT)
fat_get:
    push ebx
    push esi
    mov esi, eax
    shr eax, 7
    add eax, [fs_fat]
    mov ebx, FAT_BUF
    call lba_read
    jc .e
    and esi, 127
    mov eax, [FAT_BUF + esi * 4]
    pop esi
    pop ebx
    clc
    ret
.e: pop esi
    pop ebx
    stc
    ret

fat_set:
    push eax
    push ebx
    push esi
    mov esi, eax
    shr eax, 7
    add eax, [fs_fat]
    mov [f_lba], eax
    mov ebx, FAT_BUF
    call lba_read
    jc .e
    and esi, 127
    mov [FAT_BUF + esi * 4], edx
    mov eax, [f_lba]
    mov ebx, FAT_BUF
    call lba_write
    jc .e
    pop esi
    pop ebx
    pop eax
    clc
    ret
.e: pop esi
    pop ebx
    pop eax
    stc
    ret

; Занять свободный кусок -> eax. CF = нет места
fat_alloc:
    xor eax, eax
; EAX = first cluster to consider. Streams allocate in ascending order.
fat_alloc_from:
    push ebx
    push ecx
    push edx
    push esi
    cmp eax, [fs_nclus]
    jae .err
    mov edx, eax
    and edx, 127
    and eax, -128
    mov [f_base], eax
    shr eax, 7
    mov ecx, [fs_fat]
    add ecx, eax
.sec:
    mov eax, ecx
    mov ebx, FAT_BUF
    call lba_read
    jc .err
    lea esi, [FAT_BUF + edx * 4]
.ent:
    mov eax, [f_base]
    add eax, edx
    cmp eax, [fs_nclus]
    jae .err
    test eax, eax
    jz .skip
    cmp dword [esi], 0
    jne .skip
    mov dword [esi], 0xFFFFFFFF
    push eax
    mov eax, ecx
    mov ebx, FAT_BUF
    call lba_write
    pop eax
    jc .err
    pop esi
    pop edx
    pop ecx
    pop ebx
    clc
    ret
.skip:
    add esi, 4
    inc edx
    cmp edx, 128
    jb .ent
    xor edx, edx
    add dword [f_base], 128
    inc ecx
    mov eax, [f_base]
    cmp eax, [fs_nclus]
    jb .sec
.err:
    pop esi
    pop edx
    pop ecx
    pop ebx
    stc
    ret

; Освободить цепочку, начиная с куска eax
fat_free:
    push ecx
    push edx
.l: cmp eax, 0xFFFFFFFF
    je .d
    test eax, eax
    jz .d
    cmp eax, [fs_nclus]
    jae .d
    mov ecx, eax
    call fat_get
    jc .d
    push eax
    mov eax, ecx
    xor edx, edx
    call fat_set
    pop eax
    jc .d
    jmp .l
.d: pop edx
    pop ecx
    ret

; Сколько кусков свободно -> eax
fat_count_free:
    push ebx
    push ecx
    push edx
    push esi
    mov dword [f_base], 0
    mov dword [f_cnt], 0
    mov ecx, [fs_fat]
.sec:
    mov eax, [f_base]
    cmp eax, [fs_nclus]
    jae .done
    mov eax, ecx
    mov ebx, FAT_BUF
    call lba_read
    jc .done
    mov esi, FAT_BUF
    xor edx, edx
.ent:
    mov eax, [f_base]
    add eax, edx
    cmp eax, [fs_nclus]
    jae .done
    test eax, eax
    jz .skip
    cmp dword [esi], 0
    jne .skip
    inc dword [f_cnt]
.skip:
    add esi, 4
    inc edx
    cmp edx, 128
    jb .ent
    add dword [f_base], 128
    inc ecx
    jmp .sec
.done:
    mov eax, [f_cnt]
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; каталог: запись 32 байта (имя 16, размер, первый кусок)
streq:                                  ; esi, edi -> al = 1, если строки одинаковы
    push esi
    push edi
.l: mov al, [esi]
    cmp al, [edi]
    jne .n
    test al, al
    jz .y
    inc esi
    inc edi
    jmp .l
.y: mov al, 1
    jmp .r
.n: xor al, al
.r: pop edi
    pop esi
    ret

; После dir_find: al = номер найденной записи + 1 (так нумеруются папки)
dir_last_id:
    push edx
    mov eax, [f_dlba]
    sub eax, [fs_dir]
    shl eax, 4
    mov edx, edi
    sub edx, DIR_BUF
    shr edx, 5
    lea eax, [eax + edx + 1]
    pop edx
    ret

; Найти файл esi. Нашли: edi = запись в DIR_BUF, [f_dlba] = её сектор. CF = нет такого
dir_find:
    push ebx
    push ecx
    push edx
    mov dword [f_i], 0
.sec:
    mov eax, [f_i]
    cmp eax, [fs_dirn]
    jae .no
    add eax, [fs_dir]
    mov [f_dlba], eax
    mov ebx, DIR_BUF
    call lba_read
    jc .no
    mov edi, DIR_BUF
    mov ecx, 16
.e: cmp byte [edi], 0
    je .next
    mov al, [edi + 25]
    cmp al, [fs_par]
    jne .next
    call streq
    test al, al
    jnz .yes
.next:
    add edi, 32
    dec ecx
    jnz .e
    inc dword [f_i]
    jmp .sec
.yes:
    pop edx
    pop ecx
    pop ebx
    clc
    ret
.no:pop edx
    pop ecx
    pop ebx
    stc
    ret

; Пустая запись. CF = каталог полон
dir_free:
    push ebx
    push ecx
    push edx
    mov dword [f_i], 0
.sec:
    mov eax, [f_i]
    cmp eax, [fs_dirn]
    jae .no
    add eax, [fs_dir]
    mov [f_dlba], eax
    mov ebx, DIR_BUF
    call lba_read
    jc .no
    mov edi, DIR_BUF
    mov ecx, 16
.e: cmp byte [edi], 0
    je .yes
    add edi, 32
    dec ecx
    jnz .e
    inc dword [f_i]
    jmp .sec
.yes:
    pop edx
    pop ecx
    pop ebx
    clc
    ret
.no:pop edx
    pop ecx
    pop ebx
    stc
    ret

dir_write:
    push eax
    push ebx
    mov eax, [f_dlba]
    mov ebx, DIR_BUF
    call lba_write
    pop ebx
    pop eax
    ret

; Удалить файл esi. CF = нет такого
file_delete:
    cmp byte [fs_state], 3
    je fs3_delete_root
    push eax
    push ecx
    push edi
    call dir_find
    jc .no
    mov eax, [edi + 20]
    mov [f_first], eax
    mov ecx, 8
    xor eax, eax
    rep stosd
    call dir_write
    jc .no
    mov eax, [f_first]
    call fat_free
    pop edi
    pop ecx
    pop eax
    clc
    ret
.no:pop edi
    pop ecx
    pop eax
    stc
    ret

; Записать файл esi: данные в DATA_BUF, размер ecx. Есть такой - заменить. CF = ошибка
file_write:
    ; FSM3 has a separate, restricted copy-on-write path. Never use FSM2 code.
    cmp byte [fs_state], 3
    je fs3_write_root
    pushad
    mov [f_size], ecx
    cmp ecx, 262144
    ja .fail
    mov [f_nameptr], esi
    mov eax, ecx
    add eax, 511
    shr eax, 9
    mov [f_n], eax
    call dir_find
    jc .newfile
    mov [f_ent], edi
    mov eax, [edi + 20]
    call fat_free
    jmp .alloc
.newfile:
    call dir_free
    jc .fail
    mov [f_ent], edi
    mov esi, [f_nameptr]
    ; FSM2 file records have 15 name bytes at offsets 0..14.
    ; Offset 15 is the file-type byte (0 for files), which also acts
    ; as a terminator for a full 15-character filename.
    mov ecx, 15
.cp:lodsb
    test al, al
    jz .cpe
    stosb
    loop .cp
.cpe:
    mov byte [edi], 0
    mov edi, [f_ent]
    mov al, [fs_par]
    mov [edi + 25], al
    mov byte [edi + 24], 0
    mov byte [edi + 15], 0
    call fs_now                         ; дата создания
    mov [edi + 26], ax
    shr eax, 16
    mov [edi + 28], al
.alloc:
    mov dword [f_first], 0xFFFFFFFF
    mov dword [f_prev], 0xFFFFFFFF
    mov dword [f_k], 0
.next:
    mov eax, [f_k]
    cmp eax, [f_n]
    jae .done
    call fat_alloc
    jc .nospace
    mov [f_cur], eax
    cmp dword [f_prev], 0xFFFFFFFF
    jne .link
    mov [f_first], eax
    jmp .data
.link:
    mov edx, eax
    mov eax, [f_prev]
    call fat_set
    jc .fail
.data:
    mov eax, [f_k]
    shl eax, 9
    lea ebx, [DATA_BUF + eax]
    mov eax, [f_cur]
    add eax, [fsd_start]
    call lba_write
    jc .fail
    mov eax, [f_cur]
    mov [f_prev], eax
    inc dword [f_k]
    jmp .next
.done:
    mov edi, [f_ent]
    mov eax, [f_size]
    mov [edi + 16], eax
    mov eax, [f_first]
    mov [edi + 20], eax
    call fs_now                         ; дата последнего изменения
    mov [edi + 29], ax
    shr eax, 16
    mov [edi + 31], al
    call dir_write
    jc .fail
    call ata_flush
    popad
    clc
    ret
.nospace:
    mov eax, [f_first]
    call fat_free
    mov edi, [f_ent]
    mov ecx, 8
    xor eax, eax
    rep stosd
    call dir_write
.fail:
    popad
    stc
    ret

; Прочитать файл esi в DATA_BUF. eax = размер. CF = нет такого
file_read:
    ; FSM3 reader is independent of the legacy 32-byte FSM2 directory.
    ; A recognized FSM3 volume is never passed to the FSM2 reader.
    cmp byte [fs_state], 3
    je fs3_file_read
    push ebx
    push ecx
    push edx
    push edi
    call dir_find
    jc .no
    mov eax, [edi + 16]
    mov [f_size], eax
    mov eax, [edi + 20]
    mov [f_cur], eax
    mov dword [f_k], 0
.l: mov eax, [f_cur]
    cmp eax, 0xFFFFFFFF
    je .done
    cmp eax, [fs_nclus]
    jae .done
    cmp dword [f_k], 512
    jae .done
    mov eax, [f_k]
    shl eax, 9
    lea ebx, [DATA_BUF + eax]
    mov eax, [f_cur]
    add eax, [fsd_start]
    call lba_read
    jc .no
    mov eax, [f_cur]
    call fat_get
    jc .no
    mov [f_cur], eax
    inc dword [f_k]
    jmp .l
.done:
    mov ebx, [f_size]
    mov byte [DATA_BUF + ebx], 0
    mov eax, [f_size]
    pop edi
    pop edx
    pop ecx
    pop ebx
    clc
    ret
.no:pop edi
    pop edx
    pop ecx
    pop ebx
    stc
    ret

; Список файлов диска al в буфер edi (по 16 байт): lst_n - сколько, lst_st - состояние
fs_list:
    pushad
    mov [f_lbuf], edi
    mov byte [lst_n], 0
    call fs_setdisk
    jnc .fsm2
    ; Floppy_148: FSM3 is not writable via the legacy APIs, but its
    ; validated root directory can be previewed read-only in FloFile.
    cmp byte [fs_state], 3
    jne .out
    cmp dword [lst_ext], 0          ; never expose preview to Save/Open dialogs
    jne .out
    call fs3_preview_root
    jmp .out
.fsm2:
    mov byte [f_pass], 0                ; проход 0 - папки, проход 1 - файлы
.pass:
    mov dword [f_ls], 0
.sec:
    mov eax, [f_ls]
    cmp eax, [fs_dirn]
    jae .endp
    add eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_read
    jc .out
    mov edi, DIR_BUF
    mov ecx, 16
.e: cmp byte [edi], 2
    jb .n
    mov al, [edi + 25]                  ; только то, что лежит в текущей папке
    cmp al, [fs_par]
    jne .n
    cmp byte [edi + 15], 1
    je .isf
    cmp byte [f_pass], 0
    je .n
    xor ebx, ebx
.len:
    cmp byte [edi + ebx], 0
    je .gl
    inc ebx
    cmp ebx, 16            ; accept 15-char FSM2 filenames (NUL/type at +15)
    jb .len
    jmp .n
.gl:mov edx, [lst_ext]                  ; 0 - любой файл, иначе нужное расширение (dword)
    test edx, edx
    jz .ok
    cmp ebx, 5
    jb .n
    mov eax, [edi + ebx - 4]
    cmp edx, 2                          ; 2 - открытие в FloText: .txt и .sec
    jne .n2
    cmp eax, 0x7478742E
    je .ok
    cmp eax, 0x6365732E
    je .ok
    jmp .n
.n2:cmp edx, 1                          ; 1 - открытие в itge: .sga, .pcf и .txt
    jne .one
    cmp eax, 0x6167732E
    je .ok
    cmp eax, 0x6663702E
    je .ok
    cmp eax, 0x7478742E
    je .ok
    jmp .n
.one:
    cmp eax, edx
    jne .n
    jmp .ok
.isf:
    cmp byte [f_pass], 0
    jne .n
    cmp byte [lst_dirs], 0              ; в диалогах Save/Open папки показывает lst_dirs
    jne .ok
    cmp dword [lst_ext], 0
    jne .n
.ok:
    cmp byte [lst_n], 32
    jae .n
    push ecx
    push edi
    movzx eax, byte [lst_n]
    mov edx, 16
    sub edx, ecx
    mov ebx, [f_ls]
    shl ebx, 4
    add edx, ebx
    inc edx                             ; номер записи + 1 - это номер папки
    mov [lst_ids + eax], dl
    shl eax, 4
    add eax, [f_lbuf]
    mov esi, edi
    mov edi, eax
    mov ecx, 16
    rep movsb
    pop edi
    pop ecx
    inc byte [lst_n]
.n: add edi, 32
    dec ecx
    jnz .e
    inc dword [f_ls]
    jmp .sec
.endp:
    inc byte [f_pass]
    cmp byte [f_pass], 2
    jb .pass
.out:
    popad
    ret

; Создать папку esi в текущей папке (fs_par). CF = такая уже есть или нет места
dir_mkdir:
    cmp byte [fs_state], 3
    je fs3_mkdir_root
    pushad
    mov [f_nameptr], esi
    call dir_find
    jnc .bad
    call dir_free
    jc .bad
    mov [f_ent], edi
    mov esi, [f_nameptr]
    mov ecx, 14
.cp:lodsb
    test al, al
    jz .cpe
    stosb
    loop .cp
.cpe:
    mov edi, [f_ent]
    mov byte [edi + 15], 1
    mov byte [edi + 24], 1
    mov al, [fs_par]
    mov [edi + 25], al
    mov dword [edi + 16], 0
    mov dword [edi + 20], 0xFFFFFFFF
    call fs_now
    mov [edi + 26], ax
    mov [edi + 29], ax
    shr eax, 16
    mov [edi + 28], al
    mov [edi + 31], al
    call dir_write
    jc .bad
    popad
    clc
    ret
.bad:
    popad
    stc
    ret

; Переименовать esi в edx (в текущей папке). CF = новое имя занято или старого нет
dir_rename:
    cmp byte [fs_state], 3
    je fs3_rename_root
    pushad
    mov [f_nameptr], esi
    mov [f_nameptr2], edx
    mov esi, edx
    call dir_find
    jnc .bad
    mov esi, [f_nameptr]
    call dir_find
    jc .bad
    mov [f_ent], edi
    xor eax, eax
    mov ecx, 15
    rep stosb
    mov edi, [f_ent]
    mov esi, [f_nameptr2]
    mov ecx, 14
.cp:lodsb
    test al, al
    jz .cpe
    stosb
    loop .cp
.cpe:
    call dir_write
    jc .bad
    popad
    clc
    ret
.bad:
    popad
    stc
    ret

; Есть ли в папке al что-нибудь. CF = есть
dir_has_child:
    pushad
    mov [f_pid], al
    mov dword [f_i], 0
.sec:
    mov eax, [f_i]
    cmp eax, [fs_dirn]
    jae .no
    add eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_read
    jc .no
    mov edi, DIR_BUF
    mov ecx, 16
.e: cmp byte [edi], 0
    je .n
    mov al, [edi + 25]
    cmp al, [f_pid]
    je .yes
.n: add edi, 32
    dec ecx
    jnz .e
    inc dword [f_i]
    jmp .sec
.yes:
    popad
    stc
    ret
.no:popad
    clc
    ret

; Узнать у каждого диска, сколько места и сколько свободно
fs_pc_scan:
    pushad
    xor ebp, ebp
.d:
    mov eax, ebp
    call fs_setdisk
    jc .bad
.ok2:
    mov byte [pc_st + ebp], 0
    call fat_count_free
    mov [pc_free + ebp * 4], eax
    ; FAT entry 0 is reserved and never counts as user capacity.
    ; fat_count_free already skips entry 0. Keep denominators consistent.
    mov eax, [fs_nclus]
    test eax, eax
    jz .tot_zero_legacy
    dec eax
.tot_zero_legacy:
    mov [pc_tot + ebp * 4], eax
    jmp .n
.bad:
    ; A recognized FSM3 volume has a valid header; verify its entire catalog
    ; before exposing the ordinary used/free capacity indicator.  Damaged
    ; catalogs must never be treated as formatted or mounted writable.
    cmp byte [lst_st], 3
    jne .legacy
    call fs3_catalog_count
    jc .fs3bad
    mov byte [pc_st + ebp], 0
    call fat_count_free
    mov [pc_free + ebp * 4], eax
    ; FAT entry 0 is reserved and never counts as user capacity.
    ; fat_count_free already skips entry 0. Keep denominators consistent.
    mov eax, [fs_nclus]
    test eax, eax
    jz .tot_zero_fsm3
    dec eax
.tot_zero_fsm3:
    mov [pc_tot + ebp * 4], eax
    jmp .n
.fs3bad:
    mov byte [pc_st + ebp], 4
    mov dword [pc_free + ebp * 4], 0
    mov dword [pc_tot + ebp * 4], 0
    jmp .n
.legacy:
    ; Never format unknown, damaged or I/O-failed disks.
    ; Fresh pm.img needs first-time setup: allow only the physical boot
    ; disk C with both filesystem header sectors completely zero.
    cmp ebp, 0
    jne .b2
    cmp byte [lst_st], 2
    jne .b2
    cmp byte [sys_dsk], 0
    jne .b2
    cmp byte [dk_present], 1
    jne .b2
    cmp dword [cur_size], 0
    jne .b2
    call fs_format
    jc .b2
    xor eax, eax
    call fs_setdisk
    jnc .ok2
.b2:
    mov al, [lst_st]
    mov [pc_st + ebp], al
    mov dword [pc_free + ebp * 4], 0
    mov dword [pc_tot + ebp * 4], 0
.n:
    inc ebp
    cmp ebp, DT_N
    jb .d
    popad
    ret


; виртуальные диски
; Запись в таблице dtab (12 байт): буква, диск ATA, начало (сектор), размер в секторах (0 - настоящий диск)
DT_N        equ 8
DT_ESZ      equ 12

lba_map:                                ; eax = сектор на текущем диске -> сектор на диске ATA. CF = за пределами
    cmp dword [cur_size], 0
    je .r
    cmp eax, [cur_size]
    jae .bad
    add eax, [cur_base]
.r: clc
    ret
.bad:
    stc
    ret

; ecx = сколько кусков подряд нужно. Нашли: [f_start] = первый. CF = нет места
fat_find_run:
    pushad
    mov [f_cnt], ecx
    mov dword [f_base], 0
    mov dword [f_run], 0
    mov ecx, [fs_fat]
.sec:
    mov eax, ecx
    mov ebx, FAT_BUF
    call lba_read
    jc .no
    mov esi, FAT_BUF
    xor edx, edx
.ent:
    mov eax, [f_base]
    add eax, edx
    cmp eax, [fs_nclus]
    jae .no
    test eax, eax
    jz .used
    cmp dword [esi], 0
    jne .used
    cmp dword [f_run], 0
    jne .go
    mov [f_start], eax
.go:inc dword [f_run]
    mov eax, [f_run]
    cmp eax, [f_cnt]
    jae .found
    jmp .adv
.used:
    mov dword [f_run], 0
.adv:
    add esi, 4
    inc edx
    cmp edx, 128
    jb .ent
    add dword [f_base], 128
    inc ecx
    jmp .sec
.found:
    popad
    clc
    ret
.no:popad
    stc
    ret

; eax = первый кусок, ecx = сколько, edx = что записать в FAT. CF = ошибка диска
fat_mark_range:
    pushad
.l: test ecx, ecx
    jz .ok
    mov [f_cur], eax
    shr eax, 7
    add eax, [fs_fat]
    mov [f_lba], eax
    mov ebx, FAT_BUF
    call lba_read
    jc .e
    mov eax, [f_cur]
    and eax, 127
    lea edi, [FAT_BUF + eax * 4]
    mov ebx, 128
    sub ebx, eax
    cmp ebx, ecx
    jbe .part
    mov ebx, ecx
.part:
    push ecx
    mov ecx, ebx
    mov eax, edx
    cld
    rep stosd
    pop ecx
    mov eax, [f_lba]
    push ebx
    mov ebx, FAT_BUF
    call lba_write
    pop ebx
    jc .e
    mov eax, [f_cur]
    add eax, ebx
    sub ecx, ebx
    jmp .l
.ok:popad
    clc
    ret
.e: popad
    stc
    ret

; Просмотреть каталог текущего диска и занести виртуальные диски в таблицу
scan_dir:
    pushad
    mov dword [f_i], 0
.sec:
    mov eax, [f_i]
    cmp eax, [fs_dirn]
    jae .done
    add eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_read
    jc .done
    mov esi, DIR_BUF
    mov ecx, 16
.e: cmp byte [esi], 1
    jne .n
    mov edi, dtab + 3 * DT_ESZ
    mov edx, DT_N - 3
.f: cmp byte [edi], 0
    je .put
    add edi, DT_ESZ
    dec edx
    jnz .f
    jmp .n
.put:
    ; A virtual disk is a contiguous extent inside the host FSM2 data
    ; area. Validate the entire extent before exposing it in dtab.
    ; The host may be a user-supplied image with stale metadata.
    mov eax, [esi + 20]                ; starting host cluster
    test eax, eax
    jz .n
    cmp eax, [fs_nclus]
    jae .n
    mov ebx, [esi + 16]                ; size in sectors; ECX counts directory slots
    test ebx, ebx
    jz .n
    mov edx, [fs_nclus]
    sub edx, eax                       ; remaining host data sectors
    cmp ebx, edx
    ja .n
    mov al, [esi + 1]
    mov [edi], al
    mov al, [cur_drive]
    mov [edi + 1], al
    mov eax, [esi + 20]
    add eax, [fsd_start]
    mov [edi + 2], eax
    mov [edi + 6], ebx
.n: add esi, 32
    dec ecx
    jnz .e
    inc dword [f_i]
    jmp .sec
.done:
    popad
    ret

; Обойти настоящие диски и заново найти на них виртуальные
scan_disks:
    pushad
    push dword [cur_base]
    push dword [cur_size]
    movzx eax, byte [cur_drive]
    push eax
    movzx eax, byte [cur_letter]
    push eax
    mov edi, dtab + 3 * DT_ESZ
    mov ecx, (DT_N - 3) * DT_ESZ
    xor al, al
    cld
    rep stosb
    xor ebx, ebx
.disk:
    imul edx, ebx, DT_ESZ
    movzx edx, byte [dtab + edx + 1]
    cmp byte [dk_present + edx], 0
    je .next
    mov [cur_drive], dl
    mov dword [cur_base], 0
    mov dword [cur_size], 0
    call fs_mount
    cmp byte [fs_ok], 1
    jne .next
    call scan_dir
.next:
    inc ebx
    cmp ebx, 3
    jb .disk
    pop eax
    mov [cur_letter], al
    pop eax
    mov [cur_drive], al
    pop dword [cur_size]
    pop dword [cur_base]
    call fs_mount
    popad
    ret

; dl = диск. Тихо создать на нём виртуальный диск: буква в [f_name], размер в секторах в [f_vsize]. CF = не вышло
try_host:
    pushad
    movzx eax, dl
    cmp byte [dk_present + eax], 0
    je .skip
    push dword [cur_base]
    push dword [cur_size]
    movzx eax, byte [cur_drive]
    push eax
    mov [cur_drive], dl
    mov dword [cur_base], 0
    mov dword [cur_size], 0
    call fs_mount
    cmp byte [fs_ok], 1
    jne .no
    call dir_free
    jc .no
    mov [f_ent], edi
    mov ecx, [f_vsize]
    call fat_find_run
    jc .no
    mov eax, [f_start]
    mov ecx, [f_vsize]
    mov edx, 0xFFFFFFFE
    call fat_mark_range
    jc .no
    mov edi, [f_ent]
    push edi
    mov ecx, 8
    xor eax, eax
    cld
    rep stosd
    pop edi
    mov byte [edi], 1
    mov al, [f_name]
    mov [edi + 1], al
    mov eax, [f_vsize]
    mov [edi + 16], eax
    mov eax, [f_start]
    mov [edi + 20], eax
    mov eax, [f_dlba]
    mov ebx, DIR_BUF
    call lba_write
    jc .no
    clc
    jmp .back
.no:stc
.back:
    pop eax
    mov [cur_drive], al
    pop dword [cur_size]
    pop dword [cur_base]
    popad
    ret
.skip:
    popad
    stc
    ret

; Создать виртуальный диск: буква [f_name], размер [f_vsize]. CF = нет места
add_core:
    pushad
    cmp dword [cur_size], 0
    jne .others
    mov dl, [cur_drive]
    call try_host
    jnc .ok
.others:
    xor ebx, ebx
.cand:
    imul edx, ebx, DT_ESZ
    movzx edx, byte [dtab + edx + 1]
    cmp dword [cur_size], 0
    jne .try
    cmp dl, [cur_drive]
    je .nextc
.try:
    call try_host
    jnc .ok
.nextc:
    inc ebx
    cmp ebx, 3
    jb .cand
    call scan_disks
    popad
    stc
    ret
.ok:call scan_disks
    popad
    clc
    ret

; Удалить виртуальный диск: edi = его запись в dtab, буква в [f_name]. CF = не вышло
del_core:
    pushad
    mov byte [dc_ok], 0
    mov dl, [edi + 1]
    push dword [cur_base]
    push dword [cur_size]
    movzx eax, byte [cur_drive]
    push eax
    mov [cur_drive], dl
    mov dword [cur_base], 0
    mov dword [cur_size], 0
    call fs_mount
    cmp byte [fs_ok], 1
    jne .back
    mov dword [f_i], 0
.sec:
    mov eax, [f_i]
    cmp eax, [fs_dirn]
    jae .back
    add eax, [fs_dir]
    mov [f_dlba], eax
    mov ebx, DIR_BUF
    call lba_read
    jc .back
    mov esi, DIR_BUF
    mov ecx, 16
.e: cmp byte [esi], 1
    jne .n
    mov al, [f_name]
    cmp [esi + 1], al
    je .hit
.n: add esi, 32
    dec ecx
    jnz .e
    inc dword [f_i]
    jmp .sec
.hit:
    mov eax, [esi + 20]
    mov ecx, [esi + 16]
    xor edx, edx
    push esi
    call fat_mark_range
    pop esi
    jc .back
    mov byte [esi], 0
    mov eax, [f_dlba]
    mov ebx, DIR_BUF
    call lba_write
    jc .back
    mov byte [dc_ok], 1
.back:
    pop eax
    mov [cur_drive], al
    pop dword [cur_size]
    pop dword [cur_base]
    call scan_disks
    cmp byte [dc_ok], 1
    popad
    ret


; данные дисков
cur_drive   db 0
ata_base    dd 0
dk_present  db 0, 0, 0
dk_total    dd 0, 0, 0
fs_ok       db 0
fs_state    db 2                    ; 0 FSM2, 2 blank, 3 FSM3, 4 damaged, 5 I/O
fs_primary_state db 2             ; status of modern LBA 512 before legacy fallback
lst_dirs    db 0
lst_ext     dd 0                        ; какие файлы показывать: 0 - .txt и .pcf, иначе расширение (dword)
fs_fmtbase  dd 0
fs_total    dd 0
fs_fat      dd 0
fs_fatn     dd 0
fs_dir      dd 0
fs_dirn     dd 0
fsd_start   dd 0
fs_nclus    dd 0
f_lba       dd 0
f_base      dd 0
f_cnt       dd 0
f_i         dd 0
f_dlba      dd 0
f_first     dd 0
f_nameptr   dd 0
f_n         dd 0
f_ent       dd 0
f_prev      dd 0
f_k         dd 0
f_cur       dd 0
f_lbuf      dd 0
f_ls        dd 0
f_pass      db 0
f_pid       db 0
f_nameptr2  dd 0
dt_letters  db "COI"
cur_base    dd 0
cur_size    dd 0
cur_letter  db 'C'
dc_ok       db 0
f_run       dd 0
f_start     dd 0
f_name      db 0
f_vsize     dd 0

; Дата и время из CMOS одним числом (24 бита): год-2020 (4), месяц (4), день (5), час (5), минута (6)
fs_now:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov edi, tw_buf                     ; время UTC из CMOS -> местное
    call rtc_get
    mov esi, tw_buf
    movsx edx, byte [tz_off]
    call tz_apply
    mov eax, [tw_buf + 16]
    sub eax, 2020
    jns .y1
    xor eax, eax
.y1:cmp eax, 15
    jbe .y2
    mov eax, 15
.y2:mov ebx, eax
    shl ebx, 4
    mov eax, [tw_buf + 12]
    and eax, 15
    or ebx, eax
    shl ebx, 5
    mov eax, [tw_buf + 8]
    and eax, 31
    or ebx, eax
    shl ebx, 5
    mov eax, [tw_buf]
    and eax, 31
    or ebx, eax
    shl ebx, 6
    mov eax, [tw_buf + 4]
    and eax, 63
    or eax, ebx
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
