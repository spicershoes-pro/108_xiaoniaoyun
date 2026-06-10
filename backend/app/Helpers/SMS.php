<?php
namespace App\Helpers;

/**
 * SMS 短信服务
 * 支持 mock（开发）/ aliyun（阿里云）/ tencent（腾讯云）三种 provider
 * 通过 .env 中 SMS_PROVIDER 切换，无需修改业务代码
 */
class SMS
{
    /**
     * 发送验证码
     * @param  string $phone 11位手机号（中国大陆）
     * @param  string $code  6位验证码
     * @return array  ['ok'=>bool, 'msg'=>string]
     */
    public static function sendCode(string $phone, string $code): array
    {
        $provider = strtolower(getenv('SMS_PROVIDER') ?: 'mock');

        return match ($provider) {
            'aliyun'  => self::sendAliyun($phone, $code),
            'tencent' => self::sendTencent($phone, $code),
            default   => self::sendMock($phone, $code),
        };
    }

    // ── Mock（开发/测试）─────────────────────────────────────

    private static function sendMock(string $phone, string $code): array
    {
        error_log("[SMS MOCK] 手机号: {$phone}  验证码: {$code}  时间: " . date('Y-m-d H:i:s'));
        return ['ok' => true, 'msg' => 'mock发送成功'];
    }

    // ── 阿里云 SMS ───────────────────────────────────────────

    private static function sendAliyun(string $phone, string $code): array
    {
        $accessKey    = getenv('SMS_ACCESS_KEY')    ?: '';
        $accessSecret = getenv('SMS_SECRET_KEY')    ?: '';
        $signName     = getenv('SMS_SIGN_NAME')     ?: '霄鸟云';
        $templateCode = getenv('SMS_TEMPLATE_CODE') ?: '';

        if (!$accessKey || !$accessSecret || !$templateCode) {
            error_log('[SMS] 阿里云配置不完整，回退 mock');
            return self::sendMock($phone, $code);
        }

        $params = [
            'AccessKeyId'      => $accessKey,
            'Action'           => 'SendSms',
            'Format'           => 'JSON',
            'PhoneNumbers'     => $phone,
            'RegionId'         => 'cn-hangzhou',
            'SignName'         => $signName,
            'SignatureMethod'  => 'HMAC-SHA1',
            'SignatureNonce'   => uniqid('', true),
            'SignatureVersion' => '1.0',
            'TemplateCode'     => $templateCode,
            'TemplateParam'    => json_encode(['code' => $code]),
            'Timestamp'        => gmdate('Y-m-d\TH:i:s\Z'),
            'Version'          => '2017-05-25',
        ];

        ksort($params);
        $canonical = urlencode(http_build_query($params));
        $str2sign  = 'GET&%2F&' . $canonical;
        $signature  = base64_encode(hash_hmac('sha1', $str2sign, $accessSecret . '&', true));
        $params['Signature'] = $signature;

        $url = 'https://dysmsapi.aliyuncs.com/?' . http_build_query($params);

        $ctx = stream_context_create(['http' => ['timeout' => 8]]);
        $resp = @file_get_contents($url, false, $ctx);
        if ($resp === false) {
            error_log('[SMS Aliyun] 请求失败');
            return ['ok' => false, 'msg' => '短信服务请求失败'];
        }

        $data = json_decode($resp, true);
        if (($data['Code'] ?? '') === 'OK') {
            return ['ok' => true, 'msg' => '发送成功'];
        }

        error_log('[SMS Aliyun] 发送失败: ' . $resp);
        return ['ok' => false, 'msg' => $data['Message'] ?? '发送失败'];
    }

    // ── 腾讯云 SMS ───────────────────────────────────────────

    private static function sendTencent(string $phone, string $code): array
    {
        $secretId  = getenv('TENCENT_SECRET_ID')  ?: '';
        $secretKey = getenv('TENCENT_SECRET_KEY') ?: '';
        $sdkAppId  = getenv('TENCENT_SMS_APP_ID') ?: '';
        $signName  = getenv('SMS_SIGN_NAME')       ?: '霄鸟云';
        $tplId     = getenv('TENCENT_SMS_TPL_ID') ?: '';

        if (!$secretId || !$secretKey || !$sdkAppId || !$tplId) {
            error_log('[SMS] 腾讯云配置不完整，回退 mock');
            return self::sendMock($phone, $code);
        }

        $host      = 'sms.tencentcloudapi.com';
        $timestamp = time();
        $date      = gmdate('Y-m-d', $timestamp);
        $payload   = json_encode([
            'SmsSdkAppId'   => $sdkAppId,
            'SignName'       => $signName,
            'TemplateId'     => $tplId,
            'TemplateParamSet' => [$code, '5'],
            'PhoneNumberSet' => ["+86{$phone}"],
        ]);

        $algorithm    = 'TC3-HMAC-SHA256';
        $credScope    = "{$date}/sms/tc3_request";
        $canonicalReq = "POST\n/\n\ncontent-type:application/json\nhost:{$host}\n\ncontent-type;host\n" . hash('sha256', $payload);
        $str2sign     = "{$algorithm}\n{$timestamp}\n{$credScope}\n" . hash('sha256', $canonicalReq);

        $secretDate    = hash_hmac('sha256', $date,          "TC3{$secretKey}", true);
        $secretService = hash_hmac('sha256', 'sms',          $secretDate, true);
        $secretSigning = hash_hmac('sha256', 'tc3_request',  $secretService, true);
        $signature     = bin2hex(hash_hmac('sha256', $str2sign, $secretSigning, true));

        $auth = "{$algorithm} Credential={$secretId}/{$credScope}, SignedHeaders=content-type;host, Signature={$signature}";

        $ctx = stream_context_create(['http' => [
            'method'  => 'POST',
            'header'  => "Content-Type: application/json\r\nHost: {$host}\r\nAuthorization: {$auth}\r\n"
                       . "X-TC-Action: SendSms\r\nX-TC-Version: 2021-01-11\r\nX-TC-Timestamp: {$timestamp}\r\nX-TC-Region: ap-guangzhou",
            'content' => $payload,
            'timeout' => 8,
        ]]);

        $resp = @file_get_contents("https://{$host}", false, $ctx);
        if ($resp === false) {
            return ['ok' => false, 'msg' => '短信服务请求失败'];
        }
        $data = json_decode($resp, true);
        $sendStatus = $data['Response']['SendStatusSet'][0] ?? [];
        if (($sendStatus['Code'] ?? '') === 'Ok') {
            return ['ok' => true, 'msg' => '发送成功'];
        }
        error_log('[SMS Tencent] 失败: ' . $resp);
        return ['ok' => false, 'msg' => $sendStatus['Message'] ?? '发送失败'];
    }
}
