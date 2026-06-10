<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

// ── AdminController（总管理端）───────────────────────────────
class AdminController
{
    private function requireAdmin(): array { return JWT::requireRole('admin','super_admin'); }

    public function dashboard(array $p, array $b): void
    {
        $this->requireAdmin();

        $today      = date('Y-m-d');
        $monthStart = date('Y-m-01');

        $kpis = [
            'total_users'      => DB::first("SELECT COUNT(*) c FROM users WHERE role='buyer'")['c'],
            'new_users_today'  => DB::first("SELECT COUNT(*) c FROM users WHERE role='buyer' AND DATE(created_at)=?",[$today])['c'],
            'total_merchants'  => DB::first("SELECT COUNT(*) c FROM merchant_profiles")['c'],
            'pending_merchants'=> DB::first("SELECT COUNT(*) c FROM merchant_profiles WHERE status='reviewing'")['c'],
            'total_products'   => DB::first("SELECT COUNT(*) c FROM products")['c'],
            'pending_products' => DB::first("SELECT COUNT(*) c FROM products WHERE status='pending'")['c'],
            'total_orders'     => DB::first("SELECT COUNT(*) c FROM orders")['c'],
            'active_orders'    => DB::first("SELECT COUNT(*) c FROM orders WHERE status IN('paid','material','production','shipping')")['c'],
            'dispute_orders'   => DB::first("SELECT COUNT(*) c FROM orders WHERE status='dispute'")['c'],
            'pending_inquiries'=> DB::first("SELECT COUNT(*) c FROM inquiries WHERE status='pending'")['c'],
            'today_gmv'        => (float)(DB::first("SELECT COALESCE(SUM(total_amount),0) v FROM orders WHERE status!='cancelled' AND DATE(created_at)=?",[$today])['v']),
            'month_gmv'        => (float)(DB::first("SELECT COALESCE(SUM(total_amount),0) v FROM orders WHERE status!='cancelled' AND created_at>=?",[$monthStart.' 00:00:00'])['v']),
            'month_revenue'    => (float)(DB::first("SELECT COALESCE(SUM(platform_fee),0) v FROM orders WHERE status!='cancelled' AND created_at>=?",[$monthStart.' 00:00:00'])['v']),
        ];

        // 近12月趋势
        $trend = [];
        for ($i = 11; $i >= 0; $i--) {
            $ms  = date('Y-m-01', strtotime("-{$i} months"));
            $me  = date('Y-m-t',  strtotime("-{$i} months"));
            $row = DB::first("SELECT COALESCE(SUM(total_amount),0) gmv,COALESCE(SUM(platform_fee),0) revenue,COUNT(*) orders FROM orders WHERE status!='cancelled' AND created_at BETWEEN ? AND ?", [$ms, $me.' 23:59:59']);
            $trend[] = ['month'=>date('n月',strtotime($ms)), 'gmv'=>(float)$row['gmv'], 'revenue'=>(float)$row['revenue'], 'orders'=>(int)$row['orders']];
        }

        Response::ok(['kpis' => $kpis, 'monthly_stats' => $trend]);
    }

    public function users(array $p, array $b): void
    {
        $this->requireAdmin();
        $status  = $_GET['status']   ?? 'all';
        $role    = $_GET['role']     ?? 'all';
        $q       = $_GET['q']        ?? '';
        $page    = max(1, (int)($_GET['page'] ?? 1));

        $where = ['1=1']; $binds = [];
        if ($status !== 'all') { $where[] = 'u.status=?'; $binds[] = $status; }
        if ($role   !== 'all') { $where[] = 'u.role=?';   $binds[] = $role; }
        if ($q) {
            $like = "%{$q}%";
            $where[] = '(u.phone LIKE ? OR u.name LIKE ? OR bp.company_name LIKE ?)';
            $binds   = array_merge($binds, [$like, $like, $like]);
        }

        $result = DB::paginate(
            "SELECT u.id,u.phone,u.name,u.role,u.status,u.created_at,
                    bp.company_name,bp.country,bp.level,bp.total_gmv,bp.verified,
                    mp.short_name AS merchant_short_name, mp.status AS merchant_status, mp.level AS merchant_level
             FROM users u
             LEFT JOIN buyer_profiles    bp ON bp.user_id=u.id
             LEFT JOIN merchant_profiles mp ON mp.user_id=u.id
             WHERE " . implode(' AND ',$where) . " ORDER BY u.created_at DESC",
            $binds, $page, 20
        );
        Response::paginated($result);
    }

    public function updateUser(array $p, array $b): void
    {
        $auth   = $this->requireAdmin();
        $uid    = (int)($p['id'] ?? 0);
        $action = $b['action'] ?? '';

        $user = DB::first("SELECT * FROM users WHERE id=?", [$uid]);
        if (!$user) Response::notFound('用户不存在');

        if ($action === 'suspend')  DB::execute("UPDATE users SET status='suspended' WHERE id=?", [$uid]);
        elseif ($action === 'activate') DB::execute("UPDATE users SET status='active' WHERE id=?", [$uid]);
        elseif ($action === 'verify') DB::execute("UPDATE buyer_profiles SET verified=1,verified_at=NOW() WHERE user_id=?", [$uid]);

        $this->log($auth['sub'], "{$action}用户", "{$user['name']}($uid)");
        Response::ok(null, '操作成功');
    }

    public function merchants(array $p, array $b): void
    {
        $this->requireAdmin();
        $status  = $_GET['status'] ?? 'all';
        $page    = max(1, (int)($_GET['page'] ?? 1));
        $where = ['1=1']; $binds = [];
        if ($status !== 'all') { $where[] = 'status=?'; $binds[] = $status; }
        $result = DB::paginate(
            "SELECT * FROM merchant_profiles WHERE " . implode(' AND ',$where) . " ORDER BY created_at DESC",
            $binds, $page, 20
        );
        Response::paginated($result);
    }

    public function updateMerchant(array $p, array $b): void
    {
        $auth    = $this->requireAdmin();
        $mid     = (int)($p['id'] ?? 0);
        $action  = $b['action'] ?? '';

        $merchant = DB::first("SELECT * FROM merchant_profiles WHERE id=?", [$mid]);
        if (!$merchant) Response::notFound('商家不存在');

        $statusMap = ['approve'=>'active','reject'=>'rejected','suspend'=>'suspended','activate'=>'active'];
        if (!isset($statusMap[$action])) Response::error('未知操作');

        $sets = ['status=?']; $binds = [$statusMap[$action]];
        if ($action === 'approve') { $sets[] = 'verified=1'; $sets[] = 'verified_at=NOW()'; }
        $binds[] = $mid;
        DB::execute("UPDATE merchant_profiles SET " . implode(',', $sets) . " WHERE id=?", $binds);

        // 通知商家
        DB::insert(
            "INSERT INTO notifications (user_id,title,content,type) VALUES (?,?,?,?)",
            [$merchant['user_id'],
             $action === 'approve' ? '入驻审核通过' : '账号状态变更',
             $b['note'] ?? ($action === 'approve' ? '恭喜！您的商家入驻申请已通过审核。' : '您的账号状态已变更，如有疑问请联系客服。'),
             'system']
        );

        $this->log($auth['sub'], "{$action}商家", "{$merchant['short_name']}($mid)");
        Response::ok(null, '操作成功');
    }

    public function products(array $p, array $b): void
    {
        $this->requireAdmin();
        $status  = $_GET['status'] ?? 'all';
        $page    = max(1, (int)($_GET['page'] ?? 1));
        $where = ['1=1']; $binds = [];
        if ($status !== 'all') { $where[] = 'p.status=?'; $binds[] = $status; }
        $result = DB::paginate(
            "SELECT p.*,mp.short_name AS merchant_name,
                    GROUP_CONCAT(pc.name SEPARATOR ',') AS cert_names
             FROM products p
             LEFT JOIN merchant_profiles mp ON mp.id=p.merchant_id
             LEFT JOIN product_certs pc ON pc.product_id=p.id
             WHERE " . implode(' AND ',$where) . " GROUP BY p.id ORDER BY p.created_at DESC",
            $binds, $page, 20
        );
        foreach ($result['list'] as &$row) {
            $row['certs'] = $row['cert_names'] ? explode(',', $row['cert_names']) : [];
            unset($row['cert_names']);
        }
        Response::paginated($result);
    }

    public function updateProduct(array $p, array $b): void
    {
        $auth   = $this->requireAdmin();
        $pid    = (int)($p['id'] ?? 0);
        $action = $b['action'] ?? '';

        $product = DB::first("SELECT * FROM products WHERE id=?", [$pid]);
        if (!$product) Response::notFound('产品不存在');

        $statusMap = ['approve'=>'online','reject'=>'rejected','offline'=>'offline'];
        if (!isset($statusMap[$action])) Response::error('未知操作');

        DB::execute("UPDATE products SET status=?,reviewed_at=NOW(),review_note=? WHERE id=?",
            [$statusMap[$action], $b['note'] ?? null, $pid]);

        $this->log($auth['sub'], "{$action}产品", "{$product['name']}($pid)");
        Response::ok(null, '操作成功');
    }

    public function orders(array $p, array $b): void
    {
        $this->requireAdmin();
        $status  = $_GET['status'] ?? 'all';
        $page    = max(1, (int)($_GET['page'] ?? 1));
        $where = ['1=1']; $binds = [];
        if ($status !== 'all') { $where[] = 'o.status=?'; $binds[] = $status; }
        $result = DB::paginate(
            "SELECT o.*,u.name AS buyer_name,bp.company_name AS buyer_company,bp.country AS buyer_country,mp.short_name AS merchant_name
             FROM orders o LEFT JOIN users u ON u.id=o.buyer_id LEFT JOIN buyer_profiles bp ON bp.user_id=o.buyer_id
             LEFT JOIN merchant_profiles mp ON mp.id=o.merchant_id
             WHERE " . implode(' AND ',$where) . " ORDER BY o.created_at DESC",
            $binds, $page, 20
        );
        Response::paginated($result);
    }

    public function inquiries(array $p, array $b): void
    {
        $this->requireAdmin();
        $page = max(1, (int)($_GET['page'] ?? 1));
        $result = DB::paginate(
            "SELECT i.*,u.name AS buyer_name,bp.company_name AS buyer_company,mp.short_name AS merchant_name
             FROM inquiries i LEFT JOIN users u ON u.id=i.buyer_id LEFT JOIN buyer_profiles bp ON bp.user_id=i.buyer_id
             LEFT JOIN merchant_profiles mp ON mp.id=i.merchant_id ORDER BY i.created_at DESC",
            [], $page, 20
        );
        Response::paginated($result);
    }

    public function content(array $p, array $b): void
    {
        $this->requireAdmin();
        $status = $_GET['status'] ?? 'all';
        $page   = max(1, (int)($_GET['page'] ?? 1));
        $where = ['1=1']; $binds = [];
        if ($status !== 'all') { $where[] = 'po.status=?'; $binds[] = $status; }
        $result = DB::paginate(
            "SELECT po.*,u.name AS author_name,u.role AS author_role FROM posts po LEFT JOIN users u ON u.id=po.author_id WHERE " . implode(' AND ',$where) . " ORDER BY po.created_at DESC",
            $binds, $page, 20
        );
        Response::paginated($result);
    }

    public function updateContent(array $p, array $b): void
    {
        $auth   = $this->requireAdmin();
        $pid    = (int)($p['id'] ?? 0);
        $action = $b['action'] ?? '';
        $map    = ['approve'=>'published','reject'=>'rejected','delete'=>'deleted'];
        if (!isset($map[$action])) Response::error('未知操作');
        DB::execute("UPDATE posts SET status=? WHERE id=?", [$map[$action], $pid]);
        $this->log($auth['sub'], "{$action}内容", "post($pid)");
        Response::ok(null, '操作成功');
    }

    public function finance(array $p, array $b): void
    {
        $this->requireAdmin();
        $tab  = $_GET['tab']  ?? 'summary';
        $page = max(1, (int)($_GET['page'] ?? 1));

        if ($tab === 'summary') {
            $summary = [
                'total_gmv'     => (float)(DB::first("SELECT COALESCE(SUM(total_amount),0) v FROM orders WHERE status!='cancelled'")['v']),
                'platform_revenue'=> (float)(DB::first("SELECT COALESCE(SUM(platform_fee),0) v FROM orders WHERE status!='cancelled'")['v']),
                'pending_withdrawal'=> (float)(DB::first("SELECT COALESCE(SUM(amount),0) v FROM withdrawals WHERE status IN('pending','processing')")['v']),
                'pending_count' => (int)(DB::first("SELECT COUNT(*) c FROM withdrawals WHERE status IN('pending','processing')")['c']),
                'withdrawn'     => (float)(DB::first("SELECT COALESCE(SUM(amount),0) v FROM withdrawals WHERE status='completed'")['v']),
            ];
            Response::ok($summary);
        }

        if ($tab === 'withdrawals') {
            $status = $_GET['status'] ?? 'all';
            $where = ['1=1']; $binds = [];
            if ($status !== 'all') { $where[] = 'w.status=?'; $binds[] = $status; }
            $result = DB::paginate(
                "SELECT w.*,mp.short_name AS merchant_name FROM withdrawals w LEFT JOIN merchant_profiles mp ON mp.id=w.merchant_id WHERE " . implode(' AND ',$where) . " ORDER BY w.applied_at DESC",
                $binds, $page, 20
            );
            Response::paginated($result);
        }
    }

    public function reviewWithdrawal(array $p, array $b): void
    {
        $auth   = $this->requireAdmin();
        $id     = (int)($p['id'] ?? 0);
        $action = $b['action'] ?? '';

        $wd = DB::first("SELECT w.*,mp.user_id AS merchant_user_id,mp.short_name FROM withdrawals w LEFT JOIN merchant_profiles mp ON mp.id=w.merchant_id WHERE w.id=?", [$id]);
        if (!$wd) Response::notFound('提现记录不存在');

        $statusMap = ['approve'=>'processing','reject'=>'rejected'];
        if (!isset($statusMap[$action])) Response::error('未知操作');

        DB::execute("UPDATE withdrawals SET status=?,processed_at=NOW(),note=? WHERE id=?", [$statusMap[$action], $b['note'] ?? null, $id]);
        DB::insert("INSERT INTO notifications (user_id,title,content,type) VALUES (?,?,?,?)",
            [$wd['merchant_user_id'], $action==='approve'?'提现申请已受理':'提现申请被拒绝', $b['note'] ?? '', 'system']);

        $this->log($auth['sub'], "{$action}提现", "{$wd['short_name']} ¥{$wd['amount']}");
        Response::ok(null, '操作成功');
    }

    public function ips(array $p, array $b): void
    {
        $this->requireAdmin();
        $tab  = $_GET['tab']  ?? 'library';
        $page = max(1, (int)($_GET['page'] ?? 1));

        if ($tab === 'library') {
            $list = DB::select("SELECT ip.*,(SELECT COUNT(*) FROM ip_applications WHERE ip_id=ip.id) AS application_count FROM ip_licenses ip ORDER BY is_hot DESC,name", []);
            Response::ok(['list' => $list, 'total' => count($list)]);
        }

        $status = $_GET['status'] ?? 'all';
        $where = ['1=1']; $binds = [];
        if ($status !== 'all') { $where[] = 'status=?'; $binds[] = $status; }
        $result = DB::paginate(
            "SELECT ia.*,il.name AS ip_name,il.emoji FROM ip_applications ia LEFT JOIN ip_licenses il ON il.id=ia.ip_id WHERE " . implode(' AND ',$where) . " ORDER BY created_at DESC",
            $binds, $page, 20
        );
        Response::paginated($result);
    }

    public function updateIp(array $p, array $b): void
    {
        $auth   = $this->requireAdmin();
        $id     = (int)($p['id'] ?? 0);
        $action = $b['action'] ?? '';
        $map    = ['approve'=>'approved','reject'=>'rejected'];
        if (!isset($map[$action])) Response::error('未知操作');

        DB::execute("UPDATE ip_applications SET status=?,note=?,reviewed_at=NOW() WHERE id=?", [$map[$action], $b['note'] ?? null, $id]);
        $this->log($auth['sub'], "{$action}IP授权申请", "application($id)");
        Response::ok(null, '操作成功');
    }

    public function logs(array $p, array $b): void
    {
        $this->requireAdmin();
        $page = max(1, (int)($_GET['page'] ?? 1));
        $result = DB::paginate(
            "SELECT ol.*,u.name AS admin_name FROM operation_logs ol LEFT JOIN users u ON u.id=ol.admin_id ORDER BY ol.created_at DESC",
            [], $page, 50
        );
        Response::paginated($result);
    }

    public function config(array $p, array $b): void
    {
        $this->requireAdmin();
        $list = DB::select("SELECT * FROM system_configs ORDER BY `key`", []);
        Response::ok(['list' => $list, 'map' => array_column($list, 'value', 'key')]);
    }

    public function updateConfig(array $p, array $b): void
    {
        JWT::requireRole('super_admin');
        $key = $b['key'] ?? ''; $val = $b['value'] ?? '';
        if (!$key) Response::error('缺少 key');
        DB::execute("INSERT INTO system_configs (`key`,`value`) VALUES (?,?) ON DUPLICATE KEY UPDATE `value`=?", [$key, $val, $val]);
        Response::ok(null, '配置已更新');
    }

    private function log(int $adminId, string $action, string $target, array $detail = []): void
    {
        DB::insert(
            "INSERT INTO operation_logs (admin_id,action,target,detail,ip) VALUES (?,?,?,?,?)",
            [$adminId, $action, $target, $detail ? json_encode($detail) : null, $_SERVER['REMOTE_ADDR'] ?? null]
        );
    }
}
