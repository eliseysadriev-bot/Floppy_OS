@echo off
cd /d "%~dp0"
taskkill /f /im bochs.exe >nul 2>&1
timeout /t 1 /nobreak >nul
del /f /q "*.lock" >nul 2>&1
"C:\Program Files\Bochs-3.1\bochs.exe" -q -f "%~dp0bochsrc.txt"
del /f /q "*.lock" >nul 2>&1
pause
