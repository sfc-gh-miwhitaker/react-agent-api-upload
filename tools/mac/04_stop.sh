#!/bin/bash
# ==============================================================================
#                 ** Stop All Services **
#
#   Cleanly stops all demo services (backend API and frontend UI).
#   Safe to run multiple times.
#
#   Usage:
#     ./tools/mac/04_stop.sh
#
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
PIDS_DIR="$PROJECT_ROOT/.pids"

BACKEND_PORT=4000
FRONTEND_PORT=3002

echo "================================================================================"
echo "  Stopping All Services"
echo "================================================================================"
echo ""

STOPPED_ANY=false

# Function to stop process by PID file
stop_by_pid_file() {
    local service_name=$1
    local pid_file=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
            echo "Stopped $service_name (PID: $pid)"
            STOPPED_ANY=true
        fi
        rm -f "$pid_file"
    fi
}

# Function to stop process by port
stop_by_port() {
    local service_name=$1
    local port=$2
    
    local pid=$(lsof -ti :$port 2>/dev/null || echo "")
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || true
        sleep 1
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
        echo "Stopped $service_name (PID: $pid, Port: $port)"
        STOPPED_ANY=true
    fi
}

# Try to stop using PID files first
if [ -d "$PIDS_DIR" ]; then
    stop_by_pid_file "Backend" "$PIDS_DIR/backend.pid"
    stop_by_pid_file "Frontend" "$PIDS_DIR/frontend.pid"
fi

# Fallback: stop by port (in case PID files are missing)
stop_by_port "Backend" $BACKEND_PORT
stop_by_port "Frontend" $FRONTEND_PORT

# Also check port 3000 (React dev server default)
stop_by_port "React Dev Server" 3000

# Nuclear option: Kill any node processes in this project directory
echo ""
echo "Checking for orphaned node processes..."
ORPHANED=$(ps aux | grep "[n]ode.*react-agent-api-upload" | awk '{print $2}' || echo "")
if [ -n "$ORPHANED" ]; then
    echo "$ORPHANED" | xargs kill -9 2>/dev/null || true
    echo "Cleaned up orphaned processes"
    STOPPED_ANY=true
fi

# Clean up PID directory if empty
if [ -d "$PIDS_DIR" ] && [ -z "$(ls -A "$PIDS_DIR")" ]; then
    rmdir "$PIDS_DIR" 2>/dev/null || true
fi

echo ""
if [ "$STOPPED_ANY" = true ]; then
    echo "All services stopped"
else
    echo "No services were running"
fi
echo ""
echo "================================================================================"

