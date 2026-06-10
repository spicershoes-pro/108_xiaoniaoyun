<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

class FavoriteController
{
    public function index(array $p, array $b): void
    {
        $auth = JWT::requireAuth();
        $list = DB::select(
            "SELECT f.*, p.name,p.emoji,p.cover_color,p.base_price,p.rating,mp.short_name AS merchant_name
             FROM favorites f
             JOIN products p ON p.id=f.product_id
             LEFT JOIN merchant_profiles mp ON mp.id=p.merchant_id
             WHERE f.user_id=? ORDER BY f.created_at DESC",
            [$auth['sub']]
        );
        Response::ok(['list' => $list, 'total' => count($list)]);
    }

    public function toggle(array $p, array $b): void
    {
        $auth = JWT::requireAuth();
        $pid  = (int)($b['product_id'] ?? 0);
        if (!$pid) Response::error('缺少 product_id');

        if (!DB::first("SELECT id FROM products WHERE id=?", [$pid])) Response::notFound('产品不存在');

        $existing = DB::first("SELECT id FROM favorites WHERE user_id=? AND product_id=?", [$auth['sub'], $pid]);
        if ($existing) {
            DB::execute("DELETE FROM favorites WHERE id=?", [$existing['id']]);
            Response::ok(['favorited' => false], '已取消收藏');
        }
        DB::insert("INSERT INTO favorites (user_id,product_id) VALUES (?,?)", [$auth['sub'], $pid]);
        Response::ok(['favorited' => true], '收藏成功');
    }
}

// ── SampleController ─────────────────────────────────────────
