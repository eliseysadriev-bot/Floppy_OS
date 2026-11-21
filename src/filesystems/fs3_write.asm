; Floppy_153 phase 1: copy-on-write multi-cluster FSM3 file replacement.
; ESI=existing name, ECX=bytes in DATA_BUF (1..262143), fs3_folder_id=parent.
; Pre-commit writes only to newly allocated free clusters. The existing
; directory entry is switched after every block and FAT link is written.
; If a write fails, the old directory entry remains unchanged; staged
; clusters may leak rather than being reclaimed in an uncertain state.
; This interface is NOT a 4 MiB streaming API. The shared DATA_BUF and
; client programs must be audited before raising the in-memory size cap.
fs3_file_write_small:
    pushad
    mov [fs3w_name], esi
    mov [fs3w_size], ecx
    cmp byte [fs_state], 3
    jne .fail
    cmp dword [cur_size], 0
    je .fail             ; never write physical disks through this path
    test ecx, ecx
    jz .fail
    cmp ecx, 262143      ; one extra byte for NUL in DATA_BUF
    ja .fail
    cmp dword [fs3_folder_id], 1024
    ja .fail
    call fs3_catalog_count
    jc .fail

    xor ebp, ebp
.find:
    cmp ebp, 1024
    jae .fail
    mov eax, ebp
    call fs3_dir_read
    jc .fail
    cmp byte [edi + 24], 1
    jne .next
    mov ax, [fs3_folder_id]
    cmp word [edi + 26], ax
    jne .next
    mov esi, [fs3w_name]
    xor edx, edx
.compare:
    cmp edx, 15
    jae .next
    mov al, [esi + edx]
    cmp al, [edi + edx]
    jne .next
    test al, al
    jz .found
    inc edx
    jmp .compare
.next:
    inc ebp
    jmp .find
.found:
    mov [fs3w_slot], ebp
    mov eax, [edi + 16]
    cmp eax, 262143
    ja .fail             ; do not replace files beyond current read limit
    mov [fs3w_old_size], eax
    mov eax, [edi + 20]
    mov [fs3w_old_cluster], eax
    ; Verify the entire old chain first, so existing corruption cannot
    ; cause us to free arbitrary blocks after the directory switch.
    mov eax, [fs3w_old_size]
    add eax, 511
    shr eax, 9
    mov [fs3w_old_blocks], eax
    mov eax, [fs3w_old_cluster]
    xor ebp, ebp
.oldcheck:
    cmp ebp, [fs3w_old_blocks]
    jae .oldend
    test eax, eax
    jz .fail
    cmp eax, [fs_nclus]
    jae .fail
    call fat_get
    jc .fail
    inc ebp
    jmp .oldcheck
.oldend:
    cmp eax, 0xFFFFFFFF
    jne .fail

    mov eax, [fs3w_size]
    add eax, 511
    shr eax, 9
    mov [fs3w_blocks], eax
    ; Avoid partially staged chains on a predictably full volume.
    call fat_count_free
    cmp eax, [fs3w_blocks]
    jb .fail
    mov dword [fs3w_index], 0
    mov dword [fs3w_first], 0xFFFFFFFF
    mov dword [fs3w_last], 0xFFFFFFFF
    ; A preallocated chain is intentionally private until commit.
.stage:
    mov eax, [fs3w_index]
    cmp eax, [fs3w_blocks]
    jae .commit
    call fat_alloc       ; eax=free cluster, marked EOC
    jc .fail
    mov [fs3w_new], eax
    ; Write the payload before linking the new block into the staged chain.
    add eax, [fsd_start]
    mov ebx, [fs3w_index]
    shl ebx, 9
    add ebx, DATA_BUF
    call lba_write
    jc .fail
    cmp dword [fs3w_first], 0xFFFFFFFF
    jne .link
    mov eax, [fs3w_new]
    mov [fs3w_first], eax
    jmp .nextblock
.link:
    mov eax, [fs3w_last]
    mov edx, [fs3w_new]
    call fat_set
    jc .fail
.nextblock:
    mov eax, [fs3w_new]
    mov [fs3w_last], eax
    inc dword [fs3w_index]
    jmp .stage

.commit:
    ; Reload directory and guard against stale record before replacing it.
    mov eax, [fs3w_slot]
    call fs3_dir_read
    jc .fail
    cmp byte [edi + 24], 1
    jne .fail
    mov ax, [fs3_folder_id]
    cmp word [edi + 26], ax
    jne .fail
    mov eax, [edi + 16]
    cmp eax, [fs3w_old_size]
    jne .fail
    mov eax, [edi + 20]
    cmp eax, [fs3w_old_cluster]
    jne .fail
    mov eax, [fs3w_size]
    mov [edi + 16], eax
    mov eax, [fs3w_first]
    mov [edi + 20], eax
    mov eax, [fs3w_slot]
    shr eax, 3
    add eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_write
    jc .fail             ; uncertain commit: do not free either chain
    call ata_flush
    ; After a successful commit, old chain is no longer reachable.
    ; fat_free has historically been used for FSM2, but we only call it
    ; after checking the old chain length and terminal marker above.
    mov eax, [fs3w_old_cluster]
    cmp eax, 0xFFFFFFFF
    je .success
    call fat_free
.success:
    mov eax, [fs3w_size]
    mov [f_size], eax
    popad
    clc
    ret
.fail:
    popad
    stc
    ret

fs3w_name        dd 0
fs3w_size        dd 0
fs3w_old_size    dd 0
fs3w_old_blocks  dd 0
fs3w_old_cluster dd 0
fs3w_slot        dd 0
fs3w_blocks      dd 0
fs3w_index       dd 0
fs3w_first       dd 0
fs3w_last        dd 0
fs3w_new         dd 0
