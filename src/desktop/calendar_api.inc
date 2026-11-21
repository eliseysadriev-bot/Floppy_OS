; Адреса FloCalendar.sys (модуль всегда читается загрузчиком в 0x54000).
; Пять внешних процедур через 5-байтовые переходы FSYS.
cal_open  equ 0x54010
cal_exit  equ 0x54015
cal_draw  equ 0x5401A
cal_hit   equ 0x5401F
cal_press equ 0x54024
; Состояние модуля, на которое ссылается ядро (переменные с 0x54100).
d2_cal    equ 0x54100
cal_x     equ 0x54103

; Службы ядра, не экспортируем внутренние адреса и переменные.
cal_get_timezone:
    movsx edx, byte [tz_off]
    ret
cal_drag_context:
    mov byte [d_ctx], 9
    ret
