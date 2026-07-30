#!/bin/bash
# Proxy For Edukasi & Imclass
# ws.py = service utama (WS proxy, Python). Binary "ws" cuma di-download
# sebagai CADANGAN di /usr/local/bin/ws-backup, tidak dipakai otomatis.
REPO="https://raw.githubusercontent.com/PeyxDev/scripttun/main"
file_path="/etc/handeling"

if [ ! -f "$file_path" ]; then
    echo -e "PXSTORE Server Connected\nGREEN" | sudo tee "$file_path" > /dev/null
    echo "File '$file_path' berhasil dibuat."
else
    if [ ! -s "$file_path" ]; then
        echo -e "PXSTORE Server Connected\nGREEN" | sudo tee "$file_path" > /dev/null
        echo "File '$file_path' kosong dan telah diisi."
    else
        echo "File '$file_path' sudah ada dan berisi data."
    fi
fi

sudo apt install -y python3

# ---- Service utama: ws.py ----
wget -O /usr/local/bin/ws.py "${REPO}/project/websocket/ws.py"
chmod +x /usr/local/bin/ws.py

cat > /etc/systemd/system/ws.service << END
[Unit]
Description=Proxy Mod By PX Store (ws.py)
Documentation=https://t.me/PeyxDev
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/ws.py 10015
Restart=on-failure
RestartSec=2
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
END

cat > /etc/systemd/system/ws-ovpn.service << END
[Unit]
Description=Proxy Mod By PeyxDev (ws.py)
Documentation=https://t.me/PeyxDev
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/ws.py 2086
Restart=on-failure
RestartSec=2
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable ws.service ws-ovpn.service
systemctl restart ws.service
systemctl restart ws-ovpn.service

# ---- Cadangan: binary ws (tidak dijalankan otomatis) ----
wget -O /usr/local/bin/ws-backup "${REPO}/project/sshws/ws"
chmod +x /usr/local/bin/ws-backup
echo "Binary cadangan tersimpan di /usr/local/bin/ws-backup (tidak aktif)."
echo "Kalau ws.py bermasalah, jalankan manual:"
echo "  systemctl stop ws && /usr/local/bin/ws-backup 10015"

sleep 1
echo "----- STATUS CHECK -----"
if ss -tlpn | grep -q ":10015 "; then
    echo "OK: ws.service (ws.py) listening di port 10015"
else
    echo "GAGAL: ws.service TIDAK listening di port 10015 — cek: journalctl -u ws -n 50"
fi
if ss -tlpn | grep -q ":2086 "; then
    echo "OK: ws-ovpn.service (ws.py) listening di port 2086"
else
    echo "GAGAL: ws-ovpn.service TIDAK listening di port 2086 — cek: journalctl -u ws-ovpn -n 50"
fi
