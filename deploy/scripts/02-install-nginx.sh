#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · Nginx 安装与基础配置脚本
# 用法：sudo bash deploy/scripts/02-install-nginx.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }

[[ $EUID -ne 0 ]] && echo "请以 root 权限执行" && exit 1

APP_DIR="/opt/xiaoniao"

info "安装 Nginx..."
apt-get install -y -qq nginx
systemctl enable nginx
ok "Nginx 安装完成：$(nginx -v 2>&1)"

info "备份默认配置..."
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

info "写入优化后的 nginx.conf..."
cat > /etc/nginx/nginx.conf << 'NGINXCONF'
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections  4096;
    use                 epoll;
    multi_accept        on;
}

http {
    # ── 基础 ──────────────────────────────────────────────────
    include       mime.types;
    default_type  application/octet-stream;
    charset       utf-8;
    server_tokens off;

    # ── 性能 ──────────────────────────────────────────────────
    sendfile           on;
    tcp_nopush         on;
    tcp_nodelay        on;
    keepalive_timeout  65;
    keepalive_requests 1000;

    # ── 缓冲 ──────────────────────────────────────────────────
    client_max_body_size     12M;
    client_body_buffer_size  128k;
    client_header_buffer_size 4k;
    large_client_header_buffers 4 16k;

    # ── Gzip ──────────────────────────────────────────────────
    gzip              on;
    gzip_vary         on;
    gzip_proxied      any;
    gzip_comp_level   6;
    gzip_min_length   1024;
    gzip_types
        text/plain text/css text/xml text/javascript
        application/javascript application/json application/xml
        application/rss+xml application/atom+xml
        image/svg+xml font/woff font/woff2;

    # ── SSL 全局设置 ──────────────────────────────────────────
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    ssl_stapling        on;
    ssl_stapling_verify on;
    resolver            8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout    5s;

    # ── 日志 ──────────────────────────────────────────────────
    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    'rt=$request_time';
    access_log  /var/log/nginx/access.log main;
    error_log   /var/log/nginx/error.log warn;

    # ── 限流（全局，防 DDoS） ─────────────────────────────────
    limit_req_zone $binary_remote_addr zone=api:10m    rate=120r/m;
    limit_req_zone $binary_remote_addr zone=login:10m  rate=10r/m;
    limit_conn_zone $binary_remote_addr zone=perip:10m;

    # ── 包含各站点配置 ────────────────────────────────────────
    include /etc/nginx/conf.d/*.conf;
}
NGINXCONF

info "复制站点配置文件..."
cp "${APP_DIR}/deploy/nginx/conf.d/"*.conf /etc/nginx/conf.d/ 2>/dev/null || true
cp "${APP_DIR}/deploy/nginx/snippets/"*.conf /etc/nginx/snippets/ 2>/dev/null || true

info "测试 Nginx 配置..."
nginx -t && ok "Nginx 配置测试通过"

systemctl reload nginx
ok "Nginx 重载完成"
echo ""
echo "✅ Nginx 安装配置完成！"
echo "   下一步：bash deploy/scripts/03-ssl-cert.sh"
