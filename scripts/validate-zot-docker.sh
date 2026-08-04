#!/usr/bin/env bash
# Validate the Docker-hosted Zot stand-in (endpoint zot-registry:30001).
set -euo pipefail

PORT=30001
REGISTRY_HOST="${REGISTRY_HOST:-zot-registry}"
REGISTRY="${REGISTRY_HOST}:${PORT}"
NAME="${ZOT_CONTAINER_NAME:-zot-registry}"
DATA_DIR="${ZOT_DATA_DIR:-/tmp/zot-docker-data}"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; exit 1; }

echo "==> 1) Container running"
docker inspect -f '{{.State.Running}}' "${NAME}" 2>/dev/null | grep -q true || fail "container ${NAME} not running"
pass "container ${NAME} running"

echo "==> 2) Port binding 30001"
docker port "${NAME}" | grep -q '5000/tcp -> .*:30001' || fail "port 30001 not bound"
pass "host :30001 -> container :5000"

echo "==> 3) Persistent data directory mounted"
MOUNT="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/registry"}}{{.Source}}{{end}}{{end}}' "${NAME}")"
[[ -n "${MOUNT}" ]] || fail "no volume on /var/lib/registry"
pass "persistent mount ${MOUNT} -> /var/lib/registry"

echo "==> 4) Registry API /v2/"
HTTP_CODE="$(curl -sS -o /tmp/zot-v2.json -w '%{http_code}' "http://${REGISTRY}/v2/")"
[[ "${HTTP_CODE}" == "200" ]] || fail "GET /v2/ -> ${HTTP_CODE}"
pass "GET http://${REGISTRY}/v2/ -> 200"

echo "==> 5) Catalog"
curl -sf "http://${REGISTRY}/v2/_catalog" | tee /tmp/zot-catalog.json
echo
pass "catalog reachable"

echo "==> 6) Hostname alias zot-registry"
getent hosts zot-registry >/dev/null || fail "zot-registry not in hosts/DNS"
pass "zot-registry resolves"

echo
echo "Docker Zot validation passed (${REGISTRY})."
