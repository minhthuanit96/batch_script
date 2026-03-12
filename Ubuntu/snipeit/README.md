# Snipe-IT v7.1.17 – Installation Guide

**Stack:** Ubuntu 22.04 LTS · Nginx · MariaDB · PHP 8.2 · Composer · Git  
**App path:** `/var/www/snipeit`  
**Access:** `http://<server-ip>` (local/IP-based, no SSL)

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [System Preparation](#2-system-preparation)
3. [PHP 8.2 Installation](#3-php-82-installation)
4. [MariaDB Setup](#4-mariadb-setup)
5. [Nginx Installation](#5-nginx-installation)
6. [Composer Installation](#6-composer-installation)
7. [Download Snipe-IT v7.1.17](#7-download-snipe-it-v7117)
8. [Environment Configuration (.env)](#8-environment-configuration-env)
9. [Composer Install](#9-composer-install)
10. [Artisan Commands](#10-artisan-commands)
11. [File Permissions](#11-file-permissions)
12. [Nginx Virtual Host](#12-nginx-virtual-host)
13. [Firewall](#13-firewall)
14. [Queue Worker & Scheduler](#14-queue-worker--scheduler)
15. [Validation](#15-validation)
16. [Troubleshooting](#16-troubleshooting)

---

## 1. Prerequisites

- Fresh Ubuntu 22.04 LTS server
- Root or `sudo` access
- Internet access (to pull packages and clone the repo)

> All commands below must be run as **root** (`sudo -i` or prefix with `sudo`).

---

## 2. System Preparation

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y
apt-get install -y \
    curl wget git unzip zip gnupg2 ca-certificates lsb-release \
    software-properties-common apt-transport-https ufw
```

---

## 3. PHP 8.2 Installation

### Add PPA and install

```bash
add-apt-repository ppa:ondrej/php -y
apt-get update -y

apt-get install -y \
    php8.2 php8.2-fpm php8.2-cli \
    php8.2-mysql php8.2-gd php8.2-xml \
    php8.2-mbstring php8.2-curl php8.2-zip \
    php8.2-bcmath php8.2-tokenizer php8.2-intl \
    php8.2-fileinfo php8.2-exif php8.2-ldap \
    php8.2-pdo php8.2-opcache
```

> **Note:** `php8.2-json` does **not** exist — JSON is bundled into PHP core since PHP 8.0.

### Verify

```bash
php -v
php -m | grep -E 'gd|mbstring|xml|curl|zip|bcmath|intl|opcache'
```

### Tune php.ini

```bash
PHP_INI="/etc/php/8.2/fpm/php.ini"
sed -i 's/^;*upload_max_filesize.*/upload_max_filesize = 64M/' $PHP_INI
sed -i 's/^;*post_max_size.*/post_max_size = 64M/'             $PHP_INI
sed -i 's/^;*memory_limit.*/memory_limit = 256M/'              $PHP_INI
sed -i 's/^;*max_execution_time.*/max_execution_time = 300/'    $PHP_INI
sed -i 's/^;*date.timezone.*/date.timezone = UTC/'              $PHP_INI
sed -i 's/^;*expose_php.*/expose_php = Off/'                    $PHP_INI

systemctl enable php8.2-fpm
systemctl restart php8.2-fpm
```

---

## 4. MariaDB Setup

### Install and start

```bash
apt-get install -y mariadb-server mariadb-client
systemctl enable mariadb
systemctl start mariadb
```

### Create database and user

```bash
mysql -u root <<SQL
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';

CREATE DATABASE snipeit CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'snipeit'@'localhost' IDENTIFIED BY 'YOUR_STRONG_PASSWORD';
GRANT ALL PRIVILEGES ON snipeit.* TO 'snipeit'@'localhost';
FLUSH PRIVILEGES;
SQL
```

### Verify connection

```bash
mysql -u snipeit -p snipeit -e "SELECT VERSION();"
```

---

## 5. Nginx Installation

```bash
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
```

---

## 6. Composer Installation

```bash
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php

# Verify checksum
EXPECTED=$(curl -sS https://composer.github.io/installer.sig)
ACTUAL=$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")
[ "$EXPECTED" = "$ACTUAL" ] || { echo "Hash mismatch!"; exit 1; }

php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm /tmp/composer-setup.php
composer --version
```

---

## 7. Download Snipe-IT v7.1.17

```bash
git clone --branch v7.1.17 --depth 1 \
    https://github.com/snipe/snipe-it.git \
    /var/www/snipeit
```

---

## 8. Environment Configuration (.env)

```bash
cp /var/www/snipeit/.env.example /var/www/snipeit/.env
```

Edit `/var/www/snipeit/.env` with the following content:

```ini
# ── Application ──────────────────────────────────────────────────────────────
APP_ENV=production
APP_DEBUG=false
APP_KEY=                        # filled in by artisan key:generate
APP_URL=http://YOUR_SERVER_IP
APP_TIMEZONE=Asia/Ho_Chi_Minh
APP_LOCALE=vi-VN

# ── Database ──────────────────────────────────────────────────────────────────
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=snipeit
DB_USERNAME=snipeit
DB_PASSWORD=YOUR_STRONG_PASSWORD

# ── Session & Cache ───────────────────────────────────────────────────────────
SESSION_DRIVER=file
CACHE_DRIVER=file
QUEUE_DRIVER=sync

# ── Mail ──────────────────────────────────────────────────────────────────────
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

# ── Image Library ─────────────────────────────────────────────────────────────
IMAGE_LIB=gd

# ── Logging ───────────────────────────────────────────────────────────────────
LOG_CHANNEL=daily
LOG_LEVEL=error
APP_LOG_MAX_FILES=30

# ── Security ──────────────────────────────────────────────────────────────────
ALLOW_ICONV=true
COOKIE_SAMESITE_STRICT=false
```

---

## 9. Composer Install

```bash
cd /var/www/snipeit

composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --prefer-dist
```

> `--no-dev` excludes packages like `fakerphp/faker`. Do **not** run `php artisan db:seed` — it requires Faker and is not needed; the web wizard handles initial data.

---

## 10. Artisan Commands

```bash
cd /var/www/snipeit

# 1. Generate application key (writes to .env APP_KEY)
php artisan key:generate --force --ansi

# 2. Run database migrations
php artisan migrate --force

# 3. Create public storage symlink
php artisan storage:link

# 4. Cache for performance
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

### Clear cache (use when changing .env)

```bash
php artisan config:clear
php artisan route:clear
php artisan view:clear
```

---

## 11. File Permissions

```bash
# Set ownership
chown -R www-data:www-data /var/www/snipeit
chmod -R 755 /var/www/snipeit

# Writable directories
chmod -R 775 /var/www/snipeit/storage
chmod -R 775 /var/www/snipeit/bootstrap/cache
chmod -R 775 /var/www/snipeit/public/uploads
```

---

## 12. Nginx Virtual Host

Create `/etc/nginx/sites-available/snipeit`:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    # Accepts requests by IP address (no domain needed)
    server_name _;

    root /var/www/snipeit/public;
    index index.php index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    server_tokens off;

    # Deny hidden files
    location ~ /\. {
        deny all;
    }

    # Laravel front controller
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP-FPM
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    # Static assets
    location ~* \.(jpg|jpeg|gif|png|ico|svg|webp|css|js|woff2?|ttf|eot)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    # Deny sensitive files
    location ~* \.(env|log|htaccess|htpasswd|ini|pem|key)$ {
        deny all;
        return 404;
    }

    client_max_body_size 64M;

    access_log /var/log/nginx/snipeit.access.log;
    error_log  /var/log/nginx/snipeit.error.log warn;
}
```

### Enable the site

```bash
ln -sf /etc/nginx/sites-available/snipeit /etc/nginx/sites-enabled/snipeit
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
```

---

## 13. Firewall

```bash
ufw allow OpenSSH
ufw allow 'Nginx HTTP'
ufw --force enable
ufw status
```

---

## 14. Queue Worker & Scheduler

### Queue worker (systemd service)

Create `/etc/systemd/system/snipeit-queue.service`:

```ini
[Unit]
Description=Snipe-IT Laravel Queue Worker
After=network.target mariadb.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/snipeit
ExecStart=/usr/bin/php /var/www/snipeit/artisan queue:work --sleep=3 --tries=3 --max-time=3600
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable snipeit-queue
systemctl start snipeit-queue
```

### Laravel scheduler (cron)

```bash
crontab -u www-data -e
```

Add this line:

```
* * * * * /usr/bin/php /var/www/snipeit/artisan schedule:run >> /dev/null 2>&1
```

---

## 15. Validation

### Service status

```bash
systemctl is-active nginx php8.2-fpm mariadb snipeit-queue
```

### PHP extensions

```bash
php -m | grep -E 'bcmath|curl|exif|fileinfo|gd|intl|mbstring|pdo|xml|zip'
```

### Directory permissions

```bash
ls -ld /var/www/snipeit/storage \
        /var/www/snipeit/bootstrap/cache \
        /var/www/snipeit/public/uploads
```

### HTTP connectivity

```bash
curl -so /dev/null -w "%{http_code}" http://$(hostname -I | awk '{print $1}')
# Expected: 200 or 302
```

### Open in browser

```
http://<server-ip>
```

The Snipe-IT **setup wizard** will appear. Use it to create the first admin account and company.

---

## 16. Troubleshooting

### Logs

| Log | Path |
|-----|------|
| Nginx error | `/var/log/nginx/snipeit.error.log` |
| Laravel app | `/var/www/snipeit/storage/logs/laravel-YYYY-MM-DD.log` |
| PHP-FPM | `journalctl -u php8.2-fpm -f` |
| Queue worker | `journalctl -u snipeit-queue -f` |

```bash
# Live Nginx errors
tail -f /var/log/nginx/snipeit.error.log

# Live Laravel log (today)
tail -f /var/www/snipeit/storage/logs/laravel-$(date +%Y-%m-%d).log
```

### Common issues

| Symptom | Fix |
|---------|-----|
| **500 Internal Server Error** | Set `APP_DEBUG=true` temporarily, check Laravel log, then revert |
| **white screen / blank page** | Run `php artisan config:clear` |
| **storage/ not writable** | `chown -R www-data:www-data /var/www/snipeit/storage` |
| **502 Bad Gateway** | Restart PHP-FPM: `systemctl restart php8.2-fpm` |
| **`Class "Faker\Factory" not found`** | Do **not** run `db:seed`; use the web setup wizard instead |
| **`php8.2-json` not found** | Remove it — JSON is built into PHP 8.x core |
| **Migrations fail** | Check `DB_*` values in `.env`; verify MariaDB is running |
| **APP_KEY missing** | Run `php artisan key:generate --force` |

### Reset permissions

```bash
chown -R www-data:www-data /var/www/snipeit
chmod -R 755 /var/www/snipeit
chmod -R 775 /var/www/snipeit/storage \
             /var/www/snipeit/bootstrap/cache \
             /var/www/snipeit/public/uploads
```

### Re-run caches after .env change

```bash
cd /var/www/snipeit
php artisan config:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

### Verify Snipe-IT environment keys

```bash
cd /var/www/snipeit
php artisan snipeit:check-keys
```

### Re-run migrations (safe to repeat)

```bash
cd /var/www/snipeit
php artisan migrate --force
```

---

## Automated Installation

A fully automated installer script is included:

```bash
# 1. Edit credentials
nano snipeit.conf

# 2. Run
sudo bash install_snipeit.sh
```

See [`snipeit.conf`](./snipeit.conf) for all configurable variables.  
Sensitive values are isolated in `snipeit.conf` (auto-set to `chmod 600`) and never hardcoded in the installer script.
