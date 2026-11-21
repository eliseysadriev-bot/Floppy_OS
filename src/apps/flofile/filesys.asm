; FloFile.sys - файловый менеджер отдельным модулем. Загрузчик кладёт его в память по адресу 0x42000
org 0x42000
bits 32

C_BLACK equ 0
C_BLUE  equ 1
C_DBLUE equ 2
C_GRAY  equ 7
C_GRAY2 equ 8
C_WHITE equ 15
DT_N    equ 8
DT_ESZ  equ 12

%include "src/include/kvars.inc"
%include "src/include/macros.inc"
%include "src/include/filevars.inc"
%include "src/include/modvars.inc"
%include "src/include/textvars.inc"
%include "src/include/paintvars.inc"
%assign MI 0
%macro MAPI 1
%1 equ MJ + 5 * MI
%assign MI MI + 1
%endmacro
%include "src/include/mapilist.inc"
%assign TI 0
%macro TAPI 1
%1 equ TJ + 5 * TI
%assign TI TI + 1
%endmacro
%include "src/include/tapilist.inc"
%assign PI 0
%macro PAPI 1
%1 equ PJ + 5 * PI
%assign PI PI + 1
%endmacro
%include "src/include/papilist.inc"
%assign II 0
%macro IAPI 1
%1 equ IJ + 5 * II
%assign II II + 1
%endmacro
%include "src/include/iapilist.inc"
%include "src/include/itgevars.inc"
%assign KI 0
%macro KAPI 1
%1 equ KJ + 5 * KI
%assign KI KI + 1
%endmacro
%include "src/include/kapilist.inc"
%assign BI 0
%macro BAPI 1
%1 equ BJ + 5 * BI
%assign BI BI + 1
%endmacro
%include "src/include/bapilist.inc"
%include "src/include/boilvars.inc"
%macro FAPI 1
    jmp near %1
%endmacro

    db "FSYS"                           ; признак модуля
    dd MODSIZE                          ; размер в секторах
times 0x10 - ($ - $$) db 0
%include "src/include/fapilist.inc"
times 0x100 - ($ - $$) db 0
    db 0, 0, 0, 0                       ; d2_files, d2_err, d2_nm, fl_cnt
    db 0, 0, 0, 0                       ; fl_scr
    dd 0                                ; fl_sbo
times 0x200 - ($ - $$) db 0

s_cancel         db "Cancel", 0
s_file           db "File", 0
s_exit           db "Exit", 0

%include "src/apps/flofile/files_body.asm"

MODSIZE equ 48
times MODSIZE * 512 - ($ - $$) db 0
