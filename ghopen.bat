@echo off
setlocal

git rev-parse --git-dir >nul 2>&1
if errorlevel 1 (
    echo Not a git repository.
    exit /b 1
)

where gh >nul 2>&1
if errorlevel 1 goto :no_gh

:: Try to open the PR page first; if there is no PR on this branch, gh exits non-zero
echo Checking for PR...
gh pr view --web 2>nul
if not errorlevel 1 exit /b 0

:: No PR - open the repo at the current path and branch
echo Opening repo...
gh browse
exit /b 0

:no_gh
:: gh CLI not installed - parse origin remote and open manually
echo Opening repo...
set "REMOTE="
for /f "tokens=*" %%i in ('git remote get-url origin 2^>nul') do set "REMOTE=%%i"
:: Use "if defined". Expanding the variable here would let quotes or ampersands in the remote run as commands.
if not defined REMOTE (
    echo No origin remote found.
    echo Tip: install the GitHub CLI ^(gh^) for smarter GitHub navigation.
    exit /b 1
)

:: open-remote.ps1 reads REMOTE from the environment and only opens https://github.com pages.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0open-remote.ps1"
exit /b %errorlevel%
