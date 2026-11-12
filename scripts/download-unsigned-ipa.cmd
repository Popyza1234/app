@echo off
setlocal
title dekpop - download unsigned IPA
cd /d "%~dp0.."

echo ==========================================================
echo  dekpop - download dekpop-unsigned.ipa from GitHub Actions
echo ==========================================================
echo.

where python >nul 2>&1
if errorlevel 1 (
  if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" (
    set "PY=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
  ) else (
    echo [ERROR] Python 3 not found. Install it from https://www.python.org/
    goto :fail
  )
) else (
  set "PY=python"
)

"%PY%" scripts\download-unsigned-ipa.py %*
if errorlevel 1 goto :fail

echo.
echo [OK] dekpop-unsigned.ipa is in this folder. It is UNSIGNED - sign it first.
echo      ESign on the device, or scripts\resign-windows-zsign.ps1 on Windows.
pause
exit /b 0

:fail
echo.
echo [FAILED] You can always download the artifact manually:
echo   https://github.com/Popyza1234/app/actions  ^> Artifacts ^> dekpop-unsigned-ipa
pause
exit /b 1
