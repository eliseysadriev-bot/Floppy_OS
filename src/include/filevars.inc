; Состояние FloFile.sys, которое видит ядро: лежит в модуле по постоянным адресам
FJ        equ 0x42010                   ; таблица переходов модуля
FV        equ 0x42100                   ; переменные модуля
d2_files  equ FV + 0
d2_err    equ FV + 1
d2_nm     equ FV + 2
fl_cnt    equ FV + 3
fl_scr    equ FV + 4
fl_sbo    equ FV + 8
