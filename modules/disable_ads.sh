#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news 2>/dev/null || true
command -v pro >/dev/null 2>&1 && pro config set apt_news=false || true
echo "Terminal ads disabled."
