---
category: technical
name: monitoring-expert
description: Use when designing alerts, dashboards, log queries, or telemetry pipelines. Focuses on golden signals, alert quality (low FP/FN), cost-aware log retention, and query patterns.
paths:
  - "**/dashboards/**"
  - "**/alerts/**"
  - "**/newrelic/**"
  - "**/*.nrql"
  - "**/log-based-metrics/**"
metadata:
  domain: observability
  triggers: NewRelic, NRQL, alert policy, dashboard, golden signals, log-based metric, Cloud Logging, paging routing, telemetry, monitoring
  role: specialist
  scope: design + implementation
  related-skills: sre-engineer, gke, kubernetes
---

# Monitoring Expert

**Worked-example stack:**
- **APM platform** (e.g. New Relic, Datadog) — primary APM, alerts, dashboards. Examples below use NRQL; swap for your platform's query language.
- **Paging tool** (e.g. PagerDuty, Squadcast, Opsgenie) — paging only, not a metric source. Receives webhooks from the APM platform and CI.
- **Cloud log platform** (e.g. Google Cloud Logging, CloudWatch) — application + infra logs. Log-based metrics for things the APM platform can't see.
- **Cloud metrics platform** (e.g. Google Cloud Monitoring, CloudWatch Metrics) — minimal use; only for infra signals the APM agent can't reach (managed DB replication lag, serverless function execution counts).

## When to Use

- Adding/tuning an APM alert
- Designing a service dashboard
- Writing a query in your APM or log query language
- Setting log retention or sink config
- Routing a new alert source into the paging tool

## When NOT to Use

- Defining SLOs (use `sre-engineer` — that's design-level; this skill is implementation-level)
- Pure infra changes (`terraform`, `terragrunt`)

## Golden Signals (per service)

| Signal | NRQL pattern |
|---|---|
| **Latency** | `SELECT percentile(duration, 50, 95, 99) FROM Transaction WHERE appName = 'X' TIMESERIES` |
| **Traffic** | `SELECT rate(count(*), 1 minute) FROM Transaction WHERE appName = 'X' TIMESERIES` |
| **Errors** | `SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = 'X' TIMESERIES` |
| **Saturation** | host or pod resource usage; for K8s pods use a container-sample source: `SELECT average(cpuUsedCores / cpuLimitCores) FROM K8sContainerSample WHERE clusterName = 'X' FACET podName` |

## Alert Design — MUST DO

- **Burn-rate alerts > threshold alerts** for SLO-bound services
- **Every alert has a runbook URL** in the policy description/details; the paging tool renders this in the page payload
- **One condition per SLI**, one policy per service (simplifies routing + ack-suppression)
- **Group incidents per condition-and-target** so per-host issues don't suppress each other
- **Sustained-for ≥ 5 min** for low-cardinality alerts (avoid flap from single deploy)
- **Test the alert** — query validation catches syntax errors, but also dry-run in dev with deliberate fault injection before promoting to prod

## Alert Design — MUST NOT DO

- Compound conditions in one rule (e.g., "errors AND latency"). Split into two; OR-route in the paging tool if they should page together.
- Use `count()` with no `since`/time-window clause — picks a default window, often wrong
- Alert on raw `error_count` for variable-traffic services — use error rate
- Send low-severity alerts to your default paging service — make a low-severity routing target or push to chat-only

## NewRelic Alert Policy Template (Terraform)

```hcl
resource "newrelic_alert_policy" "service" {
  name                = "${var.service}"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

resource "newrelic_nrql_alert_condition" "error_rate" {
  policy_id   = newrelic_alert_policy.service.id
  name        = "${var.service} — error rate burn"
  type        = "static"
  enabled     = true
  description = "Runbook: <wiki/runbook URL for this service>"

  nrql {
    query = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = '${var.service}'"
  }

  critical {
    operator              = "above"
    threshold             = 5  # 5% error rate
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}
```

## Log Platform Patterns

- **Structured logging** — prefer a JSON payload with a `severity`/`trace` field over free-text payloads for new code.
- **Log-based metrics** for events your APM platform can't see:
  - Scheduled/serverless job success/failure
  - Controller reconciler errors from a specific workload
  - Pre-merge CI audit failures
- **Cost-aware retention:**
  - Default log bucket: days in dev/stage, up to ~30d in prod
  - Audit/compliance bucket: long retention (e.g. 400d), immutable
  - Application logs beyond ~30d → sink to a warehouse, not raw log retention
- **Querying:** prefer your log platform's stored/saved queries over ad-hoc — they're shareable in postmortems

## Log-Based Metric Template (Terraform)

```hcl
resource "google_logging_metric" "rotation_failure" {
  project = var.project
  name    = "rotation-failure-${var.env}"
  filter  = <<-EOT
    resource.type="cloud_function"
    resource.labels.function_name=~"^rotate-secret-"
    severity>=ERROR
  EOT
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}
```

Then alert on it via your APM platform's query language (if it syncs cloud metrics) or your cloud metrics platform's native alerting.

## Paging-Tool Routing

- Webhook source per origin (APM platform, CI, cloud metrics platform)
- Service-mapping in the paging tool's UI: alert-policy name → paging-tool service
- Maintenance windows: prefer an API/event-driven trigger pattern; manual UI toggle as the fallback for unplanned windows
- Suppress flap: dedup keys default to per-condition; fine as long as incidents are grouped per-condition-and-target

## SLO/SLA Alert Tuning — Naming Convention

Once alert policies are generated by a driver module (see `sre-engineer`), name them `<team>-<env>-<severity>--policy` and resolve them centrally. **Don't create per-service alert policies by hand** — go through the driver. SLO modules emit `warning` channels (ticket/chat); SLA modules emit `critical` channels (page). Severity is set per-env in `service_settings_all` (see `sre-engineer/references/slo-template.md`).

## Reference Guide

| Topic | Reference | Load when |
|---|---|---|
| NRQL cookbook | `references/nrql-cookbook.md` | Writing NRQL-style queries |
| Dashboard templates | `references/dashboard-templates.md` | Building service dashboards |
| Log filter cookbook | `references/gcl-filters.md` | Writing log queries |

## Companion

- `sre-engineer` skill — for SLO/SLI design (this skill is implementation)

## Local addendum

If `ADDENDUM.md` exists in this skill's directory, read it before acting. It carries the employer-specific values this body refers to generically: org and repo names, ticket prefix, project and cluster names, incident history, and local probe commands.
