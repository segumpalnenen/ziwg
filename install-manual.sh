#!/bin/bash
# Master Installer for ZiVPN and WireGuard
# REPO: github.com/segumpalnenen/ziwg

# Colors
green='\e[0;32m'; red='\e[1;31m'; nc='\e[0m'

# Configuration
REPO="https://raw.githubusercontent.com/segumpalnenen/ziwg/main"

# Root check
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root!"
   exit 1
fi

# Dependency check
if ! command -v jq >/dev/null 2>&1; then
    apt update && apt install -y jq >/dev/null 2>&1
fi

clear
echo -e "${green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
echo -e "       ZIWG REMOTE INSTALLER (GITHUB REPO)        "
echo -e "${green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"

# 1. Ask Data
read -rp "Enter Base Domain (e.g., example.com): " basedom
read -rp "Enter Cloudflare Token: " cf_token
echo -e "---------------------------------------------------"
read -rp "Enter Subdomain for WireGuard (e.g., wg): " wg_sub
read -rp "Enter Subdomain for ZiVPN (e.g., zi): " zi_sub
echo -e "${green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"

# 2. Download Pointing Script (Temporary)
echo -e ">>> Fetching DNS Pointing tools..."
wget -q -O pointing.sh "$REPO/pointing.sh"
chmod +x pointing.sh

# 3. Install WireGuard
echo -e ">>> Installing WireGuard..."
wget -q -O wg.sh "$REPO/wireguard/wg.sh"
chmod +x wg.sh
bash wg.sh "$basedom" "$wg_sub" "$cf_token"
rm -f wg.sh

echo -e "---------------------------------------------------"

# 4. Install ZiVPN
echo -e ">>> Installing ZiVPN..."
wget -q -O ins-zivpn.sh "$REPO/zivpn/ins-zivpn.sh"
chmod +x ins-zivpn.sh
bash ins-zivpn.sh "$basedom" "$zi_sub" "$cf_token"
rm -f ins-zivpn.sh

# 5. Install Master Menu
echo -e ">>> Installing Master Menu 'ziwg'..."
wget -q -O /usr/bin/ziwg "$REPO/ziwg.sh"
chmod +x /usr/bin/ziwg

# Cleanup
rm -f pointing.sh

echo -e "---------------------------------------------------"
echo -e "${green}Installation finished successfully!${nc}"
echo -e "Type ${green}'ziwg'${nc} to manage your services."
