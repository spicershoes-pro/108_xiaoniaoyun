# 108_霄鸟云 · 开发记录（open_log）

> **本聊天窗专用项目**  
> - 项目编号/目录名：`108_xiaoniaoyun`  
> - 中文名：`108_霄鸟云`  
> - 工作区路径：`/Users/OPENAPI/108_xiaoniaoyun`  
> - 维护方式：按时间倒序追加（最新记录放最上面）

---

## 2026-06-03 · 生产环境搭建（xiaoniaoyun.dowima.com · 108 服务器）

- **目标**：宝塔非 Docker 单域名生产部署。
- **服务器**：内网 `192.168.1.184` · SSH `59.57.32.193:50025` · 宝塔 `:11160/5edd0dbe`
- **改动（本地）**：
  - 三端 Vite 增加 `VITE_BASE_PATH`（merchant `/merchant/`，admin `/admin/`）
  - `scripts/pack-baota-prod.sh` · `deploy/baota/*` · 部署文档
- **服务器已完成**：
  - 重装 Nginx（原 tarball 0 字节）· PHP 8.2 putenv · MySQL root 重置
  - 代码目录 `/www/wwwroot/xiaoniaoyun.dowima.com`
  - 数据库 `xiaoniao`（schema + seed，8 users / 8 products）
  - Nginx 站点 + 扩展路由（`/api/` `/merchant/` `/admin/`）
- **本机验证（Host 头）**：`/` `/merchant/` `/admin/` 200 · `/api/auth/login` 成功 · `/api/products` 8 条
- **入口 URL**（DNS + 端口转发就绪后）：
  - 用户端 `https://xiaoniaoyun.dowima.com/`
  - 商家端 `https://xiaoniaoyun.dowima.com/merchant/`
  - 管理端 `https://xiaoniaoyun.dowima.com/admin/`
- **待收尾**：DNS → 公网 IP · 路由器 80/443 → 192.168.1.184 · 宝塔 HTTPS · 关闭万能验证码
- **凭证**：仅保存在服务器 `/root/.108_xny_prod.env`

---

## 2026-06-02 · 错误记录：聊天窗项目归属混淆

- **错误**：本聊天窗被误用于 **102_云豹**（`102_yunbao`）生产部署与「无法访问」排查（`yunbao.dowima.com`、宝塔 102 服务器等），与窗口约定不符。
- **正确归属**：
  - 本窗：**108_霄鸟云** · `108_xiaoniaoyun`
  - 云豹相关操作应使用 **102_云豹** 专用窗口 / `102_yunbao` 仓库
- **误操作影响范围**（均在远程 102 云豹环境，**未改动** `108_xiaoniaoyun` 代码库）：
  - 102 生产机 Nginx / 宝塔 / MySQL 部署与排查
  - 误写 `102_yunbao/open_log.md` 中的外网访问排查记录
- **纠正**：
  - 本文件 header 由错误的 `102_霄鸟云` / `102_xiaoniaoyun` 更正为 **`108_霄鸟云` / `108_xiaoniaoyun`**
  - 后续本窗仅记录与开发 **108_霄鸟云** 相关事项
- **备注**：目录名为 `108_xiaoniaoyun`，与项目编号 **108** 一致；勿与 `102_yunbao`（云豹点餐）混淆。

---

## 2026-06-02 · 项目范围确认

- **目标**：明确本窗口仅服务 **108_霄鸟云**，不与云豹点餐等其他项目混开发。
- **约定**：
  - 对外称呼：`108_霄鸟云`
  - 工程标识：`108_xiaoniaoyun`
  - 后续所有开发记录、改动说明、验收结论均写入本文件。
- **当前仓库概况**（`108_xiaoniaoyun`）：
  - 三端前端：`frontend/buyer` · `merchant` · `admin`
  - 后端 API：`backend/`
  - 数据库：`database/`
  - 文档：`doc/` · `DEV-GUIDE.md` · `DEPLOY-GUIDE.md` 等

---

## 日志模板（复制追加）

### YYYY-MM-DD HH:mm
- **目标**：
- **改动**：
  - `path/to/file`
- **原因**：
- **验证**：
- **结果**：
- **下一步**：
