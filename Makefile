.PHONY: build bundle setup bash bash_test test rspec rubocop down clean ps

APP_NAME=engine

build:
	docker-compose build

bundle:
	docker-compose run --rm $(APP_NAME) bundle install

setup: build bundle
	docker-compose run --rm $(APP_NAME) bin/rails app:db:prepare
	docker-compose run --rm -e RAILS_ENV=test $(APP_NAME) bin/rails app:db:prepare

bash:
	docker-compose run --rm -e RACK_ENV=development $(APP_NAME) bash

bash_test:
	docker-compose run --rm -e RACK_ENV=test $(APP_NAME) bash

test rspec:
	docker-compose run --rm -e RAILS_ENV=test $(APP_NAME) bundle exec rspec

rubocop:
	docker-compose run --rm $(APP_NAME) bundle exec rubocop

down:
	docker-compose down

clean:
	docker-compose rm -f

ps:
	docker-compose ps
