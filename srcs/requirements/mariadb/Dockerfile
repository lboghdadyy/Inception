FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends mariadb-server mariadb-client

COPY conf/mariadb.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /run/mysqld \
    && chown mysql:mysql /run/mysqld

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]