#!/bin/bash
#UDP
REPO="https://raw.githubusercontent.com/PeyxDev/scripttun/main"
LOCAL_DIR="${PX_PROJECT_DIR:-}/BadVPN-UDPGW"

fetch_asset() {
    # fetch_asset <local_file> <dest> <remote_url>
    local local_file="$1" dest="$2" remote="$3"
    if [[ -n "$LOCAL_DIR" && -f "$local_file" ]]; then
        cp -f "$local_file" "$dest" >/dev/null 2>&1
    else
        wget -q -O "$dest" "$remote" >/dev/null 2>&1
    fi
}

fetch_asset "${LOCAL_DIR}/badvpn" /usr/bin/badvpn "${REPO}/project/BadVPN-UDPGW/badvpn"
chmod +x /usr/bin/badvpn > /dev/null 2>&1
fetch_asset "${LOCAL_DIR}/badvpn1.service" /etc/systemd/system/badvpn1.service "${REPO}/project/BadVPN-UDPGW/badvpn1.service"
fetch_asset "${LOCAL_DIR}/badvpn2.service" /etc/systemd/system/badvpn2.service "${REPO}/project/BadVPN-UDPGW/badvpn2.service"
fetch_asset "${LOCAL_DIR}/badvpn3.service" /etc/systemd/system/badvpn3.service "${REPO}/project/BadVPN-UDPGW/badvpn3.service"
systemctl disable badvpn1 
systemctl stop badvpn1 
systemctl enable badvpn1
systemctl start badvpn1 
systemctl disable badvpn2 
systemctl stop badvpn2 
systemctl enable badvpn2
systemctl start badvpn2 
systemctl disable badvpn3 
systemctl stop badvpn3  
systemctl enable badvpn3
systemctl start badvpn3 
