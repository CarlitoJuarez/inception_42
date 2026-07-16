#!/bin/sh

# on error exit
set -e
FTP_PASS="$(cat /run/secrets/ftp_password)"

# required env vars
: "${FTP_USER:?FTP_USER is not set}"
: "${FTP_PASS:?FTP_PASS is not set}"

WP_PATH="/var/www/html"

# make sure volume exists
mkdir -p "$WP_PATH"

# vsftpd expects a secure chroot dir where it can run some child proccesses in;
# which cannot be jailed out of
# default as /var/run/vsftpd/empty which:
#   - must exist
#   - must be empty
#   - not be writable by FTP user aka www-data

mkdir -p /var/run/vsftpd/empty

chown root:root /var/run/vsftpd /var/run/vsftpd/empty
chmod 755 /var/run/vsftpd
chmod 555 /var/run/vsftpd/empty

echo "$FTP_USER:$FTP_PASS" | chpasswd

# recursively set FTP_USER as owner for all files / dir inside
# also the www-data cannot jail out
chown -R "$FTP_USER:www-data" "$WP_PATH"

find "$WP_PATH" -type d -exec chmod 775 {} +
find "$WP_PATH" -type f -exec chmod 664 {} +

exec vsftpd /etc/vsftpd/vsftpd.conf
