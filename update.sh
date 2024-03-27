#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW} starting the update and upgrade process.... ${NC}"
apt update && apt upgrade -y
clear

echo -e "${GREEN} your Vps updated!!!! ${NC}"
echo -e "${YELLOW} installing packages.... ${NC}"
sleep 10

apt-get install -y software-properties-common ufw wget curl git socat cron busybox bash-completion locales nano apt-utils certbot nginx php 


echo -e "${GREEN} all packages installed. ${NC}"


