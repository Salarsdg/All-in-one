#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root

echo "This will run the recommended optimizations in order:"
echo "  1) Enable BBR"
echo "  2) Network Optimization (Recommended)"
echo "  3) SSH Optimization (Recommended)"
echo "  4) System Limits Optimization"
echo "  5) Disable Terminal Ads"
echo "  6) Limit Journald Disk Usage"
echo
read -rp "Continue? (y/n): " yn
[[ "${yn:-n}" =~ ^[Yy]$ ]] || { echo "Canceled."; exit 0; }

bash "$BASE_DIR/modules/bbr.sh"
bash "$BASE_DIR/modules/opt_network_recommended.sh"
bash "$BASE_DIR/modules/opt_ssh_recommended.sh"
bash "$BASE_DIR/modules/opt_limits.sh"
bash "$BASE_DIR/modules/disable_ads.sh"
bash "$BASE_DIR/modules/journald_limit.sh"

echo
echo "Recommended optimizations applied."
echo "Status:"
bash "$BASE_DIR/modules/opt_status.sh"
echo
read -rp "Reboot recommended. Reboot now? (y/n): " rb
if [[ "${rb:-n}" =~ ^[Yy]$ ]]; then
  reboot
fi
