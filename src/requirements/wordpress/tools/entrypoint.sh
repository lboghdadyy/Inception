#!/bin/bash

echo "================ starting wordpress ================"

SECRETFILE="/run/secrets/mySqlPassword"

if [[ ! -f "$SECRETFILE" || ! -r "$SECRETFILE" ]]; then
    echo "ERR: Something is wrong with your secret files"
    exit 1
fi

DATABASE="${MYSQL_DB:?MYSQL_DB is not set}"
USERNAME="${MYSQL_USERN:?MYSQL_USER is not set}"

echo "define('DB_NAME', '$DATABASE');
define('DB_USER', '$USERNAME');
define('DB_PASSWORD', '$(cat $SECRETFILE)');
define('HOST_NAME', 'mariadb');" > wp-config.php

