#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · SSL 证书申请与自动续期脚本
# 方案：Let's Encrypt（Certbot）免费 SSL，90天自动续期
# 用法：sudo bash deploy/scripts/03-ssl-cert.sh [domain]
# 前置：域名 DNS 已解析到本服务器，Nginx 已启动并放行 80
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && error "请以 root 权限执行"

# ── 配置域名 ─────────────────────────────────────────────────
BASE_DOMAIN="${1:-xiaoniao.com}"
EMAIL="${SSL_EMAIL:-ops@xiaoniao.com}"

DOMAINS=(
    "${BASE_DOMAIN}"
    "www.${BASE_DOMAIN}"
    "api.${BASE_DOMAIN}"
    "merchant.${BASE_DOMAIN}"
    "admin.${BASE_DOMAIN}"
)

echo "══════════════════════════════════════════════════════"
echo "  霄鸟云 · SSL 证书申请"
echo "  主域名：${BASE_DOMAIN}"
echo "  邮箱：${EMAIL}"
echo "══════════════════════════════════════════════════════"

# ── 1. 检查 Certbot ──────────────────────────────────────────
if ! command -v certbot &>/dev/null; then
    info "安装 Certbot..."
    apt-get install -y certbot python3-certbot-nginx
    ok "Certbot 安装完成"
fi

# ── 2. DNS 连通性预检 ─────────────────────────────────────────
info "验证域名 DNS 解析..."
SERVER_IP=$(curl -s4 ifconfig.me 2>/dev/null || echo "")
if [[ -z "$SERVER_IP" ]]; then
    warn "无法获取服务器公网IP，跳过DNS验证"
else
    for domain in "${DOMAINS[@]}"; do
        resolved_ip=$(dig +short "${domain}" A 2>/dev/null | head -1 || echo "")
        if [[ "$resolved_ip" == "$SERVER_IP" ]]; then
            ok "${domain} → ${resolved_ip} ✓"
        else
            warn "${domain} 解析IP(${resolved_ip:-未解析}) ≠ 服务器IP(${SERVER_IP})"
            warn "请确认 DNS 记录正确，否则证书申请会失败"
        fi
    done
fi

# ── 3. 申请 Let's Encrypt 泛域名证书（推荐）────────────────────
# 方案A：泛域名证书（需 DNS 插件验证，推荐）
# 需要 DNS 服务商支持，这里使用 --manual 方式或单域名方式

# 方案B：逐个申请（HTTP-01 验证，无需DNS插件，更简单）
info "申请 SSL 证书..."

# 先为各域名临时配置 HTTP 验证 location
# 确保 Nginx 有 /.well-known/acme-challenge/ 路由
if [[ ! -f "/etc/nginx/snippets/acme-challenge.conf" ]]; then
    cat > /etc/nginx/snippets/acme-challenge.conf << 'ACME'
location ^~ /.well-known/acme-challenge/ {
    default_type "text/plain";
    root /var/www/certbot;
    allow all;
}
ACME
fi
mkdir -p /var/www/certbot

# 构建域名参数
DOMAIN_ARGS=""
for domain in "${DOMAINS[@]}"; do
    DOMAIN_ARGS="${DOMAIN_ARGS} -d ${domain}"
done

# 申请证书
certbot certonly \
    --nginx \
    --non-interactive \
    --agree-tos \
    --email "${EMAIL}" \
    --redirect \
    ${DOMAIN_ARGS} \
    --cert-name "${BASE_DOMAIN}"

ok "SSL 证书申请成功！"

# ── 4. 验证证书文件 ───────────────────────────────────────────
CERT_PATH="/etc/letsencrypt/live/${BASE_DOMAIN}"
if [[ -f "${CERT_PATH}/fullchain.pem" && -f "${CERT_PATH}/privkey.pem" ]]; then
    EXPIRE=$(openssl x509 -noout -enddate -in "${CERT_PATH}/fullchain.pem" | cut -d= -f2)
    ok "证书文件：${CERT_PATH}"
    ok "有效期至：${EXPIRE}"
else
    error "证书文件不存在，申请可能失败"
fi

# ── 5. 生成 DH 参数（增强安全性，耗时约1-2分钟） ──────────────
DH_FILE="/etc/nginx/ssl/dhparam.pem"
if [[ ! -f "$DH_FILE" ]]; then
    info "生成 DH 参数（需要约1-2分钟）..."
    mkdir -p /etc/nginx/ssl
    openssl dhparam -out "$DH_FILE" 2048
    chmod 644 "$DH_FILE"
    ok "DH 参数生成完成"
fi

# ── 6. 配置自动续期 ───────────────────────────────────────────
info "配置证书自动续期..."

# 测试续期
certbot renew --dry-run --quiet
ok "证书续期测试通过"

# 设置 Cron 定时任务（每天 2:30 检查并续期）
CRON_JOB="30 2 * * * certbot renew --quiet --nginx --post-hook 'nginx -s reload' >> /var/log/certbot-renew.log 2>&1"
(crontab -l 2>/dev/null | grep -v certbot; echo "${CRON_JOB}") | crontab -
ok "自动续期 Cron 已设置（每日 02:30 执行）"

# ── 7. 更新 Nginx 配置（启用 HTTPS） ─────────────────────────
info "重载 Nginx 应用 HTTPS 配置..."
nginx -t && systemctl reload nginx
ok "Nginx 已应用 HTTPS 配置"

echo ""
echo "══════════════════════════════════════════════════════"
echo -e "${GREEN}✅ SSL 证书部署完成！${NC}"
echo ""
echo "证书位置：${CERT_PATH}/"
echo "  fullchain.pem  — 证书链"
echo "  privkey.pem    — 私钥"
echo "  chain.pem      — 中间证书"
echo ""
echo "验证 HTTPS："
for domain in "${DOMAINS[@]}"; do
    echo "  curl -I https://${domain}"
done
echo ""
echo "下一步：bash deploy/scripts/04-deploy-app.sh"
echo "══════════════════════════════════════════════════════"
