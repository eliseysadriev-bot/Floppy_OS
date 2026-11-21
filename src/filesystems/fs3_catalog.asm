; Floppy_146: FSM3 catalog, read-only inspection API.
; Catalog: 128 sectors, eight 64-byte slots per sector = 1024 slots.
; v1 slot layout (reserved for a later patch that implements writers):
; +0..15 zero-terminated name, +16 dd file length, +20 dd first cluster,
; +24 db kind (0 free, 1 file, 2 directory), +25 flags (reserved),
; +26 dw parent slot ID (0 root, 1..1024), rest reserved.
; This reader NEVER writes to the disk and NEVER enables FSM2 writers.
;
; fs3_dir_read: eax=entry index (0..1023), returns edi=slot in DIR_BUF,
; CF=0 on success. Works only after a successful FSM3 mount.
fs3_dir_read:
    push eax
    push ebx
    push edx
    cmp byte [fs_state], 3
    jne .bad
    cmp eax, 1024
    jae .bad
    mov edx, eax
    shr eax, 3                       ; eight slots per sector
    add eax, [fs_dir]
    and edx, 7
    shl edx, 6                       ; 64 bytes each
    mov ebx, DIR_BUF
    call lba_read
    jc .bad
    lea edi, [DIR_BUF + edx]
    pop edx
    pop ebx
    pop eax
    clc
    ret
.bad:
    pop edx
    pop ebx
    pop eax
    stc
    ret

; fs3_catalog_count: eax = occupied records, CF=0 only for valid catalog.
; Checks all 1024 entries; bounds check on file size, cluster and parent.
; Does not make damaged volumes writable or change their contents.
fs3_catalog_count:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    cmp byte [fs_state], 3
    jne .bad
    ; Build a map of existing directory slots before validating parent IDs.
    ; 1024 bits = 128 bytes. No volume data is changed.
    push eax
    push ecx
    push edi
    mov edi, fs3_dir_bitmap
    mov ecx, 32
    xor eax, eax
    cld
    rep stosd
    pop edi
    pop ecx
    pop eax
    ; Fail closed before scanning. Every possible cluster index must fit
    ; the bitmap; on-disk FAT entries remain 32-bit and unchanged.
    cmp dword [fs_nclus], FS3_MAX_SECTORS
    ja .bad
    ; One bit per data cluster, used to detect cross-linked files.
    ; Two files sharing a FAT cluster are unsafe to delete or overwrite.
    push eax
    push ecx
    push edi
    mov edi, fs3_cluster_bitmap
    mov ecx, FS3_BITMAP_DWORDS       ; 8192 bytes = 65,536 bits (32 MiB)
    xor eax, eax
    rep stosd
    pop edi
    pop ecx
    pop eax
    xor esi, esi                     ; slot index
    xor edx, edx                     ; occupied count
.loop:
    cmp esi, 1024
    jae .ok
    ; Read each sector once, then scan eight slots locally.
    mov eax, esi
    and eax, 7
    jnz .cached
    mov eax, esi
    shr eax, 3
    add eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_read
    jc .bad
.cached:
    mov edi, esi
    and edi, 7
    shl edi, 6
    add edi, DIR_BUF
    mov al, [edi + 24]
    test al, al
    jz .free
    cmp al, 2
    ja .bad
    cmp byte [edi], 0               ; occupied entries must be named
    je .bad
    ; Names must have a NUL within the first 15 bytes (max 14 chars).
    ; Otherwise the listing and name comparison may run into metadata.
    push ecx
    push edi
    mov ecx, 15
    xor eax, eax
    cld
    repne scasb
    pop edi
    pop ecx
    jne .bad
    cmp word [edi + 26], 1024
    ja .bad
    cmp byte [edi + 25], 0          ; flags not defined yet
    jne .bad
    ; AL is zeroed for REPNE SCASB above (NUL name terminator).
    ; Re-read the record kind, otherwise files are mistaken for folders.
    cmp byte [edi + 24], 1
    jne .directory
    cmp dword [edi + 16], 4194304
    ja .bad
    mov eax, [edi + 20]
    cmp dword [edi + 16], 0
    jne .nonempty_file
    cmp eax, 0xFFFFFFFF             ; empty file has no clusters
    jne .bad
    jmp .occupied
.nonempty_file:
    cmp eax, 0xFFFFFFFF             ; nonempty file must have a chain
    je .bad
    test eax, eax                   ; cluster 0 is reserved
    jz .bad
    cmp eax, [fs_nclus]
    jae .bad
    ; Phase 1 integrity: exact chain length / no cyclic or out-of-range
    ; links in each file. Read-only check; bad chains block every FSM3
    ; mutating operation that calls fs3_catalog_count.
    call fs3_check_file_chain
    jc .bad
    ; Chain length can be valid while another file points at the same
    ; clusters. Reject sharing before permitting any writes/deletes.
    call fs3_check_chain_unique
    jc .bad
    jmp .occupied
.directory:
    cmp dword [edi + 16], 0         ; directories carry no file data
    jne .bad
    cmp dword [edi + 20], 0xFFFFFFFF ; directories own no FAT chain
    jne .bad
    ; Slot number is zero-based; the parent directory ID is slot+1.
    bts dword [fs3_dir_bitmap], esi
    jmp .occupied
.free:
    ; A free slot must have all 64 bytes cleared.
    push ecx
    push edi
    xor eax, eax
    mov ecx, 16
    repe scasd
    pop edi
    pop ecx
    jne .bad
    jmp .next
.occupied:
    inc edx
.next:
    inc esi
    jmp .loop
.ok:
    ; Second pass: every nonroot entry must point at an existing directory.
    ; A directory cannot be its own parent. Invalid/missing parents make
    ; the whole volume fail the existing fail-closed catalog check.
    xor esi, esi
.parent_scan:
    cmp esi, 1024
    jae .cycle_start
    mov eax, esi
    and eax, 7
    jnz .parent_cached
    mov eax, esi
    shr eax, 3
    add eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_read
    jc .bad
.parent_cached:
    mov edi, esi
    and edi, 7
    shl edi, 6
    add edi, DIR_BUF
    cmp byte [edi + 24], 0
    je .parent_next
    movzx eax, word [edi + 26]
    test eax, eax
    jz .parent_next           ; root is parent ID 0
    dec eax                   ; parent ID -> directory slot index
    cmp eax, esi
    je .bad                   ; self-parent directory or file
    bt dword [fs3_dir_bitmap], eax
    jnc .bad                  ; parent slot is absent or not a directory
.parent_next:
    inc esi
    jmp .parent_scan
; Additional third pass: walk every directory ancestry to the root.
; Detect 2+ directory loops (A -> B -> A) that self-parent tests miss.
; Only reads directory sectors and never modifies the disk.
.cycle_start:
    xor esi, esi
.cycle_scan:
    cmp esi, 1024
    jae .parents_ok
    mov eax, esi
    call fs3_dir_read
    jc .bad
    cmp byte [edi + 24], 2
    jne .cycle_next
    movzx ebp, word [edi + 26]
    xor ecx, ecx
.cycle_walk:
    test ebp, ebp
    jz .cycle_next
    cmp ecx, 1024
    jae .bad
    dec ebp                         ; parent slot ID -> zero-based slot
    cmp ebp, esi                    ; reached this directory: cycle
    je .bad
    mov eax, ebp
    call fs3_dir_read              ; guaranteed in range by parent pass
    jc .bad
    cmp byte [edi + 24], 2
    jne .bad
    movzx ebp, word [edi + 26]
    inc ecx
    jmp .cycle_walk
.cycle_next:
    inc esi
    jmp .cycle_scan
.parents_ok:
    mov [fs3_count_result], edx
    mov eax, edx
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    clc
    ret
.bad:
    ; A malformed FSM3 catalog is never writable. The next explicit
    ; mount revalidates it. No attempt to repair data in-place.
    mov byte [fs_state], 4
    mov byte [fs_ok], 0
    cmp byte [fs3_alert_ready], 0
    je .silent
    mov byte [fs3_alert_pending], 1
.silent:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    stc
    ret


; Check a regular file's FAT chain without changing any volume data.
; Input EDI -> loaded 64-byte catalog entry. Return CF=1 if corrupted.
; An exact final EOC is required, so cycles, truncated / excess chains,
; and out-of-range cluster indices cannot pass.
fs3_check_file_chain:
    pushad
    mov ecx, [edi + 16]
    test ecx, ecx
    jz .bad                        ; caller handles zero-byte files
    add ecx, 511
    shr ecx, 9
    mov eax, [edi + 20]
.loop:
    test eax, eax
    jz .bad
    cmp eax, [fs_nclus]
    jae .bad
    call fat_get
    jc .bad
    dec ecx
    jnz .loop
    cmp eax, 0xFFFFFFFF
    jne .bad
    popad
    clc
    ret
.bad:
    popad
    stc
    ret

; Check that this file's data clusters are not also owned by another
; regular file encountered during the same catalog scan. The first
; fs3_check_file_chain pass already validated the chain and length.
fs3_check_chain_unique:
    pushad
    mov ecx, [edi + 16]
    add ecx, 511
    shr ecx, 9
    mov eax, [edi + 20]
.loop:
    test ecx, ecx
    jz .ok
    test eax, eax
    jz .bad
    cmp eax, [fs_nclus]
    jae .bad
    bts dword [fs3_cluster_bitmap], eax
    jc .bad
    call fat_get
    jc .bad
    dec ecx
    jmp .loop
.ok:
    popad
    clc
    ret
.bad:
    popad
    stc
    ret

; Keep the 8192-byte scratch bitmap in unused low RAM at 0x51000..0x52FFF.
; The boot process first relocates FloCalendar from 0x50000..0x51FFF to
; 0x54000..0x55FFF, so catalog checks can then reuse this space safely.
; This avoids enlarging the fixed-size kernel image or boot-menu layout.
; Only used by fs3_catalog_count; cleared on every invocation.
fs3_cluster_bitmap equ 0x51000
align 4
fs3_dir_bitmap times 128 db 0
fs3_count_result dd 0


; FSM3 paged listing of the current directory (16-bit parent ID).
; Called ONLY when fs_setdisk refused FSM3 (fs_ok remains 0).
; Output: lst_n names (maximum 32), 16-byte legacy display records.
; No writing, no folder traversal, no file read, no legacy IDs.
; FS3 full validation is performed first; a corrupt catalog stays blocked.
fs3_preview_root:
    pushad
    cmp byte [fs_state], 3
    jne .fail
    call fs3_catalog_count
    jc .fail
    ; fs_par comes from FloFile only for FSM3 preview (0..31 pages).
    ; Legacy FSM2 operations never reach this routine.
    movzx eax, byte [fs_par]
    cmp eax, 31
    ja .fail
    shl eax, 5                     ; 32 root records per page
    mov [fs3_preview_skip], eax
    xor esi, esi                    ; sector index (0..127)
.sector:
    cmp esi, FS3_DIRN
    jae .ok
    mov eax, [fs_dir]
    add eax, esi
    mov ebx, DIR_BUF
    call lba_read
    jc .fail
    xor ebp, ebp                    ; record in sector (0..7)
.entry:
    cmp ebp, 8
    jae .nextsector
    mov edx, ebp
    shl edx, 6
    lea ebx, [DIR_BUF + edx]
    mov al, [ebx + 24]
    test al, al
    jz .nextentry
    mov ax, [fs3_folder_id]
    cmp word [ebx + 26], ax       ; filter by current FSM3 parent
    jne .nextentry
    cmp dword [fs3_preview_skip], 0
    je .include
    dec dword [fs3_preview_skip]
    jmp .nextentry
.include:
    movzx eax, byte [lst_n]
    cmp eax, 32
    jae .ok                       ; limit of current FloFile list API
    mov edi, [f_lbuf]
    shl eax, 4
    add edi, eax
    ; Zero out display name, type and final byte first.
    push edi
    xor eax, eax
    mov ecx, 4
    rep stosd
    pop edi
    mov ecx, 14                   ; 14 visible characters + NUL
    mov edx, edi
    mov edi, ebx
.copy:
    mov al, [edi]
    test al, al
    jz .copied
    mov [edx], al
    inc edi
    inc edx
    loop .copy
.copied:
    movzx eax, byte [lst_n]
    ; Entry identity is catalog slot+1 (1..1024), split over two arrays.
    ; Do not squeeze FSM3 identifiers into the legacy FSM2 byte ID.
    mov edx, esi
    shl edx, 3
    add edx, ebp
    inc edx
    mov byte [lst_ids + eax], dl
    shr edx, 8
    mov byte [fs3_list_hi + eax], dl
    cmp byte [ebx + 24], 2
    jne .isfile
    mov edi, [f_lbuf]
    shl eax, 4
    mov byte [edi + eax + 15], 1 ; legacy folder display marker
.isfile:
    inc byte [lst_n]
.nextentry:
    inc ebp
    jmp .entry
.nextsector:
    inc esi
    jmp .sector
.ok:
    ; Special successful FSM3 preview result for FloFile.sys.
    ; Unlike fs_state this field is exported through kvarlist.inc.
    ; FloFile converts this marker back to ordinary status 0 immediately.
    mov byte [lst_st], 4
    popad
    ret
.fail:
    mov byte [lst_n], 0
    mov byte [lst_st], 3
    popad
    ret

; Ephemeral counter for paginated read-only FSM3 root listing.
fs3_preview_skip dd 0
