# SLA Template

SLA is the **paging tier**. Single below-threshold check. Only enabled in prod by default. Distinct from SLO (which is the multi-window burn-rate ticket-driven tier).

## Module: `<module-source>/sla`

Reads a resolved context config (team/env/severity) from the driver module plus a per-call config for the URLs/severity/thresholds.

```hcl
resource "newrelic_nrql_alert_condition" "sla" {
  policy_id    = data.newrelic_alert_policy.policy.id   # resolved by team-env-severity-policy
  enabled      = local.is_enabled
  type         = "static"
  name         = local.alert_name
  description  = local.alert_description
  runbook_url  = var.context_config.runbook
  fill_option  = "static"
  fill_value   = 100                                    # missing data → assume healthy (100%)
  aggregation_window = var.nr_config.aggregation_window
  aggregation_method = "event_flow"
  aggregation_delay  = var.nr_config.aggregation_delay
  nrql {
    query = local.final_sla_query                       # generated from sla_request_urls
  }
  critical {
    operator              = "below"                     # success rate BELOW threshold
    threshold             = var.nr_config.sla_violation_threshold
    threshold_duration    = var.nr_config.sla_violation_threshold_duration
    threshold_occurrences = var.nr_config.critical_threshold_occurrences
  }
}
```

## SLA vs SLO — when to use which

| Question | SLO (burn-rate) | SLA (single threshold) |
|---|---|---|
| Where does it route? | Ticket/Slack | Page |
| Severity in prod | `warning` | `critical` |
| Sensitivity | Catches gradual degradation | Catches steady-state breach |
| Windows | 3 (fast/moderate/slow) | 1 |
| Operator | `above_or_equals` (burn rate) | `below` (success rate) |
| Lower envs | `info` / `warning` | usually disabled |

## When to add a new SLA

- Endpoint is in the contractual API (public API, partner integrations)
- A 5-minute outage of this endpoint costs revenue (payments, messaging)
- Customer SLAs reference it explicitly

## When NOT to add a new SLA

- Internal-only endpoint
- Best-effort batch/async path (use SLO + budget alerts instead)
- Endpoint has < 100 req/min (denominator too noisy — the SLA will flap)

## Per-service SLA URL set (canonical pattern)

```hcl
sla_request_urls = [
  {
    endpoint_urls = [
      "/api/v1/admin/locations/%/location-features",
      "/api/v1/organizations/%/features/%/locations"
    ]
    dev   = { severity = "info",     enabled = false }
    stage = { severity = "warning",  enabled = false }
    prod  = { severity = "critical", enabled = true }
  }
]
```

The `%` is SQL-style wildcard for the URL match in the load-balancer log source; multiple URLs per SLA are OR'd inside the generated query.

## Routing

Use a naming convention for the alert policy such as `<team>-<env>-critical--policy`, and wire it to the team's paging destination via the same driver module every time. **Never wire the paging channel by hand** — always go through the driver to keep team mappings consistent.
