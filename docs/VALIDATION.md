# Validation results

## Manifest schema

```text
kubeconform: 6 resources found in 5 files - Valid: 6, Invalid: 0, Errors: 0, Skipped: 0
Structural checks: namespace zot-registry, NodePort 30001, PVC mount, storage label affinity
```

## Registry runtime (Docker stand-in for zot-registry:30001)

This cloud environment cannot run kubelet (cgroup v2 nesting blocks ContainerManager).
Registry behavior was validated with the same Zot image/config and endpoint shape as the K8s Service.

| Check | Result |
|---|---|
| Container running | PASS |
| Host `:30001` → container `:5000` | PASS |
| Persistent mount `/var/lib/registry` | PASS |
| `GET http://zot-registry:30001/v2/` | PASS (200) |
| Catalog before push | `{"repositories":[]}` |
| Push `alpine:3.20` → `zot-registry:30001/demo/alpine:3.20` | PASS |
| Catalog after push | `{"repositories":["demo/alpine"]}` |
| Tags list | `{"name":"demo/alpine","tags":["3.20"]}` |
| Digest | `sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc` |
| Survive container restart | PASS (image still listed) |

## Commands used

```bash
./scripts/validate-manifests.sh
./scripts/run-local-zot-docker.sh
./scripts/validate-zot-docker.sh
./scripts/push-test-image.sh
```

## On your 1 master + 3 worker cluster

```bash
# on chosen worker
sudo mkdir -p /data/zot-registry && sudo chmod 777 /data/zot-registry
kubectl label node <WORKER> zot-registry/storage=true --overwrite
./scripts/deploy-zot.sh
echo "<NODE_IP> zot-registry" | sudo tee -a /etc/hosts
export REGISTRY_HOST=zot-registry
./scripts/validate-zot.sh
./scripts/push-test-image.sh
```
