#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
limits="/etc/security/limits.d/99-all-in-one.conf"
sysctlfile="/etc/sysctl.d/99-all-in-one-limits.conf"

cat > "$limits" <<'EOF'
# All in One - System Limits (Recommended)
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

cat > "$sysctlfile" <<'EOF'
# All in One - fs limits (Recommended)
fs.file-max=1048576
EOF

sysctl --system >/dev/null
echo "Limits applied:"
echo " - $limits"
echo " - $sysctlfile"
echo "Note: re-login is recommended for some limits to take effect."
