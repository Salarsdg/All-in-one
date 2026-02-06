#!/usr/bin/env bash
set -Eeuo pipefail

NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE="/etc/netplan/99-sit.yaml"
SYSTEMD_DIR="/etc/systemd/network"
SYSTEMD_FILE="/etc/systemd/network/99-sit.network"

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

# ---------------- Root check ----------------
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  die "Run this script as root"
fi

# ---------------- Helpers ----------------
valid_ipv4() {
  local ip="${1:-}"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local o1 o2 o3 o4
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
  for o in "$o1" "$o2" "$o3" "$o4"; do
    [[ "$o" =~ ^[0-9]+$ ]] || return 1
    ((o >= 0 && o <= 255)) || return 1
  done
  return 0
}

ask_ipv4() {
  local prompt="$1" v
  while true; do
    read -rp "$prompt: " v
    valid_ipv4 "$v" && echo "$v" && return 0
    echo "Invalid IPv4. Try again."
  done
}

valid_ipv6() {
  local ip="${1:-}"
  [[ "$ip" =~ ^[0-9a-fA-F:]+$ ]] || return 1
  [[ "$ip" == *:* ]] || return 1
  return 0
}

ask_ipv6() {
  local prompt="$1" v
  while true; do
    read -rp "$prompt (example: 2001:db8:abcd::1): " v
    valid_ipv6 "$v" && echo "$v" && return 0
    echo "Invalid IPv6. Try again."
  done
}

ensure_reqs() {
  info "Checking requirements..."
  if ! command -v netplan >/dev/null 2>&1; then
    info "Installing netplan.io..."
    apt update -y
    apt install -y netplan.io
  fi

  mkdir -p "$NETPLAN_DIR" "$SYSTEMD_DIR"

  info "Ensuring systemd-networkd is enabled..."
  systemctl unmask systemd-networkd.service >/dev/null 2>&1 || true
  systemctl unmask systemd-networkd.socket  >/dev/null 2>&1 || true
  systemctl enable systemd-networkd.service >/dev/null 2>&1 || true
  systemctl start systemd-networkd.service  >/dev/null 2>&1 || true
}

backup_files() {
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$NETPLAN_DIR/aio-backup" "$SYSTEMD_DIR/aio-backup"
  [ -f "$NETPLAN_FILE" ] && cp -f "$NETPLAN_FILE" "$NETPLAN_DIR/aio-backup/$(basename "$NETPLAN_FILE").$ts.bak" && ok "Backup: $NETPLAN_DIR/aio-backup/$(basename "$NETPLAN_FILE").$ts.bak"
  [ -f "$SYSTEMD_FILE" ] && cp -f "$SYSTEMD_FILE" "$SYSTEMD_DIR/aio-backup/$(basename "$SYSTEMD_FILE").$ts.bak" && ok "Backup: $SYSTEMD_DIR/aio-backup/$(basename "$SYSTEMD_FILE").$ts.bak"
}

# ---------------- Show tunnel ----------------
show_tunnel() {
  hr
  echo -e "${BLUE}Show IPv6 (SIT) tunnel${NC}"
  echo -e "Netplan: ${YELLOW}$NETPLAN_FILE${NC}"
  echo -e "Systemd: ${YELLOW}$SYSTEMD_FILE${NC}"
  hr

  if [ ! -f "$NETPLAN_FILE" ]; then
    warn "No tunnel netplan file found."
    return 0
  fi

  local name mode local4 remote4 mtu addrs
  name="$(awk '/^[[:space:]]{4}[A-Za-z0-9_-]+:/{gsub(":","",$1); print $1; exit}' "$NETPLAN_FILE" 2>/dev/null || true)"
  mode="$(awk '/^[[:space:]]{6}mode:/{print $2; exit}' "$NETPLAN_FILE" 2>/dev/null || true)"
  local4="$(awk '/^[[:space:]]{6}local:/{print $2; exit}' "$NETPLAN_FILE" 2>/dev/null || true)"
  remote4="$(awk '/^[[:space:]]{6}remote:/{print $2; exit}' "$NETPLAN_FILE" 2>/dev/null || true)"
  mtu="$(awk '/^[[:space:]]{6}mtu:/{print $2; exit}' "$NETPLAN_FILE" 2>/dev/null || true)"
  addrs="$(awk '/^[[:space:]]{8}-/{print $2}' "$NETPLAN_FILE" 2>/dev/null | paste -sd',' - || true)"

  [ -z "${name:-}" ] && name="local"
  [ -z "${mode:-}" ] && mode="sit"

  echo -e "${GREEN}Tunnel:${NC} ${YELLOW}${name}${NC}  (mode: ${mode})"
  echo -e "${GREEN}Public IPv4:${NC}  ${BLUE}${local4}${NC}  ->  ${BLUE}${remote4}${NC}"
  echo -e "${GREEN}IPv6 addresses:${NC} ${CYAN}${addrs:-?}${NC}"
  echo -e "${GREEN}MTU:${NC} ${mtu:-?}"
  echo

  if [ -f "$SYSTEMD_FILE" ]; then
    local gw addr
    addr="$(awk -F= '/^Address=/{print $2; exit}' "$SYSTEMD_FILE" 2>/dev/null || true)"
    gw="$(awk -F= '/^Gateway=/{print $2; exit}' "$SYSTEMD_FILE" 2>/dev/null || true)"
    echo -e "${GREEN}Systemd network:${NC}"
    echo -e "  Address: ${CYAN}${addr:-?}${NC}"
    echo -e "  Gateway: ${CYAN}${gw:-?}${NC}"
  else
    warn "Systemd network file not found (optional)."
  fi

  hr
}

# ---------------- Create tunnel ----------------
create_iran() {
  hr
  echo -e "${BLUE}IRAN MODE (SIT IPv6 over IPv4)${NC}"
  hr

  local iran4 kharej4 iran6 kharej6
  iran4="$(ask_ipv4 "Enter IRAN public IPv4")"
  kharej4="$(ask_ipv4 "Enter KHAREJ public IPv4")"
  iran6="$(ask_ipv6 "Enter IRAN IPv6 (local on tunnel)")"
  kharej6="$(ask_ipv6 "Enter KHAREJ IPv6 (peer/gateway)")"

  backup_files

  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  tunnels:
    local:
      mode: sit
      local: $iran4
      remote: $kharej4
      addresses:
        - ${iran6}/64
      mtu: 1500
EOF
  chmod 600 "$NETPLAN_FILE"

  cat > "$SYSTEMD_FILE" <<EOF
[Network]
Address=${iran6}/64
Gateway=${kharej6}
EOF

  netplan apply
  systemctl restart systemd-networkd >/dev/null 2>&1 || true

  ok "IPv6 local tunnel configured (Iran mode)"
  show_tunnel
}

create_kharej() {
  hr
  echo -e "${BLUE}KHAREJ MODE (SIT IPv6 over IPv4)${NC}"
  hr

  local kharej4 iran4 kharej6 iran6
  kharej4="$(ask_ipv4 "Enter KHAREJ public IPv4")"
  iran4="$(ask_ipv4 "Enter IRAN public IPv4")"
  kharej6="$(ask_ipv6 "Enter KHAREJ IPv6 (local on tunnel)")"
  iran6="$(ask_ipv6 "Enter IRAN IPv6 (peer/gateway)")"

  backup_files

  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  tunnels:
    local:
      mode: sit
      local: $kharej4
      remote: $iran4
      addresses:
        - ${kharej6}/64
      mtu: 1500
EOF
  chmod 600 "$NETPLAN_FILE"

  cat > "$SYSTEMD_FILE" <<EOF
[Network]
Address=${kharej6}/64
Gateway=${iran6}
EOF

  netplan apply
  systemctl restart systemd-networkd >/dev/null 2>&1 || true

  ok "IPv6 local tunnel configured (Kharej mode)"
  show_tunnel
}

# ---------------- Delete tunnel ----------------
delete_tunnel() {
  hr
  echo -e "${BLUE}Delete IPv6 (SIT) tunnel${NC}"
  hr

  if [ ! -f "$NETPLAN_FILE" ] && [ ! -f "$SYSTEMD_FILE" ]; then
    warn "Nothing to delete."
    return 0
  fi

  show_tunnel
  echo -e "${YELLOW}This will remove:${NC}"
  echo " - $NETPLAN_FILE"
  echo " - $SYSTEMD_FILE"
  echo
  read -rp "Type YES to delete: " ans
  if [ "${ans:-}" != "YES" ]; then
    warn "Canceled."
    return 0
  fi

  backup_files
  rm -f "$NETPLAN_FILE" "$SYSTEMD_FILE" || true

  netplan apply >/dev/null 2>&1 || true
  systemctl restart systemd-networkd >/dev/null 2>&1 || true
  ok "Tunnel deleted."
}

main_menu() {
  ensure_reqs
  while true; do
    clear
    echo
    hr
    echo -e "${BLUE}IPv6 Local Manager (SIT)${NC}"
    hr
    echo "1) Create tunnel (Iran mode)"
    echo "2) Create tunnel (Kharej mode)"
    echo "3) Show tunnel"
    echo "4) Delete tunnel"
    echo "0) Exit"
    read -rp "Select: " c
    case "${c:-}" in
      1)
      create_iran
      read -rp "Press Enter to return..." _
      ;;
      2)
      create_kharej
      read -rp "Press Enter to return..." _
      ;;
      3)
      show_tunnel
      echo
      read -rp "Press Enter to return..." _
      ;;
      4)
      delete_tunnel
      read -rp "Press Enter to return..." _
      ;;
      0) exit 0 ;;
      *) warn "Invalid option"; sleep 1 ;;
    esac

  done
}

main_menu
