#!/bin/bash
set -euo pipefail

# Music Funnel AI - Google VPS Installer
# One-command deployment script for Ubuntu 22.04 on Google Compute Engine
# Usage: ./install.sh [--gemini-key YOUR_API_KEY]

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
NGINX_CONF_SRC="$(cd "$(dirname "$0")" && pwd)/nginx.conf"
BACKEND_SERVICE_SRC="$(cd "$(dirname "$0")" && pwd)/backend.service"

# Variables
GEMINI_API_KEY=""
SKIP_PACKAGES=false
SKIP_FIREWALL=false

# Logging helpers
log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}[STEP]${NC}  $1"; echo; }

# Print banner
print_banner() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}           ${APP_NAME} - Google VPS Installer${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo
    echo -e "  This script will install and configure:"
    echo -e "    - Nginx reverse proxy"
    echo -e "    - FastAPI backend (systemd service)"
    echo -e "    - React frontend (static build)"
    echo -e "    - UFW firewall"
    echo -e "    - Python 3 virtual environment"
    echo
    echo -e "${BLUE}============================================================${NC}"
    echo
}

# Print help
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --gemini-key KEY     Set the Google Gemini API key"
    echo "  --skip-packages      Skip system package installation"
    echo "  --skip-firewall      Skip UFW firewall configuration"
    echo "  --help, -h           Show this help message"
    echo
    echo "Examples:"
    echo "  $0"
    echo "  $0 --gemini-key YOUR_API_KEY_HERE"
    echo "  $0 --skip-packages --gemini-key YOUR_API_KEY_HERE"
    echo
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --gemini-key)
                GEMINI_API_KEY="$2"
                shift 2
                ;;
            --skip-packages)
                SKIP_PACKAGES=true
                shift
                ;;
            --skip-firewall)
                SKIP_FIREWALL=true
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

# Check if running on Ubuntu/Debian
check_os() {
    log_step "Checking operating system..."
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS. This script requires Ubuntu or Debian."
        exit 1
    fi

    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log_error "Unsupported OS: $ID. This script requires Ubuntu or Debian."
        exit 1
    fi

    log_ok "Detected OS: $PRETTY_NAME"
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

# Update system packages
update_system() {
    log_step "Updating system packages..."
    apt update -qq
    apt upgrade -y -qq
    log_ok "System packages updated"
}

# Install required packages
install_packages() {
    log_step "Installing required packages..."

    apt install -y -qq \
        curl \
        wget \
        git \
        nginx \
        python3 \
        python3-pip \
        python3-venv \
        ufw \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        2>&1 | grep -v "^Selecting\|^Preparing\|^Unpacking\|^Setting up\|^Processing\|^Scanning\|^Building" || true

    log_ok "Base packages installed"
}

# Install Node.js 20 from NodeSource
install_nodejs() {
    log_step "Installing Node.js 20..."

    if command -v node &>/dev/null && [[ "$(node -v | cut -d'v' -f2 | cut -d'.' -f1)" == "20" ]]; then
        log_ok "Node.js 20 already installed ($(node -v))"
        return
    fi

    if command -v node &>/dev/null; then
        CURRENT_VERSION=$(node -v 2>/dev/null || echo "none")
        log_warn "Current Node.js version: $CURRENT_VERSION. Upgrading to 20..."
    fi

    # Remove old NodeSource setup if exists
    rm -f /etc/apt/sources.list.d/nodesource.list
    rm -f /etc/apt/keyrings/nodesource.gpg

    # Install NodeSource GPG key and repo
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

    NODE_MAJOR=20
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list

    apt update -qq
    apt install -y -qq nodejs 2>&1 | grep -v "^Selecting\|^Preparing\|^Unpacking\|^Setting up\|^Processing" || true

    # Verify installation
    NODE_VERSION=$(node -v 2>/dev/null || echo "unknown")
    NPM_VERSION=$(npm -v 2>/dev/null || echo "unknown")
    log_ok "Node.js installed: ${NODE_VERSION}, npm: ${NPM_VERSION}"
}

# Prompt for Gemini API key
prompt_gemini_key() {
    log_step "Configuring Gemini API Key..."

    if [[ -n "$GEMINI_API_KEY" ]]; then
        log_info "Using Gemini API key from command line argument"
        return
    fi

    echo
    echo -e "${CYAN}-----------------------------------------------------------${NC}"
    echo -e "  The ${APP_NAME} requires a Google Gemini API key for AI mode."
    echo
    echo -e "  You can get a free API key from:"
    echo -e "    ${YELLOW}https://aistudio.google.com/app/apikey${NC}"
    echo
    echo -e "  If you don't have one yet, you can:"
    echo -e "    1. Enter a placeholder now and edit ${APP_DIR}/.env later"
    echo -e "    2. Press Ctrl+C to exit, get a key, and re-run this script"
    echo -e "${CYAN}-----------------------------------------------------------${NC}"
    echo

    read -rp "  Enter your Gemini API key (or press Enter to skip): " GEMINI_API_KEY

    if [[ -z "$GEMINI_API_KEY" ]]; then
        log_warn "No API key provided. AI mode will not work until you set GEMINI_API_KEY in ${APP_DIR}/.env"
        GEMINI_API_KEY="your_gemini_api_key_here"
    else
        log_ok "API key saved (hidden for security)"
    fi
    echo
}

# Create app directory structure
create_directories() {
    log_step "Creating application directories..."

    mkdir -p "${APP_DIR}"
    mkdir -p "${BACKEND_DIR}"
    mkdir -p "${APP_DIR}/frontend/dist"
    mkdir -p "${APP_DIR}/logs"

    log_ok "Directories created at ${APP_DIR}"
}

# Create .env file
create_env_file() {
    log_step "Creating environment configuration..."

    cat > "${APP_DIR}/.env" <<EOF
# ============================================
# Music Funnel AI - Production Environment
# Generated on $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# ============================================

# Google Gemini API Key (required for AI mode)
# Get your key from: https://aistudio.google.com/app/apikey
GEMINI_API_KEY=${GEMINI_API_KEY}

# Backend port (default: 8000)
# Only change this if you know what you're doing - nginx proxies to 8000
PORT=8000

# CORS allowed origins (comma-separated, or * for all)
# In production, set this to your actual domain(s)
ALLOWED_ORIGINS=*
EOF

    chmod 600 "${APP_DIR}/.env"
    log_ok "Environment file created at ${APP_DIR}/.env"
}

# Copy and setup backend
setup_backend() {
    log_step "Setting up Python backend..."

    # Determine where the backend source is relative to this script
    local SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    local BACKEND_SRC=""

    # Try to find backend source
    if [[ -d "${SCRIPT_DIR}/../backend" ]]; then
        BACKEND_SRC="${SCRIPT_DIR}/../backend"
    elif [[ -d "${SCRIPT_DIR}/../../backend" ]]; then
        BACKEND_SRC="${SCRIPT_DIR}/../../backend"
    elif [[ -d "/music-funnel-ai/backend" ]]; then
        BACKEND_SRC="/music-funnel-ai/backend"
    else
        log_warn "Backend source not found. Please copy backend files manually to ${BACKEND_DIR}"
        log_info "Expected: backend/ folder at project root (same level as deployment/)"
        return
    fi

    log_info "Copying backend files from ${BACKEND_SRC}..."
    cp -r "${BACKEND_SRC}"/* "${BACKEND_DIR}/"

    # Create Python virtual environment
    log_info "Creating Python virtual environment..."
    python3 -m venv "${BACKEND_DIR}/venv"

    # Install Python dependencies
    log_info "Installing Python dependencies..."
    if [[ -f "${BACKEND_DIR}/requirements.txt" ]]; then
        "${BACKEND_DIR}/venv/bin/pip" install --upgrade pip -q
        "${BACKEND_DIR}/venv/bin/pip" install -r "${BACKEND_DIR}/requirements.txt" -q
    else
        log_warn "No requirements.txt found. Installing common FastAPI packages..."
        "${BACKEND_DIR}/venv/bin/pip" install --upgrade pip -q
        "${BACKEND_DIR}/venv/bin/pip" install fastapi uvicorn python-dotenv google-generativeai -q
    fi

    log_ok "Backend setup complete"
}

# Build and setup frontend
setup_frontend() {
    log_step "Building frontend..."

    local SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    local FRONTEND_SRC=""

    # Try to find frontend source
    if [[ -d "${SCRIPT_DIR}/../frontend" ]]; then
        FRONTEND_SRC="${SCRIPT_DIR}/../frontend"
    elif [[ -d "${SCRIPT_DIR}/../../frontend" ]]; then
        FRONTEND_SRC="${SCRIPT_DIR}/../../frontend"
    elif [[ -d "/music-funnel-ai/frontend" ]]; then
        FRONTEND_SRC="/music-funnel-ai/frontend"
    else
        log_warn "Frontend source not found. Please copy built files manually to ${FRONTEND_DIST}"
        log_info "Expected: frontend/ folder at project root (same level as deployment/)"
        return
    fi

    log_info "Building frontend from ${FRONTEND_SRC}..."

    # Create a temporary build directory
    local BUILD_DIR="/tmp/music-funnel-frontend-build"
    rm -rf "${BUILD_DIR}"
    cp -r "${FRONTEND_SRC}" "${BUILD_DIR}"

    # Install dependencies and build
    cd "${BUILD_DIR}"
    npm install --silent 2>&1 | tail -5 || true
    npm run build --silent 2>&1 | tail -10 || true

    if [[ ! -d "${BUILD_DIR}/dist" ]]; then
        log_warn "No dist/ folder after build. Check frontend/package.json for build script."
        # Try alternative output directory
        if [[ -d "${BUILD_DIR}/build" ]]; then
            log_info "Found build/ directory, using it instead"
            cp -r "${BUILD_DIR}/build"/* "${FRONTEND_DIST}/"
        fi
    else
        cp -r "${BUILD_DIR}/dist"/* "${FRONTEND_DIST}/"
        log_ok "Frontend built and copied to ${FRONTEND_DIST}"
    fi

    # Cleanup
    rm -rf "${BUILD_DIR}"
    cd - > /dev/null
}

# Set proper file permissions
set_permissions() {
    log_step "Setting file permissions..."

    # Create www-data user if not exists
    id -u www-data &>/dev/null || useradd -r -s /usr/sbin/nologin www-data

    chown -R www-data:www-data "${APP_DIR}"
    chmod 750 "${APP_DIR}"
    chmod 600 "${APP_DIR}/.env"
    chmod -R 755 "${FRONTEND_DIST}"

    # Ensure backend files are readable
    chmod -R 755 "${BACKEND_DIR}"

    log_ok "Permissions set (owner: www-data:www-data)"
}

# Setup systemd service
setup_systemd() {
    log_step "Configuring systemd service..."

    local SERVICE_SRC="${BACKEND_SERVICE_SRC}"

    if [[ ! -f "$SERVICE_SRC" ]]; then
        log_warn "backend.service file not found at ${SERVICE_SRC}"
        log_info "Creating service file from template..."

        cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<'EOF'
[Unit]
Description=Music Funnel AI Backend
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/music-funnel-ai/backend
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/opt/music-funnel-ai/.env
ExecStart=/opt/music-funnel-ai/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=music-funnel-ai

[Install]
WantedBy=multi-user.target
EOF
    else
        cp "$SERVICE_SRC" "/etc/systemd/system/${SERVICE_NAME}.service"
    fi

    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}.service"
    systemctl start "${SERVICE_NAME}.service"

    # Wait a moment and check status
    sleep 2
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        log_ok "Backend service is running"
    else
        log_warn "Backend service may not have started. Check with: systemctl status ${SERVICE_NAME}"
    fi
}

# Setup Nginx
setup_nginx() {
    log_step "Configuring Nginx..."

    # Backup default site
    if [[ -f /etc/nginx/sites-enabled/default ]]; then
        mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak.$(date +%s)
    fi

    local CONF_SRC="${NGINX_CONF_SRC}"

    if [[ ! -f "$CONF_SRC" ]]; then
        log_warn "nginx.conf not found at ${CONF_SRC}"
        log_info "Creating nginx config from template..."

        cat > /etc/nginx/sites-available/music-funnel-ai <<'NGINXCONF'
server {
    listen 80;
    server_name _;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;

    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
    }

    location / {
        root /opt/music-funnel-ai/frontend/dist;
        try_files $uri $uri/ /index.html;

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
NGINXCONF
    else
        cp "$CONF_SRC" /etc/nginx/sites-available/music-funnel-ai
    fi

    # Enable site
    ln -sf /etc/nginx/sites-available/music-funnel-ai /etc/nginx/sites-enabled/music-funnel-ai

    # Test nginx config
    nginx -t 2>&1 | sed 's/^/  /'

    # Reload nginx
    systemctl restart nginx
    systemctl enable nginx

    log_ok "Nginx configured and running"
}

# Setup UFW firewall
setup_firewall() {
    if [[ "$SKIP_FIREWALL" == true ]]; then
        log_info "Skipping firewall configuration (--skip-firewall)"
        return
    fi

    log_step "Configuring UFW firewall..."

    # Check if UFW is available
    if ! command -v ufw &>/dev/null; then
        log_warn "UFW not found, installing..."
        apt install -y ufw -qq
    fi

    # Set default policies
    ufw default deny incoming -q
    ufw default allow outgoing -q

    # Allow SSH
    ufw allow 22/tcp comment 'SSH' -q

    # Allow HTTP
    ufw allow 80/tcp comment 'HTTP' -q

    # Allow HTTPS
    ufw allow 443/tcp comment 'HTTPS' -q

    # Allow backend port (for direct access during debugging)
    ufw allow 8000/tcp comment 'Backend API (debug)' -q

    # Enable firewall (non-interactive)
    echo "y" | ufw enable -q

    log_ok "Firewall configured"
    ufw status verbose | sed 's/^/  /'
}

# Print success message
print_success() {
    local SERVER_IP
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_SERVER_IP")

    echo
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}           Installation Complete!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo
    echo -e "  ${APP_NAME} is now deployed and running!"
    echo
    echo -e "  ${CYAN}Access your application:${NC}"
    echo -e "    Frontend: ${YELLOW}http://${SERVER_IP}/${NC}"
    echo -e "    API:      ${YELLOW}http://${SERVER_IP}/api/${NC}"
    echo -e "    Backend:  ${YELLOW}http://${SERVER_IP}:8000/${NC} (direct)"
    echo
    echo -e "  ${CYAN}Server Configuration:${NC}"
    echo -e "    App Directory:  ${APP_DIR}"
    echo -e "    Config File:    ${APP_DIR}/.env"
    echo -e "    Nginx Config:   /etc/nginx/sites-available/music-funnel-ai"
    echo -e "    Service:        /etc/systemd/system/${SERVICE_NAME}.service"
    echo
    echo -e "  ${CYAN}Useful Commands:${NC}"
    echo -e "    View logs:      ${YELLOW}journalctl -u ${SERVICE_NAME} -f${NC}"
    echo -e "    Restart app:    ${YELLOW}systemctl restart ${SERVICE_NAME}${NC}"
    echo -e "    Check status:   ${YELLOW}systemctl status ${SERVICE_NAME}${NC}"
    echo -e "    Nginx test:     ${YELLOW}nginx -t${NC}"
    echo -e "    Nginx reload:   ${YELLOW}systemctl reload nginx${NC}"
    echo
    echo -e "  ${CYAN}Update the app:${NC}"
    echo -e "    ${YELLOW}./deployment/update.sh${NC}"
    echo

    if [[ "$GEMINI_API_KEY" == "your_gemini_api_key_here" ]]; then
        echo -e "  ${YELLOW}⚠️  WARNING: Gemini API key is not set!${NC}"
        echo
        echo -e "  AI mode will NOT work until you set a valid API key."
        echo
        echo -e "  To set it:"
        echo -e "    1. Get your key from: ${YELLOW}https://aistudio.google.com/app/apikey${NC}"
        echo -e "    2. Edit the config:   ${YELLOW}nano ${APP_DIR}/.env${NC}"
        echo -e "    3. Set GEMINI_API_KEY=your_actual_key"
        echo -e "    4. Restart:           ${YELLOW}systemctl restart ${SERVICE_NAME}${NC}"
        echo
    fi

    echo -e "  ${CYAN}Need SSL/HTTPS?${NC}"
    echo -e "    Run: ${YELLOW}./deployment/ssl-setup.sh your-domain.com${NC}"
    echo
    echo -e "${GREEN}============================================================${NC}"
    echo
}

# Main execution
main() {
    parse_args "$@"
    print_banner
    check_os
    check_root

    if [[ "$SKIP_PACKAGES" == false ]]; then
        update_system
        install_packages
        install_nodejs
    else
        log_info "Skipping package installation (--skip-packages)"
    fi

    prompt_gemini_key
    create_directories
    create_env_file
    setup_backend
    setup_frontend
    set_permissions
    setup_systemd
    setup_nginx
    setup_firewall
    print_success
}

# Run main
main "$@"
