#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/lib/utils.sh"

require_root
is_ubuntu_or_debian || die "This module supports Debian/Ubuntu (apt)."

need_cmd curl
need_cmd a2ensite || true

info "Installing Apache, PHP, and Certbot..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends ca-certificates gnupg lsb-release

# Add ondrej/php PPA (Ubuntu). On Debian, this may fail; we try and continue.
if command -v add-apt-repository >/dev/null 2>&1; then
  warn "Adding PPA: ondrej/php (Ubuntu). If you are on Debian, this may not be applicable."
  add-apt-repository -y ppa:ondrej/php || warn "Could not add PPA; continuing with default repos."
fi

apt-get update -y
apt-get install -y --no-install-recommends apache2 php libapache2-mod-php certbot python3-certbot-apache
a2enmod ssl rewrite >/dev/null 2>&1 || true
systemctl enable --now apache2

read -rp "Enter your domain (example.com): " domain
[[ -n "${domain:-}" ]] || die "Domain cannot be empty."

read -rp "Enter document root (default: /var/www/${domain}): " root
root="${root:-/var/www/${domain}}"

site_name="${domain//./_}"
conf="/etc/apache2/sites-available/${site_name}.conf"

info "Creating site at: $conf"
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

  ErrorLog \${APACHE_LOG_DIR}/${site_name}_error.log
  CustomLog \${APACHE_LOG_DIR}/${site_name}_access.log combined
</VirtualHost>
EOF

a2ensite "${site_name}.conf" >/dev/null 2>&1 || true
a2dissite 000-default.conf >/dev/null 2>&1 || true
systemctl reload apache2

info "Requesting SSL certificate via Certbot (Apache plugin)..."
# This will ask for email/ToS; user can pass flags later if desired.
certbot --apache -d "$domain" -d "www.$domain"

ok "Done."
ok "You can test: https://${domain}/index.php"
