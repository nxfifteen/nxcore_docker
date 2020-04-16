include envfile.ini
export $(shell sed 's/=.*//' envfile)

dir=${CURDIR}
frontenddir=$(dir)/application/angular-frontend
storedir=$(dir)/application/symfony-store
project=-p core
# app_env=docker-${HOSTNAME}

ifneq ($(interactive),1)
	optionT=-T
endif

ifeq (symfony-db,$(firstword $(MAKECMDGOALS)))
  # use the rest as arguments for "run"
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(RUN_ARGS):;@:)
endif

test:
	@echo $(httpadr)
	@echo $(invitecode)
	@echo $(appsecret)

clean:
	if [ -d "$(frontenddir)" ]; then sudo rm -r $(frontenddir); fi
	if [ -d "$(storedir)" ]; then sudo rm -r $(storedir); fi

start:
	@docker-compose -f docker-compose.yml $(project) up -d

stop:
	@docker-compose -f docker-compose.yml $(project) down

restart: stop start

log:
	@docker logs -f apache

log-db:
	@docker logs -f db

log-debug:
	@docker exec -it apache multitail /tmp/sync_upload_post/debug_transform.txt

ssh:
	@docker exec -it apache bash

ssh-db:
	@docker exec -it db bash

backup-db:
	@if [ ! -d "$(dir)/backups" ]; then mkdir "$(dir)/backups"; fi
	datefilename=$(date) && echo $(datefilename)
	# @docker-compose $(project) exec $(optionT) db /usr/bin/mysqldump -u symfony --password=symfony symfony > "$(dir)/backups/backup.sql"

restore-db:
	cat "$(dir)/backups/import.sql" | docker-compose $(project) exec $(optionT) db /usr/bin/mysql -u symfony --password=symfony symfony

configure:
	@if [ -d "$(frontenddir)/src/assets/badges/" ]; then mkdir -p "$(frontenddir)/src/assets/badges/"; fi
	@rsync -hru 192.168.0.2:/volume1/web/ui/assets/badges/* $(frontenddir)/src/assets/badges/
	@if [ -d "$(frontenddir)/src/assets/xplevels/" ]; then mkdir -p "$(frontenddir)/src/assets/xplevels/"; fi
	@rsync -hru 192.168.0.2:/volume1/web/ui/assets/xplevels/* $(frontenddir)/src/assets/xplevels/
	@if [ -d "$(frontenddir)/src/assets/fonts/" ]; then mkdir -p "$(frontenddir)/src/assets/fonts/"; fi
	@rsync -hru 192.168.0.2:/volume1/web/ui/assets/fonts/* $(frontenddir)/src/assets/fonts/
	@if [ -d "$(frontenddir)/src/scss/fonts/" ]; then mkdir -p "$(frontenddir)/src/scss/fonts/"; fi
	@rsync -hru 192.168.0.2:/volume1/web/ui/scss/fonts/* $(frontenddir)/src/scss/fonts/
	@touch $(frontenddir)/src/scss/fonts/fonts.scss

	@sed -i "s|http://localhost:4200|$(httpadr)|g" $(frontenddir)/src/environments/environment.ts
	@sed -i "s|production: false|production: true|g" $(frontenddir)/src/environments/environment.ts
	
	@cp $(frontenddir)/src/environments/environment.ts $(frontenddir)/src/environments/environment.docker.ts
	@cp $(frontenddir)/src/environments/environment.ts $(frontenddir)/src/environments/environment.prod.ts
	
	@echo "TIMEZONE=\"${TZ}\"" > $(storedir)/.env.local
	@echo "APP_SECRET=\"$(appsecret)\"" >> $(storedir)/.env.local
	@echo "INSTALL_URL=\"$(httpadr)/store\"" >> $(storedir)/.env.local
	@echo "ASSET_URL=\"$(httpadr)/assets\"" >> $(storedir)/.env.local
	@echo "UI_URL=\"$(httpadr)\"" >> $(storedir)/.env.local
	@echo "DATABASE_URL=\"mysql://symfony:symfony@db:3306/symfony\"" >> $(storedir)/.env.local
	@echo "CORE_INVITE_CODE=\"$(invitecode)\"" >> $(storedir)/.env.local
	@echo "# FITBIT_SECRET=\"CHANGEME\"" >> $(storedir)/.env.local
	@echo "# FITBIT_ID=\"CHANGEME\"" >> $(storedir)/.env.local
	@echo "# PATREON_CLIENT_ID=\"\"" >> $(storedir)/.env.local
	@echo "# PATREON_CLIENT_SECRET=\"\"" >> $(storedir)/.env.local
	@echo "# PATREON_CREATORS_ACCESS=\"\"" >> $(storedir)/.env.local
	@echo "# PATREON_CREATORS_REFRESH=\"\"" >> $(storedir)/.env.local
	@echo "# SYNOLOGY_CHAT_URL=\"\"" >> $(storedir)/.env.local
	@echo "# SYNOLOGY_CHATBOT=\"\"" >> $(storedir)/.env.local
	@echo "# SYNOLOGY_CHAT=\"\"" >> $(storedir)/.env.local
	@echo "# DISCORD_WH_PVP=\"\"" >> $(storedir)/.env.local
	@echo "# DISCORD_WH_PVE=\"\"" >> $(storedir)/.env.local
	@echo "# DISCORD_WH_STAR=\"\"" >> $(storedir)/.env.local
	@echo "# SITE_EMAIL_NAME=\"\"" >> $(storedir)/.env.local
	@echo "# SITE_EMAIL_ADDRESS=\"\"" >> $(storedir)/.env.local
	@echo "# SITE_EMAIL_NOREPLY=\"\"" >> $(storedir)/.env.local
	@echo "MAILER_URL=\"null://localhost\"" >> $(storedir)/.env.local

	# @docker exec -it apache composer dump-env docker

install:
	@if [ -d "$(frontenddir)" ]; then sudo rm -rf "$(frontenddir)"; fi
	git clone https://github.com/nxfifteen/nxcore_angular.git "$(frontenddir)"
	@cd "$(frontenddir)" && git checkout $(frontendbranch)

	@if [ -d "$(storedir)" ]; then sudo rm -rf "$(storedir)"; fi
	git clone https://github.com/nxfifteen/nxcore_store.git "$(storedir)"
	@cd "$(storedir)" && git checkout $(storebranch)

	@make configure

	@make build
	@make start
	@make migrate

uninstall:
	@make stop
	@docker volume rm core_angular-dist
	@docker volume rm core_cache
	@docker volume rm core_db
	@docker volume rm core_logs
	@docker volume rm core_vendor

build:
	@docker-compose -f docker-compose.yml build

update: update-ui update-store configure build restart migrate

update-ui:
	cd "$(frontenddir)" && git checkout $(frontendbranch) && git pull
	
update-store:
	cd "$(storedir)" && git checkout $(storebranch) && git pull
	@docker exec -it apache composer install
	@make migrate

info:
	@docker exec -it apache php bin/console --version
	@docker exec -it apache php --version

migration:
	@docker exec -it apache php -d memory_limit=1G bin/console doctrine:migrations:$(RUN_ARGS)

migrate:
	@docker exec -it apache php -d memory_limit=1G bin/console doctrine:migrations:migrate --no-interaction --all-or-nothing

config:
	@nano -w $(storedir)/.env.local

cron-auth-refresh:
	@docker exec -it apache php bin/console auth:refresh:fitbit

cron-rpg-challenge:
	@docker exec -it apache php bin/console cron:rpg:challenge:friends

cron-fetch-fitbit:
	@docker exec -it apache php bin/console queue:fetch:fitbit

cron-fetch-patreon:
	@docker exec -it apache php bin/console queue:fetch:patreon

cron-history-fitbit:
	@docker exec -it apache php bin/console history:download:fitbit

cron-populate-fitbit:
	@docker exec -it apache php bin/console queue:populate:fitbit
	