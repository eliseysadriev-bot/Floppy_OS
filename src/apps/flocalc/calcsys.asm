; FloCalc.sys - калькулятор отдельным модулем. Загрузчик кладёт его в память по адресу 0x30000
org 0x30000
bits 32

C_BLACK equ 0
C_BLUE  equ 1
C_DBLUE equ 2
C_GRAY  equ 7
C_GRAY2 equ 8
C_WHITE equ 15

%include "src/include/kvars.inc"
%include "src/include/macros.inc"
%include "src/include/modvars.inc"
%assign KI 0
%macro KAPI 1
%1 equ KJ + 5 * KI
%assign KI KI + 1
%endmacro
%include "src/include/kapilist.inc"
%macro MAPI 1
    jmp near %1
%endmacro

    db "FSYS"                           ; признак модуля
    dd MODSIZE                          ; размер в секторах
times 0x10 - ($ - $$) db 0
%include "src/include/mapilist.inc"
times 0x100 - ($ - $$) db 0
    db 0, 0, 0, 0xFF                    ; d2_calc, calc_foc, calc_menu, calc_pr
    dd 220, 70, 360, 452                ; calc_x0, calc_y0, calc_w, calc_h
    dd 0, 0                             ; csx, csy
    dd 0, 0                             ; cvw, cvh
times 0x200 - ($ - $$) db 0

cvb db 0
chb db 0
s_error db "Error 5x", 0
s_file db "File", 0
s_exit db "Exit", 0
s_k_e db "Ctrl + E", 0
%include "src/apps/flocalc/calc_body.asm"

MODSIZE equ 8
times MODSIZE * 512 - ($ - $$) db 0
