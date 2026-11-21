@echo off
setlocal
cd /d "%~dp0"
rem Floppy 32: 32-bit test. Build and run.
set "N="
where nasm >nul 2>&1 && set "N=nasm"
if not defined N if exist "%LOCALAPPDATA%\bin\NASM\nasm.exe" set "N=%LOCALAPPDATA%\bin\NASM\nasm.exe"
if not defined N if exist "%LOCALAPPDATA%\NASM\nasm.exe" set "N=%LOCALAPPDATA%\NASM\nasm.exe"
if not defined N if exist "%ProgramFiles%\NASM\nasm.exe" set "N=%ProgramFiles%\NASM\nasm.exe"
if not defined N goto nonasm
set "Q="
where qemu-system-i386 >nul 2>&1 && set "Q=qemu-system-i386"
if not defined Q if exist "%ProgramFiles%\qemu\qemu-system-i386.exe" set "Q=%ProgramFiles%\qemu\qemu-system-i386.exe"
if not defined Q if exist "C:\qemu\qemu-system-i386.exe" set "Q=C:\qemu\qemu-system-i386.exe"
if not defined Q goto noqemu
"%N%" -f bin src\boot\boot.asm -o boot.bin
if errorlevel 1 goto err
"%N%" -f bin src\kernel\kernel32.asm -o kernel32.bin
if errorlevel 1 goto err
"%N%" -f bin src\apps\flocalc\calcsys.asm -o calcsys.bin
if errorlevel 1 goto err
"%N%" -f bin src\apps\flotext\textsys.asm -o textsys.bin
if errorlevel 1 goto err
"%N%" -f bin src\apps\flopaint\paintsys.asm -o paintsys.bin
if errorlevel 1 goto err
"%N%" -f bin src\apps\flofile\filesys.asm -o filesys.bin
if errorlevel 1 goto err
"%N%" -f bin src\apps\flotasks\boilsys.asm -o boilsys.bin
if errorlevel 1 goto err
"%N%" -f bin src\apps\floitge\itgesys.asm -o itgesys.bin
if errorlevel 1 goto err
"%N%" -f bin src\apps\flocalendar\calendarsys.asm -o calendarsys.bin
if errorlevel 1 goto err
copy /b boot.bin + kernel32.bin + calcsys.bin + textsys.bin + paintsys.bin + filesys.bin + boilsys.bin + itgesys.bin + calendarsys.bin pm.img >nul
if not exist disk_o.img call :mkdisk disk_o.img
if not exist disk_i.img call :mkdisk disk_i.img
set "D3="
if exist dos.img set "D3=-drive file=dos.img,format=raw,if=ide,index=3"
"%Q%" -drive file=pm.img,format=raw,if=ide,index=0 -drive file=disk_o.img,format=raw,if=ide,index=1 -drive file=disk_i.img,format=raw,if=ide,index=2 %D3%
if errorlevel 1 pause
exit /b
:mkdisk
rem empty 64 MB disk (made once, files on it are kept between builds)
fsutil file createnew %1 67108864 >nul
if exist %1 exit /b
echo times 64 * 1048576 db 0 > _zero.asm
"%N%" -f bin _zero.asm -o %1
del _zero.asm
exit /b
:nonasm
echo Error: NASM was not found.
pause
exit /b
:noqemu
echo Error: QEMU was not found.
pause
exit /b
:err
echo Error: build failed.
pause
