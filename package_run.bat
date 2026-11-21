@echo off
setlocal
cd /d "%~dp0"
if not exist "pm.img" (
  echo ERROR: pm.img missing. Run build.bat first.
  pause
  exit /b 1
)
set "OUT=%~dp0Floppy_OS_1_1_RUN.zip"
set "STAGE=%TEMP%\Floppy_OS_1_1_RUN_PACKAGE"
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%"
copy /y "pm.img" "%STAGE%\pm.img" >nul
copy /y "run.bat" "%STAGE%\run.bat" >nul
>"%STAGE%\build.bat" echo @echo off
>>"%STAGE%\build.bat" echo call "%%~dp0run.bat"
rem Do NOT ship disk_o.img or disk_i.img: they may contain private user data.
powershell -NoProfile -Command "Compress-Archive -Path '%STAGE%\*' -DestinationPath '%OUT%' -Force"
if errorlevel 1 (
  echo ERROR: could not create RUN archive.
  pause
  exit /b 1
)
rmdir /s /q "%STAGE%"
echo RUN package created: %OUT%
pause
