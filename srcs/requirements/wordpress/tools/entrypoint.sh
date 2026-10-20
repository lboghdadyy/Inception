#!/bin/bash
set -e

DB_PASSWORD="$(cat /run/secrets/mySqlPassword)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp-AdminPassword)"
WP_USER_PASSWORD="$(cat /run/secrets/wp-UserPassword)"

WP_PATH=/var/www/html

if [ ! -f /usr/local/bin/wp ]; then
    curl -sSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
    chmod +x /usr/local/bin/wp
fi
if [ ! -d ${WP_PATH} ] ; then 
    mkdir -p "${WP_PATH}"
    cd "${WP_PATH}"
fi

if [ ! -f wp-load.php ]; then
    wp core download --allow-root
fi

if [ ! -f wp-config.php ]; then
    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="${MYSQL_HOST}"
    if ! grep -q "_SERVER\['HTTP_HOST'\]" wp-config.php; then
        sed -i "/That's all, stop editing/i if ( ! isset( \$_SERVER['HTTP_HOST'] ) ) { \$_SERVER['HTTP_HOST'] = '${DOMAIN_NAME}'; }" wp-config.php
    fi
else
    echo "wp-config.php already exists !"
fi

if ! wp core is-installed --allow-root; then
    wp core install --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email
fi

if ! wp user get "${WP_USER}" --allow-root >/dev/null 2>&1; then
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=author --allow-root
fi

chown -R www-data:www-data "${WP_PATH}"

mkdir -p /run/php0

exec php-fpm8.2 -F