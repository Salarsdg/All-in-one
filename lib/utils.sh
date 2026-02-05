#!/usr/bin/env bash
set -Eeuo pipefail

: "${LOG_FILE:=/tmp/all-in-one.log}"

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

die() { echo "ERROR: $*" >&2; log "ERROR: $*"; exit 1; }
require_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root (sudo)"; }

is_debian_like() { [[ -f /etc/debian_version ]]; }

apt_install() {
  is_debian_like || die "This module supports Debian/Ubuntu (apt)."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends "$@"
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
