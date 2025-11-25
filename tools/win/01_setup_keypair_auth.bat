@echo off
REM ============================================================================
REM Single-command setup for Snowflake key-pair authentication
REM
REM Usage:
REM   tools\win\01_setup_keypair_auth.bat [--account ACCOUNT_ID] [--user USERNAME]
REM
REM Example:
REM   tools\win\01_setup_keypair_auth.bat --account SFSENORTHAMERICA-DEMO_AWS
REM ============================================================================

setlocal

REM Change to project root
cd /d "%~dp0..\.."

REM Ensure Python script exists
if not exist "tools\01_setup_keypair_auth.py" (
    echo Error: tools\01_setup_keypair_auth.py not found
    exit /b 1
)

REM Check for virtual environment
if not exist "venv" (
    echo Virtual environment not found. Creating one...
    python -m venv venv
    echo Virtual environment created
    echo.
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Install dependencies if needed
python -c "import cryptography" 2>nul
if %errorlevel% neq 0 (
    echo Installing required dependencies...
    pip install -q cryptography
    echo Dependencies installed
    echo.
)

REM Run the Python script with all arguments
python tools\01_setup_keypair_auth.py %*

endlocal

