; Состояние FloPaint.sys, которое видит ядро: лежит в модуле по постоянным адресам
PJ        equ 0x38010                   ; таблица переходов модуля
PV        equ 0x38100                   ; переменные модуля
d2_paint  equ PV + 0
pa_drag   equ PV + 1
pa_tool   equ PV + 2
pa_size   equ PV + 3
pa_dsk    equ PV + 4                    ; pa_dsk и pa_par лежат подряд
pa_par    equ PV + 5
pa_nm     equ PV + 8                    ; 16 байт
