FROM alpine:3.20

RUN apk add --no-cache vsftpd

# RECEIVE THE ARGS

ARG UID=33
ARG GID=33

ENV HOME=/tmp

# create ftp USER (UID/GID aligned with www-data = 33 from php & nginx default)
#   aka fileownership for container-to-container consistency
# NOTE: for bind mounts 33 mismatches with 1000 from local host
#       as for bind mounts the host filesystem becomes the source of truth
#       for named mounts UID does not matter as UID = 33 --> matches with www-data which align with other containers

RUN addgroup -g $GID wpgroup && \
  adduser -u $UID -D -G wpgroup wpuser


# CREATES SYMLINK AT /proc/1/fd/1 which is STDOUT
# RM /var/log/vsftp.log if it exists
# FOR LOGGING VIA SYMLINK TO STDOUT
# so: /var/log/vsftp.log --> STDOUT
# STDOUT of DOCKER PID 1 not inside container

RUN mkdir -p /var/log && \
  ln -sf /proc/1/fd/1 /var/log/vsftpd.log

# copy config + entrypoint

COPY vsftpd.conf /etc/vsftpd/vsftpd.conf

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
