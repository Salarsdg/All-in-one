#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
conf="/etc/systemd/journald.conf"
cp -a "$conf" "${conf}.bak.$(date +%s)" 2>/dev/null || true

if grep -qE '^\s*SystemMaxUse=' "$conf"; then
  sed -i -E 's|^\s*SystemMaxUse=.*|SystemMaxUse=200M|' "$conf"
else
  echo "SystemMaxUse=200M" >> "$conf"
fi

systemctl restart systemd-journald
echo "Journald limited to 200M. Backup: ${conf}.bak.*"
