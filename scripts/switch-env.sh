#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 环境切换脚本
# 用法：bash scripts/switch-env.sh [development|testing|staging|production]
# ============================================================

set -euo pipefail

ENV="${1:-development}"
VALID_ENVS=("development" "testing" "staging" "production")

valid=false
for e in "${VALID_ENVS[@]}"; do
  [[ "$e" == "$ENV" ]] && valid=true && break
done

if [[ "$valid" == "false" ]]; then
  echo "❌ 无效环境：$ENV  可选值：${VALID_ENVS[*]}"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend"
FRONTEND_DIR="${ROOT_DIR}/frontend"
ENV_FILE="${BACKEND_DIR}/config/env/.env.${ENV}"

echo "══════════════════════════════════════════"
echo "  霄鸟云 · 切换至 [$ENV] 环境"
echo "══════════════════════════════════════════"

# ── 1. 后端 ──────────────────────────────────────────────────
if [[ -f "$ENV_FILE" ]]; then
  cp "$ENV_FILE" "${BACKEND_DIR}/.env"
  echo "✅ 后端 .env 已加载 config/env/.env.${ENV}"
else
  echo "⚠️  未找到 ${ENV_FILE}，请先创建该环境配置文件"
fi

# 生产/预发环境安全检查
if [[ "$ENV" == "production" ]] || [[ "$ENV" == "staging" ]]; then
  if grep -q 'REPLACE_' "${BACKEND_DIR}/.env" 2>/dev/null; then
    echo ""
    echo "❌ 发现未替换的占位符，禁止部署！"
    grep 'REPLACE_' "${BACKEND_DIR}/.env"
    exit 1
  fi
fi

# ── 2. 前端 ──────────────────────────────────────────────────
for app in buyer merchant admin; do
  src="${FRONTEND_DIR}/${app}/env/.env.${ENV}"
  dst="${FRONTEND_DIR}/${app}/.env.${ENV}"
  if [[ -f "$src" ]]; then
    cp "$src" "$dst"
    echo "✅ 前端 ${app}：env/.env.${ENV} 已就绪"
  else
    echo "⚠️  前端 ${app}：未找到 env/.env.${ENV}"
  fi
done

# ── 3. 摘要 ──────────────────────────────────────────────────
echo ""
echo "── 当前环境摘要 ──────────────────────────"
if [[ -f "${BACKEND_DIR}/.env" ]]; then
  grep -E '^(APP_ENV|APP_URL|DB_NAME|SMS_PROVIDER|APP_DEBUG)=' "${BACKEND_DIR}/.env"
fi
echo "──────────────────────────────────────────"
echo ""
echo "✅ 环境切换完成！"
echo "   后端：cd backend && php -S localhost:8080 -t public"
echo "   前端：cd frontend/buyer && npm run dev"
