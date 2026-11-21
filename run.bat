@echo off
setlocal
cd /d "%~dp0"
set "QEMU=C:\Program Files\qemu\qemu-system-i386.exe"
if not exist "%QEMU%" (
  where qemu-system-i386 >nul 2>&1
  if errorlevel 1 (
    echo ERROR: QEMU not found. Install QEMU or edit QEMU path in run.bat.
    pause
    exit /b 1
  )
  set "QEMU=qemu-system-i386"
)
if not exist "pm.img" (
  echo ERROR: pm.img is missing.
  echo To make this package runnable, compile the SOURCE project
  echo using build.bat and copy pm.img here.
  pause
  exit /b 1
)
if not exist "disk_o.img" fsutil file createnew "disk_o.img" 67108864 >nul
if not exist "disk_i.img" fsutil file createnew "disk_i.img" 67108864 >nul
if not exist "disk_o.img" goto diskerror
if not exist "disk_i.img" goto diskerror
set "D3="
if exist "dos.img" set "D3=-drive file=dos.img,format=raw,if=ide,index=3"
"%QEMU%" -drive file=pm.img,format=raw,if=ide,index=0 -drive file=disk_o.img,format=raw,if=ide,index=1 -drive file=disk_i.img,format=raw,if=ide,index=2 %D3%
if errorlevel 1 pause
exit /b 0
:diskerror
echo ERROR: Not enough disk space or cannot create virtual disks.
pause
exit /b 1
