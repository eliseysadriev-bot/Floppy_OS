; Boil.sys - игра Boil отдельным модулем на весь экран. Загрузчик кладёт её в память по адресу 0x3C000
org 0x3C000
bits 32

C_BLACK equ 0
C_BLUE  equ 1
C_DBLUE equ 2
C_GRAY  equ 7
C_GRAY2 equ 8
C_WHITE equ 15
VGA     equ 0xA0000

%include "src/include/kvars.inc"
%include "src/include/macros.inc"
%include "src/include/boilvars.inc"
%assign KI 0
%macro KAPI 1
%1 equ KJ + 5 * KI
%assign KI KI + 1
%endmacro
%include "src/include/kapilist.inc"
%macro BAPI 1
    jmp near %1
%endmacro

    db "FSYS"                           ; признак модуля
    dd MODSIZE                          ; размер в секторах
times 0x10 - ($ - $$) db 0
%include "src/include/bapilist.inc"
times 0x100 - ($ - $$) db 0
    db 0                                ; d2_boil
times 0x200 - ($ - $$) db 0

%include "src/apps/flotasks/boil_body.asm"

MODSIZE equ 12
times MODSIZE * 512 - ($ - $$) db 0
