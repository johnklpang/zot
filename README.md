# Zot Registry on Kubernetes

End-to-end Zot OCI registry for a **1 master + 3 worker** cluster.

| Requirement | Implementation |
|---|---|
| Namespace | `zot-registry` |
| Persistent storage | HostPath PV + PVC (`20Gi`, RWO) at `/data/zot-registry` |
| Endpoint | **`zot-registry:30001`** (Service + NodePort `30001`) |
| Image | `ghcr.io/project-zot/zot-linux-amd64:v2.1.8` |

## Quick deploy (your cluster)

```bash
# 1) On the worker that will store images
sudo mkdir -p /data/zot-registry
sudo chmod 777 /data/zot-registry

# 2) Label that worker (PV + pod both require this)
kubectl get nodes
kubectl label node <WORKER_NODE_NAME> zot-registry/storage=true --overwrite

# 3) Deploy
./scripts/deploy-zot.sh

# 4) Point hostname at any node IP (NodePort is on all nodes)
echo "<NODE_IP> zot-registry" | sudo tee -a /etc/hosts

# 5) Validate + upload test image
export REGISTRY_HOST=zot-registry
./scripts/validate-zot.sh
./scripts/push-test-image.sh   # needs: crane
```

Test image lands at:

```text
zot-registry:30001/demo/alpine:3.20
```

Verify:

```bash
curl http://zot-registry:30001/v2/_catalog
# {"repositories":["demo/alpine"]}
curl http://zot-registry:30001/v2/demo/alpine/tags/list
```

## Step-by-step detail

### 1. Prerequisites

- `kubectl` talking to your cluster (`kubectl get nodes` shows 1 control-plane + 3 workers)
- Directory `/data/zot-registry` on the storage worker
- Optional client tools: `crane` (push/pull), `curl`

### 2. Label storage worker

```bash
kubectl label node <WORKER_NODE_NAME> zot-registry/storage=true --overwrite
```

The PV `nodeAffinity` and Deployment `nodeAffinity` both select this label so the pod and hostPath data stay on the same node.

### 3. Deploy manifests

```bash
kubectl apply -k k8s/zot-registry
kubectl -n zot-registry get all,pvc,pv
kubectl -n zot-registry rollout status deployment/zot
```

Resources created:

1. Namespace `zot-registry`
2. PV `zot-registry-pv` + PVC `zot-registry-pvc` (20Gi)
3. ConfigMap `zot-config` (`/etc/zot/config.json`)
4. Deployment `zot` (1 replica, `Recreate`, volume at `/var/lib/registry`)
5. Service `zot-registry` — `port`/`nodePort` **30001** → container **5000**

### 4. Use `zot-registry:30001`

| From | URL |
|---|---|
| Nodes / laptops (via `/etc/hosts`) | `http://zot-registry:30001` |
| Any node IP | `http://<node-ip>:30001` |
| In-cluster | `http://zot-registry.zot-registry.svc.cluster.local:30001` |

Docker clients (HTTP, no TLS) need insecure registry config:

```json
{ "insecure-registries": ["zot-registry:30001"] }
```

### 5. Validation checklist

```bash
./scripts/validate-zot.sh
```

Checks: namespace, Ready pod on labeled worker, Bound PVC, NodePort 30001, `/v2/` API, in-cluster DNS.

### 6. Upload test image

```bash
./scripts/push-test-image.sh
```

### 7. Confirm persistence

```bash
kubectl -n zot-registry delete pod -l app.kubernetes.io/name=zot
kubectl -n zot-registry wait --for=condition=Ready pod -l app.kubernetes.io/name=zot --timeout=120s
curl http://zot-registry:30001/v2/_catalog
# demo/alpine should still appear
```

## Layout

```text
k8s/
  kind/cluster-config.yaml      # optional local kind: 1 CP + 3 workers
  zot-registry/
    00-namespace.yaml
    01-persistent-volume.yaml
    02-configmap.yaml
    03-deployment.yaml
    04-service.yaml
    config.json
    kustomization.yaml
scripts/
  deploy-zot.sh
  validate-zot.sh
  push-test-image.sh
  validate-manifests.sh
  create-kind-cluster.sh
  run-local-zot-docker.sh       # registry stand-in when kubelet unavailable
  validate-zot-docker.sh
  teardown-zot.sh
docs/VALIDATION.md
```

## Optional: kind lab (1+3)

On a host that can run kind:

```bash
./scripts/create-kind-cluster.sh
./scripts/deploy-zot.sh
echo "127.0.0.1 zot-registry" | sudo tee -a /etc/hosts
export REGISTRY_HOST=zot-registry
./scripts/validate-zot.sh
./scripts/push-test-image.sh
```

## Local registry stand-in (no Kubernetes)

Useful to exercise the same endpoint/image/config when kubelet cannot run:

```bash
./scripts/run-local-zot-docker.sh
./scripts/validate-zot-docker.sh
./scripts/push-test-image.sh
```

See [docs/VALIDATION.md](docs/VALIDATION.md) for recorded results.

## Teardown

```bash
./scripts/teardown-zot.sh
```

## Notes

- Auth/TLS are off for lab simplicity — add them in `02-configmap.yaml` before production.
- On ARM workers use `ghcr.io/project-zot/zot-linux-arm64:<tag>`.
- Update strategy is `Recreate` because the volume is `ReadWriteOnce`.
