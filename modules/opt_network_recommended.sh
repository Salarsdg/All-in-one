#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
f="/etc/sysctl.d/99-all-in-one.conf"
cp -a "$f" "${f}.bak.$(date +%s)" 2>/dev/null || true

cat > "$f" <<'EOF'
# All in One - Network Optimization (Recommended)
net.core.default_qdisc=fq
net.core.somaxconn=65535
net.core.netdev_max_backlog=16384
net.ipv4.tcp_fin_timeout=25
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=5
EOF

sysctl --system >/dev/null
echo "Applied: $f"
