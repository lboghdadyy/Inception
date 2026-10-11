FROM debian:12

RUN apt-get update && apt-get install -y \
    php-fpm \
    php-cli \
    php-mysql \
    curl \
    tar \
    && rm -rf /var/lib/apt/lists/*

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp \
    && wp --info

WORKDIR /var/www/html

RUN curl --fail --location \
    https://wordpress.org/wordpress-7.1.3.tar.gz \
    --output /tmp/wordpress.tar.gz \
    && tar -xf /tmp/wordpress.tar.gz -C /tmp \
    && cp -a /tmp/wordpress/. /var/www/html/ \
    && rm -rf /tmp/wordpress /tmp/wordpress.tar.gz

COPY conf/www.conf /tmp/www.conf

RUN PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;') \
    && cp /tmp/www.conf "/etc/php/$PHP_VERSION/fpm/pool.d/www.conf" \
    && rm /tmp/www.conf

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
