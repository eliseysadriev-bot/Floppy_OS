; Постоянные адреса ядра
KJ       equ 0x10010                    ; таблица переходов ядра
KBSS     equ 0x60000                    ; буферы ядра вне образа (свободная память), при старте обнуляются
KBSS_N   equ 0x1100
BOOT_EXT_KB equ 0x504                 ; BIOS extended memory above 1 MiB, 0 if unavailable
KV       equ 0x10200                    ; переменные ядра
t2_buf   equ 0x180000
clip_buf equ 0x190000
DATA_BUF equ 0x400000                   ; содержимое файла (до 256 КБ), выше 1 МБ
RUFONT   equ 0x4E000                    ; русский шрифт в конце модуля itge
