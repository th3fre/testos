#!/bin/bash
SCRIPT_PATH=$(realpath "$0")
rm -rf "$SCRIPT_PATH"

cat > /etc/udp/udp_service.sh << 'EOF'
#!/bin/bash

LOGFILE="/tmp/hysteria_sessions.map"

# Create file if missing and clear it on each start
: > "$LOGFILE"

journalctl -fu udp -o cat | awk '
/Client connected/ {
    connected++
    line = "\033[32m[+]\033[0m " $0 "\n\033[36mActive clients:\033[0m " connected
    print line
    system("echo \"" gensub(/\033\[[0-9;]*m/, "", "g", line) "\" >> /tmp/hysteria_sessions.map")
}
/Client disconnected/ {
    if (connected > 0) connected--
    line = "\033[31m[-]\033[0m " $0 "\n\033[36mActive clients:\033[0m " connected
    print line
    system("echo \"" gensub(/\033\[[0-9;]*m/, "", "g", line) "\" >> /tmp/hysteria_sessions.map")
}'

EOF
chmod +x /etc/udp/udp_service.sh

cat > /etc/systemd/system/hysteria-watch.service << 'EOF'
[Unit]
Description=Hysteria UDP Live Connection Counter
After=network.target

[Service]
Type=simple
ExecStart=/etc/udp/udp_service.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now hysteria-watch.service
systemctl restart hysteria-watch.service
