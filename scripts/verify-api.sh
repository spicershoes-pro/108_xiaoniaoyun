#!/usr/bin/env bash
# ?????? API ????????Docker ??????????????????????? MySQL ??????
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NET="108_xiaoniaoyun-dev-internal"
DB_CONTAINER="108_xiaoniaoyun-db-dev"
PHP_CONTAINER="xny-php-verify"

echo "==> ????????????"
docker start "$DB_CONTAINER" 2>/dev/null || true
for i in $(seq 1 30); do
  docker exec "$DB_CONTAINER" mysqladmin ping -h localhost -u root -pXiaoNiaoRoot2026 --silent 2>/dev/null && break
  sleep 2
done

USERS=$(docker exec "$DB_CONTAINER" mysql -u root -pXiaoNiaoRoot2026 -N -e "SELECT COUNT(*) FROM xiaoniao.users" 2>/dev/null || echo 0)
if [ "${USERS:-0}" = "0" ]; then
  echo "==> ???? schema + seed"
  docker exec "$DB_CONTAINER" mysql -u root -pXiaoNiaoRoot2026 -e "CREATE DATABASE IF NOT EXISTS xiaoniao;"
  docker exec -i "$DB_CONTAINER" mysql -u root -pXiaoNiaoRoot2026 < "$ROOT/database/schema.sql"
  docker exec -i "$DB_CONTAINER" mysql -u root -pXiaoNiaoRoot2026 xiaoniao < "$ROOT/database/seed.sql"
fi
echo "    users=$USERS"

docker rm -f "$PHP_CONTAINER" 2>/dev/null || true
echo "==> ???? PHP ???????"
docker run -d --name "$PHP_CONTAINER" --network "$NET" \
  -v "$ROOT/backend:/var/www/html" \
  -v "$ROOT/scripts:/scripts:ro" \
  -e APP_ENV=development \
  -e DB_HOST="$DB_CONTAINER" \
  -e DB_PORT=3306 \
  -e DB_NAME=xiaoniao \
  -e DB_USER=root \
  -e DB_PASS=XiaoNiaoRoot2026 \
  -e JWT_SECRET=xiaoniao-secret-change-in-production-2026 \
  -e SMS_PROVIDER=mock \
  php:8.2-cli \
  sh -c "docker-php-ext-install pdo_mysql >/dev/null 2>&1 && exec php -S 0.0.0.0:8080 -t /var/www/html/public"

for i in $(seq 1 20); do
  docker exec "$PHP_CONTAINER" php -r "@file_get_contents('http://127.0.0.1:8080/api/banners');" 2>/dev/null | grep -q '"code":0' && break
  sleep 2
done

echo "==> API ????"
docker exec "$PHP_CONTAINER" php /scripts/verify-api-inner.php

docker rm -f "$PHP_CONTAINER" 2>/dev/null || true
echo "==> ???"
