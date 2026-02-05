#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

echo "=== All in One - Optimization Status ==="
echo

echo "[BBR]"
sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc 2>/dev/null || true
echo

echo "[Swap]"
swapon --show || echo "No swap"
echo

echo "[UFW]"
ufw status verbose 2>/dev/null || echo "UFW not installed"
echo

echo "[Fail2Ban]"
systemctl is-active fail2ban 2>/dev/null || echo "fail2ban not installed"
echo

echo "[Sysctl files]"
ls -1 /etc/sysctl.d/99-all-in-one*.conf 2>/dev/null || echo "No All in One sysctl files found"
