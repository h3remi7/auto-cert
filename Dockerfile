FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/certbot/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        python3 \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/certbot \
    && /opt/certbot/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/certbot/bin/pip install --no-cache-dir \
        certbot==5.5.0 \
        certbot-dns-cloudflare==5.5.0

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

VOLUME ["/etc/letsencrypt", "/var/lib/letsencrypt", "/logs"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
