#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 服务器初始化安全加固脚本
# 目标：Ubuntu 22.04 LTS
# 用法：sudo bash deploy/scripts/01-server-init.sh
# 执行时间：首次部署时运行一次
# ============================================================

set -euo pipefail

DEPLOY_USER="${1:-www}"           # 应用运行账号
APP_DIR="/opt/xiaoniao"           # 项目目录
LOG_DIR="/var/log/xiaoniao"       # 日志目录
SSH_PORT="${SSH_PORT:-22}"        # SSH 端口（建议改为非标准端口）

# ── 颜色输出 ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && error "请以 root 权限执行"

echo "══════════════════════════════════════════════════════"
echo "  霄鸟云 · 服务器初始化  $(date '+%Y-%m-%d %H:%M:%S')"
echo "══════════════════════════════════════════════════════"

# ── 1. 系统更新 ───────────────────────────────────────────────
info "1/10 系统更新..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
ok "系统更新完成"

# ── 2. 安装必要工具 ───────────────────────────────────────────
info "2/10 安装工具..."
apt-get install -y -qq \
    curl wget git vim \
    ufw fail2ban \
    htop iotop \
    net-tools lsof \
    openssl certbot python3-certbot-nginx \
    logrotate cron \
    jq unzip
ok "工具安装完成"

# ── 3. 创建应用用户（最小权限） ──────────────────────────────
info "3/10 创建应用用户 ${DEPLOY_USER}..."
if ! id "${DEPLOY_USER}" &>/dev/null; then
    useradd -m -s /bin/bash -G docker "${DEPLOY_USER}"
    ok "用户 ${DEPLOY_USER} 创建完成"
else
    usermod -aG docker "${DEPLOY_USER}"
    ok "用户 ${DEPLOY_USER} 已存在，已加入 docker 组"
fi

# ── 4. 创建目录结构 ───────────────────────────────────────────
info "4/10 创建目录结构..."
mkdir -p "${APP_DIR}"/{config,backups,ssl}
mkdir -p "${LOG_DIR}"/{nginx,php,app}
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${APP_DIR}"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${LOG_DIR}"
chmod 750 "${APP_DIR}"
chmod 700 "${APP_DIR}/config"   # 配置目录严格权限
ok "目录创建完成"

# ── 5. SSH 安全加固 ───────────────────────────────────────────
info "5/10 SSH 安全加固..."
SSHD_CFG="/etc/ssh/sshd_config"
cp "${SSHD_CFG}" "${SSHD_CFG}.bak.$(date +%Y%m%d)"

# 禁用 root 远程登录
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "${SSHD_CFG}"
# 禁用密码登录（需提前配置 SSH Key）
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "${SSHD_CFG}"
# 禁用空密码
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' "${SSHD_CFG}"
# 禁用 X11 转发
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "${SSHD_CFG}"
# 超时设置
grep -q "ClientAliveInterval" "${SSHD_CFG}" || echo "ClientAliveInterval 300" >> "${SSHD_CFG}"
grep -q "ClientAliveCountMax" "${SSHD_CFG}" || echo "ClientAliveCountMax 3" >> "${SSHD_CFG}"
# 最大认证尝试
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "${SSHD_CFG}"
# 禁用 DNS 反查（加速登录）
grep -q "UseDNS" "${SSHD_CFG}" || echo "UseDNS no" >> "${SSHD_CFG}"

systemctl reload sshd
ok "SSH 加固完成（root登录、密码登录已禁用）"
warn "⚠️  确保已配置 SSH Key 后再关闭 SSH，否则将无法登录！"

# ── 6. 防火墙配置（UFW） ─────────────────────────────────────
info "6/10 配置防火墙..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# 允许 SSH
ufw allow "${SSH_PORT}/tcp" comment "SSH"
# 允许 HTTP/HTTPS（Nginx 对外）
ufw allow 80/tcp   comment "HTTP"
ufw allow 443/tcp  comment "HTTPS"

# 容器服务端口仅允许本机访问（由 Nginx 代理）
# 不对外开放：3306(MySQL)、6379(Redis)、8080(API)、5173-5175(前端内部)

ufw --force enable
ok "防火墙配置完成（仅 SSH/HTTP/HTTPS 对外）"

# ── 7. Fail2ban 配置（防暴力破解） ───────────────────────────
info "7/10 配置 Fail2ban..."
cat > /etc/fail2ban/jail.local << 'F2B'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 86400

[nginx-http-auth]
enabled  = true

[nginx-botsearch]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 2
F2B
systemctl restart fail2ban
systemctl enable fail2ban
ok "Fail2ban 配置完成"

# ── 8. 系统内核参数优化 ──────────────────────────────────────
info "8/10 内核参数优化..."
cat >> /etc/sysctl.conf << 'SYSCTL'

# 霄鸟云生产优化
# 网络连接
net.core.somaxconn          = 65535
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout     = 15
net.ipv4.tcp_keepalive_time  = 300
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl  = 15
# 文件描述符
fs.file-max          = 1048576
# 内存
vm.swappiness        = 10
vm.dirty_ratio       = 60
vm.dirty_background_ratio = 10
# 时间戳（防 DDoS）
net.ipv4.tcp_timestamps = 0
SYSCTL
sysctl -p &>/dev/null
ok "内核参数优化完成"

# ── 9. 文件描述符限制 ────────────────────────────────────────
info "9/10 文件描述符限制..."
cat >> /etc/security/limits.conf << 'LIMITS'
# 霄鸟云生产配置
*    soft nofile 65535
*    hard nofile 65535
root soft nofile 65535
root hard nofile 65535
LIMITS
ok "文件描述符限制设置完成"

# ── 10. 安装 Docker ──────────────────────────────────────────
info "10/10 安装 Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker "${DEPLOY_USER}"
    systemctl enable docker
    systemctl start docker

    # Docker 守护进程配置
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'DAEMON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "5"
  },
  "live-restore": true,
  "default-ulimits": {
    "nofile": {
      "Hard": 65536,
      "Name": "nofile",
      "Soft": 65536
    }
  }
}
DAEMON
    systemctl reload docker
    ok "Docker 安装完成"
else
    ok "Docker 已安装：$(docker --version)"
fi

# ── 安装 Docker Compose V2 ────────────────────────────────────
COMPOSE_VER="2.27.0"
if ! docker compose version &>/dev/null; then
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/download/v${COMPOSE_VER}/docker-compose-linux-x86_64" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    ok "Docker Compose V2 安装完成"
else
    ok "Docker Compose 已安装：$(docker compose version)"
fi

# ── 完成 ─────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo -e "${GREEN}✅ 服务器初始化完成！${NC}"
echo ""
echo "下一步："
echo "  1. 安装 Nginx：bash deploy/scripts/02-install-nginx.sh"
echo "  2. 申请 SSL 证书：bash deploy/scripts/03-ssl-cert.sh"
echo "  3. 部署应用：bash deploy/scripts/04-deploy-app.sh"
echo "══════════════════════════════════════════════════════"
