#!/usr/bin/env bash
# ============================================================
# 霄鸟云 · 环境配置健康检查脚本
# 用法：bash scripts/check-env.sh [production|staging]
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/../backend" && pwd)"
ENV_FILE="${BACKEND_DIR}/.env"
ERRORS=0
WARNINGS=0

env_val() { grep "^${1}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- | xargs; }

echo "══════════════════════════════════════════"
echo "  霄鸟云 · 环境配置健康检查"
echo "══════════════════════════════════════════"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ FAIL: .env 文件不存在：${ENV_FILE}"
  exit 1
fi

APP_ENV=$(env_val APP_ENV)
echo "当前环境：${APP_ENV}"
echo ""

# ── 必填项检查 ────────────────────────────────────────────────
check_required() {
  local key="$1"
  local val
  val=$(env_val "$key")
  if [[ -z "$val" ]]; then
    echo "❌ FAIL: ${key} 未配置"
    ERRORS=$((ERRORS+1))
  elif echo "$val" | grep -q 'REPLACE_'; then
    echo "❌ FAIL: ${key} 仍为占位符（REPLACE_xxx），需要替换"
    ERRORS=$((ERRORS+1))
  else
    echo "✅ OK:   ${key}=$(echo "$val" | sed 's/.\{8\}$/***/')"
  fi
}

check_optional() {
  local key="$1"
  local val
  val=$(env_val "$key")
  if [[ -z "$val" ]]; then
    echo "⚠️  WARN: ${key} 未配置（可选）"
    WARNINGS=$((WARNINGS+1))
  elif echo "$val" | grep -q 'REPLACE_'; then
    echo "⚠️  WARN: ${key} 仍为占位符"
    WARNINGS=$((WARNINGS+1))
  else
    echo "✅ OK:   ${key} 已配置"
  fi
}

echo "── 基础配置 ──────────────────────────────"
check_required "APP_NAME"
check_required "APP_ENV"
check_required "APP_URL"

echo ""
echo "── 数据库 ────────────────────────────────"
check_required "DB_HOST"
check_required "DB_NAME"
check_required "DB_USER"
DB_PASS=$(env_val DB_PASS)
if [[ "$APP_ENV" == "production" || "$APP_ENV" == "staging" ]]; then
  if [[ -z "$DB_PASS" ]]; then
    echo "❌ FAIL: DB_PASS 生产环境必须设置密码"
    ERRORS=$((ERRORS+1))
  else
    echo "✅ OK:   DB_PASS 已设置（已隐藏）"
  fi
else
  echo "ℹ️  INFO: DB_PASS 为空（开发/测试可接受）"
fi

echo ""
echo "── JWT ───────────────────────────────────"
JWT_SECRET=$(env_val JWT_SECRET)
if [[ -z "$JWT_SECRET" ]]; then
  echo "❌ FAIL: JWT_SECRET 未配置"
  ERRORS=$((ERRORS+1))
elif [[ ${#JWT_SECRET} -lt 32 ]]; then
  echo "❌ FAIL: JWT_SECRET 长度 ${#JWT_SECRET} 位，要求至少 32 位"
  ERRORS=$((ERRORS+1))
elif echo "$JWT_SECRET" | grep -qE 'dev|test|change|secret|example'; then
  if [[ "$APP_ENV" == "production" ]]; then
    echo "❌ FAIL: JWT_SECRET 包含弱密钥关键词，生产禁止使用"
    ERRORS=$((ERRORS+1))
  else
    echo "⚠️  WARN: JWT_SECRET 包含弱密钥关键词（非生产可接受）"
    WARNINGS=$((WARNINGS+1))
  fi
else
  echo "✅ OK:   JWT_SECRET 强度符合要求（${#JWT_SECRET} 位）"
fi

echo ""
echo "── 短信 ──────────────────────────────────"
SMS=$(env_val SMS_PROVIDER)
if [[ "$SMS" == "mock" ]] && [[ "$APP_ENV" == "production" ]]; then
  echo "❌ FAIL: 生产环境 SMS_PROVIDER 不能为 mock"
  ERRORS=$((ERRORS+1))
elif [[ "$SMS" == "aliyun" ]]; then
  check_required "SMS_ACCESS_KEY"
  check_required "SMS_SECRET_KEY"
  check_required "SMS_SIGN_NAME"
  check_required "SMS_TEMPLATE_CODE"
elif [[ "$SMS" == "tencent" ]]; then
  check_required "TENCENT_SECRET_ID"
  check_required "TENCENT_SECRET_KEY"
  check_required "TENCENT_SMS_APP_ID"
  check_required "TENCENT_SMS_TPL_ID"
else
  echo "ℹ️  INFO: SMS_PROVIDER=${SMS}（mock 模式）"
fi

echo ""
echo "── CORS ──────────────────────────────────"
CORS=$(env_val CORS_ORIGINS)
if [[ "$CORS" == "*" ]] && [[ "$APP_ENV" == "production" ]]; then
  echo "❌ FAIL: 生产环境 CORS_ORIGINS 不允许为 *"
  ERRORS=$((ERRORS+1))
else
  echo "✅ OK:   CORS_ORIGINS=${CORS}"
fi

echo ""
echo "── 上传 ──────────────────────────────────"
UPLOAD_DRIVER=$(env_val UPLOAD_DRIVER)
if [[ "$UPLOAD_DRIVER" == "oss" ]]; then
  check_required "OSS_BUCKET"
  check_required "OSS_ACCESS_KEY"
  check_required "OSS_SECRET_KEY"
else
  echo "ℹ️  INFO: UPLOAD_DRIVER=${UPLOAD_DRIVER:-local}"
fi

echo ""
echo "── 安全开关 ──────────────────────────────"
UNIVERSAL=$(env_val ALLOW_UNIVERSAL_CODE)
if [[ "$UNIVERSAL" == "true" ]] && [[ "$APP_ENV" == "production" ]]; then
  echo "❌ FAIL: 生产环境 ALLOW_UNIVERSAL_CODE 不能为 true"
  ERRORS=$((ERRORS+1))
else
  echo "✅ OK:   ALLOW_UNIVERSAL_CODE=${UNIVERSAL:-false}"
fi

DEBUG=$(env_val APP_DEBUG)
if [[ "$DEBUG" == "true" ]] && [[ "$APP_ENV" == "production" ]]; then
  echo "❌ FAIL: 生产环境 APP_DEBUG 不能为 true"
  ERRORS=$((ERRORS+1))
else
  echo "✅ OK:   APP_DEBUG=${DEBUG:-false}"
fi

# ── 汇总 ─────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
if [[ $ERRORS -gt 0 ]]; then
  echo "❌ 检查不通过：${ERRORS} 个错误，${WARNINGS} 个警告"
  echo "   请修复所有错误后再部署"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo "⚠️  检查通过（含 ${WARNINGS} 个警告）"
  exit 0
else
  echo "✅ 检查全部通过！可以部署"
  exit 0
fi
