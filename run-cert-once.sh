#!/bin/sh
set -eu

: "${DOMAIN:?DOMAIN is required, for example: example.com}"
: "${EMAIL:=admin@${DOMAIN}}"
: "${CLOUDFLARE_PROPAGATION_SECONDS:=60}"
: "${STAGING:=false}"
: "${RSA_KEY_SIZE:=4096}"
: "${RENEW_BEFORE_DAYS:=30}"
: "${CERT_OUTPUT_DIR:=/certs}"
: "${LOG_DIR:=/logs}"
: "${CERTBOT_LOG_DIR:=${LOG_DIR}/letsencrypt}"
: "${CREDENTIALS_FILE:=/run/secrets/cloudflare.ini}"

if [ "$DOMAIN" = "domain.com" ]; then
    echo "DOMAIN must be changed from the placeholder domain.com" >&2
    exit 1
fi

if [ -n "${CERTBOT_DOMAINS:-}" ]; then
    DOMAINS="$CERTBOT_DOMAINS"
else
    DOMAINS="*.${DOMAIN},${DOMAIN}"
fi

domain_args() {
    old_ifs="$IFS"
    IFS=","
    for domain in $DOMAINS; do
        if [ -n "$domain" ]; then
            printf -- ' -d %s' "$domain"
        fi
    done
    IFS="$old_ifs"
}

cert_name="${CERT_NAME:-$DOMAIN}"
staging_args=""
if [ "$STAGING" = "true" ]; then
    staging_args="--staging"
fi

issue_cert() {
    echo "No existing certificate found for ${cert_name}; requesting ${DOMAINS}"
    # shellcheck disable=SC2046
    certbot certonly \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --cert-name "$cert_name" \
        --key-type rsa \
        --rsa-key-size "$RSA_KEY_SIZE" \
        --dns-cloudflare \
        --dns-cloudflare-credentials "$CREDENTIALS_FILE" \
        --dns-cloudflare-propagation-seconds "$CLOUDFLARE_PROPAGATION_SECONDS" \
        --logs-dir "$CERTBOT_LOG_DIR" \
        $staging_args \
        ${CERTBOT_EXTRA_ARGS:-} \
        $(domain_args)
}

renew_certs() {
    echo "Checking certificate renewal status"
    force_args=""
    if should_force_renew; then
        force_args="--force-renewal --cert-name ${cert_name}"
    fi

    # shellcheck disable=SC2086
    certbot renew \
        --non-interactive \
        --dns-cloudflare \
        --dns-cloudflare-credentials "$CREDENTIALS_FILE" \
        --dns-cloudflare-propagation-seconds "$CLOUDFLARE_PROPAGATION_SECONDS" \
        --logs-dir "$CERTBOT_LOG_DIR" \
        $force_args \
        $staging_args \
        ${CERTBOT_RENEW_EXTRA_ARGS:-}
}

should_force_renew() {
    cert_file="/etc/letsencrypt/live/${cert_name}/fullchain.pem"

    if [ ! -f "$cert_file" ]; then
        return 1
    fi

    expires_at="$(openssl x509 -enddate -noout -in "$cert_file" | sed 's/^notAfter=//')"
    expires_epoch="$(date -u -d "$expires_at" +%s)"
    now_epoch="$(date -u +%s)"
    seconds_left=$((expires_epoch - now_epoch))
    days_left=$((seconds_left / 86400))

    echo "Certificate ${cert_name} expires in ${days_left} day(s); renewal threshold is ${RENEW_BEFORE_DAYS} day(s)"

    if [ "$seconds_left" -le 0 ]; then
        echo "Certificate ${cert_name} is expired; forcing renewal"
        return 0
    fi

    if [ "$days_left" -le "$RENEW_BEFORE_DAYS" ]; then
        echo "Certificate ${cert_name} is within renewal threshold; forcing renewal"
        return 0
    fi

    return 1
}

sync_cert_files() {
    live_dir="/etc/letsencrypt/live/${cert_name}"
    output_dir="${CERT_OUTPUT_DIR}/${cert_name}"

    if [ ! -f "${live_dir}/fullchain.pem" ] || [ ! -f "${live_dir}/privkey.pem" ]; then
        return
    fi

    mkdir -p "$output_dir"
    chmod 755 "$CERT_OUTPUT_DIR" "$output_dir"
    cp "${live_dir}/fullchain.pem" "${output_dir}/fullchain.pem"
    cp "${live_dir}/privkey.pem" "${output_dir}/privkey.pem"
    cp "${live_dir}/chain.pem" "${output_dir}/chain.pem"
    cp "${live_dir}/cert.pem" "${output_dir}/cert.pem"
    chmod 600 "${output_dir}/privkey.pem"
    chmod 644 "${output_dir}/fullchain.pem" "${output_dir}/chain.pem" "${output_dir}/cert.pem"
}

if [ ! -f "/etc/letsencrypt/live/${cert_name}/fullchain.pem" ]; then
    issue_cert
else
    renew_certs
fi

sync_cert_files
