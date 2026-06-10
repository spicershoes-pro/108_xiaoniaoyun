<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

class MerchantDashController
{
    public function index(array $p, array $b): void
    {
        $auth = JWT::requireRole('merchant');
        $mid  = $auth['merchant_id'] ?? 0;
        if (!$mid) Response::error('商家信息未找到', 400);

        $merchant = DB::first("SELECT * FROM merchant_profiles WHERE id=?", [$mid]);

        [$onlineProducts, $totalProducts, $pendingInquiries, $totalInquiries,
         $activeOrders, $totalOrders, $pendingSamples, $monthRevenue, $monthOrders] = [
            DB::first("SELECT COUNT(*) c FROM products WHERE merchant_id=? AND status='online'",[$mid])['c'],
            DB::first("SELECT COUNT(*) c FROM products WHERE merchant_id=?",[$mid])['c'],
            DB::first("SELECT COUNT(*) c FROM inquiries WHERE merchant_id=? AND status='pending'",[$mid])['c'],
            DB::first("SELECT COUNT(*) c FROM inquiries WHERE merchant_id=?",[$mid])['c'],
            DB::first("SELECT COUNT(*) c FROM orders WHERE merchant_id=? AND status IN('paid','material','production','shipping')",[$mid])['c'],
            DB::first("SELECT COUNT(*) c FROM orders WHERE merchant_id=?",[$mid])['c'],
            DB::first("SELECT COUNT(*) c FROM sample_requests WHERE merchant_id=? AND status='pending'",[$mid])['c'],
            DB::first("SELECT COALESCE(SUM(total_amount),0) v FROM orders WHERE merchant_id=? AND status!='cancelled' AND created_at>=DATE_FORMAT(NOW(),'%Y-%m-01')",[$mid])['v'],
            DB::first("SELECT COUNT(*) c FROM orders WHERE merchant_id=? AND status!='cancelled' AND created_at>=DATE_FORMAT(NOW(),'%Y-%m-01')",[$mid])['c'],
        ];

        // 近6月趋势
        $trend = [];
        for ($i = 5; $i >= 0; $i--) {
            $monthStart = date('Y-m-01', strtotime("-{$i} months"));
            $monthEnd   = date('Y-m-t', strtotime("-{$i} months"));
            $row = DB::first(
                "SELECT COALESCE(SUM(total_amount),0) amount, COUNT(*) orders FROM orders WHERE merchant_id=? AND status!='cancelled' AND created_at BETWEEN ? AND ?",
                [$mid, $monthStart, $monthEnd . ' 23:59:59']
            );
            $trend[] = ['month' => date('n月', strtotime($monthStart)), 'amount' => (float)$row['amount'], 'orders' => (int)$row['orders']];
        }

        $recentOrders = DB::select(
            "SELECT o.*,u.name AS buyer_name,bp.company_name AS buyer_company,bp.country,mp.short_name AS merchant_name
             FROM orders o LEFT JOIN users u ON u.id=o.buyer_id LEFT JOIN buyer_profiles bp ON bp.user_id=o.buyer_id
             LEFT JOIN merchant_profiles mp ON mp.id=o.merchant_id
             WHERE o.merchant_id=? ORDER BY o.created_at DESC LIMIT 5",
            [$mid]
        );

        $expiringCerts = DB::select("SELECT * FROM merchant_certs WHERE merchant_id=? AND status IN('expiring','expired')", [$mid]);

        Response::ok([
            'merchant'       => $merchant,
            'kpis'           => compact('onlineProducts','totalProducts','pendingInquiries','totalInquiries','activeOrders','totalOrders','pendingSamples','monthRevenue','monthOrders'),
            'monthly_trend'  => $trend,
            'recent_orders'  => $recentOrders,
            'expiring_certs' => $expiringCerts,
        ]);
    }

    public function profile(array $p, array $b): void
    {
        $auth = JWT::requireRole('merchant');
        $mid  = $auth['merchant_id'] ?? 0;
        $merchant = DB::first("SELECT * FROM merchant_profiles WHERE id=?", [$mid]);
        $merchant['categories']  = array_column(DB::select("SELECT category FROM merchant_categories WHERE merchant_id=?", [$mid]), 'category');
        $merchant['certs']       = DB::select("SELECT * FROM merchant_certs WHERE merchant_id=?", [$mid]);
        $merchant['user']        = DB::first("SELECT id,name,phone,email FROM users WHERE id=?", [$auth['sub']]);
        Response::ok($merchant);
    }

    public function updateProfile(array $p, array $b): void
    {
        $auth = JWT::requireRole('merchant');
        $mid  = $auth['merchant_id'] ?? 0;

        $allowed = ['short_name','description','city','province','staff_range','response_time','bank_name','bank_account','bank_holder'];
        $sets = []; $binds = [];
        foreach ($allowed as $f) {
            if (!array_key_exists($f, $b)) continue;
            $col = $f === 'short_name' ? 'short_name' : $f;
            $sets[]  = "`{$col}` = ?";
            $binds[] = $b[$f];
        }

        if ($sets) {
            $binds[] = $mid;
            DB::execute("UPDATE merchant_profiles SET " . implode(',', $sets) . " WHERE id=?", $binds);
        }

        if (isset($b['categories'])) {
            DB::execute("DELETE FROM merchant_categories WHERE merchant_id=?", [$mid]);
            foreach ($b['categories'] as $cat) {
                DB::execute("INSERT IGNORE INTO merchant_categories (merchant_id,category) VALUES (?,?)", [$mid, $cat]);
            }
        }

        Response::ok(null, '商家信息已更新');
    }
}

// ── AdminController（总管理端）───────────────────────────────
