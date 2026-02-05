#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/lib/utils.sh"

require_root
is_ubuntu_or_debian || die "This module supports Debian/Ubuntu with netplan."

NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE="/etc/netplan/99-gre.yaml"

info "Checking requirements..."
if ! command -v netplan >/dev/null 2>&1; then
  warn "netplan not found; installing netplan.io..."
  apt_install netplan.io
fi
need_cmd curl

mkdir -p "$NETPLAN_DIR"

info "Ensuring systemd-networkd is enabled..."
systemctl unmask systemd-networkd.service 2>/dev/null || true
systemctl unmask systemd-networkd.socket 2>/dev/null || true
systemctl enable --now systemd-networkd.service

get_public_ip() {
  local ip=""
  for svc in "https://api.ipify.org" "https://ipv4.icanhazip.com"; do
    ip="$(curl -4 -fsS --max-time 5 "$svc" 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' || true)"
    [[ -n "$ip" ]] && { echo "$ip"; return 0; }
  done
  echo ""
}

ask_non_empty() {
  local prompt="$1" v=""
  while true; do
    read -rp "$prompt" v
    [[ -n "${v:-}" ]] && { echo "$v"; return 0; }
    echo "ERROR: value cannot be empty"
  done
}

echo
echo -e "${BOLD}GRE Netplan Setup${NC}"
echo "-----------------"
echo "1) Iran (multi-kharej)"
echo "2) Kharej"
read -rp "Select server role (1/2): " ROLE

[[ "${ROLE:-}" == "1" || "${ROLE:-}" == "2" ]] || die "Invalid selection."

# Backup old config
if [[ -f "$NETPLAN_FILE" ]]; then
  cp -a "$NETPLAN_FILE" "${NETPLAN_FILE}.bak.$(date +%s)"
  warn "Backed up existing file: ${NETPLAN_FILE}.bak.*"
fi

# IRAN MODE
if [[ "$ROLE" == "1" ]]; then
  echo
  echo -e "${BOLD}IRAN MODE${NC} (multi-kharej)"

  AUTO_IP="$(get_public_ip)"
  if [[ -n "$AUTO_IP" ]]; then
    read -rp "Enter IRAN public IPv4 (auto-detected: $AUTO_IP) [Enter to use]: " IRAN_PUB
    IRAN_PUB="${IRAN_PUB:-$AUTO_IP}"
  else
    IRAN_PUB="$(ask_non_empty "Enter IRAN public IPv4: ")"
  fi

  read -rp "How many kharej servers? " COUNT
  [[ "$COUNT" =~ ^[0-9]+$ ]] || die "Invalid number."

  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
EOF

  declare -a SUMMARY=()

  for ((i=1;i<=COUNT;i++)); do
    echo
    echo "Kharej #$i"
    KHAREJ_PUB="$(ask_non_empty "  Enter kharej public IPv4: ")"

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
  Tunnel name     : gre$i
  Iran GRE IPv4   : $IRAN_GRE
  Kharej GRE IPv4 : $KHAREJ_GRE"
    )
  done

  chmod 600 "$NETPLAN_FILE"
  info "Applying netplan..."
  netplan apply
  ok "IRAN configuration completed."

  for s in "${SUMMARY[@]}"; do
    echo
    echo "$s"
  done

# KHAREJ MODE
else
  echo
  echo -e "${BOLD}KHAREJ MODE${NC}"

  read -rp "Enter tunnel index (given by Iran): " IDX
  [[ "$IDX" =~ ^[0-9]+$ ]] || die "Invalid index."

  AUTO_IP="$(get_public_ip)"
  if [[ -n "$AUTO_IP" ]]; then
    read -rp "Enter KHAREJ public IPv4 (auto-detected: $AUTO_IP) [Enter to use]: " KHAREJ_PUB
    KHAREJ_PUB="${KHAREJ_PUB:-$AUTO_IP}"
  else
    KHAREJ_PUB="$(ask_non_empty "Enter KHAREJ public IPv4: ")"
  fi

  IRAN_PUB="$(ask_non_empty "Enter IRAN public IPv4: ")"
  KHAREJ_GRE="10.10.${IDX}.2/30"

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
  info "Applying netplan..."
  netplan apply
  ok "Kharej configuration completed. Tunnel gre$IDX is up."
fi

info "Netplan file: $NETPLAN_FILE"
