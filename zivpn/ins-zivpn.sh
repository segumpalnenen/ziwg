#!/bin/bash
# =========================================
# INSTALL ZIVPN UDP (TESTING VERSION)
# =========================================

# Colors
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

# Branch Detection
REPO_BASE="https://raw.githubusercontent.com/segumpalnenen/ziwg"
BRANCH="main"
REPO="$REPO_BASE/$BRANCH"

# 1. Input Data
basedom=${1:-}
subdom=${2:-}
cf_token=${3:-}

if [[ -z "$basedom" ]]; then read -rp "Enter Base Domain (e.g., example.com): " basedom; fi
if [[ -z "$subdom" ]]; then read -rp "Enter Subdomain for ZiVPN (e.g., zi1): " subdom; fi
if [[ -z "$cf_token" ]]; then read -rp "Enter Cloudflare Token: " cf_token; fi

# 2. DNS Pointing - HANDLED BY MASTER SETUP
domain="${subdom}.${basedom}"
ZIVPN_DIR="/etc/zivpn"
ZIVPN_BIN="/usr/local/bin/zivpn"
mkdir -p "$ZIVPN_DIR"
echo "$domain" > "$ZIVPN_DIR/domain"
systemctl stop zivpn.service > /dev/null 2>&1

# 4. Download Binary
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    BINARY_URL="https://github.com/rosicenterstore/UDP-ZIVPN/releases/download/v1.0/udp-zivpn-linux-amd64"
else
    BINARY_URL="https://github.com/rosicenterstore/UDP-ZIVPN/releases/download/v1.0/udp-zivpn-linux-arm64"
fi

echo -e "[ INFO ] Downloading Zivpn binary..."
wget -O "$ZIVPN_BIN" "$BINARY_URL"
chmod +x "$ZIVPN_BIN"

# 5. Generate SSL Cert
if [[ ! -f "$ZIVPN_DIR/zivpn.crt" ]]; then
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=US/ST=CA/L=LA/O=ZIVPN/CN=zivpn" \
        -keyout "$ZIVPN_DIR/zivpn.key" -out "$ZIVPN_DIR/zivpn.crt" > /dev/null 2>&1
fi

# 6. Initial Config
if [[ ! -f "$ZIVPN_DIR/config.json" ]]; then
    cat > "$ZIVPN_DIR/config.json" <<EOF
{
  "listen": ":5667",
  "cert": "$ZIVPN_DIR/zivpn.crt",
  "key": "$ZIVPN_DIR/zivpn.key",
  "obfs": "zivpn",
  "keepalive": 20,
  "auth": {
    "mode": "passwords",
    "config": ["zivpn"]
  }
}
EOF
fi

# 7. Setup Systemd Service
cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZIVPN UDP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$ZIVPN_DIR
ExecStart=$ZIVPN_BIN server -c $ZIVPN_DIR/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

# 8. Setup Iptables
IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
if [[ -n "$IFACE" ]]; then
    iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 10000:30000 -j DNAT --to-destination :5667 2>/dev/null || true
fi

# REPO
REPO="https://raw.githubusercontent.com/segumpalnenen/ziwg/main"

# 9. Install Command Scripts FROM GITHUB
echo -e "[ INFO ] Installing command scripts from GitHub..."
commands=("add-zivpn" "del-zivpn" "cek-zivpn" "renew-zivpn" "menu-zivpn")

for cmd in "${commands[@]}"; do
    echo -e " - Downloading $cmd..."
    wget -q -O "/usr/bin/$cmd" "${REPO}/zivpn/${cmd}.sh"
    chmod +x "/usr/bin/$cmd"
done
ln -sf /usr/bin/menu-zivpn /usr/bin/zivpn

echo -e "${green}ZIVPN Installation Finished Successfully with domain: $domain${nc}"
