all : run

build :
	@bash ./srcs/script.sh
	docker compose -f srcs/docker-compose.yml build

run : build
	docker compose -f srcs/docker-compose.yml up

fclean : down
	docker compose -f srcs/docker-compose.yml down --rmi all --volumes --remove-orphans
	sudo rm -rf $$HOME/data
down :
	docker compose -f srcs/docker-compose.yml down -v

logs :
	docker compose -f srcs/docker-compose.yml logs

ps :
	docker compose -f srcs/docker-compose.yml ps

re : down run