<?php
/** Merchant P0 API acceptance */
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

echo "==> Merchant P0 @ {$base}\n";

$login = http('POST', '/api/auth/login', ['phone' => '13900000001', 'code' => '123456']);
check('merchant login', $login);
$token = $login['data']['token'] ?? '';
if (!$token) {
    echo "\n=== {$ok} passed, {$fail} failed ===\n";
    exit(1);
}

check('dashboard', http('GET', '/api/merchant/dashboard', null, $token));
check('profile', http('GET', '/api/merchant/profile', null, $token));

$products = http('GET', '/api/products?status=all&per_page=50', null, $token);
check('products list (own)', $products);
$list = $products['data'] ?? [];
$allOwn = true;
foreach ($list as $p) {
    if ((int)($p['merchant_id'] ?? 0) !== 1) {
        $allOwn = false;
        break;
    }
}
echo ($allOwn ? 'PASS' : 'FAIL') . " products scoped to merchant_id=1\n";
$allOwn ? $ok++ : $fail++;

$inquiries = http('GET', '/api/inquiries?status=pending&per_page=10', null, $token);
check('inquiries list', $inquiries);
$inqId = (int)($inquiries['data'][0]['id'] ?? 0);
if ($inqId) {
    check('quote inquiry', http('PATCH', "/api/inquiries/{$inqId}", [
        'action'      => 'quote',
        'quote_price' => 'CNY 90/unit',
        'quote_note'  => 'merchant acceptance test',
    ], $token));
} else {
    echo "SKIP quote (no pending inquiry)\n";
}

$orders = http('GET', '/api/orders?status=paid&per_page=1', null, $token);
check('orders list', $orders);
$ordId = (int)($orders['data'][0]['id'] ?? 0);
if ($ordId) {
    check('start material', http('PATCH', "/api/orders/{$ordId}", ['action' => 'start_material'], $token));
}

echo "\n=== Merchant: {$ok} passed, {$fail} failed ===\n";
exit($fail > 0 ? 1 : 0);
