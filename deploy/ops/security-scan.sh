#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 安全自查脚本
# 用法：bash deploy/ops/security-scan.sh
# Cron：0 4 * * 0  bash /opt/xiaoniao/deploy/ops/security-scan.sh
# ============================================================

set -uo pipefail

APP_DIR="/opt/xiaoniao"
REPORT="/var/log/xiaoniao/security-$(date +%Y%m%d).log"
mkdir -p "$(dirname $REPORT)"

ts()   { date '+%Y-%m-%d %H:%M:%S'; }
log()  { echo "[$(ts)] $*" | tee -a "$REPORT"; }
ok()   { echo -e "\033[0;32m[$(ts)] ✅ $*\033[0m" | tee -a "$REPORT"; }
warn() { echo -e "\033[1;33m[$(ts)] ⚠️  $*\033[0m" | tee -a "$REPORT"; }
fail() { echo -e "\033[0;31m[$(ts)] ❌ $*\033[0m" | tee -a "$REPORT"; }

[[ -f "${APP_DIR}/config/prod.env" ]] && source "${APP_DIR}/config/prod.env" || true

log "════════════════════════════════════════════════════"
log " 霄鸟云安全自查报告  $(date '+%Y-%m-%d')"
log "════════════════════════════════════════════════════"

RISK=0

# ── 1. 端口开放检查 ───────────────────────────────────────────
log "[SEC-01] 端口开放检查..."
OPEN_PORTS=$(ss -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -n | uniq)
ALLOWED_PORTS="22 80 443 8080 5173 5174 5175 3306 6379"  # 容器端口本地可见

for port in $OPEN_PORTS; do
    if echo "$port" | grep -qE "^(22|80|443)$"; then
        ok "端口 ${port}：合规（必须对外）"
    elif echo "$port" | grep -qE "^(8080|5173|5174|5175)$"; then
        # 检查是否对外暴露（应该只绑定到 127.0.0.1）
        BIND=$(ss -tlnp | grep ":${port}" | awk '{print $4}' | head -1)
        echo "$BIND" | grep -q "127.0.0.1" && ok "端口 ${port}：仅本机（安全）" || \
            warn "端口 ${port}：可能对外暴露（${BIND}），建议检查防火墙"
    elif echo "$port" | grep -qE "^(3306|6379)$"; then
        BIND=$(ss -tlnp | grep ":${port}" | awk '{print $4}' | head -1)
        echo "$BIND" | grep -qE "^(127|0\.0\.0\.0)" && {
            fail "⚠️ 数据库/缓存端口 ${port} 可能对外暴露！（${BIND}）"
            RISK=$((RISK+1))
        } || ok "端口 ${port}：容器内部（安全）"
    else
        warn "未知端口开放：${port}"
    fi
done

# ── 2. SSH 安全配置检查 ───────────────────────────────────────
log "[SEC-02] SSH 安全配置..."
SSHD_CFG="/etc/ssh/sshd_config"
check_ssh() {
    local key="$1" expect="$2" desc="$3"
    val=$(grep "^${key}" "$SSHD_CFG" 2>/dev/null | awk '{print $2}')
    if [[ "$val" == "$expect" ]]; then
        ok "SSH ${desc}：${val}"
    else
        fail "SSH ${desc}：${val:-未配置}（期望：${expect}）"
        RISK=$((RISK+1))
    fi
}
check_ssh "PermitRootLogin"      "no"    "禁止root登录"
check_ssh "PasswordAuthentication" "no"  "禁止密码登录"
check_ssh "PermitEmptyPasswords" "no"    "禁止空密码"

# ── 3. 文件权限检查 ───────────────────────────────────────────
log "[SEC-03] 敏感文件权限检查..."
check_perm() {
    local file="$1" expect_max="$2"
    [[ -f "$file" ]] || { log "  文件不存在：${file}"; return; }
    PERM=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%p" "$file" 2>/dev/null | tail -c 4)
    if [[ ${PERM:-777} -le $expect_max ]]; then
        ok "${file}：权限 ${PERM}（≤${expect_max}）"
    else
        fail "${file}：权限 ${PERM} 过宽（应 ≤${expect_max}）"
        RISK=$((RISK+1))
    fi
}
check_perm "${APP_DIR}/config/prod.env"   600
check_perm "${APP_DIR}/config/.enc-keys"  600

# ── 4. 后端安全检查 ───────────────────────────────────────────
log "[SEC-04] 后端安全配置..."

# 检查生产 APP_DEBUG
APP_DEBUG_VAL=$(grep "^APP_DEBUG=" "${APP_DIR}/config/prod.env" 2>/dev/null | cut -d= -f2)
[[ "$APP_DEBUG_VAL" == "false" ]] && ok "APP_DEBUG=false" || { fail "APP_DEBUG=${APP_DEBUG_VAL}（生产必须 false）"; RISK=$((RISK+1)); }

# 检查万能码
UNIVERSAL_VAL=$(grep "^ALLOW_UNIVERSAL_CODE=" "${APP_DIR}/config/prod.env" 2>/dev/null | cut -d= -f2)
[[ "$UNIVERSAL_VAL" == "false" ]] && ok "ALLOW_UNIVERSAL_CODE=false" || { fail "万能验证码未关闭！"; RISK=$((RISK+1)); }

# 检查 JWT_SECRET 强度
JWT_LEN=$(grep "^JWT_SECRET=" "${APP_DIR}/config/prod.env" 2>/dev/null | cut -d= -f2 | wc -c)
[[ ${JWT_LEN:-0} -ge 32 ]] && ok "JWT_SECRET 长度：${JWT_LEN} 位（≥32）" || { fail "JWT_SECRET 过短！"; RISK=$((RISK+1)); }

# 检查 CORS_ORIGINS 不含 *
CORS_VAL=$(grep "^CORS_ORIGINS=" "${APP_DIR}/config/prod.env" 2>/dev/null | cut -d= -f2)
echo "$CORS_VAL" | grep -q '\*' && { fail "CORS_ORIGINS 包含 *（生产禁止）"; RISK=$((RISK+1)); } || ok "CORS_ORIGINS 配置合规"

# ── 5. 防火墙状态 ────────────────────────────────────────────
log "[SEC-05] 防火墙状态..."
UFW_STATUS=$(ufw status 2>/dev/null | head -1)
echo "$UFW_STATUS" | grep -q "active" && ok "UFW 防火墙运行中" || { fail "UFW 防火墙未激活！"; RISK=$((RISK+1)); }

# ── 6. Fail2ban 状态 ─────────────────────────────────────────
log "[SEC-06] Fail2ban 状态..."
F2B_STATUS=$(systemctl is-active fail2ban 2>/dev/null || echo "inactive")
[[ "$F2B_STATUS" == "active" ]] && ok "Fail2ban 运行中" || { fail "Fail2ban 未运行！"; RISK=$((RISK+1)); }

# ── 7. 可疑进程检查 ──────────────────────────────────────────
log "[SEC-07] 可疑进程/网络检查..."
# 检查高 CPU 进程（可能是挖矿）
HIGH_CPU=$(ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && $3>80 {print $11}' | head -5)
[[ -n "$HIGH_CPU" ]] && warn "高CPU进程：${HIGH_CPU}" || ok "无异常高CPU进程"

# 检查对外监听的非预期端口
LISTEN_PORTS=$(ss -tlnp 2>/dev/null | grep "0.0.0.0:" | awk '{print $4}' | cut -d: -f2 | sort -n)
SAFE_PORTS="22 80 443"
for p in $LISTEN_PORTS; do
    echo "$SAFE_PORTS" | grep -q "\b${p}\b" || warn "非预期对外端口：${p}"
done

# ── 8. 近期文件变动检查 ──────────────────────────────────────
log "[SEC-08] 关键文件变动（最近7天）..."
find "${APP_DIR}/backend" -name "*.php" -newer "${APP_DIR}/backend/public/index.php" \
    -not -path "*/vendor/*" 2>/dev/null | head -10 | while read -r f; do
    warn "最近修改的PHP文件：${f}"
done || ok "无异常PHP文件变动"

# ── 汇总 ─────────────────────────────────────────────────────
log ""
log "════════════════════════════════════════════════════"
if [[ $RISK -eq 0 ]]; then
    log "✅ 安全检查通过，风险项：0"
else
    log "❌ 发现 ${RISK} 个安全风险，请尽快处理！"
    log "   详细报告：${REPORT}"
fi
log "════════════════════════════════════════════════════"

# 发送告警
if [[ $RISK -gt 0 ]] && [[ -n "${WECHAT_WEBHOOK:-${DINGTALK_WEBHOOK:-}}" ]]; then
    WEBHOOK="${WECHAT_WEBHOOK:-${DINGTALK_WEBHOOK:-}}"
    curl -s -X POST "$WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"🔐 霄鸟云安全检查：发现 ${RISK} 个风险！\n$(date '+%Y-%m-%d')\n详见日志：${REPORT}\"}}" \
        &>/dev/null || true
fi

[[ $RISK -gt 0 ]] && exit 1 || exit 0
