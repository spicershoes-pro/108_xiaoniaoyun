<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

class PostController
{
    public function index(array $p, array $b): void
    {
        $type = $_GET['type'] ?? 'all';
        $page = max(1, (int)($_GET['page'] ?? 1));
        $where = ["status='published'"]; $binds = [];
        if ($type !== 'all') { $where[] = 'po.type=?'; $binds[] = $type; }
        $result = DB::paginate(
            "SELECT po.*,u.name AS author_name,u.role AS author_role,
                    COALESCE(mp.short_name,bp.company_name,'') AS author_company
             FROM posts po
             LEFT JOIN users u ON u.id=po.author_id
             LEFT JOIN merchant_profiles mp ON mp.user_id=po.author_id
             LEFT JOIN buyer_profiles bp ON bp.user_id=po.author_id
             WHERE " . implode(' AND ',$where) . " ORDER BY po.created_at DESC",
            $binds, $page, 20
        );
        Response::paginated($result);
    }

    public function store(array $p, array $b): void
    {
        $auth = JWT::requireAuth();
        if (empty($b['content']) || mb_strlen($b['content']) < 5) Response::error('内容不能少于5个字');

        $typeMap = ['merchant'=>'factory','buyer'=>'buyer','admin'=>'platform','super_admin'=>'platform'];
        $type    = $typeMap[$auth['role']] ?? 'buyer';
        $status  = in_array($auth['role'], ['admin','super_admin']) ? 'published' : 'reviewing';
        $images  = json_encode($b['images'] ?? [], JSON_UNESCAPED_UNICODE);

        $id = DB::insert(
            "INSERT INTO posts (author_id,content,images,product_id,type,status) VALUES (?,?,?,?,?,?)",
            [$auth['sub'], $b['content'], $images, $b['product_id'] ?? null, $type, $status]
        );
        Response::ok(DB::first("SELECT * FROM posts WHERE id=?", [$id]), $status === 'published' ? '发布成功' : '已提交审核');
    }
}

// ── RankingController ─────────────────────────────────────────
