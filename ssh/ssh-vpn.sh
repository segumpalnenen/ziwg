#!/bin/bash
# ==================================================
# SSH-VPN Install Script - Fixed for Ubuntu 24.04
# Optimized for 1GB RAM / 1 CPU VPS
# ==================================================

# REPO
REPO="https://raw.githubusercontent.com/segumpalnenen/ziwg/main"

# Suppress semua dialog interaktif apt (Ubuntu 22/24)
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Disable popup "Pending kernel upgrade" dan "Daemons using outdated libraries"
if [ -f /etc/needrestart/needrestart.conf ]; then
    sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
    sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/" /etc/needrestart/needrestart.conf
fi

apt dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt install netfilter-persistent -y
apt-get remove --purge ufw firewalld -y
apt install -y screen curl jq bzip2 gzip vnstat coreutils rsyslog iftop zip unzip git apt-transport-https build-essential -y

# initializing var
MYIP=$(wget -qO- ipv4.icanhazip.com)
MYIP2="s/xxxxxxxxx/$MYIP/g"
NET=$(ip -o $ANU -4 route show to default | awk '{print $5}')
source /etc/os-release
ver=$VERSION_ID

# detail nama perusahaan
country=ID
state=Indonesia
locality=Jakarta
organization=none
organizationalunit=none
commonname=none
email=none

# simple password minimal
curl -sS ${REPO}/ssh/password | openssl aes-256-cbc -d -a -pass pass:scvps07gg -pbkdf2 > /etc/pam.d/common-password
chmod +x /etc/pam.d/common-password

# ... (omitted) ...

# ============================================================
# INSTALL BADVPN - OPTIMIZED: max-clients 50 per instance
# Total: 4 x 50 = 200 clients (cukup untuk VPS 1GB)
# ============================================================
cd
wget -O /usr/bin/badvpn-udpgw "${REPO}/ssh/newudpgw"
chmod +x /usr/bin/badvpn-udpgw

# Tulis ke rc.local dengan max-clients 50
sed -i '$ i\screen -dmS badvpn1 badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 50' /etc/rc.local
sed -i '$ i\screen -dmS badvpn2 badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 50' /etc/rc.local
sed -i '$ i\screen -dmS badvpn3 badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 50' /etc/rc.local
sed -i '$ i\screen -dmS badvpn4 badvpn-udpgw --listen-addr 127.0.0.1:7400 --max-clients 50' /etc/rc.local

# Jalankan badvpn dengan max-clients 50
screen -dmS badvpn1 badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 50
screen -dmS badvpn2 badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 50
screen -dmS badvpn3 badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 50
screen -dmS badvpn4 badvpn-udpgw --listen-addr 127.0.0.1:7400 --max-clients 50

cd
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
# Ubuntu 22/24: pastikan port 22 aktif dulu
sed -i 's/^#Port 22/Port 22/' /etc/ssh/sshd_config
# Hapus semua Port lama selain 22
sed -i '/^Port [0-9]/d' /etc/ssh/sshd_config
# Set port sesuai kebutuhan: 22 dan 9696
echo "Port 22" >> /etc/ssh/sshd_config
echo "Port 9696" >> /etc/ssh/sshd_config
systemctl restart ssh

echo "=== Install Dropbear ==="
apt -y install dropbear
cat > /etc/default/dropbear <<-DROPBEAR
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143"
DROPBEAR_BANNER=""
DROPBEAR_RECEIVE_WINDOW=65536
DROPBEAR
systemctl enable dropbear
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
systemctl restart ssh
systemctl restart dropbear

# ============================================================
# INSTALL STUNNEL4 - FIXED FOR UBUNTU 24.04
# ============================================================
cd
echo "=== Install Stunnel4 ==="
apt install stunnel4 -y

# Buat semua direktori yang dibutuhkan
mkdir -p /var/log/stunnel4
mkdir -p /etc/stunnel
mkdir -p /var/run/stunnel4

# Pastikan user stunnel4 ada (Ubuntu 24.04 kadang tidak otomatis buat)
if ! id "stunnel4" &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin stunnel4 2>/dev/null || true
fi

# Set kepemilikan direktori
chown stunnel4:stunnel4 /var/log/stunnel4 2>/dev/null || chown root:root /var/log/stunnel4
chown stunnel4:stunnel4 /var/run/stunnel4 2>/dev/null || chown root:root /var/run/stunnel4
chmod 755 /var/run/stunnel4

# Generate sertifikat SSL untuk stunnel (self-signed, 10 tahun)
cd /tmp
openssl genrsa -out /tmp/stunnel-key.pem 2048 2>/dev/null
openssl req -new -x509 \
    -key /tmp/stunnel-key.pem \
    -out /tmp/stunnel-cert.pem \
    -days 3650 \
    -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email" \
    2>/dev/null
cat /tmp/stunnel-key.pem /tmp/stunnel-cert.pem > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem
chown stunnel4:stunnel4 /etc/stunnel/stunnel.pem 2>/dev/null || true
rm -f /tmp/stunnel-key.pem /tmp/stunnel-cert.pem
cd

# Tulis konfigurasi stunnel4 - kompatibel Ubuntu 24.04
cat > /etc/stunnel/stunnel.conf <<-END
; Stunnel4 Config - Ubuntu 24.04 Compatible
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
output = /var/log/stunnel4/stunnel.log
pid = /var/run/stunnel4/stunnel4.pid

[ssh-ssl]
accept = 222
connect = 127.0.0.1:22

[dropbear-ssl]
accept = 777
connect = 127.0.0.1:109

[ws-stunnel]
accept = 2096
connect = 127.0.0.1:700
END

# Tulis /etc/default/stunnel4 dengan benar
cat > /etc/default/stunnel4 <<-STUNNEL
ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER="/etc/issue.net"
PPP_RESTART=0
OUTPUT=/var/log/stunnel4/stunnel.log
STUNNEL

# FIX systemd untuk Ubuntu 24.04:
mkdir -p /etc/systemd/system/stunnel4.service.d/
cat > /etc/systemd/system/stunnel4.service.d/override.conf <<-EOF
[Service]
RuntimeDirectory=stunnel4
RuntimeDirectoryMode=0755
ExecStartPre=/bin/mkdir -p /var/run/stunnel4
ExecStartPre=/bin/chown stunnel4:stunnel4 /var/run/stunnel4
EOF

systemctl daemon-reload
systemctl enable stunnel4
systemctl stop stunnel4 2>/dev/null; sleep 1
systemctl start stunnel4

# ============================================================
# INSTALL FAIL2BAN - OPTIMIZED: kurangi log backend & interval
# ============================================================
apt -y install fail2ban

# Override fail2ban config untuk hemat RAM & CPU
mkdir -p /etc/fail2ban
cat > /etc/fail2ban/jail.local <<-F2B
[DEFAULT]
# Hemat CPU: naikkan interval pengecekan dari 60s ke 300s
findtime  = 600
bantime   = 3600
maxretry  = 5
# Gunakan backend polling (lebih ringan dari inotify di VPS)
backend   = polling

[sshd]
enabled   = true
port      = ssh,9696,222,777
logpath   = %(sshd_log)s
maxretry  = 5
F2B

systemctl enable fail2ban
systemctl enable nginx
systemctl enable cron
systemctl enable vnstat

# ============================================================
# OPTIMASI KERNEL SYSCTL - hemat RAM & tingkatkan performa
# ============================================================
cat >> /etc/sysctl.conf <<-SYSCTL

# === OPTIMASI VPS 1GB RAM ===
# Kurangi swappiness (pakai swap hanya darurat)
vm.swappiness = 10
# Cache pressure rendah = lebih banyak cache di RAM
vm.vfs_cache_pressure = 50
# Optimasi TCP buffer
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
# BBR congestion control (kalau kernel support)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
# Hemat file descriptor
fs.file-max = 51200
SYSCTL
sysctl -p >/dev/null 2>&1

# ============================================================
# TAMBAH SWAP 512MB - buffer darurat untuk RAM 1GB
# ============================================================
if [ ! -f /swapfile ]; then
    fallocate -l 512M /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "[ ok ] Swap 512MB created"
fi

# blokir torrent
iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# install script menu dari GitHub
echo "[ INFO ] Installing management scripts from GitHub..."
scripts=(
    "menu:menu/menu.sh"
    "m-vmess:menu/m-vmess.sh"
    "m-vless:menu/m-vless.sh"
    "running:menu/running.sh"
    "clearcache:menu/clearcache.sh"
    "m-ssws:menu/m-ssws.sh"
    "m-trojan:menu/m-trojan.sh"
    "m-sshovpn:menu/m-sshovpn.sh"
    "usernew:ssh/usernew.sh"
    "trial:ssh/trial.sh"
    "renew:ssh/renew.sh"
    "hapus:ssh/hapus.sh"
    "cek:ssh/cek.sh"
    "member:ssh/member.sh"
    "delete:ssh/delete.sh"
    "autokill:ssh/autokill.sh"
    "ceklim:ssh/ceklim.sh"
    "tendang:ssh/tendang.sh"
    "m-system:menu/m-system.sh"
    "m-domain:menu/m-domain.sh"
    "add-host:ssh/add-host.sh"
    "certv2ray:xray/certv2ray.sh"
    "speedtest:ssh/speedtest_cli.py"
    "auto-reboot:menu/auto-reboot.sh"
    "restart:menu/restart.sh"
    "bw:menu/bw.sh"
    "m-tcp:menu/tcp.sh"
    "xp:ssh/xp.sh"
    "m-dns:menu/m-dns.sh"
    "fix-cek:ssh/fix-cek.sh"
    "sshws:sshws/sshws.sh"
    "m-wg:wireguard/m-wg.sh"
    "menu-zivpn:zivpn/menu-zivpn.sh"
)

for script in "${scripts[@]}"; do
    NAME="${script%%:*}"
    PATH_REMOTE="${script#*:}"
    wget -q -O "/usr/bin/${NAME}" "${REPO}/${PATH_REMOTE}"
    chmod +x "/usr/bin/${NAME}"
done

chmod +x /usr/bin/*


cat > /etc/cron.d/re_otm <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 2 * * * root /sbin/reboot
END

cat > /etc/cron.d/xp_otm <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 0 * * * root /usr/bin/xp
END

cat > /home/re_otm <<-END
7
END

systemctl restart cron >/dev/null 2>&1
systemctl reload cron >/dev/null 2>&1

echo "[ INFO ] Clearing trash"
apt autoclean -y >/dev/null 2>&1
if dpkg -s unscd >/dev/null 2>&1; then
    apt -y remove --purge unscd >/dev/null 2>&1
fi
apt-get -y --purge remove samba* >/dev/null 2>&1
apt-get -y --purge remove apache2* >/dev/null 2>&1
apt-get -y --purge remove bind9* >/dev/null 2>&1
apt-get -y remove sendmail* >/dev/null 2>&1
apt autoremove -y >/dev/null 2>&1

cd
chown -R www-data:www-data /home/vps/public_html
echo "[SERVICE] Restart All service SSH & OVPN"
systemctl restart nginx >/dev/null 2>&1; echo "[ ok ] Restarting nginx"
systemctl restart cron >/dev/null 2>&1; echo "[ ok ] Restarting cron"
systemctl restart ssh >/dev/null 2>&1; echo "[ ok ] Restarting ssh"
systemctl restart dropbear >/dev/null 2>&1; echo "[ ok ] Restarting dropbear"
systemctl restart fail2ban >/dev/null 2>&1; echo "[ ok ] Restarting fail2ban"
systemctl restart stunnel4 >/dev/null 2>&1; echo "[ ok ] Restarting stunnel4"
systemctl restart vnstat >/dev/null 2>&1; echo "[ ok ] Restarting vnstat"

# Jalankan badvpn - OPTIMIZED max-clients 50 (total 200)
screen -dmS badvpn1 badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 50
screen -dmS badvpn2 badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 50
screen -dmS badvpn3 badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 50
screen -dmS badvpn4 badvpn-udpgw --listen-addr 127.0.0.1:7400 --max-clients 50

history -c
echo "unset HISTFILE" >> /etc/profile

rm -f /root/key.pem
rm -f /root/cert.pem
rm -f /root/ssh-vpn.sh
rm -f /root/bbr.sh

clear
