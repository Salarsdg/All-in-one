#!/bin/bash
set -e

NETPLAN_FILE="/etc/netplan/99-gre.yaml"

# ---------- FUNCTIONS ----------

validate_ipv4() {
    local ip=$1
    [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    for o in ${ip//./ }; do
        (( o >= 0 && o <= 255 )) || return 1
    done
}

get_public_ip() {
    curl -4 -s ifconfig.me || true
}

install_netplan() {
    command -v netplan >/dev/null 2>&1 || apt update && apt install -y netplan.io
}

fix_networkd() {
    systemctl unmask systemd-networkd.service 2>/dev/null || true
    systemctl enable systemd-networkd.service
    systemctl restart systemd-networkd.service
}

ask_local_public_ip() {
    local detected
    detected=$(get_public_ip)
    read -rp "Enter LOCAL public IPv4 (auto-detected: $detected) [Enter to use]: " ip
    if [[ -z "$ip" ]]; then
        ip="$detected"
    fi
    validate_ipv4 "$ip" || { echo "Invalid IPv4"; exit 1; }
    echo "$ip"
}

ask_remote_public_ip() {
    local ip
    while true; do
        read -rp "Enter REMOTE public IPv4: " ip
        validate_ipv4 "$ip" && break
        echo "Invalid IPv4"
    done
    echo "$ip"
}

# ---------- PRECHECK ----------

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

install_netplan
fix_networkd

# ---------- ROLE ----------

echo "Server role?"
echo "1) iran"
echo "2) kharej"
read -rp "Select (1/2): " ROLE

rm -f "$NETPLAN_FILE"

cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
EOF

# ---------- IRAN (HUB) ----------

if [[ "$ROLE" == "1" ]]; then
    IRAN_PUB=$(ask_local_public_ip)

    read -rp "How many foreign servers? " COUNT

    echo
    echo "===== FOREIGN SERVER CONFIG INFO ====="

    for ((i=1;i<=COUNT;i++)); do
        KHAREJ_PUB=$(ask_remote_public_ip)

        OFFSET=$(( (i-1) * 4 ))
        IRAN_IP=$((OFFSET + 1))
        KHAREJ_IP=$((OFFSET + 2))

        cat >> "$NETPLAN_FILE" <<EOF
    gre$i:
      mode: gre
      local: $IRAN_PUB
      remote: $KHAREJ_PUB
      addresses:
        - 10.10.10.$IRAN_IP/30
      mtu: 1476
      optional: true
EOF

        echo "Foreign #$i:"
        echo "  Tunnel index : $i"
        echo "  Local GRE IP : 10.10.10.$KHAREJ_IP/30"
        echo "  Remote GRE IP: 10.10.10.$IRAN_IP"
        echo
    done
fi

# ---------- KHAREJ ----------

if [[ "$ROLE" == "2" ]]; then
    LOCAL_PUB=$(ask_local_public_ip)
    REMOTE_PUB=$(ask_remote_public_ip)

    read -rp "Enter LOCAL GRE IPv4 (example 10.10.10.2/30): " LOCAL_GRE

    cat >> "$NETPLAN_FILE" <<EOF
    gre1:
      mode: gre
      local: $LOCAL_PUB
      remote: $REMOTE_PUB
      addresses:
        - $LOCAL_GRE
      mtu: 1476
      optional: true
EOF
fi

chmod 600 "$NETPLAN_FILE"
netplan generate
netplan apply

echo "✅ GRE configuration applied successfully."
