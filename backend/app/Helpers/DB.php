<?php
namespace App\Helpers;

use PDO;
use PDOException;

class DB
{
    private static ?PDO $instance = null;

    public static function getInstance(): PDO
    {
        if (self::$instance === null) {
            $cfg = require ROOT . '/config/database.php';
            $dsn = "mysql:host={$cfg['host']};port={$cfg['port']};dbname={$cfg['database']};charset={$cfg['charset']}";
            try {
                self::$instance = new PDO($dsn, $cfg['username'], $cfg['password'], $cfg['options']);
            } catch (PDOException $e) {
                http_response_code(500);
                header('Content-Type: application/json; charset=utf-8');
                echo json_encode(['code' => -1, 'msg' => '数据库连接失败', 'data' => null]);
                exit;
            }
        }
        return self::$instance;
    }

    /** 执行查询并返回全部行 */
    public static function select(string $sql, array $params = []): array
    {
        $stmt = self::getInstance()->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    /** 执行查询并返回单行 */
    public static function first(string $sql, array $params = []): ?array
    {
        $stmt = self::getInstance()->prepare($sql);
        $stmt->execute($params);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    /** 执行写操作，返回影响行数 */
    public static function execute(string $sql, array $params = []): int
    {
        $stmt = self::getInstance()->prepare($sql);
        $stmt->execute($params);
        return $stmt->rowCount();
    }

    /** 执行 INSERT，返回自增ID */
    public static function insert(string $sql, array $params = []): int
    {
        self::execute($sql, $params);
        return (int)self::getInstance()->lastInsertId();
    }

    /**
     * 分页查询：返回 [list, total, page, per_page, total_pages]
     * 使用子查询包装 COUNT，兼容 JOIN/GROUP BY 场景
     */
    public static function paginate(
        string $sql,
        array  $params  = [],
        int    $page    = 1,
        int    $perPage = 20
    ): array {
        // 稳健 COUNT：用子查询包装，兼容 LEFT JOIN + GROUP BY
        $countSql = "SELECT COUNT(*) AS total FROM ({$sql}) AS _count_tbl";
        $total    = (int)(self::first($countSql, $params)['total'] ?? 0);

        // 分页数据
        $page    = max(1, $page);
        $perPage = max(1, $perPage);
        $offset  = ($page - 1) * $perPage;
        $dataSql = $sql . " LIMIT {$perPage} OFFSET {$offset}";
        $list    = self::select($dataSql, $params);

        return [
            'list'        => $list,
            'total'       => $total,
            'page'        => $page,
            'per_page'    => $perPage,
            'total_pages' => (int)ceil($total / max(1, $perPage)),
        ];
    }

    /** 事务支持 */
    public static function beginTransaction(): void { self::getInstance()->beginTransaction(); }
    public static function commit(): void           { self::getInstance()->commit(); }
    public static function rollback(): void         { self::getInstance()->rollBack(); }

    /** 最后插入ID（外部可用） */
    public static function lastId(): int { return (int)self::getInstance()->lastInsertId(); }
}
