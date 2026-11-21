; FloFile copy between mounted volumes. FSM2 is read only here.
; ESI=name, EAX=source folder, EDX=destination folder, BL/BH=source/dest slots,
; CL=expected source state (0 FSM2, 3 FSM3), CH=kind (1 file, 2 folder).
; CF=1 on failure. An interrupted tree copy can leave completed entries in
; its new destination folder. Existing destination and source files are kept.
fs3_paste_from:
    pushad
    push dword [fs3_folder_id]
    movzx ebp, byte [fs_par]
    push ebp
    cmp bl, DT_N
    jae .fail
    cmp bh, DT_N
    jae .fail
    cmp edx, 1024
    ja .fail
    test cl, cl
    jz .known_source
    cmp cl, 3
    jne .fail
.known_source:
    cmp byte [fs3sw_active], 0
    jne .fail
    cmp bl, bh
    je .same_volume
    mov byte [fs3cp_between], 1
    mov [fs3cp_srcslot], bl
    mov [fs3cp_dstslot], bh
    mov [fs3cp_srcstate], cl
    mov [fs3cp_name], esi
    mov [fs3cp_srcparent], eax
    mov [fs3cp_dstparent], edx
    mov [fs2cp_kind], ch
    call fs3cp_source
    jc .fail
    mov al, [cur_drive]
    mov [fs3cp_srcdrive], al
    mov eax, [cur_base]
    mov [fs3cp_srcbase], eax
    mov eax, [cur_size]
    mov [fs3cp_srcsize], eax
    call fs3cp_destination
    jc .fail
    ; A legacy physical volume includes its virtual disks. Refuse an
    ; overlapping destination so even the source volume's raw bytes survive.
    mov al, [cur_drive]
    cmp al, [fs3cp_srcdrive]
    jne .disjoint
    mov eax, [fs3cp_srcsize]
    test eax, eax
    jz .fail
    add eax, [fs3cp_srcbase]
    jc .fail
    cmp eax, [cur_base]
    jbe .disjoint
    mov eax, [cur_base]
    add eax, [cur_size]
    jc .fail
    cmp eax, [fs3cp_srcbase]
    ja .fail
.disjoint:
    call fs3cp_source
    jc .fail
    mov eax, [fs3cp_srcparent]
    cmp byte [fs3cp_srcstate], 0
    je .legacy
    cmp eax, 1024
    ja .fail
    cmp byte [fs2cp_kind], 1
    jne .fail
    mov [fs3_folder_id], eax
    mov esi, [fs3cp_name]
    call fs3sr_open
    jc .fail
    call fs3cp_copy_opened
    jmp .done
.legacy:
    cmp eax, FS2_XFER_MAX
    ja .fail
    mov [fs_par], al
    call fs2cp_prepare
    jc .fail
    call fs2cp_execute
    jmp .done
.same_volume:
    cmp cl, 3
    jne .fail
    cmp ch, 1
    jne .fail
    push eax
    mov al, bl
    call fs_setdisk
    pop eax
    cmp byte [lst_st], 3
    jne .fail
    call fs3_copy_file
    jmp .done
.fail:
    stc
.done:
    pop eax
    mov [fs_par], al
    pop dword [fs3_folder_id]
    popad
    ret

; Re-select by slot before using geometry or shared I/O buffers on each side.
; In-volume copying can use its already mounted volume.
fs3cp_source:
    cmp byte [fs3cp_between], 0
    je .ok
    mov al, [fs3cp_srcslot]
    call fs_setdisk
    mov al, [fs3cp_srcstate]
    cmp [fs_state], al
    jne .bad
    cmp byte [lst_st], 1
    je .bad
.ok:
    clc
    ret
.bad:
    stc
    ret

fs3cp_destination:
    cmp byte [fs3cp_between], 0
    je .parent
    mov al, [fs3cp_dstslot]
    call fs_setdisk
    cmp byte [lst_st], 3
    jne .bad
    cmp dword [cur_size], 0
    je .bad
.parent:
    mov eax, [fs3cp_dstparent]
    mov [fs3_folder_id], eax
    clc
    ret
.bad:
    stc
    ret

fs3cp_between   db 0
fs3cp_srcslot   db 0
fs3cp_dstslot   db 0
fs3cp_srcstate  db 0
fs3cp_srcdrive  db 0
fs3cp_srcbase   dd 0
fs3cp_srcsize   dd 0
fs3cp_srcparent dd 0

; The FSM2 catalog has eight sectors. This scratch RAM sits above KBSS.
FS2_XFER_MAX equ FS_DIRN * 16
FS2_XFER_DIR equ 0x62000
FS2_XFER_ORDER equ FS2_XFER_DIR + FS_DIRN * 512
FS2_XFER_MAP equ FS2_XFER_ORDER + FS2_XFER_MAX

fs2cp_prepare:
    mov esi, [fs3cp_name]
    call dir_find
    jc .fail
    cmp byte [edi], 2              ; skip virtual-disk descriptors
    jb .fail
    mov al, [edi + 15]
    inc al                         ; FSM2 type 0/1 -> transfer type 1/2
    cmp al, [fs2cp_kind]
    jne .fail
    call dir_last_id
    test eax, eax
    jz .fail
    cmp eax, FS2_XFER_MAX
    ja .fail
    mov [fs2cp_root], eax
    mov eax, [fs_dir]
    mov ebx, FS2_XFER_DIR
    mov ecx, FS_DIRN
.read:
    call lba_read
    jc .fail
    inc eax
    add ebx, 512
    loop .read
    mov dword [fs2cp_count], 0
    mov dword [fs2cp_blocks], 0
    mov ebp, [fs2cp_root]
    call fs2cp_plan_entry
    jc .fail
    xor ebx, ebx
.walk:
    cmp ebx, [fs2cp_count]
    jae .ready
    movzx ebp, byte [FS2_XFER_ORDER + ebx]
    call fs2cp_entry
    inc ebx
    cmp byte [esi + 15], 1
    jne .walk
    mov edx, ebp
    mov ebp, 1
.child:
    call fs2cp_entry
    cmp byte [esi], 2
    jb .next
    cmp [esi + 25], dl
    jne .next
    call fs2cp_plan_entry
    jc .fail
.next:
    inc ebp
    cmp ebp, FS2_XFER_MAX
    jbe .child
    jmp .walk
.ready:
    call fs3cp_destination
    jc .fail
    call fs3_catalog_count
    jc .fail
    add eax, [fs2cp_count]
    cmp eax, 1024
    ja .fail
    call fat_count_free
    jc .fail
    cmp eax, [fs2cp_blocks]
    jb .fail
    mov eax, [fs3cp_dstparent]
    mov [fs2cp_parent], eax
    clc
    ret
.fail:
    stc
    ret

; EBP is the one-based FSM2 slot ID.
fs2cp_entry:
    lea esi, [ebp - 1]
    shl esi, 5
    add esi, FS2_XFER_DIR
    ret

; Preflight every name and chain before any destination writes.
fs2cp_plan_entry:
    pushad
    call fs2cp_entry
    call fs3o_namecheck
    jc .fail
    xor ecx, ecx
.check:
    cmp ecx, [fs2cp_count]
    jae .record
    movzx eax, byte [FS2_XFER_ORDER + ecx]
    cmp eax, ebp                     ; repeated record / directory cycle
    je .fail
    dec eax
    shl eax, 5
    lea edi, [FS2_XFER_DIR + eax]
    mov al, [esi + 25]
    cmp al, [edi + 25]
    jne .next
    call streq
    cmp al, 1
    je .fail
.next:
    inc ecx
    jmp .check
.record:
    cmp ecx, FS2_XFER_MAX
    jae .fail
    mov al, [esi + 15]
    cmp al, 1
    je .add
    test al, al
    jnz .fail
    mov eax, [esi + 16]
    cmp eax, 4194304
    ja .fail
    test eax, eax
    jz .empty
    mov edi, esi
    call fs3_check_file_chain
    jc .fail
    add eax, 511
    shr eax, 9
    add [fs2cp_blocks], eax
    jmp .add
.empty:
    cmp dword [esi + 20], 0xFFFFFFFF
    jne .fail
.add:
    mov eax, ebp
    mov [FS2_XFER_ORDER + ecx], al
    inc dword [fs2cp_count]
    popad
    clc
    ret
.fail:
    popad
    stc
    ret

fs2cp_execute:
    xor ecx, ecx
.next:
    cmp ecx, [fs2cp_count]
    jae .done
    movzx ebp, byte [FS2_XFER_ORDER + ecx]
    call fs2cp_entry
    mov eax, [fs2cp_parent]
    test ecx, ecx
    jz .parent
    movzx eax, byte [esi + 25]
    movzx eax, word [FS2_XFER_MAP + eax * 2]
.parent:
    mov [fs3cp_dstparent], eax
    mov [fs3cp_name], esi
    cmp byte [esi + 15], 1
    jne .file
    call fs3cp_destination
    jc .fail
    mov dl, 2
    call fs3o_create
    jc .fail
    mov eax, [fs3o_slot]
    inc eax
    mov [FS2_XFER_MAP + ebp * 2], ax
    jmp .advance
.file:
    call fs3cp_source
    jc .fail
    mov eax, [esi + 16]
    mov edx, [esi + 20]
    call fs3sr_prepare
    push ecx
    call fs3cp_copy_opened
    pop ecx
    jc .fail
.advance:
    inc ecx
    jmp .next
.done:
    clc
    ret
.fail:
    stc
    ret

fs2cp_kind   db 0
fs2cp_root   dd 0
fs2cp_count  dd 0
fs2cp_blocks dd 0
fs2cp_parent dd 0
