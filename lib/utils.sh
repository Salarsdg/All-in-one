#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="${APP_NAME:-all-in-one}"
BASE_DIR="${BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOG_FILE="${LOG_FILE:-$BASE_DIR/logs/${APP_NAME}.log}"

# shellcheck disable=SC1091
source "$BASE_DIR/lib/colors.sh"

die() { echo -e "${RED}ERROR:${NC} $*" >&2; log "ERROR: $*"; exit 1; }
info() { echo -e "${BLUE}INFO:${NC} $*"; log "INFO: $*"; }
ok()   { echo -e "${GREEN}OK:${NC} $*"; log "OK: $*"; }
warn() { echo -e "${YELLOW}WARN:${NC} $*"; log "WARN: $*"; }

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

on_err() {
  local exit_code=$?
  warn "Command failed (exit=$exit_code): ${BASH_COMMAND}"
  warn "See log: $LOG_FILE"
  return "$exit_code"
}
trap on_err ERR

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Run as root (e.g. sudo $0)"
  fi
}

pause() { read -rp "Press Enter to continue... " _; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

apt_install() {
  # Usage: apt_install pkg1 pkg2 ...
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends "$@"
}

is_ubuntu_or_debian() {
  [[ -f /etc/debian_version ]]
}

safe_sed_inplace() {
  # Works with GNU sed. Usage: safe_sed_inplace "s|a|b|" file
  local expr="$1" file="$2"
  sed -i "$expr" "$file"
}
