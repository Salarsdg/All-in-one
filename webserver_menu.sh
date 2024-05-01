#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo 1. install apache and php
echo 2. add new site
read -p "Enter your choise: " choice


case $choice in  
1)
    bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/nstall_apache_php.sh)
    ;;
2)  
    bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/add_site.sh)
    ;;
esac

bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/menu.sh)

