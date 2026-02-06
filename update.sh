#!/usr/bin/env bash
set -Eeuo pipefail
# Backward-compatible wrapper: update now lives in optimize.sh
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
bash "$SCRIPT_DIR/optimize.sh"
