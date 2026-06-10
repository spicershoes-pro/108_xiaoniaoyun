#!/usr/bin/env bash
# 生成 64 位随机 JWT Secret
# 用法：bash scripts/gen-jwt-secret.sh
echo "生成 JWT_SECRET..."
if command -v openssl &>/dev/null; then
  secret=$(openssl rand -hex 32)
else
  secret=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
fi
echo ""
echo "JWT_SECRET=${secret}"
echo ""
echo "✅ 请将上面的值写入对应环境的 .env 文件"
