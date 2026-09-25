# Dashboard Templates

Canonical pattern: one shared dashboard module (per-service dashboard with golden signals + DB panels), used by every service.

```hcl
module "nr-dashboard" {
  source         = "<module-source>/nr-dashboards-db"
  dashboard_name = var.service_name
  service_name   = var.service_name
}
```

Don't roll your own per-service dashboard. If a panel is missing from the shared module, add it there — every service gets the upgrade for free.

## Standard panel set

The shared dashboard should ship with these panels (verify by reading the module source):

1. **Overview row**
   - Throughput (req/min)
   - p50/p95/p99 latency
   - Error rate
   - Apdex
2. **DB row**
   - Slowest queries
   - Connection pool usage
   - Query throughput by operation
3. **K8s row** (joined via a container-sample source)
   - Pod CPU/Mem
   - Restart count
   - Pod status
4. **Logs row**
   - Recent ERROR-level log volume
   - Top error messages

## When to add a custom dashboard

Only when:
- Cross-service flow (e.g., a pipeline dashboard spans several serverless functions + a controller)
- Executive/SLA review (different audience than oncall)
- Incident war-room snapshot (one-off, time-boxed)

For most service work, the default shared dashboard module is enough.

## Custom dashboard via Terraform

```hcl
resource "newrelic_one_dashboard" "custom_pipeline" {
  name        = "Custom Pipeline"
  permissions = "public_read_only"

  page {
    name = "Overview"
    widget_billboard {
      title  = "Events last 24h"
      row    = 1
      column = 1
      width  = 4
      height = 3
      nrql_query {
        account_id = var.nr_account_id
        query      = "SELECT count(*) FROM Log WHERE resource.type = 'cloud_function' AND resource.labels.function_name LIKE 'my-job-%' SINCE 24 hours ago"
      }
    }
    # ... more widgets
  }
}
```

## Anti-patterns

- ❌ Per-service custom dashboards that duplicate the shared module — drift quickly
- ❌ Embedding env in dashboard name (`feature-service-dev-dashboard`) — the shared module should already FACET by env
- ❌ Cross-account dashboards — keep to one APM account per org unless there's a hard isolation requirement
- ❌ Public-write permission — always `public_read_only` or `private`
