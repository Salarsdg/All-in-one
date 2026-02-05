#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
echo "1) Tail All in One log"
echo "2) Journalctl (last 200 lines)"
read -rp "Choice: " c
case "${c:-}" in
  1) tail -n 200 -f "$BASE_DIR/logs/all-in-one.log" ;;
  2) journalctl -n 200 --no-pager ;;
  *) echo "Invalid" ;;
esac
