#!/bin/bash
# Floppy 1.1: сборка и запуск (Linux / macOS)
cd "$(dirname "$0")" || exit 1

command -v nasm >/dev/null || { echo "Ошибка: NASM не найден (sudo apt install nasm)"; exit 1; }
command -v qemu-system-i386 >/dev/null || { echo "Ошибка: QEMU не найден (sudo apt install qemu-system-x86)"; exit 1; }

nasm -f bin src/boot/boot.asm -o boot.bin || { echo "Ошибка сборки boot.asm"; exit 1; }
nasm -f bin src/kernel/kernel32.asm -o kernel32.bin || { echo "Ошибка сборки kernel32.asm"; exit 1; }
nasm -f bin src/apps/flocalc/calcsys.asm -o calcsys.bin || { echo "Ошибка сборки calcsys.asm (FloCalc.sys)"; exit 1; }
nasm -f bin src/apps/flotext/textsys.asm -o textsys.bin || { echo "Ошибка сборки textsys.asm (FloText.sys)"; exit 1; }
nasm -f bin src/apps/flopaint/paintsys.asm -o paintsys.bin || { echo "Ошибка сборки paintsys.asm (FloPaint.sys)"; exit 1; }
nasm -f bin src/apps/flofile/filesys.asm -o filesys.bin || { echo "Ошибка сборки filesys.asm (FloFile.sys)"; exit 1; }
nasm -f bin src/apps/flotasks/boilsys.asm -o boilsys.bin || { echo "Ошибка сборки boilsys.asm (Boil.sys)"; exit 1; }
nasm -f bin src/apps/floitge/itgesys.asm -o itgesys.bin || { echo "Ошибка сборки itgesys.asm (itge.sys)"; exit 1; }
nasm -f bin src/apps/flocalendar/calendarsys.asm -o calendarsys.bin || { echo "Ошибка сборки calendarsys.asm (FloCalendar.sys)"; exit 1; }
cat boot.bin kernel32.bin calcsys.bin textsys.bin paintsys.bin filesys.bin boilsys.bin itgesys.bin calendarsys.bin > pm.img

# пустые диски по 1 МБ (создаются один раз, файлы на них сохраняются)
for d in disk_o.img disk_i.img; do
    [ -f "$d" ] || dd if=/dev/zero of="$d" bs=1M count=1 status=none
done

qemu-system-i386 \
    -drive file=pm.img,format=raw,if=ide,index=0 \
    -drive file=disk_o.img,format=raw,if=ide,index=1 \
    -drive file=disk_i.img,format=raw,if=ide,index=2
