@echo off
REM ============================================================================
REM                 ** Stop All Services **
REM
REM   Cleanly stops all demo services (backend API and frontend UI).
REM   Safe to run multiple times.
REM
REM   Usage:
REM     tools\win\04_stop.bat
REM ============================================================================

setlocal

set BACKEND_PORT=4000
set FRONTEND_PORT=3002
set STOPPED_ANY=0

echo ================================================================================
echo   Stopping All Services
echo ================================================================================
echo.

REM Stop Backend (Port 4000)
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%BACKEND_PORT% " ^| findstr "LISTENING"') do (
    echo Stopping Backend (PID: %%a)...
    taskkill /F /PID %%a >nul 2>&1
    if !errorlevel! equ 0 (
        echo Stopped Backend (PID: %%a)
        set STOPPED_ANY=1
    )
)

REM Stop Frontend (Port 3002)
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%FRONTEND_PORT% " ^| findstr "LISTENING"') do (
    echo Stopping Frontend (PID: %%a)...
    taskkill /F /PID %%a >nul 2>&1
    if !errorlevel! equ 0 (
        echo Stopped Frontend (PID: %%a)
        set STOPPED_ANY=1
    )
)

REM Also kill any node processes related to this project (backup)
taskkill /F /FI "WINDOWTITLE eq Administrator:*react-agent*" >nul 2>&1

echo.
if %STOPPED_ANY% equ 1 (
    echo All services stopped
) else (
    echo No services were running
)
echo.
echo ================================================================================

endlocal

