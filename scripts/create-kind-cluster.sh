#!/usr/bin/env bash
# Create a local kind cluster: 1 master + 3 workers, ready for Zot NodePort 30001.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-zot}"
DATA_DIR="${ZOT_DATA_DIR:-/tmp/zot-kind-data}"

echo "==> Preparing host data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
chmod 777 "${DATA_DIR}"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "==> kind cluster '${CLUSTER_NAME}' already exists"
else
  echo "==> Creating kind cluster '${CLUSTER_NAME}' (1 control-plane + 3 workers)"
  kind create cluster --config "${ROOT}/k8s/kind/cluster-config.yaml"
fi

echo "==> Waiting for nodes to be Ready"
kubectl wait --for=condition=Ready nodes --all --timeout=180s

WORKER="$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')"
echo "==> Labeling worker '${WORKER}' for Zot persistent storage"
kubectl label node "${WORKER}" zot-registry/storage=true --overwrite

echo "==> Ensuring data path exists inside the worker container"
docker exec "${WORKER}" mkdir -p /data/zot-registry
docker exec "${WORKER}" chmod 777 /data/zot-registry

echo "==> Cluster ready"
kubectl get nodes -o wide
kubectl get nodes -l zot-registry/storage=true
