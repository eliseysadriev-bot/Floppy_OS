; Floppy_147: explicit, disposable-volume-only FSM3 single-file smoke test.
; Ctrl+T in Disks on a selected VIRTUAL FSM3 volume creates TEST.TXT containing
; "FSM3 OK\n" if the catalog is empty; repeated Ctrl+T verifies its contents.
; This is NOT a general-purpose file API. FSM2 writers remain disabled on FSM3.
;
; Input AL: selected dtab index. Output CF=0 verified, CF=1 refused / I/O error.
fs3_testfile:
    pushad
    movzx ebx, al
    cmp ebx, 3                        ; never touch physical C/O/I
    jb .fail
    cmp ebx, DT_N
    jae .fail
    imul ebx, DT_ESZ
    cmp byte [dtab + ebx], 0
    je .fail
    cmp dword [dtab + ebx + 6], 0     ; must be virtual
    je .fail
    ; Convert the validated byte offset back to its dtab slot index.
    mov eax, ebx
    xor edx, edx
    mov ecx, DT_ESZ
    div ecx
    call fs3_test_select             ; AL is slot index
    jc .fail
    cmp byte [fs_state], 3
    jne .fail
    call fs3_catalog_count
    jc .fail
    test eax, eax
    jnz .verify                      ; don't create on nonempty filesystem

    ; First FAT sector/entry MUST be free. We only allocate cluster zero.
    cmp dword [fs_nclus], 1
    jb .fail
    mov eax, [fs_fat]
    mov ebx, FAT_BUF
    call lba_read
    jc .fail
    cmp dword [FAT_BUF], 0
    jne .fail

    ; First directory slot MUST be empty and all zero.
    mov eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_read
    jc .fail
    cmp dword [DIR_BUF], 0
    jne .fail
    mov esi, DIR_BUF
    mov ecx, 128
    xor eax, eax
    cld
.chkfree:
    cmp dword [esi], eax
    jne .fail
    add esi, 4
    loop .chkfree

    ; Write payload first; it is not referenced until metadata commit.
    mov edi, FS2_BUF
    mov ecx, 128
    xor eax, eax
    rep stosd
    mov dword [FS2_BUF], 0x334D5346   ; "FSM3"
    mov dword [FS2_BUF + 4], 0x0A4B4F20 ; " OK\n"
    mov eax, [fsd_start]
    mov ebx, FS2_BUF
    call lba_write
    jc .fail

    ; Mark cluster zero end-of-chain. No changes to other FAT entries.
    mov dword [FAT_BUF], 0xFFFFFFFF
    mov eax, [fs_fat]
    mov ebx, FAT_BUF
    call lba_write
    jc .fail

    ; Commit new directory entry last. Before this, file is not visible.
    mov dword [DIR_BUF], 0x54534554 ; "TEST"
    mov dword [DIR_BUF + 4], 0x5458542E ; ".TXT"
    mov dword [DIR_BUF + 8], 0
    mov dword [DIR_BUF + 12], 0
    mov dword [DIR_BUF + 16], 8
    mov dword [DIR_BUF + 20], 0
    mov byte [DIR_BUF + 24], 1       ; regular file
    mov byte [DIR_BUF + 25], 0
    mov word [DIR_BUF + 26], 0       ; root folder
    mov eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_write
    jc .fail                      ; keep FAT reserved if write may be partial
    call ata_flush
    jmp .verify

.verify:
    ; Verify the on-disk entry, FAT linkage and actual file contents.
    mov eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_read
    jc .fail
    cmp dword [DIR_BUF], 0x54534554
    jne .fail
    cmp dword [DIR_BUF + 4], 0x5458542E
    jne .fail
    cmp dword [DIR_BUF + 16], 8
    jne .fail
    cmp dword [DIR_BUF + 20], 0
    jne .fail
    cmp byte [DIR_BUF + 24], 1
    jne .fail
    cmp word [DIR_BUF + 26], 0
    jne .fail
    mov eax, [fs_fat]
    mov ebx, FAT_BUF
    call lba_read
    jc .fail
    cmp dword [FAT_BUF], 0xFFFFFFFF
    jne .fail
    mov eax, [fsd_start]
    mov ebx, FS2_BUF
    call lba_read
    jc .fail
    cmp dword [FS2_BUF], 0x334D5346
    jne .fail
    cmp dword [FS2_BUF + 4], 0x0A4B4F20
    jne .fail
    call fs3_catalog_count
    jc .fail
    cmp eax, 1
    jne .fail
    popad
    clc
    ret
.fail:
    popad
    stc
    ret

fs3_test_select:
    call fs_setdisk
    jc .no
    cmp byte [fs_state], 3
    jne .no
    clc
    ret
.no:
    cmp byte [fs_state], 3
    jne .bad
    clc
    ret
.bad:
    stc
    ret
