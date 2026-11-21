; itge.sys - improved text graphics editor. Загрузчик кладёт модуль в память по адресу 0x48000
org 0x48000
bits 32

C_BLACK equ 0
C_BLUE  equ 1
C_GRAY  equ 7
C_GRAY2 equ 8
C_WHITE equ 15
VGA     equ 0xA0000

%include "src/include/kvars.inc"
%include "src/include/macros.inc"
%include "src/include/itgevars.inc"
%assign PI 0
%macro PAPI 1
%1 equ PJ + 5 * PI
%assign PI PI + 1
%endmacro
%include "src/include/papilist.inc"
%include "src/include/paintvars.inc"
%assign KI 0
%macro KAPI 1
%1 equ KJ + 5 * KI
%assign KI KI + 1
%endmacro
%include "src/include/kapilist.inc"
%macro IAPI 1
    jmp near %1
%endmacro

    db "FSYS"                           ; признак модуля
    dd MODSIZE                          ; размер в секторах
times 0x10 - ($ - $$) db 0
%include "src/include/iapilist.inc"
times 0x100 - ($ - $$) db 0
    db 0                                ; d2_itge
    db 0                                ; it_drag
    db 0                                ; it_shift
    db 0xFF                             ; it_dsk
times 0x110 - ($ - $$) db 0             ; it_nm
times 16 db 0
times 0x200 - ($ - $$) db 0

%include "src/apps/floitge/itge_body.asm"

times 0x6000 - ($ - $$) db 0
%include "src/include/rufont.inc"                    ; русский шрифт, лежит по адресу RUFONT
MODSIZE equ 64
times MODSIZE * 512 - ($ - $$) db 0
; FloCalendar.sys идёт сразу после 64 секторов FloItge.
; Заполнение pm.img до 64 МБ перенесено в calendarsys.asm.
