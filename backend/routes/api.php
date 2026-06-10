<?php
// routes/api.php
// 轻量路由分发，支持 GET/POST/PATCH/PUT/DELETE

use App\Controllers\AuthController;
use App\Controllers\ProductController;
use App\Controllers\MerchantController;
use App\Controllers\InquiryController;
use App\Controllers\OrderController;
use App\Controllers\ConversationController;
use App\Controllers\CartController;
use App\Controllers\FavoriteController;
use App\Controllers\SampleController;
use App\Controllers\SearchController;
use App\Controllers\BannerController;
use App\Controllers\CurrencyController;
use App\Controllers\NotificationController;
use App\Controllers\IpController;
use App\Controllers\PostController;
use App\Controllers\RankingController;
use App\Controllers\WithdrawalController;
use App\Controllers\MerchantDashController;
use App\Controllers\AdminController;
use App\Helpers\Response;

// 解析路径和方法
$method = $_SERVER['REQUEST_METHOD'];
$uri    = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$uri    = rtrim(preg_replace('#^/api#', '', $uri), '/') ?: '/';

// 解析 JSON body
$body = [];
if (in_array($method, ['POST', 'PUT', 'PATCH'])) {
    $raw = file_get_contents('php://input');
    if ($raw) {
        $body = json_decode($raw, true) ?? [];
    }
}

// ── 路由表 ──────────────────────────────────────────────────
// 格式: [METHOD, pattern, Controller::method]
// pattern 支持 {id} 动态段

$routes = [
    // ── 认证 ──
    ['POST',   '/auth/send-code',              [AuthController::class, 'sendCode']],
    ['POST',   '/auth/login',                  [AuthController::class, 'login']],
    ['GET',    '/auth/me',                     [AuthController::class, 'me']],
    ['DELETE', '/auth/me',                     [AuthController::class, 'logout']],

    // ── 产品 ──
    ['GET',    '/products',                    [ProductController::class, 'index']],
    ['POST',   '/products',                    [ProductController::class, 'store']],
    ['GET',    '/products/{id}',               [ProductController::class, 'show']],
    ['PATCH',  '/products/{id}',               [ProductController::class, 'update']],
    ['DELETE', '/products/{id}',               [ProductController::class, 'destroy']],

    // ── 工厂 ──
    ['GET',    '/merchants',                   [MerchantController::class, 'index']],
    ['GET',    '/merchants/{id}',              [MerchantController::class, 'show']],

    // ── 询盘 ──
    ['GET',    '/inquiries',                   [InquiryController::class, 'index']],
    ['POST',   '/inquiries',                   [InquiryController::class, 'store']],
    ['GET',    '/inquiries/{id}',              [InquiryController::class, 'show']],
    ['PATCH',  '/inquiries/{id}',              [InquiryController::class, 'update']],

    // ── 订单 ──
    ['GET',    '/orders',                      [OrderController::class, 'index']],
    ['POST',   '/orders',                      [OrderController::class, 'store']],
    ['GET',    '/orders/{id}',                 [OrderController::class, 'show']],
    ['PATCH',  '/orders/{id}',                 [OrderController::class, 'update']],

    // ── 消息 ──
    ['GET',    '/conversations',               [ConversationController::class, 'index']],
    ['POST',   '/conversations',               [ConversationController::class, 'store']],
    ['GET',    '/conversations/{id}/messages', [ConversationController::class, 'messages']],
    ['POST',   '/conversations/{id}/messages', [ConversationController::class, 'send']],

    // ── 采购清单 ──
    ['GET',    '/cart',                        [CartController::class, 'index']],
    ['POST',   '/cart',                        [CartController::class, 'upsert']],
    ['DELETE', '/cart',                        [CartController::class, 'remove']],

    // ── 收藏 ──
    ['GET',    '/favorites',                   [FavoriteController::class, 'index']],
    ['POST',   '/favorites',                   [FavoriteController::class, 'toggle']],

    // ── 样品 ──
    ['GET',    '/samples',                     [SampleController::class, 'index']],
    ['POST',   '/samples',                     [SampleController::class, 'store']],
    ['PATCH',  '/samples/{id}',                [SampleController::class, 'update']],

    // ── 搜索 / 发现 ──
    ['GET',    '/search',                      [SearchController::class, 'search']],
    ['GET',    '/banners',                     [BannerController::class, 'index']],
    ['GET',    '/currencies',                  [CurrencyController::class, 'index']],
    ['GET',    '/notifications',               [NotificationController::class, 'index']],
    ['PATCH',  '/notifications',               [NotificationController::class, 'markRead']],
    ['GET',    '/ips',                         [IpController::class, 'index']],
    ['POST',   '/ips/apply',                   [IpController::class, 'apply']],
    ['GET',    '/posts',                       [PostController::class, 'index']],
    ['POST',   '/posts',                       [PostController::class, 'store']],
    ['GET',    '/ranking',                     [RankingController::class, 'index']],

    // ── 商家端 ──
    ['GET',    '/merchant/dashboard',          [MerchantDashController::class, 'index']],
    ['GET',    '/merchant/profile',            [MerchantDashController::class, 'profile']],
    ['PATCH',  '/merchant/profile',            [MerchantDashController::class, 'updateProfile']],
    ['GET',    '/withdrawals',                 [WithdrawalController::class, 'index']],
    ['POST',   '/withdrawals',                 [WithdrawalController::class, 'store']],

    // ── 总管理端 ──
    ['GET',    '/admin/dashboard',             [AdminController::class, 'dashboard']],
    ['GET',    '/admin/users',                 [AdminController::class, 'users']],
    ['PATCH',  '/admin/users/{id}',            [AdminController::class, 'updateUser']],
    ['GET',    '/admin/merchants',             [AdminController::class, 'merchants']],
    ['PATCH',  '/admin/merchants/{id}',        [AdminController::class, 'updateMerchant']],
    ['GET',    '/admin/products',              [AdminController::class, 'products']],
    ['PATCH',  '/admin/products/{id}',         [AdminController::class, 'updateProduct']],
    ['GET',    '/admin/orders',                [AdminController::class, 'orders']],
    ['PATCH',  '/admin/orders/{id}',            [OrderController::class,  'update']],
    ['GET',    '/admin/inquiries',             [AdminController::class, 'inquiries']],
    ['GET',    '/admin/content',               [AdminController::class, 'content']],
    ['PATCH',  '/admin/content/{id}',          [AdminController::class, 'updateContent']],
    ['GET',    '/admin/finance',               [AdminController::class, 'finance']],
    ['PATCH',  '/admin/finance/withdrawals/{id}', [AdminController::class, 'reviewWithdrawal']],
    ['GET',    '/admin/ips',                   [AdminController::class, 'ips']],
    ['PATCH',  '/admin/ips/{id}',              [AdminController::class, 'updateIp']],
    ['GET',    '/admin/logs',                  [AdminController::class, 'logs']],
    ['GET',    '/admin/config',                [AdminController::class, 'config']],
    ['PATCH',  '/admin/config',                [AdminController::class, 'updateConfig']],
];

// ── 路由匹配 ──────────────────────────────────────────────────
$params = [];
$matched = false;

foreach ($routes as [$rMethod, $pattern, $handler]) {
    if ($rMethod !== $method) continue;

    // 把 {id} 转为正则
    $regex = '#^' . preg_replace('#\{(\w+)\}#', '(?P<$1>[^/]+)', $pattern) . '$#';
    if (preg_match($regex, $uri, $m)) {
        // 提取动态参数
        foreach ($m as $k => $v) {
            if (is_string($k)) $params[$k] = $v;
        }
        $matched = true;
        [$class, $action] = $handler;
        (new $class())->$action($params, $body);
        break;
    }
}

if (!$matched) {
    Response::error("接口不存在: {$method} {$uri}", 404);
}
