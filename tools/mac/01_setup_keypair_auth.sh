#!/bin/bash
#
# Single-command setup for Snowflake key-pair authentication
#
# Usage:
#   ./tools/mac/01_setup_keypair_auth.sh [--account ACCOUNT_ID] [--user USERNAME]
#
# Example:
#   ./tools/mac/01_setup_keypair_auth.sh --account SFSENORTHAMERICA-DEMO_AWS
#

set -e

# Change to project root
cd "$(dirname "$0")/../.."

# Ensure Python script exists
if [ ! -f "tools/01_setup_keypair_auth.py" ]; then
    echo "Error: tools/01_setup_keypair_auth.py not found"
    exit 1
fi

# Check for virtual environment
if [ ! -d "python/.venv" ]; then
    echo "Virtual environment not found. Creating one..."
    python3 -m venv python/.venv
    echo "Virtual environment created"
    echo ""
fi

# Activate virtual environment
if [ -f "python/.venv/bin/activate" ]; then
    source python/.venv/bin/activate
else
    echo "Error: Could not activate virtual environment"
    exit 1
fi

# Install dependencies if needed
if ! python -c "import cryptography" 2>/dev/null; then
    echo "Installing required dependencies..."
    pip install -q cryptography
    echo "Dependencies installed"
    echo ""
fi

# Run the Python script with all arguments
python tools/01_setup_keypair_auth.py "$@"
