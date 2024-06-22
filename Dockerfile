# Base stage
FROM debian:12-slim AS base

LABEL version="1.0"
LABEL description="Imagen Apache sobre Bookworn"
LABEL vendor="Jhoncy Tech"

ENV APACHE_VERSION=${APACHE_VERSION:-2.4}
ENV PHP_VERSION=${PHP_VERSION:-7.3}
ENV WP_VERSION=${WP_VERSION:-6.2.5}

ENV MYSQL_ROOT_PASSWORD='keepcoding'
ENV MYSQL_HOST="localhost"
ENV MYSQL_NAME="wordpress"
ENV MYSQL_USER="wordpressuser"
ENV MYSQL_PASS="keepcoding"

RUN apt-get -y update && apt-get -y install apt-transport-https ca-certificates lsb-release gnupg wget tar dos2unix curl && \
    echo "deb http://deb.debian.org/debian $(lsb_release -sc) main contrib non-free" > /etc/apt/sources.list.d/backports.list && \
    apt-get -y update

COPY files-config/000-default.conf files-config/apache2.conf files-config/start.sh files-config/.env /root/

#---------------------------------------------------------------------------

# APACHE Stage
FROM base AS apache

RUN apt-get -y install apache2=${APACHE_VERSION}*

COPY --from=base /root/apache2.conf /etc/apache2/
COPY --from=base /root/000-default.conf /etc/apache2/sites-available/

#---------------------------------------------------------------------------

# PHP Stage
FROM apache AS php

# Añadir el repositorio de Sury para PHP
RUN wget https://packages.sury.org/php/apt.gpg -O /tmp/apt.gpg && apt-key add /tmp/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
    apt-get -y update

RUN apt-get -y update && apt-get -y install \
    php${PHP_VERSION} \
    php${PHP_VERSION}-xmlrpc \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-common

#---------------------------------------------------------------------------

# WORDPRESS Stage
FROM php AS wordpress

RUN cd /tmp && \
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp && \
    echo 'export PATH=$PATH:/usr/local/bin' >> /root/.bashrc

RUN cd /var/www/html && \
    wp core download --locale=es_ES --version=${WP_VERSION} --force --allow-root && \
    chown -R www-data:www-data /var/www/html

#---------------------------------------------------------------------------

# FINAL Stage
FROM wordpress AS final

WORKDIR /var/www/html

COPY --from=base /root/start.sh /usr/local/bin/start.sh

RUN apt-get -y install mariadb-client && \
    dos2unix /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]