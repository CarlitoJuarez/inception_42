#!/bin/sh
set -eu

WORDPRESS_DB_PASSWORD="$(cat /run/secrets/mariadb_password)"
WORDPRESS_ADMIN_PASSWORD="$(cat /run/secrets/wordpress_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"
PROCESS_USER="www-data"

mkdir -p "$WP_CLI_CACHE_DIR"
chown "$PROCESS_USER:$PROCESS_USER" "$WP_CLI_CACHE_DIR"
chmod 755 "$WP_CLI_CACHE_DIR"

cd /var/www/html

# Make sure WordPress volume is writable by www-data
chown -R "$PROCESS_USER:$PROCESS_USER" /var/www/html

# wait for MariaDB
attempt=0
max_attempts=30

until nc -z -w 1 "$WORDPRESS_DB_HOST" 3306; do
  attempt=$((attempt + 1))

  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "MariaDB was not reachable after $max_attempts attempts." >&2
    exit 1
  fi

  echo "Waiting for MariaDB... ($attempt/$max_attempts)"
  sleep 2
done

# download wp only if volume is empty
if [ ! -f wp-load.php ]; then
  su-exec "$PROCESS_USER:$PROCESS_USER" wp core download
fi

# create wp-config.php only if missing
if [ ! -f wp-config.php ]; then
  su-exec "$PROCESS_USER:$PROCESS_USER" wp config create \
    --dbname="$WORDPRESS_DB_NAME" \
    --dbuser="$WORDPRESS_DB_USER" \
    --dbpass="$WORDPRESS_DB_PASSWORD" \
    --dbhost="$WORDPRESS_DB_HOST"
fi

# install wp only if not already installed
if ! su-exec "$PROCESS_USER:$PROCESS_USER" wp core is-installed; then
  su-exec "$PROCESS_USER:$PROCESS_USER" wp core install \
    --url="$WORDPRESS_URL" \
    --title="$WORDPRESS_TITLE" \
    --admin_user="$WORDPRESS_ADMIN_USER" \
    --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
    --admin_email="$WORDPRESS_ADMIN_EMAIL" \
    --skip-email
fi

# create regular user if missing
if ! su-exec "$PROCESS_USER:$PROCESS_USER" wp user get "$WP_USER" >/dev/null 2>&1; then
  su-exec "$PROCESS_USER:$PROCESS_USER" wp user create \
    "$WP_USER" \
    "$WP_USER_EMAIL" \
    --user_pass="$WP_USER_PASSWORD" \
    --role="$WP_USER_ROLE"
fi

exec "$@"
