-- ============================================================
-- 霄鸟云 · 跨境玩具选品平台
-- MySQL 8.0 完整建表脚本
-- 编码: utf8mb4  排序规则: utf8mb4_unicode_ci
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS `xiaoniao`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `xiaoniao`;

-- ────────────────────────────────────────────────────────────
-- 1. 用户主表
-- ────────────────────────────────────────────────────────────
CREATE TABLE `users` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone`        VARCHAR(20)  NOT NULL COMMENT '手机号',
  `email`        VARCHAR(120) DEFAULT NULL COMMENT '邮箱',
  `password`     VARCHAR(255) DEFAULT NULL COMMENT 'bcrypt 哈希',
  `name`         VARCHAR(60)  DEFAULT NULL COMMENT '姓名/昵称',
  `avatar`       VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
  `role`         ENUM('buyer','merchant','admin','super_admin') NOT NULL DEFAULT 'buyer',
  `status`       ENUM('pending','active','suspended') NOT NULL DEFAULT 'active',
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_phone` (`phone`),
  UNIQUE KEY `uq_users_email` (`email`),
  KEY `idx_users_role`   (`role`),
  KEY `idx_users_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户主表';

-- ────────────────────────────────────────────────────────────
-- 2. 买家档案
-- ────────────────────────────────────────────────────────────
CREATE TABLE `buyer_profiles` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`      BIGINT UNSIGNED NOT NULL,
  `company_name` VARCHAR(200) DEFAULT NULL COMMENT '公司名称',
  `company_type` VARCHAR(50)  DEFAULT NULL COMMENT 'buyer/distributor/retailer',
  `country`      VARCHAR(10)  DEFAULT NULL COMMENT '国家代码 CN/US/JP',
  `level`        ENUM('bronze','silver','gold','platinum') NOT NULL DEFAULT 'bronze',
  `total_gmv`    DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT '累计GMV',
  `credit_score` DECIMAL(5,2) NOT NULL DEFAULT 100.00 COMMENT '信用分',
  `verified`     TINYINT(1) NOT NULL DEFAULT 0,
  `verified_at`  DATETIME DEFAULT NULL,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_buyer_user` (`user_id`),
  CONSTRAINT `fk_buyer_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='买家档案';

-- ────────────────────────────────────────────────────────────
-- 3. 商家档案
-- ────────────────────────────────────────────────────────────
CREATE TABLE `merchant_profiles` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`         BIGINT UNSIGNED NOT NULL,
  `company_name`    VARCHAR(200) NOT NULL COMMENT '企业全称',
  `short_name`      VARCHAR(60)  DEFAULT NULL COMMENT '品牌简称',
  `city`            VARCHAR(60)  DEFAULT NULL,
  `province`        VARCHAR(60)  DEFAULT NULL,
  `founded_year`    SMALLINT UNSIGNED DEFAULT NULL,
  `staff_range`     VARCHAR(40)  DEFAULT NULL COMMENT '500-1000人',
  `description`     TEXT         DEFAULT NULL COMMENT '工厂介绍',
  `logo_url`        VARCHAR(500) DEFAULT NULL,
  `banner_url`      VARCHAR(500) DEFAULT NULL,
  `response_rate`   DECIMAL(5,2) NOT NULL DEFAULT 0.00 COMMENT '响应率%',
  `response_time`   VARCHAR(40)  DEFAULT NULL COMMENT '平均2小时',
  `rating`          DECIMAL(3,1) NOT NULL DEFAULT 0.0,
  `rating_count`    INT UNSIGNED NOT NULL DEFAULT 0,
  `total_orders`    INT UNSIGNED NOT NULL DEFAULT 0,
  `total_gmv`       DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `level`           ENUM('bronze','silver','gold','platinum') NOT NULL DEFAULT 'bronze',
  `verified`        TINYINT(1) NOT NULL DEFAULT 0,
  `verified_at`     DATETIME DEFAULT NULL,
  `status`          ENUM('reviewing','active','suspended','rejected') NOT NULL DEFAULT 'reviewing',
  `bank_name`       VARCHAR(100) DEFAULT NULL,
  `bank_account`    VARCHAR(50)  DEFAULT NULL,
  `bank_holder`     VARCHAR(100) DEFAULT NULL,
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_merchant_user` (`user_id`),
  KEY `idx_merchant_status` (`status`),
  KEY `idx_merchant_rating` (`rating`),
  CONSTRAINT `fk_merchant_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商家档案';

-- ────────────────────────────────────────────────────────────
-- 4. 商家品类
-- ────────────────────────────────────────────────────────────
CREATE TABLE `merchant_categories` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `merchant_id` BIGINT UNSIGNED NOT NULL,
  `category`    VARCHAR(60) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_mc` (`merchant_id`, `category`),
  CONSTRAINT `fk_mc_merchant` FOREIGN KEY (`merchant_id`) REFERENCES `merchant_profiles`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────
-- 5. 商家认证证书
-- ────────────────────────────────────────────────────────────
CREATE TABLE `merchant_certs` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `merchant_id` BIGINT UNSIGNED NOT NULL,
  `name`        VARCHAR(50) NOT NULL COMMENT 'CE/EN71/ISO9001/ASTM/BSCI',
  `issuer`      VARCHAR(100) DEFAULT NULL COMMENT '发证机构',
  `issued_at`   DATE DEFAULT NULL,
  `expires_at`  DATE DEFAULT NULL,
  `file_url`    VARCHAR(500) DEFAULT NULL,
  `status`      ENUM('valid','expiring','expired') NOT NULL DEFAULT 'valid',
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_cert_merchant` (`merchant_id`),
  KEY `idx_cert_status`   (`status`),
  CONSTRAINT `fk_cert_merchant` FOREIGN KEY (`merchant_id`) REFERENCES `merchant_profiles`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商家认证证书';

-- ────────────────────────────────────────────────────────────
-- 6. 验证码
-- ────────────────────────────────────────────────────────────
CREATE TABLE `verification_codes` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone`      VARCHAR(20) NOT NULL,
  `code`       VARCHAR(10) NOT NULL,
  `purpose`    ENUM('login','register','reset') NOT NULL DEFAULT 'login',
  `used_at`    DATETIME DEFAULT NULL,
  `expires_at` DATETIME NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_vc_phone`   (`phone`, `purpose`),
  KEY `idx_vc_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='短信验证码';

-- ────────────────────────────────────────────────────────────
-- 7. 产品主表
-- ────────────────────────────────────────────────────────────
CREATE TABLE `products` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `merchant_id`  BIGINT UNSIGNED NOT NULL,
  `sku`          VARCHAR(60) NOT NULL COMMENT '产品编码',
  `name`         VARCHAR(200) NOT NULL,
  `category`     VARCHAR(60) NOT NULL,
  `description`  TEXT DEFAULT NULL,
  `material`     VARCHAR(100) DEFAULT NULL,
  `age_range`    VARCHAR(30) DEFAULT NULL COMMENT '3岁+',
  `size`         VARCHAR(60) DEFAULT NULL,
  `lead_time`    TINYINT UNSIGNED DEFAULT NULL COMMENT '交期(工作日)',
  `status`       ENUM('draft','pending','online','offline','rejected') NOT NULL DEFAULT 'pending',
  `emoji`        VARCHAR(10) DEFAULT NULL,
  `cover_color`  VARCHAR(20) DEFAULT NULL COMMENT '#EFF6FF',
  `base_price`   DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '基础价格',
  `moq`          INT UNSIGNED NOT NULL DEFAULT 100 COMMENT '最小起订量',
  `stock`        INT UNSIGNED NOT NULL DEFAULT 0,
  `sales_count`  INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '累计销量',
  `view_count`   INT UNSIGNED NOT NULL DEFAULT 0,
  `rating`       DECIMAL(3,1) NOT NULL DEFAULT 0.0,
  `review_count` INT UNSIGNED NOT NULL DEFAULT 0,
  `reviewed_at`  DATETIME DEFAULT NULL,
  `review_note`  VARCHAR(500) DEFAULT NULL,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_product_sku` (`sku`),
  KEY `idx_product_merchant`  (`merchant_id`),
  KEY `idx_product_status`    (`status`),
  KEY `idx_product_category`  (`category`),
  KEY `idx_product_sales`     (`sales_count`),
  FULLTEXT KEY `ft_product_name` (`name`),
  CONSTRAINT `fk_product_merchant` FOREIGN KEY (`merchant_id`) REFERENCES `merchant_profiles`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品主表';

-- ────────────────────────────────────────────────────────────
-- 8. 产品阶梯价
-- ────────────────────────────────────────────────────────────
CREATE TABLE `product_price_tiers` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `min_qty`    INT UNSIGNED NOT NULL COMMENT '起订数量',
  `price`      DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pt_product` (`product_id`),
  CONSTRAINT `fk_pt_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品阶梯价';

-- ────────────────────────────────────────────────────────────
-- 9. 产品图片
-- ────────────────────────────────────────────────────────────
CREATE TABLE `product_images` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `url`        VARCHAR(500) NOT NULL,
  `sort`       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_pi_product` (`product_id`),
  CONSTRAINT `fk_pi_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品图片';

-- ────────────────────────────────────────────────────────────
-- 10. 产品认证
-- ────────────────────────────────────────────────────────────
CREATE TABLE `product_certs` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `name`       VARCHAR(30) NOT NULL COMMENT 'CE/EN71/ASTM',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pc` (`product_id`, `name`),
  CONSTRAINT `fk_pc_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品认证';

-- ────────────────────────────────────────────────────────────
-- 11. 产品评价
-- ────────────────────────────────────────────────────────────
CREATE TABLE `product_reviews` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `product_id`  BIGINT UNSIGNED NOT NULL,
  `buyer_name`  VARCHAR(80) NOT NULL,
  `stars`       TINYINT UNSIGNED NOT NULL DEFAULT 5,
  `content`     TEXT DEFAULT NULL,
  `helpful`     INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_review_product` (`product_id`),
  CONSTRAINT `fk_review_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品评价';

-- ────────────────────────────────────────────────────────────
-- 12. 收藏
-- ────────────────────────────────────────────────────────────
CREATE TABLE `favorites` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    BIGINT UNSIGNED NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_fav` (`user_id`, `product_id`),
  CONSTRAINT `fk_fav_user`    FOREIGN KEY (`user_id`)    REFERENCES `users`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_fav_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品收藏';

-- ────────────────────────────────────────────────────────────
-- 13. 采购清单（购物车）
-- ────────────────────────────────────────────────────────────
CREATE TABLE `cart_items` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    BIGINT UNSIGNED NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `qty`        INT UNSIGNED NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_cart` (`user_id`, `product_id`),
  CONSTRAINT `fk_cart_user`    FOREIGN KEY (`user_id`)    REFERENCES `users`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_cart_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='采购清单';

-- ────────────────────────────────────────────────────────────
-- 14. 询盘主表
-- ────────────────────────────────────────────────────────────
CREATE TABLE `inquiries` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `buyer_id`    BIGINT UNSIGNED NOT NULL,
  `merchant_id` BIGINT UNSIGNED NOT NULL,
  `status`      ENUM('pending','quoted','negotiating','converted','closed') NOT NULL DEFAULT 'pending',
  `priority`    ENUM('low','medium','high') NOT NULL DEFAULT 'medium',
  `message`     TEXT NOT NULL,
  `budget`      VARCHAR(100) DEFAULT NULL COMMENT '目标价格描述',
  `quote_price` VARCHAR(200) DEFAULT NULL,
  `quote_note`  TEXT DEFAULT NULL,
  `quoted_at`   DATETIME DEFAULT NULL,
  `converted_at`DATETIME DEFAULT NULL,
  `closed_at`   DATETIME DEFAULT NULL,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_inq_buyer`    (`buyer_id`),
  KEY `idx_inq_merchant` (`merchant_id`),
  KEY `idx_inq_status`   (`status`),
  KEY `idx_inq_created`  (`created_at`),
  CONSTRAINT `fk_inq_buyer`    FOREIGN KEY (`buyer_id`)    REFERENCES `users`(`id`),
  CONSTRAINT `fk_inq_merchant` FOREIGN KEY (`merchant_id`) REFERENCES `merchant_profiles`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='询盘主表';

-- ────────────────────────────────────────────────────────────
-- 15. 询盘产品明细
-- ────────────────────────────────────────────────────────────
CREATE TABLE `inquiry_items` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `inquiry_id`  BIGINT UNSIGNED NOT NULL,
  `product_id`  BIGINT UNSIGNED NOT NULL,
  `qty`         INT UNSIGNED NOT NULL,
  `unit_price`  DECIMAL(10,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_ii_inquiry` (`inquiry_id`),
  CONSTRAINT `fk_ii_inquiry` FOREIGN KEY (`inquiry_id`) REFERENCES `inquiries`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ii_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='询盘产品明细';

-- ────────────────────────────────────────────────────────────
-- 16. 订单主表
-- ────────────────────────────────────────────────────────────
CREATE TABLE `orders` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_no`        VARCHAR(30) NOT NULL COMMENT 'XN20240301xxxx',
  `buyer_id`        BIGINT UNSIGNED NOT NULL,
  `merchant_id`     BIGINT UNSIGNED NOT NULL,
  `inquiry_id`      BIGINT UNSIGNED DEFAULT NULL,
  `status`          ENUM('pending_payment','paid','material','production','shipping','delivered','completed','cancelled','dispute') NOT NULL DEFAULT 'pending_payment',
  `total_amount`    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `deposit`         DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '已付定金',
  `platform_fee`    DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '平台佣金5%',
  `express_company` VARCHAR(60)  DEFAULT NULL,
  `express_no`      VARCHAR(60)  DEFAULT NULL,
  `shipped_at`      DATETIME DEFAULT NULL,
  `deadline`        DATE DEFAULT NULL,
  `paid_at`         DATETIME DEFAULT NULL,
  `completed_at`    DATETIME DEFAULT NULL,
  `cancelled_at`    DATETIME DEFAULT NULL,
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_order_no` (`order_no`),
  KEY `idx_order_buyer`    (`buyer_id`),
  KEY `idx_order_merchant` (`merchant_id`),
  KEY `idx_order_status`   (`status`),
  KEY `idx_order_created`  (`created_at`),
  CONSTRAINT `fk_order_buyer`    FOREIGN KEY (`buyer_id`)    REFERENCES `users`(`id`),
  CONSTRAINT `fk_order_merchant` FOREIGN KEY (`merchant_id`) REFERENCES `merchant_profiles`(`id`),
  CONSTRAINT `fk_order_inquiry`  FOREIGN KEY (`inquiry_id`)  REFERENCES `inquiries`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单主表';

-- ────────────────────────────────────────────────────────────
-- 17. 订单产品明细
-- ────────────────────────────────────────────────────────────
CREATE TABLE `order_items` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id`   BIGINT UNSIGNED NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `qty`        INT UNSIGNED NOT NULL,
  `unit_price` DECIMAL(10,2) NOT NULL,
  `subtotal`   DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_oi_order` (`order_id`),
  CONSTRAINT `fk_oi_order`   FOREIGN KEY (`order_id`)   REFERENCES `orders`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_oi_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单产品明细';

-- ────────────────────────────────────────────────────────────
-- 18. 订单状态日志
-- ────────────────────────────────────────────────────────────
CREATE TABLE `order_status_logs` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id`    BIGINT UNSIGNED NOT NULL,
  `from_status` VARCHAR(30) DEFAULT NULL,
  `to_status`   VARCHAR(30) NOT NULL,
  `note`        VARCHAR(500) DEFAULT NULL,
  `operator_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '操作人user_id',
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_osl_order` (`order_id`),
  CONSTRAINT `fk_osl_order` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单状态日志';

-- ────────────────────────────────────────────────────────────
-- 19. 订单纠纷
-- ────────────────────────────────────────────────────────────
CREATE TABLE `order_disputes` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id`    BIGINT UNSIGNED NOT NULL,
  `reason`      TEXT NOT NULL,
  `resolution`  TEXT DEFAULT NULL,
  `resolved_at` DATETIME DEFAULT NULL,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dispute_order` (`order_id`),
  CONSTRAINT `fk_dispute_order` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单纠纷';

-- ────────────────────────────────────────────────────────────
-- 20. 消息会话
-- ────────────────────────────────────────────────────────────
CREATE TABLE `conversations` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `last_message` VARCHAR(500) DEFAULT NULL,
  `last_msg_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_conv_last` (`last_msg_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='消息会话';

-- ────────────────────────────────────────────────────────────
-- 21. 会话参与者
-- ────────────────────────────────────────────────────────────
CREATE TABLE `conversation_participants` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `conversation_id` BIGINT UNSIGNED NOT NULL,
  `user_id`         BIGINT UNSIGNED NOT NULL,
  `unread_count`    INT UNSIGNED NOT NULL DEFAULT 0,
  `last_read_at`    DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_cp` (`conversation_id`, `user_id`),
  KEY `idx_cp_user` (`user_id`),
  CONSTRAINT `fk_cp_conv` FOREIGN KEY (`conversation_id`) REFERENCES `conversations`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_cp_user` FOREIGN KEY (`user_id`)         REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='会话参与者';

-- ────────────────────────────────────────────────────────────
-- 22. 消息
-- ────────────────────────────────────────────────────────────
CREATE TABLE `messages` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `conversation_id` BIGINT UNSIGNED NOT NULL,
  `sender_id`       BIGINT UNSIGNED NOT NULL,
  `type`            ENUM('text','image','file','product_card','system') NOT NULL DEFAULT 'text',
  `content`         TEXT NOT NULL,
  `metadata`        JSON DEFAULT NULL COMMENT '产品卡片等附加信息',
  `read_at`         DATETIME DEFAULT NULL,
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_msg_conv`    (`conversation_id`, `created_at`),
  KEY `idx_msg_sender`  (`sender_id`),
  CONSTRAINT `fk_msg_conv`   FOREIGN KEY (`conversation_id`) REFERENCES `conversations`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_msg_sender` FOREIGN KEY (`sender_id`)       REFERENCES `users`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='消息';

-- ────────────────────────────────────────────────────────────
-- 23. 样品申请
-- ────────────────────────────────────────────────────────────
CREATE TABLE `sample_requests` (
  `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `buyer_id`         BIGINT UNSIGNED NOT NULL,
  `merchant_id`      BIGINT UNSIGNED NOT NULL,
  `product_id`       BIGINT UNSIGNED NOT NULL,
  `qty`              TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `status`           ENUM('pending','processing','shipped','delivered','rejected') NOT NULL DEFAULT 'pending',
  `fee`              DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `paid`             TINYINT(1) NOT NULL DEFAULT 0,
  `recipient_name`   VARCHAR(60)  DEFAULT NULL,
  `recipient_phone`  VARCHAR(20)  DEFAULT NULL,
  `recipient_address`VARCHAR(300) DEFAULT NULL,
  `note`             VARCHAR(500) DEFAULT NULL,
  `express_company`  VARCHAR(60)  DEFAULT NULL,
  `express_no`       VARCHAR(60)  DEFAULT NULL,
  `shipped_at`       DATETIME DEFAULT NULL,
  `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sr_buyer`    (`buyer_id`),
  KEY `idx_sr_merchant` (`merchant_id`),
  KEY `idx_sr_status`   (`status`),
  CONSTRAINT `fk_sr_buyer`    FOREIGN KEY (`buyer_id`)    REFERENCES `users`(`id`),
  CONSTRAINT `fk_sr_merchant` FOREIGN KEY (`merchant_id`) REFERENCES `merchant_profiles`(`id`),
  CONSTRAINT `fk_sr_product`  FOREIGN KEY (`product_id`)  REFERENCES `products`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='样品申请';

-- ────────────────────────────────────────────────────────────
-- 24. IP授权库
-- ────────────────────────────────────────────────────────────
CREATE TABLE `ip_licenses` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`          VARCHAR(60) NOT NULL,
  `origin`        VARCHAR(40) DEFAULT NULL COMMENT '美国/中国/日本',
  `licensor`      VARCHAR(100) DEFAULT NULL COMMENT '权利方',
  `category`      VARCHAR(40) DEFAULT NULL COMMENT '经典IP/动画IP',
  `description`   TEXT DEFAULT NULL,
  `emoji`         VARCHAR(10) DEFAULT NULL,
  `is_hot`        TINYINT(1) NOT NULL DEFAULT 0,
  `revenue_share` VARCHAR(20) DEFAULT NULL COMMENT '8%',
  `status`        ENUM('active','negotiating','expiring') NOT NULL DEFAULT 'active',
  `expires_at`    DATE DEFAULT NULL,
  `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ip_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='IP授权库';

-- ────────────────────────────────────────────────────────────
-- 25. IP授权申请
-- ────────────────────────────────────────────────────────────
CREATE TABLE `ip_applications` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ip_id`        BIGINT UNSIGNED NOT NULL,
  `user_id`      BIGINT UNSIGNED NOT NULL,
  `company_name` VARCHAR(200) NOT NULL,
  `product`      VARCHAR(200) NOT NULL,
  `annual_qty`   INT UNSIGNED DEFAULT NULL,
  `purpose`      VARCHAR(300) DEFAULT NULL,
  `status`       ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  `note`         VARCHAR(500) DEFAULT NULL,
  `reviewed_at`  DATETIME DEFAULT NULL,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ipa_ip`     (`ip_id`),
  KEY `idx_ipa_user`   (`user_id`),
  KEY `idx_ipa_status` (`status`),
  CONSTRAINT `fk_ipa_ip`   FOREIGN KEY (`ip_id`)   REFERENCES `ip_licenses`(`id`),
  CONSTRAINT `fk_ipa_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='IP授权申请';

-- ────────────────────────────────────────────────────────────
-- 26. 玩具圈帖子
-- ────────────────────────────────────────────────────────────
CREATE TABLE `posts` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `author_id`  BIGINT UNSIGNED NOT NULL,
  `content`    TEXT NOT NULL,
  `images`     JSON DEFAULT NULL COMMENT '图片URL数组',
  `product_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '关联产品',
  `type`       ENUM('factory','platform','buyer') NOT NULL DEFAULT 'buyer',
  `status`     ENUM('reviewing','published','rejected','deleted') NOT NULL DEFAULT 'reviewing',
  `likes`      INT UNSIGNED NOT NULL DEFAULT 0,
  `comments`   INT UNSIGNED NOT NULL DEFAULT 0,
  `reports`    INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_post_author` (`author_id`),
  KEY `idx_post_status` (`status`),
  KEY `idx_post_type`   (`type`),
  CONSTRAINT `fk_post_author` FOREIGN KEY (`author_id`) REFERENCES `users`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='玩具圈帖子';

-- ────────────────────────────────────────────────────────────
-- 27. 首页 Banner
-- ────────────────────────────────────────────────────────────
CREATE TABLE `banners` (
  `id`        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title`     VARCHAR(100) NOT NULL,
  `subtitle`  VARCHAR(200) DEFAULT NULL,
  `tag`       VARCHAR(20)  DEFAULT NULL COMMENT 'HOT/NEW/AI',
  `emoji`     VARCHAR(10)  DEFAULT NULL,
  `bg_style`  VARCHAR(300) NOT NULL COMMENT 'CSS gradient',
  `link_url`  VARCHAR(500) DEFAULT NULL,
  `position`  TINYINT UNSIGNED NOT NULL DEFAULT 99,
  `status`    ENUM('active','draft','paused') NOT NULL DEFAULT 'draft',
  `starts_at` DATETIME DEFAULT NULL,
  `ends_at`   DATETIME DEFAULT NULL,
  `clicks`    INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at`DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_banner_status` (`status`, `position`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='首页Banner';

-- ────────────────────────────────────────────────────────────
-- 28. 汇率
-- ────────────────────────────────────────────────────────────
CREATE TABLE `exchange_rates` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `currency_code` VARCHAR(10)  NOT NULL,
  `name`          VARCHAR(40)  NOT NULL,
  `flag`          VARCHAR(10)  DEFAULT NULL,
  `rate_to_cny`   DECIMAL(10,6) NOT NULL,
  `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_currency` (`currency_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='汇率';

-- ────────────────────────────────────────────────────────────
-- 29. 通知
-- ────────────────────────────────────────────────────────────
CREATE TABLE `notifications` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    BIGINT UNSIGNED NOT NULL,
  `title`      VARCHAR(100) NOT NULL,
  `content`    VARCHAR(500) NOT NULL,
  `type`       VARCHAR(30)  NOT NULL DEFAULT 'system' COMMENT 'inquiry/order/system/sample',
  `link_id`    VARCHAR(30)  DEFAULT NULL COMMENT '关联业务ID',
  `read_at`    DATETIME DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_notif_user`    (`user_id`, `read_at`),
  KEY `idx_notif_created` (`created_at`),
  CONSTRAINT `fk_notif_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知';

-- ────────────────────────────────────────────────────────────
-- 30. 提现申请
-- ────────────────────────────────────────────────────────────
CREATE TABLE `withdrawals` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `merchant_id`  BIGINT UNSIGNED NOT NULL,
  `amount`       DECIMAL(12,2) NOT NULL,
  `bank_name`    VARCHAR(100) DEFAULT NULL,
  `bank_account` VARCHAR(50)  DEFAULT NULL,
  `status`       ENUM('pending','processing','completed','rejected') NOT NULL DEFAULT 'pending',
  `note`         VARCHAR(500) DEFAULT NULL,
  `applied_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `processed_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_wd_merchant` (`merchant_id`),
  KEY `idx_wd_status`   (`status`),
  CONSTRAINT `fk_wd_merchant` FOREIGN KEY (`merchant_id`) REFERENCES `merchant_profiles`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='提现申请';

-- ────────────────────────────────────────────────────────────
-- 31. 管理员操作日志
-- ────────────────────────────────────────────────────────────
CREATE TABLE `operation_logs` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id`   BIGINT UNSIGNED NOT NULL,
  `action`     VARCHAR(60)  NOT NULL,
  `target`     VARCHAR(200) DEFAULT NULL,
  `detail`     JSON         DEFAULT NULL,
  `ip`         VARCHAR(45)  DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_log_admin`   (`admin_id`),
  KEY `idx_log_created` (`created_at`),
  CONSTRAINT `fk_log_admin` FOREIGN KEY (`admin_id`) REFERENCES `users`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='管理员操作日志';

-- ────────────────────────────────────────────────────────────
-- 32. 系统配置
-- ────────────────────────────────────────────────────────────
CREATE TABLE `system_configs` (
  `id`    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `key`   VARCHAR(80)  NOT NULL,
  `value` TEXT         NOT NULL,
  `desc`  VARCHAR(200) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_config_key` (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统配置';

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- 初始化数据
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- T33. 热销榜（全球分区域）
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `product_rankings` (
  `id`            BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `region`        VARCHAR(20)      NOT NULL COMMENT '地区代码 US/EU/JP/SEA/AU/ME',
  `rank_no`       TINYINT UNSIGNED NOT NULL COMMENT '排名 1-50',
  `product_id`    BIGINT UNSIGNED  NOT NULL,
  `monthly_sales` INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT '月销量',
  `growth_rate`   DECIMAL(7,2)     NOT NULL DEFAULT 0.00 COMMENT '环比增长率(%)',
  `updated_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_region_rank` (`region`, `rank_no`),
  KEY `idx_region`  (`region`),
  KEY `idx_product` (`product_id`),
  CONSTRAINT `fk_ranking_product` FOREIGN KEY (`product_id`)
    REFERENCES `products`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='全球热销榜';
