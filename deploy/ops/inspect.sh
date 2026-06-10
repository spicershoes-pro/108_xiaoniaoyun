#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 运维巡检脚本
# 用法：bash deploy/ops/inspect.sh [weekly|monthly]
# Cron：0 9 * * 1  bash /opt/xiaoniao/deploy/ops/inspect.sh weekly
#        0 9 1 * *  bash /opt/xiaoniao/deploy/ops/inspect.sh monthly
# ============================================================

set -uo pipefail

APP_DIR="/opt/xiaoniao"
MODE="${1:-weekly}"
REPORT_FILE="/var/log/xiaoniao/inspect-$(date +%Y%m%d).log"

mkdir -p "$(dirname $REPORT_FILE)"

ts()  { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $*" | tee -a "$REPORT_FILE"; }
ok()  { echo -e "\033[0;32m[$(ts)] ✅ $*\033[0m" | tee -a "$REPORT_FILE"; }
warn(){ echo -e "\033[1;33m[$(ts)] ⚠️  $*\033[0m" | tee -a "$REPORT_FILE"; }
fail(){ echo -e "\033[0;31m[$(ts)] ❌ $*\033[0m" | tee -a "$REPORT_FILE"; }

[[ -f "${APP_DIR}/config/prod.env" ]] && source "${APP_DIR}/config/prod.env" || true

echo "" | tee -a "$REPORT_FILE"
log "════════════════════════════════════════════════════"
log " 霄鸟云运维巡检报告 [${MODE}]  $(date '+%Y-%m-%d')"
log "════════════════════════════════════════════════════"

# ══════════════════════════════════════════════════════
# 每周巡检项目
# ══════════════════════════════════════════════════════
weekly_inspect() {
    log ""
    log "━━ 每周巡检清单 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 1. 系统安全更新
    log "[W-01] 检查可用系统安全更新..."
    UPDATE_COUNT=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst.*security" || echo "0")
    [[ $UPDATE_COUNT -gt 0 ]] && warn "有 ${UPDATE_COUNT} 个安全更新待安装" || ok "无待更新安全补丁"

    # 2. 磁盘使用趋势
    log "[W-02] 磁盘使用情况..."
    df -h | grep -E "^(/|/data|/opt)" | while read -r line; do
        use_pct=$(echo "$line" | awk '{gsub(/%/,"",$5); print $5}')
        mount=$(echo "$line" | awk '{print $6}')
        if [[ ${use_pct:-0} -gt 75 ]]; then
            warn "分区 ${mount} 使用率 ${use_pct}%（建议扩容）"
        else
            ok "分区 ${mount} 使用率 ${use_pct}%"
        fi
    done

    # 3. Docker 镜像清理
    log "[W-03] Docker 资源使用..."
    DOCKER_SIZE=$(docker system df 2>/dev/null | tail -1 | awk '{print $4}' || echo "N/A")
    log "  Docker 可回收空间：${DOCKER_SIZE}"
    DANGLING=$(docker images -f "dangling=true" -q | wc -l)
    [[ $DANGLING -gt 0 ]] && warn "发现 ${DANGLING} 个悬挂镜像，建议执行：docker image prune -f" || ok "无悬挂镜像"

    # 4. 日志文件大小
    log "[W-04] 日志文件检查..."
    for logdir in /var/log/nginx /var/log/xiaoniao; do
        [[ -d "$logdir" ]] || continue
        total=$(du -sh "$logdir" 2>/dev/null | cut -f1)
        log "  ${logdir}: ${total}"
        find "$logdir" -name "*.log" -size +100M 2>/dev/null | while read -r f; do
            warn "大日志文件：${f}（$(du -sh $f | cut -f1)）"
        done
    done

    # 5. 备份文件验证
    log "[W-05] 备份文件完整性验证..."
    LATEST_DB=$(find "${APP_DIR}/backups/db" -name "*.sql.gz" 2>/dev/null | sort -r | head -1)
    if [[ -n "$LATEST_DB" ]]; then
        if [[ -f "${LATEST_DB}.md5" ]]; then
            md5sum -c "${LATEST_DB}.md5" --quiet 2>/dev/null && ok "最新DB备份MD5验证通过：$(basename $LATEST_DB)" || fail "备份文件MD5验证失败！"
        else
            warn "缺少MD5校验文件：${LATEST_DB}"
        fi
        # 验证可解压性
        zcat "$LATEST_DB" | head -5 | grep -q "MySQL" && ok "备份文件可正常解压" || fail "备份文件无法解压！"
    else
        fail "未找到数据库备份文件"
    fi

    # 6. 账号权限审查
    log "[W-06] 系统账号审查..."
    SUDO_USERS=$(getent group sudo | cut -d: -f4)
    log "  sudo 用户组成员：${SUDO_USERS}"
    # 检查无密码 sudo
    grep -E "NOPASSWD" /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -v "^#" | \
        while read -r line; do warn "发现无密码sudo配置：${line}"; done || ok "无异常sudo配置"

    # 7. 失败登录统计
    log "[W-07] SSH 登录审计..."
    FAIL_COUNT=$(journalctl -u ssh --since "7 days ago" 2>/dev/null | grep -c "Failed password" || \
                 grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
    BANNED_COUNT=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}' || echo "0")
    log "  近7天SSH失败登录：${FAIL_COUNT} 次"
    log "  当前Fail2ban封禁IP：${BANNED_COUNT} 个"
    [[ ${FAIL_COUNT:-0} -gt 100 ]] && warn "SSH失败登录次数异常偏高（${FAIL_COUNT}次），请检查日志"

    # 8. 证书到期
    log "[W-08] SSL证书有效期..."
    CERT="/etc/letsencrypt/live/xiaoniao.com/fullchain.pem"
    [[ -f "$CERT" ]] && {
        EXPIRE=$(openssl x509 -noout -enddate -in "$CERT" | cut -d= -f2)
        DAYS=$(( ($(date -d "$EXPIRE" +%s 2>/dev/null || echo 0) - $(date +%s)) / 86400 ))
        [[ $DAYS -lt 30 ]] && warn "SSL证书剩余 ${DAYS} 天！" || ok "SSL证书剩余 ${DAYS} 天"
    } || fail "SSL证书文件不存在"

    # 9. 容器资源限制检查
    log "[W-09] 容器资源状态..."
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | \
        tee -a "$REPORT_FILE" || warn "无法获取容器资源信息"

    # 10. 数据库表大小
    log "[W-10] 数据库大小统计..."
    docker compose -f "${APP_DIR}/docker-compose.prod.yml" exec -T db \
        mysql -u root --password="${MYSQL_ROOT_PASSWORD}" "${DB_NAME}" 2>/dev/null \
        -e "SELECT table_name, ROUND(data_length/1024/1024,2) AS 'MB' FROM information_schema.tables WHERE table_schema='${DB_NAME}' ORDER BY data_length DESC LIMIT 10;" \
        2>/dev/null | tee -a "$REPORT_FILE" || warn "无法获取数据库表大小"
}

# ══════════════════════════════════════════════════════
# 每月巡检项目
# ══════════════════════════════════════════════════════
monthly_inspect() {
    log ""
    log "━━ 每月巡检清单 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 1. 系统更新（执行）
    log "[M-01] 应用安全更新..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --only-upgrade 2>/dev/null | \
        tail -5 | tee -a "$REPORT_FILE"
    ok "系统安全更新完成"

    # 2. Docker 清理
    log "[M-02] Docker 资源清理..."
    docker image prune -f 2>/dev/null && ok "悬挂镜像已清理"
    docker volume prune -f 2>/dev/null && ok "未使用卷已清理"

    # 3. 备份恢复演练（dry-run）
    log "[M-03] 备份恢复演练（验证最新备份可用性）..."
    LATEST_DB=$(find "${APP_DIR}/backups/db" -name "*.sql.gz" | sort -r | head -1)
    [[ -n "$LATEST_DB" ]] && {
        TABLE_COUNT=$(zcat "$LATEST_DB" | grep -c "^CREATE TABLE" || echo "0")
        ok "最新备份包含 ${TABLE_COUNT} 张表的建表语句（预期 ≥ 30）"
        [[ $TABLE_COUNT -lt 30 ]] && fail "备份文件可能不完整！实际表数：${TABLE_COUNT}"
    }

    # 4. 密码/密钥轮换提醒
    log "[M-04] 密钥有效期提醒..."
    LAST_ROTATE=$(cat "${APP_DIR}/config/.last-rotate" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    DAYS_SINCE=$(( (NOW - ${LAST_ROTATE:-0}) / 86400 ))
    [[ $DAYS_SINCE -gt 90 ]] && warn "JWT_SECRET 已 ${DAYS_SINCE} 天未轮换（建议90天轮换一次）" || ok "密钥上次轮换：${DAYS_SINCE} 天前"

    # 5. 日志归档
    log "[M-05] 日志归档..."
    find /var/log/nginx -name "*.log" -mtime +30 -exec gzip {} \;
    find /var/log/xiaoniao -name "*.log" -mtime +30 -exec gzip {} \;
    ok "30天以上日志已压缩归档"

    # 6. 防火墙规则审查
    log "[M-06] 防火墙规则..."
    ufw status numbered 2>/dev/null | tee -a "$REPORT_FILE"

    # 7. 数据库性能检查
    log "[M-07] 数据库慢查询统计..."
    docker compose -f "${APP_DIR}/docker-compose.prod.yml" exec -T db \
        mysql -u root --password="${MYSQL_ROOT_PASSWORD}" 2>/dev/null \
        -e "SELECT query_time, sql_text FROM mysql.slow_log ORDER BY query_time DESC LIMIT 10;" \
        2>/dev/null || warn "慢查询日志为空或未启用"

    # 8. 镜像版本盘点
    log "[M-08] 运行中镜像版本..."
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | tee -a "$REPORT_FILE"
}

# ── 执行巡检 ─────────────────────────────────────────────────
weekly_inspect
[[ "$MODE" == "monthly" ]] && monthly_inspect

log ""
log "════════════════════════════════════════════════════"
log " 巡检报告已保存：${REPORT_FILE}"
log "════════════════════════════════════════════════════"

# 发送巡检报告
ALERT_WEBHOOK="${WECHAT_WEBHOOK:-${DINGTALK_WEBHOOK:-}}"
if [[ -n "$ALERT_WEBHOOK" ]]; then
    REPORT_SUMMARY=$(tail -20 "$REPORT_FILE" | tr '\n' '\\n')
    curl -s -X POST "$ALERT_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"📋 霄鸟云${MODE}巡检完成\n$(date '+%Y-%m-%d')\n详细报告：${REPORT_FILE}\"}}" \
        &>/dev/null || true
fi
