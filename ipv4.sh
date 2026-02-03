#!/bin/bash

set -e

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# IPv4 validation function
valid_ipv4() {
  local ip=$1
  [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
  for o in $o1 $o2 $o3 $o4; do
    ((o >= 0 && o <= 255)) || return 1
  done
  return 0
}

echo "=== GRE Netplan Auto Setup ==="

# Check netplan
if ! command -v netplan >/dev/null 2>&1; then
  apt update
  apt install -y netplan.io
fi

# Ensure systemd-networkd
systemctl unmask systemd-networkd.service || true
systemctl enable systemd-networkd.service
systemctl start systemd-networkd.service

echo "Select server role:"
echo "1) IRAN"
echo "2) KHAREJ"
read -p "Enter choice (1/2): " ROLE

if [[ "$ROLE" != "1" && "$ROLE" != "2" ]]; then
  echo "Invalid selection"
  exit 1
fi

ROLE_NAME=$([ "$ROLE" == "1" ] && echo "iran" || echo "kharej")

# Ask for PUBLIC IPs (no default, must be valid)
while true; do
  read -p "Enter $ROLE_NAME PUBLIC IPv4: " LOCAL_PUB
  valid_ipv4 "$LOCAL_PUB" && break
  echo "Invalid IPv4. Try again."
done

while true; do
  read -p "Enter REMOTE PUBLIC IPv4: " REMOTE_PUB
  valid_ipv4 "$REMOTE_PUB" && break
  echo "Invalid IPv4. Try again."
done

# GRE IP defaults
if [ "$ROLE" == "1" ]; then
  DEF_GRE="10.10.10.1/30"
else
  DEF_GRE="10.10.10.2/30"
fi

read -p "Enter local GRE IP [$DEF_GRE]: " LOCAL_GRE
LOCAL_GRE=${LOCAL_GRE:-$DEF_GRE}

NETPLAN_FILE="/etc/netplan/99-gre.yaml"

cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
    gre1:
      mode: gre
      local: $LOCAL_PUB
      remote: $REMOTE_PUB
      addresses:
        - $LOCAL_GRE
      mtu: 1476
EOF

chmod 600 "$NETPLAN_FILE"

netplan generate
netplan apply

echo "=== GRE tunnel configured successfully on $ROLE_NAME ==="
