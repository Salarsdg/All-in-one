#!/bin/bash

set -euo pipefail

ZIP_URL="https://github.com/Salarsdg/All-in-one/releases/download/v1.0/backhaul_premium.zip"

TMP_DIR="/tmp/backhaul_install"
INSTALL_DIR="/root/backhaul-core"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run as root.${NC}"
    exit 1
fi

echo -e "${YELLOW}Installing required packages...${NC}"

if command -v apt >/dev/null 2>&1; then
    apt update -y
    apt install -y curl wget unzip
fi

echo -e "${YELLOW}Preparing directories...${NC}"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
mkdir -p "$INSTALL_DIR"

cd "$TMP_DIR"

echo -e "${YELLOW}Downloading backhaul package...${NC}"

wget -q --show-progress -O backhaul_premium.zip "$ZIP_URL"

echo -e "${YELLOW}Extracting package...${NC}"

unzip -o backhaul_premium.zip >/dev/null

if [ ! -f backhaul_premium ]; then
    echo -e "${RED}ERROR: backhaul_premium not found in archive.${NC}"
    exit 1
fi

if [ ! -f backhaul.sh ]; then
    echo -e "${RED}ERROR: backhaul.sh not found in archive.${NC}"
    exit 1
fi

chmod +x backhaul_premium
chmod +x backhaul.sh

echo -e "${YELLOW}Installing files...${NC}"

mv -f backhaul_premium "$INSTALL_DIR/backhaul_premium"
mv -f backhaul.sh /root/backhaul.sh

chmod +x "$INSTALL_DIR/backhaul_premium"
chmod +x /root/backhaul.sh

rm -f backhaul_premium.zip

echo -e "${GREEN}Installation completed successfully.${NC}"
echo -e "${GREEN}Binary : $INSTALL_DIR/backhaul_premium${NC}"
echo -e "${GREEN}Script : /root/backhaul.sh${NC}"

cd /root
rm -rf "$TMP_DIR"

echo -e "${YELLOW}Launching Backhaul Manager...${NC}"

exec bash /root/backhaul.sh