#!/bin/sh

# ============================================================
# KEENETIC HOSTS AUTOMATION v2.0
# Automatic hosts → dnsmasq updater
# Integration with nfqws-keenetic by Anonym-tsk
# ============================================================

set -e

VERSION="2.0"
INSTALL_DIR="/opt/etc"
LOG_FILE="/opt/var/log/install-hosts.log"
GITHUB_RAW="https://raw.githubusercontent.com/ldeprive3-spec/keenetic-hosts-automation/main"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    clear
    echo "${CYAN}============================================================${NC}"
    echo "${CYAN}  KEENETIC HOSTS AUTOMATION v${VERSION}${NC}"
    echo "${CYAN}  Integration with nfqws-keenetic${NC}"
    echo "${CYAN}============================================================${NC}"
    echo ""
}

print_step() {
    echo "${YELLOW}[STEP $1/$2]${NC} $3"
}

print_success() {
    echo "  ${GREEN}✓${NC} $1"
}

print_error() {
    echo "  ${RED}✗${NC} $1"
}

print_info() {
    echo "  ${CYAN}ℹ${NC} $1"
}

# ============================================================
# STEP 1: Pre-flight checks
# ============================================================

print_header
print_step "1" "7" "Pre-flight checks"

log_msg "============================================================"
log_msg "Installation started"
log_msg "============================================================"

# Check Entware
if ! command -v opkg >/dev/null 2>&1; then
    print_error "Entware not found!"
    echo ""
    echo "Please install Entware first:"
    echo "  https://help.keenetic.com/hc/ru/articles/360021888880"
    exit 1
fi

print_success "Entware found"

# Check nfqws-keenetic
if opkg list-installed | grep -q "nfqws-keenetic"; then
    NFQWS_VERSION=$(opkg list-installed | grep "nfqws-keenetic" | awk '{print $3}')
    print_success "nfqws-keenetic installed ($NFQWS_VERSION)"
    NFQWS_INSTALLED=1
else
    print_info "nfqws-keenetic not found"
    NFQWS_INSTALLED=0
fi

# Check free space
FREE_SPACE=$(df /opt | tail -1 | awk '{print $4}')
if [ "$FREE_SPACE" -lt 10000 ]; then
    print_error "Insufficient space (need 10MB, available: $((FREE_SPACE/1024))MB)"
    exit 1
fi

print_success "Free space: $((FREE_SPACE/1024))MB"

# Check internet
if ! wget -q --spider google.com 2>/dev/null; then
    print_error "No internet connection"
    exit 1
fi

print_success "Internet connection OK"
echo ""

# ============================================================
# STEP 2: Install/Check nfqws-keenetic
# ============================================================

print_step "2" "7" "nfqws-keenetic installation"

if [ $NFQWS_INSTALLED -eq 0 ]; then
    echo ""
    echo "${YELLOW}nfqws-keenetic not found. Install it now? (recommended)${NC}"
    echo ""
    echo "  This will install:"
    echo "    - nfqws (DPI bypass for YouTube, Discord, etc.)"
    echo "    - nfqws-keenetic-web (Web interface at http://192.168.1.1:90)"
    echo ""
    printf "  Install? [Y/n]: "
    read -r INSTALL_NFQWS

    if [ -z "$INSTALL_NFQWS" ] || [ "$INSTALL_NFQWS" = "y" ] || [ "$INSTALL_NFQWS" = "Y" ]; then
        # Add repository
        print_info "Adding nfqws-keenetic repository..."
        mkdir -p /opt/etc/opkg
        echo "src/gz nfqws-keenetic https://anonym-tsk.github.io/nfqws-keenetic/all" > /opt/etc/opkg/nfqws-keenetic.conf

        # Update and install
        print_info "Installing nfqws-keenetic..."
        opkg update >/dev/null 2>&1
        opkg install nfqws-keenetic nfqws-keenetic-web >/dev/null 2>&1

        if opkg list-installed | grep -q "nfqws-keenetic"; then
            print_success "nfqws-keenetic installed"
            ROUTER_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
            print_info "Web interface: http://${ROUTER_IP}:90"
            NFQWS_INSTALLED=1
        else
            print_error "Failed to install nfqws-keenetic"
            echo ""
            echo "You can install it manually later:"
            echo "  https://github.com/Anonym-tsk/nfqws-keenetic"
            NFQWS_INSTALLED=0
        fi
    else
        print_info "Skipping nfqws-keenetic installation"
        print_info "You can install it later from:"
        print_info "  https://github.com/Anonym-tsk/nfqws-keenetic"
    fi
else
    print_success "Using existing nfqws-keenetic installation"
    print_info "Update: opkg update && opkg upgrade nfqws-keenetic"
fi

echo ""

# ============================================================
# STEP 3: Update package list
# ============================================================

print_step "3" "7" "Updating packages"

opkg update >/dev/null 2>&1
print_success "Package list updated"
echo ""

# ============================================================
# STEP 4: Install dependencies
# ============================================================

print_step "4" "7" "Installing dependencies"

PACKAGES="wget curl dnsmasq"

for pkg in $PACKAGES; do
    if ! opkg list-installed | grep -q "^$pkg "; then
        print_info "Installing $pkg..."
        opkg install $pkg >/dev/null 2>&1 && print_success "$pkg installed" || print_error "Failed to install $pkg"
    else
        print_success "$pkg already installed"
    fi
done

echo ""

# ============================================================
# STEP 5: Download scripts
# ============================================================

print_step "5" "7" "Downloading scripts"

mkdir -p "$INSTALL_DIR"
mkdir -p /opt/var/log
mkdir -p /opt/etc/dnsmasq.d
mkdir -p /opt/etc/dnsmasq.d/backups
mkdir -p /opt/etc/hosts-automation

# Download main script
print_info "Downloading update-hosts-auto.sh..."
if wget -q -O "$INSTALL_DIR/update-hosts-auto.sh" "$GITHUB_RAW/scripts/update-hosts-auto.sh" 2>/dev/null; then
    chmod +x "$INSTALL_DIR/update-hosts-auto.sh"
    print_success "update-hosts-auto.sh downloaded"
else
    print_error "Failed to download script"
fi

# Download config
print_info "Downloading sources.list..."
if wget -q -O /opt/etc/hosts-automation/sources.list "$GITHUB_RAW/config/sources.list" 2>/dev/null; then
    print_success "sources.list downloaded"
else
    # Create default sources.list
    cat > /opt/etc/hosts-automation/sources.list << 'SOURCES'
https://raw.githubusercontent.com/Internet-Helper/GeoHideDNS/refs/heads/main/hosts/hosts|GeoHide DNS
https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/hosts|Zapret Discord
SOURCES
    print_success "sources.list created (default)"
fi

print_success "Scripts downloaded"
echo ""

# ============================================================
# STEP 6: Initial hosts update
# ============================================================

print_step "6" "7" "Downloading hosts lists"

if [ -f "$INSTALL_DIR/update-hosts-auto.sh" ]; then
    print_info "Running initial hosts update (this may take a minute)..."
    $INSTALL_DIR/update-hosts-auto.sh >/dev/null 2>&1

    ENTRIES=$(grep -c "^address=" /opt/etc/dnsmasq.d/custom.conf 2>/dev/null || echo 0)
    print_success "Hosts updated: $ENTRIES entries"
else
    print_error "Update script not found"
fi

# Restart dnsmasq
print_info "Restarting dnsmasq..."
if [ -f /opt/etc/init.d/S56dnsmasq ]; then
    /opt/etc/init.d/S56dnsmasq restart >/dev/null 2>&1
    print_success "dnsmasq restarted"
elif [ -f /opt/etc/init.d/S05dnsmasq ]; then
    /opt/etc/init.d/S05dnsmasq restart >/dev/null 2>&1
    print_success "dnsmasq restarted"
fi

echo ""

# ============================================================
# STEP 7: Setup auto-update
# ============================================================

print_step "7" "7" "Setting up auto-update"

# Create cron job
cat > /opt/etc/cron.d/update-hosts << 'CRON'
# Update hosts daily at 3:00 AM
0 3 * * * root /opt/etc/update-hosts-auto.sh >> /opt/var/log/hosts-updater.log 2>&1
CRON

# Restart cron
if [ -f /opt/etc/init.d/S10cron ]; then
    /opt/etc/init.d/S10cron restart >/dev/null 2>&1
fi

print_success "Auto-update configured (daily at 3:00 AM)"
echo ""

# Create uninstaller
print_info "Creating uninstaller..."

cat > "$INSTALL_DIR/uninstall-hosts-automation.sh" << 'UNINSTALL'
#!/bin/sh
echo "============================================================"
echo "  Uninstalling Keenetic Hosts Automation..."
echo "============================================================"
echo ""

# Remove scripts
echo "[1/5] Removing scripts..."
rm -f /opt/etc/update-hosts-auto.sh
echo "  ✓ Scripts removed"

# Remove configs
echo ""
echo "[2/5] Removing configs..."
rm -rf /opt/etc/hosts-automation
rm -f /opt/etc/dnsmasq.d/custom.conf
rm -rf /opt/etc/dnsmasq.d/backups
rm -f /opt/etc/cron.d/update-hosts
echo "  ✓ Configs removed"

# Remove logs
echo ""
echo "[3/5] Removing logs..."
rm -f /opt/var/log/hosts-updater.log
rm -f /opt/var/log/hosts-stats.txt
echo "  ✓ Logs removed"

# Restart services
echo ""
echo "[4/5] Restarting services..."
if [ -f /opt/etc/init.d/S56dnsmasq ]; then
    /opt/etc/init.d/S56dnsmasq restart 2>/dev/null
elif [ -f /opt/etc/init.d/S05dnsmasq ]; then
    /opt/etc/init.d/S05dnsmasq restart 2>/dev/null
fi
if [ -f /opt/etc/init.d/S10cron ]; then
    /opt/etc/init.d/S10cron restart 2>/dev/null
fi
echo "  ✓ Services restarted"

# Remove self
echo ""
echo "[5/5] Removing uninstaller..."
rm -f /opt/etc/uninstall-hosts-automation.sh

echo ""
echo "============================================================"
echo "  Uninstallation complete!"
echo "============================================================"
echo ""
echo "Note: nfqws-keenetic was NOT removed"
echo "To remove it: opkg remove --autoremove nfqws-keenetic"
echo ""
UNINSTALL

chmod +x "$INSTALL_DIR/uninstall-hosts-automation.sh"
print_success "Uninstaller created"
echo ""

# ============================================================
# FINAL: Summary
# ============================================================

ROUTER_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
[ -z "$ROUTER_IP" ] && ROUTER_IP="192.168.1.1"

echo "${GREEN}============================================================${NC}"
echo "${GREEN}  INSTALLATION COMPLETED!${NC}"
echo "${GREEN}============================================================${NC}"
echo ""
echo "${CYAN}Installed components:${NC}"
if [ $NFQWS_INSTALLED -eq 1 ]; then
    echo "  ✓ nfqws-keenetic (DPI bypass)"
fi
echo "  ✓ dnsmasq (DNS with hosts)"
echo "  ✓ Auto-update (daily 3:00 AM)"
echo ""
echo "${CYAN}Statistics:${NC}"
cat /opt/var/log/hosts-stats.txt 2>/dev/null | sed 's/^/  /' || echo "  No stats yet"
echo ""

if [ $NFQWS_INSTALLED -eq 1 ]; then
    echo "${CYAN}Web interfaces:${NC}"
    echo "  nfqws: http://${ROUTER_IP}:90"
    echo ""
fi

echo "${CYAN}Management:${NC}"
echo "  Update hosts:   /opt/etc/update-hosts-auto.sh"
echo "  View logs:      tail -f /opt/var/log/hosts-updater.log"
echo "  View stats:     cat /opt/var/log/hosts-stats.txt"
echo "  Uninstall:      /opt/etc/uninstall-hosts-automation.sh"
echo ""

if [ $NFQWS_INSTALLED -eq 1 ]; then
    echo "${CYAN}nfqws-keenetic:${NC}"
    echo "  Web:            http://${ROUTER_IP}:90"
    echo "  Config:         /opt/etc/nfqws/nfqws.conf"
    echo "  Restart:        /opt/etc/init.d/S51nfqws restart"
    echo "  User list:      /opt/etc/nfqws/user.list"
    echo ""
fi

echo "${CYAN}Next steps:${NC}"
if [ $NFQWS_INSTALLED -eq 1 ]; then
    echo "  1. Configure nfqws: http://${ROUTER_IP}:90"
else
    echo "  1. Install nfqws-keenetic (optional):"
    echo "     https://github.com/Anonym-tsk/nfqws-keenetic"
fi
echo "  2. Test DNS: nslookup youtube.com 127.0.0.1"
echo "  3. Test bypass: curl -I https://youtube.com (on PC)"
echo ""

log_msg "Installation completed successfully"

exit 0
