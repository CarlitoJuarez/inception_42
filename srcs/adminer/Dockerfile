FROM alpine:3.23.5


RUN apk add --no-cache \
  php84 \
  php84-session \
  php84-mysqli \
  curl

# RUN apk add --no-cache \
#   php84 \ # php runtime
#   php84-session \ # for login
#   php84-mysqli \ # driver for php using the mysqli extension using MySQLi API
#   curl # needed to download adminer

# commands run from now on inside ..
WORKDIR /var/www/html


# downloads adminer's php file and saves it under ..
RUN curl -fsSL https://www.adminer.org/latest.php -o adminer.php

COPY index.php /var/www/html/index.php

# just for documentation can be left out as we did in the rest
EXPOSE 8080

# runs php's built-in dev web server
# we use 0.0.0.0 -> listen on all network interfaces inside the container
# when use localhost instead Docker port mapping would not work properly
# -t --> webroot -> server adminer from here on port 8080
CMD ["php84", "-S", "0.0.0.0:8080", "-t", "/var/www/html"]
