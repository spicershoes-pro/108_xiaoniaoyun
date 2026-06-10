<?php
/** 管理端 P0 API 验收 */
$base = getenv('XNY_API_BASE') ?: 'http://127.0.0.1:18080';

function http(string $method, string $path, ?array $body = null, ?string $token = null): array
{
    global $base;
    $ch = curl_init($base . $path);
    $headers = ['Content-Type: application/json'];
    if ($token) {
        $headers[] = "Authorization: Bearer {$token}";
    }
    curl_setopt_array($ch, [
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER     => $headers,
        CURLOPT_TIMEOUT        => 20,
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body, JSON_UNESCAPED_UNICODE));
    }
    $raw = curl_exec($ch);
    curl_close($ch);
    return json_decode($raw ?: '{}', true) ?: [];
}

$ok = 0;
$fail = 0;
function check(string $name, array $d): void
{
    global $ok, $fail;
    $pass = ($d['code'] ?? -1) === 0;
    $pass ? $ok++ : $fail++;
    echo ($pass ? 'PASS' : 'FAIL') . " {$name} code=" . ($d['code'] ?? '?') . "\n";
    if (!$pass && !empty($d['msg'])) {
        echo "      msg: {$d['msg']}\n";
    }
}

echo "==> Admin P0 @ {$base}\n";

$login = http('POST', '/api/auth/login', ['phone' => '13800000000', 'code' => '123456']);
check('admin login', $login);
$token = $login['data']['token'] ?? '';
if (!$token) {
    echo "\n=== {$ok} passed, {$fail} failed ===\n";
    exit(1);
}

check('dashboard', http('GET', '/api/admin/dashboard', null, $token));
check('users', http('GET', '/api/admin/users?per_page=5', null, $token));
check('merchants', http('GET', '/api/admin/merchants?per_page=5', null, $token));
check('products', http('GET', '/api/admin/products?per_page=5', null, $token));
check('orders', http('GET', '/api/admin/orders?per_page=5', null, $token));
check('inquiries', http('GET', '/api/admin/inquiries?per_page=5', null, $token));
check('content', http('GET', '/api/admin/content?per_page=5', null, $token));
check('finance', http('GET', '/api/admin/finance', null, $token));
check('ips', http('GET', '/api/admin/ips?per_page=5', null, $token));
check('config', http('GET', '/api/admin/config', null, $token));

$pending = http('GET', '/api/admin/products?status=pending&per_page=1', null, $token);
$pid = (int)($pending['data'][0]['id'] ?? 0);
if ($pid) {
    check('approve product', http('PATCH', "/api/admin/products/{$pid}", ['action' => 'approve'], $token));
} else {
    echo "SKIP approve product (no pending)\n";
}

echo "\n=== Admin: {$ok} passed, {$fail} failed ===\n";
exit($fail > 0 ? 1 : 0);
