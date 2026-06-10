#!/usr/bin/env bash
# 108_xiaoniaoyun ?? dev state split deploy (DB 223 + App 87)
#
#   source deploy/devices.dev.env
#   export SSHPASS='...'
#   bash scripts/push-dev-xny.sh
#
# Options:
#   DEPLOY_SKIP_RSYNC=1 | DEPLOY_DB_ONLY=1 | DEPLOY_APP_ONLY=1
#   DEPLOY_MAC_APP_DB_RELAY=1 (default on Mac app host)
#   DEPLOY_LOAD_LOCAL_IMAGES=1 (default: docker save|load)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/deploy/devices.dev.env"

RSYNC_REMOTE_SUBDIR="${DEPLOY_REMOTE_SUBDIR:-$XNY_REMOTE_DIR}"
DEPLOY_DB_HOST="${DEPLOY_DB_HOST:-$XNY_DB_HOST}"
DEPLOY_DB_USER="${DEPLOY_DB_USER:-$XNY_DB_SSH_USER}"
DEPLOY_APP_HOST="${DEPLOY_APP_HOST:-$XNY_APP_HOST}"
DEPLOY_APP_USER="${DEPLOY_APP_USER:-$XNY_APP_SSH_USER}"
REMOTE_MYSQL_HOST="${REMOTE_MYSQL_HOST:-$XNY_DB_HOST}"
DEPLOY_DB_ONLY="${DEPLOY_DB_ONLY:-0}"
DEPLOY_APP_ONLY="${DEPLOY_APP_ONLY:-0}"
MAC_RELAY="${DEPLOY_MAC_APP_DB_RELAY:-1}"
_LOAD_IMG="${DEPLOY_LOAD_LOCAL_IMAGES:-1}"
_MP="${MYSQL_ROOT_PASSWORD:-$(openssl rand -hex 12)}"
_DB_COMPOSE="$XNY_DB_COMPOSE_FILE"
_APP_COMPOSE="$XNY_APP_COMPOSE_FILE"
_MYSQL_C="${XNY_DB_CONTAINER_MYSQL}"
_ENV_REMOTE="${XNY_REMOTE_ENV_FILE}"

if [[ "$DEPLOY_DB_ONLY" == "1" && "$DEPLOY_APP_ONLY" == "1" ]]; then
  echo "Use at most one of DEPLOY_DB_ONLY=1 or DEPLOY_APP_ONLY=1." >&2
  exit 1
fi

ssh_base() {
  local user="$1" host="$2"
  shift 2
  if [[ -n "${SSHPASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
    SSHPASS="$SSHPASS" sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 "${user}@${host}" "$@"
  else
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 "${user}@${host}" "$@"
  fi
}

rsync_base() {
  local user="$1" host="$2"
  shift 2
  local dest="${user}@${host}:~/${RSYNC_REMOTE_SUBDIR}/"
  if [[ -n "${SSHPASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
    SSHPASS="$SSHPASS" sshpass -e rsync -az --delete \
      -e "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 -o PreferredAuthentications=password,keyboard-interactive" \
      "$@" "$dest"
  else
    rsync -az --delete -e "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20" "$@" "$dest"
  fi
}

RSYNC_EXCLUDES=(
  --exclude '.git/'
  --exclude '**/node_modules/'
  --exclude 'frontend/*/dist/'
  --exclude '.env'
  --exclude 'deploy/.env.dev'
  --exclude 'deploy/.env.prod'
)

echo "==> 108_xiaoniaoyun state=${XNY_STATE} image_tag=${XNY_IMAGE_TAG}"

if [[ "${DEPLOY_SKIP_RSYNC:-0}" != "1" ]]; then
  if [[ "$DEPLOY_APP_ONLY" != "1" ]]; then
    echo "==> rsync DB ${DEPLOY_DB_USER}@${DEPLOY_DB_HOST} (${XNY_DB_HOSTNAME})"
    ssh_base "$DEPLOY_DB_USER" "$DEPLOY_DB_HOST" "mkdir -p \"\$HOME/${RSYNC_REMOTE_SUBDIR}\""
    rsync_base "$DEPLOY_DB_USER" "$DEPLOY_DB_HOST" "${RSYNC_EXCLUDES[@]}" "$REPO_ROOT/"
  fi
  if [[ "$DEPLOY_DB_ONLY" != "1" ]]; then
    echo "==> rsync APP ${DEPLOY_APP_USER}@${DEPLOY_APP_HOST} (${XNY_APP_HOSTNAME})"
    ssh_base "$DEPLOY_APP_USER" "$DEPLOY_APP_HOST" "mkdir -p \"\$HOME/${RSYNC_REMOTE_SUBDIR}\""
    rsync_base "$DEPLOY_APP_USER" "$DEPLOY_APP_HOST" "${RSYNC_EXCLUDES[@]}" "$REPO_ROOT/"
  fi
fi

if [[ "$DEPLOY_APP_ONLY" != "1" ]]; then
  echo "==> DB: project ${XNY_DB_COMPOSE_PROJECT} MySQL :${XNY_DB_MYSQL_PORT}"
  ssh_base "$DEPLOY_DB_USER" "$DEPLOY_DB_HOST" bash -s <<REMOTE
set -euo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:/usr/bin:/bin:\$PATH"
cd "\$HOME/${RSYNC_REMOTE_SUBDIR}"
mkdir -p deploy
if [[ -f deploy/.env.dev ]]; then
  set -a; source deploy/.env.dev; set +a
elif [[ -f deploy/.env.prod ]]; then
  set -a; source deploy/.env.prod; set +a
else
  MYSQL_ROOT_PASSWORD="${_MP}"
  echo "XNY_STATE=dev" > deploy/.env.dev
  echo "MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}" >> deploy/.env.dev
  echo "DB_NAME=${XNY_DB_NAME}" >> deploy/.env.dev
fi
for _lp in xiaoniao-db-prod 108_xiaoniaoyun-db 108_xiaoniaoyun_db_dev; do
  docker compose -p "\$_lp" -f ${_DB_COMPOSE} down --remove-orphans 2>/dev/null || true
  docker compose -p "\$_lp" -f docker-compose.db-prod-remote.yml down --remove-orphans 2>/dev/null || true
done
docker rm -f xn-db-prod 108_xiaoniaoyun-mysql 108_xiaoniaoyun-mysql-dev 2>/dev/null || true
docker compose -f ${_DB_COMPOSE} --env-file deploy/.env.dev up -d 2>/dev/null || \
  docker compose -f ${_DB_COMPOSE} --env-file deploy/.env.prod up -d
for i in \$(seq 1 40); do
  if docker inspect ${_MYSQL_C} --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy; then
    echo "MySQL healthy (${_MYSQL_C})"
    break
  fi
  sleep 3
done
REMOTE
fi

if [[ "$DEPLOY_DB_ONLY" == "1" ]]; then
  echo "==> Done DB only. ${REMOTE_MYSQL_HOST}:${XNY_DB_MYSQL_PORT}"
  exit 0
fi

if [[ "$MAC_RELAY" == "1" ]]; then
  _DB_HOST="host.docker.internal"
  _DB_PORT="${XNY_APP_MAC_DB_RELAY_PORT}"
else
  _DB_HOST="${REMOTE_MYSQL_HOST}"
  _DB_PORT="${XNY_DB_MYSQL_PORT}"
fi

if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  _remote_mp="$(ssh_base "$DEPLOY_DB_USER" "$DEPLOY_DB_HOST" \
    "grep '^MYSQL_ROOT_PASSWORD=' \"\$HOME/${RSYNC_REMOTE_SUBDIR}/deploy/.env.dev\" 2>/dev/null | cut -d= -f2- || \
     grep '^MYSQL_ROOT_PASSWORD=' \"\$HOME/${RSYNC_REMOTE_SUBDIR}/deploy/.env.prod\" 2>/dev/null | cut -d= -f2-" || true)"
  [[ -n "$_remote_mp" ]] && _MP="$_remote_mp"
fi

_JWT="${JWT_SECRET:-$(openssl rand -hex 24)}"
_RP="${REDIS_PASS:-$(openssl rand -hex 8)}"
_MP_APP="${MYSQL_ROOT_PASSWORD:-$_MP}"

ensure_image() {
  local new="$1"
  shift
  docker image inspect "$new" >/dev/null 2>&1 && return 0
  for old in "$@"; do
    docker image inspect "$old" >/dev/null 2>&1 && docker tag "$old" "$new" && return 0
  done
  return 1
}

if [[ "$_LOAD_IMG" == "1" ]]; then
  echo "==> docker save|load 108_xiaoniaoyun/*:${XNY_IMAGE_TAG}"
  ensure_image "108_xiaoniaoyun/backend:${XNY_IMAGE_TAG}" xiaoniao/backend:prod 108_xiaoniaoyun/backend:prod || true
  ensure_image "108_xiaoniaoyun/frontend-buyer:${XNY_IMAGE_TAG}" xiaoniao/frontend-buyer:prod 108_xiaoniaoyun/frontend-buyer:prod || true
  ensure_image "108_xiaoniaoyun/frontend-merchant:${XNY_IMAGE_TAG}" xiaoniao/frontend-merchant:prod 108_xiaoniaoyun/frontend-merchant:prod || true
  ensure_image "108_xiaoniaoyun/frontend-admin:${XNY_IMAGE_TAG}" xiaoniao/frontend-admin:prod 108_xiaoniaoyun/frontend-admin:prod || true
  for img in 108_xiaoniaoyun/backend:${XNY_IMAGE_TAG} 108_xiaoniaoyun/frontend-buyer:${XNY_IMAGE_TAG} \
    108_xiaoniaoyun/frontend-merchant:${XNY_IMAGE_TAG} 108_xiaoniaoyun/frontend-admin:${XNY_IMAGE_TAG}; do
    docker image inspect "$img" >/dev/null 2>&1 || { echo "Missing image: $img" >&2; exit 1; }
  done
  docker save \
    "108_xiaoniaoyun/backend:${XNY_IMAGE_TAG}" \
    "108_xiaoniaoyun/frontend-buyer:${XNY_IMAGE_TAG}" \
    "108_xiaoniaoyun/frontend-merchant:${XNY_IMAGE_TAG}" \
    "108_xiaoniaoyun/frontend-admin:${XNY_IMAGE_TAG}" \
    | gzip -1 | ssh_base "$DEPLOY_APP_USER" "$DEPLOY_APP_HOST" \
    'export PATH="/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:/usr/bin:/bin:$PATH"; gunzip | docker load'
fi

echo "==> APP: project ${XNY_APP_COMPOSE_PROJECT} DB ${_DB_HOST}:${_DB_PORT}"
ssh_base "$DEPLOY_APP_USER" "$DEPLOY_APP_HOST" bash -s <<REMOTE
set -euo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:/usr/bin:/bin:\$PATH"
cd "\$HOME/${RSYNC_REMOTE_SUBDIR}"
mkdir -p deploy
if [[ ! -f deploy/.env.dev ]]; then
  cat > deploy/.env.dev << ENVEOF
XNY_STATE=dev
MYSQL_ROOT_PASSWORD=${_MP_APP}
DB_NAME=${XNY_DB_NAME}
JWT_SECRET=${_JWT}
REDIS_PASS=${_RP}
REMOTE_DB_HOST=${_DB_HOST}
REMOTE_DB_PORT=${_DB_PORT}
PUBLIC_HOST=${DEPLOY_APP_HOST}
APP_ENV=${XNY_APP_ENV}
SEED_DATA=${XNY_SEED_DATA}
ENVEOF
else
  grep -q '^XNY_STATE=' deploy/.env.dev || echo "XNY_STATE=dev" >> deploy/.env.dev
  if grep -q '^MYSQL_ROOT_PASSWORD=' deploy/.env.dev; then
    sed -i.bak "s|^MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=${_MP_APP}|" deploy/.env.dev
  else
    echo "MYSQL_ROOT_PASSWORD=${_MP_APP}" >> deploy/.env.dev
  fi
  grep -q JWT_SECRET deploy/.env.dev || echo "JWT_SECRET=${_JWT}" >> deploy/.env.dev
  grep -q REDIS_PASS deploy/.env.dev || echo "REDIS_PASS=${_RP}" >> deploy/.env.dev
  sed -i.bak "s|^REMOTE_DB_HOST=.*|REMOTE_DB_HOST=${_DB_HOST}|" deploy/.env.dev 2>/dev/null || echo "REMOTE_DB_HOST=${_DB_HOST}" >> deploy/.env.dev
  sed -i.bak "s|^REMOTE_DB_PORT=.*|REMOTE_DB_PORT=${_DB_PORT}|" deploy/.env.dev 2>/dev/null || echo "REMOTE_DB_PORT=${_DB_PORT}" >> deploy/.env.dev
  rm -f deploy/.env.dev.bak
fi
if [[ "${MAC_RELAY}" == "1" ]]; then
  pkill -f mysql_tcp_relays_mac_app_host.py 2>/dev/null || true
  nohup env RELAY_UPSTREAM_HOST="${REMOTE_MYSQL_HOST}" RELAY_LOCAL_BASE=${XNY_APP_MAC_DB_RELAY_PORT} RELAY_REMOTE_BASE=${XNY_DB_MYSQL_PORT} RELAY_COUNT=1 \
    python3 scripts/mysql_tcp_relays_mac_app_host.py >>/tmp/108_xiaoniaoyun-mysql-relay.log 2>&1 &
  sleep 2
fi
for _lp in xiaoniao-app-prod 108_xiaoniaoyun-app 108_xiaoniaoyun_app_dev; do
  docker compose -p "\$_lp" -f ${_APP_COMPOSE} --env-file deploy/.env.dev down --remove-orphans 2>/dev/null || true
  docker compose -p "\$_lp" -f docker-compose.app-prod-remote.yml down --remove-orphans 2>/dev/null || true
done
docker rm -f xn-redis-prod xn-backend-prod xn-nginx-api-prod xn-buyer-prod xn-merchant-prod xn-admin-prod \
  108_xiaoniaoyun-redis 108_xiaoniaoyun-backend 108_xiaoniaoyun-nginx-api 108_xiaoniaoyun-buyer 108_xiaoniaoyun-merchant 108_xiaoniaoyun-admin \
  108_xiaoniaoyun-redis-dev 108_xiaoniaoyun-backend-dev 108_xiaoniaoyun-nginx-api-dev 108_xiaoniaoyun-buyer-dev 108_xiaoniaoyun-merchant-dev 108_xiaoniaoyun-admin-dev 2>/dev/null || true
docker compose -f ${_APP_COMPOSE} --env-file deploy/.env.dev up -d
for i in \$(seq 1 60); do
  curl -sf "http://127.0.0.1:${XNY_APP_API_PORT}/health" >/dev/null 2>&1 && echo "API health OK" && break
  sleep 5
done
REMOTE

echo ""
echo "==> 108_xiaoniaoyun_${XNY_STATE} deploy done"
echo "    DB  ${XNY_DB_HOSTNAME} ${REMOTE_MYSQL_HOST}:${XNY_DB_MYSQL_PORT}  (${_MYSQL_C})"
echo "    APP ${XNY_APP_HOSTNAME} http://${DEPLOY_APP_HOST}:${XNY_APP_API_PORT}/health"
echo "    buyer   http://${DEPLOY_APP_HOST}:5173/"
echo "    merchant http://${DEPLOY_APP_HOST}:5174/"
echo "    admin   http://${DEPLOY_APP_HOST}:5175/"
echo "    code    123456 (${XNY_APP_ENV})"
