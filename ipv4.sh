#!/bin/bash

set -e

echo "=============================="
echo " GRE Netplan Setup Script"
echo "=============================="

# Must be run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

# Check netplan
if ! command -v netplan >/dev/null 2>&1; then
    echo "netplan not found. Installing..."
    apt update
    apt install -y netplan.io
fi

# Check systemd-networkd
if ! systemctl is-active --quiet systemd-networkd; then
    echo "ERROR: systemd-networkd is not running."
    echo "Netplan GRE requires systemd-networkd."
    exit 1
fi

# User input
read -p "Is this server IRAN or FOREIGN? (iran/foreign): " ROLE
read -p "Public IP of IRAN server: " IR_IP
read -p "Public IP of FOREIGN server: " FR_IP

TUN_NAME="gre_auto"
MTU="1480"
NETPLAN_FILE="/etc/netplan/99-gre.yaml"

# Role logic
if [[ "$ROLE" == "iran" ]]; then
    LOCAL_IP="$IR_IP"
    REMOTE_IP="$FR_IP"
    TUN_IP="10.10.10.1/30"
elif [[ "$ROLE" == "foreign" ]]; then
    LOCAL_IP="$FR_IP"
    REMOTE_IP="$IR_IP"
    TUN_IP="10.10.10.2/30"
else
    echo "Invalid role"
    exit 1
fi

echo "Creating netplan GRE configuration..."

# Create netplan config
cat <<EOF > $NETPLAN_FILE
network:
  version: 2
  renderer: networkd
  tunnels:
    $TUN_NAME:
      mode: gre
      local: $LOCAL_IP
      remote: $REMOTE_IP
      ttl: 255
      mtu: $MTU
      addresses:
        - $TUN_IP
EOF

# Secure permissions
chmod 600 $NETPLAN_FILE
chown root:root $NETPLAN_FILE

echo "Applying netplan..."
netplan generate
netplan apply

echo "=============================="
echo " GRE tunnel configured via netplan"
echo " Tunnel interface: $TUN_NAME"
echo " Tunnel IP: $TUN_IP"
echo "=============================="
