#!/bin/env bash
set -e

#
# Validation
#

if [[ -z "$FQDN" ]]; then
  echo "FQDN environmental variable is required"
  exit 1
fi
if [[ -z "$HTTP_PROXY_URL" ]]; then
  echo "HTTP_PROXY_URL environmental variable is required"
  exit 1
fi

# SERVER_NAME should be optional but needs to be a string, even if empty.
if [[ -z "$SERVER_NAME" ]]; then
  SERVER_NAME=""
  export SERVER_NAME
fi

if [ -n "$DEBUG" ]; then
    echo "Environment variables:"
    env
    echo ""
fi


#
# Certificates
#

echo "Pulling certificate for ${FQDN}"

# Get existing certificate ARN
cert_arn=$(eval "aws acm list-certificates --query 'CertificateSummaryList[?DomainName==\`${FQDN}\`]'.[CertificateArn] --output text")
if [[ -z "$cert_arn" ]]; then
  echo "Unable to find an appropriate certificate for ${FQDN}"
  exit 1
fi

# Generate a new passphrase for this container
cert_pass_phrase=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()-=_+;:,./<>?' </dev/urandom | head -c 128)

# Save passphrase for nginx
touch /etc/ssl/passphrases
chmod 600 /etc/ssl/passphrases
echo $cert_pass_phrase > /etc/ssl/passphrases

# Get SSL Certificate and Key from AWS
ssl_cert_response=$(aws acm export-certificate --certificate-arn $cert_arn --passphrase $cert_pass_phrase)
ssl_cert=$(echo ${ssl_cert_response} | jq -r '"\(.Certificate)\(.CertificateChain)"')
ssl_key=$(echo ${ssl_cert_response} | jq -r '"\(.PrivateKey)"')

# Save the Certificate Chain
if [ ! -f "/etc/ssl/certs/${FQDN}.crt" ]; then
  mkdir -p /etc/ssl/certs/
  echo "Creating key file for certificate key"
  touch /etc/ssl/certs/${FQDN}.crt
fi
echo "Copying ACM cert to file /etc/ssl/certs/${FQDN}.crt"
echo "$ssl_cert" > "/etc/ssl/certs/${FQDN}.crt"

# Save the Private Key
if [ ! -f "/etc/ssl/private/${FQDN}.key" ]; then
  mkdir -p "/etc/ssl/private/"
  echo "Creating key file for certificate key"
  touch "/etc/ssl/private/${FQDN}.key"
fi
echo "Copying ACM key to file /etc/ssl/private/${FQDN}.key"
echo "$ssl_key" > "/etc/ssl/private/${FQDN}.key"


#
# Install a Private CA
#

if [[ -v $PRIVATE_CA_NAME ]]; then
  if [[ -v $PRIVATE_CA_URL ]]; then
      echo "PRIVATE_CA_URL is not set but PRIVATE_CA_NAME is"
      exit 1
  fi
  curl -s -o /usr/local/share/ca-certificates/${PRIVATE_CA_NAME}.crt ${PRIVATE_CA_URL} && \
    chmod 644 /usr/local/share/ca-certificates/${PRIVATE_CA_NAME}.crt && \
    update-ca-certificates
fi


#
# NGINX
#


# Replace variables $ENV{<environment varname>}
function ReplaceEnvironmentVariable() {
    grep -rl "\$ENV{\"$1\"}" $3|xargs -r \
        sed -i "s|\\\$ENV{\"$1\"}|$2|g"
}


# Restore "template" configuration for modification below
cp /default.conf /etc/nginx/conf.d/default.conf

# Replace all variables
for _curVar in `env | awk -F = '{print $1}'`;do
    # awk has split them by the equals sign
    # Pass the name and value to our function
    ReplaceEnvironmentVariable "${_curVar}" "${!_curVar}" /etc/nginx/conf.d/*
done

function certificate_expiration_check() {
  expires=$(openssl s_client -servername $FQDN -connect 127.0.0.1:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter)
  expires_date=${expires:9}
  echo "Certificate expires on ${expires_date}"
}

sleep 4 && certificate_expiration_check &

# Run nginx
echo 'Starting nginx'
nginx -g "daemon off;"
