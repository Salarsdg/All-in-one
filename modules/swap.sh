#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$BASE_DIR/lib/utils.sh"

require_root
read -rp "Swap size in GB (e.g. 2): " gb
[[ "$gb" =~ ^[0-9]+$ ]] || die "Invalid number."

swapfile="/swapfile"
swapoff -a 2>/dev/null || true
rm -f "$swapfile"

fallocate -l "${gb}G" "$swapfile" || dd if=/dev/zero of="$swapfile" bs=1G count="$gb"
chmod 600 "$swapfile"
mkswap "$swapfile"
swapon "$swapfile"
grep -q "^/swapfile" /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab

echo "Swap enabled: ${gb}G"
