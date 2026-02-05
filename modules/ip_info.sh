#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

need_cmd ip
apt_install curl >/dev/null 2>&1 || true

echo "Local Interfaces:"
ip -br a

echo
echo "Public IPv4:"
curl -4 -fsS --max-time 5 https://api.ipify.org || true
echo

echo "Public IPv6:"
curl -6 -fsS --max-time 5 https://api64.ipify.org || true
echo
