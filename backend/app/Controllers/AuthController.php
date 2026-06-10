<?php
namespace App\Controllers;

use App\Helpers\{DB, JWT, Response, SMS};

class AuthController
{
    /** POST /api/auth/send-code */
    public function sendCode(array $params, array $body): void
    {
        $phone   = trim($body['phone'] ?? '');
        $purpose = $body['purpose'] ?? 'login';

        if (!preg_match('/^1[3-9]\d{9}$/', $phone)) {
            Response::error('手机号格式不正确');
        }

        // 60秒限流
        $recent = DB::first(
            "SELECT id FROM verification_codes
             WHERE phone=? AND purpose=? AND used_at IS NULL AND created_at >= DATE_SUB(NOW(), INTERVAL 60 SECOND)
             LIMIT 1",
            [$phone, $purpose]
        );
        if ($recent) {
            Response::error('发送太频繁，请60秒后再试', 429);
        }

        // 使旧验证码失效
        DB::execute(
            "UPDATE verification_codes SET used_at=NOW() WHERE phone=? AND purpose=? AND used_at IS NULL",
            [$phone, $purpose]
        );

        $code      = (string)random_int(100000, 999999);
        $expiresAt = date('Y-m-d H:i:s', strtotime('+5 minutes'));

        DB::insert(
            "INSERT INTO verification_codes (phone,code,purpose,expires_at) VALUES (?,?,?,?)",
            [$phone, $code, $purpose, $expiresAt]
        );

        // 发送短信
        SMS::sendCode($phone, $code);

        Response::ok(['expire_seconds' => 300], '验证码已发送');
    }

    /** POST /api/auth/login */
    public function login(array $params, array $body): void
    {
        $phone = trim($body['phone'] ?? '');
        $code  = trim($body['code']  ?? '');

        if (!preg_match('/^1[3-9]\d{9}$/', $phone)) Response::error('手机号格式不正确');
        if (strlen($code) !== 6)                      Response::error('验证码为6位数字');

        // 万能码（仅 APP_ENV=development 或显式配置 ALLOW_UNIVERSAL_CODE=true 时生效）
        $cfg         = require ROOT . '/config/app.php';
        $isUniversal = ($cfg['allow_universal_code'] ?? false) && $code === '123456';

        if (!$isUniversal) {
            $record = DB::first(
                "SELECT id FROM verification_codes
                 WHERE phone=? AND code=? AND used_at IS NULL AND expires_at >= NOW()
                 ORDER BY created_at DESC LIMIT 1",
                [$phone, $code]
            );
            if (!$record) Response::error('验证码错误或已过期');
            DB::execute("UPDATE verification_codes SET used_at=NOW() WHERE id=?", [$record['id']]);
        }

        // 查找或创建用户
        $user  = DB::first("SELECT * FROM users WHERE phone=? LIMIT 1", [$phone]);
        $isNew = false;

        if (!$user) {
            $userId = DB::insert(
                "INSERT INTO users (phone,role,status) VALUES (?,'buyer','active')",
                [$phone]
            );
            DB::insert(
                "INSERT INTO buyer_profiles (user_id,level,credit_score) VALUES (?,?,100)",
                [$userId, 'bronze']
            );
            $user  = DB::first("SELECT * FROM users WHERE id=?", [$userId]);
            $isNew = true;
        }

        if ($user['status'] === 'suspended') {
            Response::error('账号已被封禁，请联系客服', 403);
        }

        // 读取角色关联档案
        $profile    = $this->getProfile($user);
        $merchantId = $profile['merchant_id'] ?? null;

        $token = JWT::sign([
            'sub'         => $user['id'],
            'phone'       => $user['phone'],
            'role'        => $user['role'],
            'name'        => $user['name'],
            'merchant_id' => $merchantId,
        ]);

        // 设置 Cookie（7天）
        $cfg = require ROOT . '/config/app.php';
        setcookie('xn_token', $token, time() + $cfg['jwt_expire'] * 3600, '/', '', false, true);

        Response::ok([
            'token'  => $token,
            'user'   => array_merge($user, ['password' => null], $profile),
            'is_new' => $isNew,
        ], $isNew ? '注册成功' : '登录成功');
    }

    /** GET /api/auth/me */
    public function me(array $params, array $body): void
    {
        $auth    = JWT::requireAuth();
        $user    = DB::first("SELECT id,phone,email,name,avatar,role,status,created_at FROM users WHERE id=?", [$auth['sub']]);
        if (!$user) Response::notFound('用户不存在');

        $profile = $this->getProfile($user);
        $stats   = $this->getStats($user['id'], $user['role'], $profile['merchant_id'] ?? null);

        Response::ok(array_merge($user, $profile, ['stats' => $stats]));
    }

    /** DELETE /api/auth/me */
    public function logout(array $params, array $body): void
    {
        setcookie('xn_token', '', time() - 3600, '/');
        Response::ok(null, '已退出登录');
    }

    // ── 私有方法 ──────────────────────────────────────────────

    private function getProfile(array $user): array
    {
        if ($user['role'] === 'buyer') {
            $p = DB::first("SELECT * FROM buyer_profiles WHERE user_id=?", [$user['id']]);
            return ['buyer_profile' => $p, 'merchant_id' => null];
        }
        if (in_array($user['role'], ['merchant'])) {
            $p = DB::first("SELECT * FROM merchant_profiles WHERE user_id=?", [$user['id']]);
            return ['merchant_profile' => $p, 'merchant_id' => $p['id'] ?? null];
        }
        return ['merchant_id' => null];
    }

    private function getStats(int $userId, string $role, ?int $merchantId): array
    {
        if ($role === 'buyer') {
            return [
                'orders'    => DB::first("SELECT COUNT(*) c FROM orders WHERE buyer_id=?", [$userId])['c'] ?? 0,
                'inquiries' => DB::first("SELECT COUNT(*) c FROM inquiries WHERE buyer_id=?", [$userId])['c'] ?? 0,
                'favorites' => DB::first("SELECT COUNT(*) c FROM favorites WHERE user_id=?", [$userId])['c'] ?? 0,
                'samples'   => DB::first("SELECT COUNT(*) c FROM sample_requests WHERE buyer_id=?", [$userId])['c'] ?? 0,
            ];
        }
        if ($role === 'merchant' && $merchantId) {
            return [
                'orders'    => DB::first("SELECT COUNT(*) c FROM orders WHERE merchant_id=?", [$merchantId])['c'] ?? 0,
                'inquiries' => DB::first("SELECT COUNT(*) c FROM inquiries WHERE merchant_id=?", [$merchantId])['c'] ?? 0,
                'products'  => DB::first("SELECT COUNT(*) c FROM products WHERE merchant_id=?", [$merchantId])['c'] ?? 0,
            ];
        }
        return [];
    }
}
