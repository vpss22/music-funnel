#!/bin/bash
set -euo pipefail

# Music Funnel AI - Uninstall Script
# Removes the application, service, and configuration from the VPS
# Usage: ./uninstall.sh [--purge]

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
SERVICE_NAME="music-funnel-ai"
PURGE=false
FORCE=false

# Logging helpers
log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}[STEP]${NC}  $1"; echo; }

# Print banner
print_banner() {
    echo -e "${YELLOW}============================================================${NC}"
    echo -e "${YELLOW}           ${APP_NAME} - Uninstaller${NC}"
    echo -e "${YELLOW}============================================================${NC}"
    echo
    echo -e "  ${RED}WARNING: This will remove:${NC}"
    echo -e "    - The systemd service (${SERVICE_NAME})"
    echo -e "    - The application directory (${APP_DIR})"
    echo -e "    - Nginx configuration"
    echo -e "    - Environment variables"
    echo
    if [[ "$PURGE" == true ]]; then
        echo -e "  ${RED}PURGE MODE: Will also attempt to remove installed packages${NC}"
    fi
    echo -e "${YELLOW}============================================================${NC}"
    echo
}

# Print help
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --purge      Also remove installed packages (nginx, nodejs, certbot)"
    echo "  --force, -f  Skip confirmation prompt"
    echo "  --help, -h   Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Interactive uninstall"
    echo "  $0 --force            # Uninstall without confirmation"
    echo "  $0 --force --purge    # Complete removal including packages"
    echo
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --purge)
                PURGE=true
                shift
                ;;
            --force|-f)
                FORCE=true
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

# Confirm uninstall
confirm_uninstall() {
    if [[ "$FORCE" == true ]]; then
        return
    fi

    echo -n "  Are you sure you want to uninstall ${APP_NAME}? [y/N]: "
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo
        log_info "Uninstall cancelled."
        exit 0
    fi
    echo
}

# Stop and disable systemd service
remove_service() {
    log_step "Removing systemd service..."

    if systemctl list-unit-files | grep -q "${SERVICE_NAME}.service"; then
        systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
        systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        systemctl daemon-reload
        log_ok "Systemd service removed"
    else
        log_warn "Service ${SERVICE_NAME} not found"
    fi
}

# Remove Nginx configuration
remove_nginx() {
    log_step "Removing Nginx configuration..."

    # Remove site config
    rm -f /etc/nginx/sites-available/music-funnel-ai
    rm -f /etc/nginx/sites-enabled/music-funnel-ai

    # Restore default site if backup exists
    if [[ -f /etc/nginx/sites-enabled/default.bak.* ]]; then
        LATEST_BACKUP=$(ls -t /etc/nginx/sites-enabled/default.bak.* 2>/dev/null | head -1)
        if [[ -n "$LATEST_BACKUP" ]]; then
            mv "$LATEST_BACKUP" /etc/nginx/sites-enabled/default
            log_info "Restored default Nginx site"
        fi
    fi

    # Test and reload nginx
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        log_ok "Nginx configuration removed and reloaded"
    else
        log_warn "Nginx config test failed after removal. Manual check needed."
    fi
}

# Remove application directory
remove_app_dir() {
    log_step "Removing application directory..."

    if [[ -d "$APP_DIR" ]]; then
        # Create a backup of .env before removal (just in case)
        if [[ -f "${APP_DIR}/.env" ]]; then
            cp "${APP_DIR}/.env" "/tmp/music-funnel-ai.env.backup.$(date +%s)" 2>/dev/null || true
        fi
        rm -rf "$APP_DIR"
        log_ok "Application directory removed: ${APP_DIR}"
    else
        log_warn "Application directory not found: ${APP_DIR}"
    fi
}

# Remove log files
remove_logs() {
    log_step "Cleaning up log files..."

    # Remove application-specific log directory
    if [[ -d "${APP_DIR}/logs" ]]; then
        rm -rf "${APP_DIR}/logs"
    fi

    # Truncate systemd journal entries for this service
    if command -v journalctl &>/dev/null; then
        journalctl --rotate --vacuum-time=1s -u "${SERVICE_NAME}" 2>/dev/null || true
    fi

    log_ok "Log files cleaned up"
}

# Remove firewall rules
remove_firewall_rules() {
    log_step "Removing firewall rules..."

    if command -v ufw &>/dev/null; then
        ufw delete allow 8000/tcp comment 'Backend API (debug)' 2>/dev/null || true
        log_info "Removed UFW rule for port 8000"
    fi

    log_ok "Firewall rules cleaned up"
}

# Purge installed packages
purge_packages() {
    if [[ "$PURGE" == false ]]; then
        return
    fi

    log_step "Purging installed packages..."

    echo
    echo -e "  ${YELLOW}The following packages were installed by the installer:${NC}"
    echo -e "    - nginx"
    echo -e "    - nodejs (from NodeSource)"
    echo -e "    - certbot (if SSL was set up)"
    echo -e "    - python3-venv"
    echo -e "    - ufw"
    echo
    echo -e "  ${RED}WARNING: Removing these may affect other services on this server!${NC}"
    echo

    if [[ "$FORCE" == false ]]; then
        echo -n "  Continue with package removal? [y/N]: "
        read -r PURGE_CONFIRM
        if [[ ! "$PURGE_CONFIRM" =~ ^[Yy]$ ]]; then
            log_info "Package removal skipped."
            return
        fi
    fi

    # Stop services first
    systemctl stop nginx 2>/dev/null || true
    systemctl disable nginx 2>/dev/null || true

    # Remove packages
    apt remove --purge -y nginx nginx-common 2>/dev/null || true
    apt remove --purge -y nodejs 2>/dev/null || true
    apt remove --purge -y certbot python3-certbot-nginx 2>/dev/null || true

    # Remove NodeSource repository
    rm -f /etc/apt/sources.list.d/nodesource.list
    rm -f /etc/apt/keyrings/nodesource.gpg

    # Auto-remove unused dependencies
    apt autoremove -y 2>/dev/null || true
    apt autoclean -y 2>/dev/null || true

    log_ok "Packages purged"
}

# Print completion message
print_complete() {
    echo
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}           Uninstall Complete${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo
    echo -e "  ${APP_NAME} has been removed from your server."
    echo
    echo -e "  ${CYAN}What was removed:${NC}"
    echo -e "    - Systemd service: ${SERVICE_NAME}"
    echo -e "    - Application directory: ${APP_DIR}"
    echo -e "    - Nginx configuration"
    echo -e "    - Firewall rules"
    echo

    if [[ "$PURGE" == true ]]; then
        echo -e "  ${CYAN}Packages purged:${NC}"
        echo -e "    - nginx"
        echo -e "    - nodejs"
        echo -e "    - certbot (if installed)"
        echo
    fi

    echo -e "  ${YELLOW}Note:${NC} Your .env file was backed up to /tmp/ before removal"
    echo -e "        (if it existed)."
    echo
    echo -e "${GREEN}============================================================${NC}"
    echo
}

# Main execution
main() {
    parse_args "$@"
    print_banner
    check_root
    confirm_uninstall
    remove_service
    remove_nginx
    remove_app_dir
    remove_logs
    remove_firewall_rules
    purge_packages
    print_complete
}

# Run main
main "$@"
