#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
apt_install ufw

ufw default deny incoming
ufw default allow outgoing

read -rp "Allow SSH port (default 22): " sshp
sshp="${sshp:-22}"
ufw allow "${sshp}/tcp"

read -rp "Allow HTTP/HTTPS? (y/n): " web
if [[ "${web:-n}" =~ ^[Yy]$ ]]; then
  ufw allow 80/tcp
  ufw allow 443/tcp
fi

ufw --force enable
ufw status verbose
