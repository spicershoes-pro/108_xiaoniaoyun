#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 全量备份脚本
# 覆盖：数据库 + 用户上传文件 + 生产配置快照
# 用法：bash deploy/ops/backup-full.sh [--upload-oss]
# Cron（推荐）：
#   0  3 * * *  bash /opt/xiaoniao/deploy/ops/backup-full.sh --upload-oss
#   0 20 * * *  bash /opt/xiaoniao/deploy/ops/backup-full.sh          # 晚间增量
# ============================================================

set -euo pipefail

# ── 配置 ─────────────────────────────────────────────────────
APP_DIR="/opt/xiaoniao"
BACKUP_ROOT="${APP_DIR}/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DATE_LABEL=$(date +%Y%m%d)
KEEP_DB_DAYS=30
KEEP_FILES_DAYS=14
KEEP_CONF_DAYS=90
UPLOAD_OSS="${1:-}"
LOG_FILE="${APP_DIR}/backups/logs/backup-${DATE_LABEL}.log"

# ── 颜色 ─────────────────────────────────────────────────────
ts()   { date '+%Y-%m-%d %H:%M:%S'; }
log()  { echo "[$(ts)] $*" | tee -a "$LOG_FILE"; }
ok()   { log "✅ $*"; }
warn() { log "⚠️  $*"; }
fail() { log "❌ $*"; exit 1; }

mkdir -p "${BACKUP_ROOT}"/{db,files,config,logs}

log "════════════════════════════════════════"
log " 霄鸟云全量备份开始  ${DATE}"
log "════════════════════════════════════════"

# 加载配置
source "${APP_DIR}/config/prod.env"

# ── 1. 数据库备份 ─────────────────────────────────────────────
log "[1/4] 数据库备份..."
DB_FILE="${BACKUP_ROOT}/db/xiaoniao_db_${DATE}.sql.gz"

docker compose -f "${APP_DIR}/docker-compose.prod.yml" exec -T db \
    mysqldump \
    -u root --password="${MYSQL_ROOT_PASSWORD}" \
    --single-transaction --routines --triggers \
    --events --set-gtid-purged=OFF \
    "${DB_NAME}" 2>/dev/null \
| gzip > "${DB_FILE}"

# MD5 完整性校验
md5sum "${DB_FILE}" > "${DB_FILE}.md5"

DB_SIZE=$(du -sh "${DB_FILE}" | cut -f1)
ok "数据库备份：${DB_FILE}（${DB_SIZE}）"

# 验证备份可读性（解压首行）
if zcat "${DB_FILE}" | head -5 | grep -q "MySQL dump"; then
    ok "数据库备份完整性校验通过"
else
    fail "数据库备份完整性校验失败！文件可能损坏"
fi

# ── 2. 用户上传文件备份 ───────────────────────────────────────
log "[2/4] 用户上传文件备份..."
FILES_FILE="${BACKUP_ROOT}/files/uploads_${DATE}.tar.gz"

# 从 Docker 卷中备份
docker run --rm \
    -v xiaoniao-prod-uploads:/data:ro \
    -v "${BACKUP_ROOT}/files":/backup \
    alpine:3.19 \
    tar czf "/backup/uploads_${DATE}.tar.gz" -C /data . 2>/dev/null || \
    (warn "Docker卷备份失败，尝试直接路径" && \
     tar czf "${FILES_FILE}" \
         -C /var/lib/docker/volumes/xiaoniao-prod-uploads/_data . 2>/dev/null || \
     warn "上传文件卷不存在或为空，跳过")

[[ -f "${FILES_FILE}" ]] && {
    md5sum "${FILES_FILE}" > "${FILES_FILE}.md5"
    FILES_SIZE=$(du -sh "${FILES_FILE}" | cut -f1)
    ok "上传文件备份：${FILES_FILE}（${FILES_SIZE}）"
} || warn "上传文件备份跳过（卷可能为空）"

# ── 3. 配置文件快照 ───────────────────────────────────────────
log "[3/4] 配置文件快照..."
CONF_FILE="${BACKUP_ROOT}/config/config_snapshot_${DATE}.tar.gz"

# 备份配置（排除密钥值，仅保留结构）
tar czf "${CONF_FILE}" \
    --exclude="${APP_DIR}/config/prod.env" \
    "${APP_DIR}/backend/config/" \
    "${APP_DIR}/backend/.env.example" \
    "${APP_DIR}/deploy/" \
    "${APP_DIR}/docker-compose.prod.yml" \
    "${APP_DIR}/Makefile" \
    2>/dev/null

md5sum "${CONF_FILE}" > "${CONF_FILE}.md5"

# 单独备份 prod.env（加密存储，仅限有权限用户读取）
CONF_PASS=$(openssl rand -hex 8)
openssl enc -aes-256-cbc -salt -pbkdf2 \
    -in "${APP_DIR}/config/prod.env" \
    -out "${BACKUP_ROOT}/config/prod.env.enc.${DATE}" \
    -k "${CONF_PASS}" 2>/dev/null
# 将密码安全记录（实际生产应写入密钥管理系统）
echo "${DATE} ${CONF_PASS}" >> "${APP_DIR}/config/.enc-keys"
chmod 600 "${APP_DIR}/config/.enc-keys"

ok "配置文件快照：${CONF_FILE}"

# ── 4. 上传到 OSS ─────────────────────────────────────────────
if [[ "${UPLOAD_OSS}" == "--upload-oss" ]] && command -v ossutil &>/dev/null; then
    log "[4/4] 上传到 OSS..."
    OSS_PREFIX="oss://${OSS_BUCKET:-xiaoniao-prod}/backups/${DATE_LABEL}"

    ossutil cp "${DB_FILE}"   "${OSS_PREFIX}/db/"     --quiet && ok "DB已上传OSS"
    ossutil cp "${DB_FILE}.md5" "${OSS_PREFIX}/db/"   --quiet
    [[ -f "${FILES_FILE}" ]] && \
        ossutil cp "${FILES_FILE}" "${OSS_PREFIX}/files/" --quiet && ok "文件已上传OSS"
    ossutil cp "${CONF_FILE}" "${OSS_PREFIX}/config/" --quiet && ok "配置已上传OSS"
else
    log "[4/4] 跳过OSS上传（未指定 --upload-oss 或 ossutil 未安装）"
fi

# ── 5. 清理过期备份 ───────────────────────────────────────────
log "[5/5] 清理过期备份..."
find "${BACKUP_ROOT}/db"     -name "*.sql.gz*" -mtime +${KEEP_DB_DAYS}    -delete
find "${BACKUP_ROOT}/files"  -name "*.tar.gz*" -mtime +${KEEP_FILES_DAYS} -delete
find "${BACKUP_ROOT}/config" -name "*.tar.gz*" -mtime +${KEEP_CONF_DAYS}  -delete
find "${BACKUP_ROOT}/logs"   -name "*.log"     -mtime +60                  -delete
ok "过期备份清理完成"

# ── 6. 告警通知 ───────────────────────────────────────────────
ALERT_WEBHOOK="${DINGTALK_WEBHOOK:-${WECHAT_WEBHOOK:-}}"
if [[ -n "$ALERT_WEBHOOK" ]]; then
    curl -s -X POST "$ALERT_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"✅ 霄鸟云备份完成\\n时间：${DATE}\\nDB：${DB_SIZE}\\n状态：正常\"}}" \
        &>/dev/null || true
fi

# ── 备份摘要 ─────────────────────────────────────────────────
log "════════════════════════════════════════"
log " 备份任务完成"
log " DB备份: ${DB_FILE}"
log " 剩余DB备份数: $(find ${BACKUP_ROOT}/db -name '*.sql.gz' | wc -l)"
log " 备份日志: ${LOG_FILE}"
log "════════════════════════════════════════"
