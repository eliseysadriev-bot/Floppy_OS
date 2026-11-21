@echo off
setlocal
rem Floppy 1.0: makes dos.img and starts the FreeDOS installer.
rem Put this file next to build.bat together with the FreeDOS LiveCD file (FD14LIVE.iso or similar).
set "Q="
where qemu-system-i386 >nul 2>&1 && set "Q=qemu-system-i386"
if not defined Q if exist "%ProgramFiles%\qemu\qemu-system-i386.exe" set "Q=%ProgramFiles%\qemu\qemu-system-i386.exe"
if not defined Q if exist "C:\qemu\qemu-system-i386.exe" set "Q=C:\qemu\qemu-system-i386.exe"
if not defined Q goto noqemu
set "I="
for %%f in (*LIVE*.iso) do set "I=%%f"
if not defined I goto noiso
if exist dos.img goto have
fsutil file createnew dos.img 104857600 >nul
if errorlevel 1 goto noimg
:have
echo Installing FreeDOS from %I% to dos.img
echo In the window choose: Install to harddisk, then answer Yes.
"%Q%" -drive file=dos.img,format=raw,if=ide,index=0 -cdrom "%I%" -boot d
echo Done. Now add this to the end of the QEMU line in build.bat:
echo -drive file=dos.img,format=raw,if=ide,index=3
pause
exit /b
:noqemu
echo Error: QEMU was not found.
pause
exit /b
:noiso
echo Error: no FreeDOS LiveCD file (*LIVE*.iso) next to this file.
pause
exit /b
:noimg
echo Error: could not make dos.img.
pause
exit /b
