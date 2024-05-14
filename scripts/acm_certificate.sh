#!/usr/bin/env bash
set -e

echo "Pulling certificate for ${SHORT_FQDN}"

# Get existing certificate ARN
cert_arn=$(eval "aws acm list-certificates --query 'CertificateSummaryList[?DomainName==\`${SHORT_FQDN}\`]'.[CertificateArn] --output text")
if [[ -z "$cert_arn" ]]; then
  echo "Unable to find an appropriate certificate for ${SHORT_FQDN}"
  exit 1
fi

# Generate a new passphrase for this container
cert_pass_phrase=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()-=_+;:,./<>?' </dev/urandom | head -c 128)

# Save passphrase for nginx
touch /etc/ssl/passphrases
chmod 600 /etc/ssl/passphrases
echo $cert_pass_phrase >/etc/ssl/passphrases

# Get SSL Certificate and Key from AWS
ssl_cert_response=$(aws acm export-certificate --certificate-arn $cert_arn --passphrase $cert_pass_phrase)
ssl_cert=$(echo ${ssl_cert_response} | jq -r '"\(.Certificate)\(.CertificateChain)"')
ssl_key=$(echo ${ssl_cert_response} | jq -r '"\(.PrivateKey)"')

# Save the Certificate Chain
if [ ! -f "/etc/ssl/certs/${KEYFILE}.crt" ]; then
  mkdir -p /etc/ssl/certs/
  echo "Creating key file for certificate key"
  touch /etc/ssl/certs/${KEYFILE}.crt
fi
echo "Copying ACM cert to file /etc/ssl/certs/${KEYFILE}.crt"
echo "$ssl_cert" >"/etc/ssl/certs/${KEYFILE}.crt"

# Save the Private Key
if [ ! -f "/etc/ssl/private/${KEYFILE}.key" ]; then
  mkdir -p "/etc/ssl/private/"
  echo "Creating key file for certificate key"
  touch "/etc/ssl/private/${KEYFILE}.key"
fi
echo "Copying ACM key to file /etc/ssl/private/${KEYFILE}.key"
echo "$ssl_key" >"/etc/ssl/private/${KEYFILE}.key"

#
# Install a Private CA
#

if [[ -v $PRIVATE_CA_NAME ]]; then
  if [[ -v $PRIVATE_CA_URL ]]; then
    echo "PRIVATE_CA_URL is not set but PRIVATE_CA_NAME is"
    exit 1
  fi
  curl -s -o /usr/local/share/ca-certificates/${PRIVATE_CA_NAME}.crt ${PRIVATE_CA_URL} &&
    chmod 644 /usr/local/share/ca-certificates/${PRIVATE_CA_NAME}.crt &&
    update-ca-certificates
fi
