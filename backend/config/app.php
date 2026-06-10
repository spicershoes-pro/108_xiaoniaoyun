<?php
// config/app.php
// 所有配置均从环境变量读取，严禁在此文件硬编码任何密钥或密码

$env = getenv('APP_ENV') ?: 'development';

return [
    // ── 应用基础 ──────────────────────────────────────────────
    'name'       => getenv('APP_NAME')    ?: '霄鸟云',
    'env'        => $env,
    'debug'      => filter_var(getenv('APP_DEBUG') ?: 'false', FILTER_VALIDATE_BOOLEAN),
    'url'        => getenv('APP_URL')     ?: 'http://localhost:8080',
    'version'    => getenv('APP_VERSION') ?: '1.0.0',

    // ── JWT ───────────────────────────────────────────────────
    'jwt_secret' => getenv('JWT_SECRET')       ?: 'xn-dev-secret-not-for-production',
    'jwt_expire' => (int)(getenv('JWT_EXPIRE_HOURS') ?: 168),

    // ── 短信 ──────────────────────────────────────────────────
    'sms_provider' => getenv('SMS_PROVIDER') ?: 'mock',

    // ── CORS ──────────────────────────────────────────────────
    'cors_origins' => array_filter(array_map(
        'trim',
        explode(',', getenv('CORS_ORIGINS') ?: '*')
    )),

    // ── 文件上传 ──────────────────────────────────────────────
    'upload' => [
        'driver'       => getenv('UPLOAD_DRIVER')     ?: 'local',
        'max_mb'       => (int)(getenv('UPLOAD_MAX_MB') ?: 10),
        'local_path'   => getenv('UPLOAD_LOCAL_PATH') ?: __DIR__ . '/../public/uploads/',
        'url_prefix'   => getenv('UPLOAD_URL_PREFIX') ?: '/uploads/',
        'oss_endpoint' => getenv('OSS_ENDPOINT')  ?: '',
        'oss_bucket'   => getenv('OSS_BUCKET')    ?: '',
        'oss_ak'       => getenv('OSS_ACCESS_KEY') ?: '',
        'oss_sk'       => getenv('OSS_SECRET_KEY') ?: '',
        'oss_cdn'      => getenv('OSS_CDN_PREFIX') ?: '',
    ],

    // ── 缓存 ──────────────────────────────────────────────────
    'cache' => [
        'driver'   => getenv('CACHE_DRIVER') ?: 'none',
        'redis' => [
            'host'     => getenv('REDIS_HOST') ?: '127.0.0.1',
            'port'     => (int)(getenv('REDIS_PORT') ?: 6379),
            'password' => getenv('REDIS_PASS') ?: null,
            'database' => (int)(getenv('REDIS_DB')   ?: 0),
        ],
    ],

    // ── 日志 ──────────────────────────────────────────────────
    'log' => [
        'level'   => getenv('LOG_LEVEL')   ?: 'debug',
        'channel' => getenv('LOG_CHANNEL') ?: 'stderr',
        'path'    => getenv('LOG_PATH')    ?: '/tmp/xiaoniao/app.log',
    ],

    // ── 平台业务参数 ──────────────────────────────────────────
    'fee_rate'       => (float)(getenv('PLATFORM_FEE_RATE') ?: 0.05),
    'min_withdrawal' => (int)(getenv('MIN_WITHDRAWAL')       ?: 1000),
    'inquiry_expire' => (int)(getenv('INQUIRY_EXPIRE_DAYS')  ?: 30),
    'sample_max_qty' => (int)(getenv('SAMPLE_MAX_QTY')       ?: 5),

    // ── 安全开关 ──────────────────────────────────────────────
    'allow_universal_code' => $env === 'development'
        || filter_var(getenv('ALLOW_UNIVERSAL_CODE') ?: 'false', FILTER_VALIDATE_BOOLEAN),

    'force_https' => filter_var(getenv('FORCE_HTTPS') ?: 'false', FILTER_VALIDATE_BOOLEAN),
    'rate_limit'  => (int)(getenv('RATE_LIMIT_PER_MIN') ?: 0),
];
