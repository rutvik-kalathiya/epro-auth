#!/bin/sh
# Required: OPENFGA_DATASTORE_URI (postgres://...) and OPENFGA_AUTHN_PRESHARED_KEYS (one or
# more comma-separated secrets; the app sends one as FGA_API_TOKEN). The API is never
# started without a key, because it would otherwise be open to anyone on the internet.
set -eu
: "${OPENFGA_DATASTORE_URI:?Set OPENFGA_DATASTORE_URI to the Postgres connection string}"
: "${OPENFGA_AUTHN_PRESHARED_KEYS:?Set OPENFGA_AUTHN_PRESHARED_KEYS so the API requires a key}"

openfga migrate --datastore-engine postgres --datastore-uri "$OPENFGA_DATASTORE_URI"

exec openfga run \
  --datastore-engine postgres \
  --datastore-uri "$OPENFGA_DATASTORE_URI" \
  --datastore-max-open-conns "${OPENFGA_DATASTORE_MAX_OPEN_CONNS:-10}" \
  --authn-method preshared \
  --authn-preshared-keys "$OPENFGA_AUTHN_PRESHARED_KEYS" \
  --http-addr "0.0.0.0:${PORT:-8080}" \
  --grpc-addr 127.0.0.1:8081 \
  --playground-enabled=false \
  --metrics-enabled=false
