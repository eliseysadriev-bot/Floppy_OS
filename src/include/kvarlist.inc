; Переменные ядра, которые видят модули .sys. Один список: ядро по нему кладёт данные, модули получают адреса
KVD clp_x0, 0
KVD clp_y0, 0
KVD clp_x1, 800
KVD clp_y1, 600
KVD cw_x, 0
KVD cw_y, 0
KVD win_w, 0
KVD win_h, 0
KVD m_x, 400
KVD m_y, 300
KVD r_x, 0
KVD r_y, 0
KVD r_w, 0
KVD r_h, 0
KVD r_c, 0
KVD t_x, 0
KVD t_y, 0
KVB t_id, 0
KVB on_disk, 0
KVB fs_par, 0
KVB t2_dsk, 255
KVB t2_par, 0
KVS t2_nm, 16
KVS t2_title, 24
KVS fn_buf, 20
KVB sel_drag, 0
KVS t2_tmp, 2
KVD sb_w, 16
KVD clip_len, 0
KVD f_size, 0
KVD r_fn, 0
KVS dl_name, 20
KVB dl_len, 0
KVB dl_car, 0
KVB dl_anc, 255
KVB dl_nohint, 0
KVB dl_app, 0
KVD qx0, 176
KVD qy0, 80
KVD dlg_w, 448
KVB lst_st, 0
KVB lst_n, 0
KVS lst_ids, 33
KVS pc_st, 8
KVS pc_tot, 32
KVS pc_free, 32
KVS dtab, 96
KVB sb_drag, 0
KVB sb_ctx, 0
KVB d2_tm, 0
KVD ticks, 0
KVB fclip_ok, 0                        ; 0 empty, 1 file, 2 FSM2 folder
KVB fclip_dsk, 0
KVB fclip_par, 0
KVS fclip_nm, 16
KVB pa_dirty, 0
KVB it_mod, 0
KVB sv_who, 0
KVB sv_after, 0
KVB hp_on, 0
KVD hp_w, 0
KVD hp_h, 0
KVB kb_ru, 0
KVB ui_ru, 0

; FSM3 nested folders (append-only shared ABI). Root=0, folder=slot index+1.
KVD fs3_folder_id, 0
KVS fs3_list_hi, 33

; Movable FloFile dialogs. Append-only shared kernel/module ABI.
KVD nm_x, 200
KVD nm_y, 200
KVD nm_w, 400
KVD nm_h, 280
KVD pr_x, 160
KVD pr_y, 100
KVD pr_w, 480
KVD pr_h, 368

; Modal FloFile titlebar minimize state (append-only ABI; earlier offsets unchanged).
KVB nm_min, 0
KVB pr_min, 0
