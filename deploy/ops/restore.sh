#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 一键恢复脚本
# 用法：bash deploy/ops/restore.sh [db|files|all] [备份文件路径]
# 示例：bash deploy/ops/restore.sh db /opt/xiaoniao/backups/db/xiaoniao_db_20260517_030001.sql.gz
#       bash deploy/ops/restore.sh all  （交互式选择最新备份）
# ============================================================

set -euo pipefail

APP_DIR="/opt/xiaoniao"
BACKUP_ROOT="${APP_DIR}/backups"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
ts()    { date '+%Y-%m-%d %H:%M:%S'; }
log()   { echo -e "[$(ts)] $*"; }
ok()    { echo -e "${GREEN}[$(ts)] ✅ $*${NC}"; }
warn()  { echo -e "${YELLOW}[$(ts)] ⚠️  $*${NC}"; }
error() { echo -e "${RED}[$(ts)] ❌ $*${NC}"; exit 1; }

MODE="${1:-all}"
BACKUP_FILE="${2:-}"

# 加载配置
[[ -f "${APP_DIR}/config/prod.env" ]] && source "${APP_DIR}/config/prod.env"

echo -e "${RED}"
echo "══════════════════════════════════════════════════════"
echo "  霄鸟云 · 数据恢复"
echo "  ⚠️  此操作将覆盖现有数据，请谨慎！"
echo "══════════════════════════════════════════════════════"
echo -e "${NC}"

# ── 恢复前确认 ───────────────────────────────────────────────
confirm() {
    local msg="$1"
    read -rp "$(echo -e ${YELLOW})⚠️  ${msg} 确认继续？(输入 yes 继续) $(echo -e ${NC})" ans
    [[ "$ans" != "yes" ]] && echo "已取消操作" && exit 0
}

# ── 选择备份文件 ─────────────────────────────────────────────
select_latest_backup() {
    local dir="$1" pattern="$2"
    latest=$(find "${dir}" -name "${pattern}" -type f | sort -r | head -1)
    echo "$latest"
}

# ── 校验备份完整性 ────────────────────────────────────────────
verify_backup() {
    local file="$1"
    [[ -f "${file}" ]] || error "备份文件不存在：${file}"
    [[ -f "${file}.md5" ]] && {
        md5sum -c "${file}.md5" --quiet 2>/dev/null && ok "MD5校验通过" || error "MD5校验失败，文件可能损坏！"
    } || warn "未找到MD5文件，跳过校验"
}

# ── 1. 数据库恢复 ─────────────────────────────────────────────
restore_db() {
    local file="${1:-}"
    if [[ -z "$file" ]]; then
        file=$(select_latest_backup "${BACKUP_ROOT}/db" "*.sql.gz")
        [[ -z "$file" ]] && error "未找到数据库备份文件"
    fi

    log "准备恢复数据库..."
    log "备份文件：${file}"
    log "目标数据库：${DB_NAME:-xiaoniao_prod}"

    verify_backup "$file"

    confirm "将使用 ${file} 覆盖数据库 ${DB_NAME:-xiaoniao_prod}"

    log "开始恢复数据库..."

    # 停止后端服务（防止写入冲突）
    log "暂停后端服务..."
    docker compose -f "${APP_DIR}/docker-compose.prod.yml" stop backend 2>/dev/null || true

    # 创建安全备份（恢复前再备一次当前数据）
    SAFETY_FILE="${BACKUP_ROOT}/db/xiaoniao_db_safety_$(date +%Y%m%d_%H%M%S).sql.gz"
    log "创建安全备份 ${SAFETY_FILE}..."
    docker compose -f "${APP_DIR}/docker-compose.prod.yml" exec -T db \
        mysqldump -u root --password="${MYSQL_ROOT_PASSWORD}" \
        --single-transaction "${DB_NAME}" 2>/dev/null | gzip > "${SAFETY_FILE}"
    ok "安全备份完成"

    # 恢复数据
    log "导入数据库备份..."
    zcat "$file" | docker compose -f "${APP_DIR}/docker-compose.prod.yml" exec -T db \
        mysql -u root --password="${MYSQL_ROOT_PASSWORD}" "${DB_NAME}" 2>/dev/null

    ok "数据库恢复完成"

    # 重启后端
    log "重启后端服务..."
    docker compose -f "${APP_DIR}/docker-compose.prod.yml" start backend
    sleep 5
    curl -sf http://localhost:8080/health &>/dev/null && ok "后端服务已恢复" || warn "后端健康检查失败，请手动检查"
}

# ── 2. 上传文件恢复 ───────────────────────────────────────────
restore_files() {
    local file="${1:-}"
    if [[ -z "$file" ]]; then
        file=$(select_latest_backup "${BACKUP_ROOT}/files" "*.tar.gz")
        [[ -z "$file" ]] && error "未找到文件备份"
    fi

    log "准备恢复上传文件..."
    verify_backup "$file"
    confirm "将使用 ${file} 覆盖用户上传文件"

    log "恢复上传文件到 Docker 卷..."
    docker run --rm \
        -v xiaoniao-prod-uploads:/data \
        -v "$(dirname $file)":/backup:ro \
        alpine:3.19 \
        sh -c "rm -rf /data/* && tar xzf /backup/$(basename $file) -C /data"

    ok "上传文件恢复完成"
}

# ── 执行 ─────────────────────────────────────────────────────
case "$MODE" in
    db)    restore_db "${BACKUP_FILE}" ;;
    files) restore_files "${BACKUP_FILE}" ;;
    all)
        log "全量恢复模式..."
        restore_db
        restore_files
        ok "全量恢复完成"
        ;;
    *)
        echo "用法: $0 [db|files|all] [备份文件路径]"
        exit 1
        ;;
esac

log "恢复操作完成  $(date '+%Y-%m-%d %H:%M:%S')"
