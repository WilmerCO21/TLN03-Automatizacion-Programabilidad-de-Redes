FROM frr:10.7.1-ssh

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        nginx \
        procps \
        curl \
    && rm -rf /var/lib/apt/lists/*

COPY start-web.sh /usr/local/bin/start-web.sh
COPY default.conf /etc/nginx/sites-available/default

RUN chmod 0755 /usr/local/bin/start-web.sh \
    && mkdir -p /usr/share/nginx/html

ENTRYPOINT ["/usr/local/bin/start-web.sh"]
