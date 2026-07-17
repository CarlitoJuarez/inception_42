# Inception Developer Documentation

## 1. Architecture

The mandatory request flow is:

```txt
Client
  |
  | HTTPS on port 443
  v
NGINX
  |
  | FastCGI on port 9000
  v
WordPress + PHP-FPM
  |
  | MariaDB protocol on port 3306
  v
MariaDB
```

NGINX is the only public entrypoint for the mandatory infrastructure.

The mandatory containers communicate through the private Docker network:

```txt
inception
```

The current additional services are Redis, FTP, Adminer, and a static website served by NGINX.

Redis currently runs as its own internal container but is not integrated with the WordPress object cache.

## 2. Repository structure

```txt
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── .env
    ├── docker-compose.yml
    ├── secrets/
    ├── nginx/
    │   ├── Dockerfile
    │   └── default.conf
    ├── wordpress/
    │   ├── Dockerfile
    │   ├── entrypoint.sh
    │   ├── php.ini
    │   └── www.conf
    ├── mariadb/
    │   ├── Dockerfile
    │   └── entrypoint.sh
    ├── redis/
    ├── ftp/
    ├── adminer/
    └── static/
```

Each actual service is built from its own Dockerfile and runs in its own container.

The static website is content rather than a separate process. It is mounted into the existing NGINX container and served at `/static/`.

## 3. Prerequisites

Use a Linux virtual machine containing:

```txt
Docker Engine
Docker Compose plugin
GNU Make
```

Verify the tools:

```sh
docker --version
docker compose version
make --version
```

The current user must be able to run Docker commands and create directories under:

```txt
/home/cjuarez/data
```

## 4. Configuration

### Domain

The implementation is configured for:

```txt
cjuarez.42.fr
```

The value is currently present in the WordPress configuration and hardcoded in the NGINX server configuration and self-signed certificate.

Map the domain to the VM through `/etc/hosts`:

```txt
127.0.0.1 cjuarez.42.fr
```

Use the VM IP instead of `127.0.0.1` when accessing it from another machine.

### Environment file

`srcs/.env` contains non-sensitive configuration used by Docker Compose and the entrypoint scripts.

The current implementation expects values corresponding to:

```env
LOGIN=cjuarez

NGINX_BIND_ADDR=0.0.0.0

MARIADB_DATABASE=wordpress
MARIADB_USER=wpuser

WORDPRESS_DB_HOST=mariadb
WORDPRESS_URL=https://cjuarez.42.fr
WORDPRESS_TITLE=Inception
WORDPRESS_ADMIN_USER=owner
WORDPRESS_ADMIN_EMAIL=owner@example.com
WP_USER=editor
WP_USER_EMAIL=editor@example.com
WP_USER_ROLE=editor

FTP_BIND_ADDR=127.0.0.1
FTP_USER=ftpuser
FTP_PORT=21
FTP_PASV_PORT_RANGE=21100-21110

ADMINER_BIND_IP=127.0.0.1
ADMINER_PORT=8081
```

The exact usernames and descriptive values may be changed, but the administrator username must not contain `admin` or `administrator`.

### Secrets

The current secret files are located under `srcs/secrets/`:

```txt
mariadb_password.txt
mariadb_root_password.txt
wordpress_admin_password.txt
wp_user_password.txt
ftp_password.txt
```

Each file contains only its value.

Docker Compose mounts the granted secrets under:

```txt
/run/secrets/<secret_name>
```

## 5. Makefile behavior

The Makefile uses the fixed Compose project name:

```txt
inception
```

through:

```makefile
COMPOSE := docker compose -p $(NAME) -f $(COMPOSE_YML) --env-file $(ENV_FILE)
```

Using the Makefile consistently prevents the same Compose file from being started under multiple project names.

The primary targets are:

```sh
make
make up
make build
make down
make stop
make start
make restart
make logs
make ps
make clean
make fclean
make re
```

Behavior:

- `make` runs `up`.
- `make up` creates the host data directories and runs `docker compose up -d --build`.
- `make build` builds the images.
- `make down` removes the project containers and network.
- `make stop` stops the containers without removing them.
- `make start` starts stopped containers.
- `make restart` restarts the containers.
- `make clean` runs Compose `down`.
- `make fclean` removes containers, images, volumes, orphan containers, and the host data directories.
- `make re` performs the full cleanup and rebuild.

## 6. Docker images

Every service is built from its local Dockerfile.

The current image naming uses explicit tags:

```txt
nginx:inception
wordpress:inception
mariadb:inception
redis:inception
ftp:inception
adminer:inception
```

The repository part of each image name matches its corresponding Compose service.

All service Dockerfiles use the configured Alpine base image instead of prebuilt WordPress, MariaDB, or NGINX images.

## 7. Docker network

The Compose file declares the `inception` network.

Docker Compose provides service-name DNS inside the network:

```txt
nginx -> wordpress:9000
wordpress -> mariadb:3306
adminer -> mariadb:3306
```

The implementation does not use host networking, `links`, or `--link`.

## 8. Persistent volumes

The two mandatory named volumes are:

```txt
wordpress
db_data
```

They are mounted as:

```txt
wordpress -> /var/www/html
db_data   -> /var/lib/mysql
```

The local volume driver stores their data under:

```txt
/home/cjuarez/data/wordpress
/home/cjuarez/data/mariadb
```

The Makefile creates these host directories before Compose starts.

Inspect the volumes with:

```sh
docker volume ls
docker volume inspect wordpress
docker volume inspect db_data
```

The inspection output should contain the corresponding path under `/home/cjuarez/data`.

## 9. NGINX implementation

The NGINX image installs:

```txt
nginx
openssl
```

The certificate is generated during the image build and is configured for:

```txt
cjuarez.42.fr
```

The NGINX configuration:

- listens on port `443`;
- enables only TLS 1.2 and TLS 1.3;
- serves WordPress files from `/var/www/html`;
- forwards PHP requests to `wordpress:9000`;
- serves the static website from `/var/www/static`;
- does not listen on port `80`.

The static route is:

```nginx
location /static/ {
    alias /var/www/static/;
    index index.html;
    try_files $uri $uri/ /static/index.html;
}
```

The static files are mounted through:

```yaml
- ./static:/var/www/static
```

## 10. WordPress implementation

The WordPress image installs PHP-FPM, WP-CLI, the MariaDB client, and the required PHP extensions.

PHP-FPM listens on:

```txt
0.0.0.0:9000
```

The WordPress entrypoint performs this sequence:

1. Reads the database and WordPress passwords from `/run/secrets`.
2. Creates the WP-CLI cache directory.
3. Ensures `/var/www/html` is owned by `www-data`.
4. Waits for MariaDB port `3306` with a bounded retry loop.
5. Downloads WordPress when `wp-load.php` is missing.
6. Creates `wp-config.php` when it is missing.
7. Installs WordPress when it is not already installed.
8. Creates the additional regular WordPress user when missing.
9. Replaces the shell process with PHP-FPM through `exec "$@"`.

The MariaDB wait loop is bounded and exits after the configured number of failed attempts. It is not an infinite-loop container workaround.

The entrypoint uses:

```sh
set -e
```

This causes the script to stop when an unhandled command fails.

Commands used as conditions are handled intentionally. For example:

```sh
if ! wp core is-installed; then
    # Install WordPress.
fi
```

A nonzero result here means WordPress is not installed, so the script enters the installation block.

## 11. MariaDB implementation

The MariaDB image installs:

```txt
mariadb
mariadb-client
su-exec
```

The entrypoint reads:

```txt
/run/secrets/mariadb_password
/run/secrets/mariadb_root_password
```

It validates the required environment variables and initializes the database only when:

```txt
/var/lib/mysql/mysql
```

does not exist.

During first initialization it:

1. Initializes the MariaDB system tables.
2. Creates the configured WordPress database.
3. Creates the configured application user for network access.
4. Grants that user all privileges on the WordPress database.
5. Sets the MariaDB root password.
6. Starts `mariadbd` as the `mysql` user.

The main process runs in the foreground as PID 1:

```sh
exec su-exec mysql mariadbd ...
```

## 12. MariaDB accounts

The current implementation has two relevant MariaDB accounts.

### WordPress database user

Configured through:

```txt
MARIADB_USER
mariadb_password.txt
```

It is created as:

```sql
'MARIADB_USER'@'%'
```

and receives:

```sql
GRANT ALL PRIVILEGES ON `MARIADB_DATABASE`.* ...
```

This account is used by:

- WordPress;
- Adminer;
- manual checks of the WordPress database.

It can fully manage the WordPress database but does not have unrestricted global MariaDB privileges.

### MariaDB root

Configured through:

```txt
mariadb_root_password.txt
```

The root password is assigned to:

```sql
'root'@'localhost'
```

This account is intended for local database administration from inside the MariaDB container.

It is not the normal account to demonstrate through Adminer.

## 13. Database access

### Adminer

Use:

```txt
System: MariaDB or MySQL
Server: mariadb
Username: value of MARIADB_USER
Password: mariadb_password.txt
Database: value of MARIADB_DATABASE
```

### MariaDB container

Open a shell:

```sh
docker compose -p inception   -f srcs/docker-compose.yml   --env-file srcs/.env   exec mariadb sh
```

Application user:

```sh
mariadb -u "$MARIADB_USER" -p "$MARIADB_DATABASE"
```

Root:

```sh
mariadb -u root -p
```

Useful checks:

```sql
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
SELECT ID, user_login FROM wp_users;
```

The table prefix may differ if WordPress uses a non-default prefix.

## 14. Persistence test

A full persistence test is:

1. Run `make`.
2. Edit a WordPress page from the administration dashboard.
3. Verify the change on the website.
4. Run `make down`.
5. Reboot the virtual machine.
6. Run `make up`.
7. Confirm that WordPress remains installed and the page change still exists.

The data remains because it is stored in the named volumes backed by `/home/cjuarez/data`.

## 15. Changing MariaDB passwords

MariaDB account passwords are stored inside the persistent database.

Changing only:

```txt
mariadb_password.txt
mariadb_root_password.txt
```

does not update accounts in an already initialized database.

During development, either:

- update the account with `ALTER USER`; or
- run the destructive cleanup and allow MariaDB to initialize again.

## 16. Additional services

### Redis

Redis runs in its own container on the internal Docker network.

The current implementation does not connect WordPress to Redis, so it should only be described as an available Redis service rather than an active WordPress object cache.

### FTP

FTP mounts the same `wordpress` named volume at:

```txt
/var/www/html
```

This allows the FTP user to access the persistent WordPress files.

### Adminer

Adminer connects to MariaDB through the Docker network using the service name:

```txt
mariadb
```

It is published locally according to:

```txt
ADMINER_BIND_IP
ADMINER_PORT
```

### Static website

The static website does not run a separate process.

Its files are mounted into the NGINX container and served through:

```txt
https://cjuarez.42.fr/static/
```

## 17. Troubleshooting Compose resource conflicts

The project should be started through the Makefile so Compose always uses:

```txt
-p inception
```

Starting the same Compose file separately from `srcs/` can create another project, commonly named `srcs`.

That can leave fixed container names or named volumes in use by the other project.

Find containers using the mandatory volumes:

```sh
docker ps -a --filter volume=wordpress
docker ps -a --filter volume=db_data
```

Inspect a container's Compose project:

```sh
docker inspect   -f '{{ index .Config.Labels "com.docker.compose.project" }}'   <container>
```

Remove only confirmed obsolete containers or the obsolete Compose project before running `make re` again.

## 18. Evaluation checks

Before submission, verify:

```sh
make re
make ps
```

Then confirm:

- all configured containers remain running;
- HTTPS works on port `443`;
- HTTP on port `80` is unavailable;
- TLS 1.2 and TLS 1.3 are enabled;
- WordPress is already installed;
- the administrator username does not contain `admin`;
- the second WordPress user exists;
- WordPress and MariaDB use separate named volumes;
- both volumes resolve under `/home/cjuarez/data`;
- the database is non-empty;
- WordPress data survives a VM reboot;
- the mandatory services do not use prebuilt service images;
- no container uses host networking, links, infinite loops, or background-process workarounds.
