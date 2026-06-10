#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 监控与告警脚本
# 覆盖：服务存活 / 容器状态 / 服务器负载 / 磁盘 / DB连接 / SSL到期
# 用法：bash deploy/ops/monitor.sh [--quiet]
# Cron：*/5 * * * * bash /opt/xiaoniao/deploy/ops/monitor.sh --quiet
# ============================================================

set -uo pipefail

APP_DIR="/opt/xiaoniao"
QUIET="${1:-}"
LOG_FILE="/var/log/xiaoniao/monitor.log"
ALERT_COOLDOWN=1800    # 告警冷却时间（秒），同一告警 30 分钟内不重复
COOLDOWN_DIR="/tmp/xn-alert-cooldown"

mkdir -p "$COOLDOWN_DIR" "$(dirname $LOG_FILE)"

ts()     { date '+%Y-%m-%d %H:%M:%S'; }
log()    { [[ "$QUIET" != "--quiet" ]] && echo "[$(ts)] $*" || true; echo "[$(ts)] $*" >> "$LOG_FILE"; }
alert()  {
    local key="$1" msg="$2"
    local lock="${COOLDOWN_DIR}/${key}"
    local now=$(date +%s)
    # 冷却检查
    if [[ -f "$lock" ]]; then
        local last=$(cat "$lock")
        [[ $((now - last)) -lt $ALERT_COOLDOWN ]] && return 0
    fi
    echo "$now" > "$lock"
    log "🚨 告警：${msg}"
    send_alert "$msg"
}

# ── 告警发送（企业微信/钉钉/邮件）────────────────────────────
send_alert() {
    local msg="$1"
    local hostname=$(hostname)
    local timestamp=$(ts)
    local full_msg="【霄鸟云告警】${hostname}\n时间：${timestamp}\n${msg}"

    # 企业微信机器人
    if [[ -n "${WECHAT_WEBHOOK:-}" ]]; then
        curl -s -X POST "${WECHAT_WEBHOOK}" \
            -H "Content-Type: application/json" \
            -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"${full_msg}\",\"mentioned_list\":[\"@all\"]}}" \
            &>/dev/null || true
    fi

    # 钉钉机器人
    if [[ -n "${DINGTALK_WEBHOOK:-}" ]]; then
        curl -s -X POST "${DINGTALK_WEBHOOK}" \
            -H "Content-Type: application/json" \
            -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"${full_msg}\"}}" \
            &>/dev/null || true
    fi

    # 邮件（需 mailutils）
    if [[ -n "${ALERT_EMAIL:-}" ]] && command -v mail &>/dev/null; then
        echo -e "$full_msg" | mail -s "【霄鸟云告警】${hostname}" "${ALERT_EMAIL}" &>/dev/null || true
    fi
}

# ── 加载配置 ─────────────────────────────────────────────────
[[ -f "${APP_DIR}/config/prod.env" ]] && source "${APP_DIR}/config/prod.env" || true

log "══ 监控检查开始 ══"
FAILED=0

# ── 1. 服务存活检查 ───────────────────────────────────────────
log "[1] 服务存活检查..."
declare -A ENDPOINTS=(
    ["后端API"]="http://localhost:8080/health"
    ["用户端"]="http://localhost:5173"
    ["商家端"]="http://localhost:5174"
    ["管理端"]="http://localhost:5175"
)
declare -A HTTPS_ENDPOINTS=(
    ["HTTPS用户端"]="https://www.xiaoniao.com"
    ["HTTPS接口"]="https://api.xiaoniao.com/health"
)

for name in "${!ENDPOINTS[@]}"; do
    url="${ENDPOINTS[$name]}"
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
    if [[ "$http_code" =~ ^(200|301|302|304)$ ]]; then
        log "  ✅ ${name}: HTTP ${http_code}"
    else
        alert "svc_$(echo $name | tr ' ' _)" "⛔ 服务 [${name}] 不可用（HTTP ${http_code}）\nURL：${url}"
        FAILED=$((FAILED+1))
    fi
done

# ── 2. 容器状态检查 ───────────────────────────────────────────
log "[2] 容器状态检查..."
EXPECTED_CONTAINERS=("108_xiaoniaoyun-mysql-dev" "108_xiaoniaoyun-redis-dev" "108_xiaoniaoyun-backend-dev" "108_xiaoniaoyun-nginx-api-dev" "108_xiaoniaoyun-buyer-dev" "108_xiaoniaoyun-merchant-dev" "108_xiaoniaoyun-admin-dev")

for cname in "${EXPECTED_CONTAINERS[@]}"; do
    status=$(docker inspect --format='{{.State.Status}}' "$cname" 2>/dev/null || echo "not_found")
    health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no_healthcheck{{end}}' "$cname" 2>/dev/null || echo "unknown")
    if [[ "$status" == "running" ]]; then
        if [[ "$health" == "unhealthy" ]]; then
            alert "container_${cname}" "⚠️ 容器 ${cname} 运行中但健康检查失败"
            FAILED=$((FAILED+1))
        else
            log "  ✅ ${cname}: ${status}/${health}"
        fi
    else
        alert "container_${cname}" "⛔ 容器 ${cname} 状态异常：${status}"
        FAILED=$((FAILED+1))
    fi
done

# ── 3. 服务器资源检查 ─────────────────────────────────────────
log "[3] 服务器资源检查..."

# CPU 使用率（5秒平均）
CPU=$(top -bn2 | grep "Cpu(s)" | tail -1 | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "0")
log "  CPU使用率: ${CPU}%"
[[ ${CPU:-0} -gt 85 ]] && alert "cpu_high" "⚠️ CPU使用率高：${CPU}%（阈值 85%）"

# 内存使用率
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
log "  内存使用: ${MEM_USED}MB/${MEM_TOTAL}MB（${MEM_PCT}%）"
[[ $MEM_PCT -gt 85 ]] && alert "mem_high" "⚠️ 内存使用率高：${MEM_PCT}%（阈值 85%）"

# 磁盘使用率（根分区）
DISK_PCT=$(df / | awk 'NR==2{gsub(/%/,"",$5); print $5}')
DISK_AVAIL=$(df -h / | awk 'NR==2{print $4}')
log "  磁盘使用: ${DISK_PCT}%（剩余 ${DISK_AVAIL}）"
[[ ${DISK_PCT:-0} -gt 80 ]] && alert "disk_high" "⚠️ 磁盘使用率高：${DISK_PCT}%（阈值 80%，剩余 ${DISK_AVAIL}）"

# Docker 卷磁盘
for vol in 108_xiaoniaoyun-db-data 108_xiaoniaoyun-uploads; do
    vol_path=$(docker volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null || echo "")
    if [[ -n "$vol_path" ]]; then
        vol_size=$(du -sh "$vol_path" 2>/dev/null | cut -f1 || echo "N/A")
        log "  卷 ${vol}: ${vol_size}"
    fi
done

# ── 4. 数据库连接检查 ─────────────────────────────────────────
log "[4] 数据库连接检查..."
DB_STATUS=$(docker compose -f "${APP_DIR}/docker-compose.prod.yml" exec -T db \
    mysqladmin -u root --password="${MYSQL_ROOT_PASSWORD}" status 2>/dev/null | \
    grep -o "Threads: [0-9]*" || echo "FAIL")

if echo "$DB_STATUS" | grep -q "Threads:"; then
    THREADS=$(echo "$DB_STATUS" | grep -o "[0-9]*")
    log "  ✅ MySQL 连接正常（活跃线程: ${THREADS}）"
    [[ ${THREADS:-0} -gt 150 ]] && alert "db_threads" "⚠️ MySQL 活跃连接数高：${THREADS}（阈值 150）"
else
    alert "db_conn" "⛔ MySQL 连接失败！"
    FAILED=$((FAILED+1))
fi

# ── 5. Redis 连接检查 ─────────────────────────────────────────
log "[5] Redis 检查..."
REDIS_PONG=$(docker compose -f "${APP_DIR}/docker-compose.prod.yml" exec -T redis \
    redis-cli --no-auth-warning -a "${REDIS_PASS:-}" ping 2>/dev/null || echo "FAIL")
if [[ "$REDIS_PONG" == "PONG" ]]; then
    log "  ✅ Redis 连接正常"
else
    alert "redis_conn" "⛔ Redis 连接失败！"
    FAILED=$((FAILED+1))
fi

# ── 6. SSL 证书到期检查 ───────────────────────────────────────
log "[6] SSL 证书检查..."
CERT_FILE="/etc/letsencrypt/live/xiaoniao.com/fullchain.pem"
if [[ -f "$CERT_FILE" ]]; then
    EXPIRE_DATE=$(openssl x509 -noout -enddate -in "$CERT_FILE" | cut -d= -f2)
    EXPIRE_TS=$(date -d "$EXPIRE_DATE" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRE_DATE" +%s 2>/dev/null || echo "0")
    NOW_TS=$(date +%s)
    DAYS_LEFT=$(( (EXPIRE_TS - NOW_TS) / 86400 ))
    log "  SSL 证书剩余 ${DAYS_LEFT} 天（到期：${EXPIRE_DATE}）"
    if [[ $DAYS_LEFT -lt 14 ]]; then
        alert "ssl_expire" "🔐 SSL证书即将到期！剩余 ${DAYS_LEFT} 天，请立即续期！"
    elif [[ $DAYS_LEFT -lt 30 ]]; then
        alert "ssl_expire_warn" "⚠️ SSL证书将在 ${DAYS_LEFT} 天后到期"
    fi
else
    alert "ssl_missing" "⛔ SSL证书文件不存在！"
fi

# ── 7. 备份完整性检查 ─────────────────────────────────────────
log "[7] 备份检查..."
LATEST_BACKUP=$(find "${APP_DIR}/backups/db" -name "*.sql.gz" -mtime -1 2>/dev/null | head -1)
if [[ -n "$LATEST_BACKUP" ]]; then
    BACKUP_SIZE=$(du -sh "$LATEST_BACKUP" | cut -f1)
    log "  ✅ 最近24小时存在备份：${BACKUP_SIZE}"
else
    alert "backup_missing" "⚠️ 最近24小时内没有数据库备份！"
fi

# ── 汇总 ─────────────────────────────────────────────────────
log "══ 监控检查完成 ══"
if [[ $FAILED -gt 0 ]]; then
    log "❌ 发现 ${FAILED} 个异常，已发送告警"
    exit 1
else
    log "✅ 所有检查通过"
    exit 0
fi
