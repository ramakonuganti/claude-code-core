---
category: workflow
name: sre-engineer
description: Use when defining SLIs/SLOs, managing error budgets, designing incident response, building reliable systems at scale, capacity planning, or reducing toil.
paths:
  - "**/slo/**"
  - "**/slo.yaml"
  - "**/runbooks/**"
  - "**/postmortems/**"
  - "**/pagerduty/**"
  - "**/newrelic/**"
metadata:
  domain: reliability
  triggers: SLO, SLI, error budget, incident response, postmortem, golden signals, on-call, MTTR, capacity, toil reduction, paging, runbook
  role: specialist
  scope: design + implementation
  related-skills: monitoring-expert, chaos-engineer, kubernetes, gke
---

# SRE Engineer

**Worked-example stack:** the patterns below are phrased against a paging tool (e.g. PagerDuty/Squadcast/Opsgenie) + an APM/alerting platform (e.g. New Relic/Datadog) + a log platform (e.g. Google Cloud Logging/CloudWatch). Swap in your own stack's terminology — the method is what matters, not the vendor names.

## Two-Tier SLO/SLA Model

Split alerts into two tiers: **SLO = warning/ticket** (multi-window burn rate) and **SLA = critical/page** (single threshold below). Per-env severity tables let prod downgrade SLO to `warning` while keeping SLA `critical`. This is usually the single biggest noise-reduction lever available — apply it to every new service.

**Canonical module shape** (organize your alerting Terraform this way, regardless of vendor):
- `<module-source>/health` — synthetic-monitor uptime
- `<module-source>/slo/{endpoint,error,performance}` — SLO burn-rate
- `<module-source>/sla` — SLA single-threshold page
- `<module-source>/derive-alert-infrastructure-outputs` — driver that resolves team/env/severity into alert policies

When migrating from an older per-service alerting setup: keep the deprecated top-level modules working for existing services, but stop using them for new work.

**Per-env settings table** (canonical pattern):
```hcl
service_settings_all = {
  dev   = { health = { enabled = true, severity = "info" },     performance_slo = { ..., severity = "info" },     error_slo = { ..., severity = "info" } }
  stage = { health = { enabled = true, severity = "warning" },  performance_slo = { ..., severity = "warning" },  error_slo = { ..., severity = "warning" } }
  prod  = { health = { enabled = true, severity = "critical" }, performance_slo = { ..., severity = "warning" },  error_slo = { ..., severity = "warning" } }
}
```
Note prod: `health=critical` (synthetic down → page), `slo=warning` (burn-rate → ticket). Only SLA modules page in prod for steady-state-violation cases.

## When to Use

- Defining a new service's SLI/SLO before launch
- Calculating error budget burn for an alert decision
- Writing a postmortem after a page
- Designing alert routing in the paging tool or condition policies in the APM platform
- Right-sizing on-call rotation or estimating toil load
- Building diagnostic runbooks for an automated alert-triage agent

## When NOT to Use

- Pure infra changes (use `terraform`, `terragrunt`, `gke`)
- Rotation/secrets incidents (use a secrets-rotation skill)
- Generic K8s troubleshooting (use `kubernetes`)

## Core Workflow

1. **Define what reliability means for this service** — user-facing journey, not internal metric
2. **Pick SLIs from golden signals** — latency, traffic, errors, saturation; one or two per service
3. **Set SLO targets** — phrase as availability % over rolling window; tied to user expectation, not aspirational
4. **Compute error budget** — `(1 - SLO) × window`; track burn rate
5. **Design alerts on burn rate, not threshold** — slow burn (24h+) → ticket; fast burn (1h) → page
6. **Write the runbook BEFORE shipping the alert** — alert without runbook = noise

## MUST DO

- Phrase SLIs from the user's perspective (request success rate, p95 latency from gateway), not internal counters
- Tie every alert to a runbook URL in the alert payload (most paging tools support this in a description/details field)
- Write blameless postmortems for every page-worthy incident
- Use your APM platform's query language to define SLI queries; document the query in the SLO doc
- Track toil quarterly — anything an on-caller does >2x/quarter is an automation candidate
- Capture incident timelines in UTC, link to a log-explorer query pre-filtered to the incident time range

## MUST NOT DO

- Set SLOs without user-impact justification ("99.9% because nice number" → reject)
- Alert on symptoms without actionable runbooks
- Page on slow burns that can wait until business hours
- Use raw threshold alerts (`error_count > 100`) where burn-rate alerts work better
- Mix terminology from a paging tool you migrated away from — pick one vocabulary and use it consistently, it trips up imported runbook templates otherwise
- Auto-resolve incidents; require human ack so the postmortem trigger fires correctly

## Paging-Tool Integration Notes

- Service-to-service routing handled via the paging tool's service mappings; one service per microservice
- Alert sources: APM platform (primary), log-based metrics (rare, only when the APM platform is blind), CI failures (noise — keep low-severity)
- Maintenance windows: prefer an API/event-driven trigger pattern over manual UI toggling; keep manual UI as the fallback for unplanned windows

## APM/Alerting Patterns

- One alert policy per service, one condition per SLI; avoid mega-policies
- Query pattern for availability: `SELECT percentage(count(*), WHERE httpResponseCode < '500') FROM Transaction WHERE appName = 'X'` (adapt to your query language)
- For burn-rate, use a static threshold sustained for a window — fast burn = (14.4× normal rate sustained 1h), slow burn = (3× normal sustained 24h)
- Set per-condition-and-target incident grouping so per-host issues don't suppress each other

## Log Platform Patterns

- Log-based metrics for events your APM platform can't see (scheduled job failures, CI orb runs)
- Use structured logging (JSON payload) — easier to alert on specific fields
- Cost watch: log volume is often a top-3 cloud line item; keep default-bucket retention short (days) and route anything needing long retention to a warehouse
- Sink to a warehouse only for security/audit logs (long retention)

## Reference Guide

| Topic | Reference | Load when |
|---|---|---|
| SLO doc template | `references/slo-template.md` | Authoring a new SLO |
| SLA doc template | `references/sla-template.md` | Adding the paging tier to a service |
| Postmortem template | `references/postmortem-template.md` | Writing up an incident |
| Error budget math | `references/error-budget-math.md` | Computing budgets/burn rates |

## Local addendum

If `ADDENDUM.md` exists in this skill's directory, read it before acting. It carries the employer-specific values this body refers to generically: org and repo names, ticket prefix, project and cluster names, incident history, and local probe commands.
