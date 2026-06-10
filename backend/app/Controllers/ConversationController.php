<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

class ConversationController
{
    public function index(array $p, array $b): void
    {
        $auth = JWT::requireAuth();
        $list = DB::select(
            "SELECT c.id, c.last_message, c.last_msg_at,
                    cp.unread_count,
                    u2.id AS peer_id, u2.name AS peer_name, u2.role AS peer_role,
                    COALESCE(mp.short_name, bp.company_name, u2.name) AS peer_display
             FROM conversations c
             JOIN conversation_participants cp  ON cp.conversation_id = c.id AND cp.user_id = ?
             JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id != ?
             JOIN users u2 ON u2.id = cp2.user_id
             LEFT JOIN merchant_profiles mp ON mp.user_id = u2.id
             LEFT JOIN buyer_profiles    bp ON bp.user_id = u2.id
             ORDER BY c.last_msg_at DESC",
            [$auth['sub'], $auth['sub']]
        );
        Response::ok(['list' => $list, 'total' => count($list)]);
    }

    public function store(array $p, array $b): void
    {
        $auth   = JWT::requireAuth();
        $target = (int)($b['target_user_id'] ?? 0);
        if (!$target || $target === (int)$auth['sub']) Response::error('无效的目标用户');

        if (!DB::first("SELECT id FROM users WHERE id=?", [$target])) Response::notFound('用户不存在');

        // 找已有会话
        $existing = DB::first(
            "SELECT c.id FROM conversations c
             JOIN conversation_participants a ON a.conversation_id=c.id AND a.user_id=?
             JOIN conversation_participants b ON b.conversation_id=c.id AND b.user_id=?
             LIMIT 1",
            [$auth['sub'], $target]
        );
        if ($existing) { Response::ok(['conversation_id' => $existing['id'], 'is_new' => false]); }

        $cid = DB::insert("INSERT INTO conversations (created_at) VALUES (NOW())");
        DB::insert("INSERT INTO conversation_participants (conversation_id,user_id) VALUES (?,?),(?,?)",
            [$cid, $auth['sub'], $cid, $target]);

        Response::ok(['conversation_id' => $cid, 'is_new' => true], '会话创建成功');
    }

    public function messages(array $p, array $b): void
    {
        $auth    = JWT::requireAuth();
        $cid     = (int)($p['id'] ?? 0);
        $after   = $_GET['after']    ?? null;
        $page    = max(1, (int)($_GET['page']     ?? 1));
        $perPage = min(200, (int)($_GET['per_page'] ?? 50));

        $cp = DB::first("SELECT * FROM conversation_participants WHERE conversation_id=? AND user_id=?", [$cid, $auth['sub']]);
        if (!$cp) Response::forbidden('无权访问此会话');

        $where = ['m.conversation_id=?'];
        $binds = [$cid];

        if ($after) {
            $last = DB::first("SELECT created_at FROM messages WHERE id=?", [$after]);
            if ($last) { $where[] = 'm.created_at > ?'; $binds[] = $last['created_at']; }
        }

        $whereStr = implode(' AND ', $where);
        $order    = $after ? 'ASC' : 'DESC';
        $sql      = "SELECT m.*, u.name AS sender_name, u.role AS sender_role,
                            COALESCE(mp.short_name,'') AS sender_merchant
                     FROM messages m
                     LEFT JOIN users u ON u.id=m.sender_id
                     LEFT JOIN merchant_profiles mp ON mp.user_id=m.sender_id
                     WHERE {$whereStr} ORDER BY m.created_at {$order}";

        if (!$after) {
            $result = DB::paginate($sql, $binds, $page, $perPage);
            $result['list'] = array_reverse($result['list']);
            $list = $result['list'];
        } else {
            $list = DB::select($sql . " LIMIT 200", $binds);
        }

        // 标为已读
        DB::execute("UPDATE conversation_participants SET unread_count=0,last_read_at=NOW() WHERE conversation_id=? AND user_id=?", [$cid, $auth['sub']]);

        Response::ok(['list' => $list, 'total' => count($list), 'last_id' => $list ? end($list)['id'] : null]);
    }

    public function send(array $p, array $b): void
    {
        $auth = JWT::requireAuth();
        $cid  = (int)($p['id'] ?? 0);

        $cp = DB::first("SELECT * FROM conversation_participants WHERE conversation_id=? AND user_id=?", [$cid, $auth['sub']]);
        if (!$cp) Response::forbidden('无权发送消息到此会话');

        if (empty($b['content'])) Response::error('消息内容不能为空');
        $type    = $b['type'] ?? 'text';
        $content = $b['content'];
        $meta    = isset($b['metadata']) ? json_encode($b['metadata'], JSON_UNESCAPED_UNICODE) : null;

        $mid = DB::insert(
            "INSERT INTO messages (conversation_id,sender_id,type,content,metadata) VALUES (?,?,?,?,?)",
            [$cid, $auth['sub'], $type, $content, $meta]
        );

        $preview = $type === 'text' ? $content : "[{$type}]";
        DB::execute("UPDATE conversations SET last_message=?,last_msg_at=NOW() WHERE id=?", [mb_substr($preview,0,200), $cid]);
        DB::execute("UPDATE conversation_participants SET unread_count=unread_count+1 WHERE conversation_id=? AND user_id!=?", [$cid, $auth['sub']]);

        Response::ok(DB::first("SELECT * FROM messages WHERE id=?", [$mid]), '消息已发送');
    }
}

// ── CartController ────────────────────────────────────────────
