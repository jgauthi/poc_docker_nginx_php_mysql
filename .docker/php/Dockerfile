FROM php:7.4-fpm

# Some libs
RUN apt-get update && apt-get install -y --no-install-recommends vim curl locales apt-utils unzip

# https://github.com/mlocati/docker-php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions @composer \
    apcu opcache intl \
    gd imagick \
    pdo_mysql \
    mbstring \
    xdebug \
    zip

# PHP Conf
COPY php.ini /usr/local/etc/php/php.ini
COPY php-fpm-pool.conf /usr/local/etc/php/php-fpm.conf

# Purge
RUN rm -rf /var/lib/apt/lists/* \
    && apt-get purge --auto-remove -y g++ \
    && apt-get clean

WORKDIR /var/www/
USER www-data

EXPOSE 9000
CMD ["php-fpm"]