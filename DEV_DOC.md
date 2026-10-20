# Developer Documentation

This document explains how to set up, build, run and maintain the Inception project from scratch. For day-to-day usage, see [USER_DOC.md](USER_DOC.md).

## 1. Setting up the environment from scratch

### Prerequisites

- A Linux virtual machine (Debian/Ubuntu recommended)
- **Docker Engine** and the **Docker Compose** plugin (`docker compose version` must work)
- `make`, `git`, and `sudo` rights (needed to remove data created by containers)
- Your user in the `docker` group, or use `sudo` for Docker commands

### Get the project

```bash
git clone git@github.com:lboghdadyy/Inception.git inception
cd inception
```

### Domain name

Map the domain to the local machine:

```bash
echo "127.0.0.1   sbaghdad.42.fr" | sudo tee -a /etc/hosts
```

### Configuration file: `srcs/.env`

Holds **non-sensitive** configuration. Create it (it is git-ignored):

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=sbaghdad
MYSQL_HOST=mariadb
WP_TITLE=Inception
WP_ADMIN_USER=lboghdady
WP_ADMIN_EMAIL=soufianebaghdadi@gmail.com
WP_USER=sbaghdad
WP_USER_EMAIL=soufianebaghdadiuser@gmail.com
DOMAIN_NAME=sbaghdad.42.fr
```

> The WordPress administrator username must not contain `admin` or `administrator` (subject requirement).

### Secrets: `secrets/`

Holds **sensitive** values, one per file (also git-ignored):

```bash
mkdir -p secrets
echo "choose-a-root-password"  > secrets/db_root_password.txt
echo "choose-a-db-password"    > secrets/db_password.txt
echo "choose-an-admin-password" > secrets/wp_admin_password.txt
echo "choose-a-user-password"  > secrets/wp_user_password.txt
chmod 600 secrets/*
```

Secrets are declared at the bottom of `docker-compose.yml` and attached to each service that needs them. Inside a container they appear as files in `/run/secrets/<name>`. Entrypoint scripts read them with:

```bash
DB_PASSWORD=$(cat /run/secrets/db_password)
```

### Project layout

```
.
├── Makefile
├── secrets/                      # password files (git-ignored)
└── srcs/
    ├── .env                      # non-sensitive config (git-ignored)
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/   (Dockerfile, conf/, tools/ entrypoint script)
        ├── nginx/     (Dockerfile, conf/, tools/)
        └── wordpress/ (Dockerfile, conf/, tools/ setup script)
```

## 2. Building and launching

### With the Makefile

| Target | What it does |
|---|---|
| `make` / `make run` | Creates `/home/sbaghdad/data/{mariadb,wordpress}`, builds the images, starts the containers in the background |
| `make build` | build the docker images from the dockerfiles |
| `make down` | Stops and removes the containers |
| `make ps` | shows the containers status and infos |
| `make logs` | shows the logs of the containers |
| `make fclean`| delets all the data volumes and images |
| `make re` | `down` then `run` |

The host data folders **must exist** before Compose starts, because the named volumes bind to them. The Makefile creates them with `mkdir -p`.

### With Docker Compose directly

```bash
docker compose -f srcs/docker-compose.yml up -d --build     # build and start
docker compose -f srcs/docker-compose.yml down              # stop
docker compose -f srcs/docker-compose.yml down -v           # stop and delete volume definitions
```

### Startup order

`nginx` depends on `wordpress`, which depends on `mariadb` (`depends_on`). MariaDB exposes a healthcheck and WordPress starts only when it is `healthy`. The WordPress entrypoint additionally waits until the database accepts connections, because "started" does not mean "ready".

## 3. Managing containers and volumes

### Containers

```bash
docker ps                                                     # running containers
docker ps -a                                                  # all containers
docker compose -f srcs/docker-compose.yml logs -f <service>   # follow logs
docker compose -f srcs/docker-compose.yml exec <service> sh   # shell in a container
docker compose -f srcs/docker-compose.yml restart <service>   # restart one service
docker compose -f srcs/docker-compose.yml build --no-cache <service>   # rebuild one image
docker inspect --format '{{json .State.Health}}' <container>  # healthcheck status
```

`<service>` is one of `mariadb`, `wordpress`, `nginx`.

### Useful checks

```bash
# Open a MariaDB session (password from the secret file)
docker compose -f srcs/docker-compose.yml exec mariadb \
  sh -c 'MYSQL_PWD=$(cat /run/secrets/db_root_password) mariadb -u root'

# Validate the nginx configuration
docker compose -f srcs/docker-compose.yml exec nginx nginx -t

# Check which secrets are mounted
docker compose -f srcs/docker-compose.yml exec wordpress ls /run/secrets
```

### Volumes

```bash
docker volume ls
docker volume inspect srcs_mariadb-data
docker volume inspect srcs_wordpress-data
```

`inspect` should show `"type": "none"`, `"o": "bind"` and the host path under `Options`.

### Cleaning up

```bash
docker compose -f srcs/docker-compose.yml down -v   # remove containers and volumes
docker system prune -af                             # remove all unused images, containers, networks
sudo rm -rf /home/sbaghdad/data/mariadb/* /home/sbaghdad/data/wordpress/*
```

> Volume options (`device`, `o`) are fixed when a volume is created. If you change them in `docker-compose.yml`, remove the volume first (`down -v` or `docker volume rm <name>`) or the old definition is kept.

## 4. Where the data is stored and how it persists

| Data | Container path | Host path | Volume |
|---|---|---|---|
| MariaDB database files | `/var/lib/mysql` | `/home/sbaghdad/data/mariadb` | `mariadb-data` |
| WordPress files (core, themes, plugins, uploads) | `/var/www/html` | `/home/sbaghdad/data/wordpress` | `wordpress-data` |

Both volumes are **named volumes** using the `local` driver with `driver_opts` (`type: none`, `o: bind`, `device: <host path>`), so Docker manages them as volumes while the data physically lives in the chosen host folders.

- **Persistence:** data survives `docker compose down`, container rebuilds and VM reboots, because it lives on the host and not in the container's writable layer.
- **First start detection:** the MariaDB entrypoint checks whether the database directory already exists (e.g. `/var/lib/mysql/<database>`) and only runs the initialization on the first start. WordPress does the same by checking for an existing `wp-config.php`.
- **Shared volume:** the WordPress volume is mounted in both `wordpress` and `nginx` at `/var/www/html`. NGINX serves static files directly and sends the PHP file path to php-fpm, which needs to find the same file at the same path.
- **Resetting everything:** `make fclean` deletes the host folders' contents, so the next `make` re-initializes the database and reinstalls WordPress from scratch.
- **Permissions:** files are owned by the container users (`mysql`, `www-data`), so deleting them from the host needs `sudo`. Entrypoints run `chown` on the mounted directories at startup.

## 5. Design notes for developers

- **One process per container**, run in the foreground as PID 1 (`mysqld_safe`/`mysqld`, `php-fpm -F`, `nginx -g "daemon off;"`). No `tail -f`, `sleep infinity` or `while true` tricks.
- **Base images:** penultimate stable Debian or Alpine, with images built from our own Dockerfiles only.
- **Network:** a single custom bridge network. Services reach each other by name (`mariadb`, `wordpress`) via Docker's embedded DNS. `network: host` and `links` are not used.
- **Ports:** only `443:443` on NGINX is published. PHP-FPM listens on 9000 and MariaDB on 3306 inside the network only. MariaDB binds to `0.0.0.0` and the WordPress DB user is created for host `%` so connections from the WordPress container are accepted.
- **TLS:** self-signed certificate generated by OpenSSL at image build time, TLSv1.2/1.3 only.
- **Restart policy:** `restart: unless-stopped` so services recover from crashes.
- **Credentials:** never in Dockerfiles or in the repository. Passwords come from secrets, configuration from `.env`.
