d2_cal      db 0
cal_menu    db 0
cal_pr      db 0
cal_x       dd 184
cal_y       dd 96
cal_w       dd CAL_W
cal_h       dd CAL_H
cal_tb      times 5 dd 0                ; сегодня: час, минута, день, месяц, год
cal_vb      dd 0, 0, 0, 11, 2026        ; показанный месяц ([12]) и год ([16])
cal_st      dd 0
cal_nd      dd 0
cal_d       dd 0
cal_cx      dd 0
cal_cy      dd 0
cal_tc      dd 0
cal_tl      dd 0
cal_tx      dd 0
cal_nb      times 8 db 0
cal_step_x  dd 56                        ; date cell spacing at current width
cal_step_y  dd 36                        ; date row spacing at current height
cal_t       db 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4
cal_mn      dd s_cal_m1, s_cal_m2, s_cal_m3, s_cal_m4, s_cal_m5, s_cal_m6
            dd s_cal_m7, s_cal_m8, s_cal_m9, s_cal_m10, s_cal_m11, s_cal_m12
s_cal_t     db "FloCalendar", 0
s_wm_file   db "File", 0
s_cal_l     db "<", 0
s_cal_r     db ">", 0
s_cal_m1    db "January", 0
s_cal_m2    db "February", 0
s_cal_m3    db "March", 0
s_cal_m4    db "April", 0
s_cal_m5    db "May", 0
s_cal_m6    db "June", 0
s_cal_m7    db "July", 0
s_cal_m8    db "August", 0
s_cal_m9    db "September", 0
s_cal_m10   db "October", 0
s_cal_m11   db "November", 0
s_cal_m12   db "December", 0
s_cal_w1    db "Mo", 0
s_cal_w2    db "Tu", 0
s_cal_w3    db "We", 0
s_cal_w4    db "Th", 0
s_cal_w5    db "Fr", 0
s_cal_w6    db "Sa", 0
s_cal_w7    db "Su", 0

; Added after existing data; preserves fixed offset of d2_cal/cal_x for kernel.
cal_min db 0
s_cal_minimized db "FloCalendar", 0
