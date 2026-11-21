; FloPaint.sys - рисовалка отдельным модулем. Загрузчик кладёт его в память по адресу 0x38000
org 0x38000
bits 32

C_BLACK equ 0
C_BLUE  equ 1
C_DBLUE equ 2
C_GRAY  equ 7
C_GRAY2 equ 8
C_WHITE equ 15
DT_ESZ  equ 12
VGA     equ 0xA0000

%include "src/include/kvars.inc"
%include "src/include/macros.inc"
%include "src/include/paintvars.inc"
%assign KI 0
%macro KAPI 1
%1 equ KJ + 5 * KI
%assign KI KI + 1
%endmacro
%include "src/include/kapilist.inc"
%macro PAPI 1
    jmp near %1
%endmacro

    db "FSYS"                           ; признак модуля
    dd MODSIZE                          ; размер в секторах
times 0x10 - ($ - $$) db 0
%include "src/include/papilist.inc"
times 0x100 - ($ - $$) db 0
    db 0, 0, 0, 3                       ; d2_paint, pa_drag, pa_tool, pa_size
    db 0xFF, 0, 0, 0                    ; pa_dsk, pa_par
    times 16 db 0                       ; pa_nm
times 0x200 - ($ - $$) db 0

s_file           db "File", 0
s_exit           db "Exit", 0
s_m_save         db "Save", 0
s_m_saveto       db "Save to...", 0
s_m_open         db "Open...", 0

%include "src/apps/flopaint/paint_body.asm"

MODSIZE equ 32
times MODSIZE * 512 - ($ - $$) db 0
