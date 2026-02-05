#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
apt_install ca-certificates curl wget git nano unzip zip htop jq lsof ufw fail2ban socat cron bash-completion locales net-tools iproute2 dnsutils certbot
echo "Essentials installed."
