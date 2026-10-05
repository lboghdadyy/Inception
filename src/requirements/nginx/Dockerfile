FROM debian:latest

WORKDIR /etc/nginx

RUN apt update

RUN apt install nginx openssl -y

RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout inception_private_key.key -out inception_certif.crt

COPY conf/nginx.conf .

EXPOSE 443

ENTRYPOINT ["nginx"]

CMD ["-g", "daemon off;"]