@echo off
setlocal
cd /d "%~dp0.."

echo ==========================================================
echo  3105 - push to GitHub, then Actions builds the unsigned IPA
echo ==========================================================
echo.

set "REPO=%~1"
if "%REPO%"=="" (
  for /f "delims=" %%R in ('git remote get-url origin 2^>nul') do set "REPO=%%R"
)
if "%REPO%"=="" (
  echo [ERROR] No remote given and 'origin' is not configured yet.
  echo Usage: scripts\push-now.cmd https://github.com/^<user^>/^<repo^>.git
  goto :fail
)

where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] git not found. Install Git for Windows: https://git-scm.com/
  goto :fail
)

if not exist ".git" (
  echo No local git repo here - running the full bootstrap script instead...
  where bash >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Git Bash not found. Run scripts\push-to-github.sh from Git Bash.
    goto :fail
  )
  bash ./scripts/push-to-github.sh "%REPO%"
  if errorlevel 1 goto :fail
  goto :ok
)

git remote get-url origin >nul 2>&1
if errorlevel 1 ( git remote add origin "%REPO%" ) else ( git remote set-url origin "%REPO%" )

echo Remote: %REPO%
echo A GitHub sign-in window may open. Sign in with YOUR OWN account.
echo Never paste a token into a chat or into a file.
echo.
git push -u origin main
if errorlevel 1 goto :pushfail

:ok
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
