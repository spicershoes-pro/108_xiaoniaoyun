#!/usr/bin/env bash
# P0 业务流 API 验收
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export XNY_API_BASE="${XNY_API_BASE:-http://127.0.0.1:18080}"
php "$ROOT/scripts/accept-p0-inner.php"
