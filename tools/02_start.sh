#!/bin/bash
# ==============================================================================
#                 ** Start All Services **
#
#   Starts the backend API and frontend UI for the demo.
#   Writes PID files for tracking and easy cleanup.
#
#   Usage:
#     ./tools/02_start.sh
#
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/config/.env"
PIDS_DIR="$PROJECT_ROOT/.pids"

BACKEND_PORT=4000
FRONTEND_PORT=3002

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Helper Functions ---

function print_header() {
    echo "================================================================================"
    echo "  $1"
    echo "================================================================================"
}

function check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ Error: Required command '$1' not found.${NC}"
        echo "Please install it and ensure it's in your PATH."
        exit 1
    fi
}

function check_port() {
    local port=$1
    if lsof -ti :$port > /dev/null 2>/dev/null; then
        return 1  # Port is in use
    fi
    return 0  # Port is free
}

function source_env_file() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}❌ Error: Environment file not found at '$ENV_FILE'${NC}"
        echo ""
        echo "Please run the key-pair setup script first:"
        echo "  ./tools/01_setup_keypair_auth.sh --account YOUR_ACCOUNT_ID"
        exit 1
    fi
    export $(grep -v '^#' "$ENV_FILE" | xargs)
    echo -e "${GREEN}✅ Configuration loaded from '$ENV_FILE'${NC}"
}

# --- Main Execution ---

print_header "Starting Demo Services"
echo ""

# 1. Check dependencies
echo "Checking dependencies..."
check_dependency "node"
check_dependency "npm"
echo -e "${GREEN}✅ All dependencies present${NC}"
echo ""

# 2. Load environment variables
source_env_file
echo ""

# 3. Check for port conflicts
echo "Checking ports..."
PORT_CONFLICT=false
if ! check_port $BACKEND_PORT; then
    echo -e "${RED}❌ Port $BACKEND_PORT is already in use (needed for backend)${NC}"
    PORT_CONFLICT=true
fi
if ! check_port $FRONTEND_PORT; then
    echo -e "${RED}❌ Port $FRONTEND_PORT is already in use (needed for frontend)${NC}"
    PORT_CONFLICT=true
fi

if [ "$PORT_CONFLICT" = true ]; then
    echo ""
    echo -e "${YELLOW}Tip: Run './tools/04_stop.sh' to stop existing services${NC}"
    echo "     or check what's using these ports with: lsof -ti :$BACKEND_PORT :$FRONTEND_PORT"
    exit 1
fi
echo -e "${GREEN}✅ Ports are available${NC}"
echo ""

# 4. Create PID directory
mkdir -p "$PIDS_DIR"

# 5. Start Backend
print_header "Starting Backend API"
cd "$PROJECT_ROOT/server"
PORT=$BACKEND_PORT nohup node src/index.js > "$PROJECT_ROOT/.pids/backend.log" 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > "$PIDS_DIR/backend.pid"
echo -e "${GREEN}✅ Backend started on port $BACKEND_PORT (PID: $BACKEND_PID)${NC}"
echo "   Log: .pids/backend.log"
echo ""

# Wait for backend to be ready
echo "Waiting for backend to be ready..."
for i in {1..10}; do
    if curl -s http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend is healthy${NC}"
        break
    fi
    if [ $i -eq 10 ]; then
        echo -e "${RED}❌ Backend failed to start. Check .pids/backend.log${NC}"
        exit 1
    fi
    sleep 1
done
echo ""

# 6. Start Frontend
print_header "Starting Frontend UI"
cd "$PROJECT_ROOT"
PORT=$FRONTEND_PORT REACT_APP_BACKEND_URL=http://localhost:$BACKEND_PORT nohup npm start > "$PIDS_DIR/frontend.log" 2>&1 &
FRONTEND_PID=$!
echo $FRONTEND_PID > "$PIDS_DIR/frontend.pid"
echo -e "${GREEN}✅ Frontend started on port $FRONTEND_PORT (PID: $FRONTEND_PID)${NC}"
echo "   Log: .pids/frontend.log"
echo ""

# Wait for frontend to be ready
echo "Waiting for frontend to be ready (this takes ~10-15 seconds)..."
for i in {1..30}; do
    if curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Frontend is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${YELLOW}⚠️  Frontend is taking longer than expected${NC}"
        echo "   It may still be starting. Check .pids/frontend.log"
        break
    fi
    sleep 1
done
echo ""

# 7. Success summary
print_header "✅ All Services Started"
echo ""
echo "  Backend API:  http://localhost:$BACKEND_PORT"
echo "  Frontend UI:  http://localhost:$FRONTEND_PORT"
echo ""
echo "Next steps:"
echo "  1. Open http://localhost:$FRONTEND_PORT in your browser"
echo "  2. Check status: ./tools/03_status.sh"
echo "  3. Stop services: ./tools/04_stop.sh"
echo ""
echo "================================================================================"

