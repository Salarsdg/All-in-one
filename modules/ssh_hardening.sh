#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
need_cmd sshd

cfg="/etc/ssh/sshd_config"
cp -a "$cfg" "${cfg}.bak.$(date +%s)"

read -rp "Change SSH port? (enter number or blank to skip): " port
if [[ -n "${port:-}" ]]; then
  [[ "$port" =~ ^[0-9]+$ ]] || die "Invalid port."
  if grep -qE "^[#]*\s*Port\s+" "$cfg"; then
    sed -i -E "s|^[#]*\s*Port\s+.*|Port ${port}|" "$cfg"
  else
    echo "Port ${port}" >> "$cfg"
  fi
fi

read -rp "Disable root login? (y/n): " disroot
if [[ "${disroot:-n}" =~ ^[Yy]$ ]]; then
  if grep -qE "^[#]*\s*PermitRootLogin\s+" "$cfg"; then
    sed -i -E "s|^[#]*\s*PermitRootLogin\s+.*|PermitRootLogin no|" "$cfg"
  else
    echo "PermitRootLogin no" >> "$cfg"
  fi
fi

sshd -t || die "sshd_config test failed. Restore backup: ${cfg}.bak.*"
systemctl restart ssh 2>/dev/null || systemctl restart sshd
echo "SSH hardening applied. Backup: ${cfg}.bak.*"
