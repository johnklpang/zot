#!/usr/bin/env bash
# Schema-validate Kubernetes manifests (no cluster required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${ROOT}/k8s/zot-registry"

echo "==> kubeconform validation"
kubeconform -summary -strict -ignore-missing-schemas \
  -schema-location default \
  "${DIR}/00-namespace.yaml" \
  "${DIR}/01-persistent-volume.yaml" \
  "${DIR}/02-configmap.yaml" \
  "${DIR}/03-deployment.yaml" \
  "${DIR}/04-service.yaml"

echo "==> Structural checks"
grep -q 'name: zot-registry' "${DIR}/00-namespace.yaml"
grep -q 'nodePort: 30001' "${DIR}/04-service.yaml"
grep -q 'port: 30001' "${DIR}/04-service.yaml"
grep -q 'name: zot-registry' "${DIR}/04-service.yaml"
grep -q 'persistentVolumeClaim' "${DIR}/03-deployment.yaml"
grep -q 'zot-registry/storage' "${DIR}/01-persistent-volume.yaml"
grep -q 'zot-registry/storage' "${DIR}/03-deployment.yaml"
grep -q '/var/lib/registry' "${DIR}/03-deployment.yaml"

echo "Manifest validation passed."
