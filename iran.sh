#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Install netplan and start systemd-networkd service
sudo apt install -y netplan.io
sudo systemctl unmask systemd-networkd.service
sudo systemctl start systemd-networkd.service

# Define the directories and file paths
NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE="$NETPLAN_DIR/localip.yaml"
SYSTEMD_DIR="/etc/systemd/network"
SYSTEMD_FILE="$SYSTEMD_DIR/localip.network"

# Function to validate non-empty input
validate_input() {
    local input=$1
    local prompt=$2
    while [[ -z "$input" ]]; do
        read -p "$prompt" input
    done
    echo "$input"
}

# Ask for IPv4 addresses
SERVER1_IPV4=$(validate_input "" "Enter iran ipv4: ")
SERVER2_IPV4=$(validate_input "" "Enter kharej ipv4: ")

# Ask for IPv6 addresses
IPV6_1=$(validate_input "" "Enter iran IPv6 address (e.g., 2001:db8:xxxx::2): ")
IPV6_2=$(validate_input "" "Enter kharej IPv6 address (e.g., 2001:db8:xxxx::1): ")

# Ensure the netplan directory exists
if [ ! -d "$NETPLAN_DIR" ]; then
    echo -e "${YELLOW}Directory $NETPLAN_DIR does not exist. Creating it now.${NC}"
    sudo mkdir -p "$NETPLAN_DIR"
fi

# Remove the netplan configuration file if it exists
if [ -f "$NETPLAN_FILE" ]; then
    echo -e "${YELLOW}File $NETPLAN_FILE already exists. Removing it.${NC}"
    sudo rm -f "$NETPLAN_FILE"
fi

# Create the netplan configuration file
echo -e "${BLUE}Creating file $NETPLAN_FILE.${NC}"
sudo bash -c "cat > $NETPLAN_FILE <<EOF
network:
  version: 2
  tunnels:
    local:
      mode: sit
      local: $SERVER1_IPV4
      remote: $SERVER2_IPV4
      addresses:
        - ${IPV6_1}/64
      mtu: 1500
EOF"

# Apply the netplan configuration
sudo netplan apply

# Ensure the systemd network directory exists
if [ ! -d "$SYSTEMD_DIR" ]; then
    echo -e "${YELLOW}Directory $SYSTEMD_DIR does not exist. Creating it now.${NC}"
    sudo mkdir -p "$SYSTEMD_DIR"
fi

# Remove the systemd network configuration file if it exists
if [ -f "$SYSTEMD_FILE" ]; then
    echo -e "${YELLOW}File $SYSTEMD_FILE already exists. Removing it.${NC}"
    sudo rm -f "$SYSTEMD_FILE"
fi

# Create the systemd network configuration file
echo -e "${BLUE}Creating file $SYSTEMD_FILE.${NC}"
sudo bash -c "cat > $SYSTEMD_FILE <<EOF
[Network]
Address=${IPV6_1}/64
Gateway=${IPV6_2}
EOF"

# Restart the systemd-networkd service
sudo systemctl restart systemd-networkd

# Prompt to reboot the system
read -p "Do you want to reboot the system? [Y/n]: " REBOOT
REBOOT=${REBOOT:-Y}

if [[ $REBOOT =~ ^[Yy]$ ]]; then
    echo "Rebooting the system."
    sudo reboot
else
    echo "Reboot aborted."
fi

echo "Script execution completed."
