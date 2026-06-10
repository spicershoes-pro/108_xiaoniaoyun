#!/usr/bin/env bash
# ??????????????MySQL(Docker) + API + Vite??3
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$ROOT/deploy/devices.dev.env" ]] && source "$ROOT/deploy/devices.dev.env"
NET="108_xiaoniaoyun-dev-internal"
DB="108_xiaoniaoyun-db-dev"
API="xny-api-dev"
API_PORT="${XNY_API_PORT:-18080}"
DB_HOST_PORT="${XNY_DB_PORT:-3308}"
API_PID_FILE="$ROOT/.logs/api.pid"

cmd="${1:-start}"

stop_all() {
  docker rm -f "$API" 2>/dev/null || true
  if [ -f "$API_PID_FILE" ]; then
    kill "$(cat "$API_PID_FILE")" 2>/dev/null || true
    rm -f "$API_PID_FILE"
  fi
  pkill -f "php -S 0.0.0.0:${API_PORT}" 2>/dev/null || true
  pkill -f "vite --port 5173" 2>/dev/null || true
  pkill -f "vite --port 5174" 2>/dev/null || true
  pkill -f "vite --port 5175" 2>/dev/null || true
}

start_db() {
  cd "$ROOT"
  docker compose up -d db
  for i in $(seq 1 30); do
    docker exec "$DB" mysqladmin ping -h localhost -u root -pXiaoNiaoRoot2026 --silent 2>/dev/null && return 0
    sleep 2
  done
  echo "MySQL not ready" >&2
  exit 1
}

ensure_data() {
  local cnt
  cnt=$(docker exec "$DB" mysql -u root -pXiaoNiaoRoot2026 -N -e "SELECT COUNT(*) FROM xiaoniao.users" 2>/dev/null || echo 0)
  if [ "${cnt:-0}" = "0" ]; then
    echo "==> import schema + seed"
    docker exec "$DB" mysql -u root -pXiaoNiaoRoot2026 -e "CREATE DATABASE IF NOT EXISTS xiaoniao;"
    docker exec -i "$DB" mysql -u root -pXiaoNiaoRoot2026 < "$ROOT/database/schema.sql"
    docker exec -i "$DB" mysql -u root -pXiaoNiaoRoot2026 xiaoniao < "$ROOT/database/seed.sql"
  fi
}

api_health_ok() {
  curl -sf "http://127.0.0.1:${API_PORT}/api/banners" 2>/dev/null | grep -q '"code":0' && return 0
  docker exec "$API" php -r "@file_get_contents('http://127.0.0.1:8080/api/banners');" 2>/dev/null | grep -q '"code":0'
}

start_api_host() {
  mkdir -p "$ROOT/.logs"
  if ! mysql -h127.0.0.1 -P"$DB_HOST_PORT" -uroot -pXiaoNiaoRoot2026 -e "SELECT 1" &>/dev/null; then
    return 1
  fi
  echo "    mode: host php (DB 127.0.0.1:${DB_HOST_PORT})"
  (
    cd "$ROOT/backend/public"
    export APP_ENV=development
    export DB_HOST=127.0.0.1
    export DB_PORT="$DB_HOST_PORT"
    export DB_NAME=xiaoniao
    export DB_USER=root
    export DB_PASS=XiaoNiaoRoot2026
    export JWT_SECRET=xiaoniao-secret-change-in-production-2026
    export SMS_PROVIDER=mock
    exec php -S "0.0.0.0:${API_PORT}" -t .
  ) >>"$ROOT/.logs/api.log" 2>&1 &
  echo $! >"$API_PID_FILE"
  for i in $(seq 1 15); do
    api_health_ok && return 0
    sleep 1
  done
  return 1
}

start_api_docker() {
  docker rm -f "$API" 2>/dev/null || true
  echo "    mode: docker php (network ${NET})"
  docker run -d --name "$API" --network "$NET" \
    -p "127.0.0.1:${API_PORT}:8080" \
    -v "$ROOT/backend:/var/www/html" \
    -e APP_ENV=development \
    -e DB_HOST="$DB" \
    -e DB_PORT=3306 \
    -e DB_NAME=xiaoniao \
    -e DB_USER=root \
    -e DB_PASS=XiaoNiaoRoot2026 \
    -e JWT_SECRET=xiaoniao-secret-change-in-production-2026 \
    -e SMS_PROVIDER=mock \
    php:8.2-cli \
    sh -c "docker-php-ext-install pdo_mysql >/dev/null 2>&1 && exec php -S 0.0.0.0:8080 -t /var/www/html/public"
  for i in $(seq 1 30); do
    api_health_ok && return 0
    sleep 2
  done
  return 1
}

start_api() {
  if start_api_host; then
    return 0
  fi
  if start_api_docker; then
    if ! curl -sf "http://127.0.0.1:${API_PORT}/api/banners" 2>/dev/null | grep -q '"code":0'; then
      echo "    ???: ?????? API ?????????????? :${API_PORT} ?????Vite ???????????????? Docker ??????" >&2
    fi
    return 0
  fi
  echo "API not ready (see .logs/api.log or: docker logs $API)" >&2
  exit 1
}

start_frontends() {
  local entry name p
  for entry in buyer:5173 merchant:5174 admin:5175; do
    name="${entry%%:*}"
    p="${entry##*:}"
    mkdir -p "$ROOT/.logs"
    (cd "$ROOT/frontend/$name" && XNY_API_PORT="$API_PORT" npm run dev -- --port "$p" --host 0.0.0.0) >>"$ROOT/.logs/${name}.log" 2>&1 &
    echo "  $name -> http://localhost:$p"
  done
}

case "$cmd" in
  start)
    stop_all
    echo "==> MySQL (host :${DB_HOST_PORT})"
    start_db
    ensure_data
    echo "==> API :${API_PORT}"
    start_api
    export XNY_API_PORT="$API_PORT"
    echo "==> Vite (proxy -> :${API_PORT})"
    start_frontends
    echo ""
    echo "portal   file://$ROOT/portal.html"
    echo "buyer    http://localhost:5173   (?????)"
    echo "merchant http://localhost:5174   (????)"
    echo "admin    http://localhost:5175   (??????)"
    echo "API      http://localhost:${API_PORT}"
    echo "stop: $0 stop"
    ;;
  api)
    start_db
    ensure_data
    start_api
    echo "API http://localhost:${API_PORT}"
    ;;
  stop)
    stop_all
    echo "stopped"
    ;;
  verify)
    start_db
    ensure_data
    "$ROOT/scripts/verify-api.sh"
    ;;
  accept)
    start_db
    ensure_data
    start_api_host 2>/dev/null || start_api_docker
    echo "==> P0 acceptance (buyer + merchant + admin)"
    "$ROOT/scripts/verify-api.sh" || true
    "$ROOT/scripts/accept-p0.sh"
    "$ROOT/scripts/accept-merchant.sh"
    "$ROOT/scripts/accept-admin.sh"
    ;;
  install)
    for app in buyer merchant admin; do
      echo "==> npm install frontend/$app"
      (cd "$ROOT/frontend/$app" && npm install)
    done
    ;;
  *)
    echo "usage: $0 {start|api|stop|verify|accept|install}"
    exit 1
    ;;
esac
