#!/bin/bash
set -euo pipefail

# Music Funnel AI - Update Script
# Pulls latest changes, rebuilds frontend, and restarts services
# Usage: ./update.sh [--skip-git] [--skip-build] [--restart-only]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Music Funnel AI"
APP_DIR="/opt/music-funnel-ai"
BACKEND_DIR="${APP_DIR}/backend"
FRONTEND_DIST="${APP_DIR}/frontend/dist"
SERVICE_NAME="music-funnel-ai"

# Script location (where the update.sh is)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT=""

# Options
SKIP_GIT=false
SKIP_BUILD=false
RESTART_ONLY=false
BACKUP=true

# Logging helpers
log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}[STEP]${NC}  $1"; echo; }

# Print banner
print_banner() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}           ${APP_NAME} - Update Script${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo
}

# Print help
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --skip-git      Skip git pull (use local files only)"
    echo "  --skip-build    Skip frontend rebuild (copy existing dist)"
    echo "  --restart-only  Only restart services (no code changes)"
    echo "  --no-backup     Skip creating backup before update"
    echo "  --help, -h      Show this help message"
    echo
    echo "Examples:"
    echo "  $0                  # Full update (git pull + build + restart)"
    echo "  $0 --skip-git       # Update using local files only"
    echo "  $0 --restart-only   # Just restart services"
    echo "  $0 --skip-build     # Pull and restart without rebuilding frontend"
    echo
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-git)
                SKIP_GIT=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --restart-only)
                RESTART_ONLY=true
                SKIP_GIT=true
                SKIP_BUILD=true
                shift
                ;;
            --no-backup)
                BACKUP=false
                shift
                ;;
            --help|-h)
                print_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done
}

# Check for root/sudo access
check_root() {
    log_step "Checking privileges..."
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo."
        echo
        echo "  Please run:"
        echo -e "    ${YELLOW}sudo $0${NC}"
        echo
        exit 1
    fi
    log_ok "Running with root privileges"
}

# Detect project root directory
detect_project_root() {
    # Try to find the project root relative to this script
    if [[ -d "${SCRIPT_DIR}/../backend" && -d "${SCRIPT_DIR}/../frontend" ]]; then
        PROJECT_ROOT="${SCRIPT_DIR}/.."
    elif [[ -d "${SCRIPT_DIR}/../../backend" && -d "${SCRIPT_DIR}/../../frontend" ]]; then
        PROJECT_ROOT="${SCRIPT_DIR}/../.."
    elif [[ -d "/music-funnel-ai/backend" && -d "/music-funnel-ai/frontend" ]]; then
        PROJECT_ROOT="/music-funnel-ai"
    elif [[ "$SKIP_GIT" == false && -d "${APP_DIR}/.git" ]]; then
        PROJECT_ROOT="$APP_DIR"
    else
        PROJECT_ROOT=""
    fi

    if [[ -n "$PROJECT_ROOT" ]]; then
        log_info "Project root detected: ${PROJECT_ROOT}"
    else
        log_warn "Could not auto-detect project root"
    fi
}

# Create backup before update
create_backup() {
    if [[ "$BACKUP" == false || "$RESTART_ONLY" == true ]]; then
        return
    fi

    log_step "Creating backup..."

    local BACKUP_DIR="/opt/music-funnel-ai-backups"
    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_PATH="${BACKUP_DIR}/backup_${TIMESTAMP}"

    mkdir -p "$BACKUP_DIR"

    # Backup application directory (excluding venv and node_modules)
    if [[ -d "$APP_DIR" ]]; then
        tar czf "${BACKUP_PATH}.tar.gz" \
            --exclude='venv' \
            --exclude='node_modules' \
            --exclude='.npm' \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            -C "$(dirname "$APP_DIR")" \
            "$(basename "$APP_DIR")" 2>/dev/null || true

        log_ok "Backup created: ${BACKUP_PATH}.tar.gz"

        # Keep only the last 10 backups
        ls -t "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
    fi
}

# Pull latest changes from git
git_pull() {
    if [[ "$SKIP_GIT" == true ]]; then
        log_info "Skipping git pull (--skip-git or --restart-only)"
        return
    fi

    log_step "Pulling latest changes..."

    # Check if app dir is a git repo
    if [[ -d "${APP_DIR}/.git" ]]; then
        cd "$APP_DIR"
        local CURRENT_BRANCH
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

        log_info "Current branch: ${CURRENT_BRANCH}"
        git fetch origin

        # Check if there are changes
        if git diff --quiet HEAD "origin/${CURRENT_BRANCH}" 2>/dev/null; then
            log_ok "Already up to date"
        else
            git pull origin "${CURRENT_BRANCH}"
            log_ok "Latest changes pulled from origin/${CURRENT_BRANCH}"
        fi
        cd - > /dev/null
    elif [[ -n "$PROJECT_ROOT" && -d "${PROJECT_ROOT}/.git" ]]; then
        cd "$PROJECT_ROOT"
        git pull
        cd - > /dev/null
        log_ok "Pulled from project root"
    else
        log_warn "No git repository found. Skipping git pull."
        log_info "To use git: cd ${APP_DIR} && git init && git remote add origin <your-repo-url>"
    fi
}

# Update backend
update_backend() {
    if [[ "$RESTART_ONLY" == true ]]; then
        return
    fi

    log_step "Updating backend..."

    local SOURCE_DIR=""

    # Determine source directory
    if [[ -n "$PROJECT_ROOT" && -d "${PROJECT_ROOT}/backend" ]]; then
        SOURCE_DIR="${PROJECT_ROOT}/backend"
    elif [[ -d "${APP_DIR}/backend" ]]; then
        SOURCE_DIR="${APP_DIR}/backend"
    fi

    if [[ -z "$SOURCE_DIR" ]]; then
        log_warn "Backend source not found. Skipping backend update."
        return
    fi

    # Ensure virtual environment exists
    if [[ ! -d "${BACKEND_DIR}/venv" ]]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv "${BACKEND_DIR}/venv"
    fi

    # Update Python dependencies
    if [[ -f "${SOURCE_DIR}/requirements.txt" ]]; then
        log_info "Installing/updating Python dependencies..."
        cp "${SOURCE_DIR}/requirements.txt" "${BACKEND_DIR}/requirements.txt"
        "${BACKEND_DIR}/venv/bin/pip" install -r "${BACKEND_DIR}/requirements.txt" -q
    fi

    # Copy backend source files
    log_info "Copying backend files..."
    rsync -a --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' \
        "${SOURCE_DIR}/" "${BACKEND_DIR}/" 2>/dev/null || \
        cp -r "${SOURCE_DIR}"/* "${BACKEND_DIR}/"

    # Ensure permissions are correct
    chown -R www-data:www-data "${BACKEND_DIR}"

    log_ok "Backend updated"
}

# Build and update frontend
update_frontend() {
    if [[ "$SKIP_BUILD" == true ]]; then
        log_info "Skipping frontend build (--skip-build or --restart-only)"
        return
    fi

    log_step "Building frontend..."

    local SOURCE_DIR=""

    # Determine source directory
    if [[ -n "$PROJECT_ROOT" && -d "${PROJECT_ROOT}/frontend" ]]; then
        SOURCE_DIR="${PROJECT_ROOT}/frontend"
    elif [[ -d "${APP_DIR}/frontend/src" ]]; then
        SOURCE_DIR="${APP_DIR}/frontend"
    fi

    if [[ -z "$SOURCE_DIR" ]]; then
        log_warn "Frontend source not found. Skipping frontend build."
        return
    fi

    # Create a temporary build directory
    local BUILD_DIR="/tmp/music-funnel-update-build"
    rm -rf "${BUILD_DIR}"
    cp -r "${SOURCE_DIR}" "${BUILD_DIR}"

    # Install dependencies and build
    cd "${BUILD_DIR}"
    log_info "Installing npm dependencies..."
    npm install --silent 2>&1 | tail -5 || true

    log_info "Building frontend..."
    npm run build --silent 2>&1 | tail -10 || true

    if [[ ! -d "${BUILD_DIR}/dist" ]]; then
        log_warn "No dist/ folder after build. Trying build/ directory..."
        if [[ -d "${BUILD_DIR}/build" ]]; then
            mkdir -p "$FRONTEND_DIST"
            cp -r "${BUILD_DIR}/build"/* "${FRONTEND_DIST}/"
            log_ok "Frontend built and updated (from build/)"
        else
            log_error "Frontend build failed - no dist/ or build/ directory found"
        fi
    else
        mkdir -p "$FRONTEND_DIST"
        rm -rf "${FRONTEND_DIST:?}"/*
        cp -r "${BUILD_DIR}/dist"/* "${FRONTEND_DIST}/"
        log_ok "Frontend built and updated"
    fi

    # Set correct ownership
    chown -R www-data:www-data "${FRONTEND_DIST}"

    # Cleanup
    rm -rf "${BUILD_DIR}"
    cd - > /dev/null
}

# Restart services
restart_services() {
    log_step "Restarting services..."

    # Restart backend service
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        log_info "Restarting ${SERVICE_NAME}..."
        systemctl restart "$SERVICE_NAME"

        # Wait and check status
        sleep 2
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log_ok "Backend service restarted successfully"
        else
            log_error "Backend service failed to start!"
            echo
            echo -e "  ${YELLOW}Check logs with:${NC}"
            echo -e "    ${YELLOW}journalctl -u ${SERVICE_NAME} -n 50 --no-pager${NC}"
            echo
            exit 1
        fi
    else
        log_info "Starting ${SERVICE_NAME}..."
        systemctl start "$SERVICE_NAME"
    fi

    # Reload nginx
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        log_ok "Nginx reloaded"
    else
        log_warn "Nginx config test failed, not reloading"
    fi
}

# Verify the update
verify_update() {
    log_step "Verifying update..."

    local SERVER_IP
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

    # Check backend health
    local BACKEND_STATUS
    BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8000/" 2>/dev/null || echo "000")

    echo
    if [[ "$BACKEND_STATUS" == "200" || "$BACKEND_STATUS" == "307" ]]; then
        echo -e "  Backend health:  ${GREEN}OK${NC} (HTTP ${BACKEND_STATUS})"
    else
        echo -e "  Backend health:  ${YELLOW}Check${NC} (HTTP ${BACKEND_STATUS})"
    fi

    # Check frontend
    local FRONTEND_STATUS
    FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1/" 2>/dev/null || echo "000")

    if [[ "$FRONTEND_STATUS" == "200" ]]; then
        echo -e "  Frontend health: ${GREEN}OK${NC} (HTTP ${FRONTEND_STATUS})"
    else
        echo -e "  Frontend health: ${YELLOW}Check${NC} (HTTP ${FRONTEND_STATUS})"
    fi

    echo
    echo -e "  ${CYAN}Access URLs:${NC}"
    echo -e "    Frontend: http://${SERVER_IP}/"
    echo -e "    API:      http://${SERVER_IP}/api/"
    echo
}

# Print success message
print_success() {
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}           Update Complete!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo

    if [[ "$RESTART_ONLY" == true ]]; then
        echo -e "  Services have been restarted."
    else
        echo -e "  ${APP_NAME} has been updated successfully!"
    fi

    echo
    echo -e "  ${CYAN}Check logs:${NC}"
    echo -e "    Backend: ${YELLOW}journalctl -u ${SERVICE_NAME} -f${NC}"
    echo
}

# Main execution
main() {
    parse_args "$@"
    print_banner
    check_root
    detect_project_root
    create_backup
    git_pull
    update_backend
    update_frontend
    restart_services
    verify_update
    print_success
}

# Run main
main "$@"
