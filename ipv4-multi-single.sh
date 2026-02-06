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

# ✅ بهتر: هم خط هم دستور خراب رو نشون بده
trap 'rc=$?; echo -e "\n${RED}[✘] Error on line $LINENO: ${YELLOW}$BASH_COMMAND${NC} ${RED}(exit=$rc)${NC}\n" >&2; exit $rc' ERR

[ "$EUID" -eq 0 ] || die "Run as root"

# ---------------- Requirements ----------------
ensure_reqs() {
  mkdir -p "$NETPLAN_DIR" "$NETPLAN_DIR/aio-backup"

  if ! command -v netplan >/dev/null 2>&1; then
    info "netplan not found. Installing netplan.io ..."
    apt-get update -y
    apt-get install -y netplan.io
  fi

  # netplan معمولاً با networkd بهتره
  systemctl unmask systemd-networkd.service >/dev/null 2>&1 || true
  systemctl unmask systemd-networkd.socket  >/dev/null 2>&1 || true
  systemctl enable systemd-networkd.service >/dev/null 2>&1 || true
  systemctl start  systemd-networkd.service >/dev/null 2>&1 || true

  # ✅ چک writable بودن
  touch "$NETPLAN_FILE" 2>/dev/null || die "Cannot write to $NETPLAN_FILE (check filesystem/permissions)"
}

# ---------------- Helpers ----------------
valid_ipv4() { [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }

ask_ipv4() {
  local p="$1" d="${2:-}" v
  while true; do
    if [ -n "$d" ]; then
      read -rp "$p [$d]: " v; v="${v:-$d}"
    else
      read -rp "$p: " v
    fi
    valid_ipv4 "$v" && echo "$v" && return 0
    echo "Invalid IPv4"
  done
}

get_public_ip() {
  curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null || true
}

backup_netplan() {
  mkdir -p "$NETPLAN_DIR/aio-backup"
  if [ -f "$NETPLAN_FILE" ]; then
    cp -f "$NETPLAN_FILE" "$NETPLAN_DIR/aio-backup/99-gre.$(date +%s).bak" || true
  fi
}

write_header() {
  # اگر به هر دلیلی redirection fail بشه، همینجا معلوم میشه
  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
EOF
  chmod 600 "$NETPLAN_FILE"
}

# ---------------- Tunnel listing (for later use) ----------------
list_tunnels_raw() {
  # name|local|remote|addr
  awk '
  /^[[:space:]]{4}gre/ { name=$1; sub(":", "", name) }
  /^[[:space:]]{6}local:/  { local=$2 }
  /^[[:space:]]{6}remote:/ { remote=$2 }
  /^[[:space:]]{8}-/ { addr=$2; print name "|" local "|" remote "|" addr }
  ' "$NETPLAN_FILE"
}

list_tunnels_pretty() {
  local i=1
  list_tunnels_raw | while IFS='|' read -r name local remote addr; do
    echo "[$i] $name"
    echo "     Public : $local -> $remote"
    echo "     Private: $addr"
    echo
    i=$((i+1))
  done
}

show_tunnels() {
  hr
  echo -e "${BLUE}Show GRE tunnels${NC}"
  hr
  [ -f "$NETPLAN_FILE" ] || { warn "No tunnels file: $NETPLAN_FILE"; return; }

  local total
  total=$(list_tunnels_raw | wc -l || true)
  [ "${total:-0}" -eq 0 ] && { warn "No tunnels found"; return; }

  list_tunnels_pretty
}

delete_tunnels() {
  hr
  echo -e "${RED}Delete GRE tunnels${NC}"
  hr
  [ -f "$NETPLAN_FILE" ] || { warn "Nothing to delete"; return; }

  mapfile -t TUNNELS < <(list_tunnels_raw)
  local count="${#TUNNELS[@]}"
  [ "$count" -eq 0 ] && { warn "No tunnels found"; return; }

  list_tunnels_pretty

  echo "[0] Cancel"
  echo "[A] Delete ALL tunnels"
  read -rp "Select tunnel number: " sel

  case "$sel" in
    0|"") return ;;
    A|a)
      backup_netplan
      cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels: {}
EOF
      chmod 600 "$NETPLAN_FILE"
      netplan apply
      ok "All tunnels deleted"
      return
      ;;
  esac

  [[ "$sel" =~ ^[0-9]+$ ]] || { warn "Invalid selection"; return; }
  (( sel >= 1 && sel <= count )) || { warn "Out of range"; return; }

  local entry="${TUNNELS[$((sel-1))]}"
  local tname="${entry%%|*}"

  backup_netplan
  awk -v t="    $tname:" '
    BEGIN{del=0}
    $0==t {del=1; next}
    del && /^[[:space:]]{4}gre/ {del=0}
    !del {print}
  ' "$NETPLAN_FILE" > /tmp/gre.tmp

  mv /tmp/gre.tmp "$NETPLAN_FILE"
  chmod 600 "$NETPLAN_FILE"
  netplan apply
  ok "Deleted tunnel: $tname"
}

# ============================================================
# 1) IRAN (multi kharej)   => 10.10.x.1/30
# ============================================================
iran_multi_kharej() {
  clear; hr; echo "IRAN (multi kharej)"; hr
  local iran_pub count
  iran_pub="$(ask_ipv4 "Iran public IPv4" "$(get_public_ip)")"
  read -rp "How many kharej servers? " count
  [[ "$count" =~ ^[0-9]+$ ]] || die "Invalid number"

  backup_netplan
  write_header

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

  netplan apply
  ok "IRAN multi-kharej configured"
}

# ============================================================
# 2) IRAN (single kharej)  => 10.20.idx.1/30
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
# 3) KHAREJ (multi iran)   => 10.20.x.2/30
# ============================================================
kharej_multi_iran() {
  clear; hr; echo "KHAREJ (multi iran)"; hr
  local kharej_pub count
  kharej_pub="$(ask_ipv4 "Kharej public IPv4" "$(get_public_ip)")"
  read -rp "How many iran servers? " count
  [[ "$count" =~ ^[0-9]+$ ]] || die "Invalid number"

  backup_netplan
  write_header

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

  netplan apply
  ok "KHAREJ multi-iran configured"
}

# ============================================================
# 4) KHAREJ (single iran)  => 10.20.idx.2/30
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
ensure_reqs

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
  read -rp "Press Enter to return..." _ || true
done
