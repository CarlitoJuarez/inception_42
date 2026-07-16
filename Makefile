NAME        := inception

SRC_DIR     := srcs
COMPOSE_YML := $(SRC_DIR)/docker-compose.yml
ENV_FILE    := $(SRC_DIR)/.env

include $(ENV_FILE)

DATA_DIR    := /home/$(LOGIN)/data
WP_DATA     := $(DATA_DIR)/wordpress
DB_DATA     := $(DATA_DIR)/mariadb

COMPOSE     := docker compose -f $(COMPOSE_YML) --env-file $(ENV_FILE)


all: up

dirs:
	mkdir -p $(WP_DATA)
	mkdir -p $(DB_DATA)

up: dirs
	$(COMPOSE) up -d --build

build: dirs
	$(COMPOSE) build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down

fclean:
	$(COMPOSE) down -v --rmi all		--remove-orphans
	sudo rm -rf $(WP_DATA)
	sudo rm -rf $(DB_DATA)

re: fclean all


.PHONY: all up build down stop start restart logs ps clean fclean re dirs

