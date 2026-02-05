#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
need_cmd sshd

cfg="/etc/ssh/sshd_config"
cp -a "$cfg" "${cfg}.bak.$(date +%s)"

apply_or_add() {
  local key="$1" value="$2"
  if grep -qE "^[#]*\s*${key}\s+" "$cfg"; then
    sed -i -E "s|^[#]*\s*${key}\s+.*|${key} ${value}|" "$cfg"
  else
    echo "${key} ${value}" >> "$cfg"
  fi
}

apply_or_add "UseDNS" "no"
apply_or_add "Compression" "yes"
apply_or_add "ClientAliveInterval" "300"
apply_or_add "ClientAliveCountMax" "2"
apply_or_add "TCPKeepAlive" "yes"
apply_or_add "MaxAuthTries" "4"
apply_or_add "MaxSessions" "10"
apply_or_add "AllowAgentForwarding" "no"
apply_or_add "X11Forwarding" "no"

sshd -t || die "sshd_config test failed. Restore backup: ${cfg}.bak.*"
systemctl restart ssh 2>/dev/null || systemctl restart sshd
echo "SSH recommended optimization applied. Backup: ${cfg}.bak.*"
