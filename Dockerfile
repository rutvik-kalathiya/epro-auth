# OpenFGA for e:pro Portfolio, backed by Postgres. The container migrates the database schema on
# every start (a no-op when current), then serves the HTTP API on $PORT.
FROM alpine:3.22

ARG OPENFGA_VERSION=1.22.0
# From https://github.com/openfga/openfga/releases/download/v1.22.0/checksums.txt
ARG OPENFGA_SHA256=eaa86a22c7ece1e461467082447fdf943bd2aca03ed400e31d5c82953d85cf14

RUN apk add --no-cache ca-certificates \
 && apk add --no-cache --virtual .fetch curl \
 && curl -fsSL -o /tmp/openfga.tgz \
    "https://github.com/openfga/openfga/releases/download/v${OPENFGA_VERSION}/openfga_${OPENFGA_VERSION}_linux_amd64.tar.gz" \
 && echo "${OPENFGA_SHA256}  /tmp/openfga.tgz" | sha256sum -c - \
 && tar -xzf /tmp/openfga.tgz -C /usr/local/bin openfga \
 && rm /tmp/openfga.tgz \
 && apk del .fetch \
 && adduser -D -H openfga

# The executable bit is tracked in git, so a plain COPY keeps it.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
USER openfga
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
