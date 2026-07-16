FROM alpine:3.23.5

RUN apk add --no-cache redis

CMD ["redis-server", "--protected-mode", "no", "--bind", "0.0.0.0"]
