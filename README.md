Enables nginx with SSL certificates pulled from AWS ACM to be used as a sidecar for other containers or `endpoints`.

# Environmental Variables
Enables use of environmental variables in nginx configuration. Upon start, will pull from environment `FQDN`, `ENDPOINT_NAME`, and `DOMAIN_NAME`, which construct the server_name. `ROOT_URL_PATH` needs to be set, and can be set as an empty string.

The nginx configuration generated will look like:

```server {
  listen       *:443 ssl;

  server_name  $ENV{"FQDN"} $ENV{"SERVER_NAME"}

  ssl on;
  ssl_certificate           /etc/ssl/certs/$ENV{"FQDN"}.crt;
  ssl_certificate_key       /etc/ssl/private/$ENV{"FQDN"}.key;
  ssl_session_cache         shared:SSL:10m;
  ssl_session_timeout       5m;
  ssl_protocols             TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers               ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS;
  ssl_prefer_server_ciphers on;

  index  index.html;

  access_log            /var/log/nginx/ssl-$ENV{"FQDN"}.access.log combined;
  error_log             /var/log/nginx/ssl-$ENV{"FQDN"}.error.log;

  underscores_in_headers on;


  location / {
    proxy_pass            http://$ENV{"HTTP_PROXY_PATH"};
    proxy_read_timeout    90s;
    proxy_connect_timeout 90s;
    proxy_send_timeout    90s;
    proxy_redirect        http:// $scheme://;
    proxy_set_header      Host $host;
    proxy_set_header      X-Real-IP $remote_addr;
    proxy_set_header      X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header      Proxy "";
  }
}

server {
  listen *:80;

  server_name           $ENV{"FQDN"} $ENV{"SERVER_NAME"}


  index  index.html index.htm index.php;
  access_log            /var/log/nginx/ssl-$ENV{"FQDN"}.access.log combined;
  error_log             /var/log/nginx/ssl-$ENV{"FQDN"}.error.log;

  location / {
    index     index.html index.htm index.php;
    rewrite ^ https://$server_name$request_uri? permanent;
  }
}
```

# Retrieval of certificate
When the container starts, the ACM certificate named with the environmental variable `FQDN` will be pulled. The pull depends on the container having access to a secret named `FQDN` that has been used to decrypt the ACM certificate.
