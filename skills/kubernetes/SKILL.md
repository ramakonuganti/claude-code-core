---
category: technical
description: Kubernetes patterns — Istio ambient mesh, resource requests, kubectl commands, secrets, Helm CRD upgrade gotchas, and mutation safety rules.
paths:
  - "**/k8s/**"
  - "**/kubernetes/**"
  - "**/manifests/**"
  - "**/helm/**"
  - "**/charts/**"
---
# Skill: Kubernetes — Cluster Patterns

**Context:** Managed Kubernetes (e.g. GKE) with a service mesh in ambient mode on higher environments. Tooling: `kubectl`, Helm, Terraform kubernetes provider.

---

## Cluster Topology (fill in for your org)

| Env | Mode | Service Mesh | Notes |
|-----|------|-------------|-------|
| dev | Standard | sidecar → migrating to ambient | In-progress migration |
| stage | Standard | Istio ambient | L7 via waypoints, L4 via ztunnel |
| prod | Standard | Istio ambient | Same as stage |
| cicd | Autopilot | None | CI runners only |

---

## Istio Ambient Mode (stage/prod)

Ambient mode removes sidecars from pods. Instead:
- **ztunnel** (DaemonSet) handles L4 mTLS — one per node, transparent to pods
- **waypoint proxies** handle L7 (HTTP routing, retries, auth policies) — one per namespace/service

**Why ambient over sidecars?**
- No sidecar injection → simpler pod specs
- No sidecar restart when updating Istio
- Lower resource overhead per pod (no Envoy in every pod)
- Pods start faster (no sidecar init container)

```bash
# Check if ambient mode is active on a namespace
kubectl get ns <namespace> -o jsonpath='{.metadata.labels}'
# Should show: istio.io/dataplane-mode=ambient

# Check ztunnel status
kubectl get pods -n istio-system -l app=ztunnel

# Check waypoint proxies
kubectl get pods -n <namespace> -l gateway.istio.io/managed=istio.io-mesh-controller
```

---

## Resource Requests — Always Set Them

```yaml
resources:
  requests:
    cpu: "100m"      # 100 millicores = 0.1 CPU
    memory: "128Mi"  # 128 mebibytes
  limits:
    cpu: "500m"
    memory: "512Mi"
```

**Autopilot clusters:** Pods without `resources.requests` are rejected by the admission controller. Non-negotiable.

**Standard clusters:** Highly recommended — without requests, the scheduler can't make good placement decisions and pods may get OOM-killed.

**CPU units:** `1000m` = 1 full CPU core. `100m` = 10% of one core.
**Memory units:** Mi (mebibytes) preferred over M (megabytes). `1Gi` = 1024Mi.

---

## Key kubectl Commands

```bash
# Namespace operations
kubectl get pods -n <namespace>
kubectl get all -n <namespace>
kubectl describe pod <pod-name> -n <namespace>

# Logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> -f           # follow/stream
kubectl logs -l app=<label> -n <namespace>           # by label selector

# Exec into a pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Watch (useful for seeing pods come/go)
kubectl get pods -n <namespace> --watch

# Events (good for debugging why a pod won't start)
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Port-forward for local debugging
kubectl port-forward svc/<service> 8080:80 -n <namespace>
```

---

## Kubernetes Secrets

```hcl
# Terraform-managed Kubernetes secret pattern
resource "kubernetes_secret" "my_secret" {
  metadata {
    name      = "my-secret-name"
    namespace = "target-namespace"
  }
  data = {
    key = data.google_secret_manager_secret_version.my_secret.secret_data
  }
  type = "Opaque"
}
```

**Never** store secrets in ConfigMaps, environment variable literals in pod specs, or git-tracked YAML files.

---

## Namespace Conventions

- One namespace per service/workload (not one giant `default`)
- `<ci-runner-namespace>` — CI runner pods
- `istio-system` — Istio control plane components
- Service namespaces follow the service/team name

---

## Helm CRD Limitation — Critical Pattern

Helm v3 **never updates existing CRDs** on `helm upgrade`. This is by design — Helm treats CRDs as a one-time install. If a cluster has legacy CRDs from an older Helm v2 (Tiller-based) install, those CRDs will be stale forever unless updated out-of-band.

**Solution pattern:**
```hcl
resource "null_resource" "istio_crds" {
  triggers = { istio_version = local.istio_meta.istio_version }
  provisioner "local-exec" {
    command = <<EOT
helm template release-name chart-name \
  --repo https://chart-repo-url \
  --version $VERSION --include-crds --no-hooks \
  | kubectl apply --server-side --force-conflicts -f -
EOT
  }
}

resource "helm_release" "istio_base" {
  depends_on = [null_resource.istio_crds]  # CRDs must exist before Helm runs
  ...
}
```

**Key flags:**
- `--server-side`: server-side apply, tracks field ownership per-manager
- `--force-conflicts`: takes ownership from previous managers (e.g. Tiller)
- `--include-crds --no-hooks`: extracts only CRDs from the chart template

**CRITICAL — kubectl auth dependency:** Any `null_resource` that runs kubectl in a cluster-bootstrap module MUST depend on whatever resource writes the kubeconfig, if it doesn't transitively depend through Helm releases. Without that dependency, kubectl falls back to `localhost:8080` → connection refused. This is a real failure mode the first time a fresh apply runs — order matters even though nothing in the HCL visibly ties them together.

**When to use:** Any Helm chart that ships CRDs AND was previously installed via Helm v2/Tiller or an older version that served different API versions.

**Lesson learned:** A cluster with CRDs from an old Tiller install (only supporting an older CRD API version) will break when a newer chart version requires the newer CRD API version. Clusters with fresh installs from the start are unaffected — the bug only bites clusters with install history predating the CRD version bump.

---

## Helm Releases via Terraform

```hcl
resource "helm_release" "my_chart" {
  name             = "release-name"
  repository       = "https://charts.example.com"
  chart            = "chart-name"
  version          = "1.2.3"          # always pin the chart version
  namespace        = "target-namespace"
  create_namespace = false             # let Terraform manage the namespace separately

  values = [yamlencode({
    # Helm values as HCL object → Terraform interpolates variables
    image.tag = var.image_tag
  })]
}
```

---

## HARD RULE — Always Ask Before kubectl Mutations

Before running any of these, show the exact command + environment and wait for explicit "yes, run it":
- `kubectl delete` (any resource)
- `kubectl apply` (any manifest)
- `kubectl patch` / `kubectl edit`
- `helm upgrade` / `helm install` / `helm uninstall`

`kubectl get`, `kubectl describe`, `kubectl logs` are safe — run freely.

---

## Diagrams

If diagram generation is required for implementations in this domain, load a diagrams skill alongside this one and save output per that skill's convention.

## Local addendum

If `ADDENDUM.md` exists in this skill's directory, read it before acting. It carries the employer-specific values this body refers to generically: org and repo names, ticket prefix, project and cluster names, incident history, and local probe commands.
