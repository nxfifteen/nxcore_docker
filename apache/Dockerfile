# Stage 0, "build-stage", based on Node.js, to build and compile the frontend
FROM tiangolo/node-frontend:10 as build-stage

RUN npm install -g @angular/cli@8.3.26
# RUN ng config -g cli.warnings.versionMismatch false

COPY application/angular-frontend/package.json /app/
COPY application/angular-frontend /app/

WORKDIR /app/

RUN npm install

# --configuration docker
RUN npm run build -- --output-path=./dist/out --prod

FROM php:7.3.14-apache

# set main params
ARG BUILD_ARGUMENT_DEBUG_ENABLED=false
ENV DEBUG_ENABLED=$BUILD_ARGUMENT_DEBUG_ENABLED
ARG BUILD_ARGUMENT_ENV=dev
ENV ENV=$BUILD_ARGUMENT_ENV
ENV APP_HOME /var/www/html/

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
  procps \
  nano \
  git \
  unzip \
  libicu-dev \
  zlib1g-dev \
  libxml2 \
  libxml2-dev \
  libreadline-dev \
  supervisor \
  cron \
  libzip-dev \
  librabbitmq-dev \
  multitail \
  && pecl install amqp \
  && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
  && docker-php-ext-configure intl \
  && docker-php-ext-install \
  pdo_mysql \
  json \
  zip \
  && docker-php-ext-enable amqp \
  && rm -rf /tmp/* \
  && rm -rf /var/list/apt/* \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get clean \
  && docker-php-source delete

# disable default site and delete all default files inside APP_HOME
RUN a2dissite 000-default.conf
RUN rm -r $APP_HOME

# create document root
RUN mkdir -p $APP_HOME/public_frontend
RUN mkdir -p $APP_HOME/public_store

# change uid and gid of apache to docker user uid/gid
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data
RUN chown -R www-data:www-data $APP_HOME/public_frontend $APP_HOME/public_store

# put apache and php config for Symfony, enable sites
COPY ./apache/000-http.conf /etc/apache2/sites-available/application-http.conf
COPY ./apache/001-http-ssl.conf /etc/apache2/sites-available/application-http-ssl.conf
RUN a2ensite application-http.conf && a2ensite application-http-ssl
COPY ./env/dev/php.ini /usr/local/etc/php/php.ini

# enable apache modules
RUN a2enmod rewrite
RUN a2enmod ssl

# install Xdebug in case development or test environment
COPY ./env/dev/do_we_need_xdebug.sh /tmp/
COPY ./env/dev/xdebug.ini /tmp/
RUN chmod u+x /tmp/do_we_need_xdebug.sh && /tmp/do_we_need_xdebug.sh

# install composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN chmod +x /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER 1

# add supervisor
RUN mkdir -p /var/log/supervisor
COPY --chown=root:root ./env/all/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY --chown=root:root ./env/all/cron /var/spool/cron/crontabs/root
RUN chmod 0600 /var/spool/cron/crontabs/root

# generate certificates
# TODO: change it and make additional logic for production environment
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/ssl-cert-snakeoil.key -out /etc/ssl/certs/ssl-cert-snakeoil.pem -subj "/C=AT/ST=Vienna/L=Vienna/O=Security/OU=Development/CN=example.com"

# set working directory
WORKDIR $APP_HOME

# create composer folder for user www-data
RUN mkdir -p /var/www/.composer && chown -R www-data:www-data /var/www/.composer

RUN mkdir -p /tmp/sync_upload_post && chown -R www-data:www-data /tmp/sync_upload_post

USER www-data

# copy source files
COPY --chown=www-data:www-data --from=build-stage /app/dist/out/ $APP_HOME/public_frontend
COPY --chown=www-data:www-data application/symfony-store $APP_HOME/public_store
WORKDIR $APP_HOME/public_store

RUN composer install

# # install all PHP dependencies
# RUN if [ "$BUILD_ARGUMENT_ENV" = "dev" ] || [ "$BUILD_ARGUMENT_ENV" = "test" ]; then COMPOSER_MEMORY_LIMIT=-1 composer install --optimize-autoloader --no-interaction --no-progress; \
#   else export APP_ENV=$BUILD_ARGUMENT_ENV && COMPOSER_MEMORY_LIMIT=-1 composer install --optimize-autoloader --no-interaction --no-progress --no-dev; \
#   fi

# # create cached config file .env.local.php in case prod environment
# RUN if [ "$BUILD_ARGUMENT_ENV" = "prod" ]; then composer dump-env $BUILD_ARGUMENT_ENV; \
#   fi

USER root
