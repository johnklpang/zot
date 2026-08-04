#!/usr/bin/env bash
# Pull a small public image, retag, push to Zot at zot-registry:30001, then verify.
set -euo pipefail

PORT=30001
REGISTRY_HOST="${REGISTRY_HOST:-127.0.0.1}"

# Prefer hostname alias when present (maps to NodePort via /etc/hosts)
if grep -qE '(^|[[:space:]])zot-registry([[:space:]]|$)' /etc/hosts 2>/dev/null; then
  REGISTRY_HOST="zot-registry"
fi

REGISTRY="${REGISTRY_HOST}:${PORT}"
SRC_IMAGE="${SRC_IMAGE:-docker.io/library/alpine:3.20}"
DEST_IMAGE="${REGISTRY}/demo/alpine:3.20"

echo "==> Source image: ${SRC_IMAGE}"
echo "==> Destination:  ${DEST_IMAGE}"

echo "==> Copying image into Zot (crane, insecure HTTP)"
crane copy --insecure "${SRC_IMAGE}" "${DEST_IMAGE}"

echo "==> Verifying catalog"
curl -sf "http://${REGISTRY}/v2/_catalog"
echo
curl -sf "http://${REGISTRY}/v2/demo/alpine/tags/list"
echo

echo "==> Pulling digest back from registry"
DIGEST="$(crane digest --insecure "${DEST_IMAGE}")"
echo "Digest: ${DIGEST}"

echo "==> Manifest summary"
crane manifest --insecure "${DEST_IMAGE}" >/tmp/zot-manifest.json
python3 - <<'PY'
import json
m=json.load(open("/tmp/zot-manifest.json"))
print("mediaType:", m.get("mediaType"))
print("schemaVersion:", m.get("schemaVersion"))
print("layers:", len(m.get("layers", m.get("manifests", []))))
PY

echo
echo "Test image uploaded successfully:"
echo "  ${DEST_IMAGE}"
echo "Pull example:"
echo "  crane pull --insecure ${DEST_IMAGE} /tmp/demo-alpine.tar"
echo "  # or docker (after adding insecure-registries for ${REGISTRY}):"
echo "  docker pull ${DEST_IMAGE}"
