FROM debian:13

RUN apt-get -y update && apt-get -y upgrade && apt update -y && apt upgrade

RUN apt-get update && apt-get install php-fpm php-mysql curl tar -y

WORKDIR /var/www/html

RUN curl https://wordpress.org/wordpress-7.1.3.tar.gz --output wordpress.tar.gz

RUN tar -xf wordpress.tar.gz

RUN cp wordpress/* -rf .

COPY conf/www.conf /tmp/www.conf

RUN PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;') && cp /tmp/www.conf /etc/php/$PHP_VERSION/fpm/pool.d/

COPY tools/entrypoint.sh .

ENTRYPOINT [ "entrypoint.sh" ]