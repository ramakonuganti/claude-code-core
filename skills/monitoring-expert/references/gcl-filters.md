# Log Filter Cookbook

Prefer structured (JSON) log payloads everywhere. Use your log platform's stored/saved queries — share via URL in postmortems. Avoid free-text payloads for new code.

## Common filters

```
# Service errors (GKE-style)
resource.type="k8s_container"
resource.labels.cluster_name="<cluster>"
resource.labels.namespace_name="<namespace>"
resource.labels.container_name="<service>"
severity>=ERROR
```

```
# Scheduled/serverless job failures
resource.type="cloud_function"
resource.labels.function_name=~"^<job-name-prefix>-"
severity>=ERROR
```

```
# Controller/operator errors
resource.type="k8s_container"
labels."k8s-pod/app"="<controller-app-label>"
jsonPayload.message=~"UnknownError|reconciler"
severity>=WARNING
```

```
# CI orb/pipeline audit failures (push from webhook)
resource.type="cloud_run_revision"
resource.labels.service_name="<audit-service>"
jsonPayload.audit_status="FAILED"
```

```
# Sidecar/agent liveness check
resource.type="k8s_container"
labels."k8s-pod/app"="<agent-app-label>"
severity>=INFO
```

```
# CDC/streaming pod logs filtered
resource.type="k8s_container"
resource.labels.namespace_name="<namespace>"
resource.labels.pod_name=~"-<component>-"
jsonPayload.level=~"ERROR|WARN"
```

## Log-based metrics (Terraform)

```hcl
resource "google_logging_metric" "job_failure" {
  project = var.project
  name    = "job-failure-${var.env}"
  filter  = <<-EOT
    resource.type="cloud_function"
    resource.labels.function_name=~"^<job-name-prefix>-"
    severity>=ERROR
  EOT
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
  label_extractors = {
    service = "EXTRACT(jsonPayload.service)"
  }
}
```

After apply, the metric shows up in your cloud metrics platform as a namespaced user metric. If your APM platform syncs cloud metrics, it becomes queryable there too (as a `Metric` source).

## Retention rules

| Bucket | dev | stage | prod |
|---|---|---|---|
| Default | 7d | 7d | 30d |
| Audit/compliance | 400d | 400d | 400d |
| Application logs >30d | sink to warehouse | sink to warehouse | sink to warehouse |

Log volume is often a top-3 cloud cost line item. Don't extend default-bucket retention for application logs — sink to a warehouse instead.

## Cost-aware patterns

- Use `severity>=WARNING` not `severity>=DEBUG` in saved queries that run frequently
- For dashboard panels, prefer log-based metrics (queried as numeric time-series) over raw-log queries
- Exclude noisy `INFO` log lines at ingest with exclusion filters if they're not needed for incident analysis

## Paging-tool routing from logs

Log-based metric → cloud metrics alert policy → paging-tool webhook (rare; most paths should go through the APM platform). Use only when the APM platform cannot see the source (serverless function logs, control-plane events).
