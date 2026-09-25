# Chaos Hypothesis Template

Every experiment starts as a written hypothesis. If you can't write it, you don't know what you're testing.

```markdown
# <Experiment name> — <YYYY-MM-DD>

## Owner
<name> · Reviewer: <name>

## Hypothesis
"If <fault> on <target>, then <expected behavior> within <time> with <constraints>."

Example:
"If we delete the leader pod of a stateful dependency's StatefulSet in stage, the StatefulSet will replace it within 60 seconds, the new pod will pick up the current secret from the secret manager, and replication lag will recover to < 30s within 3 minutes, with zero 5xx visible to callers."

## Steady-state metrics (define BEFORE injection)
- Pod count: <N>
- p95 latency: <X>ms
- Error rate: <Y%>
- Replication/CDC lag: <Z>s
- Pager alerts: 0

## Abort criteria
| Metric | Threshold | Action |
|---|---|---|
| Error rate | > 5% sustained 60s | STOP, restore |
| p95 latency | > 2000ms sustained 60s | STOP, restore |
| Pager P0 | any | STOP, restore |
| Customer reports | any | STOP, restore |

## Blast radius
- Env: <dev|stage|prod>
- Scope: 1 pod / 1 node / 1 zone (pick smallest that exercises hypothesis)
- Affected service: <name>
- Customer impact estimate: <none|low|medium>

## Pre-flight
- [ ] Maintenance/on-call-mute window scheduled
- [ ] Team channel pre-announce posted with start/end UTC
- [ ] Rollback command typed into a separate terminal
- [ ] Steady-state captured for 5–15 min
- [ ] Reviewer ack on hypothesis + abort criteria

## Run log
| UTC | Event |
|---|---|
| | inject fault: <command> |
| | first alert fires |
| | recovery start (visible) |
| | steady-state restored |

## Result
- Hypothesis confirmed? <yes|no|partial>
- Time-to-detect: <Xs>
- Time-to-recover: <Ys>
- Surprises:

## Action items (always — even on success)
- AI-1: <owner> by <date>: <action>
```

## Anti-patterns

- ❌ "We'll know it when we see it" instead of abort criteria
- ❌ More than one variable per experiment
- ❌ Skipping the run log — without timing data the experiment is wasted
- ❌ Skipping action items on success — successful experiments still expose follow-on failure modes
