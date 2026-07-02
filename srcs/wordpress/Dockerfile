FROM alpine:3.21

# use this dir as default for processes / services which need home dir
ENV HOME=/tmp

# --no-cache
#   --> combines update + add command
#   --> fetch from internet --> do not use cached
#   --> not stored to disk; for minimal setup
# - php83-fpm
#   --> FastCGI Package Manager
RUN apk add --no-cache su-exec \
  curl tar bash mysql-client ca-certificates \
  php83 php83-fpm php83-cli php83-mysqli php83-phar \
  php83-mbstring php83-iconv php83-curl php83-json \
  php83-dom php83-xml php83-openssl php83-zip php83-gd

RUN mkdir -p /var/log/php83 \
  && touch /var/log/php83/error.log \
  && chown -R 33:33 /var/log/php83

### NOTE: PROBABLY NOT NEEDED ?! 
# RUN update-ca-certificates

# install wp-cli
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  && chmod +x /usr/local/bin/wp

# cd + create dir
WORKDIR /var/www/html


COPY www.conf /etc/php83/php-fpm.d/www.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# not needed actually
EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm83", "-F"]
