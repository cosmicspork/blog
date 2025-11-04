+++
title = "The pocket guide to building PHP 7.4 extensions in Docker containers and also OCI8"
date = 2025-08-01
updated = 2025-08-06
description = "A potentially helpful guide to build dependencies in the official PHP containers."

[taxonomies]
tags = ["php","docker","containers"]
categories = ["software development"]
+++

For reasons I don't want to get into, I need to build a bunch of extensions for PHP 7.4 in a Docker container to keep a legacy application on life-support. I have found the process for determining what extensions need what libraries to compile frustrating, to say the least.

## PHP 7.4 Extensions

To determine exactly what was required I installed.

```dockerfile
FROM php:7.4

# Init
ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt-get update \
 && apt-get install -y \
 curl \
 git \
 openssl \
 unzip \
 wget \
 zsh

# Install PHP extensions
RUN docker-php-ext-install bcmath

RUN apt-get install -y libcurl4 libcurl4-openssl-dev
RUN docker-php-ext-install curl

RUN docker-php-ext-install fileinfo

RUN apt-get install -y libssl-dev
RUN docker-php-ext-install ftp

RUN apt-get install -y libfreetype6-dev libgd-dev libjpeg62-turbo-dev libpng-dev
RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install gd

RUN apt-get install -y libicu-dev
RUN docker-php-ext-install intl

RUN apt-get install -y libldap2-dev libldap-common
RUN docker-php-ext-install ldap

RUN apt-get install -y libonig-dev
RUN docker-php-ext-install mbstring

RUN docker-php-ext-install pcntl
RUN docker-php-ext-install session

RUN apt-get install -y libxml2-dev
RUN docker-php-ext-install dom
RUN docker-php-ext-install soap
RUN docker-php-ext-install xml

RUN apt-get install -y libzip-dev
RUN docker-php-ext-install zip
```

It's certainly not perfect and I am fairly confident that libssl-dev is required by a couple other packages further down.

## OCI8

```dockerfile
# Install Oracle Instantclient
RUN apt-get install -y libaio1 libaio-dev
RUN mkdir -p /opt/oracle
RUN wget https://download.oracle.com/otn_software/linux/instantclient/2114000/instantclient-basic-linux.x64-21.14.0.0.0dbru.zip \
    && wget https://download.oracle.com/otn_software/linux/instantclient/2114000/instantclient-sdk-linux.x64-21.14.0.0.0dbru.zip \
    && unzip instantclient-basic-linux.x64-21.14.0.0.0dbru.zip -d /opt/oracle \
    && unzip instantclient-sdk-linux.x64-21.14.0.0.0dbru.zip -d /opt/oracle \ 
    && rm -rf *.zip \
    && mv /opt/oracle/instantclient_21_14 /opt/oracle/instantclient
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient
RUN echo "/opt/oracle/instantclient" > /etc/ld.so.conf.d/oracle.conf && ldconfig

RUN docker-php-ext-configure pdo_oci --with-pdo-oci=instantclient,/opt/oracle/instantclient,21.14 \
    && echo 'instantclient,/opt/oracle/instantclient/' | pecl install oci8-2.2.0 \
    && docker-php-ext-enable oci8 \
    && docker-php-ext-install pdo pdo_oci
```

## Sources that helped me out

- Gist ["Complete list of php docker ext"](https://gist.github.com/hoandang/88bfb1e30805df6d1539640fc1719d12) (2017)
- This [comment](https://github.com/docker-library/php/issues/912#issuecomment-1761074297) about setting up the *gd* extension.
