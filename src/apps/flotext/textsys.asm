; FloText.sys - текстовый редактор отдельным модулем. Загрузчик кладёт его в память по адресу 0x34000
org 0x34000
bits 32

C_BLACK equ 0
C_BLUE  equ 1
C_DBLUE equ 2
C_GRAY  equ 7
C_GRAY2 equ 8
C_WHITE equ 15

%include "src/include/kvars.inc"
%include "src/include/macros.inc"
%include "src/include/textvars.inc"
%assign KI 0
%macro KAPI 1
%1 equ KJ + 5 * KI
%assign KI KI + 1
%endmacro
%include "src/include/kapilist.inc"
%macro TAPI 1
    jmp near %1
%endmacro

    db "FSYS"                           ; признак модуля
    dd MODSIZE                          ; размер в секторах
times 0x10 - ($ - $$) db 0
%include "src/include/tapilist.inc"
times 0x100 - ($ - $$) db 0
    db 0, 0, 0, 0                       ; d2_text, t_menu, t2_top, (пусто)
    dd 0                                ; t2_sbo
times 0x200 - ($ - $$) db 0

TX_ROWS equ 100                         ; всего строк (видно 16, остальное прокручивается)
TX_N    equ 49 * TX_ROWS

t2_row           db 0
t2_col           db 0
t2_anc           dd -1
sel_lo           dd 0
sel_hi           dd 0
pk_last          db 0
pk_size          dd 0
s_file           db "File", 0
s_exit           db "Exit", 0
s_m_save         db "Save", 0
s_m_saveto       db "Save to...", 0
s_m_open         db "Open...", 0

%include "src/apps/flotext/text_body.asm"

MODSIZE equ 16
times MODSIZE * 512 - ($ - $$) db 0
