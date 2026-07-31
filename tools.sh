#!/bin/bash
#
# tools.sh — Installer dependency untuk PX STORE VPN Panel
# Semua langkah terlihat jelas, tidak ada obfuscation / eval tersembunyi.
#
# Cara pakai:
#   chmod +x tools.sh
#   sudo ./tools.sh
#
# =============================================================

set -euo pipefail

# --- Warna output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Cek harus root ---
if [[ $EUID -ne 0 ]]; then
  err "Script ini harus dijalankan sebagai root (pakai sudo)."
  exit 1
fi

# --- Cek OS ---
if [[ ! -f /etc/os-release ]]; then
  err "Tidak bisa mendeteksi OS (/etc/os-release tidak ditemukan)."
  exit 1
fi
. /etc/os-release
log "Terdeteksi OS: $PRETTY_NAME"

if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
  warn "Script ini didesain untuk Ubuntu/Debian. OS lain mungkin tidak kompatibel."
fi

# --- Disable IPv6 secara permanen ---
disable_ipv6() {
  log "Mendisable IPv6 secara permanen..."
  
  # Backup file sysctl.conf
  if [[ -f /etc/sysctl.conf ]]; then
    cp /etc/sysctl.conf /etc/sysctl.conf.bak.$(date +%Y%m%d_%H%M%S)
  fi
  
  # Tambahkan konfigurasi disable IPv6
  cat >> /etc/sysctl.conf << EOF

# Disable IPv6 - ditambahkan oleh tools.sh
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

  # Terapkan konfigurasi
  sysctl -p
  
  # Disable IPv6 pada GRUB (opsional untuk permanen total)
  if [[ -f /etc/default/grub ]]; then
    if ! grep -q "ipv6.disable=1" /etc/default/grub; then
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 /' /etc/default/grub
      sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1 /' /etc/default/grub
      update-grub
      log "IPv6 telah dinonaktifkan di GRUB. Reboot diperlukan untuk efek penuh."
    fi
  fi
  
  log "IPv6 berhasil dinonaktifkan."
}

# --- Update sistem ---
log "Update package list..."
apt-get update -y

log "Upgrade paket yang sudah terpasang..."
apt-get upgrade -y

# --- Paket dasar yang dibutuhkan panel ---
BASE_PACKAGES=(
  curl
  wget
  unzip
  tar
  jq
  git
  socat
  cron
  net-tools
  iptables
  iptables-persistent
  uuid-runtime
  bc
  screen
  htop
  build-essential
  ufw
  dos2unix
)

log "Install paket dasar: ${BASE_PACKAGES[*]}"
DEBIAN_FRONTEND=noninteractive apt-get install -y "${BASE_PACKAGES[@]}"

# --- Disable IPv6 ---
disable_ipv6

# --- Ringkasan versi ---
echo
log "=== Ringkasan versi terinstall ==="
command -v curl >/dev/null 2>&1 && echo "curl : $(curl --version | head -n1)"
command -v git  >/dev/null 2>&1 && echo "git  : $(git --version)"
command -v jq   >/dev/null 2>&1 && echo "jq   : $(jq --version)"
command -v dos2unix >/dev/null 2>&1 && echo "dos2unix : $(dos2unix --version | head -n1)"

echo
log "Instalasi dependency dasar selesai."
echo
log "Catatan: IPv6 telah dinonaktifkan. Jika Anda belum reboot, lakukan reboot sistem untuk efek penuh."