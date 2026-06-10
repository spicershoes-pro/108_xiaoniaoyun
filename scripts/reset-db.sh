#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 数据库重置脚本
# 用法：bash scripts/reset-db.sh [--seed]
# ⚠️  危险操作！仅允许在 development / testing 环境执行
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/backend/.env"

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    while IFS='=' read -r key val; do
      [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
      key=$(echo "$key" | xargs)
      val=$(echo "$val" | xargs)
      export "$key=$val" 2>/dev/null || true
    done < "$ENV_FILE"
  fi
}

load_env

APP_ENV="${APP_ENV:-development}"

# 安全锁：禁止在生产/预发环境执行
if [[ "$APP_ENV" == "production" ]] || [[ "$APP_ENV" == "staging" ]]; then
  echo "❌ 禁止在 $APP_ENV 环境执行数据库重置！"
  exit 1
fi

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-xiaoniao_dev}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-}"

MYSQL_CMD="mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USER}"
[[ -n "$DB_PASS" ]] && MYSQL_CMD="${MYSQL_CMD} -p${DB_PASS}"

echo "══════════════════════════════════════════"
echo "  霄鸟云 · 数据库重置 [$APP_ENV]"
echo "  数据库：${DB_NAME}@${DB_HOST}"
echo "══════════════════════════════════════════"
echo ""
read -p "⚠️  即将清空并重建数据库 ${DB_NAME}，确认继续？(yes/no) " confirm
[[ "$confirm" != "yes" ]] && echo "已取消" && exit 0

echo ""
echo "1. 删除并重建数据库..."
$MYSQL_CMD -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "2. 执行建表脚本..."
$MYSQL_CMD "$DB_NAME" < "${ROOT_DIR}/database/schema.sql"

if [[ "${1:-}" == "--seed" ]]; then
  echo "3. 导入演示数据..."
  $MYSQL_CMD "$DB_NAME" < "${ROOT_DIR}/database/seed.sql"
  echo "✅ 演示数据已导入"
fi

echo ""
echo "✅ 数据库重置完成！"
