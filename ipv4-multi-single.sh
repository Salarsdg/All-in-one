#!/bin/bash
set -e

NETPLAN_FILE="/etc/netplan/99-gre.yaml"

# ---------------- Functions ----------------

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

# ---------------- Role ----------------

echo "GRE Netplan Setup"
echo "-----------------"
echo "1) Iran"
echo "2) Kharej"
read -rp "Select server role (1/2): " ROLE

# ---------------- Iran ----------------

if [ "$ROLE" == "1" ]; then
  echo
  echo "IRAN MODE (multi-kharej)"

  AUTO_IP=$(get_public_ip)
  if [ -n "$AUTO_IP" ]; then
    read -rp "Enter IRAN public IPv4 (auto-detected: $AUTO_IP) [Enter to use]: " IRAN_PUB
    IRAN_PUB=${IRAN_PUB:-$AUTO_IP}
  else
    IRAN_PUB=$(ask_non_empty "Enter IRAN public IPv4: ")
  fi

  read -rp "How many kharej servers? (number): " COUNT
  if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ]; then
    echo "ERROR: invalid number"
    exit 1
  fi

  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
EOF

  declare -a SUMMARY

  for ((i=1; i<=COUNT; i++)); do
    echo
    echo "Kharej #$i"
    KHAREJ_PUB=$(ask_non_empty "  Enter kharej public IPv4: ")

    IRAN_GRE="10.10.${i}.1/30"
    KHAREJ_GRE="10.10.${i}.2/30"

    cat >> "$NETPLAN_FILE" <<EOF
    gre$i:
      mode: gre
      local: $IRAN_PUB
      remote: $KHAREJ_PUB
      addresses:
        - $IRAN_GRE
      mtu: 1476
EOF

    SUMMARY+=(
"Kharej #$i
  Tunnel name       : gre$i
  Iran public IPv4  : $IRAN_PUB
  Kharej public IPv4: $KHAREJ_PUB
  Kharej GRE IPv4   : $KHAREJ_GRE
  Iran GRE IPv4     : $IRAN_GRE"
    )
  done

  chmod 600 "$NETPLAN_FILE"
  netplan apply

  echo
  echo "======================================"
  echo "IRAN CONFIGURATION COMPLETED"
  echo "======================================"
  for s in "${SUMMARY[@]}"; do
    echo
    echo "$s"
  done

# ---------------- Kharej ----------------

elif [ "$ROLE" == "2" ]; then
  echo
  echo "KHAREJ MODE (single GRE)"

  read -rp "Enter tunnel index (given by Iran): " IDX
  if ! [[ "$IDX" =~ ^[0-9]+$ ]]; then
    echo "ERROR: invalid index"
    exit 1
  fi

  AUTO_IP=$(get_public_ip)
  if [ -n "$AUTO_IP" ]; then
    read -rp "Enter KHAREJ public IPv4 (auto-detected: $AUTO_IP) [Enter to use]: " KHAREJ_PUB
    KHAREJ_PUB=${KHAREJ_PUB:-$AUTO_IP}
  else
    KHAREJ_PUB=$(ask_non_empty "Enter KHAREJ public IPv4: ")
  fi

  IRAN_PUB=$(ask_non_empty "Enter IRAN public IPv4: ")

  KHAREJ_GRE="10.10.${IDX}.2/30"
  IRAN_GRE="10.10.${IDX}.1/30"

  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
    gre$IDX:
      mode: gre
      local: $KHAREJ_PUB
      remote: $IRAN_PUB
      addresses:
        - $KHAREJ_GRE
      mtu: 1476
EOF

  chmod 600 "$NETPLAN_FILE"
  netplan apply

  echo
  echo "======================================"
  echo "KHAREJ CONFIGURATION COMPLETED"
  echo "======================================"
  echo "Tunnel name    : gre$IDX"
  echo "Local GRE IPv4 : $KHAREJ_GRE"
  echo "Remote GRE IPv4: $IRAN_GRE"

else
  echo "ERROR: invalid selection"
  exit 1
fi
