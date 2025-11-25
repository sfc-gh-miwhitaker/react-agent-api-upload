#!/bin/bash
# ==============================================================================
#                 ** Service Status Check **
#
#   Shows the status of all demo services (backend API and frontend UI).
#
#   Usage:
#     ./tools/mac/03_status.sh
#
#   Exit codes:
#     0 - All expected services are running
#     1 - One or more services are not running
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
PIDS_DIR="$PROJECT_ROOT/.pids"

BACKEND_PORT=4000
FRONTEND_PORT=3002

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================================================"
echo "  Service Status Check"
echo "================================================================================"
echo ""

ALL_RUNNING=true

# Check Backend
echo "Backend API (Port $BACKEND_PORT):"
BACKEND_PID=$(lsof -ti :$BACKEND_PORT 2>/dev/null || echo "")
if [ -n "$BACKEND_PID" ]; then
    echo -e "  ${GREEN}Running${NC} (PID: $BACKEND_PID)"
    BACKEND_CMD=$(ps -p $BACKEND_PID -o command= 2>/dev/null | head -c 60)
    echo "     Process: $BACKEND_CMD..."
    
    # Health check
    if curl -s http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
        echo -e "  ${GREEN}Health check: OK${NC}"
    else
        echo -e "  ${YELLOW}Health check: Failed${NC}"
    fi
else
    echo -e "  ${RED}Stopped${NC}"
    ALL_RUNNING=false
fi
echo ""

# Check Frontend
echo "Frontend UI (Port $FRONTEND_PORT):"
FRONTEND_PID=$(lsof -ti :$FRONTEND_PORT 2>/dev/null || echo "")
if [ -n "$FRONTEND_PID" ]; then
    echo -e "  ${GREEN}Running${NC} (PID: $FRONTEND_PID)"
    
    # HTTP check
    if curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
        echo -e "  ${GREEN}HTTP check: OK${NC}"
    else
        echo -e "  ${YELLOW}HTTP check: Failed${NC}"
    fi
else
    echo -e "  ${RED}Stopped${NC}"
    ALL_RUNNING=false
fi
echo ""

# Access URLs
if [ "$ALL_RUNNING" = true ]; then
    echo "================================================================================"
    echo "  Access URLs"
    echo "================================================================================"
    echo ""
    echo "  Frontend: http://localhost:$FRONTEND_PORT"
    echo "  Backend:  http://localhost:$BACKEND_PORT"
    echo ""
    echo -e "${GREEN}All services running${NC}"
    echo ""
    exit 0
else
    echo "================================================================================"
    echo -e "${YELLOW}Some services are not running${NC}"
    echo ""
    echo "To start services: ./tools/mac/02_start.sh"
    echo "================================================================================"
    echo ""
    exit 1
fi

