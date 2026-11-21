; Установка Floppy 1.1 на другой диск. Подключается из kernel32.asm
; Показывается при запуске, пока Floppy не стоит ни на диске O, ни на диске I (там в секторе 313 лежит FloFile.sys с признаком FSYS).
; Управление только стрелками и Enter. Шаги: приветствие, выбор диска, "всё сотрётся?", копирование, перезагрузка.
IST_DIR equ 0x3F0000                    ; копия каталога диска C (8 секторов)
IST_MAP equ 0x3F2000                    ; старый номер папки -> новый
IST_DONE equ 0x3F2100                   ; какие записи уже скопированы
IST_SYS equ 512                         ; столько секторов в начале диска занимает система

; При запуске: нужна ли установка
ist_check:
    pushad
    movzx eax, byte [0x4F1]             ; меню загрузки записало, с какого диска грузимся
    test al, al
    jz .c
    cmp al, 0x80
    jne .r                              ; загрузились с диска, куда Floppy уже поставили
.c: mov eax, 480                        ; пометка: диск C выбран главным, остальные очищены
    mov dl, 0
    mov ebx, DATA_BUF
    call ist_rd
    jc .nm
    cmp dword [DATA_BUF], 'CMAN'
    je .r
.nm:mov ebx, 1
.l: cmp byte [dk_present + ebx], 0
    je .n
    mov eax, 313
    mov dl, bl
    mov ebx, DATA_BUF
    call ist_rd
    movzx ebx, dl
    jc .n
    cmp dword [DATA_BUF], 'FSYS'
    je .r                               ; уже установлено
.n: inc ebx
    cmp ebx, 3
    jb .l
    mov byte [d2_ist], 1
    mov byte [ist_st], 1
    mov byte [ist_sel], 0
    call redraw
.r: popad
    ret

; Сектор eax диска dl (0 C, 1 O, 2 I) в ebx / из ebx. CF = ошибка
ist_rd:
    mov [cur_drive], dl
    mov dword [cur_base], 0
    mov dword [cur_size], 0
    jmp lba_read
ist_wr:
    mov [cur_drive], dl
    mov dword [cur_base], 0
    mov dword [cur_size], 0
    jmp lba_write

; Сколько пунктов на этом шаге -> eax
ist_nopt:
    movzx eax, byte [ist_st]
    movzx eax, byte [ist_ntab + eax]
    cmp byte [ist_st], 2
    jne .r
    movzx eax, byte [ist_ndk]
    inc eax                             ; диски и Back
.r: ret

; Клавиши
ist_key:
    pushad
    cmp byte [ist_st], 4
    je .r
    cmp al, 0x90
    jne .a
    cmp byte [ist_sel], 0
    je .r
    dec byte [ist_sel]
    jmp .d
.a: cmp al, 0x91
    jne .b
    call ist_nopt
    movzx ebx, byte [ist_sel]
    inc ebx
    cmp ebx, eax
    jae .r
    mov [ist_sel], bl
    jmp .d
.b: cmp al, 13
    jne .r
    call ist_enter
.d: call ist_draw
.r: popad
    ret

ist_enter:
    movzx eax, byte [ist_st]
    movzx ebx, byte [ist_sel]
    mov byte [ist_sel], 0
    cmp eax, 9
    jne .n9
    mov [kb_ru], bl                     ; раскладка
    mov byte [ist_st], 10
    mov al, [ui_ru]
    mov [ist_sel], al
    ret
.n9:cmp eax, 10
    jne .n10
    mov [ui_ru], bl                     ; язык
    mov byte [ist_st], 11
    mov byte [ist_sel], 15              ; UTC+3, Москва
    ret
.n10:cmp eax, 11
    jne .n11
    sub bl, 12                          ; часовой пояс
    mov [tz_off], bl
    mov al, [ist_nx]
    mov [ist_st], al
    ret
.n11:
    cmp eax, 1
    jne .s2
    test ebx, ebx
    jnz ist_reboot                      ; No: назад в серое меню
    jmp ist_disks
.s2:cmp eax, 2
    jne .s3
    cmp bl, [ist_ndk]
    jae .back
    mov al, [ist_dk + ebx]
    mov [ist_tg], al
    movzx eax, al
    test eax, eax
    jnz .nc
    mov byte [ist_nx], 7                ; C главным: остальные диски очистятся
    jmp ist_reg
.nc:cmp dword [dk_total + eax * 4], 2048
    jb .small
    mov byte [ist_nx], 3
    jmp ist_reg
.small:
    mov esi, s_ist_sm
    jmp ist_fail
.back:
    mov byte [ist_st], 1
    ret
.s3:cmp eax, 3
    jne .s5
    test ebx, ebx
    jnz ist_disks                       ; No: выбрать другой диск
    jmp ist_run
.s5:cmp eax, 7
    jne .s8
    test ebx, ebx
    jnz ist_disks                       ; No: выбрать другой диск
    jmp ist_runc
.s8:cmp eax, 8
    je ist_reboot
    cmp eax, 5
    je ist_reboot
    jmp ist_disks                       ; после ошибки - снова выбор диска

; После выбора диска: раскладка, язык, часовой пояс, потом шаг ist_nx
ist_reg:
    mov byte [ist_st], 9
    mov al, [kb_ru]
    mov [ist_sel], al
    ret

; Настройки раскладки, языка и часового пояса записываются на новый главный диск
ist_setg:
    push eax
    mov al, [sys_dsk]
    push eax
    mov al, [ist_tg]
    mov [sys_dsk], al
    call st_save
    pop eax
    mov [sys_dsk], al
    pop eax
    ret

ist_reboot:
    mov al, 0xFE
    out 0x64, al
    jmp $

; Список дисков, куда можно ставить
ist_disks:
    mov byte [ist_st], 2
    mov byte [ist_ndk], 0
    xor ebx, ebx                        ; C тоже в списке
.l: cmp byte [dk_present + ebx], 0
    je .n
    movzx eax, byte [ist_ndk]
    mov [ist_dk + eax], bl
    inc byte [ist_ndk]
.n: inc ebx
    cmp ebx, 3
    jb .l
    ret

ist_fail:
    mov [ist_err], esi
    mov byte [ist_st], 6
    mov byte [ist_sel], 0
    ret

; Установка: система (первые 512 секторов), потом новый формат диска и все папки и файлы диска C
ist_run:
    mov byte [ist_st], 4
    mov dword [ist_pct], 0
    mov dword [ist_name], s_ist_sys
    call ist_draw
    xor ebp, ebp                        ; сектор
.sys:
    mov ecx, 64                         ; кусками по 64 сектора
    mov ebx, DATA_BUF
    mov eax, ebp
.rd:mov dl, 0
    call ist_rd
    jc .err
    inc eax
    add ebx, 512
    loop .rd
    mov ecx, 64
    mov ebx, DATA_BUF
    mov eax, ebp
.wr:mov dl, [ist_tg]
    call ist_wr
    jc .err
    inc eax
    add ebx, 512
    loop .wr
    add ebp, 64
    mov eax, ebp
    imul eax, 30
    shr eax, 9
    mov [ist_pct], eax
    call ist_bar
    cmp ebp, IST_SYS
    jb .sys
    movzx eax, byte [ist_tg]            ; новая файловая система на весь диск
    call fs_setdisk
    call fs_format
    jc .err
    xor eax, eax                        ; каталог диска C
    call fs_setdisk
    jc .err
    mov ecx, [fs_dirn]
    mov eax, [fs_dir]
    mov ebx, IST_DIR
.dr:call lba_read
    jc .err
    inc eax
    add ebx, 512
    loop .dr
    mov edi, IST_MAP
    mov ecx, 0x200 / 4
    xor eax, eax
    rep stosd
    xor ecx, ecx                        ; сколько всего записей
    mov esi, IST_DIR
    mov edx, [fs_dirn]
    shl edx, 4
    mov [ist_ne], edx
.cn:cmp byte [esi], 2
    jb .cn2
    inc ecx
.cn2:add esi, 32
    dec edx
    jnz .cn
    mov [ist_tot], ecx
    mov dword [ist_cnt], 0
    mov dword [ist_pass], 0
.pass:
    mov dword [ist_prog], 0
    mov dword [ist_i], 0
.ent:
    mov eax, [ist_i]
    cmp eax, [ist_ne]
    jae .pe
    mov esi, eax
    shl esi, 5
    add esi, IST_DIR
    mov [ist_e], esi
    cmp byte [esi], 2
    jb .nx
    cmp byte [IST_DONE + eax], 0
    jne .nx
    movzx ebx, byte [esi + 25]          ; родитель уже есть на новом диске?
    test ebx, ebx
    jz .ok
    cmp byte [IST_MAP + ebx], 0
    je .nx
.ok:mov al, [IST_MAP + ebx]
    mov [ist_np], al
    mov [ist_name], esi
    cmp byte [esi + 15], 1
    je .dir
    xor eax, eax                        ; файл: прочитать с C
    call fs_setdisk
    jc .err
    mov esi, [ist_e]
    mov al, [esi + 25]
    mov [fs_par], al
    call file_read
    jc .skip
    mov [ist_sz], eax
    movzx eax, byte [ist_tg]            ; и записать на новый диск
    call fs_setdisk
    jc .err
    mov al, [ist_np]
    mov [fs_par], al
    mov esi, [ist_e]
    mov ecx, [ist_sz]
    call file_write
    jc .full
    jmp .meta
.dir:
    movzx eax, byte [ist_tg]
    call fs_setdisk
    jc .err
    mov al, [ist_np]
    mov [fs_par], al
    mov esi, [ist_e]
    call dir_mkdir
    jc .full
    mov esi, [ist_e]
    call dir_find
    jc .err
    call dir_last_id
    mov ebx, [ist_i]
    inc ebx
    mov [IST_MAP + ebx], al
.meta:                                  ; признаки и даты как на диске C
    mov esi, [ist_e]
    call dir_find
    jc .skip
    mov ebx, [ist_e]
    mov al, [ebx + 24]
    mov [edi + 24], al
    mov eax, [ebx + 26]
    mov [edi + 26], eax
    mov ax, [ebx + 30]
    mov [edi + 30], ax
    call dir_write
.skip:
    mov eax, [ist_i]
    mov byte [IST_DONE + eax], 1
    inc dword [ist_cnt]
    mov dword [ist_prog], 1
    mov eax, [ist_cnt]
    imul eax, 70
    xor edx, edx
    mov ecx, [ist_tot]
    test ecx, ecx
    jz .nx
    div ecx
    add eax, 30
    mov [ist_pct], eax
    call ist_bar
.nx:inc dword [ist_i]
    jmp .ent
.pe:mov eax, [ist_cnt]
    cmp eax, [ist_tot]
    jae .done
    cmp dword [ist_prog], 0
    je .done                            ; остались записи без родителя - их пропускаем
    inc dword [ist_pass]
    cmp dword [ist_pass], 16
    jb .pass
.done:
    call ist_setg
    call ata_flush
    mov byte [fs_par], 0
    mov byte [ist_st], 5
    mov byte [ist_sel], 0
    ret
.full:
    mov byte [fs_par], 0
    mov esi, s_ist_full
    jmp ist_fail
.err:
    mov byte [fs_par], 0
    mov esi, s_ist_dsk
    jmp ist_fail

; C главный: на дисках O и I стираем систему (первые 512 секторов) и делаем новую пустую файловую систему
ist_runc:
    mov byte [ist_st], 4
    mov dword [ist_pct], 0
    mov dword [ist_name], s_ist_clr
    call ist_draw
    mov edi, DATA_BUF
    mov ecx, 64 * 512 / 4
    xor eax, eax
    rep stosd
    mov byte [ist_ci], 1
.dk:movzx edx, byte [ist_ci]
    cmp byte [dk_present + edx], 0
    je .nd
    xor ebp, ebp
.ch:mov ecx, 64
    mov ebx, DATA_BUF
    mov eax, ebp
.wr:movzx edx, byte [ist_ci]
    call ist_wr
    jc .err
    inc eax
    add ebx, 512
    loop .wr
    add ebp, 64
    cmp ebp, IST_SYS
    jb .ch
    movzx eax, byte [ist_ci]
    call fs_setdisk
    call fs_format
    jc .err
.nd:movzx eax, byte [ist_ci]
    imul eax, 50
    mov [ist_pct], eax
    call ist_bar
    inc byte [ist_ci]
    cmp byte [ist_ci], 3
    jb .dk
    mov dword [ist_pct], 100
    call ist_bar
    call ist_setg
    mov dword [DATA_BUF], 'CMAN'        ; пометка на диске C, чтобы окно установки не появлялось снова
    mov eax, 480
    mov dl, 0
    mov ebx, DATA_BUF
    call ist_wr
    call ata_flush
    mov byte [ist_st], 8
    mov byte [ist_sel], 0
    ret
.err:
    mov byte [fs_par], 0
    mov esi, s_ist_dsk
    jmp ist_fail

; Строка esi в точке eax, ebx цветом ecx
ist_txt:
    mov [t_x], eax
    mov [t_y], ebx
    mov [r_c], ecx
    jmp draw_big

; Весь экран установки
ist_draw:
    pushad
    xor eax, eax
    mov [cw_x], eax
    mov [cw_y], eax
    RECT 0, 0, 800, 600, 3
    xor ebx, ebx
.s: mov eax, ebx
    shl eax, 2
    mov [r_x], eax
    mov dword [r_y], 0
    mov dword [r_w], 2
    mov dword [r_h], 600
    mov dword [r_c], 4
    call fill_rect
    inc ebx
    cmp ebx, 200
    jb .s
    RECT 88, 128, 640, 360, C_BLACK
    RECT 80, 120, 640, 360, C_BLACK
    RECT 82, 122, 636, 356, C_WHITE
    RECT 82, 160, 636, 2, C_BLACK
    mov esi, s_ist_t
    mov eax, 400 - 16 * 16 / 2
    mov ebx, 126
    mov ecx, C_BLACK
    call ist_txt
    call ist_pic                        ; картинка этого шага справа от текста
    movzx eax, byte [ist_st]            ; три строки текста этого шага
    imul eax, 12
    lea ebp, [ist_lines + eax]
    xor edi, edi
.tl:mov esi, [ebp + edi * 4]
    test esi, esi
    jz .tn
    cmp esi, 1
    jne .tp
    mov esi, [ist_name]                 ; 1 - имя того, что сейчас копируется
.tp:cmp esi, 2
    jne .tq
    mov esi, [ist_err]                  ; 2 - текст ошибки
.tq:cmp esi, 3
    jne .tr
    movzx eax, byte [ist_tg]            ; 3 - "Disk O"
    mov al, [dt_letters + eax]
    mov [s_ist_dl + 5], al
    mov esi, s_ist_dl
.tr:mov eax, 104
    mov ebx, edi
    imul ebx, 34
    add ebx, 180
    mov ecx, C_BLACK
    call ist_txt
.tn:inc edi
    cmp edi, 3
    jb .tl
    cmp byte [ist_st], 4
    jne .opt
    call ist_bar
    jmp .h
.opt:
    call ist_nopt                       ; пункты: выбранный - чёрная полоса
    mov [ist_no], eax
    xor edi, edi
    cmp byte [ist_st], 11               ; часовые пояса: окно из пяти строк вокруг выбранного
    jne .ol
    movzx edi, byte [ist_sel]
    sub edi, 2
    jns .f1
    xor edi, edi
.f1:cmp edi, 22
    jbe .f2
    mov edi, 22
.f2:mov [ist_first], edi
    lea eax, [edi + 5]
    mov [ist_no], eax
.ol:cmp edi, [ist_no]
    jae .h
    mov ebx, edi
    imul ebx, 40
    add ebx, 300
    cmp byte [ist_st], 11
    jne .o2
    mov eax, [ist_first]
    imul eax, 40
    sub ebx, eax
    jmp .s70
.o2:cmp byte [ist_st], 2                ; в списке дисков четыре пункта: выше, чтобы не налезали на подсказку
    jne .ob
.s70:sub ebx, 70
.ob:mov ecx, C_BLACK
    movzx eax, byte [ist_sel]
    cmp eax, edi
    jne .ot
    mov [r_y], ebx
    mov dword [r_x], 96
    mov dword [r_w], 608
    mov dword [r_h], 36
    mov dword [r_c], C_BLACK
    call fill_rect
    mov ecx, C_WHITE
.ot:add ebx, 2
    push ecx
    push ebx
    call ist_optname
    pop ebx
    pop ecx
    mov eax, 112
    call ist_txt
    inc edi
    jmp .ol
.h: mov esi, s_ist_h
    mov eax, 104
    mov ebx, 440
    mov ecx, C_BLACK
    call ist_txt
    popad
    ret


; Картинка шага 16x16, каждая точка 3x3, справа: правый край на одной линии с пунктами (704), верх под полосой заголовка
ist_pic:
    pushad
    movzx eax, byte [ist_st]
    mov esi, [ist_pics + eax * 4]
    test esi, esi
    jz .r
    xor ebp, ebp                        ; строка
.row:
    xor ebx, ebx                        ; колонка
.col:
    movzx edx, byte [esi]
    inc esi
    cmp dl, '.'
    je .n
    mov ecx, C_BLACK
    cmp dl, 'B'
    jne .nb
    mov ecx, C_BLUE
.nb:cmp dl, 'W'
    jne .nw
    mov ecx, C_WHITE
.nw:cmp dl, 'G'
    jne .ng
    mov ecx, C_GRAY
.ng:cmp dl, 'g'                          ; светло-серый
    jne .ng2
    mov ecx, 7
.ng2:cmp dl, 'd'                         ; тёмно-серый
    jne .ng3
    mov ecx, 8
.ng3:mov [r_c], ecx
    mov eax, ebx
    imul eax, 3
    add eax, 656
    mov [r_x], eax
    mov eax, ebp
    imul eax, 3
    add eax, 170
    mov [r_y], eax
    mov dword [r_w], 3
    mov dword [r_h], 3
    call fill_rect
.n: inc ebx
    cmp ebx, 16
    jb .col
    inc ebp
    cmp ebp, 16
    jb .row
.r: popad
    ret

; Какая картинка на каком шаге (0 - нет): привет, диски, сотрётся?, копирование, готово, ошибка, диск C главный?, диск C готово
ist_pics    dd 0, pic_floppy, pic_hdd, pic_qm, pic_arrows, pic_check, pic_nofloppy, pic_qm, pic_check, pic_qm, pic_qm, pic_qm
pic_floppy:
    db "KKKKKKKKKKKKKKKK"
    db "KBBBBKKKKGGKBBBK"
    db "KBBBBKKKKGGKBBBK"
    db "KBBBBKKKKGGKBBBK"
    db "KBBBBKKKKGGKBBBK"
    db "KBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBK"
    db "KBBBBBBBBBBBBBBK"
    db "KBBBGGGGGGGGGBBK"
    db "KBBBWWWWWWWWWBBK"
    db "KBBBWWWWWWWWWBBK"
    db "KBBBWWWWWWWWWBBK"
    db "KBBBWWWWWWWWWBBK"
    db "KKKKKKKKKKKKKKKK"
pic_hdd:
    db "..KKKKKKKKKKKK.."
    db "..KdddKKKKdddK.."
    db "..KddKggggKddK.."
    db "..KdKggddggKdK.."
    db "..KdKgddddgKdK.."
    db "..KdKgddddgKdK.."
    db "..KdKggddggKdK.."
    db "..KdKdggggKddK.."
    db "..KdgKKKKKdddK.."
    db "..KgdddddddddK.."
    db "..KddddddddddK.."
    db "..KdddddKKKddK.."
    db "..KddddKgggKdK.."
    db "..KdddddKKKddK.."
    db "..KddddddddddK.."
    db "..KKKKKKKKKKKK.."
pic_qm:
    db "................"
    db ".....KKKKKK....."
    db "....KKKKKKKK...."
    db "...KKK....KKK..."
    db "...KK......KK..."
    db "...........KK..."
    db "..........KKK..."
    db ".........KKK...."
    db "........KKK....."
    db ".......KKK......"
    db ".......KK......."
    db ".......KK......."
    db "................"
    db ".......KK......."
    db ".......KK......."
    db "................"
pic_arrows:
    db "................"
    db "................"
    db ".....KKKKKK....."
    db "....KKKKKKKK...."
    db "...KKK....KKK..."
    db "..KKK......K...."
    db "...K......KKKKKK"
    db "..KKK.....KKKKK."
    db ".KKKKK.....KKK.."
    db "KKKKKK......K..."
    db "....K......KKK.."
    db "...KKK....KKK..."
    db "....KKKKKKKK...."
    db ".....KKKKKK....."
    db "................"
    db "................"
pic_check:
    db "................"
    db "..............KK"
    db ".............KKK"
    db "............KKK."
    db "...........KKK.."
    db "..KK......KKK..."
    db "..KKK....KKK...."
    db "...KKK..KKK....."
    db "....KKKKKK......"
    db ".....KKKK......."
    db "......KK........"
    db "................"
    db "................"
    db "................"
    db "................"
    db "................"
pic_nofloppy:
    db "KKKKKKKKKKKKKWWK"
    db "KBBBBKKKKGGKWWKK"
    db "KBBBBKKKKGGWWKKW"
    db "KBBBBKKKKGWWKKWW"
    db "KBBBBKKKKWWKKWWK"
    db "KBBBBBBBWWKKWWBK"
    db "KBBBBBBWWKKWWBBK"
    db "KBBBBBWWKKWWBBBK"
    db "KBBBBWWKKWWBBBBK"
    db "KBBBWWKKWWBBBBBK"
    db "KBBWWKKWWGGGGBBK"
    db "KBWWKKWWWWWWWBBK"
    db "KWWKKWWWWWWWWBBK"
    db "WWKKWWWWWWWWWBBK"
    db "WKKWWWWWWWWWWBBK"
    db "KKWWKKKKKKKKKKKK"

; Надпись пункта edi -> esi
ist_optname:
    movzx eax, byte [ist_st]
    cmp eax, 11
    je .tz
    cmp eax, 2
    jne .o
    movzx eax, byte [ist_ndk]
    cmp edi, eax
    jae .bk
    movzx ebx, byte [ist_dk + edi]      ; "Disk O - 16 MB"
    push edi
    mov edi, ist_ob
    mov esi, s_ist_dk
.c: lodsb
    stosb
    test al, al
    jnz .c
    dec edi
    mov al, [dt_letters + ebx]
    stosb
    mov al, ' '
    stosb
    mov al, '-'
    stosb
    mov al, ' '
    stosb
    mov eax, [dk_total + ebx * 4]
    shr eax, 11
    call u32str
    mov esi, s_ist_mb
.c2:lodsb
    stosb
    test al, al
    jnz .c2
    pop edi
    mov esi, ist_ob
    ret
.bk:mov esi, s_ist_back
    ret
.tz:push edi                            ; "UTC+3 - Moscow"
    mov ecx, edi
    mov ebx, edi
    sub ebx, 12
    mov edi, ist_ob
    mov byte [edi], 'U'
    mov byte [edi + 1], 'T'
    mov byte [edi + 2], 'C'
    add edi, 3
    mov dl, '+'
    test ebx, ebx
    jns .tp
    neg ebx
    mov dl, '-'
.tp:mov [edi], dl
    inc edi
    mov eax, ebx
    cmp eax, 10
    jb .to
    mov byte [edi], '1'
    inc edi
    sub eax, 10
.to:add al, '0'
    mov [edi], al
    inc edi
    mov byte [edi], 0
    cmp ecx, 15
    jne .te
    mov esi, s_ist_msk
    cmp byte [ui_ru], 0
    je .tc
    mov esi, s_ist_mskr
.tc:lodsb
    stosb
    test al, al
    jnz .tc
.te:pop edi
    mov esi, ist_ob
    ret
.o: imul eax, 8
    mov esi, [ist_opts + eax + edi * 4]
    ret

; Полоска копирования (ist_pct %)
ist_bar:
    pushad
    RECT 104, 300, 592, 36, C_BLACK
    RECT 106, 302, 588, 32, C_WHITE
    mov eax, [ist_pct]
    cmp eax, 100
    jbe .a
    mov eax, 100
.a: imul eax, 584
    xor edx, edx
    mov ecx, 100
    div ecx
    mov [r_w], eax
    mov dword [r_x], 108
    mov dword [r_y], 304
    mov dword [r_h], 28
    mov dword [r_c], C_BLACK
    call fill_rect
    RECT 104, 214, 592, 32, C_WHITE     ; имя файла
    mov esi, [ist_name]
    mov eax, 104
    mov ebx, 214
    mov ecx, C_BLACK
    call ist_txt
    RECT 360, 350, 96, 32, C_WHITE      ; проценты
    mov edi, ist_ob
    mov eax, [ist_pct]
    call u32str
    mov word [edi], '%'
    mov esi, ist_ob
    mov eax, 376
    mov ebx, 350
    mov ecx, C_BLACK
    call ist_txt
    popad
    ret

d2_ist      db 0
ist_st      db 0                        ; 1 привет, 2 диски, 3 сотрётся?, 4 копирование, 5 готово, 6 ошибка
ist_sel     db 0
ist_tg      db 0
ist_ndk     db 0
ist_dk      db 0, 0, 0
ist_ntab    db 0, 2, 0, 2, 0, 1, 1, 2, 1, 2, 2, 27
ist_ci      db 0
ist_no      dd 0
ist_first   dd 0
ist_nx      db 0
ist_pct     dd 0
ist_name    dd 0
ist_err     dd 0
ist_tot     dd 0
ist_cnt     dd 0
ist_pass    dd 0
ist_prog    dd 0
ist_i       dd 0
ist_ne      dd 0
ist_e       dd 0
ist_sz      dd 0
ist_np      db 0
ist_ob      times 24 db 0
; три строки текста на каждый шаг (0 - нет строки, 1 - имя файла, 2 - ошибка, 3 - "Disk O")
ist_lines   dd 0, 0, 0
            dd s_ist_w1, s_ist_w2, s_ist_w3
            dd s_ist_c1, 0, 0
            dd s_ist_e1, 3, s_ist_e2
            dd s_ist_i1, 0, 0
            dd s_ist_d1, s_ist_d2, 0
            dd s_ist_x1, 2, 0
            dd s_ist_c2, s_ist_c3, s_ist_c4
            dd s_ist_c5, s_ist_c6, 0
            dd s_ist_k1, 0, 0
            dd s_ist_l1, 0, 0
            dd s_ist_z1, 0, 0
ist_opts    dd 0, 0
            dd s_ist_yes, s_ist_no
            dd 0, 0
            dd s_ist_ey, s_ist_en
            dd 0, 0
            dd s_ist_rb, 0
            dd s_ist_back, 0
            dd s_ist_cy, s_ist_en
            dd s_ist_rb, 0
            dd s_ist_ken, s_ist_kru
            dd s_lang_en, s_lang_ru
            dd 0, 0
s_ist_t     db "Floppy 1.1 Setup", 0
s_ist_w1    db "Welcome to the Floppy 1.1 setup.", 0
s_ist_w2    db "It puts Floppy 1.1 and all your", 0
s_ist_w3    db "files on another disk.", 0
s_ist_yes   db "Yes - install Floppy 1.1", 0
s_ist_no    db "No - back to the boot menu", 0
s_ist_c1    db "Choose the disk for Floppy 1.1:", 0
s_ist_dk    db "Disk ", 0
s_ist_mb    db " MB", 0
s_ist_back  db "Back", 0
s_ist_e1    db "All files on this disk", 0
s_ist_dl    db "Disk X", 0
s_ist_e2    db "will be erased. Continue?", 0
s_ist_ey    db "Yes - erase and install", 0
s_ist_en    db "No - choose another disk", 0
s_ist_i1    db "Installing Floppy 1.1...", 0
s_ist_sys   db "system", 0
s_ist_d1    db "Floppy 1.1 is now installed.", 0
s_ist_d2    db "It is in the boot menu now.", 0
s_ist_rb    db "Reboot now", 0
s_ist_x1    db "Error:", 0
s_ist_sm    db "the disk is too small", 0
s_ist_full  db "the disk is full", 0
s_ist_dsk   db "the disk can't be read", 0
s_ist_c2    db "Disk C will be the main disk.", 0
s_ist_c3    db "Disks O and I will be erased.", 0
s_ist_c4    db "Continue?", 0
s_ist_c5    db "Disk C is the main disk now.", 0
s_ist_c6    db "Disks O and I are empty.", 0
s_ist_cy    db "Yes - erase O and I", 0
s_ist_clr   db "clearing disks", 0
s_ist_h     db "Arrows - choose, Enter - OK", 0
s_ist_k1    db "Choose the keyboard layout:", 0
s_ist_l1    db "Choose the language:", 0
s_ist_z1    db "Choose the time zone:", 0
s_ist_ken   db "English (EN)", 0
s_ist_kru   db 0xD0, 0xF3, 0xF1, 0xF1, 0xEA, 0xE0, 0xFF, " (RU)", 0
s_ist_msk   db " - Moscow", 0
s_ist_mskr  db " - ", 0xCC, 0xEE, 0xF1, 0xEA, 0xE2, 0xE0, 0

; Загрузились с диска O или I: он главный (sys_dsk), диск C остаётся, просто не главный
boot_main:
    movzx eax, byte [0x4F1]
    cmp al, 0x81
    je .h
    cmp al, 0x82
    jne .r
.h: sub al, 0x80
    mov [sys_dsk], al
.r: ret
