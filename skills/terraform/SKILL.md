---
category: technical
paths:
  - "**/*.tf"
  - "**/*.tf.json"
  - "**/modules/**"
---
# Skill: Terraform — Patterns and Gotchas

**Context:** Terraform handles resource definitions; Terragrunt (where used) handles state, DRY config, and dependencies. Prefer Terragrunt commands over raw `terraform` in any repo that has adopted it.

---

## Provider Versions — Lock Them

```hcl
terraform {
  required_providers {
    google      = { source = "hashicorp/google",      version = "<x.y.z>" }
    google-beta = { source = "hashicorp/google-beta", version = "<x.y.z>" }
    kubernetes  = { source = "hashicorp/kubernetes",  version = "<x.y.z>" }
    helm        = { source = "hashicorp/helm",        version = "<x.y.z>"  }
  }
}
```

**Why lock versions?** Prevents provider changes from breaking infra. Upgrade deliberately, not accidentally.

---

## Module File Structure Pattern

Every module follows this layout:

```
modules/<category>/<name>/
├── main.tf         # primary resources
├── providers.tf    # required_providers + provider configs
├── variables.tf    # all input variables
├── outputs.tf      # all outputs
└── <optional>.tf   # extra resource files (e.g. helm.tf, k8s.tf)
```

One resource type per file when a module has multiple complex resources (cluster + Helm + K8s).

---

## Secrets — Never in HCL, Always from a Secret Manager

```hcl
# Read a secret from a secret manager
data "google_secret_manager_secret_version" "app_token" {
  secret  = "<secret-name>"
  project = var.gcp_project_id
}

# Use it in a resource
resource "kubernetes_secret" "app_token" {
  data = {
    token = data.google_secret_manager_secret_version.app_token.secret_data
  }
}
```

**Why:** Hardcoding secrets in `.hcl` files risks them ending up in git history or Terraform state in plaintext.

---

## Helm Values — Use yamlencode()

```hcl
resource "helm_release" "example" {
  values = [yamlencode({
    agent = {
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
        limits   = { cpu = "500m", memory = "512Mi" }
      }
    }
  })]
}
```

**Why yamlencode() over `values = [file("values.yaml")]`?** Allows Terraform interpolation (variable references, data source outputs). Keeps everything in one file. No separate values.yaml to maintain.

---

## Sensitive Outputs

```hcl
output "cluster_endpoint" {
  value     = google_container_cluster.my_cluster.endpoint
  sensitive = true   # prevents printing in plan/apply output
}
```

Mark outputs sensitive when they contain tokens, endpoints, certificates, or any credential-adjacent data.

---

## deletion_protection

```hcl
resource "google_container_cluster" "example" {
  deletion_protection = false   # OK for non-prod; set true for prod clusters
}
```

`deletion_protection = true` (the GKE default) prevents `terraform destroy` from deleting the cluster. For dev/test clusters, set `false` so cleanup works. For prod, leave as `true`.

---

## depends_on for K8s Resources

Kubernetes and Helm providers initialize lazily — they connect to the cluster when they first need to. Resources that must wait for the cluster:

```hcl
resource "kubernetes_namespace" "example" {
  depends_on = [google_container_cluster.example]
}

resource "helm_release" "agent" {
  depends_on = [
    kubernetes_namespace.example,
    kubernetes_secret.app_token,
  ]
}
```

**Why:** Without `depends_on`, Terraform might try to create the namespace before the cluster API server is ready.

---

## google-beta Provider

Required for resources not yet in the stable google provider:
- `enable_autopilot = true` on GKE clusters
- Some network features

```hcl
resource "google_container_cluster" "example" {
  provider = google-beta   # required for enable_autopilot
  enable_autopilot = true
}
```

---

## Verification After Writing Terraform

```bash
# In the module directory:
terraform fmt .         # normalize formatting
terraform validate      # check syntax + schema (requires terraform init first)

# In the Terragrunt live config directory, if applicable:
TG_ENV=<env> terragrunt validate
TG_ENV=<env> terragrunt plan    # always plan before apply
```

Don't run `terraform fmt` on files you aren't otherwise changing — it creates noisy, unrelated diffs in a PR.

---

## Workspace/Directory Groups via a Non-Default Provider

Some SaaS identity providers (e.g. a Workspace/directory group provider) can't authenticate for domain-scoped group operations through the mainline cloud provider without complex service-account setup. If a dedicated provider exists for that purpose and already has delegated auth configured, prefer it over forcing the mainline provider.

**Architecture pattern:** keep org-scoped resources (like directory groups) in a single environment's state, not symlinked/duplicated across every env's state — otherwise every env competes to create the same resources.

```
common/groups.yaml              → membership data (symlinked everywhere, read-only)
common/group-locals.tf          → string locals for IAM (symlinked everywhere)
<one-env>/groups.tf             → actual resources (single env state only)
<one-env>/workspace-provider.tf → dedicated provider auth
```

**CRITICAL — domain-wide delegation:** When adding OAuth scopes to a domain-delegated provider's config, you MUST also add them to the admin console's domain-wide delegation for that client ID. The provider typically requests ALL scopes in one token — an unauthorized scope breaks the ENTIRE auth, including existing resources that used to work.

Keep the scope list in the provider config and the admin-console delegation list in sync — every scope must appear in both.

---

## GitHub App Authentication (instead of a PAT)

Using a **GitHub App** for team/repo management instead of a personal access token:

```hcl
data "google_secret_manager_secret_version" "github_app_private_key" {
  count   = var.github_app_id != "" ? 1 : 0
  secret  = "github-app-private-key"
  project = local.gcp_project_id   # reads from current env's project
}

provider "github" {
  owner = "<org>"
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = try(data.google_secret_manager_secret_version.github_app_private_key[0].secret_data, "")
  }
}
```

**How values flow:** CI context env vars → container env → Terragrunt `get_env()` → module input variables → provider `app_auth` block. The PEM key comes from a secret manager (one copy per project/environment).

**PACKAGES LIMITATION:** GitHub App installation tokens **cannot authenticate with GitHub Packages/GHCR** ([community discussion](https://github.com/orgs/community/discussions/24636)). The `packages` permission in the App UI only controls billing API access, not actual push/pull. Package publishing requires PATs or Actions `GITHUB_TOKEN`.

**Token lifecycle & revocation:**
- Installation tokens are **1 hour TTL**, non-renewable without the PEM.
- The Terraform provider generates a fresh token per `terraform apply` invocation — the token dies with the process.
- The token lives only in container memory — when the container exits, the token is gone (never written to disk).
- Non-GitHub steps between Terraform runs do NOT consume the token's TTL.
- User-to-server tokens (OAuth flow) are a different mechanism, not used by Terraform.
- If a stolen installation token is compromised, the attacker has at most the remaining TTL and cannot extend it without the PEM.
- **Revocation API:** `DELETE /installation/token` (Authorization: Bearer <token>) — immediately invalidates the token. The TF provider doesn't expose the token for manual revocation, so a wrapper script would be needed; an ephemeral container effectively self-revokes on exit.

**Repository-level permissions:**
- `github_team` + `github_team_membership` → Organization > Members: Write
- `github_team_repository` (team collaborators on repos) → **Repository > Administration: Write** (separate from org-level Administration)

**Gotchas learned the hard way:**
1. **CI context vars don't auto-enter a container** — the container's compose/env config must explicitly pass them through.
2. **Don't name env vars `GITHUB_APP_ID`/`GITHUB_APP_INSTALLATION_ID`** — the `integrations/github` provider auto-reads these, causing partial auth if the PEM env var isn't also set. Use a distinct prefix for your own vars.
3. **`GITHUB_TOKEN` in env takes precedence** over a broken `app_auth` block — if `app_auth` values are empty strings, the provider silently falls back to a `GITHUB_TOKEN` PAT. A silent fallback like this can mask a broken App config for a long time.
4. **PEM must be stored with real newlines** — write it with a `--data-file=` flag from a file, not by pasting into a web UI (which can mangle line breaks).
5. **Don't run `terraform fmt` on files you're not changing** — it creates noisy PRs.

---

## Cross-Repo IAM Conflict: Additive vs Authoritative Bindings (CRITICAL)

**Two repos (or two Terraform roots) managing IAM on the same project with conflicting resource types is a ticking time bomb:**
- One side using `google_project_iam_binding` (authoritative: "ONLY these members get this role")
- The other side using `google_project_iam_member` (additive: "add this member to this role")

**If you add a `google_project_iam_member` for a role that another root manages via `iam_binding`, that root's next apply REMOVES it** — silently, with no error, on a completely unrelated PR's apply.

**MANDATORY checklist when granting any service account a project-level role:**
1. Check whether the role already has an `iam_binding` managed elsewhere in the org's Terraform.
2. If yes → **also add the SA to that binding's member list**, in the same change window (may mean a PR to each repo).
3. If no → safe to use `iam_member` in the current root only.

Applies especially to: any new IAM role grant for a CI service account, a workload identity SA, or a K8s SA needing project-level roles. When onboarding a new repo/root that manages IAM, first inventory every existing `iam_binding` in the org before adding any `iam_member`.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Adding `iam_member` for a role that another root manages via `iam_binding` | Also add the SA to the authoritative binding's member list — otherwise it gets removed on the next apply |
| Hardcoding secrets | Use `data "google_secret_manager_secret_version"` (or equivalent) |
| Missing `depends_on` on k8s resources | Add explicit dependency on the cluster resource |
| A `null_resource` running kubectl without depending on kubeconfig setup | kubeconfig doesn't exist yet → kubectl hits localhost:8080 → connection refused. Always `depends_on = [null_resource.setup_kubectl]` |
| Wrong provider for Autopilot | Add `provider = google-beta` |
| Forgetting `sensitive = true` on credential outputs | Always mark tokens/certs sensitive |
| Using raw `terraform` instead of `terragrunt` in a Terragrunt-managed env | Use `TG_ENV=x terragrunt ...` |
| Relying on Helm to upgrade CRDs | Helm v3 never updates existing CRDs — use `null_resource` + `helm template` + `kubectl apply --server-side` |
| Using the mainline cloud provider for Workspace/directory groups | Use the dedicated identity provider — the mainline provider often can't auth for domain-scoped group operations |
| Adding domain-delegated OAuth scopes without updating the admin console's delegation list | All scopes must be in BOTH the provider config AND the admin console delegation — one missing scope can break ALL auth for that client ID |
| Putting org-scoped resources in a symlinked/shared config dir | Symlinked config gets applied by every env's state → state conflicts. Put it in one env's directory |

---

## Diagrams — Required for All Implementations

**Every implementation in this domain MUST include a diagram.** Load the diagrams skill alongside this skill when generating diagrams.

- **Format:** draw.io XML (`.drawio`) is the primary format
- **Style:** Use color-coded zones, priority badges, and legends per the diagrams skill guide
- **Validate:** Always run XML validation before delivering: `python3 -c "import xml.etree.ElementTree as ET; ET.parse('file.drawio')"`
- **XML safety:** Never use HTML named entities (`&amp;rarr;`, `&amp;bull;`) in raw XML — use numeric entities or ASCII

## Local addendum

If `ADDENDUM.md` exists in this skill's directory, read it before acting. It carries the employer-specific values this body refers to generically: org and repo names, ticket prefix, project and cluster names, incident history, and local probe commands.
