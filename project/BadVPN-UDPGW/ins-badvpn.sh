#!/bin/bash
#UDP
REPO="https://raw.githubusercontent.com/PeyxDev/scripttun/main"
wget -O /usr/bin/badvpn "${REPO}/project/BadVPN-UDPGW/badvpn" >/dev/null 2>&1
chmod +x /usr/bin/badvpn > /dev/null 2>&1
wget -q -O /etc/systemd/system/badvpn1.service "${REPO}/project/BadVPN-UDPGW/badvpn1.service" >/dev/null 2>&1
wget -q -O /etc/systemd/system/badvpn2.service "${REPO}/project/BadVPN-UDPGW/badvpn2.service" >/dev/null 2>&1
wget -q -O /etc/systemd/system/badvpn3.service "${REPO}/project/BadVPN-UDPGW/badvpn3.service" >/dev/null 2>&1
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
