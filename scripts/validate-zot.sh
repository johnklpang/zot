#!/usr/bin/env bash
# Validate Zot registry: API health, catalog, persistence mounts, NodePort.
set -euo pipefail

NS=zot-registry
SVC=zot-registry
PORT=30001
REGISTRY_HOST="${REGISTRY_HOST:-127.0.0.1}"
REGISTRY="${REGISTRY_HOST}:${PORT}"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; exit 1; }

echo "==> 1) Namespace exists"
kubectl get ns "${NS}" >/dev/null || fail "namespace ${NS} missing"
pass "namespace ${NS}"

echo "==> 2) Pod is Running/Ready"
POD="$(kubectl -n "${NS}" get pod -l app.kubernetes.io/name=zot -o jsonpath='{.items[0].metadata.name}')"
PHASE="$(kubectl -n "${NS}" get pod "${POD}" -o jsonpath='{.status.phase}')"
READY="$(kubectl -n "${NS}" get pod "${POD}" -o jsonpath='{.status.containerStatuses[0].ready}')"
[[ "${PHASE}" == "Running" && "${READY}" == "true" ]] || fail "pod ${POD} phase=${PHASE} ready=${READY}"
pass "pod ${POD} Running/Ready"

echo "==> 3) Pod scheduled on storage-labeled worker"
NODE="$(kubectl -n "${NS}" get pod "${POD}" -o jsonpath='{.spec.nodeName}')"
LABEL="$(kubectl get node "${NODE}" -o jsonpath='{.metadata.labels.zot-registry/storage}')"
[[ "${LABEL}" == "true" ]] || fail "pod on ${NODE} without zot-registry/storage=true"
pass "pod on storage node ${NODE}"

echo "==> 4) PVC Bound and mounted"
PVC_PHASE="$(kubectl -n "${NS}" get pvc zot-registry-pvc -o jsonpath='{.status.phase}')"
[[ "${PVC_PHASE}" == "Bound" ]] || fail "PVC phase=${PVC_PHASE}"
MOUNT="$(kubectl -n "${NS}" get pod "${POD}" -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="zot-data")].mountPath}')"
[[ "${MOUNT}" == "/var/lib/registry" ]] || fail "unexpected mount path: ${MOUNT}"
pass "PVC Bound, mounted at /var/lib/registry"

echo "==> 5) Service NodePort is 30001"
NP="$(kubectl -n "${NS}" get svc "${SVC}" -o jsonpath='{.spec.ports[0].nodePort}')"
SP="$(kubectl -n "${NS}" get svc "${SVC}" -o jsonpath='{.spec.ports[0].port}')"
[[ "${NP}" == "30001" && "${SP}" == "30001" ]] || fail "service port=${SP} nodePort=${NP}"
pass "Service ${SVC} port/nodePort=30001"

echo "==> 6) Registry HTTP API via NodePort (${REGISTRY})"
HTTP_CODE="$(curl -sS -o /tmp/zot-v2.json -w '%{http_code}' "http://${REGISTRY}/v2/" || true)"
[[ "${HTTP_CODE}" == "200" ]] || fail "GET /v2/ returned ${HTTP_CODE}"
pass "GET http://${REGISTRY}/v2/ -> 200"

echo "==> 7) Catalog endpoint"
HTTP_CODE="$(curl -sS -o /tmp/zot-catalog.json -w '%{http_code}' "http://${REGISTRY}/v2/_catalog" || true)"
[[ "${HTTP_CODE}" == "200" ]] || fail "GET /v2/_catalog returned ${HTTP_CODE}"
cat /tmp/zot-catalog.json
echo
pass "catalog reachable"

echo "==> 8) In-cluster DNS name resolution"
kubectl -n "${NS}" delete pod zot-dns-check --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "${NS}" run zot-dns-check --restart=Never --image=curlimages/curl:8.7.1 -- \
  curl -sf "http://zot-registry.zot-registry.svc.cluster.local:30001/v2/"
kubectl -n "${NS}" wait --for=jsonpath='{.status.phase}'=Succeeded pod/zot-dns-check --timeout=120s \
  || fail "in-cluster DNS/service check failed"
kubectl -n "${NS}" delete pod zot-dns-check --ignore-not-found >/dev/null 2>&1 || true
pass "zot-registry.zot-registry.svc.cluster.local:30001 reachable in-cluster"

echo
echo "All validation checks passed."
