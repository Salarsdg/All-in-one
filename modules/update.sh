#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/lib/utils.sh"

require_root
is_ubuntu_or_debian || die "This module currently supports Debian/Ubuntu (apt)."

info "Updating and upgrading packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
ok "System updated."

info "Installing common packages..."
apt-get install -y --no-install-recommends \
  software-properties-common ufw wget curl git socat cron busybox \
  bash-completion locales nano apt-utils certbot ca-certificates
ok "Common packages installed."

info "Tip: log file is at $LOG_FILE"
