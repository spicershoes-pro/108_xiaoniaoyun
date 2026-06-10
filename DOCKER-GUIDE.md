# 霄鸟云 · Docker 容器化部署操作手册

**文档编号：** XN-DOCKER-201-10  
**版本：** v1.0.0  
**上游依据：** XN-ENV-201-09 · XN-DEV-201-08  
**状态：** 正式发布

---

## 第一章 容器化架构总览

### 1.1 服务拓扑

```
┌─────────────────────────────────────────────────────────┐
│                      外部访问                            │
└──────┬─────────┬─────────┬──────────────────────────────┘
       │ :8080   │ :5173   │ :5174  │ :5175
       ▼         ▼         ▼        ▼
  ┌─────────┐ ┌────────┐ ┌────────┐ ┌────────┐
  │nginx-api│ │ buyer  │ │merchant│ │ admin  │
  │(API代理) │ │(Nginx) │ │(Nginx) │ │(Nginx) │
  └────┬────┘ └────────┘ └────────┘ └────────┘
       │ fastcgi_pass:9000    （三端静态SPA，History路由回退）
       ▼
  ┌─────────┐        ┌─────────┐
  │ backend │───────▶│  redis  │
  │(PHP-FPM)│        │(cache)  │
  └────┬────┘        └─────────┘
       │ PDO
       ▼
  ┌─────────┐
  │   db    │
  │(MySQL8) │
  └─────────┘

网络隔离：
  xn-internal（内部，禁止外网）：db、redis、backend
  xn-external（对外）：nginx-api、frontend-*
```

### 1.2 镜像清单

| 镜像名 | 基础镜像 | 大小估算 | 说明 |
|--------|---------|---------|------|
| `xiaoniao/backend` | php:8.2-fpm-alpine | ~80MB | PHP-FPM + PDO/opcache |
| `xiaoniao/frontend-buyer` | nginx:1.25-alpine（多阶段）| ~25MB | 用户端静态SPA |
| `xiaoniao/frontend-merchant` | nginx:1.25-alpine | ~25MB | 商家端静态SPA |
| `xiaoniao/frontend-admin` | nginx:1.25-alpine | ~25MB | 管理端静态SPA |

### 1.3 镜像版本命名规范

```
格式：xiaoniao/{service}:{env}-{YYYYMMDDHHMI}
示例：xiaoniao/backend:prod-202605171430
      xiaoniao/frontend-buyer:dev-202605171430

固定标签：
  :dev     → 最新开发构建
  :staging → 最新预发构建
  :latest  → 最新生产构建
  :cache   → 构建缓存层
```

---

## 第二章 环境准备

### 2.1 系统要求

```
操作系统：Linux（Ubuntu 22.04+ / CentOS 8+ 推荐）
Docker：   20.10+
Docker Compose：V2（compose 命令，非 docker-compose 命令）
内存：     开发 ≥ 4GB，生产 ≥ 8GB
磁盘：     ≥ 20GB（含数据库数据）
```

### 2.2 Docker 安装（Ubuntu）

```bash
# 安装 Docker Engine
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 验证
docker version
docker compose version
```

### 2.3 开启 BuildKit（加速构建）

```bash
# 临时开启
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# 永久写入（推荐）
echo 'export DOCKER_BUILDKIT=1' >> ~/.bashrc
echo 'export COMPOSE_DOCKER_CLI_BUILD=1' >> ~/.bashrc
source ~/.bashrc
```

---

## 第三章 开发环境快速启动

### 3.1 一键启动（推荐）

```bash
# 1. 克隆项目
git clone https://github.com/your-org/xiaoniao-php.git
cd xiaoniao-php

# 2. 初始化环境配置
make dev                     # 切换开发环境配置

# 3. 构建并启动所有服务（首次约 3-5 分钟）
docker compose up -d --build

# 4. 查看启动状态
docker compose ps

# 5. 查看日志（确认无错误）
docker compose logs -f backend
```

### 3.2 验证服务

```bash
# 后端 API 健康检查
curl http://localhost:8080/health
# 预期：{"status":"ok","service":"api"}

# 后端接口测试
curl http://localhost:8080/api/banners
# 预期：{"code":0,"msg":"success","data":[...]}

# 前端访问
open http://localhost:5173    # 用户端
open http://localhost:5174    # 商家端
open http://localhost:5175    # 管理端
```

### 3.3 测试账号

| 端口 | 账号 | 验证码 |
|------|------|--------|
| :5173 买家端 | 18888888888 | 123456 |
| :5174 商家端 | 13900000001 | 123456 |
| :5175 管理端 | 13800000000 | 123456 |

---

## 第四章 常用运维命令

### 4.1 服务管理

```bash
# 启动所有服务
docker compose up -d

# 停止所有服务（保留数据卷）
docker compose down

# 停止并删除所有数据（谨慎！）
docker compose down -v

# 重启指定服务
docker compose restart backend
docker compose restart nginx-api

# 查看服务状态
docker compose ps

# 实时查看所有日志
docker compose logs -f

# 查看指定服务日志（最近100行）
docker compose logs --tail=100 -f backend
docker compose logs --tail=100 -f db
```

### 4.2 进入容器

```bash
# 进入后端容器（调试）
docker compose exec backend sh

# 进入 MySQL（需要密码）
docker compose exec db mysql -u root -p

# 进入 Redis CLI
docker compose exec redis redis-cli -a ${REDIS_PASS:-XiaoNiaoRedis2026}

# 在后端容器中执行 PHP
docker compose exec backend php -r "echo 'PHP OK';"

# 在容器中手动导入 SQL
docker compose exec backend sh -c \
  "mysql -h db -u \$DB_USER -p\$DB_PASS \$DB_NAME < /var/www/html/database/schema.sql"
```

### 4.3 代码更新（开发模式）

```bash
# 开发模式已挂载源码目录，PHP 代码修改无需重建镜像
# 若修改了 Dockerfile 或 PHP 配置，需重建
docker compose up -d --build backend

# 若修改了前端代码（开发模式建议用 npm run dev 本地开发）
docker compose up -d --build frontend-buyer
```

### 4.4 数据库操作

```bash
# 重建数据库（仅开发/测试）
make reset-db-seed

# 导出数据库备份
docker compose exec db mysqldump \
  -u root -p${MYSQL_ROOT_PASSWORD:-XiaoNiaoRoot2026} \
  xiaoniao_dev > backup_$(date +%Y%m%d).sql

# 导入备份
docker compose exec -T db mysql \
  -u root -p${MYSQL_ROOT_PASSWORD:-XiaoNiaoRoot2026} \
  xiaoniao_dev < backup_20260517.sql
```

---

## 第五章 镜像构建规范

### 5.1 手动构建

```bash
# 构建所有镜像（开发标签）
bash docker/scripts/build.sh dev

# 构建生产镜像（带时间戳版本）
bash docker/scripts/build.sh prod 20260517-v1.0.1

# 单独构建后端
docker build -f Dockerfile.backend -t xiaoniao/backend:dev .

# 单独构建前端（以 buyer 为例）
docker build -f Dockerfile.frontend \
  --build-arg APP=buyer \
  -t xiaoniao/frontend-buyer:dev .
```

### 5.2 Makefile 快捷构建

```bash
make docker-build        # 开发镜像
make docker-build-prod   # 生产镜像
make docker-up           # 启动
make docker-down         # 停止
make docker-logs         # 查看日志
make docker-shell-backend # 进入后端容器
```

### 5.3 推送到镜像仓库

```bash
# 推送到 Docker Hub
docker tag xiaoniao/backend:prod docker.io/yourorg/xn-backend:v1.0.0
docker push docker.io/yourorg/xn-backend:v1.0.0

# 推送到阿里云 ACR
REGISTRY=registry.cn-hangzhou.aliyuncs.com/yourns
docker tag xiaoniao/backend:prod ${REGISTRY}/xn-backend:v1.0.0
docker push ${REGISTRY}/xn-backend:v1.0.0

# 推送到私有 Harbor
REGISTRY=harbor.yourcompany.com/xiaoniao
docker tag xiaoniao/backend:prod ${REGISTRY}/backend:v1.0.0
docker push ${REGISTRY}/backend:v1.0.0
```

---

## 第六章 生产环境部署

### 6.1 前置准备

```bash
# 1. 生成强密钥
bash scripts/gen-jwt-secret.sh      # 获取 JWT_SECRET

# 2. 创建生产环境配置（不提交 Git）
cp backend/config/env/.env.production backend/.env.production.local
# 编辑并替换所有 REPLACE_xxx 占位符
vim backend/.env.production.local

# 3. 配置检查（必须全部通过才能部署）
APP_ENV=production bash scripts/check-env.sh
```

### 6.2 生产启动命令

```bash
# 加载生产配置
export $(cat backend/.env.production.local | grep -v '^#' | xargs)

# 启动生产服务
docker compose -f docker-compose.prod.yml up -d

# 验证
docker compose -f docker-compose.prod.yml ps
curl http://localhost:8080/health
```

### 6.3 滚动更新（零停机）

```bash
# 1. 构建新镜像
IMAGE_TAG=20260517-v1.0.2
bash docker/scripts/build.sh prod ${IMAGE_TAG}

# 2. 更新后端（replica=2，逐个替换）
IMAGE_TAG=${IMAGE_TAG} docker compose -f docker-compose.prod.yml \
  up -d --no-deps --scale backend=2 backend

# 3. 验证新容器正常
sleep 10
curl http://localhost:8080/health

# 4. 更新前端（逐个更新，无停机）
for APP in buyer merchant admin; do
  IMAGE_TAG=${IMAGE_TAG} docker compose -f docker-compose.prod.yml \
    up -d --no-deps frontend-${APP}
  sleep 5
done

echo "✅ 滚动更新完成"
```

### 6.4 回滚

```bash
# 回滚到指定版本
IMAGE_TAG=20260516-v1.0.1 docker compose -f docker-compose.prod.yml \
  up -d --no-deps backend
IMAGE_TAG=20260516-v1.0.1 docker compose -f docker-compose.prod.yml \
  up -d --no-deps frontend-buyer frontend-merchant frontend-admin
```

---

## 第七章 日志管理

### 7.1 日志位置

| 服务 | 容器内路径 | 说明 |
|------|-----------|------|
| PHP 错误日志 | `/var/www/logs/php-error.log` | PHP 运行错误 |
| PHP-FPM 慢日志 | `/var/www/logs/php-fpm-slow.log` | 超过3秒的请求 |
| PHP-FPM 错误 | `/var/www/logs/php-fpm-error.log` | FPM进程错误 |
| Nginx 访问日志 | `/var/log/nginx/api-access.log` | API 访问记录 |
| Nginx 错误日志 | `/var/log/nginx/api-error.log` | Nginx 错误 |

### 7.2 查看日志命令

```bash
# 实时追踪后端日志
docker compose logs -f backend

# 查看 PHP 错误日志（宿主机通过 volume 访问）
docker compose exec backend tail -f /var/www/logs/php-error.log

# 查看 Nginx 访问日志
docker compose exec nginx-api tail -f /var/log/nginx/api-access.log

# 查看 MySQL 慢查询日志
docker compose exec db tail -f /var/lib/mysql/slow.log

# 查看 Redis 日志
docker compose logs redis
```

### 7.3 日志轮转（生产推荐）

```bash
# 创建 logrotate 配置
cat > /etc/logrotate.d/xiaoniao << 'EOF'
/var/lib/docker/volumes/xiaoniao-prod-logs/_data/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    dateext
}
EOF
```

---

## 第八章 故障排查

### 8.1 常见问题速查

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| 后端容器反复重启 | DB 连接失败 / .env 缺失 | `docker compose logs backend` 看详情 |
| API 返回 502 | PHP-FPM 未启动 / 端口错误 | `docker compose exec backend php-fpm -t` |
| API 返回 500 | PHP 代码错误 / 权限问题 | `docker compose exec backend tail -f /var/www/logs/php-error.log` |
| 数据库连接拒绝 | DB 未就绪 / 密码错误 | 检查 DB_PASS 和容器健康状态 |
| 前端页面空白 | dist/ 构建失败 | `docker compose logs frontend-buyer` 查构建错误 |
| 跨域错误 | CORS_ORIGINS 未配置 | 检查 Nginx api.conf 和 CORS_ORIGINS 环境变量 |
| 上传失败 | uploads/ 目录权限 | `docker compose exec backend chown -R www-data /var/www/html/public/uploads` |
| 容器时间不对 | TZ 环境变量未设置 | 检查 TZ=Asia/Shanghai 是否传入 |

### 8.2 健康检查命令

```bash
# 检查所有服务状态
docker compose ps

# 检查后端 PHP-FPM 配置
docker compose exec backend php-fpm -t

# 检查 MySQL 连接
docker compose exec backend php -r "
  \$pdo = new PDO(
    'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME'),
    getenv('DB_USER'), getenv('DB_PASS')
  );
  echo '数据库连接成功，版本：' . \$pdo->getAttribute(PDO::ATTR_SERVER_VERSION);
"

# 检查 Redis 连接
docker compose exec redis redis-cli \
  -a ${REDIS_PASS:-XiaoNiaoRedis2026} ping

# 检查 Nginx 配置
docker compose exec nginx-api nginx -t
```

### 8.3 完整重建（开发时调试用）

```bash
# 停止并清理所有容器和数据卷
docker compose down -v

# 清理所有构建缓存
docker system prune -f
docker volume prune -f

# 重新构建并启动
docker compose up -d --build

# 查看启动日志
docker compose logs -f
```

---

## 第九章 CI/CD 集成示例

### GitHub Actions 完整流水线

```yaml
# .github/workflows/deploy.yml
name: Build & Deploy

on:
  push:
    branches: [main]
    tags: ['v*']

env:
  REGISTRY: ghcr.io/${{ github.repository_owner }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: 设置 Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: 登录镜像仓库
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: 构建并推送后端镜像
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile.backend
          push: true
          tags: |
            ${{ env.REGISTRY }}/xn-backend:${{ github.sha }}
            ${{ env.REGISTRY }}/xn-backend:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: 构建并推送前端镜像（buyer）
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile.frontend
          build-args: APP=buyer
          push: true
          tags: |
            ${{ env.REGISTRY }}/xn-frontend-buyer:${{ github.sha }}
            ${{ env.REGISTRY }}/xn-frontend-buyer:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: SSH 部署到生产服务器
        uses: appleboy/ssh-action@v1
        with:
          host:     ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key:      ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/xiaoniao
            IMAGE_TAG=${{ github.sha }}
            export IMAGE_TAG
            # 注入生产密钥（从服务器本地安全存储读取）
            source /etc/xiaoniao/prod.env
            docker compose -f docker-compose.prod.yml pull
            docker compose -f docker-compose.prod.yml up -d --no-deps backend
            sleep 10
            curl -f http://localhost:8080/health || exit 1
            docker compose -f docker-compose.prod.yml up -d --no-deps \
              frontend-buyer frontend-merchant frontend-admin
            echo "部署成功：${IMAGE_TAG}"
```

---

## 附录 A：Docker 文件清单

```
xiaoniao-php/
├── Dockerfile.backend              # 后端 PHP-FPM 镜像
├── Dockerfile.frontend             # 前端三端通用镜像（多阶段）
├── docker-compose.yml              # 开发环境编排
├── docker-compose.prod.yml         # 生产环境编排
└── docker/
    ├── nginx/conf.d/
    │   ├── api.conf                # API Nginx 配置
    │   └── frontend.conf           # 前端 SPA Nginx 配置
    ├── php/
    │   ├── php.ini                 # PHP 自定义配置
    │   ├── php-fpm.conf            # PHP-FPM 进程配置
    │   └── opcache.ini             # OPcache 配置
    ├── mysql/
    │   ├── init.sql                # 数据库初始化（首次）
    │   └── my.cnf                  # MySQL 性能配置
    ├── redis/
    │   └── redis.conf              # Redis 配置
    └── scripts/
        ├── backend-entrypoint.sh   # 后端启动入口脚本
        └── build.sh                # 镜像批量构建脚本
```

## 附录 B：端口映射总览

| 端口 | 服务 | 说明 |
|------|------|------|
| 8080 | nginx-api | 后端 API（Nginx 代理 PHP-FPM）|
| 5173 | frontend-buyer | 用户端 |
| 5174 | frontend-merchant | 商家端 |
| 5175 | frontend-admin | 管理端 |
| 3306 | db | MySQL（开发暴露，生产不暴露）|
| 6379 | redis | Redis（开发暴露，生产不暴露）|

## 附录 C：数据卷说明

| 卷名 | 挂载路径 | 说明 | 备份优先级 |
|------|---------|------|-----------|
| `xiaoniao-dev-db` | `/var/lib/mysql` | 数据库文件 | ⭐⭐⭐ 高 |
| `xiaoniao-dev-redis` | `/data` | Redis AOF | ⭐⭐ 中 |
| `xiaoniao-dev-uploads` | `/var/www/html/public/uploads` | 用户上传文件 | ⭐⭐⭐ 高 |
| `xiaoniao-dev-logs` | `/var/www/logs` | PHP 日志 | ⭐ 低 |
| `xiaoniao-dev-nginx-logs` | `/var/log/nginx` | Nginx 日志 | ⭐ 低 |

---

**文档结束**

| 项目 | 内容 |
|------|------|
| 文档编号 | XN-DOCKER-201-10 |
| 版本 | v1.0.0 |
| 创建时间 | 2026-05-17 |
| 下游衔接 | 生产服务器部署 / K8s 编排 / CDN 配置 |
