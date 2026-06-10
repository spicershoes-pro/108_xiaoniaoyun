#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 应用部署脚本
# 用法：sudo -u www bash deploy/scripts/04-deploy-app.sh [tag]
# 功能：拉取最新镜像 → 注入生产配置 → 启动容器 → 健康检查
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

APP_DIR="/opt/xiaoniao"
IMAGE_TAG="${1:-latest}"
ENV_FILE="${APP_DIR}/config/prod.env"

echo "══════════════════════════════════════════════════════"
echo "  霄鸟云 · 生产部署  tag=${IMAGE_TAG}  $(date '+%Y-%m-%d %H:%M')"
echo "══════════════════════════════════════════════════════"

# ── 前置检查 ─────────────────────────────────────────────────
[[ -d "$APP_DIR" ]] || error "应用目录不存在：${APP_DIR}，请先执行 01-server-init.sh"
[[ -f "$ENV_FILE" ]] || error "生产配置不存在：${ENV_FILE}，请先创建并填写密钥"
command -v docker &>/dev/null || error "Docker 未安装"

# ── 配置安全检查 ─────────────────────────────────────────────
info "配置安全检查..."
if grep -q 'REPLACE_' "$ENV_FILE"; then
    error "配置文件存在未替换占位符！\n$(grep 'REPLACE_' ${ENV_FILE})"
fi
ok "配置安全检查通过"

# ── 加载生产配置 ─────────────────────────────────────────────
info "加载生产配置 ${ENV_FILE}..."
export $(grep -v '^#' "$ENV_FILE" | xargs)
export IMAGE_TAG

# ── 备份当前版本信息（用于回滚）────────────────────────────
BACKUP_FILE="${APP_DIR}/backups/deploy-$(date +%Y%m%d%H%M%S).log"
mkdir -p "${APP_DIR}/backups"
docker compose -f "${APP_DIR}/docker-compose.prod.yml" ps 2>/dev/null > "$BACKUP_FILE" || true
info "当前版本已备份到 ${BACKUP_FILE}"

# ── 拉取新镜像 ───────────────────────────────────────────────
info "拉取镜像（tag=${IMAGE_TAG}）..."
docker compose -f "${APP_DIR}/docker-compose.prod.yml" pull
ok "镜像拉取完成"

# ── 滚动更新后端（零停机）────────────────────────────────────
info "更新后端服务..."
docker compose -f "${APP_DIR}/docker-compose.prod.yml" \
    up -d --no-deps --remove-orphans backend

# 等待后端就绪（健康检查）
info "等待后端健康检查..."
MAX_WAIT=60
ELAPSED=0
until curl -sf http://localhost:8080/health >/dev/null 2>&1; do
    sleep 3
    ELAPSED=$((ELAPSED+3))
    [[ $ELAPSED -ge $MAX_WAIT ]] && error "后端启动超时（${MAX_WAIT}s），请检查日志：docker compose logs backend"
    echo -n "."
done
echo ""
ok "后端服务就绪"

# ── 更新前端服务 ─────────────────────────────────────────────
info "更新前端服务..."
for APP in buyer merchant admin; do
    docker compose -f "${APP_DIR}/docker-compose.prod.yml" \
        up -d --no-deps "frontend-${APP}"
    sleep 3
    ok "frontend-${APP} 更新完成"
done

# ── 更新 Nginx（API代理容器）─────────────────────────────────
docker compose -f "${APP_DIR}/docker-compose.prod.yml" \
    up -d --no-deps nginx-api

# ── 全链路健康检查 ───────────────────────────────────────────
info "全链路健康检查..."
declare -A CHECKS=(
    ["后端API"]="https://api.xiaoniao.com/health"
    ["用户端"]="https://www.xiaoniao.com"
    ["商家端"]="https://merchant.xiaoniao.com"
    ["管理端"]="https://admin.xiaoniao.com"
)

FAILED=0
for name in "${!CHECKS[@]}"; do
    url="${CHECKS[$name]}"
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
    if [[ "$http_code" =~ ^(200|301|302|304)$ ]]; then
        ok "${name}（${url}）→ HTTP ${http_code}"
    else
        warn "${name}（${url}）→ HTTP ${http_code} ⚠️"
        FAILED=$((FAILED+1))
    fi
done

# ── 清理旧镜像（节省磁盘）────────────────────────────────────
info "清理旧镜像..."
docker image prune -f &>/dev/null || true

# ── 输出部署摘要 ─────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ 部署完成！所有服务正常${NC}"
else
    echo -e "${YELLOW}⚠️  部署完成，但有 ${FAILED} 个健康检查失败，请排查${NC}"
fi
echo ""
echo "镜像版本：${IMAGE_TAG}"
echo "部署时间：$(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "服务状态："
docker compose -f "${APP_DIR}/docker-compose.prod.yml" ps
echo "══════════════════════════════════════════════════════"
