FROM debian:bookworm

RUN apt update && apt install -y redis-server

CMD ["redis-server", "--protected-mode", "no"]

