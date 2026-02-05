#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DEFAULT="Salarsdg/All-in-one"
BRANCH_DEFAULT="Stage"
INSTALL_DIR_DEFAULT="/opt/all-in-one"

REPO="${REPO:-$REPO_DEFAULT}"
BRANCH="${BRANCH:-$BRANCH_DEFAULT}"
INSTALL_DIR="${INSTALL_DIR:-$INSTALL_DIR_DEFAULT}"

COLOR() { [[ -t 1 ]] && printf '\e[%sm' "$1" || true; }
RED="$(COLOR 31)"; GRN="$(COLOR 32)"; YLW="$(COLOR 33)"; BLU="$(COLOR 34)"; NC="$(COLOR 0)"

die(){ echo -e "${RED}ERROR:${NC} $*" >&2; exit 1; }
info(){ echo -e "${BLU}INFO:${NC} $*"; }
ok(){ echo -e "${GRN}OK:${NC} $*"; }
warn(){ echo -e "${YLW}WARN:${NC} $*"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Run as root: sudo bash -c '...'"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

cleanup() {
  [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]] && rm -rf "$TMP_DIR" || true
}
trap cleanup EXIT

require_root
need_cmd curl
need_cmd tar

ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

info "Installing All-in-one"
info "Repo:   ${REPO}"
info "Branch: ${BRANCH}"
info "Target: ${INSTALL_DIR}"
info "Fetch:  ${ARCHIVE_URL}"

TMP_DIR="$(mktemp -d)"
cd "$TMP_DIR"

info "Downloading..."
curl -fLsS "$ARCHIVE_URL" -o repo.tar.gz || die "Download failed. Check repo/branch."

info "Extracting..."
tar -xzf repo.tar.gz || die "Extract failed."

SRC_DIR="$(find . -maxdepth 1 -type d -name 'All-in-one-*' | head -n 1)"
[[ -n "${SRC_DIR:-}" ]] || die "Could not find extracted folder."

info "Preparing install dir..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -a "$SRC_DIR"/. "$INSTALL_DIR"/

info "Setting permissions..."
chmod +x "$INSTALL_DIR/main.sh" || true
chmod +x "$INSTALL_DIR/modules/"*.sh 2>/dev/null || true
chmod +x "$INSTALL_DIR/lib/"*.sh 2>/dev/null || true

# Optional convenience symlink
if [[ -d /usr/local/bin ]]; then
  ln -sf "$INSTALL_DIR/main.sh" /usr/local/bin/all-in-one || true
  ok "Command installed: all-in-one"
fi

ok "Install completed."
info "Running main menu..."
cd "$INSTALL_DIR"
bash "$INSTALL_DIR/main.sh"
