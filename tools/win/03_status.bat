@echo off
REM ============================================================================
REM                 ** Service Status Check **
REM
REM   Shows the status of all demo services (backend API and frontend UI).
REM
REM   Usage:
REM     tools\win\03_status.bat
REM ============================================================================

setlocal enabledelayedexpansion

set BACKEND_PORT=4000
set FRONTEND_PORT=3002
set ALL_RUNNING=1

echo ================================================================================
echo   Service Status Check
echo ================================================================================
echo.

REM Check Backend
echo Backend API (Port %BACKEND_PORT%):
netstat -ano | findstr ":%BACKEND_PORT% " | findstr "LISTENING" >nul 2>&1
if %errorlevel% equ 0 (
    echo   [32mRunning[0m
    curl -s http://localhost:%BACKEND_PORT%/health >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [32mHealth check: OK[0m
    ) else (
        echo   [33mHealth check: Failed[0m
    )
) else (
    echo   [31mStopped[0m
    set ALL_RUNNING=0
)
echo.

REM Check Frontend
echo Frontend UI (Port %FRONTEND_PORT%):
netstat -ano | findstr ":%FRONTEND_PORT% " | findstr "LISTENING" >nul 2>&1
if %errorlevel% equ 0 (
    echo   [32mRunning[0m
    curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [32mHTTP check: OK[0m
    ) else (
        echo   [33mHTTP check: Failed[0m
    )
) else (
    echo   [31mStopped[0m
    set ALL_RUNNING=0
)
echo.

REM Show URLs or start instructions
if %ALL_RUNNING% equ 1 (
    echo ================================================================================
    echo   Access URLs
    echo ================================================================================
    echo.
    echo   Frontend: http://localhost:%FRONTEND_PORT%
    echo   Backend:  http://localhost:%BACKEND_PORT%
    echo.
    echo [32mAll services running[0m
    echo.
    exit /b 0
) else (
    echo ================================================================================
    echo [33mSome services are not running[0m
    echo.
    echo To start services: tools\win\02_start.bat
    echo ================================================================================
    echo.
    exit /b 1
)

