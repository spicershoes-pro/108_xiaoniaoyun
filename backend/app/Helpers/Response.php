<?php
namespace App\Helpers;

class Response
{
    /** 成功响应 */
    public static function ok(mixed $data = null, string $msg = 'success', int $code = 200): void
    {
        self::json(['code' => 0, 'msg' => $msg, 'data' => $data], $code);
    }

    /** 分页响应 */
    public static function paginated(array $result, string $msg = 'success'): void
    {
        self::json([
            'code'        => 0,
            'msg'         => $msg,
            'data'        => $result['list'],
            'total'       => $result['total'],
            'page'        => $result['page'],
            'per_page'    => $result['per_page'],
            'total_pages' => $result['total_pages'],
        ]);
    }

    /** 错误响应 */
    public static function error(string $msg = '请求失败', int $httpCode = 400, int $code = -1): void
    {
        self::json(['code' => $code, 'msg' => $msg, 'data' => null], $httpCode);
    }

    /** 未授权 */
    public static function unauthorized(string $msg = '未登录或登录已过期'): void
    {
        self::error($msg, 401, 401);
    }

    /** 禁止访问 */
    public static function forbidden(string $msg = '权限不足'): void
    {
        self::error($msg, 403, 403);
    }

    /** 资源不存在 */
    public static function notFound(string $msg = '资源不存在'): void
    {
        self::error($msg, 404, 404);
    }

    /** 核心输出 */
    private static function json(array $payload, int $httpCode = 200): void
    {
        http_response_code($httpCode);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }
}
