#!/bin/sh
set -eu

MARIADB_PASSWORD="$(cat /run/secrets/mariadb_password)"
MARIADB_ROOT_PASSWORD="$(cat /run/secrets/mariadb_root_password)"

DATADIR="/var/lib/mysql"

: "${MARIADB_DATABASE:?MARIADB_DATABASE is not set}"
: "${MARIADB_USER:?MARIADB_USER is not set}"
: "${MARIADB_PASSWORD:?MARIADB_PASSWORD is not set}"
: "${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD is not set}"

mkdir -p /run/mysqld "$DATADIR"
chown -R mysql:mysql /run/mysqld "$DATADIR"

if [ ! -d "$DATADIR/mysql" ]; then
  mariadb-install-db \
    --user=mysql \
    --datadir="$DATADIR" \
    --auth-root-authentication-method=normal

  su-exec mysql mariadbd \
    --bootstrap \
    --datadir="$DATADIR" \
    --skip-networking <<SQL
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%'
    IDENTIFIED BY '${MARIADB_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.*
    TO '${MARIADB_USER}'@'%';

ALTER USER 'root'@'localhost'
    IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';

FLUSH PRIVILEGES;
SQL
fi

exec su-exec mysql mariadbd \
  --datadir="$DATADIR" \
  --bind-address=0.0.0.0 \
  --socket=/run/mysqld/mysqld.sock \
  --port=3306 \
  --skip-networking=0
