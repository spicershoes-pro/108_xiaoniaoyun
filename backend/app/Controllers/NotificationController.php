<?php
namespace App\Controllers;
use App\Helpers\{DB, JWT, Response};

class NotificationController
{
    /** GET /api/notifications?page=1&per_page=20&unread_only=0 */
    public function index(array $p, array $b): void
    {
        $auth      = JWT::requireAuth();
        $page      = max(1, (int)($_GET['page'] ?? 1));
        $perPage   = min((int)($_GET['per_page'] ?? 20), 50);
        $unreadOnly = (bool)($_GET['unread_only'] ?? false);

        $cond   = $unreadOnly ? " AND is_read=0" : '';
        $result = DB::paginate(
            "SELECT * FROM notifications WHERE user_id=?{$cond} ORDER BY created_at DESC",
            [$auth['sub']],
            $page,
            $perPage
        );

        $unreadCount = DB::first(
            "SELECT COUNT(*) c FROM notifications WHERE user_id=? AND is_read=0",
            [$auth['sub']]
        )['c'] ?? 0;

        Response::paginated(array_merge($result, ['unread_count' => $unreadCount]));
    }

    /** PATCH /api/notifications?id=xxx  (id=all 标记全部) */
    public function markRead(array $p, array $b): void
    {
        $auth = JWT::requireAuth();
        $id   = $_GET['id'] ?? $b['id'] ?? 'all';

        if ($id === 'all') {
            DB::execute("UPDATE notifications SET is_read=1 WHERE user_id=?", [$auth['sub']]);
        } else {
            DB::execute("UPDATE notifications SET is_read=1 WHERE id=? AND user_id=?", [$id, $auth['sub']]);
        }

        Response::ok(null, '已标记为已读');
    }
}
