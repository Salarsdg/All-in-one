#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo 1. update and install needed packages.
echo 2. install webserver.
echo 3. get ipv6 local

read -p "Enter your choice: " choice








case $choice in  

1) 
bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/update.sh)
;;
2)  
bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/webserver_menu.sh)
;;
2)  
bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/ip-local-menu.sh)
;;


esac
