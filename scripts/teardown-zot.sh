#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Deleting Zot resources"
kubectl delete -k "${ROOT}/k8s/zot-registry" --ignore-not-found

echo "==> Deleting retained PV (if still present)"
kubectl delete pv zot-registry-pv --ignore-not-found

echo "Teardown complete."
