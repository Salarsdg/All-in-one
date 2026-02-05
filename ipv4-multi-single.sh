#!/bin/bash
set -e

NETPLAN_FILE="/etc/netplan/99-gre.yaml"

# ------------------ Functions ------------------

is_valid_ipv4_cidr() {
  [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/30$ ]]
}

get_public_ip() {
  for svc in \
    "https://api.ipify.org" \
    "https://ipv4.icanhazip.com"
  do
    ip=$(curl -4 -s --max-time 5 "$svc" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
    [ -n "$ip" ] && echo "$ip" && return
  done
  echo ""
}

ask_non_empty() {
  local prompt=$1
  local value
  while true; do
    read -rp "$prompt" value
    [ -n "$value" ] && echo "$value" && return
    echo "ERROR: value cannot be empty"
  done
}

ask_ipv4_cidr() {
  local prompt=$1
  local ip
  while true; do
    read -rp "$prompt" ip
    if is_valid_ipv4_cidr "$ip"; then
      echo "$ip"
      return
    fi
    echo "ERROR: invalid format (example: 10.10.10.2/30)"
  done
}

# ------------------ Start ------------------

echo "GRE Netplan Setup"
echo "-----------------"
echo "1) Iran server"
echo "2) Foreign server"
read -rp "Select server type (1/2): " SERVER_TYPE

# ------------------ Public IP ------------------

AUTO_IP=$(get_public_ip)

if [ -n "$AUTO_IP" ]; then
  read -rp "Enter LOCAL public IPv4 (auto-detected: $AUTO_IP) [Enter to use]: " LOCAL_PUB
  LOCAL_PUB=${LOCAL_PUB:-$AUTO_IP}
else
  LOCAL_PUB=$(ask_non_empty "Enter LOCAL public IPv4 manually: ")
fi

REMOTE_PUB=$(ask_non_empty "Enter REMOTE public IPv4: ")

# ------------------ GRE IP Logic ------------------

if [ "$SERVER_TYPE" == "2" ]; then
  echo
  echo "GRE local IP configuration:"
  echo "1) Automatic (by index)"
  echo "2) Manual"
  read -rp "Select (1/2): " MODE

  if [ "$MODE" == "1" ]; then
    read -rp "Enter tunnel index (number): " IDX

    IRAN_GRE="10.10.${IDX}.1/30"
    FOREIGN_GRE="10.10.${IDX}.2/30"

    echo
    echo "GRE IPs will be configured as:"
    echo "Local  (this server): $FOREIGN_GRE"
    echo "Remote (Iran side) : $IRAN_GRE"
    read -rp "Press Enter to continue..." _

    LOCAL_GRE="$FOREIGN_GRE"
    REMOTE_GRE="$IRAN_GRE"

  else
    LOCAL_GRE=$(ask_ipv4_cidr "Enter LOCAL GRE IPv4 (example 10.10.10.2/30): ")
    REMOTE_GRE=$(ask_ipv4_cidr "Enter REMOTE GRE IPv4 (example 10.10.10.1/30): ")
  fi

else
  read -rp "Enter tunnel index (number): " IDX

  LOCAL_GRE="10.10.${IDX}.1/30"
  REMOTE_GRE="10.10.${IDX}.2/30"
fi

# ------------------ Netplan Write ------------------

cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
    gre${IDX}:
      mode: gre
      local: $LOCAL_PUB
      remote: $REMOTE_PUB
      addresses:
        - $LOCAL_GRE
      mtu: 1476
EOF

chmod 600 "$NETPLAN_FILE"

echo
echo "Applying netplan configuration..."
netplan apply

# ------------------ Result ------------------

echo
echo "SUCCESS: GRE tunnel configured"
echo "-------------------------------"
echo "Tunnel name       : gre${IDX}"
echo "Local GRE IPv4    : $LOCAL_GRE"
echo "Remote GRE IPv4   : $REMOTE_GRE"
echo "Netplan file      : $NETPLAN_FILE"
echo "-------------------------------"
