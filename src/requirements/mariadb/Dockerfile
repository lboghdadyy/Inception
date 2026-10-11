FROM debian:12

RUN apt update && apt upgrade -y

RUN apt install mariadb-server mariadb-client -y

WORKDIR /etc/mysql

COPY conf/mariadb.cnf .

COPY tools/entrypoint.sh .

ENTRYPOINT [ "entrypoint.sh" ]