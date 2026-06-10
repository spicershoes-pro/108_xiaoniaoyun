<?php
namespace App\Controllers;
use App\Helpers\{DB, Response};

class BannerController
{
    /** GET /api/banners?position=home */
    public function index(array $p, array $b): void
    {
        $banners = DB::select(
            "SELECT id, title, subtitle, tag, emoji, bg_style,
                    link_url, position, status, clicks
             FROM banners
             WHERE status = 'active'
             ORDER BY position ASC, id ASC
             LIMIT 10"
        );

        Response::ok($banners);
    }
}
