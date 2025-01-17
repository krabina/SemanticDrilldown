-include .env
export

# ======== Naming ========
EXTENSION := SemanticDrilldown
EXTENSION_FOLDER := /var/www/html/extensions/$(EXTENSION)
extension := $(shell echo $(EXTENSION) | tr A-Z a-z})
IMAGE_NAME := $(extension):test-$(MW_VERSION)-$(SMW_VERSION)-$(PS_VERSION)-$(AL_VERSION)-$(MAPS_VERSION)-$(SRF_VERSION)


# ======== CI ENV Variables ========
MW_VERSION ?= 1.35
SMW_VERSION ?= 4.1.0
PS_VERSION ?= 0.6.1
AL_VERSION ?= 0.4.2
MAPS_VERSION ?= 9.0.7
SRF_VERSION ?= 4.0.1
PHP_VERSION ?= 7.4
DB_TYPE ?= sqlite
DB_IMAGE ?= ""


environment = IMAGE_NAME=$(IMAGE_NAME) \
MW_VERSION=$(MW_VERSION)  \
SMW_VERSION=$(SMW_VERSION) \
PS_VERSION=$(PS_VERSION) \
AL_VERSION=$(AL_VERSION) \
MAPS_VERSION=$(MAPS_VERSION) \
SRF_VERSION=$(SRF_VERSION) \
PHP_VERSION=$(PHP_VERSION) \
DB_TYPE=$(DB_TYPE) \
DB_IMAGE=$(DB_IMAGE) \
EXTENSION_FOLDER=$(EXTENSION_FOLDER)


ifneq (,$(wildcard ./docker-compose.override.yml))
     COMPOSE_OVERRIDE=-f docker-compose.override.yml
endif


compose = $(environment) docker-compose $(COMPOSE_OVERRIDE) $(COMPOSE_ARGS)
compose-ci = $(environment) docker-compose -f docker-compose.yml -f docker-compose-ci.yml $(COMPOSE_OVERRIDE) $(COMPOSE_ARGS)
compose-dev = $(environment) docker-compose -f docker-compose.yml -f docker-compose-dev.yml $(COMPOSE_OVERRIDE) $(COMPOSE_ARGS)

compose-run = $(compose) run -T --rm
compose-exec-wiki = $(compose) exec -T wiki

show-current-target = @echo; echo "======= $@ ========"

# ======== CI ========
# ======== Global Targets ========

.PHONY: ci
ci: install composer-test npm-test

.PHONY: ci-coverage
ci-coverage: install composer-test-coverage npm-test-coverage

.PHONY: install
install: destroy up .install

.PHONY: up
up: .init .build .up

.PHONY: down
down: .init .down

.PHONY: destroy
destroy: .init .destroy

.PHONY: bash
bash: up .bash

# ======== General Docker-Compose Helper Targets ========

.PHONY: .build
.build:
	$(show-current-target)
	$(compose-ci) build wiki
.PHONY: .up
.up:
	$(show-current-target)
	$(compose-ci) up -d

.PHONY: .install
.install: .wait-for-db
	$(show-current-target)
	$(compose-exec-wiki) bash -c "sudo -u www-data \
		php maintenance/install.php \
		    --pass=wiki4everyone --server=http://localhost:8080 --scriptpath='' \
    		--dbname=wiki --dbuser=wiki --dbpass=wiki $(WIKI_DB_CONFIG) wiki WikiSysop && \
		cat __setup_extension__ >> LocalSettings.php && \
		sudo -u www-data php maintenance/update.php --skip-external-dependencies --quick \
		"

.PHONY: .down
.down:
	$(show-current-target)
	$(compose-ci) down

.PHONY: .destroy
.destroy:
	$(show-current-target)
	$(compose-ci) down -v

.PHONY: .bash
.bash: .init
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && bash"

# ======== Test Targets ========

.PHONY: composer-test
composer-test:
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && composer test"

.PHONY: composer-test-coverage
composer-test-coverage:
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && composer test-coverage"

.PHONY: npm-test
npm-test:
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && npm run test"

.PHONY: npm-test-coverage
npm-test-coverage:
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && npm run test-coverage"

# ======== Dev Targets ========

.PHONY: dev-bash
dev-bash: .init
	$(compose-dev) run -it wiki bash -c 'service apache2 start && bash'

.PHONY: run
run:
	$(compose-dev) -f docker-compose-dev.yml run -it wiki

# ======== Releasing ========
VERSION = `node -e 'console.log(require("./extension.json").version)'`

.PHONY: release
release: ci git-push gh-login
	gh release create $(VERSION)

.PHONY: git-push
git-push:
	git diff --quiet || (echo 'git directory has changes'; exit 1)
	git push

.PHONY: gh-login
gh-login: require-GH_API_TOKEN
	gh config set prompt disabled
	@echo $(GH_API_TOKEN) | gh auth login --with-token

.PHONY: require-GH_API_TOKEN
require-GH_API_TOKEN:
ifndef GH_API_TOKEN
	$(error GH_API_TOKEN is not set)
endif


# ======== Helpers ========
.PHONY: .init
.init:
	$(show-current-target)
	$(eval COMPOSE_ARGS = --project-name ${extension}-$(DB_TYPE) --profile $(DB_TYPE))
ifeq ($(DB_TYPE), sqlite)
	$(eval WIKI_DB_CONFIG = --dbtype=$(DB_TYPE) --dbpath=/tmp/sqlite)
else
	$(eval WIKI_DB_CONFIG = --dbtype=$(DB_TYPE) --dbserver=$(DB_TYPE) --installdbuser=root --installdbpass=database)
endif
	@echo "COMPOSE_ARGS: $(COMPOSE_ARGS)"

.PHONY: .wait-for-db
.wait-for-db:
	$(show-current-target)
ifeq ($(DB_TYPE), mysql)
	$(compose-run) wait-for $(DB_TYPE):3306 -t 120
else ifeq ($(DB_TYPE), postgres)
	$(compose-run) wait-for $(DB_TYPE):5432 -t 120
endif