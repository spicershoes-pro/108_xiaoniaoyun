<?php
namespace App\Controllers;

use App\Helpers\{DB, JWT, Response};

class OrderController
{
    /** GET /api/orders */
    public function index(array $params, array $body): void
    {
        $auth    = JWT::requireAuth();
        $status  = $_GET['status']   ?? 'all';
        $page    = max(1, (int)($_GET['page']     ?? 1));
        $perPage = min(100, (int)($_GET['per_page'] ?? 20));

        $where = ['1=1'];
        $binds = [];

        if ($auth['role'] === 'buyer') {
            $where[] = 'o.buyer_id = ?'; $binds[] = $auth['sub'];
        } elseif ($auth['role'] === 'merchant') {
            $mid = $auth['merchant_id'] ?? 0;
            if (!$mid) Response::error('商家信息未找到', 400);
            $where[] = 'o.merchant_id = ?'; $binds[] = $mid;
        }

        if ($status !== 'all') {
            $where[] = 'o.status = ?'; $binds[] = $status;
        }

        $whereStr = implode(' AND ', $where);
        $sql = "SELECT o.*,
                       u.name  AS buyer_name,
                       bp.company_name AS buyer_company,
                       bp.country AS buyer_country,
                       mp.short_name AS merchant_name
                FROM orders o
                LEFT JOIN users u ON u.id = o.buyer_id
                LEFT JOIN buyer_profiles bp ON bp.user_id = o.buyer_id
                LEFT JOIN merchant_profiles mp ON mp.id = o.merchant_id
                WHERE {$whereStr}
                ORDER BY o.created_at DESC";

        $result = DB::paginate($sql, $binds, $page, $perPage);

        // 附加订单明细
        $ids = array_column($result['list'], 'id');
        if ($ids) {
            $ph    = implode(',', array_fill(0, count($ids), '?'));
            $items = DB::select(
                "SELECT oi.*, p.name AS product_name, p.emoji, p.cover_color
                 FROM order_items oi LEFT JOIN products p ON p.id = oi.product_id
                 WHERE oi.order_id IN ({$ph})",
                $ids
            );
            $itemsMap = [];
            foreach ($items as $it) $itemsMap[$it['order_id']][] = $it;

            $logs = DB::select(
                "SELECT * FROM order_status_logs WHERE order_id IN ({$ph}) ORDER BY created_at",
                $ids
            );
            $logsMap = [];
            foreach ($logs as $l) $logsMap[$l['order_id']][] = $l;

            foreach ($result['list'] as &$row) {
                $row['items']       = $itemsMap[$row['id']] ?? [];
                $row['status_logs'] = $logsMap[$row['id']] ?? [];
                $row['step']        = $this->statusToStep($row['status']);
            }
        }

        Response::paginated($result);
    }

    /** POST /api/orders - 从询盘创建订单 */
    public function store(array $params, array $body): void
    {
        $auth = JWT::requireRole('buyer');

        $inquiryId = (int)($body['inquiry_id'] ?? 0);
        if (!$inquiryId) Response::error('请提供询盘ID');

        $inquiry = DB::first(
            "SELECT i.*, mp.user_id AS merchant_user_id
             FROM inquiries i
             LEFT JOIN merchant_profiles mp ON mp.id = i.merchant_id
             WHERE i.id=?",
            [$inquiryId]
        );
        if (!$inquiry)                                              Response::notFound('询盘不存在');
        if ($inquiry['buyer_id'] != $auth['sub'])                  Response::forbidden('无权操作此询盘');
        if (!in_array($inquiry['status'], ['quoted','negotiating'])) Response::error('询盘尚未报价，无法下单');

        // 检查是否已下单
        $existing = DB::first("SELECT id FROM orders WHERE inquiry_id=?", [$inquiryId]);
        if ($existing) Response::error('该询盘已创建过订单');

        // 询盘产品明细
        $items = DB::select(
            "SELECT ii.*, p.base_price FROM inquiry_items ii LEFT JOIN products p ON p.id=ii.product_id WHERE ii.inquiry_id=?",
            [$inquiryId]
        );
        if (empty($items)) Response::error('询盘无产品明细');

        // 计算金额
        $totalAmount = 0;
        $orderItems  = [];
        foreach ($items as $item) {
            $unitPrice    = (float)($item['unit_price'] ?: $item['base_price']);
            $subtotal     = $unitPrice * $item['qty'];
            $totalAmount += $subtotal;
            $orderItems[] = ['product_id' => $item['product_id'], 'qty' => $item['qty'], 'unit_price' => $unitPrice, 'subtotal' => $subtotal];
        }

        $cfg         = require ROOT . '/config/app.php';
        $platformFee = round($totalAmount * $cfg['fee_rate'], 2);
        $orderNo     = $this->generateOrderNo();

        DB::beginTransaction();
        try {
            $orderId = DB::insert(
                "INSERT INTO orders (order_no,buyer_id,merchant_id,inquiry_id,status,total_amount,platform_fee,deadline)
                 VALUES (?,?,?,?,'pending_payment',?,?,?)",
                [
                    $orderNo, $auth['sub'], $inquiry['merchant_id'], $inquiryId,
                    $totalAmount, $platformFee,
                    $body['deadline'] ?? null,
                ]
            );

            foreach ($orderItems as $oi) {
                DB::insert(
                    "INSERT INTO order_items (order_id,product_id,qty,unit_price,subtotal) VALUES (?,?,?,?,?)",
                    [$orderId, $oi['product_id'], $oi['qty'], $oi['unit_price'], $oi['subtotal']]
                );
            }

            DB::insert(
                "INSERT INTO order_status_logs (order_id,to_status,note,operator_id) VALUES (?,'pending_payment','订单创建',?)",
                [$orderId, $auth['sub']]
            );

            // 更新询盘状态
            DB::execute("UPDATE inquiries SET status='converted',converted_at=NOW() WHERE id=?", [$inquiryId]);

            // 通知商家
            DB::insert(
                "INSERT INTO notifications (user_id,title,content,type,link_id) VALUES (?,?,?,?,?)",
                [$inquiry['merchant_user_id'], '新订单', "买家已确认下单，订单号 {$orderNo}", 'order', $orderId]
            );

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollback();
            Response::error('创建订单失败：' . $e->getMessage(), 500);
        }

        Response::ok(DB::first("SELECT * FROM orders WHERE id=?", [$orderId]), '订单创建成功，请及时完成付款');
    }

    /** GET /api/orders/{id} */
    public function show(array $params, array $body): void
    {
        $auth = JWT::requireAuth();
        $id   = (int)($params['id'] ?? 0);

        $order = DB::first(
            "SELECT o.*,
                    u.name AS buyer_name, u.phone AS buyer_phone,
                    bp.company_name AS buyer_company, bp.country AS buyer_country,
                    mp.short_name AS merchant_name, mp.company_name AS merchant_company_name, mp.city AS merchant_city
             FROM orders o
             LEFT JOIN users u ON u.id=o.buyer_id
             LEFT JOIN buyer_profiles bp ON bp.user_id=o.buyer_id
             LEFT JOIN merchant_profiles mp ON mp.id=o.merchant_id
             WHERE o.id=?",
            [$id]
        );
        if (!$order) Response::notFound('订单不存在');

        if ($auth['role'] === 'buyer'    && $order['buyer_id']    != $auth['sub'])           Response::forbidden();
        if ($auth['role'] === 'merchant' && $order['merchant_id'] != $auth['merchant_id'])   Response::forbidden();

        $order['items']       = DB::select("SELECT oi.*,p.name AS product_name,p.emoji FROM order_items oi LEFT JOIN products p ON p.id=oi.product_id WHERE oi.order_id=?", [$id]);
        $order['status_logs'] = DB::select("SELECT * FROM order_status_logs WHERE order_id=? ORDER BY created_at", [$id]);
        $order['dispute']     = DB::first("SELECT * FROM order_disputes WHERE order_id=?", [$id]);
        $order['step']        = $this->statusToStep($order['status']);

        Response::ok($order);
    }

    /** PATCH /api/orders/{id} - 状态流转 */
    public function update(array $params, array $body): void
    {
        $auth   = JWT::requireAuth();
        $id     = (int)($params['id'] ?? 0);
        $action = $body['action'] ?? '';

        $order = DB::first(
            "SELECT o.*, mp.user_id AS merchant_user_id FROM orders o
             LEFT JOIN merchant_profiles mp ON mp.id = o.merchant_id WHERE o.id=?",
            [$id]
        );
        if (!$order) Response::notFound('订单不存在');

        if ($auth['role'] === 'buyer'    && $order['buyer_id']    != $auth['sub'])        Response::forbidden();
        if ($auth['role'] === 'merchant' && $order['merchant_id'] != $auth['merchant_id']) Response::forbidden();

        // 状态流转规则
        $transitions = [
            'pay'              => ['from' => ['pending_payment'],       'role' => ['buyer']],
            'start_material'   => ['from' => ['paid'],                  'role' => ['merchant']],
            'start_production' => ['from' => ['material'],              'role' => ['merchant']],
            'ship'             => ['from' => ['production'],            'role' => ['merchant']],
            'confirm_receipt'  => ['from' => ['shipping'],              'role' => ['buyer']],
            'cancel'           => ['from' => ['pending_payment','paid'],'role' => ['buyer','merchant','admin','super_admin']],
            'dispute'          => ['from' => ['shipping','delivered'],  'role' => ['buyer']],
            'resolve_dispute'  => ['from' => ['dispute'],               'role' => ['admin','super_admin']],
        ];

        if (!isset($transitions[$action])) Response::error('未知操作');

        $rule = $transitions[$action];
        if (!in_array($order['status'], $rule['from'])) {
            Response::error("当前订单状态「{$order['status']}」不允许执行此操作");
        }
        if (!in_array($auth['role'], $rule['role'])) {
            Response::forbidden('您没有权限执行此操作');
        }

        $statusMap = [
            'pay'              => 'paid',
            'start_material'   => 'material',
            'start_production' => 'production',
            'ship'             => 'shipping',
            'confirm_receipt'  => 'completed',
            'cancel'           => 'cancelled',
            'dispute'          => 'dispute',
            'resolve_dispute'  => 'completed',
        ];
        $newStatus = $statusMap[$action];

        $updateFields = ['status' => $newStatus];
        $note         = $action;

        DB::beginTransaction();
        try {
            switch ($action) {
                case 'pay':
                    $ratio   = (float)($body['deposit_ratio'] ?? 0.5);
                    $deposit = round($order['total_amount'] * $ratio, 2);
                    $updateFields['deposit']  = $deposit;
                    $updateFields['paid_at']  = date('Y-m-d H:i:s');
                    $note = "买家已付款 ¥{$deposit}（" . ($ratio * 100) . "%定金）";
                    break;
                case 'ship':
                    $express = $body['express_company'] ?? '';
                    $no      = $body['express_no'] ?? '';
                    if (!$express || !$no) Response::error('请填写快递公司和单号');
                    $updateFields['express_company'] = $express;
                    $updateFields['express_no']      = $no;
                    $updateFields['shipped_at']      = date('Y-m-d H:i:s');
                    $note = "已发货：{$express} {$no}";
                    break;
                case 'confirm_receipt':
                    $updateFields['completed_at'] = date('Y-m-d H:i:s');
                    $note = '买家确认收货，订单完成';
                    break;
                case 'cancel':
                    $updateFields['cancelled_at'] = date('Y-m-d H:i:s');
                    $note = '订单取消' . (isset($body['reason']) ? "：{$body['reason']}" : '');
                    break;
                case 'dispute':
                    $reason = $body['reason'] ?? '';
                    if (strlen($reason) < 5) Response::error('请详细描述纠纷原因（至少5个字）');
                    DB::insert("INSERT INTO order_disputes (order_id,reason) VALUES (?,?)", [$id, $reason]);
                    $note = "买家发起纠纷：{$reason}";
                    break;
                case 'resolve_dispute':
                    $resolution = $body['resolution'] ?? '';
                    if (strlen($resolution) < 5) Response::error('请填写处理结果');
                    DB::execute("UPDATE order_disputes SET resolution=?,resolved_at=NOW() WHERE order_id=?", [$resolution, $id]);
                    $updateFields['completed_at'] = date('Y-m-d H:i:s');
                    $note = "管理员调解结果：{$resolution}";
                    break;
            }

            // 构建 UPDATE SQL
            $sets  = [];
            $binds = [];
            foreach ($updateFields as $k => $v) {
                $sets[]  = "`{$k}` = ?";
                $binds[] = $v;
            }
            $binds[] = $id;
            DB::execute("UPDATE orders SET " . implode(',', $sets) . " WHERE id=?", $binds);

            // 记录日志
            DB::insert(
                "INSERT INTO order_status_logs (order_id,from_status,to_status,note,operator_id) VALUES (?,?,?,?,?)",
                [$id, $order['status'], $newStatus, $note, $auth['sub']]
            );

            // 通知对方
            $notifyUserId = $auth['role'] === 'buyer' ? $order['merchant_user_id'] : $order['buyer_id'];
            DB::insert(
                "INSERT INTO notifications (user_id,title,content,type,link_id) VALUES (?,?,?,?,?)",
                [$notifyUserId, '订单状态更新', $note, 'order', $id]
            );

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollback();
            Response::error('操作失败：' . $e->getMessage(), 500);
        }

        Response::ok(DB::first("SELECT * FROM orders WHERE id=?", [$id]), '订单状态已更新');
    }

    // ── 工具方法 ──────────────────────────────────────────────

    private function generateOrderNo(): string
    {
        $prefix = 'XN' . date('Ymd');
        $last   = DB::first(
            "SELECT order_no FROM orders WHERE order_no LIKE ? ORDER BY order_no DESC LIMIT 1",
            [$prefix . '%']
        );
        $seq = $last ? ((int)substr($last['order_no'], -4) + 1) : 1;
        return $prefix . str_pad($seq, 4, '0', STR_PAD_LEFT);
    }

    public static function statusToStep(string $status): int
    {
        return [
            'pending_payment' => 1,
            'paid'            => 2,
            'material'        => 3,
            'production'      => 4,
            'shipping'        => 5,
            'delivered'       => 5,
            'completed'       => 6,
        ][$status] ?? 0;
    }
}
