-- ============================================================
-- 霄鸟云演示种子数据
-- 运行前请先执行 schema.sql
-- ============================================================

USE `xiaoniao`;

-- ── 管理员（验证码登录；开发环境万能码 123456）──
INSERT INTO `users` (`phone`,`email`,`password`,`name`,`role`,`status`) VALUES
('13800000000','admin@xiaoniao.com','$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','系统管理员','super_admin','active'),
('13800000001','ops@xiaoniao.com','$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','运营管理员','admin','active');

-- ── 买家用户（密码均为 Test@2026）──
INSERT INTO `users` (`phone`,`email`,`password`,`name`,`role`,`status`) VALUES
('18888888888','liming@example.com','$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','李明远','buyer','active'),
('18800000002','tom@ustoyimports.com','$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','Tom Zhang','buyer','active'),
('18800000003','maria@juguetes.es','$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','Maria García','buyer','active');

-- ── 商家用户 ──
INSERT INTO `users` (`phone`,`email`,`password`,`name`,`role`,`status`) VALUES
('13900000001','wjg@letu-toys.com','$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','王建国','merchant','active'),
('13900000002','zhang@chuanglian.com','$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','张工','merchant','active'),
('13900000003','li@yangzhou-toy.com','$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','李厂长','merchant','active');

-- 买家档案
INSERT INTO `buyer_profiles` (`user_id`,`company_name`,`company_type`,`country`,`level`,`total_gmv`,`credit_score`,`verified`,`verified_at`) VALUES
(3,'深圳好玩贸易有限公司','buyer','CN','gold',486000.00,98.60,1,'2025-03-15 00:00:00'),
(4,'US Toy Imports LLC','distributor','US','platinum',2340000.00,99.10,1,'2024-08-20 00:00:00'),
(5,'Juguetes España SL','retailer','ES','gold',890000.00,97.50,1,'2024-11-10 00:00:00');

-- ── 商家档案 ──
INSERT INTO `merchant_profiles`
(`user_id`,`company_name`,`short_name`,`city`,`province`,`founded_year`,`staff_range`,`description`,`response_rate`,`response_time`,`rating`,`rating_count`,`total_orders`,`total_gmv`,`level`,`verified`,`verified_at`,`status`,`bank_name`,`bank_account`,`bank_holder`)
VALUES
(6,'广州乐途玩具制造有限公司','广州乐途','广州','广东',2008,'500-1000人',
 '专注高端益智玩具18年，拥有现代化生产线12条，年产能超500万件，是欧美知名玩具品牌的核心代工工厂。',
 98.50,'平均2小时',4.8,128,2340,18600000.00,'gold',1,'2023-06-15','active',
 '中国工商银行广州天河支行','6222000012345678','广州乐途玩具制造有限公司'),
(7,'汕头创联玩具科技股份','汕头创联','汕头','广东',2012,'200-500人',
 '科技类玩具专家，拥有50+项自主专利技术，研发团队80人，是多个国际玩具品牌的技术合作伙伴。',
 99.20,'平均1小时',4.9,96,3120,28400000.00,'platinum',1,'2023-01-20','active',
 '招商银行汕头分行','6225000087654321','汕头创联玩具科技股份'),
(8,'扬州欢乐工坊玩具有限公司','扬州欢乐','扬州','江苏',2005,'100-200人',
 '传统毛绒玩具领域领先企业，工艺精湛，专注中高端毛绒玩具生产20年，质量口碑卓著。',
 96.00,'平均4小时',4.6,74,987,6200000.00,'silver',1,'2024-03-10','active',
 '中国建设银行扬州分行','6217000023456789','扬州欢乐工坊玩具有限公司');

-- 商家品类
INSERT INTO `merchant_categories` (`merchant_id`,`category`) VALUES
(1,'遥控玩具'),(1,'益智玩具'),(1,'科技玩具'),
(2,'科技玩具'),(2,'户外玩具'),(2,'益智玩具'),
(3,'毛绒玩具'),(3,'传统玩具');

-- 商家认证
INSERT INTO `merchant_certs` (`merchant_id`,`name`,`issuer`,`expires_at`,`status`) VALUES
(1,'ISO9001','SGS','2027-01-15','valid'),
(1,'CE','TÜV SÜD','2026-06-01','expiring'),
(1,'EN71','Bureau Veritas','2026-09-10','valid'),
(1,'ASTM','UL','2027-03-22','valid'),
(1,'BSCI','amfori','2025-11-05','expired'),
(2,'ASTM','UL','2027-06-01','valid'),
(2,'CE','SGS','2027-01-01','valid'),
(2,'ISO9001','Bureau Veritas','2026-08-01','valid'),
(3,'CE','TÜV SÜD','2026-12-01','valid'),
(3,'EN71','SGS','2026-08-15','valid');

-- ── 产品 ──
INSERT INTO `products`
(`merchant_id`,`sku`,`name`,`category`,`description`,`material`,`age_range`,`size`,`lead_time`,`status`,`emoji`,`cover_color`,`base_price`,`moq`,`stock`,`sales_count`,`view_count`,`rating`,`review_count`)
VALUES
(1,'XN-001','恐龙遥控挖掘机套装','遥控玩具','高品质ABS环保材质，符合EN71安全标准，四驱越野设计，电池续航3小时，支持OEM/ODM定制。','ABS环保塑料','3岁+','28×18×12cm',15,'online','🦕','#EFF6FF',89.00,100,2400,12400,89000,4.8,234),
(2,'XN-002','泡泡机彩虹发射器','户外玩具','7孔发泡设计，续航2小时，防水IPX4，TikTok年度热门爆款，复购率极高。','PP+ABS','3岁+','22×12×8cm',10,'online','🫧','#F0FDF4',45.00,200,5600,8900,64000,4.9,189),
(1,'XN-003','儿童积木创意城堡','益智玩具','320片磁力拼接，无毒无味，STEM教育首选，获多项国际玩具设计大奖。','EVA泡棉','3岁+','40×30×30cm',20,'online','🏰','#FFF7ED',156.00,50,890,6700,42000,4.7,156),
(3,'XN-004','毛绒公仔海洋系列','毛绒玩具','6款海洋生物可选，手感柔软，高密度PP棉填充，通过婴幼儿安全标准测试。','短毛绒+PP棉','0岁+','35cm',25,'online','🐋','#EFF6FF',68.00,150,3200,5600,38000,4.6,98),
(2,'XN-005','磁力拼图3D立体','益智玩具','64片磁力片，可拼接180+造型，STEM教育玩具，全球累计销售200万套。','磁力片+ABS','3岁+','片约4cm',12,'online','🧲','#F5F3FF',128.00,80,1200,4300,31000,4.8,211),
(3,'XN-006','音乐发光陀螺套装','传统玩具','LED七彩发光，内置音乐播放，3个/套，拼手速竞技，抖音百万播放。','合金+ABS','3岁+','10×10×8cm',8,'online','🌀','#FFF0F6',32.00,500,8900,9800,72000,4.5,342),
(1,'XN-007','AR互动恐龙卡片','科技玩具','AR增强现实技术，扫码3D恐龙跃然纸上，20张/套，科教融合新体验。','纸质+AR芯片','5岁+','标准卡片',18,'online','📱','#ECFDF5',78.00,120,560,3200,28000,4.9,67),
(2,'XN-008','儿童相机双镜头','科技玩具','2000万像素，防摔防水设计，内置滤镜游戏，最受欢迎的儿童节礼品。','ABS+硅胶','3岁+','11×7×4cm',22,'online','📷','#FFF7ED',198.00,30,320,2800,21000,4.7,89);

-- 产品阶梯价
INSERT INTO `product_price_tiers` (`product_id`,`min_qty`,`price`) VALUES
(1,100,89.00),(1,200,82.00),(1,500,76.00),
(2,200,45.00),(2,400,41.00),(2,1000,38.00),
(3,50,156.00),(3,100,144.00),(3,250,133.00),
(4,150,68.00),(4,300,63.00),(4,600,58.00),
(5,80,128.00),(5,160,118.00),(5,400,109.00),
(6,500,32.00),(6,1000,29.00),(6,2000,27.00),
(7,120,78.00),(7,240,72.00),(7,600,66.00),
(8,30,198.00),(8,60,183.00),(8,150,168.00);

-- 产品认证
INSERT INTO `product_certs` (`product_id`,`name`) VALUES
(1,'CE'),(1,'EN71'),(1,'ASTM'),
(2,'CE'),(2,'EN71'),
(3,'CE'),(3,'EN71'),(3,'ASTM'),
(4,'CE'),(4,'EN71'),
(5,'CE'),(5,'EN71'),(5,'ASTM'),
(6,'CE'),(6,'EN71'),
(7,'CE'),(7,'EN71'),
(8,'CE'),(8,'ASTM'),(8,'EN71');

-- 产品评价
INSERT INTO `product_reviews` (`product_id`,`buyer_name`,`stars`,`content`,`helpful`) VALUES
(1,'Tom Z.',5,'质量超棒，已复购3次！包装精美。',24),
(1,'Lisa M.',4,'交期准时，工厂配合度很高。',18),
(1,'Alex K.',5,'采购三批质量一致，强烈推荐！',31),
(2,'Maria G.',5,'泡泡很多，孩子喜欢！',22),
(2,'John W.',5,'大量采购，质量稳定。',15);

-- ── 询盘 ──
INSERT INTO `inquiries` (`buyer_id`,`merchant_id`,`status`,`priority`,`message`,`budget`,`quote_price`,`quote_note`,`quoted_at`,`created_at`) VALUES
(4,1,'quoted','high','Hi, we are interested in your RC Dinosaur Excavator. MOQ 500pcs, need CE+ASTM cert. Can you quote?','$35-42/件','¥82/件，500件起','交期15个工作日，支持定制LOGO，CE+ASTM认证完整。','2026-03-25 10:00:00','2026-03-24 09:32:00'),
(3,2,'negotiating','medium','We need 200pcs bubble machine with custom logo. Delivery before June. Please provide your best price.','€15-20/件',NULL,NULL,NULL,'2026-03-24 14:18:00'),
(5,1,'pending','high','Looking for 100pcs RC dinosaur toys with OEM packaging for our Spain stores.','€20-28/件',NULL,NULL,NULL,'2026-03-25 08:11:00');

-- 询盘明细
INSERT INTO `inquiry_items` (`inquiry_id`,`product_id`,`qty`) VALUES
(1,1,500),(2,2,200),(3,1,100);

-- ── 订单 ──
INSERT INTO `orders` (`order_no`,`buyer_id`,`merchant_id`,`inquiry_id`,`status`,`total_amount`,`deposit`,`platform_fee`,`express_company`,`express_no`,`shipped_at`,`deadline`,`paid_at`,`created_at`) VALUES
('XN202403001',4,1,1,'production',44500.00,22250.00,2225.00,NULL,NULL,NULL,'2026-04-15','2026-03-16 10:00:00','2026-03-15 09:00:00'),
('XN202403002',4,2,NULL,'shipping',9000.00,9000.00,450.00,'顺丰国际','SF3012345678','2026-03-22 14:00:00','2026-03-28','2026-03-10 11:00:00','2026-03-10 09:00:00'),
('XN202402003',3,1,NULL,'completed',23400.00,23400.00,1170.00,'顺丰国际','SF2998765432','2026-03-05 10:00:00','2026-03-20','2026-02-28 10:00:00','2026-02-28 08:00:00'),
('XN202402004',3,3,NULL,'dispute',20400.00,10200.00,1020.00,NULL,NULL,NULL,'2026-04-20',NULL,'2026-03-18 09:00:00');

-- 订单明细
INSERT INTO `order_items` (`order_id`,`product_id`,`qty`,`unit_price`,`subtotal`) VALUES
(1,1,500,89.00,44500.00),
(2,2,200,45.00,9000.00),
(3,7,300,78.00,23400.00),
(4,4,300,68.00,20400.00);

-- 订单状态日志
INSERT INTO `order_status_logs` (`order_id`,`from_status`,`to_status`,`note`,`operator_id`) VALUES
(1,NULL,'pending_payment','订单创建',4),
(1,'pending_payment','paid','买家已付款50%定金',4),
(1,'paid','material','开始备料',6),
(1,'material','production','进入生产',6),
(2,NULL,'pending_payment','订单创建',4),
(2,'pending_payment','paid','买家全款支付',4),
(2,'paid','material','备料完成',7),
(2,'material','production','生产完成',7),
(2,'production','shipping','顺丰国际SF3012345678',7);

-- 订单纠纷
INSERT INTO `order_disputes` (`order_id`,`reason`) VALUES
(4,'买家反映收到的毛绒公仔与样品质量不符，填充物不足，面料色差明显，要求退款或重发。');

-- ── 会话与消息 ──
INSERT INTO `conversations` (`last_message`,`last_msg_at`) VALUES
('MOQ可以谈，300件以上优惠','2026-03-25 09:32:00'),
('样品明天发出，请注意查收','2026-03-24 14:00:00');

INSERT INTO `conversation_participants` (`conversation_id`,`user_id`,`unread_count`) VALUES
(1,3,0),(1,6,0),(2,4,0),(2,7,0);

INSERT INTO `messages` (`conversation_id`,`sender_id`,`type`,`content`,`created_at`) VALUES
(1,6,'text','您好！我是王经理，恐龙遥控挖掘机现货500件随时可发。','2026-03-25 09:10:00'),
(1,3,'text','请问MOQ多少？300件价格能优惠吗？','2026-03-25 09:12:00'),
(1,6,'text','MOQ 100件，¥89/件。300件以上¥82，支持定制LOGO。','2026-03-25 09:15:00'),
(1,6,'product_card','产品推荐','2026-03-25 09:16:00'),
(1,3,'text','好的，先寄一个样品，地址等会发您','2026-03-25 09:18:00'),
(1,6,'text','MOQ可以谈，300件以上优惠','2026-03-25 09:32:00'),
(2,7,'text','样品明天发出，顺丰SF3012345678，请注意查收','2026-03-24 14:00:00');

-- ── 样品申请 ──
INSERT INTO `sample_requests` (`buyer_id`,`merchant_id`,`product_id`,`qty`,`status`,`fee`,`paid`,`recipient_name`,`recipient_phone`,`recipient_address`,`express_company`,`express_no`,`shipped_at`) VALUES
(4,1,1,2,'shipped',280.00,1,'Tom Zhang','+1-310-555-0100','123 Toy Street, Los Angeles, CA 90001, USA','DHL','DHL123456789','2026-03-22 10:00:00'),
(4,2,2,1,'pending',45.00,0,'Tom Zhang','+1-310-555-0100','123 Toy Street, Los Angeles, CA 90001, USA',NULL,NULL,NULL),
(3,1,3,1,'delivered',156.00,1,'Maria García','+34-91-555-0123','Calle Mayor 45, 28013 Madrid, España','FedEx','FDX987654321',NULL);

-- ── 帖子 ──
INSERT INTO `posts` (`author_id`,`content`,`type`,`status`,`likes`,`comments`) VALUES
(6,'最新款恐龙遥控车已量产！支持定制LOGO，起订100件，欢迎询价 🦕\n\n• ABS材质，续航3小时\n• 四驱越野，IP54防水\n• 支持OEM/ODM','factory','published',28,6),
(1,'【2026 Q2爆款预测】磁力积木热度持续上升，欧美市场增速+41%！建议尽早备货 💡\n\n数据来源：海关出口+亚马逊BSR综合分析','platform','published',156,34),
(3,'问一下：有没有做AR互动类玩具的工厂推荐？要有CE认证，MOQ在100以内的。谢谢！🙏','buyer','published',12,18),
(7,'泡泡机彩虹发射器 补货通知！\n昨日TikTok带货，单日询盘300+，现货告急！\n预计下周二补货2万件，有意向的客户请尽快下单锁定 📦','factory','published',89,23);

-- ── 通知 ──
INSERT INTO `notifications` (`user_id`,`title`,`content`,`type`,`link_id`) VALUES
(3,'有新的询盘回复','广州乐途已对您的询盘进行报价，请及时查看','inquiry','1'),
(6,'收到新询盘','买家 Maria García 发来新的采购询盘，请及时回复','inquiry','3'),
(4,'订单状态更新','订单 XN202403002 已发货，顺丰国际 SF3012345678','order','2');

-- ── 提现申请 ──
INSERT INTO `withdrawals` (`merchant_id`,`amount`,`bank_name`,`bank_account`,`status`,`applied_at`) VALUES
(1,128000.00,'中国工商银行广州天河支行','6222000012345678','pending','2026-03-24 10:00:00'),
(2,234000.00,'招商银行汕头分行','6225000087654321','processing','2026-03-23 14:00:00'),
(3,46000.00,'中国建设银行扬州分行','6217000023456789','pending','2026-03-22 09:00:00');

-- ── 收藏 ──
INSERT INTO `favorites` (`user_id`,`product_id`) VALUES (3,1),(3,5),(3,7),(4,2),(4,3);

-- ── 采购清单 ──
INSERT INTO `cart_items` (`user_id`,`product_id`,`qty`) VALUES (3,1,100),(3,5,80);

-- ── 汇率基础数据 ──────────────────────────────────────────────
INSERT INTO `exchange_rates` (`currency_code`,`name`,`flag`,`rate_to_cny`) VALUES
('USD','美元','🇺🇸',7.240000),
('EUR','欧元','🇪🇺',7.890000),
('GBP','英镑','🇬🇧',9.180000),
('JPY','日元','🇯🇵',0.048000),
('KRW','韩元','🇰🇷',0.005400),
('AED','阿联酋迪拉姆','🇦🇪',1.970000),
('AUD','澳大利亚元','🇦🇺',4.740000),
('SGD','新加坡元','🇸🇬',5.430000)
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`),`rate_to_cny`=VALUES(`rate_to_cny`),`updated_at`=NOW();

-- ── Banner 数据 ───────────────────────────────────────────────
INSERT INTO `banners` (`title`,`subtitle`,`tag`,`emoji`,`bg_style`,`link_url`,`position`,`status`) VALUES
('Q2全球选品季','3000+ SKU 同步上新，精准匹配采购需求','HOT','🎯','linear-gradient(135deg,#1677FF,#0958D9,#5E5CE6)','/products',1,'active'),
('IP授权中心开放','50+ 国际大牌授权通道全面开放','NEW','🎨','linear-gradient(135deg,#BF5AF2,#FF375F)','/ips',2,'active'),
('AI智能选品助手','基于实时市场数据精准推荐爆款','AI','🤖','linear-gradient(135deg,#30D158,#0A84FF)','/products',3,'active')
ON DUPLICATE KEY UPDATE `bg_style`=VALUES(`bg_style`),`updated_at`=NOW();

-- ── 系统配置 ─────────────────────────────────────────────────
INSERT INTO `system_configs` (`key`,`value`,`desc`) VALUES
('platform_name','霄鸟云','平台名称'),
('platform_fee_rate','0.05','平台佣金率（5%）'),
('min_withdrawal','1000','最低提现金额（元）'),
('sms_provider','mock','短信服务商：mock/aliyun/tencent'),
('inquiry_expire_days','30','询盘过期天数'),
('sample_max_qty','5','单次样品最大申请数量'),
('platform_version','1.0.0','当前版本号'),
('maintenance_mode','0','维护模式（0=正常 1=维护中）')
ON DUPLICATE KEY UPDATE `value`=VALUES(`value`), `desc`=VALUES(`desc`);

-- ── IP授权库 ─────────────────────────────────────────────────
INSERT INTO `ip_licenses` (`name`,`origin`,`licensor`,`category`,`emoji`,`revenue_share`,`is_hot`,`status`) VALUES
('芝麻街','美国','Sesame Workshop','经典IP','🐸','8%',1,'active'),
('迷你特工队','中国','华策影视','动画IP','🤖','6%',1,'active'),
('小猪佩奇','英国','eOne/Hasbro','经典IP','🐷','TBD',1,'negotiating'),
('Hello Kitty','日本','Sanrio','潮流IP','🎀','10%',0,'active'),
('奥特曼系列','日本','圆谷プロ','英雄IP','⚡','9%',1,'active'),
('超级飞侠','中国','奥飞娱乐','动画IP','✈️','5%',0,'expiring')
ON DUPLICATE KEY UPDATE `revenue_share`=VALUES(`revenue_share`);

-- ── 热销榜 ───────────────────────────────────────────────────
INSERT INTO `product_rankings` (`region`,`rank_no`,`product_id`,`monthly_sales`,`growth_rate`) VALUES
('US',1,1,128000,34.00),('US',2,5,98000,22.00),('US',3,3,87000,41.00),
('US',4,8,76000,18.00),('US',5,2,65000,29.00),
('EU',1,3,156000,12.00),('EU',2,6,134000,28.00),('EU',3,4,112000,9.00),
('JP',1,6,234000,45.00),('JP',2,7,189000,23.00),('JP',3,5,167000,38.00),
('SEA',1,2,89000,56.00),('SEA',2,1,76000,33.00),('SEA',3,3,67000,24.00)
ON DUPLICATE KEY UPDATE `monthly_sales`=VALUES(`monthly_sales`),`updated_at`=NOW();
