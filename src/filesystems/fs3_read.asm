; Floppy_152: bounded read-only FSM3 file reader.
; Called through existing kernel file_read API when fs_state=3.
; Input: ESI -> filename, fs3_folder_id -> 16-bit parent folder ID.
; Output: DATA_BUF contains file bytes, EAX=size, CF clear on success.
; No FSM3 write/delete/mkdir operations are enabled in this patch.
; Strict size cap is intentionally kept at 256 KiB until streaming buffers
; and the 4 MiB memory map are designed and verified.
fs3_file_read:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov [fs3_read_name], esi
    cmp byte [fs_state], 3
    jne .fail
    call fs3_catalog_count       ; validate all 1024 slots first
    jc .fail
    xor ebp, ebp                 ; sector 0..127 of directory
.sector:
    cmp ebp, FS3_DIRN
    jae .fail
    mov eax, [fs_dir]
    add eax, ebp
    mov ebx, DIR_BUF
    call lba_read
    jc .fail
    xor edx, edx                 ; slot 0..7
.slot:
    cmp edx, 8
    jae .next_sector
    mov edi, edx
    shl edi, 6
    add edi, DIR_BUF
    cmp byte [edi + 24], 1       ; a regular file, not a directory
    jne .next_slot
    mov ax, [fs3_folder_id]
    cmp word [edi + 26], ax     ; current directory
    jne .next_slot
    mov esi, [fs3_read_name]
    xor ecx, ecx
.compare:
    cmp ecx, 15                  ; max 14 chars + NUL
    jae .next_slot
    mov al, [esi + ecx]
    cmp al, [edi + ecx]
    jne .next_slot
    test al, al
    jz .found
    inc ecx
    jmp .compare
.next_slot:
    inc edx
    jmp .slot
.next_sector:
    inc ebp
    jmp .sector
.found:
    mov eax, [edi + 16]
    cmp eax, 262143              ; DATA_BUF must have NUL room
    ja .fail
    mov [fs3_read_size], eax
    mov [f_size], eax
    mov eax, [edi + 20]
    mov [fs3_read_cluster], eax
    mov eax, [fs3_read_size]
    add eax, 511
    shr eax, 9
    mov [fs3_read_sectors], eax
    mov dword [fs3_read_index], 0
    test eax, eax
    jz .empty
.read_loop:
    mov eax, [fs3_read_cluster]
    cmp eax, [fs_nclus]
    jae .fail
    mov ecx, [fs3_read_index]
    shl ecx, 9
    lea ebx, [DATA_BUF + ecx]
    add eax, [fsd_start]
    call lba_read
    jc .fail
    mov eax, [fs3_read_cluster]
    call fat_get
    jc .fail
    mov [fs3_read_cluster], eax
    inc dword [fs3_read_index]
    mov ecx, [fs3_read_index]
    cmp ecx, [fs3_read_sectors]
    jb .read_loop
    cmp eax, 0xFFFFFFFF          ; refuse short or overlong FAT chains
    jne .fail
    jmp .success
.empty:
    cmp dword [fs3_read_cluster], 0xFFFFFFFF
    jne .fail
.success:
    mov eax, [fs3_read_size]
    mov byte [DATA_BUF + eax], 0
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    clc
    ret
.fail:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    stc
    ret

fs3_read_name    dd 0
fs3_read_size    dd 0
fs3_read_cluster dd 0
fs3_read_sectors dd 0
fs3_read_index   dd 0
