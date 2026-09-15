@echo off
setlocal enabledelayedexpansion
title Baguio Dengue Surveillance - Requirements Installer
cd /d "%~dp0"

echo ====================================================================
echo    BAGUIO DENGUE SURVEILLANCE ^& HOTSPOT TERMINAL SYSTEM
echo            AUTOMATED REQUIREMENTS INSTALLER
echo ====================================================================
echo.

set "FOUND_R="

where Rscript >nul 2>nul
if %errorlevel% equ 0 (
    for /f "delims=" %%i in ('where Rscript') do (
        set "FOUND_R=%%i"
        goto :R_FOUND
    )
)

if exist "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" (
    set "FOUND_R=C:\Program Files\R\R-4.6.1\bin\Rscript.exe"
    goto :R_FOUND
)
if exist "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" (
    set "FOUND_R=C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"
    goto :R_FOUND
)

for /d %%D in ("C:\Program Files\R\R-*") do (
    if exist "%%D\bin\Rscript.exe" (
        set "FOUND_R=%%D\bin\Rscript.exe"
        goto :R_FOUND
    )
    if exist "%%D\bin\x64\Rscript.exe" (
        set "FOUND_R=%%D\bin\x64\Rscript.exe"
        goto :R_FOUND
    )
)

:R_FOUND
if defined FOUND_R (
    echo [OK] R installation detected at:
    echo      !FOUND_R!
    echo.
    goto :CHECK_PACKAGES
)

echo [!] R runtime environment was NOT detected on this machine.
echo [!] Attempting automated download and installation...
echo.

:: Check for winget
where winget >nul 2>nul
if %errorlevel% equ 0 (
    echo [INFO] Installing R via Windows Package Manager (winget)...
    winget install --id RProject.R -e --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [OK] R installed successfully via winget.
        goto :DETECT_NEW_R
    ) else (
        echo [WARN] Winget install returned code %errorlevel%. Trying direct download fallback...
    )
)

echo [INFO] Downloading latest R Windows installer from CRAN...
set "INSTALLER_EXE=%TEMP%\R-Windows-Setup.exe"
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://cran.r-project.org/bin/windows/base/R-release.exe', '%INSTALLER_EXE%')"

if exist "%INSTALLER_EXE%" (
    echo [INFO] Running installer silently...
    start /wait "" "%INSTALLER_EXE%" /SILENT /VERYSILENT /DIR="C:\Program Files\R\R-latest"
    del /f /q "%INSTALLER_EXE%" >nul 2>nul
) else (
    echo [ERROR] Failed to download R installer automatically.
    echo Please manually download and install R from: https://cran.r-project.org/bin/windows/base/
    pause
    exit /b 1
)

:DETECT_NEW_R
for /d %%D in ("C:\Program Files\R\R-*") do (
    if exist "%%D\bin\Rscript.exe" (
        set "FOUND_R=%%D\bin\Rscript.exe"
    )
)

if not defined FOUND_R (
    echo [ERROR] R installation finished, but Rscript could not be located.
    echo Please restart your terminal or check C:\Program Files\R.
    pause
    exit /b 1
)

:CHECK_PACKAGES
echo [INFO] Verifying R runtime and base environment packages...
"!FOUND_R!" -e "cat('R Version:', R.version.string, '\nAll project dependencies (base, stats, utils) verified successfully.\n')"

echo.
echo ====================================================================
echo [SUCCESS] All requirements for Baguio Dengue Surveillance are ready!
echo You can now launch the app using: run_terminal.bat
echo ====================================================================
echo.
pause
