#!/bin/bash
# ==================== INSTALL DROPBEAR ====================
# Dipanggil dari setup.sh, contoh hook di Installasi():
#   res3() {
#   wget -q ${REPO}project/dropbear/dropbear.sh && chmod +x dropbear.sh && bash dropbear.sh
#   clear
#   }
#
# Bisa juga dijalankan manual dengan port custom:
#   bash dropbear.sh 58080

REPO="https://raw.githubusercontent.com/PeyxDev/scripttun/main/"
DROPBEAR_PORT="${1:-58080}"

# ==================== WARNA (sinkron dengan script lain) ====================
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

# ==================== FUNGSI PRINT ====================
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

print_warning() {
    echo -e "${MODERN_ORANGE}  ⚠${RESET_ALL} ${MODERN_BOLD}$1${RESET_ALL}"
}

# ==================== CEK ROOT ====================
if [ "${EUID}" -ne 0 ]; then
    print_error "Script ini harus dijalankan sebagai root"
    exit 1
fi

print_section_header "INSTALL DROPBEAR"

# ==================== CEK PORT BENTROK ====================
if ss -tulpn 2>/dev/null | grep -q ":${DROPBEAR_PORT} "; then
    print_warning "Port ${DROPBEAR_PORT} sudah dipakai proses lain, cek dulu sebelum lanjut:"
    ss -tulpn | grep ":${DROPBEAR_PORT} "
fi

# ==================== INSTALL PAKET ====================
export DEBIAN_FRONTEND=noninteractive

if command -v dropbear &>/dev/null; then
    print_success "Paket dropbear sudah terinstall, skip install"
else
    print_info "Menginstall paket dropbear..."
    apt install -y dropbear >/dev/null 2>&1
fi

if ! command -v dropbear &>/dev/null; then
    print_error "Gagal install dropbear. Cek koneksi/repo APT."
    exit 1
fi
print_success "Paket dropbear terinstall"

# Matikan dropbear-initramfs prompt kalau ada (biar apt gak nyangkut nanya²)
systemctl stop dropbear >/dev/null 2>&1

# ==================== KONFIGURASI /etc/default/dropbear ====================
print_info "Konfigurasi /etc/default/dropbear (ports 109, 143, 442, ${DROPBEAR_PORT})"

DEFAULTCFG="/etc/default/dropbear"
touch "$DEFAULTCFG"

set_default() {
    local key="$1" val="$2"
    if grep -q "^${key}=" "$DEFAULTCFG"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$DEFAULTCFG"
    else
        echo "${key}=${val}" >> "$DEFAULTCFG"
    fi
}

set_default "DROPBEAR_PORT" "143"
set_default "DROPBEAR_RECEIVE_WINDOW" "65536"
set_default "DROPBEAR_EXTRA_ARGS" "\"-p 109 -p 442 -p 58080\""
set_default "NO_START" "0"

print_success "Konfigurasi port & opsi dropbear disimpan"

# ==================== GENERATE HOST KEY ====================
print_info "Menyiapkan host key dropbear..."
mkdir -p /etc/dropbear

[[ -f /etc/dropbear/dropbear_rsa_host_key ]] || dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
[[ -f /etc/dropbear/dropbear_ecdsa_host_key ]] || dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key >/dev/null 2>&1
[[ -f /etc/dropbear/dropbear_ed25519_host_key ]] || dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key >/dev/null 2>&1

# dropbear_dss_host_key sengaja TIDAK dibuat (DSS sudah deprecated/insecure
# dan dropbear versi baru cuma warning-skip kalau gak ada, bukan fatal)

if [[ -f /etc/dropbear/dropbear_rsa_host_key && -f /etc/dropbear/dropbear_ed25519_host_key ]]; then
    print_success "Host key RSA/ECDSA/ED25519 siap"
else
    print_error "Gagal generate host key dropbear"
    exit 1
fi

# ==================== SYSTEMD OVERRIDE (anti race + anti rate-limit) ====================
print_info "Memasang systemd override (network-online + restart delay)"

mkdir -p /etc/systemd/system/dropbear.service.d
cat > /etc/systemd/system/dropbear.service.d/override.conf << EOF
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
Restart=on-failure
RestartSec=2
EOF

systemctl daemon-reload >/dev/null 2>&1
print_success "Override systemd terpasang"

# ==================== ENABLE & START ====================
systemctl unmask dropbear >/dev/null 2>&1
systemctl enable dropbear >/dev/null 2>&1
systemctl reset-failed dropbear >/dev/null 2>&1
systemctl restart dropbear >/dev/null 2>&1

sleep 1

# ==================== VERIFIKASI ====================
print_section_header "📊 STATUS CHECK"

if systemctl is-active --quiet dropbear; then
    print_success "Dropbear service aktif"
else
    print_error "Dropbear gagal start, cek: journalctl -u dropbear -e"
    systemctl status dropbear --no-pager
    exit 1
fi

if ss -tulpn 2>/dev/null | grep -q ":${DROPBEAR_PORT} "; then
    print_success "Dropbear listening di port ${DROPBEAR_PORT}"
else
    print_error "Dropbear aktif tapi tidak listening di port ${DROPBEAR_PORT}, cek konfigurasi"
    exit 1
fi

print_section_header "✅ DROPBEAR INSTALLED"
print_info "Port     : ${DROPBEAR_PORT}"
print_info "Config   : /etc/default/dropbear"
print_info "Host key : /etc/dropbear/"
print_info "Kalau dipakai di belakang HAProxy, pastikan backend-nya:"
print_info "  server dropbear_server 127.0.0.1:${DROPBEAR_PORT} check inter 3000 rise 2 fall 3"
echo ""
