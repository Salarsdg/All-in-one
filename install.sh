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

fetch() {
  local f="$1"
  if curl -fsSL "$REPO/$f" | tr -d '\r' > "$DEST/$f"; then
    return 0
  else
    warn_missing "$f"
    return 1
  fi
}

warn_missing(){ echo "[!] Missing on Stage (skipped): $1"; }

# فایل‌های ضروری
REQUIRED=(
  menu.sh
  optimize.sh
  ipv4-multi-single.sh
  ipv6-local-manager.sh
  README.md
)

# فایل‌های اختیاری (اگر نبود، نصب ادامه پیدا کنه)
OPTIONAL=(
  update.sh
)

for f in "${REQUIRED[@]}"; do
  info "Downloading $f"
  curl -fsSL "$REPO/$f" | tr -d '\r' > "$DEST/$f"
done

for f in "${OPTIONAL[@]}"; do
  info "Downloading $f (optional)"
  fetch "$f" || true
done

chmod +x "$DEST"/*.sh || true

# اگر update.sh نبود، یکی بساز که optimize رو اجرا کنه (سازگاری)
if [ ! -f "$DEST/update.sh" ]; then
  cat > "$DEST/update.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
bash "$SCRIPT_DIR/optimize.sh"
EOF
  chmod +x "$DEST/update.sh"
fi

# ساخت launcher
cat > "$BIN" <<'EOF'
#!/usr/bin/env bash
exec sudo bash /opt/aio/menu.sh
EOF
chmod +x "$BIN"

ok "Installed successfully"
echo "Run with: sudo aio"
