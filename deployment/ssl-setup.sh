#!/bin/bash
set -euo pipefail

# Music Funnel AI - SSL Setup with Let's Encrypt
# Sets up HTTPS using Certbot and Let's Encrypt on Google VPS
# Usage: ./ssl-setup.sh <your-domain.com>

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
DOMAIN=""
EMAIL=""
SERVICE_NAME="music-funnel-ai"

# Logging helpers
log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}[STEP]${NC}  $1"; echo; }

# Print banner
print_banner() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}     ${APP_NAME} - SSL/HTTPS Setup (Let's Encrypt)${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo
}

# Print help
print_help() {
    echo "Usage: $0 <domain> [email]"
    echo
    echo "Arguments:"
    echo "  domain    Your domain name (e.g., musicfunnel.example.com)"
    echo "  email     Email address for Let's Encrypt notifications (optional)"
    echo
    echo "Examples:"
    echo "  $0 musicfunnel.example.com"
    echo "  $0 musicfunnel.example.com admin@example.com"
    echo
    echo "Prerequisites:"
    echo "  - Domain DNS A record must point to this server's IP"
    echo "  - Port 80 must be accessible from the internet"
    echo "  - install.sh must have been run first"
    echo
}

# Check for root/sudo access
check_root() {
    log_step "Checking privileges..."
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo."
        echo
        echo "  Please run:"
        echo -e "    ${YELLOW}sudo $0 $*${NC}"
        echo
        exit 1
    fi
    log_ok "Running with root privileges"
}

# Validate prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."

    # Check domain is provided
    if [[ -z "$DOMAIN" ]]; then
        log_error "No domain specified!"
        print_help
        exit 1
    fi

    # Check nginx is installed
    if ! command -v nginx &>/dev/null; then
        log_error "Nginx not found. Please run install.sh first."
        exit 1
    fi

    # Check that the site config exists
    if [[ ! -f /etc/nginx/sites-available/music-funnel-ai ]]; then
        log_error "Nginx site config not found. Please run install.sh first."
        exit 1
    fi

    # Check if certbot is installed
    if ! command -v certbot &>/dev/null; then
        log_info "Certbot not found, will install it..."
    fi

    log_ok "Prerequisites check passed"
}

# Install Certbot
install_certbot() {
    log_step "Installing Certbot..."

    if ! command -v certbot &>/dev/null; then
        apt update -qq
        apt install -y -qq certbot python3-certbot-nginx 2>&1 | grep -v "^Selecting\|^Preparing\|^Unpacking\|^Setting up\|^Processing" || true
    fi

    local CERTBOT_VERSION
    CERTBOT_VERSION=$(certbot --version 2>/dev/null || echo "unknown")
    log_ok "Certbot installed: ${CERTBOT_VERSION}"
}

# Update nginx config with domain name
update_nginx_domain() {
    log_step "Updating Nginx configuration for domain: ${DOMAIN}..."

    local NGINX_CONF="/etc/nginx/sites-available/music-funnel-ai"

    # Backup current config
    cp "$NGINX_CONF" "${NGINX_CONF}.bak.$(date +%s)"

    # Update server_name from _ to the actual domain
    sed -i "s/server_name _;/server_name ${DOMAIN};/" "$NGINX_CONF"

    # Test the config
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        log_ok "Nginx config updated and reloaded"
    else
        log_error "Nginx config test failed after domain update"
        nginx -t
        exit 1
    fi
}

# Obtain SSL certificate
obtain_certificate() {
    log_step "Obtaining SSL certificate from Let's Encrypt..."

    local CERTBOT_ARGS="--nginx --non-interactive --agree-tos --redirect"

    # Add email if provided
    if [[ -n "$EMAIL" ]]; then
        CERTBOT_ARGS="${CERTBOT_ARGS} --email ${EMAIL}"
    else
        CERTBOT_ARGS="${CERTBOT_ARGS} --register-unsafely-without-email"
    fi

    CERTBOT_ARGS="${CERTBOT_ARGS} -d ${DOMAIN}"

    log_info "Running: certbot ${CERTBOT_ARGS}"
    echo

    if certbot ${CERTBOT_ARGS}; then
        log_ok "SSL certificate obtained successfully!"
    else
        log_error "Failed to obtain SSL certificate"
        echo
        echo -e "  ${YELLOW}Common issues:${NC}"
        echo -e "    1. Domain DNS A record does not point to this server's IP"
        echo -e "    2. Port 80 is blocked by firewall"
        echo -e "    3. Domain name is incorrect"
        echo
        echo -e "  ${YELLOW}Verify DNS:${NC}"
        echo -e "    nslookup ${DOMAIN}"
        echo
        exit 1
    fi
}

# Update nginx config with SSL settings
configure_ssl_nginx() {
    log_step "Configuring Nginx with SSL..."

    local NGINX_CONF="/etc/nginx/sites-available/music-funnel-ai"

    # Certbot usually modifies the nginx config automatically.
    # This function adds any additional SSL hardening that certbot may have missed.

    # Check if certbot added the SSL configuration
    if grep -q "listen 443 ssl" "$NGINX_CONF"; then
        log_ok "SSL configuration detected in Nginx config"
    else
        log_warn "SSL configuration not found. You may need to configure it manually."
    fi

    # Reload nginx to apply all changes
    systemctl reload nginx
    log_ok "Nginx reloaded with SSL configuration"
}

# Setup auto-renewal cron job
setup_auto_renewal() {
    log_step "Setting up SSL certificate auto-renewal..."

    # Check if certbot systemd timer exists (newer systems)
    if systemctl list-timers 2>/dev/null | grep -q certbot; then
        log_info "Certbot systemd timer already active"
        systemctl status certbot.timer --no-pager 2>/dev/null | head -5
        log_ok "Auto-renewal is handled by systemd timer"
        return
    fi

    # Otherwise, set up a cron job
    if ! crontab -l 2>/dev/null | grep -q certbot; then
        (
            crontab -l 2>/dev/null || true
            echo "# Certbot auto-renewal for ${APP_NAME}"
            echo "0 3 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'"
        ) | crontab -
        log_ok "Auto-renewal cron job added (runs daily at 3:00 AM)"
    else
        log_ok "Certbot cron job already exists"
    fi
}

# Verify SSL setup
verify_ssl() {
    log_step "Verifying SSL setup..."

    echo
    echo -e "  ${CYAN}SSL Certificate Info:${NC}"
    echo -n "  "
    echo | openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -dates -subject | sed 's/^/  /' || echo -e "  ${YELLOW}Could not verify (domain may not resolve yet)${NC}"

    echo
    echo -e "  ${CYAN}Test your HTTPS setup:${NC}"
    echo -e "    ${YELLOW}curl -I https://${DOMAIN}/${NC}"
    echo
}

# Print success message
print_success() {
    local SERVER_IP
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_SERVER_IP")

    echo
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}           SSL/HTTPS Setup Complete!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo
    echo -e "  ${APP_NAME} is now accessible via HTTPS!"
    echo
    echo -e "  ${CYAN}Your secure URLs:${NC}"
    echo -e "    HTTPS:    ${GREEN}https://${DOMAIN}/${NC}"
    echo -e "    API:      ${GREEN}https://${DOMAIN}/api/${NC}"
    echo
    echo -e "  ${CYAN}SSL Certificate:${NC}"
    echo -e "    Issuer:   Let's Encrypt"
    echo -e "    Domain:   ${DOMAIN}"
    echo -e "    Auto-renew: Yes (via certbot)"
    echo
    echo -e "  ${CYAN}Certificate files:${NC}"
    echo -e "    /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
    echo -e "    /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
    echo
    echo -e "  ${CYAN}Nginx config:${NC}"
    echo -e "    /etc/nginx/sites-available/music-funnel-ai"
    echo
    echo -e "  ${CYAN}Manual renewal (if needed):${NC}"
    echo -e "    ${YELLOW}certbot renew --force-renewal${NC}"
    echo
    echo -e "  ${CYAN}Certificate expiry check:${NC}"
    echo -e "    ${YELLOW}echo | openssl s_client -connect ${DOMAIN}:443 2>/dev/null | openssl x509 -noout -dates${NC}"
    echo
    echo -e "${GREEN}============================================================${NC}"
    echo
}

# Main execution
main() {
    # Parse arguments
    DOMAIN="${1:-}"
    EMAIL="${2:-}"

    if [[ -z "$DOMAIN" || "$DOMAIN" == "--help" || "$DOMAIN" == "-h" ]]; then
        print_banner
        print_help
        exit 0
    fi

    print_banner
    check_root
    check_prerequisites
    install_certbot
    update_nginx_domain
    obtain_certificate
    configure_ssl_nginx
    setup_auto_renewal
    verify_ssl
    print_success
}

# Run main
main "$@"
