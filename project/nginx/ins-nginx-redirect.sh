#!/bin/bash
# ==================== NGINX REDIRECT (backend HAProxy) ====================
# Dipanggil dari setup.sh, setelah Xray/HAProxy terpasang (res5), contoh hook:
#   res_nginx_redirect() {
#   wget -q ${REPO}project/nginx/ins-nginx-redirect.sh && chmod +x ins-nginx-redirect.sh && ./ins-nginx-redirect.sh
#   clear
#   }
#
# Fungsinya cuma satu: kasih HAProxy backend nginx yang hidup (nginx_backend,
# 127.0.0.1:8081) buat nampung request browser biasa (bukan websocket, bukan
# raw SSH) yang lewat port 80/443/dst, biar gak nyasar ke dropbear_backend.

REPO="https://raw.githubusercontent.com/PeyxDev/scripttun/main/"

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

print_section_header "NGINX REDIRECT (backend HAProxy)"

# ==================== INSTALL NGINX (skip kalau sudah ada) ====================
if command -v nginx &>/dev/null; then
    print_success "Paket nginx sudah terinstall, skip install"
else
    print_info "Menginstall paket nginx..."
    export DEBIAN_FRONTEND=noninteractive
    apt install -y nginx >/dev/null 2>&1
fi

if ! command -v nginx &>/dev/null; then
    print_error "Gagal install nginx. Cek koneksi/repo APT."
    exit 1
fi
print_success "Paket nginx terinstall"

# Default site nginx suka nyangkut di 0.0.0.0:80 dan bentrok sama HAProxy,
# pastikan tetap nonaktif.
rm -f /etc/nginx/sites-enabled/default

# ==================== CEK PORT BENTROK ====================
if ss -tulpn 2>/dev/null | grep -q ":8081 "; then
    print_warning "Port 8081 sudah dipakai proses lain, cek dulu sebelum lanjut:"
    ss -tulpn | grep ":8081 "
fi

# ==================== DEPLOY VHOST REDIRECT ====================
print_info "Mengunduh & memasang vhost redirect ke /etc/nginx/conf.d/redirect.conf"

[[ -f /etc/nginx/conf.d/redirect.conf ]] && cp /etc/nginx/conf.d/redirect.conf /etc/nginx/conf.d/redirect.conf.bak-peyx
wget -q ${REPO}project/nginx/redirect.conf -O /etc/nginx/conf.d/redirect.conf

if [[ ! -s /etc/nginx/conf.d/redirect.conf ]]; then
    print_error "Gagal mengunduh redirect.conf, cek koneksi/REPO"
    [[ -f /etc/nginx/conf.d/redirect.conf.bak-peyx ]] && mv /etc/nginx/conf.d/redirect.conf.bak-peyx /etc/nginx/conf.d/redirect.conf
    exit 1
fi

# ==================== VALIDASI SEBELUM RELOAD ====================
if nginx -t >/tmp/nginx_test.err 2>&1; then
    systemctl enable nginx >/dev/null 2>&1
    systemctl restart nginx >/dev/null 2>&1
    sleep 1
    if systemctl is-active --quiet nginx; then
        print_success "Nginx aktif & listening di 127.0.0.1:8081 (nginx_backend)"
    else
        print_error "Nginx gagal restart, cek: journalctl -u nginx -e"
        exit 1
    fi
else
    print_error "Config nginx baru tidak valid, dibatalkan:"
    cat /tmp/nginx_test.err
    if [[ -f /etc/nginx/conf.d/redirect.conf.bak-peyx ]]; then
        mv /etc/nginx/conf.d/redirect.conf.bak-peyx /etc/nginx/conf.d/redirect.conf
        systemctl restart nginx >/dev/null 2>&1
    else
        rm -f /etc/nginx/conf.d/redirect.conf
    fi
    exit 1
fi

# ==================== VERIFIKASI KE HAPROXY ====================
if ss -tulpn 2>/dev/null | grep -q ":8081 "; then
    print_success "Port 8081 listening, siap dipakai HAProxy (backend nginx_backend)"
else
    print_error "Nginx aktif tapi tidak listening di 8081, cek /etc/nginx/conf.d/redirect.conf"
fi

if command -v haproxy &>/dev/null && [[ -f /etc/haproxy/haproxy.cfg ]]; then
    if grep -q "nginx_backend" /etc/haproxy/haproxy.cfg; then
        print_success "haproxy.cfg sudah selaras (ada nginx_backend), reload HAProxy..."
        if haproxy -c -f /etc/haproxy/haproxy.cfg >/tmp/haproxy_test.err 2>&1; then
            systemctl reload haproxy >/dev/null 2>&1 || systemctl restart haproxy >/dev/null 2>&1
            print_success "HAProxy reload OK"
        else
            print_error "haproxy.cfg tidak valid, HAProxy TIDAK di-reload (biar gak putus semua koneksi):"
            cat /tmp/haproxy_test.err
        fi
    else
        print_warning "haproxy.cfg belum punya nginx_backend (config lama)."
        print_warning "Jalankan ulang instalasi Xray (res5) buat ambil haproxy.cfg versi terbaru, lalu jalankan ulang step ini."
    fi
fi

print_section_header "✅ NGINX REDIRECT SIAP"
print_info "Vhost   : /etc/nginx/conf.d/redirect.conf"
print_info "Listen  : 127.0.0.1:8081 (lokal, bukan publik)"
print_info "Dipakai HAProxy sebagai nginx_backend untuk request browser biasa"
echo ""
