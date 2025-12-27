FROM php:8.4-fpm
LABEL maintainer="J.GAUTHI <github.com/jgauthi>"

ENV \
    DEBIAN_FRONTEND=noninteractive \
    LANG=fr_FR.UTF-8 \
    LANGUAGE=fr_FR.UTF-8 \
    LC_ALL=fr_FR.UTF-8 \
    TZ=Europe/Paris \
    USER_NAME=localuser \
    USER_NGINX=www-data \
    WORKDIR=/var/www/project/demo

# Installation des outils, configuration du fuseau horaire ET des locales
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano curl locales apt-utils supervisor tzdata \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && echo "${LANG} UTF-8" >> /etc/locale.gen && locale-gen \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Extensions PHP: https://github.com/mlocati/docker-php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
    apcu \
    amqp \
    @composer \
    gd \
    intl \
    memcached \
    mysqli pdo_mysql \
    mbstring \
    opcache \
    openssl \
    soap \
    tidy \
    xdebug \
    zip

# Install symfony cli
RUN curl -sS https://get.symfony.com/cli/installer | bash && mv /root/.symfony5/bin/symfony /usr/local/bin/

# PHP Conf
COPY 98-xdebug.ini $PHP_INI_DIR/conf.d/98-xdebug.ini
COPY 99-custom-php-conf.ini $PHP_INI_DIR/conf.d/99-custom-php-conf.ini

# Purge
RUN rm -rf /var/lib/apt/lists/* \
    && apt-get purge --auto-remove -y g++ \
    && apt-get clean

# Current User usage docker + Apache Group
RUN useradd -u 1000 -g ${USER_NGINX} -m -s /bin/bash ${USER_NAME} || true \
    && chown -R ${USER_NAME}:${USER_NGINX} /var/www \
    && chmod -R 775 /var/www

WORKDIR ${WORKDIR}

EXPOSE 9000
CMD ["php-fpm"]