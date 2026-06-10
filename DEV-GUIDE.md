# 霄鸟云 · 跨境玩具选品平台
## 【201-07】全功能开发完成说明文档

**文档版本：** v1.0.0  
**完成日期：** 2026-05-16  
**上游依据：** XN-STD-201-01 · XN-BIZ-201-02 · XN-TECH-201-03 · XN-PROTO-201-05 · XN-PROTO-201-06

---

## 一、工程总览

### 1.1 技术栈

| 层次 | 技术选型 | 版本 |
|------|---------|------|
| 后端 | 原生 PHP（无框架）+ 轻量路由 | PHP 8.1+ |
| 数据库 | MySQL | 8.0+ |
| 认证 | 手动实现 JWT（HS256） | — |
| 前端 | Vue 3 + Vite + Pinia + Vue Router | Vue 3.4+ |
| HTTP 客户端 | Axios | 1.x |
| 构建工具 | Vite | 5.x |

### 1.2 工程结构

```
xiaoniao-php/
├── README.md
├── database/
│   ├── schema.sql          # 33张表完整DDL + 索引
│   └── seed.sql            # 演示数据（用户/产品/订单/配置等）
├── backend/
│   ├── .env                # 环境变量（开发可直接使用）
│   ├── config/
│   │   ├── app.php         # 应用配置（从.env读取）
│   │   └── database.php    # 数据库配置
│   ├── public/
│   │   ├── index.php       # 统一入口（自动加载+全局异常）
│   │   └── .htaccess       # Apache rewrite规则
│   ├── routes/
│   │   └── api.php         # 65条路由（完整）
│   └── app/
│       ├── Controllers/    # 19个控制器
│       ├── Helpers/        # 4个工具类
│       └── Middleware/     # Cors中间件
└── frontend/
    ├── buyer/              # 用户端（端口5173）
    ├── merchant/           # 商家端（端口5174）
    └── admin/              # 管理端（端口5175）
```

---

## 二、环境搭建

### 2.1 前置要求

```
PHP   >= 8.1（开启 pdo_mysql, json, mbstring 扩展）
MySQL >= 8.0
Node  >= 18.0
npm   >= 9.0
```

### 2.2 数据库初始化

```bash
# 1. 创建数据库
mysql -u root -p -e "CREATE DATABASE xiaoniao CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 2. 执行建表脚本
mysql -u root -p xiaoniao < database/schema.sql

# 3. 导入演示数据
mysql -u root -p xiaoniao < database/seed.sql
```

### 2.3 后端启动

```bash
cd backend

# 配置环境变量（按实际修改）
cp .env .env.local   # 或直接编辑 .env

# 启动开发服务器
php -S localhost:8080 -t public

# 验证接口可访问
curl http://localhost:8080/api/banners
# 预期返回: {"code":0,"msg":"success","data":[...]}
```

### 2.4 前端启动（三端独立）

```bash
# 用户端
cd frontend/buyer
npm install
npm run dev        # http://localhost:5173

# 商家端
cd frontend/merchant
npm install
npm run dev        # http://localhost:5174

# 管理端
cd frontend/admin
npm install
npm run dev        # http://localhost:5175
```

---

## 三、测试账号

| 角色 | 手机号 | 验证码 | 说明 |
|------|--------|--------|------|
| 超级管理员 | 13800000000 | 123456 | 管理端全功能 |
| 运营管理员 | 13800000001 | 123456 | 管理端（无财务/系统页） |
| 买家（中国） | 18888888888 | 123456 | 用户端全功能 |
| 买家（美国） | 18800000002 | 123456 | 用户端全功能 |
| 商家（广州乐途） | 13900000001 | 123456 | 商家端全功能 |
| 商家（汕头创联） | 13900000002 | 123456 | 商家端全功能 |

> 开发模式：任意合法格式手机号 + 验证码 `123456` 均可登录

---

## 四、后端开发规范

### 4.1 API 统一响应格式

```json
// 成功
{ "code": 0, "msg": "success", "data": {} }

// 分页
{ "code": 0, "msg": "success", "data": [], "total": 100, "page": 1, "per_page": 20, "total_pages": 5 }

// 错误
{ "code": -1, "msg": "错误描述", "data": null }

// 特殊状态码
{ "code": 401, "msg": "未登录" }
{ "code": 403, "msg": "权限不足" }
{ "code": 404, "msg": "资源不存在" }
{ "code": 429, "msg": "请求太频繁" }
```

### 4.2 权限校验

```php
// 要求任意登录用户
$auth = JWT::requireAuth();

// 要求特定角色
$auth = JWT::requireRole('merchant');           // 商家
$auth = JWT::requireRole('admin','super_admin'); // 管理员
$auth = JWT::requireRole('super_admin');         // 仅超管

// $auth 结构
// [
//   'sub'         => int   // user.id
//   'phone'       => string
//   'role'        => string  // buyer|merchant|admin|super_admin
//   'name'        => string
//   'merchant_id' => int|null  // 商家 id
//   'iat'         => int   // issued at
//   'exp'         => int   // expires at
// ]
```

### 4.3 DB 工具类

```php
// 查询全部
DB::select("SELECT * FROM products WHERE status=?", ['online']);

// 查询单条
DB::first("SELECT * FROM users WHERE id=?", [$id]);

// 写操作（返回影响行数）
DB::execute("UPDATE users SET name=? WHERE id=?", [$name, $id]);

// 插入（返回自增ID）
DB::insert("INSERT INTO users (phone,role) VALUES (?,?)", [$phone, 'buyer']);

// 分页（返回 [list, total, page, per_page, total_pages]）
$result = DB::paginate("SELECT * FROM products ORDER BY id DESC", [], $page, 20);
Response::paginated($result);

// 事务
DB::beginTransaction();
try {
    DB::execute("...");
    DB::insert("...");
    DB::commit();
} catch (\Throwable $e) {
    DB::rollback();
    throw $e;
}
```

### 4.4 SMS 接入

```
# .env 配置

# 开发模式（验证码打印到 PHP error_log）
SMS_PROVIDER=mock

# 阿里云（生产）
SMS_PROVIDER=aliyun
SMS_ACCESS_KEY=your_access_key
SMS_SECRET_KEY=your_access_secret
SMS_SIGN_NAME=霄鸟云
SMS_TEMPLATE_CODE=SMS_xxxxxxx

# 腾讯云（生产）
SMS_PROVIDER=tencent
TENCENT_SECRET_ID=your_secret_id
TENCENT_SECRET_KEY=your_secret_key
TENCENT_SMS_APP_ID=your_app_id
TENCENT_SMS_TPL_ID=your_tpl_id
SMS_SIGN_NAME=霄鸟云
```

---

## 五、前端开发规范

### 5.1 API 调用分层

```javascript
// buyer端（src/api/index.js）
import { authApi, productApi, merchantApi, inquiryApi, orderApi,
         msgApi, cartApi, favApi, sampleApi, discoverApi } from '@/api'

// merchant端
import { authApi, dashApi, profileApi, productApi, inquiryApi,
         orderApi, sampleApi, withdrawalApi, msgApi, certApi } from '@/api'

// admin端
import { authApi, adminApi, discoverApi } from '@/api'
```

### 5.2 Token 存储与鉴权

```javascript
// Token 存储位置
localStorage.getItem('xn_token')   // Token字符串
localStorage.getItem('xn_user')    // User JSON对象

// HTTP 拦截器自动附加
// 响应拦截：code=401 自动跳转 /login

// 路由守卫
// meta: { auth: true }  → 需要登录
// meta: { guest: true } → 游客页（已登录则跳转首页）
```

### 5.3 工具函数（src/utils/index.js）

```javascript
import {
  fmtMoney,           // ¥89.00 / ¥1.2万
  fmtNum,             // 1,234 / 1.2w
  fmtDate,            // 2026-03-24 / 2026-03-24 09:32
  fmtRelativeTime,    // 3分钟前 / 2天前
  orderStatusToStep,  // 'production' → 4
  orderStatusLabel,   // 'production' → '生产中'
  orderStatusBadge,   // 'production' → 'badge-info'
  calcTierPrice,      // 阶梯价计算
  isPhone,            // 手机号校验
  isEmail,            // 邮箱校验
  debounce,           // 防抖
  copyText,           // 复制到剪贴板
  levelInfo,          // 等级信息
} from '@/utils'
```

### 5.4 订单状态机（前端标准实现）

```javascript
// 对齐 XN-BIZ-201-02 §1.1 订单6步状态机
const STATUS_STEP = {
  pending_payment: 1,  // 待付款
  paid:            2,  // 已付款
  material:        3,  // 备料中
  production:      4,  // 生产中
  shipping:        5,  // 运输中
  delivered:       5,  // 已送达（同shipping步骤）
  completed:       6,  // 已完成
  cancelled:       0,  // 已取消（不在进度条）
  dispute:         0,  // 纠纷中（不在进度条）
}
```

### 5.5 全局CSS变量（三端统一）

```css
:root {
  --blue: #1677FF;   --blue2: #0958D9;
  --green: #52C41A;  --orange: #FA8C16;
  --red: #FF4D4F;    --gold: #FAAD14;  --purple: #722ED1;
  --t1: #0A0F1E;     --t4: #9CA3AF;   --t6: #F3F4F6;
  --border: #E5E7EB; --bg0: #F8FAFC;
  --r8: 8px;         --r12: 12px;     --r16: 16px;
  --sh: 0 2px 8px rgba(0,0,0,.08);
}
```

---

## 六、业务接口清单（65条）

### 认证（4条）
| Method | Path | 说明 |
|--------|------|------|
| POST | /api/auth/send-code | 发送验证码 |
| POST | /api/auth/login | 手机号验证码登录 |
| GET | /api/auth/me | 获取当前用户信息 |
| DELETE | /api/auth/me | 退出登录 |

### 产品（5条）
| Method | Path | 权限 | 说明 |
|--------|------|------|------|
| GET | /api/products | Public | 产品列表（支持筛选/分页） |
| POST | /api/products | merchant | 发布产品 |
| GET | /api/products/{id} | Public | 产品详情（含阶梯价/认证/评价） |
| PATCH | /api/products/{id} | merchant | 更新产品 |
| DELETE | /api/products/{id} | merchant | 删除产品 |

### 工厂（2条）
| GET | /api/merchants | Public | 工厂列表 |
| GET | /api/merchants/{id} | Public | 工厂详情 |

### 询盘（4条）
| POST | /api/inquiries | buyer | 发起询盘 |
| GET | /api/inquiries | buyer/merchant | 询盘列表（角色隔离） |
| GET | /api/inquiries/{id} | buyer/merchant | 询盘详情 |
| PATCH | /api/inquiries/{id} | 双方 | 状态流转（quote/close/convert） |

### 订单（4条）
| POST | /api/orders | buyer | 下单 |
| GET | /api/orders | buyer/merchant | 订单列表 |
| GET | /api/orders/{id} | 双方 | 订单详情 |
| PATCH | /api/orders/{id} | 按角色 | 状态流转（9个action） |

> 订单状态机 action 列表：
> `pay` / `start_material` / `start_production` / `ship` / `deliver` / `confirm_receipt` / `cancel` / `dispute` / `resolve_dispute`

### 消息（4条）
| GET | /api/conversations | auth | 会话列表 |
| POST | /api/conversations | auth | 创建会话 |
| GET | /api/conversations/{id}/messages | auth | 消息列表 |
| POST | /api/conversations/{id}/messages | auth | 发送消息 |

### 采购清单（3条）
| GET | /api/cart | buyer | 清单列表（含阶梯价计算） |
| POST | /api/cart | buyer | 加入/更新清单 |
| DELETE | /api/cart | buyer | 移除（product_id参数）/清空 |

### 收藏（2条）
| GET | /api/favorites | buyer | 收藏列表 |
| POST | /api/favorites | buyer | 切换收藏（toggle） |

### 样品（3条）
| GET | /api/samples | buyer/merchant | 样品列表（角色隔离） |
| POST | /api/samples | buyer | 申请样品 |
| PATCH | /api/samples/{id} | merchant | 处理（accept/reject/ship） |

### 发现类（9条）
| GET | /api/search | Public | 搜索产品+工厂 |
| GET | /api/banners | Public | Banner列表 |
| GET | /api/currencies | Public | 汇率列表 |
| GET | /api/notifications | auth | 通知列表 |
| PATCH | /api/notifications | auth | 标记已读 |
| GET | /api/ips | Public | IP授权列表 |
| POST | /api/ips/apply | buyer | 申请IP授权 |
| GET | /api/posts | Public | 玩具圈帖子 |
| POST | /api/posts | auth | 发布帖子 |
| GET | /api/ranking | Public | 热销榜（按地区） |

### 商家端（5条）
| GET | /api/merchant/dashboard | merchant | 仪表盘数据 |
| GET | /api/merchant/profile | merchant | 商家详情+认证 |
| PATCH | /api/merchant/profile | merchant | 更新商家信息 |
| GET | /api/withdrawals | merchant | 提现列表 |
| POST | /api/withdrawals | merchant | 申请提现 |

### 管理端（20条）
| GET/PATCH | /api/admin/dashboard | admin | 运营大盘 |
| GET/PATCH | /api/admin/users/{id} | admin | 用户管理 |
| GET/PATCH | /api/admin/merchants/{id} | admin | 商家管理 |
| GET/PATCH | /api/admin/products/{id} | admin | 产品审核 |
| GET | /api/admin/orders | admin | 订单监控 |
| GET | /api/admin/inquiries | admin | 询盘管理 |
| GET/PATCH | /api/admin/content/{id} | admin | 内容管理 |
| GET | /api/admin/finance | super_admin | 财务结算 |
| PATCH | /api/admin/finance/withdrawals/{id} | super_admin | 提现审批 |
| GET/PATCH | /api/admin/ips/{id} | admin | IP授权管理 |
| GET | /api/admin/logs | admin | 操作日志 |
| GET/PATCH | /api/admin/config | super_admin | 系统配置 |

---

## 七、多角色权限矩阵

| 功能 | L0游客 | L1买家 | L2商家 | L4管理员 | L5超管 |
|------|:------:|:------:|:------:|:--------:|:------:|
| 浏览产品/工厂 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 收藏/询盘/下单 | ❌ | ✅ | ❌ | ❌ | ❌ |
| 发布产品 | ❌ | ❌ | ✅ | ❌ | ❌ |
| 订单状态推进（备料/生产/发货）| ❌ | ❌ | ✅ | ❌ | ❌ |
| 用户管理 | ❌ | ❌ | ❌ | ✅ | ✅ |
| 商家/产品审核 | ❌ | ❌ | ❌ | ✅ | ✅ |
| 纠纷调解 | ❌ | ❌ | ❌ | ✅ | ✅ |
| 财务结算/提现审批 | ❌ | ❌ | ❌ | ❌ | ✅ |
| 系统配置 | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 八、已完成核心功能清单

### 后端（19个控制器）

| 控制器 | 行数 | 核心功能 |
|--------|------|---------|
| AuthController | 178 | 验证码发送（SMS三种provider）、JWT登录、自动注册、角色档案读取 |
| ProductController | 266 | 产品CRUD、阶梯价管理、认证关联、状态机（draft→pending→online） |
| InquiryController | 205 | 询盘创建（含items）、状态流转、数据双向隔离 |
| OrderController | 346 | 订单创建（含佣金计算）、9种action状态机、纠纷处理 |
| CartController | 150 | 阶梯价实时计算、upsert/remove/clear |
| ConversationController | 120 | 会话管理、消息分页（轮询+首次加载）、未读计数 |
| MerchantController | 80 | 工厂列表/详情（含认证/分类） |
| MerchantDashController | 100 | 仪表盘KPI、6月趋势、到期认证 |
| AdminController | 351 | 运营大盘、用户/商家/产品/订单/IP/内容/财务/系统全管理 |
| SampleController | 78 | 样品申请（买家）、处理流程（商家） |
| FavoriteController | 45 | 收藏toggle、列表 |
| SearchController | 49 | 全文搜索（产品+工厂） |
| IpController | 40 | IP授权列表、申请 |
| PostController | 55 | 玩具圈帖子（角色自动分类、审核机制） |
| WithdrawalController | 35 | 提现申请、最低金额校验 |
| BannerController | 25 | Banner按位置查询 |
| CurrencyController | 35 | 汇率列表（含静态兜底） |
| RankingController | 42 | 热销榜按地区 |
| NotificationController | 48 | 通知列表、标记已读（单条/全部） |

### 前端（51个Vue页面/组件）

**用户端（25个.vue文件）**
- 20个页面：Home/Products/ProductDetail/Factories/FactoryDetail/Search/Ranking/IPs/Circle/Currency/Cart/Inquiries/InquiryDetail/Orders/OrderDetail/Messages/Samples/Favorites/Profile/Login
- 5个组件：ProductCard/ToastProvider/EmptyState/LoadingSpinner 等

**商家端（12个.vue文件）**
- Login/Layout + 9个业务页：Dashboard/Inquiries/Products/Orders/Samples/Messages/Analytics/Certs/Settings

**管理端（14个.vue文件）**
- Login/Layout + 12个业务页：Dashboard/Users/Merchants/Products/Orders/Inquiries/IPs/Content/Finance/Analytics/System

### 工具层
- `SMS.php` Helper：mock/阿里云/腾讯云三种 provider 可插拔切换
- `utils/index.js`：17个工具函数（格式化/校验/状态机/阶梯价）
- `DB.php`：select/first/execute/insert/paginate + 事务支持
- `JWT.php`：HS256签发验证、三通道Token读取（Header/Cookie/Query）

---

## 九、联调自测说明

### 9.1 接口连通性验证

```bash
# 1. 发送验证码（mock模式下查看php error_log）
curl -X POST http://localhost:8080/api/auth/send-code \
  -H "Content-Type: application/json" \
  -d '{"phone":"18888888888","purpose":"login"}'

# 2. 登录获取Token
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"18888888888","code":"123456"}' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['token'])")

# 3. 获取产品列表
curl http://localhost:8080/api/products?per_page=5 \
  -H "Authorization: Bearer $TOKEN"

# 4. 获取购物车
curl http://localhost:8080/api/cart \
  -H "Authorization: Bearer $TOKEN"

# 5. 管理端大盘
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800000000","code":"123456"}' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['token'])")

curl http://localhost:8080/api/admin/dashboard \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 9.2 功能自测检查点

**用户端**
- [ ] 注册/登录（验证码倒计时、6位格式校验）
- [ ] 产品列表筛选（品类/排序/搜索联动，切换重置到第1页）
- [ ] 产品详情阶梯价（数量变动时实时更新价格）
- [ ] 询盘表单（内容≥5字校验、blur+submit双重）
- [ ] 购物车（阶梯价实时计算、批量发送询盘分组逻辑）
- [ ] 订单进度条（6步状态机对应）
- [ ] 消息双向对话（发送、自动回复模拟）
- [ ] 收藏toggle（心形图标即时变化）

**商家端**
- [ ] 仪表盘数字与订单/询盘列表一致
- [ ] 报价弹窗：报价内容必填校验
- [ ] 订单状态推进（备料→生产→录入发货）
- [ ] 快递单号必填校验
- [ ] 认证即将到期提醒

**管理端**
- [ ] 超管登录可见财务/系统菜单
- [ ] 运营管理员不可见财务/系统菜单
- [ ] 商家通过/拒绝流程
- [ ] 纠纷调解（reason≥5字校验）
- [ ] 系统配置修改（仅超管）

---

## 十、生产部署指南

### 10.1 Nginx 配置

```nginx
server {
    listen 80;
    server_name api.xiaoniao.com;
    root /var/www/xiaoniao-php/backend/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

### 10.2 环境变量（生产）

```bash
APP_ENV=production
APP_DEBUG=false
DB_PASS=强密码
JWT_SECRET=64位随机字符串
SMS_PROVIDER=aliyun   # 或 tencent
SMS_ACCESS_KEY=...
```

### 10.3 前端构建

```bash
# 构建各端（产出到 dist/ 目录）
cd frontend/buyer    && npm run build
cd frontend/merchant && npm run build
cd frontend/admin    && npm run build
```

---

## 十一、版本归档

| 文件 | 说明 | 大小 |
|------|------|------|
| `xiaoniao-php-final.tar.gz` | 完整工程源码包 | ~132KB |
| `database/schema.sql` | 33张表完整DDL | — |
| `database/seed.sql` | 演示种子数据 | — |

**归档校验（SHA256）：**
```bash
sha256sum xiaoniao-php-final.tar.gz
```

---

*本文档为【201-07】阶段最终交付物，与工程源码同步归档。*
