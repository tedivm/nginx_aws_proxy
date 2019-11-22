#!/bin/env bash

####################
# Trust Private CA #
####################


echo "Pulling certificate for ${FQDN}"

## SSL CERTIFICATES
if [[ -v $FQDN ]]; then
    echo "FQDN is not set"
    exit 1
elif [[ -z "$FQDN" ]]; then
    echo "FQDN is set to the empty string"
    exit 1
fi

secret_re='.*"SecretString": "(.*)",.*'
cert_arn=$(eval "aws acm list-certificates --query 'CertificateSummaryList[?DomainName==\`${FQDN}\`]'.[CertificateArn] --output text")

if [[ $(aws secretsmanager get-secret-value --secret-id ${FQDN}) =~ $secret_re ]]; then
  cert_pass_phrase=${BASH_REMATCH[1]}
else
  echo "No cert pass phrase by the domain ${FQDN}"
  exit 1
fi

# SSL Certificate
if [ ! -d "/etc/ssl/certs/" ]; then
  mkdir "/etc/ssl/certs/"
  if [ ! -f "/etc/ssl/certs/${FQDN}.crt"]; then
    echo "Creating key file for certificate key"
    touch "/etc/ssl/certs/${FQDN}.crt"
  fi
fi

ssl_cert=$(aws acm export-certificate --certificate-arn $cert_arn --passphrase $cert_pass_phrase | jq -r '"\(.Certificate)\(.CertificateChain)"')
if [[ $ssl_cert!="$(cat /etc/ssl/certs/${FQDN}.crt)" ]]; then
  echo "Copying ACM cert to file /etc/ssl/certs/${FQDN}.crt"
  echo "$ssl_cert" > "/etc/ssl/certs/${FQDN}.crt"
  restart_nginx="true"
else
  echo "Certificate value has not changed, not updating."
fi

# SSL Key
if [ ! -d "/etc/ssl/private/" ]; then
  mkdir "/etc/ssl/private/"
  if [ ! -f "/etc/ssl/private/${FQDN}.key"]; then
    echo "Creating key file for certificate key"
    touch "/etc/ssl/private/${FQDN}.key"
  fi
fi
ssl_key=$(aws acm export-certificate --certificate-arn $cert_arn --passphrase $cert_pass_phrase | jq -r '"\(.PrivateKey)"')
if [[ $ssl_key!="$(cat /etc/ssl/private/${FQDN}.key)" ]]; then
  echo "Copying ACM key to file /etc/ssl/private/${FQDN}.key"
  echo "$ssl_key" > "/etc/ssl/private/${FQDN}.key"
  restart_nginx="true"
else
  echo "Key value has not changed, not updating."
fi

####################
# Trust Private CA #
####################

if [[ -v $PRIVATE_CA_NAME ]]; then
  curl -s -o /usr/local/share/ca-certificates/${PRIVATE_CA_NAME}.crt ${PRIVATE_CA_URL} && \
    chmod 644 /usr/local/share/ca-certificates/${PRIVATE_CA_NAME}.crt && \
    update-ca-certificates
fi


###########
### NGINX #
###########

# Restore original default config if no config has been provided
if [[ ! "$(ls -A /etc/nginx/conf.d)" ]]; then
    cp -a /etc/nginx/.conf.d.orig/. /etc/nginx/conf.d 2>/dev/null
fi

# Replace variables $ENV{<environment varname>}
function ReplaceEnvironmentVariable() {
    grep -rl "\$ENV{\"$1\"}" $3|xargs -r \
        sed -i "s|\\\$ENV{\"$1\"}|$2|g"
}

if [ -n "$DEBUG" ]; then
    echo "Environment variables:"
    env
    echo "..."
fi

if [ -z "$" ]; then
    export SENTRY_AUTH_STRING=""
fi

# Replace all variables
for _curVar in `env | awk -F = '{print $1}'`;do
    # awk has split them by the equals sign
    # Pass the name and value to our function
    ReplaceEnvironmentVariable ${_curVar} ${!_curVar} /etc/nginx/conf.d/*
done

# Run nginx
echo $cert_pass_phrase | service nginx start

if [ $restart_nginx=="true" ]; then
  echo "Restarting nginx per certificate change"
  service nginx stop
  echo $cert_pass_phrase | service nginx start
fi
