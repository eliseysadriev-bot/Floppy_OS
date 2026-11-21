; Состояние FloText.sys, которое видит ядро: лежит в модуле по постоянным адресам
TJ        equ 0x34010                   ; таблица переходов модуля
TV        equ 0x34100                   ; переменные модуля
d2_text   equ TV + 0
t_menu    equ TV + 1
t2_top    equ TV + 2
t2_sbo    equ TV + 4
