#!/bin/bash
set -euo pipefail

NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE="/etc/netplan/99-gre.yaml"

# ---------------- Root check ----------------
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run this script as root"
  exit 1
fi

# ---------------- Install requirements ----------------
echo "Checking requirements..."

if ! command -v netplan >/dev/null 2>&1; then
  echo "Installing netplan.io..."
  apt update -y
  apt install -y netplan.io
fi

mkdir -p "$NETPLAN_DIR"

echo "Ensuring systemd-networkd is enabled..."
systemctl unmask systemd-networkd.service || true
systemctl unmask systemd-networkd.socket || true
systemctl enable systemd-networkd.service
systemctl start systemd-networkd.service

# ---------------- Helpers ----------------
get_public_ip() {
  local ip
  for svc in \
    "https://api.ipify.org" \
    "https://ipv4.icanhazip.com"
  do
    ip="$(curl -4 -s --max-time 5 "$svc" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' || true)"
    [ -n "${ip:-}" ] && echo "$ip" && return
  done
  echo ""
}

ask_non_empty() {
  local v=""
  while true; do
    read -rp "$1" v
    v="$(echo "$v" | xargs)"
    [ -n "$v" ] && echo "$v" && return
    echo "ERROR: value cannot be empty"
  done
}

ask_yes_no() {
  local prompt="$1"
  local ans=""
  while true; do
    read -rp "$prompt" ans
    ans="$(echo "$ans" | xargs | tr '[:upper:]' '[:lower:]')"
    case "$ans" in
      y|yes) return 0 ;;
      n|no|"") return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

list_tunnels_in_file() {
  # prints: gre1 gre2 ...
  [ -f "$NETPLAN_FILE" ] || return 0
  grep -E '^\s{4}gre[0-9]+:\s*$' "$NETPLAN_FILE" \
    | sed -E 's/^\s{4}(gre[0-9]+):\s*$/\1/' \
    | sort -V
}

delete_tunnel_from_file() {
  local gre_name="$1"
  [ -f "$NETPLAN_FILE" ] || { echo "ERROR: $NETPLAN_FILE not found"; return 1; }

  # Remove the gre block:
  # starts at line: "    greX:"
  # continues until next "    greY:" or EOF
  awk -v key="$gre_name" '
    BEGIN{skip=0}
    {
      # start skip when exact tunnel block header matches
      if ($0 ~ "^    " key ":\\s*$") { skip=1; next }

      # end skip when we reach next tunnel header
      if (skip && $0 ~ "^    gre[0-9]+:\\s*$") { skip=0 }

      if (!skip) print
    }
  ' "$NETPLAN_FILE" > "${NETPLAN_FILE}.tmp"

  mv "${NETPLAN_FILE}.tmp" "$NETPLAN_FILE"

  # If tunnels: section is now empty, remove it and keep minimal netplan skeleton
  if ! grep -Eq '^\s{4}gre[0-9]+:\s*$' "$NETPLAN_FILE"; then
    # keep network/version/renderer, remove tunnels section entirely if present
    awk '
      BEGIN{in_tunnels=0}
      /^\s*tunnels:\s*$/ {in_tunnels=1; next}
      in_tunnels {
        # tunnels section ends when indentation goes back to 2 spaces or less (new top key)
        if ($0 ~ /^\s{0,2}[A-Za-z0-9_-]+:\s*$/) {in_tunnels=0; print}
        next
      }
      {print}
    ' "$NETPLAN_FILE" > "${NETPLAN_FILE}.tmp2" || true

    # If awk produced nothing (unlikely), write minimal file
    if [ -s "${NETPLAN_FILE}.tmp2" ]; then
      mv "${NETPLAN_FILE}.tmp2" "$NETPLAN_FILE"
    else
      cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
EOF
      rm -f "${NETPLAN_FILE}.tmp2" || true
    fi
  else
    rm -f "${NETPLAN_FILE}.tmp2" 2>/dev/null || true
  fi

  chmod 600 "$NETPLAN_FILE"
}

apply_and_optional_reboot() {
  echo
  echo "Applying netplan..."
  netplan apply

  echo
  echo "IMPORTANT: Reboot is required to fully apply and register tunnel changes."
  if ask_yes_no "Reboot now? (y/N): "; then
    echo "Rebooting..."
    reboot
  else
    echo "Reboot skipped. Please reboot manually later (required)."
  fi
}

# ---------------- Main menu ----------------
echo
echo "GRE Netplan Setup"
echo "-----------------"
echo "1) Iran (multi-kharej create)"
echo "2) Kharej (single create)"
echo "3) Delete tunnel"
read -rp "Select option (1/2/3): " MENU
MENU="$(echo "$MENU" | xargs)"

# ---------------- Option 3: DELETE ----------------
if [ "$MENU" = "3" ]; then
  echo
  echo "DELETE TUNNEL"
  echo "-------------"

  if [ ! -f "$NETPLAN_FILE" ]; then
    echo "No netplan GRE config found at: $NETPLAN_FILE"
    exit 1
  fi

  mapfile -t TUNNELS < <(list_tunnels_in_file)

  if [ "${#TUNNELS[@]}" -eq 0 ]; then
    echo "No tunnels found inside $NETPLAN_FILE"
    exit 1
  fi

  echo "Found tunnels:"
  for t in "${TUNNELS[@]}"; do
    echo " - $t"
  done

  GRE_TO_DELETE=""
  while true; do
    read -rp "Which tunnel do you want to delete? (example: gre2): " GRE_TO_DELETE
    GRE_TO_DELETE="$(echo "$GRE_TO_DELETE" | xargs)"
    if printf '%s\n' "${TUNNELS[@]}" | grep -qx "$GRE_TO_DELETE"; then
      break
    fi
    echo "ERROR: tunnel not found. Choose one of: ${TUNNELS[*]}"
  done

  echo
  echo "Deleting tunnel: $GRE_TO_DELETE"
  delete_tunnel_from_file "$GRE_TO_DELETE"

  apply_and_optional_reboot
  exit 0
fi

# Remove old config before creating a new one (only for create modes)
[ -f "$NETPLAN_FILE" ] && rm -f "$NETPLAN_FILE"

# ---------------- Option 1: IRAN MODE ----------------
if [ "$MENU" = "1" ]; then
  echo
  echo "IRAN MODE (multi-kharej)"

  AUTO_IP="$(get_public_ip)"
  if [ -n "$AUTO_IP" ]; then
    read -rp "Enter IRAN public IPv4 (auto-detected: $AUTO_IP) [Enter to use]: " IRAN_PUB
    IRAN_PUB="$(echo "${IRAN_PUB:-$AUTO_IP}" | xargs)"
  else
    IRAN_PUB="$(ask_non_empty "Enter IRAN public IPv4: ")"
  fi

  read -rp "How many kharej servers? " COUNT
  COUNT="$(echo "$COUNT" | xargs)"
  [[ "$COUNT" =~ ^[0-9]+$ ]] || { echo "ERROR: invalid number"; exit 1; }
  [ "$COUNT" -ge 1 ] || { echo "ERROR: must be >= 1"; exit 1; }

  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
EOF

  declare -a SUMMARY

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
  netplan apply

  echo
  echo "IRAN CONFIGURATION COMPLETED"
  for s in "${SUMMARY[@]}"; do
    echo
    echo "$s"
  done

  apply_and_optional_reboot
  exit 0
fi

# ---------------- Option 2: KHAREJ MODE ----------------
if [ "$MENU" = "2" ]; then
  echo
  echo "KHAREJ MODE"

  read -rp "Enter tunnel index (given by Iran): " IDX
  IDX="$(echo "$IDX" | xargs)"
  [[ "$IDX" =~ ^[0-9]+$ ]] || { echo "ERROR: invalid index"; exit 1; }
  [ "$IDX" -ge 1 ] || { echo "ERROR: index must be >= 1"; exit 1; }

  AUTO_IP="$(get_public_ip)"
  if [ -n "$AUTO_IP" ]; then
    read -rp "Enter KHAREJ public IPv4 (auto-detected: $AUTO_IP) [Enter to use]: " KHAREJ_PUB
    KHAREJ_PUB="$(echo "${KHAREJ_PUB:-$AUTO_IP}" | xargs)"
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
  netplan apply

  echo
  echo "KHAREJ CONFIGURATION COMPLETED"
  echo "Tunnel gre$IDX is up"

  apply_and_optional_reboot
  exit 0
fi

echo "ERROR: invalid selection"
exit 1