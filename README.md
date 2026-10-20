*This project has been created as part of the 42 curriculum by sbaghdad.*

# Inception

## Description

Inception is a system administration project whose goal is to build a small but complete web infrastructure using **Docker** and **Docker Compose**, inside a virtual machine. Every service runs in its own container, built from our own Dockerfiles (no pre-built images such as `wordpress` or `nginx` from Docker Hub, only the Debian/Alpine base image).

The infrastructure is made of three services:

| Service | Role | Exposed |
|---|---|---|
| **NGINX** | Reverse proxy / web server, the only entry point. TLS 1.2 / 1.3 only. | Port **443** |
| **WordPress + PHP-FPM** | The website, run by php-fpm (no web server inside). | Port 9000 (internal) |
| **MariaDB** | Database used by WordPress. | Port 3306 (internal) |

```
Browser --443/TLS--> [ nginx ] --9000/FastCGI--> [ wordpress / php-fpm ] --3306--> [ mariadb ]
                          |                              |                            |
                          +-------- wordpress volume ----+                      mariadb volume
```

All containers are attached to a dedicated Docker bridge network. Two named volumes persist the WordPress files and the database on the host, under `/home/sbaghdad/data/`. Sensitive values are handled with Docker secrets, and non-sensitive configuration with a `.env` file.

## Instructions

### Prerequisites

- A Linux virtual machine with **Docker Engine** and the **Docker Compose** plugin installed
- `make` and `sudo` rights
- The domain name pointing to the local machine. Add this line to `/etc/hosts`:

```
127.0.0.1   sbaghdad.42.fr
```

### Configuration

1. Create the `srcs/.env` file (non-sensitive configuration):

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=sbaghdad
MYSQL_HOST=mariadb
WP_TITLE=Inception
WP_ADMIN_USER=lboghdady
WP_ADMIN_EMAIL=admin@example.com
WP_USER=sbaghdad
WP_USER_EMAIL=user@example.com
DOMAIN_NAME=sbaghdad.42.fr
```

2. Create the secret files (one password per file, never committed to Git):

```
secrets/
├── mySqlRootPassword.txt
├── mySqlPassword.txt
├── wp-AdminPassword.txt
└── wp-UserPassword.txt
```

### Build and run

```bash
make          # prepare data folders, build the images, start the containers (background)
make logs     # show the logs
make ps       # show the status of the containers
make down     # stop the containers (data is kept)
make clean    # down + remove volume definitions and images
make fclean   # clean + delete the persisted data in /home/sbaghdad/data
make re       # fclean + start again
```

### Usage

- Website: <https://sbaghdad.42.fr> (the certificate is self-signed, accept the browser warning)
- Administration panel: <https://sbaghdad.42.fr/wp-admin>
- Check the containers: `docker ps`
- Check the logs: `docker compose -f srcs/docker-compose.yml logs -f`
- Check the database:

```bash
docker exec -it mariadb mariadb -u root -p
> USE wordpress;
> SHOW TABLES;
```

## Project description

### Use of Docker

Docker packages each service with exactly the dependencies it needs, in an isolated container that shares the host kernel. Docker Compose describes the whole stack (services, network, volumes, secrets) in a single file so it can be built and started with one command and reproduced anywhere.

### Sources included in the project

```
.
├── Makefile                     # entry point: build, start, stop, clean
├── README.md
├── secrets/                     # password files (git-ignored)
└── srcs/
    ├── .env                     # non-sensitive configuration (git-ignored)
    ├── docker-compose.yml       # services, network, volumes, secrets
    └── requirements/
        ├── mariadb/             # Dockerfile, config, init script
        ├── nginx/               # Dockerfile, nginx.conf, TLS certificate generation
        └── wordpress/           # Dockerfile, php-fpm config, WP-CLI setup script
```

- **mariadb**: installs MariaDB, configures it to listen on the Docker network, and an entrypoint script creates the database and users on first start, then runs `mysqld` in the foreground as PID 1.
- **wordpress**: installs PHP-FPM and WP-CLI, waits for MariaDB to be ready, downloads and installs WordPress, creates the admin and the second user, then runs `php-fpm -F`.
- **nginx**: installs NGINX, generates a self-signed certificate with OpenSSL, enables only TLSv1.2/1.3 and forwards `.php` requests to `wordpress:9000`. It runs with `daemon off;`.

### Main design choices

- One process per container, run in the foreground as PID 1 (no `tail -f`, `sleep infinity` or infinite-loop hacks).
- Start order is enforced with `depends_on` and `condition: service_healthy`: WordPress starts only when MariaDB is healthy (a real login + `SELECT 1`), and NGINX only when WordPress is healthy.
- NGINX is the only published port, and only over TLS.
- Containers restart automatically on crash (`restart: on-failure`).
- Credentials are never written in the Dockerfiles or in the repository.

### Comparisons

#### Virtual Machines vs Docker

| | Virtual Machine | Docker |
|---|---|---|
| Isolation | Full OS with its own kernel, isolated by a hypervisor | Process-level isolation, shares the host kernel (namespaces, cgroups) |
| Size | Gigabytes | Megabytes |
| Startup time | Minutes | Seconds or less |
| Resource usage | Heavy: reserved RAM/CPU for a whole OS | Light: only what the process uses |
| Portability | Disk images are large and hypervisor-specific | Images are small, layered and run on any Docker host |
| Security boundary | Stronger (separate kernel) | Weaker (shared kernel) |

A VM virtualizes the *hardware*, Docker virtualizes the *operating system*. In this project the VM is the host that provides a safe environment, and Docker runs the services inside it: each service stays lightweight and reproducible.

#### Secrets vs Environment Variables

| | Environment variables | Docker secrets |
|---|---|---|
| Storage | Part of the container's process environment | Files mounted at `/run/secrets/<name>` |
| Visible in `docker inspect` | Yes, in plain text | No |
| Inherited by child processes | Yes | No, only code that opens the file reads it |
| Risk of leaking | High (logs, `env`, `phpinfo()`, crash dumps, baked in image layers with `ENV`) | Lower (access controlled by file permissions) |
| Best for | Non-sensitive configuration (domain, database name, usernames) | Passwords, keys, tokens |

In this project, non-sensitive values live in `.env`, and all passwords are stored in secret files that the entrypoint scripts read with `cat /run/secrets/...`. Note that with plain Docker Compose (not Swarm), a secret is a bind-mounted file, so it is not encrypted at rest on the host.

#### Docker Network vs Host Network

| | Docker (bridge) network | Host network |
|---|---|---|
| Isolation | Containers get their own network namespace and private IPs | Container shares the host's network stack |
| Service discovery | Built-in DNS: containers reach each other by service name (`mariadb`, `wordpress`) | None, everything is on `localhost` |
| Port exposure | Only ports explicitly published are reachable from outside | Every port the process opens is exposed on the host |
| Port conflicts | None between containers | Possible with host services |

We use a custom bridge network so that MariaDB and WordPress are unreachable from outside, and only NGINX publishes port 443. `network: host` and `links` are forbidden by the subject.

#### Docker Volumes vs Bind Mounts

| | Docker named volumes | Bind mounts |
|---|---|---|
| Managed by | Docker (`docker volume ...`) | The user: a host path mapped into the container |
| Location | Docker-controlled (`/var/lib/docker/volumes/`) unless configured otherwise | Any path on the host |
| Portability | Independent of the host directory layout | Depends on the host's file structure |
| Permissions / setup | Initialized and handled by Docker | Host folder must exist, ownership must be managed manually |
| Typical use | Persistent application data (databases) | Development, sharing source code or config |

We use **named volumes** declared in `docker-compose.yml`, configured with the `local` driver and `device:` options so that their data is stored in `/home/sbaghdad/data/mariadb` and `/home/sbaghdad/data/wordpress`, as required by the subject. The data survives container removal and restarts.

## Resources

### Documentation and references

- [Docker documentation](https://docs.docker.com/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Docker Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker networking overview](https://docs.docker.com/engine/network/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Best practices for writing Dockerfiles](https://docs.docker.com/build/building/best-practices/)
- [NGINX documentation](https://nginx.org/en/docs/) and the [ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/documentation/)
- [WordPress developer documentation](https://developer.wordpress.org/)
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [OpenSSL `req` manual](https://docs.openssl.org/master/man1/openssl-req/)

### Use of AI

AI (Claude) was used as a learning and debugging assistant, not as a replacement for understanding the project. It was used for:

- Explaining concepts: `depends_on` vs healthchecks, how `until` wait loops work, the full request flow from the browser through NGINX, PHP-FPM and MariaDB, and the differences between secrets/env, volumes/bind mounts and bridge/host networks.
- Debugging errors, for example the Docker error caused by a missing host directory for the bind-mounted named volume, and healthcheck authentication problems.
- Reviewing the Docker Compose structure (named volumes with `driver_opts`, secrets usage, healthcheck syntax).
- Helping draft and structure this README.

All generated suggestions were read, tested and adapted by me, and I am able to explain every part of the code in this repository.