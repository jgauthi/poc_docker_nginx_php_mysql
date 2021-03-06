# Load env file
ifneq ("$(wildcard .env)","")
	include .env
	export $(shell sed 's/=.*//' .env)
endif

# Init var
user := $(shell id -u)
group := $(shell id www-data -g)
DOCKER_COMPOSE := USER_ID=$(user) GROUP_ID=$(group) docker-compose
EXEC?=$(DOCKER_COMPOSE) exec php
EXEC_ROOT?=$(DOCKER_COMPOSE) exec -u root php
CONSOLE=bin/console
PHPCSFIXER?=$(EXEC) php -d memory_limit=1024m vendor/bin/php-cs-fixer
DOCKER_COMPOSE_OVERRIDE ?= dev

help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'


##
## Project setup
##---------------------------------------------------------------------------

sf: ## Symfony Command, example: `sf CMD="debug:router"`
	@$(EXEC) $(CONSOLE) $(CMD)

up: docker-compose.override.yml up-ci  ## Start project with docker-compose + Dev env

stop:  ## Stop docker containers
	@$(DOCKER_COMPOSE) stop

restart: stop up-ci  ## Restart docker containers

install: docker-compose.override.yml build up ## Create and start docker containers

install-demo:
	@$(EXEC_ROOT) chmod 775 /var/www
	@$(EXEC_ROOT) chown www-data:www-data /var/www
	@rm -rf project/* project/.env
	$(call composer,create-project symfony/symfony-demo demo)
	@cp .docker/php/symfony-demo.env project/.env
	@$(EXEC_ROOT) bash -c "mv demo/* . && rm -rf demo/ data/"
	@make restart perm db-create-migration db-install clear-cache

install-prod:
	APP_ENV=prod APP_DEBUG=0 $(call composer,install --no-dev --optimize-autoloader)
	APP_ENV=prod make clear-cache
	APP_ENV=prod APP_DEBUG=0 @$(EXEC) $(CONSOLE) cache:clear
	@$(EXEC) $(CONSOLE) cache:pool:clear cache.global_clearer

status:  ## Docker container status
	@$(DOCKER_COMPOSE) ps

uninstall: clear stop  ## Remove docker containers
	@$(DOCKER_COMPOSE) rm -vf

reset: uninstall install  ## Remove and re-create docker containers

clear-cache: perm  ## Clear + Prepare Cache (alias: c:c), you can specify the env: ENV=prod
	@$(EXEC) $(CONSOLE) cache:clear --no-warmup --env=$(APP_ENV)
	@$(EXEC) $(CONSOLE) cache:warmup --env=$(APP_ENV)

c\:c: clear-cache

clear: perm  ## Remove all the cache, the logs, the sessions and the built assets
	@$(EXEC_ROOT) rm -rf var/cache/* var/log/* public/build
	@$(EXEC_ROOT) rm -f var/.php_cs.cache

clean: clear  ## Clear and remove dependencies
	@$(EXEC_ROOT) rm -rf vendor




##
## Developpment
##---------------------------------------------------------------------------
define composer
	@$(EXEC) php -d memory_limit=1500M /usr/local/bin/composer $(1) -n
endef

composer-install:  ## Composer installation
	$(call composer,install)

composer:  ## Composer command. You can specified package, example: `make composer CMD="update twig/twig"`
	$(call composer,$(CMD))

shell:  ## Run app container in interactive mode
	@$(EXEC) /bin/bash

server-dump:  ## [Dev only] Display dump() values with tail (ctrl+C to stop)
	@$(EXEC) $(CONSOLE) server:dump


##
## Doctrine Command (Database)
##---------------------------------------------------------------------------
db-diff:  ## Generate a migration by comparing your current database to your mapping information
	@$(EXEC) $(CONSOLE) doctrine:migration:diff

db-create-migration: ## Create migration
	@$(EXEC) $(CONSOLE) make:migration

db-migrate:  ## Migrate database schema to the latest available version
	@$(EXEC) $(CONSOLE) doctrine:migration:migrate -n --env=$(APP_ENV)

db-rollback:  ## Rollback the latest executed migration
	@$(EXEC) $(CONSOLE) doctrine:migration:migrate prev -n --env=$(APP_ENV)

db-validate:  ## Check the ORM mapping
	@$(EXEC) $(CONSOLE) doctrine:schema:validate

db-create-database: ## Create database if not exists
	@$(EXEC) $(CONSOLE) doctrine:database:create --if-not-exists

db-fixtures:  ## Apply doctrine fixtures
	@$(EXEC) $(CONSOLE) doctrine:fixtures:load -n --env=$(APP_ENV)

db-install: db-create-database db-migrate db-fixtures ## Drop and install database with schema + fixtures

db-dump: ## Dump Database on dump_DBNAME.sql file
	@$(DOCKER_COMPOSE) exec db mysqldump --host=db --port=$(MYSQL_PORT) --default-character-set=utf8 -u $(MYSQL_USER) --password=$(MYSQL_PASSWORD) $(MYSQL_DATABASE) > dump_$(MYSQL_DATABASE).sql
	@ls -l dump_$(MYSQL_DATABASE).sql

db-query: ## Execute query $CMD="mysql query"
	@$(DOCKER_COMPOSE) exec db mysql --host=db --port=$(MYSQL_PORT) --default-character-set=utf8 -u $(MYSQL_USER) --password=$(MYSQL_PASSWORD) $(MYSQL_DATABASE) -e "$(CMD)"


# ##
# ## Assets
# ##---------------------------------------------------------------------------

#watch: node_modules ## Watch the assets and build their development version on change
#	@$(EXEC) yarn watch
#
#assets: node_modules## Build the development version of the assets
#	@$(EXEC) yarn dev
#
#assets-build: node_modules ## Build the production version of the assets
#	@$(EXEC) yarn build

##
## Tests
##---------------------------------------------------------------------------

tests: ## Run all the PHP tests
	@$(EXEC) bin/phpunit

lint: lint-symfony php-cs  ## Run lint on Twig, YAML, PHP and Javascript files

lint-symfony: lint-yaml lint-twig lint-xliff  ## Lint Symfony (Twig and YAML) files

lint-yaml:   ## Lint YAML files
	@$(EXEC) $(CONSOLE) lint:yaml config

lint-twig:   ## Lint Twig files
	@$(EXEC) $(CONSOLE) lint:twig templates

lint-xliff:   ## Lint Translation files
	@$(EXEC) $(CONSOLE) lint:xliff translations

php-cs: vendor  ## Lint PHP code
	@$(PHPCSFIXER) fix --diff --dry-run --no-interaction -v

php-cs-fix: vendor  ## Lint and fix PHP code to follow the convention
	@$(PHPCSFIXER) fix

security-check: vendor  ## Check for vulnerable dependencies
	@$(EXEC) vendor/bin/security-checker security:check

test-schema: vendor ## Test the doctrine Schema
	@$(EXEC) $(CONSOLE) doctrine:schema:validate --skip-sync -vvv --no-interaction

test-all: lint test-schema security-check tests  ## Lint all, check vulnerable dependencies, run PHP tests

##


# Internal rules
build:
	@$(DOCKER_COMPOSE) pull --ignore-pull-failures
	@$(DOCKER_COMPOSE) build --force-rm

up-ci:
	@$(DOCKER_COMPOSE) up -d --remove-orphans

perm: ## Set folder permissions
	@$(EXEC_ROOT) chmod -R 775 var migrations
	@$(EXEC_ROOT) chgrp -R www-data var migrations
	@$(EXEC_ROOT) bash -c "chmod +x bin/* vendor/bin/*"

#docker-compose.override.yml:
#ifneq ($(wildcard docker-compose.override.yml),docker-compose.override.yml)
#	@echo docker-compose.override.yml do not exists, copy docker-compose.override.yml.dist to create it, and fill it.
#	exit 1
#endif

define echo_text
	echo -e '\e[1;$(2)m$(1)\e[0m'
endef

docker-compose.override.yml: docker-compose.$(DOCKER_COMPOSE_OVERRIDE).yml
ifeq (,$(wildcard .env))
	@cp .env.dist .env
endif
	@test -f docker-compose.override.yml \
		&& $(call echo_text,/!\ docker-compose.$(DOCKER_COMPOSE_OVERRIDE).yml might have been modified - remove docker-compose.override.yml to be up-to-date,31) \
		|| ( echo "Copy docker-compose.override.yml from docker-compose.$(DOCKER_COMPOSE_OVERRIDE).yml"; cp docker-compose.$(DOCKER_COMPOSE_OVERRIDE).yml docker-compose.override.yml )


#node_modules: yarn.lock
#	@$(EXEC) yarn install
#
#yarn.lock: package.json
#	@echo yarn.lock is not up to date.