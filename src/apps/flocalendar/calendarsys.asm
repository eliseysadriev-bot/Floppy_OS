; FloCalendar.sys — самостоятельный исполняемый модуль, загружается с pm.img в 0x54000.
; Функции вызываются ядром через таблицу переходов, общие API — через kapilist.inc.
org 0x54000
bits 32

C_BLACK equ 0
C_BLUE  equ 1
C_DBLUE equ 2
C_GRAY  equ 7
C_GRAY2 equ 8
C_WHITE equ 15
VGA     equ 0xA0000
CAL_W   equ 424
CAL_H   equ 376

%include "src/include/kvars.inc"
%include "src/include/macros.inc"
%assign KI 0
%macro KAPI 1
%1 equ KJ + 5 * KI
%assign KI KI + 1
%endmacro
%include "src/include/kapilist.inc"

db "FSYS"
dd MODSIZE
 times 0x10 - ($ - $$) db 0
; Таблица точек входа: каждая запись — near jmp (5 байт).
    jmp near cal_open
    jmp near cal_exit
    jmp near cal_draw
    jmp near cal_hit
    jmp near cal_press
 times 0x100 - ($ - $$) db 0
; Переменные размещены по постоянным адресам: ядро читает d2_cal и cal_x.
%include "src/apps/flocalendar/calendar_data.asm"
 times 0x400 - ($ - $$) db 0
%include "src/apps/flocalendar/calendar_body.asm"

MODSIZE equ 16
 times MODSIZE * 512 - ($ - $$) db 0
; Последний модуль в pm.img. Календарь обязан начинаться на LBA 437.
; Предыдущие модули: boot 1, kernel 256, calc 8, text 16, paint 32,
; files 48, boil 12, itge 64. До текущего модуля всего 437 секторов.
; Заполняем образ до 64 МБ ТОЛЬКО ПОСЛЕ 16 секторов календаря.
times 64 * 1024 * 1024 - (1 + 256 + 8 + 16 + 32 + 48 + 12 + 64) * 512 - ($ - $$) db 0
