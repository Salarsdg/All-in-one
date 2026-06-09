#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ZIP_URL="https://github.com/Salarsdg/All-in-one/releases/download/v1.0/backhaul_premium.zip"
TMP_DIR="/tmp/backhaul_premium_install"
INSTALL_DIR="/root/backhaul-core"

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}ERROR: This script must be run as root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Installing required packages...${NC}"
apt update -y
apt install -y curl wget unzip

echo -e "${YELLOW}Preparing install directory...${NC}"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
mkdir -p "$INSTALL_DIR"

cd "$TMP_DIR"

echo -e "${YELLOW}Downloading backhaul premium package...${NC}"
wget -O backhaul_premium.zip "$ZIP_URL"

echo -e "${YELLOW}Extracting package...${NC}"
unzip -o backhaul_premium.zip

if [ ! -f "backhaul_premium" ]; then
  echo -e "${RED}ERROR: backhaul_premium not found.${NC}"
  exit 1
fi

if [ ! -f "backhaul.sh" ]; then
  echo -e "${RED}ERROR: backhaul.sh not found.${NC}"
  exit 1
fi

chmod +x backhaul_premium
chmod +x backhaul.sh

echo -e "${YELLOW}Moving backhaul_premium to $INSTALL_DIR ...${NC}"
mv -f backhaul_premium "$INSTALL_DIR/backhaul_premium"

echo -e "${GREEN}Installation completed successfully.${NC}"
echo -e "${YELLOW}Running backhaul.sh...${NC}"

bash "$TMP_DIR/backhaul.sh"