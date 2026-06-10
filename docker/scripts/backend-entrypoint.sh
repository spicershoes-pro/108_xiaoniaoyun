#!/bin/sh
# docker/scripts/backend-entrypoint.sh
# 后端容器启动入口脚本
# 功能：等待数据库就绪 → 执行数据库初始化 → 启动 PHP-FPM

set -e

echo "══════════════════════════════════════════"
echo "  霄鸟云后端容器启动"
echo "  APP_ENV=${APP_ENV:-development}"
echo "  PHP=$(php -r 'echo PHP_VERSION;')"
echo "══════════════════════════════════════════"

# ── 等待 MySQL 就绪 ──────────────────────────────────────────
DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-}"
DB_NAME="${DB_NAME:-xiaoniao_dev}"

echo "⏳ 等待 MySQL ${DB_HOST}:${DB_PORT} 就绪..."
MAX_RETRY=30
RETRY=0

until php -r "
  try {
    \$pdo = new PDO(
      'mysql:host=${DB_HOST};port=${DB_PORT}',
      '${DB_USER}',
      '${DB_PASS}',
      [PDO::ATTR_TIMEOUT => 3]
    );
    echo 'connected';
  } catch (Exception \$e) {
    exit(1);
  }
" 2>/dev/null | grep -q connected; do
  RETRY=$((RETRY+1))
  if [ $RETRY -ge $MAX_RETRY ]; then
    echo "❌ MySQL 连接超时（${MAX_RETRY}次），容器退出"
    exit 1
  fi
  echo "   等待中...（${RETRY}/${MAX_RETRY}）"
  sleep 2
done

echo "✅ MySQL 已就绪"

# ── 数据库初始化（首次部署或强制重建） ──────────────────────
# 检查 schema 是否已初始化（以 users 表是否存在为标志）
DB_INITIALIZED=$(php -r "
  try {
    \$pdo = new PDO(
      'mysql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_NAME}',
      '${DB_USER}', '${DB_PASS}'
    );
    \$stmt = \$pdo->query('SHOW TABLES LIKE \"users\"');
    echo \$stmt->rowCount() > 0 ? 'yes' : 'no';
  } catch (Exception \$e) {
    echo 'no';
  }
" 2>/dev/null)

if [ "$DB_INITIALIZED" != "yes" ] || [ "${FORCE_MIGRATE:-0}" = "1" ]; then
  echo "📦 执行数据库建表初始化..."
  php -r "
    \$pdo = new PDO(
      'mysql:host=${DB_HOST};port=${DB_PORT}',
      '${DB_USER}', '${DB_PASS}'
    );
    \$pdo->exec('CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
      CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
  " 2>/dev/null || true

  mysql --skip-ssl -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" \
    ${DB_PASS:+-p"${DB_PASS}"} \
    "${DB_NAME}" < /var/www/html/database/schema.sql

  echo "✅ 数据库表结构初始化完成"

  # 开发/测试环境自动导入演示数据
  APP_ENV="${APP_ENV:-development}"
  if [ "$APP_ENV" = "development" ] || [ "$APP_ENV" = "testing" ] || \
     { [ "$APP_ENV" = "staging" ] && [ "${SEED_DATA:-0}" = "1" ]; }; then
    if [ "${SEED_DATA:-1}" = "1" ]; then
      echo "🌱 导入演示数据（${APP_ENV}）..."
      mysql --skip-ssl -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" \
        ${DB_PASS:+-p"${DB_PASS}"} \
        "${DB_NAME}" < /var/www/html/database/seed.sql
      echo "✅ 演示数据导入完成"
    fi
  fi
else
  echo "ℹ️  数据库已初始化，跳过建表"
fi

# ── 确保目录权限 ─────────────────────────────────────────────
mkdir -p /var/www/html/public/uploads /var/www/logs
chown -R www-data:www-data /var/www/html/public/uploads /var/www/logs 2>/dev/null || true

echo ""
echo "🚀 启动 PHP-FPM..."
exec "$@"
