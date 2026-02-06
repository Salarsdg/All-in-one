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

mkdir -p "$DEST"

# -------- Required files --------
REQUIRED=(
  menu.sh
  optimize.sh
  ipv4-multi-single.sh
  ipv6-local-manager.sh
)

OPTIONAL=(
  update.sh
)

download() {
  curl -fsSL "$REPO/$1?nocache=$(date +%s)" | tr -d '\r' > "$DEST/$1"
}

info "Downloading required files..."
for f in "${REQUIRED[@]}"; do
  info "  - $f"
  download "$f"
done

info "Downloading optional files..."
for f in "${OPTIONAL[@]}"; do
  info "  - $f (optional)"
  download "$f" || true
done

# compat update.sh
if [ ! -f "$DEST/update.sh" ]; then
  cat > "$DEST/update.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
bash "$DIR/optimize.sh"
EOF
fi

# -------- aio-update.sh --------
cat > "$DEST/aio-update.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO="https://raw.githubusercontent.com/Salarsdg/All-in-one/Stage"
DEST="/opt/aio"

[ "$EUID" -eq 0 ] || exec sudo "$0" "$@"

FILES=(
  menu.sh
  optimize.sh
  ipv4-multi-single.sh
  ipv6-local-manager.sh
  update.sh
)

echo "[i] Updating All-in-one..."
for f in "${FILES[@]}"; do
  echo "  - $f"
  curl -fsSL "$REPO/$f?nocache=$(date +%s)" | tr -d '\r' > "$DEST/$f" || true
done

chmod +x "$DEST"/*.sh
echo "[✔] Update completed"
EOF

chmod +x "$DEST"/*.sh

# -------- launcher --------
cat > "$BIN" <<'EOF'
#!/usr/bin/env bash
AIO="/opt/aio"

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

case "${1:-}" in
  update)
    exec bash "$AIO/aio-update.sh"
    ;;
  ""|menu)
    exec bash "$AIO/menu.sh"
    ;;
  *)
    echo "Usage:"
    echo "  aio        -> run menu"
    echo "  aio update -> update scripts"
    exit 1
    ;;
esac
EOF

chmod +x "$BIN"

ok "Installed successfully"
echo "Run: sudo aio"
echo "Update: sudo aio update"
