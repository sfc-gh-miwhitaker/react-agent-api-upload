@echo off
REM Single-command setup for Snowflake key-pair authentication (Windows)
REM
REM Usage:
REM   tools\01_setup_keypair_auth.bat [--account ACCOUNT_ID] [--user USERNAME]
REM
REM Example:
REM   tools\01_setup_keypair_auth.bat --account SFSENORTHAMERICA-MWHITAKER_AWS

setlocal EnableDelayedExpansion

REM Change to project root
cd /d "%~dp0\.."

REM Check for Python script
if not exist "tools\01_setup_keypair_auth.py" (
    echo Error: tools\01_setup_keypair_auth.py not found
    exit /b 1
)

REM Check for virtual environment
if not exist "venv" (
    echo Virtual environment not found. Creating one...
    python -m venv venv
    if errorlevel 1 (
        echo Error: Failed to create virtual environment
        exit /b 1
    )
    echo Virtual environment created
    echo.
)

REM Activate virtual environment
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
) else (
    echo Error: Could not activate virtual environment
    exit /b 1
)

REM Install dependencies if needed
python -c "import cryptography" 2>nul
if errorlevel 1 (
    echo Installing required dependencies...
    pip install -q cryptography
    if errorlevel 1 (
        echo Error: Failed to install dependencies
        exit /b 1
    )
    echo Dependencies installed
    echo.
)

REM Run the Python script with all arguments
python tools\01_setup_keypair_auth.py %*

