#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="all-in-one"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$BASE_DIR/logs/${APP_NAME}.log"

# shellcheck disable=SC1091
source "$BASE_DIR/lib/utils.sh"
# shellcheck disable=SC1091
source "$BASE_DIR/lib/menu.sh"

require_root
ok "Starting $APP_NAME"
main_menu
