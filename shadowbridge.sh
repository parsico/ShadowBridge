#!/bin/bash

# ---------------- INSTALL DEPENDENCIES ----------------
echo "[*] Installing prerequisites (iproute2, net-tools, grep, awk, jq, curl)..."
sudo apt update -y >/dev/null 2>&1
sudo apt install -y iproute2 net-tools grep awk sudo iputils-ping jq curl haproxy >/dev/null 2>&1
sudo apt-get install -y jq
sudo apt install -y haproxy

# ---------------- COLORS ----------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ---------------- FUNCTIONS ----------------

check_core_status() {
    ip link show | grep -q 'vxlan' && echo "Active" || echo "Inactive"
}

ShadowBridge_menu() {
    clear
    SERVER_IP=$(hostname -I | awk '{print $1}')
    SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')
    SERVER_ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp')

    echo "+-----------------------------------------------------------------------------+"
    echo "███████╗██╗  ██╗ █████╗ ██████╗  ██████╗ ██╗    ██╗██████╗ ██████╗ ██╗██████╗  ██████╗ ███████╗"
    echo "██╔════╝██║  ██║██╔══██╗██╔══██╗██╔═══██╗██║    ██║██╔══██╗██╔══██╗██║██╔══██╗██╔════╝ ██╔════╝"
    echo "███████╗███████║███████║██║  ██║██║   ██║██║ █╗ ██║██████╔╝██████╔╝██║██║  ██║██║  ███╗█████╗  "
    echo "╚════██║██╔══██║██╔══██║██║  ██║██║   ██║██║███╗██║██╔══██╗██╔══██╗██║██║  ██║██║   ██║██╔══╝  "
    echo "███████║██║  ██║██║  ██║██████╔╝╚██████╔╝╚███╔███╔╝██████╔╝██║  ██║██║██████╔╝╚██████╔╝███████╗"
    echo "╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚══════╝"
    echo "+-----------------------------------------------------------------------------+"
    echo -e "| Telegram Channel : ${MAGENTA}@PARSDADE ${NC}| Project : ${GREEN}ShadowBridge v1.0${NC} "
    echo "+-----------------------------------------------------------------------------+"      
    echo -e "|${GREEN}Server Country    |${NC} $SERVER_COUNTRY"
    echo -e "|${GREEN}Server IP         |${NC} $SERVER_IP"
    echo -e "|${GREEN}Server ISP        |${NC} $SERVER_ISP"
    echo "+-----------------------------------------------------------------------------+"
    echo -e "|${YELLOW}Please choose an option:${NC}"
    echo "+-----------------------------------------------------------------------------+"
    echo -e "1- Install new tunnel"
    echo -e "2- Uninstall tunnel(s)"
    echo -e "3- Install BBR"
    echo "+-----------------------------------------------------------------------------+"
    echo -e "\033[0m"
}

uninstall_all_vxlan() {
    echo "[!] Deleting all VXLAN interfaces and cleaning up..."
    for i in $(ip -d link show | grep -o 'vxlan[0-9]\+'); do
        ip link del $i 2>/dev/null
    done
    rm -f /usr/local/bin/vxlan_bridge.sh /etc/ping_vxlan.sh
    systemctl disable --now vxlan-tunnel.service 2>/dev/null
    rm -f /etc/systemd/system/vxlan-tunnel.service
    systemctl daemon-reload
    echo "[+] All VXLAN tunnels deleted."
}

install_bbr() {
    echo "Running BBR script..."
    curl -fsSL https://raw.githubusercontent.com/MrAminiDev/NetOptix/main/scripts/bbr.sh -o /tmp/bbr.sh
    bash /tmp/bbr.sh
    rm /tmp/bbr.sh
}

install_haproxy_and_configure() {
    echo "[*] Configuring HAProxy..."
    local CONFIG_FILE="/etc/haproxy/haproxy.cfg"
    local BACKUP_FILE="/etc/haproxy/haproxy.cfg.bak"
    [ -f "$CONFIG_FILE" ] && cp "$CONFIG_FILE" "$BACKUP_FILE"

    cat <<EOL > "$CONFIG_FILE"
global
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    mode    tcp
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
EOL

    read -p "Enter ports (comma-separated): " user_ports
    local local_ip=$(hostname -I | awk '{print $1}')
    IFS=',' read -ra ports <<< "$user_ports"

    for port in "${ports[@]}"; do
        cat <<EOL >> "$CONFIG_FILE"

frontend frontend_$port
    bind *:$port
    default_backend backend_$port

backend backend_$port
    server server1 $local_ip:$port check
EOL
    done

    if haproxy -c -f "$CONFIG_FILE"; then
        echo "[*] Restarting HAProxy service..."
        systemctl restart haproxy
        echo -e "${GREEN}HAProxy configured and restarted successfully.${NC}"
    else
        echo -e "${YELLOW}Warning: HAProxy configuration is invalid!${NC}"
    fi
}

# ---------------- MAIN ----------------
while true; do
    ShadowBridge_menu
    read -p "Enter your choice [1-3]: " main_action
    case $main_action in
        1) break;;
        2) uninstall_all_vxlan; read -p "Press Enter to return to menu...";;
        3) install_bbr; read -p "Press Enter to return to menu...";;
        *) echo "[x] Invalid option. Try again."; sleep 1;;
    esac
done

if ! command -v ip >/dev/null 2>&1; then
    echo "[x] iproute2 is not installed. Aborting."
    exit 1
fi

VNI=88
VXLAN_IF="vxlan${VNI}"

echo "Choose server role:"
echo "1- Iran"
echo "2- Kharej"
read -p "Enter choice (1/2): " role_choice

if [[ "$role_choice" == "1" ]]; then
    read -p "Enter IRAN IP: " IRAN_IP
    read -p "Enter Kharej IP: " KHAREJ_IP
    while true; do
        read -p "Tunnel port (1 ~ 64435): " DSTPORT
        if [[ $DSTPORT =~ ^[0-9]+$ ]] && (( DSTPORT >= 1 && DSTPORT <= 64435 )); then break; else echo "Invalid port. Try again."; fi
    done
    read -p "Should port forwarding be done automatically? (1-yes, 2-no): " haproxy_choice
    if [[ "$haproxy_choice" == "1" ]]; then
        install_haproxy_and_configure
    fi
    VXLAN_IP="30.0.0.1/24"
    REMOTE_IP=$KHAREJ_IP
elif [[ "$role_choice" == "2" ]]; then
    read -p "Enter IRAN IP: " IRAN_IP
    read -p "Enter Kharej IP: " KHAREJ_IP
    while true; do
        read -p "Tunnel port (1 ~ 64435): " DSTPORT
        if [[ $DSTPORT =~ ^[0-9]+$ ]] && (( DSTPORT >= 1 && DSTPORT <= 64435 )); then break; else echo "Invalid port. Try again."; fi
    done
    VXLAN_IP="30.0.0.2/24"
    REMOTE_IP=$IRAN_IP
else
    echo "[x] Invalid role selected."
    exit 1
fi

INTERFACE=$(ip route get 1.1.1.1 | awk '{print $5}' | head -n1)
echo "Detected main interface: $INTERFACE"

ip link add $VXLAN_IF type vxlan id $VNI local $(hostname -I | awk '{print $1}') remote $REMOTE_IP dev $INTERFACE dstport $DSTPORT nolearning
ip addr add $VXLAN_IP dev $VXLAN_IF
ip link set $VXLAN_IF up
iptables -I INPUT 1 -p udp --dport $DSTPORT -j ACCEPT
iptables -I INPUT 1 -s $REMOTE_IP -j ACCEPT
iptables -I INPUT 1 -s ${VXLAN_IP%/*} -j ACCEPT

echo "[+] Creating systemd service for VXLAN..."

cat <<EOF > /usr/local/bin/vxlan_bridge.sh
#!/bin/bash
ip link add $VXLAN_IF type vxlan id $VNI local $(hostname -I | awk '{print $1}') remote $REMOTE_IP dev $INTERFACE dstport $DSTPORT nolearning
ip addr add $VXLAN_IP dev $VXLAN_IF
ip link set $VXLAN_IF up
EOF

chmod +x /usr/local/bin/vxlan_bridge.sh

cat <<EOF > /etc/systemd/system/vxlan-tunnel.service
[Unit]
Description=VXLAN Tunnel Interface
After=network.target

[Service]
ExecStart=/usr/local/bin/vxlan_bridge.sh
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/vxlan-tunnel.service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable vxlan-tunnel.service
systemctl start vxlan-tunnel.service

echo -e "\n${GREEN}[✓] ShadowBridge tunnel setup completed successfully and will run on boot.${NC}"
