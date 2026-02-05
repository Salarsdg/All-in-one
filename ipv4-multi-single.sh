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
    return 0
}

install_netplan() {
    if ! command -v netplan >/dev/null 2>&1; then
        echo "[*] Installing netplan..."
        apt update && apt install -y netplan.io
    fi
}

fix_networkd() {
    echo "[*] Enabling systemd-networkd..."
    systemctl unmask systemd-networkd.service || true
    systemctl enable systemd-networkd.service
    systemctl restart systemd-networkd.service
}

ask_public_ip() {
    local label=$1
    local ip=""
    while true; do
        read -rp "Enter $label public IPv4: " ip
        validate_ipv4 "$ip" && break
        echo "Invalid IPv4, try again."
    done
    echo "$ip"
}

# ---------- PRECHECK ----------

if [[ $EUID -ne 0 ]]; then
    echo "Run as root."
    exit 1
fi

install_netplan
fix_networkd

# ---------- ROLE ----------

echo "Server role?"
echo "1) iran"
echo "2) kharej"
read -rp "Select (1/2): " ROLE

[[ "$ROLE" != "1" && "$ROLE" != "2" ]] && exit 1

# ---------- CLEAN OLD FILE ----------

if [[ -f "$NETPLAN_FILE" ]]; then
    rm -f "$NETPLAN_FILE"
fi

# ---------- BASE CONFIG ----------

cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
EOF

# ---------- IRAN (HUB or SINGLE) ----------

if [[ "$ROLE" == "1" ]]; then
    IRAN_PUB=$(ask_public_ip "IRAN")

    echo "GRE mode?"
    echo "1) Single (1 to 1)"
    echo "2) Multiple (1 to N)"
    read -rp "Select (1/2): " MODE

    if [[ "$MODE" == "1" ]]; then
        KHAREJ_PUB=$(ask_public_ip "KHAREJ")

        cat >> "$NETPLAN_FILE" <<EOF
    gre1:
      mode: gre
      local: $IRAN_PUB
      remote: $KHAREJ_PUB
      addresses:
        - 10.10.10.1/30
      mtu: 1476
      optional: true
EOF

    elif [[ "$MODE" == "2" ]]; then
        read -rp "How many foreign servers? " COUNT

        for ((i=1;i<=COUNT;i++)); do
            KHAREJ_PUB=$(ask_public_ip "KHAREJ #$i")
            OFFSET=$(( (i-1) * 4 ))
            IRAN_IP=$((OFFSET + 1))

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
        done
    else
        exit 1
    fi
fi

# ---------- KHAREJ (SPOKE) ----------

if [[ "$ROLE" == "2" ]]; then
    KHAREJ_PUB=$(ask_public_ip "KHAREJ")
    IRAN_PUB=$(ask_public_ip "IRAN")

    read -rp "Tunnel index (default 1): " IDX
    IDX=${IDX:-1}

    OFFSET=$(( (IDX-1) * 4 ))
    KHAREJ_IP=$((OFFSET + 2))

    cat >> "$NETPLAN_FILE" <<EOF
    gre1:
      mode: gre
      local: $KHAREJ_PUB
      remote: $IRAN_PUB
      addresses:
        - 10.10.10.$KHAREJ_IP/30
      mtu: 1476
      optional: true
EOF
fi

# ---------- APPLY ----------

chmod 600 "$NETPLAN_FILE"
netplan generate
netplan apply

echo "✅ GRE tunnel(s) configured successfully."
