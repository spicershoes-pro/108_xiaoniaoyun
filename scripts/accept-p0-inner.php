<?php
/** P0 ????? API ???? */
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

echo "==> P0 flow @ {$base}\n";

$buyer = http('POST', '/api/auth/login', ['phone' => '18888888888', 'code' => '123456']);
check('buyer login', $buyer);
$bt = $buyer['data']['token'] ?? '';
if (!$bt) {
    echo "\n=== {$ok} passed, {$fail} failed (aborted) ===\n";
    exit(1);
}

$inq = http('POST', '/api/inquiries', [
    'merchant_id' => 1,
    'message'     => 'P0??????????',
    'items'       => [['product_id' => 1, 'qty' => 500]],
], $bt);
check('create inquiry', $inq);
$inqId = (int)($inq['data']['id'] ?? 0);

$merch = http('POST', '/api/auth/login', ['phone' => '13900000001', 'code' => '123456']);
check('merchant login', $merch);
$mt = $merch['data']['token'] ?? '';

$quote = http('PATCH', "/api/inquiries/{$inqId}", [
    'action'      => 'quote',
    'quote_price' => '?88/??',
    'quote_note'  => 'P0???????',
], $mt);
check('merchant quote', $quote);

$ord = http('POST', '/api/orders', ['inquiry_id' => $inqId], $bt);
check('create order', $ord);
$ordId = (int)($ord['data']['id'] ?? 0);

check('pay deposit', http('PATCH', "/api/orders/{$ordId}", ['action' => 'pay', 'deposit_ratio' => 0.5], $bt));
check('start material', http('PATCH', "/api/orders/{$ordId}", ['action' => 'start_material'], $mt));
check('start production', http('PATCH', "/api/orders/{$ordId}", ['action' => 'start_production'], $mt));
check('ship order', http('PATCH', "/api/orders/{$ordId}", [
    'action'           => 'ship',
    'express_company'  => '???',
    'express_no'       => 'SF' . time(),
], $mt));
check('confirm receipt', http('PATCH', "/api/orders/{$ordId}", ['action' => 'confirm_receipt'], $bt));

$conv = http('POST', '/api/conversations', ['target_user_id' => 4], $bt);
check('create conversation', $conv);

echo "\n=== P0 flow: {$ok} passed, {$fail} failed ===\n";
exit($fail > 0 ? 1 : 0);
