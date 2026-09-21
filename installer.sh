#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export RepoURL="th3fre/testos/main"
export TOKEN="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"
SCRIPT_PATH=$(realpath "$0")
rm -rf "$SCRIPT_PATH"
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

ARCH=$(uname -m)

mkdir -p /etc/JuanScript
timedatectl set-timezone Asia/Manila
echo "0 8 * * * root /sbin/reboot" | tee -a /etc/cron.d/reboot_at_8am > /dev/null
IP_ADDRESS=$(curl -4s https://checkip.amazonaws.com)

API_ENDPOINT="https://api.cloudflare.com/client/v4/zones"
AUTH_EMAIL="mahmoud.rabiee.elsayed@gmail.com"
AUTH_KEY="2111d694773708c0e603c346ef9c97fd4d83c"
ZONE_ID="500e8d996bcfc9fe5b85142db521b3be"
DOMAIN_NAME="90netvpnnn.dpdns.org"

# Define colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
NC="\033[0m" # No Color / reset

echo ""
echo -e "${CYAN}Enter subdomain (e.g., subdomain.$DOMAIN_NAME)${NC}"
echo -e "${YELLOW}Do not include $DOMAIN_NAME, just the prefix${NC}"
echo -e "${GREEN}Example: If you want juan.$DOMAIN_NAME, just enter 'juan'${NC}"
read -p "Enter subdomain: " SUBDOMAIN
echo -e "SUBDOMAIN: $SUBDOMAIN.$DOMAIN_NAME"
echo -e "${MAGENTA}For Hysteria UDP choose your version${NC}"
echo -e "a) 1.3.5"
echo -e "b) 2.x (latest)"

while true; do
    read -rp "Choose (a/b): " choice
    case "$choice" in
        a|b)
            break
            ;;
        *)
            echo "Invalid input. Please enter only a or b."
            ;;
    esac
done
echo -e "${CYAN}Enter obfuscation string for Hysteria (optional, press Enter to skip)${NC}"
read -p "Obfuscation string: " obfs
read -p "Enter Response: " RESPONSE
echo ""


# Create a system info script
cat > /etc/profile.d/juan.sh << 'EOF' 
#!/bin/bash
clear
screenfetch -p -A $(lsb_release -si)

# Clear history and logs
set +o history && history -cw > /dev/null 2>&1
rm -rf /{var,run}/log/{journal/*,lastlog}
history -w -c
rm -f ~/.bash_history

# Count active SSH sessions
# Count authenticated SSH sessions (exclude root & unknown)
total_ssh=$(pgrep -a sshd | grep priv | grep -v root | grep -v unknown | wc -l)

if [ -f /tmp/hysteria_sessions.map ]; then
    total_hysteria=$(grep "Active clients:" /tmp/hysteria_sessions.map | tail -n1 | awk '{print $3}')
else
    total_hysteria=0
fi

# Function to check if a service is active
check_service_status() {
    if systemctl is-active --quiet "$1"; then
        echo -e "[\e[32mOn\e[0m]"
    else
        echo -e "[\e[31mOff\e[0m]"
    fi
}

# Define monitored services
services=(
    "JuanMUX.service TLS 443"
    "JuanSSH.service SSH 22"
    "JuanDNSTT.service SDNS any"
    "JuanWS.service WS 80,443"
    "openvpn-server@tcp.service OVPN-SSL 443"
    "openvpn-server@tcp.service OVPN-TCP 1194"
    "xray.service XRAY 80,443"
    "udp.service Hysteria 20k:50k"
    "badvpn.service UDP-GW 7300"
    "squid.service SQUID 8000"
)

# Print header
echo -e "---------------------------------"
echo -e "| Command : menu                |"
echo -e "---------------------------------"
printf "| OVPN: %-3s |SSH: %-3s |UDP: %-3s |\n" \
"$(awk -F',' '$1=="CLIENT_LIST" && $2!="UNDEF" {count++} END {print count+0}' /etc/openvpn/tcp_stats.log 2>/dev/null)" \
"$total_ssh" \
"${total_hysteria:-0}"
echo -e "---------------------------------"
echo -e "| Service   | Status | Ports    |"
echo -e "---------------------------------"

# Print service statuses
for service in "${services[@]}"; do
    service_name=$(echo "$service" | cut -d' ' -f1)
    service_label=$(echo "$service" | cut -d' ' -f2)
    service_ports=$(echo "$service" | cut -d' ' -f3)

    status=$(check_service_status "$service_name")
    printf "| %-9s | %-6s | %-10s |\n" "$service_label" "$status" "$service_ports"
done

# Print system details
echo -e "---------------------------------"
echo -e "| IP      : $(wget -4qO- http://ipinfo.io/ip)"
echo -e "| A       : $(cat /etc/JuanScript/domain)"
echo -e "| NS      : $(cat /etc/JuanScript/nameserver)"
echo -e "| UUID    : $(cat /etc/xray/uuid)"
echo -e "| Key     : $(cat /etc/JuanScript/server.pub | fold -w 100)"
echo -e "---------------------------------"
EOF

# Make script executable
chmod +x /etc/profile.d/juan.sh

apt update && apt upgrade -y
packages=(
    "sudo" "lsof" "iptables" "iptables-persistent" "zip" "openvpn" "screenfetch" "curl" "certbot" "dnsutils" "git" "cmake"
    "build-essential" "libssl-dev" "zlib1g-dev" "autoconf" "automake" "libtool" "m4" "libpthread-stubs0-dev" "net-tools"
    "autoconf-archive" "pkg-config" "libpam0g-dev" "libcurl4-openssl-dev" "libxml2-dev" "libnspr4-dev" "libnss3-dev"
    "liblzo2-dev" "libpkcs11-helper1-dev" "liblz4-dev" "libnl-genl-3-dev" "libcap-ng-dev" "software-properties-common"
    "dos2unix" "jq" "openvpn-dco-dkms" "squid" "git" "tcpdump" "unzip" "pamtester" "gawk"
)

for pkg in "${packages[@]}"; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        echo "$pkg is not installed. Installing..."
        apt install -y "$pkg"
    fi
done


rm -rf /etc/openvpn/*
mkdir -p /etc/openvpn/server/
mkdir -p /etc/openvpn/certificates/
mkdir -p /etc/xray
mkdir -p /etc/udp

AVAILABLE_STORAGE=$(df --output=avail / | tail -n 1)
SWAP_SIZE=$((AVAILABLE_STORAGE * 2 / 10)) 
SWAP_SIZE_MB=$((SWAP_SIZE / 1024))  
echo "Optimizing your system ${SWAP_SIZE_MB} MB..."
sudo dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE_MB status=progress
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
if ! grep -q "/swapfile" /etc/fstab; then
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

sed -i '/net.ipv4.ip_forward.*/d' /etc/sysctl.conf
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/20-openvpn.conf
sysctl --system &> /dev/null
echo 1 > /proc/sys/net/ipv4/ip_forward

# Define the A record
A_RECORD=$(cat <<EOF
{
  "type": "A",
  "name": "${SUBDOMAIN}.${DOMAIN_NAME}",
  "content": "${IP_ADDRESS}",
  "ttl": 1,
  "proxied": false
}
EOF
)

# Send POST request to Cloudflare API to add A record
A_RESPONSE=$(curl -s -X POST "${API_ENDPOINT}/${ZONE_ID}/dns_records" \
     -H "X-Auth-Email: ${AUTH_EMAIL}" \
     -H "X-Auth-Key: ${AUTH_KEY}" \
     -H "Content-Type: application/json" \
     --data "${A_RECORD}")

# Parse the A record response
A_SUCCESS=$(echo ${A_RESPONSE} | jq -r '.success')

# If the A record was successfully added, define the NS record
if [ "${A_SUCCESS}" == "true" ]; then
    # Define the NS record pointing to the A record
    NS_RECORD=$(cat <<EOF
    {
      "type": "NS",
      "name": "ns.${SUBDOMAIN}.${DOMAIN_NAME}",
      "content": "${SUBDOMAIN}.${DOMAIN_NAME}",
      "ttl": 1,
      "proxied": false
    }
EOF
    )

    # Send POST request to Cloudflare API to add NS record
    NS_RESPONSE=$(curl -s -X POST "${API_ENDPOINT}/${ZONE_ID}/dns_records" \
         -H "X-Auth-Email: ${AUTH_EMAIL}" \
         -H "X-Auth-Key: ${AUTH_KEY}" \
         -H "Content-Type: application/json" \
         --data "${NS_RECORD}")

    # Parse the NS record response
    NS_SUCCESS=$(echo ${NS_RESPONSE} | jq -r '.success')

    # If the NS record was successfully added, echo and write to files
    if [ "${NS_SUCCESS}" == "true" ]; then
        mkdir -p /etc/JuanScript
        echo "${SUBDOMAIN}.${DOMAIN_NAME}" > /etc/JuanScript/domain 
        wget https://go.dev/dl/go1.26.0.linux-amd64.tar.gz
        apt remove golang-go -y
        apt autoremove -y
        tar -C /usr/local -xzf go1.26.0.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /etc/profile
        source /etc/profile &>/dev/null
        go version &>/dev/null
        git clone https://www.bamsoftware.com/git/dnstt.git
        cd dnstt/dnstt-server
        go build
        mv dnstt-server /etc/JuanScript/dnstt-server
        chmod +x /etc/JuanScript/dnstt-server
        echo "8c85ae8f1d915369205a418e25f5284d3180e80ccfe659fa3c49eddc62246ae8" > /etc/JuanScript/server.key
        echo "1dc937f2537767e9df2ab2de1f9bbcb59d99be0f31bd73eb09aea96a876d796e" > /etc/JuanScript/server.pub
        echo "ns.${SUBDOMAIN}.${DOMAIN_NAME}" > /etc/JuanScript/nameserver
        echo "Both A and NS records successfully added."
        echo "[Unit]
Description=DNSTT Server
After=network-online.target
Wants=network-online.target

[Service]
user=root
Type=simple
WorkingDirectory=/etc/JuanScript
ExecStart=/etc/JuanScript/dnstt-server -mtu 512 -udp :5300 -privkey-file server.key ns.${SUBDOMAIN}.${DOMAIN_NAME} 127.0.0.1:22
Restart=on-failure
RestartSec=5s
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
StandardOutput=file:/etc/JuanScript/status.log

[Install]
WantedBy=multi-user.target
" > /lib/systemd/system/JuanDNSTT.service
systemctl daemon-reload
systemctl enable JuanDNSTT &>/dev/null
systemctl restart JuanDNSTT &>/dev/null
    else
        echo "${SUBDOMAIN}.${DOMAIN_NAME}" > /etc/JuanScript/domain
        echo "A record added successfully, but NS record failed."
    fi
else
    echo "Failed to add A record."
fi

curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/squid/squid" > /tmp/squid && bash /tmp/squid
cd /etc/JuanScript
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/JuanWS_${ARCH}" > JuanWS
echo "MSG=\"$RESPONSE\"" >> /etc/JuanScript/juanws.conf
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/JuanMUX_${ARCH}" > JuanMUX
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/JuanUDP_${ARCH}" > JuanUDP
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/JuanDNS" > JuanDNS
chmod +x *
cd /etc/openvpn/certificates
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/ovpn.zip" > ovpn.zip
unzip *.zip
rm -f *.zip
cd /etc/xray
bash -c "$(curl -4L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/xray/config.json" > config.json
UUID=$(xray uuid)
sed -i "s/XRAYUUID/${UUID}/g" /etc/xray/config.json
echo $UUID > /etc/xray/uuid
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/xray/add.sh" > /usr/local/bin/xray-add && chmod +x /usr/local/bin/xray-add
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/xray/xraymenu.sh" > /usr/local/bin/xray-menu && chmod +x /usr/local/bin/xray-menu
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/xray/list.sh" > /usr/local/bin/xray-list && chmod +x /usr/local/bin/xray-list
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/xray/del.sh" > /usr/local/bin/xray-del && chmod +x /usr/local/bin/xray-del
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/xray/showpath.sh" > /usr/local/bin/xray-showpath && chmod +x /usr/local/bin/xray-showpath

sudo chown -R www-data:www-data /var/log/xray
rm -rf /etc/systemd/system/xray.service.d
rm -rf /etc/systemd/system/xray@.service
cat > /etc/systemd/system/xray.service << "XRAY" 
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
XRAY
systemctl enable xray.service

if [ "$(lsb_release -is 2>/dev/null)" = "Ubuntu" ] && \
   [[ "$(lsb_release -rs 2>/dev/null)" == 25.* ]]; then
    echo "Ubuntu 25 detected"
    sudo apt install -y apparmor-utils
    sudo aa-complain openvpn
    ##sudo aa-complain wg-quick WireGuard
fi

cd /tmp
git clone https://github.com/openssh/openssh-portable.git
cd openssh-portable

cat <<EOF > version.h
#define SSH_VERSION    "${RESPONSE}_JuanScript"

#define SSH_RELEASE_MINIMUM    SSH_VERSION
#ifdef SSH_EXTRAVERSION
#define SSH_RELEASE    SSH_RELEASE_MINIMUM " "
#else
#define SSH_RELEASE    SSH_RELEASE_MINIMUM
#endif
EOF

mkdir -p /etc/JuanSSH/etc 
mkdir -p /etc/JuanSSH/var/empty
autoreconf -fi
./configure --prefix=/etc/JuanSSH --sysconfdir=/etc/JuanSSH/etc --with-privsep-path=/etc/JuanSSH/var/empty --with-pam
make -j$(nproc)
sudo make install

cat <<MySSHConfig > /etc/JuanSSH/etc/sshd_config
Port 22
ListenAddress ::
ListenAddress 0.0.0.0
Protocol 2
HostKey /etc/JuanSSH/etc/ssh_host_rsa_key
HostKey /etc/JuanSSH/etc/ssh_host_ecdsa_key
HostKey /etc/JuanSSH/etc/ssh_host_ed25519_key
SyslogFacility AUTH
LogLevel INFO
PermitRootLogin no
StrictModes yes
PubkeyAuthentication no
IgnoreRhosts yes
HostbasedAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PasswordAuthentication yes
X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PermitTunnel yes
PrintLastLog yes
AcceptEnv LANG LC_*
UsePAM yes
Banner /etc/banner
TCPKeepAlive yes
UseDNS no
KexAlgorithms +diffie-hellman-group14-sha1,diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha256,curve25519-sha256,curve25519-sha256@libssh.org
LoginGraceTime 0
ClientAliveInterval 2
ClientAliveCountMax 10
MaxStartups 50000
MySSHConfig

echo '[Unit]
Description=JuanSSH Server
Documentation=man:sshd(8) man:sshd_config(5)
After=network.target auditd.service

[Service]
Environment="PATH=/etc/JuanSSH/libexec:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EnvironmentFile=-/etc/JuanSSH/sbin/sshd
ExecStartPre=/etc/JuanSSH/sbin/sshd -t
ExecStart=/etc/JuanSSH/sbin/sshd -D $SSHD_OPTS
ExecReload=/etc/JuanSSH/sbin/sshd -t
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartPreventExitStatus=255
Type=notify
RuntimeDirectory=sshd
RuntimeDirectoryMode=0755
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/JuanSSH.service

sudo ln -s /etc/JuanSSH/libexec/sshd-auth /usr/libexec/sshd-
systemctl daemon-reload
systemctl enable JuanSSH.service

cd /tmp
git clone https://github.com/ambrop72/badvpn.git
cd badvpn
mkdir build
cd build
cmake ..
make
sudo make install
echo '[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target' > /lib/systemd/system/badvpn.service

cat <<'EOF' > /lib/systemd/system/JuanMUX.service
[Unit]
Description=JuanMUX
Documentation=https://t.me/juanscript
After=network.target

[Service]
User=root
WorkingDirectory=/etc/JuanScript
ExecStart=/etc/JuanScript/JuanMUX
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat <<'EOF' > /lib/systemd/system/JuanDNS.service
[Unit]
Description=JuanDNS
Documentation=https://t.me/juanscript
After=network.target

[Service]
User=root
WorkingDirectory=/etc/JuanScript
ExecStart=/etc/JuanScript/JuanDNS
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat <<'EOF' > /lib/systemd/system/JuanWS.service
[Unit]
Description=JuanWS
Documentation=https://t.me/juanscript
After=network.target

[Service]
User=root
WorkingDirectory=/etc/JuanScript
EnvironmentFile=-/etc/JuanScript/ws.conf
ExecStart=/etc/JuanScript/JuanWS -port "$PORT"
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat <<'TCP' > /etc/openvpn/server/tcp.conf
port 1194
proto tcp
dev tun
ca /etc/openvpn/certificates/ca.crt
cert /etc/openvpn/certificates/JuanScript.crt
key /etc/openvpn/certificates/JuanScript.key
dh none
username-as-common-name
verify-client-cert none
duplicate-cn
server 10.8.0.0 255.255.240.0
topology subnet
keepalive 5 30
tcp-nodelay
push "sndbuf 0"
push "rcvbuf 0"
sndbuf 0
rcvbuf 0
cipher AES-128-GCM
persist-key
persist-tun
mute-replay-warnings
fast-io
max-clients 4096
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
status /etc/openvpn/tcp_stats.log 3
log /etc/openvpn/tcp.log
verb 3
script-security 3
plugin /usr/lib/aarch64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so /etc/pam.d/login
TCP

plugin_file=$(find / -name openvpn-plugin-auth-pam.so 2>/dev/null | head -n 1)
if [ -z "$plugin_file" ]; then
   echo "OpenVPN error, contact juanscriptxx98@gmail.com"
    exit 1
fi
sed -i "s|^plugin.*|plugin $(printf '%q' "$plugin_file") /etc/pam.d/login|" /etc/openvpn/server/*.conf

CONFIG_FILE="/etc/udp/config.json"
DOWNLOAD_PATH="/etc/udp/hysteria"
curl -sk -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/${RepoURL}/JuanScript/udp/udp_service.sh" > udp_service.sh && bash udp_service.sh
domainName="$(cat /etc/JuanScript/domain)"
case "$choice" in
    a)
        echo "You chose Hysteria UDP 1.3.5"
         cat << UDP > /etc/udp/config.json
{
    "listen": ":36712",
    "protocol": "udp",
    "cert": "/etc/letsencrypt/live/$domainName/fullchain.pem",
    "key": "/etc/letsencrypt/live/$domainName/privkey.pem",
    "up": "1000 Mbps",
    "up_mbps": 1000,
    "down": "1000 Mbps",
    "down_mbps": 1000,
    "disable_udp": false,
    "insecure": true,
    "obfs": "$obfs",
    "auth": {
    "mode": "external",
    "config": {
    "cmd": "/etc/JuanScript/JuanUDP"
    }
  }
}
UDP
        DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/v1.3.5/hysteria-linux-amd64"
        wget --retry-connrefused --waitretry=5 --read-timeout=20 --timeout=15 -t 10 -O $DOWNLOAD_PATH $DOWNLOAD_URL
        ;;
    b)
        echo "You choose Hysteria UDP 2.x (latest)"
         LATEST_VERSION=$(curl -4 --silent "https://api.github.com/repos/apernet/hysteria/releases/latest" \
        | grep '"tag_name":' \
        | sed -E 's/.*"([^"]+)".*/\1/')
        DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${LATEST_VERSION}/hysteria-linux-amd64"
        wget --retry-connrefused --waitretry=5 --read-timeout=20 --timeout=15 -t 10 -O $DOWNLOAD_PATH $DOWNLOAD_URL
        cat << UDP > /etc/udp/config.json
{
    "listen": ":36712",
    "protocol": ["udp", "tcp"],
    "tls": {
        "cert": "/etc/letsencrypt/live/$domainName/fullchain.pem",
        "key": "/etc/letsencrypt/live/$domainName/privkey.pem",
        "sniGuard": "disable"
    },
    "bandwidth": {
        "up": "1 gbps",
        "down": "1 gbps"
    },
    "speedTest": true,
    "disableUDP": false,
    "obfs": {
        "type": "salamander",
        "salamander": {
            "password": "$obfs"
        }
    },
    "auth": {
        "type": "command",
        "command": "/etc/JuanScript/JuanUDP"
    },
    "quic": {
        "initStreamReceiveWindow": 8388608, 
        "maxStreamReceiveWindow": 8388608, 
        "initConnReceiveWindow": 20971520,  
        "maxConnReceiveWindow": 20971520,   
        "maxIdleTimeout": "30s",            
        "maxIncomingStreams": 1024,        
        "disablePathMTUDiscovery": false  
    }
}
UDP
    sed -i 's/Client/client/g' /etc/udp/udp_service.sh
        ;;
    *)
        echo "Invalid choice"
        ;;
esac


chmod +x /etc/udp/*
cat << EOF > /etc/systemd/system/udp.service
[Unit]
Description=JuanScript Simplified UDP
After=network.target

[Service]
User=root
WorkingDirectory=/etc/udp

# Run before hysteria starts
ExecStartPre=/bin/rm -f /tmp/hysteria_sessions.map
ExecStartPre=/usr/bin/tee /tmp/hysteria_sessions.map
ExecStart=/etc/udp/hysteria server --config $CONFIG_FILE

[Install]
WantedBy=multi-user.target
EOF

PNET="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
apt install iptables-persistent -yf &>/dev/null
systemctl -q enable netfilter-persistent
iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -A PREROUTING -i ${PNET} -p udp --dport 20000:50000 -j DNAT --to-destination :36712
iptables -t nat -I PREROUTING -i ${PNET} -p udp --dport 53 -j REDIRECT --to-ports 5300
iptables -A INPUT -s 0.0.0.0/0 -p tcp -m multiport --dport 1:65535 -j ACCEPT
iptables -A INPUT -s 0.0.0.0/0 -p udp -m multiport --dport 1:65535 -j ACCEPT
iptables -I FORWARD -s 10.8.0.0/16 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/16 -o ${PNET} -j MASQUERADE
iptables -I FORWARD -s 10.9.0.0/16 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.9.0.0/16 -o ${PNET} -j MASQUERADE
iptables -A INPUT -m string --algo bm --string "BitTorrent" -j REJECT
iptables -A INPUT -m string --algo bm --string "BitTorrent protocol" -j REJECT
iptables -A INPUT -m string --algo bm --string ".torrent" -j REJECT
iptables -A INPUT -m string --algo bm --string "torrent" -j REJECT
iptables -A INPUT -m string --string "BitTorrent" --algo kmp -j REJECT
iptables -A INPUT -m string --string "BitTorrent protocol" --algo kmp -j REJECT
iptables -A INPUT -m string --string "bittorrent-announce" --algo kmp -j REJECT
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j REJECT
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j REJECT
iptables -A FORWARD -m string --algo bm --string ".torrent" -j REJECT
iptables -A FORWARD -m string --algo bm --string "torrent" -j REJECT
iptables -A FORWARD -m string --string "BitTorrent" --algo kmp -j REJECT
iptables -A FORWARD -m string --string "BitTorrent protocol" --algo kmp -j REJECT
iptables -A FORWARD -m string --string "bittorrent-announce" --algo kmp -j REJECT
iptables -A OUTPUT -m string --algo bm --string "BitTorrent" -j REJECT
iptables -A OUTPUT -m string --algo bm --string "BitTorrent protocol" -j REJECT
iptables -A OUTPUT -m string --algo bm --string ".torrent" -j REJECT
iptables -A OUTPUT -m string --algo bm --string "torrent" -j REJECT
iptables -A OUTPUT -m string --string "BitTorrent" --algo kmp -j REJECT
iptables -A OUTPUT -m string --string "BitTorrent protocol" --algo kmp -j REJECT
iptables -A OUTPUT -m string --string "bittorrent-announce" --algo kmp -j REJECT
netfilter-persistent save
systemctl -q restart netfilter-persistent

systemctl daemon-reload &>/dev/null
systemctl enable JuanSSH.service &>/dev/null
systemctl enable JuanWS.service &>/dev/null
systemctl enable badvpn &>/dev/null
systemctl enable JuanMUX.service &>/dev/null
systemctl enable udp.service &>/dev/null
systemctl enable xray.service &>/dev/null
systemctl enable squid.service &>/dev/null
systemctl enable openvpn-server@tcp &>/dev/null
systemctl enable JuanDNS &>/dev/null

CONFIG="/etc/xray/config.json"
BACKUP="/etc/xray/config.json.bak.$(date +%F_%T)"

# Check jq
if ! command -v jq >/dev/null 2>&1; then
    echo "jq not found, installing..."
    apt update -y && apt install -y jq
fi

# Backup config
cp "$CONFIG" "$BACKUP"
echo "Backup created: $BACKUP"

# Modify paths
jq '
.inbounds |= map(
    if (.streamSettings?.network == "ws" and .streamSettings.wsSettings?.path) then
        .streamSettings.wsSettings.path |=
            (if endswith("_juan") then . else . + "_juan" end)
    else
        .
    end
)
' "$CONFIG" > /tmp/config.json

# Validate JSON
jq empty /tmp/config.json

# Replace config
mv /tmp/config.json "$CONFIG"

domainName="$(cat /etc/JuanScript/domain)"
# Check if the certificates exist
if [[ -f "/etc/letsencrypt/live/$domainName/fullchain.pem" && -f "/etc/letsencrypt/live/$domainName/privkey.pem" ]]; then
    echo "Certificates already exist for $domainName."
else
    echo "Certificates do not exist for $domainName. Attempting to generate them."

    # Try using certbot to generate certificates
    certbot certonly --standalone --pre-hook "echo ${domainName}" -d ${domainName} \
        --email jlhsnzfn@bugfoo.com --agree-tos --non-interactive --no-eff-email

    # Check again if the certificates were successfully generated
    if [[ -f "/etc/letsencrypt/live/$domainName/fullchain.pem" && -f "/etc/letsencrypt/live/$domainName/privkey.pem" ]]; then
        echo "Certificates successfully generated for $domainName."
    else
        echo "Certbot failed to generate certificates. Using an alternative method."

        # Alternative method to generate self-signed certificates
        mkdir -p "/etc/letsencrypt/live/$domainName"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "/etc/letsencrypt/live/$domainName/privkey.pem" \
            -out "/etc/letsencrypt/live/$domainName/fullchain.pem" \
            -subj "/CN=$domainName"

        if [[ -f "/etc/letsencrypt/live/$domainName/fullchain.pem" && -f "/etc/letsencrypt/live/$domainName/privkey.pem" ]]; then
            echo "Self-signed certificates generated for $domainName."
        else
            echo "Failed to generate certificates for $domainName. Exiting."
            exit 1
        fi
    fi
fi
cat /etc/letsencrypt/live/$domainName/fullchain.pem \
    /etc/letsencrypt/live/$domainName/privkey.pem \
    > /etc/JuanScript/juan.pem

systemctl disable ssh.socket
systemctl mask ssh.socket
apt install --reinstall coreutils

# Make script executable
cat <<'MENU' > /usr/local/bin/menu
#!/bin/bash

CRON_FILE="/etc/cron.d/reboot_at_8am"

reboot_menu() {
    while true; do
        clear
        echo "=============================="
        echo "        Reboot Settings"
        echo "=============================="
        echo "Current Timezone: $(timedatectl | grep 'Time zone' | awk '{print $3}')"
        
        if [ -f "$CRON_FILE" ]; then
            echo "Auto Reboot: ENABLED"
            echo "Schedule: $(cat $CRON_FILE | awk '{print $2 ":00"}')"
        else
            echo "Auto Reboot: DISABLED"
        fi

        echo "------------------------------"
        echo "1) Change Timezone"
        echo "2) Set Daily Auto Reboot"
        echo "3) Disable Auto Reboot"
        echo "4) Reboot Now"
        echo "5) Back to Main Menu"
        echo "=============================="
        read -p "Choose an option [1-4]: " rchoice

        case $rchoice in
            1)
                echo "Example: Asia/Manila"
                read -p "Enter timezone: " tz
                timedatectl set-timezone "$tz"
                echo "Timezone updated."
                read -p "Press Enter to continue..."
                ;;
            2)
                read -p "Enter hour (0-23): " hour
                if [[ "$hour" =~ ^[0-9]+$ ]] && [ "$hour" -ge 0 ] && [ "$hour" -le 23 ]; then
                    echo "0 $hour * * * root /sbin/reboot" > "$CRON_FILE"
                    echo "Auto reboot set at $hour:00 daily."
                else
                    echo "Invalid hour!"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                rm -f "$CRON_FILE"
                echo "Auto reboot disabled."
                read -p "Press Enter to continue..."
                ;;
            4)
                reboot
                ;;
            5)
                break
                ;;
            *)
                echo "Invalid choice!"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

while true; do
    clear
    echo "=============================="
    echo "         User Manager"
    echo "=============================="
    echo "1) Create Account"
    echo "2) Delete Account"
    echo "3) List Accounts"
    echo "4) Xray Menu"
    echo "5) Exit"
    echo "6) Reboot Settings"
    echo "=============================="
    read -p "Choose an option [1-6]: " choice

    case $choice in
        1)
            read -p "Enter username: " username
            if id "$username" &>/dev/null; then
                echo "User '$username' already exists!"
                read -p "Press Enter to continue..."
                continue
            fi
            read -p "Enter password: " password
            echo
            useradd -m -s /bin/false "$username"
            echo "$username:$password" | chpasswd
            echo "User '$username' created successfully."
            read -p "Press Enter to continue..."
            ;;
        2)
            read -p "Enter username to delete: " username
            if ! id "$username" &>/dev/null; then
                echo "User '$username' does not exist!"
                read -p "Press Enter to continue..."
                continue
            fi
            userdel -rf "$username"
            echo "User '$username' deleted successfully."
            read -p "Press Enter to continue..."
            ;;
        3)
            echo "Listing users with UID between 1000 and 3000..."
            awk -F: '$3 >= 1000 && $3 <= 3000 {print $1, "(UID:", $3, ")"}' /etc/passwd
            read -p "Press Enter to continue..."
            ;;
        4)
            clear
            /usr/local/bin/xray-menu
            exit 0
            ;;
        5)
            clear
            source /etc/profile.d/juan.sh
            exit 0
            ;;
        6)
            reboot_menu
            ;;
        *)
            echo "Invalid choice!"
            read -p "Press Enter to continue..."
            ;;
    esac
done
MENU

chmod +x /usr/local/bin/menu

chmod +x /etc/profile.d/juan.sh
sleep 10
reboot
