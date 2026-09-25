# Error Budget Math

## Budget = (1 − SLO) × window

| SLO | Window | Budget |
|---|---|---|
| 99%   | 30d | 7h 12m  |
| 99.5% | 30d | 3h 36m  |
| 99.9% | 30d | 43m 12s |
| 99.95%| 30d | 21m 36s |
| 99.99%| 30d | 4m 19s  |
| 99.9% | 28d | 40m 19s |

Common default: rolling 28 days at 99.9% = 40min budget (28d aligns burn-rate math to a 4-week cadence rather than a calendar month).

## Burn-rate alerts (Google SRE multi-window)

A burn rate of N× means: at this rate, the budget is consumed N× faster than allowed. If sustained for the full window, you'd exhaust the budget in `window/N`.

Standard recipe:

| Window | Burn rate | Budget consumed | Severity |
|---|---|---|---|
| 1h (60s aggregation) | 14.4× | 2% | Page (fast burn — incident in progress) |
| 6h (1800s aggregation) | 6× | 5% | Ticket (moderate — investigate) |
| 24h (21600s aggregation) | 3× | 10% | Slack/notify (slow — track) |

Why 14.4? At 14.4× rate sustained 1h on a 99.9%/28d SLO: `1h × 14.4 / 720h_total_budget × 100% = 2%`. Catches obvious incidents fast without paging on noise.

## Example math

99.9% SLO over 28d → 40.32 min budget. Service does 100 req/sec. In 1h (3600s × 100 = 360,000 requests).

- 14.4× burn rate threshold → error rate = 14.4 × (1 − 0.999) = 1.44%
- In 1h that's 5,184 errors; SLO budget allows 360 over 28d × 0.001 = 360 errors over 28 days → 5184 errors in 1h obliterates budget. Page.

## When NOT to alert on burn rate

- Service has < 100 req/min — burn-rate denominators get noisy. Use static threshold + sustained-for instead.
- SLO covers a queue-style workload (lag-based). Use queue-depth alerts instead.
- New service in soft-launch: budget is meaningless until baseline traffic stabilizes.

## Budget exhausted — what to do

1. Freeze risky deploys to that service (no schema migrations, no infra changes)
2. Allocate next sprint's first slot to reliability work for that service
3. Review alerts that did/didn't fire; tune
4. After 2 consecutive cycles within budget, lift freeze
