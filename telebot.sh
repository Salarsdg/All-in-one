#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${YELLOW} Installing php and nginx .... ${NC}"
sleep 10
apt-get install php
apt install nginx
sudo systemctl start nginx
sudo systemctl enable nginx
clear
sleep 10
read -p "${BLUE} enter your domain for SSL and certificate :  ${NC}" domain

sudo certbot --nginx -d "$domain" -d "$domain"

sleep 10

cat > "/etc/nginx/sites-available/$domain" <<EOF
server {
    listen 443 ssl;
    server_name $domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    # Additional SSL configurations (optional)

    location / {
        # Root directory of your website
        root /var/www/html;
        index index.php index.html index.htm;
    }

    location ~ \.php$ {
        # Path to PHP-FPM socket
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;  # Adjust version if needed
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
EOF

echo "NGINX configuration file created for $domain."

sleep 10
sudo nginx -s reload

