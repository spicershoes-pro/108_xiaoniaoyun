<?php
namespace App\Controllers;
use App\Helpers\{DB, Response};

class SearchController
{
    /** GET /api/search?q=xxx&per_page=20 */
    public function search(array $p, array $b): void
    {
        $q       = trim($_GET['q'] ?? '');
        $perPage = min((int)($_GET['per_page'] ?? 20), 50);

        if (strlen($q) < 1) {
            Response::ok(['products' => [], 'merchants' => [], 'total' => 0]);
        }

        $like = "%{$q}%";

        $products = DB::select(
            "SELECT p.id, p.name, p.emoji, p.cover_color, p.base_price, p.moq,
                    p.sales_count, p.rating, mp.short_name AS merchant_name, p.status
             FROM products p
             LEFT JOIN merchant_profiles mp ON mp.id = p.merchant_id
             WHERE p.status='online'
               AND (p.name LIKE ? OR p.category LIKE ? OR p.description LIKE ?)
             ORDER BY p.sales_count DESC
             LIMIT ?",
            [$like, $like, $like, $perPage]
        );

        $merchants = DB::select(
            "SELECT mp.id, mp.short_name, mp.province, mp.city,
                    mp.rating, mp.status, mp.level, mp.response_rate
             FROM merchant_profiles mp
             WHERE mp.status='active'
               AND (mp.short_name LIKE ? OR mp.full_name LIKE ? OR mp.city LIKE ?)
             ORDER BY mp.rating DESC
             LIMIT 10",
            [$like, $like, $like]
        );

        Response::ok([
            'products'  => $products,
            'merchants' => $merchants,
            'total'     => count($products) + count($merchants),
            'keyword'   => $q,
        ]);
    }
}
