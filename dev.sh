#!/bin/bash
# Music Funnel AI - Local Development Launcher
# Starts both backend and frontend concurrently for local testing

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Music Funnel AI - Local Dev Server${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check dependencies
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}ERROR: $1 is not installed.${NC}"
        echo -e "${YELLOW}Please install $1 first.${NC}"
        exit 1
    fi
}

check_command python3
check_command node
check_command npm

# --- Backend Setup ---
echo -e "${BLUE}[1/4] Setting up Python backend...${NC}"
cd backend

if [ ! -d "venv" ]; then
    echo "  Creating virtual environment..."
    python3 -m venv venv
fi

# Detect venv activation path (Windows vs Linux)
if [ -f "venv/Scripts/activate" ]; then
    VENV_ACTIVATE="venv/Scripts/activate"
else
    VENV_ACTIVATE="venv/bin/activate"
fi

echo "  Installing Python dependencies..."
source "$VENV_ACTIVATE"
pip install -q -r requirements.txt

echo -e "${GREEN}  Backend ready!${NC}"
cd ..

# --- Frontend Setup ---
echo -e "${BLUE}[2/4] Setting up frontend...${NC}"
cd frontend

if [ ! -d "node_modules" ]; then
    echo "  Installing npm packages (this may take a minute)..."
    npm install
fi

echo -e "${GREEN}  Frontend ready!${NC}"
cd ..

# --- Start Services ---
echo ""
echo -e "${BLUE}[3/4] Starting services...${NC}"
echo ""

# Start backend in background
echo -e "${GREEN}  Backend:${NC} http://localhost:8000"
echo -e "${GREEN}  Frontend:${NC} http://localhost:3000"
echo ""

cd backend
source "$VENV_ACTIVATE"

# Function to cleanup processes on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down services...${NC}"
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
    wait $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
    echo -e "${GREEN}Done!${NC}"
    exit 0
}
trap cleanup INT TERM

# Start backend
python3 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!

cd ../frontend

# Start frontend
npm run dev &
FRONTEND_PID=$!

echo -e "${BLUE}[4/4] Both services are running!${NC}"
echo ""
echo -e "${GREEN}  API Docs:${NC}   http://localhost:8000/api/docs"
echo -e "${GREEN}  Health:${NC}    http://localhost:8000/api/health"
echo -e "${GREEN}  App:${NC}       http://localhost:3000"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop both services.${NC}"
echo ""

# Wait for both processes
wait $BACKEND_PID $FRONTEND_PID
