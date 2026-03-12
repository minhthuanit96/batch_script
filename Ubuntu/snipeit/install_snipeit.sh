#!/usr/bin/env bash
# =============================================================================
# Snipe-IT v7.1.17 – Local Installer (IP-based, no SSL)
# OS      : Ubuntu 22.04 LTS (fresh server)
# Stack   : Nginx · MariaDB · PHP 8.2 · Composer · Git
# Access  : http://<server-ip>   (no domain, no SSL required)
# Install : /var/www/snipeit
#
# Usage   : sudo bash install_snipeit.sh
#
# BEFORE RUNNING:
#   1. Edit snipeit.conf with your DB password and any custom settings.
#   2. Run: sudo bash install_snipeit.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${GREEN}══════════════════════════════════════════════${NC}"; \
            echo -e "${GREEN}  $*${NC}"; \
            echo -e "${GREEN}══════════════════════════════════════════════${NC}"; }

[[ $EUID -ne 0 ]] && error "Run this script as root: sudo bash $0"

# ── LOAD CONFIGURATION FROM snipeit.conf ─────────────────────────────────────
CONF_FILE="$(dirname "$(realpath "$0")")/snipeit.conf"

if [[ ! -f "$CONF_FILE" ]]; then
    error "Config file not found: ${CONF_FILE}\nCreate it from the template and set your DB_PASS before running."
fi

# Lock down the config file so only root can read it
chmod 600 "$CONF_FILE"

# shellcheck source=snipeit.conf
# Unset any pre-existing values to prevent environment variable injection
unset APP_DIR WEBUSER SNIPEIT_TAG SNIPEIT_REPO PHP_VER \
      DB_NAME DB_USER DB_PASS APP_TIMEZONE APP_LOCALE

# Source in a subshell first to syntax-check, then for real
(bash -n "$CONF_FILE") || error "Syntax error detected in ${CONF_FILE}. Aborting."
# shellcheck disable=SC1090
source "$CONF_FILE"

# ── VALIDATE REQUIRED VARIABLES ───────────────────────────────────────────────
for VAR in APP_DIR WEBUSER SNIPEIT_TAG SNIPEIT_REPO PHP_VER DB_NAME DB_USER DB_PASS; do
    [[ -z "${!VAR:-}" ]] && error "Required variable '${VAR}' is not set in ${CONF_FILE}"
done

if [[ "$DB_PASS" == "Change_Me_Now!" ]]; then
    error "DB_PASS is still the default value. Set a real password in ${CONF_FILE} before running."
fi

# ── DEFAULTS FOR OPTIONAL VARIABLES ───────────────────────────────────────────
APP_TIMEZONE="${APP_TIMEZONE:-UTC}"
APP_LOCALE="${APP_LOCALE:-en}"

info "Configuration loaded from: ${CONF_FILE}"
# ─────────────────────────────────────────────────────────────────────────────

# Detect server IP automatically
SERVER_IP=$(hostname -I | awk '{print $1}')
info "Detected server IP: ${SERVER_IP}"

# =============================================================================
# STEP 1 – SYSTEM PREPARATION
# =============================================================================
section "STEP 1 – System Preparation"

info "Updating package lists and upgrading existing packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y \
    curl wget git unzip zip gnupg2 ca-certificates lsb-release \
    software-properties-common apt-transport-https ufw

# =============================================================================
# STEP 2 – INSTALL PHP 8.2 AND REQUIRED EXTENSIONS
# =============================================================================
section "STEP 2 – PHP 8.2 + Extensions"

info "Adding Ondřej Surý PHP PPA..."
add-apt-repository ppa:ondrej/php -y
apt-get update -y

info "Installing PHP ${PHP_VER} and Snipe-IT required extensions..."
apt-get install -y \
    php${PHP_VER} \
    php${PHP_VER}-fpm \
    php${PHP_VER}-cli \
    php${PHP_VER}-mysql \
    php${PHP_VER}-gd \
    php${PHP_VER}-xml \
    php${PHP_VER}-mbstring \
    php${PHP_VER}-curl \
    php${PHP_VER}-zip \
    php${PHP_VER}-bcmath \
    php${PHP_VER}-tokenizer \
    php${PHP_VER}-intl \
    php${PHP_VER}-fileinfo \
    php${PHP_VER}-exif \
    php${PHP_VER}-ldap \
    php${PHP_VER}-pdo \
    php${PHP_VER}-opcache

# Verify PHP version
PHP_BIN=$(which php)
info "PHP installed: $($PHP_BIN -v | head -1)"

# Configure PHP-FPM
PHP_FPM_INI="/etc/php/${PHP_VER}/fpm/php.ini"
sed -i 's/^;*upload_max_filesize.*/upload_max_filesize = 64M/'  "$PHP_FPM_INI"
sed -i 's/^;*post_max_size.*/post_max_size = 64M/'              "$PHP_FPM_INI"
sed -i 's/^;*memory_limit.*/memory_limit = 256M/'               "$PHP_FPM_INI"
sed -i 's/^;*max_execution_time.*/max_execution_time = 300/'     "$PHP_FPM_INI"
sed -i 's/^;*date.timezone.*/date.timezone = UTC/'               "$PHP_FPM_INI"
sed -i 's/^;*expose_php.*/expose_php = Off/'                     "$PHP_FPM_INI"

systemctl enable php${PHP_VER}-fpm
systemctl restart php${PHP_VER}-fpm
info "PHP-FPM ${PHP_VER} started."

# =============================================================================
# STEP 3 – INSTALL MARIADB AND CREATE DATABASE
# =============================================================================
section "STEP 3 – MariaDB Setup"

info "Installing MariaDB..."
apt-get install -y mariadb-server mariadb-client

systemctl enable mariadb
systemctl start mariadb

info "Securing MariaDB and creating database/user..."
mysql -u root <<SQL
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';
-- Remove remote root login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- Create Snipe-IT database and user
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
info "Database '${DB_NAME}' and user '${DB_USER}' created."

# =============================================================================
# STEP 4 – INSTALL NGINX
# =============================================================================
section "STEP 4 – Nginx"

info "Installing Nginx..."
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

# =============================================================================
# STEP 5 – INSTALL COMPOSER
# =============================================================================
section "STEP 5 – Composer"

if ! command -v composer &>/dev/null; then
    info "Downloading and installing Composer..."
    curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
    EXPECTED_HASH="$(curl -sS https://composer.github.io/installer.sig)"
    ACTUAL_HASH="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
    if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
        error "Composer installer hash mismatch – aborting for security."
    fi
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm /tmp/composer-setup.php
else
    info "Composer already installed: $(composer --version)"
fi

composer self-update --stable 2>/dev/null || true

# =============================================================================
# STEP 6 – DOWNLOAD SNIPE-IT v7.1.17
# =============================================================================
section "STEP 6 – Snipe-IT ${SNIPEIT_TAG}"

if [ -d "${APP_DIR}" ]; then
    warn "Directory ${APP_DIR} already exists. Backing up to ${APP_DIR}.bak..."
    mv "${APP_DIR}" "${APP_DIR}.bak.$(date +%Y%m%d%H%M%S)"
fi

info "Cloning Snipe-IT at tag ${SNIPEIT_TAG}..."
git clone --branch "${SNIPEIT_TAG}" --depth 1 "${SNIPEIT_REPO}" "${APP_DIR}"

# =============================================================================
# STEP 7 – ENVIRONMENT CONFIGURATION (.env)
# =============================================================================
section "STEP 7 – .env Configuration"

cp "${APP_DIR}/.env.example" "${APP_DIR}/.env"

# Generate a random APP_KEY placeholder; artisan key:generate will overwrite it
APP_KEY_PLACEHOLDER="base64:$(openssl rand -base64 32)"

info "Writing .env settings (APP_URL = http://${SERVER_IP})..."
cat > "${APP_DIR}/.env" <<ENV
# ── Application ──────────────────────────────────────────
APP_ENV=production
APP_DEBUG=false
APP_KEY=${APP_KEY_PLACEHOLDER}
APP_URL=http://${SERVER_IP}
APP_TIMEZONE=${APP_TIMEZONE}
APP_LOCALE=${APP_LOCALE}

# ── Database ──────────────────────────────────────────────
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

# ── Session & Cache ───────────────────────────────────────
SESSION_DRIVER=file
CACHE_DRIVER=file
QUEUE_DRIVER=sync

# ── Mail (configure as needed) ───────────────────────────
MAIL_MAILER=smtp
MAIL_HOST=localhost
MAIL_PORT=587
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=snipeit@localhost
MAIL_FROM_NAME="Snipe-IT"
MAIL_REPLYTO_EMAIL=snipeit@localhost
MAIL_REPLYTO_NAME="Snipe-IT"
MAIL_AUTO_EMBED_METHOD=base64

# ── Image / Storage ───────────────────────────────────────
IMAGE_LIB=gd

# ── Logging ───────────────────────────────────────────────
LOG_CHANNEL=daily
LOG_LEVEL=error
APP_LOG_MAX_FILES=30

# ── Security ──────────────────────────────────────────────
ALLOW_ICONV=true
COOKIE_SAMESITE_STRICT=false
ENV

info ".env file written to ${APP_DIR}/.env"

# =============================================================================
# STEP 8 – COMPOSER INSTALL
# =============================================================================
section "STEP 8 – Composer Install"

cd "${APP_DIR}"
info "Running composer install (no-dev, optimised autoloader)..."
composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --prefer-dist

# =============================================================================
# STEP 9 – LARAVEL KEY & ARTISAN SETUP
# =============================================================================
section "STEP 9 – Laravel Key & Artisan Commands"

cd "${APP_DIR}"

info "Generating application key..."
php artisan key:generate --force --ansi

info "Running database migrations..."
php artisan migrate --force

info "Creating symbolic storage link..."
php artisan storage:link

info "Caching config, routes and views..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# =============================================================================
# STEP 10 – FILE PERMISSIONS
# =============================================================================
section "STEP 10 – File Permissions"

info "Setting ownership and permissions..."
chown -R "${WEBUSER}:${WEBUSER}" "${APP_DIR}"
chmod -R 755 "${APP_DIR}"

# Writable directories
for DIR in storage bootstrap/cache public/uploads; do
    chmod -R 775 "${APP_DIR}/${DIR}"
done

info "Permissions set."

# =============================================================================
# STEP 11 – NGINX VIRTUAL HOST (HTTP, IP-based)
# =============================================================================
section "STEP 11 – Nginx Virtual Host"

NGINX_CONF="/etc/nginx/sites-available/snipeit"

info "Writing Nginx configuration (listening on all interfaces, port 80)..."
cat > "${NGINX_CONF}" <<NGINX
# Snipe-IT – IP-based local access
# Document root: ${APP_DIR}/public

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    # Accept requests by IP (and any hostname)
    server_name _;

    root ${APP_DIR}/public;
    index index.php index.html;

    # Basic security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Hide Nginx version
    server_tokens off;

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    # Main routing
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP-FPM
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    # Static assets – cache
    location ~* \.(jpg|jpeg|gif|png|ico|svg|webp|css|js|woff2?|ttf|eot)\$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    # Deny access to sensitive files
    location ~* \.(env|log|htaccess|htpasswd|ini|pem|key)\$ {
        deny all;
        return 404;
    }

    client_max_body_size 64M;

    access_log /var/log/nginx/snipeit.access.log;
    error_log  /var/log/nginx/snipeit.error.log warn;
}
NGINX

# Enable site, disable default
ln -sf "${NGINX_CONF}" "/etc/nginx/sites-enabled/snipeit"
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
info "Nginx configured and reloaded."

# =============================================================================
# STEP 12 – FIREWALL
# =============================================================================
section "STEP 12 – UFW Firewall"

info "Configuring UFW (SSH + HTTP only)..."
ufw allow OpenSSH
ufw allow 'Nginx HTTP'
ufw --force enable
info "UFW enabled."

# =============================================================================
# STEP 13 – QUEUE WORKER (systemd)
# =============================================================================
section "STEP 13 – Laravel Queue Worker (systemd)"

cat > /etc/systemd/system/snipeit-queue.service <<UNIT
[Unit]
Description=Snipe-IT Laravel Queue Worker
After=network.target mariadb.service

[Service]
User=${WEBUSER}
Group=${WEBUSER}
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/php ${APP_DIR}/artisan queue:work --sleep=3 --tries=3 --max-time=3600
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable snipeit-queue
systemctl start snipeit-queue
info "Queue worker service enabled and started."

# =============================================================================
# STEP 14 – SCHEDULER CRON
# =============================================================================
section "STEP 14 – Laravel Scheduler Cron"

CRON_TMP=$(mktemp)
crontab -u "${WEBUSER}" -l 2>/dev/null > "${CRON_TMP}" || true
if ! grep -q "snipeit" "${CRON_TMP}"; then
    echo "* * * * * /usr/bin/php ${APP_DIR}/artisan schedule:run >> /dev/null 2>&1" >> "${CRON_TMP}"
    crontab -u "${WEBUSER}" "${CRON_TMP}"
    info "Cron job for Laravel scheduler added."
else
    info "Scheduler cron already present – skipped."
fi
rm "${CRON_TMP}"

# =============================================================================
# STEP 15 – VALIDATION
# =============================================================================
section "STEP 15 – Validation & Quick Checks"

echo ""
info "── Service Status ──────────────────────────────────────"
for SVC in nginx php${PHP_VER}-fpm mariadb snipeit-queue; do
    STATUS=$(systemctl is-active "$SVC" 2>/dev/null || echo "inactive")
    if [ "$STATUS" = "active" ]; then
        echo -e "  ${GREEN}✓${NC} $SVC"
    else
        echo -e "  ${RED}✗${NC} $SVC  (status: $STATUS)"
    fi
done

echo ""
info "── PHP Extensions ───────────────────────────────────────"
REQUIRED_EXTS="bcmath curl exif fileinfo gd intl json mbstring openssl pdo pdo_mysql tokenizer xml zip"
for EXT in $REQUIRED_EXTS; do
    if php -m 2>/dev/null | grep -qi "^${EXT}$"; then
        echo -e "  ${GREEN}✓${NC} php-${EXT}"
    else
        echo -e "  ${RED}✗${NC} php-${EXT}  (MISSING)"
    fi
done

echo ""
info "── Directory Permissions ────────────────────────────────"
for DIR in storage bootstrap/cache public/uploads; do
    FULL="${APP_DIR}/${DIR}"
    if [ -w "$FULL" ] || sudo -u "${WEBUSER}" test -w "$FULL" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} ${FULL} is writable"
    else
        echo -e "  ${RED}✗${NC} ${FULL} is NOT writable"
    fi
done

echo ""
info "── HTTP Connectivity ────────────────────────────────────"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${SERVER_IP}" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" =~ ^(200|302)$ ]]; then
    echo -e "  ${GREEN}✓${NC} http://${SERVER_IP} returned HTTP ${HTTP_CODE}"
else
    echo -e "  ${YELLOW}~${NC} http://${SERVER_IP} returned HTTP ${HTTP_CODE}"
fi

# =============================================================================
# TROUBLESHOOTING REFERENCE
# =============================================================================
section "TROUBLESHOOTING REFERENCE"

cat <<TIPS
══════════════════════════════════════════════════════════════════════
  COMMON TROUBLESHOOTING COMMANDS
══════════════════════════════════════════════════════════════════════

  ── Logs ──────────────────────────────────────────────────────────
  tail -f /var/log/nginx/snipeit.error.log
  tail -f /var/www/snipeit/storage/logs/laravel-\$(date +%Y-%m-%d).log
  journalctl -u php${PHP_VER}-fpm -f
  journalctl -u mariadb -f
  journalctl -u snipeit-queue -f

  ── Nginx ─────────────────────────────────────────────────────────
  nginx -t                              # Test config
  systemctl reload nginx                # Reload after changes
  systemctl restart nginx

  ── PHP-FPM ───────────────────────────────────────────────────────
  systemctl restart php${PHP_VER}-fpm
  php -m | grep -E 'gd|xml|mbstring'   # Check extensions

  ── MariaDB ───────────────────────────────────────────────────────
  mysql -u ${DB_USER} -p ${DB_NAME}    # Connect to DB
  mysqlcheck -u root ${DB_NAME}        # Check tables

  ── Laravel / Snipe-IT ────────────────────────────────────────────
  cd ${APP_DIR}
  php artisan snipeit:check-keys        # Verify env keys
  php artisan config:clear && php artisan config:cache
  php artisan migrate --force           # Re-run migrations
  php artisan storage:link              # Re-create storage symlink

  ── Permissions reset ─────────────────────────────────────────────
  chown -R www-data:www-data ${APP_DIR}
  chmod -R 755 ${APP_DIR}
  chmod -R 775 ${APP_DIR}/storage ${APP_DIR}/bootstrap/cache

  ── 500 errors ────────────────────────────────────────────────────
  Set APP_DEBUG=true in .env temporarily, then revert!
  php artisan config:clear

══════════════════════════════════════════════════════════════════════
TIPS

# =============================================================================
# DONE
# =============================================================================
section "INSTALLATION COMPLETE"

echo -e ""
echo -e "  ${GREEN}Snipe-IT ${SNIPEIT_TAG} has been installed successfully.${NC}"
echo -e ""
echo -e "  URL  : ${GREEN}http://${SERVER_IP}${NC}"
echo -e "  Dir  : ${APP_DIR}"
echo -e "  DB   : ${DB_NAME}  (user: ${DB_USER})"
echo -e ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. Open http://${SERVER_IP} in your browser."
echo -e "  2. Complete the Snipe-IT web setup wizard."
echo -e "  3. Update MAIL_* settings in ${APP_DIR}/.env if email is needed."
echo -e ""
