#!/usr/bin/env python3
"""从 backend/routes/api.php 生成 OpenAPI 3.0.3（Apifox 可导入）"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTES_FILE = ROOT / "backend/routes/api.php"
OUT_FILE = ROOT / "doc/api/108_xny-openapi.yaml"

PUBLIC = {
    ("POST", "/auth/send-code"),
    ("POST", "/auth/login"),
    ("GET", "/products"),
    ("GET", "/products/{id}"),
    ("GET", "/merchants"),
    ("GET", "/merchants/{id}"),
    ("GET", "/banners"),
    ("GET", "/currencies"),
    ("GET", "/ranking"),
    ("GET", "/posts"),
    ("GET", "/search"),
}

PAGINATED_GET = {
    "/products", "/merchants", "/inquiries", "/orders", "/notifications",
    "/samples", "/favorites", "/conversations", "/withdrawals", "/posts", "/ips",
    "/admin/users", "/admin/merchants", "/admin/products", "/admin/orders",
    "/admin/inquiries", "/admin/content", "/admin/finance", "/admin/ips", "/admin/logs",
}

TAG_RULES = [
    ("/auth", "认证"),
    ("/products", "产品"),
    ("/merchants", "工厂"),
    ("/inquiries", "询盘"),
    ("/orders", "订单"),
    ("/conversations", "消息"),
    ("/cart", "购物车"),
    ("/favorites", "收藏"),
    ("/samples", "样品"),
    ("/search", "发现"),
    ("/banners", "发现"),
    ("/currencies", "发现"),
    ("/notifications", "通知"),
    ("/ips", "IP授权"),
    ("/posts", "发现"),
    ("/ranking", "发现"),
    ("/merchant", "商家端"),
    ("/withdrawals", "商家端"),
    ("/admin", "管理端"),
]


def tag_for(path: str) -> str:
    for prefix, tag in TAG_RULES:
        if path.startswith(prefix):
            return tag
    return "其他"


def parse_routes() -> list[tuple[str, str, str]]:
    text = ROUTES_FILE.read_text(encoding="utf-8")
    pat = re.compile(
        r"\['(\w+)',\s+'([^']+)',\s+\[(\w+)::class,\s+'(\w+)'\]\]"
    )
    return [(m.group(1), m.group(2), f"{m.group(3)}_{m.group(4)}") for m in pat.finditer(text)]


def build_path_item(method: str, path: str, op_id: str) -> str:
    tag = tag_for(path)
    need_auth = (method, path) not in PUBLIC
    lines = [
        f"    {method.lower()}:",
        f"      tags: [{tag}]",
        f"      summary: {op_id}",
        f"      operationId: {op_id}",
    ]

    params: list[str] = []
    for p in re.findall(r"\{(\w+)\}", path):
        params += [
            f"        - name: {p}",
            "          in: path",
            "          required: true",
            "          schema:",
            "            type: integer",
        ]
    if method == "GET" and path in PAGINATED_GET:
        params += [
            "        - name: page",
            "          in: query",
            "          schema:",
            "            type: integer",
            "            default: 1",
            "        - name: per_page",
            "          in: query",
            "          schema:",
            "            type: integer",
            "            default: 20",
        ]
    if params:
        lines.append("      parameters:")
        lines.extend(params)

    if method in ("POST", "PUT", "PATCH", "DELETE") and method != "DELETE":
        ref = None
        if path == "/auth/login":
            ref = "#/components/schemas/LoginRequest"
        elif path == "/auth/send-code":
            ref = "#/components/schemas/SendCodeRequest"
        lines += [
            "      requestBody:",
            "        required: true",
            "        content:",
            "          application/json:",
            "            schema:",
        ]
        if ref:
            lines.append(f"              $ref: '{ref}'")
        else:
            lines += [
                "              type: object",
                "              additionalProperties: true",
            ]

    lines += [
        "      responses:",
        "        '200':",
        "          description: 成功（code=0）",
        "          content:",
        "            application/json:",
        "              schema:",
        "                $ref: '#/components/schemas/ApiResult'",
        "        '401':",
        "          description: 未登录",
        "          content:",
        "            application/json:",
        "              schema:",
        "                $ref: '#/components/schemas/ApiError'",
        "        '403':",
        "          description: 权限不足",
        "        '404':",
        "          description: 资源不存在",
        "        '422':",
        "          description: 参数校验失败",
    ]
    if need_auth:
        lines += ["      security:", "        - bearerAuth: []"]
    return "\n".join(lines)


def main() -> None:
    routes = parse_routes()
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    header = """openapi: 3.0.3
info:
  title: 108_xny · 108_霄鸟云 API
  description: |
    跨境玩具 B2B 选品平台 · PHP 8.2 后端

    **统一响应**：`{ code, msg, data }`，`code=0` 成功。

    **分页列表**额外字段：`total`、`page`、`per_page`、`total_pages`。

    **鉴权**：
    - 前缀 `/api`（Nginx 转发至 `backend/public/index.php`）
    - Header `Authorization: Bearer {token}`（登录接口返回）
    - 可选 Cookie `xn_token`、Query `?token=`

    **Apifox 导入**：项目设置 → 导入数据 → OpenAPI/Swagger → 上传本 YAML 文件。

    **导出格式**（Apifox 内）：OpenAPI 3.0 YAML/JSON、Postman、HTML、Markdown、Apifox 原生。
  version: 1.0.0
servers:
  - url: https://xiaoniaoyun.dowima.com/api
    description: 生产环境
  - url: http://127.0.0.1:18080/api
    description: 本地开发（dev.sh）
  - url: http://192.168.1.184/api
    description: 108 内网直连
tags:
  - name: 认证
  - name: 产品
  - name: 工厂
  - name: 询盘
  - name: 订单
  - name: 消息
  - name: 购物车
  - name: 收藏
  - name: 样品
  - name: 发现
  - name: 通知
  - name: IP授权
  - name: 商家端
  - name: 管理端
paths:
"""

    paths: dict[str, list[str]] = {}
    for method, path, op_id in routes:
        paths.setdefault(path, []).append(build_path_item(method, path, op_id))

    parts = [header]
    for path in sorted(paths.keys()):
        parts.append(f"  {path}:\n")
        parts.append("\n".join(paths[path]))
        parts.append("\n")

    footer = """
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: POST /auth/login 返回的 token
  schemas:
    ApiResult:
      type: object
      properties:
        code:
          type: integer
          example: 0
        msg:
          type: string
          example: success
        data:
          nullable: true
    ApiError:
      type: object
      properties:
        code:
          type: integer
          example: 401
        msg:
          type: string
        data:
          nullable: true
    LoginRequest:
      type: object
      required: [phone, code]
      properties:
        phone:
          type: string
          example: '18888888888'
        code:
          type: string
          example: '123456'
    SendCodeRequest:
      type: object
      required: [phone]
      properties:
        phone:
          type: string
          example: '18888888888'
        purpose:
          type: string
          default: login
"""

    OUT_FILE.write_text("".join(parts) + footer, encoding="utf-8")
    print(f"Generated {OUT_FILE} ({len(routes)} operations)")


if __name__ == "__main__":
    main()
