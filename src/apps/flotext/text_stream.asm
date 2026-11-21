; Keep large-document memory above the old 16 MiB memory map.
; Buffer ends at 29 MiB; the BIOS reports memory above the first MiB.
TXL_MAX     equ 0x400000
TXL_DATA    equ 0x1000000
TXL_STAGE   equ 0x1400000
TXL_LINES   equ 0x1800000
TXL_LONG_CLIP equ 0x1900000
TXL_MEMORY_KB equ 28 * 1024
TXL_COLS    equ 48
TXL_CLIP    equ 0x10000               ; shared clipboard ends at the terminal buffer

txl_size    dd 0
txl_rows    dd 1
txl_pos     dd 0
txl_anchor  dd -1
txl_row     dd 0
txl_start   dd 0
txl_long_len dd 0
txl_dirty   db 0
txl_byte    db 0
txl_newline db 13, 10

; Open into staging first so a failed read preserves the current document.
txl_load:
    pushad
    call fs3sr_open
    jc .bad
    xor ebp, ebp
    mov ebx, TXL_STAGE
.read:
    call fs3sr_next
    jc .end
    add ebp, eax
    add ebx, 512
    jmp .read
.end:
    test eax, eax
    jnz .bad
    mov [txl_size], ebp
    mov ecx, ebp
    mov esi, TXL_STAGE
    mov edi, TXL_DATA
    cld
    rep movsb
    mov dword [txl_top], 0
    mov dword [txl_pos], 0
    mov dword [txl_anchor], -1
    mov byte [txl_dirty], 0
    mov byte [txl_mode], 1
    call txl_index
    popad
    clc
    ret
.bad:
    popad
    stc
    ret

; EAX is visual line start; EDX is content end; EAX returns next start.
; CRLF is one line ending. Wrapping affects display only.
txl_line:
    lea edx, [eax + TXL_COLS]
.scan:
    cmp eax, [txl_size]
    jae .end
    cmp byte [TXL_DATA + eax], 10
    je .lf
    cmp byte [TXL_DATA + eax], 13
    je .cr
    cmp eax, edx
    jae .end
    inc eax
    jmp .scan
.cr:
    mov edx, eax
    inc eax
    cmp eax, [txl_size]
    jae .return
    cmp byte [TXL_DATA + eax], 10
    jne .return
    inc eax
    ret
.lf:
    mov edx, eax
    inc eax
    ret
.end:
    mov edx, eax
.return:
    ret

; Index one offset every 64 visual lines, even for a file full of LF bytes.
txl_index:
    pushad
    xor eax, eax
    xor ecx, ecx
    mov edi, TXL_LINES
.row:
    test cl, 63
    jnz .scan
    stosd
.scan:
    inc ecx
    call txl_line
    cmp eax, [txl_size]
    jb .row
    cmp eax, edx
    jne .row                        ; a final newline leaves an empty row
    mov [txl_rows], ecx
    sub ecx, 16
    jnc .clamp
    xor ecx, ecx
.clamp:
    cmp [txl_top], ecx
    jbe .ready
    mov [txl_top], ecx
.ready:
    popad
    ret

; EAX=row -> EAX=byte offset. Preserve the caller's other registers.
txl_at_row:
    push ecx
    push edx
    mov ecx, eax
    shr eax, 6
    mov eax, [TXL_LINES + eax*4]
    and ecx, 63
    jz .done
.next:
    call txl_line
    loop .next
.done:
    pop edx
    pop ecx
    ret

; Locate the caret using binary search on the sparse index.
txl_locate:
    pushad
    xor ebx, ebx
    mov ecx, [txl_rows]
    dec ecx
    shr ecx, 6
    inc ecx
    mov esi, [txl_pos]
.search:
    lea eax, [ebx + ecx]
    shr eax, 1
    cmp eax, ebx
    je .found
    cmp [TXL_LINES + eax*4], esi
    ja .higher
    mov ebx, eax
    jmp .search
.higher:
    mov ecx, eax
    jmp .search
.found:
    mov eax, [TXL_LINES + ebx*4]
    shl ebx, 6
.row:
    mov [txl_start], eax
    mov [txl_row], ebx
    inc ebx
    cmp ebx, [txl_rows]
    jae .done
    call txl_line
    cmp eax, esi
    jbe .row
.done:
    popad
    ret

; EAX/EDX hold the selected range [start,end), or one caret offset.
txl_selection:
    mov eax, [txl_pos]
    mov edx, [txl_anchor]
    cmp edx, -1
    jne .order
    mov edx, eax
.order:
    cmp eax, edx
    jbe .done
    xchg eax, edx
.done:
    ret

txl_render:
    pushad
    call txl_locate
    call txl_selection
    push edx
    push eax
    mov eax, [txl_top]
    call txl_at_row
    mov ebp, eax
    mov ebx, [txl_top]
    mov dword [t_y], 86
.row:
    cmp ebx, [txl_rows]
    jae .bar
    cmp dword [t_y], 598
    jae .bar
    mov eax, ebp
    call txl_line
    push eax
    push edx
    mov dword [t_x], 0
.char:
    cmp ebp, [esp]
    jae .next
    mov dword [r_c], C_BLACK
    cmp ebp, [esp+8]
    jb .glyph
    cmp ebp, [esp+12]
    jae .glyph
    mov eax, [t_x]
    mov [r_x], eax
    mov eax, [t_y]
    mov [r_y], eax
    mov dword [r_w], 16
    mov dword [r_h], 32
    call fill_rect
    mov dword [r_c], C_WHITE
.glyph:
    mov al, [TXL_DATA + ebp]
    cmp al, 32
    jb .space
    CHKHI al, .space
    jmp .show
.space:
    mov al, ' '
.show:
    mov [t2_tmp], al
    mov esi, t2_tmp
    call draw_big
    inc ebp
    add dword [t_x], 16
    jmp .char
.next:
    add esp, 4
    pop ebp
    inc ebx
    add dword [t_y], 32
    jmp .row
.bar:
    add esp, 8
    cmp dword [txl_rows], 16
    jbe .caret
    mov eax, 780
    mov ebx, 86
    mov ecx, 512
    xor edx, edx
    mov esi, 16
    mov edi, [txl_rows]
    mov ebp, [txl_top]
    mov dword [sb_w], 20
    call sbar
    mov dword [sb_w], 16
.caret:
    cmp byte [t_menu], 0
    jne .done
    call txl_selection
    cmp eax, edx
    jne .done
    sub eax, [txl_start]
    shl eax, 4
    mov [r_x], eax
    mov eax, [txl_row]
    sub eax, [txl_top]
    cmp eax, 16
    jae .done
    shl eax, 5
    add eax, 86
    mov [r_y], eax
    mov dword [r_w], 2
    mov dword [r_h], 32
    mov dword [r_c], C_BLACK
    call fill_rect
.done:
    popad
    ret

; Convert the pointed row and column to a byte position.
txl_mouse:
    mov eax, [m_y]
    sub eax, 86
    jns .row
    xor eax, eax
.row:
    shr eax, 5
    cmp eax, 15
    jbe .visible
    mov eax, 15
.visible:
    add eax, [txl_top]
    cmp eax, [txl_rows]
    jb .inside
    mov eax, [txl_rows]
    dec eax
.inside:
    call txl_at_row
    mov ebx, eax
    call txl_line
    mov eax, [m_x]
    shr eax, 4
    add eax, ebx
    cmp eax, edx
    jbe .done
    mov eax, edx
.done:
    ret

txl_click:
    call txl_mouse
    mov [txl_pos], eax
    mov [txl_anchor], eax
    mov byte [sel_drag], 1
    jmp text_draw

txl_drag:
    call txl_mouse
    cmp eax, [txl_pos]
    je .done
    mov [txl_pos], eax
    jmp text_draw
.done:
    ret

txl_reveal:
    call txl_locate
    mov eax, [txl_row]
    cmp eax, [txl_top]
    jb .top
    sub eax, 15
    jc .done
    cmp eax, [txl_top]
    jbe .done
.top:
    mov [txl_top], eax
.done:
    jmp text_draw

; Move one logical character. Preserve CRLF as a pair.
txl_left:
    test eax, eax
    jz .done
    dec eax
    jz .done
    cmp word [TXL_DATA + eax - 1], 0x0A0D
    jne .done
    dec eax
.done:
    ret

txl_right:
    cmp eax, [txl_size]
    jae .done
    inc eax
    cmp eax, [txl_size]
    jae .done
    cmp word [TXL_DATA + eax - 1], 0x0A0D
    jne .done
    inc eax
.done:
    ret

; Replace [EAX, EDX) with ECX bytes from ESI, after checking capacity.
txl_replace:
    mov ebx, [txl_size]
    sub ebx, edx
    lea edi, [eax + ecx]
    lea ebp, [edi + ebx]
    cmp ebp, TXL_MAX
    ja .bad
    test ebx, ebx
    jz .insert
    push esi
    push ecx
    push edi
    mov ecx, ebx
    lea esi, [TXL_DATA + edx]
    add edi, TXL_DATA
    cmp edi, esi
    jbe .move
    lea edi, [edi + ecx - 1]
    lea esi, [esi + ecx - 1]
    std
.move:
    rep movsb
    cld
    pop edi
    pop ecx
    pop esi
.insert:
    mov [txl_pos], edi
    add eax, TXL_DATA
    mov edi, eax
    rep movsb
    mov [txl_size], ebp
    mov dword [txl_anchor], -1
    mov byte [txl_dirty], 1
    call txl_index
    ; An edit can remove rows above the viewport as well as below it.
    jmp txl_reveal
.bad:
    mov al, 0x36
    jmp core_err_raise

txl_key:
    cmp al, 1
    je .all
    cmp al, 3
    je .copy
    cmp al, 0x18
    je .copy
    cmp al, 0x16
    je .paste
    cmp al, 8
    je .backspace
    cmp al, 0x97
    je .delete
    cmp al, 13
    je .newline
    cmp al, 0x93
    jb .other
    cmp al, 0x99
    jbe .nav
.other:
    cmp al, 0x90
    je .nav
    cmp al, 0x91
    je .nav
    cmp al, 32
    jb .done
    CHKHI al, .done
    mov [txl_byte], al
    mov esi, txl_byte
    mov ecx, 1
    jmp .insert
.newline:
    mov esi, txl_newline
    mov ecx, 2
    jmp .insert
.paste:
    mov ecx, [clip_len]
    test ecx, ecx
    jz .done
    mov esi, clip_buf
    cmp ecx, TXL_CLIP
    jne .insert
    cmp dword [txl_long_len], TXL_CLIP
    jbe .insert
    mov ecx, [txl_long_len]
    mov esi, TXL_LONG_CLIP
.insert:
    call txl_selection
    jmp txl_replace
.copy:
    mov bl, al
    call txl_selection
    mov ecx, edx
    sub ecx, eax
    jz .done
    mov dword [txl_long_len], 0
    lea esi, [TXL_DATA + eax]
    cmp ecx, TXL_CLIP
    jbe .shared
    mov [txl_long_len], ecx
    mov edi, TXL_LONG_CLIP
    rep movsb
    lea esi, [TXL_DATA + eax]
    mov ecx, TXL_CLIP
.shared:
    ; Legacy apps read at most the first 64 KiB. Only this editor can
    ; publish a clipboard of that size, so a later legacy copy clears it.
    mov [clip_len], ecx
    mov edi, clip_buf
    rep movsb
    cmp bl, 0x18
    jne .done
    jmp txl_replace
.all:
    mov dword [txl_anchor], 0
    mov eax, [txl_size]
    mov [txl_pos], eax
    jmp text_draw
.backspace:
    call txl_selection
    cmp eax, edx
    jne .erase
    call txl_left
    jmp .erase
.delete:
    call txl_selection
    cmp eax, edx
    jne .erase
    call txl_right
    xchg eax, edx
.erase:
    cmp eax, edx
    je .done
    xor ecx, ecx
    jmp txl_replace
.nav:
    mov bl, al
    mov dword [txl_anchor], -1
    mov eax, [txl_pos]
    cmp bl, 0x93
    jne .right
    call txl_left
    jmp .move
.right:
    cmp bl, 0x94
    jne .rows
    call txl_right
    jmp .move
.rows:
    call txl_locate
    cmp bl, 0x95
    je .home
    cmp bl, 0x96
    je .end
    mov eax, [txl_row]
    cmp bl, 0x90
    je .up
    cmp bl, 0x91
    je .down
    cmp bl, 0x98
    jne .page_down
    sub eax, 15
    jnc .row
    xor eax, eax
    jmp .row
.page_down:
    add eax, 14
.down:
    inc eax
    cmp eax, [txl_rows]
    jb .row
    mov eax, [txl_rows]
.up:
    test eax, eax
    jz .row
    dec eax
.row:
    call txl_at_row
    mov ebx, eax
    call txl_line
    mov eax, [txl_pos]
    sub eax, [txl_start]
    add eax, ebx
    cmp eax, edx
    jbe .move
    mov eax, edx
    jmp .move
.home:
    mov eax, [txl_start]
    jmp .move
.end:
    mov eax, [txl_start]
    call txl_line
    mov eax, edx
.move:
    mov [txl_pos], eax
    jmp txl_reveal
.done:
    ret
