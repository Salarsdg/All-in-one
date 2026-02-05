#!/usr/bin/env bash
BLUE="\e[38;5;39m"
CYAN="\e[38;5;51m"
GREEN="\e[38;5;82m"
YELLOW="\e[38;5;226m"
RED="\e[38;5;196m"
GRAY="\e[38;5;245m"
BOLD="\e[1m"
NC="\e[0m"

# ===============================
# Ultra-safe UI symbols (Unicode / ASCII)
# ===============================
UI_MODE="ascii"

# Prefer Unicode only when locale advertises UTF-8
if locale 2>/dev/null | grep -qi 'utf-8'; then
  UI_MODE="unicode"
fi

# Fallback to ASCII on limited terminals
if ! command -v tput >/dev/null 2>&1; then
  UI_MODE="ascii"
elif [ "$(tput colors 2>/dev/null || echo 0)" -lt 8 ]; then
  UI_MODE="ascii"
fi

if [ "$UI_MODE" = "unicode" ]; then
  UI_H="─"; UI_V="│"
  UI_TL="┌"; UI_TR="┐"
  UI_BL="└"; UI_BR="┘"
  UI_OK="✓"; UI_ERR="✗"; UI_BYE="👋"
else
  UI_H="-"; UI_V="|"
  UI_TL="+"; UI_TR="+"
  UI_BL="+"; UI_BR="+"
  UI_OK="OK"; UI_ERR="ERR"; UI_BYE=""
fi

ui_term_cols() { tput cols 2>/dev/null || echo 80; }

ui_clear(){ clear 2>/dev/null || true; }

ui_logo() {
cat <<'EOF'
 █████╗ ██╗     ██╗         ██╗███╗   ██╗     ██████╗ ███╗   ██╗███████╗
██╔══██╗██║     ██║         ██║████╗  ██║    ██╔═══██╗████╗  ██║██╔════╝
███████║██║     ██║         ██║██╔██╗ ██║    ██║   ██║██╔██╗ ██║█████╗  
██╔══██║██║     ██║         ██║██║╚██╗██║    ██║   ██║██║╚██╗██║██╔══╝  
██║  ██║███████╗███████╗    ██║██║ ╚████║    ╚██████╔╝██║ ╚████║███████╗
╚═╝  ╚═╝╚══════╝╚══════╝    ╚═╝╚═╝  ╚═══╝     ╚═════╝ ╚═╝  ╚═══╝╚══════╝
EOF
}

ui_hr() {
  local w
  w="$(ui_term_cols)"
  printf "${BLUE}%*s${NC}
" "$w" "" | tr ' ' "$UI_H"
}

ui_header() {
  local name="$1" ver="$2" repo="$3"
  ui_clear
  echo -e "${CYAN}"; ui_logo; echo -e "${NC}"
  ui_hr
  printf "${GRAY} Name:${NC} ${BOLD}%s${NC}   ${GRAY}Version:${NC} ${GREEN}%s${NC}   ${GRAY}GitHub:${NC} ${CYAN}%s${NC}\n" "$name" "$ver" "$repo"
  printf "${GRAY} Log:${NC} ${CYAN}%s${NC}\n" "${LOG_FILE:-/tmp/all-in-one.log}"
  ui_hr
}

ui_box() {
  local title="$1"; shift
  local cols inner pad line

  cols="$(ui_term_cols)"
  # Keep it readable on narrow terminals
  [ "$cols" -lt 60 ] && cols=60
  inner=$((cols - 2))

  # Top border
  printf "${BLUE}${UI_TL}%*s${UI_TR}${NC}
" "$inner" "" | tr ' ' "$UI_H"

  # Title line
  pad=$((inner - 2))
  printf "${BLUE}${UI_V}${NC} ${BOLD}%-*s${NC}${BLUE}${UI_V}${NC}
" "$pad" "$title"

  # Content lines
  for line in "$@"; do
    printf "${BLUE}${UI_V}${NC} ${CYAN}%-*s${NC}${BLUE}${UI_V}${NC}
" "$pad" "$line"
  done

  # Bottom border
  printf "${BLUE}${UI_BL}%*s${UI_BR}${NC}
" "$inner" "" | tr ' ' "$UI_H"
}


ui_main_menu() {
  ui_box "Main Menu" \
    "[1] System Update & Upgrade" \
    "[2] Install Essentials" \
    "[3] Security & Firewall" \
    "[4] Network & Tools" \
    "[5] Docker & Services" \
    "[6] Monitoring & Logs" \
    "[7] Utilities" \
    "[8] Optimize & Tuning" \
    "[0] Exit"
}

ui_prompt() {
  local label="$1" __var="$2"
  echo -ne "${GREEN}${label}${GRAY} › ${NC}"
  read -r "$__var"
}

ui_toast_error(){ echo -e "${RED}${UI_ERR}${NC} $*"; }
ui_toast_ok(){ echo -e "${GREEN}${UI_OK}${NC} $*"; }
ui_goodbye(){ echo -e "${YELLOW}Bye ${UI_BYE}${NC}"; }

ui_run() {
  local title="$1"; shift
  echo -e "${BOLD}${CYAN}→ ${title}${NC}\n"
  "$@"
  echo
  ui_toast_ok "Done. Press Enter..."
  read -r _
}
