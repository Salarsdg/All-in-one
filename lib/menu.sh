#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck disable=SC1091
source "$BASE_DIR/lib/utils.sh"

run_module() {
  local mod="$1"
  if [[ ! -x "$BASE_DIR/modules/$mod" ]]; then
    die "Module not found: $mod"
  fi
  bash "$BASE_DIR/modules/$mod"
}

main_menu() {
  while true; do
    clear
    echo -e "${BOLD}${APP_NAME}${NC}"
    echo "--------------------------------"
    echo "1) Update system + install common packages"
    echo "2) Webserver menu (Apache/PHP + sites)"
    echo "3) GRE IPv4 netplan setup (Iran/Kharej)"
    echo "0) Exit"
    echo
    read -rp "Enter your choice: " choice

    case "${choice:-}" in
      1) run_module "update.sh"; pause ;;
      2) run_module "webserver_menu.sh";;
      3) run_module "gre_ipv4.sh"; pause ;;
      0) exit 0 ;;
      *) warn "Invalid choice"; sleep 1 ;;
    esac
  done
}
