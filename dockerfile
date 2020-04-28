FROM nginx

# All this just for the awscli
RUN apt-get update && \
    apt-get install -y \
        python3 \
        python3-pip \
        python3-setuptools \
        curl \
        jq \
    && python3 -m pip --no-cache-dir install --upgrade pip \
    && python3 -m pip --no-cache-dir install --upgrade awscli \
    && apt-get clean


# Copy our launch and configuration files
COPY launch_proxy.sh /opt/launch_proxy.sh
COPY conf/default.conf /default.conf

# Remove built in default.conf- it gets replaced by launch_proxy.sh
RUN rm -f /etc/nginx/conf.d/default.conf

# Upstream nginx uses CMD instead of ENTRYPOINT so we do too.
CMD ["bash", "/opt/launch_proxy.sh"]
