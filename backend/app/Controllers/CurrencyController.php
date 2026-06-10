<?php
namespace App\Controllers;
use App\Helpers\{DB, Response};

class CurrencyController
{
    /** GET /api/currencies */
    public function index(array $p, array $b): void
    {
        $currencies = DB::select(
            "SELECT currency_code, rate_to_cny, updated_at
             FROM exchange_rates
             ORDER BY currency_code ASC"
        );

        // 如果表为空则返回静态兜底数据
        if (empty($currencies)) {
            $currencies = [
                ['currency_code'=>'USD','rate_to_cny'=>7.24,'updated_at'=>date('Y-m-d H:i:s')],
                ['currency_code'=>'EUR','rate_to_cny'=>7.89,'updated_at'=>date('Y-m-d H:i:s')],
                ['currency_code'=>'GBP','rate_to_cny'=>9.18,'updated_at'=>date('Y-m-d H:i:s')],
                ['currency_code'=>'JPY','rate_to_cny'=>0.048,'updated_at'=>date('Y-m-d H:i:s')],
                ['currency_code'=>'KRW','rate_to_cny'=>0.0054,'updated_at'=>date('Y-m-d H:i:s')],
                ['currency_code'=>'AED','rate_to_cny'=>1.97,'updated_at'=>date('Y-m-d H:i:s')],
            ];
        }

        Response::ok($currencies);
    }
}
