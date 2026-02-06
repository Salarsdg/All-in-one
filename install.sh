#!/usr/bin/env bash
set -Eeuo pipefail

REPO="https://raw.githubusercontent.com/Salarsdg/All-in-one/Stage"
DEST="/opt/aio"
BIN="/usr/local/bin/aio"

die(){ echo "[✘] $*" >&2; exit 1; }
info(){ echo "[i] $*"; }
ok(){ echo "[✔] $*"; }

[ "${EUID:-$(id -u)}" -eq 0 ] || die "Run with sudo"
command -v curl >/dev/null 2>&1 || die "curl not found"

info "Installing All-in-one to $DEST"
mkdir -p "$DEST"

FILES=(
  menu.sh
  optimize.sh
  ipv4-multi-single.sh
  ipv6-local-manager.sh
  update.sh
  README.md
)

for f in "${FILES[@]}"; do
  info "Downloading $f"
  curl -fsSL "$REPO/$f" | tr -d '\r' > "$DEST/$f"
done

chmod +x "$DEST"/*.sh

# create launcher
cat > "$BIN" <<'EOF'
#!/usr/bin/env bash
exec sudo bash /opt/aio/menu.sh
EOF
chmod +x "$BIN"

ok "Installed successfully"
echo "Run with: sudo aio"
