#!/bin/bash
set -euo pipefail

# === CONFIGURATION ===
readonly WG_PORT=51820
readonly WG_NETWORK="10.66.66.1/24"
readonly REPO="https://raw.githubusercontent.com/segumpalnenen/ziwg/main"

# === COLORS ===
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# === LOGGING ===
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# === ROOT CHECK ===
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root!"
   exit 1
fi

# === INPUT DATA ===
basedom=${1:-}
subdom=${2:-}
cf_token=${3:-}

if [[ -z "$basedom" ]]; then read -rp "Enter Base Domain (e.g., example.com): " basedom; fi
if [[ -z "$subdom" ]]; then read -rp "Enter Subdomain for WireGuard (e.g., wg1): " subdom; fi
if [[ -z "$cf_token" ]]; then read -rp "Enter Cloudflare Token: " cf_token; fi

# === DNS POINTING ===
if [[ -f "./pointing.sh" ]]; then
    bash ./pointing.sh "$subdom" "$basedom" "$cf_token"
else
    log_error "pointing.sh not found! This script should be run via install.sh"
    exit 1
fi

domain="${subdom}.${basedom}"
mkdir -p /etc/wireguard
echo "$domain" > /etc/wireguard/domain

# === INSTALL DEPENDENCIES ===
log_info "Updating packages and installing dependencies..."
apt update -qq
apt install -y wget qrencode wireguard iproute2 iptables >/dev/null 2>&1

# === DETECT INTERFACE ===
interface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)

# === CREATE CONFIG DIRECTORY ===
mkdir -p /etc/wireguard
mkdir -p /etc/wireguard/clients
chmod 700 /etc/wireguard

# === GENERATE SERVER KEYS ===
log_info "Generating WireGuard keys..."
umask 077
privkey=$(wg genkey)
pubkey=$(echo "$privkey" | wg pubkey)
echo "$privkey" > /etc/wireguard/private.key
echo "$pubkey" > /etc/wireguard/public.key

# === CREATE WIREGUARD CONFIG ===
log_info "Creating WireGuard configuration..."
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $WG_NETWORK
ListenPort = $WG_PORT
PrivateKey = $privkey
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; \
           iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE; iptables-save > /etc/iptables/rules.v4
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; \
           iptables -t nat -D POSTROUTING -o $interface -j MASQUERADE; iptables-save > /etc/iptables/rules.v4
SaveConfig = true
EOF

chmod 600 /etc/wireguard/wg0.conf

# === ENABLE IP FORWARDING ===
log_info "Configuring system networking..."
cat > /etc/sysctl.d/30-wireguard.conf <<EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
sysctl --system >/dev/null 2>&1

# === ENABLE SERVICE ===
systemctl daemon-reload
systemctl enable wg-quick@wg0.service >/dev/null 2>&1
systemctl restart wg-quick@wg0.service

# === DOWNLOAD MANAGEMENT SCRIPTS FROM GITHUB (ALWAYS GITHUB) ===
log_info "Downloading management scripts from GitHub..."
scripts=("m-wg" "wg-add" "wg-del" "wg-renew" "wg-show")

for script in "${scripts[@]}"; do
    if wget -q -O "/usr/bin/$script" "$REPO/wireguard/${script}.sh"; then
        chmod +x "/usr/bin/$script"
        log_info "Installed: /usr/bin/$script"
    else
        echo -e "${YELLOW}[WARN]${NC} Failed to download $script"
    fi
done

log_info "WireGuard Setup Completed with domain: $domain"
