#!/usr/bin/env bash
# Deploy Zot registry manifests into namespace zot-registry.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Checking cluster access"
kubectl cluster-info >/dev/null

if ! kubectl get nodes -l zot-registry/storage=true --no-headers 2>/dev/null | grep -q .; then
  echo "ERROR: No node labeled zot-registry/storage=true"
  echo "Label a worker first, e.g.:"
  echo "  kubectl label node <worker-name> zot-registry/storage=true --overwrite"
  exit 1
fi

echo "==> Applying Zot manifests"
kubectl apply -k "${ROOT}/k8s/zot-registry"

echo "==> Waiting for PVC to bind"
kubectl -n zot-registry wait --for=jsonpath='{.status.phase}'=Bound pvc/zot-registry-pvc --timeout=60s

echo "==> Waiting for Deployment rollout"
kubectl -n zot-registry rollout status deployment/zot --timeout=180s

echo "==> Waiting for pod Ready"
kubectl -n zot-registry wait --for=condition=Ready pod -l app.kubernetes.io/name=zot --timeout=180s

echo "==> Resources"
kubectl -n zot-registry get all,pvc,pv
kubectl get svc -n zot-registry zot-registry -o wide

echo "==> Deploy complete. Registry endpoint: zot-registry:30001 (NodePort)"
