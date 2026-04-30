#!/bin/bash
MYIP=$(wget -qO- ipv4.icanhazip.com);
echo "Checking VPS"
clear

if [[ -n "$1" ]]; then
    user="$1"
else
    NUMBER_OF_CLIENTS=$(grep -c -E "^#& " "/etc/xray/config.json")
    if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
        echo "You have no existing clients!"
        exit 1
    fi
    grep -E "^#& " "/etc/xray/config.json" | cut -d ' ' -f 2 | sort | uniq
    read -rp "Input Username : " user
fi

if [[ -n "$user" ]]; then
    # 1. Remove from config.json (all blocks: WS and gRPC)
    sed -i "/#& $user /,/^},{/d" /etc/xray/config.json
    
    # 2. Remove from log file
    if [ -f /etc/log-create-vless.log ]; then
        sed -i "/Remarks        : $user/,/Expired On     :/d" /etc/log-create-vless.log
        sed -i "/^━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$/d" /etc/log-create-vless.log
        sed -i '/^$/d' /etc/log-create-vless.log
    fi
    
    systemctl restart xray > /dev/null 2>&1
    echo "Account $user deleted."
fi
