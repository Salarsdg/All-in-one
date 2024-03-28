#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${YELLOW} Installing php and apache .... ${NC}"
sleep 2
sudo apt install apache2
sudo apt install php libapache2-mod-php php-mysql
sudo ufw allow 80/tcp
read -p "enter your root location ( default:/var/www/html ) :" location
if [ -z "$location" ]; then
    sudo chown -R www-data:www-data /var/www/html
    sudo chmod -R 755 /var/www/html
else
   sudo chown -R www-data:www-data $location
   sudo chmod -R 755 $location
fi
sudo apt install certbot python3-certbot-apache
sudo ufw allow 'Apache Full'
read -p "Enter your domain for SSL : " domain
sudo certbot --apache -d $domain

echo "<?php
echo ALL IN ONE;
?>
" > "$location/index.php"
clear
echo -e "${YELLOW} DONE DONE DONE ${NC}"

echo -e "${BLUE} You can access via HTTPs : https://$domain/index.php ${NC}"

bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/menu.sh)
