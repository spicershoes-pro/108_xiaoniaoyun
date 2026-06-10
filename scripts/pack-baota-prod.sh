#!/usr/bin/env bash
# 打包宝塔非 Docker 生产部署目录
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/dist-baota-prod"
STAGE="${OUT}/xiaoniaoyun.dowima.com"
TAR="${ROOT}/108_xiaoniaoyun-baota-prod.tar.gz"

echo "==> 构建三端 production"
for app in buyer merchant admin; do
  dir="${ROOT}/frontend/${app}"
  cp -f "${dir}/env/.env.production" "${dir}/.env.production"
  (cd "$dir" && npm run build -- --mode production)
done

echo "==> 组装目录"
rm -rf "$OUT" "$TAR"
mkdir -p "$STAGE"/{backend,merchant,admin}
rsync -a --exclude node_modules --exclude .git \
  "${ROOT}/backend/" "$STAGE/backend/"
cp "${ROOT}/deploy/baota/backend.env.production" "$STAGE/backend/.env"
rsync -a "${ROOT}/frontend/buyer/dist/" "$STAGE/"
rsync -a "${ROOT}/frontend/merchant/dist/" "$STAGE/merchant/"
rsync -a "${ROOT}/frontend/admin/dist/" "$STAGE/admin/"
mkdir -p "$STAGE/backend/public/uploads" "$STAGE/backend/storage/logs"
cp "${ROOT}/database/schema.sql" "${ROOT}/database/seed.sql" "$OUT/"
cp "${ROOT}/deploy/baota/nginx-108_xiaoniaoyun_routes.conf" "$OUT/"

(cd "$OUT" && tar -czf "$TAR" xiaoniaoyun.dowima.com schema.sql seed.sql nginx-108_xiaoniaoyun_routes.conf)
echo "==> 完成: $TAR ($(du -h "$TAR" | awk '{print $1}'))"
