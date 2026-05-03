#!/bin/sh
set -eu

: "${DOMAIN:?DOMAIN is required, for example: example.com}"
: "${EMAIL:=admin@${DOMAIN}}"
: "${CLOUDFLARE_PROPAGATION_SECONDS:=60}"
: "${RUN_ONCE:=false}"
: "${STAGING:=false}"
: "${RSA_KEY_SIZE:=4096}"
: "${CERT_OUTPUT_DIR:=/certs}"
: "${LOG_DIR:=/logs}"
: "${CERTBOT_LOG_DIR:=${LOG_DIR}/letsencrypt}"
: "${CERT_CRON:=17 3 * * *}"
: "${CRON_FILE:=/data/cron/crontab}"
: "${CREDENTIALS_FILE:=/run/secrets/cloudflare.ini}"

mkdir -p "$LOG_DIR" "$CERTBOT_LOG_DIR" "$(dirname "$CRON_FILE")"
exec >> "${LOG_DIR}/auto-cert.log" 2>&1

if [ "${1:-}" = "run-once" ]; then
    RUN_ONCE=true
    shift
fi

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && { [ -z "${CLOUDFLARE_API_KEY:-}" ] || [ -z "${CLOUDFLARE_EMAIL:-}" ]; }; then
    echo "Set CLOUDFLARE_API_TOKEN, or set both CLOUDFLARE_EMAIL and CLOUDFLARE_API_KEY" >&2
    exit 1
fi

mkdir -p "$(dirname "$CREDENTIALS_FILE")"
umask 077
if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    printf 'dns_cloudflare_api_token = %s\n' "$CLOUDFLARE_API_TOKEN" > "$CREDENTIALS_FILE"
else
    {
        printf 'dns_cloudflare_email = %s\n' "$CLOUDFLARE_EMAIL"
        printf 'dns_cloudflare_api_key = %s\n' "$CLOUDFLARE_API_KEY"
    } > "$CREDENTIALS_FILE"
fi

if [ "$RUN_ONCE" = "true" ]; then
    echo "Running one certificate check"
    /usr/local/bin/run-cert-once.sh "$@"
    exit 0
fi

printf '%s %s\n' "$CERT_CRON" "/usr/local/bin/run-cert-once.sh" > "$CRON_FILE"
echo "Starting certificate cron: ${CERT_CRON} /usr/local/bin/run-cert-once.sh"
exec supercronic -inotify "$CRON_FILE"
