<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

class IpController
{
    public function index(array $p, array $b): void
    {
        $category = $_GET['category'] ?? '';
        $where    = ['1=1']; $binds = [];
        if ($category && $category !== '全部') { $where[] = 'category=?'; $binds[] = $category; }
        $list = DB::select("SELECT * FROM ip_licenses WHERE " . implode(' AND ',$where) . " ORDER BY is_hot DESC,name", $binds);
        Response::ok(['list' => $list, 'total' => count($list)]);
    }

    public function apply(array $p, array $b): void
    {
        $auth = JWT::requireAuth();
        foreach (['ip_id','company','product'] as $f) {
            if (empty($b[$f])) Response::error("字段 {$f} 不能为空");
        }
        $ip = DB::first("SELECT * FROM ip_licenses WHERE id=?", [$b['ip_id']]);
        if (!$ip) Response::notFound('IP授权不存在');
        if ($ip['status'] === 'negotiating') Response::error('该IP正在洽谈中，暂不接受申请', 400);

        $id = DB::insert(
            "INSERT INTO ip_applications (ip_id,user_id,company_name,product,annual_qty,purpose) VALUES (?,?,?,?,?,?)",
            [$b['ip_id'], $auth['sub'], $b['company'], $b['product'], $b['annual_qty'] ?? null, $b['purpose'] ?? null]
        );
        Response::ok(DB::first("SELECT * FROM ip_applications WHERE id=?", [$id]), 'IP授权申请已提交，平台将在3个工作日内回复');
    }
}

// ── PostController ────────────────────────────────────────────
