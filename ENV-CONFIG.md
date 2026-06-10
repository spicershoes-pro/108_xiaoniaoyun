# 霄鸟云 · 多环境配置管理规范文档

**文档编号：** XN-ENV-201-09  
**版本：** v1.0.0  
**上游依据：** XN-STD-201-01 · XN-TECH-201-03 · XN-DEV-201-08  
**状态：** 正式发布 · 可归档  
**适用范围：** 后端开发、前端开发、DevOps、运维

---

## 第一章 环境体系总览

### 1.1 四环境定义

| 环境 | 标识 | 用途 | 数据库 | 调试 | 短信 | 提交 Git |
|------|------|------|--------|------|------|---------|
| 开发 | `development` | 本地开发 / 功能开发 | `xiaoniao_dev` | ✅ 开启 | mock | `.env.development` ✅ |
| 测试 | `testing` | 自动化测试 / CI Pipeline | `xiaoniao_test` | ✅ 开启 | mock | `.env.testing` ✅ |
| 预发 | `staging` | UAT验收 / 集成联调 | `xiaoniao_staging` | ❌ 关闭 | 真实 | ❌ 禁止 |
| 生产 | `production` | 正式运行 | `xiaoniao_prod` | ❌ 关闭 | 真实 | ❌ 禁止 |

### 1.2 配置文件层级（后端）

```
backend/
├── .env                          # 【当前激活】本地覆盖，Git忽略
├── .env.example                  # 【模板】可提交 Git，无真实密钥
└── config/
    ├── app.php                   # 配置读取（从 getenv 读取，无硬编码）
    ├── database.php              # 数据库配置读取
    └── env/
        ├── .env.development      # 开发基线，可提交 Git
        ├── .env.testing          # 测试基线，可提交 Git
        ├── .env.staging          # 预发配置，禁止提交（含真实密钥）
        └── .env.production       # 生产配置，禁止提交（含真实密钥）
```

**优先级规则（高 → 低）：**

```
1. 服务器/容器原生环境变量（最高）
2. backend/.env（本地覆盖，仅本地存在）
3. config/env/.env.{APP_ENV}（环境专属）
4. config/app.php 中的默认值（兜底）
```

### 1.3 配置文件层级（前端）

```
frontend/{buyer,merchant,admin}/
├── env/
│   ├── .env.development          # 可提交
│   ├── .env.testing              # 可提交
│   ├── .env.staging              # 禁止提交
│   └── .env.production           # 禁止提交
├── .env.development              # 由 env/ 拷贝生成，开发时存在
├── .env.production               # 由 CI/CD 注入，本地不存在
└── vite.config.js                # 多环境 defineConfig
```

---

## 第二章 配置项完整清单

### 2.1 后端环境变量总表

| 变量名 | 类型 | 必填 | 开发默认值 | 生产规范 | 说明 |
|--------|------|------|-----------|---------|------|
| `APP_NAME` | string | ✅ | `霄鸟云` | `霄鸟云` | 应用名称 |
| `APP_ENV` | enum | ✅ | `development` | `production` | 当前环境标识 |
| `APP_DEBUG` | bool | ✅ | `true` | **`false`** | 调试模式（生产必须false） |
| `APP_URL` | url | ✅ | `http://localhost:8080` | `https://api.xiaoniao.com` | API根地址 |
| `APP_VERSION` | string | — | `1.0.0` | 发版时更新 | 版本号 |
| `DB_HOST` | string | ✅ | `127.0.0.1` | 生产RDS地址 | 数据库主机 |
| `DB_PORT` | int | ✅ | `3306` | `3306` | 数据库端口 |
| `DB_NAME` | string | ✅ | `xiaoniao_dev` | `xiaoniao_prod` | 数据库名（按环境区分）|
| `DB_USER` | string | ✅ | `root` | `xiaoniao_app` | 数据库用户（生产最小权限）|
| `DB_PASS` | string | ✅* | *(空)* | 强密码（16位+） | 数据库密码（生产必填）|
| `JWT_SECRET` | string | ✅ | 弱密钥 | **64位随机串** | JWT签名密钥（生产必须强密钥）|
| `JWT_EXPIRE_HOURS` | int | — | `720` | `168` | Token有效期（小时）|
| `SMS_PROVIDER` | enum | ✅ | `mock` | **`aliyun`/`tencent`** | 短信服务商（生产禁止mock）|
| `SMS_ACCESS_KEY` | string | 条件 | *(空)* | 真实值 | 阿里云AK（provider=aliyun时必填）|
| `SMS_SECRET_KEY` | string | 条件 | *(空)* | 真实值 | 阿里云SK |
| `SMS_SIGN_NAME` | string | 条件 | `霄鸟云` | 已备案签名 | 短信签名 |
| `SMS_TEMPLATE_CODE` | string | 条件 | *(空)* | 真实模板ID | 短信模板 |
| `CORS_ORIGINS` | string | ✅ | `*` | **具体域名列表** | CORS允许来源（生产禁止*）|
| `UPLOAD_DRIVER` | enum | — | `local` | `oss` | 上传驱动 |
| `UPLOAD_MAX_MB` | int | — | `20` | `10` | 上传最大MB |
| `OSS_BUCKET` | string | 条件 | *(空)* | 真实Bucket | OSS存储桶 |
| `OSS_ACCESS_KEY` | string | 条件 | *(空)* | 真实值 | OSS AK |
| `OSS_SECRET_KEY` | string | 条件 | *(空)* | 真实值 | OSS SK |
| `OSS_CDN_PREFIX` | string | 条件 | *(空)* | CDN域名 | CDN前缀 |
| `CACHE_DRIVER` | enum | — | `none` | `redis` | 缓存驱动 |
| `REDIS_HOST` | string | 条件 | `127.0.0.1` | Redis地址 | Redis主机 |
| `REDIS_PASS` | string | 条件 | *(空)* | 强密码 | Redis密码 |
| `LOG_LEVEL` | enum | — | `debug` | `warning` | 日志级别 |
| `LOG_CHANNEL` | enum | — | `stderr` | `file` | 日志输出 |
| `LOG_PATH` | string | 条件 | *(空)* | `/var/log/xiaoniao/prod/app.log` | 日志路径 |
| `PLATFORM_FEE_RATE` | float | — | `0.05` | `0.05` | 平台佣金率（5%）|
| `MIN_WITHDRAWAL` | int | — | `1000` | `1000` | 最低提现金额（元）|
| `ALLOW_UNIVERSAL_CODE` | bool | — | 自动 | **`false`** | 万能验证码（生产必须false）|
| `FORCE_HTTPS` | bool | — | `false` | `true` | 强制HTTPS跳转 |
| `RATE_LIMIT_PER_MIN` | int | — | `0` | `120` | 每IP每分钟限流（0=不限）|

### 2.2 前端环境变量总表

| 变量名 | 开发值 | 生产值 | 说明 |
|--------|--------|--------|------|
| `VITE_APP_ENV` | `development` | `production` | 前端环境标识 |
| `VITE_APP_NAME` | `霄鸟云` | `霄鸟云` | 应用名 |
| `VITE_APP_VERSION` | `1.0.0` | 发版时更新 | 版本号 |
| `VITE_API_BASE_URL` | `/api` | `/api` | API基础路径（由Nginx代理，无需填域名）|
| `VITE_BUILD_TIME` | *(构建时注入)* | *(构建时注入)* | 构建时间戳 |

---

## 第三章 各环境差异化配置矩阵

```
配置项              development   testing    staging    production
─────────────────  ───────────   ───────    ───────    ──────────
APP_DEBUG           true          true       false      false
万能验证码 123456    ✅ 允许       ✅ 允许    ❌ 禁止    ❌ 禁止
短信服务            mock          mock       真实可选    真实必须
CORS 来源           *             *          指定域名   指定域名
错误详情暴露        完整暴露      完整暴露   脱敏       完整脱敏
数据库              xiaoniao_dev  _test      _staging   _prod
日志级别            debug         debug      info       warning
文件上传            local         local      OSS        OSS
强制 HTTPS          否            否         是         是
限流                无            无         120/分钟   120/分钟
SourceMap           inline        inline     无         无
代码压缩            无            无         是         是
Git 可提交           ✅            ✅         ❌         ❌
```

---

## 第四章 安全规范

### 4.1 密钥安全等级分类

| 等级 | 变量示例 | 存储要求 |
|------|---------|---------|
| 🔴 最高机密 | `JWT_SECRET`、`DB_PASS`、`SMS_SECRET_KEY`、`OSS_SECRET_KEY` | 禁止提交 Git；生产通过密钥管理系统注入；传输加密 |
| 🟠 高敏感 | `REDIS_PASS`、`SMS_ACCESS_KEY`、`OSS_ACCESS_KEY` | 禁止提交 Git；可通过 CI/CD Secrets 注入 |
| 🟡 中敏感 | `DB_USER`、`SMS_SIGN_NAME`、`CORS_ORIGINS` | 预发/生产 .env 禁止提交；测试可提交 |
| 🟢 低敏感 | `APP_NAME`、`APP_URL`、`LOG_LEVEL`、`PLATFORM_FEE_RATE` | 全环境可提交 `.env.development` |

### 4.2 强制安全规则

```
规则 S-01：禁止在任何代码文件中硬编码密钥（密码、Token、AK/SK）
规则 S-02：禁止将 .env（本地）、.env.staging、.env.production 提交到 Git
规则 S-03：生产环境 JWT_SECRET 必须由 openssl rand -hex 32 生成（64位随机）
规则 S-04：生产环境 DB_PASS 必须16位以上强密码，禁止空密码
规则 S-05：生产 SMS_PROVIDER 禁止为 mock，必须接入真实短信服务商
规则 S-06：生产 CORS_ORIGINS 禁止包含 *，必须列出具体允许域名
规则 S-07：生产 APP_DEBUG 必须为 false，禁止暴露错误堆栈
规则 S-08：生产 ALLOW_UNIVERSAL_CODE 必须为 false
规则 S-09：生产 DB_USER 必须使用最小权限账号（仅 SELECT/INSERT/UPDATE/DELETE）
规则 S-10：密钥轮换周期：JWT_SECRET 每 90 天，AK/SK 每 180 天
```

### 4.3 生产数据库权限创建规范

```sql
-- 创建最小权限账号（生产禁止使用 root）
CREATE USER 'xiaoniao_app'@'%' IDENTIFIED BY '${STRONG_PASS}';
GRANT SELECT, INSERT, UPDATE, DELETE ON xiaoniao_prod.* TO 'xiaoniao_app'@'%';
FLUSH PRIVILEGES;

-- 只读账号（供数据分析/报表服务使用）
CREATE USER 'xiaoniao_reader'@'%' IDENTIFIED BY '${READER_PASS}';
GRANT SELECT ON xiaoniao_prod.* TO 'xiaoniao_reader'@'%';
FLUSH PRIVILEGES;
```

### 4.4 生产 .env 文件权限规范

```bash
# 文件存放位置（推荐）
/etc/xiaoniao/backend.env

# 权限设置（仅应用进程用户可读）
chmod 600 /etc/xiaoniao/backend.env
chown www-data:www-data /etc/xiaoniao/backend.env

# Nginx / PHP-FPM 加载方式
# php-fpm.conf:
# env[APP_ENV] = production
# env[JWT_SECRET] = ${从密钥管理读取}
# ... 或通过 include /etc/xiaoniao/backend.env 加载
```

---

## 第五章 环境切换操作规范

### 5.1 标准切换流程

```bash
# 步骤 1：切换环境配置
bash scripts/switch-env.sh development    # 开发
bash scripts/switch-env.sh testing        # 测试
bash scripts/switch-env.sh staging        # 预发（需已填写真实密钥）
bash scripts/switch-env.sh production     # 生产（需已填写真实密钥）

# 或使用 Makefile
make dev
make test
make staging

# 步骤 2：验证配置（预发/生产必须执行）
bash scripts/check-env.sh
# 检查通过后输出：✅ 检查全部通过！可以部署

# 步骤 3：初始化数据库（首次/重置时）
bash scripts/reset-db.sh           # 仅建表
bash scripts/reset-db.sh --seed    # 建表+演示数据（开发/测试）

# 步骤 4：启动服务
cd backend && php -S localhost:8080 -t public
cd frontend/buyer && npm run dev
```

### 5.2 快速切换（使用 Makefile）

```bash
make dev          # 切换开发环境
make test         # 切换测试环境
make check-env    # 运行配置检查
make reset-db     # 重置数据库（仅开发/测试）
make reset-db-seed # 重置并导入演示数据
make gen-secret   # 生成 JWT 密钥
make install      # 安装前端依赖（三端）
make build        # 构建前端（生产）
```

### 5.3 不同环境的前端构建命令

```bash
# 开发（热更新）
cd frontend/buyer && npm run dev

# 测试构建验证
cd frontend/buyer && npm run build -- --mode testing

# 预发构建
cd frontend/buyer && npm run build -- --mode staging

# 生产构建
cd frontend/buyer && npm run build
# 等同于 npm run build -- --mode production
```

### 5.4 CI/CD 环境变量注入规范

```yaml
# GitHub Actions 示例
jobs:
  deploy:
    environment: production
    steps:
      - name: 部署后端
        env:
          APP_ENV: production
          APP_DEBUG: 'false'
          DB_HOST: ${{ secrets.PROD_DB_HOST }}
          DB_PASS: ${{ secrets.PROD_DB_PASS }}
          JWT_SECRET: ${{ secrets.PROD_JWT_SECRET }}
          SMS_ACCESS_KEY: ${{ secrets.PROD_SMS_AK }}
          SMS_SECRET_KEY: ${{ secrets.PROD_SMS_SK }}
        run: |
          # 生成 .env 文件（不落盘，直接注入进程）
          php -S 0.0.0.0:8080 -t backend/public &
```

---

## 第六章 数据隔离规范

### 6.1 数据库命名规范

```
xiaoniao_dev      ← 开发环境（本地，可随时重建）
xiaoniao_test     ← 测试环境（CI自动重建，每次从空库开始）
xiaoniao_staging  ← 预发环境（独立实例，类生产数据，定期从生产脱敏导入）
xiaoniao_prod     ← 生产环境（主库，严格保护）
```

### 6.2 数据互通禁令

```
禁令 D-01：开发/测试不得访问预发/生产数据库
禁令 D-02：预发数据库中不得存放真实用户隐私数据（需脱敏）
禁令 D-03：测试结束后 CI 自动触发数据库清空（AUTO_CLEAN_AFTER_TEST）
禁令 D-04：禁止通过任何方式将生产数据直接导出到开发机器（需脱敏处理）
```

### 6.3 数据同步/还原流程

```bash
# 1. 生产数据脱敏导出（供预发同步）
mysqldump xiaoniao_prod --no-data > /tmp/prod_schema.sql
mysqldump xiaoniao_prod --where="created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)" \
  --ignore-table=xiaoniao_prod.users \
  --ignore-table=xiaoniao_prod.buyer_profiles \
  > /tmp/prod_data_masked.sql

# 2. 预发环境导入
mysql -h ${STAGING_HOST} xiaoniao_staging < /tmp/prod_schema.sql
mysql -h ${STAGING_HOST} xiaoniao_staging < /tmp/prod_data_masked.sql

# 3. 开发演示数据初始化
make reset-db-seed
```

### 6.4 测试环境数据策略

```
测试数据生命周期：
  创建 → 在测试用例 setUp 中由 seed.sql 导入
  使用 → 测试执行过程中读写
  销毁 → 测试用例 tearDown 后自动回滚（事务）或 CI 后重建
  
CI Pipeline 标准流程：
  1. 重建 xiaoniao_test 数据库（schema.sql）
  2. 导入测试基础数据（seed.sql --testing）
  3. 运行全量接口测试
  4. 生成覆盖率报告
  5. 清空 xiaoniao_test（保持洁净）
```

---

## 第七章 环境配置项安全检查清单

### 7.1 预发环境部署前检查

```
□ APP_ENV=staging
□ APP_DEBUG=false
□ DB_PASS 已填写非空密码
□ JWT_SECRET 长度 ≥ 32 位
□ JWT_SECRET 不含 dev/test/change/secret 等弱密钥词
□ SMS_PROVIDER 不为 mock（或为 mock 且明确知晓为测试模式）
□ CORS_ORIGINS 已指定预发域名（不为 *）
□ ALLOW_UNIVERSAL_CODE=false
□ FORCE_HTTPS=true
□ 无任何 REPLACE_ 占位符
□ 运行 bash scripts/check-env.sh 检查通过
```

### 7.2 生产环境部署前检查（更严格）

```
□ 所有预发检查项均通过
□ APP_ENV=production
□ DB_USER=xiaoniao_app（非 root）
□ DB_PASS ≥ 16 位强密码（含大小写+数字+特殊字符）
□ JWT_SECRET 由 openssl rand -hex 32 生成（64位）
□ SMS_PROVIDER=aliyun 或 tencent（非 mock）
□ 短信服务商账号已实名认证、已审核通过
□ OSS_BUCKET 已设置正确的权限策略（私有读写）
□ REDIS_PASS 已设置密码
□ LOG_LEVEL=warning（不输出 debug 信息）
□ LOG_PATH 日志目录已建立并设置权限
□ RATE_LIMIT_PER_MIN=120（启用限流保护）
□ .env 文件权限为 600，所有者为应用用户
□ 运行 bash scripts/check-env.sh 全部通过，无 FAIL
```

---

## 第八章 运维手册

### 8.1 常见故障排查

| 现象 | 可能原因 | 排查方法 |
|------|---------|---------|
| API 返回 500 | .env 未加载 / DB 连接失败 | `cat backend/.env` 确认配置；检查 DB 连接 |
| JWT 验证失败 | JWT_SECRET 环境间不一致 | 两端对比 JWT_SECRET；清除前端 localStorage |
| 验证码收不到 | SMS_PROVIDER 未正确配置 | 检查 SMS_PROVIDER 和 AK/SK；查 error_log |
| CORS 跨域错误 | CORS_ORIGINS 未包含请求来源 | 确认 CORS_ORIGINS 包含前端域名 |
| 前端 API 404 | baseURL 或 proxy 配置错误 | 检查 vite.config.js proxy 和后端启动端口 |
| 文件上传失败 | OSS 配置错误 / 权限不足 | 检查 OSS_BUCKET、AK/SK；确认 Bucket 权限 |
| 生产 debug 信息暴露 | APP_DEBUG=true | 立即设置 APP_DEBUG=false 并重启服务 |

### 8.2 密钥轮换操作

```bash
# 步骤 1：生成新密钥
bash scripts/gen-jwt-secret.sh
# 输出新的 JWT_SECRET=xxxxx

# 步骤 2：更新生产配置（通过密钥管理系统或安全通道）
# 注意：JWT 轮换后所有当前 Token 立即失效，在线用户需重新登录
# 建议：在业务低峰期（如凌晨）执行

# 步骤 3：更新服务器环境变量（不同部署方式）
# 方式A：修改 /etc/xiaoniao/backend.env 后重启 PHP-FPM
# 方式B：更新 K8s Secret 后滚动重启 Pod
# 方式C：更新 CI/CD Secrets 后触发新部署

# 步骤 4：验证新 Token 可正常签发
curl -X POST https://api.xiaoniao.com/api/auth/login \
  -d '{"phone":"test","code":"123456"}'
```

### 8.3 环境配置更新记录要求

每次更新生产配置必须记录：

```
变更时间：YYYY-MM-DD HH:MM
变更操作人：xxx
变更内容：修改了 JWT_SECRET（密钥轮换）
变更原因：定期轮换（90天周期）
影响范围：所有在线用户 Token 失效，需重新登录
回滚方案：还原旧 JWT_SECRET（7天内 Token 仍可解析）
```

---

## 第九章 目录结构总览

```
xiaoniao-php/
├── .gitignore                        ← Git 忽略规则（密钥文件不提交）
├── Makefile                          ← 快捷命令入口
├── scripts/
│   ├── switch-env.sh                 ← 环境切换脚本
│   ├── check-env.sh                  ← 配置健康检查脚本
│   ├── reset-db.sh                   ← 数据库重置脚本（仅开发/测试）
│   └── gen-jwt-secret.sh             ← JWT密钥生成脚本
├── backend/
│   ├── .env                          ← 【当前激活，Git忽略】
│   ├── .env.example                  ← 【模板，可提交】
│   └── config/
│       ├── app.php                   ← 应用配置（纯 getenv，无硬编码）
│       ├── database.php              ← 数据库配置
│       └── env/
│           ├── .env.development      ← 【可提交，无密钥】
│           ├── .env.testing          ← 【可提交，无密钥】
│           ├── .env.staging          ← 【禁止提交，含密钥占位符】
│           └── .env.production       ← 【禁止提交，含密钥占位符】
└── frontend/{buyer,merchant,admin}/
    └── env/
        ├── .env.development          ← 【可提交】
        ├── .env.testing              ← 【可提交】
        ├── .env.staging              ← 【禁止提交】
        └── .env.production           ← 【禁止提交】
```

---

## 附录 A：快速参考命令

```bash
# 环境切换
make dev / make test / make staging / make production

# 配置检查
make check-env

# 数据库
make reset-db       # 重置（不含数据）
make reset-db-seed  # 重置 + 演示数据

# 密钥
make gen-secret     # 生成 JWT_SECRET

# 前端
make install        # npm install 三端
make build          # 生产构建三端

# 手动切换
bash scripts/switch-env.sh production
bash scripts/check-env.sh
```

## 附录 B：各环境测试账号

| 角色 | 手机号 | 验证码 | 适用环境 |
|------|--------|--------|---------|
| 超级管理员 | 13800000000 | 123456 | development / testing |
| 运营管理员 | 13800000001 | 123456 | development / testing |
| 买家 | 18888888888 | 123456 | development / testing |
| 商家（广州乐途）| 13900000001 | 123456 | development / testing |
| 商家（汕头创联）| 13900000002 | 123456 | development / testing |

> ⚠️ 以上账号和万能验证码 `123456` 仅在 `APP_ENV=development` 或 `ALLOW_UNIVERSAL_CODE=true` 时生效。预发/生产环境严格禁用。

---

**文档结束**

| 项目 | 内容 |
|------|------|
| 文档编号 | XN-ENV-201-09 |
| 版本 | v1.0.0 |
| 创建时间 | 2026-05-17 |
| 锁定状态 | 正式发布 |
| 下游衔接 | 容器化打包 / 生产部署 / CI/CD 流水线 |
