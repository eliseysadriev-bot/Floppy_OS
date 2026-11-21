; Состояние FloCalc.sys, которое видит ядро: лежит в модуле по постоянным адресам
MJ        equ 0x30010                   ; таблица переходов модуля
MV        equ 0x30100                   ; переменные модуля
d2_calc   equ MV + 0
calc_foc  equ MV + 1
calc_menu equ MV + 2
calc_pr   equ MV + 3
calc_x0   equ MV + 4
calc_y0   equ MV + 8
calc_w    equ MV + 12
calc_h    equ MV + 16
csx       equ MV + 20
csy       equ MV + 24
cvw       equ MV + 28
cvh       equ MV + 32
CALC_CW   equ 352                       ; размер содержимого: если окно меньше - появляются полоски
CALC_CH   equ 368
