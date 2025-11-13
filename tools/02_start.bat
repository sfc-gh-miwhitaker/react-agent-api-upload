@echo off
REM ============================================================================
REM                 ** Start All Services **
REM
REM   Starts the backend API and frontend UI for the demo.
REM
REM   Usage:
REM     tools\02_start.bat
REM ============================================================================

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set ENV_FILE=%PROJECT_ROOT%\config\.env
set BACKEND_PORT=4000
set FRONTEND_PORT=3002

echo ================================================================================
echo   Starting Demo Services
echo ================================================================================
echo.

REM Check if config exists
if not exist "%ENV_FILE%" (
    echo [31m❌ Error: Environment file not found at '%ENV_FILE%'[0m
    echo.
    echo Please run the key-pair setup script first:
    echo   tools\01_setup_keypair_auth.bat --account YOUR_ACCOUNT_ID
    exit /b 1
)

REM Load environment variables
echo Loading configuration...
for /f "usebackq tokens=*" %%a in ("%ENV_FILE%") do (
    set "line=%%a"
    if not "!line:~0,1!"=="#" (
        if not "!line!"=="" (
            set "%%a"
        )
    )
)
echo [32m✅ Configuration loaded[0m
echo.

REM Check for port conflicts
echo Checking ports...
netstat -ano | findstr ":%BACKEND_PORT% " | findstr "LISTENING" >nul 2>&1
if %errorlevel% equ 0 (
    echo [31m❌ Port %BACKEND_PORT% is already in use (needed for backend)[0m
    echo.
    echo Tip: Run 'tools\04_stop.bat' to stop existing services
    exit /b 1
)
netstat -ano | findstr ":%FRONTEND_PORT% " | findstr "LISTENING" >nul 2>&1
if %errorlevel% equ 0 (
    echo [31m❌ Port %FRONTEND_PORT% is already in use (needed for frontend)[0m
    echo.
    echo Tip: Run 'tools\04_stop.bat' to stop existing services
    exit /b 1
)
echo [32m✅ Ports are available[0m
echo.

REM Start Backend
echo ================================================================================
echo   Starting Backend API
echo ================================================================================
cd /d "%PROJECT_ROOT%\server"
start "React Agent Backend" /MIN cmd /c "set PORT=%BACKEND_PORT%&& node src\index.js"
echo [32m✅ Backend started on port %BACKEND_PORT%[0m
echo.

REM Wait for backend
echo Waiting for backend to be ready...
timeout /t 5 /nobreak >nul
curl -s http://localhost:%BACKEND_PORT%/health >nul 2>&1
if %errorlevel% equ 0 (
    echo [32m✅ Backend is healthy[0m
) else (
    echo [33m⚠️  Backend may still be starting...[0m
)
echo.

REM Start Frontend
echo ================================================================================
echo   Starting Frontend UI
echo ================================================================================
cd /d "%PROJECT_ROOT%"
start "React Agent Frontend" /MIN cmd /c "set PORT=%FRONTEND_PORT%&& set REACT_APP_BACKEND_URL=http://localhost:%BACKEND_PORT%&& npm start"
echo [32m✅ Frontend started on port %FRONTEND_PORT%[0m
echo.

echo Waiting for frontend to be ready (this takes ~10-15 seconds)...
timeout /t 15 /nobreak >nul
curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
if %errorlevel% equ 0 (
    echo [32m✅ Frontend is ready[0m
) else (
    echo [33m⚠️  Frontend may still be starting...[0m
)
echo.

REM Success summary
echo ================================================================================
echo   ✅ All Services Started
echo ================================================================================
echo.
echo   Backend API:  http://localhost:%BACKEND_PORT%
echo   Frontend UI:  http://localhost:%FRONTEND_PORT%
echo.
echo Next steps:
echo   1. Open http://localhost:%FRONTEND_PORT% in your browser
echo   2. Check status: tools\03_status.bat
echo   3. Stop services: tools\04_stop.bat
echo.
echo ================================================================================

endlocal

