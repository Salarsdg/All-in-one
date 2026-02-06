#!/usr/bin/env bash
set -Eeuo pipefail

NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE="/etc/netplan/99-gre.yaml"

# ---------------- UI ----------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

hr() { printf "%b\n" "${BLUE}------------------------------------------------------------${NC}"; }
die() { echo -e "${RED}[✘] $*${NC}" >&2; exit 1; }
ok()  { echo -e "${GREEN}[✔] $*${NC}"; }
info(){ echo -e "${BLUE}[i] $*${NC}"; }
warn(){ echo -e "${YELLOW}[!] $*${NC}"; }

trap 'die "Error on line $LINENO"' ERR

# ---------------- Root check ----------------
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  die "Run this script as root"
fi

# ---------------- Install requirements ----------------
ensure_reqs() {
  info "Checking requirements..."
  if ! command -v netplan >/dev/null 2>&1; then
    info "Installing netplan.io..."
    apt update -y
    apt install -y netplan.io
  fi

  mkdir -p "$NETPLAN_DIR"

  info "Ensuring systemd-networkd is enabled..."
  systemctl unmask systemd-networkd.service || true
  systemctl unmask systemd-networkd.socket || true
  systemctl enable systemd-networkd.service
  systemctl start systemd-networkd.service
}

# ---------------- Helpers ----------------
get_public_ip() {
  local ip=""
  for svc in \
    "https://api.ipify.org" \
    "https://ipv4.icanhazip.com"
  do
    ip="$(curl -4 -s --max-time 5 "$svc" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' || true)"
    [ -n "$ip" ] && echo "$ip" && return 0
  done
  echo ""
}

ask_non_empty() {
  local v
  while true; do
    read -rp "$1" v
    [ -n "${v:-}" ] && echo "$v" && return 0
    echo "ERROR: value cannot be empty"
  done
}

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
  local prompt="$1" default="${2:-}"
  local v
  while true; do
    if [ -n "$default" ]; then
      read -rp "$prompt [$default]: " v
      v="${v:-$default}"
    else
      read -rp "$prompt: " v
    fi
    valid_ipv4 "$v" && echo "$v" && return 0
    echo "Invalid IPv4. Try again."
  done
}

backup_netplan() {
  mkdir -p "$NETPLAN_DIR/aio-backup"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  if [ -f "$NETPLAN_FILE" ]; then
    cp -f "$NETPLAN_FILE" "$NETPLAN_DIR/aio-backup/99-gre.yaml.$ts.bak"
    ok "Backup saved: $NETPLAN_DIR/aio-backup/99-gre.yaml.$ts.bak"
  fi
}

# Compute peer from /30 (only for common 10.10.x.y/30 style)
peer_from_30() {
  local cidr="${1:-}"
  local ip="${cidr%%/*}"
  local mask="${cidr##*/}"
  [ "$mask" = "30" ] || { echo "?"; return 0; }
  IFS='.' read -r a b c d <<< "$ip"
  [[ "$d" =~ ^[0-9]+$ ]] || { echo "?"; return 0; }
  if [ "$d" = "1" ]; then
    echo "${a}.${b}.${c}.2/30"
  elif [ "$d" = "2" ]; then
    echo "${a}.${b}.${c}.1/30"
  else
    # generic: flip last bit inside /30 block (not perfect but ok)
    if (( d % 4 == 1 )); then
      echo "${a}.${b}.${c}.$((d+1))/30"
    elif (( d % 4 == 2 )); then
      echo "${a}.${b}.${c}.$((d-1))/30"
    else
      echo "?"
    fi
  fi
}

# Parse tunnels from NETPLAN_FILE
# Output lines: name|local|remote|addr1,addr2
list_tunnels() {
  [ -f "$NETPLAN_FILE" ] || return 0

  awk '
  BEGIN{in_tun=0; name=""; local=""; remote=""; addrs=""}
  function flush() {
    if (name != "") {
      gsub(/^,|,$/,"",addrs)
      print name "|" local "|" remote "|" addrs
    }
    name=""; local=""; remote=""; addrs=""
  }
  /^[[:space:]]*tunnels:[[:space:]]*$/ {in_tun=1; next}
  in_tun==1 && /^[[:space:]]{4}[A-Za-z0-9_-]+:[[:space:]]*$/ {
    flush()
    line=$0
    sub(/^[[:space:]]{4}/,"",line)
    sub(/:[[:space:]]*$/,"",line)
    name=line
    next
  }
  in_tun==1 && name!="" && /^[[:space:]]{6}local:[[:space:]]*/ {
    local=$0; sub(/^[[:space:]]{6}local:[[:space:]]*/,"",local); next
  }
  in_tun==1 && name!="" && /^[[:space:]]{6}remote:[[:space:]]*/ {
    remote=$0; sub(/^[[:space:]]{6}remote:[[:space:]]*/,"",remote); next
  }
  in_tun==1 && name!="" && /^[[:space:]]{8}-[[:space:]]*/ {
    a=$0; sub(/^[[:space:]]{8}-[[:space:]]*/,"",a)
    if (addrs=="") addrs=a; else addrs=addrs "," a
    next
  }
  END{flush()}
  ' "$NETPLAN_FILE"
}

show_tunnels() {
  hr
  echo -e "${BLUE}Show tunnels (from: $NETPLAN_FILE)${NC}"
  hr

  local lines
  lines="$(list_tunnels || true)"
  if [ -z "${lines:-}" ]; then
    warn "No tunnels found."
    return 0
  fi

  local idx=0
  while IFS='|' read -r name local remote addrs; do
    idx=$((idx+1))
    echo -e "${GREEN}[$idx]${NC} ${YELLOW}${name}${NC}"
    echo -e "    Public:  ${BLUE}${local}${NC}  ->  ${BLUE}${remote}${NC}"
    # Show each address + peer
    IFS=',' read -ra arr <<< "${addrs:-}"
    for a in "${arr[@]}"; do
      a="$(echo "$a" | xargs)"
      [ -z "$a" ] && continue
      peer="$(peer_from_30 "$a")"
      echo -e "    Private: ${GREEN}${a}${NC}  <->  ${GREEN}${peer}${NC}"
    done
    echo
  done <<< "$lines"
}

delete_tunnel() {
  [ -f "$NETPLAN_FILE" ] || { warn "No netplan tunnel file found: $NETPLAN_FILE"; return 0; }

  local lines
  lines="$(list_tunnels || true)"
  if [ -z "${lines:-}" ]; then
    warn "No tunnels to delete."
    return 0
  fi

  show_tunnels

  echo -e "${YELLOW}Delete options:${NC}"
  echo "1) Delete ONE tunnel by name (e.g., gre1)"
  echo "2) Delete ALL tunnels in this file"
  echo "0) Back"
  read -rp "Select: " dopt

  case "$dopt" in
    1)
      read -rp "Enter tunnel name to delete (example: gre1): " tname
      [ -n "${tname:-}" ] || { warn "Empty name"; return 0; }

      # Verify exists
      if ! printf "%s\n" "$lines" | cut -d'|' -f1 | grep -qx "$tname"; then
        warn "Tunnel '$tname' not found."
        return 0
      fi

      backup_netplan

      # Remove YAML block for this tunnel: from "    name:" until next "    other:" or end of file
      # Works for typical netplan indentation.
      local tmp
      tmp="$(mktemp)"
      awk -v t="    '"$tname"':" -v t2="    "$tname":" '
        BEGIN{del=0}
        {
          if ($0==t || $0==t2) {del=1; next}
          if (del==1 && $0 ~ /^[[:space:]]{4}[A-Za-z0-9_-]+:[[:space:]]*$/) {del=0}
          if (del==0) print
        }
      ' "$NETPLAN_FILE" > "$tmp"

      # If file becomes empty-ish, keep minimal netplan skeleton
      if ! grep -qE '^[[:space:]]{4}[A-Za-z0-9_-]+:[[:space:]]*$' "$tmp"; then
        cat > "$tmp" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels: {}
EOF
      fi

      install -m 600 "$tmp" "$NETPLAN_FILE"
      rm -f "$tmp"

      netplan apply
      ok "Deleted tunnel: $tname"
      ;;
    2)
      backup_netplan
      cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels: {}
EOF
      chmod 600 "$NETPLAN_FILE"
      netplan apply
      ok "Deleted ALL tunnels from $NETPLAN_FILE"
      ;;
    0) return 0 ;;
    *) warn "Invalid option" ;;
  esac
}

# ---------------- Create tunnels ----------------
create_iran() {
  hr
  echo -e "${BLUE}IRAN MODE (multi-kharej)${NC}"
  hr

  local auto_ip iran_pub count

  auto_ip="$(get_public_ip || true)"
  if [ -n "${auto_ip:-}" ]; then
    iran_pub="$(ask_ipv4 "Enter IRAN public IPv4 (auto-detected)" "$auto_ip")"
  else
    iran_pub="$(ask_ipv4 "Enter IRAN public IPv4")"
  fi

  read -rp "How many kharej servers? " count
  [[ "$count" =~ ^[0-9]+$ ]] || die "Invalid number"

  backup_netplan

  cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  tunnels:
EOF

  declare -a SUMMARY=()

  for ((i=1;i<=count;i++)); do
    echo
    echo "Kharej #$i"
    local kharej_pub
    kharej_pub="$(ask_ipv4 "  Enter kharej public IPv4")"

    local iran_gre="10.10.${i}.1/30"
    local kharej_gre="10.10.${i}.2/30"

    cat >> "$NETPLAN_FILE" <<EOF
    gre$i:
      mode: gre
      local: $iran_pub
      remote: $kharej_pub
      addresses:
        - $iran_gre
      mtu: 1476
EOF

    SUMMARY+=(
"Kharej #$i
  Tunnel name     : gre$i
  Public (Iran)   : $iran_pub
  Public (Kharej) : $kharej_pub
  Private (Iran)  : $iran_gre
  Private (Kharej): $kharej_gre"
    )
  done

  chmod 600 "$NETPLAN_FILE"
  netplan apply

  ok "IRAN configuration completed"
  for s in "${SUMMARY[@]}"; do
    echo
    echo "$s"
  done
}

create_kharej() {
  hr
  echo -e "${BLUE}KHAREJ MODE${NC}"
  hr

  local idx auto_ip kharej_pub iran_pub kharej_gre

  read -rp "Enter tunnel index (given by Iran): " idx
  [[ "$idx" =~ ^[0-9]+$ ]] || die "Invalid index"

  auto_ip="$(get_public_ip || true)"
  if [ -n "${auto_ip:-}" ]; then
    kharej_pub="$(ask_ipv4 "Enter KHAREJ public IPv4 (auto-detected)" "$auto_ip")"
  else
    kharej_pub="$(ask_ipv4 "Enter KHAREJ public IPv4")"
  fi

  iran_pub="$(ask_ipv4 "Enter IRAN public IPv4")"
  kharej_gre="10.10.${idx}.2/30"

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
        - $kharej_gre
      mtu: 1476
EOF

  chmod 600 "$NETPLAN_FILE"
  netplan apply

  ok "KHAREJ configuration completed"
  echo "Tunnel gre$idx is up"
}

main_menu() {
  ensure_reqs

  while true; do
    echo
    hr
    echo -e "${BLUE}GRE / Netplan - IPv4 Tunnel Manager${NC}"
    hr
    echo "1) Create tunnels (Iran mode - multi kharej)"
    echo "2) Create tunnel (Kharej mode)"
    echo "3) Show tunnels"
    echo "4) Delete tunnels"
    echo "0) Exit"
    read -rp "Select: " c

    case "$c" in
      1) create_iran ;;
      2) create_kharej ;;
      3) show_tunnels ;;
      4) delete_tunnel ;;
      0) exit 0 ;;
      *) warn "Invalid choice" ;;
    esac
  done
}

main_menu
