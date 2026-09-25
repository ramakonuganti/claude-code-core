---
category: technical
description: Terragrunt patterns for a modules-plus-live-envs repo layout — shared config, dependency mocking, apply order, and remote state.
paths:
  - "**/*.hcl"
  - "**/terragrunt.hcl"
  - "**/root.hcl"
  - "**/envs/**"
---
# Skill: Terragrunt — Live-Config Repo Patterns

**Repo layout:** `modules/` (reusable HCL) + `envs/` (live Terragrunt configs)

---

## How Terragrunt Works (Mental Model)

Terragrunt is a thin wrapper around Terraform. It adds:
- **Remote state automation**: generates the backend config based on the env + path
- **DRY configuration**: `include "root"` pulls shared settings from `root.hcl`
- **Module dependencies**: `dependency` blocks let one Terragrunt config wait for another's outputs
- **Env keying**: a single env-selector env var picks which environment you're targeting

Think of each `terragrunt.hcl` as "Terraform with batteries included" — you specify the module source and inputs; Terragrunt handles the rest.

---

## Root Config (`root.hcl`)

```hcl
# envs/root.hcl — always included from child configs
include "root" {
  path = find_in_parent_folders("root.hcl")
}
```

`root.hcl`:
- Reads an env-selector variable (e.g. `TG_ENV`) to determine which environment you're working in
- Auto-generates the remote-state bucket/prefix based on env + path
- Sets default provider version constraints

---

## Shared Config Pattern (`envs/_shared/`)

All environment-specific values live in shared HCL files as **maps keyed by env name**:

```
envs/_shared/
├── cloud/
│   ├── projects.hcl    → project_id, region per env
│   ├── cluster.hcl     → cluster network CIDRs, node_pool_configs per env
│   └── ...
└── common/
    └── vpn.hcl         → vpn.enabled per env
```

**Known env keys:** `dev`, `stage`, `prod`, `cicd`

Each module reads the shared config like this:
```hcl
locals {
  cloud_meta = read_terragrunt_config(find_in_parent_folders("projects.hcl"))
}
inputs = {
  project_id = local.cloud_meta.locals.projects[var.env].project_id
}
```

**CRITICAL:** When adding a new environment, add it to ALL shared files that key by env:
- `projects.hcl` — cloud project ID and region
- `cluster.hcl` — network CIDRs (even if not using a cluster in that env) — must have `node_pool_configs = []`
- `vpn.hcl` — `enabled = false` if VPN not needed

---

## Dependency Output Shape

If a module outputs a **single nested object** rather than individual fields, mocks and references must match that shape exactly:

```hcl
# How to reference a nested dependency output:
dependency "network" {
  config_path = "${get_repo_root()}/envs/${local.env}/network"
  mock_outputs = {
    network_outputs = {
      network_self_link    = "projects/mock/global/networks/mock"
      subnetwork_self_link = "projects/mock/regions/<region>/subnetworks/mock"
      pods_range_name      = "mock-pods"
      services_range_name  = "mock-services"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  network_self_link    = dependency.network.outputs.network_outputs.network_self_link
  subnetwork_self_link = dependency.network.outputs.network_outputs.subnetwork_self_link
  pods_range_name      = dependency.network.outputs.network_outputs.pods_range_name
  services_range_name  = dependency.network.outputs.network_outputs.services_range_name
}
```

**Gotcha:** Mock outputs must EXACTLY mirror the real output structure. If the real output is a nested object, the mock must also be nested.

---

## Apply Commands

```bash
# Always set the env-selector var — it tells root.hcl which env to target
TG_ENV=<env> terragrunt apply --terragrunt-working-dir envs/<env>/network

# For modules with dependencies, apply in order:
TG_ENV=<env> terragrunt apply --terragrunt-working-dir envs/<env>/network
TG_ENV=<env> terragrunt apply --terragrunt-working-dir envs/<env>/compute/<module>

# Plan before apply (always):
TG_ENV=<env> terragrunt plan --terragrunt-working-dir envs/<env>/network
```

---

## Module Source Pattern

```hcl
terraform {
  source = "${get_repo_root()}/modules/compute/<module>"
}
```

`get_repo_root()` finds the root of the git repo. Always use this — never use relative paths like `../../../modules`.

---

## Dependency Mock Outputs

Mock outputs serve two purposes:
1. Allow `terraform init/validate/plan` to run without real infra deployed
2. Document the expected output shape for future developers

```hcl
dependency "network" {
  config_path = "..."
  mock_outputs = { ... }                                   # must mirror real shape
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  # Do NOT add "apply" — real outputs required for apply
}
```

---

## Cloud Projects Table (fill in for your org)

| Env | Project ID | Notes |
|-----|------------|-------|
| dev | `<project-dev>` | |
| stage | `<project-stage>` | |
| prod | `<project-prod>` | |
| cicd | `<project-cicd>` | |

---

## Remote State Paths

State files live in per-env storage buckets:
- Bucket: `<state-bucket-prefix>-${env}` (prod may drop the env suffix)
- Prefix pattern: `<namespace>/envs/${env}/<module>/terraform.tfstate`

Example: `gs://<state-bucket-prefix>-dev/<namespace>/envs/dev/observability/terraform.tfstate`

**CRITICAL — stale state after a repo split/archive:** If a module's state was previously tracked in a now-archived repo, all references should be repointed to its current home. Verify with a plan diff before assuming state is current — an archived repo's state can silently drift out of sync with reality.

---

## Checklist: Adding a New Environment

- [ ] Add to `envs/_shared/cloud/projects.hcl`
- [ ] Add to `envs/_shared/cloud/cluster.hcl` (with `node_pool_configs = []` if no cluster)
- [ ] Add to `envs/_shared/common/vpn.hcl`
- [ ] Create `envs/<env>/network/terragrunt.hcl`
- [ ] Create `envs/<env>/compute/<module>/terragrunt.hcl`
- [ ] Apply network first, then compute

---

## Diagrams

If diagram generation is required for implementations in this domain, load a diagrams skill alongside this one and save output per that skill's convention.

## Local addendum

If `ADDENDUM.md` exists in this skill's directory, read it before acting. It carries the employer-specific values this body refers to generically: org and repo names, ticket prefix, project and cluster names, incident history, and local probe commands.
