#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 数据库自动备份脚本
# 用法：bash deploy/scripts/backup-db.sh
# Cron：0 3 * * * /opt/xiaoniao/deploy/scripts/backup-db.sh
# 策略：每日全量备份，保留 30 天
# ============================================================

set -euo pipefail

APP_DIR="/opt/xiaoniao"
BACKUP_DIR="${APP_DIR}/backups/db"
KEEP_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)

# 加载生产配置
source "${APP_DIR}/config/prod.env"

mkdir -p "$BACKUP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始数据库备份..."

# 执行备份（通过 Docker 容器）
BACKUP_FILE="${BACKUP_DIR}/xiaoniao_prod_${DATE}.sql.gz"

docker compose -f "${APP_DIR}/docker-compose.prod.yml" exec -T db \
    mysqldump \
    -u root \
    --password="${MYSQL_ROOT_PASSWORD}" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --set-gtid-purged=OFF \
    "${DB_NAME}" \
| gzip > "${BACKUP_FILE}"

SIZE=$(du -sh "${BACKUP_FILE}" | cut -f1)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份完成：${BACKUP_FILE}（${SIZE}）"

# 清理超过 30 天的旧备份
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +${KEEP_DAYS} -delete
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 已清理 ${KEEP_DAYS} 天前的备份"

# 可选：上传到 OSS
# ossutil cp "${BACKUP_FILE}" "oss://${OSS_BUCKET}/backups/db/"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份任务完成"
