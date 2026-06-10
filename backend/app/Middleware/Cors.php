<?php
namespace App\Middleware;

class Cors
{
    public static function handle(): void
    {
        $cfg     = require ROOT . '/config/app.php';
        $origins = $cfg['cors_origins'] ?? ['*'];
        $origin  = $_SERVER['HTTP_ORIGIN'] ?? '';

        $allowAll  = in_array('*', $origins);
        $allowThis = $origin && in_array($origin, $origins);

        if ($allowAll) {
            // 开发模式：允许所有来源
            // 注意：生产环境 cors_origins 不应包含 *
            header('Access-Control-Allow-Origin: *');
        } elseif ($allowThis) {
            header("Access-Control-Allow-Origin: {$origin}");
            header('Access-Control-Allow-Credentials: true');
            header('Vary: Origin');
        }

        header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
        header('Access-Control-Allow-Headers: Authorization, Content-Type, X-Requested-With, Accept, Origin');
        header('Access-Control-Max-Age: 86400');
        header('Content-Type: application/json; charset=utf-8');

        // 生产环境添加环境水印（仅 staging）
        $env = $cfg['env'] ?? 'development';
        if ($env === 'staging' && ($cfg['staging_watermark'] ?? false)) {
            header('X-Env: staging');
        }

        if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
            http_response_code(204);
            exit;
        }
    }
}
