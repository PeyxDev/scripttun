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
)

log "Install paket dasar: ${BASE_PACKAGES[*]}"
DEBIAN_FRONTEND=noninteractive apt-get install -y "${BASE_PACKAGES[@]}"

# --- Ringkasan versi ---
echo
log "=== Ringkasan versi terinstall ==="
command -v curl >/dev/null 2>&1 && echo "curl : $(curl --version | head -n1)"
command -v git  >/dev/null 2>&1 && echo "git  : $(git --version)"
command -v jq   >/dev/null 2>&1 && echo "jq   : $(jq --version)"

echo
log "Instalasi dependency dasar selesai."