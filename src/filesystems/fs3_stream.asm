; Floppy_156: streaming backend for FSM3 files up to 4,194,304 bytes.
; Does NOT use DATA_BUF. No BIOS/heap allocation: caller provides one
; writable 512-byte sector buffer. A client must not change disks while
; a stream is open. All interfaces use CF for failure.
;
; READ:
;   fs3sr_open: ESI=zero-terminated name, current fs3_folder_id, CF=0 OK.
;   fs3sr_next: EBX=512-byte output buffer, CF=0 -> EAX bytes (1..512).
;               CF=1, EAX=0 -> EOF; CF=1, EAX=-1 -> I/O/state error.
; WRITE (replace EXISTING file only; create empty file via fs3o_create):
;   fs3sw_begin: ESI=name, ECX=final size (1..4194304), CF=0 OK.
;   fs3sw_put: EBX=512-byte sector buffer (last padded), CF=0 OK.
;   fs3sw_commit: CF=0 on durable catalog change.
;   fs3sw_cancel: if the mounted volume is still healthy, reclaim all
;                 staged clusters; the old file remains unchanged.
; Staged writes are copy-on-write and never overwrite old file payload.
; On failed I/O, uncertain private sectors may leak (requires later fsck),
; but the original catalog record is left unchanged until commit.
;
; IMPORTANT: Old file_read / file_write API and FloText retain their 256KiB
; cap. Those clients must be upgraded to use this backend before the GUI can
; open/edit an arbitrary 4MiB file. This is a backend, not complete 4MiB UI.

fs3sr_open:
    pushad
    mov byte [fs3sr_active], 0
    mov [fs3sr_name], esi
    cmp byte [fs_state], 3
    jne .fail
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
    mov esi, [fs3sr_name]
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
    mov eax, [edi + 16]
    cmp eax, 4194304
    ja .fail
    mov [fs3sr_left], eax
    mov eax, [edi + 20]
    mov [fs3sr_cluster], eax
    mov al, [cur_drive]
    mov [fs3sr_drive], al
    mov eax, [cur_base]
    mov [fs3sr_base], eax
    mov eax, [cur_size]
    mov [fs3sr_disksz], eax
    mov byte [fs3sr_active], 1
    popad
    clc
    ret
.fail:
    popad
    stc
    ret

fs3sr_next:
    push ebx
    push ecx
    push edx
    push esi
    cmp byte [fs3sr_active], 1
    jne .error
    cmp byte [fs_state], 3
    jne .error
    mov al, [cur_drive]
    cmp al, [fs3sr_drive]
    jne .error
    mov eax, [cur_base]
    cmp eax, [fs3sr_base]
    jne .error
    mov eax, [cur_size]
    cmp eax, [fs3sr_disksz]
    jne .error
    cmp dword [fs3sr_left], 0
    je .eof
    mov esi, [fs3sr_cluster]
    test esi, esi
    jz .error
    cmp esi, [fs_nclus]
    jae .error
    mov eax, esi
    add eax, [fsd_start]
    call lba_read
    jc .error
    mov eax, esi
    call fat_get
    jc .error
    mov [fs3sr_cluster], eax
    mov eax, [fs3sr_left]
    cmp eax, 512
    jbe .last_size
    mov eax, 512
.last_size:
    sub [fs3sr_left], eax
    cmp dword [fs3sr_left], 0
    jne .more
    cmp dword [fs3sr_cluster], 0xFFFFFFFF
    jne .error
.more:
    pop esi
    pop edx
    pop ecx
    pop ebx
    clc
    ret
.eof:
    xor eax, eax
    jmp .end_err
.error:
    mov byte [fs3sr_active], 0
    mov eax, 0xFFFFFFFF
.end_err:
    pop esi
    pop edx
    pop ecx
    pop ebx
    stc
    ret

fs3sw_begin:
    pushad
    ; A second begin must not silently abandon an already staged chain.
    ; The caller must finish or explicitly cancel the existing stream.
    cmp byte [fs3sw_active], 0
    jne .fail
    mov [fs3sw_name], esi
    mov [fs3sw_size], ecx
    cmp byte [fs_state], 3
    jne .fail
    cmp dword [cur_size], 0          ; Never write physical disks
    je .fail
    test ecx, ecx
    jz .fail
    cmp ecx, 4194304
    ja .fail
    call fs3_catalog_count
    jc .fail
    mov eax, [fs3sw_size]
    add eax, 511
    shr eax, 9
    mov [fs3sw_blocks], eax
    call fat_count_free
    cmp eax, [fs3sw_blocks]
    jb .fail
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
    mov esi, [fs3sw_name]
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
    mov [fs3sw_slot], ebp
    ; Snapshot the exact name; do not depend on a mutable GUI buffer
    ; while sectors are being staged.
    mov esi, [fs3sw_name]
    push edi
    mov edi, fs3sw_namecopy
    call fs3o_name_store
    pop edi
    mov dword [fs3sw_name], fs3sw_namecopy
    mov ax, [fs3_folder_id]
    mov [fs3sw_parent], ax
    mov eax, [edi + 16]
    mov [fs3sw_old_size], eax
    mov eax, [edi + 20]
    mov [fs3sw_old_first], eax
    mov al, [cur_drive]
    mov [fs3sw_drive], al
    mov eax, [cur_base]
    mov [fs3sw_base], eax
    mov eax, [cur_size]
    mov [fs3sw_disksz], eax
    mov dword [fs3sw_index], 0
    mov dword [fs3sw_first], 0xFFFFFFFF
    mov dword [fs3sw_last], 0xFFFFFFFF
    mov byte [fs3sw_newfile], 0
    mov byte [fs3sw_active], 1
    popad
    clc
    ret
.fail:
    popad
    stc
    ret

; Start a streaming CREATE, without adding an empty catalog entry first.
; Input: ESI=unique NUL-terminated filename (1..14 bytes), ECX=final size
;        (1..4MiB), fs3_folder_id=destination parent.
; Commit installs the new catalog entry only after its complete FAT chain
; has been staged. Existing files are NEVER overwritten by this API.
fs3sw_begin_new:
    pushad
    cmp byte [fs3sw_active], 0
    jne .fail
    mov [fs3sw_name], esi
    mov [fs3sw_size], ecx
    cmp dword [cur_size], 0
    je .fail
    test ecx, ecx
    jz .fail
    cmp ecx, 4194304
    ja .fail
    call fs3o_guard                 ; checks virtual FSM3 and whole catalog
    jc .fail
    mov esi, [fs3sw_name]
    call fs3o_namecheck
    jc .fail
    mov esi, [fs3sw_name]
    mov edi, fs3sw_namecopy
    call fs3o_name_store
    mov dword [fs3sw_name], fs3sw_namecopy
    mov esi, fs3sw_namecopy
    call fs3o_find
    jnc .fail                      ; no silent overwriting
    call fs3o_free
    jc .fail
    mov [fs3sw_slot], eax
    mov ax, [fs3_folder_id]
    mov [fs3sw_parent], ax
    mov eax, [fs3sw_size]
    add eax, 511
    shr eax, 9
    mov [fs3sw_blocks], eax
    call fat_count_free
    cmp eax, [fs3sw_blocks]
    jb .fail
    mov dword [fs3sw_old_size], 0
    mov dword [fs3sw_old_first], 0xFFFFFFFF
    mov al, [cur_drive]
    mov [fs3sw_drive], al
    mov eax, [cur_base]
    mov [fs3sw_base], eax
    mov eax, [cur_size]
    mov [fs3sw_disksz], eax
    mov dword [fs3sw_index], 0
    mov dword [fs3sw_first], 0xFFFFFFFF
    mov dword [fs3sw_last], 0xFFFFFFFF
    mov byte [fs3sw_newfile], 1
    mov byte [fs3sw_active], 1
    popad
    clc
    ret
.fail:
    popad
    stc
    ret

; Validate that stream still refers to the same mounted virtual disk.
fs3sw_guard:
    cmp byte [fs3sw_active], 1
    jne .fail
    cmp byte [fs_state], 3
    jne .fail
    cmp dword [cur_size], 0
    je .fail
    mov al, [cur_drive]
    cmp al, [fs3sw_drive]
    jne .fail
    mov eax, [cur_base]
    cmp eax, [fs3sw_base]
    jne .fail
    mov eax, [cur_size]
    cmp eax, [fs3sw_disksz]
    jne .fail
    mov ax, [fs3_folder_id]
    cmp ax, [fs3sw_parent]
    jne .fail
    clc
    ret
.fail:
    stc
    ret

fs3sw_put:
    pushad
    call fs3sw_guard
    jc .fail
    mov eax, [fs3sw_index]
    cmp eax, [fs3sw_blocks]
    jae .reject                     ; extra put: allow caller to commit/cancel
    call fat_alloc
    jc .fail
    mov [fs3sw_new], eax
    add eax, [fsd_start]
    call lba_write                       ; ebx -> padded 512-byte block
    jc .fail
    cmp dword [fs3sw_first], 0xFFFFFFFF
    jne .link
    mov eax, [fs3sw_new]
    mov [fs3sw_first], eax
    jmp .advance
.link:
    mov eax, [fs3sw_last]
    mov edx, [fs3sw_new]
    call fat_set
    jc .fail
.advance:
    mov eax, [fs3sw_new]
    mov [fs3sw_last], eax
    inc dword [fs3sw_index]
    popad
    clc
    ret
.reject:
    ; No I/O occurred: preserve the staged chain for commit or cancel.
    popad
    stc
    ret
.fail:
    ; An I/O failure leaves the original entry unchanged; abandoned
    ; blocks are not reclaimed if a disk write was uncertain.
    mov byte [fs3sw_active], 0
    popad
    stc
    ret

fs3sw_commit:
    pushad
    call fs3sw_guard
    jc .fail
    mov eax, [fs3sw_index]
    cmp eax, [fs3sw_blocks]
    jne .reject                     ; incomplete: caller may put more/cancel
    ; Verify newly staged FAT chain before changing the directory.
    mov edi, FS2_BUF
    mov eax, [fs3sw_size]
    mov [edi + 16], eax
    mov eax, [fs3sw_first]
    mov [edi + 20], eax
    call fs3_check_file_chain
    jc .fail
    mov eax, [fs3sw_slot]
    call fs3_dir_read
    jc .fail
    cmp byte [fs3sw_newfile], 1
    jne .replace
    ; The slot was free at begin; ensure every reserved byte is STILL zero.
    ; Never commit on top of another file or partially damaged record.
    push edi
    mov ecx, 16
    xor eax, eax
    cld
    repe scasd
    pop edi
    jne .fail
    push edi
    mov esi, [fs3sw_name]
    call fs3o_name_store
    pop edi
    mov byte [edi + 24], 1
    mov byte [edi + 25], 0
    mov ax, [fs3sw_parent]
    mov [edi + 26], ax
    jmp .record_ready
.replace:
    cmp byte [edi + 24], 1
    jne .fail
    ; Reject a record renamed during a pending replace.
    mov esi, fs3sw_namecopy
    call streq
    cmp al, 1
    jne .fail
    mov ax, [fs3sw_parent]
    cmp word [edi + 26], ax
    jne .fail
    mov eax, [edi + 16]
    cmp eax, [fs3sw_old_size]
    jne .fail
    mov eax, [edi + 20]
    cmp eax, [fs3sw_old_first]
    jne .fail
.record_ready:
    call ata_flush
    mov eax, [fs3sw_size]
    mov [edi + 16], eax
    mov eax, [fs3sw_first]
    mov [edi + 20], eax
    mov eax, [fs3sw_slot]
    shr eax, 3
    add eax, [fs_dir]
    mov ebx, DIR_BUF
    call lba_write
    jc .fail
    call ata_flush
    mov eax, [fs3sw_old_first]
    cmp eax, 0xFFFFFFFF
    je .done
    call fat_free
.done:
    mov eax, [fs3sw_size]
    mov [f_size], eax
    mov byte [fs3sw_active], 0
    popad
    clc
    ret
.reject:
    ; No directory/FAT I/O occurred: staged blocks can still be finished
    ; or reclaimed via fs3sw_cancel.
    popad
    stc
    ret
.fail:
    mov byte [fs3sw_active], 0
    popad
    stc
    ret

fs3sw_cancel:
    ; Explicit cancellation of an otherwise healthy staged write.
    ; Never free blocks if disk selection or FSM3 state has changed.
    ; In an I/O-failure path fs3sw_put already disables the stream;
    ; freeing an uncertain chain could damage another file.
    pushad
    call fs3sw_guard
    jc .clear
    mov eax, [fs3sw_first]
    cmp eax, 0xFFFFFFFF
    je .clear
    call fat_free
    call ata_flush
.clear:
    mov byte [fs3sw_active], 0
    popad
    ret

fs3sr_name       dd 0
fs3sr_left       dd 0
fs3sr_cluster    dd 0
fs3sr_active     db 0
fs3sr_drive      db 0
fs3sr_base       dd 0
fs3sr_disksz     dd 0
fs3sw_name       dd 0
fs3sw_size       dd 0
fs3sw_old_size   dd 0
fs3sw_old_first  dd 0
fs3sw_slot       dd 0
fs3sw_parent     dw 0
fs3sw_namecopy   times 16 db 0
fs3sw_blocks     dd 0
fs3sw_index      dd 0
fs3sw_first      dd 0
fs3sw_last       dd 0
fs3sw_new        dd 0
fs3sw_active     db 0
fs3sw_newfile    db 0
fs3sw_drive      db 0
fs3sw_base       dd 0
fs3sw_disksz     dd 0

; FSM3 bounded 4 MiB sector-by-sector copy on ONE mounted virtual volume.
; This is not a cross-volume migration interface. It never touches FSM2.
; Input: ESI=NUL-terminated source name (also used for destination),
;        EAX=source parent ID, EDX=destination parent ID (0..1024).
;        A valid FSM3 virtual disk must already be selected with fs_setdisk.
; Output: CF clear only after the destination has been reread and CRC32
;         matched. Original file is never modified and existing targets
;         are NEVER overwritten. All general registers preserved.
; Special case: a zero-byte source produces a zero-byte destination.
; On failure before commit, a private FAT chain is cancelled if safe.
; On an uncertain I/O error, orphaned private clusters or a partially
; committed destination may remain: NEVER repair the original automatically.
;
FS3_COPY_BUF equ 0x50800           ; 512 B scratch; no overlap with FAT/DIR

fs3_copy_file:
    pushad
    mov [fs3cp_name], esi
    mov [fs3cp_srcparent], eax
    mov [fs3cp_dstparent], edx
    cmp byte [fs_state], 3
    jne .fail
    cmp dword [cur_size], 0         ; no real physical disk writes
    je .fail
    cmp eax, 1024
    ja .fail
    cmp edx, 1024
    ja .fail
    cmp byte [fs3sw_active], 0
    jne .fail
    mov [fs3_folder_id], eax
    mov esi, [fs3cp_name]
    call fs3sr_open
    jc .fail
    mov eax, [fs3sr_left]
    mov [fs3cp_size], eax
    ; Reject predictable disk-full errors before creating a destination.
    mov eax, [fs3cp_size]
    add eax, 511
    shr eax, 9
    mov [fs3cp_blocks], eax
    call fat_count_free
    cmp eax, [fs3cp_blocks]
    jb .fail
    mov eax, [fs3cp_dstparent]
    mov [fs3_folder_id], eax
    ; Destination must not exist. This also refuses copying onto itself.
    mov esi, [fs3cp_name]
    call fs3o_find
    jnc .fail
    cmp dword [fs3cp_size], 0
    jne .nonempty
    mov esi, [fs3cp_name]
    mov dl, 1
    call fs3o_create               ; empty source -> empty destination
    jc .fail
    jmp .verify_start
.nonempty:
    mov esi, [fs3cp_name]
    mov ecx, [fs3cp_size]
    call fs3sw_begin_new           ; no visible destination until commit
    jc .fail
    mov eax, [fs3cp_size]
    mov [fs3cp_left], eax
    mov dword [fs3cp_source_crc], 0xFFFFFFFF
.copy:
    mov ebx, FS3_COPY_BUF
    call fs3sr_next
    jc .cancel
    test eax, eax
    jz .cancel
    cmp eax, [fs3cp_left]
    ja .cancel
    cmp eax, 512
    ja .cancel
    mov [fs3cp_chunk], eax
    mov esi, FS3_COPY_BUF
    mov ecx, eax
    mov edi, fs3cp_source_crc
    call fs3cp_crc_update
    ; Zero-pad the final disk sector to avoid copying stale trailing bytes.
    mov eax, [fs3cp_chunk]
    cmp eax, 512
    je .put
    mov edi, FS3_COPY_BUF
    add edi, eax
    mov ecx, 512
    sub ecx, eax
    xor eax, eax
    cld
    rep stosb
.put:
    mov ebx, FS3_COPY_BUF
    call fs3sw_put
    jc .cancel
    mov eax, [fs3cp_chunk]
    sub [fs3cp_left], eax
    jnz .copy
    call fs3sw_commit
    jc .cancel                   ; attempt conservative cancel if still active
    jmp .verify_start
.cancel:
    call fs3sw_cancel
    ; Do not attempt to delete a potentially committed/uncommitted entry
    ; after I/O uncertainty: preserve metadata for explicit inspection.
    jmp .fail
.verify_start:
    mov eax, [fs3cp_dstparent]
    mov [fs3_folder_id], eax
    mov esi, [fs3cp_name]
    call fs3sr_open
    jc .fail
    mov eax, [fs3sr_left]
    cmp eax, [fs3cp_size]
    jne .fail
    test eax, eax
    jz .success
    mov [fs3cp_left], eax
    mov dword [fs3cp_dest_crc], 0xFFFFFFFF
.verify:
    mov ebx, FS3_COPY_BUF
    call fs3sr_next
    jc .fail
    test eax, eax
    jz .fail
    cmp eax, [fs3cp_left]
    ja .fail
    cmp eax, 512
    ja .fail
    mov [fs3cp_chunk], eax
    mov esi, FS3_COPY_BUF
    mov ecx, eax
    mov edi, fs3cp_dest_crc
    call fs3cp_crc_update
    mov eax, [fs3cp_chunk]
    sub [fs3cp_left], eax
    jnz .verify
    mov eax, [fs3cp_dest_crc]
    cmp eax, [fs3cp_source_crc]
    jne .fail
.success:
    mov eax, [fs3cp_srcparent]
    mov [fs3_folder_id], eax    ; restore caller's original folder
    popad
    clc
    ret
.fail:
    mov eax, [fs3cp_srcparent]
    mov [fs3_folder_id], eax
    popad
    stc
    ret

; Update CRC32 (IEEE, reflected) over ECX bytes at ESI.
; A small 16-entry nibble table avoids 8 bitwise rounds per byte.
; Input EDI -> dword CRC accumulator, initialized to 0xFFFFFFFF.
; Used for accidental copy/readback errors, not authentication.
fs3cp_crc_update:
    pushad
    mov edx, [edi]
.nextbyte:
    test ecx, ecx
    jz .done
    movzx eax, byte [esi]
    xor edx, eax
    mov ebp, 2
.nibble:
    mov eax, edx
    and eax, 15
    shr edx, 4
    xor edx, [fs3cp_crc_table + eax * 4]
    dec ebp
    jnz .nibble
    inc esi
    dec ecx
    jmp .nextbyte
.done:
    mov [edi], edx
    popad
    ret

align 4
fs3cp_crc_table:
    dd 0x00000000, 0x1DB71064, 0x3B6E20C8, 0x26D930AC
    dd 0x76DC4190, 0x6B6B51F4, 0x4DB26158, 0x5005713C
    dd 0xEDB88320, 0xF00F9344, 0xD6D6A3E8, 0xCB61B38C
    dd 0x9B64C2B0, 0x86D3D2D4, 0xA00AE278, 0xBDBDF21C

fs3cp_name        dd 0
fs3cp_srcparent   dd 0
fs3cp_dstparent   dd 0
fs3cp_size        dd 0
fs3cp_blocks      dd 0
fs3cp_left        dd 0
fs3cp_chunk       dd 0
fs3cp_source_crc  dd 0
fs3cp_dest_crc    dd 0
