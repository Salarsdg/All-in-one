#!/usr/bin/env bash
set -Eeuo pipefail

REPO="https://raw.githubusercontent.com/Salarsdg/All-in-one/Stage"
DEST="/opt/aio"

die(){ echo "[✘] $*" >&2; exit 1; }
info(){ echo "[i] $*"; }
ok(){ echo "[✔] $*"; }

[ "${EUID:-$(id -u)}" -eq 0 ] || die "Run with sudo"
command -v curl >/dev/null 2>&1 || die "curl not found"

FILES=(
  menu.sh
  optimize.sh
  ipv4-multi-single.sh
  ipv6-local-manager.sh
  update.sh
  README.md
)

for f in "${FILES[@]}"; do
  info "Updating $f"
  curl -fsSL "$REPO/$f?nocache=$(date +%s)" | tr -d '\r' > "$DEST/$f"
done

chmod +x "$DEST"/*.sh
ok "Update completed"
