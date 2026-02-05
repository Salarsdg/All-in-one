#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
apt_install fail2ban
systemctl enable --now fail2ban
fail2ban-client status 2>/dev/null || true
echo "Fail2Ban installed & enabled."
