; Установка системных файлов: FLOPSYS/PROGRAMS; ошибки теперь обрабатывает ядро
; Делается при первом запуске (если папки flopsys ещё нет). Модули .sys лежат в памяти: их загрузил загрузчик

sys_install:
    pushad
    xor eax, eax
    call fs_setdisk
    jnc .e1
    ; A failed mount can mean corrupt metadata or future FSM3.
    ; Never overwrite C here. First-time blank-C setup is handled by
    ; fs_pc_scan after strict blank-header detection.
    mov al, [lst_st]
    mov [si_d2], al
    mov byte [si_d3], 1
    jmp .bad1
.bad1:
    mov byte [si_d4], 1
    mov al, [lst_st]
    mov [si_d5], al
    mov eax, 512
    mov ebx, FS2_BUF
    call lba_read
    setc byte [si_d6]
    mov eax, [FS2_BUF]
    mov [si_d7], eax
    mov byte [si_err], 1
    jmp .out
.e1:mov byte [fs_par], 0
    mov esi, si_flopsys
    call dir_find
    jnc .have                           ; папка уже есть
    call si_mkdir                       ; flopsys в корне диска C
    jnc .e2
    mov byte [si_err], 2
    jmp .out
.e2:
    mov [si_ids], al
    mov [fs_par], al
    mov esi, si_programs
    call si_mkdir
    jnc .e3
    mov byte [si_err], 3
    jmp .out
.e3:
    mov [si_ids + 1], al
    mov esi, si_games
    call si_mkdir
    jnc .e5
    mov byte [si_err], 5
    jmp .out
.e5:mov ebx, si_files
.f: mov esi, [ebx]
    test esi, esi
    jz .done
    mov edx, [ebx + 12]
    mov al, [si_ids + edx]
    mov [fs_par], al
    mov edi, DATA_BUF
    mov esi, [ebx + 4]
    test esi, esi
    jz .ph
    mov ecx, [esi + 4]                  ; размер модуля в секторах (из его заголовка)
    shl ecx, 9
    push ecx
    cld
    rep movsb
    pop ecx
    jmp .wr
.ph:mov ecx, 32                         ; заглушка: имя файла и нули
    xor eax, eax
    push ecx
    rep stosb
    pop ecx
    mov edi, DATA_BUF
    mov esi, [ebx]
.pc:lodsb
    test al, al
    jz .wr
    stosb
    jmp .pc
    .wr:mov esi, [ebx]
    call file_write
    jnc .wok
    mov byte [si_err], 6
.wok:    add ebx, 16
    jmp .f
.done:
    call si_boil
    call si_itge
    call si_clock
    call si_term
    call si_calendar
    call si_authors                  ; create C:/flopsys/authors.txt if missing
    mov byte [fs_par], 0
.out:
    popad
    ret
.have:                                  ; flopsys уже есть: если нет папки games (старый диск) - создать
    call dir_last_id
    mov [fs_par], al
    mov esi, si_games
    call dir_find
    jnc .hd
    call si_mkdir
.hd:call si_boil
    call si_itge
    call si_clock
    call si_term
    call si_calendar
    call si_authors                  ; create C:/flopsys/authors.txt if missing
    mov byte [fs_par], 0
    jmp .out

; Install a real C:/flopsys/authors.txt for both new and existing disks.
; The flopsys directory is already part of the installed system.
; Store the author credits as an actual FSM2 file; preserve existing edits.
si_authors:
    pushad
    xor eax, eax
    call fs_setdisk
    jc .done
    mov byte [fs_par], 0
    mov esi, si_flopsys
    call dir_find
    jc .done                          ; do not create extra directories
    call dir_last_id
    mov [fs_par], al
    mov esi, si_authors_file
    call dir_find
    jnc .done                         ; do not overwrite existing authors.txt
    mov esi, si_authors_content
    mov edi, DATA_BUF
    mov ecx, si_authors_end - si_authors_content
    cld
    rep movsb
    mov esi, si_authors_file
    mov ecx, si_authors_end - si_authors_content
    call file_write
.done:
    mov byte [fs_par], 0
    popad
    ret

si_authors_file db "authors.txt", 0
si_authors_content:
    incbin "assets/flopsys/authors.txt"
si_authors_end:

; flopsys/games/boil с игрой Boil.sys и рекордом record.txt (если их ещё нет)
si_boil:
    mov byte [fs_par], 0
    mov esi, si_flopsys
    call dir_find
    jc .x
    call dir_last_id
    mov [fs_par], al
    mov esi, si_games
    call dir_find
    jc .x
    call dir_last_id
    mov [fs_par], al
    mov esi, si_boild
    call dir_find
    jnc .in
    mov esi, si_boild
    call si_mkdir
    jc .x
    jmp .in2
.in:call dir_last_id
.in2:
    mov [fs_par], al
    mov esi, si_bsys
    call dir_find
    jnc .hr
    mov esi, 0x3C000
    mov ecx, [esi + 4]
    shl ecx, 9
    mov edi, DATA_BUF
    push ecx
    cld
    rep movsb
    pop ecx
    mov esi, si_bsys
    call file_write
.hr:mov esi, si_brec
    call dir_find
    jnc .x
    mov byte [DATA_BUF], '0'
    mov byte [DATA_BUF + 1], 0
    mov ecx, 1
    mov esi, si_brec
    call file_write
.x: mov byte [fs_par], 0
    ret

; flopsys/programs/FloItge.sys (если его ещё нет)
si_itge:
    mov byte [fs_par], 0
    mov esi, si_flopsys
    call dir_find
    jc .x
    call dir_last_id
    mov [fs_par], al
    mov esi, si_programs
    call dir_find
    jc .x
    call dir_last_id
    mov [fs_par], al
    mov esi, si_isys
    call dir_find
    jnc .x
    mov esi, 0x48000
    mov ecx, [esi + 4]
    shl ecx, 9
    mov edi, DATA_BUF
    push ecx
    cld
    rep movsb
    pop ecx
    mov esi, si_isys
    call file_write
.x: mov byte [fs_par], 0
    ret

; flopsys/programs/FloCalendar.sys — actual executable FSYS module.
; FSM2 file names can occupy 15 bytes for files: type byte at +15 is zero.
; Do not overwrite an already installed file.
si_calendar:
    mov byte [fs_par], 0
    mov esi, si_flopsys
    call dir_find
    jc .missing_dir
    call dir_last_id
    mov [fs_par], al
    mov esi, si_programs
    call dir_find
    jc .missing_dir
    call dir_last_id
    mov [fs_par], al
    mov esi, si_can
    call dir_find
    jnc .x
    ; Calendar was already relocated to 0x54000 in kernel start.
    ; Validate FSYS header and length before copying.
    mov esi, 0x54000
    cmp dword [esi], 0x53595346 ; "FSYS" little-endian
    jne .invalid_module
    mov ecx, [esi + 4]
    cmp ecx, 16
    jne .invalid_module
    shl ecx, 9
    mov edi, DATA_BUF
    push ecx
    cld
    rep movsb
    pop ecx
    mov esi, si_can
    call file_write
    jc .write_failed
.x: mov byte [fs_par], 0
    ret
.missing_dir:
    mov byte [si_err], 7
    jmp .x
.invalid_module:
    mov byte [si_err], 8
    jmp .x
.write_failed:
    mov byte [si_err], 9
    jmp .x

si_can db "FloCalendar.sys", 0

; flopsys/programs/FloClock.sys (если его ещё нет)
si_clock:
    mov byte [fs_par], 0
    mov esi, si_flopsys
    call dir_find
    jc .x
    call dir_last_id
    mov [fs_par], al
    mov esi, si_programs
    call dir_find
    jc .x
    call dir_last_id
    mov [fs_par], al
    mov esi, si_ckn
    call dir_find
    jnc .x
    mov edi, DATA_BUF
    xor eax, eax
    mov ecx, 32
    cld
    rep stosb
    mov edi, DATA_BUF
    mov esi, si_ckn
.c: lodsb
    test al, al
    jz .w
    stosb
    jmp .c
.w: mov ecx, 32
    mov esi, si_ckn
    call file_write
.x: mov byte [fs_par], 0
    ret

si_ckn      db "FloClock.sys", 0

; flopsys/programs/FloTerm.sys (если его ещё нет)
si_term:
    mov byte [fs_par], 0
    mov esi, si_flopsys
    call dir_find
    jc .x
    call dir_last_id
    mov [fs_par], al
    mov esi, si_programs
    call dir_find
    jc .x
    call dir_last_id
    mov [fs_par], al
    mov esi, si_trn
    call dir_find
    jnc .x
    mov edi, DATA_BUF
    xor eax, eax
    mov ecx, 32
    cld
    rep stosb
    mov edi, DATA_BUF
    mov esi, si_trn
.c: lodsb
    test al, al
    jz .w
    stosb
    jmp .c
.w: mov ecx, 32
    mov esi, si_trn
    call file_write
.x: mov byte [fs_par], 0
    ret

si_trn      db "FloTerm.sys", 0

; Создать папку esi в текущей папке. al = её номер. CF = не вышло
si_mkdir:
    push esi
    call dir_mkdir
    jc .e
    pop esi
    push esi
    call dir_find
    jc .e
    call dir_last_id
    pop esi
    clc
    ret
.e: pop esi
    stc
    ret

si_err      db 0
si_d0       db 0
si_d2       db 0
si_d3       db 0
si_d4       db 0
si_d5       db 0
si_d6       db 0
si_d7       dd 0
si_d1       dd 0
si_dbg      times 40 db 0
si_msg      db "boot err 0", 0
si_ids      db 0, 0, 0
si_flopsys  db "flopsys", 0
si_programs db "programs", 0
si_games    db "games", 0
si_boild    db "boil", 0
si_bsys     db "FloBoil.sys", 0
si_brec     db "record.txt", 0
si_itgep    db "itge_program", 0
si_isys     db "FloItge.sys", 0
si_n1       db "asm.sys", 0
si_n2       db "aqe.sys", 0
si_n4       db "FloText.sys", 0
si_n5       db "FloFile.sys", 0
si_n6       db "FloCalc.sys", 0
si_n7       db "FloTasks.sys", 0
si_n8       db "FloPaint.sys", 0
; имя, модуль, резерв, папка (1 programs)
si_files    dd si_n4, 0x34000, 0, 1
            dd si_n5, 0x42000, 0, 1
            dd si_n6, 0x30000, 0, 1
            dd si_n7, 0, 0, 1
            dd si_n8, 0x38000, 0, 1
            dd 0, 0, 0, 0
