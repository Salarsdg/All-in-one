#!/bin/bash
set -euo pipefail

# =========================
# Backhaul Multi-Tunnel Manager
# Works correctly even when executed via: bash <(curl -Ls URL)
# because all user input is read from /dev/tty.
# =========================

# ---------- read from TTY (fix for bash <(curl ...)) ----------
read_tty() {
  local prompt="$1"
  local __var="$2"
  local value=""
  read -r -p "$prompt" value </dev/tty
  value="$(echo "$value" | xargs)" # trim
  printf -v "$__var" "%s" "$value"
}
is_port_in_use() {
  local p="$1"
  # ss is usually available on Ubuntu
  ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${p}$"
}

find_free_port_from() {
  local start="$1"
  local p="$start"
  while is_port_in_use "$p"; do
    p=$((p+1))
    if [ "$p" -gt 65535 ]; then
      die "No free port found starting from $start"
    fi
  done
  echo "$p"
}
# ---------- config ----------
BACKHAUL_URL="https://github.com/Salarsdg/All-in-one/releases/download/v1.0/backhaul.tar.gz"
ARCHIVE_NAME="backhaul.tar.gz"
BIN_PATH="/root/backhaul"
SYSTEMD_DIR="/etc/systemd/system"

# ---------- helpers ----------
die() { echo "ERROR: $*" >&2; exit 1; }

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "Please run this script as root (sudo)."
  fi
}

trim() { echo "$1" | xargs; }

service_name_for_index() {
  local idx="$1"
  if [ "$idx" = "1" ]; then
    echo "backhaul.service"
  else
    echo "backhaul${idx}.service"
  fi
}

config_path_for_index() {
  local idx="$1"
  if [ "$idx" = "1" ]; then
    echo "/root/config.toml"
  else
    echo "/root/config${idx}.toml"
  fi
}

service_path_for_index() {
  local idx="$1"
  echo "${SYSTEMD_DIR}/$(service_name_for_index "$idx")"
}

detect_mode_from_config() {
  local cfg="$1"
  if grep -q "^\[server\]" "$cfg"; then
    echo "iran"
  elif grep -q "^\[client\]" "$cfg"; then
    echo "kharej"
  else
    echo "unknown"
  fi
}

ensure_backhaul_binary() {
  if [ -x "$BIN_PATH" ]; then
    return 0
  fi

  echo "Backhaul binary not found at $BIN_PATH"
  echo "Downloading Backhaul..."
  wget -q --show-progress "$BACKHAUL_URL" -O "$ARCHIVE_NAME"

  echo "Extracting..."

tar -xzvf "$ARCHIVE_NAME" -C /
rm -f "$ARCHIVE_NAME"

  # Find extracted binary (usually ./backhaul)
  if [ -f "./backhaul" ]; then
    # If we are already in /root and ./backhaul == /root/backhaul, do not mv
    local src dst
    src="$(readlink -f ./backhaul)"
    dst="$(readlink -f "$BIN_PATH")"

    if [ "$src" = "$dst" ]; then
      chmod +x "$BIN_PATH"
      echo "Backhaul binary already in place at $BIN_PATH"
    else
      mv -f ./backhaul "$BIN_PATH"
      chmod +x "$BIN_PATH"
      echo "Installed binary to $BIN_PATH"
    fi
  elif [ -f "$BIN_PATH" ]; then
    chmod +x "$BIN_PATH" || true
    echo "Backhaul binary found at $BIN_PATH"
  else
    die "Backhaul binary not found after extraction."
  fi
}

next_available_index() {
  local idx=1
  while true; do
    local cfg
    cfg="$(config_path_for_index "$idx")"
    local svc
    svc="$(service_path_for_index "$idx")"
    if [ ! -f "$cfg" ] && [ ! -f "$svc" ]; then
      echo "$idx"
      return 0
    fi
    idx=$((idx+1))
  done
}

list_tunnels() {
  # Prints: idx|service|config|mode|active?
  local found=0
  for cfg in /root/config*.toml; do
    [ -e "$cfg" ] || continue

    local base
    base="$(basename "$cfg")"

    local idx="1"
    if [[ "$base" =~ ^config([0-9]+)\.toml$ ]]; then
      idx="${BASH_REMATCH[1]}"
    elif [ "$base" = "config.toml" ]; then
      idx="1"
    else
      continue
    fi

    local svc
    svc="$(service_name_for_index "$idx")"
    local mode
    mode="$(detect_mode_from_config "$cfg")"

    local active="unknown"
if systemctl status "$svc" >/dev/null 2>&1; then
    if systemctl is-active --quiet "$svc"; then
        active="active"
    else
        active="inactive"
    fi
else
    active="not-installed"
fi

    echo "${idx}|${svc}|${cfg}|${mode}|${active}"
    found=1
  done

  if [ "$found" -eq 0 ]; then
    echo ""
  fi
}

print_tunnels_table() {
  local rows
  rows="$(list_tunnels || true)"
  if [ -z "$rows" ]; then
    echo "No tunnels found." >&2
    return 0
  fi

  {
    echo "Existing tunnels:"
    echo "--------------------------------------------------------------"
    printf "%-6s %-20s %-24s %-8s %-10s\n" "Index" "Service" "Config" "Mode" "State"
    echo "--------------------------------------------------------------"
    while IFS='|' read -r idx svc cfg mode state; do
      [ -n "$idx" ] || continue
      printf "%-6s %-20s %-24s %-8s %-10s\n" "$idx" "$svc" "$cfg" "$mode" "$state"
    done <<< "$rows"
    echo "--------------------------------------------------------------"
  } >&2
}

write_service_file() {
  local idx="$1"
  local svc_path
  svc_path="$(service_path_for_index "$idx")"
  local cfg_path
  cfg_path="$(config_path_for_index "$idx")"

  cat > "$svc_path" <<EOF
[Unit]
Description=Backhaul Reverse Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/root/backhaul-core/backhaul_premium -c $cfg_path
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

restart_service() {
  local svc="$1"
  systemctl daemon-reload
  systemctl enable "$svc" >/dev/null 2>&1 || true
  systemctl restart "$svc"
}

show_status() {
  local svc="$1"
  systemctl --no-pager --full status "$svc" || true
}

show_logs() {
  local svc="$1"
  journalctl -u "$svc" --no-pager -n 150 || true
}

# ---- TOML editing (server ports array) ----
server_ports_list() {
  local cfg="$1"
  awk '
    BEGIN{inports=0}
    /^\s*ports\s*=\s*\[\s*$/ {inports=1; next}
    inports && /^\s*\]\s*$/ {inports=0; next}
    inports {
      gsub(/[",]/,"",$0)
      gsub(/[[:space:]]/,"",$0)
      if($0!="") print $0
    }
  ' "$cfg"
}

server_port_exists() {
  local cfg="$1"
  local p="$2"
  server_ports_list "$cfg" | grep -qx "${p}=${p}"
}

server_add_port() {
  local cfg="$1"
  local p="$2"

  if server_port_exists "$cfg" "$p"; then
    echo "Port $p already exists in ports list."
    return 0
  fi

  # Insert before closing bracket of ports array
  awk -v port="\""$p"="$p"\"," '
    {lines[NR]=$0}
    END{
      start=0; end=0
      for(i=1;i<=NR;i++){
        if(lines[i] ~ /^\s*ports\s*=\s*\[\s*$/) {start=i; break}
      }
      if(start==0){
        for(i=1;i<=NR;i++) print lines[i]
        print "ports = ["
        print port
        print "]"
        exit
      }
      for(i=start+1;i<=NR;i++){
        if(lines[i] ~ /^\s*\]\s*$/) {end=i; break}
      }
      if(end==0){
        for(i=1;i<=NR;i++) print lines[i]
        exit
      }

      for(i=1;i<end;i++) print lines[i]
      print port
      for(i=end;i<=NR;i++) print lines[i]
    }
  ' "$cfg" > "${cfg}.tmp" && mv "${cfg}.tmp" "$cfg"

  echo "Added port $p."
}

server_remove_port() {
  local cfg="$1"
  local p="$2"

  if ! server_port_exists "$cfg" "$p"; then
    echo "Port $p not found in ports list."
    return 0
  fi

  sed -i -E "/^\s*\"${p}=${p}\"\s*,?\s*$/d" "$cfg"
  echo "Removed port $p."
}

# ---------- create configs ----------
ask_tunnel_port_and_token() {
  local __portvar="$1"
  local __tokenvar="$2"

  read_tty "Enter tunnel port (default 3080): " tp
  tp="$(trim "$tp")"
  tp="${tp:-3080}"
  [[ "$tp" =~ ^[0-9]+$ ]] && [ "$tp" -ge 1 ] && [ "$tp" -le 65535 ] || die "Invalid tunnel port."

  read_tty "Enter token (default ezpz): " tok
  tok="$(trim "$tok")"
  tok="${tok:-ezpz}"

  printf -v "$__portvar" "%s" "$tp"
  printf -v "$__tokenvar" "%s" "$tok"

  echo "IMPORTANT: Tunnel port and token must match on BOTH servers (Iran and Kharej) for the same tunnel."
}

create_kharej_config() {
  local cfg="$1"
  local tunnel_port="$2"
  local token="$3"

  local iran_addr=""
  while true; do
    read_tty "Enter Iran server IP or domain (required): " iran_addr
    iran_addr="$(trim "$iran_addr")"
    [ -n "$iran_addr" ] && break
    echo "Iran server IP/domain cannot be empty. Please try again."
  done

  cat > "$cfg" <<EOF
[client]
remote_addr = "$iran_addr:$tunnel_port"
transport = "tcp"
token = "$token"
connection_pool = 8
aggressive_pool = false
keepalive_period = 75
dial_timeout = 10
nodelay = true
retry_interval = 3
sniffer = false
web_port = 2060
sniffer_log = "/root/backhaul.json"
log_level = "info"
EOF
}

create_iran_config() {
  local cfg="$1"
  local tunnel_port="$2"
  local token="$3"

  echo "IMPORTANT: Tunnel port must be the same as the Kharej server for this tunnel."
  local port_input=""
  while true; do
    read_tty "Enter ports to forward (comma separated, e.g. 443,2080): " port_input
    port_input="$(trim "$port_input")"
    [ -n "$port_input" ] && break
    echo "Ports list cannot be empty."
  done

  IFS=',' read -ra arr <<< "$port_input"
  local valid=()
  for p in "${arr[@]}"; do
    p="$(trim "$p")"
    if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]; then
      valid+=("$p")
    fi
  done
  [ "${#valid[@]}" -gt 0 ] || die "No valid ports provided."

  {
    echo "[server]"
    echo "bind_addr = \"0.0.0.0:$tunnel_port\""
    echo "transport = \"tcp\""
    echo "accept_udp = false"
    echo "token = \"$token\""
    echo "keepalive_period = 75"
    echo "nodelay = true"
    echo "heartbeat = 40"
    echo "channel_size = 2048"
    echo "sniffer = false"
    echo "sniffer_log = \"/root/backhaul.json\""
    echo "log_level = \"info\""
    echo "ports = ["
    for i in "${!valid[@]}"; do
      p="${valid[$i]}"
      if [ "$i" -lt "$(( ${#valid[@]} - 1 ))" ]; then
        echo "\"$p=$p\","
      else
        echo "\"$p=$p\""
      fi
    done
    echo "]"
  } > "$cfg"
}

# ---------- management actions ----------
select_tunnel_index() {
  print_tunnels_table
  local rows
  rows="$(list_tunnels || true)"
  [ -n "$rows" ] || die "No tunnels exist to manage."

  local idx=""
  while true; do
    read_tty "Enter tunnel index to manage (e.g. 1,2,3): " idx
    idx="$(trim "$idx")"
    [[ "$idx" =~ ^[0-9]+$ ]] || { echo "Invalid index."; continue; }
    local cfg
    cfg="$(config_path_for_index "$idx")"
    if [ -f "$cfg" ]; then
      echo "$idx"
      return 0
    fi
    echo "Tunnel index $idx not found."
  done
}

change_token() {
  local cfg="$1"
  read_tty "Enter new token (cannot be empty): " tok
  tok="$(trim "$tok")"
  [ -n "$tok" ] || die "Token cannot be empty."
  sed -i -E "s/^(\s*token\s*=\s*).*/\1\"$tok\"/" "$cfg"
  echo "Token updated."
}

change_tunnel_port() {
  local cfg="$1"
  local mode="$2"

  read_tty "Enter new tunnel port: " tp
  tp="$(trim "$tp")"
  [[ "$tp" =~ ^[0-9]+$ ]] && [ "$tp" -ge 1 ] && [ "$tp" -le 65535 ] || die "Invalid tunnel port."

  if [ "$mode" = "iran" ]; then
    sed -i -E "s|^(\s*bind_addr\s*=\s*).*$|\1\"0.0.0.0:$tp\"|g" "$cfg"
  elif [ "$mode" = "kharej" ]; then
    local host
    host="$(awk -F\" '/^\s*remote_addr\s*=/ {print $2}' "$cfg" | awk -F: '{print $1}')"
    [ -n "$host" ] || die "Could not parse remote_addr host."
    sed -i -E "s|^(\s*remote_addr\s*=\s*).*$|\1\"$host:$tp\"|g" "$cfg"
  else
    die "Unknown mode for tunnel."
  fi

  echo "Tunnel port updated."
}

change_kharej_iran_addr() {
  local cfg="$1"
  local current
  current="$(awk -F\" '/^\s*remote_addr\s*=/ {print $2}' "$cfg")"
  local port
  port="$(echo "$current" | awk -F: '{print $NF}')"

  local newhost=""
  while true; do
    read_tty "Enter new Iran IP/domain (required): " newhost
    newhost="$(trim "$newhost")"
    [ -n "$newhost" ] && break
    echo "Iran server IP/domain cannot be empty."
  done

  sed -i -E "s|^(\s*remote_addr\s*=\s*).*$|\1\"$newhost:$port\"|g" "$cfg"
  echo "Iran remote address updated."
}

remove_tunnel() {
  local idx="$1"
  local svc
  svc="$(service_name_for_index "$idx")"
  local svc_path
  svc_path="$(service_path_for_index "$idx")"
  local cfg
  cfg="$(config_path_for_index "$idx")"

  echo "This will remove:"
  echo "- Service: $svc_path"
  echo "- Config : $cfg"
  read_tty "Type YES to confirm: " confirm
  confirm="$(trim "$confirm")"
  [ "$confirm" = "YES" ] || { echo "Cancelled."; return 0; }

  systemctl stop "$svc" >/dev/null 2>&1 || true
  systemctl disable "$svc" >/dev/null 2>&1 || true

  rm -f "$svc_path"
  rm -f "$cfg"

  systemctl daemon-reload
  echo "Tunnel $idx removed."
}

# ---------- main menus ----------
main_menu() {
  {
    echo ""
    echo "Backhaul Multi-Tunnel Manager"
    echo "--------------------------------"
    echo "1) Create a new tunnel"
    echo "2) Manage existing tunnels"
    echo "3) List tunnels"
    echo "0) Exit"
    echo ""
  } >&2

  read_tty "Select option: " opt
  opt="$(trim "$opt")"
  echo "$opt"
}

create_tunnel_flow() {
  echo ""
  echo "Create tunnel on this server as:"
  echo "1) Iran (server)"
  echo "2) Kharej (client)"
  read_tty "Select (1 or 2): " role
  role="$(trim "$role")"
  case "$role" in
    1) ROLE="iran" ;;
    2) ROLE="kharej" ;;
    *) die "Invalid selection." ;;
  esac

  ensure_backhaul_binary

  local idx
  idx="$(next_available_index)"
  local cfg
  cfg="$(config_path_for_index "$idx")"
  local svc
  svc="$(service_name_for_index "$idx")"

  local tp tok
  ask_tunnel_port_and_token tp tok

  if [ "$ROLE" = "iran" ]; then
    create_iran_config "$cfg" "$tp" "$tok"
  else
    create_kharej_config "$cfg" "$tp" "$tok"
  fi

  write_service_file "$idx"
  restart_service "$svc"

  echo ""
  echo "Tunnel created:"
  echo "- Index  : $idx"
  echo "- Config : $cfg"
  echo "- Service: $svc"
  echo ""
  show_status "$svc"
}

manage_tunnels_flow() {
  local idx
  idx="$(select_tunnel_index)"

  local cfg
  cfg="$(config_path_for_index "$idx")"
  local svc
  svc="$(service_name_for_index "$idx")"
  local mode
  mode="$(detect_mode_from_config "$cfg")"
  [ "$mode" != "unknown" ] || die "Could not detect tunnel mode from config."

  while true; do
    echo ""
    echo "Managing tunnel #$idx  ($mode)"
    echo "Config : $cfg"
    echo "Service: $svc"
    echo "--------------------------------"
    echo "1) Show status"
    echo "2) Show logs"
    echo "3) Restart service"
    echo "4) Change token"
    echo "5) Change tunnel port"
    if [ "$mode" = "kharej" ]; then
      echo "6) Change Iran IP/domain (remote_addr host)"
    fi
    if [ "$mode" = "iran" ]; then
      echo "6) View forwarded ports"
      echo "7) Add a forwarded port"
      echo "8) Remove a forwarded port"
    fi
    echo "9) Remove this tunnel (service + config)"
    echo "0) Back"
    echo ""

    read_tty "Select option: " opt
    opt="$(trim "$opt")"

    case "$opt" in
      1) show_status "$svc" ;;
      2) show_logs "$svc" ;;
      3) restart_service "$svc"; echo "Service restarted." ;;
      4) change_token "$cfg"; restart_service "$svc"; echo "Service restarted." ;;
      5) change_tunnel_port "$cfg" "$mode"; restart_service "$svc"; echo "Service restarted." ;;
      6)
        if [ "$mode" = "kharej" ]; then
          change_kharej_iran_addr "$cfg"
          restart_service "$svc"
          echo "Service restarted."
        else
          echo "Forwarded ports:"
          local ports
          ports="$(server_ports_list "$cfg" || true)"
          if [ -z "$ports" ]; then
            echo "(none found)"
          else
            echo "$ports" | sed 's/^/ - /'
          fi
        fi
        ;;
      7)
        if [ "$mode" != "iran" ]; then
          echo "Not available for kharej/client tunnels."
        else
          read_tty "Enter port to add (1-65535): " p
          p="$(trim "$p")"
          [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ] || { echo "Invalid port."; continue; }
          server_add_port "$cfg" "$p"
          restart_service "$svc"
          echo "Service restarted."
        fi
        ;;
      8)
        if [ "$mode" != "iran" ]; then
          echo "Not available for kharej/client tunnels."
        else
          read_tty "Enter port to remove (1-65535): " p
          p="$(trim "$p")"
          [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ] || { echo "Invalid port."; continue; }
          server_remove_port "$cfg" "$p"
          restart_service "$svc"
          echo "Service restarted."
        fi
        ;;
      9)
        remove_tunnel "$idx"
        break
        ;;
      0) break ;;
      *) echo "Invalid option." ;;
    esac
  done
}

# ---------- entry ----------
need_root

while true; do
  opt="$(main_menu)"
  case "$opt" in
    1) create_tunnel_flow ;;
    2) manage_tunnels_flow ;;
    3) print_tunnels_table ;;
    0) exit 0 ;;
    *) echo "Invalid option." ;;
  esac
done