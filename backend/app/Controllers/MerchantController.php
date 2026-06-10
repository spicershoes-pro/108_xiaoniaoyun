<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

class MerchantController
{
    public function index(array $p, array $b): void
    {
        $q       = $_GET['q']        ?? '';
        $page    = max(1, (int)($_GET['page']     ?? 1));
        $perPage = min(100, (int)($_GET['per_page'] ?? 20));

        $where = ["mp.status='active'"]; $binds = [];
        if ($q) {
            $like    = "%{$q}%";
            $where[] = '(mp.company_name LIKE ? OR mp.short_name LIKE ?)';
            $binds   = array_merge($binds, [$like, $like]);
        }

        $result = DB::paginate(
            "SELECT mp.*,GROUP_CONCAT(DISTINCT mc.category ORDER BY mc.category SEPARATOR ',') AS categories_str
             FROM merchant_profiles mp
             LEFT JOIN merchant_categories mc ON mc.merchant_id=mp.id
             WHERE " . implode(' AND ',$where) . "
             GROUP BY mp.id ORDER BY mp.rating DESC",
            $binds, $page, $perPage
        );

        foreach ($result['list'] as &$row) {
            $row['categories'] = $row['categories_str'] ? explode(',', $row['categories_str']) : [];
            unset($row['categories_str']);
            $row['certs'] = array_column(DB::select("SELECT name FROM merchant_certs WHERE merchant_id=? AND status='valid'", [$row['id']]), 'name');
        }

        Response::paginated($result);
    }

    public function show(array $p, array $b): void
    {
        $id = (int)($p['id'] ?? 0);
        $merchant = DB::first("SELECT * FROM merchant_profiles WHERE id=? AND status='active'", [$id]);
        if (!$merchant) Response::notFound('工厂不存在');

        $merchant['categories']  = array_column(DB::select("SELECT category FROM merchant_categories WHERE merchant_id=?", [$id]), 'category');
        $merchant['certs']       = DB::select("SELECT * FROM merchant_certs WHERE merchant_id=?", [$id]);
        $merchant['products']    = DB::select(
            "SELECT p.*,GROUP_CONCAT(pc.name SEPARATOR ',') AS cert_names
             FROM products p
             LEFT JOIN product_certs pc ON pc.product_id=p.id
             WHERE p.merchant_id=? AND p.status='online'
             GROUP BY p.id ORDER BY p.sales_count DESC LIMIT 12",
            [$id]
        );
        foreach ($merchant['products'] as &$pr) {
            $pr['certs']       = $pr['cert_names'] ? explode(',', $pr['cert_names']) : [];
            $pr['price_tiers'] = DB::select("SELECT * FROM product_price_tiers WHERE product_id=? ORDER BY min_qty LIMIT 1", [$pr['id']]);
            unset($pr['cert_names']);
        }

        Response::ok($merchant);
    }
}

// ── MerchantDashController（商家端专属）──────────────────────
