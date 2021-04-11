# Docker Nginx + PHP + Mysql + Dev Tools
A Docker image based on Ubuntu, serving PHP 7.4 FPM running as Nginx Module. Useful for Web developers in need for a fixed PHP version. In addition, the `error_reporting` setting in php.ini is configurable per container via environment variable.

## Prerequisite

* Docker v18+ / Docker-compose v1.23+ / [Manage Docker as a non-root user](https://docs.docker.com/install/linux/linux-postinstall/)
* Make command: Under linux `sudo apt install build-essential` or for [windows users](https://stackoverflow.com/questions/32127524/how-to-install-and-use-make-in-windows/54086635)
* Git


## Installation
Before use the docker version, check that ports 80/8080/443 are available. If an Apache / Nginx local server, another docker container are active, they can block access to these ports.

```shell script
make install

# If symfony project is present on project folder
make install composer-install perm
```

**Installed packages:**
* nginx
* php
* php-cli
* php-acpu
* php-curl
* php-gd
* php-imagick
* php-intl
* php-mbstring
* php-pdo_mysql
* php-opcache
* php-zip
* composer (php package manager)

For test Nginx/php container, you can install Symfony Demo
```shell script
make install-demo
```


## Usage
Launch docker containers: `make up`, or stop with `make stop`, you can get command list with `make help`.

You can connect on url application:
* [Example Symfony Demo](http://demo.localhost.tv)
* [phpMyAdmin](http://pma.localhost.tv)
* [mailDev](http://maildev.localhost.tv)


## Dev environment
If you use dev docker file _(default configuration)_, you have additional tools:

* You can access to mysql on localhost:33060 (for PhpStorm / Mysql Workbench).
* You can use mysql command line without indicate user/pass:
	* Standard request: `make db-query CMD="show tables;"`
	* Dump: `make db-dump`

Enjoy