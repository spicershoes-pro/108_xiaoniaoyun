<?php
/** ?? PHP ????????? HTTP ??? API */
$base = 'http://127.0.0.1:8080';

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
        CURLOPT_TIMEOUT        => 15,
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
    $extra = '';
    if (is_array($d['data'] ?? null)) {
        $extra = ' items=' . count($d['data']);
    }
    echo ($pass ? 'PASS' : 'FAIL') . " {$name} code={$d['code']}{$extra}\n";
}

foreach (['/api/banners', '/api/products?per_page=2', '/api/merchants?per_page=2', '/api/currencies', '/api/ranking?region=US'] as $p) {
    check($p, http('GET', $p));
}

$login = http('POST', '/api/auth/login', ['phone' => '18888888888', 'code' => '123456']);
check('buyer login', $login);
$token = $login['data']['token'] ?? '';
if ($token) {
    check('auth/me', http('GET', '/api/auth/me', null, $token));
}

$m = http('POST', '/api/auth/login', ['phone' => '13900000001', 'code' => '123456']);
check('merchant login', $m);
if (!empty($m['data']['token'])) {
    check('merchant/dashboard', http('GET', '/api/merchant/dashboard', null, $m['data']['token']));
}

$a = http('POST', '/api/auth/login', ['phone' => '13800000000', 'code' => '123456']);
check('admin login', $a);
if (!empty($a['data']['token'])) {
    check('admin/dashboard', http('GET', '/api/admin/dashboard', null, $a['data']['token']));
}

echo "\n=== {$ok} passed, {$fail} failed ===\n";
exit($fail > 0 ? 1 : 0);
