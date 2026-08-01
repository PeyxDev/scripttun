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

# --- Disable IPv6 permanen ---
disable_ipv6() {
  log "Menonaktifkan IPv6 secara permanen..."

  # 1) Nonaktifkan langsung di runtime (sysctl, efek sekarang juga)
  sysctl -w net.ipv6.conf.all.disable_ipv6=1     >/dev/null
  sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null
  sysctl -w net.ipv6.conf.lo.disable_ipv6=1      >/dev/null

  # 2) Persist lewat /etc/sysctl.d agar tetap nonaktif setelah reboot
  local SYSCTL_FILE="/etc/sysctl.d/99-disable-ipv6.conf"
  cat > "$SYSCTL_FILE" <<'EOF'
# Dibuat otomatis oleh tools.sh — nonaktifkan IPv6 permanen
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
  sysctl -p "$SYSCTL_FILE" >/dev/null

  # 3) Nonaktifkan juga lewat GRUB (biar tidak diaktifkan lagi oleh kernel/module lain)
  if [[ -f /etc/default/grub ]]; then
    if grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
      if ! grep -q "ipv6.disable=1" /etc/default/grub; then
        cp /etc/default/grub /etc/default/grub.bak.$(date +%s)
        sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 ipv6.disable=1"/' /etc/default/grub
        if command -v update-grub >/dev/null 2>&1; then
          update-grub
        elif command -v grub2-mkconfig >/dev/null 2>&1; then
          grub2-mkconfig -o /boot/grub2/grub.cfg
        fi
        warn "GRUB diupdate dengan ipv6.disable=1 — reboot diperlukan agar berlaku penuh."
      fi
    fi
  fi

  # 4) Blokir modul ipv6 agar tidak di-load ulang
  local MODPROBE_FILE="/etc/modprobe.d/disable-ipv6.conf"
  cat > "$MODPROBE_FILE" <<'EOF'
# Dibuat otomatis oleh tools.sh
alias net-pf-10 off
alias ipv6 off
EOF

  log "IPv6 dinonaktifkan (runtime + persist via sysctl.d, grub, modprobe)."
}

disable_ipv6

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

# --- Ringkasan versi ---
echo
log "=== Ringkasan versi terinstall ==="
command -v curl >/dev/null 2>&1 && echo "curl : $(curl --version | head -n1)"
command -v git  >/dev/null 2>&1 && echo "git  : $(git --version)"
command -v jq   >/dev/null 2>&1 && echo "jq   : $(jq --version)"

echo
log "Instalasi dependency dasar selesai."