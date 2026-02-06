#!/usr/bin/env bash
set -Eeuo pipefail
# One-liner installer that avoids CRLF problems
bash <(curl -fsSL https://raw.githubusercontent.com/Salarsdg/All-in-one/Stage/menu.sh | tr -d '\r')
