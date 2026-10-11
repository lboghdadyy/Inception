#!/bin/bash
set -e
echo "================ starting wordpress ================"
SECRETFILE="/run/secrets/mySqlPassword"
DIR="/var/www/html/"

if [[ ! -f "$SECRETFILE" || ! -r "$SECRETFILE" ]]; then
    echo "ERR: Something is wrong with your secret files"
    exit 1
fi

DATABASE="${MYSQL_DB:?MYSQL_DB is not set}"
USERNAME="${MYSQL_USER:?MYSQL_USER is not set}"


if [[ ! -f "${DIR}wp-config.php" ]]; then
    DB_PASSWORD="$(cat "$SECRETFILE")"

    wp config create \
        --path="$DIR" \
        --dbname="$DATABASE" \
        --dbuser="$USERNAME" \
        --dbhost="mariadb" \
        --prompt=dbpass <<< "$DB_PASSWORD"

    wp config shuffle-salts --path="$DIR"
fi
exec php-fpm$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;') -F
