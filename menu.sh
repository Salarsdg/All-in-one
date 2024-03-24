#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
echo hello this is my first script
echo 1. update and install needed packages.
echo 2. install telegram bot.
read -p "Enter option number: " choice








case $choice in  

1) 
bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/update.sh)
;;
2) 


esac
