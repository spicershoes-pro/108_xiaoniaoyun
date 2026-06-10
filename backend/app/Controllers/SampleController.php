<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

class SampleController
{
    public function index(array $p, array $b): void
    {
        $auth    = JWT::requireAuth();
        $status  = $_GET['status']   ?? 'all';
        $page    = max(1, (int)($_GET['page'] ?? 1));

        $where = ['1=1']; $binds = [];
        if ($auth['role'] === 'buyer')    { $where[] = 'sr.buyer_id=?';    $binds[] = $auth['sub']; }
        if ($auth['role'] === 'merchant') { $where[] = 'sr.merchant_id=?'; $binds[] = $auth['merchant_id']; }
        if ($status !== 'all')            { $where[] = 'sr.status=?';      $binds[] = $status; }

        $whereStr = implode(' AND ', $where);
        $result = DB::paginate(
            "SELECT sr.*,p.name AS product_name,p.emoji,
                    u.name AS buyer_name,bp.company_name AS buyer_company,bp.country,
                    mp.short_name AS merchant_name
             FROM sample_requests sr
             LEFT JOIN products p ON p.id=sr.product_id
             LEFT JOIN users u ON u.id=sr.buyer_id
             LEFT JOIN buyer_profiles bp ON bp.user_id=sr.buyer_id
             LEFT JOIN merchant_profiles mp ON mp.id=sr.merchant_id
             WHERE {$whereStr} ORDER BY sr.created_at DESC",
            $binds, $page, 20
        );
        Response::paginated($result);
    }

    public function store(array $p, array $b): void
    {
        $auth = JWT::requireRole('buyer');
        foreach (['product_id','merchant_id','recipient_name','recipient_phone','recipient_address'] as $f) {
            if (empty($b[$f])) Response::error("字段 {$f} 不能为空");
        }
        $product = DB::first("SELECT * FROM products WHERE id=? AND status='online'", [$b['product_id']]);
        if (!$product || $product['merchant_id'] != $b['merchant_id']) Response::error('产品不可用', 400);

        $id = DB::insert(
            "INSERT INTO sample_requests (buyer_id,merchant_id,product_id,qty,fee,recipient_name,recipient_phone,recipient_address,note)
             VALUES (?,?,?,?,?,?,?,?,?)",
            [$auth['sub'], $b['merchant_id'], $b['product_id'], $b['qty'] ?? 1, $product['base_price'],
             $b['recipient_name'], $b['recipient_phone'], $b['recipient_address'], $b['note'] ?? null]
        );
        Response::ok(DB::first("SELECT * FROM sample_requests WHERE id=?", [$id]), '样品申请已提交');
    }

    public function update(array $p, array $b): void
    {
        $auth   = JWT::requireAuth();
        $id     = (int)($p['id'] ?? 0);
        $action = $b['action'] ?? '';

        $sr = DB::first("SELECT * FROM sample_requests WHERE id=?", [$id]);
        if (!$sr) Response::notFound('样品申请不存在');
        if ($auth['role'] === 'merchant' && $sr['merchant_id'] != $auth['merchant_id']) Response::forbidden();

        if ($action === 'process') {
            DB::execute("UPDATE sample_requests SET status='processing' WHERE id=?", [$id]);
        } elseif ($action === 'ship') {
            if (empty($b['express_company']) || empty($b['express_no'])) Response::error('请填写快递信息');
            DB::execute("UPDATE sample_requests SET status='shipped',express_company=?,express_no=?,shipped_at=NOW() WHERE id=?",
                [$b['express_company'], $b['express_no'], $id]);
            DB::insert("INSERT INTO notifications (user_id,title,content,type,link_id) VALUES (?,?,?,?,?)",
                [$sr['buyer_id'], '样品已发货', "{$b['express_company']} {$b['express_no']}", 'sample', $id]);
        } elseif ($action === 'reject') {
            DB::execute("UPDATE sample_requests SET status='rejected' WHERE id=?", [$id]);
        }

        Response::ok(null, '样品状态已更新');
    }
}

// ── SearchController ─────────────────────────────────────────
