#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/lib/utils.sh"

require_root
is_ubuntu_or_debian || die "This module supports Debian/Ubuntu (apt)."

need_cmd apache2ctl || die "Apache does not seem installed. Run 'Install Apache + PHP' first."

read -rp "Enter site name (default: mysite): " sitename
sitename="${sitename:-mysite}"
conf="/etc/apache2/sites-available/${sitename}.conf"

read -rp "Enter document root (example: /var/www/${sitename}): " root
[[ -n "${root:-}" ]] || die "Document root cannot be empty."

read -rp "Enter domain for SSL (example.com): " domain
[[ -n "${domain:-}" ]] || die "Domain cannot be empty."

info "Ensuring certbot is installed..."
apt_install certbot python3-certbot-apache

info "Creating document root and config..."
mkdir -p "$root"
echo '<?php phpinfo(); ?>' > "$root/index.php"

cat > "$conf" <<EOF
<VirtualHost *:80>
  ServerName ${domain}
  ServerAlias www.${domain}

  DocumentRoot ${root}
  <Directory ${root}>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
  </Directory>

  ErrorLog \${APACHE_LOG_DIR}/${sitename}_error.log
  CustomLog \${APACHE_LOG_DIR}/${sitename}_access.log combined
</VirtualHost>
EOF

a2ensite "${sitename}.conf" >/dev/null 2>&1 || true
a2enmod ssl rewrite >/dev/null 2>&1 || true
systemctl reload apache2

info "Requesting SSL certificate via Certbot..."
certbot --apache -d "$domain" -d "www.$domain"

ok "Site enabled: ${sitename}"
ok "You can test: https://${domain}/index.php"
