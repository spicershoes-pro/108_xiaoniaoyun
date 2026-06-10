<?php
namespace App\Controllers;

use App\Helpers\{DB, JWT, Response};

class ProductController
{
    /** GET /api/products */
    public function index(array $params, array $body): void
    {
        $category = $_GET['category'] ?? '';
        $q        = $_GET['q']        ?? '';
        $sort     = $_GET['sort']     ?? 'default';
        $status   = $_GET['status']   ?? 'online';
        $page     = max(1, (int)($_GET['page']      ?? 1));
        $perPage  = min(100, max(1, (int)($_GET['per_page'] ?? 20)));

        $auth = JWT::currentUser();

        $where  = ['1=1'];
        $binds  = [];

        // 游客/买家只能看上架产品
        if (!$auth || $auth['role'] === 'buyer') {
            $where[] = 'p.status = ?';
            $binds[] = 'online';
        } elseif ($status !== 'all') {
            $where[] = 'p.status = ?';
            $binds[] = $status;
        }

        // 商家只看自己的产品
        if ($auth && $auth['role'] === 'merchant' && !empty($auth['merchant_id'])) {
            $where[] = 'p.merchant_id = ?';
            $binds[] = $auth['merchant_id'];
        }

        if ($category && $category !== '全部') {
            $where[] = 'p.category = ?';
            $binds[] = $category;
        }
        if ($q) {
            $where[] = '(p.name LIKE ? OR p.category LIKE ? OR p.sku LIKE ?)';
            $like    = "%{$q}%";
            $binds   = array_merge($binds, [$like, $like, $like]);
        }

        $merchantId = $_GET['merchant_id'] ?? '';
        if ($merchantId) {
            $where[] = 'p.merchant_id = ?';
            $binds[] = $merchantId;
        }

        $orderMap = [
            'sales'      => 'p.sales_count DESC',
            'price_asc'  => 'p.base_price ASC',
            'price_desc' => 'p.base_price DESC',
            'rating'     => 'p.rating DESC',
            'newest'     => 'p.created_at DESC',
            'default'    => 'p.sales_count DESC',
        ];
        $orderBy = $orderMap[$sort] ?? $orderMap['default'];

        $whereStr = implode(' AND ', $where);
        $sql = "SELECT p.*,
                       mp.short_name AS merchant_name,
                       mp.city AS merchant_city,
                       mp.verified AS merchant_verified,
                       mp.rating AS merchant_rating
                FROM products p
                LEFT JOIN merchant_profiles mp ON mp.id = p.merchant_id
                WHERE {$whereStr}
                ORDER BY {$orderBy}";

        $result = DB::paginate($sql, $binds, $page, $perPage);

        // 批量附加阶梯价和认证
        $ids = array_column($result['list'], 'id');
        if ($ids) {
            $placeholders = implode(',', array_fill(0, count($ids), '?'));
            $tiers = DB::select("SELECT * FROM product_price_tiers WHERE product_id IN ({$placeholders}) ORDER BY min_qty", $ids);
            $certs = DB::select("SELECT * FROM product_certs WHERE product_id IN ({$placeholders})", $ids);

            $tiersMap = [];
            foreach ($tiers as $t) $tiersMap[$t['product_id']][] = $t;
            $certsMap = [];
            foreach ($certs as $c) $certsMap[$c['product_id']][] = $c['name'];

            foreach ($result['list'] as &$item) {
                $item['price_tiers'] = $tiersMap[$item['id']] ?? [];
                $item['certs']       = $certsMap[$item['id']] ?? [];
            }
        }

        Response::paginated($result);
    }

    /** POST /api/products */
    public function store(array $params, array $body): void
    {
        $auth = JWT::requireRole('merchant', 'admin', 'super_admin');

        $required = ['name', 'category', 'base_price'];
        foreach ($required as $f) {
            if (empty($body[$f])) Response::error("字段 {$f} 不能为空");
        }

        $merchantId = null;
        if ($auth['role'] === 'merchant') {
            $merchantId = $auth['merchant_id'] ?? null;
            if (!$merchantId) Response::error('商家信息未找到', 400);
        } else {
            $merchantId = (int)($body['merchant_id'] ?? 0);
            if (!$merchantId) Response::error('请指定 merchant_id');
        }

        // 生成 SKU
        $cnt = DB::first("SELECT COUNT(*) c FROM products WHERE merchant_id=?", [$merchantId])['c'] ?? 0;
        $sku = 'XN-' . str_pad($cnt + 1, 3, '0', STR_PAD_LEFT) . '-' . strtoupper(substr(base_convert(time(), 10, 36), -4));

        $id = DB::insert(
            "INSERT INTO products (merchant_id,sku,name,category,description,material,age_range,size,lead_time,status,emoji,cover_color,base_price,moq,stock)
             VALUES (?,?,?,?,?,?,?,?,?,'pending',?,?,?,?,?)",
            [
                $merchantId, $sku,
                $body['name'], $body['category'],
                $body['description'] ?? null, $body['material'] ?? null,
                $body['age_range'] ?? null, $body['size'] ?? null,
                $body['lead_time'] ?? null,
                $body['emoji'] ?? null, $body['cover_color'] ?? null,
                $body['base_price'], $body['moq'] ?? 100, $body['stock'] ?? 0,
            ]
        );

        // 阶梯价
        foreach ($body['price_tiers'] ?? [] as $tier) {
            DB::insert(
                "INSERT INTO product_price_tiers (product_id,min_qty,price) VALUES (?,?,?)",
                [$id, $tier['min_qty'], $tier['price']]
            );
        }

        // 认证
        foreach ($body['certs'] ?? [] as $cert) {
            DB::execute(
                "INSERT IGNORE INTO product_certs (product_id,name) VALUES (?,?)",
                [$id, $cert]
            );
        }

        $product = DB::first("SELECT * FROM products WHERE id=?", [$id]);
        Response::ok($product, '产品已提交审核');
    }

    /** GET /api/products/{id} */
    public function show(array $params, array $body): void
    {
        $id      = (int)($params['id'] ?? 0);
        $product = DB::first(
            "SELECT p.*, mp.short_name AS merchant_name, mp.company_name, mp.city,
                    mp.rating AS merchant_rating, mp.rating_count, mp.total_orders,
                    mp.response_rate, mp.response_time, mp.verified AS merchant_verified,
                    mp.id AS merchant_profile_id, mp.user_id AS merchant_user_id
             FROM products p
             LEFT JOIN merchant_profiles mp ON mp.id = p.merchant_id
             WHERE p.id=?",
            [$id]
        );

        if (!$product) Response::notFound('产品不存在');

        $auth = JWT::currentUser();
        if ($product['status'] !== 'online') {
            if (!$auth || ($auth['role'] === 'buyer')) Response::notFound('产品不存在');
        }

        // 增加浏览量
        DB::execute("UPDATE products SET view_count=view_count+1 WHERE id=?", [$id]);

        $product['price_tiers'] = DB::select("SELECT * FROM product_price_tiers WHERE product_id=? ORDER BY min_qty", [$id]);
        $product['certs']       = array_column(DB::select("SELECT name FROM product_certs WHERE product_id=?", [$id]), 'name');
        $product['images']      = DB::select("SELECT * FROM product_images WHERE product_id=? ORDER BY sort", [$id]);
        $product['reviews']     = DB::select("SELECT * FROM product_reviews WHERE product_id=? ORDER BY created_at DESC LIMIT 10", [$id]);

        // 商家认证
        $product['merchant_certs'] = array_column(
            DB::select("SELECT name FROM merchant_certs WHERE merchant_id=? AND status='valid'", [$product['merchant_id']]),
            'name'
        );

        Response::ok($product);
    }

    /** PATCH /api/products/{id} */
    public function update(array $params, array $body): void
    {
        $auth = JWT::requireAuth();
        $id   = (int)($params['id'] ?? 0);

        $product = DB::first("SELECT * FROM products WHERE id=?", [$id]);
        if (!$product) Response::notFound('产品不存在');

        if ($auth['role'] === 'merchant' && $auth['merchant_id'] != $product['merchant_id']) {
            Response::forbidden('无权操作此产品');
        }

        $allowed = ['name','category','description','material','age_range','size','lead_time',
                    'emoji','cover_color','base_price','moq','stock','status','review_note'];
        $sets    = [];
        $binds   = [];

        foreach ($allowed as $f) {
            if (!array_key_exists($f, $body)) continue;
            // 商家不能直接上架
            if ($f === 'status' && $body[$f] === 'online' && $auth['role'] === 'merchant') {
                Response::forbidden('产品需经平台审核后方可上架');
            }
            $sets[]  = "`{$f}` = ?";
            $binds[] = $body[$f];
        }

        if (isset($body['status']) && in_array($body['status'], ['online','rejected','offline'])) {
            $sets[]  = 'reviewed_at = NOW()';
        }

        if ($sets) {
            $binds[] = $id;
            DB::execute("UPDATE products SET " . implode(',', $sets) . " WHERE id=?", $binds);
        }

        // 产品状态变更时通知商家
        if (isset($body['status']) && in_array($body['status'], ['online','rejected'])) {
            $merchantUser = DB::first(
                "SELECT mp.user_id FROM merchant_profiles mp WHERE mp.id=?",
                [$product['merchant_id']]
            );
            if ($merchantUser) {
                $statusLabel = $body['status'] === 'online' ? '审核通过，已上架' : '审核未通过';
                $note        = $body['review_note'] ?? '';
                DB::insert(
                    "INSERT INTO notifications (user_id,title,content,type,link_id) VALUES (?,?,?,?,?)",
                    [
                        $merchantUser['user_id'],
                        '产品审核结果',
                        "产品《{$product['name']}》{$statusLabel}" . ($note ? "：{$note}" : ''),
                        'product',
                        $id,
                    ]
                );
            }
        }

        // 更新阶梯价
        if (isset($body['price_tiers'])) {
            DB::execute("DELETE FROM product_price_tiers WHERE product_id=?", [$id]);
            foreach ($body['price_tiers'] as $tier) {
                DB::insert("INSERT INTO product_price_tiers (product_id,min_qty,price) VALUES (?,?,?)",
                    [$id, $tier['min_qty'], $tier['price']]);
            }
        }

        // 更新认证
        if (isset($body['certs'])) {
            DB::execute("DELETE FROM product_certs WHERE product_id=?", [$id]);
            foreach ($body['certs'] as $cert) {
                DB::execute("INSERT IGNORE INTO product_certs (product_id,name) VALUES (?,?)", [$id, $cert]);
            }
        }

        Response::ok(DB::first("SELECT * FROM products WHERE id=?", [$id]), '更新成功');
    }

    /** DELETE /api/products/{id} */
    public function destroy(array $params, array $body): void
    {
        $auth = JWT::requireAuth();
        $id   = (int)($params['id'] ?? 0);

        $product = DB::first("SELECT * FROM products WHERE id=?", [$id]);
        if (!$product) Response::notFound('产品不存在');

        if ($auth['role'] === 'merchant' && $auth['merchant_id'] != $product['merchant_id']) {
            Response::forbidden('无权删除此产品');
        }

        DB::execute("UPDATE products SET status='offline' WHERE id=?", [$id]);
        Response::ok(null, '产品已下架');
    }
}
