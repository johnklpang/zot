#!/usr/bin/env bash
# Local Zot stand-in for environments without a working kubelet.
# Mirrors the K8s service endpoint: zot-registry:30001 with persistent data.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="${ZOT_CONTAINER_NAME:-zot-registry}"
DATA_DIR="${ZOT_DATA_DIR:-/tmp/zot-docker-data}"
PORT="${ZOT_PORT:-30001}"
IMAGE="${ZOT_IMAGE:-ghcr.io/project-zot/zot-linux-amd64:v2.1.8}"

mkdir -p "${DATA_DIR}"
chmod 777 "${DATA_DIR}"

# Host alias used by validation / push scripts
if ! grep -qE '(^|[[:space:]])zot-registry([[:space:]]|$)' /etc/hosts; then
  echo "127.0.0.1 zot-registry" | sudo tee -a /etc/hosts >/dev/null
  echo "==> Added 127.0.0.1 zot-registry to /etc/hosts"
fi

if docker ps -a --format '{{.Names}}' | grep -qx "${NAME}"; then
  echo "==> Removing existing container ${NAME}"
  docker rm -f "${NAME}" >/dev/null
fi

echo "==> Starting Zot on host port ${PORT} with persistent dir ${DATA_DIR}"
docker run -d \
  --name "${NAME}" \
  --restart unless-stopped \
  -p "${PORT}:5000" \
  -v "${DATA_DIR}:/var/lib/registry" \
  -v "${ROOT}/k8s/zot-registry/config.json:/etc/zot/config.json:ro" \
  "${IMAGE}" serve /etc/zot/config.json

echo "==> Waiting for registry API"
for i in $(seq 1 30); do
  if curl -sf "http://zot-registry:${PORT}/v2/" >/dev/null; then
    echo "==> Zot is up at http://zot-registry:${PORT}"
    exit 0
  fi
  sleep 1
done

echo "ERROR: Zot did not become ready"
docker logs "${NAME}" || true
exit 1
