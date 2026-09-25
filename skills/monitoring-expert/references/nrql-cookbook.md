# NRQL Cookbook

Default rolling window for SLO/SLA math: 28 days. Adapt account/entity references to your own APM account.

## Golden signals

```sql
-- Latency (Transaction APM)
SELECT percentile(duration, 50, 95, 99)
FROM Transaction
WHERE appName = '<service>'
TIMESERIES SINCE 1 hour ago

-- Throughput
SELECT rate(count(*), 1 minute)
FROM Transaction
WHERE appName = '<service>'
TIMESERIES

-- Error rate
SELECT percentage(count(*), WHERE error IS true)
FROM Transaction
WHERE appName = '<service>'
TIMESERIES

-- Saturation (K8s container)
SELECT average(cpuUsedCores / cpuLimitCores) * 100 AS 'CPU %',
       average(memoryUsedBytes / memoryLimitBytes) * 100 AS 'Mem %'
FROM K8sContainerSample
WHERE clusterName = '<cluster>' AND namespace = '<namespace>'
FACET podName
TIMESERIES
```

## SLO burn-rate (canonical pattern)

Tiered SLO modules typically emit:

```sql
FROM Metric
SELECT clamp_max(sum(newrelic.sli.bad) / sum(newrelic.sli.valid) * 100, 100) AS 'SLO compliance'
WHERE sli.guid = '<sli_guid>'
```

Wired with three aggregation windows: 60s (fast burn — 14.4× threshold), 1800s (moderate — 6×), 21600s (slow — 3×). Each window is a separate alert condition with `aggregation_method = "event_flow"`, `aggregation_delay = 120`, `fill_option = "static"`, `fill_value = 0`.

## Endpoint error/perf (load-balancer log source)

```sql
-- Valid events
FROM Log_Load_Balancer
SELECT count(*)
WHERE httpRequest.requestUrl LIKE '%//<dns><url>%'
  AND httpRequest.requestMethod = 'GET'
  AND httpRequest.status IS NOT NULL

-- Bad events (excluding rate-limit)
FROM Log_Load_Balancer
SELECT count(*)
WHERE httpRequest.requestUrl LIKE '%//<dns><url>%'
  AND httpRequest.requestMethod = 'GET'
  AND httpRequest.status > 420
  AND httpRequest.status != 429
```

`%` is SQL wildcard. The `>420` operator catches 4xx and 5xx but excludes 200-420 (auth-related codes still healthy from SLA POV).

## Synthetic monitor health

```sql
-- Used by a shared health-check module
SELECT filter(uniqueCount(location), WHERE result = 'FAILED')
FROM SyntheticCheck
WHERE monitorId = '<monitor-id>'
```

Aggregation window: 60s. Fires `critical` when count above 1 sustained 60s.

## Heartbeat / liveness check (custom)

```sql
SELECT rate(count(apm.service.transaction.duration), 1 minute)
FROM Metric
WHERE appName = '<service-name>'
  AND transactionName = '<heartbeat-txn-name>'
```

Set `expiration_duration = 300`, `open_violation_on_expiration = true` so that a missing heartbeat fires.

## Scheduled/serverless job success/failure

```sql
SELECT count(*)
FROM Log
WHERE resource.type = 'cloud_function'
  AND resource.labels.function_name LIKE '<job-name-prefix>-%'
  AND severity >= 'ERROR'
```

## NRQL pitfalls

- `count()` without `SINCE` defaults to 1h — set explicitly
- `LIKE '%X%'` is slow on high-cardinality fields — prefer `=` where possible
- `FACET` more than 10 dimensions = unbounded cardinality cost
- `TIMESERIES AUTO` may pick a coarser bucket than you want — set explicitly (`TIMESERIES 1 minute`)
- `WHERE error IS true` only works on `Transaction`; log-based sources use numeric status-code comparisons instead
