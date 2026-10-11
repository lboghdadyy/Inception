FROM debian:12

RUN apt update && apt upgrade -y

RUN apt install mariadb-server mariadb-client -y

WORKDIR /etc/mysql

COPY conf/mariadb.cnf .

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

RUN mkdir -p /run/mysqld \
    && chown mysql:mysql /run/mysqld

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]