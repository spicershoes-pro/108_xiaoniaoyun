-- docker/mysql/init.sql
-- MySQL 容器初始化脚本
-- 容器首次启动时自动执行（仅执行一次）

-- 字符集
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- ── 创建数据库（各环境） ─────────────────────────────────────
CREATE DATABASE IF NOT EXISTS `xiaoniao_dev`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS `xiaoniao_test`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 注意：staging 和 production 数据库不在开发容器中创建
-- 生产数据库由专用 RDS 或独立 MySQL 实例管理

-- ── 创建应用账号（最小权限）─────────────────────────────────
-- 应用读写账号
CREATE USER IF NOT EXISTS 'xiaoniao_app'@'%'
  IDENTIFIED BY 'XiaoNiao@Dev2026';

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, DROP, ALTER
  ON `xiaoniao_dev`.* TO 'xiaoniao_app'@'%';

GRANT SELECT, INSERT, UPDATE, DELETE
  ON `xiaoniao_test`.* TO 'xiaoniao_app'@'%';

-- 只读账号（供数据分析/监控使用）
CREATE USER IF NOT EXISTS 'xiaoniao_reader'@'%'
  IDENTIFIED BY 'XiaoNiaoReader@Dev2026';

GRANT SELECT ON `xiaoniao_dev`.* TO 'xiaoniao_reader'@'%';

FLUSH PRIVILEGES;
