#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW} starting the update and upgrade process.... ${NC}"
apt update && apt upgrade -y

echo -e "${GREEN} your Vps updated!!!! ${NC}"