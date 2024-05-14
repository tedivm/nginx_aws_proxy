#!/usr/bin/env bash
set -e

if [ ! -f "/etc/ssl/certs/${KEYFILE}.crt" ]; then
  echo "Creating self signed certificate for ${SHORT_FQDN}"
  touch /etc/ssl/passphrases
  openssl req -newkey rsa:4096 \
    -x509 \
    -sha256 \
    -days 365 \
    -nodes \
    -out "/etc/ssl/certs/${KEYFILE}.crt" \
    -keyout "/etc/ssl/private/${KEYFILE}.key" \
    -subj "/C=NN/ST=Lunknown/L=Lunknown/O=None/OU=None/CN=${SHORT_FQDN}"
else
  echo "Certificate already exists."
fi
