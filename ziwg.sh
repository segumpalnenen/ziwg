#!/bin/bash
# Master Menu for ZiVPN and WireGuard (ziwg)
# =========================================

# Colors
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

while true; do
    clear
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    echo -e "           ${yellow}ZIWG - MASTER PROTOCOL MENU${nc}           "
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    echo -e " [${green}1${nc}]  WIREGUARD Management Menu"
    echo -e " [${green}2${nc}]  ZIVPN UDP Management Menu"
    echo -e " [${green}3${nc}]  Check All Services Status"
    echo -e " [${green}0${nc}]  Exit Menu"
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    read -rp " Select menu [0-3] : " opt
    
    case $opt in
        1)
            if command -v m-wg >/dev/null 2>&1; then
                m-wg
            else
                echo -e "${red}Error: WireGuard menu (m-wg) not installed!${nc}"
                sleep 2
            fi
            ;;
        2)
            if command -v menu-zivpn >/dev/null 2>&1; then
                menu-zivpn
            else
                echo -e "${red}Error: ZiVPN menu (menu-zivpn) not installed!${nc}"
                sleep 2
            fi
            ;;
        3)
            echo -e "\n${yellow}Checking Services Status...${nc}"
            echo -n "WireGuard: "
            if systemctl is-active --quiet wg-quick@wg0; then echo -e "${green}Running${nc}"; else echo -e "${red}Stopped${nc}"; fi
            echo -n "ZiVPN UDP : "
            if systemctl is-active --quiet zivpn; then echo -e "${green}Running${nc}"; else echo -e "${red}Stopped${nc}"; fi
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
        0)
            clear
            exit 0
            ;;
        *)
            echo -e "${red}Invalid option!${nc}"
            sleep 1
            ;;
    esac
done
