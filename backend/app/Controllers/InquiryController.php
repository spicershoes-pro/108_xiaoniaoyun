<?php
namespace App\Controllers;

use App\Helpers\{DB, JWT, Response};

class InquiryController
{
    /** GET /api/inquiries */
    public function index(array $params, array $body): void
    {
        $auth    = JWT::requireAuth();
        $status  = $_GET['status']   ?? 'all';
        $page    = max(1, (int)($_GET['page']     ?? 1));
        $perPage = min(100, (int)($_GET['per_page'] ?? 20));

        $where = ['1=1'];
        $binds = [];

        if ($auth['role'] === 'buyer') {
            $where[] = 'i.buyer_id = ?';
            $binds[] = $auth['sub'];
        } elseif ($auth['role'] === 'merchant') {
            $mid = $auth['merchant_id'] ?? 0;
            if (!$mid) Response::error('商家信息未找到', 400);
            $where[] = 'i.merchant_id = ?';
            $binds[] = $mid;
        }

        if ($status !== 'all') {
            $where[] = 'i.status = ?';
            $binds[] = $status;
        }

        $whereStr = implode(' AND ', $where);
        $sql = "SELECT i.*,
                       u.name AS buyer_name, u.phone AS buyer_phone,
                       bp.company_name AS buyer_company, bp.country AS buyer_country,
                       mp.short_name AS merchant_name
                FROM inquiries i
                LEFT JOIN users u ON u.id = i.buyer_id
                LEFT JOIN buyer_profiles bp ON bp.user_id = i.buyer_id
                LEFT JOIN merchant_profiles mp ON mp.id = i.merchant_id
                WHERE {$whereStr}
                ORDER BY i.created_at DESC";

        $result = DB::paginate($sql, $binds, $page, $perPage);

        // 附加询盘产品明细
        $ids = array_column($result['list'], 'id');
        if ($ids) {
            $ph    = implode(',', array_fill(0, count($ids), '?'));
            $items = DB::select(
                "SELECT ii.*, p.name AS product_name, p.emoji, p.cover_color, p.base_price
                 FROM inquiry_items ii
                 LEFT JOIN products p ON p.id = ii.product_id
                 WHERE ii.inquiry_id IN ({$ph})",
                $ids
            );
            $itemsMap = [];
            foreach ($items as $it) $itemsMap[$it['inquiry_id']][] = $it;
            foreach ($result['list'] as &$row) {
                $row['items'] = $itemsMap[$row['id']] ?? [];
            }
        }

        Response::paginated($result);
    }

    /** POST /api/inquiries */
    public function store(array $params, array $body): void
    {
        $auth = JWT::requireRole('buyer');

        $required = ['merchant_id', 'message', 'items'];
        foreach ($required as $f) {
            if (empty($body[$f])) Response::error("字段 {$f} 不能为空");
        }
        if (empty($body['items']) || !is_array($body['items'])) {
            Response::error('至少选择一个产品');
        }

        $merchant = DB::first("SELECT id,user_id FROM merchant_profiles WHERE id=? AND status='active'", [$body['merchant_id']]);
        if (!$merchant) Response::error('商家不存在或暂不接受询盘', 400);

        // 验证产品
        foreach ($body['items'] as $item) {
            $product = DB::first("SELECT * FROM products WHERE id=? AND status='online'", [$item['product_id']]);
            if (!$product) Response::error("产品 {$item['product_id']} 不可用");
            if ($product['merchant_id'] != $body['merchant_id']) Response::error('产品与商家不匹配');
            if ($item['qty'] < $product['moq']) {
                Response::error("产品「{$product['name']}」最小起订量为 {$product['moq']} 件");
            }
        }

        DB::beginTransaction();
        try {
            $id = DB::insert(
                "INSERT INTO inquiries (buyer_id,merchant_id,status,priority,message,budget)
                 VALUES (?,?,?,?,?,?)",
                [
                    $auth['sub'], $body['merchant_id'], 'pending',
                    $body['priority'] ?? 'medium',
                    $body['message'],
                    $body['budget'] ?? null,
                ]
            );

            foreach ($body['items'] as $item) {
                DB::insert(
                    "INSERT INTO inquiry_items (inquiry_id,product_id,qty) VALUES (?,?,?)",
                    [$id, $item['product_id'], $item['qty']]
                );
            }

            // 通知商家
            DB::insert(
                "INSERT INTO notifications (user_id,title,content,type,link_id) VALUES (?,?,?,?,?)",
                [$merchant['user_id'], '收到新询盘', '有买家发送了新的采购询盘，请及时回复', 'inquiry', $id]
            );

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollback();
            Response::error('创建询盘失败：' . $e->getMessage(), 500);
        }

        $inquiry = DB::first("SELECT * FROM inquiries WHERE id=?", [$id]);
        Response::ok($inquiry, '询盘已发送，商家将在24小时内回复');
    }

    /** GET /api/inquiries/{id} */
    public function show(array $params, array $body): void
    {
        $auth = JWT::requireAuth();
        $id   = (int)($params['id'] ?? 0);

        $inquiry = DB::first(
            "SELECT i.*,
                    u.name AS buyer_name, u.phone AS buyer_phone,
                    bp.company_name AS buyer_company, bp.country AS buyer_country, bp.level AS buyer_level,
                    mp.short_name AS merchant_name, mp.response_time, mp.user_id AS merchant_user_id
             FROM inquiries i
             LEFT JOIN users u  ON u.id  = i.buyer_id
             LEFT JOIN buyer_profiles bp ON bp.user_id = i.buyer_id
             LEFT JOIN merchant_profiles mp ON mp.id = i.merchant_id
             WHERE i.id=?",
            [$id]
        );
        if (!$inquiry) Response::notFound('询盘不存在');

        if ($auth['role'] === 'buyer'    && $inquiry['buyer_id'] != $auth['sub'])        Response::forbidden();
        if ($auth['role'] === 'merchant' && $inquiry['merchant_id'] != $auth['merchant_id']) Response::forbidden();

        $inquiry['items'] = DB::select(
            "SELECT ii.*, p.name AS product_name, p.base_price, p.moq, p.emoji, p.cover_color
             FROM inquiry_items ii LEFT JOIN products p ON p.id=ii.product_id
             WHERE ii.inquiry_id=?",
            [$id]
        );

        Response::ok($inquiry);
    }

    /** PATCH /api/inquiries/{id} */
    public function update(array $params, array $body): void
    {
        $auth   = JWT::requireAuth();
        $id     = (int)($params['id'] ?? 0);
        $action = $body['action'] ?? '';

        $inquiry = DB::first("SELECT * FROM inquiries WHERE id=?", [$id]);
        if (!$inquiry) Response::notFound('询盘不存在');

        if ($action === 'quote') {
            if ($auth['role'] !== 'merchant' || $auth['merchant_id'] != $inquiry['merchant_id']) {
                Response::forbidden('无权操作');
            }
            if (in_array($inquiry['status'], ['converted', 'closed'])) {
                Response::error('此询盘已结束，无法报价');
            }
            if (empty($body['quote_price'])) Response::error('报价内容不能为空');

            DB::execute(
                "UPDATE inquiries SET status='quoted',quote_price=?,quote_note=?,quoted_at=NOW() WHERE id=?",
                [$body['quote_price'], $body['quote_note'] ?? null, $id]
            );

            // 通知买家
            DB::insert(
                "INSERT INTO notifications (user_id,title,content,type,link_id) VALUES (?,?,?,?,?)",
                [$inquiry['buyer_id'], '商家已回复您的询盘', "报价：{$body['quote_price']}", 'inquiry', $id]
            );

            Response::ok(DB::first("SELECT * FROM inquiries WHERE id=?", [$id]), '报价已发送');
        }

        if ($action === 'close') {
            if ($auth['role'] === 'buyer' && $inquiry['buyer_id'] != $auth['sub']) Response::forbidden();
            DB::execute("UPDATE inquiries SET status='closed',closed_at=NOW() WHERE id=?", [$id]);
            Response::ok(null, '询盘已关闭');
        }

        Response::error('未知操作');
    }
}
