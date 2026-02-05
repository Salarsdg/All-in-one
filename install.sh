#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${REPO:-Salarsdg/All-in-one}"
BRANCH="${BRANCH:-Stage}"
INSTALL_DIR="${INSTALL_DIR:-/opt/all-in-one}"

die(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing: $1"; }

[[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root: sudo bash -c '...'"
need curl
need tar

url="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

curl -fLsS "$url" -o repo.tar.gz || die "Download failed (repo/branch?)"
tar -xzf repo.tar.gz || die "Extract failed"
src="$(find . -maxdepth 1 -type d -name 'All-in-one-*' | head -n 1)"
[[ -n "${src:-}" ]] || die "Extract folder not found"

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -a "$src"/. "$INSTALL_DIR"/

chmod +x "$INSTALL_DIR/main.sh" || true
chmod +x "$INSTALL_DIR/lib/"*.sh 2>/dev/null || true
chmod +x "$INSTALL_DIR/modules/"*.sh 2>/dev/null || true

ln -sf "$INSTALL_DIR/main.sh" /usr/local/bin/all-in-one || true
echo "Installed. Run: sudo all-in-one"
bash "$INSTALL_DIR/main.sh"
