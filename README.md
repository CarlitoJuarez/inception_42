*This project has been created as part of the 42 curriculum by cjuarez.*

# Inception

## Description

Inception is a system administration and containerization project from the 42 curriculum.

The goal of the project is to build a small Docker-based infrastructure composed of several independent services. Each service runs in its own container and is configured manually through its own Dockerfile.

The mandatory infrastructure contains:

- NGINX as the only public entrypoint, available through HTTPS on port `443`.
- WordPress running with PHP-FPM.
- MariaDB as the database backend.
- Docker volumes for persistent WordPress files and database data.
- A private Docker network allowing the containers to communicate internally.

Additional services included in this project:

- Redis for WordPress caching.
- FTP for access to the WordPress files.
- Adminer for database administration.
- A static website served through NGINX.

The project is designed to be run inside a Virtual Machine and accessed through:

```txt
https://cjuarez.42.fr
```

The domain must point to the local machine or VM IP address, usually through `/etc/hosts`.

## Project Structure

```txt

.
├── Makefile
├── README.md
└── srcs/
├── .env
├── docker-compose.yml
├── secrets/
│   ├── ftp_password.txt
│   ├── mariadb_password.txt
│   ├── mariadb_root_password.txt
│   ├── wordpress_admin_password.txt
│   └── wp_user_password.txt
├── adminer/
├── ftp/
├── mariadb/
├── nginx/
├── redis/
├── static/
└── wordpress/
```

All Docker-related configuration is stored inside `srcs/`.

The root `Makefile` is used to build, start, stop, and clean the infrastructure.

## Instructions

### Requirements

The project must be executed on a Linux Virtual Machine with:

```txt
Docker
Docker Compose
Make
```

The domain must be mapped to the local machine or VM.

For local testing, add this line to `/etc/hosts`:

```txt
127.0.0.1 cjuarez.42.fr
```

If the project is accessed from another machine, replace `127.0.0.1` with the VM IP address.

### Environment File

The project uses `srcs/.env` for non-sensitive configuration.

Example:

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
WORDPRESS_USER=editor
WORDPRESS_USER_EMAIL=editor@example.com

WP_USER=additional_user
WP_USER=additional_user@example.com
WP_USER_ROLE=author

FTP_BIND_ADDR=127.0.0.1
FTP_USER=ftpuser
FTP_PORT=21
FTP_PASV_PORT_RANGE=21100-21110

ADMINER_BIND_IP=127.0.0.1
ADMINER_PORT=8081
```

Passwords must not be stored in `.env`.

### Secrets

Sensitive values are stored in files inside the `secrets/` directory.

Required files:

```txt
secrets/mariadb_password.txt
secrets/mariadb_root_password.txt
secrets/wordpress_admin_password.txt
secrets/wp_user_password.txt
secrets/ftp_password.txt
```

Each file should contain only the secret value itself.

Example:

```txt
my_password_here
```

Not:

```txt
PASSWORD=my_password_here
```

These files are mounted inside containers through Docker secrets and read from:

```txt
/run/secrets/<secret_name>
```

### Build and Run

From the root of the repository:

```sh
make
```

This creates the required data directories, builds the images, and starts the containers.

The website should then be reachable at:

```txt
https://cjuarez.42.fr
```

Because the certificate is self-signed, the browser may display a security warning.

### Useful Makefile Commands

```sh
make          # Build and start the infrastructure
make build    # Build all images
make up       # Start containers
make down     # Stop and remove containers
make stop     # Stop containers without removing them
make start    # Start stopped containers
make restart  # Restart containers
make logs     # Show container logs
make ps       # Show running services
make clean    # Stop and remove containers
make fclean   # Remove containers, images, volumes, and local data
make re       # Full clean rebuild
```

## Services

### NGINX

NGINX is the only public entrypoint of the infrastructure.

It listens on:

```txt
443:443
```

It serves:

- WordPress through PHP-FPM.
- Static files from the `srcs/static/` directory.

TLS is enabled using a self-signed certificate.

### WordPress

WordPress runs with PHP-FPM and communicates with MariaDB through the private Docker network.

It uses:

```txt
WORDPRESS_DB_HOST=mariadb
WORDPRESS_DB_NAME=${MARIADB_DATABASE}
WORDPRESS_DB_USER=${MARIADB_USER}
```

The database password is read from Docker secrets.

WordPress files are stored persistently in the `wordpress` volume.

### MariaDB

MariaDB stores the WordPress database.

The database data is persisted in:

```txt
/home/cjuarez/data/mariadb
```

The MariaDB root password and WordPress database user password are provided through Docker secrets.

### Redis

Redis is included as an additional service for WordPress caching.

It is only reachable through the internal Docker network and is not exposed publicly.

### FTP

The FTP service provides access to the WordPress files.

It shares the same WordPress volume:

```txt
/var/www/html
```

The FTP user is based on the configured MariaDB/WordPress user.

### Adminer

Adminer provides a web interface to inspect and manage the MariaDB database.

It is exposed according to the `.env` configuration:

```env
ADMINER_BIND_IP=127.0.0.1
ADMINER_PORT=8081
```

Example access:

```txt
http://127.0.0.1:8081
```

## Project Design Choices

### Virtual Machines vs Docker

A Virtual Machine runs a complete operating system with its own kernel, virtual hardware, and allocated system resources.

Docker containers share the host kernel and isolate applications at the process level.

For this project, the Virtual Machine provides the required controlled Linux environment, while Docker is used inside the VM to split the infrastructure into independent services.

This makes the setup easier to rebuild, inspect, isolate, and reproduce.

### Secrets vs Environment Variables

Environment variables are useful for non-sensitive configuration such as usernames, database names, domains, and ports.

Secrets are used for sensitive values such as passwords.

This project stores passwords in Docker secret files instead of hardcoding them in Dockerfiles, scripts, or `.env`.

Example:

```txt
/run/secrets/mariadb_password
/run/secrets/mariadb_root_password
```

This avoids exposing credentials through image layers or Compose configuration.

### Docker Network vs Host Network

The project uses a custom Docker network named `inception`.

Containers communicate with each other by service name:

```txt
wordpress -> mariadb
nginx -> wordpress
adminer -> mariadb
```

The host network is not used.

Using a private Docker network keeps internal services isolated.

Only NGINX is exposed publicly through port `443`. MariaDB, WordPress/PHP-FPM, Redis, and other internal services remain private unless explicitly published.

### Docker Volumes vs Bind Mounts

Docker volumes are used for persistent data.

This project defines Docker volumes with bind-backed storage so the data is stored at predictable host paths:

```txt
/home/cjuarez/data/wordpress
/home/cjuarez/data/mariadb
```

This keeps important data persistent even if containers are removed.

WordPress files and MariaDB database files are therefore not lost when the containers are rebuilt.

## Sources Included in the Project

Each service is built from its own source directory and Dockerfile:

```txt
srcs/nginx
srcs/wordpress
srcs/mariadb
srcs/redis
srcs/ftp
srcs/adminer
```

The project does not rely on prebuilt service images such as the official WordPress, MariaDB, or NGINX images.

Instead, each container is configured manually from a minimal base image.

The main orchestration file is:

```txt
srcs/docker-compose.yml
```

It defines:

- services
- images
- container names
- volumes
- networks
- secrets
- restart policies
- dependencies

## Resources

Useful references for this project:

- Docker documentation: https://docs.docker.com/
- Docker Compose documentation: https://docs.docker.com/compose/
- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- Docker secrets documentation: https://docs.docker.com/engine/swarm/secrets/
- NGINX documentation: https://nginx.org/en/docs/
- WordPress CLI documentation: https://wp-cli.org/
- WordPress developer documentation: https://developer.wordpress.org/
- MariaDB documentation: https://mariadb.com/kb/en/documentation/
- PHP-FPM documentation: https://www.php.net/manual/en/install.fpm.php
- Redis documentation: https://redis.io/docs/
- Adminer documentation: https://www.adminer.org/
- vsftpd documentation: https://security.appspot.com/vsftpd.html

## AI Usage

AI assistance was used during the development of this project for:

- Understanding Docker Compose behavior.
- Debugging Docker secrets and environment variable usage.
- Debugging MariaDB initialization and persistent volume issues.
- Debugging WordPress URL redirection and database-stored options.
- Debugging NGINX, PHP-FPM, and Docker networking.
- Explaining UTM port forwarding and local `/etc/hosts` configuration.
- Improving the Makefile structure.
- Drafting the complete static folder / website.

AI was not used to generate or store real credentials.

All passwords and sensitive values are managed manually through the `secrets/` directory.
