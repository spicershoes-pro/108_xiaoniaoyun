#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export XNY_API_BASE="${XNY_API_BASE:-http://127.0.0.1:18080}"
php "$ROOT/scripts/accept-merchant-inner.php"
