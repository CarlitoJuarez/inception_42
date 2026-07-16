FROM alpine:3.23.5


RUN apk add --no-cache nginx openssl

RUN mkdir -p /etc/nginx/ssl /run/nginx

# self signing certificate:
# -x509 skip CSR ( certificate signing request )
# -nodes -> no-DES encryption --> no password for priv key -> non-interactively
# -newkey rsa:2048 --> generates both: new private key + certificate; 2048 --> minimum for modern systems.
# subj: certificate identity --> non-interactively
# CN: Common Name ( i.e. domain )
# SAN: Subject Alternative Names --> use SAN for modern browsers
RUN openssl req -x509 -nodes -days 90 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=AT/ST=Vienna/L=Vienna/O=42/OU=Inception/CN=cjuarez.42.fr" \
    -addext "subjectAltName=DNS:cjuarez.42.fr,DNS:www.cjuarez.42.fr"


RUN rm -f /etc/nginx/conf.d/default.conf /etc/nginx/http.d/default.conf
COPY default.conf /etc/nginx/http.d/default.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
