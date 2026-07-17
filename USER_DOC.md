# Inception User Documentation

## Overview

Inception provides a Docker Compose infrastructure containing:

- **NGINX** as the HTTPS entrypoint on port `443`.
- **WordPress with PHP-FPM** as the website application.
- **MariaDB** as the WordPress database.
- **Redis** as an internal bonus cache service.
- **FTP** for access to the persistent WordPress files.
- **Adminer** for browser-based database administration.
- **A static website** available through its configured route.

The mandatory services communicate through the private `inception` Docker network. MariaDB, PHP-FPM, and Redis are not directly exposed as public web services.

## Requirements

Run the project inside the configured Linux virtual machine with:

- Make

The project domain is configured through `LOGIN` in `srcs/.env`.

For local access inside the VM, add the following entry to `/etc/hosts`:

```txt
127.0.0.1 cjuarez.42.fr
```

For access from another machine, replace `127.0.0.1` with the VM IP address.

## Start the project

From the repository root:

```sh
make
```

This creates the required data directories, builds the images, and starts the containers.

Useful commands:

```sh
make build
make up
make start
make restart
```

## Stop the project

Stop and remove the containers:

```sh
make down
```

Stop them without removing them:

```sh
make stop
```

Other cleanup commands:

```sh
make clean
make fclean
make re
```

`make fclean` is destructive when implemented as documented: it removes containers, images, volumes, and local persistent project data.

## Access the services

### WordPress website

```txt
https://cjuarez.42.fr
```

The certificate is self-signed, so the browser may display a warning.

Plain HTTP should not be available:

```txt
http://cjuarez.42.fr
```

### WordPress administration

```txt
https://cjuarez.42.fr/wp-admin/
```

Use the administrator username configured in `srcs/.env` and its corresponding password from the configured secret file.

### Static website

```txt
https://cjuarez.42.fr/static/
```

### Adminer

With the default local binding:

```txt
http://127.0.0.1:8081
```

Typical login values:

```txt
System: MariaDB or MySQL
Server: mariadb
Database: value of MARIADB_DATABASE
Username: value of MARIADB_USER
Password: MariaDB application-user password
```

### FTP

With the default configuration:

```txt
Host: 127.0.0.1
Port: 21
Passive ports: 21100-21110
```

The FTP root points to the shared WordPress files at `/var/www/html`.

## Configuration and credentials

Non-sensitive configuration is stored in:

```txt
srcs/.env
```

Credential values are stored in separate files under:

```txt
srcs/secrets/
```

Each secret file contains only the value itself, without a `KEY=` prefix. Inside a container, granted secrets are available under:

```txt
/run/secrets/<secret_name>
```

Changing a MariaDB password secret does not automatically update an account already stored in the persistent database. The account must be changed inside MariaDB or the development database must be reinitialized.

## Check that the services are running

```sh
make ps
make logs
```

Direct Compose commands:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs -f
```

Check individual logs:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs mariadb
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs wordpress
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs nginx
```

Check HTTPS:

```sh
curl -kI https://cjuarez.42.fr
```

Port `80` should not serve the website:

```sh
curl -I http://cjuarez.42.fr
```

Check Redis itself:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec redis redis-cli ping
```

Expected result:

```txt
PONG
```

Check MariaDB interactively:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec mariadb sh
mariadb -u "$MARIADB_USER" -p "$MARIADB_DATABASE"
```

## Persistent data

WordPress files are stored under:

```txt
/home/cjuarez/data/wordpress
```

MariaDB data is stored under:

```txt
/home/cjuarez/data/mariadb
```

The data survives container removal, rebuilding, and VM restarts unless a destructive cleanup removes the volumes and host data directories.

## Troubleshooting

### The domain does not open

Check `/etc/hosts` and ensure that `cjuarez.42.fr` points to the VM.

### The browser reports an unsafe certificate

That is expected for the self-signed certificate.

### WordPress reports a database error

Check:

```sh
make ps
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs mariadb
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs wordpress
```

### A container keeps restarting

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs --tail=100 <service>
```

Replace `<service>` with the relevant service name.
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
```
