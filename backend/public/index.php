<?php
// public/index.php - 统一入口
// 支持多环境配置自动加载

define('ROOT', dirname(__DIR__));

// ── Step 1: 加载环境变量 ────────────────────────────────────
// 优先级（高→低）：
//   1. 服务器/容器已注入的环境变量（getenv 直接可读）
//   2. 根目录 .env（本地覆盖，不提交 Git）
//   3. config/env/.env.{APP_ENV}（环境专属配置，可提交）
//   4. config/env/.env.development（兜底开发配置）

function loadEnvFile(string $path): void
{
    if (!file_exists($path)) return;
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#') continue;
        if (!str_contains($line, '=')) continue;
        [$k, $v] = explode('=', $line, 2);
        $k = trim($k);
        $v = trim($v, " \t\n\r\0\x0B\"'");
        // 只在未设置时才写入（已有的环境变量优先级更高）
        if ($k && getenv($k) === false) {
            putenv("{$k}={$v}");
        }
    }
}

// 加载本地 .env（最高优先级，本地覆盖）
loadEnvFile(ROOT . '/.env');

// 根据 APP_ENV 加载对应环境配置
$appEnv = getenv('APP_ENV') ?: 'development';
loadEnvFile(ROOT . "/config/env/.env.{$appEnv}");

// 兜底：确保 development 配置始终可用
if ($appEnv !== 'development') {
    // 仅用于填充未被上层覆盖的默认值
}

// ── Step 2: 自动加载 ─────────────────────────────────────────
spl_autoload_register(function (string $class): void {
    $file = ROOT . '/app/' . str_replace(['App\\', '\\'], ['', '/'], $class) . '.php';
    if (file_exists($file)) require $file;
});

// ── Step 3: 错误显示策略（按环境区分） ──────────────────────
$cfg = require ROOT . '/config/app.php';

if ($cfg['debug']) {
    error_reporting(E_ALL);
    ini_set('display_errors', '1');
} else {
    error_reporting(0);
    ini_set('display_errors', '0');
    // 生产错误写入日志
    $logPath = $cfg['log']['path'] ?? '/tmp/xiaoniao/app.log';
    $logDir  = dirname($logPath);
    if (!is_dir($logDir)) @mkdir($logDir, 0755, true);
    ini_set('error_log', $logPath);
    ini_set('log_errors', '1');
}

// ── Step 4: 全局异常处理 ─────────────────────────────────────
set_exception_handler(function (\Throwable $e) use ($cfg): void {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');

    if ($cfg['debug']) {
        // 开发/测试：输出详细错误信息
        $msg = $e->getMessage() . ' [' . $e->getFile() . ':' . $e->getLine() . ']';
    } else {
        // 生产：完全脱敏，不暴露任何内部信息
        error_log('[EXCEPTION] ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
        $msg = '服务器内部错误，请稍后重试';
    }

    echo json_encode(['code' => -1, 'msg' => $msg, 'data' => null], JSON_UNESCAPED_UNICODE);
    exit;
});

// ── Step 5: 强制 HTTPS（生产） ───────────────────────────────
if ($cfg['force_https'] && (!isset($_SERVER['HTTPS']) || $_SERVER['HTTPS'] !== 'on')) {
    $redirectUrl = 'https://' . ($_SERVER['HTTP_HOST'] ?? '') . ($_SERVER['REQUEST_URI'] ?? '/');
    header("Location: {$redirectUrl}", true, 301);
    exit;
}

// ── Step 6: CORS ─────────────────────────────────────────────
use App\Middleware\Cors;
Cors::handle();

// ── Step 7: 路由 ─────────────────────────────────────────────
require ROOT . '/routes/api.php';
