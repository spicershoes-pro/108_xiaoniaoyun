# 霄鸟云 · 运维闭环规范文档集

**文档编号：** XN-OPS-201-12  
**版本：** v1.0.0  
**状态：** 正式发布 · 全流程终态归档  
**上游依据：** XN-STD-201-01 ～ XN-DEPLOY-201-11  
**适用范围：** 运维 · DevOps · 技术负责人

---

> 本文档集包含五个子文档：
> - 第一部分：生产运维规范
> - 第二部分：数据备份与恢复手册
> - 第三部分：安全管控策略
> - 第四部分：监控告警说明
> - 第五部分：应急处置指南

---

## 第一部分：生产运维规范

### 1.1 运维责任矩阵

| 职责 | 负责人 | 频率 | 说明 |
|------|--------|------|------|
| 日常服务监控 | 值班运维 | 持续（5分钟一次）| 自动化脚本 |
| 周巡检 | DevOps | 每周一 09:00 | inspect.sh weekly |
| 月巡检 | 技术负责人 | 每月1日 09:00 | inspect.sh monthly |
| 安全扫描 | 运维 | 每周日 04:00 | security-scan.sh |
| 数据库备份 | 自动化 | 每日 03:00 | backup-full.sh |
| 证书续期检查 | 自动化 | 每日 02:30 | Certbot Cron |
| 生产发布 | 技术负责人审批 | 按需 | release.sh deploy |
| 密钥轮换 | 技术负责人 | 每90天 | gen-jwt-secret.sh |

### 1.2 Cron 任务完整清单

```bash
# 以 www 用户身份配置
crontab -u www -e

# 内容如下：
# ────────────────────────────────────────────────────────────────────────
# 每5分钟：服务监控（静默模式）
*/5 * * * *  bash /opt/xiaoniao/deploy/ops/monitor.sh --quiet

# 每日03:00：全量备份（含OSS上传）
0 3 * * *  bash /opt/xiaoniao/deploy/ops/backup-full.sh --upload-oss >> /var/log/xiaoniao/backup.log 2>&1

# 每周一09:00：周巡检
0 9 * * 1  bash /opt/xiaoniao/deploy/ops/inspect.sh weekly >> /var/log/xiaoniao/inspect.log 2>&1

# 每月1日09:00：月巡检
0 9 1 * *  bash /opt/xiaoniao/deploy/ops/inspect.sh monthly >> /var/log/xiaoniao/inspect.log 2>&1

# 每周日04:00：安全扫描
0 4 * * 0  bash /opt/xiaoniao/deploy/ops/security-scan.sh >> /var/log/xiaoniao/security.log 2>&1

# 每日02:30：SSL证书续期（root身份）
30 2 * * *  certbot renew --quiet --nginx --post-hook "nginx -s reload" >> /var/log/certbot-renew.log 2>&1
```

### 1.3 服务器目录规范

```
/opt/xiaoniao/                     # 项目根目录
├── docker-compose.prod.yml        # 生产编排文件
├── config/
│   ├── prod.env                   # 生产密钥（权限600，不提交Git）
│   ├── .deploy-history            # 发布版本历史
│   ├── .last-rotate               # 密钥轮换时间记录
│   └── .enc-keys                  # 加密配置密码（权限600）
├── backups/
│   ├── db/                        # 数据库备份（.sql.gz + .md5）
│   ├── files/                     # 上传文件备份
│   ├── config/                    # 配置快照
│   └── logs/                      # 备份日志
├── deploy/
│   ├── ops/                       # 运维脚本
│   └── ...
└── logs/ → /var/log/xiaoniao/     # 软链接到日志目录

/var/log/xiaoniao/                 # 应用日志目录
├── monitor.log                    # 监控日志（5分钟滚动）
├── backup.log                     # 备份任务日志
├── inspect-YYYYMMDD.log           # 巡检报告
├── security-YYYYMMDD.log          # 安全扫描报告
└── release.log                    # 发布历史日志
```

### 1.4 版本发布标准流程

```
发布前：
  □ 代码已通过 CI 自动化测试
  □ 镜像已构建并推送到镜像仓库
  □ 数据库迁移脚本已准备（如有）
  □ 回滚方案已确认
  □ 技术负责人已审批

发布操作：
  bash /opt/xiaoniao/deploy/ops/release.sh deploy v1.2.0

发布后验证（10分钟内）：
  □ curl https://api.xiaoniao.com/health 返回 {"status":"ok"}
  □ 登录各端界面验证核心功能
  □ 查看 docker compose logs --tail=100 无异常错误
  □ 监控脚本无告警
```

### 1.5 密钥轮换操作规范

```bash
# JWT Secret 轮换（每90天，业务低峰执行）
# ⚠️ 轮换后所有在线 Token 立即失效，用户需重新登录

# 1. 生成新密钥
NEW_SECRET=$(openssl rand -hex 32)
echo "新JWT_SECRET：${NEW_SECRET}"

# 2. 更新配置文件
sed -i "s/^JWT_SECRET=.*/JWT_SECRET=${NEW_SECRET}/" /opt/xiaoniao/config/prod.env

# 3. 滚动重启后端容器（零停机）
docker compose -f /opt/xiaoniao/docker-compose.prod.yml \
    up -d --no-deps backend

# 4. 记录轮换时间
date +%s > /opt/xiaoniao/config/.last-rotate
echo "JWT_SECRET 轮换完成：$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/xiaoniao/release.log
```

---

## 第二部分：数据备份与恢复手册

### 2.1 备份策略总览

| 备份类型 | 频率 | 保留期 | 存储位置 | 加密 |
|---------|------|--------|---------|------|
| 数据库全量 | 每日 03:00 | 30天 | 本地+OSS | gzip压缩 |
| 用户上传文件 | 每日 03:00 | 14天 | 本地+OSS | gzip压缩 |
| 生产配置快照 | 每日 03:00 | 90天 | 本地 | AES-256加密 |
| 容器镜像 | 每次发布 | 5个版本 | 镜像仓库 | — |

### 2.2 备份文件命名规范

```
数据库：  xiaoniao_db_{YYYYMMDD}_{HHMMSS}.sql.gz
文件：    uploads_{YYYYMMDD}_{HHMMSS}.tar.gz
配置：    config_snapshot_{YYYYMMDD}_{HHMMSS}.tar.gz
校验：    {文件名}.md5
```

### 2.3 备份完整性验证

```bash
# 验证备份文件 MD5
md5sum -c /opt/xiaoniao/backups/db/xiaoniao_db_20260517_030001.sql.gz.md5

# 验证备份内容可读（首行包含 MySQL dump 标识）
zcat /opt/xiaoniao/backups/db/xiaoniao_db_20260517_030001.sql.gz | head -5

# 统计备份文件包含的表数
zcat /opt/xiaoniao/backups/db/xiaoniao_db_20260517_030001.sql.gz | \
    grep -c "^CREATE TABLE"
# 预期：33（对应 schema.sql 中的 33 张表）
```

### 2.4 数据恢复操作

#### 场景A：整库恢复

```bash
# ⚠️ 危险操作！会覆盖现有数据
# 自动恢复（选择最新备份）
bash /opt/xiaoniao/deploy/ops/restore.sh db

# 指定备份文件恢复
bash /opt/xiaoniao/deploy/ops/restore.sh db \
    /opt/xiaoniao/backups/db/xiaoniao_db_20260517_030001.sql.gz
```

#### 场景B：单表/部分数据恢复

```bash
# 从备份中提取单表
zcat /opt/xiaoniao/backups/db/xiaoniao_db_20260517_030001.sql.gz | \
    sed -n '/^-- Table structure for table `orders`/,/^-- Table structure for/p' | \
    head -n -2 > /tmp/orders_restore.sql

# 导入单表
docker compose -f /opt/xiaoniao/docker-compose.prod.yml exec -T db \
    mysql -u root --password="${MYSQL_ROOT_PASSWORD}" "${DB_NAME}" \
    < /tmp/orders_restore.sql
```

#### 场景C：上传文件恢复

```bash
bash /opt/xiaoniao/deploy/ops/restore.sh files
```

### 2.5 备份有效性检查清单（每月执行）

```
□ 最新24小时内存在 .sql.gz 备份文件
□ md5sum 校验通过
□ zcat 可正常解压读取内容
□ 备份文件包含 ≥30 张表的建表语句
□ OSS 上存在最近7天的备份
□ 恢复演练（沙箱环境）已执行并成功
```

---

## 第三部分：安全管控策略

### 3.1 纵深防御体系

```
第1层 - 网络层：
  UFW 防火墙（仅22/80/443对外）
  Fail2ban（SSH暴力破解防护：3次失败封禁24小时）
  
第2层 - 应用层：
  Nginx 限流（登录10次/分钟，接口120次/分钟）
  CORS 严格限制（仅允许指定域名）
  恶意URL扫描拦截（.env/.git/.sql等）
  
第3层 - 容器层：
  Docker 网络隔离（DB/Redis仅内部访问）
  PHP-FPM 最小权限运行（www-data）
  OPcache 禁止动态修改脚本
  
第4层 - 代码层：
  PDO 预处理防SQL注入
  JWT 签名验证防篡改
  密码字段自动脱敏（password字段 → null）
  敏感接口权限校验（requireRole）
  
第5层 - 数据层：
  生产密钥 AES-256 加密备份
  数据库最小权限账号
  禁止生产/测试数据互通
```

### 3.2 敏感数据处理规范

```php
// 禁止规范（后端代码层面）：
// ❌ 不允许
Response::ok($user);  // 直接返回可能含密码的用户对象

// ✅ 正确做法
$safe = array_merge($user, ['password' => null, 'token' => null]);
Response::ok($safe);

// 日志脱敏规范（禁止记录以下内容）：
// ❌ 禁止记录：手机号完整、密码明文、JWT Token、AK/SK
// ✅ 允许记录：手机号后四位、操作类型、IP（需脱敏评估）
```

### 3.3 应急封控操作

```bash
# 紧急封禁 IP
ufw deny from 恶意IP

# 临时关闭注册（修改配置）
docker compose exec backend php -r "
  require '/var/www/html/config/app.php';
"

# 临时启用维护模式（Nginx 返回503）
cat > /etc/nginx/conf.d/maintenance.conf << 'EOF'
server {
    listen 80 default_server;
    listen 443 ssl default_server;
    ssl_certificate /etc/letsencrypt/live/xiaoniao.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/xiaoniao.com/privkey.pem;
    return 503;
    error_page 503 @maintenance;
    location @maintenance {
        add_header Content-Type text/html;
        return 503 '<h1>系统维护中，请稍后访问</h1>';
    }
}
EOF
nginx -s reload
# 恢复：rm /etc/nginx/conf.d/maintenance.conf && nginx -s reload
```

### 3.4 定期安全任务

```
每周：
  □ bash deploy/ops/security-scan.sh（自动）
  □ 检查 Fail2ban 封禁列表
  □ 查看 Nginx 访问日志异常请求

每月：
  □ 系统安全更新：apt-get upgrade --only-upgrade
  □ Docker 基础镜像更新（php:8.2-fpm-alpine / nginx:1.25-alpine）
  □ 密钥轮换评估（90天周期）

每季：
  □ 账号权限审计（删除无用账号）
  □ 防火墙规则复审
  □ 渗透测试（可选）
```

---

## 第四部分：监控告警说明

### 4.1 监控覆盖矩阵

| 监控项 | 检查频率 | 告警阈值 | 告警方式 |
|--------|---------|---------|---------|
| 服务存活（4个端点）| 5分钟 | HTTP非2xx/3xx | 企业微信+钉钉 |
| 容器状态（7个）| 5分钟 | 非running/unhealthy | 企业微信+钉钉 |
| CPU使用率 | 5分钟 | >85% | 企业微信 |
| 内存使用率 | 5分钟 | >85% | 企业微信 |
| 磁盘使用率 | 5分钟 | >80% | 企业微信 |
| MySQL连接数 | 5分钟 | >150 活跃线程 | 企业微信 |
| Redis | 5分钟 | 连接失败 | 企业微信 |
| SSL证书 | 5分钟 | <14天 紧急 / <30天 预警 | 企业微信 |
| 备份完整性 | 5分钟 | 24小时无新备份 | 企业微信 |

### 4.2 告警接入配置

在 `/opt/xiaoniao/config/prod.env` 中添加：

```bash
# 企业微信机器人（推荐，支持群消息+@all）
WECHAT_WEBHOOK=https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=你的KEY

# 钉钉机器人（二选一或同时配置）
DINGTALK_WEBHOOK=https://oapi.dingtalk.com/robot/send?access_token=你的TOKEN

# 邮件告警（需安装 mailutils）
ALERT_EMAIL=ops@xiaoniao.com
```

### 4.3 告警冷却机制

同一告警在 **30分钟** 内不重复发送（避免告警风暴）。  
冷却锁文件存储于 `/tmp/xn-alert-cooldown/`。

### 4.4 监控日志查看

```bash
# 实时查看监控日志
tail -f /var/log/xiaoniao/monitor.log

# 查看今日告警统计
grep "告警" /var/log/xiaoniao/monitor.log | grep "$(date +%Y-%m-%d)"

# 查看服务响应时间趋势
grep "检查开始" /var/log/xiaoniao/monitor.log | wc -l  # 总执行次数
```

### 4.5 监控脚本快速参考

```bash
# 立即触发一次全量检查（含输出）
bash /opt/xiaoniao/deploy/ops/monitor.sh

# 静默检查（仅写日志，Cron使用）
bash /opt/xiaoniao/deploy/ops/monitor.sh --quiet

# 检查退出码
echo $?  # 0=正常，1=有异常
```

---

## 第五部分：应急处置指南

### 5.1 应急响应级别

| 级别 | 描述 | 响应时间 | 处置要求 |
|------|------|---------|---------|
| P0 紧急 | 全站不可访问 / 数据泄露 | 15分钟内响应 | 技术负责人主导，立即处置 |
| P1 严重 | 核心功能不可用（支付/登录）| 30分钟内响应 | 运维处置，升级技术负责人 |
| P2 重要 | 部分功能异常 / 性能劣化 | 2小时内响应 | 运维处置 |
| P3 一般 | 非核心功能异常 | 次日工作时间 | 计划处置 |

### 5.2 场景一：服务完全不可用（P0）

```bash
# 诊断步骤
echo "=== Step 1: 检查容器状态 ==="
docker compose -f /opt/xiaoniao/docker-compose.prod.yml ps

echo "=== Step 2: 查看错误日志 ==="
docker compose -f /opt/xiaoniao/docker-compose.prod.yml logs --tail=100 backend
docker compose -f /opt/xiaoniao/docker-compose.prod.yml logs --tail=50 db

echo "=== Step 3: 检查Nginx ==="
nginx -t
systemctl status nginx
tail -20 /var/log/nginx/api-error.log

# 常见修复
# 3a. 重启所有服务
docker compose -f /opt/xiaoniao/docker-compose.prod.yml restart

# 3b. 完全重建（最后手段）
docker compose -f /opt/xiaoniao/docker-compose.prod.yml down
docker compose -f /opt/xiaoniao/docker-compose.prod.yml up -d
```

### 5.3 场景二：数据库不可用（P0）

```bash
# 检查 MySQL 容器
docker compose -f /opt/xiaoniao/docker-compose.prod.yml logs --tail=50 db

# 检查磁盘（MySQL崩溃常见原因）
df -h /var/lib/docker/volumes/xiaoniao-prod-db/

# 尝试重启 MySQL
docker compose -f /opt/xiaoniao/docker-compose.prod.yml restart db
sleep 30
docker compose -f /opt/xiaoniao/docker-compose.prod.yml exec db \
    mysqladmin -u root --password="${MYSQL_ROOT_PASSWORD}" status

# MySQL 数据损坏恢复
# 1. 停止后端防止更多写入
docker compose -f /opt/xiaoniao/docker-compose.prod.yml stop backend

# 2. 从最近备份恢复
bash /opt/xiaoniao/deploy/ops/restore.sh db

# 3. 重启后端
docker compose -f /opt/xiaoniao/docker-compose.prod.yml start backend
```

### 5.4 场景三：SSL 证书失效

```bash
# 检查证书状态
openssl x509 -noout -enddate -in /etc/letsencrypt/live/xiaoniao.com/fullchain.pem

# 立即强制续期
certbot renew --force-renewal --nginx

# 重载 Nginx
nginx -s reload

# 如 DNS 验证失败（80端口不可达）
certbot certonly --standalone \
    -d xiaoniao.com -d www.xiaoniao.com \
    -d api.xiaoniao.com -d merchant.xiaoniao.com -d admin.xiaoniao.com \
    --pre-hook "nginx -s stop" \
    --post-hook "nginx"
```

### 5.5 场景四：遭受 DDoS/CC 攻击

```bash
# 查看异常访问 IP（频率最高的 Top 10）
awk '{print $1}' /var/log/nginx/api-access.log | sort | uniq -c | sort -rn | head -10

# 封禁异常 IP
ufw deny from 恶意IP1
ufw deny from 恶意IP2

# 临时收紧限流（修改 nginx.conf）
sed -i 's/rate=120r\/m/rate=30r\/m/' /etc/nginx/nginx.conf
nginx -s reload

# 开启 Nginx 连接限制
# 在 api.conf 的 location /api/ 中添加：
# limit_conn perip 5;

# CC 攻击缓解（临时只允许特定 User-Agent）
# 在 nginx.conf http{} 中添加：
# if ($http_user_agent !~* "Mozilla|Chrome|Safari|Edge|Firefox") { return 403; }
```

### 5.6 场景五：数据误操作恢复

```bash
# 立即停止服务防止更多写入（可选，视情况而定）
docker compose -f /opt/xiaoniao/docker-compose.prod.yml stop backend

# 1. 找到误操作时间点前最近的备份
ls -lt /opt/xiaoniao/backups/db/*.sql.gz | head -5

# 2. 确认备份时间点（选择误操作前的备份）
ls -la /opt/xiaoniao/backups/db/xiaoniao_db_20260517_030001.sql.gz

# 3. 先备份当前数据（恢复前的最后快照）
CURRENT_BACKUP="/opt/xiaoniao/backups/db/xiaoniao_db_before_restore_$(date +%Y%m%d_%H%M%S).sql.gz"
docker compose -f /opt/xiaoniao/docker-compose.prod.yml exec -T db \
    mysqldump -u root --password="${MYSQL_ROOT_PASSWORD}" \
    --single-transaction "${DB_NAME}" | gzip > "${CURRENT_BACKUP}"

# 4. 执行恢复
bash /opt/xiaoniao/deploy/ops/restore.sh db \
    /opt/xiaoniao/backups/db/xiaoniao_db_20260517_030001.sql.gz

# 5. 重启服务
docker compose -f /opt/xiaoniao/docker-compose.prod.yml start backend
```

### 5.7 场景六：代码发布后故障

```bash
# 立即回滚到上一版本（不需要指定版本，自动选择上一个）
bash /opt/xiaoniao/deploy/ops/release.sh rollback

# 或指定版本回滚
bash /opt/xiaoniao/deploy/ops/release.sh rollback v1.1.0

# 查看发布历史
bash /opt/xiaoniao/deploy/ops/release.sh history
```

### 5.8 应急事后处置规范

```
1. 故障发生后 24 小时内输出《故障复盘报告》：
   - 故障描述（时间、影响范围、持续时长）
   - 根因分析（Root Cause Analysis）
   - 处置过程时间线
   - 改进措施（预防类/检测类/响应类）
   - 负责人和截止日期

2. 故障分级归档：
   /var/log/xiaoniao/incidents/YYYY-MM-DD-{P0|P1}-故障描述.md

3. 改进措施跟踪：
   每次月巡检检查上次故障的改进措施是否落地
```

---

## 附录A：快速命令速查表

```bash
# ── 备份 ──────────────────────────────────────
make backup              # 全量备份
make backup-oss          # 全量备份+OSS上传
make restore-db          # 恢复数据库（交互式）

# ── 监控 ──────────────────────────────────────
make monitor             # 立即执行监控检查
make inspect             # 周巡检
make inspect-monthly     # 月巡检
make security-scan       # 安全扫描

# ── 发布 ──────────────────────────────────────
make release             # 发布最新版本
make rollback            # 回滚到上一版本

# ── Docker ────────────────────────────────────
make docker-ps           # 查看容器状态
make docker-logs         # 实时查看日志
make docker-restart      # 重启所有容器

# ── 日志查看 ──────────────────────────────────
tail -f /var/log/xiaoniao/monitor.log
tail -f /var/log/nginx/api-access.log
docker compose -f /opt/xiaoniao/docker-compose.prod.yml logs -f backend
```

## 附录B：运维文档归档清单

| 文档 | 编号 | 阶段 |
|------|------|------|
| 顶层业务与体系标准 | XN-STD-201-01 | 201-01 |
| 项目业务细化解构 | XN-BIZ-201-02 | 201-02 |
| 系统解构与技术规范 | XN-TECH-201-03 | 201-03 |
| HTML原型升级规范 | XN-PROTO-201-04 | 201-04 |
| 原型深化验收规范 | XN-PROTO-201-05 | 201-05 |
| 交互 Demo | — | 201-06 |
| 开发说明文档（DEV-GUIDE.md）| — | 201-07 |
| 多环境配置规范（ENV-CONFIG.md）| XN-ENV-201-09 | 201-09 |
| Docker容器化手册（DOCKER-GUIDE.md）| XN-DOCKER-201-10 | 201-10 |
| 生产部署手册（DEPLOY-GUIDE.md）| XN-DEPLOY-201-11 | 201-11 |
| **运维闭环规范（OPS-GUIDE.md）** | **XN-OPS-201-12** | **201-12 ← 本文档** |

---

## 附录C：全链路工程文件总览

```
xiaoniao-php/                          # 工程根目录（175个文件）
├── 文档
│   ├── README.md                      # 项目说明
│   ├── DEV-GUIDE.md                   # 开发手册（201-07）
│   ├── ENV-CONFIG.md                  # 多环境配置（201-09）
│   ├── DOCKER-GUIDE.md                # 容器化手册（201-10）
│   ├── DEPLOY-GUIDE.md                # 部署手册（201-11）
│   └── OPS-GUIDE.md                   # 运维规范（201-12）← 本文档
├── 后端 backend/（28个PHP文件）
│   ├── 19个控制器 + 4个Helper + 路由 + 入口 + 配置
├── 前端 frontend/（51个Vue文件）
│   ├── buyer（25个）+ merchant（12个）+ admin（14个）
├── 数据库 database/
│   ├── schema.sql（33张表）
│   └── seed.sql（236行演示数据）
├── 容器化
│   ├── Dockerfile.backend / Dockerfile.frontend
│   ├── docker-compose.yml / docker-compose.prod.yml
│   └── docker/（10个配置文件）
├── 多环境配置 backend/config/env/（4个环境）
├── 部署 deploy/
│   ├── scripts/（5个部署脚本）
│   ├── ops/（7个运维脚本）← 201-12新增
│   ├── nginx/（5个Nginx配置）
│   └── systemd/（开机自启）
└── 脚本工具 scripts/（4个快捷脚本）+ Makefile（26个target）
```

---

**文档结束**

| 项目 | 内容 |
|------|------|
| 文档编号 | XN-OPS-201-12 |
| 版本 | v1.0.0 |
| 创建时间 | 2026-05-17 |
| 全流程状态 | **201-01 ～ 201-12 全部完成** ✅ |
| 工程规模 | 175个文件 / PHP+Vue3 / 前后端分离三端 |
