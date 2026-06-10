# 霄鸟云 · 生产服务器部署手册

**文档编号：** XN-DEPLOY-201-11  
**版本：** v1.0.0  
**上游依据：** XN-ENV-201-09 · XN-DOCKER-201-10  
**状态：** 正式发布  
**适用范围：** 运维人员 · DevOps · 后端开发

---

## 第一部分：生产服务器部署手册

### 1.1 服务器规格要求

| 配置项 | 最低 | 推荐 | 说明 |
|--------|------|------|------|
| CPU | 2 核 | 4 核 | PHP-FPM 多进程，建议 ≥ 4 |
| 内存 | 4 GB | 8 GB | MySQL 2G + Redis 512M + PHP |
| 系统盘 | 40 GB | 80 GB | 系统 + Docker 镜像 |
| 数据盘 | 50 GB | 200 GB | 数据库持久化 + 用户上传 |
| 操作系统 | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS | — |
| 带宽 | 5 Mbps | 10+ Mbps | 按实际流量选择 |

### 1.2 域名规划

| 子域名 | 用途 | 容器端口 |
|--------|------|---------|
| `www.xiaoniao.com` | 用户端（buyer）| 5173 |
| `api.xiaoniao.com` | 后端 API | 8080 |
| `merchant.xiaoniao.com` | 商家后台 | 5174 |
| `admin.xiaoniao.com` | 管理后台 | 5175 |

### 1.3 DNS 解析配置

在域名服务商控制台（如阿里云/腾讯云），添加以下 A 记录：

```
类型    主机记录              记录值（服务器公网IP）   TTL
A       @（或 xiaoniao.com） 1.2.3.4                  600
A       www                  1.2.3.4                  600
A       api                  1.2.3.4                  600
A       merchant             1.2.3.4                  600
A       admin                1.2.3.4                  600
```

**验证 DNS 解析：**
```bash
dig +short www.xiaoniao.com A
dig +short api.xiaoniao.com A
# 应均返回服务器公网 IP
```

### 1.4 完整部署流程（步骤序号严格执行）

```
步骤 1：服务器初始化（安全加固）
步骤 2：安装 Nginx（宿主机）
步骤 3：申请 SSL 证书（Let's Encrypt）
步骤 4：上传项目文件
步骤 5：生产配置注入
步骤 6：启动容器服务
步骤 7：配置开机自启
步骤 8：全链路验证
步骤 9：配置定期备份
```

---

### 步骤 1：服务器初始化

```bash
# 以 root 登录服务器
ssh root@1.2.3.4

# 上传初始化脚本（或 git clone 项目）
scp -r deploy/scripts root@1.2.3.4:/tmp/xn-scripts/

# 执行初始化（约 5-10 分钟）
bash /tmp/xn-scripts/01-server-init.sh www

# 执行完毕后以 www 用户登录验证
ssh www@1.2.3.4
docker --version
docker compose version
```

**初始化完成后的服务器状态：**
- UFW 防火墙：仅 22/80/443 对外
- SSH：禁止 root 登录，禁止密码认证
- Fail2ban：防暴力破解（3次失败封禁24小时）
- Docker：已安装并配置日志轮转
- 系统内核参数已优化

---

### 步骤 2：安装 Nginx（宿主机层）

```bash
# 上传项目（包含 Nginx 配置）
git clone https://github.com/your-org/xiaoniao-php.git /opt/xiaoniao
cd /opt/xiaoniao

# 安装 Nginx
sudo bash deploy/scripts/02-install-nginx.sh

# 验证
nginx -v
systemctl status nginx
```

---

### 步骤 3：申请 SSL 证书

```bash
# 确认 DNS 已解析到本服务器（所有子域名）
for domain in www api merchant admin; do
  echo -n "${domain}.xiaoniao.com → "
  dig +short ${domain}.xiaoniao.com A
done

# 申请证书（需替换邮箱）
sudo SSL_EMAIL=ops@your-company.com \
  bash /opt/xiaoniao/deploy/scripts/03-ssl-cert.sh xiaoniao.com

# 验证证书
openssl x509 -noout -text -in /etc/letsencrypt/live/xiaoniao.com/fullchain.pem \
  | grep -E "Subject:|DNS:|Not After"
```

---

### 步骤 4：上传项目文件

```bash
# 方案A：通过 Git 部署（推荐）
cd /opt/xiaoniao
git pull origin main

# 方案B：通过 scp 上传
scp xiaoniao-php-final.tar.gz www@1.2.3.4:/opt/
ssh www@1.2.3.4
cd /opt && tar -xzf xiaoniao-php-final.tar.gz
mv xiaoniao-php xiaoniao
```

---

### 步骤 5：生产配置注入（关键步骤）

```bash
# 创建生产配置目录（权限严格限制）
sudo mkdir -p /opt/xiaoniao/config
sudo chown www:www /opt/xiaoniao/config
chmod 700 /opt/xiaoniao/config

# 创建生产配置文件
sudo -u www vim /opt/xiaoniao/config/prod.env

# 填写所有配置（参考 backend/config/env/.env.production）
# 必须替换所有 REPLACE_* 占位符！
```

**prod.env 最小必填项：**

```bash
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.xiaoniao.com

DB_HOST=db                           # 容器内部服务名
DB_NAME=xiaoniao_prod
DB_USER=xiaoniao_app
DB_PASS=你的强密码16位以上

MYSQL_ROOT_PASSWORD=Root的强密码

JWT_SECRET=$(openssl rand -hex 32)   # 64位随机字符串

SMS_PROVIDER=aliyun
SMS_ACCESS_KEY=你的阿里云AK
SMS_SECRET_KEY=你的阿里云SK
SMS_SIGN_NAME=霄鸟云
SMS_TEMPLATE_CODE=你的模板ID

CORS_ORIGINS=https://www.xiaoniao.com,https://merchant.xiaoniao.com,https://admin.xiaoniao.com

REDIS_PASS=Redis强密码

IMAGE_TAG=latest
```

**配置安全验证：**
```bash
# 确认无占位符
grep 'REPLACE_' /opt/xiaoniao/config/prod.env && echo "❌ 有未替换占位符" || echo "✅ 配置无占位符"

# 确认权限
ls -la /opt/xiaoniao/config/prod.env
# 应为：-rw------- 1 www www
```

---

### 步骤 6：启动容器服务

```bash
cd /opt/xiaoniao

# 加载配置并构建/拉取镜像
export $(grep -v '^#' config/prod.env | xargs)

# 方案A：使用预构建镜像（CI/CD 推送到私有仓库）
docker compose -f docker-compose.prod.yml pull

# 方案B：在服务器上构建镜像
bash docker/scripts/build.sh prod

# 启动所有服务
docker compose -f docker-compose.prod.yml up -d

# 查看启动状态（等待 30-60 秒）
docker compose -f docker-compose.prod.yml ps

# 查看日志确认无报错
docker compose -f docker-compose.prod.yml logs --tail=50 backend
docker compose -f docker-compose.prod.yml logs --tail=50 db
```

---

### 步骤 7：配置开机自启

```bash
# 安装 systemd 服务
sudo cp /opt/xiaoniao/deploy/systemd/xiaoniao.service /etc/systemd/system/

# 启用并启动
sudo systemctl daemon-reload
sudo systemctl enable xiaoniao.service
sudo systemctl start  xiaoniao.service

# 验证
sudo systemctl status xiaoniao.service
```

---

### 步骤 8：全链路验证

```bash
# 健康检查
curl -I https://www.xiaoniao.com       # 用户端
curl -I https://api.xiaoniao.com/health  # API
curl -I https://merchant.xiaoniao.com  # 商家端
curl -I https://admin.xiaoniao.com     # 管理端

# SSL 证书验证
echo | openssl s_client -connect www.xiaoniao.com:443 2>/dev/null \
  | openssl x509 -noout -dates

# API 接口测试
curl https://api.xiaoniao.com/api/banners

# 登录测试（需真实短信或mock模式）
curl -X POST https://api.xiaoniao.com/api/auth/send-code \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800000000","purpose":"login"}'
```

---

### 步骤 9：配置定期备份

```bash
# 安装备份定时任务
(crontab -u www -l 2>/dev/null; \
 echo "0 3 * * * bash /opt/xiaoniao/deploy/scripts/backup-db.sh >> /var/log/xiaoniao/backup.log 2>&1") \
| crontab -u www -

# 验证 Cron
crontab -u www -l
```

---

## 第二部分：Nginx 配置文档

### 2.1 架构层次

```
公网访问
    ↓ HTTPS（443）
宿主机 Nginx（反向代理 + SSL 终止）
    ├── www.xiaoniao.com      → proxy_pass 127.0.0.1:5173
    ├── api.xiaoniao.com      → proxy_pass 127.0.0.1:8080
    ├── merchant.xiaoniao.com → proxy_pass 127.0.0.1:5174
    └── admin.xiaoniao.com    → proxy_pass 127.0.0.1:5175
    ↓（内部网络，无 HTTPS）
容器 Nginx / PHP-FPM
    ├── :5173  前端buyer容器内Nginx（静态SPA）
    ├── :5174  前端merchant容器内Nginx
    ├── :5175  前端admin容器内Nginx
    └── :8080  API容器内Nginx → fastcgi_pass backend:9000（PHP-FPM）
```

### 2.2 配置文件清单

| 文件位置 | 作用 |
|---------|------|
| `/etc/nginx/nginx.conf` | 主配置（workers/gzip/ssl全局/限流zone）|
| `/etc/nginx/conf.d/buyer.conf` | 用户端站点（HTTPS+代理）|
| `/etc/nginx/conf.d/api.conf` | API站点（HTTPS+限流+安全过滤）|
| `/etc/nginx/conf.d/merchant-admin.conf` | 商家+管理端（HTTPS+代理）|
| `/etc/nginx/snippets/ssl-params.conf` | SSL 参数（TLS 1.2/1.3）|
| `/etc/nginx/snippets/security-headers.conf` | 安全响应头（CSP/HSTS等）|
| `/etc/nginx/snippets/acme-challenge.conf` | Let's Encrypt 验证路径 |

### 2.3 限流策略

| 限流 Zone | 速率 | 应用位置 | 说明 |
|-----------|------|---------|------|
| `login:10m` | 10次/分钟 | `/api/auth/login`、`/api/auth/send-code` | 防暴力破解 |
| `api:10m` | 120次/分钟 | `/api/*`（通用接口）| 防接口滥用 |
| `perip:10m` | 并发连接数 | 所有接口 | 防连接耗尽 |

**触发限流返回：**
```json
HTTP 429 Too Many Requests
{"code":-1,"msg":"请求过于频繁，请稍后重试","data":null}
```

### 2.4 Nginx 常用运维命令

```bash
# 测试配置
nginx -t

# 热重载（不中断请求）
systemctl reload nginx

# 完全重启（谨慎使用）
systemctl restart nginx

# 查看错误日志
tail -f /var/log/nginx/error.log

# 查看某站点访问日志
tail -f /var/log/nginx/api-access.log

# 统计 API 接口请求量（最近100行）
awk '{print $7}' /var/log/nginx/api-access.log | sort | uniq -c | sort -rn | head -20

# 查看状态码分布
awk '{print $9}' /var/log/nginx/api-access.log | sort | uniq -c | sort -rn
```

---

## 第三部分：HTTPS 证书运维指南

### 3.1 证书基本信息

| 项目 | 值 |
|------|-----|
| 证书类型 | Let's Encrypt DV 证书 |
| 有效期 | 90 天（Certbot 自动续期）|
| 私钥位置 | `/etc/letsencrypt/live/xiaoniao.com/privkey.pem` |
| 证书位置 | `/etc/letsencrypt/live/xiaoniao.com/fullchain.pem` |
| 自动续期 | 每日 02:30（Cron）|
| 续期阈值 | 到期前 30 天内触发续期 |

### 3.2 证书续期操作

```bash
# 测试续期（不实际执行）
certbot renew --dry-run

# 立即强制续期
certbot renew --force-renewal

# 续期后重载 Nginx
certbot renew --post-hook "nginx -s reload"

# 查看证书到期时间
openssl x509 -noout -enddate -in /etc/letsencrypt/live/xiaoniao.com/fullchain.pem

# 查看所有已申请证书
certbot certificates
```

### 3.3 证书自动续期验证

```bash
# 查看 Cron 任务
crontab -l | grep certbot

# 查看续期日志
cat /var/log/certbot-renew.log

# 手动触发测试
certbot renew --dry-run --quiet && echo "续期测试通过" || echo "续期测试失败"
```

### 3.4 SSL 安全评级

目标：**SSL Labs 评级 A+**

配置要点：
- ✅ 禁用 TLS 1.0 / 1.1（仅 1.2 / 1.3）
- ✅ 启用 HSTS（max-age=31536000；includeSubDomains；preload）
- ✅ 启用 OCSP Stapling
- ✅ 生成 2048 位 DH 参数
- ✅ 禁用不安全密码套件

**在线验证：** https://www.ssllabs.com/ssltest/analyze.html?d=www.xiaoniao.com

### 3.5 证书过期告警（可选）

```bash
# 添加证书过期监控（每天检查，30天内告警）
cat >> /etc/cron.daily/ssl-check << 'EOF'
#!/bin/bash
DOMAIN="xiaoniao.com"
CERT="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
DAYS_LEFT=$(( ($(date -d "$(openssl x509 -noout -enddate -in $CERT | cut -d= -f2)" +%s) - $(date +%s)) / 86400 ))
if [ $DAYS_LEFT -lt 30 ]; then
    echo "⚠️ SSL证书将在 ${DAYS_LEFT} 天后过期！域名：${DOMAIN}" \
    | mail -s "SSL证书过期警告" ops@xiaoniao.com
fi
EOF
chmod +x /etc/cron.daily/ssl-check
```

### 3.6 证书迁移/替换流程

```bash
# 1. 申请新证书（同域名自动覆盖）
certbot certonly --nginx -d xiaoniao.com -d www.xiaoniao.com \
  -d api.xiaoniao.com -d merchant.xiaoniao.com -d admin.xiaoniao.com

# 2. 测试 Nginx 配置
nginx -t

# 3. 热重载 Nginx（零停机）
systemctl reload nginx

# 4. 验证新证书
echo | openssl s_client -connect www.xiaoniao.com:443 2>/dev/null \
  | openssl x509 -noout -dates
```

---

## 第四部分：日常运维操作参考

### 4.1 快速状态检查

```bash
# 一键状态检查
echo "=== 容器状态 ===" && docker compose -f /opt/xiaoniao/docker-compose.prod.yml ps
echo "=== Nginx 状态 ===" && systemctl is-active nginx
echo "=== 磁盘使用 ===" && df -h /
echo "=== 内存使用 ===" && free -h
echo "=== 证书到期 ===" && openssl x509 -noout -enddate -in /etc/letsencrypt/live/xiaoniao.com/fullchain.pem
```

### 4.2 故障紧急处理

```bash
# 场景：后端服务不可用
docker compose -f /opt/xiaoniao/docker-compose.prod.yml restart backend
docker compose -f /opt/xiaoniao/docker-compose.prod.yml logs --tail=100 backend

# 场景：数据库连接失败
docker compose -f /opt/xiaoniao/docker-compose.prod.yml restart db
docker compose -f /opt/xiaoniao/docker-compose.prod.yml exec db mysqladmin status -u root -p

# 场景：Nginx 502
nginx -t && systemctl reload nginx
docker compose -f /opt/xiaoniao/docker-compose.prod.yml ps  # 检查容器是否运行

# 场景：磁盘满
docker system prune -f              # 清理停止的容器/镜像/网络
du -sh /var/lib/docker/volumes/*    # 查找大体积 volume
```

### 4.3 版本回滚

```bash
# 回滚到指定版本
cd /opt/xiaoniao
export IMAGE_TAG=20260516-v1.0.1   # 填写要回滚到的版本
export $(grep -v '^#' config/prod.env | xargs)
docker compose -f docker-compose.prod.yml up -d --no-deps backend
docker compose -f docker-compose.prod.yml up -d --no-deps frontend-buyer frontend-merchant frontend-admin
```

---

## 附录：部署文件清单

```
deploy/
├── scripts/
│   ├── 01-server-init.sh     # 服务器初始化（安全加固+Docker安装）
│   ├── 02-install-nginx.sh   # Nginx安装和配置
│   ├── 03-ssl-cert.sh        # Let's Encrypt证书申请+自动续期
│   ├── 04-deploy-app.sh      # 应用部署脚本（拉镜像+启容器+验证）
│   └── backup-db.sh          # 数据库定时备份
├── nginx/
│   ├── conf.d/
│   │   ├── buyer.conf        # 用户端Nginx配置
│   │   ├── api.conf          # API端Nginx配置（含限流）
│   │   └── merchant-admin.conf # 商家/管理端Nginx配置
│   └── snippets/
│       ├── ssl-params.conf   # SSL协议和密码套件
│       └── security-headers.conf # HTTP安全响应头
└── systemd/
    └── xiaoniao.service      # systemd服务（开机自启）
```

## 附录：快速参考命令

```bash
# 部署
bash deploy/scripts/04-deploy-app.sh v1.0.1

# 查看所有服务状态
docker compose -f /opt/xiaoniao/docker-compose.prod.yml ps

# 查看后端日志
docker compose -f /opt/xiaoniao/docker-compose.prod.yml logs -f backend

# 进入后端容器
docker compose -f /opt/xiaoniao/docker-compose.prod.yml exec backend sh

# 重载 Nginx
nginx -s reload

# 手动备份数据库
bash /opt/xiaoniao/deploy/scripts/backup-db.sh

# 测试证书续期
certbot renew --dry-run

# SSL 在线测评
# https://www.ssllabs.com/ssltest/analyze.html?d=www.xiaoniao.com
```

---

**文档结束**

| 项目 | 内容 |
|------|------|
| 文档编号 | XN-DEPLOY-201-11 |
| 版本 | v1.0.0 |
| 创建时间 | 2026-05-17 |
| 适用环境 | Ubuntu 22.04 + Docker + Let's Encrypt |
| 下游衔接 | CI/CD 自动化 / 多节点集群 / CDN 接入 |
