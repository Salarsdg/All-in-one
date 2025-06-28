#!/bin/bash

FILE="backhaul_linux_amd64.tar.gz"
URL="https://github.com/Musixal/Backhaul/releases/download/v0.6.5/$FILE"

# Download and extract
if [ -f "$FILE" ]; then
    echo "[✔] $FILE already exists."
else
    echo "[↓] Downloading $FILE..."
    wget "$URL"
    [ $? -ne 0 ] && echo "[✘] Download failed." && exit 1
fi

echo "[⇩] Extracting $FILE..."
tar -xzf "$FILE" || { echo "[✘] Extraction failed."; exit 1; }

# Select location
echo ""
echo "Choose location:"
echo "1) iran"
echo "2) kharej"
read -p "Enter choice [1-2]: " choice

if [[ "$choice" != "1" && "$choice" != "2" ]]; then
    echo "[✘] Invalid choice."
    exit 1
fi

# Select protocol
echo ""
echo "Select protocol:"
echo "1) tcp"
echo "2) tcp mux"
echo "3) ws"
read -p "Enter protocol [1-3]: " proto

case $proto in
    1)
        proto_name="tcp"
        default_tunnel_port=3080
        ;;
    2)
        proto_name="tcpmux"
        default_tunnel_port=3080
        ;;
    3)
        proto_name="ws"
        default_tunnel_port=8080
        ;;
    *)
        echo "[✘] Invalid protocol choice."
        exit 1
        ;;
esac

# Prompt: Tunnel Port
read -p "Enter tunnel port [default: $default_tunnel_port]: " tunnel_port
tunnel_port="${tunnel_port:-$default_tunnel_port}"
while ss -tuln | grep -q ":$tunnel_port "; do
    echo "[⚠] Port $tunnel_port is in use. Choose another."
    read -p "Enter tunnel port [default: $default_tunnel_port]: " tunnel_port
    tunnel_port="${tunnel_port:-$default_tunnel_port}"
done

# Prompt: Token
read -p "Enter token [default: token]: " token
token="${token:-token}"
if ! [[ "$token" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "[✘] Token must be alphanumeric (English only)."
    exit 1
fi

# Prompt: Web Port
read -p "Enter web port [default: 2060]: " web_port
web_port="${web_port:-2060}"
while ss -tuln | grep -q ":$web_port "; do
    echo "[⚠] Web port $web_port is in use. Choose another."
    read -p "Enter web port [default: 2060]: " web_port
    web_port="${web_port:-2060}"
done

# Prompt: Port list
read -p "Enter list of ports (comma-separated): " port_list
IFS=',' read -ra PORTS <<< "$port_list"

PORT_LINES=""
for p in "${PORTS[@]}"; do
    p=$(echo "$p" | xargs)
    [[ "$p" =~ ^[0-9]+$ ]] && PORT_LINES+="\"$p=$p\",\n"
done
PORT_LINES=$(echo -e "$PORT_LINES" | sed '$ s/,\n$//')

# Determine config file name
CONFIG_NAME="/root/config.toml"
i=2
while [ -f "$CONFIG_NAME" ]; do
    CONFIG_NAME="/root/config${i}.toml"
    ((i++))
done

# Write config depending on protocol
case $proto_name in
    tcp)
        cat > "$CONFIG_NAME" <<EOF
[server]
bind_addr = "0.0.0.0:$tunnel_port"
transport = "tcp"
accept_udp = false
token = "$token"
keepalive_period = 75
nodelay = true
heartbeat = 40
channel_size = 2048
sniffer = false
web_port = $web_port
sniffer_log = "/root/backhaul.json"
log_level = "info"
ports = [
$PORT_LINES
]
EOF
        ;;
    tcpmux)
        cat > "$CONFIG_NAME" <<EOF
[server]
bind_addr = "0.0.0.0:$tunnel_port"
transport = "tcpmux"
token = "$token"
keepalive_period = 75
nodelay = true
heartbeat = 40
channel_size = 2048
mux_con = 8
mux_version = 1
mux_framesize = 32768
mux_recievebuffer = 4194304
mux_streambuffer = 65536
sniffer = false
web_port = $web_port
sniffer_log = "/root/backhaul.json"
log_level = "info"
ports = [
$PORT_LINES
]
EOF
        ;;
    ws)
        cat > "$CONFIG_NAME" <<EOF
[server]
bind_addr = "0.0.0.0:$tunnel_port"
transport = "ws"
token = "$token"
channel_size = 2048
keepalive_period = 75
heartbeat = 40
nodelay = true
sniffer = false
web_port = $web_port
sniffer_log = "/root/backhaul.json"
log_level = "info"
ports = [
$PORT_LINES
]
EOF
        ;;
esac

echo "[✔] Config saved to $CONFIG_NAME"

# ساخت سرویس systemd با نام دنباله‌دار
SERVICE_NAME="/etc/systemd/system/backhaul.service"
i=2
while [ -f "$SERVICE_NAME" ]; do
    SERVICE_NAME="/etc/systemd/system/backhaul${i}.service"
    ((i++))
done

CONFIG_BASENAME=$(basename "$CONFIG_NAME")

cat > "$SERVICE_NAME" <<EOF
[Unit]
Description=Backhaul Reverse Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/root/backhaul -c /root/$CONFIG_BASENAME
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

echo "[✔] Systemd service created at $SERVICE_NAME"

systemctl daemon-reload
systemctl enable "$(basename $SERVICE_NAME)"
systemctl restart "$(basename $SERVICE_NAME)"

echo "[✔] Service $(basename $SERVICE_NAME) enabled and started."
