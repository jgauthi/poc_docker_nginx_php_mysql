# Load env file
ifneq ("$(wildcard .env)","")
	include .env
	export $(shell sed 's/=.*//' .env)
endif

# Init var
user := $(shell id -u)
group := $(shell id www-data -g)
PROJECT_NAME=demo
PROJECT_DIR=/var/www/project/$(PROJECT_NAME)
DOCKER_COMPOSE := USER_ID=$(user) GROUP_ID=$(group) docker compose
EXEC?=$(DOCKER_COMPOSE) exec --workdir $(PROJECT_DIR) php
EXEC_SF?=$(DOCKER_COMPOSE) exec -u www-data php
EXEC_ROOT?=$(DOCKER_COMPOSE) exec --workdir $(PROJECT_DIR) -u root php
CONSOLE=$(EXEC_SF) symfony console
PHPCSFIXER?=$(EXEC) php -d memory_limit=1024m vendor/bin/php-cs-fixer

help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'


##
## Project setup
##---------------------------------------------------------------------------

sf: ## Symfony Command, example: `sf CMD="debug:router"`
	@$(CONSOLE) $(CMD)

up: conf-env-file up-ci  ## Start project with docker-compose + Dev env

stop:  ## Stop docker containers
	@$(DOCKER_COMPOSE) stop

refresh: ## Remove and re-create docker containers (WITHOUT delete all data)
	@$(DOCKER_COMPOSE) down
	@make up-ci

restart: stop up-ci  ## Restart docker containers

install: conf-env-file build up ## Create and start docker containers

install-demo:
	@$(EXEC_ROOT) chmod -R 775 /var/www
	@$(EXEC_ROOT) chown -R www-data:www-data /var/www
	@rm -rf project/* project/.env
	$(call composer,create-project symfony/symfony-demo install_project,/var/www/project)
	@cp .docker/php/symfony-demo.env project/.env
	@$(EXEC_ROOT) bash -c "cd /var/www/project && mv install_project/* $(PROJECT_NAME)/ && rm -rf install_project/ data/"
	@make restart perm db-create-migration db-install clear-cache

install-prod:
	APP_ENV=prod APP_DEBUG=0 $(call composer,install --no-dev --optimize-autoloader)
	APP_ENV=prod make clear-cache
	APP_ENV=prod APP_DEBUG=0 @$(CONSOLE) cache:clear
	@$(CONSOLE) cache:pool:clear cache.global_clearer

status:  ## Docker container status
	@$(DOCKER_COMPOSE) ps

uninstall: clear stop  ## Remove docker containers
	@$(DOCKER_COMPOSE) rm -vf

reset: uninstall install  ## Remove and re-create docker containers

clear-cache: perm  ## Clear + Prepare Cache (alias: c:c), you can specify the env: ENV=prod
	@$(CONSOLE) cache:clear --no-warmup
	@$(CONSOLE) cache:warmup

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
	@$(EXEC) php -d memory_limit=1500M /usr/local/bin/composer $(1) -n --working-dir=$(or $(2),$(PROJECT_DIR))
endef

composer-install:  ## Composer installation
	$(call composer,install)

composer:  ## Composer command. You can specified package, example: `make composer CMD="update twig/twig"`, you can set another project folder with the argument PROJECT_NAME="folder name in /var/www --OR-- /folder/full/path/location"
	$(call composer,$(CMD))

shell:  ## Run app container in interactive mode
	@$(EXEC) /bin/bash

server-dump:  ## [Dev only] Display dump() values with tail (ctrl+C to stop)
	@$(CONSOLE) server:dump


##
## Doctrine Command (Database)
##---------------------------------------------------------------------------
db-diff:  ## Generate a migration by comparing your current database to your mapping information
	@$(CONSOLE) doctrine:migration:diff

db-create-migration: ## Create migration
	@$(CONSOLE) make:migration

db-migrate:  ## Migrate database schema to the latest available version
	@$(CONSOLE) doctrine:migration:migrate -n

db-rollback:  ## Rollback the latest executed migration
	@$(CONSOLE) doctrine:migration:migrate prev -n

db-validate:  ## Check the ORM mapping
	@$(CONSOLE) doctrine:schema:validate

db-create-database: ## Create database if not exists
	@$(CONSOLE) doctrine:database:create --if-not-exists

db-fixtures:  ## Apply doctrine fixtures
	@$(CONSOLE) doctrine:fixtures:load -n

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
	@$(CONSOLE) lint:yaml config

lint-twig:   ## Lint Twig files
	@$(CONSOLE) lint:twig templates

lint-xliff:   ## Lint Translation files
	@$(CONSOLE) lint:xliff translations

php-cs: vendor  ## Lint PHP code
	@$(PHPCSFIXER) fix --diff --dry-run --no-interaction -v

php-cs-fix: vendor  ## Lint and fix PHP code to follow the convention
	@$(PHPCSFIXER) fix

security-check: vendor  ## Check for vulnerable dependencies
	@$(EXEC) vendor/bin/security-checker security:check

test-schema: vendor ## Test the doctrine Schema
	@$(CONSOLE) doctrine:schema:validate --skip-sync -vvv --no-interaction

test-all: lint test-schema security-check tests  ## Lint all, check vulnerable dependencies, run PHP tests

##


# Internal rules
build:
	@$(DOCKER_COMPOSE) pull --ignore-pull-failures
	@$(DOCKER_COMPOSE) build --force-rm

up-ci:
	@$(DOCKER_COMPOSE) up -d --remove-orphans --force-recreate

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

conf-env-file:
ifeq (,$(wildcard .env))
	@cp .docker/compose/docker.env .env
endif


#node_modules: yarn.lock
#	@$(EXEC) yarn install
#
#yarn.lock: package.json
#	@echo yarn.lock is not up to date.