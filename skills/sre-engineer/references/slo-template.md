# SLO Template

## Module hierarchy

Organize alerting modules by tier, not by service, so every service picks up improvements for free:

| Tier | Module | Severity | Behavior |
|---|---|---|---|
| Health | `<module-source>/health` | prod=critical, lower envs warning | Synthetic monitor (every 1 min from multiple regions). Down 1+ location → page. |
| SLO endpoint | `<module-source>/slo/endpoint` | prod=warning | Per-URL+method burn-rate, 3 windows (fast/moderate/slow). |
| SLO error | `<module-source>/slo/error` | prod=warning | Service-wide error rate from the load-balancer log source. |
| SLO performance | `<module-source>/slo/performance` | prod=warning | Duration-based from the APM transaction source. |
| SLA | `<module-source>/sla` | prod=critical | Single below-threshold page. **Only paging tier in prod.** |
| Driver | `<module-source>/derive-alert-infrastructure-outputs` | — | Team/env/severity → alert policy resolution. |

## Canonical wiring

```hcl
locals {
  service_context = {
    service_name = var.service_name
    team         = var.team
    env          = var.this_env
    dns          = var.dns
  }

  service_settings_all = {
    dev   = { health = { enabled = true, severity = "info" },     performance_slo = { enabled = true, severity = "info" },     error_slo = { enabled = true, severity = "info" } }
    stage = { health = { enabled = true, severity = "warning" },  performance_slo = { enabled = true, severity = "warning" },  error_slo = { enabled = true, severity = "warning" } }
    prod  = { health = { enabled = true, severity = "critical" }, performance_slo = { enabled = true, severity = "warning" },  error_slo = { enabled = true, severity = "warning" } }
  }

  slo_endpoints = [
    {
      endpoint_url            = "/api/v1/organizations/%/features/%/locations%"
      lb_logs_url             = "/api/v1/organizations/%/features/%/locations%"
      request_method          = "GET"
      error_target_percentage = 99
      perf_duration           = 0.5
      perf_target_percentage  = 99
      rolling_count_days      = 28
      env_severities = {
        dev   = { severity = "info",    enabled = true }
        stage = { severity = "warning", enabled = true }
        prod  = { severity = "warning", enabled = true }   # SLO = warning, never page
      }
    },
  ]

  filtered_endpoints = [for ep in local.slo_endpoints : merge(ep, ep.env_severities[var.this_env])]

  # SLA URLs are SEPARATE from SLO URLs and only paged in prod
  sla_request_urls = [
    {
      endpoint_urls = [
        "/api/v1/admin/locations/%/location-features",
        "/api/v1/organizations/%/features/%/locations",
      ]
      dev   = { severity = "info",     enabled = false }
      stage = { severity = "warning",  enabled = false }
      prod  = { severity = "critical", enabled = true }    # SLA = critical, pages
    }
  ]
  filtered_sla_request_urls = {
    for e in local.sla_request_urls : join(",", e.endpoint_urls) => merge(e, e[var.this_env])
  }
}

module "derive-alert-infrastructure-outputs" {
  source           = "<module-source>/derive-alert-infrastructure-outputs"
  service_context  = local.service_context
  service_settings = local.service_settings_all[var.this_env]
}

module "team-service-health-check" {
  source         = "<module-source>/health"
  context_config = module.derive-alert-infrastructure-outputs.base_health_config
}

module "nr-endpoint-slo" {
  source         = "<module-source>/slo/endpoint"
  context_config = module.derive-alert-infrastructure-outputs.all_slo_configs.endpoint
  nr_config      = { endpoints = local.filtered_endpoints }
}

module "nr-sla" {
  for_each       = local.filtered_sla_request_urls
  source         = "<module-source>/sla"
  context_config = module.derive-alert-infrastructure-outputs.sla_config
  nr_config = {
    sla_request_urls = each.value.endpoint_urls
    severity         = each.value.severity
    enabled          = each.value.enabled
  }
}
```

## Author Format (`docs/slo/<service>.md`)

```markdown
# <service> — SLO/SLA

## User journey
<one sentence describing what the user does that this protects>

## SLO (warning tier — burn-rate)
- Source: load-balancer log source (errors) / APM transaction source (latency)
- Endpoints: <list with target % + perf_duration>
- Window: rolling 28 days
- Burn-rate alerts: 3 windows (fast 1m / moderate 30m / slow 6h), all → ticket

## SLA (critical tier — pages prod)
- URLs (prod-only enable): <list>
- Threshold: success rate must stay above X% for Y minutes
- Routes to: <paging-tool service> (P0)

## Runbook
- URL: <wiki/runbook URL for this service>
- Owner team: <team>
- Last reviewed: <date>
```

## Common values

- Default rolling window: 28 days (matches calendar month)
- Bad-events filter: `httpRequest.status > 420 AND httpRequest.status != 429` (excludes rate-limit)
- Health monitor period: `EVERY_MINUTE` from 3+ regions
- Health `violation_time_limit_seconds`: 3600 if severity=critical else 86400

## Anti-patterns (the things this pattern fixes)

- ❌ Pages on SLO burn-rate in prod — that's noise. SLO → ticket. SLA → page.
- ❌ Same severity across all envs — dev/stage at `info`/`warning`, prod splits per tier
- ❌ Rolling everything into one alert policy — the driver creates per-team-per-env-per-severity policies
- ❌ Using deprecated per-service modules for new services — use the shared tiered modules
