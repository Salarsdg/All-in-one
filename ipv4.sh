#!/bin/bash

set -e

echo "=============================="
echo " GRE Tunnel Auto Setup"
echo "=============================="

# Must be run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

# Check if netplan exists, install if missing
if ! command -v netplan >/dev/null 2>&1; then
    echo "netplan not found, installing..."
    apt update
    apt install -y netplan.io
else
    echo "netplan already installed"
fi

# User input
read -p "Is this server IRAN or FOREIGN? (iran/foreign): " ROLE
read -p "Public IP of IRAN server: " IR_IP
read -p "Public IP of FOREIGN server: " FR_IP

TUN="gre_auto"
MTU="1480"

# Assign tunnel IPs based on server role
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

# Create GRE tunnel immediately (runtime)
ip tunnel del $TUN 2>/dev/null || true
ip tunnel add $TUN mode gre local $LOCAL_IP remote $REMOTE_IP ttl 255
ip addr add $TUN_IP dev $TUN
ip link set $TUN mtu $MTU
ip link set $TUN up

echo "GRE tunnel is UP"

# Create persistent GRE script (runs on every boot)
cat <<EOF >/usr/local/bin/gre-auto.sh
#!/bin/bash
# This script is executed by systemd at boot
ip tunnel add $TUN mode gre local $LOCAL_IP remote $REMOTE_IP ttl 255 || true
ip addr add $TUN_IP dev $TUN || true
ip link set $TUN mtu $MTU
ip link set $TUN up
EOF

chmod +x /usr/local/bin/gre-auto.sh

# Create systemd service
cat <<EOF >/etc/systemd/system/gre-auto.service
[Unit]
Description=Persistent GRE Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gre-auto.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gre-auto
systemctl restart gre-auto

echo "=============================="
echo " Setup completed successfully"
echo " Tunnel interface: $TUN"
echo " Tunnel IP: $TUN_IP"
echo "=============================="
