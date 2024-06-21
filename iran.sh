#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

apt install netplan.io
sudo systemctl unmask systemd-networkd.service
sudo systemctl start systemd-networkd.service

# Define the directories and file paths
NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE="$NETPLAN_DIR/localip.yaml"
SYSTEMD_DIR="/etc/systemd/network"
SYSTEMD_FILE="$SYSTEMD_DIR/localip.network"

# Function to generate a random three-digit number
generate_random_number() {
    echo $((RANDOM % 900 + 100))
}

# Ask for IPv4 addresses
read -p "Enter Iran ipv4: " SERVER1_IPV4
read -p "Enter kharej ipv4: " SERVER2_IPV4

# Generate random three-digit number and create two IPv6 addresses
RANDOM_NUMBER=$(generate_random_number)
IPV6_1="2001:db8:${RANDOM_NUMBER}::1"
IPV6_2="2001:db8:${RANDOM_NUMBER}::2"

# Ensure the netplan directory exists
if [ ! -d "$NETPLAN_DIR" ]; then
    echo "Directory $NETPLAN_DIR does not exist. Creating it now."
    sudo mkdir -p "$NETPLAN_DIR"
fi

# Remove the netplan configuration file if it exists
if [ -f "$NETPLAN_FILE" ]; then
    echo "File $NETPLAN_FILE already exists. Removing it."
    sudo rm -f "$NETPLAN_FILE"
fi

# Create the netplan configuration file
echo "Creating file $NETPLAN_FILE."
sudo bash -c "cat > $NETPLAN_FILE <<EOF
network:
  version: 2
  tunnels:
    local:
      mode: sit
      local: $SERVER1_IPV4
      remote: $SERVER2_IPV4
      addresses:
        - ${IPV6_2}/64
      mtu: 1500
EOF"

# Apply the netplan configuration
sudo netplan apply

# Ensure the systemd network directory exists
if [ ! -d "$SYSTEMD_DIR" ]; then
    echo "Directory $SYSTEMD_DIR does not exist. Creating it now."
    sudo mkdir -p "$SYSTEMD_DIR"
fi

# Create the systemd network configuration file
echo "Creating file $SYSTEMD_FILE."
sudo bash -c "cat > $SYSTEMD_FILE <<EOF
[Network]
Address=${IPV6_2}/64
Gateway=${IPV6_1}
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