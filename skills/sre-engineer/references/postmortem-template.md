# Postmortem Template

Blameless. Action-oriented. Post it to wherever your team's incident docs live and link it from the paging-tool incident.

```markdown
# Postmortem — <one-line title>

- **Incident ID:** <paging-tool incident ID>
- **Date:** <YYYY-MM-DD>  **Detected:** <UTC>  **Resolved:** <UTC>  **Duration:** <Xm>
- **Severity:** SEV-<n>  **Customer impact:** yes/no, scope
- **Authors:** <names>  **Reviewed by:** <names>

## TL;DR
2–3 sentences a non-engineer can read.

## Timeline (UTC)
| Time | Event |
|---|---|
| 04:12 | Burn-rate alert fires (fast burn, 1m window 14.4×) |
| 04:13 | Paging tool pages oncall |
| 04:18 | Oncall ack, opens log-explorer link from alert payload |
| ... | |

## Root cause
What was the technical fault. Be specific. Include the file/line if known.

## Why did our defenses fail?
For each defense that should have caught this:
- Test coverage: did we have a test? did it run?
- Alert: did the right alert fire? at the right time?
- Review: did the PR review catch it? if not, why?
- Canary / rollout: did we stage it? if not, why?

## What went well
Bullets. Include them. Reinforces signal.

## What went badly
Bullets. Be honest. No naming individuals.

## Action items
| ID | Owner | Due | Description |
|---|---|---|---|
| AI-1 | <person> | <date> | <concrete action> |

Action items must be SMART. "Improve monitoring" is not an action item; "add alert on FooQueue depth > 100 sustained 5m, page <team>" is.

## References
- APM incident: <link>
- Paging-tool incident: <link>
- Log query: <link with time range>
- Related PRs: <links>
- Earlier related postmortems: <links>
```

## Trigger thresholds (when to write)

- Any P0 page
- Customer-impacting incident regardless of pager
- Near-miss where a single additional failure would have caused customer impact
- Anything an exec asks about

## Anti-patterns

- "Human error" as root cause — keep digging until you find the system that allowed the error
- "We will be more careful" as action item — replace with a control
- Skipping the "what went well" section — those are reinforcement signals worth surfacing
