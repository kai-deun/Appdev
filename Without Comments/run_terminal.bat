@echo off
title Baguio Dengue Surveillance & Hotspot Monitor (Terminal)
cd /d "%~dp0"

echo ====================================================================
echo Starting Baguio Dengue Surveillance Terminal System...
echo ====================================================================

set "RSCRIPT=Rscript"
where Rscript >nul 2>nul
if %errorlevel% neq 0 (
    if exist "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" (
        set "RSCRIPT=C:\Program Files\R\R-4.6.1\bin\Rscript.exe"
    ) else if exist "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" (
        set "RSCRIPT=C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"
    ) else (
        for /f "tokens=2*" %%a in ('reg query "HKLM\Software\R-core\R64" /v InstallPath 2^>nul') do set "R_PATH=%%b"
        if defined R_PATH (
            set "RSCRIPT=%R_PATH%\bin\Rscript.exe"
        ) else (
            echo [ERROR] Rscript.exe not found in PATH or standard install paths.
            pause
            exit /b 1
        )
    )
)

"%RSCRIPT%" terminal_menu.R
pause
