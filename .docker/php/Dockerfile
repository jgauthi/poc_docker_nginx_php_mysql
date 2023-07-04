FROM php:8.2-fpm
MAINTAINER J.GAUTHI <github.com/jgauthi>

# Some libs
RUN apt-get update && apt-get install -y --no-install-recommends vim curl locales apt-utils unzip

# https://github.com/mlocati/docker-php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
    apcu opcache intl \
    gd \
    pdo_mysql \
    mbstring \
    sodium \
    xdebug \
    zip

# Install composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Install symfony cli
RUN curl -sS https://get.symfony.com/cli/installer | bash && mv /root/.symfony5/bin/symfony /usr/local/bin/
RUN chown -R www-data:www-data /var/www

# PHP Conf
COPY php.ini /usr/local/etc/php/php.ini
COPY php-fpm-pool.conf /usr/local/etc/php/php-fpm.conf

# Purge
RUN rm -rf /var/lib/apt/lists/* \
    && apt-get purge --auto-remove -y g++ \
    && apt-get clean

WORKDIR /var/www/project/demo
USER www-data

EXPOSE 9000
CMD ["php-fpm"]