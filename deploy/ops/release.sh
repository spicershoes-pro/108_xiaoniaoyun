#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 标准化发布 & 回滚脚本
# 用法：bash deploy/ops/release.sh <deploy|rollback> [version]
# 示例：bash deploy/ops/release.sh deploy v1.2.0
#       bash deploy/ops/release.sh rollback v1.1.0
#       bash deploy/ops/release.sh rollback  （回滚到上一版本）
# ============================================================

set -euo pipefail

APP_DIR="/opt/xiaoniao"
VERSIONS_FILE="${APP_DIR}/config/.deploy-history"
LOG_FILE="/var/log/xiaoniao/release.log"

mkdir -p "$(dirname $LOG_FILE)"
touch "$VERSIONS_FILE"

ts()   { date '+%Y-%m-%d %H:%M:%S'; }
log()  { echo "[$(ts)] $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\033[0;32m[$(ts)] ✅ $*\033[0m" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[$(ts)] ⚠️  $*\033[0m" | tee -a "$LOG_FILE"; }
error(){ echo -e "\033[0;31m[$(ts)] ❌ $*\033[0m" | tee -a "$LOG_FILE"; exit 1; }

ACTION="${1:-}" ; VERSION="${2:-}"
[[ -z "$ACTION" ]] && { echo "用法：$0 <deploy|rollback> [version]"; exit 1; }

source "${APP_DIR}/config/prod.env"

# ── 发布函数 ─────────────────────────────────────────────────
do_deploy() {
    local version="${1:-$(date +v%Y%m%d-%H%M%S)}"
    log "══ 开始发布 [${version}] ══"

    # 1. 配置检查
    log "[1/6] 配置安全检查..."
    grep -q 'REPLACE_' "${APP_DIR}/config/prod.env" && \
        error "配置文件存在未替换占位符，禁止部署！"
    ok "配置检查通过"

    # 2. 记录当前版本（用于回滚）
    CURRENT_VERSION=$(tail -1 "$VERSIONS_FILE" | awk '{print $2}' || echo "unknown")
    echo "$(ts) ${version} deploy" >> "$VERSIONS_FILE"
    log "[2/6] 当前版本：${CURRENT_VERSION} → 目标版本：${version}"

    # 3. 拉取新镜像
    log "[3/6] 拉取镜像（${version}）..."
    export IMAGE_TAG="$version"
    docker compose -f "${APP_DIR}/docker-compose.prod.yml" pull || \
        error "镜像拉取失败：${version}"
    ok "镜像拉取完成"

    # 4. 部署前健康快照
    log "[4/6] 部署前健康检查..."
    PRE_HEALTH=$(curl -s http://localhost:8080/health 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['status'])" 2>/dev/null || echo "unknown")
    log "  部署前API状态：${PRE_HEALTH}"

    # 5. 滚动更新
    log "[5/6] 滚动更新..."

    # 先更新后端（最重要）
    log "  更新后端..."
    docker compose -f "${APP_DIR}/docker-compose.prod.yml" \
        up -d --no-deps --remove-orphans backend
    # 等待后端就绪（最多60秒）
    for i in $(seq 1 20); do
        sleep 3
        HEALTH=$(curl -s http://localhost:8080/health 2>/dev/null | grep -o '"status":"ok"' || echo "")
        [[ -n "$HEALTH" ]] && ok "后端就绪（${i}次检查）" && break
        [[ $i -eq 20 ]] && {
            warn "后端启动超时，自动回滚..."
            do_rollback "$CURRENT_VERSION"
            error "发布失败并已回滚到 ${CURRENT_VERSION}"
        }
    done

    # 更新前端（逐个，不影响后端服务）
    for app in buyer merchant admin; do
        log "  更新 frontend-${app}..."
        docker compose -f "${APP_DIR}/docker-compose.prod.yml" \
            up -d --no-deps "frontend-${app}"
        sleep 3
    done

    # 6. 全链路验证
    log "[6/6] 全链路验证..."
    declare -A CHECKS=(
        ["API"]="http://localhost:8080/health"
        ["Buyer"]="http://localhost:5173"
        ["Merchant"]="http://localhost:5174"
        ["Admin"]="http://localhost:5175"
    )
    FAIL_COUNT=0
    for name in "${!CHECKS[@]}"; do
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${CHECKS[$name]}" 2>/dev/null || echo "000")
        [[ "$code" =~ ^(200|301|302)$ ]] && ok "${name}: HTTP ${code}" || { warn "${name}: HTTP ${code}"; FAIL_COUNT=$((FAIL_COUNT+1)); }
    done

    if [[ $FAIL_COUNT -gt 1 ]]; then
        warn "多个服务验证失败（${FAIL_COUNT} 个），自动回滚..."
        do_rollback "$CURRENT_VERSION"
        error "发布失败已回滚"
    fi

    # 清理旧镜像
    docker image prune -f &>/dev/null || true

    ok "══ 发布 [${version}] 完成 ══"
    log "访问验证：curl https://api.xiaoniao.com/health"
}

# ── 回滚函数 ─────────────────────────────────────────────────
do_rollback() {
    local target_version="${1:-}"

    if [[ -z "$target_version" ]]; then
        # 自动获取上一个版本
        target_version=$(tail -2 "$VERSIONS_FILE" | head -1 | awk '{print $2}')
        [[ -z "$target_version" ]] && error "无可用版本历史，无法回滚"
    fi

    log "══ 开始回滚到 [${target_version}] ══"

    # 确认
    echo ""
    read -rp "确认回滚到版本 ${target_version}？(yes/no) " ans
    [[ "$ans" != "yes" ]] && echo "已取消" && exit 0

    export IMAGE_TAG="$target_version"
    docker compose -f "${APP_DIR}/docker-compose.prod.yml" pull 2>/dev/null || \
        warn "镜像拉取失败，使用本地缓存"

    docker compose -f "${APP_DIR}/docker-compose.prod.yml" \
        up -d --no-deps --remove-orphans backend

    sleep 10
    HEALTH=$(curl -s http://localhost:8080/health 2>/dev/null | grep -o '"status":"ok"' || echo "")
    [[ -z "$HEALTH" ]] && error "回滚后后端仍不可用！请手动检查"

    docker compose -f "${APP_DIR}/docker-compose.prod.yml" \
        up -d --no-deps frontend-buyer frontend-merchant frontend-admin

    echo "$(ts) ${target_version} rollback" >> "$VERSIONS_FILE"
    ok "══ 回滚到 [${target_version}] 完成 ══"
}

# ── 执行 ─────────────────────────────────────────────────────
case "$ACTION" in
    deploy)   do_deploy "$VERSION" ;;
    rollback) do_rollback "$VERSION" ;;
    history)
        log "发布历史："
        cat "$VERSIONS_FILE" | tail -20
        ;;
    *)
        echo "用法：$0 <deploy|rollback|history> [version]"
        exit 1
        ;;
esac
