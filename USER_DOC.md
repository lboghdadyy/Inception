# User Documentation

This document explains how to use the Inception stack as an end user or administrator, without needing to know how it is built. For the technical details, see [DEV_DOC.md](DEV_DOC.md).

## 1. Services provided

The stack runs three services, each in its own Docker container:

| Service (container) | What it does | Reachable from outside? |
|---|---|---|
| **nginx** | Web server and the single entry point. Encrypts traffic with HTTPS (TLS 1.2/1.3). | Yes, port **443** |
| **wordpress** (PHP-FPM) | The website and its administration panel. | No, internal only |
| **mariadb** | The database that stores the site's content (posts, pages, comments, users). | No, internal only |

Everything is accessed through the browser at **https://sbaghdad.42.fr**.

## 2. Starting and stopping the project

All commands are run from the root of the repository, **as your normal user (not with `sudo`)**.

| Action | Command |
|---|---|
| Start the project (builds it the first time) | `make` |
| Stop the project (data is kept) | `make down` |
| Show the status of the containers | `make ps` |
| Show / follow the logs | `make logs` |
| Remove containers, volumes definitions and images (data is kept) | `make clean` |
| Remove everything, **including all site data** | `make fclean` |
| Rebuild everything from scratch (erases the data) | `make re` |

> **Warning:** `make fclean` permanently delete the website content and the database stored in `/home/sbaghdad/data`. Use `make down` for a normal stop.

The first start can take a minute or two: MariaDB initializes first, and WordPress and NGINX only start once the service they depend on reports `healthy`.

## 3. Accessing the website and the administration panel

1. Make sure your machine resolves the domain name. This line must be in `/etc/hosts`:

   ```
   127.0.0.1   sbaghdad.42.fr
   ```

2. Open a browser and go to:
   - **Website:** https://sbaghdad.42.fr
   - **Administration panel:** https://sbaghdad.42.fr/wp-admin

3. The browser will warn that the connection is not trusted. This is expected: the HTTPS certificate is self-signed (generated locally, not issued by a public authority). Accept the warning to continue.

Plain `http://` (port 80) is not available. Only HTTPS works.

## 4. Locating and managing credentials

Passwords are **not** stored in the configuration file or in the images. They are separate files in the `secrets/` folder at the root of the repository:

| File | Contains |
|---|---|
| `secrets/mySqlRootPassword.txt` | MariaDB root password |
| `secrets/mySqlPassword.txt` | Password of the database user used by WordPress |
| `secrets/wp-AdminPassword.txt` | Password of the WordPress administrator |
| `secrets/wp-UserPassword.txt` | Password of the second (regular) WordPress user |

Non-sensitive settings (domain name, database name, usernames, emails) are in `srcs/.env`.

To log in to the administration panel, use the administrator username `WP_ADMIN_USER` from `srcs/.env` and the password in `secrets/wp-AdminPassword.txt`. A second, non-administrator user (`WP_USER`) also exists, with the password in `secrets/wp-UserPassword.txt`.

### Changing a password

- **A WordPress user's password:** change it from the administration panel (*Users > Profile*). This is the simplest and recommended way.
- **A password in the `secrets/` folder** (for example the database password): secrets are read when the services are first initialized, so editing the file afterwards does not change the existing database. To apply a new value you must run `make fclean` and then `make`. This **erases all site content**.

Keep `secrets/` and `srcs/.env` private and never commit them to Git.

## 5. Checking that the services are running correctly

**1. List the containers.** All three must be `Up`; `mariadb` and `wordpress` must show `(healthy)`:

```bash
make ps
```

**2. Check the website.** Open https://sbaghdad.42.fr. You should see the WordPress site. A "502 Bad Gateway" error means NGINX is running but WordPress has crashed or is not responding.

**3. Check the logs** if something looks wrong:

```bash
make logs
docker logs mariadb
docker logs wordpress
docker logs nginx
```

**4. Check the health status** of a service:

```bash
docker inspect --format '{{.State.Health.Status}}' mariadb
docker inspect --format '{{.State.Health.Status}}' wordpress
```

**5. Check the encryption** (optional). Only TLS 1.2 and 1.3 are accepted:

```bash
openssl s_client -connect sbaghdad.42.fr:443 -tls1_2 </dev/null 2>/dev/null | grep -i "protocol"
openssl s_client -connect sbaghdad.42.fr:443 -tls1_1 </dev/null 2>&1 | grep -i "alert\|error"   # must fail
```

**6. Check that port 80 is closed** (optional):

```bash
curl -I http://sbaghdad.42.fr    # must fail to 
```

### Common problems

| Symptom | Likely cause and fix |
|---|---|
| The domain does not load | The `/etc/hosts` line is missing, or the stack is not running (`make ps`). |
| Nothing starts, `mariadb` stays unhealthy | Check `docker logs mariadb`: wrong secret, or leftover data from an older run (`make clean`, then `make`). |
| 502 Bad Gateway | WordPress crashed or is not ready. Check `docker logs wordpress`. |
| "Error establishing a database connection" | Credentials in `secrets/` and the database do not match. Reset with `make fclean` then `make`. |
| Browser security warning | Normal for a self-signed certificate. Accept it. |
| Site content disappeared | `make fclean` or `make re` was used, which deletes the data. |