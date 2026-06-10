<?php
namespace App\Helpers;

class JWT
{
    private static function secret(): string
    {
        $cfg = require ROOT . '/config/app.php';
        return $cfg['jwt_secret'];
    }

    private static function expireHours(): int
    {
        $cfg = require ROOT . '/config/app.php';
        return $cfg['jwt_expire'];
    }

    /** 签发 Token */
    public static function sign(array $payload): string
    {
        $header  = self::base64url(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
        $payload['iat'] = time();
        $payload['exp'] = time() + self::expireHours() * 3600;
        $body    = self::base64url(json_encode($payload, JSON_UNESCAPED_UNICODE));
        $sig     = self::base64url(hash_hmac('sha256', "$header.$body", self::secret(), true));
        return "$header.$body.$sig";
    }

    /** 验证并解析 Token，失败返回 null */
    public static function verify(string $token): ?array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) return null;

        [$header, $body, $sig] = $parts;
        $expected = self::base64url(hash_hmac('sha256', "$header.$body", self::secret(), true));

        // 时间安全比较
        if (!hash_equals($expected, $sig)) return null;

        $payload = json_decode(self::base64urlDecode($body), true);
        if (!$payload || ($payload['exp'] ?? 0) < time()) return null;

        return $payload;
    }

    /** 从请求头或 Cookie 中取当前用户，失败返回 null */
    public static function currentUser(): ?array
    {
        $token = null;

        // 1. Authorization: Bearer xxx
        $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if (str_starts_with($auth, 'Bearer ')) {
            $token = substr($auth, 7);
        }

        // 2. Cookie xn_token
        if (!$token) {
            $token = $_COOKIE['xn_token'] ?? null;
        }

        // 3. Query string token（移动端兼容）
        if (!$token) {
            $token = $_GET['token'] ?? null;
        }

        if (!$token) return null;
        return self::verify($token);
    }

    /** 要求登录，否则直接输出 401 */
    public static function requireAuth(): array
    {
        $user = self::currentUser();
        if (!$user) {
            Response::unauthorized();
        }
        return $user;
    }

    /** 要求指定角色 */
    public static function requireRole(string ...$roles): array
    {
        $user = self::requireAuth();
        if (!in_array($user['role'], $roles, true)) {
            Response::forbidden();
        }
        return $user;
    }

    private static function base64url(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    private static function base64urlDecode(string $data): string
    {
        return base64_decode(strtr($data, '-_', '+/') . str_repeat('=', (4 - strlen($data) % 4) % 4));
    }
}
