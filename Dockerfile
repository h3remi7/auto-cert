FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/certbot/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        openssl \
        python3 \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Latest releases available at https://github.com/aptible/supercronic/releases
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.45/supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=e894b193bea75a5ee644e700c59e30eedc804cf7 \
    SUPERCRONIC=supercronic-linux-amd64

RUN curl -fsSLO "$SUPERCRONIC_URL" \
    && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
    && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

RUN python3 -m venv /opt/certbot \
    && /opt/certbot/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/certbot/bin/pip install --no-cache-dir \
        certbot==5.5.0 \
        certbot-dns-cloudflare==5.5.0

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY run-cert-once.sh /usr/local/bin/run-cert-once.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/run-cert-once.sh \
    && mkdir -p /data/cron /logs

VOLUME ["/etc/letsencrypt", "/var/lib/letsencrypt", "/logs"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
