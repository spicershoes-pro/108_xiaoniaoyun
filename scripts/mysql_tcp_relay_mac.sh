#!/usr/bin/env bash
# macOS 应用机 Docker 经 host.docker.internal 访问远程 MySQL
set -euo pipefail
UP="${RELAY_UPSTREAM_HOST:-192.168.1.223}"
LOCAL="${RELAY_LOCAL_PORT:-13320}"
REMOTE="${RELAY_REMOTE_PORT:-3320}"
pkill -f "nc.*${LOCAL}.*${UP}" 2>/dev/null || true
while true; do
  nc -l "${LOCAL}" 0.0.0.0 | nc "${UP}" "${REMOTE}" || sleep 2
done
