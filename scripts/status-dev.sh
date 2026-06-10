#!/usr/bin/env bash
# Print 108_xiaoniaoyun dev stack status per device
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/deploy/devices.dev.env"

echo "108_xiaoniaoyun  state=${XNY_STATE}  image=${XNY_IMAGE_TAG}"
echo ""

printf "%-12s %-18s %-22s %-36s\n" "device" "host" "compose_project" "key_container"
printf "%-12s %-18s %-22s %-36s\n" "------" "----" "---------------" "-------------"
printf "%-12s %-12s %-22s %-36s\n" "$XNY_DEVICE_LOCAL" "localhost" "$XNY_LOCAL_COMPOSE_PROJECT" "108_xiaoniaoyun-db-dev"
printf "%-12s %-12s %-22s %-36s\n" "$XNY_DEVICE_DB" "$XNY_DB_HOST" "$XNY_DB_COMPOSE_PROJECT" "$XNY_DB_CONTAINER_MYSQL"
printf "%-12s %-12s %-22s %-36s\n" "$XNY_DEVICE_APP" "$XNY_APP_HOST" "$XNY_APP_COMPOSE_PROJECT" "$XNY_APP_CONTAINER_BACKEND"
echo ""

if command -v docker >/dev/null 2>&1; then
  echo "==> local ($XNY_LOCAL_COMPOSE_PROJECT)"
  docker compose -f "$ROOT/$XNY_LOCAL_COMPOSE_FILE" ps 2>/dev/null || echo "(not running)"
  echo ""
fi

echo "URLs (app tier):"
echo "  API      http://${XNY_APP_HOST}:${XNY_APP_API_PORT}/health"
echo "  buyer    http://${XNY_APP_HOST}:5173/"
echo "  merchant http://${XNY_APP_HOST}:5174/"
echo "  admin    http://${XNY_APP_HOST}:5175/"
echo "  MySQL    ${XNY_DB_HOST}:${XNY_DB_MYSQL_PORT}"
