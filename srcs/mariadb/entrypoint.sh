#!/bin/sh
set -eu

# secrets
MARIADB_PASSWORD="$(cat /run/secrets/mariadb_password)"
MARIADB_ROOT_PASSWORD="$(cat /run/secrets/mariadb_root_password)"

DATADIR="/var/lib/mysql"

: "${MARIADB_DATABASE:?MARIADB_DATABASE is not set}"
: "${MARIADB_USER:?MARIADB_USER is not set}"
: "${MARIADB_PASSWORD:?MARIADB_PASSWORD is not set}"
: "${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD is not set}"

# -p : parent flag
# -R : recursive
mkdir -p /run/mysqld "$DATADIR"
chown -R mysql:mysql /run/mysqld "$DATADIR"

# create DB
if [ ! -d "$DATADIR/mysql" ]; then
  mariadb-install-db --user=mysql --datadir="$DATADIR"

  su-exec mysql mariadbd \
    --datadir="$DATADIR" \
    --socket=/run/mysqld/mysqld.sock \
    --skip-networking &

  pid="$!"

  i=0
  until mariadb-admin --socket=/run/mysqld/mysqld.sock ping --silent; do
    i=$((i + 1))
    if [ "$i" -gt 60 ]; then
      echo "MariaDB failed to start"
      exit 1
    fi
    sleep 1
  done

  # 1. connect to DB as root
  # 2. create DB with collation
  # 3. create user set password for user ( can connect from anywhere '@'%' )
  # 4. grant all privileges to this user
  # 5. sets root password
  # 6. flush = make changes active
  mariadb --socket=/run/mysqld/mysqld.sock <<SQL
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL

  mariadb-admin \
    --socket=/run/mysqld/mysqld.sock \
    -uroot \
    -p"${MARIADB_ROOT_PASSWORD}" \
    shutdown

  wait "$pid" || true
fi

exec su-exec mysql mariadbd \
  --datadir="$DATADIR" \
  --bind-address=0.0.0.0 \
  --socket=/run/mysqld/mysqld.sock \
  --port=3306 \
  --skip-networking=0
