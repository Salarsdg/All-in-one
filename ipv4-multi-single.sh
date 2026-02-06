#!/usr/bin/env bash
set -Eeuo pipefail

NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE="/etc/netplan/99-gre.yaml"

# ---------------- UI ----------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

hr()   { printf "%b\n" "${BLUE}------------------------------------------------------------${NC}"; }
die()  { echo -e "${RED}[✘] $*${NC}" >&2; exit 1; }
ok()   { echo -e "${GREEN}[✔] $*${NC}"; }
info() { echo -e "${CYAN}[i] $*${NC}"; }
warn() { echo -e "${YELLOW}[!] $*${NC}"; }

trap 'die "Error on line $LINENO"' ERR
[ "$EUID" -eq 0 ] || die "Run as root"

# ---------------- Helpers ----------------
valid_ipv4() { [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }

ask_ipv4() {
  local p="$1" d="${2:-}" v
  while true; do
    if [ -n "$d" ]; then read -rp "$p [$d]: " v; v="${v:-$d}"
    else read -rp "$p: " v; fi
    valid_ipv4 "$v" && echo "$v" && return
    echo "Invalid IPv4"
  done
}

get_public_ip() {
  curl -4 -s --max-time 5 https://api.ipify.org || true
}

backup_netplan() {
  mkdir -p "$NETPLAN_DIR/aio-backup"
  [ -f "$NETPLAN_FILE" ] && cp "$NETPLAN_FILE" "$NETPLAN_DIR/aio-backup/99-gre.$(date +%s).bak"
}

# ---------------- Show tunnels ----------------
show_tunnels() {
  hr
  echo -e "${BLUE}Show GRE tunnels${NC}"
  hr

  if [ ! -f "$NETPLAN_FILE" ]; then
    warn "No tunnels found"
    return
  fi

  awk '
  /^[[:space:]]{4}gre/ { name=$1; sub(":", "", name) }
  /^[[:space:]]{6}local:/ { local=$2 }
  /^[[:space:]]{6}remote:/ { remote=$2 }
  /^[[:space:]]{8}-/ {
    addr=$2
    print "Tunnel:", name
    print "  Public :", local, "->", remote
    print "  Private:", addr
    print ""
  }' "$NETPLAN_FILE"
}

# ---------------- Delete tunnels ----------------
delete_tunnels() {
  hr
  echo -e "${RED}Delete tunnels${NC}"
  hr

  [ -f "$NETPLAN_FILE" ] || { warn "Nothing to delete"; return; }

  echo "1) Delete ONE tunnel"
  echo "2) Delete ALL tunnels"
  echo "0) Back"
  read -rp "Select: " d

  case "$d" in
    1)
      read -rp "Tunnel name (e.g. gre1): " t
      grep -q "^[[:space:]]*$t:" "$NETPLAN_FILE" || { warn "Tunnel not found"; return; }
      backup_netplan
      awk -v t="    $t:" '
        BEGIN{del=0}
        $0==t {del=1; next}
        del && /^[[:space:]]{4}gre/ {del=0}
        !del {print}
      ' "$NETPLAN_FILE" > /tmp/gre.tmp
      mv /tmp/gre.tmp "$NETPLAN_FILE"
      netplan apply
      ok "Deleted $t"
      ;;
    2)
      backup_netplan
      cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels: {}
EOF
      netplan apply
      ok "All tunnels deleted"
      ;;
    0) return ;;
    *) warn "Invalid choice" ;;
  esac
}

# ============================================================
# 1) IRAN (multi kharej)
# ============================================================
iran_multi_kharej() {
  clear; hr; echo "IRAN (multi kharej)"; hr
  local iran_pub count
  iran_pub="$(ask_ipv4 "Iran public IPv4" "$(get_public_ip)")"
  read -rp "How many kharej servers? " count
  [[ "$count" =~ ^[0-9]+$ ]] || die "Invalid number"

  backup_netplan
  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
EOF

  for ((i=1;i<=count;i++)); do
    local kharej_pub
    kharej_pub="$(ask_ipv4 "Kharej #$i public IPv4")"
    cat >> "$NETPLAN_FILE" <<EOF
    gre$i:
      mode: gre
      local: $iran_pub
      remote: $kharej_pub
      addresses:
        - 10.10.$i.1/30
      mtu: 1476
EOF
  done

  chmod 600 "$NETPLAN_FILE"
  netplan apply
  ok "IRAN multi-kharej configured"
}

# ============================================================
# 2) IRAN (single kharej)
# ============================================================
iran_single_kharej() {
  clear; hr; echo "IRAN (single kharej)"; hr
  local idx iran_pub kharej_pub
  read -rp "Tunnel index: " idx
  [[ "$idx" =~ ^[0-9]+$ ]] || die "Invalid index"
  iran_pub="$(ask_ipv4 "Iran public IPv4" "$(get_public_ip)")"
  kharej_pub="$(ask_ipv4 "Kharej public IPv4")"

  backup_netplan
  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
    gre$idx:
      mode: gre
      local: $iran_pub
      remote: $kharej_pub
      addresses:
        - 10.20.$idx.1/30
      mtu: 1476
EOF
  chmod 600 "$NETPLAN_FILE"
  netplan apply
  ok "IRAN single-kharej configured"
}

# ============================================================
# 3) KHAREJ (multi iran)
# ============================================================
kharej_multi_iran() {
  clear; hr; echo "KHAREJ (multi iran)"; hr
  local kharej_pub count
  kharej_pub="$(ask_ipv4 "Kharej public IPv4" "$(get_public_ip)")"
  read -rp "How many iran servers? " count
  [[ "$count" =~ ^[0-9]+$ ]] || die "Invalid number"

  backup_netplan
  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
EOF

  for ((i=1;i<=count;i++)); do
    local iran_pub
    iran_pub="$(ask_ipv4 "Iran #$i public IPv4")"
    cat >> "$NETPLAN_FILE" <<EOF
    gre$i:
      mode: gre
      local: $kharej_pub
      remote: $iran_pub
      addresses:
        - 10.20.$i.2/30
      mtu: 1476
EOF
  done

  chmod 600 "$NETPLAN_FILE"
  netplan apply
  ok "KHAREJ multi-iran configured"
}

# ============================================================
# 4) KHAREJ (single iran)
# ============================================================
kharej_single_iran() {
  clear; hr; echo "KHAREJ (single iran)"; hr
  local idx kharej_pub iran_pub
  read -rp "Tunnel index: " idx
  [[ "$idx" =~ ^[0-9]+$ ]] || die "Invalid index"
  kharej_pub="$(ask_ipv4 "Kharej public IPv4" "$(get_public_ip)")"
  iran_pub="$(ask_ipv4 "Iran public IPv4")"

  backup_netplan
  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
    gre$idx:
      mode: gre
      local: $kharej_pub
      remote: $iran_pub
      addresses:
        - 10.20.$idx.2/30
      mtu: 1476
EOF
  chmod 600 "$NETPLAN_FILE"
  netplan apply
  ok "KHAREJ single-iran configured"
}

# ---------------- Menu ----------------
while true; do
  clear
  hr
  echo -e "${BLUE}IPv4 GRE Manager${NC}"
  hr
  echo "1) IRAN   (multi kharej)"
  echo "2) IRAN   (single kharej)"
  echo "3) KHAREJ (multi iran)"
  echo "4) KHAREJ (single iran)"
  echo "5) Show tunnels"
  echo "6) Delete tunnels"
  echo "0) Back"
  read -rp "Select: " c

  case "$c" in
    1) iran_multi_kharej ;;
    2) iran_single_kharej ;;
    3) kharej_multi_iran ;;
    4) kharej_single_iran ;;
    5) show_tunnels ;;
    6) delete_tunnels ;;
    0) exit 0 ;;
    *) warn "Invalid choice"; sleep 1 ;;
  esac

  echo
  read -rp "Press Enter to return..." _
done
