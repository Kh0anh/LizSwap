#!/bin/sh
# ============================================================
# LizSwap – Certbot Init Script
# ============================================================
# Chạy script này lần đầu để lấy SSL certificate từ Let's Encrypt.
# Sau đó Certbot container sẽ tự động renew.
#
# Sử dụng:
#   chmod +x infra/certbot/init-letsencrypt.sh
#   ./infra/certbot/init-letsencrypt.sh
# ============================================================

set -e

# Đọc biến từ .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

DOMAIN=${DOMAIN:-lizswap.xyz}
ADMIN_DOMAIN=${ADMIN_DOMAIN:-admin.lizswap.xyz}
EMAIL=${CERTBOT_EMAIL:-admin@lizswap.xyz}
DATA_PATH="./infra/certbot"

echo "### Creating dummy certificate for $DOMAIN and $ADMIN_DOMAIN ..."
mkdir -p "$DATA_PATH/conf/live/$DOMAIN"
docker compose run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:4096 -days 1 \
    -keyout '/etc/letsencrypt/live/$DOMAIN/privkey.pem' \
    -out '/etc/letsencrypt/live/$DOMAIN/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "### Starting nginx ..."
docker compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $DOMAIN ..."
docker compose run --rm --entrypoint "\
    rm -rf /etc/letsencrypt/live/$DOMAIN && \
    rm -rf /etc/letsencrypt/archive/$DOMAIN && \
    rm -rf /etc/letsencrypt/renewal/$DOMAIN.conf" certbot
echo

echo "### Requesting Let's Encrypt certificate for $DOMAIN and $ADMIN_DOMAIN ..."
docker compose run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN \
    -d $ADMIN_DOMAIN \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker compose exec nginx nginx -s reload
echo

echo "### Done! SSL certificates installed for $DOMAIN and $ADMIN_DOMAIN"
echo "### Now uncomment SSL lines in infra/nginx/conf.d/default.conf"
echo "### Then run: docker compose restart nginx"
