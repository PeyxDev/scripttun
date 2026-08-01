#!/bin/bash
# ==========================================================================
#  PX STORE - INSTALLER (REMOTE / GITHUB)
#  Script ini mengunduh folder project/ dan menu/ langsung dari repository
#  GitHub (lihat REPO_OWNER/REPO_NAME/REPO_BRANCH di bawah), lalu
#  menjalankan semua modul instalasi dari hasil unduhan tersebut.
#  Modul-modul individual (ins-xray.sh, insshws.sh, ohp.sh, ins-badvpn.sh)
#  juga sudah dipatch supaya pakai file/binary hasil unduhan lebih dulu
#  (lewat env PX_PROJECT_DIR), baru fallback download remote kalau
#  dijalankan manual/standalone di luar installer ini.
#
#  Modul yang dijalankan (urutan tetap):
#    - project/dropbear/ins-dropbear.sh
#    - project/BadVPN-UDPGW/ins-badvpn.sh
#    - project/openvpn/ins-openvpn.sh
#    - project/examples/bbr.sh          (BBR + optimasi kernel)
#    - project/Xray/ins-xray.sh         (butuh /etc/xray/domain)
#    - project/nginx/ins-nginx-redirect.sh
#    - project/api/api-px.sh
#    - project/sshws/insshws.sh
#    - project/sshws/ohp.sh
#    - project/udp/udp-custom.sh
#
#  Domain WAJIB diminta & disimpan ke /etc/xray/domain SEBELUM modul
#  apapun dijalankan, karena ins-xray.sh akan exit error jika file
#  tersebut belum ada.
#
#  Setelah semua modul jalan, installer ini juga membenahi akses SSH
#  tunnel (sshd_config, PAM, banner /etc/issue.net) supaya akun SSH
#  benar-benar bisa connect di VPS Ubuntu/Debian (root cause umum:
#  drop-in cloud-init yang mematikan password auth).
#
#  By PeyxDev
# ==========================================================================

# ==================== COLORS ====================
Green="\e[92;1m"
RED="\033[1;31m"
YELLOW="\033[33;1m"
CYAN="\033[96;1m"
WHITE="\033[97;1m"
GRAY="\033[1;30m"
NC='\e[0m'
FONT="\033[0m"
purple="\e[38;5;141m"
bold_white="\e[1;37m"
neutral="${NC}"
reset="\e[0m"

MODERN_CYAN="\033[38;2;0;255;255m"
MODERN_GREEN="\033[38;2;0;255;128m"
MODERN_RED="\033[38;2;255;50;50m"
MODERN_DIM="\033[2m"
MODERN_BOLD="\033[1m"
RESET_ALL="\033[0m"

SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
CHECK_ICON="✓"
CROSS_ICON="✗"

# ==================== PATH DASAR ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PROJECT_DIR & MENU_DIR diisi otomatis oleh download_project() setelah
# file-file diunduh satu per satu dari GitHub raw (lihat konfigurasi
# REPO_* di bawah).
PROJECT_DIR=""
MENU_DIR=""

# ==================== REPO SUMBER (GITHUB RAW) ====================
REPO_OWNER="PeyxDev"
REPO_NAME="scripttun"
REPO_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"
TOOLS_SCRIPT="${RAW_BASE}/package.sh"

# File tambahan di project/ (di luar MODULES) yang dipakai langsung oleh
# installer ini (lihat setup_ssh_access()).
EXTRA_PROJECT_FILES=(
    "examples/sshd"
    "examples/common-password"
    "examples/banner"
)

LOG_FILE="/tmp/px_install.log"

MODULES=(
    "dropbear/ins-dropbear.sh"
    "BadVPN-UDPGW/ins-badvpn.sh"
    "openvpn/ins-openvpn.sh"
    "examples/bbr.sh"
    "Xray/ins-xray.sh"
    "nginx/ins-nginx-redirect.sh"
    "api/api-px.sh"
    "sshws/insshws.sh"
    "sshws/ohp.sh"
    "udp/udp-custom.sh"
)

# ==================== UI HELPERS ====================
show_loading_animation() {
    local pid=$1 message=$2 i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${MODERN_CYAN}${SPINNER[$i]}${RESET_ALL} ${MODERN_DIM}${message}...${RESET_ALL}"
        i=$(( (i+1) % 10 ))
        sleep 0.1
    done
    printf "\r\033[K"
}

run_task() {
    local message="$1" command="$2"
    printf "${MODERN_CYAN}◐${RESET_ALL} ${MODERN_DIM}${message}...${RESET_ALL}"
    bash -c "$command" &>>"$LOG_FILE" &
    local task_pid=$!
    show_loading_animation "$task_pid" "$message"
    wait "$task_pid"
    local status=$?
    if [ $status -eq 0 ]; then
        printf "\r${MODERN_GREEN}${CHECK_ICON}${RESET_ALL} ${MODERN_BOLD}${message}${RESET_ALL} ${MODERN_GREEN}${CHECK_ICON}${RESET_ALL}\n"
    else
        printf "\r${MODERN_RED}${CROSS_ICON}${RESET_ALL} ${MODERN_BOLD}${message}${RESET_ALL} ${MODERN_RED}${CROSS_ICON}${RESET_ALL}\n"
        echo -e "${MODERN_RED}  Error log: ${LOG_FILE}${RESET_ALL}"
    fi
    return $status
}

print_section_header() {
    echo ""
    echo -e "${purple}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MODERN_BOLD}${WHITE}  $1${RESET_ALL}"
    echo -e "${purple}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() { echo -e "${MODERN_GREEN}  ${CHECK_ICON}${RESET_ALL} ${MODERN_BOLD}$1${RESET_ALL}"; }
print_error()   { echo -e "${MODERN_RED}  ${CROSS_ICON}${RESET_ALL} ${MODERN_BOLD}$1${RESET_ALL}"; }
print_info()    { echo -e "${MODERN_CYAN}  •${RESET_ALL} $1"; }
print_warning() { echo -e "\033[38;2;255;128;0m  ⚠${RESET_ALL} ${MODERN_BOLD}$1${RESET_ALL}"; }
print_fail()    { echo -e "\r${RED}✗${NC} $1"; exit 1; }

PX_Banner() {
clear
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │                    ${bold_white}WELCOME TO SCRIPT${neutral}                    ${purple}│${neutral}"
echo -e "${purple} │         ${Green}┌─┐─┐ ┬  ┌─┐┌┬┐┌─┐┬─┐┌─┐          ${purple}│${neutral}"
echo -e "${purple} │         ${Green}├─┘┌┴┬┘  └─┐ │ │ │├┬┘├┤           ${purple}│${neutral}"
echo -e "${purple} │         ${Green}┴  ┴ └─  └─┘ ┴ └─┘┴└─└─┘          ${neutral}${purple}│${neutral}"
echo -e "${purple} │        ${YELLOW}Copyright${reset} (C)${GRAY} https://t.me/PeyxDev     ${purple}│${neutral}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
}

Service_System_Operating() {
echo -e "${purple}┌────────────────────────────────────────────────┐${neutral}"
echo -e "${purple}│${WHITE} SYSTEM OS : $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/PRETTY_NAME=//g; s/"//g') ${NC}"
echo -e "${purple}│${WHITE} IP VPS    : $(curl -s ipv4.icanhazip.com) ${NC}"
echo -e "${purple}└────────────────────────────────────────────────┘${neutral}"
}

CEKIP() {
MYIP=$(curl -sS ipv4.icanhazip.com)
IPVPS=$(curl -sS "https://raw.githubusercontent.com/PeyxDev/scripttun/main/izin" | grep "$MYIP" | awk '{print $4}')
USERNAME=$(curl -sS "https://raw.githubusercontent.com/PeyxDev/scripttun/main/izin" | grep "$MYIP" | awk '{print $2}')
EXPIRED=$(curl -sS "https://raw.githubusercontent.com/PeyxDev/scripttun/main/izin" | grep "$MYIP" | awk '{print $3}')

if [[ "$MYIP" == "$IPVPS" ]]; then
  today=$(date -d "0 days" +%Y-%m-%d)
  d1=$(date -d "$EXPIRED" +%s 2>/dev/null)
  d2=$(date -d "$today" +%s)

  if [[ -z "$EXPIRED" ]]; then
    return 0
  elif [[ $d1 -lt $d2 ]]; then
    clear
    echo -e "${purple}┌───────────────────────────────────────────────┐${neutral}"
    echo -e "${purple}│${RED}              ACCOUNT EXPIRED !${FONT}"
    echo -e "${purple}└───────────────────────────────────────────────┘${neutral}"
    echo -e "  ${RED}Masa berlaku script Anda telah habis!${NC}"
    echo -e "  ${YELLOW}Silakan perpanjang ke admin${NC}"
    echo -e "  ${CYAN}Telegram : https://t.me/PeyxDev${NC}"
    exit 1
  else
    return 0
  fi
else
  clear
  echo -e "${purple}┌───────────────────────────────────────────────┐${neutral}"
  echo -e "${purple}│${RED}              PERMISSION DENIED !${FONT}"
  echo -e "${purple}└───────────────────────────────────────────────┘${neutral}"
  echo -e "  ${RED}IP Anda tidak terdaftar!${NC}"
  echo -e "  ${YELLOW}Silakan hubungi admin untuk izin akses${NC}"
  echo -e "  ${CYAN}Telegram : https://t.me/PeyxDev${NC}"
  exit 1
fi
}

download_project() {
    print_section_header "⬇️  Mengunduh Project dari Repository"

    PROJECT_DIR="/tmp/px_project"
    MENU_DIR="/tmp/px_menu"
    rm -rf "$PROJECT_DIR" "$MENU_DIR"
    mkdir -p "$PROJECT_DIR" "$MENU_DIR"

    local all_files=("${MODULES[@]}" "${EXTRA_PROJECT_FILES[@]}")
    local f dest_dir failed=0
    for f in "${all_files[@]}"; do
        dest_dir="$(dirname "${PROJECT_DIR}/${f}")"
        mkdir -p "$dest_dir"
        if ! run_task "Mengunduh project/${f}" "curl -fsSL -o '${PROJECT_DIR}/${f}' '${RAW_BASE}/project/${f}'"; then
            print_warning "Gagal mengunduh project/${f}"
            failed=1
        fi
    done

    if ! run_task "Mengunduh menu/update.sh" "curl -fsSL -o '${MENU_DIR}/update.sh' '${RAW_BASE}/menu/update.sh'"; then
        print_warning "Gagal mengunduh update.sh, instalasi menu manager mungkin dilewati"
    fi

    if ! run_task "Mengunduh tools.sh" "curl -fsSL -o '${TOOLS_SCRIPT}' '${RAW_BASE}/tools.sh'"; then
        print_warning "Gagal mengunduh tools.sh, instalasi tools mungkin dilewati"
    fi

    if [ $failed -eq 1 ]; then
        print_warning "Sebagian file project gagal diunduh, modul terkait mungkin gagal berjalan"
    else
        print_success "Semua file project berhasil diunduh ke ${PROJECT_DIR}"
    fi
}

install_tools() {
    print_section_header "🛠️  Installing Tools"

    if [ ! -f "$TOOLS_SCRIPT" ]; then
        print_error "tools.sh tidak ditemukan, instalasi tools dilewati"
        return 1
    fi

    chmod +x "$TOOLS_SCRIPT"

    print_info "Menjalankan tools.sh"
    bash "$TOOLS_SCRIPT"
    local status=$?

    if [ $status -eq 0 ]; then
        print_success "tools.sh selesai dijalankan"
    else
        print_warning "tools.sh selesai dengan kode keluar ${status}"
    fi
    return $status
}

install_module() {
    local rel="$1"
    local path="${PROJECT_DIR}/${rel}"
    local name
    name="$(basename "$rel")"

    if [[ ! -f "$path" ]]; then
        print_error "Modul tidak ditemukan: ${rel}"
        return 1
    fi

    chmod +x "$path"

    print_info "Menjalankan modul: ${name}"
    PX_PROJECT_DIR="$PROJECT_DIR" bash "$path"
    local status=$?

    if [ $status -eq 0 ]; then
        print_success "Modul ${name} selesai"
    else
        print_warning "Modul ${name} selesai dengan kode keluar ${status}"
    fi
    return $status
}

set_dns() {
    print_info "Mengatur DNS resolver ke 8.8.8.8 dan 8.8.4.4"
    chattr -i /etc/resolv.conf 2>/dev/null
    if [ -L /etc/resolv.conf ]; then
        rm -f /etc/resolv.conf
    fi
    cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    chattr +i /etc/resolv.conf 2>/dev/null
    print_success "DNS resolver diset ke 8.8.8.8 & 8.8.4.4"
}

setup_ssh_access() {
    print_section_header "🔐 Konfigurasi Akses SSH Tunnel"

    local sshd_src="${PROJECT_DIR}/examples/sshd"
    local pam_src="${PROJECT_DIR}/examples/common-password"
    local banner_src="${PROJECT_DIR}/examples/banner"

    if [[ -f "$banner_src" ]]; then
        cp -f "$banner_src" /etc/issue.net
        print_success "Banner dipasang ke /etc/issue.net"
    else
        print_warning "File banner tidak ditemukan (${banner_src}), dilewati"
    fi

    if [ -d /etc/ssh/sshd_config.d ]; then
        for f in /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf; do
            if [ -f "$f" ]; then
                rm -f "$f"
                print_info "Drop-in override dihapus: $(basename "$f")"
            fi
        done
    fi

    if [[ -f "$sshd_src" ]]; then
        local backup_file="/etc/ssh/sshd_config.bak.$(date +%s)"
        cp -f /etc/ssh/sshd_config "$backup_file" 2>/dev/null
        cp -f "$sshd_src" /etc/ssh/sshd_config
        sed -i 's#/etc/PeyxDev.txt#/etc/issue.net#' /etc/ssh/sshd_config

        if grep -q '^PasswordAuthentication' /etc/ssh/sshd_config; then
            sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        else
            echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
        fi

        if sshd -t 2>>"$LOG_FILE"; then
            print_success "sshd_config diterapkan (port 22/2222/2223, PermitRootLogin yes)"
        else
            print_error "sshd_config baru gagal validasi (sshd -t), rollback ke config lama"
            cp -f "$backup_file" /etc/ssh/sshd_config 2>/dev/null
        fi
    else
        print_warning "File sshd template tidak ditemukan (${sshd_src}), dilewati"
    fi

    if [[ -f "$pam_src" ]]; then
        cp -f "$pam_src" /etc/pam.d/common-password
        print_success "PAM common-password diterapkan"
    fi

    if [ -f /etc/default/dropbear ]; then
        if grep -q '^DROPBEAR_BANNER=' /etc/default/dropbear; then
            sed -i 's#^DROPBEAR_BANNER=.*#DROPBEAR_BANNER="/etc/issue.net"#' /etc/default/dropbear
        else
            echo 'DROPBEAR_BANNER="/etc/issue.net"' >> /etc/default/dropbear
        fi
        print_success "Dropbear banner diarahkan ke /etc/issue.net"
    fi

    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    systemctl restart dropbear 2>/dev/null

    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        print_success "Service SSH aktif & siap menerima koneksi"
    else
        print_warning "Service SSH tidak terdeteksi aktif, cek manual: systemctl status ssh"
    fi
}

install_menu() {
    print_section_header "📦 Installing Menu Manager"

    local update_script="${MENU_DIR}/update.sh"
    if [ ! -f "$update_script" ]; then
        print_error "update.sh tidak ditemukan di ${MENU_DIR}, instalasi menu dilewati"
        return 1
    fi

    chmod +x "$update_script"

    print_info "Menjalankan update.sh (download & install menu manager)"
    bash "$update_script"
    local status=$?

    if [ $status -eq 0 ]; then
        print_success "update.sh selesai dijalankan"
    else
        print_warning "update.sh selesai dengan kode keluar ${status}"
    fi

    sed -i '/# ========== AUTO MENU ==========/,/# ================================/d' /root/.bashrc 2>/dev/null
    sed -i '/# ========== AUTO MENU ==========/,/# ================================/d' /root/.profile 2>/dev/null
    sed -i '/alias menu=/d' /root/.bashrc 2>/dev/null
    rm -f /etc/profile.d/menu.sh 2>/dev/null

    cat > /etc/profile.d/menu.sh << 'EOF'
#!/bin/bash
if [ -t 0 ] && [ -f /usr/local/bin/welcome ] && [ -z "$PX_MENU_SHOWN" ]; then
    export PX_MENU_SHOWN=1
    clear
    /usr/local/bin/welcome
fi
EOF
    chmod +x /etc/profile.d/menu.sh

    echo "alias menu='bash /usr/local/bin/menu'" >> /root/.bashrc

    print_success "Menu Manager terpasang & auto-start saat login dikonfigurasi"
}

cleanup_downloads() {
    print_section_header "🧹 Membersihkan File Unduhan"
    run_task "Menghapus file project/menu/tools hasil unduhan" "rm -rf '${PROJECT_DIR}' '${MENU_DIR}' '${TOOLS_SCRIPT}'"
}

# ==================== MAIN ====================

PX_Banner
Service_System_Operating
CEKIP

if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
  print_fail "System not supported (Linux AMD64 only)"
fi

print_section_header "📦 Persiapan Sistem"
run_task "Memperbarui daftar paket" "apt-get update -y"
run_task "Memasang paket dasar" "apt-get install -y wget curl ca-certificates p7zip-full dos2unix"

download_project

print_section_header "🌐 Konfigurasi Domain"
echo ""
echo -e "${MODERN_DIM}────────────────────────────────────────────────${RESET_ALL}"
echo -ne "${MODERN_CYAN}  Masukkan Domain${RESET_ALL} ${MODERN_DIM}(contoh: vps.domainanda.com):${RESET_ALL} "
read -r domain

while [[ -z "$domain" ]]; do
  echo -e "${MODERN_RED}  Domain tidak boleh kosong!${RESET_ALL}"
  echo -ne "${MODERN_CYAN}  Masukkan Domain${RESET_ALL}: "
  read -r domain
done
echo -e "${MODERN_DIM}────────────────────────────────────────────────${RESET_ALL}"

mkdir -p /etc/xray
echo "$domain" > /etc/xray/domain
print_success "Domain diset & disimpan ke /etc/xray/domain: $domain"

print_section_header "🚀 Menjalankan Semua Modul Instalasi (lokal)"
print_info "Modul yang akan dijalankan: ${MODULES[*]}"

install_tools

FAILED_MODULES=()
for module in "${MODULES[@]}"; do
    print_section_header "📦 Modul: ${module}"
    if ! install_module "$module"; then
        FAILED_MODULES+=("$module")
    fi
    clear
    PX_Banner
done

setup_ssh_access

install_menu

cleanup_downloads

print_section_header "🌐 Konfigurasi DNS"
set_dns

clear
PX_Banner
echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${Green}              INSTALASI SELESAI!${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""
echo -e "${purple} │${CYAN}  Domain           : ${domain}${FONT}"
echo -e "${purple} │${CYAN}  DNS Resolver     : 8.8.8.8, 8.8.4.4${FONT}"
echo -e "${purple} │${CYAN}  Modul dijalankan  : ${MODULES[*]}${FONT}"

if [ ${#FAILED_MODULES[@]} -eq 0 ]; then
  echo -e "${purple} │${Green}  Status            : Semua modul berhasil${FONT}"
else
  echo -e "${purple} │${RED}  Status            : Gagal pada -> ${FAILED_MODULES[*]}${FONT}"
  echo -e "${purple} │${YELLOW}  Cek log detail    : ${LOG_FILE}${FONT}"
fi

echo -e "${purple} ────────────────────────────────────────────────${neutral}"
echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${YELLOW}  Menu Manager:${FONT}"
echo -e "${purple} │${Green}    menu${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""
echo -e "${purple} ┌───────────────────────────────────────────────┐${neutral}"
echo -e "${purple} │${GRAY}  Telegram : https://t.me/PeyxDev${FONT}"
echo -e "${purple} └───────────────────────────────────────────────┘${neutral}"
echo ""

if [ -f /usr/local/bin/welcome ]; then
    echo -e "${YELLOW}  Tekan Enter untuk melanjutkan...${NC}"
    read -r
    bash /usr/local/bin/welcome
fi