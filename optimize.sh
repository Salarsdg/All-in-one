#!/usr/bin/env bash
set -Eeuo pipefail

# ---------------- Colors & UI ----------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

hr() { printf "%b" "${BLUE}============================================================${NC}\n"; }
info(){ echo -e "${CYAN}[i]${NC} $*"; }
ok(){   echo -e "${GREEN}[✔]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; }
die(){  echo -e "${RED}[✘]${NC} $*" >&2; exit 1; }

require_root(){ [ "${EUID:-$(id -u)}" -eq 0 ] || die "Please run as root"; }

# ---------------- Logging ----------------
LOG_FILE="/var/log/all-in-one.log"
mkdir -p "$(dirname "$LOG_FILE")" || true
exec > >(tee -a "$LOG_FILE") 2>&1

trap 'die "Error on line $LINENO"' ERR

# ---------------- Helpers ----------------
have_cmd(){ command -v "$1" >/dev/null 2>&1; }

apply_sysctl() {
  local conf="/etc/sysctl.d/99-all-in-one.conf"
  cat > "$conf" <<'SYSCTL'
# All-in-one safe sysctl tuning
# (Network tuning; generally safe for VPS)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

net.core.somaxconn = 4096
net.core.netdev_max_backlog = 16384

net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_syn_retries = 3

net.ipv4.ip_forward = 1

# Basic hardening
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.log_martians = 1
SYSCTL

  sysctl --system >/dev/null 2>&1 || sysctl -p "$conf" >/dev/null 2>&1 || true
}

apply_limits() {
  local conf="/etc/security/limits.d/99-all-in-one.conf"
  cat > "$conf" <<'LIMITS'
# All-in-one file descriptor limits
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS
}

ensure_bbr_supported() {
  # If BBR module exists, good. If not, still keep sysctl; kernel decides.
  if lsmod | grep -q '^tcp_bbr'; then
    ok "BBR module is loaded"
  else
    modprobe tcp_bbr >/dev/null 2>&1 || true
    lsmod | grep -q '^tcp_bbr' && ok "BBR module loaded" || warn "BBR module not available (kernel may not support it)"
  fi
}

cleanup_system() {
  apt-get autoremove -y >/dev/null 2>&1 || true
  apt-get autoclean -y >/dev/null 2>&1 || true
}

# ---------------- Main ----------------
require_root

clear
hr
echo -e "${BOLD}System Optimize${NC}  (Update + basic tuning)"
hr
info "Log: $LOG_FILE"

info "Updating packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
ok "System updated"

info "Installing common packages..."
apt-get install -y \
  software-properties-common ufw wget curl git socat cron busybox bash-completion \
  locales nano apt-utils ca-certificates unzip zip htop net-tools \
  fail2ban || true
ok "Packages installed (some may already exist)"

info "Enabling systemd-networkd (if present)..."
systemctl unmask systemd-networkd.service >/dev/null 2>&1 || true
systemctl unmask systemd-networkd.socket >/dev/null 2>&1 || true
systemctl enable systemd-networkd.service >/dev/null 2>&1 || true
systemctl start systemd-networkd.service  >/dev/null 2>&1 || true

info "Applying sysctl tuning (BBR + safe network/hardening)..."
apply_sysctl
ensure_bbr_supported
ok "Sysctl applied"

info "Applying file descriptor limits..."
apply_limits
ok "Limits applied"

info "Optional: UFW"
warn "UFW is installed but NOT enabled automatically (to avoid locking you out)."
warn "If you want: ufw allow 22/tcp && ufw enable"

info "Cleaning up..."
cleanup_system
ok "Cleanup done"

hr
echo -e "${GREEN}Done.${NC}"
echo "- Re-login recommended to fully apply limits"
echo "- You can check: sysctl net.ipv4.tcp_congestion_control"
hr

# Return to menu if exists
if [ -f "/opt/all-in-one/menu.sh" ]; then
  bash /opt/all-in-one/menu.sh || true
elif [ -f "./menu.sh" ]; then
  bash ./menu.sh || true
fi
