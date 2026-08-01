#!/bin/bash
# ==================== INSTALL OPENVPN (TCP + UDP) ====================
# Dipanggil dari setup.sh, contoh hook di Installasi():
#   res12() {
#   wget -q ${REPO}project/openvpn/ins-openvpn.sh && chmod +x ins-openvpn.sh && ./ins-openvpn.sh
#   clear
#   }
#   ...
#   print_section_header "INSTALL OPENVPN"
#   res12

REPO="https://raw.githubusercontent.com/PeyxDev/scripttun/main/"

# ==================== WARNA (sinkron dengan setup.sh) ====================
MODERN_CYAN="\033[38;2;0;255;255m"
MODERN_PURPLE="\033[38;2;156;0;255m"
MODERN_GREEN="\033[38;2;0;255;128m"
MODERN_RED="\033[38;2;255;50;50m"
MODERN_ORANGE="\033[38;2;255;128;0m"
MODERN_BOLD="\033[1m"
RESET_ALL="\033[0m"
WHITE="\033[97;1m"

CHECK_ICON="✓"
CROSS_ICON="✗"

# ==================== FUNGSI PRINT (sinkron dengan setup.sh) ====================
print_section_header() {
    local title="$1"
    echo ""
    echo -e "${MODERN_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_ALL}"
    echo -e "${MODERN_BOLD}${WHITE}  ${title}${RESET_ALL}"
    echo -e "${MODERN_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_ALL}"
}

print_success() {
    echo -e "${MODERN_GREEN}  ${CHECK_ICON}${RESET_ALL} ${MODERN_BOLD}$1${RESET_ALL}"
}

print_error() {
    echo -e "${MODERN_RED}  ${CROSS_ICON}${RESET_ALL} ${MODERN_BOLD}$1${RESET_ALL}"
}

print_info() {
    echo -e "${MODERN_CYAN}  •${RESET_ALL} $1"
}

# ==================== CEK ROOT ====================
if [ "${EUID}" -ne 0 ]; then
    print_error "Script ini harus dijalankan sebagai root"
    exit 1
fi

# ==================== INSTALL DEPENDENSI ====================
print_section_header "INSTALL OPENVPN"
print_info "Menginstall paket openvpn, unzip, iptables-persistent..."

export DEBIAN_FRONTEND=noninteractive
apt install -y openvpn unzip iptables-persistent >/dev/null 2>&1

if ! command -v openvpn &>/dev/null; then
    print_error "Gagal install paket openvpn. Cek koneksi/repo APT."
    exit 1
fi
print_success "Paket openvpn terinstall"

# ==================== DOWNLOAD & EXTRACT openvpn.zip ====================
print_info "Mengunduh openvpn.zip..."
cd /root || exit 1
wget -q ${REPO}project/openvpn/openvpn.zip -O openvpn.zip

if [[ ! -s openvpn.zip ]]; then
    print_error "Gagal mengunduh openvpn.zip dari repo"
    exit 1
fi

mkdir -p /etc/openvpn/server
mkdir -p /etc/openvpn/client
unzip -oq openvpn.zip -d /etc/openvpn/server
rm -f openvpn.zip
print_success "openvpn.zip berhasil diekstrak ke /etc/openvpn/server"

# Bersihkan file log/ipp bawaan zip biar fresh
rm -f /etc/openvpn/server/log-tcp.log /etc/openvpn/server/log-udp.log
rm -f /etc/openvpn/server/server-tcp.log /etc/openvpn/server/server-udp.log
: > /etc/openvpn/server/ipp.txt

# ==================== IP FORWARDING ====================
if ! grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
else
    sed -i "s/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/" /etc/sysctl.conf
fi
sysctl -p >/dev/null 2>&1
print_success "IP forwarding diaktifkan"

# ==================== DETEKSI INTERFACE UTAMA ====================
NIC=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
[[ -z "$NIC" ]] && NIC="eth0"
print_info "Interface terdeteksi: ${NIC}"

# ==================== SETUP NAT/IPTABLES ====================
cat > /etc/openvpn/server/openvpn-iptables.sh << EOF
#!/bin/bash
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ${NIC} -j MASQUERADE
iptables -t nat -A POSTROUTING -s 20.8.0.0/24 -o ${NIC} -j MASQUERADE
iptables -I INPUT -p udp --dport 2200 -j ACCEPT
iptables -I INPUT -p tcp --dport 1194 -j ACCEPT
iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
iptables -I FORWARD -d 10.8.0.0/24 -j ACCEPT
iptables -I FORWARD -s 20.8.0.0/24 -j ACCEPT
iptables -I FORWARD -d 20.8.0.0/24 -j ACCEPT
EOF
chmod +x /etc/openvpn/server/openvpn-iptables.sh
bash /etc/openvpn/server/openvpn-iptables.sh

cat > /etc/systemd/system/openvpn-iptables.service << EOF
[Unit]
Description=iptables rules for OpenVPN NAT
After=network.target

[Service]
Type=oneshot
ExecStart=/etc/openvpn/server/openvpn-iptables.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload >/dev/null 2>&1
systemctl enable openvpn-iptables.service >/dev/null 2>&1
print_success "Rule NAT/iptables dipasang & di-persist lewat systemd"

# ==================== JALANKAN SERVICE OPENVPN ====================
systemctl daemon-reload >/dev/null 2>&1
systemctl enable openvpn-server@server-tcp >/dev/null 2>&1
systemctl enable openvpn-server@server-udp >/dev/null 2>&1
systemctl restart openvpn-server@server-tcp >/dev/null 2>&1
systemctl restart openvpn-server@server-udp >/dev/null 2>&1

sleep 2

if systemctl is-active --quiet openvpn-server@server-tcp; then
    print_success "OpenVPN TCP (port 1194) berjalan"
else
    print_error "OpenVPN TCP gagal start, cek: journalctl -u openvpn-server@server-tcp -e"
fi

if systemctl is-active --quiet openvpn-server@server-udp; then
    print_success "OpenVPN UDP (port 2200) berjalan"
else
    print_error "OpenVPN UDP gagal start, cek: journalctl -u openvpn-server@server-udp -e"
fi

print_section_header "✅ OPENVPN INSTALLED"
print_info "OpenVPN TCP : port 1194"
print_info "OpenVPN UDP : port 2200"
print_info "Auth        : Username/Password sistem (PAM login), tanpa client cert"
echo ""

# ==================== INSTALL SQUID PROXY ====================
print_section_header "INSTALL SQUID PROXY"
print_info "Menginstall paket squid..."

apt install -y squid >/dev/null 2>&1

if ! command -v squid &>/dev/null; then
    print_error "Gagal install paket squid. Cek koneksi/repo APT."
else
    print_success "Paket squid terinstall"

    # Backup config asli (sekali saja)
    if [[ ! -f /etc/squid/squid.conf.bak ]]; then
        cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
    fi

    # Tulis ulang squid.conf dengan port custom
    cat > /etc/squid/squid.conf << EOF
acl SSH_ports port 22
acl CONNECT method CONNECT

http_access allow all
http_port 3128
http_port 8080
http_port 8888

visible_hostname squid-proxy
dns_nameservers 8.8.8.8 8.8.4.4
forwarded_for off
via off
request_header_access X-Forwarded-For deny all
request_header_access Via deny all
request_header_access Cache-Control deny all

cache deny all
access_log none
cache_store_log none
EOF

    # Buka port squid di iptables & tambahkan ke script persist
    cat >> /etc/openvpn/server/openvpn-iptables.sh << EOF
iptables -I INPUT -p tcp --dport 3128 -j ACCEPT
iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
iptables -I INPUT -p tcp --dport 8888 -j ACCEPT
EOF
    bash /etc/openvpn/server/openvpn-iptables.sh >/dev/null 2>&1

    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable squid >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1

    sleep 2

    if systemctl is-active --quiet squid; then
        print_success "Squid proxy berjalan"
    else
        print_error "Squid gagal start, cek: journalctl -u squid -e"
    fi

    print_section_header "✅ SQUID PROXY INSTALLED"
    print_info "Squid Proxy : port 3128, 8080, 8888"
fi
echo ""