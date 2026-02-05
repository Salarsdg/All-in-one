#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/lib/utils.sh"

require_root

while true; do
  clear
  echo -e "${BOLD}Webserver Menu${NC}"
  echo "----------------"
  echo "1) Install Apache + PHP + SSL for a domain"
  echo "2) Add a new Apache site + SSL"
  echo "0) Back"
  echo
  read -rp "Enter your choice: " choice

  case "${choice:-}" in
    1) bash "$BASE_DIR/modules/install_apache_php.sh"; pause ;;
    2) bash "$BASE_DIR/modules/add_site.sh"; pause ;;
    0) exit 0 ;;
    *) warn "Invalid choice"; sleep 1 ;;
  esac
done
