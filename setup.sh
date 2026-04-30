#!/bin/bash
# ============================================================
# Master Installer - Combined SSH, Xray, WG, ZiVPN
# Supported OS: Ubuntu 22.04 / 24.04
# ============================================================
export DEBIAN_FRONTEND=noninteractive
clear

# Colors
red='\e[1;31m'; green='\e[0;32m'; yell='\e[1;33m'; blue='\e[1;34m'; NC='\e[0m'

# Root Check
if [[ "${EUID}" -ne 0 ]]; then
    echo "You need to run this script as root"
    exit 1
fi

# REPO URL
REPO="https://raw.githubusercontent.com/segumpalnenen/ziwg/main"

cleanup_residue() {
    echo -e "[ ${blue}INFO${NC} ] Cleaning up old residue & conflicts..."
    
    # List of services to stop & disable
    services=("xray" "nginx" "zivpn" "wg-quick@wg0" "stunnel4" "ws-dropbear" "ws-stunnel" "fail2ban" "runn")
    for svc in "${services[@]}"; do
        systemctl stop "$svc" >/dev/null 2>&1 || true
        systemctl disable "$svc" >/dev/null 2>&1 || true
    done

    # Remove Configurations & Data
    echo -e " - Removing configuration folders..."
    rm -rf /etc/xray /etc/v2ray /etc/wireguard /etc/zivpn /etc/stunnel /etc/fail2ban /var/lib/wireguard
    rm -f /etc/nginx/conf.d/xray.conf
    rm -f /var/lib/ipvps.conf
    rm -f /root/domain /root/scdomain /root/log-install.txt

    # Remove Binaries & Management Scripts
    echo -e " - Removing old binaries and scripts..."
    rm -f /usr/local/bin/xray /usr/local/bin/zivpn /usr/local/bin/ws-dropbear /usr/local/bin/ws-stunnel
    
    scripts=("menu" "m-vmess" "m-vless" "running" "clearcache" "m-ssws" "m-trojan" "m-sshovpn" "usernew" "trial" "renew" "hapus" "cek" "member" "delete" "autokill" "ceklim" "tendang" "sshws" "m-system" "m-domain" "add-host" "certv2ray" "speedtest" "auto-reboot" "restart" "bw" "m-tcp" "xp" "m-dns" "fix-cek" "m-wg" "wg-add" "wg-del" "wg-renew" "wg-show" "menu-zivpn" "add-zivpn" "del-zivpn" "cek-zivpn" "renew-zivpn")
    for script in "${scripts[@]}"; do
        rm -f "/usr/bin/$script"
    done

    # Purge WireGuard if exists
    if command -v wg &>/dev/null; then
        apt purge -y wireguard qrencode >/dev/null 2>&1 || true
    fi

    echo -e "[ ${green}OK${NC} ] Cleanup completed."
}

# Run Cleanup before asking for data
cleanup_residue

# Dependency check
echo -e "[ ${blue}INFO${NC} ] Installing dependencies..."
apt update -y && apt install jq curl wget socat git -y >/dev/null 2>&1

# Collect Data
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "          MASTER INSTALLER (MULTI-PROTOCOL)        "
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "Enter Base Domain (e.g., example.com): " basedom
read -rp "Enter Cloudflare Token: " cf_token
echo -e "---------------------------------------------------"
read -rp "Subdomain for SSH (default: ssh): " sub_ssh
read -rp "Subdomain for VMess (default: vmess): " sub_vmess
read -rp "Subdomain for VLess (default: vless): " sub_vless
read -rp "Subdomain for Trojan (default: trojan): " sub_trojan
read -rp "Subdomain for Shadowsocks (default: ss): " sub_ss
read -rp "Subdomain for WireGuard (default: wg): " sub_wg
read -rp "Subdomain for ZiVPN (default: zi): " sub_zi

# Defaults
sub_ssh=${sub_ssh:-ssh}; sub_vmess=${sub_vmess:-vmess}; sub_vless=${sub_vless:-vless}
sub_trojan=${sub_trojan:-trojan}; sub_ss=${sub_ss:-ss}; sub_wg=${sub_wg:-wg}; sub_zi=${sub_zi:-zi}

echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Prepare Domain Files
mkdir -p /etc/xray /etc/wireguard /etc/zivpn
echo "$basedom" > /etc/xray/domain
echo "${sub_ssh}.${basedom}" > /etc/xray/domain_ssh
echo "${sub_vmess}.${basedom}" > /etc/xray/domain_vmess
echo "${sub_vless}.${basedom}" > /etc/xray/domain_vless
echo "${sub_trojan}.${basedom}" > /etc/xray/domain_trojan
echo "${sub_ss}.${basedom}" > /etc/xray/domain_ss
echo "${sub_wg}.${basedom}" > /etc/wireguard/domain
echo "${sub_zi}.${basedom}" > /etc/zivpn/domain

# DNS Pointing Logic (Adapted from pointing.sh)
IP=$(curl -sS ifconfig.me)
ZONE_ID=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones?name=$basedom&status=active" \
     -H "Authorization: Bearer $cf_token" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ -z "$ZONE_ID" || "$ZONE_ID" == "null" ]]; then
    echo -e "${red}Error: Could not find Zone ID for $basedom. Check your token.${NC}"
    exit 1
fi

point_dns() {
    local SUB=$1; local DOM="${SUB}.${basedom}"
    echo -e "[ ${green}INFO${NC} ] Pointing $DOM to $IP..."
    local RECORD_ID=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${DOM}&type=A" \
        -H "Authorization: Bearer ${cf_token}" \
        -H "Content-Type: application/json" | jq -r '.result[0].id // empty')
    local DATA="{\"type\":\"A\",\"name\":\"${DOM}\",\"content\":\"${IP}\",\"ttl\":120,\"proxied\":false}"
    if [[ -z "$RECORD_ID" ]]; then
        curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" -H "Authorization: Bearer ${cf_token}" -H "Content-Type: application/json" --data "$DATA" > /dev/null
    else
        curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" -H "Authorization: Bearer ${cf_token}" -H "Content-Type: application/json" --data "$DATA" > /dev/null
    fi
}

# Point Base and all subdomains
point_dns "@" # Optional, if you want base domain pointed too
point_dns "$sub_ssh"
point_dns "$sub_vmess"
point_dns "$sub_vless"
point_dns "$sub_trojan"
point_dns "$sub_ss"
point_dns "$sub_wg"
point_dns "$sub_zi"

# Issue Wildcard SSL Certificate
echo -e "[ ${green}INFO${NC} ] Issuing Wildcard SSL Certificate via Cloudflare DNS API..."
curl https://get.acme.sh | sh -s email=admin@${basedom}
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
export CF_Token="$cf_token"
/root/.acme.sh/acme.sh --issue --dns dns_cf -d "$basedom" -d "*.$basedom"
~/.acme.sh/acme.sh --installcert -d "$basedom" --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc

# Start Installation of Modules from GitHub
echo -e "[ ${green}INFO${NC} ] Installing SSH & VPN Base..."
wget -q -O ssh-vpn.sh "${REPO}/ssh/ssh-vpn.sh" && chmod +x ssh-vpn.sh && bash ssh-vpn.sh

echo -e "[ ${green}INFO${NC} ] Installing SSH Websocket..."
wget -q -O insshws.sh "${REPO}/sshws/insshws.sh" && chmod +x insshws.sh && bash insshws.sh

echo -e "[ ${green}INFO${NC} ] Installing XRAY Core..."
wget -q -O ins-xray.sh "${REPO}/xray/ins-xray.sh" && chmod +x ins-xray.sh && bash ins-xray.sh

echo -e "[ ${green}INFO${NC} ] Installing WireGuard..."
wget -q -O wg.sh "${REPO}/wireguard/wg.sh" && chmod +x wg.sh && bash wg.sh "$basedom" "$sub_wg" "$cf_token"

echo -e "[ ${green}INFO${NC} ] Installing ZiVPN..."
wget -q -O ins-zivpn.sh "${REPO}/zivpn/ins-zivpn.sh" && chmod +x ins-zivpn.sh && bash ins-zivpn.sh "$basedom" "$sub_zi" "$cf_token"

# Cleanup temporary install scripts
rm -f ssh-vpn.sh insshws.sh ins-xray.sh wg.sh ins-zivpn.sh

# Generate log-install.txt
echo "   >>> Service & Port"  | tee -a log-install.txt
echo "   - OpenSSH                  : 22, 9696"  | tee -a log-install.txt
echo "   - SSH Websocket            : 80 (via Nginx -> ws-dropbear:2095)" | tee -a log-install.txt
echo "   - SSH SSL Websocket        : 443" | tee -a log-install.txt
echo "   - Stunnel4                 : 222, 777" | tee -a log-install.txt
echo "   - Dropbear                 : 109, 143" | tee -a log-install.txt
echo "   - Badvpn                   : 7100-7400" | tee -a log-install.txt
echo "   - Nginx                    : 81" | tee -a log-install.txt
echo "   - Vmess WS TLS             : 443" | tee -a log-install.txt
echo "   - Vless WS TLS             : 443" | tee -a log-install.txt
echo "   - Trojan WS TLS            : 443" | tee -a log-install.txt
echo "   - Shadowsocks WS TLS       : 443" | tee -a log-install.txt
echo "   - Vmess WS none TLS        : 80" | tee -a log-install.txt
echo "   - Vless WS none TLS        : 80" | tee -a log-install.txt
echo "   - Trojan WS none TLS       : 80" | tee -a log-install.txt
echo "   - Shadowsocks WS none TLS  : 80" | tee -a log-install.txt
echo "   - Vmess gRPC               : 443" | tee -a log-install.txt
echo "   - Vless gRPC               : 443" | tee -a log-install.txt
echo "   - Trojan gRPC              : 443" | tee -a log-install.txt
echo "   - Shadowsocks gRPC         : 443" | tee -a log-install.txt
echo "   - WireGuard                : 51820" | tee -a log-install.txt
echo "   - ZiVPN UDP                : 5667 (Range 10000-30000)" | tee -a log-install.txt
echo "" | tee -a log-install.txt
cp log-install.txt /root/log-install.txt

# Cleanup & Finalize
rm -f /root/setup.sh
echo "IP=$basedom" > /var/lib/ipvps.conf

cat > /root/.profile << END
if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
tty -s && mesg n || true
clear
menu
END
chmod 644 /root/.profile

echo -e "${green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "         INSTALLATION COMPLETED SUCCESSFULLY       "
echo -e "${green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " SSH Domain    : ${sub_ssh}.${basedom}"
echo -e " Vmess Domain  : ${sub_vmess}.${basedom}"
echo -e " Vless Domain  : ${sub_vless}.${basedom}"
echo -e " Trojan Domain : ${sub_trojan}.${basedom}"
echo -e " SS Domain     : ${sub_ss}.${basedom}"
echo -e " WG Domain     : ${sub_wg}.${basedom}"
echo -e " ZiVPN Domain  : ${sub_zi}.${basedom}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " Rebooting in 5 seconds..."
sleep 5
reboot
