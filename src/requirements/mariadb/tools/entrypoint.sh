```bash
#!/bin/bash

set -e

echo "============ starting mariadb ============"

FILE="/var/lib/mysql/mysql"

SECRETFILE="/run/secrets/mySqlPassword"

if [[ ! -f "$SECRETFILE" || ! -r "$SECRETFILE" ]]; then
    echo "ERR: Something is wrong with your secret files"
    exit 1
fi

PASSWORD=$(cat "$SECRETFILE")

if [[ -z "$PASSWORD" ]]; then
    echo "ERR: Invalid PASSWORD"
    exit 1
fi

DATABASE="${MYSQL_DB:?MYSQL_DB is not set}"
USERNAME="${MYSQL_USER:?MYSQL_USER is not set}"

MYSQLFILE="/var/lib/mysql"

if [[ ! -d "$FILE" ]]; then
    mariadb-install-db \
        --user=mysql \
        --basedir=/usr \
        --datadir="$MYSQLFILE" \
        --auth-root-authentication-method=socket
    chown -R mysql:mysql "$MYSQLFILE"
    mariadbd --user=mysql --datadir="$MYSQLFILE" --skip-networking &
    MARIADBPID=$!
    until mariadb-admin --user=root ping --silent; do
        if ! kill -0 "$MARIADBPID" 2>/dev/null; then
            echo "ERR: MariaDB failed to start"
            exit 1
        fi
        sleep 1
    done
    mariadb --user=root <<SQL
CREATE DATABASE IF NOT EXISTS \`$DATABASE\`;
CREATE USER IF NOT EXISTS '$USERNAME'@'%' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON \`$DATABASE\`.* TO '$USERNAME'@'%';
SQL
    mariadb-admin --user=root shutdown
    wait "$MARIADBPID"
fi

exec mariadbd --user=mysql --datadir="$MYSQLFILE"