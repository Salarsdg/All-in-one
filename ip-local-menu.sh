#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
echo dar kodam server hastid ? 
echo 1. iran
echo 2. kharej
read -p "Enter your choice: " choice








case $choice in  

1) 
bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/iran.sh)
;;
2)  
bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/kharej.sh)
;;


esac