#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

APP_NAME="All in One"
APP_VERSION="1.0.0"
APP_REPO="github.com/Salarsdg/All-in-one"
LOG_FILE="$BASE_DIR/logs/all-in-one.log"

source "$BASE_DIR/lib/utils.sh"
source "$BASE_DIR/lib/ui.sh"

require_root

while true; do
  ui_header "$APP_NAME" "$APP_VERSION" "$APP_REPO"
  ui_main_menu
  ui_prompt "Select option (0-8)" choice

  case "${choice:-}" in
    1) ui_run "System Update & Upgrade" bash "$BASE_DIR/modules/system_update.sh" ;;
    2) ui_run "Install Essentials" bash "$BASE_DIR/modules/essentials.sh" ;;
    3) ui_run "Security & Firewall" security_menu ;;
    4) ui_run "Network & Tools" network_menu ;;
    5) ui_run "Docker & Services" bash "$BASE_DIR/modules/docker_install.sh" ;;
    6) ui_run "Monitoring & Logs" bash "$BASE_DIR/modules/logs.sh" ;;
    7) ui_run "Utilities" utilities_menu ;;
    8) ui_run "Optimize & Tuning" optimize_menu ;;
    0) ui_goodbye; exit 0 ;;
    *) ui_toast_error "Invalid option"; sleep 1 ;;
  esac
done

security_menu() {
  while true; do
    ui_header "$APP_NAME" "$APP_VERSION" "$APP_REPO"
    ui_box "Security & Firewall" \
      "[1] SSH Hardening (port/root login options)" \
      "[2] UFW Firewall (interactive)" \
      "[3] Fail2Ban (install/enable)" \
      "[0] Back"
    ui_prompt "Select option (0-3)" c
    case "${c:-}" in
      1) ui_run "SSH Hardening" bash "$BASE_DIR/modules/ssh_hardening.sh" ;;
      2) ui_run "UFW Firewall" bash "$BASE_DIR/modules/ufw.sh" ;;
      3) ui_run "Fail2Ban" bash "$BASE_DIR/modules/fail2ban.sh" ;;
      0) return 0 ;;
      *) ui_toast_error "Invalid option"; sleep 1 ;;
    esac
  done
}

network_menu() {
  while true; do
    ui_header "$APP_NAME" "$APP_VERSION" "$APP_REPO"
    ui_box "Network & Tools" \
      "[1] IP Info (IPv4/IPv6/local/public)" \
      "[2] Speedtest CLI" \
      "[3] Enable BBR" \
      "[0] Back"
    ui_prompt "Select option (0-3)" c
    case "${c:-}" in
      1) ui_run "IP Info" bash "$BASE_DIR/modules/ip_info.sh" ;;
      2) ui_run "Speedtest" bash "$BASE_DIR/modules/speedtest.sh" ;;
      3) ui_run "Enable BBR" bash "$BASE_DIR/modules/bbr.sh" ;;
      0) return 0 ;;
      *) ui_toast_error "Invalid option"; sleep 1 ;;
    esac
  done
}

utilities_menu() {
  while true; do
    ui_header "$APP_NAME" "$APP_VERSION" "$APP_REPO"
    ui_box "Utilities" \
      "[1] Swap (Create/Resize)" \
      "[0] Back"
    ui_prompt "Select option (0-1)" c
    case "${c:-}" in
      1) ui_run "Swap" bash "$BASE_DIR/modules/swap.sh" ;;
      0) return 0 ;;
      *) ui_toast_error "Invalid option"; sleep 1 ;;
    esac
  done
}

optimize_menu() {
  while true; do
    ui_header "$APP_NAME" "$APP_VERSION" "$APP_REPO"
    ui_box "Optimize & Tuning" \
      "[1] Optimize Everything (Recommended)" \
      "[2] Enable BBR" \
      "[3] Create / Resize Swap" \
      "[4] Network Optimization (Recommended)" \
      "[5] SSH Optimization (Recommended)" \
      "[6] System Limits Optimization" \
      "[7] Disable Terminal Ads" \
      "[8] Limit Journald Disk Usage" \
      "[9] Optimization Status" \
      "[0] Back"
    ui_prompt "Select option (0-9)" c
    case "${c:-}" in
      1) ui_run "Optimize Everything (Recommended)" bash "$BASE_DIR/modules/opt_everything_recommended.sh" ;;
      2) ui_run "Enable BBR" bash "$BASE_DIR/modules/bbr.sh" ;;
      3) ui_run "Swap" bash "$BASE_DIR/modules/swap.sh" ;;
      4) ui_run "Network Optimization (Recommended)" bash "$BASE_DIR/modules/opt_network_recommended.sh" ;;
      5) ui_run "SSH Optimization (Recommended)" bash "$BASE_DIR/modules/opt_ssh_recommended.sh" ;;
      6) ui_run "System Limits Optimization" bash "$BASE_DIR/modules/opt_limits.sh" ;;
      7) ui_run "Disable Terminal Ads" bash "$BASE_DIR/modules/disable_ads.sh" ;;
      8) ui_run "Limit Journald Disk Usage" bash "$BASE_DIR/modules/journald_limit.sh" ;;
      9) ui_run "Optimization Status" bash "$BASE_DIR/modules/opt_status.sh" ;;
      0) return 0 ;;
      *) ui_toast_error "Invalid option"; sleep 1 ;;
    esac
  done
}
