#!/usr/bin/env bash
set -Eeuo pipefail

# -------- UI --------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

hr(){ printf "%b\n" "${BLUE}============================================================${NC}"; }
title(){
  clear || true
  hr
  echo -e "${BOLD}${CYAN}All-in-one Menu${NC}"
  echo -e "${YELLOW}Safe, clean, LF-only scripts (no CRLF)${NC}"
  hr
}
info(){ echo -e "${CYAN}[i]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; }
die(){ echo -e "${RED}[✘]${NC} $*" >&2; exit 1; }

require_root(){
  [ "${EUID:-$(id -u)}" -eq 0 ] || die "Please run as root"
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
OPTIMIZE="$SCRIPT_DIR/optimize.sh"
IPV4="$SCRIPT_DIR/ipv4-multi-single.sh"

run_local(){
  local f="$1"
  [ -f "$f" ] || die "File not found: $f"
  chmod +x "$f" >/dev/null 2>&1 || true
  bash "$f"
}

run_remote_safe(){
  # runs a remote script but strips CRLF just in case
  local url="$1"
  command -v curl >/dev/null 2>&1 || die "curl not found"
  bash <(curl -fsSL "$url" | tr -d '\r')
}

require_root

while true; do
  title
  echo -e "${GREEN}1)${NC} System Optimize  (update + packages + sysctl + limits)"
  echo -e "${GREEN}2)${NC} IPv6 Local Manager (create/show/delete tunnel)"
  echo -e "${GREEN}3)${NC} IPv4 GRE Manager (create/show/delete tunnels)"
  echo -e "${GREEN}0)${NC} Exit"
  hr
  read -rp "Select: " choice
  case "${choice:-}" in
    1) run_local "$OPTIMIZE" ;;
    2) run_local "$SCRIPT_DIR/ipv6-local-manager.sh" ;;
    3) run_local "$IPV4" ;;
    0) exit 0 ;;
    *) warn "Invalid choice" ;;
  esac
  echo
  read -rp "Press Enter to continue..." _ || true
done
