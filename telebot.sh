#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${YELLOW} Installing php and apache .... ${NC}"
sleep 2
sudo apt install apache2 php libapache2-mod-php
sudo a2enmod php7.4
sudo a2enmod rewrite
root=""
config_file_content="<VirtualHost *:80>
    ServerName your_website.com
    ServerAlias www.your_website.com

    DocumentRoot /var/www/my_website

    <Directory /var/www/my_website>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/my_website_error.log
    CustomLog ${APACHE_LOG_DIR}/my_website_access.log combined
</VirtualHost>
"
config_file_address=" /etc/apache2/sites-available/all_in_one.conf"
sudo echo -e "$config_file_content" | sudo tee $config_file_address >/dev/null
read -p "enter your root location ( default: /var/www/my_website | must type like : /var/www/your location ) :" location
while [[ -z "$domain" ]]; do
    read -p "Enter your domain for SSL : " domain
    if [[ -z "$domain" ]]; then
        echo "domain can not be empty"
    fi
done
if [ -z "$location" ]; then
    root="/var/www/my_website"
    sudo mkdir -p /var/www/my_website
    sudo echo '<?php phpinfo(); ?>' | sudo tee $root/index.php > /dev/null
else
    root="$location"
    sudo mkdir -p $root
    sudo echo '<?php phpinfo(); ?>' | sudo tee $root/index.php > /dev/null
    sudo sed -i "s|DocumentRoot /var/www/my_website|DocumentRoot $root|" "$config_file_address"
    sudo sed -i "s|<Directory /var/www/my_website>|<Directory $root>|" "$config_file_address"
fi

if [ -n "$domain" ]; then
    sudo sed -i "s|ServerName your_website.com|ServerName $domain|" "$config_file_address"
    sudo sed -i "s|ServerAlias www.your_website.com|ServerAlias www.$domain>|" "$config_file_address"
fi
sudo a2ensite all_in_one.conf
sudo a2enmod ssl
sudo apt install certbot python3-certbot-apache
sudo certbot --apache -d $domain -d www.$domain
echo -e "${YELLOW} DONE DONE DONE ${NC}"

echo -e "${BLUE} You can access via HTTPs : https://$domain/index.php ${NC}"

bash <(curl -Ls https://raw.githubusercontent.com/Salarsdg/All-in-one/main/menu.sh)
