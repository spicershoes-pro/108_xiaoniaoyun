# 霄鸟云（108_xny）

跨境玩具 B2B 选品平台 · 工程与文档仓库。

## 三端应用

| 端 | 目录 | 本地地址 | 说明 |
|----|------|----------|------|
| **用户端** | `frontend/buyer` | http://localhost:5173 | 选品、询盘、订单、消息等 20 页 |
| **商家端** | `frontend/merchant` | http://localhost:5174 | 询盘报价、产品、订单发货等 11 页 |
| **管理端** | `frontend/admin` | http://localhost:5175 | 审核、监控、财务、系统等 13 页 |

本地入口页（三端链接）：打开 [portal.html](portal.html)

## 目录

| 路径 | 说明 |
|------|------|
| `doc/` | 六类项目文档 |
| `backend/` | PHP 8.2 API |
| `frontend/buyer` · `merchant` · `admin` | Vue3 + Vite 三端 |
| `database/` | `schema.sql` + `seed.sql` |
| `scripts/dev.sh` | 一键启动 MySQL + API + 三端 Vite |
| `scripts/verify-api.sh` | 基础 API 验证（11 项） |
| `scripts/accept-p0.sh` | 买家 P0 业务流 |
| `scripts/accept-merchant.sh` | 商家端 API 验收 |
| `scripts/accept-admin.sh` | 管理端 API 验收 |

## 需求边界

规划原文：`/Users/openclaw/Documents/[SUBC]-V5/OS-2 项目原型开发/108_宵鸟云-APP/201`

## 快速开始

```bash
# 首次：安装三端依赖
./scripts/dev.sh install

# 一键启动（MySQL:3308、API:18080、Vite 5173/5174/5175）
./scripts/dev.sh start

# 全量 API 验收
./scripts/dev.sh accept

# 停止
./scripts/dev.sh stop
```

说明：宿主机 **8080/3307** 常被其他 Docker 项目占用；本仓库默认 **API 18080**、**MySQL 3308**。

## 测试账号

| 端 | 手机号 | 验证码 |
|----|--------|--------|
| 用户端 | 18888888888 | 123456 |
| 商家端 | 13900000001 / 13900000002 | 123456 |
| 管理端超管 | 13800000000 | 123456 |

## 生产推送（内网拆分）

| 角色 | 主机 | 端口 |
|------|------|------|
| MySQL | 192.168.1.223 (MM-V3-CORE-01) | **3320** |
| 应用 | 192.168.1.87 (MM-V2-PROD-01) | API 8080，三端 5173/5174/5175 |

```bash
# 本地先构建镜像（应用机常无法拉 Docker Hub）
cd frontend/buyer && npm run build && cd ../merchant && npm run build && cd ../admin && npm run build
cd ../..
docker build -f Dockerfile.backend -t 108_xiaoniaoyun/backend:prod .
# 前端镜像可用 docker commit，见 scripts/push-prod-xny.sh

export SSHPASS='...'   # 或 ssh-copy-id
bash scripts/push-prod-xny.sh
```

生产访问：http://192.168.1.87:5173/（买家）、`:5174` 商家、`:5175` 管理；验证码仍为 `123456`（staging）。
