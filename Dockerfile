FROM php:7.4-fpm-alpine

# Настройка прокси-серверов через ARG для безопасности сборки
ARG HTTP_PROXY
ARG HTTPS_PROXY
ENV http_proxy=$HTTP_PROXY
ENV https_proxy=$HTTPS_PROXY

# Переключение apk репозиториев на http на время сборки за прокси (если SSL ломается)
RUN sed -i 's/https/http/g' /etc/apk/repositories

# Установка системных зависимостей для production-окружения PHP (Yii2 / Web)
RUN apk add --no-cache \
    nginx \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    zlib-dev \
    mariadb-client \
    bash

# Настройка и установка расширений ядра PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install pdo_mysql gd zip intl mysqli mbstring exif

# Перевод PHP-FPM на прослушивание локального порта 9000
RUN sed -i 's/listen = .*/listen = 127.0.0.1:9000/' /usr/local/etc/php-fpm.d/www.conf

# Очистка дефолтных сайтов Nginx и копирование оптимизированного конфига
RUN rm -rf /etc/nginx/http.d/* /etc/nginx/conf.d/* /etc/nginx/nginx.conf
COPY nginx-app.conf /etc/nginx/nginx.conf

# Перенаправление логов веб-сервера в stdout/stderr для сбора логов силами Kubernetes (Promtail/Fluentd)
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

WORKDIR /var/www/html
COPY . /var/www/html/

# Инициализация необходимых папок и сброс прав на www-data для безопасности (Non-root выполнения процессов)
RUN mkdir -p runtime web/assets /var/lib/nginx/tmp && \
  chown -R www-data:www-data /var/www/html && \
  chown -R www-data:www-data /var/lib/nginx && \
  chown -R www-data:www-data /var/log/nginx && \
  chmod -R 775 runtime web/assets

EXPOSE 80

# Скрипт запуска веб-сервера и PHP-FPM в одном контейнере
CMD ["sh", "-c", "php-fpm -D && nginx -g 'daemon off;'"]