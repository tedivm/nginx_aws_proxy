# NGINX AWS Proxy

This is an extremely thin wrapper around the official NGINX containers that configures nginx for SSL Termination.

The primary use case for this container is to run behind a load balancer where the load balancer itself is handling SSL termination. In that scenario this container enables SSL between the load balancer and whatever containers it is running as a sidecar to.

## Signing Options

### Self Signed

This image can create a fully self signed certificate when it launches. This is ideal for services that are behind a Load Balancer that is handling SSL Termination. The Load Balancer is what gets exposed to the user, and this container (with its self signed certificate) enables encryption between the load balancer and the service.

Note that self signed certificates do not allow for Authentication, just Encryption. Load Balancers do not check certificate authentication though, and instead rely on signed packets in the AWS network to ensure that traffic goes to the appropriate location.

### AWS Private CA

For systems behind an AWS Load Balancer *there is no additional benefit fo the Private CA*. AWS Load Balancers do not authenticate certificates.

However, if you want SSL Termination directly on the ECS task itself you'll need to use a AWS Private CA. The Private CA allows you to download the private key, which normal ACM does not allow. This container will search for and download the certificate that matches the FQDN passed to it.


## Environmental Variables

* `FQDN` - the fully qualified domain to use.
* `HTTP_PROXY_URL` - the URL you're pointing the proxy at. In general this is another container in the same ECS task.

That's it! From there the container downloads the certificate from the AWS ACM Private CA, configures the private key, certificate chain, and passphrase files, before launching nginx.

There are some additional environmental variables you can set-

* `PRIVATE_CA_NAME` and `PRIVATE_CA_URL` allow you to install a private CA on the server, which is useful if you're trying to proxy to another server running HTTPS. Ultimately though you should probably bake in the certificates another image if you go this route.

* `DEBUG` - when set to "true" logging will be turned up and environmental variables will be printed on launch.


## Changing the nginx default configuration

The `default.conf` we use is different than the one shipped by nginx in two ways-

* It includes all the SSL and Proxy settings needed to do its job.
* It uses embedded tokens that get replaced on launch.

So if you want to change this file you should start with the one in this project (in conf/default.conf) and when you put it into the container you should place it at `/default.conf`- the launch script will find it, inject the appropriate settings in, and then move it to `/etc/nginx/conf.d/default.conf` for you. If you try to alter `/etc/nginx/conf.d/default.conf` directly it will get overwritten.
