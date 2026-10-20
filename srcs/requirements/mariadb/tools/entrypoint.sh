#!/bin/bash
set -e
unset MYSQL_HOST MARIADB_HOST
ROOT_PASSWORD="$(cat /run/secrets/mySqlRootPassword)"
MYSQL_PASSWORD="$(cat /run/secrets/mySqlPassword)"

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null
fi

chown -R mysql:mysql /var/lib/mysql

if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    mysqld --user=mysql --skip-networking &

    until mariadb-admin --protocol=socket ping --silent 2>/dev/null; do
        sleep 1
    done

    mariadb --protocol=socket <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    mariadb-admin --protocol=socket --user=root --password="${ROOT_PASSWORD}" shutdown

    while pgrep -x mariadbd >/dev/null || pgrep -x mysqld >/dev/null; do
        sleep 1
    done
fi

exec mysqld --user=mysql