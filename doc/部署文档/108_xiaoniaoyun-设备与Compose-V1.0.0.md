# 108_xiaoniaoyun · 设备与 Compose 对照（开发状态 dev）

> **版本** V1.0.0 | **状态** `dev` | **配置源** `deploy/devices.dev.env`

## 总览

| 设备角色 | 主机名 | IP | Compose 项目名 | Compose 文件 |
|----------|--------|-----|----------------|--------------|
| 本地工作站 | local | 127.0.0.1 | `108_xiaoniaoyun_dev` | `docker-compose.yml` |
| 库机 | MM-V3-CORE-01 | 192.168.1.223 | `108_xiaoniaoyun_db_dev` | `docker-compose.db-dev-remote.yml` |
| 应用机 | MM-V2-PROD-01 | 192.168.1.87 | `108_xiaoniaoyun_app_dev` | `docker-compose.app-dev-remote.yml` |

远程同步目录（三台统一）：`~/108_xiaoniaoyun_dev/`  
环境变量文件：`deploy/.env.dev`（参考 `deploy/.env.dev.example`）

## 容器命名（均为 dev 后缀）

| 设备 | 容器名 |
|------|--------|
| 本地 | `108_xiaoniaoyun-db-dev`、`108_xiaoniaoyun-backend-dev`、`108_xiaoniaoyun-buyer-dev` … |
| 库机 | `108_xiaoniaoyun-mysql-dev` |
| 应用机 | `108_xiaoniaoyun-redis-dev`、`108_xiaoniaoyun-backend-dev`、`108_xiaoniaoyun-nginx-api-dev`、`108_xiaoniaoyun-buyer-dev`、`108_xiaoniaoyun-merchant-dev`、`108_xiaoniaoyun-admin-dev` |

## 端口

| 设备 | 服务 | 端口 |
|------|------|------|
| 本地 | MySQL | 3308 |
| 本地 | API（dev.sh PHP） | 18080 |
| 本地 | Vite 三端 | 5173 / 5174 / 5175 |
| 库机 | MySQL | **3320** |
| 应用机 | API Nginx | **8080** |
| 应用机 | 三端 Nginx | 5173 / 5174 / 5175 |
| 应用机→库机中继 | Mac `host.docker.internal` | **13320** → 223:3320 |

## 镜像标签

统一前缀 `108_xiaoniaoyun/`，开发状态标签 **`:dev`**（如 `108_xiaoniaoyun/backend:dev`）。

## 常用命令

```bash
# 查看三端设备与本地 compose 状态
./scripts/status-dev.sh

# 本地开发
./scripts/dev.sh start

# 推送库机 + 应用机（开发状态）
export SSHPASS='...'
bash scripts/push-dev-xny.sh
DEPLOY_DB_ONLY=1 bash scripts/push-dev-xny.sh   # 仅库机
DEPLOY_APP_ONLY=1 bash scripts/push-dev-xny.sh  # 仅应用机
```

## 数据卷（沿用历史卷名，避免丢数据）

| 卷名 | 用途 |
|------|------|
| `xiaoniao-prod-db-data` | 库机 MySQL 数据 |
| `xiaoniao-prod-uploads` | 应用机上传目录 |
| `xiaoniao-prod-logs` | 应用机日志 |

## 废弃文件

以下文件已由 `*-dev-remote.yml` 替代，仅作兼容参考：

- `docker-compose.db-prod-remote.yml`
- `docker-compose.app-prod-remote.yml`
- `scripts/push-prod-xny.sh`（转发至 `push-dev-xny.sh`）
