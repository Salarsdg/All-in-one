#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
echo hello this is my first script
echo 1. update and upgrade the server
echo 2. install telegram bot.
read -p "Enter option number: " choice








case $choice in  

1) 
echo -e "${YELLOW} starting the update and upgrade process.... ${NC}"
apt update && apt upgrade -y

echo -e "${GREEN} your Vps updated!!!! ${NC}"
;;
2) 


esac
