FROM debian:12

RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /etc/nginx

RUN mkdir certificate/

RUN openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout certificate/inception_private_key.key \
    -out certificate/inception_certif.crt \
    -subj "/C=MA/ST=BeniMellal-Khenifra/L=Khouribga/O=42/CN=sbaghdad.42.fr"

COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

COPY ./tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

CMD [ "/usr/local/bin/entrypoint.sh" ]