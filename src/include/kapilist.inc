; Функции ядра, которые видят модули .sys (адреса не меняются)
KAPI cwin
KAPI draw_big
KAPI fill_rect
KAPI mclip_off
KAPI redraw
KAPI sbar
KAPI wait_end
KAPI wait_start
KAPI xbtn
KAPI strlen
KAPI wbtn
KAPI dlg_open
KAPI file_read
KAPI file_write
KAPI splash_start
KAPI z_hide_others
KAPI z_restore
KAPI fs_setdisk
KAPI make_title
KAPI mkname
KAPI dt_letter
KAPI dlg_open_p
KAPI mkname_p
KAPI dir_find
KAPI dir_has_child
KAPI dir_mkdir
KAPI dir_rename
KAPI dk_open
KAPI dlg_key
KAPI dlg_mcell
KAPI dlg_name_draw
KAPI file_delete
KAPI fs_list
KAPI fs_pc_scan
KAPI sb_set
KAPI sb_grab
KAPI tm_toggle
KAPI u32str
KAPI dir_last_id
KAPI dlg_open_i
KAPI set_palette
KAPI dlg_open_x
KAPI sv_ask
KAPI ck_open
KAPI tr_open
KAPI mn_pdraw
KAPI egg_test
KAPI hp_win
KAPI ui_tr
KAPI mn_over

; Floppy_156 streaming FSM3 API (append-only ABI)
KAPI fs3sr_open
KAPI fs3sr_next
KAPI fs3sw_begin
KAPI fs3sw_put
KAPI fs3sw_commit
KAPI fs3sw_cancel

; FloCalendar.sys: kernel services needed by external calendar module (append-only).
KAPI rtc_get
KAPI tz_apply
KAPI tz_dim
KAPI wm_menu
KAPI hp_bw
KAPI wm_hit
KAPI drag_start
KAPI cal_get_timezone
KAPI cal_drag_context

; AL = (section << 4) | error number; show shared dialog
KAPI core_err_raise

; FloFile.sys: select a kernel drag context without direct access to d_ctx.
KAPI file_drag_context

; Floppy OS 2.0 native unframed title buttons, append-only ABI.
KAPI mbtn
KAPI title_button_state

; Shared native System File menu and title routines (append-only for .sys modules).
KAPI sys_file_draw
KAPI sys_file_hit
KAPI sys_modal_center

; Common Z-order for separately assembled windowed apps (DL = window ID).
KAPI fz_open_window

; FSM3 in-volume, byte-streamed Copy/Paste for FloFile (append-only ABI).
KAPI fs3_copy_file

; FSM3 streaming creation with atomic catalog visibility (append-only ABI).
KAPI fs3sw_begin_new

; Shared press animation state for native/dialog/FloFile buttons (append-only).
KAPI ui_button_state
