<?php
namespace App\Controllers;
use App\Helpers\{DB, Response};

class RankingController
{
    /** GET /api/ranking?region=US&limit=10 */
    public function index(array $p, array $b): void
    {
        $region = strtoupper($_GET['region'] ?? 'US');
        $limit  = min((int)($_GET['limit'] ?? 10), 50);

        $allowed = ['US','EU','JP','SEA','AU','ME','LATAM'];
        if (!in_array($region, $allowed)) $region = 'US';

        $rows = DB::select(
            "SELECT r.rank_no, r.growth_rate, r.monthly_sales,
                    p.id AS product_id, p.name, p.emoji, p.cover_color,
                    p.base_price, p.moq, mp.short_name AS merchant_name
             FROM product_rankings r
             JOIN products p ON p.id = r.product_id
             LEFT JOIN merchant_profiles mp ON mp.id = p.merchant_id
             WHERE r.region = ?
             ORDER BY r.rank_no ASC
             LIMIT ?",
            [$region, $limit]
        );

        Response::ok([
            'region' => $region,
            'list'   => $rows,
            'total'  => count($rows),
        ]);
    }
}
