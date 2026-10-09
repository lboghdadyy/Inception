FROM debian:13

RUN apt update && apt upgrade -y

RUN apt install mariadb-server mariadb-client

WORKDIR /etc/mysql

COPY conf/mariadb.cnf .

ENTRYPOINT [ "tools/entrypoint.sh" ]

CMD ["mariadb"]