#!/usr/bin/env bash
# docker/scripts/build.sh
# 霄鸟云镜像构建脚本
# 用法：bash docker/scripts/build.sh [dev|prod] [tag]

set -euo pipefail

MODE="${1:-dev}"
TAG="${2:-$(date +%Y%m%d%H%M)}"
REGISTRY="${REGISTRY:-108_xiaoniaoyun}"

echo "══════════════════════════════════════════"
echo "  霄鸟云镜像构建  mode=${MODE}  tag=${TAG}"
echo "══════════════════════════════════════════"

# ── 构建后端镜像 ─────────────────────────────────────────────
echo ""
echo "▶ 构建后端镜像..."
docker build \
  --file Dockerfile.backend \
  --tag "${REGISTRY}/backend:${TAG}" \
  --tag "${REGISTRY}/backend:${MODE}" \
  --cache-from "${REGISTRY}/backend:cache" \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  .
echo "✅ backend:${TAG}"

# ── 构建前端三端镜像 ─────────────────────────────────────────
for APP in buyer merchant admin; do
  echo ""
  echo "▶ 构建前端 ${APP} 镜像..."
  docker build \
    --file Dockerfile.frontend \
    --build-arg APP="${APP}" \
    --tag "${REGISTRY}/frontend-${APP}:${TAG}" \
    --tag "${REGISTRY}/frontend-${APP}:${MODE}" \
    --cache-from "${REGISTRY}/frontend-${APP}:cache" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    .
  echo "✅ frontend-${APP}:${TAG}"
done

echo ""
echo "══════════════════════════════════════════"
echo "✅ 所有镜像构建完成！"
echo ""
echo "镜像列表："
echo "  ${REGISTRY}/backend:${TAG}"
echo "  ${REGISTRY}/frontend-buyer:${TAG}"
echo "  ${REGISTRY}/frontend-merchant:${TAG}"
echo "  ${REGISTRY}/frontend-admin:${TAG}"
echo ""
echo "下一步："
if [ "$MODE" = "prod" ]; then
  echo "  docker compose -f docker-compose.prod.yml up -d"
else
  echo "  docker compose up -d"
fi
echo "══════════════════════════════════════════"
