#!/bin/sh
set -e

WORDPRESS_DB_PASSWORD="$(cat /run/secrets/mariadb_password)"
WORDPRESS_ADMIN_PASSWORD="$(cat /run/secrets/wordpress_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

cd /var/www/html

# Make sure WordPress volume is writable by www-data
chown -R 33:33 /var/www/html

# wait for MariaDB
until nc -z "$WORDPRESS_DB_HOST" 3306; do
  echo "Waiting for MariaDB..."
  sleep 2
done

# download wp only if volume is empty
if [ ! -f wp-load.php ]; then
  su-exec 33:33 wp core download
fi

# create wp-config.php only if missing
if [ ! -f wp-config.php ]; then
  su-exec 33:33 wp config create \
    --dbname="$WORDPRESS_DB_NAME" \
    --dbuser="$WORDPRESS_DB_USER" \
    --dbpass="$WORDPRESS_DB_PASSWORD" \
    --dbhost="$WORDPRESS_DB_HOST"
fi

# install wp only if not already installed
if ! su-exec 33:33 wp core is-installed; then
  su-exec 33:33 wp core install \
    --url="$WORDPRESS_URL" \
    --title="$WORDPRESS_TITLE" \
    --admin_user="$WORDPRESS_ADMIN_USER" \
    --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
    --admin_email="$WORDPRESS_ADMIN_EMAIL" \
    --skip-email
fi

# create regular user if missing
if ! su-exec 33:33 wp user get "$WP_USER" >/dev/null 2>&1; then
  su-exec 33:33 wp user create \
    "$WP_USER" \
    "$WP_USER_EMAIL" \
    --user_pass="$WP_USER_PASSWORD" \
    --role="$WP_USER_ROLE"
fi

exec su-exec 33:33 "$@"
