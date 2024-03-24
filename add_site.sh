#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${YELLOW} Installing php and apache .... ${NC}"
sleep 2
sudo apt update
sudo add-apt-repository ppa:ondrej/php
sudo apt install apache2 php libapache2-mod-php
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

read -p "enter your site name : ( default: mysite ) :" sitename

if [ -z "$sitename" ]; then
    sitename="mysite"
    config_file_address="/etc/apache2/sites-available/$sitename.conf"
    sudo touch $config_file_address
    sudo echo -e "$config_file_content" | sudo tee $config_file_address >/dev/null

else
    config_file_address="/etc/apache2/sites-available/$sitename.conf"
    sudo touch $config_file_address
    sudo echo -e "$config_file_content" | sudo tee $config_file_address >/dev/null
fi

while [[ -z "$location" ]]; do
    read -p "enter your new site location :" location
    if [[ -z "$location" ]]; then
        echo "location can not be empty"
    fi
done
if [ -n "$location" ]; then
    root="$location"
    sudo mkdir -p $root
    sudo echo '<?php phpinfo(); ?>' | sudo tee $root/index.php >/dev/null
    sudo sed -i "s|DocumentRoot /var/www/my_website|DocumentRoot $root|" "$config_file_address"
    sudo sed -i "s|<Directory /var/www/my_website>|<Directory $root>|" "$config_file_address"
fi
while [[ -z "$domain" ]]; do
    read -p "Enter your domain for SSL : " domain
    if [[ -z "$domain" ]]; then
        echo "domain can not be empty"
    fi
done
if [ -n "$domain" ]; then
    sudo sed -i "s|ServerName your_website.com|ServerName $domain|" "$config_file_address"
    sudo sed -i "s|ServerAlias www.your_website.com|ServerAlias www.$domain>|" "$config_file_address"
fi

sudo a2ensite $sitename.conf
sudo a2enmod ssl
sudo apt install certbot python3-certbot-apache
sudo certbot --apache -d $domain
