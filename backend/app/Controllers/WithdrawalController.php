<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

class WithdrawalController
{
    public function index(array $p, array $b): void
    {
        $auth = JWT::requireRole('merchant');
        $mid  = $auth['merchant_id'] ?? 0;
        $list = DB::select("SELECT * FROM withdrawals WHERE merchant_id=? ORDER BY applied_at DESC", [$mid]);
        Response::ok(['list' => $list, 'total' => count($list)]);
    }

    public function store(array $p, array $b): void
    {
        $auth   = JWT::requireRole('merchant');
        $mid    = $auth['merchant_id'] ?? 0;
        $amount = (float)($b['amount'] ?? 0);
        $cfg    = require ROOT . '/config/app.php';
        if ($amount < $cfg['min_withdrawal']) Response::error("最低提现金额为 ¥{$cfg['min_withdrawal']}");

        $id = DB::insert(
            "INSERT INTO withdrawals (merchant_id,amount,bank_name,bank_account,status) VALUES (?,?,?,?,'pending')",
            [$mid, $amount, $b['bank_name'] ?? null, $b['bank_account'] ?? null]
        );
        Response::ok(DB::first("SELECT * FROM withdrawals WHERE id=?", [$id]), '提现申请已提交');
    }
}
