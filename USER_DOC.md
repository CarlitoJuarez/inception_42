# Inception User Documentation

## 1. Overview

Inception is a Docker Compose infrastructure running inside a Linux virtual machine.

The mandatory services are:

- **NGINX** — the only public web entrypoint, available through HTTPS on port `443`.
- **WordPress with PHP-FPM** — runs the WordPress application without NGINX.
- **MariaDB** — stores the WordPress database without NGINX.

The project also contains additional services:

- **Redis** — currently runs as an internal Redis service; WordPress cache integration is not part of the current implementation.
- **FTP** — provides access to the persistent WordPress files.
- **Adminer** — provides a browser interface for the WordPress database.
- **Static website** — served directly by the existing NGINX container under `/static/`.

The containers communicate through the private Docker network named `inception`.

## 2. Requirements

Run the project inside the configured Linux virtual machine with:

- Docker
- Docker Compose
- GNU Make

The project uses the domain:

```txt
cjuarez.42.fr
```

For access inside the VM, add this line to `/etc/hosts`:

```txt
127.0.0.1 cjuarez.42.fr
```

For the necessary credentials and env variables an .env file will be copied from outside the VM.
All passwords are created via the following commands:

mkdir srcs/secrets
openssl rand -base64 24 > srcs/secrets/mariadb_password.txt
openssl rand -base64 24 > srcs/secrets/mariadb_root_password.txt
openssl rand -base64 24 > srcs/secrets/wordpress_admin_password.txt
openssl rand -base64 24 > srcs/secrets/wp_user_password.txt
openssl rand -base64 24 > srcs/secrets/ftp_password.txt



For access from another computer, replace `127.0.0.1` with the VM IP address.

## 3. Starting the project

From the repository root, run:

```sh
make
```

This command:

1. Creates the persistent host directories.
2. Builds the Docker images.
3. Creates the Docker network and named volumes.
4. Starts the containers in detached mode.

Other available commands:

```sh
make build
make up
make start
make restart
```

## 4. Stopping and cleaning the project

Stop and remove the project containers and network:

```sh
make down
```

Stop the containers without removing them:

```sh
make stop
```

Start previously stopped containers:

```sh
make start
```

Remove the project containers and network:

```sh
make clean
```

Perform a destructive cleanup:

```sh
make fclean
```

`make fclean` removes the project containers, images, named volumes, orphan containers, and the persistent directories under `/home/cjuarez/data`.

Perform a full clean rebuild:

```sh
make re
```

## 5. Accessing the services

### WordPress website

Open:

```txt
https://cjuarez.42.fr
```

The TLS certificate is self-signed, so the browser may show a certificate warning.

The website must not be available through plain HTTP:

```txt
http://cjuarez.42.fr
```

### WordPress administration panel

Open:

```txt
https://cjuarez.42.fr/wp-admin/
```

Use the administrator username configured in `srcs/.env` and the password stored in:

```txt
srcs/secrets/wordpress_admin_password.txt
```

The project also creates one additional non-administrator WordPress user.

### Static website

Open:

```txt
https://cjuarez.42.fr/static/
```

The static files are mounted into the NGINX container from:

```txt
srcs/static/
```

and served directly by NGINX.

### Adminer

With the current local binding, open:

```txt
http://127.0.0.1:8081
```

Use the WordPress database user:

```txt
System: MariaDB or MySQL
Server: mariadb
Username: value of MARIADB_USER
Password: value stored in mariadb_password.txt
Database: value of MARIADB_DATABASE
```

This user has full privileges on the WordPress database, but not on every MariaDB database.

The MariaDB `root` account is intended for local administration from inside the MariaDB container, not for normal Adminer access.

### FTP

With the current local configuration:

```txt
Host: 127.0.0.1
Port: 21
Passive ports: 21100-21110
```

The FTP service uses the persistent WordPress volume mounted at:

```txt
/var/www/html
```

## 6. Configuration and credentials

Non-sensitive configuration is stored in:

```txt
srcs/.env
```

Passwords are stored as individual files under:

```txt
srcs/secrets/
```

The current secret files are:

```txt
mariadb_password.txt
mariadb_root_password.txt
wordpress_admin_password.txt
wp_user_password.txt
ftp_password.txt
```

Each file contains only the secret value.

Inside the relevant containers, Docker Compose mounts the files under:

```txt
/run/secrets/
```

The two MariaDB passwords serve different accounts:

- `mariadb_password.txt` — password for the restricted MariaDB user used by WordPress and Adminer.
- `mariadb_root_password.txt` — password for the MariaDB root administrator inside the MariaDB container.

## 7. Checking the services

Show the current project containers:

```sh
make ps
```

Follow all project logs:

```sh
make logs
```

Check the containers directly:

```sh
docker compose -p inception   -f srcs/docker-compose.yml   --env-file srcs/.env   ps
```

Check specific logs:

```sh
docker compose -p inception   -f srcs/docker-compose.yml   --env-file srcs/.env   logs mariadb

docker compose -p inception   -f srcs/docker-compose.yml   --env-file srcs/.env   logs wordpress

docker compose -p inception   -f srcs/docker-compose.yml   --env-file srcs/.env   logs nginx
```

Check HTTPS:

```sh
curl -kI https://cjuarez.42.fr
```

Check that HTTP is unavailable:

```sh
curl -I http://cjuarez.42.fr
```

## 8. Checking MariaDB

### Through Adminer

Log in with the WordPress database user and verify that the configured database contains WordPress tables such as:

```txt
wp_posts
wp_users
wp_options
```

The exact prefix may differ if WordPress uses a custom table prefix.

### From inside the MariaDB container

Open a shell:

```sh
docker compose -p inception   -f srcs/docker-compose.yml   --env-file srcs/.env   exec mariadb sh
```

Connect as the WordPress database user:

```sh
mariadb -u "$MARIADB_USER" -p "$MARIADB_DATABASE"
```

Connect as MariaDB root:

```sh
mariadb -u root -p
```

## 9. Persistent data

WordPress files are stored on the host under:

```txt
/home/cjuarez/data/wordpress
```

MariaDB files are stored on the host under:

```txt
/home/cjuarez/data/mariadb
```

The Docker named volumes are:

```txt
wordpress
db_data
```

The data survives normal container removal, image rebuilding, and VM restarts.

The data is intentionally removed by:

```sh
make fclean
```

## 10. Troubleshooting

### The domain does not open

Check that `/etc/hosts` maps `cjuarez.42.fr` to the VM.

### The browser reports an unsafe certificate

This is expected because the certificate is self-signed.

### WordPress reports a database connection error

Check:

```sh
make ps
docker compose -p inception -f srcs/docker-compose.yml --env-file srcs/.env logs mariadb
docker compose -p inception -f srcs/docker-compose.yml --env-file srcs/.env logs wordpress
```

### A container keeps restarting

Inspect its recent logs:

```sh
docker compose -p inception   -f srcs/docker-compose.yml   --env-file srcs/.env   logs --tail=100 <service>
```

### A container name or volume is already in use

The Makefile manages the Compose project under the name `inception`.

Do not start the same Compose file separately under another project name. Old containers from another project can keep fixed container names or volumes in use.

Find containers using a volume:

```sh
docker ps -a --filter volume=wordpress
docker ps -a --filter volume=db_data
```

Remove only confirmed obsolete containers before retrying the build.
