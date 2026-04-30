#!/bin/bash
MYIP=$(wget -qO- ipv4.icanhazip.com);
echo "Checking VPS"
clear
cekray=`cat /root/log-install.txt | grep -ow "XRAY" | sort | uniq`
clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
read -rp "Domain/Host: " -e host
echo ""
if [ -z $host ]; then
echo "????"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -n 1 -s -r -p "Press any key to back on menu"
menu
else
echo "IP=$host" > /var/lib/ipvps.conf
echo "$host" > /etc/xray/domain
echo "$host" > /etc/xray/domain_ssh
echo "$host" > /etc/xray/domain_vmess
echo "$host" > /etc/xray/domain_vless
echo "$host" > /etc/xray/domain_trojan
echo "$host" > /etc/xray/domain_ss
echo "$host" > /etc/wireguard/domain
echo "$host" > /etc/zivpn/domain
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "Dont forget to renew cert"
echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
fi
