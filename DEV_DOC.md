# Inception Developer Documentation

## Architecture

Mandatory request flow:

```txt
Client
  |
  | HTTPS :443
  v
NGINX
  |
  | FastCGI :9000
  v
WordPress + PHP-FPM
  |
  | MariaDB protocol :3306
  v
MariaDB
```

The containers communicate through the private `inception` Docker network.

Persistent storage is split into two named volumes:

- `wordpress` for WordPress files.
- `db_data` for MariaDB data.

Their host data paths are:

```txt
/home/cjuarez/data/wordpress
/home/cjuarez/data/mariadb
```

## Repository layout

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
    ├── wordpress/
    ├── mariadb/
    ├── redis/
    ├── ftp/
    ├── adminer/
    └── static/
```

Each service has its own Dockerfile and runs in its own container.

## Prerequisites

Use a Linux VM containing:

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

## Environment setup

### Domain mapping

`DOMAIN_NAME` in `srcs/.env` is the single source of truth for the project domain.

For local testing inside the VM, add:

```txt
127.0.0.1 cjuarez.42.fr
```

to `/etc/hosts`.

### Environment file

A representative `srcs/.env` is:

```env
LOGIN=cjuarez
DOMAIN_NAME=cjuarez.42.fr

NGINX_BIND_ADDR=0.0.0.0

MARIADB_DATABASE=wordpress
MARIADB_USER=wpuser

WORDPRESS_DB_HOST=mariadb
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

Derive the WordPress URL in Compose instead of duplicating the domain:

```yaml
environment:
  WORDPRESS_URL: "https://${DOMAIN_NAME}"
  `

### Secret files

Required files under `srcs/secrets/`:

```txt
mariadb_password.txt
mariadb_root_password.txt
wordpress_admin_password.txt
wp_user_password.txt
ftp_password.txt
```

Each file contains only the secret value.

### Persistent directories

The Makefile should create these before Compose starts:

```sh
mkdir -p /home/cjuarez/data/wordpress
mkdir -p /home/cjuarez/data/mariadb
```

## Build and launch

From the repository root:

```sh
make
```

Useful targets:

```sh
make build
make up
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

Validate the resolved Compose configuration:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml config
```

## Image naming and building

For a service with both `build` and `image`:

```yaml
nginx:
  build: ./nginx
    image: nginx:inception
  pull_policy: build
```

- `build` defines how Compose builds the image from the local Dockerfile.
- `image` assigns the resulting local image name and tag.
- `pull_policy: build` makes the local build behavior explicit.

Use explicit non-`latest` tags while keeping the image repository name equal to the service name:

```txt
nginx:inception
wordpress:inception
mariadb:inception
```

## MariaDB readiness

Startup order alone does not prove that MariaDB has completed initialization. The health check should verify that the configured application user can authenticate and access the configured database.

Add to the MariaDB service:

```yaml
healthcheck:
  test:
      - CMD-SHELL
        - >-
            MYSQL_PWD="$$(cat /run/secrets/mariadb_password)"
            mariadb --protocol=TCP
            --host=127.0.0.1
            --port=3306
            --user="$${MARIADB_USER}"
            --database="$${MARIADB_DATABASE}"
            --execute="SELECT 1"
            >/dev/null 2>&1
        interval: 3s
  timeout: 3s
  retries: 20
  start_period: 10s
```

Make WordPress wait for that health check:

```yaml
depends_on:
  mariadb:
      condition: service_healthy
   

The WordPress entrypoint should also use a bounded authenticated retry before WP-CLI operations. This keeps the script safe when the container is started separately.

## Entrypoint error handling

Use:

```sh
set -eu
```

- `set -e` exits when an unhandled command fails.
- `set -u` exits when an unset variable is expanded.

Still validate required variables explicitly to produce clear errors:

```sh
: "${WORDPRESS_DB_HOST:?WORDPRESS_DB_HOST is not set}"
: "${WORDPRESS_DB_NAME:?WORDPRESS_DB_NAME is not set}"
: "${WORDPRESS_DB_USER:?WORDPRESS_DB_USER is not set}"
```

Validate secret files before reading them:

```sh
[ -r /run/secrets/mariadb_password ] || {
    echo "Missing MariaDB password secret." >&2
    exit 1
}
```

A command used inside `if`, `while`, or `until` is intentionally allowed to return nonzero. For example:

```sh
if ! wp core is-installed; then
    # Install WordPress.
  fi
```

Here, a nonzero status means "not installed" and is handled by the `if` statement.

## MariaDB initialization and SQL escaping

Initialization should run only when the MariaDB system database does not exist:

```sh
if [ ! -d /var/lib/mysql/mysql ]; then
    # Initialize the data directory and accounts.
  fi
```

Restrict SQL identifiers such as the database and application username:

```sh
validate_identifier() {
    name="$1"
    value="$2"

    case "$value" in
    ""|*[!A-Za-z0-9_]*)
        echo "$name contains unsupported characters." >&2
        exit 1
        ;;
    esac
}
```

Escape SQL string literals by enabling `NO_BACKSLASH_ESCAPES` in the initialization session and doubling single quotes:

```sh
sql_escape_literal() {
    printf '%s' "$1" | sed "s/'/''/g"
}
```

Example:

```sh
DB_USER_SQL="$(sql_escape_literal "$MARIADB_USER")"
DB_PASSWORD_SQL="$(sql_escape_literal "$MARIADB_PASSWORD")"
ROOT_PASSWORD_SQL="$(sql_escape_literal "$MARIADB_ROOT_PASSWORD")"
```

Then use:

```sql
SET SESSION sql_mode = 'NO_BACKSLASH_ESCAPES';
CREATE USER '${DB_USER_SQL}'@'%' IDENTIFIED BY '${DB_PASSWORD_SQL}';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD_SQL}';
```

## NGINX domain templating

Add to `srcs/.env`:

```env
DOMAIN_NAME=cjuarez.42.fr
```

Pass it to NGINX in Compose:

```yaml
environment:
  DOMAIN_NAME: ${DOMAIN_NAME}
  ```

  Use a template containing:

  ```nginx
server_name ${DOMAIN_NAME};
```

Generate the final NGINX configuration with:

```sh
envsubst '${DOMAIN_NAME}' \
  < /etc/nginx/templates/default.conf.template \
  > /etc/nginx/http.d/default.conf
```

Limit `envsubst` to `DOMAIN_NAME`. Unrestricted substitution would also replace NGINX variables such as `$uri`, `$args`, and `$document_root`.

Generate the self-signed certificate from the same variable:

```sh
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/inception.key \
  -out /etc/nginx/ssl/inception.crt \
  -subj "/CN=${DOMAIN_NAME}" \
  -addext "subjectAltName=DNS:${DOMAIN_NAME}"
```

## Container management

Show service state:

```sh
make ps
```

Show logs:

```sh
make logs
```

Open a shell:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec wordpress sh
```

Rebuild one service:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml build wordpress
docker compose --env-file srcs/.env -f srcs/docker-compose.yml up -d wordpress
```

## Volume inspection and persistence

```sh
docker volume ls
docker volume inspect wordpress
docker volume inspect db_data
```

The inspection output must show the corresponding paths under `/home/cjuarez/data/`.

Persistence test:

1. Start the stack.
2. Edit a WordPress page.
3. Run `make down`.
4. Reboot the VM.
5. Run `make up`.
6. Verify that the page, users, uploads, and database data remain.

## Database access

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec mariadb sh
mariadb -u "$MARIADB_USER" -p "$MARIADB_DATABASE"
```

Useful checks:

```sql
SHOW DATABASES;
SHOW TABLES;
SELECT ID, user_login FROM wp_users;
```

The table prefix may differ if WordPress uses a custom prefix.

## Password changes after initialization

MariaDB account passwords are stored in the persistent database. Replacing only a secret file does not update an existing account.

Use one of these approaches:

- connect to MariaDB and run `ALTER USER`;
- remove the development MariaDB data and let initialization run again.

## TLS verification

```sh
curl -kI https://cjuarez.42.fr
curl -I http://cjuarez.42.fr
openssl s_client -connect cjuarez.42.fr:443 -tls1_2
openssl s_client -connect cjuarez.42.fr:443 -tls1_3
```

NGINX should allow only:

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

## Bonus-service notes

Redis server check:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec redis redis-cli ping
```

A running Redis server alone does not prove that WordPress uses Redis. WordPress integration must also be enabled and tested.

The static website is mounted into the NGINX container at `/var/www/static`
and is served at `/static/`. It contains no PHP and does not require a
separate application process.

## Evaluation rebuild checklist

From a clean development state:

```sh
make fclean
make
make ps
```

Verify:

- every configured container remains running;
- MariaDB becomes healthy;
- WordPress is already installed;
- HTTPS works on `443`;
- HTTP on `80` is unavailable;
- the administrator username does not contain `admin`;
- the second WordPress user exists;
- both mandatory volumes resolve under `/home/cjuarez/data`;
- data survives `make down`, a VM reboot, and `make up`.
