FROM frr:10.7.1-ssh

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        keepalived \
        iptables \
        nftables \
    && rm -rf /var/lib/apt/lists/*

COPY start-cpe.sh check-wan.sh /usr/local/bin/

RUN chmod 0755 /usr/local/bin/start-cpe.sh /usr/local/bin/check-wan.sh \
    && mkdir -p /run/keepalived

ENTRYPOINT ["/usr/local/bin/start-cpe.sh"]
