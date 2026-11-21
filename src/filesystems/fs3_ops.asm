; Floppy_152 folders: FSM3 operations in root and nested folders.
; Only virtual volumes, no legacy FSM2 directory writes.
; All public entries return CF on failure and preserve caller registers.
;
fs3o_guard:
    cmp byte [fs_state], 3
    jne .bad
    cmp dword [cur_size], 0
    je .bad
    call fs3_catalog_count
    jc .bad
    ; A nonroot parent must name an existing directory slot.
    mov eax, [fs3_folder_id]
    cmp eax, 1024
    ja .bad
    test eax, eax
    jz .valid
    dec eax
    call fs3_dir_read
    jc .bad
    cmp byte [edi + 24], 2
    jne .bad
.valid:
    clc
    ret
.bad: stc
    ret

; Validate a zero-terminated name of 1..14 chars, input ESI.
fs3o_namecheck:
    push eax
    push ecx
    xor ecx, ecx
.loop:
    cmp ecx, 15
    jae .bad
    mov al, [esi+ecx]
    test al, al
    jz .finish
    cmp al, '/'
    je .bad
    cmp al, 92
    je .bad
    inc ecx
    jmp .loop
.finish:
    test ecx, ecx
    jz .bad
    pop ecx
    pop eax
    clc
    ret
.bad:
    pop ecx
    pop eax
    stc
    ret

; Write a validated NUL-terminated FSM3 filename into the 16-byte name
; field. Never copy bytes beyond the source's terminating NUL. Fill the
; unused destination bytes with zero, as the catalog requires. A name is
; at most 14 chars; caller checked it with fs3o_namecheck.
; Input ESI=name, EDI=16-byte directory name field; advances ESI/EDI.
; Preserves EAX and ECX.
fs3o_name_store:
    push eax
    push ecx
    mov ecx, 16
    cld
.copy:
    lodsb
    stosb
    dec ecx
    jz .done
    test al, al
    jnz .copy
    xor eax, eax
    rep stosb
.done:
    pop ecx
    pop eax
    ret

; Find a name in the current folder. ESI=filename, CF=0: EAX=slot, EDI=entry.
; CF=1 returns EAX=-1 for a missing name or EAX=-2 for a read error.
fs3o_find:
    mov [fs3o_name], esi
    xor ecx, ecx
.scan:
    cmp ecx, 1024
    jae .missing
    mov eax, ecx
    call fs3_dir_read
    jc .io_error
    cmp byte [edi+24], 0
    je .next
    mov ax, [fs3_folder_id]
    cmp word [edi+26], ax
    jne .next
    mov esi, [fs3o_name]
    xor edx, edx
.cmp:
    cmp edx, 15
    jae .next
    mov al, [esi+edx]
    cmp al, [edi+edx]
    jne .next
    test al, al
    jz .found
    inc edx
    jmp .cmp
.next:
    inc ecx
    jmp .scan
.found:
    mov eax, ecx
    clc
    ret
.missing:
    mov eax, -1
    stc
    ret
.io_error:
    mov eax, -2
    stc
    ret

; Find first completely free slot, EAX=index, EDI=entry.
fs3o_free:
    xor ecx, ecx
.loop:
    cmp ecx, 1024
    jae .bad
    mov eax, ecx
    call fs3_dir_read
    jc .bad
    cmp byte [edi+24], 0
    jne .next
    push ecx
    push edi
    mov ecx, 16
    xor eax, eax
    cld
    repe scasd
    pop edi
    pop ecx
    jne .bad
    mov eax, ecx
    clc
    ret
.next:
    inc ecx
    jmp .loop
.bad:
    stc
    ret

; Commit DIR_BUF sector for slot EAX; caller must still have correct buffer.
fs3o_commit:
    shr eax, 3
    add eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_write
    jc .bad
    jmp ata_flush
.bad: stc
    ret

; ESI=name, DL=kind (1 regular file, 2 directory).
fs3o_create:
    pushad
    mov [fs3o_name], esi
    mov [fs3o_kind], dl
    call fs3o_guard
    jc .bad
    mov esi, [fs3o_name]
    call fs3o_namecheck
    jc .bad
    mov esi, [fs3o_name]
    call fs3o_find
    jnc .bad                       ; duplicate
    cmp eax, -1
    jne .bad                       ; a read error does not prove absence
    call fs3o_free
    jc .bad
    mov [fs3o_slot], eax
    mov esi, [fs3o_name]
    call fs3o_name_store            ; NUL-terminated name + zero-filled tail
    mov edi, DIR_BUF
    mov eax, [fs3o_slot]
    and eax, 7
    shl eax, 6
    add edi, eax
    mov dword [edi+16], 0
    mov dword [edi+20], 0xFFFFFFFF
    mov dl, [fs3o_kind]
    mov byte [edi+24], dl
    mov byte [edi+25], 0
    mov ax, [fs3_folder_id]
    mov word [edi+26], ax
    mov eax, [fs3o_slot]
    call fs3o_commit
    jc .bad
    popad
    clc
    ret
.bad:
    popad
    stc
    ret

; Existing file: old bounded writer. New file: only empty files for now.
fs3_write_root:
    test ecx, ecx
    jnz fs3_file_write_small
    mov dl, 1
    jmp fs3o_create

fs3_mkdir_root:
    mov dl, 2
    jmp fs3o_create

; Rename file or folder in root. ESI=old, EDX=new.
fs3_rename_root:
    pushad
    mov [fs3o_old], esi
    mov [fs3o_new], edx
    call fs3o_guard
    jc .bad
    mov esi, [fs3o_new]
    call fs3o_namecheck
    jc .bad
    mov esi, [fs3o_new]
    call fs3o_find
    jnc .bad
    cmp eax, -1
    jne .bad
    mov esi, [fs3o_old]
    call fs3o_find
    jc .bad
    mov [fs3o_slot], eax
    ; Reload exact sector after search; then replace name bytes only.
    mov eax, [fs3o_slot]
    call fs3_dir_read
    jc .bad
    mov esi, [fs3o_new]
    call fs3o_name_store            ; replace all 16 bytes, no stale padding
    mov eax, [fs3o_slot]
    call fs3o_commit
    jc .bad
    popad
    clc
    ret
.bad:
    popad
    stc
    ret

; Delete an empty folder or a file of any size supported by FSM3.
; The complete FAT chain is validated BEFORE the catalog entry is cleared.
; The directory commit happens first; an I/O error while releasing clusters
; can leak disk space but must not leave a live entry pointing at freed data.
; An interrupted deletion is not a repair operation.
fs3_delete_root:
    pushad
    mov [fs3o_old], esi
    call fs3o_guard
    jc .bad
    mov esi, [fs3o_old]
    call fs3o_find
    jc .bad
    mov [fs3o_slot], eax
    cmp byte [edi+24], 2
    je .folder
    cmp byte [edi+24], 1
    jne .bad
    mov eax, [edi+16]
    mov [fs3o_del_size], eax
    mov eax, [edi+20]
    mov [fs3o_cluster], eax
    cmp dword [fs3o_del_size], 0
    jne .nonempty
    cmp eax, 0xFFFFFFFF
    jne .bad
    jmp .clear
.nonempty:
    ; The global catalog check in fs3o_guard already validates chains,
    ; but validate this precise record once more immediately before commit.
    call fs3_check_file_chain
    jc .bad
    jmp .clear
.folder:
    ; Check whether any occupied entry references this folder ID.
    mov eax, [fs3o_slot]
    inc eax
    mov [fs3o_parent], ax
    xor ebp, ebp
.child:
    cmp ebp, 1024
    jae .folder_clear
    mov eax, ebp
    call fs3_dir_read
    jc .bad
    cmp byte [edi+24], 0
    je .child_next
    mov ax, [fs3o_parent]
    cmp word [edi+26], ax
    je .bad
.child_next:
    inc ebp
    jmp .child
.folder_clear:
    mov dword [fs3o_cluster], 0xFFFFFFFF
.clear:
    mov eax, [fs3o_slot]
    call fs3_dir_read
    jc .bad
    push edi
    xor eax, eax
    mov ecx, 16
    cld
    rep stosd
    pop edi
    mov eax, [fs3o_slot]
    call fs3o_commit
    jc .bad
    ; Release the exact validated old chain. On I/O failure, return an
    ; error: the file may already be removed, so do not retry blindly.
    mov eax, [fs3o_cluster]
    cmp eax, 0xFFFFFFFF
    je .good
    mov edx, [fs3o_del_size]
    add edx, 511
    shr edx, 9
    mov [fs3o_del_left], edx
.release:
    cmp dword [fs3o_del_left], 0
    je .good
    mov [fs3o_del_curr], eax
    call fat_get
    jc .bad
    mov [fs3o_del_next], eax
    mov eax, [fs3o_del_curr]
    xor edx, edx
    call fat_set
    jc .bad
    mov eax, [fs3o_del_next]
    dec dword [fs3o_del_left]
    jmp .release
.good:
    popad
    clc
    ret
.bad:
    popad
    stc
    ret

fs3o_name   dd 0
fs3o_old    dd 0
fs3o_new    dd 0
fs3o_slot   dd 0
fs3o_cluster dd 0
fs3o_parent dw 0
fs3o_kind   db 0

; FSM3 deletion scratch: separate from active sector buffers.
fs3o_del_size dd 0
fs3o_del_left dd 0
fs3o_del_curr dd 0
fs3o_del_next dd 0
