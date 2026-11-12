@echo off
setlocal
title 3105 - push to GitHub

echo ==========================================================
echo  3105 - push to GitHub, then Actions builds the unsigned IPA
echo ==========================================================
echo.

REM Change this if you use another repo, or pass the URL as the first argument.
set "DEFAULT_REPO=https://github.com/Popyza1234/app.git"
set "REPO=%~1"
if "%REPO%"=="" set "REPO=%DEFAULT_REPO%"

REM Works even if this file was opened from a downloaded/copied location.
cd /d "%~dp0.."
if not exist "ThreeOneOSFive.xcodeproj\project.pbxproj" (
  if exist "%USERPROFILE%\Desktop\3105-1.1.1\ThreeOneOSFive.xcodeproj\project.pbxproj" (
    cd /d "%USERPROFILE%\Desktop\3105-1.1.1"
    echo [INFO] Switched to the project folder on your Desktop.
  ) else (
    echo [ERROR] Project files not found next to this script.
    echo Put this file inside the scripts folder of the extracted 3105 project.
    goto :fail
  )
)

where git >nul 2>&1
if errorlevel 1 (
  if exist "%ProgramFiles%\Git\cmd\git.exe" (
    set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
    echo [INFO] Using Git from %ProgramFiles%\Git\cmd
  ) else if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" (
    set "PATH=%LOCALAPPDATA%\Programs\Git\cmd;%PATH%"
    echo [INFO] Using Git from %LOCALAPPDATA%\Programs\Git\cmd
  ) else (
    echo [ERROR] git not found. Install Git for Windows: https://git-scm.com/
    echo         then run this file again.
    goto :fail
  )
)

echo Repo   : %REPO%
echo Folder : %CD%
echo.

echo [1/6] Checking git repository...
if not exist ".git\HEAD" (
  git init -b main >nul 2>&1
  if errorlevel 1 (
    git init >nul 2>&1
    git checkout -b main >nul 2>&1
  )
  echo       initialized on branch main
) else (
  echo       already a git repository
)

set "BRANCH="
for /f "delims=" %%B in ('git branch --show-current 2^>nul') do set "BRANCH=%%B"
if /I not "%BRANCH%"=="main" (
  echo [2/6] Renaming branch to main...
  git branch -M main
) else (
  echo [2/6] Branch is main.
)

echo [3/6] Staging project files and checking for secrets...
git add -A
for %%F in (scripts\*.sh) do git update-index --chmod=+x "scripts/%%~nxF" >nul 2>&1
git diff --cached --name-only | findstr /i /e ".p12 .mobileprovision .cer .pem .key .env" >nul
if not errorlevel 1 (
  echo [ERROR] Signing material or .env is staged. Remove it before pushing.
  goto :fail
)
git ls-files --error-unmatch .github/workflows/build-unsigned-ipa.yml >nul 2>&1
if errorlevel 1 (
  echo [ERROR] .github\workflows\build-unsigned-ipa.yml is missing.
  goto :fail
)

echo [4/6] Committing (if needed)...
git diff --cached --quiet
if errorlevel 1 (
  git -c user.name="3105 local" -c user.email="local@3105.invalid" commit -q -m "Enable all iOS versions and add no-Mac IPA build tooling"
  echo       committed
) else (
  echo       nothing to commit
)

echo [5/6] Setting origin...
git remote get-url origin >nul 2>&1
if errorlevel 1 ( git remote add origin "%REPO%" ) else ( git remote set-url origin "%REPO%" )

echo [6/6] Pushing main - sign in with YOUR OWN GitHub account when prompted.
echo       Never paste a token into a chat or a file.
echo.
git push -u origin main
if errorlevel 1 goto :pushfail

echo.
echo [OK] Pushed to main.
echo Next:
echo   1. Open the Actions tab of %REPO%
echo   2. Build unsigned IPA ^> Run workflow (the push already triggers it)
echo   3. Download artifact '3105-unsigned-ipa' -^> 3105-unsigned.ipa
echo   4. Sign it before installing (the IPA is UNSIGNED)
echo.
pause
exit /b 0

:pushfail
echo.
echo [FAILED] Authentication failed or the push was rejected.
echo  - Sign in with your GitHub account in the pop-up, or use a PAT as password.
echo  - If the remote already has commits: git pull --rebase origin main
echo  - Or recreate the repo completely empty (no README/license/.gitignore).
echo.

:fail
pause
exit /b 1
