<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

class CartController
{
    public function index(array $p, array $b): void
    {
        $auth  = JWT::requireAuth();
        $items = DB::select(
            "SELECT ci.*, p.name,p.emoji,p.cover_color,p.base_price,p.moq,p.status,p.merchant_id,
                    mp.short_name AS merchant_name
             FROM cart_items ci
             JOIN products p ON p.id=ci.product_id
             LEFT JOIN merchant_profiles mp ON mp.id=p.merchant_id
             WHERE ci.user_id=? ORDER BY ci.created_at DESC",
            [$auth['sub']]
        );

        $ids = array_column($items, 'product_id');
        $tiersMap = [];
        if ($ids) {
            $ph    = implode(',', array_fill(0, count($ids), '?'));
            $tiers = DB::select("SELECT * FROM product_price_tiers WHERE product_id IN ({$ph}) ORDER BY min_qty", $ids);
            foreach ($tiers as $t) $tiersMap[$t['product_id']][] = $t;
        }

        $total = 0;
        foreach ($items as &$item) {
            $item['price_tiers'] = $tiersMap[$item['product_id']] ?? [];
            // 当前阶梯价
            $currentPrice = (float)$item['base_price'];
            foreach (array_reverse($item['price_tiers']) as $tier) {
                if ($item['qty'] >= $tier['min_qty']) { $currentPrice = (float)$tier['price']; break; }
            }
            $item['current_price'] = $currentPrice;
            $item['subtotal']      = $currentPrice * $item['qty'];
            $total += $item['subtotal'];
        }

        Response::ok(['items' => $items, 'total' => $total, 'count' => count($items)]);
    }

    public function upsert(array $p, array $b): void
    {
        $auth = JWT::requireRole('buyer');
        $pid  = (int)($b['product_id'] ?? 0);
        $qty  = (int)($b['qty'] ?? 0);
        if (!$pid || $qty < 1) Response::error('参数错误');

        $product = DB::first("SELECT * FROM products WHERE id=? AND status='online'", [$pid]);
        if (!$product) Response::error('产品不可用', 400);
        if ($qty < $product['moq']) Response::error("最小起订量为 {$product['moq']} 件");

        $existing = DB::first("SELECT id FROM cart_items WHERE user_id=? AND product_id=?", [$auth['sub'], $pid]);
        if ($existing) {
            DB::execute("UPDATE cart_items SET qty=? WHERE id=?", [$qty, $existing['id']]);
        } else {
            DB::insert("INSERT INTO cart_items (user_id,product_id,qty) VALUES (?,?,?)", [$auth['sub'], $pid, $qty]);
        }
        Response::ok(null, '已更新采购清单');
    }

    public function remove(array $p, array $b): void
    {
        $auth = JWT::requireAuth();
        $pid  = (int)($_GET['product_id'] ?? 0);
        if ($pid) {
            DB::execute("DELETE FROM cart_items WHERE user_id=? AND product_id=?", [$auth['sub'], $pid]);
            Response::ok(null, '已从清单移除');
        }
        DB::execute("DELETE FROM cart_items WHERE user_id=?", [$auth['sub']]);
        Response::ok(null, '清单已清空');
    }
}

// ── FavoriteController ────────────────────────────────────────
